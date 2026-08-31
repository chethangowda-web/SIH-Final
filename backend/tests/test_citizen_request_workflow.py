"""Comprehensive Automated Test Suite for Citizen Request -> AI Advisory Assessment
-> Officer Authorization -> Allocation Workflow.
"""

import pytest
import sqlite3
from app.core.database import get_db_connection, init_db
from app.core.config import settings
from app.services.ai_request_advisor import ai_request_advisor
from httpx import AsyncClient, ASGITransport
from app.main import app


@pytest.fixture(autouse=True)
def setup_test_database():
    """Ensure clean test database with required tables before running tests."""
    init_db()
    yield


# ============================================================================ #
# 1. CARD STATUTORY ENTITLEMENT & VALIDATION TESTS
# ============================================================================ #

def test_card_statutory_entitlement_derivation():
    """Verify that card types and family sizes map correctly to statutory ceilings."""
    conn = get_db_connection()
    try:
        # Beneficiary 10 (AAY card)
        aay_ent = ai_request_advisor.get_beneficiary_entitlement(conn, "BEN-KA-0010", "Rice")
        assert aay_ent["card_type"] == "AAY"
        assert aay_ent["statutory_entitlement_rice_kg"] == 25.0
        assert aay_ent["statutory_entitlement_wheat_kg"] == 10.0

        # Beneficiary 1 (PHH card)
        phh_ent = ai_request_advisor.get_beneficiary_entitlement(conn, "BEN-KA-0001", "Rice")
        assert phh_ent["card_type"] == "PHH"
        assert phh_ent["statutory_entitlement_rice_kg"] == 20.0
        assert phh_ent["statutory_entitlement_wheat_kg"] == 5.0
    finally:
        conn.close()


@pytest.mark.asyncio
async def test_over_entitlement_request_rejection():
    """Verify that citizen cannot request quantities wildly exceeding statutory limits (e.g. 100 kg)."""
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        cycle_id = "2026-09"

        # Submit 100 kg on a 20 kg entitlement card -> Must be rejected with 422
        bad_payload = {
            "beneficiary_id": "BEN-KA-0001",
            "cycle_id": cycle_id,
            "intended_fps_id": "FPS-KA-BLR-001",
            "commodity": "Rice",
            "declared_quantity_kg": 100.0,
            "confidence": 0.95
        }
        res = await ac.post("/api/intent", json=bad_payload)
        assert res.status_code == 422
        assert "exceeds statutory monthly entitlement ceiling" in res.json()["detail"].lower()


# ============================================================================ #
# 2. AI DECISION-SUPPORT ADVISOR TESTS
# ============================================================================ #

def test_ai_advisor_healthy_shop_recommendation():
    """Verify that a request within quota to a well-stocked FPS yields APPROVE."""
    conn = get_db_connection()
    try:
        eval_res = ai_request_advisor.evaluate_request(
            conn,
            beneficiary_id="BEN-KA-0001",
            intended_fps_id="FPS-KA-BLR-001",
            commodity="Rice",
            requested_quantity_kg=20.0,
            cycle_id="2026-09"
        )

        assert eval_res["ai_assessment"]["recommendation"] in ["APPROVE", "PARTIAL_ALLOCATION"]
        assert eval_res["ai_assessment"]["is_advisory"] is True
        assert len(eval_res["ai_assessment"]["factors"]) >= 3
        assert "Statutory Quota Verified" in eval_res["ai_assessment"]["factors"][0]
    finally:
        conn.close()


def test_ai_advisor_quota_capping_factor():
    """Verify that when requested qty is slightly above normal monthly quota, AI caps to statutory limit."""
    conn = get_db_connection()
    try:
        eval_res = ai_request_advisor.evaluate_request(
            conn,
            beneficiary_id="BEN-KA-0001",
            intended_fps_id="FPS-KA-BLR-001",
            commodity="Rice",
            requested_quantity_kg=25.0,  # 5kg above 20kg ceiling for PHH
            cycle_id="2026-09"
        )

        assert eval_res["ai_assessment"]["recommendation"] == "PARTIAL_ALLOCATION"
        assert eval_res["ai_assessment"]["recommended_quantity_kg"] == 20.0
        assert "Statutory Entitlement Cap" in eval_res["ai_assessment"]["factors"][0]
    finally:
        conn.close()


# ============================================================================ #
# 3. CITIZEN REQUEST CREATION & QUEUE LINKAGE TESTS
# ============================================================================ #

@pytest.mark.asyncio
async def test_citizen_intent_populates_review_queue():
    """Verify that POST /api/intent automatically creates a record in citizen_requests queue with AI analysis."""
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        cycle_id = "2026-09"
        ben_id = "BEN-KA-0002"

        # Submit valid citizen request
        req_payload = {
            "beneficiary_id": ben_id,
            "cycle_id": cycle_id,
            "intended_fps_id": "FPS-KA-BLR-004",
            "commodity": "Rice",
            "declared_quantity_kg": 20.0,
            "confidence": 0.95
        }
        submit_res = await ac.post("/api/intent", json=req_payload)
        assert submit_res.status_code == 201

        # Query Officer Review Queue
        queue_res = await ac.get(f"/api/admin/citizen-requests?cycle_id={cycle_id}")
        assert queue_res.status_code == 200
        data = queue_res.json()
        assert data["total_count"] > 0

        # Find our submitted request
        matching = [it for it in data["items"] if it["beneficiary_id"] == ben_id and it["commodity"] == "Rice"]
        assert len(matching) >= 1
        req_item = matching[0]
        assert req_item["status"] in ["PENDING_OFFICER_REVIEW", "OFFICER_APPROVED"]
        assert req_item["ai_recommendation"] is not None
        assert req_item["requested_quantity_kg"] == 20.0


# ============================================================================ #
# 4. OFFICER AUTHORIZATION & AUDIT TRAIL TESTS
# ============================================================================ #

@pytest.mark.asyncio
async def test_officer_authorization_role_guards():
    """Verify that unauthorized roles cannot authorize citizen requests."""
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        cycle_id = "2026-09"
        queue_res = await ac.get(f"/api/admin/citizen-requests?cycle_id={cycle_id}")
        assert queue_res.status_code == 200
        req_id = queue_res.json()["items"][0]["request_id"]

        # Unauthorized citizen role
        bad_auth = {
            "officer_name": "Citizen Attacker",
            "officer_role": "CITIZEN_USER",
            "decision": "APPROVE",
            "officer_justification": "Trying unauthorized approval"
        }
        res_bad = await ac.post(f"/api/admin/citizen-requests/{req_id}/authorize", json=bad_auth)
        assert res_bad.status_code == 403


@pytest.mark.asyncio
async def test_officer_full_approval_workflow():
    """Verify authorized officer full approval updates status, synchronizes intent, and writes audit event."""
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        cycle_id = "2026-09"
        queue_res = await ac.get(f"/api/admin/citizen-requests?cycle_id={cycle_id}")
        assert queue_res.status_code == 200
        req_id = queue_res.json()["items"][0]["request_id"]

        # Authorized DSO approval
        good_auth = {
            "officer_name": "K. Srinivas Murthy",
            "officer_role": "DISTRICT_SUPPLY_OFFICER",
            "decision": "APPROVE",
            "officer_justification": "Verified within NFSA statutory quota and FPS headroom"
        }
        auth_res = await ac.post(f"/api/admin/citizen-requests/{req_id}/authorize", json=good_auth)
        assert auth_res.status_code == 200
        auth_data = auth_res.json()
        assert auth_data["approval_status"] == "OFFICER_APPROVED"
        assert auth_data["officer_name"] == "K. Srinivas Murthy"
        assert auth_data["officer_role"] == "DISTRICT_SUPPLY_OFFICER"

        # Verify audit log in database
        conn = get_db_connection()
        try:
            cursor = conn.cursor()
            cursor.execute("SELECT * FROM governance_audit_logs WHERE action = 'CITIZEN_REQUEST_AUTHORIZED' ORDER BY id DESC LIMIT 1;")
            audit_row = cursor.fetchone()
            assert audit_row is not None
            assert audit_row["actor_role"] == "DISTRICT_SUPPLY_OFFICER"
            assert "OFFICER_APPROVED" in audit_row["notes"]
        finally:
            conn.close()


@pytest.mark.asyncio
async def test_officer_partial_and_redirect_workflows():
    """Verify officer partial allocation and alternative FPS redirection decisions."""
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        cycle_id = "2026-09"
        queue_res = await ac.get(f"/api/admin/citizen-requests?cycle_id={cycle_id}")
        items = queue_res.json()["items"]
        assert len(items) >= 2

        # 1. Test Partial Allocation
        req_1 = items[0]["request_id"]
        part_auth = {
            "officer_name": "K. Srinivas Murthy",
            "officer_role": "DISTRICT_SUPPLY_OFFICER",
            "decision": "PARTIAL_ALLOCATION",
            "allocated_quantity_kg": 15.0,
            "officer_justification": "Adjusted to 15kg for local storage equilibrium"
        }
        res_part = await ac.post(f"/api/admin/citizen-requests/{req_1}/authorize", json=part_auth)
        assert res_part.status_code == 200
        assert res_part.json()["approval_status"] == "OFFICER_PARTIAL_APPROVED"
        assert res_part.json()["authorized_quantity_kg"] == 15.0

        # 2. Test FPS Redirection
        req_2 = items[1]["request_id"]
        redir_auth = {
            "officer_name": "Basavaraj V.",
            "officer_role": "DEPOT_MANAGER",
            "decision": "REDIRECT_ALTERNATIVE_FPS",
            "allocated_fps_id": "FPS-KA-BLR-004",
            "allocated_quantity_kg": 20.0,
            "officer_justification": "Redirected to Rajajinagar FPS due to congestion at target shop"
        }
        res_redir = await ac.post(f"/api/admin/citizen-requests/{req_2}/authorize", json=redir_auth)
        assert res_redir.status_code == 200
        assert res_redir.json()["approval_status"] == "OFFICER_REDIRECTED"
        assert res_redir.json()["allocated_fps_id"] == "FPS-KA-BLR-004"


@pytest.mark.asyncio
async def test_officer_rejection_and_deferral_workflows():
    """Verify officer explicit rejection and deferral decisions with mandatory justification."""
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        cycle_id = "2026-09"
        queue_res = await ac.get(f"/api/admin/citizen-requests?cycle_id={cycle_id}")
        items = queue_res.json()["items"]
        assert len(items) >= 3

        # 1. Test Rejection
        req_reject = items[2]["request_id"]
        reject_payload = {
            "officer_name": "K. Srinivas Murthy",
            "officer_role": "DISTRICT_SUPPLY_OFFICER",
            "decision": "REJECT",
            "officer_justification": "Duplicate submission detected during cross-verification"
        }
        res_rej = await ac.post(f"/api/admin/citizen-requests/{req_reject}/authorize", json=reject_payload)
        assert res_rej.status_code == 200
        assert res_rej.json()["approval_status"] == "REJECTED"

        # 2. Test Deferral
        if len(items) >= 4:
            req_defer = items[3]["request_id"]
            defer_payload = {
                "officer_name": "Basavaraj V.",
                "officer_role": "DEPOT_MANAGER",
                "decision": "DEFER_TO_CYCLE",
                "officer_justification": "Deferred to cycle 2026-10 pending address verification"
            }
            res_def = await ac.post(f"/api/admin/citizen-requests/{req_defer}/authorize", json=defer_payload)
            assert res_def.status_code == 200
            assert res_def.json()["approval_status"] == "OFFICER_DEFERRED"


def test_ai_advisor_alternative_fps_search():
    """Verify that when a target FPS has low stock or high stockout risk, advisor finds alternative FPS within 5km."""
    conn = get_db_connection()
    try:
        # Evaluate request for a simulated stressed FPS
        eval_res = ai_request_advisor.evaluate_request(
            conn,
            beneficiary_id="BEN-KA-0005",
            intended_fps_id="FPS-KA-BLR-003",
            commodity="Rice",
            requested_quantity_kg=20.0,
            cycle_id="2026-09"
        )
        assert "target_fps" in eval_res
        assert "statutory_floor_kg" in eval_res["target_fps"]
        assert "capacity_headroom_kg" in eval_res["target_fps"]
        assert eval_res["ai_assessment"]["is_advisory"] is True
        assert eval_res["ai_assessment"]["risk_level"] in ["LOW", "ELEVATED", "HIGH", "CRITICAL"]
    finally:
        conn.close()


@pytest.mark.asyncio
async def test_transparent_metrics_in_citizen_request_queue():
    """Verify that GET /api/admin/citizen-requests returns all transparent operational metrics."""
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        res = await ac.get("/api/admin/citizen-requests?cycle_id=2026-09")
        assert res.status_code == 200
        data = res.json()
        assert len(data["items"]) > 0
        first = data["items"][0]

        # Verify all transparent diagnostic fields are present
        assert "requested_quantity_kg" in first
        assert "statutory_entitlement_commodity_kg" in first
        assert "current_inventory_kg" in first
        assert "statutory_floor_kg" in first
        assert "pending_demand_kg" in first
        assert "fps_capacity_kg" in first
        assert "capacity_headroom_kg" in first
        assert "replenishment_eta" in first
        assert "ai_recommendation" in first
        assert "ai_risk_level" in first
        assert "ai_factors" in first
        assert isinstance(first["ai_factors"], list)


@pytest.mark.asyncio
async def test_citizen_entitlement_summary_and_authoritative_calculation():
    """Verify GET /api/beneficiary/{id}/entitlement-summary provides complete government quota metadata."""
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        res = await ac.get("/api/beneficiary/BEN-KA-0001/entitlement-summary?cycle_id=2026-09")
        assert res.status_code == 200
        data = res.json()

        assert data["beneficiary_id"] == "BEN-KA-0001"
        assert data["card_type"] == "PHH"
        assert data["statutory_entitlement_rice_kg"] == 20.0
        assert data["statutory_entitlement_wheat_kg"] == 5.0
        assert data["total_eligible_balance_kg"] == 25.0
        assert "transport_policy" in data


@pytest.mark.asyncio
async def test_home_delivery_transparent_fee_calculation():
    """Verify home delivery transport fees are calculated accurately based on distance with zero commodity price."""
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        payload = {
            "beneficiary_id": "BEN-KA-0003",
            "cycle_id": "2026-09",
            "intended_fps_id": "FPS-KA-BLR-001",
            "commodity": "Rice",
            "delivery_mode": "HOME_DELIVERY",
            "delivery_address": "Flat 402, Green Glen Layout, Bengaluru",
            "delivery_distance_km": 4.5
        }
        res = await ac.post("/api/intent", json=payload)
        assert res.status_code == 201
        data = res.json()

        assert data["delivery_mode"] == "HOME_DELIVERY"
        assert data["delivery_distance_km"] == 4.5
        # Base fee 20 + (4.5 - 2.0)*5 = 20 + 12.5 = 32.5 INR
        assert data["transport_fee_inr"] == 32.5
        assert data["declared_quantity_kg"] == 20.0  # Server-calculated statutory ceiling


@pytest.mark.asyncio
async def test_citizen_delivery_confirmation_and_dispute_workflow():
    """Verify full delivery confirmation and dispute resolution lifecycle."""
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        ben_id = "BEN-KA-0004"
        cycle_id = "2026-09"

        # 1. Submit preference
        init_res = await ac.post("/api/intent", json={
            "beneficiary_id": ben_id,
            "cycle_id": cycle_id,
            "intended_fps_id": "FPS-KA-BLR-002",
            "commodity": "Rice",
            "delivery_mode": "HOME_DELIVERY",
            "delivery_distance_km": 3.0
        })
        assert init_res.status_code == 201
        req_id = f"REQ-{cycle_id}-{ben_id.split('-')[-1]}-R"

        # 2. Authorize by officer
        auth_res = await ac.post(f"/api/admin/citizen-requests/{req_id}/authorize", json={
            "officer_name": "K. Srinivas Murthy",
            "officer_role": "DISTRICT_SUPPLY_OFFICER",
            "decision": "APPROVE",
            "allocated_quantity_kg": 20.0,
            "officer_justification": "Approved full statutory home delivery"
        })
        assert auth_res.status_code == 200

        # 3. Citizen raises a Delivery Dispute due to shortfall (e.g. received 15kg instead of 20kg)
        dispute_payload = {
            "request_id": req_id,
            "confirmation_status": "DELIVERY_DISPUTE",
            "received_rice_kg": 15.0,
            "received_wheat_kg": 0.0,
            "dispute_notes": "Received 15kg rice in package instead of 20kg statutory allocation."
        }
        disp_res = await ac.post(f"/api/beneficiary/{ben_id}/confirm-delivery", json=dispute_payload)
        assert disp_res.status_code == 200
        disp_data = disp_res.json()
        assert disp_data["status"] == "DELIVERY_DISPUTE"
        assert disp_data["shortfall_kg"] == 5.0
        dispute_id = disp_data["dispute_id"]

        # 4. Officer reviews Dispute Queue
        disputes_queue = await ac.get(f"/api/admin/delivery-disputes?cycle_id={cycle_id}")
        assert disputes_queue.status_code == 200
        dispute_items = disputes_queue.json()
        assert len(dispute_items) > 0
        matching = [d for d in dispute_items if d["dispute_id"] == dispute_id]
        assert len(matching) == 1
        assert matching[0]["shortfall_kg"] == 5.0

        # 5. Officer Resolves Dispute with supplementary allocation directive
        resolve_payload = {
            "officer_name": "K. Srinivas Murthy (DSO)",
            "officer_role": "DISTRICT_SUPPLY_OFFICER",
            "decision": "OFFICER_RESOLVED",
            "resolution_notes": "Weighment error verified at depot. 5.0 kg supplementary dispatch voucher issued."
        }
        res_resolve = await ac.post(f"/api/admin/delivery-disputes/{dispute_id}/resolve", json=resolve_payload)
        assert res_resolve.status_code == 200
        assert res_resolve.json()["status"] == "success"
        assert res_resolve.json()["decision"] == "OFFICER_RESOLVED"


