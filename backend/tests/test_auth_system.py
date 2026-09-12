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
