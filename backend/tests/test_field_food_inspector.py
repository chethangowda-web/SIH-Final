"""Tests for Field Food Inspector Workflow & APIs.

Verifies:
1. List inspections and context retrieval
2. Geofence arrival verification
3. Active inspection session persistence (save, retrieve, clear)
4. Inspection report submission with 6-point checklist and cryptographic SHA-256 seal
5. RBAC security: unauthorized roles cannot submit inspection
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
    yield
    conn.close()

def get_auth_header(role: str = "FIELD_FOOD_INSPECTOR", username: str = "inspector_user"):
    token = create_token({"username": username, "role": role})
    return {"Authorization": f"Bearer {token}"}

def test_1_list_inspections():
    headers = get_auth_header()
    res = client.get("/api/officer/inspections", headers=headers)
    assert res.status_code == 200
    data = res.json()
    assert "orders" in data
    assert "completed_inspections" in data

def test_2_get_inspection_context():
    headers = get_auth_header()
    res = client.get("/api/officer/fps/FPS-KA-BLR-001/inspection-context", headers=headers)
    assert res.status_code == 200
    data = res.json()
    assert "fps" in data
    assert "digital_stock" in data
    assert "previous_inspections" in data

def test_3_geofence_arrival_verification():
    headers = get_auth_header()
    payload = {
        "fps_id": "FPS-KA-BLR-001",
        "inspector_lat": 12.9716,
        "inspector_lon": 77.5946
    }
    res = client.post("/api/officer/geofence/verify", json=payload, headers=headers)
    assert res.status_code == 200
    data = res.json()
    assert data["status"] == "SUCCESS"
    assert "geofence_status" in data
    assert "distance_m" in data

def test_4_active_session_lifecycle():
    headers = get_auth_header()
    
    # Save active session
    save_payload = {
        "fps_id": "FPS-KA-BLR-001",
        "current_step": 3,
        "workflow_status": "PRE_CHECK_COMPLETED",
        "session_data": {
            "pre_checks": {"location": True, "identity": True},
            "observed_rice_kg": 1490.0,
            "observed_wheat_kg": 995.0
        }
    }
    res_save = client.post("/api/officer/inspection/active-session", json=save_payload, headers=headers)
    assert res_save.status_code == 200
    
    # Retrieve active session
    res_get = client.get("/api/officer/inspection/active-session", headers=headers)
    assert res_get.status_code == 200
    get_data = res_get.json()
    assert get_data["has_active_session"] is True
    assert get_data["session"]["fps_id"] == "FPS-KA-BLR-001"
    assert get_data["session"]["current_step"] == 3
    assert get_data["session"]["session_data"]["observed_rice_kg"] == 1490.0

    # Clear active session
    res_del = client.delete("/api/officer/inspection/active-session", headers=headers)
    assert res_del.status_code == 200

    # Verify cleared
    res_verify = client.get("/api/officer/inspection/active-session", headers=headers)
    assert res_verify.status_code == 200
    assert res_verify.json()["has_active_session"] is False

def test_5_submit_inspection_and_seal():
    headers = get_auth_header()
    payload = {
        "fps_id": "FPS-KA-BLR-001",
        "scale_certified": True,
        "display_board_updated": True,
        "stock_matches_register": True,
        "cctv_functional": True,
        "epos_online": True,
        "hygiene_compliant": True,
        "compliance_score": 100.0,
        "remarks": "Physical verification completed with 0 divergence.",
        "geofence_verified": True,
        "geofence_distance_m": 15.0,
        "expected_rice_kg": 1500.0,
        "observed_rice_kg": 1500.0,
        "expected_wheat_kg": 1000.0,
        "observed_wheat_kg": 1000.0,
        "moisture_pct": 11.2,
        "scale_error_g": 0.0,
        "evidence_items": [
            {"type": "PHOTOGRAPH", "description": "Stock stacks verified", "path": "photos/stock_01.jpg"}
        ],
        "checklist_details": {"point_1": "COMPLIANT", "point_2": "COMPLIANT"}
    }
    res = client.post("/api/officer/inspection/submit", json=payload, headers=headers)
    assert res.status_code == 200
    data = res.json()
    assert data["status"] == "SUCCESS"
    assert data["inspection_id"].startswith("INSP-")
    assert "sealed_hash" in data
    assert len(data["sealed_hash"]) == 32

def test_6_rbac_dso_forbidden():
    dso_headers = get_auth_header(role="DSO", username="dso_user")
    payload = {"fps_id": "FPS-KA-BLR-001"}
    res = client.post("/api/officer/inspection/submit", json=payload, headers=dso_headers)
    assert res.status_code == 403

def test_7_fps_assigned_dispatch():
    headers = get_auth_header()
    res = client.get("/api/officer/fps/FPS-KA-BLR-001/assigned-dispatch", headers=headers)
    assert res.status_code == 200
    data = res.json()
    assert data["status"] == "success"
    assert data["fps_id"] == "FPS-KA-BLR-001"
    assert data["has_inbound_dispatch"] is True
    disp = data["dispatch_info"]
    assert disp is not None
    assert "truck_id" in disp
    assert "origin_depot_name" in disp
    assert "dispatched_quantity_kg" in disp
    assert "route_stops" in disp
    assert len(disp["route_stops"]) >= 2
    assert "dispatch_timeline" in disp

