"""Deterministic Planning-Cycle Engine & Demand Lock Snapshot Service.

Implements the authoritative PDS Planning Lifecycle:
Day 21–24: Beneficiary Choice Window OPEN (location & channel selection)
Day 25: Demand Lock (officer freezes demand snapshot D_hat, closes choice window)
Day 25+: Downstream Planning & Logistics Dispatch

Enforces immutable frozen demand snapshots, cryptographic SHA-256 integrity sealing,
and prevents preference mutations after lock.
"""

import sqlite3
import json
import hashlib
from datetime import datetime
from typing import Dict, Any, List, Optional, Tuple

from app.core.config import settings
from app.core.logging_config import get_logger
from app.services.governance_trail import governance_trail

logger = get_logger("planning_cycle")

DEMO_NOTICE = "DEMO DATA — NOT GOVERNMENT DATA (PLANNING CYCLE ENGINE)"

# Canonical cycle schedule configuration
DEFAULT_PLANNING_DAY = 22  # By default for active cycle demo, Choice Window is OPEN (Day 22 of 21-24)
CHOICE_WINDOW_START_DAY = 21
CHOICE_WINDOW_END_DAY = 24
DEMAND_LOCK_DAY = 25


class PlanningCycleEngine:
    """Core Service managing Planning-Cycle Days, Choice-Window State, and Immutable Demand Snapshots."""

    def ensure_tables(self, db: sqlite3.Connection) -> None:
        """Ensure demand_snapshots and planning_cycle_state tables exist."""
        cursor = db.cursor()
        cursor.execute("""
        CREATE TABLE IF NOT EXISTS demand_snapshots (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            snapshot_id TEXT UNIQUE NOT NULL,
            cycle_id TEXT NOT NULL,
            version TEXT NOT NULL DEFAULT 'v1.0',
            lock_status TEXT NOT NULL DEFAULT 'LOCKED',
            lock_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            locked_by TEXT NOT NULL,
            total_beneficiary_requests INTEGER NOT NULL,
            total_declared_intent_kg REAL NOT NULL,
            total_locked_demand_kg REAL NOT NULL,
            fps_demand_json TEXT NOT NULL,
            commodity_quantities_json TEXT NOT NULL,
            location_distribution_json TEXT NOT NULL,
            canonical_hash TEXT NOT NULL,
            is_frozen INTEGER NOT NULL DEFAULT 1,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        );
        """)
        cursor.execute("CREATE INDEX IF NOT EXISTS idx_demand_snapshots_cycle ON demand_snapshots (cycle_id);")

        cursor.execute("""
        CREATE TABLE IF NOT EXISTS planning_cycle_config (
            cycle_id TEXT PRIMARY KEY,
            planning_day INTEGER NOT NULL DEFAULT 22,
            is_manual_override INTEGER NOT NULL DEFAULT 0,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        );
        """)
        db.commit()

    def get_planning_day(self, db: sqlite3.Connection, cycle_id: str = settings.CURRENT_CYCLE) -> int:
        """
        Get the current planning day (e.g., 21..25+) for the given cycle.
        Defaults to Day 22 if choice window is open, or Day 25 if locked.
        """
        self.ensure_tables(db)
        cursor = db.cursor()
        cursor.execute("SELECT planning_day FROM planning_cycle_config WHERE cycle_id = ?;", (cycle_id,))
        row = cursor.fetchone()
        if row is not None:
            return int(row[0])

        # Infer from workflow status: if locked/closed -> Day 25, else Day 22 (open)
        from app.services.forecast_engine import forecast_engine
        status = forecast_engine.get_persisted_workflow_status(db, cycle_id)
        if status in ["FORECAST_LOCKED", "CHOICE_WINDOW_CLOSED", "VALIDATED", "ALLOCATED", "OPTIMIZED", "DISPATCH_GENERATED"]:
            return DEMAND_LOCK_DAY
        return DEFAULT_PLANNING_DAY

    def set_planning_day(self, db: sqlite3.Connection, cycle_id: str, day: int) -> int:
        """Manually advance or set the planning day for demo testing (e.g. Day 21 -> 24 -> 25, or re-open back to 22)."""
        self.ensure_tables(db)
        cursor = db.cursor()
        cursor.execute("""
        INSERT INTO planning_cycle_config (cycle_id, planning_day, is_manual_override, updated_at)
        VALUES (?, ?, 1, CURRENT_TIMESTAMP)
        ON CONFLICT(cycle_id) DO UPDATE SET
            planning_day = excluded.planning_day,
            is_manual_override = 1,
            updated_at = CURRENT_TIMESTAMP;
        """, (cycle_id, day))

        # If re-opening before Day 25 for demo presentation:
        if day < DEMAND_LOCK_DAY:
            cursor.execute("DELETE FROM demand_snapshots WHERE cycle_id = ?;", (cycle_id,))
            cursor.execute("UPDATE forecast SET status = 'DRAFT' WHERE cycle_id = ?;", (cycle_id,))
            from app.services.workflow_manager import workflow_manager, WorkflowState
            workflow_manager.transition_state(
                db, cycle_id, WorkflowState.FORECASTED,
                "District Supply Officer (Demo Admin)", "DISTRICT_SUPPLY_OFFICER",
                f"Demo mode: Planning cycle set to Day {day}. Choice window re-opened.", force=True
            )

        db.commit()
        return day

    def get_cycle_state(self, db: sqlite3.Connection, cycle_id: str = settings.CURRENT_CYCLE) -> Dict[str, Any]:
        """
        Get comprehensive deterministic planning-cycle and choice-window status.
        Returns whether the choice window is open, current planning day, and demand lock status.
        """
        self.ensure_tables(db)
        cursor = db.cursor()

        from app.services.forecast_engine import forecast_engine
        workflow_status = forecast_engine.get_persisted_workflow_status(db, cycle_id)
        planning_day = self.get_planning_day(db, cycle_id)

        snapshot = self.get_latest_snapshot(db, cycle_id)
        is_workflow_open = workflow_status in ["PLANNING_OPEN", "DRAFT_GENERATED", "DRAFT"]
        is_day_in_window = (CHOICE_WINDOW_START_DAY <= planning_day <= CHOICE_WINDOW_END_DAY)
        # Choice window is open if within days 21..24 and demand snapshot has not yet been sealed
        is_open = (snapshot is None) and (planning_day < DEMAND_LOCK_DAY)

        # Fetch intent statistics
        cursor.execute("""
        SELECT COUNT(DISTINCT beneficiary_id), COALESCE(SUM(declared_quantity_kg), 0.0)
        FROM intent
        WHERE cycle_id = ?;
        """, (cycle_id,))
        cnt_row = cursor.fetchone()
        intents_count = int(cnt_row[0]) if cnt_row else 0
        declared_kg = round(float(cnt_row[1]), 1) if cnt_row else 0.0

        # Check existing snapshot
        snapshot = self.get_latest_snapshot(db, cycle_id)
        is_demand_locked = (snapshot is not None) or (not is_open and not is_workflow_open)

        stage_label = "BENEFICIARY CHOICE WINDOW" if is_open else ("DEMAND LOCK BASELINE" if planning_day == 25 else "DISPATCH PLANNING")

        return {
            "cycle_id": cycle_id,
            "planning_day": planning_day,
            "choice_window_start_day": CHOICE_WINDOW_START_DAY,
            "choice_window_end_day": CHOICE_WINDOW_END_DAY,
            "demand_lock_day": DEMAND_LOCK_DAY,
            "is_open": is_open,
            "status": "CHOICE_WINDOW_OPEN" if is_open else "CHOICE_WINDOW_CLOSED",
            "stage_label": stage_label,
            "workflow_status": workflow_status,
            "is_demand_locked": is_demand_locked,
            "active_intents_count": intents_count,
            "total_declared_intent_kg": declared_kg,
            "snapshot_version": snapshot["version"] if snapshot else None,
            "snapshot_hash": snapshot["canonical_hash"] if snapshot else None,
            "closing_deadline": f"Day {CHOICE_WINDOW_END_DAY} of Planning Cycle (23:59 IST)",
            "governance_notice": "Beneficiary preference is a location/channel selection signal. Statutory entitlement ceiling remains government-controlled.",
            "demo_notice": DEMO_NOTICE
        }

    def compute_canonical_snapshot_hash(self, payload: Dict[str, Any]) -> str:
        """Generate a tamper-evident SHA-256 integrity hash for a frozen demand snapshot."""
        canonical_str = json.dumps(payload, sort_keys=True, separators=(',', ':'))
        return hashlib.sha256(canonical_str.encode("utf-8")).hexdigest()

    def lock_demand_snapshot(
        self,
        db: sqlite3.Connection,
        cycle_id: str = settings.CURRENT_CYCLE,
        officer_name: str = "District Supply Officer (Demo Admin)",
        officer_role: str = "DISTRICT_SUPPLY_OFFICER"
    ) -> Dict[str, Any]:
        """
        Idempotent demand lock operation:
        1. Aggregates all submitted beneficiary preferences for the cycle.
        2. Computes frozen FPS-wise and commodity-wise totals and location shift distributions.
        3. Freezes an immutable snapshot record with cryptographic SHA-256 hash.
        4. Transitions planning_day to Day 25 and workflow state to FORECAST_LOCKED.
        5. Logs an authoritative governance audit trail.
        """
        self.ensure_tables(db)
        cursor = db.cursor()

        # Idempotency check: Return existing snapshot if already locked
        existing = self.get_latest_snapshot(db, cycle_id)
        if existing:
            # Ensure planning day is at least 25
            self.set_planning_day(db, cycle_id, DEMAND_LOCK_DAY)
            return {
                "status": "ALREADY_LOCKED",
                "message": f"Demand for cycle '{cycle_id}' is already frozen in snapshot {existing['snapshot_id']}.",
                "snapshot": existing,
                "snapshot_id": existing["snapshot_id"],
                "canonical_hash": existing["canonical_hash"],
                "version": existing["version"],
                "cycle_id": cycle_id,
                "planning_day": DEMAND_LOCK_DAY,
                "workflow_status": "FORECAST_LOCKED",
                "demo_notice": DEMO_NOTICE
            }

        # 1. Aggregate beneficiary intent preferences
        cursor.execute("""
        SELECT 
            i.intended_fps_id,
            p.name as fps_name,
            i.commodity,
            COUNT(DISTINCT i.beneficiary_id) as requests_count,
            COALESCE(SUM(i.declared_quantity_kg), 0.0) as declared_kg
        FROM intent i
        LEFT JOIN fps p ON i.intended_fps_id = p.fps_id
        WHERE i.cycle_id = ?
        GROUP BY i.intended_fps_id, i.commodity;
        """, (cycle_id,))
        intent_rows = cursor.fetchall()

        fps_demand: Dict[str, Dict[str, Any]] = {}
        commodity_totals: Dict[str, float] = {"Rice": 0.0, "Wheat": 0.0}
        total_requests = 0
        total_declared_kg = 0.0

        for r in intent_rows:
            fid = r["intended_fps_id"]
            comm = r["commodity"]
            count = int(r["requests_count"])
            qty = round(float(r["declared_kg"]), 1)

            if fid not in fps_demand:
                fps_demand[fid] = {
                    "fps_id": fid,
                    "fps_name": r["fps_name"] or fid,
                    "commodities": {},
                    "total_requests": 0,
                    "total_declared_kg": 0.0
                }
            fps_demand[fid]["commodities"][comm] = qty
            fps_demand[fid]["total_requests"] += count
            fps_demand[fid]["total_declared_kg"] = round(fps_demand[fid]["total_declared_kg"] + qty, 1)

            commodity_totals[comm] = round(commodity_totals.get(comm, 0.0) + qty, 1)
            total_requests += count
            total_declared_kg = round(total_declared_kg + qty, 1)

        # 2. Location distribution: Home vs Portability declarations
        cursor.execute("""
        SELECT 
            COUNT(CASE WHEN i.intended_fps_id = b.registered_fps_id THEN 1 END) as home_count,
            COUNT(CASE WHEN i.intended_fps_id != b.registered_fps_id THEN 1 END) as portability_count
        FROM intent i
        JOIN beneficiaries b ON i.beneficiary_id = b.pseudonymous_beneficiary_id
        WHERE i.cycle_id = ?;
        """, (cycle_id,))
        dist_row = cursor.fetchone()
        home_count = int(dist_row[0]) if dist_row else 0
        portability_count = int(dist_row[1]) if dist_row else 0
        location_distribution = {
            "home_fps_collections": home_count,
            "portability_shifts": portability_count,
            "portability_percentage": round((portability_count / max(1, home_count + portability_count)) * 100.0, 1)
        }

        # 3. Generate forecasts from intent and lock them in forecast_engine
        from app.services.forecast_engine import forecast_engine
        forecast_res = forecast_engine.generate_and_persist_forecasts(db, cycle_id=cycle_id, force=True)
        lock_res = forecast_engine.lock_persisted_forecast(db, cycle_id=cycle_id)

        # Get total forecast demand
        cursor.execute("SELECT COALESCE(SUM(predicted_quantity_kg), 0.0) FROM forecast WHERE cycle_id = ?;", (cycle_id,))
        total_forecast_kg = round(float(cursor.fetchone()[0]), 1)

        # 4. Generate Snapshot ID and Canonical Hash
        timestamp_str = datetime.now().strftime("%Y-%m-%d %H:%M:%S UTC+05:30")
        snapshot_id = f"SNAP-{cycle_id}-DEMAND-LOCK-v1"
        version = "v1.0"

        canonical_data = {
            "snapshot_id": snapshot_id,
            "cycle_id": cycle_id,
            "version": version,
            "lock_status": "LOCKED",
            "total_beneficiary_requests": total_requests,
            "total_declared_intent_kg": total_declared_kg,
            "total_locked_demand_kg": total_forecast_kg,
            "commodity_totals": commodity_totals,
            "location_distribution": location_distribution,
            "fps_count": len(fps_demand)
        }
        canonical_hash = self.compute_canonical_snapshot_hash(canonical_data)

        # 5. Insert Snapshot into DB
        cursor.execute("""
        INSERT INTO demand_snapshots (
            snapshot_id, cycle_id, version, lock_status, lock_timestamp, locked_by,
            total_beneficiary_requests, total_declared_intent_kg, total_locked_demand_kg,
            fps_demand_json, commodity_quantities_json, location_distribution_json,
            canonical_hash, is_frozen
        ) VALUES (?, ?, ?, 'LOCKED', CURRENT_TIMESTAMP, ?, ?, ?, ?, ?, ?, ?, ?, 1);
        """, (
            snapshot_id, cycle_id, version, officer_name,
            total_requests, total_declared_kg, total_forecast_kg,
            json.dumps(fps_demand), json.dumps(commodity_totals), json.dumps(location_distribution),
            canonical_hash
        ))

        # 6. Set planning day to Day 25
        self.set_planning_day(db, cycle_id, DEMAND_LOCK_DAY)

        # 7. Update workflow state machine
        from app.services.workflow_manager import workflow_manager, WorkflowState
        workflow_manager.transition_state(
            db, cycle_id, WorkflowState.VALIDATED,
            officer_name, officer_role,
            f"Demand Lock completed on Day {DEMAND_LOCK_DAY}. Snapshot {snapshot_id} frozen with SHA-256 seal.",
            force=True
        )

        db.commit()

        # 8. Record in Unified Governance Audit Log
        governance_trail.record_event(
            db=db,
            event_type="DEMAND_LOCKED",
            action="LOCK_AGGREGATED_DEMAND_SNAPSHOT",
            entity_type="DEMAND_SNAPSHOT",
            entity_id=snapshot_id,
            actor_name=officer_name,
            actor_role=officer_role,
            cycle_id=cycle_id,
            before_state={"choice_window": "OPEN", "planning_day": CHOICE_WINDOW_END_DAY},
            after_state={
                "choice_window": "CLOSED",
                "planning_day": DEMAND_LOCK_DAY,
                "snapshot_id": snapshot_id,
                "total_locked_demand_kg": total_forecast_kg,
                "canonical_hash": canonical_hash
            },
            notes=f"Demand baseline frozen into tamper-evident snapshot {snapshot_id} for cycle {cycle_id}",
            integrity_metadata={"sha256": canonical_hash},
            is_success=True,
            is_simulation=False
        )

        logger.info("Demand snapshot locked: snapshot_id='%s', cycle='%s', hash='%s'", snapshot_id, cycle_id, canonical_hash[:12])

        return {
            "status": "LOCKED",
            "snapshot_id": snapshot_id,
            "version": version,
            "cycle_id": cycle_id,
            "planning_day": DEMAND_LOCK_DAY,
            "total_beneficiary_requests": total_requests,
            "total_declared_intent_kg": total_declared_kg,
            "total_locked_demand_kg": total_forecast_kg,
            "commodity_totals": commodity_totals,
            "location_distribution": location_distribution,
            "canonical_hash": canonical_hash,
            "message": f"Demand baseline for cycle '{cycle_id}' is permanently LOCKED into snapshot {snapshot_id}.",
            "demo_notice": DEMO_NOTICE
        }

    def get_latest_snapshot(self, db: sqlite3.Connection, cycle_id: str = settings.CURRENT_CYCLE) -> Optional[Dict[str, Any]]:
        """Retrieve the frozen demand snapshot for a cycle if one exists."""
        self.ensure_tables(db)
        cursor = db.cursor()
        cursor.execute("""
        SELECT 
            snapshot_id, cycle_id, version, lock_status, lock_timestamp, locked_by,
            total_beneficiary_requests, total_declared_intent_kg, total_locked_demand_kg,
            fps_demand_json, commodity_quantities_json, location_distribution_json,
            canonical_hash, is_frozen
        FROM demand_snapshots
        WHERE cycle_id = ?
        ORDER BY id DESC LIMIT 1;
        """, (cycle_id,))
        row = cursor.fetchone()
        if not row:
            return None

        return {
            "snapshot_id": row[0],
            "cycle_id": row[1],
            "version": row[2],
            "lock_status": row[3],
            "lock_timestamp": str(row[4]),
            "locked_by": row[5],
            "total_beneficiary_requests": int(row[6]),
            "total_declared_intent_kg": float(row[7]),
            "total_locked_demand_kg": float(row[8]),
            "fps_demand": json.loads(row[9]) if row[9] else {},
            "commodity_quantities": json.loads(row[10]) if row[10] else {},
            "location_distribution": json.loads(row[11]) if row[11] else {},
            "canonical_hash": row[12],
            "is_frozen": bool(row[13])
        }


planning_cycle_engine = PlanningCycleEngine()
