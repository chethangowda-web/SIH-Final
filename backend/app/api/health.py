"""System Health Check Router."""
from datetime import datetime
from fastapi import APIRouter, Depends, status
import sqlite3
from app.core.database import get_db
from app.models.schemas import HealthResponse, DEMO_NOTICE

router = APIRouter(tags=["System Health"])

@router.get("/health", response_model=HealthResponse, status_code=status.HTTP_200_OK)
def get_health(db: sqlite3.Connection = Depends(get_db)):
    """Live diagnostic health check for PDS DemandSync engine."""
    cursor = db.cursor()
    try:
        cursor.execute("SELECT COUNT(*) FROM fps;")
        fps_count = cursor.fetchone()[0]
        cursor.execute("SELECT COUNT(*) FROM beneficiaries;")
        ben_count = cursor.fetchone()[0]
        db_status = "connected"
    except Exception as e:
        fps_count = 0
        ben_count = 0
        db_status = f"error: {str(e)}"

    now = datetime.now()
    return HealthResponse(
        status="healthy",
        project_name="PDS DemandSync",
        subtitle="Forward-Looking Beneficiary Intent for Pre-Dispatch PDS Demand Forecasting",
        version="1.0.0-demo-v1",
        database_status=db_status,
        district="Bengaluru Urban - Demo District",
        active_cycle="2026-09",
        historical_cycles=["2026-03", "2026-04", "2026-05", "2026-06", "2026-07", "2026-08"],
        fps_count=fps_count,
        beneficiaries_count=ben_count,
        server_time=now.strftime("%Y-%m-%d %H:%M:%S UTC+05:30"),
        demo_notice=DEMO_NOTICE
    )
