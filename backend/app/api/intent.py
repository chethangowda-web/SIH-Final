"""Beneficiary Forward-Looking Intent Declaration API Router."""
import sqlite3
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, Query, status
from app.core.database import get_db
from app.models.schemas import IntentCreateIn, IntentOut, DEMO_NOTICE

router = APIRouter(tags=["Beneficiary Intent"])

@router.post("/intent", response_model=IntentOut, status_code=status.HTTP_201_CREATED)
def submit_intent(payload: IntentCreateIn, db: sqlite3.Connection = Depends(get_db)):
    """
    Submit or update a forward-looking voluntary intent declaration for an upcoming PDS cycle.
    Validates beneficiary, intended FPS, commodity, quantity, and choice window state.
    """
    cursor = db.cursor()

    # 0. Validate Choice Window Status for target cycle
    from app.services.forecast_engine import forecast_engine
    workflow_status = forecast_engine.get_persisted_workflow_status(db, payload.cycle_id.strip())
    if workflow_status in ["FORECAST_LOCKED", "CHOICE_WINDOW_CLOSED"]:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Choice window for cycle '{payload.cycle_id.strip()}' is closed and demand is locked for dispatch planning. Preferences can no longer be modified."
        )

    # 1. Validate quantity > 0
    if payload.declared_quantity_kg <= 0:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Declared quantity must be greater than 0 kg."
        )

    # 2. Validate commodity
    if payload.commodity not in ["Rice", "Wheat"]:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=f"Invalid commodity '{payload.commodity}'. Must be either 'Rice' or 'Wheat'."
        )

    # 3. Validate beneficiary exists
    cursor.execute("SELECT pseudonymous_beneficiary_id, registered_fps_id FROM beneficiaries WHERE pseudonymous_beneficiary_id = ?;", (payload.beneficiary_id.strip(),))
    ben_row = cursor.fetchone()
    if not ben_row:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Beneficiary '{payload.beneficiary_id}' not found."
        )

    home_fps_id = ben_row["registered_fps_id"]

    # 4. Validate intended FPS exists
    cursor.execute("SELECT fps_id, name FROM fps WHERE fps_id = ?;", (payload.intended_fps_id.strip(),))
    fps_row = cursor.fetchone()
    if not fps_row:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Intended Fair Price Shop '{payload.intended_fps_id}' not found."
        )

    intended_fps_name = fps_row["name"]
    is_portability = (payload.intended_fps_id.strip() != home_fps_id)
    confidence = payload.confidence if payload.confidence is not None else 0.95

    # 5. Insert or Update (UPSERT) Intent
    cursor.execute("""
    INSERT INTO intent (beneficiary_id, cycle_id, intended_fps_id, commodity, declared_quantity_kg, confidence, status)
    VALUES (?, ?, ?, ?, ?, ?, 'SUBMITTED')
    ON CONFLICT(beneficiary_id, cycle_id, commodity) DO UPDATE SET
        intended_fps_id = excluded.intended_fps_id,
        declared_quantity_kg = excluded.declared_quantity_kg,
        confidence = excluded.confidence,
        status = 'SUBMITTED',
        created_at = CURRENT_TIMESTAMP;
    """, (
        payload.beneficiary_id.strip(),
        payload.cycle_id.strip(),
        payload.intended_fps_id.strip(),
        payload.commodity,
        payload.declared_quantity_kg,
        confidence
    ))
    db.commit()

    # Retrieve created record
    cursor.execute("""
    SELECT id, beneficiary_id, cycle_id, intended_fps_id, commodity, declared_quantity_kg, confidence, created_at, status
    FROM intent
    WHERE beneficiary_id = ? AND cycle_id = ? AND commodity = ?;
    """, (payload.beneficiary_id.strip(), payload.cycle_id.strip(), payload.commodity))
    row = cursor.fetchone()

    return IntentOut(
        id=row["id"],
        beneficiary_id=row["beneficiary_id"],
        cycle_id=row["cycle_id"],
        intended_fps_id=row["intended_fps_id"],
        intended_fps_name=intended_fps_name,
        home_fps_id=home_fps_id,
        is_portability_intent=is_portability,
        commodity=row["commodity"],
        declared_quantity_kg=row["declared_quantity_kg"],
        confidence=row["confidence"],
        created_at=row["created_at"],
        status=row["status"],
        demo_notice=DEMO_NOTICE
    )

@router.get("/intents", response_model=List[IntentOut])
def list_intents(
    cycle_id: Optional[str] = Query("2026-09", description="Filter by cycle ID"),
    fps_id: Optional[str] = Query(None, description="Filter by intended FPS ID"),
    beneficiary_id: Optional[str] = Query(None, description="Filter by beneficiary ID"),
    limit: int = Query(100, ge=1, le=1000),
    offset: int = Query(0, ge=0),
    db: sqlite3.Connection = Depends(get_db)
):
    """Retrieve list of declared intent signals with optional filters."""
    cursor = db.cursor()
    query = """
    SELECT 
        i.id, i.beneficiary_id, i.cycle_id, i.intended_fps_id, i.commodity, i.declared_quantity_kg, 
        i.confidence, i.created_at, i.status, f.name as intended_fps_name, b.registered_fps_id as home_fps_id
    FROM intent i
    LEFT JOIN fps f ON i.intended_fps_id = f.fps_id
    LEFT JOIN beneficiaries b ON i.beneficiary_id = b.pseudonymous_beneficiary_id
    WHERE 1=1
    """
    params = []

    if cycle_id:
        query += " AND i.cycle_id = ?"
        params.append(cycle_id.strip())

    if fps_id:
        query += " AND i.intended_fps_id = ?"
        params.append(fps_id.strip())

    if beneficiary_id:
        query += " AND i.beneficiary_id = ?"
        params.append(beneficiary_id.strip())

    query += " ORDER BY i.id DESC LIMIT ? OFFSET ?;"
    cursor.execute(query, params + [limit, offset])
    rows = cursor.fetchall()

    return [
        IntentOut(
            id=r["id"],
            beneficiary_id=r["beneficiary_id"],
            cycle_id=r["cycle_id"],
            intended_fps_id=r["intended_fps_id"],
            intended_fps_name=r["intended_fps_name"],
            home_fps_id=r["home_fps_id"],
            is_portability_intent=(r["intended_fps_id"] != r["home_fps_id"]),
            commodity=r["commodity"],
            declared_quantity_kg=r["declared_quantity_kg"],
            confidence=r["confidence"],
            created_at=r["created_at"],
            status=r["status"],
            demo_notice=DEMO_NOTICE
        )
        for r in rows
    ]


@router.get("/choice-window/status")
def get_choice_window_status(
    cycle_id: str = Query("2026-09", description="Planning cycle ID"),
    db: sqlite3.Connection = Depends(get_db)
):
    """
    Retrieve real-time Choice Window status, active beneficiary preference count, 
    and aggregated demand locking status for an upcoming PDS planning cycle.
    """
    from app.services.forecast_engine import forecast_engine
    cursor = db.cursor()
    workflow_status = forecast_engine.get_persisted_workflow_status(db, cycle_id.strip())
    is_open = (workflow_status == "PLANNING_OPEN")

    cursor.execute("""
    SELECT COUNT(DISTINCT beneficiary_id), COALESCE(SUM(declared_quantity_kg), 0.0)
    FROM intent
    WHERE cycle_id = ?;
    """, (cycle_id.strip(),))
    cnt_row = cursor.fetchone()
    intents_count = int(cnt_row[0]) if cnt_row else 0
    declared_kg = round(float(cnt_row[1]), 1) if cnt_row else 0.0

    return {
        "cycle_id": cycle_id.strip(),
        "is_open": is_open,
        "status": "CHOICE_WINDOW_OPEN" if is_open else "CHOICE_WINDOW_CLOSED",
        "workflow_status": workflow_status,
        "active_intents_count": intents_count,
        "total_declared_intent_kg": declared_kg,
        "closing_deadline": "5th of Planning Month (23:59 IST)",
        "governance_notice": "Beneficiary preference is a location/demand signal only and does not reduce statutory NFSA ration entitlement.",
        "demo_notice": DEMO_NOTICE
    }

