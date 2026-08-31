"""Comprehensive Automated API and Database Tests for PDS DemandSync Demo V1."""
import pytest
import httpx
from app.main import app
from app.core.database import get_db_connection, init_db, recreate_db
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
    conn.commit()
    conn.close()

@pytest.mark.asyncio
async def test_health():
    """Verify GET /health returns 200 OK and valid health metadata."""
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        response = await client.get("/health")
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "healthy"
        assert data["database_status"] == "connected"
        assert data["fps_count"] == 20
        assert data["beneficiaries_count"] == 2000
        assert data["active_cycle"] == "2026-09"
        assert len(data["historical_cycles"]) == 6
        assert "DEMO DATA" in data["demo_notice"]

@pytest.mark.asyncio
async def test_beneficiary_retrieval():
    """Verify beneficiary list pagination and individual beneficiary lookups."""
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        # 1. List beneficiaries (paginated)
        res_list = await client.get("/beneficiaries?limit=10&offset=0")
        assert res_list.status_code == 200
        list_data = res_list.json()
        assert list_data["total"] == 2000
        assert len(list_data["items"]) == 10
        assert list_data["items"][0]["pseudonymous_beneficiary_id"].startswith("BEN-KA-")

        # 2. Get single beneficiary by pseudonymous ID
        target_id = list_data["items"][0]["pseudonymous_beneficiary_id"]
        res_single = await client.get(f"/beneficiaries/{target_id}")
        assert res_single.status_code == 200
        single_data = res_single.json()
        assert single_data["pseudonymous_beneficiary_id"] == target_id
        assert "name_for_demo" in single_data
        assert single_data["registered_fps_id"].startswith("FPS-KA-BLR-")

        # 3. Non-existent beneficiary returns 404
        res_not_found = await client.get("/beneficiaries/NON-EXISTENT-ID")
        assert res_not_found.status_code == 404

@pytest.mark.asyncio
async def test_fps_retrieval():
    """Verify FPS list and individual FPS details with inventories and intent totals."""
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        # 1. List all 20 FPS
        res_list = await client.get("/fps")
        assert res_list.status_code == 200
        fps_list = res_list.json()
        assert len(fps_list) == 20
        assert fps_list[0]["fps_id"].startswith("FPS-KA-BLR-")
        assert fps_list[0]["capacity_kg"] > 0
        assert fps_list[0]["current_inventory_total_kg"] >= 0

        # 2. Get single FPS by ID
        target_fps = "FPS-KA-BLR-001"
        res_single = await client.get(f"/fps/{target_fps}")
        assert res_single.status_code == 200
        fps_detail = res_single.json()
        assert fps_detail["fps_id"] == target_fps
        assert len(fps_detail["inventories"]) == 2  # Rice & Wheat
        assert fps_detail["registered_beneficiaries_count"] > 0

        # 3. Non-existent FPS returns 404
        res_not_found = await client.get("/fps/FPS-NON-EXISTENT")
        assert res_not_found.status_code == 404

@pytest.mark.asyncio
async def test_intent_creation_success():
    """Verify POST /intent successfully records and updates beneficiary intent."""
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        payload = {
            "beneficiary_id": "BEN-KA-0001",
            "cycle_id": "2026-09",
            "intended_fps_id": "FPS-KA-BLR-013",  # Peenya Migrant Hub
            "commodity": "Rice",
            "declared_quantity_kg": 20.0,
            "confidence": 0.92
        }
        response = await client.post("/intent", json=payload)
        assert response.status_code == 201
        data = response.json()
        assert data["beneficiary_id"] == "BEN-KA-0001"
        assert data["intended_fps_id"] == "FPS-KA-BLR-013"
        assert data["commodity"] == "Rice"
        assert data["declared_quantity_kg"] == 20.0
        assert data["confidence"] == 0.92
        assert data["status"] == "SUBMITTED"
        assert data["is_portability_intent"] is True

@pytest.mark.asyncio
async def test_invalid_intent_nonexistent_beneficiary():
    """Verify POST /intent fails with 404 when beneficiary does not exist."""
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        payload = {
            "beneficiary_id": "BEN-INVALID-9999",
            "cycle_id": "2026-09",
            "intended_fps_id": "FPS-KA-BLR-001",
            "commodity": "Rice",
            "declared_quantity_kg": 25.0
        }
        response = await client.post("/intent", json=payload)
        assert response.status_code == 404
        assert "not found" in response.json()["detail"].lower()

@pytest.mark.asyncio
async def test_missing_fps():
    """Verify POST /intent fails with 404 when intended FPS does not exist."""
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        payload = {
            "beneficiary_id": "BEN-KA-0001",
            "cycle_id": "2026-09",
            "intended_fps_id": "FPS-INVALID-999",
            "commodity": "Rice",
            "declared_quantity_kg": 25.0
        }
        response = await client.post("/intent", json=payload)
        assert response.status_code == 404
        assert "not found" in response.json()["detail"].lower()

@pytest.mark.asyncio
async def test_invalid_quantity():
    """Verify POST /intent fails with 422 when quantity is zero or negative."""
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        payload_zero = {
            "beneficiary_id": "BEN-KA-0001",
            "cycle_id": "2026-09",
            "intended_fps_id": "FPS-KA-BLR-001",
            "commodity": "Rice",
            "declared_quantity_kg": 0.0
        }
        res_zero = await client.post("/intent", json=payload_zero)
        assert res_zero.status_code == 422

@pytest.mark.asyncio
async def test_historical_demand_and_inventory():
    """Verify historical demand and inventory endpoints for an FPS."""
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        res_hist = await client.get("/historical-demand/FPS-KA-BLR-001")
        assert res_hist.status_code == 200
        hist_data = res_hist.json()
        assert hist_data["fps_id"] == "FPS-KA-BLR-001"
        assert len(hist_data["records"]) == 12

        res_inv = await client.get("/inventory/FPS-KA-BLR-001")
        assert res_inv.status_code == 200
        inv_data = res_inv.json()
        assert inv_data["fps_id"] == "FPS-KA-BLR-001"
        assert inv_data["total_available_kg"] > 0

@pytest.mark.asyncio
async def test_dashboard_summary():
    """Verify executive dashboard summary metrics."""
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        response = await client.get("/dashboard/summary")
        assert response.status_code == 200
        data = response.json()
        assert data["total_fps"] == 20
        assert data["total_beneficiaries"] == 2000
        assert data["active_cycle"] == "2026-09"

@pytest.mark.asyncio
async def test_admin_dashboard_endpoint():
    """Verify District Admin dashboard metrics, 20 FPS matrix, and risk classifications."""
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        response = await client.get("/admin/dashboard")
        assert response.status_code == 200
        data = response.json()
        assert data["total_fps"] == 20
        assert data["active_intents_count"] > 0
        assert data["total_declared_intent_kg"] > 0
        assert len(data["fps_list"]) == 20
        assert len(data["historical_cycles_trend"]) == 6
        assert data["high_risk_fps_count"] >= 0
        assert "HIGH" in data["risk_distribution"]

@pytest.mark.asyncio
async def test_admin_fps_detail_endpoint():
    """Verify deep-dive FPS analytics endpoint."""
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        response = await client.get("/admin/fps/FPS-KA-BLR-001")
        assert response.status_code == 200
        data = response.json()
        assert data["fps_id"] == "FPS-KA-BLR-001"
        assert len(data["historical_records"]) == 12
        assert len(data["rice_trend_kg"]) == 6
        assert len(data["wheat_trend_kg"]) == 6
        assert len(data["inventory_items"]) == 2

@pytest.mark.asyncio
async def test_admin_workflow_actions():
    """Verify forecast generate and lock actions."""
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        # 1. Trigger generate
        res_gen = await client.post("/admin/forecast/generate")
        assert res_gen.status_code == 200
        assert res_gen.json()["workflow_status"] == "DRAFT_GENERATED"

        # 2. Trigger lock
        res_lock = await client.post("/admin/forecast/lock")
        assert res_lock.status_code == 200
        assert res_lock.json()["workflow_status"] == "FORECAST_LOCKED"

@pytest.mark.asyncio
async def test_forecast_generation_and_sqlite_persistence():
    """Verify POST /admin/forecast/generate calculates and persists 40 records in SQLite."""
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        # Generate forecast
        res = await client.post("/admin/forecast/generate")
        assert res.status_code == 200
        data = res.json()
        assert data["status"] == "success"
        assert data["workflow_status"] == "DRAFT_GENERATED"
        assert data["total_fps"] == 20
        assert data["generated_records_count"] == 40
        assert data["total_forecast_demand_kg"] > 0
        assert data["total_recommended_dispatch_kg"] > 0
        assert data["average_confidence"] > 0

        # Query SQLite database directly to confirm persistence
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("SELECT COUNT(*) FROM forecast WHERE cycle_id = '2026-09';")
        db_count = cursor.fetchone()[0]
        assert db_count == 40

        cursor.execute("SELECT fps_id, commodity, historical_component, intent_component, predicted_quantity_kg, recommended_dispatch_kg, status FROM forecast WHERE cycle_id = '2026-09' LIMIT 5;")
        sample_rows = cursor.fetchall()
        for r in sample_rows:
            assert r["predicted_quantity_kg"] > 0
            assert r["status"] == "DRAFT"
            assert r["commodity"] in ["Rice", "Wheat"]
        conn.close()

@pytest.mark.asyncio
async def test_forecast_formula_deterministic_calculation():
    """Verify D_hat = (1 - w*C)*H + (w*C)*I formula accuracy."""
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        await client.post("/admin/forecast/generate?force=true")

        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("""
        SELECT fps_id, commodity, historical_component, intent_component, confidence, predicted_quantity_kg
        FROM forecast
        WHERE cycle_id = '2026-09' AND fps_id = 'FPS-KA-BLR-001' AND commodity = 'Rice';
        """)
        row = cursor.fetchone()
        assert row is not None

        H = row["historical_component"]
        I = row["intent_component"]
        C = row["confidence"]
        actual_pred = row["predicted_quantity_kg"]

        w = 0.65
        alpha = w * C
        expected_pred = round(((1.0 - alpha) * H) + (alpha * I), 1)
        assert abs(actual_pred - expected_pred) < 0.2
        conn.close()

@pytest.mark.asyncio
async def test_forecast_locking_and_protection():
    """Verify forecast lock persists in DB and prevents accidental overwrite."""
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        # Generate then Lock
        await client.post("/admin/forecast/generate?force=true")
        res_lock = await client.post("/admin/forecast/lock")
        assert res_lock.status_code == 200
        assert res_lock.json()["workflow_status"] == "FORECAST_LOCKED"
        assert res_lock.json()["locked_records_count"] == 40

        # Verify SQLite has FORECAST_LOCKED status
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("SELECT COUNT(*) FROM forecast WHERE cycle_id = '2026-09' AND status = 'FORECAST_LOCKED';")
        locked_in_db = cursor.fetchone()[0]
        assert locked_in_db == 40
        conn.close()

        # Attempt to regenerate without force -> should return 400 Bad Request
        res_regen = await client.post("/admin/forecast/generate")
        assert res_regen.status_code == 400
        assert "cannot be regenerated" in res_regen.json()["detail"].lower() or \
               "forecast_locked" in res_regen.json()["detail"].lower()

        # Attempt to regenerate with force=true -> should succeed
        res_forced = await client.post("/admin/forecast/generate?force=true")
        assert res_forced.status_code == 200

@pytest.mark.asyncio
async def test_admin_dashboard_and_fps_detail_with_persisted_forecast():
    """Verify admin dashboard and FPS detail endpoints return populated forecast & dispatch data."""
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        await client.post("/admin/forecast/generate?force=true")
        await client.post("/admin/forecast/lock")

        # Dashboard summary
        res_dash = await client.get("/admin/dashboard")
        assert res_dash.status_code == 200
        dash_data = res_dash.json()
        assert dash_data["workflow_status"] == "FORECAST_LOCKED"
        assert dash_data["total_forecast_demand_kg"] > 0
        assert dash_data["total_recommended_dispatch_kg"] > 0
        assert dash_data["fps_list"][0]["recommended_dispatch_kg"] >= 0
        assert dash_data["fps_list"][0]["confidence_score"] > 0

        # FPS detail for FPS-001 (Stable)
        res_detail = await client.get("/admin/fps/FPS-KA-BLR-001")
        assert res_detail.status_code == 200
        detail_data = res_detail.json()
        assert detail_data["status"] == "Locked"
        assert detail_data["forecast_kg"] > 0
        assert detail_data["recommended_dispatch_kg"] >= 0
        assert "D_hat =" in detail_data["formula_explanation"]
        assert "Rice" in detail_data["forecast_breakdown"]
        assert "Wheat" in detail_data["forecast_breakdown"]

        # FPS detail for FPS-017 (Low Inventory stress node -> positive recommended dispatch required)
        res_detail_stress = await client.get("/admin/fps/FPS-KA-BLR-017")
        assert res_detail_stress.status_code == 200
        detail_stress = res_detail_stress.json()
        assert detail_stress["recommended_dispatch_kg"] > 0

@pytest.mark.asyncio
async def test_dispatch_generation_before_forecast_lock_rejected():
    """Verify dispatch cannot be generated before forecasts are generated and locked."""
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        # Case 1: Planning open (no forecast)
        res_open = await client.post("/admin/dispatch/generate")
        assert res_open.status_code == 400
        assert "no forecast records found" in res_open.json()["detail"].lower() or "must be locked" in res_open.json()["detail"].lower()

        # Case 2: Draft forecast generated but not locked
        await client.post("/admin/forecast/generate")
        res_draft = await client.post("/admin/dispatch/generate")
        assert res_draft.status_code == 400
        assert "must be locked" in res_draft.json()["detail"].lower()

@pytest.mark.asyncio
async def test_dispatch_generation_after_forecast_lock_and_manifest():
    """Verify dispatch generation succeeds once forecast is locked and returns structured manifest."""
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        await client.post("/admin/forecast/generate")
        await client.post("/admin/forecast/lock")

        res_gen = await client.post("/admin/dispatch/generate")
        assert res_gen.status_code == 200
        data = res_gen.json()
        assert data["status"] == "success"
        assert data["workflow_status"] == "DISPATCH_GENERATED"
        assert data["cycle_id"] == "2026-09"
        assert data["total_dispatch_kg"] > 0
        assert data["total_rice_dispatch_kg"] >= 0
        assert data["total_wheat_dispatch_kg"] >= 0
        assert data["total_vehicles_count"] == 4
        assert data["total_fps_count"] > 0
        assert len(data["vehicles"]) == 4
        assert len(data["records"]) > 0

        # Check vehicle corridor structure
        v0 = data["vehicles"][0]
        assert "truck_id" in v0
        assert "source_godown" in v0
        assert "route_name" in v0
        assert v0["total_payload_kg"] >= 0
        assert v0["total_payload_mt"] >= 0
        assert len(v0["delivery_stops"]) > 0

@pytest.mark.asyncio
async def test_dispatch_sqlite_persistence_and_matching_quantities():
    """Verify dispatch records are persisted in SQLite and match recommended dispatch."""
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        await client.post("/admin/forecast/generate")
        await client.post("/admin/forecast/lock")
        await client.post("/admin/dispatch/generate")

        # Query SQLite directly
        conn = get_db_connection()
        c = conn.cursor()
        c.execute("SELECT COUNT(*), COUNT(DISTINCT fps_id), COUNT(DISTINCT demo_truck_id) FROM dispatch WHERE cycle_id = '2026-09';")
        count_row = c.fetchone()
        assert count_row[0] > 0
        assert count_row[1] == 20
        assert count_row[2] == 4

        # Compare with recommended dispatch in forecast table
        c.execute("""
        SELECT d.fps_id, d.commodity, d.quantity_kg, f.recommended_dispatch_kg
        FROM dispatch d
        JOIN forecast f ON d.fps_id = f.fps_id AND d.cycle_id = f.cycle_id AND d.commodity = f.commodity
        WHERE d.cycle_id = '2026-09';
        """)
        rows = c.fetchall()
        assert len(rows) > 0
        for r in rows:
            # If recommended dispatch was > 0, quantity_kg matches recommended_dispatch_kg
            if r["recommended_dispatch_kg"] > 0:
                assert abs(r["quantity_kg"] - r["recommended_dispatch_kg"]) < 0.05
        conn.close()

@pytest.mark.asyncio
async def test_dispatch_api_endpoints_and_idempotency():
    """Verify GET dispatch endpoints, individual record retrieval, and idempotency."""
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        await client.post("/admin/forecast/generate")
        await client.post("/admin/forecast/lock")
        await client.post("/admin/dispatch/generate")

        # 1. GET /admin/dispatch
        res_disp = await client.get("/admin/dispatch")
        assert res_disp.status_code == 200
        disp_data = res_disp.json()
        assert disp_data["workflow_status"] == "DISPATCH_GENERATED"
        assert len(disp_data["records"]) > 0

        # 2. GET /admin/dispatch/cycle/2026-09
        res_cyc = await client.get("/admin/dispatch/cycle/2026-09")
        assert res_cyc.status_code == 200
        assert res_cyc.json()["cycle_id"] == "2026-09"

        # 3. GET /admin/dispatch/{id}
        first_id = disp_data["records"][0]["id"]
        res_single = await client.get(f"/admin/dispatch/{first_id}")
        assert res_single.status_code == 200
        assert res_single.json()["id"] == first_id
        assert "DEMO DATA" in res_single.json()["demo_notice"]

        # 4. Non-existent dispatch ID -> 404
        res_404 = await client.get("/admin/dispatch/999999")
        assert res_404.status_code == 404

        # 5. Repeated dispatch generation idempotency (no duplicate count explosions)
        conn = get_db_connection()
        initial_count = conn.execute("SELECT COUNT(*) FROM dispatch WHERE cycle_id = '2026-09';").fetchone()[0]
        conn.close()

        res_repeat = await client.post("/admin/dispatch/generate?force=true")
        assert res_repeat.status_code == 200

        conn = get_db_connection()
        repeat_count = conn.execute("SELECT COUNT(*) FROM dispatch WHERE cycle_id = '2026-09';").fetchone()[0]
        conn.close()
        assert repeat_count == initial_count

@pytest.mark.asyncio
async def test_dispatch_workflow_restart_persistence():
    """Verify dispatch workflow state (DISPATCH_GENERATED) survives client/server restarts."""
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client1:
        await client1.post("/admin/forecast/generate")
        await client1.post("/admin/forecast/lock")
        await client1.post("/admin/dispatch/generate")

    # Simulate fresh restart with client2
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client2:
        res_dash = await client2.get("/admin/dashboard")
        assert res_dash.status_code == 200
        assert res_dash.json()["workflow_status"] == "DISPATCH_GENERATED"

        res_manifest = await client2.get("/admin/dispatch/manifest")
        assert res_manifest.status_code == 200
        assert res_manifest.json()["workflow_status"] == "DISPATCH_GENERATED"
        assert res_manifest.json()["total_dispatch_kg"] > 0

@pytest.mark.asyncio
async def test_safe_demo_workflow_reset():
    """Verify safe demo reset returns workflow back to PLANNING_OPEN while preserving datasets."""
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        # 1. Drive workflow to DISPATCH_GENERATED
        await client.post("/admin/forecast/generate")
        await client.post("/admin/forecast/lock")
        await client.post("/admin/dispatch/generate")

        # Verify state is DISPATCH_GENERATED
        res_dash = await client.get("/admin/dashboard")
        assert res_dash.json()["workflow_status"] == "DISPATCH_GENERATED"

        # 2. Call safe demo reset
        res_reset = await client.post("/admin/demo/reset?cycle_id=2026-09")
        assert res_reset.status_code == 200
        reset_data = res_reset.json()
        assert reset_data["status"] == "success"
        assert reset_data["workflow_status"] == "PLANNING_OPEN"

        # 3. Check dashboard is back to PLANNING_OPEN
        res_dash_after = await client.get("/admin/dashboard")
        dash_after = res_dash_after.json()
        assert dash_after["workflow_status"] == "PLANNING_OPEN"
        assert dash_after["total_fps"] == 20

        # 4. Verify database benchmark data is fully preserved
        conn = get_db_connection()
        c = conn.cursor()
        c.execute("SELECT COUNT(*) FROM beneficiaries;")
        assert c.fetchone()[0] == 2000
        c.execute("SELECT COUNT(*) FROM historical_demand;")
        assert c.fetchone()[0] == 240
        c.execute("SELECT COUNT(*) FROM forecast WHERE cycle_id = '2026-09';")
        assert c.fetchone()[0] == 0
        c.execute("SELECT COUNT(*) FROM dispatch WHERE cycle_id = '2026-09';")
        assert c.fetchone()[0] == 0
        conn.close()

# ----------------- Phase 6: Distribution, Evaluation & Calibration Tests ----------------- #

@pytest.mark.asyncio
async def test_distribution_rejected_before_dispatch():
    """Verify distribution simulation is rejected if dispatch has not been generated."""
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        await client.post("/admin/demo/reset?cycle_id=2026-09")
        res = await client.post("/admin/distribution/simulate?cycle_id=2026-09")
        assert res.status_code == 400
        assert "Dispatch manifest must be GENERATED" in res.json()["detail"]

@pytest.mark.asyncio
async def test_distribution_simulation_and_persistence():
    """Verify distribution simulation generates and persists 40 records to SQLite."""
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        # Drive through forecast and dispatch first
        await client.post("/admin/forecast/generate")
        await client.post("/admin/forecast/lock")
        await client.post("/admin/dispatch/generate")

        # Simulate distribution
        res = await client.post("/admin/distribution/simulate?cycle_id=2026-09")
        assert res.status_code == 200
        data = res.json()
        assert data["status"] == "success"
        assert data["workflow_status"] == "ACTUAL_DISTRIBUTION_SIMULATED"
        assert data["simulated_records_count"] == 40
        assert data["total_fps_count"] == 20
        assert data["total_actual_quantity_kg"] > 0
        assert data["total_rice_actual_kg"] > 0
        assert data["total_wheat_actual_kg"] > 0

        # Verify SQLite persistence
        conn = get_db_connection()
        c = conn.cursor()
        c.execute("SELECT COUNT(*) FROM actual_distribution WHERE cycle_id = '2026-09';")
        assert c.fetchone()[0] == 40
        conn.close()

@pytest.mark.asyncio
async def test_distribution_idempotency_and_deterministic_values():
    """Verify distribution simulation is deterministic and idempotent on repeated calls."""
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        await client.post("/admin/forecast/generate")
        await client.post("/admin/forecast/lock")
        await client.post("/admin/dispatch/generate")
        res1 = await client.post("/admin/distribution/simulate?cycle_id=2026-09")
        assert res1.status_code == 200
        data1 = res1.json()

        # Repeat simulation call
        res2 = await client.post("/admin/distribution/simulate?cycle_id=2026-09")
        assert res2.status_code == 200
        data2 = res2.json()

        assert data1["total_actual_quantity_kg"] == data2["total_actual_quantity_kg"]
        assert len(data1["records"]) == len(data2["records"]) == 40

@pytest.mark.asyncio
async def test_evaluation_metrics_mathematical_correctness_and_persistence():
    """Verify forecast vs actual evaluation metrics (MAE, MAPE, Accuracy) and SQLite persistence."""
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        await client.post("/admin/forecast/generate")
        await client.post("/admin/forecast/lock")
        await client.post("/admin/dispatch/generate")
        await client.post("/admin/distribution/simulate?cycle_id=2026-09")

        res = await client.get("/admin/evaluation?cycle_id=2026-09")
        assert res.status_code == 200
        data = res.json()

        assert data["status"] == "success"
        assert data["workflow_status"] == "FORECAST_EVALUATED"
        assert data["records_evaluated_count"] == 40
        assert data["mae_kg"] > 0
        assert 0.0 <= data["mape_pct"] <= 20.0
        assert 80.0 <= data["overall_accuracy_pct"] <= 100.0

        # Mathematical verification: overall_accuracy == 100 - mape
        expected_accuracy = round(100.0 - data["mape_pct"], 2)
        assert abs(data["overall_accuracy_pct"] - expected_accuracy) < 0.05

        # Verify SQLite forecast_evaluation persistence
        conn = get_db_connection()
        c = conn.cursor()
        c.execute("SELECT COUNT(*) FROM forecast_evaluation WHERE cycle_id = '2026-09';")
        assert c.fetchone()[0] == 40
        conn.close()

@pytest.mark.asyncio
async def test_sklearn_model_calibration_and_future_cycle_parameters():
    """Verify closed-loop ML calibration using scikit-learn Ridge regression creates future-cycle model."""
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        await client.post("/admin/forecast/generate")
        await client.post("/admin/forecast/lock")
        await client.post("/admin/dispatch/generate")
        await client.post("/admin/distribution/simulate?cycle_id=2026-09")
        await client.get("/admin/evaluation?cycle_id=2026-09")

        res = await client.post("/admin/calibrate?cycle_id=2026-09")
        assert res.status_code == 200
        data = res.json()

        assert data["status"] == "success"
        assert data["workflow_status"] == "MODEL_CALIBRATED"
        assert data["target_future_cycle"] == "2026-10"
        assert data["model_version"] == "v1.1-calibrated"
        assert "Ridge" in data["algorithm"]
        assert data["previous_weight"] == 0.65
        assert 0.20 <= data["calibrated_weight"] <= 0.90
        assert data["records_trained"] == 40
        assert len(data["training_features"]) >= 3

        # Verify SQLite model_calibration persistence
        conn = get_db_connection()
        c = conn.cursor()
        c.execute("SELECT COUNT(*) FROM model_calibration WHERE cycle_id = '2026-09';")
        assert c.fetchone()[0] == 1
        conn.close()

@pytest.mark.asyncio
async def test_phase6_workflow_restart_persistence():
    """Verify Phase 6 workflow state (MODEL_CALIBRATED) survives client/server restarts."""
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client1:
        await client1.post("/admin/forecast/generate")
        await client1.post("/admin/forecast/lock")
        await client1.post("/admin/dispatch/generate")
        await client1.post("/admin/distribution/simulate?cycle_id=2026-09")
        await client1.get("/admin/evaluation?cycle_id=2026-09")
        await client1.post("/admin/calibrate?cycle_id=2026-09")

    # Simulate fresh client/restart
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client2:
        res = await client2.get("/admin/dashboard")
        assert res.status_code == 200
        assert res.json()["workflow_status"] == "MODEL_CALIBRATED"

@pytest.mark.asyncio
async def test_safe_demo_reset_clears_all_phase6_data():
    """Verify demo reset completely cleans Phase 6 tables back to PLANNING_OPEN."""
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        res = await client.post("/admin/demo/reset?cycle_id=2026-09")
        assert res.status_code == 200
        assert res.json()["workflow_status"] == "PLANNING_OPEN"

        # Check DB counts
        conn = get_db_connection()
        c = conn.cursor()
        c.execute("SELECT COUNT(*) FROM model_calibration WHERE cycle_id = '2026-09';")
        assert c.fetchone()[0] == 0
        c.execute("SELECT COUNT(*) FROM forecast_evaluation WHERE cycle_id = '2026-09';")
        assert c.fetchone()[0] == 0
        c.execute("SELECT COUNT(*) FROM actual_distribution WHERE cycle_id = '2026-09';")
        assert c.fetchone()[0] == 0
        c.execute("SELECT COUNT(*) FROM dispatch WHERE cycle_id = '2026-09';")
        assert c.fetchone()[0] == 0
        c.execute("SELECT COUNT(*) FROM forecast WHERE cycle_id = '2026-09';")
        assert c.fetchone()[0] == 0
        # Benchmark data intact
        c.execute("SELECT COUNT(*) FROM beneficiaries;")
        assert c.fetchone()[0] == 2000
        c.execute("SELECT COUNT(*) FROM fps;")
        assert c.fetchone()[0] == 20
        conn.close()

def test_database_recreation_from_scratch():
    """Verify database can be completely dropped, recreated, and re-seeded from scratch."""
    recreate_db()
    result = seed_all_data(recreate=False)
    assert result["status"] == "success"
    assert result["fps_count"] == 20
    assert result["beneficiaries_count"] == 2000


# ──────────────────────────────────────────────────────────────────────────────
# REGRESSION TESTS: Forecast Lock Guard — All Post-Lock States (Issue #H2)
# Verifies that POST /admin/forecast/generate is rejected for every state
# at or beyond FORECAST_LOCKED.  Ordinary generation must only succeed from
# PLANNING_OPEN and DRAFT_GENERATED.
# ──────────────────────────────────────────────────────────────────────────────

@pytest.mark.asyncio
async def test_forecast_generate_blocked_after_dispatch():
    """Forecast generation must be rejected once DISPATCH_GENERATED."""
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        await client.post("/admin/forecast/generate")
        await client.post("/admin/forecast/lock")
        await client.post("/admin/dispatch/generate")

        # Dashboard must confirm DISPATCH_GENERATED
        dash = await client.get("/admin/dashboard")
        assert dash.json()["workflow_status"] == "DISPATCH_GENERATED"

        # Ordinary generate must be rejected
        res = await client.post("/admin/forecast/generate")
        assert res.status_code == 400, (
            f"Expected HTTP 400 in DISPATCH_GENERATED state, got {res.status_code}: {res.text}"
        )
        assert "cannot be regenerated" in res.json()["detail"].lower() or \
               "locked" in res.json()["detail"].lower()

        # Forecast rows must still be FORECAST_LOCKED
        from app.core.database import get_db_connection
        conn = get_db_connection()
        c = conn.cursor()
        c.execute(
            "SELECT DISTINCT status FROM forecast WHERE cycle_id = '2026-09';"
        )
        statuses = {r[0] for r in c.fetchall()}
        conn.close()
        assert statuses == {"FORECAST_LOCKED"}, \
            f"Expected only FORECAST_LOCKED rows but found: {statuses}"


@pytest.mark.asyncio
async def test_forecast_generate_blocked_after_distribution():
    """Forecast generation must be rejected once ACTUAL_DISTRIBUTION_SIMULATED."""
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        await client.post("/admin/forecast/generate")
        await client.post("/admin/forecast/lock")
        await client.post("/admin/dispatch/generate")
        await client.post("/admin/distribution/simulate?cycle_id=2026-09")

        dash = await client.get("/admin/dashboard")
        assert dash.json()["workflow_status"] == "ACTUAL_DISTRIBUTION_SIMULATED"

        res = await client.post("/admin/forecast/generate")
        assert res.status_code == 400, (
            f"Expected HTTP 400 in ACTUAL_DISTRIBUTION_SIMULATED state, got {res.status_code}"
        )

        from app.core.database import get_db_connection
        conn = get_db_connection()
        c = conn.cursor()
        c.execute("SELECT DISTINCT status FROM forecast WHERE cycle_id = '2026-09';")
        statuses = {r[0] for r in c.fetchall()}
        conn.close()
        assert statuses == {"FORECAST_LOCKED"}, \
            f"Forecast rows mutated — expected FORECAST_LOCKED but found: {statuses}"


@pytest.mark.asyncio
async def test_forecast_generate_blocked_after_evaluation():
    """Forecast generation must be rejected once FORECAST_EVALUATED."""
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        await client.post("/admin/forecast/generate")
        await client.post("/admin/forecast/lock")
        await client.post("/admin/dispatch/generate")
        await client.post("/admin/distribution/simulate?cycle_id=2026-09")
        await client.get("/admin/evaluation?cycle_id=2026-09")

        dash = await client.get("/admin/dashboard")
        assert dash.json()["workflow_status"] == "FORECAST_EVALUATED"

        res = await client.post("/admin/forecast/generate")
        assert res.status_code == 400, (
            f"Expected HTTP 400 in FORECAST_EVALUATED state, got {res.status_code}"
        )

        from app.core.database import get_db_connection
        conn = get_db_connection()
        c = conn.cursor()
        c.execute("SELECT DISTINCT status FROM forecast WHERE cycle_id = '2026-09';")
        statuses = {r[0] for r in c.fetchall()}
        conn.close()
        assert statuses == {"FORECAST_LOCKED"}, \
            f"Forecast rows mutated — expected FORECAST_LOCKED but found: {statuses}"


@pytest.mark.asyncio
async def test_forecast_generate_blocked_after_calibration():
    """
    Forecast generation must be rejected once MODEL_CALIBRATED.
    This is the primary regression test for the post-calibration lock guard bug.
    Forecast rows must remain FORECAST_LOCKED — calibration must NOT touch them.
    """
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        # Run full workflow to MODEL_CALIBRATED
        await client.post("/admin/forecast/generate")
        await client.post("/admin/forecast/lock")
        await client.post("/admin/dispatch/generate")
        await client.post("/admin/distribution/simulate?cycle_id=2026-09")
        await client.get("/admin/evaluation?cycle_id=2026-09")
        await client.post("/admin/calibrate?cycle_id=2026-09")

        # Confirm final state
        dash = await client.get("/admin/dashboard")
        assert dash.json()["workflow_status"] == "MODEL_CALIBRATED"

        # Ordinary generate must be blocked
        res = await client.post("/admin/forecast/generate")
        assert res.status_code == 400, (
            f"CRITICAL: POST /admin/forecast/generate returned {res.status_code} "
            f"in MODEL_CALIBRATED state — lock guard bypass confirmed. "
            f"Response: {res.text}"
        )
        assert "cannot be regenerated" in res.json()["detail"].lower() or \
               "locked" in res.json()["detail"].lower() or \
               "model_calibrated" in res.json()["detail"].lower()

        # Forecast rows must remain FORECAST_LOCKED (calibration must not touch them)
        from app.core.database import get_db_connection
        conn = get_db_connection()
        c = conn.cursor()
        c.execute("SELECT DISTINCT status FROM forecast WHERE cycle_id = '2026-09';")
        statuses = {r[0] for r in c.fetchall()}
        c.execute("SELECT COUNT(*) FROM model_calibration WHERE cycle_id = '2026-09';")
        cal_count = c.fetchone()[0]
        conn.close()

        assert statuses == {"FORECAST_LOCKED"}, (
            f"Forecast rows mutated by calibration — expected only FORECAST_LOCKED "
            f"but found: {statuses}"
        )
        assert cal_count == 1, \
            f"Expected 1 calibration record, found {cal_count}"


# ──────────────────────────────────────────────────────────────────────────────
# PRE-DISPATCH DECISION INTELLIGENCE: 9-MODULE TESTS
# ──────────────────────────────────────────────────────────────────────────────

@pytest.mark.asyncio
async def test_constraint_validation_rules_and_audit():
    """Verify 6 operational constraints (Storage, Payload, Depot, Safety Buffer, Quota, Availability)."""
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        # Generate & Lock Forecast first
        await client.post("/admin/forecast/generate")
        await client.post("/admin/forecast/lock")
        await client.post("/admin/dispatch/generate")

        # 1. District-Wide Constraint Audit
        res_audit = await client.get("/admin/constraints/validate?cycle_id=2026-09")
        assert res_audit.status_code == 200
        audit_data = res_audit.json()
        assert audit_data["status"] == "success"
        assert audit_data["total_fps_audited"] == 20
        assert audit_data["pass_count"] >= 10
        assert len(audit_data["fps_evaluations"]) == 20

        # 2. Single FPS Constraint Check (Hero FPS-017 / FPS-001)
        res_single = await client.get("/admin/constraints/fps/FPS-KA-BLR-001?cycle_id=2026-09")
        assert res_single.status_code == 200
        single_data = res_single.json()
        assert single_data["fps_id"] == "FPS-KA-BLR-001"
        assert len(single_data["checks"]) == 9


@pytest.mark.asyncio
async def test_dispatch_route_and_cost_optimization():
    """Verify corridor TSP route sequencing, fuel cost calculation, and optimization score."""
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        await client.post("/admin/forecast/generate")
        await client.post("/admin/forecast/lock")
        await client.post("/admin/dispatch/generate")

        # 1. District-Wide Optimization
        res = await client.get("/admin/optimization/run?cycle_id=2026-09")
        assert res.status_code == 200
        data = res.json()
        assert data["status"] == "success"
        assert data["total_vehicles_optimized"] == 4
        assert data["total_district_distance_km"] > 50.0
        assert data["total_transport_cost_inr"] > 2000.0
        assert data["average_optimization_score"] >= 50.0

        # 2. Single Corridor Optimization (North-West Heavy Corridor)
        res_corridor = await client.get("/admin/optimization/corridor/DEMO-KA-04-E-1021?cycle_id=2026-09")
        assert res_corridor.status_code == 200
        corr_data = res_corridor.json()
        assert corr_data["truck_id"] == "DEMO-KA-04-E-1021"
        assert corr_data["corridor"] == "NORTH_WEST"
        assert len(corr_data["optimized_stops"]) == 5
        assert corr_data["optimization_score"] > 0.0
        assert corr_data["estimated_transport_cost_inr"] > 0.0


@pytest.mark.asyncio
async def test_digital_gatepass_lifecycle():
    """Verify digital gatepass generation, weighbridge slips, and 5-stage progression."""
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        await client.post("/admin/forecast/generate")
        await client.post("/admin/forecast/lock")
        await client.post("/admin/dispatch/generate")

        # 1. Generate all gatepasses
        res_all = await client.get("/admin/gatepasses?cycle_id=2026-09")
        assert res_all.status_code == 200
        assert len(res_all.json()["gatepasses"]) == 4

        # 2. Retrieve single gatepass
        truck_id = "DEMO-KA-04-E-1021"
        res_gp = await client.get(f"/admin/gatepass/{truck_id}?cycle_id=2026-09")
        assert res_gp.status_code == 200
        gp_data = res_gp.json()
        gatepass_id = gp_data["gatepass_id"]
        assert gatepass_id.startswith("GP-2026-09-")
        assert gp_data["security_token"].startswith("GP-SEC-")
        assert "weighbridge_slip" in gp_data
        assert gp_data["weighbridge_slip"]["tare_weight_kg"] > 0
        assert len(gp_data["event_timeline"]) == 5

        # 3. Advance gatepass stage
        res_adv = await client.post(f"/admin/gatepass/{gatepass_id}/advance?target_status=WAREHOUSE_VERIFIED")
        assert res_adv.status_code == 200
        assert res_adv.json()["status"] == "WAREHOUSE_VERIFIED"

        res_adv2 = await client.post(f"/admin/gatepass/{gatepass_id}/advance?target_status=DISPATCH_CONFIRMED")
        assert res_adv2.status_code == 200
        assert res_adv2.json()["status"] == "DISPATCH_CONFIRMED"


@pytest.mark.asyncio
async def test_pre_dispatch_alert_notifications():
    """Verify multi-channel WhatsApp, SMS, and IVR simulated broadcasts and logs."""
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        await client.post("/admin/forecast/generate")
        await client.post("/admin/forecast/lock")
        await client.post("/admin/dispatch/generate")

        # 1. Trigger notification broadcast
        res_notif = await client.post("/admin/notifications/dispatch?cycle_id=2026-09")
        assert res_notif.status_code == 200
        data = res_notif.json()
        assert data["status"] == "success"
        assert data["dealer_notifications_count"] == 20
        assert data["citizen_notifications_count"] > 0
        assert "WHATSAPP" in data["channels_utilized"]

        # 2. Query notification logs
        res_logs = await client.get("/admin/notifications/logs?cycle_id=2026-09")
        assert res_logs.status_code == 200
        logs_data = res_logs.json()
        assert logs_data["total_logs_count"] > 0
        assert logs_data["logs"][0]["status"] in ["DELIVERED", "FALLBACK_TRIGGERED", "ACKNOWLEDGED"]


# -----------------------------------------------------------------------------
# PHASE 1: FOUNDATION AND COMMAND DASHBOARD TESTS
# -----------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_phase1_command_center_overview():
    """Verify Command Center overview endpoint returns 6 KPI cards, 7 sections, and filters."""
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        res = await client.get("/admin/command-center?cycle_id=2026-09")
        assert res.status_code == 200
        data = res.json()

        assert data["status"] == "success"
        assert data["cycle_id"] == "2026-09"
        assert "kpis" in data
        kpis = data["kpis"]
        assert kpis["fps_monitored"] == 20
        assert kpis["forecast_cycles"] == 7
        assert "dispatches_today" in kpis
        assert "constraint_violations" in kpis
        assert "locked_manifests" in kpis

        # Verify sections
        sections = data["sections"]
        assert "forecast_overview" in sections
        assert "dispatch_recommendations" in sections
        assert "constraint_status" in sections
        assert "vehicle_availability" in sections
        assert "pending_manifest_actions" in sections
        assert "recent_notifications" in sections
        assert "feedback_accuracy" in sections

        # Verify filters
        filters = data["filters"]
        assert "Karnataka" in filters["states"]
        assert any("Bengaluru Urban" in d for d in filters["districts"])
        assert len(filters["depots"]) == 2
        assert len(filters["fps_list"]) == 20
        assert len(data["fps_summary_list"]) == 20


@pytest.mark.asyncio
async def test_phase1_fps_pre_dispatch_analytics():
    """Verify FPS detailed pre-dispatch analytics (inventory, 6-cycle history, trend, portability, risk, route)."""
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        res = await client.get("/admin/fps/FPS-KA-BLR-001/analytics?cycle_id=2026-09")
        assert res.status_code == 200
        data = res.json()

        assert data["fps_id"] == "FPS-KA-BLR-001"
        assert "Malleshwaram" in data["fps_name"] or "Sri Lakshmi" in data["fps_name"]
        assert "Bengaluru Urban" in data["district"]
        assert "beneficiaries" in data
        assert data["beneficiaries"]["count"] > 0
        assert "inventory" in data
        assert data["inventory"]["storage_capacity_kg"] > 0
        assert len(data["historical_offtake"]) == 6
        assert "analytics" in data
        assert "portability_rate" in data["analytics"]
        assert "stockout_frequency" in data["analytics"]
        assert "seasonal_factor" in data["analytics"]
        assert "pre_dispatch_recommendation" in data
        assert "supply_chain_logistics" in data
        assert data["supply_chain_logistics"]["assigned_depot"] in ["Bengaluru Central FCI Godown (Hebbal)", "Banaswadi PDS Buffer Depot"]


@pytest.mark.asyncio
async def test_phase1_supply_routes():
    """Verify supply corridor routes dataset connecting depots to FPS."""
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        res = await client.get("/admin/routes")
        assert res.status_code == 200
        data = res.json()

        assert data["status"] == "success"
        assert data["total_routes_count"] >= 20
        route = data["routes"][0]
        assert "route_id" in route
        assert "source_depot_id" in route
        assert "destination_fps_id" in route
        assert route["distance_km"] > 0
        assert route["estimated_time_mins"] > 0


@pytest.mark.asyncio
async def test_phase1_pre_dispatch_analysis_run():
    """Verify Run Pre-Dispatch Analysis pipeline executes all 6 stages."""
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        # 1. District-wide analysis run
        res = await client.post("/admin/analysis/run?cycle_id=2026-09")
        assert res.status_code == 200
        data = res.json()
        assert data["status"] == "success"
        assert data["analysis_mode"] == "DISTRICT_WIDE"
        assert len(data["pipeline_stages"]) == 6
        stage_names = [s["stage"] for s in data["pipeline_stages"]]
        assert "1. FORECAST" in stage_names
        assert "2. DECISION" in stage_names
        assert "3. VALIDATION" in stage_names
        assert "4. OPTIMIZATION" in stage_names
        assert "5. MANIFEST" in stage_names
        assert "6. NOTIFICATION" in stage_names

        # 2. Single FPS specific analysis run
        res_fps = await client.post("/admin/analysis/run?cycle_id=2026-09&fps_id=FPS-KA-BLR-001")
        assert res_fps.status_code == 200
        data_fps = res_fps.json()
        assert data_fps["status"] == "success"
        assert data_fps["fps_id"] == "FPS-KA-BLR-001"
        assert "dossier" in data_fps


# -----------------------------------------------------------------------------
# PHASE 2 TESTS: EXPLAINABLE DEMAND FORECASTING & WHAT-IF ENGINE
# -----------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_phase2_explainable_fps_forecast():
    """Verify explainable multi-factor forecast with feature decomposition and intervals."""
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        res = await client.get("/admin/fps/FPS-KA-BLR-001/forecast?cycle_id=2026-09")
        assert res.status_code == 200
        data = res.json()

        assert data["status"] == "success"
        assert data["fps_id"] == "FPS-KA-BLR-001"
        assert data["cycle_id"] == "2026-09"

        # Check summary metrics
        summary = data["summary"]
        assert summary["predicted_demand_kg"] > 0.0
        assert 0.70 <= summary["confidence_score"] <= 1.0
        assert summary["lower_estimate_kg"] <= summary["predicted_demand_kg"] <= summary["upper_estimate_kg"]
        assert summary["margin_of_error_kg"] > 0.0

        # Check commodity breakdown (Rice + Wheat)
        comm_breakdown = data["commodity_breakdown"]
        assert len(comm_breakdown) == 2
        commodities = [c["commodity"] for c in comm_breakdown]
        assert "Rice" in commodities
        assert "Wheat" in commodities
        for c in comm_breakdown:
            assert c["historical_weighted_avg_kg"] > 0
            assert c["predicted_demand_kg"] > 0

        # Check feature contributions
        features = data["feature_contributions"]
        assert len(features) >= 5
        feat_names = [f["feature"] for f in features]
        assert "Historical Offtake Baseline" in feat_names
        assert "Recent Consumption Trend" in feat_names
        assert "Seasonal Multiplier" in feat_names
        assert "Portability & Intent Shift" in feat_names
        assert "Stockout Distortion Correction" in feat_names

        # Check 6-cycle historical trend
        assert len(data["historical_trend"]) == 6


@pytest.mark.asyncio
async def test_phase2_what_if_simulation():
    """Verify real-time What-If scenario forecasting with modified operational parameters."""
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        # Simulate with +50% beneficiaries and 1.25x seasonal factor
        payload = {
            "beneficiaries_count": 150,
            "seasonal_factor": 1.25,
            "portability_rate": 0.25,
            "stockout_frequency": 0.10
        }
        res = await client.post("/admin/fps/FPS-KA-BLR-001/forecast/what-if?cycle_id=2026-09", json=payload)
        assert res.status_code == 200
        data = res.json()

        assert data["status"] == "success"
        assert data["fps_id"] == "FPS-KA-BLR-001"
        assert "baseline" in data
        assert "simulation" in data
        assert "comparison" in data

        comparison = data["comparison"]
        assert comparison["simulated_demand_kg"] > comparison["baseline_demand_kg"]
        assert comparison["delta_kg"] > 0
        assert comparison["delta_pct"] > 0

        # Check simulation parameters were applied
        sim = data["simulation"]
        assert sim["parameters"]["beneficiaries_count"] == 150
        assert sim["parameters"]["seasonal_factor"] == 1.25


@pytest.mark.asyncio
async def test_phase2_district_forecast_summary():
    """Verify aggregated district demand forecast summary across all 20 Fair Price Shops."""
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        res = await client.get("/admin/forecast/district-summary?cycle_id=2026-09")
        assert res.status_code == 200
        data = res.json()

        assert data["status"] == "success"
        assert data["total_fps_count"] == 20
        assert data["total_district_predicted_kg"] > 0
        assert data["total_rice_predicted_kg"] > 0
        assert data["total_wheat_predicted_kg"] > 0
        assert data["average_district_confidence"] >= 0.70
        assert len(data["fps_forecasts"]) == 20


# -----------------------------------------------------------------------------
# PHASE 3 TESTS: DISPATCH DECISION ENGINE & SCENARIO EVALUATION
# -----------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_phase3_fps_dispatch_decision_calculation():
    """Verify dispatch decision core formula: Demand - Stock + SafetyBuffer."""
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        res = await client.get("/admin/fps/FPS-KA-BLR-001/dispatch-decision?scenario=NORMAL&cycle_id=2026-09")
        assert res.status_code == 200
        data = res.json()

        assert data["status"] == "success"
        assert data["fps_id"] == "FPS-KA-BLR-001"
        assert "core_metrics" in data
        m = data["core_metrics"]
        assert m["predicted_demand_kg"] > 0
        assert m["current_stock_kg"] >= 0
        assert m["safety_buffer_kg"] > 0
        assert m["recommended_dispatch_kg"] >= 0
        assert m["storage_capacity_kg"] == 20000.0
        assert m["remaining_capacity_kg"] >= 0

        # Check explicit formula string
        assert "formula" in data
        assert "-" in data["formula"]["values"]
        assert "+" in data["formula"]["values"]
        assert "=" in data["formula"]["values"]

        # Check 'Why this quantity?' narrative
        assert "decision_explanation" in data
        assert len(data["decision_explanation"]["narrative"]) > 20
        assert len(data["decision_explanation"]["key_drivers"]) >= 3


@pytest.mark.asyncio
async def test_phase3_dispatch_decision_scenarios():
    """Verify all 3 scenarios: Normal, High Demand, and Low Stock / Critical Risk."""
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        # 1. Normal scenario
        res_normal = await client.get("/admin/fps/FPS-KA-BLR-001/dispatch-decision?scenario=NORMAL&cycle_id=2026-09")
        assert res_normal.status_code == 200
        d_normal = res_normal.json()

        # 2. High Demand scenario (+20% demand)
        res_high = await client.get("/admin/fps/FPS-KA-BLR-001/dispatch-decision?scenario=HIGH_DEMAND&cycle_id=2026-09")
        assert res_high.status_code == 200
        d_high = res_high.json()
        assert d_high["core_metrics"]["predicted_demand_kg"] > d_normal["core_metrics"]["predicted_demand_kg"]

        # 3. Low Stock / Critical Risk scenario (elevated safety buffer)
        res_low = await client.get("/admin/fps/FPS-KA-BLR-001/dispatch-decision?scenario=LOW_STOCK_HIGH_RISK&cycle_id=2026-09")
        assert res_low.status_code == 200
        d_low = res_low.json()
        assert d_low["core_metrics"]["safety_buffer_kg"] >= d_normal["core_metrics"]["safety_buffer_kg"]
        assert len(d_normal["all_scenarios"]) == 3


@pytest.mark.asyncio
async def test_phase3_dispatch_decision_save_and_district_summary():
    """Verify saving dispatch recommendation and district-wide summary."""
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        # 1. Save dispatch recommendation
        save_res = await client.post("/admin/fps/FPS-KA-BLR-001/dispatch-decision/save?cycle_id=2026-09", json={"scenario": "NORMAL"})
        assert save_res.status_code == 200
        assert save_res.json()["status"] == "success"

        # 2. District summary
        sum_res = await client.get("/admin/dispatch-decisions/district-summary?cycle_id=2026-09")
        assert sum_res.status_code == 200
        sum_data = sum_res.json()
        assert sum_data["total_fps_count"] == 20
        assert sum_data["total_district_recommended_dispatch_kg"] > 0
        assert len(sum_data["fps_decisions"]) == 20


# -----------------------------------------------------------------------------
# PHASE 4 TESTS: 9-RULE CONSTRAINT ENGINE & FAILURE RESOLUTION
# -----------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_phase4_nine_logistics_constraints_audit():
    """Verify all 9 logistics constraints (Storage, Truck, Depot, Quota, Safety, Fleet, Route, Window, Tender)."""
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        res = await client.get("/admin/fps/FPS-KA-BLR-001/constraints?scenario=NORMAL&cycle_id=2026-09")
        assert res.status_code == 200
        data = res.json()

        assert data["status"] == "success"
        assert data["fps_id"] == "FPS-KA-BLR-001"
        assert data["overall_status"] == "PASS"
        assert data["can_lock_manifest"] is True
        assert data["total_rules_checked"] == 9
        assert len(data["checks"]) == 9

        rule_ids = [c["rule_id"] for c in data["checks"]]
        assert "FPS_STORAGE_CAPACITY" in rule_ids
        assert "TRUCK_CAPACITY" in rule_ids
        assert "DEPOT_STOCK_AVAILABILITY" in rule_ids
        assert "ALLOCATION_LIMIT" in rule_ids
        assert "MIN_SAFETY_STOCK" in rule_ids
        assert "VEHICLE_AVAILABILITY" in rule_ids
        assert "ROUTE_RESTRICTIONS" in rule_ids
        assert "DELIVERY_WINDOW" in rule_ids
        assert "GOVERNMENT_TENDER_COMPLIANCE" in rule_ids

        # Every rule check must have actual_value, required_value, explanation, severity
        for c in data["checks"]:
            assert "actual_value" in c
            assert "required_value" in c
            assert "explanation" in c
            assert c["severity"] in ["CRITICAL", "MAJOR", "INFO"]


@pytest.mark.asyncio
async def test_phase4_constraint_failure_scenario_and_blocking_guard():
    """Verify failure scenario visibly shows violation and blocks manifest lock."""
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        # Trigger failure simulation on FPS-KA-BLR-001
        res_fail = await client.post(
            "/admin/fps/FPS-KA-BLR-001/constraints/resolve?cycle_id=2026-09",
            json={"action": "TRIGGER_FAILURE_SIMULATION"}
        )
        assert res_fail.status_code == 200
        data_fail = res_fail.json()
        assert data_fail["status"] == "success"

        reval = data_fail["revalidation"]
        assert reval["overall_status"] == "FAIL"
        assert reval["can_lock_manifest"] is False
        assert reval["fail_count"] >= 1
        assert "blocking_reason" in reval
        assert "Constraint not satisfied" in reval["summary_message"]

        # Verify Truck Capacity failed specifically
        truck_check = next(c for c in reval["checks"] if c["rule_id"] == "TRUCK_CAPACITY")
        assert truck_check["status"] == "FAIL"
        assert "exceeds" in truck_check["explanation"]
        assert len(truck_check["resolution_actions"]) >= 2

        # Verify manifest locking is BLOCKED during failure
        lock_res = await client.post("/admin/forecast/lock?cycle_id=2026-09")
        assert lock_res.status_code == 400
        assert "Manifest lock blocked" in lock_res.json()["detail"] or "Blocked" in lock_res.json()["detail"]


@pytest.mark.asyncio
async def test_phase4_constraint_resolution_and_revalidation():
    """Verify resolving constraint restores PASS status and permits workflow progression."""
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        # Resolve constraint by upgrading to 10 MT heavy carrier
        resolve_res = await client.post(
            "/admin/fps/FPS-KA-BLR-001/constraints/resolve?cycle_id=2026-09",
            json={"action": "SELECT_ALTERNATE_TRUCK"}
        )
        assert resolve_res.status_code == 200
        data_res = resolve_res.json()
        assert data_res["status"] == "success"
        assert data_res["revalidation"]["overall_status"] == "PASS"
        assert data_res["revalidation"]["can_lock_manifest"] is True

        # Revalidate district-wide
        reval_res = await client.post("/admin/constraints/revalidate?cycle_id=2026-09")
        assert reval_res.status_code == 200
        reval_data = reval_res.json()
        assert reval_data["district_validation_status"] in ["PASS", "WARNING"]
        assert reval_data["can_lock_manifest"] is True


@pytest.mark.asyncio
async def test_phase5_multi_candidate_dispatch_optimization():
    """Verify district-wide multi-candidate dispatch optimization and penalty score calculation."""
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        res = await client.get("/admin/optimization/run?cycle_id=2026-09")
        assert res.status_code == 200
        data = res.json()
        assert data["status"] == "success"
        assert data["total_vehicles_optimized"] >= 4
        assert data["total_stops_sequenced"] >= 5
        assert data["total_district_distance_km"] > 0
        assert data["total_transport_cost_inr"] > 0
        assert 0.0 <= data["average_optimization_score"] <= 100.0
        assert len(data["corridor_optimizations"]) >= 4

        # Check first corridor
        corr = data["corridor_optimizations"][0]
        assert "selected_candidate_id" in corr
        assert "why_selected_reason" in corr
        assert len(corr["evaluated_candidates"]) == 3
        assert len(corr["delivery_sequence"]) >= 1


@pytest.mark.asyncio
async def test_phase5_corridor_candidate_scoring_and_selection():
    """Verify candidate scoring respects cost, stockout, excess, and delay penalty formulas."""
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        res = await client.get("/admin/optimization/corridor/DEMO-KA-04-E-1021?cycle_id=2026-09")
        assert res.status_code == 200
        data = res.json()
        assert data["status"] == "success"
        assert len(data["evaluated_candidates"]) == 3

        selected_cand = next(c for c in data["evaluated_candidates"] if c["is_selected"])
        assert selected_cand["candidate_id"] == data["selected_candidate_id"]

        # Verify score breakdown fields
        breakdown = selected_cand["scoreBreakdown"] if "scoreBreakdown" in selected_cand else selected_cand["score_breakdown"]
        assert breakdown["transport_cost_score"] >= 0
        assert breakdown["stockout_risk_penalty"] >= 0
        assert breakdown["delay_penalty"] >= 0
        assert breakdown["composite_penalty_score"] > 0

        # Winner should have minimal composite penalty score among compliant candidates
        for c in data["evaluated_candidates"]:
            if c["is_capacity_compliant"]:
                assert selected_cand["composite_penalty_score"] <= c["composite_penalty_score"]


@pytest.mark.asyncio
async def test_phase5_optimization_what_if_recalculation():
    """Verify interactive what-if parameters update routes, costs, and optimization scores."""
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        # Tweak fuel cost and route condition
        res = await client.post(
            "/admin/optimization/what-if?cycle_id=2026-09",
            json={
                "truck_id": "DEMO-KA-04-E-1021",
                "vehicle_capacity_kg": 12000.0,
                "fuel_cost_per_km": 55.0,
                "route_condition": "CONGESTED_PEAK_CORRIDOR",
                "departure_window": "07:30 AM"
            }
        )
        assert res.status_code == 200
        data = res.json()
        assert data["status"] == "success"
        assert data["fuel_cost_per_km"] == 55.0
        assert "Congested" in data["route_condition"]
        assert len(data["evaluated_candidates"]) == 3


# ----------------- Phase 6: Auditable Manifest Generation & Lock Tests ----------------- #

@pytest.mark.asyncio
async def test_phase6_manifest_generation_and_initial_audit_trail():
    """Verify manifest generation in DRAFT status with initial CREATED, VALIDATED, and OPTIMIZED audit entries."""
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        res = await client.post("/admin/manifests/generate?truck_id=DEMO-KA-04-E-1021&cycle_id=2026-09")
        assert res.status_code == 200
        data = res.json()
        assert data["status"] == "success"
        assert data["approval_status"] == "DRAFT"
        assert data["is_locked"] is False
        assert data["version"] == "v1.0"
        assert data["truck_id"] == "DEMO-KA-04-E-1021"
        assert data["total_quantity_kg"] > 0
        assert len(data["commodities"]) == 2
        assert len(data["delivery_sequence"]) >= 1
        assert len(data["audit_trail"]) >= 3

        # Check initial audit trail sequence
        actions = [a["action"] for a in data["audit_trail"]]
        assert "CREATED" in actions
        assert "VALIDATED" in actions
        assert "OPTIMIZED" in actions


@pytest.mark.asyncio
async def test_phase6_manifest_draft_parameter_modification():
    """Verify modifying parameters in DRAFT status succeeds and logs a MODIFIED audit entry."""
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        gen_res = await client.post("/admin/manifests/generate?truck_id=DEMO-KA-04-E-1021&cycle_id=2026-09")
        mid = gen_res.json()["manifest_id"]

        update_res = await client.post(
            f"/admin/manifests/{mid}/update",
            json={
                "total_quantity_kg": 4500.0,
                "route_type": "EXPRESS_CORRIDOR",
                "departure_window": "07:30 AM (Early Priority)",
                "modification_reason": "Adjusting payload for priority corridor release"
            }
        )
        assert update_res.status_code == 200
        updated_data = update_res.json()
        assert updated_data["total_quantity_kg"] == 4500.0
        assert updated_data["departure_window"] == "07:30 AM (Early Priority)"
        assert updated_data["route_type"] == "EXPRESS_CORRIDOR"

        # Check audit trail has MODIFIED entry
        actions = [a["action"] for a in updated_data["audit_trail"]]
        assert "MODIFIED" in actions


@pytest.mark.asyncio
async def test_phase6_manifest_locking_and_immutability_guard():
    """Verify locking freezes manifest, issues SHA-256 seal, and blocks direct edits with HTTP 400."""
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        gen_res = await client.post("/admin/manifests/generate?truck_id=DEMO-KA-04-E-1021&cycle_id=2026-09")
        mid = gen_res.json()["manifest_id"]

        # Lock manifest
        lock_res = await client.post(
            f"/admin/manifests/{mid}/lock",
            json={
                "actor_name": "Dr. Ramesh Kumar, IAS",
                "actor_role": "DISTRICT_SUPPLY_OFFICER",
                "lock_reason": "Official pre-dispatch operational freeze"
            }
        )
        assert lock_res.status_code == 200
        locked_data = lock_res.json()
        assert locked_data["approval_status"] == "LOCKED"
        assert locked_data["is_locked"] is True
        assert locked_data["digital_seal_hash"] is not None
        assert len(locked_data["digital_seal_hash"]) >= 16

        # Attempting direct modification on LOCKED manifest MUST FAIL with HTTP 400
        tamper_res = await client.post(
            f"/admin/manifests/{mid}/update",
            json={"total_quantity_kg": 9999.0}
        )
        assert tamper_res.status_code == 400
        assert "LOCKED" in tamper_res.json()["detail"] or "prohibited" in tamper_res.json()["detail"]


@pytest.mark.asyncio
async def test_phase6_manifest_revision_workflow():
    """Verify creating an authorized revision increments version, records REVISED, and unlocks draft."""
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        gen_res = await client.post("/admin/manifests/generate?truck_id=DEMO-KA-04-E-1021&cycle_id=2026-09")
        mid = gen_res.json()["manifest_id"]

        # Lock first
        await client.post(f"/admin/manifests/{mid}/lock", json={"lock_reason": "Pre-dispatch freeze"})

        # Authorize revision
        rev_res = await client.post(
            f"/admin/manifests/{mid}/revise",
            json={
                "actor_name": "Dr. Ramesh Kumar, IAS",
                "actor_role": "DISTRICT_SUPPLY_OFFICER",
                "revision_reason": "Special festival allocation quota increase (+15%)"
            }
        )
        assert rev_res.status_code == 200
        rev_data = rev_res.json()
        assert rev_data["approval_status"] == "DRAFT"
        assert rev_data["is_locked"] is False
        assert rev_data["version"] == "v1.1"

        # Now editing is permitted again under v1.1
        edit_res = await client.post(
            f"/admin/manifests/{mid}/update",
            json={"total_quantity_kg": 5200.0}
        )
        assert edit_res.status_code == 200
        assert edit_res.json()["total_quantity_kg"] == 5200.0

        # Check full audit trail shows complete lifecycle
        all_actions = [a["action"] for a in edit_res.json()["audit_trail"]]
        assert "CREATED" in all_actions
        assert "LOCKED" in all_actions
        assert "REVISED" in all_actions


@pytest.mark.asyncio
async def test_phase6_manifest_list_endpoint():
    """Verify district-wide manifest list retrieves all active fleet manifests."""
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        res = await client.get("/admin/manifests?cycle_id=2026-09")
        assert res.status_code == 200
        data = res.json()
        assert data["status"] == "success"
        assert data["total_manifests_count"] >= 1
        assert len(data["manifests"]) >= 1


# ----------------- Phase 7: Gatepass & Pre-Dispatch Readiness Notification Tests ----------------- #

@pytest.mark.asyncio
async def test_phase7_gatepass_generation_from_locked_manifest():
    """Verify gatepass generation creates a simulated digital gatepass linked to manifest."""
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        # 1. Lock manifest first
        man_res = await client.post("/admin/manifests/generate?truck_id=DEMO-KA-04-E-1021&cycle_id=2026-09")
        mid = man_res.json()["manifest_id"]
        await client.post(f"/admin/manifests/{mid}/lock", json={"lock_reason": "Lock for physical gatepass generation"})

        # 2. Retrieve / generate gatepass
        res = await client.get("/admin/gatepass/DEMO-KA-04-E-1021?cycle_id=2026-09")
        assert res.status_code == 200
        data = res.json()
        assert "GP-2026-09" in data["gatepass_id"]
        assert data["truck_id"] == "DEMO-KA-04-E-1021"
        assert data["status"] in ["GATEPASS_ISSUED", "WAREHOUSE_APPROVED", "WAREHOUSE_VERIFIED", "VEHICLE_LOADED", "DISPATCH_CONFIRMED"]
        assert data["total_payload_kg"] > 0
        assert data["loading_bay"] is not None
        assert "PROTOTYPE" in data["demo_disclaimer"]
        assert len(data["event_timeline"]) in [4, 5]
        assert data["weighbridge_slip"]["tare_weight_kg"] > 0
        assert len(data["delivery_stops"]) >= 1


@pytest.mark.asyncio
async def test_phase7_gatepass_four_stage_handshake_lifecycle():
    """Verify advancing gatepass across: GATEPASS_ISSUED -> WAREHOUSE_APPROVED -> VEHICLE_LOADED -> DISPATCH_CONFIRMED."""
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        gp_res = await client.get("/admin/gatepass/DEMO-KA-04-E-1021?cycle_id=2026-09")
        gpid = gp_res.json()["gatepass_id"]

        # Stage 2: Warehouse Approval
        wh_res = await client.post(f"/admin/gatepass/{gpid}/advance?target_status=WAREHOUSE_APPROVED")
        assert wh_res.status_code == 200
        assert wh_res.json()["status"] == "WAREHOUSE_APPROVED"

        # Stage 3: Vehicle Loading
        load_res = await client.post(f"/admin/gatepass/{gpid}/advance?target_status=VEHICLE_LOADED")
        assert load_res.status_code == 200
        assert load_res.json()["status"] == "VEHICLE_LOADED"

        # Stage 4: Dispatch Confirmed (Out for Delivery)
        disp_res = await client.post(f"/admin/gatepass/{gpid}/advance?target_status=DISPATCH_CONFIRMED")
        assert disp_res.status_code == 200
        assert disp_res.json()["status"] == "DISPATCH_CONFIRMED"

        # Verify all timeline events are completed
        timeline = disp_res.json()["event_timeline"]
        for stage_item in timeline:
            assert stage_item["status"] == "COMPLETED"
            assert stage_item["actor_name"] is not None
            assert stage_item["reference_id"] is not None


@pytest.mark.asyncio
async def test_phase7_multi_channel_readiness_notification_broadcast():
    """Verify dispatching multi-channel alerts (WhatsApp, SMS, IVR) across FPS dealers and household groups."""
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        res = await client.post("/admin/notifications/dispatch?cycle_id=2026-09")
        assert res.status_code == 200
        data = res.json()
        assert data["status"] == "success"
        assert data["notifications_dispatched_count"] >= 5
        assert len(data["dealer_alerts"]) >= 1
        assert len(data["citizen_alerts"]) >= 1
        assert "WHATSAPP" in data["channels_used"]
        assert "SMS" in data["channels_used"]
        assert "IVR" in data["channels_used"]

        # Verify dealer alert content contains expected readiness message
        first_dealer = data["dealer_alerts"][0]
        assert "PDS Dispatch Readiness Alert" in first_dealer["title"] or "PDS Dispatch Readiness Alert" in first_dealer["message"]
        assert "Expected arrival" in first_dealer["message"]


@pytest.mark.asyncio
async def test_phase7_notification_logs_and_filtering():
    """Verify querying notification logs by recipient filter."""
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        # All logs
        res_all = await client.get("/admin/notifications/logs?cycle_id=2026-09")
        assert res_all.status_code == 200
        assert res_all.json()["total_logs_count"] >= 1

        # Dealer filtered
        res_dealers = await client.get("/admin/notifications/logs?cycle_id=2026-09&recipient_type=DEALER")
        assert res_dealers.status_code == 200
        for log in res_dealers.json()["logs"]:
            assert log["recipient_type"] == "DEALER"
            assert log["channel"] == "WHATSAPP"


# -----------------------------------------------------------------------------
# PHASE 8: DELIVERY FEEDBACK LOOP AND FINAL SIH DEMO MODE TESTS
# -----------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_phase8_sih_demo_scenarios_listing():
    """Verify listing all 4 preconfigured SIH demonstration scenarios."""
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        res = await client.get("/admin/demo/scenarios")
        assert res.status_code == 200
        data = res.json()
        assert data["status"] == "success"
        assert data["total_scenarios_count"] == 5
        scenario_ids = [s["id"] for s in data["scenarios"]]
        assert "SCENARIO_1" in scenario_ids
        assert "SCENARIO_2" in scenario_ids
        assert "SCENARIO_3" in scenario_ids
        assert "SCENARIO_4" in scenario_ids
        assert "SCENARIO_5" in scenario_ids


@pytest.mark.asyncio
async def test_phase8_sih_demo_scenario_14_step_execution():
    """Verify executing Scenario 1 runs all 14 steps end-to-end with formulas and system impact."""
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        payload = {
            "scenario_id": "SCENARIO_1",
            "target_fps_id": "FPS-KA-BLR-001",
            "cycle_id": "2026-09"
        }
        res = await client.post("/admin/demo/scenario/run", json=payload)
        assert res.status_code == 200
        data = res.json()
        assert data["status"] == "success"
        assert data["scenario_id"] == "SCENARIO_1"
        assert data["total_steps_executed"] == 14
        assert len(data["steps_trace"]) == 14

        # Verify specific steps in 14-step pipeline
        step_titles = [s["title"] for s in data["steps_trace"]]
        assert "Select Target FPS Profile" in step_titles[0]
        assert "Multi-Factor Demand Forecasting" in step_titles[2]
        assert "Pre-Dispatch Decision Recommendation" in step_titles[3]
        assert "Validate 9 Logistics Constraints" in step_titles[4]
        assert "Select Fleet Carrier (Candidate Scoring)" in step_titles[5]
        assert "Optimize Delivery Tour (TSP Routing)" in step_titles[6]
        assert "Generate Corridor Pre-Dispatch Manifest" in step_titles[7]
        assert "Lock Manifest & Issue Cryptographic Seal" in step_titles[8]
        assert "Generate Digital Gatepass & Weighbridge Slip" in step_titles[9]
        assert "Confirm Physical Dispatch (Gate Clearance)" in step_titles[10]
        assert "Send Multi-Channel Readiness Notifications" in step_titles[11]
        assert "Ingest Actual Offtake & Error Residual" in step_titles[12]
        assert "Closed-Loop Model Feedback & Future Calibration" in step_titles[13]

        # Verify all steps have COMPLETED status
        for step in data["steps_trace"]:
            assert step["status"] == "COMPLETED"

        # Verify system impact summary
        summary = data["system_impact_summary"]
        assert summary["stockout_risk_reduction_pct"] > 80.0
        assert summary["truck_utilization_pct"] > 90.0
        assert summary["core_usp"] == "Forecast → Decide → Lock → Notify"


@pytest.mark.asyncio
async def test_phase8_sih_demo_alternate_scenarios():
    """Verify executing Scenarios 2, 3, and 4."""
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        # Scenario 2: Truck Capacity Failure & Remediation
        res2 = await client.post("/admin/demo/scenario/run", json={"scenario_id": "SCENARIO_2"})
        assert res2.status_code == 200
        data2 = res2.json()
        assert data2["scenario_id"] == "SCENARIO_2"
        assert len(data2["steps_trace"]) == 14

        # Scenario 3: High Demand Spike & Dynamic Buffer
        res3 = await client.post("/admin/demo/scenario/run", json={"scenario_id": "SCENARIO_3"})
        assert res3.status_code == 200
        data3 = res3.json()
        assert data3["scenario_id"] == "SCENARIO_3"
        # Verify dynamic buffer in step 4
        step4 = data3["steps_trace"][3]
        assert step4["details"]["safety_buffer_kg"] == 680.0

        # Scenario 4: Route Restriction & Expressway Tour
        res4 = await client.post("/admin/demo/scenario/run", json={"scenario_id": "SCENARIO_4"})
        assert res4.status_code == 200
        data4 = res4.json()
        assert data4["scenario_id"] == "SCENARIO_4"


@pytest.mark.asyncio
async def test_phase8_actual_offtake_recording_and_residual_calculation():
    """Verify user-entered actual offtake computes residual errors, directional bias, and feedback telemetry."""
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        payload = {
            "fps_id": "FPS-KA-BLR-001",
            "actual_rice_kg": 1950.0,
            "actual_wheat_kg": 1100.0,
            "cycle_id": "2026-09"
        }
        res = await client.post("/admin/evaluation/offtake/record", json=payload)
        assert res.status_code == 200
        data = res.json()
        assert data["status"] == "success"
        assert data["fps_id"] == "FPS-KA-BLR-001"
        assert data["total_actual_quantity_kg"] == 3050.0
        assert data["total_absolute_error_kg"] >= 0.0
        assert data["percentage_error"] >= 0.0
        assert data["overall_accuracy_pct"] >= 80.0
        assert data["bias_direction"] in ["OVER_PREDICTED", "UNDER_PREDICTED", "EXACT"]
        assert len(data["commodities"]) == 2
        assert len(data["historical_accuracy_trend"]) >= 3
        assert "Feedback captured for next forecasting cycle" in data["model_feedback_status"]
        assert data["dataset_updated"] is True


@pytest.mark.asyncio
async def test_phase8_system_impact_dashboard_metrics():
    """Verify retrieving Before vs After prototype impact KPIs and value chain."""
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        res = await client.get("/admin/system-impact?cycle_id=2026-09")
        assert res.status_code == 200
        data = res.json()
        assert data["status"] == "success"
        assert len(data["impact_metrics"]) == 7
        assert "stockout_risk_reduction" in data["impact_metrics"]
        assert "truck_utilization" in data["impact_metrics"]
        assert "transport_cost_savings" in data["impact_metrics"]
        assert "forecast_accuracy" in data["impact_metrics"]
        assert len(data["system_value_chain"]) == 8
        assert data["core_usp"] == "Forecast → Decide → Lock → Notify"
        assert "Prototype simulation" in data["prototype_label"]


@pytest.mark.asyncio
async def test_phase9_sih_judge_defense_view():
    """Verify SIH Judge Defense view endpoint returns complete architectural demarcation and FAQ defense."""
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        res = await client.get("/admin/judge-view")
        assert res.status_code == 200
        data = res.json()
        assert data["status"] == "success"
        assert "what_exists" in data
        assert len(data["what_exists"]["pillars"]) >= 6
        assert "what_we_add" in data
        assert len(data["what_we_add"]["innovations"]) >= 8
        assert len(data["value_chain_matrix"]) >= 8
        assert len(data["judge_faq_defense"]) >= 5
        assert "Forecast → Decide → Validate → Optimize → Lock → Notify" in data["core_usp"]
        assert "Prototype Simulation" in data["prototype_disclaimer"]








