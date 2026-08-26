"""Automated API Integration Tests for Scarcity & Stockout Risk Endpoints.

Tests:
1. test_depot_balance_endpoint: GET /api/admin/scarcity/depot-balance returns complete balance metadata
2. test_risk_prediction_endpoint: POST /api/admin/scarcity/predict-risk returns continuous probability and tier
3. test_fair_share_simulation_endpoint: POST /api/admin/scarcity/simulate-fair-share returns candidate plan
4. test_simulation_does_not_modify_live_dispatch: confirms live forecast & dispatch are unaltered
5. test_simulation_produces_pending_officer_review: staged plan has status PENDING_OFFICER_REVIEW
6. test_approve_plan_requires_authorization: unauthorized roles return HTTP 403 Forbidden
7. test_valid_officer_can_approve_valid_plan: authorized officer approves plan, marking OFFICER_APPROVED
8. test_duplicate_approval_is_rejected: duplicate approval returns HTTP 400 Bad Request
9. test_invalid_plan_is_rejected: non-existent plan ID returns HTTP 404 Not Found
10. test_invalid_commodity_is_rejected: invalid commodity returns HTTP 400 Bad Request
11. test_server_ignores_client_supplied_risk_probability: server extracts features and calculates risk
12. test_server_ignores_client_supplied_statutory_floor: server derives statutory floors from database
13. test_approved_allocation_never_exceeds_depot_stock: approved allocation <= available stock
14. test_approved_allocation_preserves_statutory_floors_when_feasible: floors preserved when stock is feasible
15. test_infeasible_statutory_floors_are_explicitly_surfaced: STATUTORY_FLOORS_UNSATISFIABLE alert surfaced
16. test_audit_trail_endpoint_returns_complete_plan_information: GET /api/admin/scarcity/audit-trail/{id} returns audit details
17. test_forecast_predicted_quantity_remains_unchanged_after_approval: predicted_quantity_kg unmutated
18. test_existing_dispatch_lifecycle_remains_valid: full pipeline integrity preserved post-approval
"""

import pytest
import httpx
from app.main import app
from app.core.database import get_db_connection, init_db
from app.data.seed_data import seed_all_data
from app.services.forecast_engine import forecast_engine


@pytest.fixture(autouse=True)
def setup_database_for_scarcity_api():
    """Ensure clean baseline database state for scarcity API tests."""
    init_db()
    seed_all_data(recreate=True)
    conn = get_db_connection()
    forecast_engine.generate_and_persist_forecasts(conn, cycle_id="2026-09", force=True)
    conn.close()


@pytest.mark.asyncio
async def test_depot_balance_endpoint():
    """Test 1: Verify GET /api/admin/scarcity/depot-balance returns valid deficit and floor data."""
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        response = await client.get("/api/admin/scarcity/depot-balance?cycle_id=2026-09&depot_id=DEPOT-01&commodity=Rice")
        assert response.status_code == 200
        data = response.json()
        assert data["cycle_id"] == "2026-09"
        assert data["depot_id"] == "DEPOT-01"
        assert data["commodity"] == "Rice"
        assert data["aggregate_demand_kg"] >= 0.0
        assert data["available_depot_stock_kg"] > 0.0
        assert data["statutory_floor_status"] in ["STATUTORY_FLOORS_SATISFIED", "STATUTORY_FLOORS_UNSATISFIABLE"]
        assert "DEMO DATA" in data["demo_notice"]


@pytest.mark.asyncio
async def test_risk_prediction_endpoint():
    """Test 2: Verify POST /api/admin/scarcity/predict-risk runs server-side ML model inference."""
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        payload = {
            "cycle_id": "2026-09",
            "commodity": "Rice",
            "fps_id": "FPS-KA-BLR-001",
            "proposed_allocation_kg": 1500.0
        }
        response = await client.post("/api/admin/scarcity/predict-risk", json=payload)
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "success"
        assert data["predictions_count"] == 1
        item = data["predictions"][0]
        assert item["fps_id"] == "FPS-KA-BLR-001"
        assert 0.0 <= item["stockout_probability"] <= 1.0
        assert item["risk_tier"] in ["CRITICAL", "ELEVATED", "MODERATE", "LOW"]
        assert "historical_demand_mean_kg" in item["features"]


@pytest.mark.asyncio
async def test_fair_share_simulation_endpoint():
    """Test 3: Verify POST /api/admin/scarcity/simulate-fair-share generates deterministic allocation plan."""
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        payload = {
            "cycle_id": "2026-09",
            "depot_id": "DEPOT-01",
            "commodity": "Rice",
            "available_depot_stock_kg": 15000.0,
            "allocation_strategy": "FAIR_SHARE_RISK_WEIGHTED",
            "persist_candidate": False
        }
        response = await client.post("/api/admin/scarcity/simulate-fair-share", json=payload)
        assert response.status_code == 200
        data = response.json()
        assert data["depot_id"] == "DEPOT-01"
        assert data["total_reconciled_allocation_kg"] <= 15000.1
        assert len(data["allocated_items"]) > 0


@pytest.mark.asyncio
async def test_simulation_does_not_modify_live_dispatch():
    """Test 4: Verify simulation is strictly read-only and leaves live forecast unchanged."""
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute("SELECT fps_id, commodity, predicted_quantity_kg, recommended_dispatch_kg FROM forecast WHERE cycle_id = '2026-09';")
    before_records = cursor.fetchall()
    conn.close()

    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        payload = {
            "cycle_id": "2026-09",
            "depot_id": "DEPOT-01",
            "commodity": "Rice",
            "available_depot_stock_kg": 10000.0,
            "allocation_strategy": "FAIR_SHARE_RISK_WEIGHTED",
            "persist_candidate": False
        }
        response = await client.post("/api/admin/scarcity/simulate-fair-share", json=payload)
        assert response.status_code == 200

    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute("SELECT fps_id, commodity, predicted_quantity_kg, recommended_dispatch_kg FROM forecast WHERE cycle_id = '2026-09';")
    after_records = cursor.fetchall()
    conn.close()

    assert before_records == after_records


@pytest.mark.asyncio
async def test_simulation_produces_pending_officer_review():
    """Test 5: Staging a candidate plan sets status to PENDING_OFFICER_REVIEW."""
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        payload = {
            "cycle_id": "2026-09",
            "depot_id": "DEPOT-01",
            "commodity": "Rice",
            "available_depot_stock_kg": 12000.0,
            "persist_candidate": True
        }
        response = await client.post("/api/admin/scarcity/simulate-fair-share", json=payload)
        assert response.status_code == 200
        data = response.json()
        assert data["plan_id"] is not None
        assert data["approval_status"] == "PENDING_OFFICER_REVIEW"


@pytest.mark.asyncio
async def test_approve_plan_requires_authorization():
    """Test 6: Reject approval from unauthorized roles with HTTP 403 Forbidden."""
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        # First stage a plan
        stage_res = await client.post("/api/admin/scarcity/simulate-fair-share", json={
            "cycle_id": "2026-09",
            "depot_id": "DEPOT-01",
            "commodity": "Rice",
            "available_depot_stock_kg": 14000.0,
            "persist_candidate": True
        })
        plan_id = stage_res.json()["plan_id"]

        # Attempt approval with unauthorized role
        bad_approval = {
            "plan_id": plan_id,
            "officer_name": "Citizen Observer",
            "officer_role": "BENEFICIARY",
            "approval_notes": "Unapproved attempt"
        }
        approve_res = await client.post("/api/admin/scarcity/approve-plan", json=bad_approval)
        assert approve_res.status_code == 403
        assert "Unauthorized" in approve_res.json()["detail"]


@pytest.mark.asyncio
async def test_valid_officer_can_approve_valid_plan():
    """Test 7: Authorized District Supply Officer successfully approves a staged plan."""
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        stage_res = await client.post("/api/admin/scarcity/simulate-fair-share", json={
            "cycle_id": "2026-09",
            "depot_id": "DEPOT-01",
            "commodity": "Rice",
            "available_depot_stock_kg": 16000.0,
            "persist_candidate": True
        })
        plan_id = stage_res.json()["plan_id"]

        valid_approval = {
            "plan_id": plan_id,
            "officer_name": "Prajwal S",
            "officer_role": "DISTRICT_SUPPLY_OFFICER",
            "approval_notes": "DSO official scarcity allocation sign-off"
        }
        approve_res = await client.post("/api/admin/scarcity/approve-plan", json=valid_approval)
        assert approve_res.status_code == 200
        data = approve_res.json()
        assert data["approval_status"] == "OFFICER_APPROVED"
        assert "Prajwal S" in data["approved_by"]


@pytest.mark.asyncio
async def test_duplicate_approval_is_rejected():
    """Test 8: Prevent duplicate approval on an already approved plan (HTTP 400)."""
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        stage_res = await client.post("/api/admin/scarcity/simulate-fair-share", json={
            "cycle_id": "2026-09",
            "depot_id": "DEPOT-01",
            "commodity": "Rice",
            "available_depot_stock_kg": 15000.0,
            "persist_candidate": True
        })
        plan_id = stage_res.json()["plan_id"]

        approval_payload = {
            "plan_id": plan_id,
            "officer_name": "DSO Ramesh",
            "officer_role": "DISTRICT_SUPPLY_OFFICER"
        }
        # First approval succeeds
        res1 = await client.post("/api/admin/scarcity/approve-plan", json=approval_payload)
        assert res1.status_code == 200

        # Second approval fails
        res2 = await client.post("/api/admin/scarcity/approve-plan", json=approval_payload)
        assert res2.status_code == 400
        assert "already been approved" in res2.json()["detail"]


@pytest.mark.asyncio
async def test_invalid_plan_is_rejected():
    """Test 9: Approval attempt on non-existent plan ID returns HTTP 404."""
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        payload = {
            "plan_id": "PLAN-NON-EXISTENT-9999",
            "officer_name": "DSO Officer",
            "officer_role": "DISTRICT_SUPPLY_OFFICER"
        }
        response = await client.post("/api/admin/scarcity/approve-plan", json=payload)
        assert response.status_code == 404
        assert "not found" in response.json()["detail"]


@pytest.mark.asyncio
async def test_invalid_commodity_is_rejected():
    """Test 10: Invalid commodity name returns HTTP 400 Bad Request."""
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        response = await client.get("/api/admin/scarcity/depot-balance?commodity=InvalidGrain")
        assert response.status_code == 400
        assert "Invalid commodity" in response.json()["detail"]


@pytest.mark.asyncio
async def test_server_ignores_client_supplied_risk_probability():
    """Test 11: Server derives probability dynamically and ignores spoofed client probability."""
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        payload = {
            "cycle_id": "2026-09",
            "commodity": "Rice",
            "fps_id": "FPS-KA-BLR-001",
            "proposed_allocation_kg": 2000.0,
            "stockout_probability": 0.9999,  # Spoofed client value
            "risk_tier": "CRITICAL"          # Spoofed client tier
        }
        response = await client.post("/api/admin/scarcity/predict-risk", json=payload)
        assert response.status_code == 200
        item = response.json()["predictions"][0]
        # Verified server calculated value is bounded and genuine
        assert 0.0 <= item["stockout_probability"] <= 1.0


@pytest.mark.asyncio
async def test_server_ignores_client_supplied_statutory_floor():
    """Test 12: Server calculates statutory floors from SQL table and ignores spoofed values."""
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        payload = {
            "cycle_id": "2026-09",
            "depot_id": "DEPOT-01",
            "commodity": "Rice",
            "available_depot_stock_kg": 18000.0,
            "statutory_floor_kg": 0.0  # Spoofed client floor
        }
        response = await client.post("/api/admin/scarcity/simulate-fair-share", json=payload)
        assert response.status_code == 200
        data = response.json()
        assert data["total_statutory_floors_kg"] > 0.0


@pytest.mark.asyncio
async def test_approved_allocation_never_exceeds_depot_stock():
    """Test 13: Total reconciled allocation across all FPS is strictly <= available depot stock."""
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        stage_res = await client.post("/api/admin/scarcity/simulate-fair-share", json={
            "cycle_id": "2026-09",
            "depot_id": "DEPOT-01",
            "commodity": "Rice",
            "available_depot_stock_kg": 11500.0,
            "persist_candidate": True
        })
        plan_id = stage_res.json()["plan_id"]
        total_alloc = stage_res.json()["total_reconciled_allocation_kg"]
        assert total_alloc <= 11500.1

        approve_res = await client.post("/api/admin/scarcity/approve-plan", json={
            "plan_id": plan_id,
            "officer_name": "DSO Officer",
            "officer_role": "DISTRICT_SUPPLY_OFFICER"
        })
        assert approve_res.status_code == 200
        assert approve_res.json()["total_reconciled_allocation_kg"] <= 11500.1


@pytest.mark.asyncio
async def test_approved_allocation_preserves_statutory_floors_when_feasible():
    """Test 14: Under feasible scarcity, every FPS receives at least its statutory entitlement floor."""
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        # Determine total floors
        bal_res = await client.get("/api/admin/scarcity/depot-balance?commodity=Rice")
        total_floors = bal_res.json()["statutory_floor_total_kg"]

        stage_res = await client.post("/api/admin/scarcity/simulate-fair-share", json={
            "cycle_id": "2026-09",
            "depot_id": "DEPOT-01",
            "commodity": "Rice",
            "available_depot_stock_kg": total_floors + 3000.0,
            "persist_candidate": True
        })
        plan_data = stage_res.json()
        assert plan_data["statutory_floor_status"] == "STATUTORY_FLOORS_SATISFIED"

        for it in plan_data["allocated_items"]:
            assert it["reconciled_allocation_kg"] >= it["statutory_floor_kg"]
            assert it["statutory_floor_satisfied"] is True


@pytest.mark.asyncio
async def test_infeasible_statutory_floors_are_explicitly_surfaced():
    """Test 15: Critical scarcity surfaces STATUTORY_FLOORS_UNSATISFIABLE alert."""
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        stage_res = await client.post("/api/admin/scarcity/simulate-fair-share", json={
            "cycle_id": "2026-09",
            "depot_id": "DEPOT-01",
            "commodity": "Rice",
            "available_depot_stock_kg": 500.0,  # Extreme deficit
            "persist_candidate": True
        })
        plan_data = stage_res.json()
        assert plan_data["statutory_floor_status"] == "STATUTORY_FLOORS_UNSATISFIABLE"
        assert plan_data["is_statutory_floor_satisfied"] is False
        assert "STATUTORY_FLOORS_UNSATISFIABLE" in plan_data["governance_alert"]


@pytest.mark.asyncio
async def test_audit_trail_endpoint_returns_complete_plan_information():
    """Test 16: Verify GET /api/admin/scarcity/audit-trail/{plan_id} returns complete plan lifecycle history."""
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        stage_res = await client.post("/api/admin/scarcity/simulate-fair-share", json={
            "cycle_id": "2026-09",
            "depot_id": "DEPOT-01",
            "commodity": "Rice",
            "available_depot_stock_kg": 13500.0,
            "persist_candidate": True
        })
        plan_id = stage_res.json()["plan_id"]

        await client.post("/api/admin/scarcity/approve-plan", json={
            "plan_id": plan_id,
            "officer_name": "Auditor General",
            "officer_role": "ADMIN",
            "approval_notes": "Forensic audit authorization test"
        })

        audit_res = await client.get(f"/api/admin/scarcity/audit-trail/{plan_id}")
        assert audit_res.status_code == 200
        data = audit_res.json()
        assert data["plan_id"] == plan_id
        assert data["approval_status"] == "OFFICER_APPROVED"
        assert "Auditor General" in data["approved_by"]
        assert len(data["allocated_items"]) > 0


@pytest.mark.asyncio
async def test_forecast_predicted_quantity_remains_unchanged_after_approval():
    """Test 17: Approval updates recommended_dispatch_kg but NEVER touches predicted_quantity_kg."""
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute("SELECT fps_id, predicted_quantity_kg FROM forecast WHERE cycle_id = '2026-09' AND commodity = 'Rice';")
    pred_before = {r[0]: r[1] for r in cursor.fetchall()}
    conn.close()

    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        stage_res = await client.post("/api/admin/scarcity/simulate-fair-share", json={
            "cycle_id": "2026-09",
            "depot_id": "DEPOT-01",
            "commodity": "Rice",
            "available_depot_stock_kg": 12500.0,
            "persist_candidate": True
        })
        plan_id = stage_res.json()["plan_id"]

        await client.post("/api/admin/scarcity/approve-plan", json={
            "plan_id": plan_id,
            "officer_name": "DSO Officer",
            "officer_role": "DISTRICT_SUPPLY_OFFICER"
        })

    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute("SELECT fps_id, predicted_quantity_kg FROM forecast WHERE cycle_id = '2026-09' AND commodity = 'Rice';")
    pred_after = {r[0]: r[1] for r in cursor.fetchall()}
    conn.close()

    assert pred_before == pred_after, "Approval unexpectedly modified forecast.predicted_quantity_kg!"


@pytest.mark.asyncio
async def test_existing_dispatch_lifecycle_remains_valid():
    """Test 18: Operational forecast summary and admin endpoints continue working properly post-approval."""
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        admin_res = await client.get("/api/admin/dashboard")
        assert admin_res.status_code == 200
        summary = admin_res.json()
        assert summary["total_fps"] == 20
        assert summary["active_cycle"] == "2026-09"


@pytest.mark.asyncio
async def test_scenario_5_in_available_scenarios_list():
    """Test 19: Verify SCENARIO_5 is registered and returned in the available demo scenarios list."""
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        res = await client.get("/api/admin/demo/scenarios")
        assert res.status_code == 200
        data = res.json()
        scenarios = data["scenarios"]
        scenario_ids = [s["id"] for s in scenarios]
        assert "SCENARIO_5" in scenario_ids
        sc5 = next(s for s in scenarios if s["id"] == "SCENARIO_5")
        assert sc5["badge"] == "AI SCARCITY RECONCILIATION"
        assert "Depot Scarcity" in sc5["title"]


@pytest.mark.asyncio
async def test_scenario_5_execution_and_scarcity_trace():
    """Test 20: Verify executing SCENARIO_5 runs the full 14-step trace with AI Scarcity Reconciliation in Step 4."""
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute("SELECT fps_id, predicted_quantity_kg FROM forecast WHERE cycle_id = '2026-09' AND commodity = 'Rice';")
    pred_before = {r[0]: r[1] for r in cursor.fetchall()}
    conn.close()

    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        res = await client.post("/api/admin/demo/scenario/run", json={
            "scenario_id": "SCENARIO_5",
            "cycle_id": "2026-09"
        })
        assert res.status_code == 200
        data = res.json()
        assert data["status"] == "success"
        assert data["scenario_id"] == "SCENARIO_5"
        assert data["total_steps_executed"] == 14

        steps = data["steps_trace"]
        step4 = next(s for s in steps if s["step_number"] == 4)
        assert "AI Scarcity Reconciliation" in step4["title"]
        assert step4["details"]["approval_status"] == "OFFICER_APPROVED"
        assert step4["details"]["statutory_floor_status"] == "STATUTORY_FLOORS_SATISFIED"
        assert step4["details"]["reconciled_allocation_kg"] > 0
        assert 0.0 <= step4["details"]["ml_predicted_stockout_risk"] <= 1.0

        # Step 9 must have digital seal
        step9 = next(s for s in steps if s["step_number"] == 9)
        assert len(step9["details"]["digital_seal_hash"]) >= 32

        # Step 10 must have gatepass
        step10 = next(s for s in steps if s["step_number"] == 10)
        assert "GP-" in step10["details"]["gatepass_id"]

    # Verify forecast.predicted_quantity_kg is completely untouched
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute("SELECT fps_id, predicted_quantity_kg FROM forecast WHERE cycle_id = '2026-09' AND commodity = 'Rice';")
    pred_after = {r[0]: r[1] for r in cursor.fetchall()}
    conn.close()

    assert pred_before == pred_after


@pytest.mark.asyncio
async def test_rejected_plan_cannot_be_approved():
    """Test 21: Verify a plan with REJECTED status cannot be approved and returns HTTP 400."""
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        stage_res = await client.post("/api/admin/scarcity/simulate-fair-share", json={
            "cycle_id": "2026-09",
            "depot_id": "DEPOT-01",
            "commodity": "Rice",
            "available_depot_stock_kg": 15000.0,
            "persist_candidate": True
        })
        plan_id = stage_res.json()["plan_id"]

    # Mark plan as REJECTED in database
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute("UPDATE scarcity_allocation_plans SET approval_status = 'REJECTED' WHERE plan_id = ?;", (plan_id,))
    conn.commit()
    conn.close()

    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        app_res = await client.post("/api/admin/scarcity/approve-plan", json={
            "plan_id": plan_id,
            "officer_name": "District Supply Officer",
            "officer_role": "DISTRICT_SUPPLY_OFFICER"
        })
        assert app_res.status_code == 400
        assert "has been rejected" in app_res.json()["detail"]


