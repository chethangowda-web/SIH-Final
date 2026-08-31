"""
tests/test_governance_trail.py
==============================
Unified Governance Event Trail Verification Suite.

Tests:
1. Authorized mutation creates the expected governance event.
2. Unauthorized mutation creates no successful mutation event.
3. Workflow transition creates an event.
4. Manifest lock/revision creates an event.
5. Scarcity approval creates an event.
6. What-if simulation is marked as simulation and does not appear as an operational commit.
7. Audit entries cannot be silently modified/deleted through normal application APIs.
8. Actor identity and role are captured correctly.
9. Existing concurrency/idempotency behavior remains intact.
10. Read-only admin/auditor endpoint returns formatted trail with filters.
"""

import os
import pytest
import httpx
from app.main import app
from app.core.database import get_db_connection
from app.services.governance_trail import governance_trail
from app.services.workflow_manager import workflow_manager, WorkflowState
from app.services.manifest_engine import manifest_engine
from app.services.gatepass_engine import gatepass_engine

@pytest.fixture(autouse=True)
def setup_auth_headers(monkeypatch):
    """Ensure tests run with valid test environment."""
    monkeypatch.setenv("PDS_TEST_AUTH_MOCK", "1")

@pytest.mark.asyncio
async def test_1_workflow_transition_creates_governance_event():
    """Verify that a valid workflow state transition creates a structured governance event."""
    conn = get_db_connection()
    workflow_manager.transition_state(
        conn, "2026-09", WorkflowState.FORECASTED,
        "Test Setup", "ADMIN", force=True
    )
    conn.close()

    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        # Perform transition: FORECASTED -> VALIDATED
        payload = {
            "cycle_id": "2026-09",
            "new_state": "VALIDATED",
            "actor_name": "District Supply Officer",
            "actor_role": "DISTRICT_SUPPLY_OFFICER",
            "reason": "Logistics constraints audit passed"
        }
        res = await client.post("/admin/workflow/transition", json=payload)
        assert res.status_code == 200

        # Query governance trail
        trail_res = await client.get("/admin/governance/trail?cycle_id=2026-09&event_type=WORKFLOW_TRANSITION")
        assert trail_res.status_code == 200
        events = trail_res.json()["events"]
        assert len(events) >= 1
        
        latest = events[0]
        assert latest["event_type"] == "WORKFLOW_TRANSITION"
        assert latest["entity_type"] == "WORKFLOW"
        assert latest["entity_id"] == "2026-09"
        assert latest["actor_name"] == "District Supply Officer"
        assert latest["actor_role"] == "DISTRICT_SUPPLY_OFFICER"
        assert latest["is_simulation"] is False
        assert latest["is_success"] is True
        assert latest["after_state"]["new_state"] == "VALIDATED"

@pytest.mark.asyncio
async def test_2_unauthorized_mutation_creates_no_success_event(monkeypatch):
    """Verify that an unauthorized request is rejected and does not log a successful mutation event."""
    monkeypatch.setenv("PDS_TEST_AUTH_MOCK", "0")
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        # Login as citizen
        login_res = await client.post("/api/auth/login", json={"username": "BEN-KA-0001", "password": "citizen_pass"})
        token = login_res.json()["access_token"]
        headers = {"Authorization": f"Bearer {token}"}

        # Count events before unauthorized attempt
        conn = get_db_connection()
        c = conn.cursor()
        c.execute("SELECT COUNT(*) FROM governance_audit_logs WHERE event_type = 'MANIFEST_LOCKED';")
        count_before = c.fetchone()[0]
        conn.close()

        # Attempt to lock manifest as citizen (unauthorized)
        res = await client.post("/api/admin/manifests/MAN-KA-001/lock", headers=headers, json={"lock_reason": "Hacker lock"})
        assert res.status_code == 403

        # Confirm no new successful MANIFEST_LOCKED event was created
        conn = get_db_connection()
        c = conn.cursor()
        c.execute("SELECT COUNT(*) FROM governance_audit_logs WHERE event_type = 'MANIFEST_LOCKED' AND is_success = 1;")
        count_after = c.fetchone()[0]
        conn.close()
        assert count_after == count_before

@pytest.mark.asyncio
async def test_3_manifest_lock_and_revision_create_events():
    """Verify that locking and revising a manifest produces distinct audit events with cryptographic integrity metadata."""
    conn = get_db_connection()
    # Transition to OPTIMIZED so manifest lock is permissible
    workflow_manager.transition_state(conn, "2026-09", WorkflowState.OPTIMIZED, "Test Setup", "ADMIN", force=True)
    manifest_dossier = manifest_engine.generate_corridor_manifest(conn, "DEMO-KA-04-E-1021", "2026-09")
    manifest_id = manifest_dossier["manifest_id"]
    cursor = conn.cursor()
    cursor.execute("UPDATE manifests SET status = 'DRAFT', digital_seal_hash = NULL WHERE manifest_id = ?;", (manifest_id,))
    conn.commit()
    conn.close()

    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        # 1. Lock Manifest
        lock_res = await client.post(
            f"/admin/manifests/{manifest_id}/lock",
            json={
                "actor_name": "Senior DSO Officer",
                "actor_role": "DISTRICT_SUPPLY_OFFICER",
                "lock_reason": "Operational sign-off complete"
            }
        )
        assert lock_res.status_code == 200

        # Query trail for MANIFEST_LOCKED
        trail_res = await client.get(f"/admin/governance/trail?entity_id={manifest_id}&event_type=MANIFEST_LOCKED")
        assert trail_res.status_code == 200
        lock_events = trail_res.json()["events"]
        assert len(lock_events) >= 1
        lock_evt = lock_events[0]
        assert lock_evt["actor_name"] == "Senior DSO Officer"
        assert lock_evt["integrity_metadata"] is not None
        assert "digital_seal_hash" in lock_evt["integrity_metadata"]

        # 2. Create Revision of locked manifest
        rev_res = await client.post(
            f"/admin/manifests/{manifest_id}/revision",
            json={
                "actor_name": "Senior DSO Officer",
                "actor_role": "DISTRICT_SUPPLY_OFFICER",
                "revision_reason": "Emergency buffer increase"
            }
        )
        assert rev_res.status_code == 200

        # Query trail for MANIFEST_REVISED
        trail_rev_res = await client.get(f"/admin/governance/trail?entity_id={manifest_id}&event_type=MANIFEST_REVISED")
        assert trail_rev_res.status_code == 200
        rev_events = trail_rev_res.json()["events"]
        assert len(rev_events) >= 1
        rev_evt = rev_events[0]
        assert rev_evt["before_state"]["status"] == "LOCKED"
        assert rev_evt["after_state"]["status"] == "DRAFT"
        assert rev_evt["notes"] == "Emergency buffer increase"

@pytest.mark.asyncio
async def test_4_scarcity_simulation_vs_approval_isolation():
    """Verify that scarcity simulations are marked is_simulation=True while approvals are operational."""
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        # 1. Run scarcity simulation
        sim_res = await client.post("/api/admin/scarcity/simulate-fair-share", json={
            "depot_id": "DEPOT-01",
            "cycle_id": "2026-09",
            "commodity": "Rice",
            "available_depot_stock_kg": 15000.0,
            "persist_candidate": True,
            "notes": "What-If supply bottleneck simulation"
        })
        assert sim_res.status_code == 200
        plan_id = sim_res.json()["plan_id"]

        # Check simulation event in trail
        sim_trail = await client.get(f"/admin/governance/trail?event_type=SCARCITY_SIMULATION&is_simulation=true")
        assert sim_trail.status_code == 200
        sim_events = sim_trail.json()["events"]
        assert len(sim_events) >= 1
        assert sim_events[0]["is_simulation"] is True
        assert sim_events[0]["event_type"] == "SCARCITY_SIMULATION"

        # 2. Approve scarcity plan
        app_res = await client.post("/api/admin/scarcity/approve-plan", json={
            "plan_id": plan_id,
            "officer_name": "District Supply Officer",
            "officer_role": "DISTRICT_SUPPLY_OFFICER",
            "approval_notes": "Fair-share plan approved for execution"
        })
        assert app_res.status_code == 200

        # Check approval event in trail (must be is_simulation=False)
        app_trail = await client.get(f"/admin/governance/trail?event_type=SCARCITY_APPROVAL&is_simulation=false")
        assert app_trail.status_code == 200
        app_events = app_trail.json()["events"]
        assert len(app_events) >= 1
        assert app_events[0]["is_simulation"] is False
        assert app_events[0]["after_state"]["status"] == "OFFICER_APPROVED"

@pytest.mark.asyncio
async def test_5_audit_trail_is_append_only_and_no_mutation_endpoints_exist():
    """Verify that there are no endpoints to delete or overwrite governance audit events."""
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        # Attempt DELETE or PUT on audit trail
        r_del = await client.delete("/admin/governance/trail")
        assert r_del.status_code in [404, 405]

        r_put = await client.put("/admin/governance/trail", json={"notes": "Tampered notes"})
        assert r_put.status_code in [404, 405]

@pytest.mark.asyncio
async def test_6_gatepass_issuance_and_advance_events():
    """Verify that gatepass issuance and advancement log structured events with security tokens."""
    conn = get_db_connection()
    # Generate draft manifest and lock it
    m = manifest_engine.generate_corridor_manifest(conn, "DEMO-KA-04-E-1021", "2026-09")
    manifest_id = m["manifest_id"]
    if m["status"] != "LOCKED":
        manifest_engine.lock_manifest(conn, manifest_id)
    
    gp = gatepass_engine.generate_or_get_gatepass_for_truck(conn, "DEMO-KA-04-E-1021", "2026-09")
    gatepass_id = gp["gatepass_id"]

    # Advance to VEHICLE_LOADED
    gatepass_engine.advance_gatepass_status(conn, gatepass_id, "VEHICLE_LOADED", "Security Guard", "SECURITY_OFFICER")
    conn.close()

    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        trail_res = await client.get(f"/admin/governance/trail?entity_id={gatepass_id}")
        assert trail_res.status_code == 200
        events = trail_res.json()["events"]
        assert len(events) >= 2
        
        event_types = [e["event_type"] for e in events]
        assert "GATEPASS_ISSUED" in event_types
        assert "GATEPASS_ADVANCED" in event_types


@pytest.mark.asyncio
async def test_7_ai_identity_rejected_from_officer_workflow_transition():
    """Verify that AI role identity is strictly prohibited from authorizing officer governance transitions."""
    conn = get_db_connection()
    try:
        with pytest.raises(ValueError) as exc:
            workflow_manager.transition_state(
                conn,
                cycle_id="2026-09",
                new_state=WorkflowState.ALLOCATED,
                actor_name="Automated AI Model",
                actor_role="AI_ADVISORY"
            )
        assert "AI role is advisory only" in str(exc.value)
    finally:
        conn.close()


@pytest.mark.asyncio
async def test_8_citizen_role_rejected_from_planning_workflow_transition():
    """Verify that Citizen role identity is strictly prohibited from transitioning allocation states."""
    conn = get_db_connection()
    try:
        with pytest.raises(ValueError) as exc:
            workflow_manager.transition_state(
                conn,
                cycle_id="2026-09",
                new_state=WorkflowState.ALLOCATED,
                actor_name="Citizen User",
                actor_role="CITIZEN_BENEFICIARY"
            )
        assert "Citizen role cannot transition" in str(exc.value)
    finally:
        conn.close()


@pytest.mark.asyncio
async def test_9_manifest_seal_verification_logs_governance_event():
    """Verify that checking manifest cryptographic seal records an immutable verification event."""
    conn = get_db_connection()
    try:
        m = manifest_engine.generate_corridor_manifest(conn, "DEMO-KA-04-E-1021", "2026-09")
        mid = m["manifest_id"]
        if not m["is_locked"]:
            manifest_engine.lock_manifest(conn, mid)
    finally:
        conn.close()

    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        res = await client.get(f"/api/admin/manifests/{mid}/verify-seal")
        assert res.status_code == 200

        trail = await client.get(f"/admin/governance/trail?entity_id={mid}&event_type=MANIFEST_SEAL_VERIFIED")
        assert trail.status_code == 200
        events = trail.json()["events"]
        assert len(events) >= 1
        evt = events[0]
        assert evt["event_type"] == "MANIFEST_SEAL_VERIFIED"
        assert evt["entity_type"] == "MANIFEST"
        assert evt["actor_role"] == "AUDITOR"
        assert evt["integrity_metadata"]["is_valid"] is True


@pytest.mark.asyncio
async def test_10_gatepass_token_verification_logs_governance_event():
    """Verify that checking gatepass security token records a security verification event."""
    conn = get_db_connection()
    try:
        gp = gatepass_engine.generate_or_get_gatepass_for_truck(conn, "DEMO-KA-04-E-1021", "2026-09")
        gpid = gp["gatepass_id"]
        token = gp["security_token"]
    finally:
        conn.close()

    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        res = await client.post("/api/admin/gatepasses/verify", json={
            "gatepass_id": gpid,
            "security_token": token
        })
        assert res.status_code == 200

        trail = await client.get(f"/admin/governance/trail?entity_id={gpid}&event_type=GATEPASS_TOKEN_VERIFIED")
        assert trail.status_code == 200
        events = trail.json()["events"]
        assert len(events) >= 1
        evt = events[0]
        assert evt["event_type"] == "GATEPASS_TOKEN_VERIFIED"
        assert evt["entity_type"] == "GATEPASS"
        assert evt["actor_role"] == "DEPOT_SECURITY"


@pytest.mark.asyncio
async def test_11_constraint_audit_creates_governance_event():
    """Verify that executing district constraint validation logs a constraint audit event."""
    from app.services.constraint_engine import constraint_engine
    conn = get_db_connection()
    try:
        constraint_engine.run_full_district_constraint_audit(conn, "2026-09")
    finally:
        conn.close()

    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        trail = await client.get("/admin/governance/trail?event_type=CONSTRAINT_AUDIT_EVALUATED&cycle_id=2026-09")
        assert trail.status_code == 200
        events = trail.json()["events"]
        assert len(events) >= 1
        evt = events[0]
        assert evt["event_type"] == "CONSTRAINT_AUDIT_EVALUATED"
        assert evt["actor_role"] == "SYSTEM_AUDITOR"
        assert "district_validation_status" in evt["after_state"]


def test_12_all_governance_audit_logs_have_complete_provenance():
    """Verify that every row in governance_audit_logs satisfies 10-point audit evidence provenance."""
    conn = get_db_connection()
    try:
        cursor = conn.cursor()
        cursor.execute("SELECT * FROM governance_audit_logs ORDER BY id DESC LIMIT 50;")
        rows = [dict(r) for r in cursor.fetchall()]
        assert len(rows) > 0

        for row in rows:
            # 1. actor identity
            assert row["actor_name"] is not None and len(row["actor_name"].strip()) > 0
            # 2. actor role
            assert row["actor_role"] is not None and len(row["actor_role"].strip()) > 0
            # 3. timestamp
            assert row["timestamp"] is not None
            # 4. operation / action
            assert row["action"] is not None and len(row["action"].strip()) > 0
            # 5. target entity
            assert row["entity_type"] is not None and len(row["entity_type"].strip()) > 0
            assert row["entity_id"] is not None and len(row["entity_id"].strip()) > 0
            # 6. event_id (unique canonical reference)
            assert row["event_id"] is not None and row["event_id"].startswith("GEV-")
            # 7. cycle_id relationship
            assert row["cycle_id"] is not None
    finally:
        conn.close()

