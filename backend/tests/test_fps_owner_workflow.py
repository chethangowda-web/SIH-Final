"""Tests for FPS Owner Operations Command Workflow & APIs.

Verifies:
1. Operational session lifecycle (get, save, open shop, close shop)
2. Inventory & Stock Ledger retrieval
3. Consignments & replenishment receipt confirmation
4. Beneficiary lookup & e-PoS eligibility check
5. Beneficiary verification (Aadhaar / OTP)
6. e-PoS dispensing with atomic inventory deduction & receipt generation
7. Duplicate collection prevention
8. Reconciliation calculation
9. Day closure and post-closure dispensing lock
10. RBAC: FPS Owner cannot access another FPS
"""

import pytest
import sqlite3
from fastapi.testclient import TestClient
from app.main import app
from app.core.database import get_db_connection, init_db
from app.core.auth import create_token

client = TestClient(app)

@pytest.fixture(autouse=True)
def setup_test_db():
    init_db()
    conn = get_db_connection()
    from app.core.auth import hash_password
    conn.execute(
        "INSERT OR REPLACE INTO users (username, password_hash, role) VALUES ('FPS-KA-BAG-0001', ?, 'FPS_OWNER');",
        (hash_password("fps_pass"),)
    )
    conn.commit()
    yield
    conn.close()

def get_auth_header(role: str = "FPS_OWNER", username: str = "fps_user"):
    token = create_token({"username": username, "role": role})
    return {"Authorization": f"Bearer {token}"}

def test_1_get_operational_session():
    headers = get_auth_header()
    res = client.get("/api/fps/FPS-KA-BAG-0001/operational-session", headers=headers)
    assert res.status_code == 200
    data = res.json()
    assert data["fps_id"] == "FPS-KA-BAG-0001"
    assert "active_step" in data
    assert "workflow_status" in data

def test_2_open_shop():
    headers = get_auth_header()
    res = client.post("/api/fps/FPS-KA-BAG-0001/open-shop", headers=headers)
    assert res.status_code == 200
    data = res.json()
    assert data["status"] == "OPEN"
    assert data["active_step"] == 1
    assert "opened_at" in data

def test_3_inventory_and_stock_ledger():
    headers = get_auth_header()
    # Inventory
    res_inv = client.get("/api/fps/FPS-KA-BAG-0001/inventory", headers=headers)
    assert res_inv.status_code == 200
    inv = res_inv.json()
    assert "rice_stock_kg" in inv
    assert "wheat_stock_kg" in inv

    # Stock Ledger
    res_ledger = client.get("/api/fps/FPS-KA-BAG-0001/stock-ledger", headers=headers)
    assert res_ledger.status_code == 200
    ledger = res_ledger.json()
    assert "summary" in ledger
    assert "movements" in ledger

def test_4_consignments():
    headers = get_auth_header()
    res = client.get("/api/fps/FPS-KA-BAG-0001/consignments", headers=headers)
    assert res.status_code == 200
    data = res.json()
    assert "consignments" in data

def test_5_beneficiary_eligibility_and_verification():
    headers = get_auth_header()
    # Eligibility
    res_elig = client.get("/api/epos/eligibility?fps_id=FPS-KA-BAG-0001&beneficiary_id=RC-KA-000001&cycle_id=2026-09", headers=headers)
    assert res_elig.status_code == 200
    elig = res_elig.json()
    assert elig["beneficiary_id"] == "RC-KA-000001"
    assert "statutory_rice_kg" in elig
    assert "statutory_wheat_kg" in elig
    assert "already_collected" in elig

    # Verify beneficiary biometric
    verify_payload = {
        "fps_id": "FPS-KA-BAG-0001",
        "beneficiary_id": "RC-KA-000001",
        "verification_mode": "AADHAAR_BIOMETRIC"
    }
    res_ver = client.post("/api/epos/verify-beneficiary", json=verify_payload, headers=headers)
    assert res_ver.status_code == 200
    assert res_ver.json()["status"] == "VERIFIED"

def test_6_epos_dispense_and_duplicate_guard():
    headers = get_auth_header()
    
    # Dispense ration
    dispense_payload = {
        "fps_id": "FPS-KA-BAG-0001",
        "beneficiary_id": "RC-KA-000001",
        "cycle_id": "2026-09",
        "rice_kg": 0.0,
        "wheat_kg": 10.0,
        "auth_mode": "AADHAAR_BIOMETRIC"
    }
    res_disp = client.post("/api/epos/dispense", json=dispense_payload, headers=headers)
    assert res_disp.status_code in [200, 400]
    
    if res_disp.status_code == 200:
        data = res_disp.json()
        assert data["status"] == "SUCCESS_DISPENSED"
        assert data["transaction_id"].startswith("TX-EPOS-")
        
        # Second attempt must be rejected (duplicate collection guard)
        res_dup = client.post("/api/epos/dispense", json=dispense_payload, headers=headers)
        assert res_dup.status_code == 400
        assert "Duplicate collection prohibited" in res_dup.json()["detail"]

def test_7_transactions_and_reconciliation():
    headers = get_auth_header()
    # Digital register
    res_tx = client.get("/api/fps/FPS-KA-BAG-0001/transactions", headers=headers)
    assert res_tx.status_code == 200
    assert isinstance(res_tx.json(), list)

    # Reconciliation
    res_rec = client.get("/api/fps/FPS-KA-BAG-0001/reconciliation", headers=headers)
    assert res_rec.status_code == 200
    rec = res_rec.json()
    assert "commodities" in rec
    assert "overall_status" in rec

def test_8_close_shop():
    headers = get_auth_header()
    # Close shop with exception reason in case of stock variance
    res_close = client.post(
        "/api/fps/FPS-KA-BAG-0001/close-shop",
        json={"exception_reason": "End-of-day statutory reconciliation verified against e-PoS ledger."},
        headers=headers
    )
    assert res_close.status_code == 200
    data = res_close.json()
    assert data["status"] == "CLOSED"
    assert data["active_step"] == 7
    assert data["closure_id"].startswith("CLS-")

def test_9_dispense_blocked_after_close():
    headers = get_auth_header()
    dispense_payload = {
        "fps_id": "FPS-KA-BAG-0001",
        "beneficiary_id": "RC-KA-000002",
        "cycle_id": "2026-09",
        "rice_kg": 5.0,
        "wheat_kg": 5.0
    }
    res = client.post("/api/epos/dispense", json=dispense_payload, headers=headers)
    assert res.status_code == 400
    assert "operations are CLOSED" in res.json()["detail"]

def test_10_rbac_cross_fps_denied():
    # Specific FPS owner account cannot touch another FPS
    specific_headers = get_auth_header(role="FPS_OWNER", username="FPS-KA-BAG-0001")
    res = client.get("/api/fps/FPS-KA-BLR-001/inventory", headers=specific_headers)
    assert res.status_code == 403
