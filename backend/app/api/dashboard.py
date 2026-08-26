"""Executive Dashboard Analytics API Router."""
import sqlite3
from fastapi import APIRouter, Depends
from app.core.database import get_db
from app.models.schemas import DashboardSummaryOut, DEMO_NOTICE

router = APIRouter(tags=["District Dashboard"])

@router.get("/dashboard/summary", response_model=DashboardSummaryOut)
def get_dashboard_summary(db: sqlite3.Connection = Depends(get_db)):
    """Retrieve district-level high-level KPI metrics, inventory totals, and forward-looking intent signals."""
    cursor = db.cursor()

    # 1. FPS Count
    cursor.execute("SELECT COUNT(*) FROM fps;")
    total_fps = cursor.fetchone()[0]

    # 2. Beneficiaries Count
    cursor.execute("SELECT COUNT(*) FROM beneficiaries;")
    total_beneficiaries = cursor.fetchone()[0]

    # 3. Inventory Totals
    cursor.execute("SELECT COALESCE(SUM(available_quantity_kg), 0.0) FROM inventory WHERE commodity = 'Rice';")
    rice_inv = cursor.fetchone()[0]
    cursor.execute("SELECT COALESCE(SUM(available_quantity_kg), 0.0) FROM inventory WHERE commodity = 'Wheat';")
    wheat_inv = cursor.fetchone()[0]
    total_inv = rice_inv + wheat_inv

    # 4. Intent Totals for Active Cycle (2026-09)
    cursor.execute("SELECT COALESCE(SUM(declared_quantity_kg), 0.0) FROM intent WHERE cycle_id = '2026-09' AND commodity = 'Rice';")
    rice_intent = cursor.fetchone()[0]
    cursor.execute("SELECT COALESCE(SUM(declared_quantity_kg), 0.0) FROM intent WHERE cycle_id = '2026-09' AND commodity = 'Wheat';")
    wheat_intent = cursor.fetchone()[0]
    total_intent = rice_intent + wheat_intent

    # 5. Distinct Beneficiaries with Intent
    cursor.execute("SELECT COUNT(DISTINCT beneficiary_id) FROM intent WHERE cycle_id = '2026-09';")
    intent_ben_count = cursor.fetchone()[0]

    # 6. Portability Intents (where intended_fps != registered_fps)
    cursor.execute("""
    SELECT COUNT(DISTINCT i.beneficiary_id)
    FROM intent i
    JOIN beneficiaries b ON i.beneficiary_id = b.pseudonymous_beneficiary_id
    WHERE i.cycle_id = '2026-09' AND i.intended_fps_id != b.registered_fps_id;
    """)
    portability_count = cursor.fetchone()[0]
    portability_pct = round((portability_count / intent_ben_count) * 100.0, 1) if intent_ben_count > 0 else 0.0

    return DashboardSummaryOut(
        district="Bengaluru Urban - Demo District",
        total_fps=total_fps,
        total_beneficiaries=total_beneficiaries,
        active_cycle="2026-09",
        historical_cycles_count=6,
        total_inventory_kg=round(total_inv, 1),
        total_rice_inventory_kg=round(rice_inv, 1),
        total_wheat_inventory_kg=round(wheat_inv, 1),
        total_declared_intent_kg=round(total_intent, 1),
        total_rice_intent_kg=round(rice_intent, 1),
        total_wheat_intent_kg=round(wheat_intent, 1),
        intent_beneficiaries_count=intent_ben_count,
        portability_intent_count=portability_count,
        portability_intent_pct=portability_pct,
        demo_notice=DEMO_NOTICE
    )
