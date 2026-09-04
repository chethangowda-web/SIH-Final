"""Tests for PDS Business Rule:
Once a beneficiary has successfully received and confirmed their ration for the current cycle,
they cannot submit another foodgrain application/request for the same cycle.
"""
import pytest
import sqlite3
from httpx import AsyncClient, ASGITransport
from app.main import app
from app.core.database import get_db_connection, init_db
from app.data.seed_data import seed_all_data


@pytest.fixture(autouse=True)
def setup_test_db():
    """Ensure clean test database with required state before each test."""
    init_db()
    conn = get_db_connection()
    conn.execute("DELETE FROM demand_snapshots;")
    conn.execute("DELETE FROM planning_cycle_config;")
    conn.execute("INSERT OR REPLACE INTO planning_cycle_config (cycle_id, planning_day, is_manual_override, updated_at) VALUES ('2026-09', 22, 1, CURRENT_TIMESTAMP);")
    conn.execute("INSERT OR REPLACE INTO planning_cycle_config (cycle_id, planning_day, is_manual_override, updated_at) VALUES ('2026-10', 22, 1, CURRENT_TIMESTAMP);")
    conn.execute("DELETE FROM beneficiary_cycle_receipts;")
    conn.execute("DELETE FROM delivery_disputes WHERE beneficiary_id IN ('BEN-KA-0001', 'BEN-KA-0002', 'BEN-KA-0003', 'BEN-KA-0004');")
    conn.execute("DELETE FROM citizen_requests WHERE beneficiary_id IN ('BEN-KA-0001', 'BEN-KA-0002', 'BEN-KA-0003', 'BEN-KA-0004');")
    conn.execute("DELETE FROM intent WHERE beneficiary_id IN ('BEN-KA-0001', 'BEN-KA-0002', 'BEN-KA-0003', 'BEN-KA-0004');")
    conn.execute("DELETE FROM governance_audit_logs WHERE actor_name IN ('BEN-KA-0001', 'BEN-KA-0002', 'BEN-KA-0003', 'BEN-KA-0004');")
    conn.commit()
    conn.close()
    yield


@pytest.mark.asyncio
async def test_a_beneficiary_can_submit_before_receiving_ration():
    """A. Beneficiary can submit their allowed foodgrain request/preference before receiving ration."""
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        ben_id = "BEN-KA-0001"
        cycle_id = "2026-09"

        payload = {
            "beneficiary_id": ben_id,
            "cycle_id": cycle_id,
            "intended_fps_id": "FPS-KA-BLR-001",
            "commodity": "Rice",
            "delivery_mode": "FPS_COLLECTION",
            "declared_quantity_kg": 20.0,
            "confidence": 0.95
        }
        res = await ac.post("/api/intent", json=payload)
        assert res.status_code == 201, f"Expected 201 Created, got {res.status_code}: {res.text}"
        data = res.json()
        assert data["beneficiary_id"] == ben_id
        assert data["cycle_id"] == cycle_id
        assert data["commodity"] == "Rice"
        assert data["status"] == "SUBMITTED"


@pytest.mark.asyncio
async def test_b_beneficiary_can_confirm_receipt():
    """B. Beneficiary can confirm receipt of allocated ration."""
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        ben_id = "BEN-KA-0001"
        cycle_id = "2026-09"

        # 1. Submit initial intent
        submit_res = await ac.post("/api/intent", json={
            "beneficiary_id": ben_id,
            "cycle_id": cycle_id,
            "intended_fps_id": "FPS-KA-BLR-001",
            "commodity": "Rice",
            "delivery_mode": "FPS_COLLECTION"
        })
        assert submit_res.status_code == 201

        # 2. Get the created citizen_request
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("SELECT request_id FROM citizen_requests WHERE beneficiary_id = ? AND cycle_id = ?;", (ben_id, cycle_id))
        row = cursor.fetchone()
        assert row is not None
        req_id = row["request_id"]
        conn.close()

        # 3. Confirm delivery receipt
        confirm_payload = {
            "request_id": req_id,
            "confirmation_status": "DELIVERY_CONFIRMED",
            "received_rice_kg": 20.0,
            "received_wheat_kg": 0.0
        }
        conf_res = await ac.post(f"/api/beneficiary/{ben_id}/confirm-delivery", json=confirm_payload)
        assert conf_res.status_code == 200
        conf_data = conf_res.json()
        assert conf_data["status"] == "DELIVERY_CONFIRMED"

        # Verify durable receipt in database
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("SELECT * FROM beneficiary_cycle_receipts WHERE beneficiary_id = ? AND cycle_id = ?;", (ben_id, cycle_id))
        receipt_record = cursor.fetchone()
        assert receipt_record is not None
        assert receipt_record["status"] == "COMPLETED"
        assert receipt_record["received_rice_kg"] == 20.0

        # Verify intent is updated to COMPLETED
        cursor.execute("SELECT status FROM intent WHERE beneficiary_id = ? AND cycle_id = ?;", (ben_id, cycle_id))
        intent_row = cursor.fetchone()
        assert intent_row["status"] == "COMPLETED"
        conn.close()


@pytest.mark.asyncio
async def test_c_beneficiary_cannot_submit_another_request_in_same_cycle_after_receipt():
    """C. Beneficiary cannot submit another request in same cycle after receipt."""
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        ben_id = "BEN-KA-0001"
        cycle_id = "2026-09"

        # 1. Submit initial intent
        await ac.post("/api/intent", json={
            "beneficiary_id": ben_id,
            "cycle_id": cycle_id,
            "intended_fps_id": "FPS-KA-BLR-001",
            "commodity": "Rice"
        })

        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("SELECT request_id FROM citizen_requests WHERE beneficiary_id = ? AND cycle_id = ?;", (ben_id, cycle_id))
        req_id = cursor.fetchone()["request_id"]
        conn.close()

        # 2. Confirm delivery receipt
        await ac.post(f"/api/beneficiary/{ben_id}/confirm-delivery", json={
            "request_id": req_id,
            "confirmation_status": "DELIVERY_CONFIRMED",
            "received_rice_kg": 20.0
        })

        # 3. Attempt second submission in same cycle -> MUST be rejected with HTTP 400
        res_repeat = await ac.post("/api/intent", json={
            "beneficiary_id": ben_id,
            "cycle_id": cycle_id,
            "intended_fps_id": "FPS-KA-BLR-002",
            "commodity": "Rice",
            "delivery_mode": "HOME_DELIVERY"
        })
        assert res_repeat.status_code == 400
        detail = res_repeat.json()["detail"]
        assert "Ration already received for this cycle" in detail
        assert "next distribution cycle" in detail


@pytest.mark.asyncio
async def test_d_duplicate_receipt_confirmation_does_not_create_duplicate_state():
    """D. Duplicate receipt confirmation does not create duplicate state or events."""
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        ben_id = "BEN-KA-0001"
        cycle_id = "2026-09"

        # 1. Initial intent and request
        await ac.post("/api/intent", json={
            "beneficiary_id": ben_id,
            "cycle_id": cycle_id,
            "intended_fps_id": "FPS-KA-BLR-001",
            "commodity": "Rice"
        })

        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("SELECT request_id FROM citizen_requests WHERE beneficiary_id = ? AND cycle_id = ?;", (ben_id, cycle_id))
        req_id = cursor.fetchone()["request_id"]
        conn.close()

        # 2. First receipt confirmation
        first_conf = await ac.post(f"/api/beneficiary/{ben_id}/confirm-delivery", json={
            "request_id": req_id,
            "confirmation_status": "DELIVERY_CONFIRMED",
            "received_rice_kg": 20.0
        })
        assert first_conf.status_code == 200

        # Count audit log events and receipts
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("SELECT COUNT(*) FROM beneficiary_cycle_receipts WHERE beneficiary_id = ? AND cycle_id = ?;", (ben_id, cycle_id))
        receipts_count_1 = cursor.fetchone()[0]
        assert receipts_count_1 == 1

        cursor.execute("SELECT COUNT(*) FROM governance_audit_logs WHERE action = 'DELIVERY_CONFIRMED_BY_CITIZEN' AND entity_id = ?;", (req_id,))
        audit_count_1 = cursor.fetchone()[0]
        assert audit_count_1 == 1
        conn.close()

        # 3. Duplicate confirmation click
        second_conf = await ac.post(f"/api/beneficiary/{ben_id}/confirm-delivery", json={
            "request_id": req_id,
            "confirmation_status": "DELIVERY_CONFIRMED",
            "received_rice_kg": 20.0
        })
        assert second_conf.status_code == 200
        assert second_conf.json()["status"] == "DELIVERY_CONFIRMED"

        # Verify idempotency: No duplicate rows in beneficiary_cycle_receipts or governance_audit_logs
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("SELECT COUNT(*) FROM beneficiary_cycle_receipts WHERE beneficiary_id = ? AND cycle_id = ?;", (ben_id, cycle_id))
        receipts_count_2 = cursor.fetchone()[0]
        assert receipts_count_2 == 1, "Duplicate receipt record created!"

        cursor.execute("SELECT COUNT(*) FROM governance_audit_logs WHERE action = 'DELIVERY_CONFIRMED_BY_CITIZEN' AND entity_id = ?;", (req_id,))
        audit_count_2 = cursor.fetchone()[0]
        assert audit_count_2 == 1, "Duplicate audit event logged on duplicate confirmation!"
        conn.close()


@pytest.mark.asyncio
async def test_e_beneficiary_can_participate_again_after_new_cycle_starts():
    """E. Beneficiary can participate again after a new cycle starts (e.g. 2026-10)."""
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        ben_id = "BEN-KA-0001"
        cycle_current = "2026-09"
        cycle_next = "2026-10"

        # 1. Complete cycle 2026-09
        await ac.post("/api/intent", json={
            "beneficiary_id": ben_id,
            "cycle_id": cycle_current,
            "intended_fps_id": "FPS-KA-BLR-001",
            "commodity": "Rice"
        })

        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("SELECT request_id FROM citizen_requests WHERE beneficiary_id = ? AND cycle_id = ?;", (ben_id, cycle_current))
        req_id = cursor.fetchone()["request_id"]
        conn.close()

        await ac.post(f"/api/beneficiary/{ben_id}/confirm-delivery", json={
            "request_id": req_id,
            "confirmation_status": "DELIVERY_CONFIRMED",
            "received_rice_kg": 20.0
        })

        # 2. Blocked for 2026-09
        blocked_res = await ac.post("/api/intent", json={
            "beneficiary_id": ben_id,
            "cycle_id": cycle_current,
            "intended_fps_id": "FPS-KA-BLR-001",
            "commodity": "Rice"
        })
        assert blocked_res.status_code == 400

        # 3. Permitted for 2026-10
        next_cycle_res = await ac.post("/api/intent", json={
            "beneficiary_id": ben_id,
            "cycle_id": cycle_next,
            "intended_fps_id": "FPS-KA-BLR-002",
            "commodity": "Rice",
            "delivery_mode": "FPS_COLLECTION"
        })
        assert next_cycle_res.status_code == 201, f"Expected 201 for next cycle, got {next_cycle_res.status_code}: {next_cycle_res.text}"
        assert next_cycle_res.json()["cycle_id"] == cycle_next


@pytest.mark.asyncio
async def test_f_another_beneficiary_who_has_not_received_ration_is_unaffected():
    """F. Another beneficiary who has not received ration is unaffected."""
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        ben_1 = "BEN-KA-0001"
        ben_2 = "BEN-KA-0002"
        cycle_id = "2026-09"

        # 1. Beneficiary 1 receives ration
        await ac.post("/api/intent", json={
            "beneficiary_id": ben_1,
            "cycle_id": cycle_id,
            "intended_fps_id": "FPS-KA-BLR-001",
            "commodity": "Rice"
        })
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("SELECT request_id FROM citizen_requests WHERE beneficiary_id = ? AND cycle_id = ?;", (ben_1, cycle_id))
        req_id = cursor.fetchone()["request_id"]
        conn.close()

        await ac.post(f"/api/beneficiary/{ben_1}/confirm-delivery", json={
            "request_id": req_id,
            "confirmation_status": "DELIVERY_CONFIRMED",
            "received_rice_kg": 20.0
        })

        # Beneficiary 1 is blocked
        res_1 = await ac.post("/api/intent", json={
            "beneficiary_id": ben_1,
            "cycle_id": cycle_id,
            "intended_fps_id": "FPS-KA-BLR-001",
            "commodity": "Rice"
        })
        assert res_1.status_code == 400

        # Beneficiary 2 (has not received ration) can submit successfully
        res_2 = await ac.post("/api/intent", json={
            "beneficiary_id": ben_2,
            "cycle_id": cycle_id,
            "intended_fps_id": "FPS-KA-BLR-004",
            "commodity": "Rice",
            "delivery_mode": "HOME_DELIVERY",
            "delivery_distance_km": 2.5
        })
        assert res_2.status_code == 201
        assert res_2.json()["beneficiary_id"] == ben_2


@pytest.mark.asyncio
async def test_g_direct_api_attempt_after_receipt_is_rejected():
    """G. Direct API attempt after receipt (with modified payload, different shop, different commodity) is rejected."""
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        ben_id = "BEN-KA-0003"
        cycle_id = "2026-09"

        # 1. Initial submission and confirmation
        await ac.post("/api/intent", json={
            "beneficiary_id": ben_id,
            "cycle_id": cycle_id,
            "intended_fps_id": "FPS-KA-BLR-001",
            "commodity": "Rice"
        })
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("SELECT request_id FROM citizen_requests WHERE beneficiary_id = ? AND cycle_id = ?;", (ben_id, cycle_id))
        req_id = cursor.fetchone()["request_id"]
        conn.close()

        await ac.post(f"/api/beneficiary/{ben_id}/confirm-delivery", json={
            "request_id": req_id,
            "confirmation_status": "DELIVERY_CONFIRMED",
            "received_rice_kg": 20.0
        })

        # 2. Attacker / beneficiary attempts direct API call with Wheat
        direct_payload_wheat = {
            "beneficiary_id": ben_id,
            "cycle_id": cycle_id,
            "intended_fps_id": "FPS-KA-BLR-005",
            "commodity": "Wheat",
            "declared_quantity_kg": 5.0,
            "delivery_mode": "HOME_DELIVERY",
            "delivery_distance_km": 1.0
        }
        res_wheat = await ac.post("/api/intent", json=direct_payload_wheat)
        assert res_wheat.status_code == 400
        assert "Ration already received for this cycle" in res_wheat.json()["detail"]

        # 3. Entitlement summary accurately reflects backend truth
        summary_res = await ac.get(f"/api/beneficiary/{ben_id}/entitlement-summary?cycle_id={cycle_id}")
        assert summary_res.status_code == 200
        summary_data = summary_res.json()
        assert summary_data["ration_received_for_cycle"] is True
        assert summary_data["receipt_confirmed_at"] is not None
        assert summary_data["receipt_status_label"] == "Ration Received — Wait for Next Cycle"
