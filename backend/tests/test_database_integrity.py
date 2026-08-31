"""
Database Integrity, Migration & Recovery Hardening Test Suite.
Verifies referential integrity (foreign keys), UNIQUE/CHECK constraints,
transaction rollback semantics, online backup/restore, migration idempotency,
and deep PRAGMA integrity diagnostics.
"""
import os
import tempfile
import sqlite3
import pytest
from httpx import AsyncClient, ASGITransport
from app.main import app
from app.core.config import settings
from app.core.auth import create_token
from app.core.database import (
    get_db_connection,
    init_db,
    recreate_db,
    run_migrations,
    get_schema_version,
    run_database_integrity_check,
    backup_database,
    restore_database
)
from app.data.seed_data import seed_all_data


@pytest.fixture(autouse=True)
def setup_database_env(monkeypatch):
    """Ensure mock auth is disabled and database is initialized and seeded."""
    monkeypatch.setenv("PDS_TEST_AUTH_MOCK", "0")
    init_db()
    seed_all_data(recreate=False)


@pytest.fixture
def admin_token():
    return create_token(
        {"username": "admin_user", "role": "ADMIN", "beneficiary_id": None}
    )


# -----------------------------------------------------------------------------
# 1. REFERENTIAL INTEGRITY & CONSTRAINT TESTS
# -----------------------------------------------------------------------------

def test_foreign_key_enforcement_blocks_invalid_beneficiary():
    """Ensure inserting an intent with a non-existent beneficiary raises IntegrityError."""
    conn = get_db_connection()
    cursor = conn.cursor()
    with pytest.raises(sqlite3.IntegrityError):
        cursor.execute("""
        INSERT INTO intent (beneficiary_id, cycle_id, intended_fps_id, commodity, declared_quantity_kg, confidence, status)
        VALUES ('NON-EXISTENT-BEN', '2026-09', 'FPS-KA-BLR-001', 'Rice', 25.0, 1.0, 'SUBMITTED');
        """)
        conn.commit()
    conn.close()


def test_foreign_key_enforcement_blocks_invalid_fps():
    """Ensure inserting an intent with a non-existent FPS raises IntegrityError."""
    conn = get_db_connection()
    cursor = conn.cursor()
    with pytest.raises(sqlite3.IntegrityError):
        cursor.execute("""
        INSERT INTO intent (beneficiary_id, cycle_id, intended_fps_id, commodity, declared_quantity_kg, confidence, status)
        VALUES ('BEN-KA-0001', '2026-09', 'NON-EXISTENT-FPS-999', 'Rice', 25.0, 1.0, 'SUBMITTED');
        """)
        conn.commit()
    conn.close()


def test_unique_constraint_enforcement_on_intent():
    """Ensure duplicate intent for same beneficiary, cycle, and commodity raises IntegrityError."""
    conn = get_db_connection()
    cursor = conn.cursor()
    # First intent insert
    cursor.execute("DELETE FROM intent WHERE beneficiary_id = 'BEN-KA-0001' AND cycle_id = '2026-09' AND commodity = 'Rice';")
    conn.commit()

    cursor.execute("""
    INSERT INTO intent (beneficiary_id, cycle_id, intended_fps_id, commodity, declared_quantity_kg, confidence, status)
    VALUES ('BEN-KA-0001', '2026-09', 'FPS-KA-BLR-001', 'Rice', 25.0, 1.0, 'SUBMITTED');
    """)
    conn.commit()

    # Second intent insert with same composite unique key
    with pytest.raises(sqlite3.IntegrityError):
        cursor.execute("""
        INSERT INTO intent (beneficiary_id, cycle_id, intended_fps_id, commodity, declared_quantity_kg, confidence, status)
        VALUES ('BEN-KA-0001', '2026-09', 'FPS-KA-BLR-002', 'Rice', 30.0, 0.9, 'SUBMITTED');
        """)
        conn.commit()
    conn.close()


def test_check_constraint_on_invalid_commodity():
    """Ensure invalid commodity name violates CHECK constraint."""
    conn = get_db_connection()
    cursor = conn.cursor()
    with pytest.raises(sqlite3.IntegrityError):
        cursor.execute("""
        INSERT INTO intent (beneficiary_id, cycle_id, intended_fps_id, commodity, declared_quantity_kg, confidence, status)
        VALUES ('BEN-KA-0001', '2026-09', 'FPS-KA-BLR-001', 'Barley', 25.0, 1.0, 'SUBMITTED');
        """)
        conn.commit()
    conn.close()


def test_check_constraint_on_non_positive_quantity():
    """Ensure 0 or negative declared quantity violates CHECK constraint."""
    conn = get_db_connection()
    cursor = conn.cursor()
    with pytest.raises(sqlite3.IntegrityError):
        cursor.execute("""
        INSERT INTO intent (beneficiary_id, cycle_id, intended_fps_id, commodity, declared_quantity_kg, confidence, status)
        VALUES ('BEN-KA-0001', '2026-09', 'FPS-KA-BLR-001', 'Rice', -5.0, 1.0, 'SUBMITTED');
        """)
        conn.commit()
    conn.close()


# -----------------------------------------------------------------------------
# 2. TRANSACTION INTEGRITY & ROLLBACK TESTS
# -----------------------------------------------------------------------------

def test_transaction_rollback_prevents_partial_writes():
    """Ensure failed transaction rolls back all partial mutations atomically."""
    conn = get_db_connection()
    cursor = conn.cursor()

    # Record baseline count
    cursor.execute("SELECT COUNT(*) FROM constraint_logs;")
    initial_count = cursor.fetchone()[0]

    # Attempt a multi-step operation where step 2 fails
    try:
        cursor.execute("BEGIN TRANSACTION;")
        # Step 1: Valid insert
        cursor.execute("""
        INSERT INTO constraint_logs (cycle_id, fps_id, rule_name, status, details)
        VALUES ('2026-09', 'FPS-KA-BLR-001', 'TEST_RULE_1', 'PASS', 'Step 1 success');
        """)
        # Step 2: Invalid insert (foreign key violation)
        cursor.execute("""
        INSERT INTO constraint_logs (cycle_id, fps_id, rule_name, status, details)
        VALUES ('2026-09', 'NON_EXISTENT_FPS', 'TEST_RULE_2', 'FAIL', 'Step 2 failure');
        """)
        conn.commit()
    except Exception:
        conn.rollback()

    # Verify that Step 1 was rolled back completely
    cursor.execute("SELECT COUNT(*) FROM constraint_logs;")
    final_count = cursor.fetchone()[0]
    assert final_count == initial_count
    conn.close()


# -----------------------------------------------------------------------------
# 3. DETERMINISTIC MIGRATION & IDEMPOTENCY TESTS
# -----------------------------------------------------------------------------

def test_migrations_are_idempotent_and_track_version():
    """Ensure running migrations multiple times leaves schema intact and tracks user_version."""
    conn = get_db_connection()

    # Initial migration execution
    results_1 = run_migrations(conn)
    # Re-running immediately should apply 0 new migrations
    results_2 = run_migrations(conn)
    assert len(results_2) == 0

    # Verify user_version is at latest (5)
    version = get_schema_version(conn)
    assert version >= 5

    cursor = conn.cursor()
    cursor.execute("SELECT COUNT(*) FROM schema_migrations;")
    migrations_count = cursor.fetchone()[0]
    assert migrations_count >= 5

    conn.close()


def test_init_db_preserves_existing_data():
    """Ensure calling init_db on a populated database does not drop or wipe data."""
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute("SELECT COUNT(*) FROM fps;")
    fps_before = cursor.fetchone()[0]
    assert fps_before == 20

    # Call init_db
    init_db(conn)

    cursor.execute("SELECT COUNT(*) FROM fps;")
    fps_after = cursor.fetchone()[0]
    assert fps_after == fps_before
    conn.close()


# -----------------------------------------------------------------------------
# 4. DEEP PRAGMA INTEGRITY DIAGNOSTICS
# -----------------------------------------------------------------------------

def test_database_integrity_diagnostic():
    """Verify deep diagnostic integrity check reports HEALTHY on the database."""
    conn = get_db_connection()
    report = run_database_integrity_check(conn)
    assert report["status"] == "HEALTHY"
    assert report["integrity_check_passed"] is True
    assert report["quick_check_passed"] is True
    assert report["foreign_keys_valid"] is True
    assert report["foreign_key_violations_count"] == 0
    assert report["journal_mode"].upper() == "WAL"
    assert report["foreign_keys_pragma_enabled"] is True
    assert report["user_version"] >= 5
    assert report["applied_migrations_count"] >= 5
    conn.close()


# -----------------------------------------------------------------------------
# 5. ONLINE NON-BLOCKING BACKUP & RESTORE TESTS
# -----------------------------------------------------------------------------

def test_online_backup_and_restore_cycle():
    """Verify online backup captures a valid snapshot and can be restored cleanly."""
    with tempfile.TemporaryDirectory() as tmpdir:
        backup_file = os.path.join(tmpdir, "test_backup.db")

        # 1. Perform online backup
        saved_path = backup_database(target_path=backup_file)
        assert os.path.exists(saved_path)
        assert os.path.getsize(saved_path) > 0

        # 2. Check backup file integrity
        backup_conn = get_db_connection(db_path=saved_path)
        diag = run_database_integrity_check(backup_conn)
        assert diag["status"] == "HEALTHY"
        assert diag["foreign_keys_valid"] is True

        cursor = backup_conn.cursor()
        cursor.execute("SELECT COUNT(*) FROM fps;")
        fps_in_backup = cursor.fetchone()[0]
        assert fps_in_backup == 20
        backup_conn.close()

        # 3. Test restore into a new empty SQLite database
        restore_target = os.path.join(tmpdir, "restored_target.db")
        target_conn = get_db_connection(db_path=restore_target)
        restore_res = restore_database(source_backup_path=saved_path, target_conn=target_conn)
        assert restore_res["status"] == "RESTORED"

        # Verify restored database has identical tables and rows
        t_cursor = target_conn.cursor()
        t_cursor.execute("SELECT COUNT(*) FROM fps;")
        assert t_cursor.fetchone()[0] == 20
        target_conn.close()


# -----------------------------------------------------------------------------
# 6. ADMIN INTEGRITY & BACKUP API ENDPOINTS
# -----------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_admin_database_integrity_endpoint(admin_token):
    """GET /api/admin/database/integrity returns 200 with HEALTHY status."""
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
        res = await ac.get(
            "/api/admin/database/integrity",
            headers={"Authorization": f"Bearer {admin_token}"}
        )
        assert res.status_code == 200
        data = res.json()
        assert data["status"] == "HEALTHY"
        assert data["integrity_check_passed"] is True
        assert data["journal_mode"].upper() == "WAL"


@pytest.mark.asyncio
async def test_admin_database_backup_endpoint(admin_token):
    """POST /api/admin/database/backup creates snapshot and returns 200."""
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
        res = await ac.post(
            "/api/admin/database/backup",
            headers={"Authorization": f"Bearer {admin_token}"}
        )
        assert res.status_code == 200
        data = res.json()
        assert data["status"] == "SUCCESS"
        assert "backup_file" in data
        assert os.path.exists(data["backup_file"])


# -----------------------------------------------------------------------------
# 7. PHASE 3 TRANSACTIONAL RESILIENCE & FAILURE INJECTION TESTS
# -----------------------------------------------------------------------------

def test_manifest_locking_atomic_rollback_on_midstream_failure():
    """Verify that if manifest locking encounters a mid-stream exception, the state rolls back to DRAFT."""
    conn = get_db_connection()
    try:
        cursor = conn.cursor()
        cycle_id = "2026-12"
        manifest_id = "MAN-TEST-ROLLBACK-01"

        cursor.execute("""
        INSERT INTO manifests (
            manifest_id, cycle_id, truck_id, source_depot_id, corridor,
            total_rice_kg, total_wheat_kg, total_quantity_kg,
            driver_name, driver_phone, status, version
        ) VALUES (?, ?, 'DEMO-KA-04-E-1021', 'DEPOT-01', 'North', 2000.0, 1120.0, 3120.0, 'Test Driver', '+91 9000000001', 'DRAFT', 'v1.0')
        ON CONFLICT(manifest_id) DO UPDATE SET status = 'DRAFT';
        """, (manifest_id, cycle_id))
        conn.commit()

        # Simulate mid-stream failure during lock operation
        try:
            cursor.execute("BEGIN TRANSACTION;")
            cursor.execute("UPDATE manifests SET status = 'LOCKED' WHERE manifest_id = ?;", (manifest_id,))
            # Force failure before commit
            cursor.execute("INSERT INTO non_existent_table VALUES (1);")
            conn.commit()
        except Exception:
            conn.rollback()

        cursor.execute("SELECT status FROM manifests WHERE manifest_id = ?;", (manifest_id,))
        row = cursor.fetchone()
        assert row["status"] == "DRAFT"
        cursor.execute("DELETE FROM manifests WHERE manifest_id = ?;", (manifest_id,))
        conn.commit()
    finally:
        conn.close()


def test_gatepass_advance_atomic_rollback_on_event_failure():
    """Verify that gatepass advance failure rolls back status cleanly."""
    conn = get_db_connection()
    try:
        cursor = conn.cursor()
        gp_id = "GP-TEST-RB-01"

        cursor.execute("""
        INSERT INTO gatepasses (
            gatepass_id, cycle_id, truck_id, source_depot_id, manifest_id, corridor,
            total_rice_kg, total_wheat_kg, total_payload_kg, driver_name, driver_phone,
            security_token, status
        ) VALUES (?, '2026-12', 'DEMO-KA-04-E-1021', 'DEPOT-01', 'MAN-01', 'North', 2000.0, 1120.0, 3120.0, 'Test Driver', '+91 9000000001', 'TOK-01', 'GATEPASS_ISSUED')
        ON CONFLICT(gatepass_id) DO UPDATE SET status = 'GATEPASS_ISSUED';
        """, (gp_id,))
        conn.commit()

        try:
            cursor.execute("BEGIN TRANSACTION;")
            cursor.execute("UPDATE gatepasses SET status = 'VEHICLE_LOADED' WHERE gatepass_id = ?;", (gp_id,))
            cursor.execute("INSERT INTO non_existent_table VALUES (1);")
            conn.commit()
        except Exception:
            conn.rollback()

        cursor.execute("SELECT status FROM gatepasses WHERE gatepass_id = ?;", (gp_id,))
        row = cursor.fetchone()
        assert row["status"] == "GATEPASS_ISSUED"
        cursor.execute("DELETE FROM gatepasses WHERE gatepass_id = ?;", (gp_id,))
        conn.commit()
    finally:
        conn.close()


def test_unlocked_manifest_blocks_gatepass_clearance():
    """Verify that gatepass engine rejects DISPATCH_CONFIRMED if manifest is in DRAFT."""
    from app.services.gatepass_engine import gatepass_engine
    conn = get_db_connection()
    try:
        cursor = conn.cursor()

        # Create DRAFT manifest using truck DEMO-KA-04-E-1022 on cycle 2026-12
        man_id = "MAN-TEST-UNLOCKED-02"
        cursor.execute("""
        INSERT INTO manifests (
            manifest_id, cycle_id, truck_id, source_depot_id, corridor,
            total_rice_kg, total_wheat_kg, total_quantity_kg,
            driver_name, driver_phone, status, version
        ) VALUES (?, '2026-12', 'DEMO-KA-04-E-1022', 'DEPOT-01', 'East', 2000.0, 1120.0, 3120.0, 'Test Driver', '+91 9000000001', 'DRAFT', 'v1.0')
        ON CONFLICT(manifest_id) DO UPDATE SET status = 'DRAFT';
        """, (man_id,))

        # Create Gatepass linked to DRAFT manifest
        gp_id = "GP-TEST-UNLOCKED-02"
        cursor.execute("""
        INSERT INTO gatepasses (
            gatepass_id, cycle_id, truck_id, source_depot_id, manifest_id, corridor,
            total_rice_kg, total_wheat_kg, total_payload_kg, driver_name, driver_phone,
            security_token, status
        ) VALUES (?, '2026-12', 'DEMO-KA-04-E-1022', 'DEPOT-01', ?, 'East', 2000.0, 1120.0, 3120.0, 'Test Driver', '+91 9000000001', 'TOK-DRAFT', 'VEHICLE_LOADED')
        ON CONFLICT(gatepass_id) DO UPDATE SET status = 'VEHICLE_LOADED', manifest_id = ?;
        """, (gp_id, man_id, man_id))
        conn.commit()

        with pytest.raises(ValueError) as exc:
            gatepass_engine.advance_gatepass_status(conn, gp_id, "DISPATCH_CONFIRMED")
        assert "requires a LOCKED" in str(exc.value)

        cursor.execute("DELETE FROM gatepasses WHERE gatepass_id = ?;", (gp_id,))
        cursor.execute("DELETE FROM manifests WHERE manifest_id = ?;", (man_id,))
        conn.commit()
    finally:
        conn.close()


def test_manifest_locked_requires_digital_seal_invariant():
    """Verify that a manifest in LOCKED status must possess a valid digital seal hash."""
    from app.services.manifest_engine import manifest_engine
    conn = get_db_connection()
    try:
        cursor = conn.cursor()
        cursor.execute("SELECT manifest_id FROM manifests WHERE status = 'LOCKED' LIMIT 1;")
        row = cursor.fetchone()
        if row:
            dossier = manifest_engine.get_manifest_dossier(conn, row[0])
            assert dossier.get("digital_seal_hash") is not None
            assert len(dossier["digital_seal_hash"]) >= 16
        else:
            # Generate and lock a test manifest to verify seal invariant
            dossier = manifest_engine.generate_corridor_manifest(conn, "DEMO-KA-51-M-3419", "2026-09")
            locked = manifest_engine.lock_manifest(conn, dossier["manifest_id"])
            assert locked.get("digital_seal_hash") is not None
            assert len(locked["digital_seal_hash"]) >= 16
    finally:
        conn.close()


def test_forecast_generation_is_idempotent_on_retry():
    """Verify that repeatedly generating forecasts for the same cycle safely updates existing rows without duplication."""
    from app.services.forecast_engine import forecast_engine
    conn = get_db_connection()
    try:
        cursor = conn.cursor()

        res1 = forecast_engine.generate_and_persist_forecasts(conn, "2026-09", force=True)
        cursor.execute("SELECT COUNT(*) FROM forecast WHERE cycle_id = '2026-09';")
        count1 = cursor.fetchone()[0]

        # Re-run generation immediately
        res2 = forecast_engine.generate_and_persist_forecasts(conn, "2026-09", force=True)
        cursor.execute("SELECT COUNT(*) FROM forecast WHERE cycle_id = '2026-09';")
        count2 = cursor.fetchone()[0]

        assert count1 == count2
        assert count1 == 40  # 20 FPS * 2 commodities (Rice + Wheat)
    finally:
        conn.close()




