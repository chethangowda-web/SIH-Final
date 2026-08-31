import pytest
import httpx
import sqlite3
from app.main import app
from app.core.database import get_db_connection, init_db
from app.data.seed_data import seed_all_data
from app.services.workflow_manager import workflow_manager, WorkflowState
from app.services.constraint_engine import constraint_engine

@pytest.fixture(autouse=True)
def setup_database():
    """Ensure database is seeded and state is clean before each test."""
    init_db()
    seed_all_data(recreate=False)
    conn = get_db_connection()
    # Reset state machine tables and other stages
    conn.execute("DELETE FROM cycle_workflow_states;")
    conn.execute("DELETE FROM workflow_audit_logs;")
    conn.execute("DELETE FROM model_calibration;")
    conn.execute("DELETE FROM forecast_evaluation;")
    conn.execute("DELETE FROM actual_distribution;")
    conn.execute("DELETE FROM dispatch;")
    conn.execute("DELETE FROM forecast;")
    conn.execute("DELETE FROM gatepasses;")
    conn.commit()
    conn.close()

@pytest.mark.asyncio
async def test_get_workflow_status():
    """Test retrieving the initial workflow state."""
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        res = await client.get("/admin/workflow/status?cycle_id=2026-09")
        assert res.status_code == 200
        data = res.json()
        assert data["current_state"] == "FORECASTED"
        assert "VALIDATED" in data["allowed_next_states"]
        assert len(data["audit_history"]) == 0

@pytest.mark.asyncio
async def test_invalid_state_transition():
    """Test that out-of-order transition fails (e.g., FORECASTED -> GATEPASS_READY)."""
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        payload = {
            "cycle_id": "2026-09",
            "new_state": "GATEPASS_READY",
            "actor_name": "Test Officer",
            "actor_role": "DISTRICT_SUPPLY_OFFICER",
            "reason": "Skip steps"
        }
        res = await client.post("/admin/workflow/transition", json=payload)
        assert res.status_code == 400
        assert "Illegal state transition" in res.json()["detail"]

@pytest.mark.asyncio
async def test_citizen_role_blocked():
    """Test that citizen role cannot transition allocation states."""
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        payload = {
            "cycle_id": "2026-09",
            "new_state": "VALIDATED",
            "actor_name": "Swathi (Citizen)",
            "actor_role": "CITIZEN",
            "reason": "Attempting transition"
        }
        res = await client.post("/admin/workflow/transition", json=payload)
        assert res.status_code == 400
        assert "Unauthorized Access: Citizen role cannot transition" in res.json()["detail"]

@pytest.mark.asyncio
async def test_ai_role_blocked_from_officer_states():
    """Test that AI role is blocked from authorizing officer-governed states."""
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        # AI tries to transition to ALLOCATED
        payload = {
            "cycle_id": "2026-09",
            "new_state": "ALLOCATED",
            "actor_name": "DemandSync Advisor (AI)",
            "actor_role": "AI",
            "reason": "AI Auto-approval recommendation"
        }
        res = await client.post("/admin/workflow/transition", json=payload)
        assert res.status_code == 400
        assert "AI role is advisory only" in res.json()["detail"]

        # AI tries to transition to MANIFEST_LOCKED
        payload["new_state"] = "MANIFEST_LOCKED"
        res = await client.post("/admin/workflow/transition", json=payload)
        assert res.status_code == 400
        assert "AI role is advisory only" in res.json()["detail"]

@pytest.mark.asyncio
async def test_failed_constraints_block_manifest_lock():
    """Test that failed constraints block manifest locking state transition."""
    # Seed a simulated failed constraint override
    constraint_engine.set_simulation_override("FPS-KA-BLR-001", {"overall_status": "FAIL", "blocking_reason": "Storage Exceeded"})
    
    conn = get_db_connection()
    # Transition to MANIFEST_DRAFT manually to attempt lock transition
    workflow_manager.transition_state(
        conn, "2026-09", WorkflowState.MANIFEST_DRAFT,
        "System Test", "DISTRICT_SUPPLY_OFFICER", force=True
    )
    conn.close()

    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        payload = {
            "cycle_id": "2026-09",
            "new_state": "MANIFEST_LOCKED",
            "actor_name": "District Supply Officer",
            "actor_role": "DISTRICT_SUPPLY_OFFICER",
            "reason": "Lock manifests"
        }
        res = await client.post("/admin/workflow/transition", json=payload)
        assert res.status_code == 400
        assert "State Transition Blocked" in res.json()["detail"]
        assert "Manifest lock blocked" in res.json()["detail"]

    # Clear override
    constraint_engine.set_simulation_override("FPS-KA-BLR-001", None)

@pytest.mark.asyncio
async def test_gatepass_issuance_invalid_state_blocked():
    """Test that GATEPASS_READY is blocked if current state is not MANIFEST_LOCKED."""
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        # Current state is FORECASTED. Transition to GATEPASS_READY should be blocked.
        payload = {
            "cycle_id": "2026-09",
            "new_state": "GATEPASS_READY",
            "actor_name": "District Supply Officer",
            "actor_role": "DISTRICT_SUPPLY_OFFICER",
            "reason": "Issue gatepass"
        }
        res = await client.post("/admin/workflow/transition", json=payload)
        assert res.status_code == 400
        assert "Illegal state transition" in res.json()["detail"]

@pytest.mark.asyncio
async def test_dispatch_blocked_before_gatepass_ready():
    """Test that DISPATCHED state is blocked if current state is not GATEPASS_READY."""
    conn = get_db_connection()
    # Manually transition to MANIFEST_LOCKED (valid state, but not GATEPASS_READY)
    workflow_manager.transition_state(
        conn, "2026-09", WorkflowState.MANIFEST_LOCKED,
        "System Test", "DISTRICT_SUPPLY_OFFICER", force=True
    )
    conn.close()

    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        payload = {
            "cycle_id": "2026-09",
            "new_state": "DISPATCHED",
            "actor_name": "District Supply Officer",
            "actor_role": "DISTRICT_SUPPLY_OFFICER",
            "reason": "Confirm truck departure"
        }
        res = await client.post("/admin/workflow/transition", json=payload)
        assert res.status_code == 400
        assert "Illegal state transition" in res.json()["detail"]

@pytest.mark.asyncio
async def test_evaluation_blocked_without_distribution_data():
    """Test that transitioning to EVALUATED is blocked if actual distribution data is missing."""
    conn = get_db_connection()
    # Transition to VERIFIED manually
    workflow_manager.transition_state(
        conn, "2026-09", WorkflowState.VERIFIED,
        "System Test", "DISTRICT_SUPPLY_OFFICER", force=True
    )
    # Ensure actual distribution data is empty
    conn.execute("DELETE FROM actual_distribution;")
    conn.commit()
    conn.close()

    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        payload = {
            "cycle_id": "2026-09",
            "new_state": "EVALUATED",
            "actor_name": "District Supply Officer",
            "actor_role": "DISTRICT_SUPPLY_OFFICER",
            "reason": "Finalize forecast evaluation"
        }
        res = await client.post("/admin/workflow/transition", json=payload)
        assert res.status_code == 400
        assert "State Transition Blocked" in res.json()["detail"]
        assert "Actual ePoS distribution data has not been simulated/recorded" in res.json()["detail"]

@pytest.mark.asyncio
async def test_repeated_transition_idempotent():
    """Test that repeating the same state transition request is idempotent and returns 200."""
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        payload = {
            "cycle_id": "2026-09",
            "new_state": "VALIDATED",
            "actor_name": "District Supply Officer",
            "actor_role": "DISTRICT_SUPPLY_OFFICER",
            "reason": "Constraint check passed"
        }
        # First transition: FORECASTED -> VALIDATED
        res1 = await client.post("/admin/workflow/transition", json=payload)
        assert res1.status_code == 200
        assert res1.json()["current_state"] == "VALIDATED"

        # Second transition (duplicate identical request): VALIDATED -> VALIDATED
        res2 = await client.post("/admin/workflow/transition", json=payload)
        assert res2.status_code == 200
        assert res2.json()["current_state"] == "VALIDATED"

@pytest.mark.asyncio
async def test_illegal_skip_stages_rejected():
    """Test that skipping mandatory stages is strictly rejected with 400."""
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        # Starting from FORECASTED, attempt to skip directly to ALLOCATED (skipping VALIDATED)
        payload = {
            "cycle_id": "2026-09",
            "new_state": "ALLOCATED",
            "actor_name": "District Supply Officer",
            "actor_role": "DISTRICT_SUPPLY_OFFICER",
            "reason": "Skipping validation"
        }
        res = await client.post("/admin/workflow/transition", json=payload)
        assert res.status_code == 400
        assert "Illegal state transition" in res.json()["detail"]

@pytest.mark.asyncio
async def test_full_authorized_forward_lifecycle():
    """Test authoritative forward progression through all lifecycle states."""
    # Seed required prereqs for later stages: actual distribution data
    conn = get_db_connection()
    conn.execute("""
    INSERT OR REPLACE INTO actual_distribution 
        (cycle_id, fps_id, commodity, dispatch_quantity_kg, actual_quantity_kg)
    VALUES ('2026-09', 'FPS-KA-BLR-001', 'Rice', 5000.0, 4950.0);
    """)
    conn.commit()
    conn.close()

    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        stages = [
            "VALIDATED",
            "ALLOCATED",
            "OPTIMIZED",
            "MANIFEST_DRAFT",
            "MANIFEST_LOCKED",
            "GATEPASS_READY",
            "DISPATCHED",
            "VERIFIED",
            "EVALUATED"
        ]

        for stage in stages:
            res = await client.post("/admin/workflow/transition", json={
                "cycle_id": "2026-09",
                "new_state": stage,
                "actor_name": "District Supply Officer",
                "actor_role": "DISTRICT_SUPPLY_OFFICER",
                "reason": f"Advancing to {stage}"
            })
            assert res.status_code == 200, f"Failed transitioning to {stage}: {res.text}"
            assert res.json()["current_state"] == stage

        # Verify audit history logged all transitions
        status_res = await client.get("/admin/workflow/status?cycle_id=2026-09")
        assert status_res.status_code == 200
        audit_history = status_res.json()["audit_history"]
        assert len(audit_history) >= len(stages)

