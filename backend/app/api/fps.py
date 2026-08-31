"""Fair Price Shop (FPS) Management & Lookup API Router."""
import sqlite3
from typing import List
from fastapi import APIRouter, Depends, HTTPException, status
from app.core.database import get_db
from app.models.schemas import FPSOut, FPSDetailOut, InventoryItem, DEMO_NOTICE

from app.core.auth import get_current_user

router = APIRouter(tags=["Fair Price Shops"], dependencies=[Depends(get_current_user)])

@router.get("/fps", response_model=List[FPSOut])
def list_fps(db: sqlite3.Connection = Depends(get_db)):
    """Retrieve list of all 20 Fair Price Shops with aggregated inventory and intent totals."""
    cursor = db.cursor()
    cursor.execute("""
    SELECT 
        f.id, f.fps_id, f.name, f.district, f.latitude, f.longitude, f.capacity_kg, f.status,
        (SELECT COUNT(*) FROM beneficiaries b WHERE b.registered_fps_id = f.fps_id) as registered_cards,
        COALESCE((SELECT SUM(available_quantity_kg) FROM inventory inv WHERE inv.fps_id = f.fps_id), 0.0) as total_inventory_kg,
        COALESCE((SELECT SUM(declared_quantity_kg) FROM intent i WHERE i.intended_fps_id = f.fps_id AND i.cycle_id = '2026-09'), 0.0) as total_intent_kg
    FROM fps f
    ORDER BY f.id ASC;
    """)
    rows = cursor.fetchall()

    return [
        FPSOut(
            id=r["id"],
            fps_id=r["fps_id"],
            name=r["name"],
            district=r["district"],
            latitude=r["latitude"],
            longitude=r["longitude"],
            capacity_kg=r["capacity_kg"],
            status=r["status"],
            registered_beneficiaries_count=r["registered_cards"],
            current_inventory_total_kg=round(r["total_inventory_kg"], 1),
            declared_intent_cycle_kg=round(r["total_intent_kg"], 1)
        )
        for r in rows
    ]

@router.get("/fps/{id}", response_model=FPSDetailOut)
def get_fps_detail(id: str, db: sqlite3.Connection = Depends(get_db)):
    """Retrieve detailed Fair Price Shop profile by integer ID or string fps_id."""
    cursor = db.cursor()

    if id.isdigit():
        cursor.execute("SELECT id, fps_id, name, district, latitude, longitude, capacity_kg, status FROM fps WHERE id = ?;", (int(id),))
    else:
        cursor.execute("SELECT id, fps_id, name, district, latitude, longitude, capacity_kg, status FROM fps WHERE fps_id = ?;", (id.strip(),))

    row = cursor.fetchone()
    if not row:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Fair Price Shop with identifier '{id}' not found."
        )

    fps_id = row["fps_id"]

    # 1. Registered Beneficiaries Count
    cursor.execute("SELECT COUNT(*) FROM beneficiaries WHERE registered_fps_id = ?;", (fps_id,))
    registered_count = cursor.fetchone()[0]

    # 2. Inventories for Rice & Wheat
    cursor.execute("SELECT commodity, available_quantity_kg FROM inventory WHERE fps_id = ? ORDER BY commodity ASC;", (fps_id,))
    inv_rows = cursor.fetchall()
    inventories = [InventoryItem(commodity=r["commodity"], available_quantity_kg=r["available_quantity_kg"]) for r in inv_rows]

    # 3. Intent Totals for Active Cycle (2026-09)
    cursor.execute("""
    SELECT 
        commodity,
        COUNT(DISTINCT beneficiary_id) as beneficiary_count,
        SUM(declared_quantity_kg) as total_quantity_kg,
        AVG(confidence) as avg_confidence
    FROM intent 
    WHERE intended_fps_id = ? AND cycle_id = '2026-09'
    GROUP BY commodity;
    """, (fps_id,))
    intent_rows = cursor.fetchall()
    intent_summary = {
        "cycle_id": "2026-09",
        "commodities": {
            r["commodity"]: {
                "beneficiary_count": r["beneficiary_count"],
                "total_quantity_kg": round(r["total_quantity_kg"], 1),
                "avg_confidence": round(r["avg_confidence"], 2)
            }
            for r in intent_rows
        }
    }

    return FPSDetailOut(
        id=row["id"],
        fps_id=row["fps_id"],
        name=row["name"],
        district=row["district"],
        latitude=row["latitude"],
        longitude=row["longitude"],
        capacity_kg=row["capacity_kg"],
        status=row["status"],
        registered_beneficiaries_count=registered_count,
        inventories=inventories,
        current_cycle_intents=intent_summary,
        demo_notice=DEMO_NOTICE
    )
