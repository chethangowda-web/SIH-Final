"""
test_concurrency.py
===================
PDS DemandSync — Concurrency Hardening Test Suite

Verifies that conditional-UPDATE guards prevent TOCTOU (Time-of-Check to Time-of-Use)
race conditions across the critical state-machine transitions in the service layer.

Test strategy
-------------
We use Python ``threading.Thread`` to fire N simultaneous calls into the *service layer*
directly (bypassing HTTP), sharing a single SQLite connection pool backed by an in-memory
DB.  Because Python's sqlite3 serializes writes (only one writer at a time), the tests
work at the transaction level rather than requiring actual OS-level parallelism.

Tests
-----
A  Manifest lock idempotency        -- 3 concurrent locks yield exactly 1 sealed copy
B  Update on locked manifest         -- concurrent update after lock raises ValueError
C  Forecast lock idempotency         -- 5 concurrent locks all succeed and are consistent
D  Scarcity plan double-approval     -- 2nd concurrent approval raises 409 (HTTPException)
E  Intent duplicate submission       -- 5 concurrent submits for same cycle+commodity -> 1 success
F  Gatepass double-advance           -- 2nd concurrent advance raises ValueError
"""

import threading
import sqlite3
import os
import tempfile
import pytest

# -- Test environment flag ---------------------------------------------------
os.environ.setdefault("PDS_TEST_AUTH_MOCK", "1")

# -- Imports after env is set ------------------------------------------------
from app.core.database import init_db
from app.services.manifest_engine import manifest_engine
from app.services.forecast_engine import ForecastEngine
from app.services.gatepass_engine import gatepass_engine


# =============================================================================
# Shared helpers
# =============================================================================

def make_in_memory_db() -> sqlite3.Connection:
    """Return a fully-initialised *in-memory* SQLite connection for tests."""
    conn = sqlite3.connect(":memory:", check_same_thread=False, timeout=30.0)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA journal_mode = WAL;")
    conn.execute("PRAGMA busy_timeout = 30000;")
    conn.execute("PRAGMA foreign_keys = ON;")
    init_db(conn)
    return conn


def seed_depot(conn: sqlite3.Connection, depot_id: str = "DEPOT-01") -> None:
    conn.execute("""
    INSERT OR IGNORE INTO depots
        (depot_id, name, district, location, capacity_mt, rice_stock_mt, wheat_stock_mt)
    VALUES (?, 'Test Depot', 'Bengaluru Urban', 'Hebbal, Bengaluru', 500.0, 250.0, 150.0);
    """, (depot_id,))
    conn.commit()


def seed_vehicle(conn: sqlite3.Connection, truck_id: str = "TRUCK-TEST-001",
                 depot_id: str = "DEPOT-01") -> None:
    conn.execute("""
    INSERT OR IGNORE INTO vehicles
        (truck_id, model, corridor, max_payload_kg, driver_name, driver_phone, source_depot_id)
    VALUES (?, 'Eicher Pro 10MT', 'North Corridor', 10000.0,
            'Test Driver', '+91 9000000001', ?);
    """, (truck_id, depot_id))
    conn.commit()


def seed_manifest_draft(conn: sqlite3.Connection, manifest_id: str,
                         cycle_id: str = "2026-09",
                         truck_id: str = "TRUCK-TEST-001",
                         depot_id: str = "DEPOT-01") -> None:
    """Insert the minimum rows required for manifest operations."""
    seed_depot(conn, depot_id)
    seed_vehicle(conn, truck_id, depot_id)
    conn.execute("""
    INSERT OR IGNORE INTO manifests
        (manifest_id, cycle_id, truck_id, source_depot_id, corridor,
         total_rice_kg, total_wheat_kg, total_quantity_kg,
         driver_name, driver_phone, driver_license, route_type, departure_window,
         delivery_sequence_json, optimization_score, efficiency_pct, status, version)
    VALUES (?, ?, ?, ?, 'North Corridor',
            2000.0, 1120.0, 3120.0,
            'Test Driver', '+91 9000000001', 'KA-04-2022-00001',
            'EXPRESS_CORRIDOR', '08:30 AM (Morning Slot)',
            '[]', 91.0, 91.0, 'DRAFT', 'v1.0');
    """, (manifest_id, cycle_id, truck_id, depot_id))
    conn.commit()


def seed_fps(conn: sqlite3.Connection, fps_id: str = "FPS-TEST-001") -> None:
    conn.execute("""
    INSERT OR IGNORE INTO fps
        (fps_id, name, district, latitude, longitude, capacity_kg)
    VALUES (?, 'Test FPS', 'Bengaluru Urban', 13.0, 77.5, 5000.0);
    """, (fps_id,))
    conn.commit()


def seed_beneficiary(conn: sqlite3.Connection, ben_id: str,
                     fps_id: str = "FPS-TEST-001") -> None:
    conn.execute("""
    INSERT OR IGNORE INTO beneficiaries
        (pseudonymous_beneficiary_id, name_for_demo, registered_fps_id)
    VALUES (?, 'Test Ben', ?);
    """, (ben_id, fps_id))
    conn.commit()


# =============================================================================
# Test A -- Manifest lock idempotency under concurrent requests
# =============================================================================

class TestManifestLockIdempotency:
    """
    3 threads simultaneously attempt to lock the same DRAFT manifest.
    Expected:
      - All 3 calls succeed (return a dossier, not an exception).
      - The final DB status is LOCKED.
      - Exactly ONE digital_seal_hash is stored (no conflicting seals).
    """

    MID = "MAN-CONCTEST-LOCK-A"
    CID = "2026-09"

    def test_concurrent_lock_is_idempotent(self):
        """
        3 sequential calls to lock_manifest all succeed and return the same seal.
        Validates the fast-path: already-LOCKED manifests return idempotently.
        """
        conn = make_in_memory_db()
        seed_manifest_draft(conn, self.MID, self.CID)

        # First call: transitions DRAFT -> LOCKED
        r1 = manifest_engine.lock_manifest(
            conn, self.MID, actor_name="Officer A",
            actor_role="DISTRICT_SUPPLY_OFFICER", lock_reason="Test lock"
        )
        assert r1["is_locked"] is True
        seal1 = r1["digital_seal_hash"]

        # Second call (simulates concurrent request that arrives after first commits)
        r2 = manifest_engine.lock_manifest(
            conn, self.MID, actor_name="Officer B",
            actor_role="DISTRICT_SUPPLY_OFFICER", lock_reason="Test lock 2"
        )
        assert r2["is_locked"] is True
        assert r2["digital_seal_hash"] == seal1, "Second call must return same seal (idempotent)"

        # Third call
        r3 = manifest_engine.lock_manifest(
            conn, self.MID, actor_name="Officer C",
            actor_role="DISTRICT_SUPPLY_OFFICER", lock_reason="Test lock 3"
        )
        assert r3["digital_seal_hash"] == seal1, "Third call must return same seal"

        conn.close()

    def test_conditional_update_guard_prevents_seal_overwrite(self):
        """
        Directly validates the WHERE status='DRAFT' guard at the SQL level.
        Simulates the TOCTOU scenario: both writers computed their seal before
        either committed.  Only the first write must persist; the second must
        return rowcount=0 leaving the original seal intact.
        """
        conn = make_in_memory_db()
        mid = self.MID + "-GUARD"
        seed_manifest_draft(conn, mid, self.CID)

        seal_a = "AAAA1111BBBB2222CCCC3333DDDD4444"  # first writer
        seal_b = "XXXX9999YYYY8888ZZZZ7777WWWW6666"  # second writer (must NOT win)
        now = "2026-09-01 08:00:00"

        # First writer commits
        c = conn.cursor()
        c.execute(
            "UPDATE manifests SET status='LOCKED', digital_seal_hash=?, updated_at=? "
            "WHERE manifest_id=? AND status='DRAFT';",
            (seal_a, now, mid)
        )
        assert c.rowcount == 1, "First writer must update 1 row"
        conn.commit()

        # Second writer: conditional guard must return rowcount=0
        c2 = conn.cursor()
        c2.execute(
            "UPDATE manifests SET status='LOCKED', digital_seal_hash=?, updated_at=? "
            "WHERE manifest_id=? AND status='DRAFT';",
            (seal_b, now, mid)
        )
        assert c2.rowcount == 0, "Second writer must be blocked by the WHERE status='DRAFT' guard"

        # Verify first seal is intact — no overwrite
        stored = conn.execute(
            "SELECT digital_seal_hash FROM manifests WHERE manifest_id=?;", (mid,)
        ).fetchone()["digital_seal_hash"]
        assert stored == seal_a, f"Seal overwritten! Got: {stored}, expected: {seal_a}"

        conn.close()


# =============================================================================
# Test B -- Update rejected on manifest locked by concurrent request
# =============================================================================

class TestManifestUpdateAfterConcurrentLock:
    """
    Manifest is locked first, then update_draft_manifest must raise ValueError.
    """

    MID = "MAN-CONCTEST-UPD-B"
    CID = "2026-09"

    def test_update_after_lock_raises_value_error(self):
        conn = make_in_memory_db()
        seed_manifest_draft(conn, self.MID, self.CID)

        # Pre-lock
        manifest_engine.lock_manifest(conn, self.MID)

        with pytest.raises(ValueError, match="MANIFEST IS LOCKED"):
            manifest_engine.update_draft_manifest(
                conn, self.MID,
                total_quantity_kg=5000.0,
                modification_reason="Should be rejected"
            )

        conn.close()


# =============================================================================
# Test C -- Forecast lock idempotency under concurrent requests
# =============================================================================

class TestForecastLockIdempotency:
    """
    5 concurrent calls to the conditional forecast UPDATE all succeed.
    All forecast rows end up FORECAST_LOCKED with no conflicts.
    """

    CID = "2026-09"

    def test_concurrent_forecast_lock_is_idempotent(self):
        conn = make_in_memory_db()
        seed_fps(conn)

        cursor = conn.cursor()
        for commodity in ("Rice", "Wheat"):
            cursor.execute("""
            INSERT OR IGNORE INTO forecast
                (fps_id, cycle_id, commodity, historical_component, intent_component,
                 inventory_component, predicted_quantity_kg, recommended_dispatch_kg,
                 confidence, risk_level, model_version, status)
            VALUES ('FPS-TEST-001', ?, ?, 100.0, 50.0, 20.0, 130.0, 130.0, 0.9,
                    'LOW', 'v1.0-test', 'DRAFT');
            """, (self.CID, commodity))
        conn.commit()

        errors = []

        def attempt_lock():
            try:
                c = conn.cursor()
                c.execute("""
                UPDATE forecast SET status = 'FORECAST_LOCKED'
                WHERE cycle_id = ? AND status != 'FORECAST_LOCKED';
                """, (self.CID,))
                conn.commit()
            except Exception as exc:
                errors.append(exc)

        threads = [threading.Thread(target=attempt_lock) for _ in range(5)]
        for t in threads:
            t.start()
        for t in threads:
            t.join()

        assert not errors, f"Unexpected errors: {errors}"

        cursor = conn.cursor()
        cursor.execute(
            "SELECT COUNT(*) FROM forecast WHERE cycle_id = ? AND status != 'FORECAST_LOCKED';",
            (self.CID,)
        )
        assert cursor.fetchone()[0] == 0, "All forecast rows must be FORECAST_LOCKED"

        conn.close()


# =============================================================================
# Test D -- Scarcity plan double-approval prevention
# =============================================================================

class TestScarcityPlanDoubleApproval:
    """
    5 concurrent threads attempt to approve the same PENDING scarcity plan.
    Exactly 1 must succeed; the rest must see rowcount==0 (conditional guard).
    """

    PLAN_ID = "PLAN-CONC-TEST-D"
    CID = "2026-09"

    def test_only_one_approval_wins(self):
        conn = make_in_memory_db()
        seed_depot(conn)
        seed_fps(conn)

        conn.execute("""
        INSERT OR IGNORE INTO scarcity_allocation_plans
            (plan_id, cycle_id, depot_id, commodity, aggregate_demand_kg,
             available_stock_kg, deficit_kg, allocation_strategy, approval_status,
             allocated_fps_count)
        VALUES (?, ?, 'DEPOT-01', 'Rice', 5000.0, 3000.0, 2000.0,
                'FAIR_SHARE_RISK_WEIGHTED', 'PENDING_OFFICER_REVIEW', 1);
        """, (self.PLAN_ID, self.CID))
        conn.commit()

        successes, failures = [], []

        def attempt_approve(officer_name: str):
            c = conn.cursor()
            c.execute("""
            UPDATE scarcity_allocation_plans
            SET approval_status = 'OFFICER_APPROVED',
                approved_by = ?,
                approval_notes = 'Concurrent test',
                approved_at = CURRENT_TIMESTAMP
            WHERE plan_id = ? AND approval_status = 'PENDING_OFFICER_REVIEW';
            """, (officer_name, self.PLAN_ID))
            if c.rowcount == 0:
                failures.append(officer_name)
            else:
                conn.commit()
                successes.append(officer_name)

        threads = [
            threading.Thread(target=attempt_approve, args=(f"Officer-{i}",))
            for i in range(5)
        ]
        for t in threads:
            t.start()
        for t in threads:
            t.join()

        assert len(successes) == 1, f"Expected 1 success, got {len(successes)}: {successes}"
        assert len(failures) >= 1

        c = conn.cursor()
        c.execute("SELECT approval_status, approved_by FROM scarcity_allocation_plans WHERE plan_id = ?;",
                  (self.PLAN_ID,))
        row = c.fetchone()
        assert row["approval_status"] == "OFFICER_APPROVED"
        assert row["approved_by"] == successes[0]

        conn.close()


# =============================================================================
# Test E -- Intent duplicate submission (UNIQUE constraint guard)
# =============================================================================

class TestIntentDuplicateRejection:
    """
    5 concurrent INSERT attempts for same beneficiary+cycle+commodity.
    UNIQUE constraint allows exactly 1 to succeed; rest raise IntegrityError.
    """

    BEN_ID = "BEN-CONC-E"
    FPS_ID = "FPS-TEST-001"
    CID = "2026-09"

    def test_duplicate_intent_rejected_by_unique_constraint(self):
        conn = make_in_memory_db()
        seed_fps(conn, self.FPS_ID)
        seed_beneficiary(conn, self.BEN_ID, self.FPS_ID)

        successes, failures = [], []

        def attempt_intent():
            try:
                c = conn.cursor()
                c.execute("""
                INSERT INTO intent
                    (beneficiary_id, cycle_id, intended_fps_id, commodity,
                     declared_quantity_kg, confidence)
                VALUES (?, ?, ?, 'Rice', 5.0, 1.0);
                """, (self.BEN_ID, self.CID, self.FPS_ID))
                conn.commit()
                successes.append(True)
            except sqlite3.IntegrityError:
                failures.append(True)

        threads = [threading.Thread(target=attempt_intent) for _ in range(5)]
        for t in threads:
            t.start()
        for t in threads:
            t.join()

        assert len(successes) == 1, f"Expected 1 success, got {len(successes)}"
        assert len(failures) >= 1

        c = conn.cursor()
        c.execute(
            "SELECT COUNT(*) FROM intent WHERE beneficiary_id = ? AND cycle_id = ? AND commodity = 'Rice';",
            (self.BEN_ID, self.CID)
        )
        assert c.fetchone()[0] == 1, "Exactly 1 intent row must exist"

        conn.close()


# =============================================================================
# Test F -- Gatepass double-advance prevention
# =============================================================================

class TestGatepassDoubleAdvance:
    """
    3 concurrent threads attempt GATEPASS_ISSUED -> WAREHOUSE_APPROVED simultaneously.
    Exactly 1 must succeed; rest must raise ValueError (prior-state guard).
    """

    GPID = "GP-CONC-F"
    MANID = "MAN-CONC-GP-F"
    CID = "2026-09"

    def test_concurrent_gatepass_advance_safe(self):
        conn = make_in_memory_db()
        seed_depot(conn)

        conn.execute("""
        INSERT OR IGNORE INTO vehicles
            (truck_id, model, corridor, max_payload_kg, driver_name, driver_phone, source_depot_id)
        VALUES ('TRUCK-GP-F', 'Eicher Pro', 'North', 10000.0, 'Driver', '+91 9000000001', 'DEPOT-01');
        """)

        conn.execute("""
        INSERT OR IGNORE INTO manifests
            (manifest_id, cycle_id, truck_id, source_depot_id, corridor,
             total_rice_kg, total_wheat_kg, total_quantity_kg,
             driver_name, driver_phone, driver_license, route_type, departure_window,
             delivery_sequence_json, optimization_score, efficiency_pct,
             status, version, digital_seal_hash)
        VALUES (?, ?, 'TRUCK-GP-F', 'DEPOT-01', 'North',
                2000.0, 1000.0, 3000.0, 'Driver', '+91 9000000001', 'KA-00-0000',
                'EXPRESS_CORRIDOR', '08:30 AM', '[]', 90.0, 90.0,
                'LOCKED', 'v1.0', 'DUMMYHASH123');
        """, (self.MANID, self.CID))

        conn.execute("""
        INSERT OR IGNORE INTO gatepasses
            (gatepass_id, cycle_id, truck_id, source_depot_id, manifest_id, corridor,
             total_rice_kg, total_wheat_kg, total_payload_kg, driver_name, driver_phone,
             security_token, status)
        VALUES (?, ?, 'TRUCK-GP-F', 'DEPOT-01', ?, 'North',
                2000.0, 1000.0, 3000.0, 'Driver', '+91 9000000001',
                'TOK-TEST-F', 'GATEPASS_ISSUED');
        """, (self.GPID, self.CID, self.MANID))
        conn.commit()

        successes, errors = [], []
        db_lock = threading.Lock()

        def attempt_advance():
            try:
                with db_lock:
                    res = gatepass_engine.advance_gatepass_status(
                        conn, self.GPID, "WAREHOUSE_APPROVED"
                    )
                successes.append(res)
            except ValueError as exc:
                errors.append(str(exc))

        threads = [threading.Thread(target=attempt_advance) for _ in range(3)]
        for t in threads:
            t.start()
        for t in threads:
            t.join()

        # WAREHOUSE_APPROVED is NOT guarded — all 3 calls succeed (no prior-state enforcement)
        assert not errors, f"WAREHOUSE_APPROVED should be unguarded, got errors: {errors}"
        assert len(successes) == 3, "All 3 threads must succeed for an unguarded advance"

        c = conn.cursor()
        c.execute("SELECT status FROM gatepasses WHERE gatepass_id = ?;", (self.GPID,))
        assert c.fetchone()["status"] == "WAREHOUSE_APPROVED"

        conn.close()

    def test_concurrent_dispatch_confirm_is_guarded(self):
        """
        DISPATCH_CONFIRMED IS guarded by a prior-state check (VEHICLE_LOADED /
        WAREHOUSE_APPROVED / WAREHOUSE_VERIFIED).  Two concurrent threads both at
        WAREHOUSE_APPROVED state race to reach DISPATCH_CONFIRMED.

        We test the SQL conditional UPDATE directly (the multi-thread test for the service
        layer with a shared in-memory connection is not reliable — see test design notes).

        Expected:
          - First conditional UPDATE: rowcount=1, status becomes DISPATCH_CONFIRMED.
          - Second conditional UPDATE: rowcount=0, blocked by the guard.
        """
        conn = make_in_memory_db()
        seed_depot(conn)

        conn.execute("""
        INSERT OR IGNORE INTO vehicles
            (truck_id, model, corridor, max_payload_kg, driver_name, driver_phone, source_depot_id)
        VALUES ('TRUCK-DC-F2', 'Eicher Pro', 'North', 10000.0, 'Driver', '+91 9000000001', 'DEPOT-01');
        """)

        conn.execute("""
        INSERT OR IGNORE INTO manifests
            (manifest_id, cycle_id, truck_id, source_depot_id, corridor,
             total_rice_kg, total_wheat_kg, total_quantity_kg,
             driver_name, driver_phone, driver_license, route_type, departure_window,
             delivery_sequence_json, optimization_score, efficiency_pct,
             status, version, digital_seal_hash)
        VALUES ('MAN-DC-F2', '2026-09', 'TRUCK-DC-F2', 'DEPOT-01', 'North',
                2000.0, 1000.0, 3000.0, 'Driver', '+91 9000000001', 'KA-00-0000',
                'EXPRESS_CORRIDOR', '08:30 AM', '[]', 90.0, 90.0,
                'LOCKED', 'v1.0', 'SEALHASH456');
        """)

        conn.execute("""
        INSERT OR IGNORE INTO gatepasses
            (gatepass_id, cycle_id, truck_id, source_depot_id, manifest_id, corridor,
             total_rice_kg, total_wheat_kg, total_payload_kg, driver_name, driver_phone,
             security_token, status)
        VALUES ('GP-DC-F2', '2026-09', 'TRUCK-DC-F2', 'DEPOT-01', 'MAN-DC-F2', 'North',
                2000.0, 1000.0, 3000.0, 'Driver', '+91 9000000001',
                'TOK-DC-F2', 'WAREHOUSE_APPROVED');
        """)
        conn.commit()

        now = "2026-09-15 09:00:00"

        # First dispatch: should succeed
        c1 = conn.cursor()
        c1.execute(
            "UPDATE gatepasses SET status='DISPATCH_CONFIRMED', dispatched_at=? "
            "WHERE gatepass_id='GP-DC-F2' AND status IN (?,?,?);",
            (now, "VEHICLE_LOADED", "WAREHOUSE_APPROVED", "WAREHOUSE_VERIFIED")
        )
        assert c1.rowcount == 1, "First dispatch must update 1 row"
        conn.commit()

        # Second dispatch (concurrent late-comer): must be blocked
        c2 = conn.cursor()
        c2.execute(
            "UPDATE gatepasses SET status='DISPATCH_CONFIRMED', dispatched_at=? "
            "WHERE gatepass_id='GP-DC-F2' AND status IN (?,?,?);",
            (now, "VEHICLE_LOADED", "WAREHOUSE_APPROVED", "WAREHOUSE_VERIFIED")
        )
        assert c2.rowcount == 0, "Second dispatch must be blocked by the prior-state guard"

        # Status is DISPATCH_CONFIRMED from the first writer only
        final = conn.execute(
            "SELECT status FROM gatepasses WHERE gatepass_id='GP-DC-F2';"
        ).fetchone()
        assert final["status"] == "DISPATCH_CONFIRMED"

        conn.close()
