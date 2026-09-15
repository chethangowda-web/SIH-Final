"""API Router for Vehicle Routing Problem (VRP) & GIS District Heatmap."""

from fastapi import APIRouter, Depends, Query
from pydantic import BaseModel, Field
import sqlite3
from app.core.database import get_db
from app.services.vrp_solver import vrp_solver

router = APIRouter(prefix="/routing", tags=["GIS & VRP Route Optimization"])

@router.get("/optimize")
def get_optimized_routes(
    truck_capacity_kg: float = Query(10000.0, description="Truck capacity in kg (default 10 MT)"),
    db: sqlite3.Connection = Depends(get_db)
):
    """
    Computes optimal multi-stop Capacitated Vehicle Routing Problem (CVRP)
    corridor dispatches from FCI Godown to Fair Price Shops, showing fuel & CO2 savings.
    """
    return vrp_solver.optimize_dispatch_routes(db, truck_capacity_kg=truck_capacity_kg)

@router.get("/gis-heatmap")
def get_gis_heatmap_data(
    cycle_id: str = Query("2026-09", description="Planning cycle ID"),
    db: sqlite3.Connection = Depends(get_db)
):
    """
    Returns geo-tagged Fair Price Shop risk markers (Lat/Long + Deficit Risk Level)
    for rendering interactive district GIS maps in Flutter.
    """
    cursor = db.cursor()
    cursor.execute("""
        SELECT f.fps_id, f.name, f.district, f.latitude, f.longitude, f.capacity_kg,
               COALESCE(SUM(i.declared_quantity_kg), 0.0) as declared_intent_kg,
               (f.capacity_kg * 0.2) as inventory_kg
        FROM fps f
        LEFT JOIN intent i ON f.fps_id = i.intended_fps_id AND i.cycle_id = ?
        GROUP BY f.fps_id
    """, (cycle_id.strip(),))
    rows = cursor.fetchall()

    heatmap_points = []
    for r in rows:
        fps_id, name, district, lat, lon, capacity, intent_kg, inventory = r
        
        # Determine stockout risk category
        demand_ratio = (intent_kg + 3000.0) / (inventory + 100.0)
        if demand_ratio > 2.0:
            risk_level = "HIGH_STOCKOUT_RISK"
            color_hex = "#DC2626"  # Red
        elif demand_ratio > 1.2:
            risk_level = "TIGHT_BUFFER"
            color_hex = "#EAB308"  # Yellow
        else:
            risk_level = "OPTIMAL_SUPPLY"
            color_hex = "#16A34A"  # Green

        heatmap_points.append({
            "fps_id": fps_id,
            "name": name,
            "district": district,
            "latitude": lat,
            "longitude": lon,
            "capacity_kg": capacity,
            "declared_intent_kg": round(intent_kg, 2),
            "current_inventory_kg": round(inventory, 2),
            "risk_level": risk_level,
            "color_hex": color_hex
        })

    return {
        "cycle_id": cycle_id,
        "district": "Bengaluru Urban Pilot",
        "total_fps_nodes": len(heatmap_points),
        "high_risk_nodes": sum(1 for p in heatmap_points if p["risk_level"] == "HIGH_STOCKOUT_RISK"),
        "points": heatmap_points
    }

class GPSVerifyIn(BaseModel):
    truck_id: str = Field("DEMO-KA-04-E-1021", description="Carrier vehicle ID")
    target_fps_id: str = Field("FPS-KA-BLR-001", description="Assigned destination shop ID")
    current_lat: float = Field(13.0031, description="Current telemetry latitude")
    current_lon: float = Field(77.5643, description="Current telemetry longitude")

@router.post("/verify-arrival")
def verify_truck_arrival(
    payload: GPSVerifyIn,
    db: sqlite3.Connection = Depends(get_db)
):
    """
    Route Checking & Geofence Verification Endpoint:
    Checks if moving truck GPS telemetry is within 100m of assigned FPS location.
    Triggers ARRIVED_AT_TARGET_FPS if inside geofence, or ROUTE_DEVIATION_ALERT if outside.
    """
    cursor = db.cursor()
    cursor.execute("SELECT latitude, longitude, name FROM fps WHERE fps_id = ?;", (payload.target_fps_id.strip(),))
    fps_row = cursor.fetchone()
    
    if not fps_row:
        return {"status": "error", "message": f"Target FPS '{payload.target_fps_id}' not found."}

    target_lat, target_lon, fps_name = fps_row
    
    # Calculate Haversine distance in meters
    dist_km = vrp_solver.haversine_distance(payload.current_lat, payload.current_lon, target_lat, target_lon)
    dist_meters = dist_km * 1000.0

    is_arrived = dist_meters <= 150.0  # 150 meter geofence radius
    arrival_status = "ARRIVED_AT_TARGET_FPS" if is_arrived else ("EN_ROUTE" if dist_km < 2.0 else "ROUTE_DEVIATION_ALERT")

    cursor.execute("""
    INSERT INTO truck_telemetry (truck_id, target_fps_id, current_lat, current_lon, distance_to_target_km, arrival_status)
    VALUES (?, ?, ?, ?, ?, ?);
    """, (payload.truck_id, payload.target_fps_id, payload.current_lat, payload.current_lon, dist_km, arrival_status))
    db.commit()

    return {
        "status": "success",
        "truck_id": payload.truck_id,
        "target_fps_id": payload.target_fps_id,
        "fps_name": fps_name,
        "distance_meters": round(dist_meters, 1),
        "geofence_arrival_verified": is_arrived,
        "telemetry_status": arrival_status,
        "message": f"Truck '{payload.truck_id}' is {round(dist_meters, 1)}m from '{fps_name}'. Status: {arrival_status}"
    }


# =====================================================================
# Phase 14A: Live Truck Route Tracking & Checkpoint Movement Endpoints
# =====================================================================

class DelayReportIn(BaseModel):
    delay_minutes: int = Field(15, description="Reported delay duration in minutes")
    reason: str = Field("Traffic Congestion on Highway Bypass", description="Operational reason for delay")

class DeviationReportIn(BaseModel):
    reason: str = Field("Unscheduled detour due to road maintenance", description="Deviation rationale")


@router.get("/tracking/active")
def get_active_truck_tracking_list(
    cycle_id: str = Query("2026-09", description="Planning cycle ID"),
    db: sqlite3.Connection = Depends(get_db)
):
    """Retrieve all active en-route and dispatched trucks with checkpoint tracking metrics."""
    from app.services.truck_tracking_service import truck_tracking_service
    return truck_tracking_service.get_all_active_trackings(db, cycle_id=cycle_id)


@router.get("/tracking/{truck_id}")
def get_truck_tracking_detail(
    truck_id: str,
    cycle_id: str = Query("2026-09", description="Planning cycle ID"),
    db: sqlite3.Connection = Depends(get_db)
):
    """Retrieve live persistent route, telemetry, and checkpoint history for a specific truck."""
    from app.services.truck_tracking_service import truck_tracking_service
    return truck_tracking_service.get_truck_tracking(db, truck_id=truck_id, cycle_id=cycle_id)


@router.post("/tracking/{truck_id}/advance")
def advance_truck_checkpoint_api(
    truck_id: str,
    db: sqlite3.Connection = Depends(get_db)
):
    """
    Field Officer Operation: Advance truck to the next sequential route checkpoint.
    Updates distance travelled, remaining distance, ETA, and persists state in SQLite.
    """
    from app.services.truck_tracking_service import truck_tracking_service
    return truck_tracking_service.advance_checkpoint(db, truck_id=truck_id)


@router.post("/tracking/{truck_id}/report-delay")
def report_truck_delay_api(
    truck_id: str,
    payload: DelayReportIn,
    db: sqlite3.Connection = Depends(get_db)
):
    """
    Field Officer Operation: Report operational delay and update dynamic arrival ETA.
    """
    from app.services.truck_tracking_service import truck_tracking_service
    return truck_tracking_service.report_delay(
        db, truck_id=truck_id,
        delay_minutes=payload.delay_minutes,
        reason=payload.reason
    )


@router.post("/tracking/{truck_id}/report-deviation")
def report_truck_deviation_api(
    truck_id: str,
    payload: DeviationReportIn,
    db: sqlite3.Connection = Depends(get_db)
):
    """
    Field Officer Operation: Flag route deviation with active warning banner.
    """
    from app.services.truck_tracking_service import truck_tracking_service
    return truck_tracking_service.report_route_deviation(
        db, truck_id=truck_id,
        reason=payload.reason
    )


@router.post("/tracking/{truck_id}/confirm-arrival")
def confirm_truck_arrival_api(
    truck_id: str,
    db: sqlite3.Connection = Depends(get_db)
):
    """
    Field Officer Operation: Confirm physical arrival of truck at target FPS.
    """
    from app.services.truck_tracking_service import truck_tracking_service
    return truck_tracking_service.confirm_arrival(db, truck_id=truck_id)


@router.post("/tracking/{truck_id}/confirm-delivery")
def confirm_truck_delivery_api(
    truck_id: str,
    db: sqlite3.Connection = Depends(get_db)
):
    """
    Field Officer Operation: Confirm goods unloaded and mark dispatch lifecycle complete.
    """
    from app.services.truck_tracking_service import truck_tracking_service
    return truck_tracking_service.confirm_delivery(db, truck_id=truck_id)
