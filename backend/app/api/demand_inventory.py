"""Historical Demand & Live Inventory API Router."""
import sqlite3
from fastapi import APIRouter, Depends, HTTPException, status
from app.core.database import get_db
from app.models.schemas import (
    FPSHistoricalDemandOut, HistoricalDemandRecord,
    FPSInventoryOut, InventoryItem, DEMO_NOTICE
)

router = APIRouter(tags=["Historical Demand & Inventory"])

@router.get("/historical-demand/{fps_id}", response_model=FPSHistoricalDemandOut)
def get_historical_demand(fps_id: str, db: sqlite3.Connection = Depends(get_db)):
    """Retrieve 6-month historical lifting demand time-series for an FPS across Rice & Wheat."""
    cursor = db.cursor()

    # 1. Verify FPS exists
    cursor.execute("SELECT fps_id, name FROM fps WHERE fps_id = ?;", (fps_id.strip(),))
    fps_row = cursor.fetchone()
    if not fps_row:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Fair Price Shop '{fps_id}' not found."
        )

    # 2. Fetch historical records
    cursor.execute("""
    SELECT cycle_id, commodity, actual_quantity_kg
    FROM historical_demand
    WHERE fps_id = ?
    ORDER BY cycle_id ASC, commodity ASC;
    """, (fps_id.strip(),))
    rows = cursor.fetchall()

    records = [
        HistoricalDemandRecord(
            cycle_id=r["cycle_id"],
            commodity=r["commodity"],
            actual_quantity_kg=r["actual_quantity_kg"]
        )
        for r in rows
    ]

    rice_trend = [
        {"cycle_id": r.cycle_id, "quantity_kg": r.actual_quantity_kg}
        for r in records if r.commodity == "Rice"
    ]

    wheat_trend = [
        {"cycle_id": r.cycle_id, "quantity_kg": r.actual_quantity_kg}
        for r in records if r.commodity == "Wheat"
    ]

    return FPSHistoricalDemandOut(
        fps_id=fps_row["fps_id"],
        fps_name=fps_row["name"],
        records=records,
        rice_trend_kg=rice_trend,
        wheat_trend_kg=wheat_trend,
        demo_notice=DEMO_NOTICE
    )

@router.get("/inventory/{fps_id}", response_model=FPSInventoryOut)
def get_inventory(fps_id: str, db: sqlite3.Connection = Depends(get_db)):
    """Retrieve current stock inventory balances and capacity utilization for an FPS."""
    cursor = db.cursor()

    # 1. Verify FPS exists
    cursor.execute("SELECT fps_id, name, capacity_kg FROM fps WHERE fps_id = ?;", (fps_id.strip(),))
    fps_row = cursor.fetchone()
    if not fps_row:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Fair Price Shop '{fps_id}' not found."
        )

    # 2. Fetch inventory items
    cursor.execute("""
    SELECT commodity, available_quantity_kg
    FROM inventory
    WHERE fps_id = ?
    ORDER BY commodity ASC;
    """, (fps_id.strip(),))
    rows = cursor.fetchall()

    items = [
        InventoryItem(
            commodity=r["commodity"],
            available_quantity_kg=r["available_quantity_kg"]
        )
        for r in rows
    ]

    total_avail = sum(item.available_quantity_kg for item in items)
    capacity = fps_row["capacity_kg"]
    util_pct = round((total_avail / capacity) * 100.0, 1) if capacity > 0 else 0.0

    return FPSInventoryOut(
        fps_id=fps_row["fps_id"],
        fps_name=fps_row["name"],
        capacity_kg=capacity,
        total_available_kg=round(total_avail, 1),
        capacity_utilization_pct=util_pct,
        items=items,
        demo_notice=DEMO_NOTICE
    )
