"""Comprehensive Hardened Governance, Manifest Integrity, Gatepass Verification,
and Audit Lifecycle Test Suite for PDS DemandSync.
"""
import pytest
import sqlite3
import hashlib
from app.core.database import get_db_connection, init_db
from app.core.config import settings
from app.services.manifest_engine import manifest_engine
from app.services.gatepass_engine import gatepass_engine
from app.services.scarcity_engine import scarcity_allocation_engine
from app.services.forecast_engine import forecast_engine
from httpx import AsyncClient, ASGITransport
from app.main import app


@pytest.fixture(autouse=True)
def setup_test_database():
    """Ensure clean test database with required tables before running tests."""
    init_db()
    yield


# ============================================================================ #
# 1. MANIFEST CANONICAL HASHING & IMMUTABILITY TESTS
# ============================================================================ #

def test_manifest_canonical_hash_determinism():
    """Verify that identical manifest payloads always produce the identical deterministic hash."""
    manifest_data_1 = {
        "manifest_id": "MAN-2026-09-KA-NORT-1021",
        "cycle_id": "2026-09",
        "version": "v1.0",
        "truck_id": "DEMO-KA-04-E-1021",
        "source_depot_id": "DEPOT-01",
        "corridor": "North-West Heavy Corridor",
        "route_type": "EXPRESS_CORRIDOR",
        "total_rice_kg": 2000.0,
        "total_wheat_kg": 1120.0,
        "total_quantity_kg": 3120.0,
        "delivery_sequence": [
            {"sequence": 1, "fps_id": "FPS-KA-BLR-001", "fps_name": "Malleshwaram", "rice_kg": 1000.0, "wheat_kg": 560.0, "total_drop_kg": 1560.0, "latitude": 13.003, "longitude": 77.564},
            {"sequence": 2, "fps_id": "FPS-KA-BLR-004", "fps_name": "Rajajinagar", "rice_kg": 1000.0, "wheat_kg": 560.0, "total_drop_kg": 1560.0, "latitude": 12.998, "longitude": 77.553}
        ]
    }

    manifest_data_2 = dict(manifest_data_1)

    hash_1 = manifest_engine.compute_canonical_manifest_hash(manifest_data_1)
    hash_2 = manifest_engine.compute_canonical_manifest_hash(manifest_data_2)

    assert hash_1 == hash_2
    assert len(hash_1) == 32
    assert hash_1.isupper()


def test_manifest_canonical_hash_sensitivity():
    """Verify that any modification to material fields alters the digital seal."""
    base_data = {
        "manifest_id": "MAN-2026-09-KA-NORT-1021",
        "cycle_id": "2026-09",
        "version": "v1.0",
        "truck_id": "DEMO-KA-04-E-1021",
        "source_depot_id": "DEPOT-01",
        "corridor": "North-West Heavy Corridor",
        "route_type": "EXPRESS_CORRIDOR",
        "total_rice_kg": 2000.0,
        "total_wheat_kg": 1120.0,
        "total_quantity_kg": 3120.0,
        "delivery_sequence": [
            {"sequence": 1, "fps_id": "FPS-KA-BLR-001", "fps_name": "Malleshwaram", "rice_kg": 1000.0, "wheat_kg": 560.0, "total_drop_kg": 1560.0, "latitude": 13.003, "longitude": 77.564}
        ]
    }

    base_hash = manifest_engine.compute_canonical_manifest_hash(base_data)

    # 1. Change quantity by 1 kg
    mod_data = dict(base_data)
    mod_data["total_rice_kg"] = 2001.0
    mod_data["total_quantity_kg"] = 3121.0
    assert manifest_engine.compute_canonical_manifest_hash(mod_data) != base_hash

    # 2. Change truck
    mod_data2 = dict(base_data)
    mod_data2["truck_id"] = "DEMO-KA-04-E-1022"
    assert manifest_engine.compute_canonical_manifest_hash(mod_data2) != base_hash

    # 3. Change version
    mod_data3 = dict(base_data)
    mod_data3["version"] = "v1.1"
    assert manifest_engine.compute_canonical_manifest_hash(mod_data3) != base_hash


def test_locked_manifest_mutation_rejection():
    """Verify that updating a LOCKED manifest raises ValueError under NFSA rules."""
    conn = get_db_connection()
    try:
        manifest = manifest_engine.generate_corridor_manifest(conn, truck_id="DEMO-KA-04-E-1021", cycle_id="2026-09")
        mid = manifest["manifest_id"]

        # Ensure manifest is locked with current canonical seal
        cursor = conn.cursor()
        cursor.execute("UPDATE manifests SET status = 'DRAFT', digital_seal_hash = NULL WHERE manifest_id = ?;", (mid,))
        conn.commit()

        locked = manifest_engine.lock_manifest(conn, mid, lock_reason="Final pre-dispatch freeze")
        assert locked["is_locked"] is True
        assert locked["digital_seal_hash"] is not None

        # Attempt to update mutable field on locked manifest
        with pytest.raises(ValueError) as exc:
            manifest_engine.update_draft_manifest(conn, mid, total_quantity_kg=5000.0)
        assert "MANIFEST IS LOCKED" in str(exc.value)

        # Verification of seal should return VALID
        verify_res = manifest_engine.verify_manifest_seal(conn, mid)
        assert verify_res["is_valid"] is True
        assert verify_res["status"] == "VALID"
    finally:
        conn.close()


def test_tampered_manifest_detection():
    """Verify that if database fields are illegally tampered with, verify_manifest_seal detects TAMPERED."""
    conn = get_db_connection()
    try:
        manifest = manifest_engine.generate_corridor_manifest(conn, truck_id="DEMO-KA-51-M-3419", cycle_id="2026-09")
        mid = manifest["manifest_id"]

        cursor = conn.cursor()
        cursor.execute("UPDATE manifests SET status = 'DRAFT', digital_seal_hash = NULL WHERE manifest_id = ?;", (mid,))
        conn.commit()

        manifest_engine.lock_manifest(conn, mid)

        # Manually alter database field without going through engine
        cursor.execute("UPDATE manifests SET total_quantity_kg = total_quantity_kg + 100.0 WHERE manifest_id = ?;", (mid,))
        conn.commit()

        # Seal verification must detect mismatch
        verify_res = manifest_engine.verify_manifest_seal(conn, mid)
        assert verify_res["is_valid"] is False
        assert verify_res["status"] == "TAMPERED"
        assert "mismatch" in verify_res["reason"].lower()
    finally:
        conn.close()


def test_manifest_revision_generates_new_version_and_draft():
    """Verify that creating a revision increments version, resets lock, and logs REVISED audit event."""
    conn = get_db_connection()
    try:
        manifest = manifest_engine.generate_corridor_manifest(conn, truck_id="DEMO-KA-04-E-1022", cycle_id="2026-09")
        mid = manifest["manifest_id"]

        cursor = conn.cursor()
        cursor.execute("UPDATE manifests SET status = 'DRAFT', digital_seal_hash = NULL WHERE manifest_id = ?;", (mid,))
        conn.commit()

        manifest_engine.lock_manifest(conn, mid)

        # Create revision
        revised = manifest_engine.create_manifest_revision(conn, mid, revision_reason="Authorized monsoon quota adjustment")
        assert revised["is_locked"] is False
        assert revised["approval_status"] == "DRAFT"
        assert revised["version"].startswith("v1.") and revised["version"] != manifest["version"]
        assert revised["digital_seal_hash"] is None

        # Modifying the draft now succeeds
        updated = manifest_engine.update_draft_manifest(conn, mid, total_quantity_kg=4000.0)
        assert updated["total_quantity_kg"] == 4000.0

        # Audit log contains REVISED action
        audit = updated["audit_trail"]
        actions = [a["action"] for a in audit]
        assert "REVISED" in actions
    finally:
        conn.close()


# ============================================================================ #
# 2. DIGITAL GATEPASS VERIFICATION & MANIFEST LINKAGE TESTS
# ============================================================================ #

def test_gatepass_manifest_linkage_and_verification():
    """Verify gatepass deterministic security token and manifest-locked clearance."""
    conn = get_db_connection()
    try:
        truck_id = "DEMO-KA-04-E-1021"
        cycle_id = "2026-09"

        # 1. Ensure manifest is locked with current canonical seal
        manifest = manifest_engine.generate_corridor_manifest(conn, truck_id=truck_id, cycle_id=cycle_id)
        mid = manifest["manifest_id"]

        cursor = conn.cursor()
        cursor.execute("UPDATE manifests SET status = 'DRAFT', digital_seal_hash = NULL WHERE manifest_id = ?;", (mid,))
        conn.commit()

        manifest_engine.lock_manifest(conn, mid)

        # 2. Generate gatepass
        gp = gatepass_engine.generate_or_get_gatepass_for_truck(conn, truck_id=truck_id, cycle_id=cycle_id)
        gpid = gp["gatepass_id"]
        token = gp["security_token"]

        assert gp["manifest_id"] == mid
        assert token.startswith("GP-SEC-")

        # 3. Verify gatepass
        v_res = gatepass_engine.verify_gatepass(conn, gpid, security_token=token)
        assert v_res["is_valid"] is True
        assert v_res["status"] == "VALID"
        assert v_res["manifest_status"] == "LOCKED"

        # 4. Tampered token verification fails
        v_bad = gatepass_engine.verify_gatepass(conn, gpid, security_token="GP-SEC-FAKE123456")
        assert v_bad["is_valid"] is False
        assert v_bad["status"] == "TAMPERED_TOKEN"

        # 5. Advance gatepass through stages
        gp_wh = gatepass_engine.advance_gatepass_status(conn, gpid, "WAREHOUSE_APPROVED")
        assert gp_wh["status"] == "WAREHOUSE_APPROVED"

        gp_loaded = gatepass_engine.advance_gatepass_status(conn, gpid, "VEHICLE_LOADED")
        assert gp_loaded["status"] == "VEHICLE_LOADED"

        gp_disp = gatepass_engine.advance_gatepass_status(conn, gpid, "DISPATCH_CONFIRMED")
        assert gp_disp["status"] == "DISPATCH_CONFIRMED"
    finally:
        conn.close()


def test_gatepass_clearance_blocked_if_manifest_unlocked():
    """Verify that advancing gatepass to DISPATCH_CONFIRMED is rejected if manifest is unlocked/DRAFT."""
    conn = get_db_connection()
    try:
        truck_id = "DEMO-KA-04-E-1022"
        cycle_id = "2026-09"

        manifest = manifest_engine.generate_corridor_manifest(conn, truck_id=truck_id, cycle_id=cycle_id)
        mid = manifest["manifest_id"]

        # Ensure manifest is in DRAFT mode
        cursor = conn.cursor()
        cursor.execute("UPDATE manifests SET status = 'DRAFT', digital_seal_hash = NULL WHERE manifest_id = ?;", (mid,))
        conn.commit()

        gp = gatepass_engine.generate_or_get_gatepass_for_truck(conn, truck_id=truck_id, cycle_id=cycle_id)
        gpid = gp["gatepass_id"]

        # Verification reports MANIFEST_NOT_LOCKED
        v_res = gatepass_engine.verify_gatepass(conn, gpid)
        assert v_res["is_valid"] is False
        assert v_res["status"] == "MANIFEST_NOT_LOCKED"

        # Advance to DISPATCH_CONFIRMED must raise ValueError
        with pytest.raises(ValueError) as exc:
            gatepass_engine.advance_gatepass_status(conn, gpid, "DISPATCH_CONFIRMED")
        assert "Gate clearance requires a LOCKED" in str(exc.value)
    finally:
        conn.close()


# ============================================================================ #
# 3. CHOICE-WINDOW CLOSURE & POST-CLOSURE INTENT REJECTION
# ============================================================================ #

@pytest.mark.asyncio
async def test_choice_window_intent_rejection_after_close():
    """Verify server-side rejection of POST /intent once Choice Window is closed / demand is locked."""
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        cycle_id = "2026-09"

        # 1. Close Choice Window / Lock Demand
        close_res = await ac.post(f"/api/admin/choice-window/close?cycle_id={cycle_id}")
        assert close_res.status_code == 200
        assert close_res.json()["status"] == "CHOICE_WINDOW_CLOSED"

        # 2. Attempt POST /intent -> Must be rejected with 400 Bad Request
        intent_payload = {
            "beneficiary_id": "BEN-KA-0001",
            "cycle_id": cycle_id,
            "intended_fps_id": "FPS-KA-BLR-004",
            "commodity": "Rice",
            "declared_quantity_kg": 25.0,
            "confidence": 0.95
        }
        post_res = await ac.post("/api/intent", json=intent_payload)
        assert post_res.status_code == 400
        assert "closed" in post_res.json()["detail"].lower()


# ============================================================================ #
# 4. SCARCITY STATUTORY FLOOR SAFETY & OFFICER GOVERNANCE
# ============================================================================ #

def test_scarcity_statutory_floors_guaranteed_in_feasible_deficit():
    """Verify that in feasible scarcity (stock >= floors), all statutory floors are 100% satisfied."""
    conn = get_db_connection()
    try:
        sim = scarcity_allocation_engine.simulate_scarcity_plan(
            conn,
            depot_id="DEPOT-01",
            commodity="Rice",
            available_depot_stock_kg=22000.0,
            cycle_id="2026-09",
            allocation_strategy="FAIR_SHARE_RISK_WEIGHTED"
        )

        assert sim["is_statutory_floor_satisfied"] is True
        assert sim["statutory_floor_status"] == "STATUTORY_FLOORS_SATISFIED"
        for item in sim["allocated_items"]:
            assert item["statutory_floor_satisfied"] is True
            assert item["reconciled_allocation_kg"] >= item["statutory_floor_kg"] - 0.01
    finally:
        conn.close()


def test_scarcity_critical_deficit_explicit_infeasibility_reporting():
    """Verify that in severe deficit (stock < floors), system explicitly reports STATUTORY_FLOORS_UNSATISFIABLE."""
    conn = get_db_connection()
    try:
        sim = scarcity_allocation_engine.simulate_scarcity_plan(
            conn,
            depot_id="DEPOT-01",
            commodity="Rice",
            available_depot_stock_kg=1000.0,  # Below total statutory floors (3694.4 kg)
            cycle_id="2026-09"
        )

        assert sim["is_statutory_floor_satisfied"] is False
        assert sim["statutory_floor_status"] == "STATUTORY_FLOORS_UNSATISFIABLE"
        assert sim["governance_alert"] is not None
        assert "STATUTORY_FLOORS_UNSATISFIABLE" in sim["governance_alert"]
    finally:
        conn.close()


@pytest.mark.asyncio
async def test_scarcity_plan_officer_approval_and_duplicate_prevention():
    """Verify staging a plan, officer approval with role check, and rejection of duplicate approvals."""
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        cycle_id = "2026-09"

        # 1. Stage a scarcity plan
        stage_payload = {
            "depot_id": "DEPOT-01",
            "commodity": "Rice",
            "available_depot_stock_kg": 20000.0,
            "cycle_id": cycle_id,
            "allocation_strategy": "FAIR_SHARE_RISK_WEIGHTED",
            "persist_candidate": True,
            "notes": "Staged for DSO review"
        }
        stage_res = await ac.post("/api/admin/scarcity/simulate-fair-share", json=stage_payload)
        assert stage_res.status_code == 200
        plan_id = stage_res.json()["plan_id"]
        assert plan_id is not None

        # 2. Unauthorized role approval rejected
        bad_auth = {
            "plan_id": plan_id,
            "officer_name": "Unauthorized User",
            "officer_role": "CITIZEN_USER",
            "justification": "Trying unauthorized approval"
        }
        bad_res = await ac.post("/api/admin/scarcity/approve-plan", json=bad_auth)
        assert bad_res.status_code == 403

        # 3. Authorized DSO approval succeeds
        good_auth = {
            "plan_id": plan_id,
            "officer_name": "K. Srinivas Murthy",
            "officer_role": "DISTRICT_SUPPLY_OFFICER",
            "justification": "NFSA Section 3 compliant fair-share allocation authorized"
        }
        appr_res = await ac.post("/api/admin/scarcity/approve-plan", json=good_auth)
        assert appr_res.status_code == 200
        assert appr_res.json()["approval_status"] == "OFFICER_APPROVED"

        # 4. Duplicate approval rejected with 400 Bad Request
        dup_res = await ac.post("/api/admin/scarcity/approve-plan", json=good_auth)
        assert dup_res.status_code == 400
        assert "already been approved" in dup_res.json()["detail"].lower()


# ============================================================================ #
# 5. API VERIFICATION ENDPOINTS TESTS
# ============================================================================ #

@pytest.mark.asyncio
async def test_api_manifest_and_gatepass_verify_endpoints():
    """Verify GET /admin/manifests/{id}/verify-seal and POST /admin/gatepasses/verify endpoints."""
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        cycle_id = "2026-09"
        truck_id = "DEMO-KA-04-E-1021"

        conn = get_db_connection()
        try:
            cursor = conn.cursor()
            cursor.execute("UPDATE manifests SET status = 'DRAFT', digital_seal_hash = NULL WHERE truck_id = ? AND cycle_id = ?;", (truck_id, cycle_id))
            conn.commit()
        finally:
            conn.close()

        # Generate / fetch manifest
        await ac.post(f"/api/admin/manifests/generate?truck_id={truck_id}&cycle_id={cycle_id}")
        manifest_list = await ac.get(f"/api/admin/manifests?cycle_id={cycle_id}")
        mid = manifest_list.json()["manifests"][0]["manifest_id"]

        # Lock manifest
        await ac.post(f"/api/admin/manifests/{mid}/lock", json={
            "actor_name": "District Supply Officer",
            "actor_role": "DISTRICT_SUPPLY_OFFICER",
            "lock_reason": "Testing seal endpoint"
        })

        # Test manifest verify-seal endpoint
        m_verify = await ac.get(f"/api/admin/manifests/{mid}/verify-seal")
        assert m_verify.status_code == 200
        assert m_verify.json()["is_valid"] is True
        assert m_verify.json()["status"] == "VALID"

        # Test gatepass verify endpoint
        gp_res = await ac.get(f"/api/admin/gatepass/{truck_id}?cycle_id={cycle_id}")
        gpid = gp_res.json()["gatepass_id"]
        token = gp_res.json()["security_token"]

        gp_verify = await ac.post("/api/admin/gatepasses/verify", json={
            "gatepass_id": gpid,
            "security_token": token
        })
        assert gp_verify.status_code == 200
        assert gp_verify.json()["is_valid"] is True
        assert gp_verify.json()["status"] == "VALID"
