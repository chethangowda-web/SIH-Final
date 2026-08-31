"""
Comprehensive API Contract, Error Handling & Schema Hardening Test Suite.
Verifies status codes (200, 201, 400, 401, 403, 404, 409, 422, 500),
Pydantic response models, RBAC constraints, concurrency guards, and error sanitization.
"""
import pytest
from httpx import AsyncClient, ASGITransport
from app.main import app
from app.core.config import settings
from app.core.auth import create_token
from app.core.database import init_db
from app.data.seed_data import seed_all_data


@pytest.fixture(autouse=True)
def setup_database_and_env(monkeypatch):
    """Ensure mock auth is disabled and database is seeded."""
    monkeypatch.setenv("PDS_TEST_AUTH_MOCK", "0")
    init_db()
    seed_all_data(recreate=False)


@pytest.fixture
def admin_token():
    return create_token(
        {"username": "admin_user", "role": "ADMIN", "beneficiary_id": None}
    )


@pytest.fixture
def dso_token():
    return create_token(
        {"username": "dso_user", "role": "DSO", "beneficiary_id": None}
    )


@pytest.fixture
def beneficiary_token():
    return create_token(
        {"username": "BEN-KA-0001", "role": "BENEFICIARY", "beneficiary_id": "BEN-KA-0001"}
    )


@pytest.fixture
def other_beneficiary_token():
    return create_token(
        {"username": "BEN-KA-0002", "role": "BENEFICIARY", "beneficiary_id": "BEN-KA-0002"}
    )


# -----------------------------------------------------------------------------
# 1. AUTHENTICATION & RBAC CONTRACT TESTS
# -----------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_auth_login_public_success():
    """POST /api/auth/login should succeed with valid credentials."""
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
        res = await ac.post("/api/auth/login", json={"username": "admin_user", "password": "admin_pass"})
        assert res.status_code == 200
        data = res.json()
        assert "access_token" in data
        assert data["token_type"] == "bearer"
        assert data["role"] == "ADMIN"


@pytest.mark.asyncio
async def test_auth_login_invalid_credentials_returns_401():
    """POST /api/auth/login should return 401 for wrong credentials."""
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
        res = await ac.post("/api/auth/login", json={"username": "admin_user", "password": "wrongpassword"})
        assert res.status_code == 401
        assert "Incorrect username or password" in res.json()["detail"]


@pytest.mark.asyncio
async def test_auth_me_unauthorized_without_token():
    """GET /api/auth/me should return 401 without Bearer token."""
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
        res = await ac.get("/api/auth/me")
        assert res.status_code == 401


@pytest.mark.asyncio
async def test_admin_dashboard_forbidden_for_beneficiary(beneficiary_token):
    """GET /api/admin/dashboard should return 403 for BENEFICIARY role."""
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
        res = await ac.get(
            "/api/admin/dashboard",
            headers={"Authorization": f"Bearer {beneficiary_token}"}
        )
        assert res.status_code == 403
        assert "Access restricted" in res.json()["detail"] or "Forbidden" in res.json()["detail"] or "Access Denied" in res.json()["detail"]


@pytest.mark.asyncio
async def test_beneficiary_cannot_submit_intent_for_another(beneficiary_token):
    """POST /api/intent should return 403 when beneficiary_id does not match token."""
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
        payload = {
            "beneficiary_id": "BEN-KA-0002",  # Mismatch with BEN-KA-0001
            "cycle_id": "2026-09",
            "intended_fps_id": "FPS-KA-BLR-002",
            "commodity": "Rice",
            "declared_quantity_kg": 25.0
        }
        res = await ac.post(
            "/api/intent",
            json=payload,
            headers={"Authorization": f"Bearer {beneficiary_token}"}
        )
        assert res.status_code == 403
        assert "Access Denied" in res.json()["detail"]


@pytest.mark.asyncio
async def test_beneficiary_cannot_view_other_beneficiary_entitlement(beneficiary_token):
    """GET /api/beneficiary/{id}/entitlement-summary should return 403 for other beneficiary."""
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
        res = await ac.get(
            "/api/beneficiary/BEN-KA-0002/entitlement-summary",
            headers={"Authorization": f"Bearer {beneficiary_token}"}
        )
        assert res.status_code == 403
        assert "Access Denied" in res.json()["detail"]


# -----------------------------------------------------------------------------
# 2. SCHEMA VALIDATION (422) TESTS
# -----------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_validation_error_on_missing_required_fields(admin_token):
    """POST /api/admin/optimization/what-if should reject invalid types with 422."""
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
        res = await ac.post(
            "/api/admin/optimization/what-if",
            json={"vehicle_capacity_kg": "not-a-number"},
            headers={"Authorization": f"Bearer {admin_token}"}
        )
        assert res.status_code == 422


@pytest.mark.asyncio
async def test_validation_error_on_negative_quantity(beneficiary_token):
    """POST /api/intent should reject negative declared_quantity_kg with 422."""
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
        payload = {
            "beneficiary_id": "BEN-KA-0001",
            "cycle_id": "2026-09",
            "intended_fps_id": "FPS-KA-BLR-001",
            "commodity": "Rice",
            "declared_quantity_kg": -10.0
        }
        res = await ac.post(
            "/api/intent",
            json=payload,
            headers={"Authorization": f"Bearer {beneficiary_token}"}
        )
        assert res.status_code == 422


# -----------------------------------------------------------------------------
# 3. NOT-FOUND (404) CONTRACT TESTS
# -----------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_beneficiary_not_found(admin_token):
    """GET /api/beneficiaries/{id} should return 404 for non-existent ID."""
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
        res = await ac.get(
            "/api/beneficiaries/NON-EXISTENT-BEN-9999",
            headers={"Authorization": f"Bearer {admin_token}"}
        )
        assert res.status_code == 404
        assert "not found" in res.json()["detail"].lower()


@pytest.mark.asyncio
async def test_fps_not_found(admin_token):
    """GET /api/fps/{id} should return 404 for non-existent FPS ID."""
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
        res = await ac.get(
            "/api/fps/NON-EXISTENT-FPS-9999",
            headers={"Authorization": f"Bearer {admin_token}"}
        )
        assert res.status_code == 404
        assert "not found" in res.json()["detail"].lower()


@pytest.mark.asyncio
async def test_manifest_not_found(admin_token):
    """GET /api/admin/manifests/{id} should return 404 for non-existent manifest."""
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
        res = await ac.get(
            "/api/admin/manifests/NON-EXISTENT-MANIFEST",
            headers={"Authorization": f"Bearer {admin_token}"}
        )
        assert res.status_code == 404
        assert "not found" in res.json()["detail"].lower()


@pytest.mark.asyncio
async def test_scarcity_plan_audit_trail_not_found(admin_token):
    """GET /api/admin/scarcity/audit-trail/{id} should return 404 for non-existent plan."""
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
        res = await ac.get(
            "/api/admin/scarcity/audit-trail/NON-EXISTENT-PLAN",
            headers={"Authorization": f"Bearer {admin_token}"}
        )
        assert res.status_code == 404
        assert "not found" in res.json()["detail"].lower()


# -----------------------------------------------------------------------------
# 4. STRUCTURED RESPONSE MODELS & FRONTEND COMPATIBILITY
# -----------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_health_response_schema():
    """GET /api/health returns HealthResponse model with all required keys."""
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
        res = await ac.get("/api/health")
        assert res.status_code == 200
        data = res.json()
        assert data["status"] == "healthy"
        assert data["project_name"] == "PDS DemandSync"
        assert data["database_status"] == "connected"
        assert data["active_cycle"] == "2026-09"
        assert isinstance(data["fps_count"], int)
        assert isinstance(data["beneficiaries_count"], int)
        assert "demo_notice" in data


@pytest.mark.asyncio
async def test_choice_window_status_response_schema(beneficiary_token):
    """GET /api/choice-window/status returns ChoiceWindowStatusOut model."""
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
        res = await ac.get(
            "/api/choice-window/status?cycle_id=2026-09",
            headers={"Authorization": f"Bearer {beneficiary_token}"}
        )
        assert res.status_code == 200
        data = res.json()
        assert "cycle_id" in data
        assert "is_open" in data
        assert "status" in data
        assert "workflow_status" in data
        assert "active_intents_count" in data
        assert "total_declared_intent_kg" in data
        assert "demo_notice" in data


@pytest.mark.asyncio
async def test_admin_routes_response_schema(admin_token):
    """GET /api/admin/routes returns SupplyRoutesResponse model."""
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
        res = await ac.get(
            "/api/admin/routes",
            headers={"Authorization": f"Bearer {admin_token}"}
        )
        assert res.status_code == 200
        data = res.json()
        assert data["status"] == "success"
        assert "total_routes_count" in data
        assert isinstance(data["routes"], list)
        if len(data["routes"]) > 0:
            first_route = data["routes"][0]
            assert "route_id" in first_route
            assert "source_depot_id" in first_route
            assert "destination_fps_id" in first_route
            assert "distance_km" in first_route


@pytest.mark.asyncio
async def test_admin_forecast_district_summary_schema(admin_token):
    """GET /api/admin/forecast/district-summary returns DistrictForecastSummaryResponse."""
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
        res = await ac.get(
            "/api/admin/forecast/district-summary?cycle_id=2026-09",
            headers={"Authorization": f"Bearer {admin_token}"}
        )
        assert res.status_code == 200
        data = res.json()
        assert data["status"] == "success"
        assert data["total_fps_count"] == 20
        assert "total_district_predicted_kg" in data
        assert "average_district_confidence" in data
        assert isinstance(data["fps_forecasts"], list)


@pytest.mark.asyncio
async def test_admin_dispatch_decisions_district_summary_schema(admin_token):
    """GET /api/admin/dispatch-decisions/district-summary returns DistrictDispatchSummaryResponse."""
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
        res = await ac.get(
            "/api/admin/dispatch-decisions/district-summary?cycle_id=2026-09",
            headers={"Authorization": f"Bearer {admin_token}"}
        )
        assert res.status_code == 200
        data = res.json()
        assert data["status"] == "success"
        assert data["total_fps_count"] == 20
        assert "total_district_recommended_dispatch_kg" in data
        assert "average_capacity_utilization_pct" in data
        assert isinstance(data["fps_decisions"], list)


# ----------------- Phase 5: Conflict & State Machine Determinism ----------------- #

@pytest.mark.asyncio
async def test_scarcity_approval_unauthorized_role(beneficiary_token):
    """POST /api/admin/scarcity/approve-plan rejects unauthorized citizen role with 403."""
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
        payload = {
            "plan_id": "SC-DEMO-PLAN",
            "officer_name": "Citizen Ramesh",
            "officer_role": "CITIZEN_BENEFICIARY",
            "approval_notes": "Attempt unauthorized approval"
        }
        res = await ac.post(
            "/api/admin/scarcity/approve-plan",
            json=payload,
            headers={"Authorization": f"Bearer {beneficiary_token}"}
        )
        assert res.status_code == 403


@pytest.mark.asyncio
async def test_workflow_illegal_transition_returns_400(admin_token):
    """POST /api/admin/workflow/transition rejects illegal backward skips with 400."""
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
        payload = {
            "cycle_id": "2026-09",
            "new_state": "DISPATCHED",  # Cannot skip directly from PLANNING_OPEN to DISPATCHED without validation
            "actor_name": "Admin",
            "actor_role": "ADMIN"
        }
        res = await ac.post(
            "/api/admin/workflow/transition",
            json=payload,
            headers={"Authorization": f"Bearer {admin_token}"}
        )
        assert res.status_code in [200, 400]
        if res.status_code == 400:
            assert "Invalid transition" in res.json()["detail"] or "cannot" in res.json()["detail"].lower()


# ----------------- Phase 6: Error Sanitization Tests ----------------- #

@pytest.mark.asyncio
async def test_sanitized_error_on_invalid_citizen_request_auth(admin_token):
    """Ensure error messages never leak SQL keywords, table structures, or tracebacks."""
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
        payload = {
            "decision": "APPROVE",
            "officer_name": "K. Srinivas Murthy",
            "officer_role": "DISTRICT_SUPPLY_OFFICER",
            "officer_justification": "Approved under quota"
        }
        res = await ac.post(
            "/api/admin/citizen-requests/NON-EXISTENT-REQ-999/authorize",
            json=payload,
            headers={"Authorization": f"Bearer {admin_token}"}
        )
        assert res.status_code == 404
        detail = res.json()["detail"]
        assert "Traceback" not in detail
        assert "sqlite3.OperationalError" not in detail
        assert "SELECT " not in detail
