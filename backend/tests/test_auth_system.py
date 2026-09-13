"""Unit and Integration Tests for PDS DemandSync Authentication & RBAC System."""

import pytest
from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)

def test_admin_login_success():
    """Test login with valid admin credentials."""
    response = client.post(
        "/api/auth/login",
        json={"username": "admin_user", "password": "admin_pass"}
    )
    assert response.status_code == 200
    data = response.json()
    assert "access_token" in data
    assert "refresh_token" in data
    assert data["role"] == "ADMIN"
    assert data["token_type"] == "bearer"

def test_login_invalid_credentials():
    """Test login with invalid password returns 401 Unauthorized."""
    response = client.post(
        "/api/auth/login",
        json={"username": "admin_user", "password": "wrong_password"}
    )
    assert response.status_code == 401
    assert "Incorrect username or password" in response.json()["detail"]

def test_citizen_send_otp():
    """Test sending OTP for valid citizen Ration Card."""
    response = client.post(
        "/api/auth/citizen/send-otp",
        json={"card_id": "BEN-KA-0001"}
    )
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "success"
    assert data["card_id"] == "BEN-KA-0001"
    assert "demo_otp_code" in data

def test_citizen_verify_otp_success():
    """Test citizen OTP verification returns access token."""
    response = client.post(
        "/api/auth/citizen/verify-otp",
        json={"card_id": "BEN-KA-0001", "otp_code": "123456"}
    )
    assert response.status_code == 200
    data = response.json()
    assert "access_token" in data
    assert data["role"] == "BENEFICIARY"
    assert data["beneficiary_id"] == "BEN-KA-0001"

def test_token_refresh():
    """Test exchanging refresh token for new access token."""
    login_res = client.post(
        "/api/auth/login",
        json={"username": "admin_user", "password": "admin_pass"}
    )
    refresh_token = login_res.json()["refresh_token"]

    response = client.post(
        "/api/auth/refresh",
        json={"refresh_token": refresh_token}
    )
    assert response.status_code == 200
    data = response.json()
    assert "access_token" in data
    assert data["token_type"] == "bearer"

def test_authenticated_me_endpoint():
    """Test GET /api/auth/me returns current user profile when authenticated."""
    login_res = client.post(
        "/api/auth/login",
        json={"username": "admin_user", "password": "admin_pass"}
    )
    token = login_res.json()["access_token"]

    response = client.get(
        "/api/auth/me",
        headers={"Authorization": f"Bearer {token}"}
    )
    assert response.status_code == 200
    data = response.json()
    assert data["username"] == "admin_user"
    assert data["role"] == "ADMIN"

def test_role_based_least_privilege_field_officer():
    """Verify Field Officer has gatepass rights but is blocked from forecast/policy overrides."""
    # 1. Login as Field Officer
    login_res = client.post(
        "/api/auth/login",
        json={"username": "field_officer_user", "password": "field_pass"}
    )
    assert login_res.status_code == 200
    fo_token = login_res.json()["access_token"]
    assert login_res.json()["role"] == "FIELD_OFFICER"

    headers = {"Authorization": f"Bearer {fo_token}"}

    # 2. Field Officer CAN read gatepasses
    gp_res = client.get("/api/admin/gatepasses?cycle_id=2026-09", headers=headers)
    assert gp_res.status_code == 200

    # 3. Field Officer CANNOT lock forecast (Least privilege -> 403 Forbidden)
    lock_res = client.post(
        "/api/admin/forecast/lock",
        json={"cycle_id": "2026-09", "reason": "Attempt by field officer"},
        headers=headers
    )
    assert lock_res.status_code == 403
    assert "restricted to DSO or ADMIN" in lock_res.json()["detail"]

    # 4. Field Officer CANNOT override quotas (Least privilege -> 403 Forbidden)
    override_res = client.post(
        "/api/admin/fps/FPS-KA-BLR-001/override",
        json={"override_rice_kg": 9999.0, "reason": "Unauthorized"},
        headers=headers
    )
    assert override_res.status_code == 403

def test_role_based_dso_and_auditor_permissions():
    """Verify DSO can lock forecasts and Auditor has read-only access."""
    # DSO login
    dso_login = client.post(
        "/api/auth/login",
        json={"username": "dso_user", "password": "dso_pass"}
    )
    assert dso_login.status_code == 200
    dso_token = dso_login.json()["access_token"]
    assert dso_login.json()["role"] == "DSO"

    # Auditor login
    aud_login = client.post(
        "/api/auth/login",
        json={"username": "auditor_user", "password": "auditor_pass"}
    )
    assert aud_login.status_code == 200
    aud_token = aud_login.json()["access_token"]
    assert aud_login.json()["role"] == "AUDITOR"

    # Auditor CANNOT advance gatepass (Read-only -> 403)
    aud_advance = client.post(
        "/api/admin/gatepass/GP-2026-09-001/advance?target_status=WAREHOUSE_VERIFIED",
        headers={"Authorization": f"Bearer {aud_token}"}
    )
    assert aud_advance.status_code == 403

