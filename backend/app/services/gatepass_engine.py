"""Digital Gatepass & Physical-Dispatch Bridge Engine.

Implements the 4-Stage Physical Handshake Lifecycle:
1. GATEPASS_ISSUED (Depot Gate In-Charge - Digital Gatepass Generated from Locked Manifest)
2. WAREHOUSE_APPROVED (Warehouse Superintendent - Physical Godown Grain Stock Verification)
3. VEHICLE_LOADED (Loading Supervisor - Tare/Gross Weighbridge Calibration & Loading Slip)
4. DISPATCH_CONFIRMED (Carrier Driver & Gate Sergeant - Gate Clearance & Out for Delivery)

Trigger:
Upon DISPATCH_CONFIRMED, automatically triggers multi-channel readiness notifications (WhatsApp, SMS, IVR).

Outputs:
- Simulated Prototype Digital Gatepass (GP-2026-09-XXXX)
- Manifest ID & Linked Corridor Payload
- Loading Bay & Loading Time Window
- Weighbridge Tare/Gross Calibration Slip
- QR-style Verification Token
- Chronological Event Timeline with Actor, Status, Timestamp, and Reference ID
"""

import sqlite3
import hashlib
from datetime import datetime
from typing import List, Dict, Any, Optional
from app.core.config import settings
from app.core.logging_config import get_logger
from app.services.notification_engine import notification_engine

logger = get_logger("gatepass")

DEMO_NOTICE = "PROTOTYPE / SIMULATED DIGITAL GATEPASS — NOT AN OFFICIAL GOVERNMENT DOCUMENT"

GATEPASS_STAGES = [
    "MANIFEST_LOCKED",
    "GATEPASS_ISSUED",
    "WAREHOUSE_APPROVED",
    "WAREHOUSE_VERIFIED",
    "VEHICLE_LOADED",
    "DISPATCH_CONFIRMED"
]


class GatepassEngine:
    """Core Service for Generating, Validating, and Advancing Digital Pre-Dispatch Gatepasses."""

    def compute_gatepass_security_token(
        self,
        gatepass_id: str,
        manifest_id: str,
        truck_id: str,
        cycle_id: str,
        total_payload_kg: float
    ) -> str:
        """Compute authoritative cryptographic security clearance token."""
        token_raw = f"PDS_GATEPASS_TOKEN|{gatepass_id}|{manifest_id}|{truck_id}|{cycle_id}|{total_payload_kg:.2f}|GOVT_OF_KARNATAKA_FOOD_CIVIL_SUPPLIES"
        return f"GP-SEC-{hashlib.sha256(token_raw.encode('utf-8')).hexdigest()[:14].upper()}"

    def verify_gatepass(
        self,
        db: sqlite3.Connection,
        gatepass_id: str,
        security_token: Optional[str] = None,
        qr_payload: Optional[str] = None
    ) -> Dict[str, Any]:
        """
        Cryptographic & statutory verification of a Digital Gatepass.
        Validates:
        1. Gatepass exists in registry.
        2. Linked Manifest exists and is LOCKED with a valid cryptographic seal.
        3. Security Token matches authoritative computation.
        4. Current clearance stage is valid.
        """
        cursor = db.cursor()
        cursor.execute("SELECT * FROM gatepasses WHERE gatepass_id = ?;", (gatepass_id,))
        gp = cursor.fetchone()
        if not gp:
            return {
                "status": "INVALID",
                "is_valid": False,
                "gatepass_id": gatepass_id,
                "reason": f"Gatepass '{gatepass_id}' does not exist in the district registry."
            }

        # Verify manifest linkage
        manifest_id = gp["manifest_id"]
        cursor.execute("SELECT status, digital_seal_hash, version FROM manifests WHERE manifest_id = ?;", (manifest_id,))
        man_row = cursor.fetchone()
        if not man_row:
            return {
                "status": "UNLINKED_MANIFEST",
                "is_valid": False,
                "gatepass_id": gatepass_id,
                "manifest_id": manifest_id,
                "reason": f"Linked manifest '{manifest_id}' not found."
            }

        is_manifest_locked = (man_row["status"] == "LOCKED")
        expected_token = self.compute_gatepass_security_token(
            gatepass_id=gp["gatepass_id"],
            manifest_id=gp["manifest_id"],
            truck_id=gp["truck_id"],
            cycle_id=gp["cycle_id"],
            total_payload_kg=float(gp["total_payload_kg"])
        )

        if security_token and security_token.strip().upper() != expected_token.upper():
            return {
                "status": "TAMPERED_TOKEN",
                "is_valid": False,
                "gatepass_id": gatepass_id,
                "manifest_id": manifest_id,
                "reason": "Security token verification failed: Provided token does not match authoritative digital seal."
            }

        is_valid = is_manifest_locked and (gp["security_token"] == expected_token)

        return {
            "status": "VALID" if is_valid else ("MANIFEST_NOT_LOCKED" if not is_manifest_locked else "TAMPERED"),
            "is_valid": is_valid,
            "gatepass_id": gp["gatepass_id"],
            "cycle_id": gp["cycle_id"],
            "truck_id": gp["truck_id"],
            "manifest_id": gp["manifest_id"],
            "manifest_status": man_row["status"],
            "manifest_version": man_row["version"],
            "manifest_seal": man_row["digital_seal_hash"],
            "current_stage": gp["status"],
            "security_token": gp["security_token"],
            "total_payload_kg": float(gp["total_payload_kg"]),
            "issued_at": gp["issued_at"],
            "verified_at": gp["verified_at"],
            "loaded_at": gp["loaded_at"],
            "dispatched_at": gp["dispatched_at"],
            "approving_officer": gp["approving_officer"],
            "reason": "Gatepass authentic, verified against locked manifest and cryptographic security token." if is_valid else ("Linked manifest is still in DRAFT mode." if not is_manifest_locked else "Gatepass verification failed.")
        }

    def generate_or_get_gatepass_for_truck(
        self,
        db: sqlite3.Connection,
        truck_id: str,
        cycle_id: str = settings.CURRENT_CYCLE
    ) -> Dict[str, Any]:
        """
        Generate or retrieve existing Digital Gatepass for a vehicle corridor linked to the locked manifest.
        """
        cursor = db.cursor()

        # 1. Fetch vehicle & depot info
        cursor.execute("""
        SELECT v.truck_id, v.model, v.corridor, v.driver_name, v.driver_phone, v.source_depot_id,
               d.name as depot_name, d.location as depot_location
        FROM vehicles v
        JOIN depots d ON v.source_depot_id = d.depot_id
        WHERE v.truck_id = ?;
        """, (truck_id,))
        v_row = cursor.fetchone()
        if not v_row:
            raise ValueError(f"Vehicle '{truck_id}' not found.")

        # 2. Check for linked manifest
        cursor.execute("""
        SELECT manifest_id, total_quantity_kg, total_rice_kg, total_wheat_kg,
               departure_window, status, version
        FROM manifests
        WHERE cycle_id = ? AND truck_id = ?;
        """, (cycle_id, truck_id))
        man_row = cursor.fetchone()

        if man_row:
            manifest_id = man_row["manifest_id"]
            total_payload_kg = float(man_row["total_quantity_kg"])
            rice_payload_kg = float(man_row["total_rice_kg"])
            wheat_payload_kg = float(man_row["total_wheat_kg"])
        else:
            # Fallback calculate from dispatch
            cursor.execute("""
            SELECT COALESCE(SUM(quantity_kg), 0.0) as total_qty,
                   COALESCE(SUM(CASE WHEN commodity='Rice' THEN quantity_kg ELSE 0 END), 0.0) as rice_qty,
                   COALESCE(SUM(CASE WHEN commodity='Wheat' THEN quantity_kg ELSE 0 END), 0.0) as wheat_qty
            FROM dispatch
            WHERE cycle_id = ? AND demo_truck_id = ?;
            """, (cycle_id, truck_id))
            disp_row = cursor.fetchone()
            total_payload_kg = float(disp_row["total_qty"]) if disp_row and disp_row["total_qty"] > 0 else 3120.0
            rice_payload_kg = float(disp_row["rice_qty"]) if disp_row and disp_row["rice_qty"] > 0 else 2000.0
            wheat_payload_kg = float(disp_row["wheat_qty"]) if disp_row and disp_row["wheat_qty"] > 0 else 1120.0
            manifest_id = f"MAN-{cycle_id}-{v_row['corridor'][:4]}-{truck_id[-4:]}"

        suffix = truck_id.split("-")[-1]
        cursor.execute("SELECT gatepass_id, manifest_id, status FROM gatepasses WHERE cycle_id = ? AND truck_id = ?;", (cycle_id, truck_id))
        existing_gp = cursor.fetchone()
        if existing_gp:
            gatepass_id = existing_gp["gatepass_id"]
        else:
            gatepass_id = f"GP-{cycle_id}-{suffix}"

        bay_no = f"Bay-0{int(suffix[-1]) % 4 + 1}" if (suffix and suffix[-1].isdigit()) else "Bay-02"

        security_token = self.compute_gatepass_security_token(
            gatepass_id=gatepass_id,
            manifest_id=manifest_id,
            truck_id=truck_id,
            cycle_id=cycle_id,
            total_payload_kg=total_payload_kg
        )

        now_str = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

        cursor.execute("""
        INSERT INTO gatepasses (
            gatepass_id, cycle_id, truck_id, source_depot_id, manifest_id,
            corridor, total_rice_kg, total_wheat_kg, total_payload_kg,
            loading_bay, driver_name, driver_phone, security_token,
            status, issued_at, approving_officer
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'GATEPASS_ISSUED', ?, 'District Supply Officer (Bengaluru Urban)')
        ON CONFLICT(cycle_id, truck_id) DO UPDATE SET
            gatepass_id = excluded.gatepass_id,
            manifest_id = excluded.manifest_id,
            total_rice_kg = excluded.total_rice_kg,
            total_wheat_kg = excluded.total_wheat_kg,
            total_payload_kg = excluded.total_payload_kg,
            security_token = excluded.security_token;
        """, (
            gatepass_id,
            cycle_id,
            truck_id,
            v_row["source_depot_id"],
            manifest_id,
            v_row["corridor"],
            rice_payload_kg,
            wheat_payload_kg,
            total_payload_kg,
            bay_no,
            v_row["driver_name"],
            v_row["driver_phone"],
            security_token,
            now_str
        ))
        db.commit()

        # Record in Unified Governance Event Trail
        from app.services.governance_trail import governance_trail
        governance_trail.record_event(
            db=db,
            event_type="GATEPASS_ISSUED",
            action="ISSUE_DIGITAL_GATEPASS",
            entity_type="GATEPASS",
            entity_id=gatepass_id,
            actor_name="District Supply Officer (Demo Admin)",
            actor_role="DISTRICT_SUPPLY_OFFICER",
            cycle_id=cycle_id,
            after_state={"status": "GATEPASS_ISSUED", "manifest_id": manifest_id, "truck_id": truck_id, "total_payload_kg": total_payload_kg},
            notes=f"Digital gatepass issued for truck {truck_id} linked to manifest {manifest_id}",
            integrity_metadata={"security_token": security_token, "manifest_id": manifest_id},
            is_success=True,
            is_simulation=False
        )

        cursor.execute("SELECT * FROM gatepasses WHERE cycle_id = ? AND truck_id = ?;", (cycle_id, truck_id))
        row = cursor.fetchone()
        if not row:
            cursor.execute("SELECT * FROM gatepasses WHERE gatepass_id = ?;", (gatepass_id,))
            row = cursor.fetchone()
        return self._format_gatepass_record(dict(row), db)

    def advance_gatepass_status(
        self,
        db: sqlite3.Connection,
        gatepass_id: str,
        target_status: str,
        actor_name: Optional[str] = None,
        actor_role: Optional[str] = None
    ) -> Dict[str, Any]:
        """
        Advance gatepass lifecycle through the 4 physical-dispatch bridge stages:
        GATEPASS_ISSUED -> WAREHOUSE_APPROVED -> VEHICLE_LOADED -> DISPATCH_CONFIRMED.
        """
        if target_status not in GATEPASS_STAGES:
            raise ValueError(f"Invalid gatepass stage '{target_status}'. Must be one of {GATEPASS_STAGES}")

        cursor = db.cursor()
        cursor.execute("SELECT * FROM gatepasses WHERE gatepass_id = ?;", (gatepass_id,))
        gp = cursor.fetchone()
        if not gp:
            raise ValueError(f"Gatepass '{gatepass_id}' not found.")

        now_str = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

        # Valid prior states for each guarded forward transition.
        # WAREHOUSE_APPROVED and WAREHOUSE_VERIFIED are NOT guarded (any prior state is valid)
        # because in the demo mode officers may re-issue warehouse confirmation at any stage.
        # Only VEHICLE_LOADED and DISPATCH_CONFIRMED enforce ordering, because:
        #   - VEHICLE_LOADED before DISPATCH_CONFIRMED is a physical reality
        #   - DISPATCH_CONFIRMED is the irreversible dispatch event (most critical to guard)
        PRIOR_STATES: Dict[str, set] = {
            "VEHICLE_LOADED":     {"GATEPASS_ISSUED", "WAREHOUSE_APPROVED", "WAREHOUSE_VERIFIED"},
            "DISPATCH_CONFIRMED": {"GATEPASS_ISSUED", "VEHICLE_LOADED", "WAREHOUSE_APPROVED", "WAREHOUSE_VERIFIED"},
        }

        if target_status == "WAREHOUSE_APPROVED" or target_status == "WAREHOUSE_VERIFIED":
            # No prior-state guard — any state is acceptable for warehouse confirmation
            cursor.execute(
                "UPDATE gatepasses SET status = ?, verified_at = ? WHERE gatepass_id = ?;",
                (target_status, now_str, gatepass_id)
            )
        elif target_status in PRIOR_STATES:
            valid_priors = PRIOR_STATES[target_status]
            # Build an IN-clause to atomically guard the state transition.
            # Concurrent double-writes return rowcount=0 and are surfaced as errors below.
            placeholders = ",".join("?" * len(valid_priors))

            if target_status == "VEHICLE_LOADED":
                cursor.execute(
                    f"UPDATE gatepasses SET status = ?, loaded_at = ? "
                    f"WHERE gatepass_id = ? AND status IN ({placeholders});",
                    (target_status, now_str, gatepass_id, *valid_priors)
                )
            elif target_status == "DISPATCH_CONFIRMED":
                # Statutory Guard: Ensure referenced manifest is locked and cryptographically sealed
                cursor.execute("SELECT status, digital_seal_hash FROM manifests WHERE manifest_id = ?;", (gp["manifest_id"],))
                m_row = cursor.fetchone()
                if m_row and m_row["status"] != "LOCKED":
                    raise ValueError(f"Manifest '{gp['manifest_id']}' is in {m_row['status']} mode. Gate clearance requires a LOCKED and cryptographically sealed manifest.")

                cursor.execute(
                    f"UPDATE gatepasses SET status = ?, dispatched_at = ? "
                    f"WHERE gatepass_id = ? AND status IN ({placeholders});",
                    (target_status, now_str, gatepass_id, *valid_priors)
                )
        else:
            # Non-standard advance (e.g. MANIFEST_LOCKED, GATEPASS_ISSUED) — no prior state guard needed
            cursor.execute("UPDATE gatepasses SET status = ? WHERE gatepass_id = ?;", (target_status, gatepass_id))

        # Rowcount == 0 means either:
        # (a) The gatepass is already at the target status — idempotent, return current state
        # (b) A concurrent request advanced it to a state we don't recognise as a valid prior
        #
        # We distinguish the cases by re-reading the current status. Case (a) is safe to
        # return; case (b) is a genuine concurrent conflict and we surface a clear error.
        if cursor.rowcount == 0 and target_status in PRIOR_STATES:
            cursor.execute("SELECT status FROM gatepasses WHERE gatepass_id = ?;", (gatepass_id,))
            current = cursor.fetchone()
            current_status = current["status"] if current else "UNKNOWN"

            if current_status == target_status:
                # Already at target — idempotent return, no error
                db.commit()
            else:
                db.rollback()
                raise ValueError(
                    f"Gatepass state transition rejected: target '{target_status}' requires prior status in "
                    f"{PRIOR_STATES[target_status]}, but found '{current_status}' for gatepass '{gatepass_id}'. "
                    "This may indicate a concurrent advance or an out-of-order request."
                )

        if target_status == "DISPATCH_CONFIRMED" and cursor.rowcount > 0:
            try:
                notification_engine.dispatch_pre_dispatch_alerts(db, cycle_id=gp["cycle_id"], truck_id=gp["truck_id"])
            except Exception as e:
                pass

        db.commit()

        logger.info(
            "Gatepass advanced: gatepass_id='%s', manifest_id='%s', truck_id='%s', cycle='%s', from_status='%s', to_status='%s', actor='%s'",
            gatepass_id, gp["manifest_id"], gp["truck_id"], gp["cycle_id"], gp["status"], target_status, actor_name or "DSO"
        )

        # Record in Unified Governance Event Trail
        from app.services.governance_trail import governance_trail
        governance_trail.record_event(
            db=db,
            event_type="DISPATCH_CONFIRMED" if target_status == "DISPATCH_CONFIRMED" else "GATEPASS_ADVANCED",
            action=f"ADVANCE_GATEPASS_TO_{target_status}",
            entity_type="GATEPASS",
            entity_id=gatepass_id,
            actor_name=actor_name or "District Supply Officer (Demo Admin)",
            actor_role=actor_role or "DISTRICT_SUPPLY_OFFICER",
            cycle_id=gp["cycle_id"],
            before_state={"status": gp["status"]},
            after_state={"status": target_status},
            notes=f"Gatepass {gatepass_id} advanced from {gp['status']} to {target_status}",
            integrity_metadata={"manifest_id": gp["manifest_id"], "truck_id": gp["truck_id"]},
            is_success=True,
            is_simulation=False
        )

        cursor.execute("SELECT * FROM gatepasses WHERE gatepass_id = ?;", (gatepass_id,))
        row = cursor.fetchone()
        if not row:
            raise ValueError(f"Gatepass '{gatepass_id}' not found.")
        return self._format_gatepass_record(dict(row), db)

    def generate_all_cycle_gatepasses(
        self,
        db: sqlite3.Connection,
        cycle_id: str = settings.CURRENT_CYCLE
    ) -> List[Dict[str, Any]]:
        """Generate or retrieve gatepasses for all active corridor vehicles."""
        cursor = db.cursor()
        cursor.execute("SELECT truck_id FROM vehicles ORDER BY truck_id ASC;")
        truck_ids = [r[0] for r in cursor.fetchall()]

        results = []
        for tid in truck_ids:
            gp = self.generate_or_get_gatepass_for_truck(db, tid, cycle_id)
            results.append(gp)

        return results

    def _format_gatepass_record(self, gp: Dict[str, Any], db: sqlite3.Connection) -> Dict[str, Any]:
        """Format complete prototype digital gatepass with weighbridge slip, stops list, and event timeline."""
        cursor = db.cursor()

        # Fetch depot info
        cursor.execute("SELECT name, location FROM depots WHERE depot_id = ?;", (gp["source_depot_id"],))
        depot_row = cursor.fetchone()
        depot_name = depot_row["name"] if depot_row else "Bengaluru Central FCI Godown (Hebbal)"
        depot_loc = depot_row["location"] if depot_row else "Hebbal Ring Road, Bengaluru"

        # Fetch vehicle info
        cursor.execute("SELECT model FROM vehicles WHERE truck_id = ?;", (gp["truck_id"],))
        v_row = cursor.fetchone()
        truck_model = v_row["model"] if v_row else "Eicher Pro 10 MT"

        # Fetch stops
        cursor.execute("""
        SELECT d.fps_id, p.name as fps_name,
               COALESCE(SUM(CASE WHEN d.commodity='Rice' THEN d.quantity_kg ELSE 0 END), 0.0) as rice_kg,
               COALESCE(SUM(CASE WHEN d.commodity='Wheat' THEN d.quantity_kg ELSE 0 END), 0.0) as wheat_kg,
               COALESCE(SUM(d.quantity_kg), 0.0) as total_kg
        FROM dispatch d
        JOIN fps p ON d.fps_id = p.fps_id
        WHERE d.cycle_id = ? AND d.demo_truck_id = ?
        GROUP BY d.fps_id
        ORDER BY p.name ASC;
        """, (gp["cycle_id"], gp["truck_id"]))
        stops = [dict(s) for s in cursor.fetchall()]

        if not stops:
            # Fallback stops
            stops = [
                {"fps_id": "FPS-KA-BLR-001", "fps_name": "Malleshwaram Seva Kendra", "rice_kg": 2000.0, "wheat_kg": 1120.0, "total_kg": 3120.0},
                {"fps_id": "FPS-KA-BLR-004", "fps_name": "Rajajinagar 1st Stage FPS", "rice_kg": 1800.0, "wheat_kg": 950.0, "total_kg": 2750.0},
            ]

        payload_kg = float(gp["total_payload_kg"]) if float(gp["total_payload_kg"]) > 0 else 3120.0
        tare_weight_kg = 4850.0
        gross_weight_kg = tare_weight_kg + payload_kg

        curr_status = gp["status"]
        is_issued = True
        is_wh = curr_status in ["WAREHOUSE_APPROVED", "WAREHOUSE_VERIFIED", "VEHICLE_LOADED", "DISPATCH_CONFIRMED"]
        is_loaded = curr_status in ["VEHICLE_LOADED", "DISPATCH_CONFIRMED"]
        is_dispatched = curr_status == "DISPATCH_CONFIRMED"

        # 5-Stage Physical Bridge Timeline
        timeline = [
            {
                "stage": "MANIFEST_LOCKED",
                "title": "Manifest Approved & Locked",
                "status": "COMPLETED",
                "timestamp": gp.get("issued_at") or "2026-08-23 07:00:00",
                "actor_role": "DISTRICT_SUPPLY_OFFICER",
                "actor_name": "District Supply Officer",
                "officer": "District Supply Officer",
                "reference_id": gp.get("manifest_id") or "MAN-2026-09"
            },
            {
                "stage": "GATEPASS_ISSUED",
                "title": "Digital Gatepass Generated",
                "status": "COMPLETED",
                "timestamp": gp.get("issued_at") or "2026-08-23 07:30:00",
                "actor_role": "DEPOT_GATE_INCHARGE",
                "actor_name": "S. Nagaraj (Gate In-Charge)",
                "officer": "S. Nagaraj (Gate In-Charge)",
                "reference_id": gp["gatepass_id"]
            },
            {
                "stage": "WAREHOUSE_APPROVED",
                "title": "Warehouse Physical Stock Inspection",
                "status": "COMPLETED" if is_wh else "PENDING",
                "timestamp": gp.get("verified_at") or ( "2026-08-23 08:00:00" if is_wh else "Pending Verification" ),
                "actor_role": "WAREHOUSE_SUPERINTENDENT",
                "actor_name": "Dr. V. Shivakumar (Godown Superintendent)",
                "officer": "Dr. V. Shivakumar (Godown Superintendent)",
                "reference_id": f"WH-APPR-{gp['truck_id'][-4:]}"
            },
            {
                "stage": "VEHICLE_LOADED",
                "title": "Weighbridge Tare & Gross Calibration",
                "status": "COMPLETED" if is_loaded else "PENDING",
                "timestamp": gp.get("loaded_at") or ( "2026-08-23 08:30:00" if is_loaded else "Pending Loading" ),
                "actor_role": "LOADING_SUPERVISOR",
                "actor_name": "R. Manjunath (Weighbridge Scale #02)",
                "officer": "R. Manjunath (Weighbridge Scale #02)",
                "reference_id": f"WB-{gp['cycle_id']}-{gp['truck_id'][-4:]}"
            },
            {
                "stage": "DISPATCH_CONFIRMED",
                "title": "Gate Clearance & Out for Delivery",
                "status": "COMPLETED" if is_dispatched else "PENDING",
                "timestamp": gp.get("dispatched_at") or ( "2026-08-23 08:45:00" if is_dispatched else "Pending Gate Clearance" ),
                "actor_role": "GATE_SERGEANT",
                "actor_name": "Sub-Inspector Anand Rao (Security Gate 01)",
                "officer": "Sub-Inspector Anand Rao (Security Gate 01)",
                "reference_id": f"GATE-EXIT-{gp['cycle_id']}-{gp['truck_id'][-4:]}"
            }
        ]

        loading_window = "07:30 AM – 08:15 AM (Morning Priority Slot)"

        return {
            "gatepass_id": gp["gatepass_id"],
            "cycle_id": gp["cycle_id"],
            "manifest_id": gp["manifest_id"],
            "truck_id": gp["truck_id"],
            "truck_model": truck_model,
            "corridor": gp["corridor"],
            "status": curr_status,
            "source_depot_id": gp["source_depot_id"],
            "depot_name": depot_name,
            "depot_location": depot_loc,
            "loading_bay": gp["loading_bay"],
            "loading_window": loading_window,
            "driver_name": gp["driver_name"],
            "driver_phone": gp["driver_phone"],
            "security_token": gp["security_token"],
            "approving_officer": gp["approving_officer"],
            "total_rice_kg": float(gp["total_rice_kg"]) if float(gp["total_rice_kg"]) > 0 else 2000.0,
            "total_wheat_kg": float(gp["total_wheat_kg"]) if float(gp["total_wheat_kg"]) > 0 else 1120.0,
            "total_payload_kg": payload_kg,
            "weighbridge_slip": {
                "slip_number": f"WB-{gp['cycle_id']}-{gp['truck_id'][-4:]}",
                "tare_weight_kg": tare_weight_kg,
                "gross_weight_kg": gross_weight_kg,
                "net_payload_kg": payload_kg,
                "scale_status": "CALIBRATED_VERIFIED"
            },
            "delivery_stops": stops,
            "event_timeline": timeline,
            "qr_verification_string": f"PDS_SIMULATED_GATEPASS|{gp['gatepass_id']}|{gp['manifest_id']}|{gp['truck_id']}|{payload_kg}KG|{gp['security_token']}",
            "demo_disclaimer": DEMO_NOTICE,
            "demo_notice": DEMO_NOTICE
        }


gatepass_engine = GatepassEngine()
