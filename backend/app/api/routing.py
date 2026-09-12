"""API Router for Vehicle Routing Problem (VRP) & GIS District Heatmap."""

from fastapi import APIRouter, Depends, Query
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
