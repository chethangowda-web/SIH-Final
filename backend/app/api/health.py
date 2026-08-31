"""System Health Check & Operational Observability Router."""
import time
from datetime import datetime, timezone
from typing import List, Optional, Dict, Any
from fastapi import APIRouter, Depends, status, Request
from fastapi.responses import JSONResponse
from pydantic import BaseModel, Field
import sqlite3

from app.core.config import settings
from app.core.database import get_db, run_database_integrity_check
from app.core.logging_config import get_logger
from app.models.schemas import HealthResponse, DEMO_NOTICE
from app.services.workflow_manager import workflow_manager

logger = get_logger("health")

router = APIRouter(tags=["System Health & Observability"])


class LivenessResponse(BaseModel):
    status: str = Field("live", description="Liveness probe status indicator")
    service: str = Field(settings.PROJECT_NAME, description="Canonical service name")
    version: str = Field(settings.VERSION, description="Application version")
    timestamp: str = Field(..., description="Current ISO-8601 server timestamp")


class ReadinessResponse(BaseModel):
    status: str = Field(..., description="'ready' when operational, 'unready' on dependency failure")
    database: str = Field(..., description="Database connection health")
    integrity: str = Field(..., description="SQLite PRAGMA integrity verification state")
    tables_count: int = Field(..., description="Count of active database tables")
    timestamp: str = Field(..., description="Current ISO-8601 server timestamp")


class OperationalStatusResponse(BaseModel):
    service: str = Field(settings.PROJECT_NAME)
    active_cycle: str = Field("2026-09", description="Active planning and distribution cycle")
    workflow_state: str = Field(..., description="Current authoritative workflow state")
    allowed_next_states: List[str] = Field(default_factory=list, description="Permitted target states")
    blocked_conditions: List[str] = Field(default_factory=list, description="Active condition blockers if any")
    choice_window_status: str = Field(..., description="Forward-looking intent choice window state")
    active_dispatches_count: int = Field(0, description="Active truck dispatches in-flight")
    database_integrity: str = Field("ok", description="Database file integrity check")
    server_time: str = Field(..., description="Server timestamp")
    uptime_seconds: float = Field(..., description="Elapsed system uptime in seconds")


@router.get("/health", response_model=HealthResponse, status_code=status.HTTP_200_OK)
def get_health(db: sqlite3.Connection = Depends(get_db)):
    """
    Live diagnostic health check for PDS DemandSync engine.
    Retained for complete backwards compatibility with existing UI and external probes.
    """
    cursor = db.cursor()
    try:
        cursor.execute("SELECT COUNT(*) FROM fps;")
        fps_count = cursor.fetchone()[0]
        cursor.execute("SELECT COUNT(*) FROM beneficiaries;")
        ben_count = cursor.fetchone()[0]
        db_status = "connected"
    except Exception as e:
        logger.error("Health check failed to query database counts: %s", e)
        fps_count = 0
        ben_count = 0
        db_status = "error: database unavailable"

    now = datetime.now()
    return HealthResponse(
        status="healthy" if db_status == "connected" else "degraded",
        project_name=settings.PROJECT_NAME,
        subtitle=settings.PROJECT_SUBTITLE,
        version=settings.VERSION,
        database_status=db_status,
        district="Bengaluru Urban PDS Pilot",
        active_cycle="2026-09",
        historical_cycles=["2026-03", "2026-04", "2026-05", "2026-06", "2026-07", "2026-08"],
        fps_count=fps_count,
        beneficiaries_count=ben_count,
        server_time=now.strftime("%Y-%m-%d %H:%M:%S UTC+05:30"),
        demo_notice=DEMO_NOTICE
    )


@router.get("/health/live", response_model=LivenessResponse, status_code=status.HTTP_200_OK)
def get_liveness():
    """
    Lightweight Kubernetes/Cloud liveness probe.
    Returns HTTP 200 immediately if process event loop is active.
    """
    return LivenessResponse(
        status="live",
        service=settings.PROJECT_NAME,
        version=settings.VERSION,
        timestamp=datetime.now(timezone.utc).isoformat()
    )


@router.get("/health/ready", response_model=ReadinessResponse)
def get_readiness(db: sqlite3.Connection = Depends(get_db)):
    """
    Readiness probe verifying SQLite connectivity, table availability, and PRAGMA integrity check.
    Returns HTTP 200 if ready, or HTTP 503 if database is unreachable or corrupt.
    """
    ts = datetime.now(timezone.utc).isoformat()
    try:
        cursor = db.cursor()
        cursor.execute("SELECT COUNT(*) FROM sqlite_master WHERE type='table';")
        tables_count = cursor.fetchone()[0]

        diag = run_database_integrity_check(db)
        if diag["status"] != "HEALTHY" or not diag["integrity_check_passed"]:
            logger.error("Readiness check detected database corruption: %s", diag["integrity_check_details"])
            return JSONResponse(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                content={
                    "status": "unready",
                    "database": "connected",
                    "integrity": f"corrupt: {diag['integrity_check_details']}",
                    "tables_count": tables_count,
                    "timestamp": ts
                }
            )

        return ReadinessResponse(
            status="ready",
            database="connected",
            integrity="ok",
            tables_count=tables_count,
            timestamp=ts
        )
    except Exception as e:
        logger.error("Readiness check failed with exception: %s", e)
        return JSONResponse(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            content={
                "status": "unready",
                "database": f"error: {str(e)}",
                "integrity": "unknown",
                "tables_count": 0,
                "timestamp": ts
            }
        )


@router.get("/health/status", response_model=OperationalStatusResponse, status_code=status.HTTP_200_OK)
@router.get("/admin/operations/status", response_model=OperationalStatusResponse, status_code=status.HTTP_200_OK)
def get_operational_status(
    request: Request,
    cycle_id: str = "2026-09",
    db: sqlite3.Connection = Depends(get_db)
):
    """
    Comprehensive operational observability endpoint exposing current cycle workflow state,
    blocked stages, choice window status, and dispatch telemetry without leaking secrets.
    """
    current_state = workflow_manager.get_current_state(db, cycle_id)
    allowed_next = workflow_manager.get_allowed_next_states(current_state)

    # Check blocking conditions for next prospective state
    target_state = allowed_next[0] if allowed_next else current_state
    blockers = workflow_manager.get_blocking_conditions(db, cycle_id, current_state, target_state)

    # Check choice window status
    from app.services.forecast_engine import forecast_engine
    workflow_status = forecast_engine.get_persisted_workflow_status(db, cycle_id)
    cw_status = "OPEN" if (workflow_status == "PLANNING_OPEN") else "CLOSED"

    # Count active dispatches
    cursor = db.cursor()
    cursor.execute("SELECT COUNT(*) FROM manifests WHERE cycle_id = ?;", (cycle_id,))
    dispatches_count = cursor.fetchone()[0]

    # Calculate uptime
    start_time = getattr(request.app.state, "start_time", time.time())
    uptime = time.time() - start_time

    return OperationalStatusResponse(
        service=settings.PROJECT_NAME,
        active_cycle=cycle_id,
        workflow_state=current_state,
        allowed_next_states=allowed_next,
        blocked_conditions=blockers,
        choice_window_status=cw_status,
        active_dispatches_count=dispatches_count,
        database_integrity="ok",
        server_time=datetime.now(timezone.utc).isoformat(),
        uptime_seconds=round(uptime, 2)
    )
