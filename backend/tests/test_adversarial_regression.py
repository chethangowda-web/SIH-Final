"""
Comprehensive Adversarial Regression & Failure-Mode Test Suite for PDS DemandSync.
Validates robust handling under malicious, out-of-order, concurrent, and degraded inputs.
"""
import time
import json
import sqlite3
import hmac
import hashlib
import base64
import pytest
import httpx

from app.main import app
from app.core.config import settings
from app.core.database import get_db_connection, init_db
from app.data.seed_data import seed_all_data
from app.core.auth import create_token, verify_token
from app.services.workflow_manager import workflow_manager, WorkflowState
from app.services.manifest_engine import manifest_engine
from app.services.scarcity_engine import scarcity_allocation_engine
from app.services.forecast_engine import forecast_engine


@pytest.fixture(autouse=True)
def disable_auth_mock(monkeypatch):
    """Disable auth mock to strictly test authentication and RBAC boundaries."""
    monkeypatch.setenv("PDS_TEST_AUTH_MOCK", "0")


@pytest.fixture(autouse=True)
def setup_database():
    """Ensure clean baseline database state before each test."""
    init_db()
    seed_all_data(recreate=False)


# ==============================================================================
# 1. AUTH FAILURE-MODE & ADVERSARIAL TESTS
# ==============================================================================

@pytest.mark.asyncio
async def test_expired_token_rejected():
    """Verify that expired JWT access tokens are rejected with 401 Unauthorized."""
    expired_claims = {
        "username": "dso_user",
        "role": "DSO",
        "exp": int(time.time()) - 3600  # Expired 1 hour ago
    }
    # Forge token with expired timestamp
    header_b64 = base64.urlsafe_b64encode(json.dumps({"alg": "HS256", "typ": "JWT"}).encode()).decode().rstrip("=")
    payload_b64 = base64.urlsafe_b64encode(json.dumps(expired_claims).encode()).decode().rstrip("=")
    sig = hmac.new(settings.SECRET_KEY.encode(), f"{header_b64}.{payload_b64}".encode(), hashlib.sha256).digest()
    sig_b64 = base64.urlsafe_b64encode(sig).decode().rstrip("=")
    expired_token = f"{header_b64}.{payload_b64}.{sig_b64}"

    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        res = await client.get("/api/admin/dashboard", headers={"Authorization": f"Bearer {expired_token}"})
        assert res.status_code == 401
        assert "credentials" in res.json()["detail"].lower()


@pytest.mark.asyncio
async def test_malformed_tokens_rejected():
    """Verify that corrupt or malformed Authorization tokens return 401."""
    malformed_tokens = [
        "not-a-token",
        "Bearer",
        "part1.part2",
        "header.invalid_base64_payload???.sig",
        "",
        "None",
        "null"
    ]
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        for bad_token in malformed_tokens:
            res = await client.get("/api/admin/dashboard", headers={"Authorization": f"Bearer {bad_token}"})
            assert res.status_code == 401, f"Failed on token: {bad_token}"


@pytest.mark.asyncio
async def test_tampered_token_signature_rejected():
    """Verify that tokens with altered payloads or forged signatures are rejected."""
    # Generate valid token for beneficiary
    valid_token = create_token({"username": "BEN-KA-0001", "role": "BENEFICIARY"})
    payload_b64, sig = valid_token.split(".", 1)

    # Tamper payload to elevate role to ADMIN without resigning with secret key
    padding = 4 - (len(payload_b64) % 4)
    if padding < 4:
        payload_b64 += "=" * padding
    payload_json = base64.urlsafe_b64decode(payload_b64.encode()).decode()
    payload = json.loads(payload_json)
    payload["sub"]["role"] = "ADMIN"
    tampered_b64 = base64.urlsafe_b64encode(json.dumps(payload).encode()).decode().rstrip("=")
    tampered_token = f"{tampered_b64}.{sig}"

    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        res = await client.get("/api/admin/dashboard", headers={"Authorization": f"Bearer {tampered_token}"})
        assert res.status_code == 401


@pytest.mark.asyncio
async def test_wrong_role_mutation_rejected_with_403():
    """Verify that authenticated beneficiary cannot invoke DSO/admin mutation endpoints."""
    token = create_token({"username": "BEN-KA-0001", "role": "BENEFICIARY", "beneficiary_id": "BEN-KA-0001"})
    headers = {"Authorization": f"Bearer {token}"}

    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        # Beneficiary attempting to lock forecast
        res = await client.post("/api/admin/forecast/lock", json={"cycle_id": "2026-09"}, headers=headers)
        assert res.status_code == 403
        assert "restricted" in res.json()["detail"].lower() or "not permitted" in res.json()["detail"].lower()


@pytest.mark.asyncio
async def test_cross_beneficiary_profile_access_forbidden():
    """Verify that Beneficiary 1 is forbidden from viewing Beneficiary 2's detailed profile."""
    ben1_token = create_token({"username": "BEN-KA-0001", "role": "BENEFICIARY", "beneficiary_id": "BEN-KA-0001"})
    headers = {"Authorization": f"Bearer {ben1_token}"}

    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        # Beneficiary 1 attempts to access Beneficiary 2
        res = await client.get("/api/beneficiaries/BEN-KA-0002", headers=headers)
        assert res.status_code == 403
        assert "Access Denied" in res.json()["detail"]


@pytest.mark.asyncio
async def test_cross_beneficiary_intent_submission_forbidden():
    """Verify that Beneficiary 1 is forbidden from submitting intent for Beneficiary 2."""
    ben1_token = create_token({"username": "BEN-KA-0001", "role": "BENEFICIARY", "beneficiary_id": "BEN-KA-0001"})
    headers = {"Authorization": f"Bearer {ben1_token}"}

    payload = {
        "beneficiary_id": "BEN-KA-0002",  # Mismatch!
        "cycle_id": "2026-09",
        "commodity": "Rice",
        "intended_fps_id": "FPS-KA-BLR-001",
        "service_mode": "FPS_COLLECTION",
        "declared_quantity_kg": 20.0
    }

    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        res = await client.post("/api/intent", json=payload, headers=headers)
        assert res.status_code == 403
        assert "Access Denied" in res.json()["detail"]


# ==============================================================================
# 2. WORKFLOW STATE MACHINE FAILURE-MODE & ADVERSARIAL TESTS
# ==============================================================================

def test_workflow_illegal_stage_skip_rejected():
    """Verify that attempting to skip directly from FORECASTED to DISPATCHED is rejected."""
    conn = get_db_connection()
    try:
        workflow_manager.reset_state(conn, "2026-09")
        workflow_manager.transition_state(conn, "2026-09", WorkflowState.FORECASTED, "Admin", "DSO", force=True)

        with pytest.raises(ValueError) as exc_info:
            workflow_manager.transition_state(conn, "2026-09", WorkflowState.DISPATCHED, "Admin", "DSO", force=False)
        assert "Illegal state transition" in str(exc_info.value)
    finally:
        conn.close()


def test_workflow_backwards_transition_rejected():
    """Verify that unforced backwards state transition (e.g. ALLOCATED -> VALIDATED) is rejected."""
    conn = get_db_connection()
    try:
        workflow_manager.reset_state(conn, "2026-09")
        workflow_manager.transition_state(conn, "2026-09", WorkflowState.ALLOCATED, "Admin", "DSO", force=True)

        with pytest.raises(ValueError) as exc_info:
            workflow_manager.transition_state(conn, "2026-09", WorkflowState.VALIDATED, "Admin", "DSO", force=False)
        assert "Illegal state transition" in str(exc_info.value)
    finally:
        conn.close()


def test_workflow_citizen_role_transition_blocked():
    """Verify that citizen/beneficiary role cannot mutate planning lifecycle state."""
    conn = get_db_connection()
    try:
        workflow_manager.reset_state(conn, "2026-09")
        workflow_manager.transition_state(conn, "2026-09", WorkflowState.FORECASTED, "Admin", "DSO", force=True)

        with pytest.raises(ValueError) as exc_info:
            workflow_manager.transition_state(conn, "2026-09", WorkflowState.VALIDATED, "Citizen", "CITIZEN", force=False)
        assert "Citizen role cannot transition" in str(exc_info.value)
    finally:
        conn.close()


def test_workflow_ai_role_officer_approval_blocked():
    """Verify that AI role is advisory-only and cannot authorize ALLOCATED or MANIFEST_LOCKED."""
    conn = get_db_connection()
    try:
        workflow_manager.reset_state(conn, "2026-09")
        workflow_manager.transition_state(conn, "2026-09", WorkflowState.VALIDATED, "Admin", "DSO", force=True)

        with pytest.raises(ValueError) as exc_info:
            workflow_manager.transition_state(conn, "2026-09", WorkflowState.ALLOCATED, "ML Pipeline", "AI", force=False)
        assert "AI role is advisory only" in str(exc_info.value)
    finally:
        conn.close()


def test_workflow_repeated_transition_idempotent():
    """Verify that repeating a transition to the current state succeeds idempotently."""
    conn = get_db_connection()
    try:
        workflow_manager.reset_state(conn, "2026-09")
        s1 = workflow_manager.transition_state(conn, "2026-09", WorkflowState.FORECASTED, "Admin", "DSO", force=True)
        s2 = workflow_manager.transition_state(conn, "2026-09", WorkflowState.FORECASTED, "Admin", "DSO", force=False)
        assert s1 == s2 == WorkflowState.FORECASTED
    finally:
        conn.close()


def test_workflow_invalid_state_name_rejected():
    """Verify that non-existent state names raise a ValueError."""
    conn = get_db_connection()
    try:
        with pytest.raises(ValueError) as exc_info:
            workflow_manager.transition_state(conn, "2026-09", "NON_EXISTENT_STATE", "Admin", "DSO")
        assert "Invalid workflow state target" in str(exc_info.value)
    finally:
        conn.close()


# ==============================================================================
# 3. MANIFEST TAMPER & FAILURE-MODE TESTS
# ==============================================================================

def test_manifest_digital_seal_tamper_detection():
    """Verify that altering stop quantities produces a mismatched cryptographic digital seal."""
    manifest_payload = {
        "manifest_id": "MAN-DEMO-001",
        "cycle_id": "2026-09",
        "truck_id": "DEMO-KA-04-E-1021",
        "delivery_sequence": [
            {"sequence": 1, "fps_id": "FPS-001", "fps_name": "Malleshwaram", "rice_kg": 500.0, "wheat_kg": 200.0, "total_drop_kg": 700.0, "latitude": 13.0, "longitude": 77.5}
        ]
    }
    original_seal = manifest_engine._generate_digital_seal(manifest_payload)

    # Adversarial tampering: modify drop quantity
    tampered_payload = {
        "manifest_id": "MAN-DEMO-001",
        "cycle_id": "2026-09",
        "truck_id": "DEMO-KA-04-E-1021",
        "delivery_sequence": [
            {"sequence": 1, "fps_id": "FPS-001", "fps_name": "Malleshwaram", "rice_kg": 800.0, "wheat_kg": 200.0, "total_drop_kg": 1000.0, "latitude": 13.0, "longitude": 77.5}
        ]
    }
    tampered_seal = manifest_engine._generate_digital_seal(tampered_payload)

    assert original_seal != tampered_seal


def test_manifest_repeated_locking_idempotent():
    """Verify that calling lock_manifest on an already locked manifest is idempotent."""
    conn = get_db_connection()
    try:
        cursor = conn.cursor()
        cursor.execute("SELECT manifest_id FROM manifests LIMIT 1;")
        row = cursor.fetchone()
        if row:
            mid = row["manifest_id"]
            d1 = manifest_engine.lock_manifest(conn, mid)
            assert d1["approval_status"] == "LOCKED" and d1["is_locked"] is True
            d2 = manifest_engine.lock_manifest(conn, mid)
            assert d2["approval_status"] == "LOCKED" and d2["is_locked"] is True
            assert d1["digital_seal_hash"] == d2["digital_seal_hash"]
    finally:
        conn.close()


def test_manifest_revision_on_draft_fails():
    """Verify that creating a revision on a DRAFT manifest is rejected."""
    conn = get_db_connection()
    try:
        cursor = conn.cursor()
        cursor.execute("SELECT manifest_id FROM manifests WHERE status = 'DRAFT' LIMIT 1;")
        row = cursor.fetchone()
        if row:
            mid = row["manifest_id"]
            with pytest.raises(ValueError) as exc_info:
                manifest_engine.create_manifest_revision(conn, mid)
            assert "Concurrent revision detected" in str(exc_info.value) or "LOCKED" in str(exc_info.value)
    finally:
        conn.close()


# ==============================================================================
# 4. SCARCITY ADVERSARIAL & PRESSURE TESTS
# ==============================================================================

def test_scarcity_simulation_statutory_floor_protected_under_deep_deficit():
    """Verify that even under 70% depot scarcity, statutory floors are strictly protected."""
    conn = get_db_connection()
    try:
        sim = scarcity_allocation_engine.simulate_scarcity_plan(
            conn,
            cycle_id="2026-09",
            depot_id="DEPOT-01",
            commodity="Rice",
            available_depot_stock_kg=5000.0,  # Deep deficit
            allocation_strategy="FAIR_SHARE_RISK_WEIGHTED"
        )
        assert sim["deficit_kg"] > 0
        for item in sim["allocated_items"]:
            assert item["reconciled_allocation_kg"] >= item["statutory_floor_kg"] - 0.01
    finally:
        conn.close()


def test_scarcity_simulation_does_not_mutate_state_without_persist():
    """Verify that simulate_scarcity_plan is purely read-only when persist_candidate=False."""
    conn = get_db_connection()
    try:
        cursor = conn.cursor()
        cursor.execute("SELECT COUNT(*) FROM scarcity_allocation_plans;")
        before_count = cursor.fetchone()[0]

        _ = scarcity_allocation_engine.simulate_scarcity_plan(
            conn,
            cycle_id="2026-09",
            depot_id="DEPOT-01",
            commodity="Rice",
            available_depot_stock_kg=10000.0,
            allocation_strategy="STATUTORY_FLOOR_PRIORITY"
        )

        cursor.execute("SELECT COUNT(*) FROM scarcity_allocation_plans;")
        after_count = cursor.fetchone()[0]
        assert before_count == after_count
    finally:
        conn.close()


@pytest.mark.asyncio
async def test_scarcity_approval_of_already_approved_plan_rejected():
    """Verify that approving an already approved plan returns HTTP 400."""
    token = create_token({"username": "dso_user", "role": "DSO"})
    headers = {"Authorization": f"Bearer {token}"}

    conn = get_db_connection()
    try:
        sim = scarcity_allocation_engine.simulate_scarcity_plan(
            conn, cycle_id="2026-09", depot_id="DEPOT-01", commodity="Rice",
            available_depot_stock_kg=15000.0
        )
        plan_res = scarcity_allocation_engine.persist_scarcity_plan(conn, sim)
        plan_id = plan_res["plan_id"]
    finally:
        conn.close()

    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        # First approval: succeeds
        res1 = await client.post("/api/admin/scarcity/approve-plan", json={
            "plan_id": plan_id,
            "officer_name": "DSO Officer",
            "officer_role": "DISTRICT_SUPPLY_OFFICER",
            "officer_justification": "Statutory fair-share approval"
        }, headers=headers)
        assert res1.status_code == 200

        # Second approval attempt: rejected with 400
        res2 = await client.post("/api/admin/scarcity/approve-plan", json={
            "plan_id": plan_id,
            "officer_name": "DSO Officer",
            "officer_role": "DISTRICT_SUPPLY_OFFICER",
            "officer_justification": "Duplicate approval attempt"
        }, headers=headers)
        assert res2.status_code == 400
        assert "already been approved" in res2.json()["detail"]


# ==============================================================================
# 5. INTENT VALIDATION & DUPLICATE TESTS
# ==============================================================================

@pytest.mark.asyncio
async def test_intent_duplicate_submission_upserts_cleanly():
    """Verify that submitting intent multiple times in the same cycle updates cleanly without duplicate entries."""
    token = create_token({"username": "BEN-KA-0001", "role": "BENEFICIARY", "beneficiary_id": "BEN-KA-0001"})
    headers = {"Authorization": f"Bearer {token}"}

    payload = {
        "beneficiary_id": "BEN-KA-0001",
        "cycle_id": "2026-10",
        "commodity": "Rice",
        "intended_fps_id": "FPS-KA-BLR-001",
        "delivery_mode": "FPS_COLLECTION",
        "declared_quantity_kg": 20.0
    }

    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        # Initial submission
        res1 = await client.post("/api/intent", json=payload, headers=headers)
        assert res1.status_code == 201

        # Updated submission with new quantity
        payload["declared_quantity_kg"] = 25.0
        res2 = await client.post("/api/intent", json=payload, headers=headers)
        assert res2.status_code == 201

        # Verify only 1 intent record exists for this beneficiary and commodity
        conn = get_db_connection()
        try:
            cursor = conn.cursor()
            cursor.execute("SELECT COUNT(*) FROM intent WHERE beneficiary_id = 'BEN-KA-0001' AND commodity = 'Rice' AND cycle_id = '2026-10';")
            count = cursor.fetchone()[0]
            assert count == 1
        finally:
            conn.close()


@pytest.mark.asyncio
async def test_intent_invalid_quantity_rejected():
    """Verify that negative or zero declared quantity returns 422."""
    token = create_token({"username": "BEN-KA-0001", "role": "BENEFICIARY", "beneficiary_id": "BEN-KA-0001"})
    headers = {"Authorization": f"Bearer {token}"}

    payload = {
        "beneficiary_id": "BEN-KA-0001",
        "cycle_id": "2026-10",
        "commodity": "Rice",
        "intended_fps_id": "FPS-KA-BLR-001",
        "delivery_mode": "FPS_COLLECTION",
        "declared_quantity_kg": -10.0
    }

    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        res = await client.post("/api/intent", json=payload, headers=headers)
        assert res.status_code in [400, 422]


@pytest.mark.asyncio
async def test_intent_invalid_commodity_rejected():
    """Verify that unpermitted commodities (e.g. Sugar, Kerosene) return 422."""
    token = create_token({"username": "BEN-KA-0001", "role": "BENEFICIARY", "beneficiary_id": "BEN-KA-0001"})
    headers = {"Authorization": f"Bearer {token}"}

    payload = {
        "beneficiary_id": "BEN-KA-0001",
        "cycle_id": "2026-10",
        "commodity": "Sugar",
        "intended_fps_id": "FPS-KA-BLR-001",
        "delivery_mode": "FPS_COLLECTION",
        "declared_quantity_kg": 5.0
    }

    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        res = await client.post("/api/intent", json=payload, headers=headers)
        assert res.status_code == 422
        assert "Invalid commodity" in res.json()["detail"]


# ==============================================================================
# 6. DATABASE INTEGRITY & CONSTRAINT ENFORCEMENT TESTS
# ==============================================================================

def test_database_duplicate_user_unique_constraint():
    """Verify that duplicate user registration violates UNIQUE constraint and raises IntegrityError."""
    conn = get_db_connection()
    try:
        cursor = conn.cursor()
        cursor.execute("INSERT OR IGNORE INTO users (username, password_hash, role) VALUES ('unique_test_user', 'hash', 'ADMIN');")
        conn.commit()

        with pytest.raises(sqlite3.IntegrityError):
            cursor.execute("INSERT INTO users (username, password_hash, role) VALUES ('unique_test_user', 'hash2', 'ADMIN');")
            conn.commit()
    finally:
        conn.rollback()
        conn.close()


def test_database_transaction_rollback_on_multi_step_failure():
    """Verify that multi-step mutations roll back fully on unhandled exception."""
    conn = get_db_connection()
    try:
        cursor = conn.cursor()
        cursor.execute("SELECT COUNT(*) FROM beneficiaries;")
        initial_count = cursor.fetchone()[0]

        try:
            cursor.execute("INSERT INTO beneficiaries (pseudonymous_beneficiary_id, name_for_demo, registered_fps_id) VALUES ('TEMP-BEN-999', 'Temp User', 'FPS-KA-BLR-001');")
            # Force syntax error on second step
            cursor.execute("INSERT INTO non_existent_table VALUES (1, 2, 3);")
            conn.commit()
        except Exception:
            conn.rollback()

        cursor.execute("SELECT COUNT(*) FROM beneficiaries;")
        after_count = cursor.fetchone()[0]
        assert initial_count == after_count
    finally:
        conn.close()


# ==============================================================================
# 7. API INPUT ROBUSTNESS & MALFORMED REQUESTS
# ==============================================================================

@pytest.mark.asyncio
async def test_api_missing_required_fields_returns_422():
    """Verify that empty JSON payloads to strict endpoints return 422 Unprocessable Entity."""
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        res = await client.post("/api/auth/login", json={})
        assert res.status_code == 422


@pytest.mark.asyncio
async def test_api_invalid_data_types_returns_422():
    """Verify that wrong data types for parameters return 422."""
    token = create_token({"username": "dso_user", "role": "DSO"})
    headers = {"Authorization": f"Bearer {token}"}

    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        res = await client.get("/api/beneficiaries?limit=NOT_AN_INT", headers=headers)
        assert res.status_code == 422


@pytest.mark.asyncio
async def test_api_unknown_beneficiary_id_returns_404():
    """Verify that querying a non-existent beneficiary identifier returns 404."""
    token = create_token({"username": "dso_user", "role": "DSO"})
    headers = {"Authorization": f"Bearer {token}"}

    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        res = await client.get("/api/beneficiary/NON_EXISTENT_ID_99999", headers=headers)
        assert res.status_code == 404
        assert "not found" in res.json()["detail"].lower()


@pytest.mark.asyncio
async def test_api_unsupported_http_method_returns_405():
    """Verify that unsupported HTTP methods return 405 Method Not Allowed."""
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        res = await client.delete("/api/health/live")
        assert res.status_code == 405


# ==============================================================================
# 8. PHASE 2 PRODUCTION SECURITY & IDOR BOUNDARY TESTS
# ==============================================================================

@pytest.mark.asyncio
async def test_idor_cross_beneficiary_delivery_records_forbidden():
    """Verify that a citizen token cannot access delivery records of another beneficiary."""
    ben1_token = create_token({"username": "BEN-KA-0001", "role": "BENEFICIARY", "beneficiary_id": "BEN-KA-0001"})
    headers = {"Authorization": f"Bearer {ben1_token}"}

    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        # Attempt to access BEN-KA-0002 records
        res = await client.get("/api/beneficiary/BEN-KA-0002/delivery-records", headers=headers)
        assert res.status_code == 403
        assert "Access Denied" in res.json()["detail"]


@pytest.mark.asyncio
async def test_idor_cross_beneficiary_entitlement_summary_forbidden():
    """Verify that a citizen token cannot access entitlement summary of another beneficiary."""
    ben1_token = create_token({"username": "BEN-KA-0001", "role": "BENEFICIARY", "beneficiary_id": "BEN-KA-0001"})
    headers = {"Authorization": f"Bearer {ben1_token}"}

    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        # Attempt to access BEN-KA-0002 summary
        res = await client.get("/api/beneficiary/BEN-KA-0002/entitlement-summary", headers=headers)
        assert res.status_code == 403
        assert "Access Denied" in res.json()["detail"]


@pytest.mark.asyncio
async def test_auditor_role_cannot_perform_admin_mutations():
    """Verify that AUDITOR role has read-only access and cannot mutate dispatches or manifests."""
    auditor_token = create_token({"username": "auditor_user", "role": "AUDITOR"})
    headers = {"Authorization": f"Bearer {auditor_token}"}

    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        # GET should succeed (Auditor has read access)
        get_res = await client.get("/api/admin/dashboard", headers=headers)
        assert get_res.status_code == 200

        # POST mutation should be rejected with 403
        post_res = await client.post("/api/admin/manifests/MAN-01/lock", headers=headers)
        assert post_res.status_code == 403
        assert "Mutation actions are restricted to DSO or ADMIN roles" in post_res.json()["detail"]


@pytest.mark.asyncio
async def test_sql_injection_attempt_in_search_query_is_neutralized():
    """Verify that SQL injection patterns in query params are safely parameterized."""
    token = create_token({"username": "dso_user", "role": "DSO"})
    headers = {"Authorization": f"Bearer {token}"}
    sql_payload = "' OR '1'='1"

    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        res = await client.get(f"/api/beneficiaries?search={sql_payload}", headers=headers)
        assert res.status_code == 200
        data = res.json()
        # Safe parameterized search should return 0 items matching literal SQL fragment
        assert data["total"] == 0
        assert len(data["items"]) == 0


@pytest.mark.asyncio
async def test_oversized_payload_string_rejected_by_pydantic_bounds():
    """Verify that oversized string payloads exceeding schema bounds return 422."""
    ben_token = create_token({"username": "BEN-KA-0001", "role": "BENEFICIARY", "beneficiary_id": "BEN-KA-0001"})
    headers = {"Authorization": f"Bearer {ben_token}"}

    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        res = await client.post(
            "/api/intent",
            headers=headers,
            json={
                "beneficiary_id": "BEN-KA-0001",
                "cycle_id": "2026-09",
                "intended_fps_id": "FPS-KA-BLR-001",
                "commodity": "Rice",
                "delivery_address": "X" * 1000  # Exceeds max_length=500
            }
        )
        assert res.status_code == 422


@pytest.mark.asyncio
async def test_production_demo_reset_blocked_without_explicit_switch():
    """Verify that demo reset endpoint is locked when ALLOW_DEMO_RESET is False."""
    admin_token = create_token({"username": "admin_user", "role": "ADMIN"})
    headers = {"Authorization": f"Bearer {admin_token}"}

    original_env = settings.ENVIRONMENT
    original_reset_flag = settings.ALLOW_DEMO_RESET
    try:
        settings.ENVIRONMENT = "production"
        settings.ALLOW_DEMO_RESET = False

        async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
            res = await client.post("/api/admin/demo/reset", headers=headers)
            assert res.status_code == 403
            assert "System reset endpoint is disabled in production environment" in res.json()["detail"]
    finally:
        settings.ENVIRONMENT = original_env
        settings.ALLOW_DEMO_RESET = original_reset_flag
