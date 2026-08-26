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
from app.services.notification_engine import notification_engine

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

        # 1. Check if gatepass already exists
        cursor.execute("SELECT * FROM gatepasses WHERE cycle_id = ? AND truck_id = ?;", (cycle_id, truck_id))
        existing = cursor.fetchone()
        if existing:
            return self._format_gatepass_record(dict(existing), db)

        # 2. Fetch vehicle & depot info
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

        # 3. Check for linked manifest
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
        gatepass_id = f"GP-{cycle_id}-{suffix}"
        bay_no = f"Bay-0{int(suffix[-1]) % 4 + 1}" if suffix[-1].isdigit() else "Bay-02"

        token_raw = f"{gatepass_id}:{manifest_id}:{truck_id}:{cycle_id}:{total_payload_kg}:DEMO_SALT"
        security_token = f"GP-SEC-{hashlib.sha256(token_raw.encode()).hexdigest()[:14].upper()}"

        now_str = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

        cursor.execute("""
        INSERT INTO gatepasses (
            gatepass_id, cycle_id, truck_id, source_depot_id, manifest_id,
            corridor, total_rice_kg, total_wheat_kg, total_payload_kg,
            loading_bay, driver_name, driver_phone, security_token,
            status, issued_at, approving_officer
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'GATEPASS_ISSUED', ?, 'District Supply Officer (Demo)')
        ON CONFLICT(cycle_id, truck_id) DO UPDATE SET
            manifest_id = excluded.manifest_id,
            total_rice_kg = excluded.total_rice_kg,
            total_wheat_kg = excluded.total_wheat_kg,
            total_payload_kg = excluded.total_payload_kg;
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

        cursor.execute("SELECT * FROM gatepasses WHERE gatepass_id = ?;", (gatepass_id,))
        return self._format_gatepass_record(dict(cursor.fetchone()), db)

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

        if target_status == "WAREHOUSE_APPROVED":
            cursor.execute("UPDATE gatepasses SET status = ?, verified_at = ? WHERE gatepass_id = ?;", (target_status, now_str, gatepass_id))
        elif target_status == "VEHICLE_LOADED":
            cursor.execute("UPDATE gatepasses SET status = ?, loaded_at = ? WHERE gatepass_id = ?;", (target_status, now_str, gatepass_id))
        elif target_status == "DISPATCH_CONFIRMED":
            cursor.execute("UPDATE gatepasses SET status = ?, dispatched_at = ? WHERE gatepass_id = ?;", (target_status, now_str, gatepass_id))
            # Automatic Trigger: Dispatch readiness notifications to Dealers & Beneficiary Groups
            try:
                notification_engine.dispatch_pre_dispatch_alerts(db, cycle_id=gp["cycle_id"], truck_id=gp["truck_id"])
            except Exception as e:
                print(f"[GatepassEngine] Auto-alert trigger notice: {e}")
        else:
            cursor.execute("UPDATE gatepasses SET status = ? WHERE gatepass_id = ?;", (target_status, gatepass_id))

        db.commit()

        cursor.execute("SELECT * FROM gatepasses WHERE gatepass_id = ?;", (gatepass_id,))
        return self._format_gatepass_record(dict(cursor.fetchone()), db)

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
            # Fallback demo stops
            stops = [
                {"fps_id": "FPS-KA-BLR-001", "fps_name": "Malleshwaram Seva Kendra (Demo)", "rice_kg": 2000.0, "wheat_kg": 1120.0, "total_kg": 3120.0},
                {"fps_id": "FPS-KA-BLR-004", "fps_name": "Rajajinagar 1st Stage FPS (Demo)", "rice_kg": 1800.0, "wheat_kg": 950.0, "total_kg": 2750.0},
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
