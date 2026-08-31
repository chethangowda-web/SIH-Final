import pytest
import httpx
from app.main import app
from app.core.database import get_db_connection, init_db
from app.data.seed_data import seed_all_data

@pytest.fixture(autouse=True)
def disable_auth_mock(monkeypatch):
    """Disable the testing auth mock for these specific authentication tests."""
    monkeypatch.setenv("PDS_TEST_AUTH_MOCK", "0")

@pytest.fixture(autouse=True)
def setup_database():
    """Ensure database is seeded and users exist before each test."""
    init_db()
    seed_all_data(recreate=False)

@pytest.mark.asyncio
async def test_login_success():
    """Verify successful authentication with correct credentials."""
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        # 1. DSO login
        payload = {"username": "dso_user", "password": "dso_pass"}
        res = await client.post("/api/auth/login", json=payload)
        assert res.status_code == 200
        data = res.json()
        assert "access_token" in data
        assert data["role"] == "DSO"

        # 2. Beneficiary login
        payload = {"username": "BEN-KA-0001", "password": "citizen_pass"}
        res = await client.post("/api/auth/login", json=payload)
        assert res.status_code == 200
        data = res.json()
        assert "access_token" in data
        assert data["role"] == "BENEFICIARY"
        assert data["beneficiary_id"] == "BEN-KA-0001"

@pytest.mark.asyncio
async def test_login_failure():
    """Verify authentication failure with incorrect credentials."""
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        payload = {"username": "dso_user", "password": "wrong_password"}
        res = await client.post("/api/auth/login", json=payload)
        assert res.status_code == 401
        assert "Incorrect username or password" in res.json()["detail"]

@pytest.mark.asyncio
async def test_unauthenticated_access_blocked():
    """Verify that unauthenticated requests to protected endpoints return 401."""
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        # Admin dashboard
        res = await client.get("/api/admin/dashboard")
        assert res.status_code == 401

        # Citizen entitlement summary
        res = await client.get("/api/beneficiary/BEN-KA-0001/entitlement-summary")
        assert res.status_code == 401

@pytest.mark.asyncio
async def test_citizen_role_blocked_from_admin_dashboard():
    """Verify that a beneficiary is blocked from accessing district-wide dashboards."""
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        # Login as beneficiary
        payload = {"username": "BEN-KA-0001", "password": "citizen_pass"}
        login_res = await client.post("/api/auth/login", json=payload)
        token = login_res.json()["access_token"]
        headers = {"Authorization": f"Bearer {token}"}

        # Attempt to access admin dashboard
        res = await client.get("/api/admin/dashboard", headers=headers)
        assert res.status_code == 403
        assert "Access restricted to DSO, ADMIN, or AUDITOR" in res.json()["detail"]

@pytest.mark.asyncio
async def test_privilege_escalation_intent_blocked():
    """Verify that a citizen cannot submit or view intents of another citizen."""
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        # Login as Beneficiary 0001
        payload = {"username": "BEN-KA-0001", "password": "citizen_pass"}
        login_res = await client.post("/api/auth/login", json=payload)
        token = login_res.json()["access_token"]
        headers = {"Authorization": f"Bearer {token}"}

        # Attempt to submit intent for Beneficiary 0005
        intent_payload = {
            "beneficiary_id": "BEN-KA-0005",
            "cycle_id": "2026-09",
            "intended_fps_id": "FPS-KA-BLR-001",
            "commodity": "Rice",
            "declared_quantity_kg": 25.0
        }
        res = await client.post("/api/intent", json=intent_payload, headers=headers)
        assert res.status_code == 403
        assert "BENEFICIARY role is restricted to own data" in res.json()["detail"]

        # Attempt to view intents filtered by Beneficiary 0005
        res = await client.get("/api/intents?beneficiary_id=BEN-KA-0005", headers=headers)
        assert res.status_code == 403
        assert "restricted to filtering by own beneficiary_id" in res.json()["detail"]

@pytest.mark.asyncio
async def test_auditor_permissions():
    """Verify auditor role can view reports but is blocked from mutations/simulations."""
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        # Login as auditor
        payload = {"username": "auditor_user", "password": "auditor_pass"}
        login_res = await client.post("/api/auth/login", json=payload)
        token = login_res.json()["access_token"]
        headers = {"Authorization": f"Bearer {token}"}

        # 1. Auditor can view admin dashboard
        res = await client.get("/api/admin/dashboard", headers=headers)
        assert res.status_code == 200

        # 2. Auditor cannot trigger forecast generation (POST mutation)
        res = await client.post("/api/admin/forecast/generate", headers=headers)
        assert res.status_code == 403
        assert "restricted to DSO or ADMIN roles" in res.json()["detail"]

@pytest.mark.asyncio
async def test_admin_permissions():
    """Verify admin role can trigger resets and register users, while DSO is blocked from resets."""
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        # 1. Login as DSO
        payload_dso = {"username": "dso_user", "password": "dso_pass"}
        login_dso = await client.post("/api/auth/login", json=payload_dso)
        token_dso = login_dso.json()["access_token"]
        headers_dso = {"Authorization": f"Bearer {token_dso}"}

        # DSO blocked from reset
        res_dso = await client.post("/api/admin/demo/reset", headers=headers_dso)
        assert res_dso.status_code == 403
        assert "restricted to ADMIN role" in res_dso.json()["detail"]

        # 2. Login as ADMIN
        payload_admin = {"username": "admin_user", "password": "admin_pass"}
        login_admin = await client.post("/api/auth/login", json=payload_admin)
        token_admin = login_admin.json()["access_token"]
        headers_admin = {"Authorization": f"Bearer {token_admin}"}

        # Clean up any leftover test user from a previous run to ensure idempotency
        from app.core.database import get_db_connection
        _conn = get_db_connection()
        try:
            _conn.execute("DELETE FROM users WHERE username = 'new_staff_member';")
            _conn.commit()
        finally:
            _conn.close()

        # ADMIN can register a new user
        reg_payload = {
            "username": "new_staff_member",
            "password": "securepassword123",
            "role": "DSO"
        }
        res_reg = await client.post("/api/auth/register", json=reg_payload, headers=headers_admin)
        assert res_reg.status_code == 201
        assert res_reg.json()["username"] == "new_staff_member"

        # ADMIN can trigger reset
        res_reset = await client.post("/api/admin/demo/reset", headers=headers_admin)
        assert res_reset.status_code == 200

@pytest.mark.asyncio
async def test_expired_token_rejected():
    """Verify that an expired token returns 401 Unauthorized."""
    from app.core.auth import create_token
    expired_token = create_token({"username": "admin_user", "role": "ADMIN"}, expires_in=-30)
    headers = {"Authorization": f"Bearer {expired_token}"}
    
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        res = await client.get("/api/admin/dashboard", headers=headers)
        assert res.status_code == 401
        assert "Could not validate credentials" in res.json()["detail"]

@pytest.mark.asyncio
async def test_tampered_token_rejected():
    """Verify that a token with modified payload or bad signature returns 401 Unauthorized."""
    from app.core.auth import create_token
    valid_token = create_token({"username": "BEN-KA-0001", "role": "BENEFICIARY"})
    # Tamper with signature
    parts = valid_token.split(".")
    tampered_token = f"{parts[0]}.badsignature1234567890"
    headers = {"Authorization": f"Bearer {tampered_token}"}

    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        res = await client.get("/api/beneficiary/BEN-KA-0001/entitlement-summary", headers=headers)
        assert res.status_code == 401

@pytest.mark.asyncio
async def test_citizen_blocked_from_all_admin_mutations():
    """Verify that a citizen token is rejected on every admin operational mutation."""
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        payload = {"username": "BEN-KA-0001", "password": "citizen_pass"}
        login_res = await client.post("/api/auth/login", json=payload)
        token = login_res.json()["access_token"]
        headers = {"Authorization": f"Bearer {token}"}

        # 1. Forecast generate
        r1 = await client.post("/api/admin/forecast/generate", headers=headers)
        assert r1.status_code == 403

        # 2. Forecast lock
        r2 = await client.post("/api/admin/forecast/lock", headers=headers)
        assert r2.status_code == 403

        # 3. Dispatch generate
        r3 = await client.post("/api/admin/dispatch/generate", headers=headers)
        assert r3.status_code == 403

        # 4. Scarcity plan approve
        r4 = await client.post("/api/admin/scarcity/approve-plan", json={
            "plan_id": "NONEXISTENT",
            "officer_name": "Citizen Attacker",
            "officer_role": "CITIZEN",
            "approval_notes": "Malicious"
        }, headers=headers)
        assert r4.status_code == 403

        # 5. Demo scenario run
        r5 = await client.post("/api/admin/demo/scenario/run", json={"scenario_id": "SCENARIO_1"}, headers=headers)
        assert r5.status_code == 403

        # 6. Optimization run (GET admin route)
        r6 = await client.get("/api/admin/optimization/run", headers=headers)
        assert r6.status_code == 403

@pytest.mark.asyncio
async def test_cross_beneficiary_profile_access_blocked():
    """Verify that a citizen cannot fetch another citizen's profile details."""
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        # Login as BEN-KA-0001
        payload = {"username": "BEN-KA-0001", "password": "citizen_pass"}
        login_res = await client.post("/api/auth/login", json=payload)
        token = login_res.json()["access_token"]
        headers = {"Authorization": f"Bearer {token}"}

        # Attempt to access BEN-KA-0005 profile
        res = await client.get("/api/beneficiary/BEN-KA-0005/entitlement-summary", headers=headers)
        assert res.status_code == 403
        assert "BENEFICIARY role is restricted to own data" in res.json()["detail"]

@pytest.mark.asyncio
async def test_production_mode_neutralizes_test_auth_bypass(monkeypatch):
    """Verify that in production mode, PDS_TEST_AUTH_MOCK is strictly ignored and unauthenticated calls return 401."""
    from app.core.config import settings
    monkeypatch.setattr(settings, "ENVIRONMENT", "production")
    monkeypatch.setenv("PDS_TEST_AUTH_MOCK", "1")

    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        # Unauthenticated request must return 401 even though PDS_TEST_AUTH_MOCK=1
        res = await client.get("/api/admin/dashboard")
        assert res.status_code == 401
        assert "Could not validate credentials" in res.json()["detail"]

def test_production_config_validation_rejects_insecure_secrets():
    """Verify that validate_production_config enforces strong secrets and valid CORS in production."""
    from app.core.config import Settings, DEFAULT_DEV_SECRET_KEY

    # 1. Default dev secret fails in production
    s1 = Settings(ENVIRONMENT="production", SECRET_KEY=DEFAULT_DEV_SECRET_KEY)
    with pytest.raises(RuntimeError, match="Insecure or default SECRET_KEY"):
        s1.validate_production_config()

    # 2. Short secret (< 32 chars) fails in production
    s2 = Settings(ENVIRONMENT="production", SECRET_KEY="too_short_secret")
    with pytest.raises(RuntimeError, match="Insecure or default SECRET_KEY"):
        s2.validate_production_config()

    # 3. Wildcard CORS fails in production
    s3 = Settings(
        ENVIRONMENT="production",
        SECRET_KEY="a_very_secure_production_secret_key_at_least_32_chars!",
        CORS_ORIGINS=["*"]
    )
    with pytest.raises(RuntimeError, match=r"Wildcard '\*' in CORS_ORIGINS is prohibited"):
        s3.validate_production_config()

    # 4. Valid production settings pass
    s4 = Settings(
        ENVIRONMENT="production",
        SECRET_KEY="a_very_secure_production_secret_key_at_least_32_chars!",
        CORS_ORIGINS=["https://pds.karnataka.gov.in", "https://app.demandsync.in"]
    )
    s4.validate_production_config()  # Should not raise

def test_cors_origins_env_parsing():
    """Verify that comma-separated CORS_ORIGINS strings are cleanly parsed into lists."""
    from app.core.config import Settings
    s = Settings(CORS_ORIGINS="https://pds.karnataka.gov.in, https://app.demandsync.in")
    assert s.CORS_ORIGINS == ["https://pds.karnataka.gov.in", "https://app.demandsync.in"]

@pytest.mark.asyncio
async def test_security_headers_present_in_responses():
    """Verify that standard security headers are attached to HTTP responses."""
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        res = await client.get("/health")
        assert res.headers["x-content-type-options"] == "nosniff"
        assert res.headers["x-frame-options"] == "DENY"
        assert res.headers["x-xss-protection"] == "1; mode=block"
        assert res.headers["referrer-policy"] == "strict-origin-when-cross-origin"

@pytest.mark.asyncio
async def test_production_demo_reset_lock(monkeypatch):
    """Verify that demo reset can be locked down in production even for ADMIN role."""
    from app.core.config import settings
    monkeypatch.setattr(settings, "ENVIRONMENT", "production")
    monkeypatch.setattr(settings, "ALLOW_DEMO_RESET", False)
    
    # Login as ADMIN with valid credentials
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        login_res = await client.post("/api/auth/login", json={"username": "admin_user", "password": "admin_pass"})
        token = login_res.json()["access_token"]
        headers = {"Authorization": f"Bearer {token}"}

        # Attempt reset in production when ALLOW_DEMO_RESET=False
        res = await client.post("/api/admin/demo/reset", headers=headers)
        assert res.status_code == 403
        assert "disabled in production" in res.json()["detail"]


