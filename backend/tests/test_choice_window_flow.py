"""Automated Integration Tests for Beneficiary Preference -> Choice Window -> Demand Lock Flow."""
import pytest
import httpx
from app.main import app
from app.core.database import get_db_connection, init_db
from app.data.seed_data import seed_all_data

@pytest.fixture(autouse=True)
def setup_database():
    """Ensure database is seeded with benchmark data before tests."""
    init_db()
    seed_all_data(recreate=False)
    conn = get_db_connection()
    conn.execute("DELETE FROM model_calibration;")
    conn.execute("DELETE FROM forecast_evaluation;")
    conn.execute("DELETE FROM actual_distribution;")
    conn.execute("DELETE FROM dispatch;")
    conn.execute("DELETE FROM forecast;")
    conn.execute("DELETE FROM demand_snapshots;")
    conn.execute("DELETE FROM planning_cycle_config;")
    conn.commit()
    conn.close()


@pytest.mark.asyncio
async def test_choice_window_status_initially_open():
    """Test 1: Choice window is OPEN initially with valid active preferences count."""
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        res = await client.get("/choice-window/status?cycle_id=2026-09")
        assert res.status_code == 200
        data = res.json()
        assert data["is_open"] is True
        assert data["status"] == "CHOICE_WINDOW_OPEN"
        assert data["active_intents_count"] > 0
        assert data["total_declared_intent_kg"] > 0
        assert "DEMO DATA" in data["demo_notice"]


@pytest.mark.asyncio
async def test_beneficiary_preference_submission_during_open_window():
    """Test 2: Beneficiary can submit / update portability preference while window is OPEN."""
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        payload = {
            "beneficiary_id": "BEN-KA-0005",
            "cycle_id": "2026-09",
            "intended_fps_id": "FPS-KA-BLR-001",
            "commodity": "Rice",
            "declared_quantity_kg": 20.0,
            "confidence": 0.95
        }
        res = await client.post("/intent", json=payload)
        assert res.status_code == 201
        data = res.json()
        assert data["beneficiary_id"] == "BEN-KA-0005"
        assert data["intended_fps_id"] == "FPS-KA-BLR-001"
        assert data["status"] == "SUBMITTED"


@pytest.mark.asyncio
async def test_close_choice_window_locks_demand():
    """Test 3: Admin closes choice window, computes D_hat, and locks demand baseline."""
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        # 1. Close choice window
        res = await client.post("/admin/choice-window/close?cycle_id=2026-09")
        assert res.status_code == 200
        data = res.json()
        assert data["status"] == "CHOICE_WINDOW_CLOSED"
        assert data["workflow_status"] == "FORECAST_LOCKED"
        assert data["total_locked_forecast_demand_kg"] > 0

        # 2. Verify status endpoint reflects closed window
        status_res = await client.get("/choice-window/status?cycle_id=2026-09")
        assert status_res.status_code == 200
        assert status_res.json()["is_open"] is False
        assert status_res.json()["status"] == "CHOICE_WINDOW_CLOSED"


@pytest.mark.asyncio
async def test_preference_submission_blocked_after_choice_window_closed():
    """Test 4: Preference submission is rejected with HTTP 400 once choice window is closed."""
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        # 1. Close choice window
        await client.post("/admin/choice-window/close?cycle_id=2026-09")

        # 2. Attempt to submit preference
        payload = {
            "beneficiary_id": "BEN-KA-0001",
            "cycle_id": "2026-09",
            "intended_fps_id": "FPS-KA-BLR-002",
            "commodity": "Rice",
            "declared_quantity_kg": 30.0
        }
        res = await client.post("/intent", json=payload)
        assert res.status_code == 400
        assert "closed and demand is locked" in res.json()["detail"]


@pytest.mark.asyncio
async def test_locked_demand_flows_into_downstream_dispatch():
    """Test 5: Locked demand baseline passes cleanly into constraints, optimization, and manifest."""
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        # 1. Close window and lock demand
        lock_res = await client.post("/admin/choice-window/close?cycle_id=2026-09")
        assert lock_res.status_code == 200

        # 2. Validate constraints against locked demand
        const_res = await client.get("/admin/constraints/validate?cycle_id=2026-09")
        assert const_res.status_code == 200
        assert const_res.json()["total_fps_audited"] == 20
        assert len(const_res.json()["fps_evaluations"]) == 20

        # 3. Generate dispatch manifest from locked demand
        disp_res = await client.post("/admin/dispatch/generate?cycle_id=2026-09")
        assert disp_res.status_code == 200
        manifest_data = disp_res.json()
        assert manifest_data["status"] == "success"
        assert manifest_data["total_dispatch_kg"] > 0


@pytest.mark.asyncio
async def test_beneficiary_preference_does_not_reduce_statutory_entitlement():
    """Test 6: Statutory entitlement floor is independent of declared intent quantity."""
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute("SELECT fps_id, beneficiaries_count, entitlement_rice_kg FROM fps WHERE fps_id = 'FPS-KA-BLR-001';")
    fps_row = cursor.fetchone()
    expected_statutory_quota = round(fps_row["beneficiaries_count"] * fps_row["entitlement_rice_kg"], 1)
    conn.close()

    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        # Submit a low intent quantity (e.g. 5 kg)
        await client.post("/intent", json={
            "beneficiary_id": "BEN-KA-0001",
            "cycle_id": "2026-09",
            "intended_fps_id": "FPS-KA-BLR-001",
            "commodity": "Rice",
            "declared_quantity_kg": 5.0
        })

        # Check depot balance / statutory floors
        depot_res = await client.get("/api/admin/scarcity/depot-balance?commodity=Rice")
        assert depot_res.status_code == 200
        # Mandatory statutory floor remains robust and untouched by low beneficiary signal
        assert depot_res.json()["statutory_floor_total_kg"] > 3000.0


@pytest.mark.asyncio
async def test_planning_day_advancement_and_snapshot_integrity():
    """Test 7: Advance planning day to Day 25, lock demand, verify frozen snapshot and SHA-256 integrity seal."""
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        # 1. Reset to open choice window Day 22
        day_res = await client.post("/admin/planning-cycle/set-day?day=22&cycle_id=2026-09")
        assert day_res.status_code == 200
        assert day_res.json()["planning_day"] == 22
        assert day_res.json()["cycle_state"]["is_open"] is True

        # 2. Advance to Day 25
        day25_res = await client.post("/admin/planning-cycle/set-day?day=25&cycle_id=2026-09")
        assert day25_res.status_code == 200
        assert day25_res.json()["planning_day"] == 25
        # Day 25 choice window should now be closed for preference modifications
        assert day25_res.json()["cycle_state"]["is_open"] is False

        # 3. Lock Demand Snapshot
        lock_res = await client.post("/admin/choice-window/close?cycle_id=2026-09")
        assert lock_res.status_code == 200
        lock_data = lock_res.json()
        assert lock_data["status"] == "CHOICE_WINDOW_CLOSED"
        assert lock_data["planning_day"] == 25
        assert "snapshot_id" in lock_data
        assert "canonical_hash" in lock_data
        assert len(lock_data["canonical_hash"]) == 64  # SHA-256

        # 4. Fetch the immutable Demand Snapshot via dedicated API
        snap_res = await client.get("/admin/planning-cycle/demand-snapshot?cycle_id=2026-09")
        assert snap_res.status_code == 200
        snap_body = snap_res.json()
        snapshot = snap_body["snapshot"]
        assert snapshot["cycle_id"] == "2026-09"
        assert snapshot["lock_status"] == "LOCKED"
        assert snapshot["is_frozen"] is True
        assert snapshot["canonical_hash"] == lock_data["canonical_hash"]
        assert "FPS-KA-BLR-001" in snapshot["fps_demand"]
        assert snapshot["total_locked_demand_kg"] > 0

        # 5. Verify Idempotency: Calling lock again returns the same snapshot and hash
        dup_lock_res = await client.post("/admin/choice-window/close?cycle_id=2026-09")
        assert dup_lock_res.status_code == 200
        assert dup_lock_res.json()["canonical_hash"] == lock_data["canonical_hash"]
