"""Truck Route Tracking & Field Movement Operational Engine.
Provides deterministic, persistent route progression, checkpoint tracking, and delay/deviation handling.
"""
import sqlite3
import json
import uuid
from datetime import datetime, timedelta
from typing import List, Dict, Any, Optional

DEMO_ROUTES_BLUEPRINT = [
    {
        "truck_id": "TRK-KA-0001",
        "gatepass_id": "GP-2026-09-001",
        "driver_name": "Ramesh Bhat",
        "driver_phone": "+91-9872907057",
        "source_depot_id": "GDN-KA-0001",
        "source_depot_name": "FCI Central Godown (Bagalkot Bay #3)",
        "destination_fps_id": "FPS-KA-BAG-0001",
        "destination_fps_name": "Fair Price Shop 1 (Bagalkot Sector 4)",
        "assigned_route_id": "RTE-KA-CORR-01",
        "route_name": "NH-52 District Arterial Corridor",
        "total_distance_km": 14.8,
        "base_eta_mins": 35,
        "checkpoints": [
            {"index": 0, "name": "FCI Central Godown Bay #3 (Origin)", "type": "ORIGIN", "distance_km": 0.0, "status": "COMPLETED"},
            {"index": 1, "name": "Sector 2 Static Weighbridge Checkpost", "type": "TOUCHPOINT", "distance_km": 4.5, "status": "COMPLETED"},
            {"index": 2, "name": "Bypass Junction Cross-Verification Point", "type": "TOUCHPOINT", "distance_km": 9.8, "status": "IN_PROGRESS"},
            {"index": 3, "name": "FPS-KA-BAG-0001 Depot Gate (Destination)", "type": "DESTINATION", "distance_km": 14.8, "status": "PENDING"}
        ]
    },
    {
        "truck_id": "TRK-KA-0002",
        "gatepass_id": "GP-2026-09-002",
        "driver_name": "Sanjay Patil",
        "driver_phone": "+91-9818961986",
        "source_depot_id": "GDN-KA-0001",
        "source_depot_name": "FCI Central Godown (Bagalkot Bay #1)",
        "destination_fps_id": "FPS-KA-BAG-0002",
        "destination_fps_name": "Fair Price Shop 2 (Navanagar Block A)",
        "assigned_route_id": "RTE-KA-CORR-02",
        "route_name": "Navanagar Outer Ring Highway",
        "total_distance_km": 18.2,
        "base_eta_mins": 42,
        "checkpoints": [
            {"index": 0, "name": "FCI Central Godown Bay #1 (Origin)", "type": "ORIGIN", "distance_km": 0.0, "status": "COMPLETED"},
            {"index": 1, "name": "Ring Road Toll Booth #4", "type": "TOUCHPOINT", "distance_km": 6.2, "status": "IN_PROGRESS"},
            {"index": 2, "name": "Navanagar Transit Feeder Hub", "type": "TOUCHPOINT", "distance_km": 12.5, "status": "PENDING"},
            {"index": 3, "name": "FPS-KA-BAG-0002 Shop Entrance (Destination)", "type": "DESTINATION", "distance_km": 18.2, "status": "PENDING"}
        ]
    },
    {
        "truck_id": "TRK-KA-0003",
        "gatepass_id": "GP-2026-09-003",
        "driver_name": "Kiran Rao",
        "driver_phone": "+91-9840337167",
        "source_depot_id": "GDN-KA-0001",
        "source_depot_name": "FCI Central Godown (Bagalkot Bay #2)",
        "destination_fps_id": "FPS-KA-BAG-0003",
        "destination_fps_name": "Fair Price Shop 3 (Vidyagiri East)",
        "assigned_route_id": "RTE-KA-CORR-03",
        "route_name": "Vidyagiri Express Transit Line",
        "total_distance_km": 11.5,
        "base_eta_mins": 25,
        "checkpoints": [
            {"index": 0, "name": "FCI Central Godown Bay #2 (Origin)", "type": "ORIGIN", "distance_km": 0.0, "status": "COMPLETED"},
            {"index": 1, "name": "Vidyagiri Main Feeder Inspection Post", "type": "TOUCHPOINT", "distance_km": 5.8, "status": "PENDING"},
            {"index": 2, "name": "FPS-KA-BAG-0003 Logistics Bay (Destination)", "type": "DESTINATION", "distance_km": 11.5, "status": "PENDING"}
        ]
    },
    {
        "truck_id": "TRK-KA-01-EA-9912",
        "gatepass_id": "GP-2026-09-004",
        "driver_name": "Ramesh Kumar",
        "driver_phone": "+91-9880199120",
        "source_depot_id": "GDN-KA-0001",
        "source_depot_name": "Bengaluru Central Godown",
        "destination_fps_id": "FPS-KA-BLR-001",
        "destination_fps_name": "Malleshwaram Fair Price Shop 1",
        "assigned_route_id": "RTE-KA-BLR-01",
        "route_name": "Malleshwaram Commercial Corridor",
        "total_distance_km": 15.0,
        "base_eta_mins": 35,
        "checkpoints": [
            {"index": 0, "name": "Bengaluru Central Godown Loading Bay #3 (Origin)", "type": "ORIGIN", "distance_km": 0.0, "status": "COMPLETED"},
            {"index": 1, "name": "Yeshwanthpur Toll Gate Static Scale", "type": "TOUCHPOINT", "distance_km": 5.0, "status": "COMPLETED"},
            {"index": 2, "name": "Malleshwaram 8th Main Signal Post", "type": "TOUCHPOINT", "distance_km": 10.5, "status": "IN_PROGRESS"},
            {"index": 3, "name": "FPS-KA-BLR-001 Store Entrance (Destination)", "type": "DESTINATION", "distance_km": 15.0, "status": "PENDING"}
        ]
    },
    {
        "truck_id": "KA-04-GA-9081",
        "gatepass_id": "GP-2026-09-9081",
        "driver_name": "Ramesh Kumar",
        "driver_phone": "+91-9845012345",
        "source_depot_id": "GDN-KA-0001",
        "source_depot_name": "Central FCI Godown - Whitefield Depot",
        "destination_fps_id": "FPS-KA-BLR-001",
        "destination_fps_name": "Malleshwaram Fair Price Shop 1",
        "assigned_route_id": "RTE-KA-BLR-01",
        "route_name": "Whitefield to Malleshwaram Corridor",
        "total_distance_km": 16.0,
        "base_eta_mins": 25,
        "checkpoints": [
            {"index": 0, "name": "1. Central FCI Godown Outgate", "type": "ORIGIN", "distance_km": 0.0, "status": "COMPLETED"},
            {"index": 1, "name": "2. Highway Bypass Checkpoint", "type": "TOUCHPOINT", "distance_km": 6.5, "status": "COMPLETED"},
            {"index": 2, "name": "3. City Outer Toll Gate", "type": "TOUCHPOINT", "distance_km": 12.4, "status": "IN_PROGRESS"},
            {"index": 3, "name": "4. Target Fair Price Shop Gate", "type": "DESTINATION", "distance_km": 16.0, "status": "PENDING"}
        ]
    },
    {
        "truck_id": "KA-04-GA-7712",
        "gatepass_id": "GP-2026-09-7712",
        "driver_name": "Suresh Gowda",
        "driver_phone": "+91-9845067890",
        "source_depot_id": "GDN-KA-0002",
        "source_depot_name": "FCI Grain Buffer Hub #2",
        "destination_fps_id": "FPS-KA-BLR-002",
        "destination_fps_name": "Rajajinagar Fair Price Shop 2",
        "assigned_route_id": "RTE-KA-BLR-02",
        "route_name": "Rajajinagar Express Corridor",
        "total_distance_km": 28.0,
        "base_eta_mins": 45,
        "checkpoints": [
            {"index": 0, "name": "1. FCI Grain Buffer Hub Outgate", "type": "ORIGIN", "distance_km": 0.0, "status": "COMPLETED"},
            {"index": 1, "name": "2. Highway Bypass Junction", "type": "TOUCHPOINT", "distance_km": 12.0, "status": "IN_PROGRESS"},
            {"index": 2, "name": "3. Rajajinagar Checkpoint", "type": "TOUCHPOINT", "distance_km": 24.8, "status": "PENDING"},
            {"index": 3, "name": "4. Rajajinagar FPS Gate", "type": "DESTINATION", "distance_km": 28.0, "status": "PENDING"}
        ]
    }
]

class TruckTrackingService:
    """Service managing persistent truck route tracking and movement state machine."""

    def ensure_seeded_trackings(self, db: sqlite3.Connection, cycle_id: str = "2026-09") -> None:
        """Seed default tracking records if none exist in database."""
        cursor = db.cursor()
        cursor.execute("""
        CREATE TABLE IF NOT EXISTS truck_route_tracking (
            tracking_id TEXT PRIMARY KEY,
            truck_id TEXT NOT NULL,
            gatepass_id TEXT,
            cycle_id TEXT DEFAULT '2026-09',
            driver_name TEXT,
            driver_phone TEXT,
            source_depot_id TEXT DEFAULT 'DEPOT-01',
            source_depot_name TEXT DEFAULT 'Central FCI Godown Hub (Depot 01)',
            destination_fps_id TEXT,
            destination_fps_name TEXT,
            assigned_route_id TEXT,
            route_name TEXT,
            current_status TEXT DEFAULT 'EN_ROUTE',
            checkpoints_json TEXT,
            current_checkpoint_idx INTEGER DEFAULT 0,
            current_checkpoint_name TEXT,
            next_checkpoint_name TEXT,
            distance_travelled_km REAL DEFAULT 0.0,
            distance_remaining_km REAL DEFAULT 0.0,
            total_route_distance_km REAL DEFAULT 0.0,
            eta_minutes INTEGER DEFAULT 30,
            expected_arrival_time TEXT,
            delay_status TEXT DEFAULT 'ON_TIME',
            delay_minutes INTEGER DEFAULT 0,
            delay_reason TEXT,
            route_deviation_flag INTEGER DEFAULT 0,
            deviation_reason TEXT,
            last_telemetry_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        );
        """)
        cursor.execute("CREATE INDEX IF NOT EXISTS idx_truck_tracking_truck ON truck_route_tracking(truck_id);")
        cursor.execute("CREATE INDEX IF NOT EXISTS idx_truck_tracking_cycle ON truck_route_tracking(cycle_id);")
        db.commit()

        now = datetime.now()
        for bp in DEMO_ROUTES_BLUEPRINT:
            cursor.execute("SELECT COUNT(*) FROM truck_route_tracking WHERE truck_id = ? AND cycle_id = ?;", (bp["truck_id"], cycle_id))
            if cursor.fetchone()[0] > 0:
                continue
            tracking_id = f"TRK-LOC-{cycle_id}-{bp['truck_id'].replace('-', '')[:10]}"
            cps = [dict(c) for c in bp["checkpoints"]]
            
            # Default to checkpoint 1 or 2 as current
            current_idx = 1
            if len(cps) > 2:
                cps[0]["status"] = "COMPLETED"
                cps[1]["status"] = "IN_PROGRESS"
                for i in range(2, len(cps)):
                    cps[i]["status"] = "PENDING"
            
            curr_cp = cps[current_idx]["name"]
            next_cp = cps[min(current_idx + 1, len(cps) - 1)]["name"]
            dist_travelled = cps[current_idx]["distance_km"]
            dist_remaining = max(0.0, bp["total_distance_km"] - dist_travelled)
            eta_m = max(5, int(bp["base_eta_mins"] * (dist_remaining / bp["total_distance_km"])))
            exp_arr = (now + timedelta(minutes=eta_m)).strftime("%H:%M Today")

            cursor.execute("""
            INSERT OR REPLACE INTO truck_route_tracking (
                tracking_id, truck_id, gatepass_id, cycle_id,
                driver_name, driver_phone, source_depot_id, source_depot_name,
                destination_fps_id, destination_fps_name, assigned_route_id, route_name,
                current_status, checkpoints_json, current_checkpoint_idx,
                current_checkpoint_name, next_checkpoint_name, distance_travelled_km,
                distance_remaining_km, total_route_distance_km, eta_minutes,
                expected_arrival_time, delay_status, delay_minutes, delay_reason,
                route_deviation_flag, deviation_reason, last_telemetry_time, updated_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'EN_ROUTE', ?, ?, ?, ?, ?, ?, ?, ?, ?, 'ON_TIME', 0, NULL, 0, NULL, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP);
            """, (
                tracking_id, bp["truck_id"], bp["gatepass_id"], cycle_id,
                bp["driver_name"], bp["driver_phone"], bp["source_depot_id"], bp["source_depot_name"],
                bp["destination_fps_id"], bp["destination_fps_name"], bp["assigned_route_id"], bp["route_name"],
                json.dumps(cps), current_idx, curr_cp, next_cp, dist_travelled,
                dist_remaining, bp["total_distance_km"], eta_m, exp_arr
            ))
        db.commit()

    def get_all_active_trackings(self, db: sqlite3.Connection, cycle_id: str = "2026-09") -> List[Dict[str, Any]]:
        """Fetch all active truck tracking records."""
        self.ensure_seeded_trackings(db, cycle_id)
        cursor = db.cursor()
        cursor.execute("""
        SELECT * FROM truck_route_tracking
        WHERE cycle_id = ?
        ORDER BY rowid ASC;
        """, (cycle_id,))
        rows = cursor.fetchall()
        return [self._format_row(dict(r)) for r in rows]

    def get_truck_tracking(self, db: sqlite3.Connection, truck_id: str, cycle_id: str = "2026-09") -> Dict[str, Any]:
        """Fetch tracking detail for a specific truck."""
        self.ensure_seeded_trackings(db, cycle_id)
        cursor = db.cursor()
        cursor.execute("""
        SELECT * FROM truck_route_tracking
        WHERE truck_id = ? OR truck_id LIKE ?;
        """, (truck_id.strip(), f"%{truck_id.strip()}%"))
        row = cursor.fetchone()
        if not row:
            # Check if truck exists in vehicles table or initialize dynamically
            cursor.execute("SELECT * FROM vehicles WHERE truck_id = ?;", (truck_id.strip(),))
            v_row = cursor.fetchone()
            
            driver = v_row["driver_name"] if v_row and v_row["driver_name"] else "Ramesh Kumar"
            phone = v_row["driver_phone"] if v_row and v_row["driver_phone"] else "+91-9845012345"
            fps_id = "FPS-KA-BLR-001"
            fps_name = "Malleshwaram Fair Price Shop 1"
            if "7712" in truck_id:
                driver = "Suresh Gowda"
                phone = "+91-9845067890"
                fps_id = "FPS-KA-BLR-002"
                fps_name = "Rajajinagar Fair Price Shop 2"

            bp = {
                "truck_id": truck_id.strip(),
                "gatepass_id": f"GP-{cycle_id}-{truck_id.strip()[-4:]}",
                "driver_name": driver,
                "driver_phone": phone,
                "source_depot_id": "GDN-KA-0001",
                "source_depot_name": "Central FCI Godown - Whitefield Depot",
                "destination_fps_id": fps_id,
                "destination_fps_name": fps_name,
                "assigned_route_id": "RTE-KA-DIST-01",
                "route_name": "Arterial City Corridor",
                "total_distance_km": 16.0,
                "base_eta_mins": 35,
                "checkpoints": [
                    {"index": 0, "name": "1. Central FCI Godown Outgate (Origin)", "type": "ORIGIN", "distance_km": 0.0, "status": "COMPLETED"},
                    {"index": 1, "name": "2. Highway Bypass Checkpoint", "type": "TOUCHPOINT", "distance_km": 6.5, "status": "COMPLETED"},
                    {"index": 2, "name": "3. City Outer Toll Gate", "type": "TOUCHPOINT", "distance_km": 12.4, "status": "IN_PROGRESS"},
                    {"index": 3, "name": "4. Target Fair Price Shop Gate (Destination)", "type": "DESTINATION", "distance_km": 16.0, "status": "PENDING"}
                ]
            }
            tracking_id = f"TRK-LOC-{cycle_id}-{truck_id.strip().replace('-', '')[:10]}"
            cps = bp["checkpoints"]
            now = datetime.now()
            exp_arr = (now + timedelta(minutes=25)).strftime("%H:%M Today")
            cursor.execute("""
            INSERT OR REPLACE INTO truck_route_tracking (
                tracking_id, truck_id, gatepass_id, cycle_id,
                driver_name, driver_phone, source_depot_id, source_depot_name,
                destination_fps_id, destination_fps_name, assigned_route_id, route_name,
                current_status, checkpoints_json, current_checkpoint_idx,
                current_checkpoint_name, next_checkpoint_name, distance_travelled_km,
                distance_remaining_km, total_route_distance_km, eta_minutes,
                expected_arrival_time, delay_status, delay_minutes, delay_reason,
                route_deviation_flag, deviation_reason, last_telemetry_time, updated_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'EN_ROUTE', ?, 2, ?, ?, 12.4, 3.6, 16.0, 25, ?, 'ON_TIME', 0, NULL, 0, NULL, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP);
            """, (
                tracking_id, bp["truck_id"], bp["gatepass_id"], cycle_id,
                bp["driver_name"], bp["driver_phone"], bp["source_depot_id"], bp["source_depot_name"],
                bp["destination_fps_id"], bp["destination_fps_name"], bp["assigned_route_id"], bp["route_name"],
                json.dumps(cps), cps[2]["name"], cps[3]["name"], exp_arr
            ))
            db.commit()
            cursor.execute("SELECT * FROM truck_route_tracking WHERE truck_id = ? OR truck_id LIKE ?;", (truck_id.strip(), f"%{truck_id.strip()}%"))
            row = cursor.fetchone()

        if not row:
            raise ValueError(f"Truck tracking record for '{truck_id}' not found.")
        return self._format_row(dict(row))

    def advance_checkpoint(self, db: sqlite3.Connection, truck_id: str) -> Dict[str, Any]:
        """Advance truck to the next sequential route checkpoint and update telemetry metrics."""
        detail = self.get_truck_tracking(db, truck_id)
        cps = detail["checkpoints"]
        curr_idx = detail["current_checkpoint_idx"]
        total_dist = detail["total_route_distance_km"]

        now_str = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

        if curr_idx < len(cps) - 1:
            # Mark previous as completed
            cps[curr_idx]["status"] = "COMPLETED"
            cps[curr_idx]["completed_at"] = now_str
            
            # Next index
            new_idx = curr_idx + 1
            cps[new_idx]["status"] = "IN_PROGRESS" if new_idx < len(cps) - 1 else "COMPLETED"
            if new_idx == len(cps) - 1:
                cps[new_idx]["completed_at"] = now_str
                new_status = "ARRIVED"
            else:
                new_status = "CHECKPOINT_TOUCHED"
            
            curr_cp = cps[new_idx]["name"]
            next_cp = cps[min(new_idx + 1, len(cps) - 1)]["name"]
            dist_travelled = float(cps[new_idx]["distance_km"])
            dist_remaining = max(0.0, total_dist - dist_travelled)
            eta_m = max(0, int(35 * (dist_remaining / max(1.0, total_dist))))
            exp_arr = (datetime.now() + timedelta(minutes=eta_m)).strftime("%H:%M Today") if eta_m > 0 else "Arrived"

            cursor = db.cursor()
            cursor.execute("""
            UPDATE truck_route_tracking SET
                current_status = ?,
                checkpoints_json = ?,
                current_checkpoint_idx = ?,
                current_checkpoint_name = ?,
                next_checkpoint_name = ?,
                distance_travelled_km = ?,
                distance_remaining_km = ?,
                eta_minutes = ?,
                expected_arrival_time = ?,
                last_telemetry_time = CURRENT_TIMESTAMP,
                updated_at = CURRENT_TIMESTAMP
            WHERE truck_id = ?;
            """, (
                new_status, json.dumps(cps), new_idx, curr_cp, next_cp,
                dist_travelled, dist_remaining, eta_m, exp_arr, detail["truck_id"]
            ))
            db.commit()
            return self.get_truck_tracking(db, detail["truck_id"])
        else:
            # Already at destination -> mark DELIVERED / COMPLETED
            cursor = db.cursor()
            cursor.execute("""
            UPDATE truck_route_tracking SET
                current_status = 'DELIVERED',
                distance_remaining_km = 0.0,
                eta_minutes = 0,
                expected_arrival_time = 'Delivered & Sealed',
                last_telemetry_time = CURRENT_TIMESTAMP,
                updated_at = CURRENT_TIMESTAMP
            WHERE truck_id = ?;
            """, (detail["truck_id"],))
            db.commit()
            return self.get_truck_tracking(db, detail["truck_id"])

    def report_delay(self, db: sqlite3.Connection, truck_id: str, delay_minutes: int, reason: str) -> Dict[str, Any]:
        """Log operational delay and update dynamic arrival ETA."""
        detail = self.get_truck_tracking(db, truck_id)
        new_eta_m = detail["eta_minutes"] + max(1, delay_minutes)
        exp_arr = (datetime.now() + timedelta(minutes=new_eta_m)).strftime("%H:%M Today")

        cursor = db.cursor()
        cursor.execute("""
        UPDATE truck_route_tracking SET
            delay_status = 'DELAYED',
            delay_minutes = ?,
            delay_reason = ?,
            eta_minutes = ?,
            expected_arrival_time = ?,
            last_telemetry_time = CURRENT_TIMESTAMP,
            updated_at = CURRENT_TIMESTAMP
        WHERE truck_id = ?;
        """, (delay_minutes, reason.strip(), new_eta_m, exp_arr, detail["truck_id"]))
        db.commit()
        return self.get_truck_tracking(db, detail["truck_id"])

    def report_route_deviation(self, db: sqlite3.Connection, truck_id: str, reason: str) -> Dict[str, Any]:
        """Flag route deviation event with active security warning."""
        detail = self.get_truck_tracking(db, truck_id)
        cursor = db.cursor()
        cursor.execute("""
        UPDATE truck_route_tracking SET
            delay_status = 'ROUTE_DEVIATION',
            route_deviation_flag = 1,
            deviation_reason = ?,
            last_telemetry_time = CURRENT_TIMESTAMP,
            updated_at = CURRENT_TIMESTAMP
        WHERE truck_id = ?;
        """, (reason.strip(), detail["truck_id"]))
        db.commit()
        return self.get_truck_tracking(db, detail["truck_id"])

    def confirm_arrival(self, db: sqlite3.Connection, truck_id: str) -> Dict[str, Any]:
        """Confirm physical arrival of vehicle at destination FPS."""
        detail = self.get_truck_tracking(db, truck_id)
        cps = detail["checkpoints"]
        for c in cps:
            c["status"] = "COMPLETED"
        last_idx = len(cps) - 1

        cursor = db.cursor()
        cursor.execute("""
        UPDATE truck_route_tracking SET
            current_status = 'ARRIVED',
            checkpoints_json = ?,
            current_checkpoint_idx = ?,
            current_checkpoint_name = ?,
            next_checkpoint_name = 'Unloading Bay Docked',
            distance_travelled_km = total_route_distance_km,
            distance_remaining_km = 0.0,
            eta_minutes = 0,
            expected_arrival_time = 'Arrived at Shop',
            last_telemetry_time = CURRENT_TIMESTAMP,
            updated_at = CURRENT_TIMESTAMP
        WHERE truck_id = ?;
        """, (json.dumps(cps), last_idx, cps[last_idx]["name"], detail["truck_id"]))
        db.commit()
        return self.get_truck_tracking(db, detail["truck_id"])

    def confirm_delivery(self, db: sqlite3.Connection, truck_id: str) -> Dict[str, Any]:
        """Confirm goods unloaded, verified against weighbridge, and marked DELIVERED."""
        detail = self.get_truck_tracking(db, truck_id)
        cursor = db.cursor()
        cursor.execute("""
        UPDATE truck_route_tracking SET
            current_status = 'DELIVERED',
            expected_arrival_time = 'Distribution Complete',
            last_telemetry_time = CURRENT_TIMESTAMP,
            updated_at = CURRENT_TIMESTAMP
        WHERE truck_id = ?;
        """, (detail["truck_id"],))
        db.commit()
        return self.get_truck_tracking(db, detail["truck_id"])

    def approve_truck_movement(
        self,
        db: sqlite3.Connection,
        truck_id: str,
        current_fps_id: str,
        officer_username: str,
        next_fps_id: Optional[str] = None,
        notes: Optional[str] = None,
        manifest_id: Optional[str] = None,
        digital_signature: Optional[str] = None
    ) -> Dict[str, Any]:
        """Record officer movement authorization for onward truck dispatch between FPS stores."""
        cursor = db.cursor()
        cursor.execute("""
        CREATE TABLE IF NOT EXISTS officer_movement_approvals (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            approval_token TEXT UNIQUE NOT NULL,
            truck_id TEXT NOT NULL,
            manifest_id TEXT,
            from_fps_id TEXT NOT NULL,
            to_fps_id TEXT,
            officer_id TEXT NOT NULL,
            officer_name TEXT NOT NULL,
            approval_notes TEXT,
            digital_signature TEXT,
            status TEXT NOT NULL DEFAULT 'APPROVED',
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        );
        """)
        token = f"CLR-MVT-2026-{uuid.uuid4().hex[:6].upper()}"
        now_str = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

        cursor.execute("""
        INSERT INTO officer_movement_approvals (
            approval_token, truck_id, manifest_id, from_fps_id, to_fps_id,
            officer_id, officer_name, approval_notes, digital_signature, status, created_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 'APPROVED', ?);
        """, (
            token, truck_id, manifest_id, current_fps_id, next_fps_id,
            officer_username, f"Food Inspector ({officer_username})",
            notes or "Officer physical delivery verified. Truck cleared for onward movement.",
            digital_signature or "OFF-VERIFIED-SEAL",
            now_str
        ))

        # Update truck tracking: advance to IN_TRANSIT towards next stop or mark MOVEMENT_APPROVED
        cursor.execute("""
        UPDATE truck_route_tracking SET
            current_status = 'IN_TRANSIT',
            current_checkpoint_name = ?,
            next_checkpoint_name = ?,
            last_telemetry_time = CURRENT_TIMESTAMP,
            updated_at = CURRENT_TIMESTAMP
        WHERE truck_id = ?;
        """, (
            f"Departed {current_fps_id} (Cleared)",
            f"En Route to {next_fps_id or 'Next FPS'}",
            truck_id
        ))
        db.commit()

        return {
            "status": "APPROVED",
            "clearance_token": token,
            "truck_id": truck_id,
            "manifest_id": manifest_id,
            "current_fps_id": current_fps_id,
            "next_fps_id": next_fps_id,
            "cleared_by_officer": officer_username,
            "cleared_at": now_str,
            "approval_notes": notes or "Officer physical delivery verified. Truck cleared for onward movement."
        }


    def _format_row(self, row: Dict[str, Any]) -> Dict[str, Any]:
        """Format SQLite row into API schema structure."""
        try:
            cps = json.loads(row["checkpoints_json"]) if isinstance(row["checkpoints_json"], str) else row["checkpoints_json"]
        except Exception:
            cps = []

        total_d = float(row["total_route_distance_km"] or 14.0)
        trav_d = float(row["distance_travelled_km"] or 0.0)
        prog_pct = min(100.0, max(0.0, round((trav_d / max(0.1, total_d)) * 100.0, 1)))

        return {
            "tracking_id": row["tracking_id"],
            "truck_id": row["truck_id"],
            "gatepass_id": row["gatepass_id"],
            "cycle_id": row["cycle_id"],
            "driver_name": row["driver_name"],
            "driver_phone": row["driver_phone"],
            "source_depot_id": row["source_depot_id"],
            "source_depot_name": row["source_depot_name"],
            "origin_godown": row["source_depot_name"],
            "destination_fps_id": row["destination_fps_id"],
            "destination_fps_name": row["destination_fps_name"],
            "destination_fps": row["destination_fps_name"],
            "assigned_route_id": row["assigned_route_id"],
            "route_name": row["route_name"],
            "assigned_route": row["route_name"],
            "current_status": row["current_status"],
            "current_checkpoint_idx": int(row["current_checkpoint_idx"]),
            "current_checkpoint_name": row["current_checkpoint_name"],
            "current_checkpoint": row["current_checkpoint_name"],
            "next_checkpoint_name": row["next_checkpoint_name"],
            "next_checkpoint": row["next_checkpoint_name"],
            "distance_travelled_km": trav_d,
            "distance_remaining_km": float(row["distance_remaining_km"] or 0.0),
            "total_route_distance_km": total_d,
            "total_distance_km": total_d,
            "progress_percentage": prog_pct,
            "eta_minutes": int(row["eta_minutes"] or 0),
            "expected_arrival_time": row["expected_arrival_time"],
            "eta": row["expected_arrival_time"],
            "last_location": row["current_checkpoint_name"],
            "delay_status": row["delay_status"],
            "delay_minutes": int(row["delay_minutes"] or 0),
            "delay_reason": row["delay_reason"],
            "route_deviation_flag": bool(row["route_deviation_flag"]),
            "route_deviation_status": "DEVIATED" if bool(row["route_deviation_flag"]) else "NORMAL",
            "deviation_reason": row["deviation_reason"],
            "last_telemetry_time": str(row["last_telemetry_time"]),
            "last_updated": str(row["last_telemetry_time"]),
            "is_simulated": True,
            "checkpoints": cps
        }

truck_tracking_service = TruckTrackingService()
