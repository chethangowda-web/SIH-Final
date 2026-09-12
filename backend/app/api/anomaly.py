"""API Router for AI Anomaly & Fraud Detection Engine."""

from fastapi import APIRouter, Depends, Query
import sqlite3
from app.core.database import get_db
from app.services.anomaly_engine import anomaly_engine

router = APIRouter(prefix="/anomaly", tags=["AI Fraud & Anomaly Detection"])

@router.get("/scan")
def scan_anomalies(
    cycle_id: str = Query("2026-09", description="Planning cycle ID e.g. 2026-09"),
    db: sqlite3.Connection = Depends(get_db)
):
    """
    Run AI Anomaly & Fraud Detection scan across all registered intent signals for the specified cycle.
    Uses Isolation Forest and Z-Score spike detection to highlight unusual intent spikes.
    """
    return anomaly_engine.scan_intent_anomalies(db, cycle_id=cycle_id.strip())

@router.get("/summary")
def anomaly_summary(
    cycle_id: str = Query("2026-09", description="Planning cycle ID"),
    db: sqlite3.Connection = Depends(get_db)
):
    """Returns top-level anomaly metrics and high-risk FPS flags for District Admin widgets."""
    res = anomaly_engine.scan_intent_anomalies(db, cycle_id=cycle_id.strip())
    return {
        "cycle_id": res["cycle_id"],
        "status": res["status"],
        "total_scanned_intents": res["total_scanned_intents"],
        "high_risk_fps_count": res["anomalies_detected"],
        "fps_risk_summary": res["fps_risk_summary"],
        "timestamp": res["timestamp"]
    }
