"""Deterministic Multi-Echelon Dispatch Simulation Engine for PDS DemandSync.

Implements the SIH 2026 Phase 5 Pre-Dispatch Supply Chain Simulation:
- Reads locked forecast allocations from SQLite forecast table.
- Allocates simulated godown inventory to vehicle fleets across regional delivery corridors.
- Maps 20 Fair Price Shops to 4 specialized demo transport vehicles and 2 central godowns.
- Guarantees deterministic, reproducible, and explainable dispatch manifests.
- Persists all planned dispatch manifests in the SQLite database.
"""
import sqlite3
from typing import List, Dict, Any, Optional, Tuple
from app.core.config import settings

DEMO_NOTICE = "DEMO DATA — NOT GOVERNMENT DATA (SIMULATED GODOWN DISPATCH)"

GODOWN_HEBBAL = "Bengaluru Central FCI Godown (Hebbal)"
GODOWN_BANASWADI = "Banaswadi PDS Buffer Storage Depot"

# 4 Regional Vehicle Corridors for 20 Fair Price Shops
CORRIDOR_VEHICLES = {
    "NORTH_WEST": {
        "truck_id": "DEMO-KA-04-E-1021",
        "model": "Eicher Pro 10 MT (North-West Heavy Corridor)",
        "source_godown": GODOWN_HEBBAL,
        "fps_cluster": [
            "FPS-KA-BLR-001",  # Malleshwaram
            "FPS-KA-BLR-004",  # Rajajinagar
            "FPS-KA-BLR-013",  # Peenya Industrial Hub
            "FPS-KA-BLR-017",  # Kengeri Satellite Town
            "FPS-KA-BLR-018",  # Yelahanka Old Town
        ]
    },
    "EAST_IT_CORRIDOR": {
        "truck_id": "DEMO-KA-04-E-1022",
        "model": "Tata Ultra 10 MT (East Corridor / IT Belt)",
        "source_godown": GODOWN_HEBBAL,
        "fps_cluster": [
            "FPS-KA-BLR-005",  # Bellandur ORR
            "FPS-KA-BLR-006",  # Sarjapur Road
            "FPS-KA-BLR-007",  # Mahadevapura Sub-Center
            "FPS-KA-BLR-008",  # Thanisandra Main Road
            "FPS-KA-BLR-014",  # Whitefield IT Corridor
        ]
    },
    "SOUTH_INDUSTRIAL": {
        "truck_id": "DEMO-KA-51-M-3419",
        "model": "BharatBenz 10 MT (South Industrial Corridor)",
        "source_godown": GODOWN_BANASWADI,
        "fps_cluster": [
            "FPS-KA-BLR-002",  # Jayanagar 4th Block
            "FPS-KA-BLR-003",  # Basavanagudi Grain Center
            "FPS-KA-BLR-015",  # Electronic City Phase-2
            "FPS-KA-BLR-016",  # Bommasandra Industrial Hub
            "FPS-KA-BLR-019",  # Hebbal Distribution Point
        ]
    },
    "CENTRAL_HERITAGE": {
        "truck_id": "DEMO-KA-01-F-7801",
        "model": "Ashok Leyland 8 MT (Central Urban / Heritage Cluster)",
        "source_godown": GODOWN_BANASWADI,
        "fps_cluster": [
            "FPS-KA-BLR-009",  # Chickpet Heritage Depot
            "FPS-KA-BLR-010",  # Shivajinagar Central
            "FPS-KA-BLR-011",  # Cottonpet Old Ward
            "FPS-KA-BLR-012",  # Ulsoor Bazaar Counter
            "FPS-KA-BLR-020",  # Banaswadi Central Stock
        ]
    }
}

def get_truck_and_godown_for_fps(fps_id: str) -> Tuple[str, str, str]:
    """Map FPS to its assigned delivery truck, godown, and route corridor."""
    for corridor_name, cfg in CORRIDOR_VEHICLES.items():
        if fps_id in cfg["fps_cluster"]:
            return cfg["truck_id"], cfg["source_godown"], cfg["model"]
    # Default fallback
    return "DEMO-KA-04-E-1021", GODOWN_HEBBAL, "Eicher Pro 10 MT (North-West Heavy Corridor)"


class DispatchEngine:
    """Core Service for Generating, Persisting, and Managing Dispatch Manifests."""

    def generate_and_persist_dispatch(
        self,
        db: sqlite3.Connection,
        cycle_id: str = settings.CURRENT_CYCLE,
        force: bool = False
    ) -> Dict[str, Any]:
        """
        Generate godown dispatch manifest from locked forecast records.
        Saves records into SQLite dispatch table with status DISPATCH_PLANNED.
        """
        cursor = db.cursor()

        # 1. Verify forecast is locked
        cursor.execute("SELECT status, COUNT(*) FROM forecast WHERE cycle_id = ? GROUP BY status;", (cycle_id,))
        status_rows = cursor.fetchall()
        if not status_rows:
            raise ValueError(
                f"No forecast records found for cycle '{cycle_id}'. You must generate and lock forecasts first."
            )

        status_counts = {r[0]: r[1] for r in status_rows}
        if "FORECAST_LOCKED" not in status_counts:
            current_status = "DRAFT_GENERATED" if ("DRAFT" in status_counts or "DRAFT_GENERATED" in status_counts) else "PLANNING_OPEN"
            raise ValueError(
                f"Demand forecast must be LOCKED before generating dispatch manifest. Current status is '{current_status}'."
            )

        # 2. Fetch locked forecast records with recommended dispatch quantities
        cursor.execute("""
        SELECT 
            f.id as forecast_id, f.fps_id, f.commodity, f.predicted_quantity_kg,
            f.recommended_dispatch_kg, f.risk_level, p.name as fps_name
        FROM forecast f
        JOIN fps p ON f.fps_id = p.fps_id
        WHERE f.cycle_id = ? AND f.status = 'FORECAST_LOCKED'
        ORDER BY f.fps_id ASC, f.commodity ASC;
        """, (cycle_id,))
        forecast_rows = cursor.fetchall()

        if not forecast_rows:
            raise ValueError(f"No locked forecast records available for cycle '{cycle_id}'.")

        # Check constraint compliance before dispatch manifest generation
        from app.services.constraint_engine import constraint_engine
        can_lock, lock_err = constraint_engine.is_manifest_lock_permitted(db, cycle_id)
        if not can_lock:
            raise ValueError(f"Dispatch Generation Blocked: {lock_err}")

        # 3. Generate and Persist dispatch rows
        dispatch_records_inserted = 0
        total_dispatch_kg = 0.0
        total_rice_kg = 0.0
        total_wheat_kg = 0.0

        for row in forecast_rows:
            fid = row["fps_id"]
            comm = row["commodity"]
            rec_dispatch = float(row["recommended_dispatch_kg"])
            forecast_id = int(row["forecast_id"])

            # Always record the operational dispatch allocation (positive requirement)
            dispatch_qty = rec_dispatch

            truck_id, source_godown, _ = get_truck_and_godown_for_fps(fid)

            # Insert or Update into dispatch table
            cursor.execute("""
            INSERT INTO dispatch (
                forecast_id, fps_id, cycle_id, commodity, quantity_kg,
                demo_truck_id, source_godown, status, created_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, 'DISPATCH_PLANNED', CURRENT_TIMESTAMP)
            ON CONFLICT(fps_id, cycle_id, commodity) DO UPDATE SET
                forecast_id = excluded.forecast_id,
                quantity_kg = excluded.quantity_kg,
                demo_truck_id = excluded.demo_truck_id,
                source_godown = excluded.source_godown,
                status = 'DISPATCH_PLANNED',
                created_at = CURRENT_TIMESTAMP;
            """, (
                forecast_id,
                fid,
                cycle_id,
                comm,
                dispatch_qty,
                truck_id,
                source_godown
            ))

            dispatch_records_inserted += 1
            total_dispatch_kg += dispatch_qty
            if comm == "Rice":
                total_rice_kg += dispatch_qty
            else:
                total_wheat_kg += dispatch_qty

        db.commit()

        # 4. Assemble Manifest Data
        manifest = self.get_dispatch_manifest(db, cycle_id)
        manifest["message"] = (
            f"Simulated dispatch manifest generated for Cycle {cycle_id}: "
            f"{total_dispatch_kg:.1f} kg allocated across {manifest['total_vehicles_count']} vehicles and {manifest['total_fps_count']} Fair Price Shops."
        )
        return manifest

    def get_dispatch_manifest(
        self,
        db: sqlite3.Connection,
        cycle_id: str = settings.CURRENT_CYCLE
    ) -> Dict[str, Any]:
        """
        Retrieve structured dispatch manifest with truck fleet groupings and flat line items.
        """
        cursor = db.cursor()

        cursor.execute("""
        SELECT 
            d.id, d.forecast_id, d.fps_id, p.name as fps_name, d.cycle_id,
            d.commodity, d.quantity_kg, d.demo_truck_id, d.source_godown,
            d.status, d.created_at
        FROM dispatch d
        JOIN fps p ON d.fps_id = p.fps_id
        WHERE d.cycle_id = ?
        ORDER BY d.demo_truck_id ASC, d.fps_id ASC, d.commodity ASC;
        """, (cycle_id,))
        rows = cursor.fetchall()

        records = [dict(r) for r in rows]

        # Group by truck ID for vehicle fleet manifest
        truck_groups: Dict[str, Dict[str, Any]] = {}
        total_dispatch_kg = 0.0
        total_rice_kg = 0.0
        total_wheat_kg = 0.0
        fps_set = set()

        for r in records:
            tid = r["demo_truck_id"]
            qty = float(r["quantity_kg"])
            comm = r["commodity"]
            fid = r["fps_id"]
            fname = r["fps_name"]

            total_dispatch_kg += qty
            if comm == "Rice":
                total_rice_kg += qty
            else:
                total_wheat_kg += qty

            fps_set.add(fid)

            if tid not in truck_groups:
                # Find corridor details
                route_name = "Regional Corridor Delivery"
                godown_name = r["source_godown"]
                for corridor_name, cfg in CORRIDOR_VEHICLES.items():
                    if cfg["truck_id"] == tid:
                        route_name = cfg["model"]
                        godown_name = cfg["source_godown"]
                        break

                truck_groups[tid] = {
                    "truck_id": tid,
                    "source_godown": godown_name,
                    "route_name": route_name,
                    "total_payload_kg": 0.0,
                    "total_payload_mt": 0.0,
                    "stops_count": 0,
                    "fps_stops": {},  # fps_id -> {name, rice_kg, wheat_kg, total_kg}
                }

            tg = truck_groups[tid]
            tg["total_payload_kg"] += qty

            if fid not in tg["fps_stops"]:
                tg["fps_stops"][fid] = {
                    "fps_id": fid,
                    "fps_name": fname,
                    "rice_kg": 0.0,
                    "wheat_kg": 0.0,
                    "total_kg": 0.0
                }

            stop = tg["fps_stops"][fid]
            if comm == "Rice":
                stop["rice_kg"] += qty
            else:
                stop["wheat_kg"] += qty
            stop["total_kg"] += qty

        # Format vehicle fleet items
        vehicle_manifest_list = []
        for tid, tg in truck_groups.items():
            stops_list = list(tg["fps_stops"].values())
            vehicle_manifest_list.append({
                "truck_id": tid,
                "source_godown": tg["source_godown"],
                "route_name": tg["route_name"],
                "total_payload_kg": round(tg["total_payload_kg"], 1),
                "total_payload_mt": round(tg["total_payload_kg"] / 1000.0, 2),
                "stops_count": len(stops_list),
                "delivery_stops": stops_list
            })

        # Workflow status
        workflow_status = "DISPATCH_GENERATED" if len(records) > 0 else "FORECAST_LOCKED"

        return {
            "status": "success",
            "workflow_status": workflow_status,
            "cycle_id": cycle_id,
            "total_dispatch_kg": round(total_dispatch_kg, 1),
            "total_rice_dispatch_kg": round(total_rice_kg, 1),
            "total_wheat_dispatch_kg": round(total_wheat_kg, 1),
            "total_fps_count": len(fps_set),
            "total_vehicles_count": len(vehicle_manifest_list),
            "vehicles": vehicle_manifest_list,
            "records": records,
            "message": "Dispatch manifest retrieved successfully.",
            "demo_notice": DEMO_NOTICE
        }

    def get_dispatch_record_by_id(
        self,
        db: sqlite3.Connection,
        dispatch_id: int
    ) -> Optional[Dict[str, Any]]:
        """Retrieve single dispatch record by ID."""
        cursor = db.cursor()
        cursor.execute("""
        SELECT 
            d.id, d.forecast_id, d.fps_id, p.name as fps_name, d.cycle_id,
            d.commodity, d.quantity_kg, d.demo_truck_id, d.source_godown,
            d.status, d.created_at
        FROM dispatch d
        JOIN fps p ON d.fps_id = p.fps_id
        WHERE d.id = ?;
        """, (dispatch_id,))
        row = cursor.fetchone()
        return dict(row) if row else None


dispatch_engine = DispatchEngine()
