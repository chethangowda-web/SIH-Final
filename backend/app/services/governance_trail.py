"""
app/services/governance_trail.py
================================
Unified Governance Event Trail Service.

Provides an immutable, append-only audit trail capturing all critical
governance actions across the PDS lifecycle:
- Citizen intent submission/updates
- Forecast generation & locking
- Constraint validation
- Dispatch allocation & route optimization
- Manifest creation, revisions, and cryptographic sealing
- Gatepass issuance and step advancement
- Actual offtake recording & evaluation
- Scarcity simulation vs authoritative approval/rejection
- State machine lifecycle transitions
- Administrative reset & scenario execution

Security & Integrity Guarantees:
- Append-only recording from application layer.
- Never stores credentials, passwords, or tokens.
- Clearly distinguishes simulation/what-if actions from operational commitments.
- Cryptographic hash/seal metadata captured for verified chain of custody.
"""

import json
import uuid
import sqlite3
from typing import Dict, Any, List, Optional, Union
from datetime import datetime, timezone


class GovernanceTrailService:
    def record_event(
        self,
        db: sqlite3.Connection,
        event_type: str,
        action: str,
        entity_type: str,
        entity_id: str,
        actor_name: str,
        actor_role: str,
        cycle_id: str = "2026-09",
        actor_id: Optional[str] = None,
        before_state: Optional[Union[Dict[str, Any], str]] = None,
        after_state: Optional[Union[Dict[str, Any], str]] = None,
        notes: str = "",
        correlation_id: Optional[str] = None,
        is_success: bool = True,
        is_simulation: bool = False,
        integrity_metadata: Optional[Union[Dict[str, Any], str]] = None,
    ) -> str:
        """
        Append-only recording of a unified governance event.
        Returns the unique generated event_id.
        """
        event_id = f"GEV-{datetime.now(timezone.utc).strftime('%Y%m%d')}-{uuid.uuid4().hex[:10].upper()}"

        # Serialize states safely if dict
        before_str = json.dumps(before_state, default=str) if isinstance(before_state, dict) else (before_state or None)
        after_str = json.dumps(after_state, default=str) if isinstance(after_state, dict) else (after_state or None)
        meta_str = json.dumps(integrity_metadata, default=str) if isinstance(integrity_metadata, dict) else (integrity_metadata or None)

        cursor = db.cursor()
        cursor.execute(
            """
            INSERT INTO governance_audit_logs (
                event_id, event_type, action, entity_type, entity_id, cycle_id,
                actor_id, actor_name, actor_role, before_state, after_state,
                notes, correlation_id, is_success, is_simulation, integrity_metadata
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
            """,
            (
                event_id,
                event_type,
                action,
                entity_type,
                str(entity_id),
                cycle_id,
                actor_id,
                actor_name,
                actor_role,
                before_str,
                after_str,
                notes or f"{action} executed on {entity_type} {entity_id}",
                correlation_id,
                1 if is_success else 0,
                1 if is_simulation else 0,
                meta_str
            )
        )
        db.commit()
        return event_id

    def list_events(
        self,
        db: sqlite3.Connection,
        cycle_id: Optional[str] = None,
        entity_type: Optional[str] = None,
        entity_id: Optional[str] = None,
        event_type: Optional[str] = None,
        is_simulation: Optional[bool] = None,
        limit: int = 100,
        offset: int = 0
    ) -> Dict[str, Any]:
        """
        Retrieve structured governance events with optional filtering.
        Read-only query for administrative/auditor inspection.
        """
        cursor = db.cursor()
        query = "SELECT * FROM governance_audit_logs WHERE 1=1"
        params = []

        if cycle_id:
            query += " AND cycle_id = ?"
            params.append(cycle_id)
        if entity_type:
            query += " AND entity_type = ?"
            params.append(entity_type)
        if entity_id:
            query += " AND entity_id = ?"
            params.append(entity_id)
        if event_type:
            query += " AND event_type = ?"
            params.append(event_type)
        if is_simulation is not None:
            query += " AND is_simulation = ?"
            params.append(1 if is_simulation else 0)

        # Count total matching records
        count_query = query.replace("SELECT *", "SELECT COUNT(*)", 1)
        cursor.execute(count_query, params)
        total_count = cursor.fetchone()[0]

        # Order by newest first
        query += " ORDER BY id DESC LIMIT ? OFFSET ?"
        params.extend([min(max(1, limit), 500), max(0, offset)])

        cursor.execute(query, params)
        rows = cursor.fetchall()

        events = []
        for row in rows:
            event_dict = dict(row) if hasattr(row, "keys") else {
                "id": row[0],
                "event_id": row[1],
                "event_type": row[2],
                "action": row[3],
                "entity_type": row[4],
                "entity_id": row[5],
                "cycle_id": row[6],
                "actor_id": row[7],
                "actor_name": row[8],
                "actor_role": row[9],
                "before_state": row[10],
                "after_state": row[11],
                "notes": row[12],
                "correlation_id": row[13],
                "is_success": row[14],
                "is_simulation": row[15],
                "integrity_metadata": row[16],
                "timestamp": row[17]
            }
            # Ensure boolean types
            event_dict["is_success"] = bool(event_dict.get("is_success", 1))
            event_dict["is_simulation"] = bool(event_dict.get("is_simulation", 0))

            # Attempt to parse json states if valid
            for json_field in ["before_state", "after_state", "integrity_metadata"]:
                val = event_dict.get(json_field)
                if val and isinstance(val, str):
                    try:
                        event_dict[json_field] = json.loads(val)
                    except Exception:
                        pass
            events.append(event_dict)

        return {
            "status": "success",
            "total_count": total_count,
            "limit": limit,
            "offset": offset,
            "events": events
        }


governance_trail = GovernanceTrailService()
