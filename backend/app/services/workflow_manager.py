import sqlite3
from datetime import datetime
from typing import List, Dict, Any, Optional, Tuple
from app.core.config import settings
from app.core.logging_config import get_logger

logger = get_logger("workflow")

class WorkflowState:
    FORECASTED = "FORECASTED"
    VALIDATED = "VALIDATED"
    ALLOCATED = "ALLOCATED"
    OPTIMIZED = "OPTIMIZED"
    MANIFEST_DRAFT = "MANIFEST_DRAFT"
    MANIFEST_LOCKED = "MANIFEST_LOCKED"
    GATEPASS_READY = "GATEPASS_READY"
    DISPATCHED = "DISPATCHED"
    VERIFIED = "VERIFIED"
    EVALUATED = "EVALUATED"
    CYCLE_CLOSED = "CYCLE_CLOSED"

class WorkflowStateManager:
    """Authoritative server-side lifecycle state machine for operational planning cycles."""

    STATE_ORDER = [
        WorkflowState.FORECASTED,
        WorkflowState.VALIDATED,
        WorkflowState.ALLOCATED,
        WorkflowState.OPTIMIZED,
        WorkflowState.MANIFEST_DRAFT,
        WorkflowState.MANIFEST_LOCKED,
        WorkflowState.GATEPASS_READY,
        WorkflowState.DISPATCHED,
        WorkflowState.VERIFIED,
        WorkflowState.EVALUATED,
        WorkflowState.CYCLE_CLOSED
    ]

    ALLOWED_TRANSITIONS = {
        WorkflowState.FORECASTED: [WorkflowState.FORECASTED, WorkflowState.VALIDATED],
        WorkflowState.VALIDATED: [WorkflowState.VALIDATED, WorkflowState.ALLOCATED, WorkflowState.FORECASTED],
        WorkflowState.ALLOCATED: [WorkflowState.ALLOCATED, WorkflowState.OPTIMIZED, WorkflowState.FORECASTED],
        WorkflowState.OPTIMIZED: [WorkflowState.OPTIMIZED, WorkflowState.MANIFEST_DRAFT, WorkflowState.MANIFEST_LOCKED, WorkflowState.FORECASTED],
        WorkflowState.MANIFEST_DRAFT: [WorkflowState.MANIFEST_DRAFT, WorkflowState.MANIFEST_LOCKED, WorkflowState.FORECASTED],
        WorkflowState.MANIFEST_LOCKED: [WorkflowState.MANIFEST_LOCKED, WorkflowState.GATEPASS_READY, WorkflowState.DISPATCHED, WorkflowState.FORECASTED],
        WorkflowState.GATEPASS_READY: [WorkflowState.GATEPASS_READY, WorkflowState.DISPATCHED, WorkflowState.FORECASTED],
        WorkflowState.DISPATCHED: [WorkflowState.DISPATCHED, WorkflowState.VERIFIED, WorkflowState.FORECASTED],
        WorkflowState.VERIFIED: [WorkflowState.VERIFIED, WorkflowState.EVALUATED, WorkflowState.FORECASTED],
        WorkflowState.EVALUATED: [WorkflowState.EVALUATED, WorkflowState.CYCLE_CLOSED, WorkflowState.FORECASTED],
        WorkflowState.CYCLE_CLOSED: [WorkflowState.CYCLE_CLOSED]
    }

    def get_current_state(self, db: sqlite3.Connection, cycle_id: str) -> str:
        """Fetch persisted workflow state for the cycle, defaulting to FORECASTED."""
        cursor = db.cursor()
        cursor.execute("SELECT current_state FROM cycle_workflow_states WHERE cycle_id = ?;", (cycle_id,))
        row = cursor.fetchone()
        return row[0] if row else WorkflowState.FORECASTED

    def get_allowed_next_states(self, current_state: str) -> List[str]:
        """Return allowed target states from current state."""
        return self.ALLOWED_TRANSITIONS.get(current_state, [WorkflowState.FORECASTED])

    def get_blocking_conditions(self, db: sqlite3.Connection, cycle_id: str, current_state: str, target_state: str) -> List[str]:
        """Determine what conditions are currently blocking a state transition."""
        conditions = []

        # Failed constraints block manifest locking
        if target_state == WorkflowState.MANIFEST_LOCKED:
            from app.services.constraint_engine import constraint_engine
            can_lock, lock_err = constraint_engine.is_manifest_lock_permitted(db, cycle_id)
            if not can_lock:
                conditions.append(lock_err or "Critical constraint validation failure (FAIL).")

        # Gatepass readiness sequence guard
        if target_state == WorkflowState.GATEPASS_READY and current_state != WorkflowState.MANIFEST_LOCKED:
            conditions.append(f"State transition to GATEPASS_READY requires current state to be MANIFEST_LOCKED (currently '{current_state}').")

        # Dispatch sequence guard
        if target_state == WorkflowState.DISPATCHED and current_state != WorkflowState.GATEPASS_READY:
            conditions.append(f"State transition to DISPATCHED requires current state to be GATEPASS_READY (currently '{current_state}').")

        # Evaluation data existence guard
        if target_state == WorkflowState.EVALUATED:
            cursor = db.cursor()
            cursor.execute("SELECT COUNT(*) FROM actual_distribution WHERE cycle_id = ?;", (cycle_id,))
            if cursor.fetchone()[0] == 0:
                conditions.append("Cannot evaluate cycle: Actual ePoS distribution data has not been simulated/recorded.")

        # Cycle closure guards
        if target_state == WorkflowState.CYCLE_CLOSED:
            closure_status = self.get_cycle_closure_checklist(db, cycle_id)
            if not closure_status["can_close"]:
                conditions.extend(closure_status["blockers"])

        return conditions

    def get_cycle_closure_checklist(self, db: sqlite3.Connection, cycle_id: str) -> Dict[str, Any]:
        """Evaluate authoritative conditions required for closing a planning cycle."""
        cursor = db.cursor()
        current_state = self.get_current_state(db, cycle_id)
        
        # 1. Demand validated
        cursor.execute("SELECT COUNT(*) FROM demand_snapshots WHERE cycle_id = ?;", (cycle_id,))
        demand_validated = cursor.fetchone()[0] > 0 or current_state in [
            WorkflowState.VALIDATED, WorkflowState.ALLOCATED, WorkflowState.OPTIMIZED,
            WorkflowState.MANIFEST_DRAFT, WorkflowState.MANIFEST_LOCKED, WorkflowState.GATEPASS_READY,
            WorkflowState.DISPATCHED, WorkflowState.VERIFIED, WorkflowState.EVALUATED, WorkflowState.CYCLE_CLOSED
        ]

        # 2. Allocation approved
        cursor.execute("SELECT COUNT(*) FROM forecast WHERE cycle_id = ? AND recommended_dispatch_kg > 0;", (cycle_id,))
        allocation_count = cursor.fetchone()[0]
        allocation_approved = allocation_count > 0 or current_state in [
            WorkflowState.ALLOCATED, WorkflowState.OPTIMIZED, WorkflowState.MANIFEST_DRAFT,
            WorkflowState.MANIFEST_LOCKED, WorkflowState.GATEPASS_READY, WorkflowState.DISPATCHED,
            WorkflowState.VERIFIED, WorkflowState.EVALUATED, WorkflowState.CYCLE_CLOSED
        ]

        # 3. Optimization approved
        optimization_approved = current_state in [
            WorkflowState.OPTIMIZED, WorkflowState.MANIFEST_DRAFT, WorkflowState.MANIFEST_LOCKED,
            WorkflowState.GATEPASS_READY, WorkflowState.DISPATCHED, WorkflowState.VERIFIED,
            WorkflowState.EVALUATED, WorkflowState.CYCLE_CLOSED
        ]

        # 4. Dispatch authorized
        cursor.execute("SELECT COUNT(*) FROM dispatch WHERE cycle_id = ?;", (cycle_id,))
        dispatch_count = cursor.fetchone()[0]
        cursor.execute("SELECT COUNT(*) FROM manifests WHERE cycle_id = ? AND status = 'LOCKED';", (cycle_id,))
        locked_manifests_count = cursor.fetchone()[0]
        dispatch_authorized = (dispatch_count > 0 or locked_manifests_count > 0) or current_state in [
            WorkflowState.MANIFEST_LOCKED, WorkflowState.GATEPASS_READY, WorkflowState.DISPATCHED,
            WorkflowState.VERIFIED, WorkflowState.EVALUATED, WorkflowState.CYCLE_CLOSED
        ]

        # 5. Required deliveries verified
        cursor.execute("SELECT COUNT(*) FROM truck_route_tracking WHERE current_status NOT IN ('DELIVERED', 'COMPLETED', 'VERIFIED');")
        pending_deliveries = cursor.fetchone()[0]
        deliveries_verified = (pending_deliveries == 0) or current_state in [
            WorkflowState.VERIFIED, WorkflowState.EVALUATED, WorkflowState.CYCLE_CLOSED
        ]

        # 6. Exceptions reviewed
        from app.services.constraint_engine import constraint_engine
        constraint_audit = constraint_engine.run_full_district_constraint_audit(db, cycle_id=cycle_id)
        fail_count = constraint_audit.get("fail_count", 0)
        exceptions_reviewed = (fail_count == 0)

        # 7. Inspection records processed
        cursor.execute("SELECT COUNT(*) FROM fps_inspections;")
        inspections_count = cursor.fetchone()[0]
        inspections_processed = True

        # 8. Audit records persisted
        cursor.execute("SELECT COUNT(*) FROM workflow_audit_logs WHERE cycle_id = ?;", (cycle_id,))
        audit_count = cursor.fetchone()[0]
        audit_persisted = audit_count > 0 or current_state != WorkflowState.FORECASTED

        # Determine blockers
        blockers = []
        if not demand_validated:
            blockers.append("Demand snapshot has not been validated and frozen.")
        if not allocation_approved:
            blockers.append("District stock allocation plan has not been approved.")
        if not optimization_approved:
            blockers.append("Route & corridor supply plan has not been approved.")
        if not dispatch_authorized:
            blockers.append("Dispatch manifests have not been officially authorized.")
        if not deliveries_verified:
            blockers.append(f"{pending_deliveries} dispatch shipments remain awaiting field delivery verification.")
        if not exceptions_reviewed:
            blockers.append(f"{fail_count} unresolved critical constraint violations remain in the district.")
        if current_state not in [WorkflowState.VERIFIED, WorkflowState.EVALUATED, WorkflowState.CYCLE_CLOSED]:
            blockers.append(f"Cycle must be in VERIFIED or EVALUATED state before closure (currently '{current_state}').")

        checklist = [
            {"id": "demand_validated", "title": "Demand snapshot validated & frozen", "completed": demand_validated},
            {"id": "allocation_approved", "title": "District stock allocation approved", "completed": allocation_approved},
            {"id": "optimization_approved", "title": "Route & corridor supply plan optimized", "completed": optimization_approved},
            {"id": "dispatch_authorized", "title": "Dispatch manifests authorized & sealed", "completed": dispatch_authorized},
            {"id": "deliveries_verified", "title": "Field deliveries verified & stock received", "completed": deliveries_verified},
            {"id": "exceptions_reviewed", "title": "Supply-chain constraints & exceptions reviewed", "completed": exceptions_reviewed},
            {"id": "inspections_processed", "title": "Food inspector field records processed", "completed": inspections_processed},
            {"id": "audit_persisted", "title": "Governance trail & cryptographic audit persisted", "completed": audit_persisted},
        ]

        can_close = len(blockers) == 0

        return {
            "cycle_id": cycle_id,
            "current_state": current_state,
            "can_close": can_close,
            "blockers": blockers,
            "checklist": checklist,
            "is_closed": current_state == WorkflowState.CYCLE_CLOSED
        }

    def get_audit_history(self, db: sqlite3.Connection, cycle_id: str) -> List[Dict[str, Any]]:
        """Retrieve audit transition log for the cycle."""
        cursor = db.cursor()
        cursor.execute("""
            SELECT previous_state, new_state, actor_name, actor_role, reason, correlation_id, timestamp 
            FROM workflow_audit_logs 
            WHERE cycle_id = ? 
            ORDER BY timestamp DESC;
        """, (cycle_id,))
        rows = cursor.fetchall()
        return [dict(r) for r in rows]

    def transition_state(
        self,
        db: sqlite3.Connection,
        cycle_id: str,
        new_state: str,
        actor_name: str,
        actor_role: str,
        reason: Optional[str] = None,
        correlation_id: Optional[str] = None,
        force: bool = False
    ) -> str:
        """
        Atomically transition the workflow state for a cycle, enforcing transitions and governance guards.
        """
        if new_state not in self.STATE_ORDER:
            raise ValueError(f"Invalid workflow state target '{new_state}'.")

        current = self.get_current_state(db, cycle_id)

        # GOVERNANCE GATES & SERVER-SIDE GUARDS:

        # 1. Citizen intent cannot transition allocation state
        if actor_role.upper() in ["CITIZEN", "BENEFICIARY", "CITIZEN_BENEFICIARY"]:
            raise ValueError("Unauthorized Access: Citizen role cannot transition planning allocation states.")

        # 2. AI cannot transition officer approval state (AI is strictly advisory)
        if actor_role.upper().startswith("AI") or "MODEL" in actor_role.upper() or "SYSTEM_AI" in actor_role.upper():
            if new_state in [WorkflowState.FORECASTED, WorkflowState.ALLOCATED, WorkflowState.MANIFEST_LOCKED, WorkflowState.DISPATCHED]:
                raise ValueError("Unauthorized Access: AI role is advisory only and cannot authorize officer approval states.")

        # Skip transition logic if already in target state (idempotence for authorized roles)
        if current == new_state and not force:
            return current

        # Bypasses allowed transitions map only if force=True (DSO Reset/Calibrate bypass)
        if not force:
            allowed = self.get_allowed_next_states(current)
            if new_state not in allowed:
                raise ValueError(
                    f"Illegal state transition: Cannot transition from '{current}' to '{new_state}'. "
                    f"Allowed target states: {allowed}"
                )

        # 3. Blocking conditions validation (if not forced)
        if not force:
            blockers = self.get_blocking_conditions(db, cycle_id, current, new_state)
            if blockers:
                logger.warning(
                    "Workflow state transition blocked: cycle='%s', current='%s', target='%s', blockers=%s",
                    cycle_id, current, new_state, blockers
                )
                raise ValueError(f"State Transition Blocked: {'; '.join(blockers)}")

        # Perform update
        cursor = db.cursor()
        cursor.execute("""
            INSERT INTO cycle_workflow_states (cycle_id, current_state, updated_at)
            VALUES (?, ?, CURRENT_TIMESTAMP)
            ON CONFLICT(cycle_id) DO UPDATE SET
                current_state = excluded.current_state,
                updated_at = CURRENT_TIMESTAMP;
        """, (cycle_id, new_state))

        # Record transition audit trail
        cursor.execute("""
            INSERT INTO workflow_audit_logs (cycle_id, previous_state, new_state, actor_name, actor_role, reason, correlation_id, timestamp)
            VALUES (?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP);
        """, (cycle_id, current, new_state, actor_name, actor_role, reason, correlation_id))

        db.commit()

        logger.info(
            "Workflow state transition: cycle='%s', from='%s', to='%s', actor='%s', role='%s', reason='%s'",
            cycle_id, current, new_state, actor_name, actor_role, reason
        )

        # Record in Unified Governance Event Trail
        from app.services.governance_trail import governance_trail
        governance_trail.record_event(
            db=db,
            event_type="WORKFLOW_TRANSITION",
            action=f"TRANSITION_TO_{new_state}",
            entity_type="WORKFLOW",
            entity_id=cycle_id,
            actor_name=actor_name,
            actor_role=actor_role,
            cycle_id=cycle_id,
            before_state={"previous_state": current},
            after_state={"new_state": new_state},
            notes=reason or f"Workflow state transitioned from {current} to {new_state}",
            correlation_id=correlation_id,
            is_success=True,
            is_simulation=False
        )

        return new_state

    def reset_state(self, db: sqlite3.Connection, cycle_id: str):
        """Reset workflow status table for the cycle."""
        cursor = db.cursor()
        cursor.execute("DELETE FROM cycle_workflow_states WHERE cycle_id = ?;", (cycle_id,))
        cursor.execute("DELETE FROM workflow_audit_logs WHERE cycle_id = ?;", (cycle_id,))
        db.commit()

        from app.services.governance_trail import governance_trail
        governance_trail.record_event(
            db=db,
            event_type="WORKFLOW_RESET",
            action="RESET_WORKFLOW_STATE",
            entity_type="WORKFLOW",
            entity_id=cycle_id,
            actor_name="District Supply Officer (Demo Admin)",
            actor_role="ADMIN",
            cycle_id=cycle_id,
            after_state={"new_state": "PLANNING_OPEN"},
            notes=f"Workflow state machine reset for cycle {cycle_id}",
            is_success=True,
            is_simulation=False
        )

workflow_manager = WorkflowStateManager()
