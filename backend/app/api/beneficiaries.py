"""Beneficiary Management & Lookup API Router."""
import sqlite3
from typing import Optional
from fastapi import APIRouter, Depends, HTTPException, Query, status
from app.core.database import get_db
from app.models.schemas import BeneficiaryOut, BeneficiaryDetailOut, PaginatedBeneficiaries, DEMO_NOTICE

router = APIRouter(tags=["Beneficiaries"])

@router.get("/beneficiaries", response_model=PaginatedBeneficiaries)
def list_beneficiaries(
    limit: int = Query(50, ge=1, le=2000, description="Max records to return"),
    offset: int = Query(0, ge=0, description="Number of records to skip"),
    fps_id: Optional[str] = Query(None, description="Filter by registered FPS ID e.g. FPS-KA-BLR-001"),
    search: Optional[str] = Query(None, description="Search by pseudonymous ID or name"),
    db: sqlite3.Connection = Depends(get_db)
):
    """Retrieve paginated list of synthetic demo beneficiaries."""
    cursor = db.cursor()
    query = "SELECT id, pseudonymous_beneficiary_id, name_for_demo, registered_fps_id, language, status FROM beneficiaries WHERE 1=1"
    count_query = "SELECT COUNT(*) FROM beneficiaries WHERE 1=1"
    params = []

    if fps_id:
        query += " AND registered_fps_id = ?"
        count_query += " AND registered_fps_id = ?"
        params.append(fps_id.strip())

    if search:
        search_term = f"%{search.strip()}%"
        query += " AND (pseudonymous_beneficiary_id LIKE ? OR name_for_demo LIKE ?)"
        count_query += " AND (pseudonymous_beneficiary_id LIKE ? OR name_for_demo LIKE ?)"
        params.extend([search_term, search_term])

    cursor.execute(count_query, params)
    total = cursor.fetchone()[0]

    query += " ORDER BY id ASC LIMIT ? OFFSET ?;"
    cursor.execute(query, params + [limit, offset])
    rows = cursor.fetchall()

    items = [
        BeneficiaryOut(
            id=r["id"],
            pseudonymous_beneficiary_id=r["pseudonymous_beneficiary_id"],
            name_for_demo=r["name_for_demo"],
            registered_fps_id=r["registered_fps_id"],
            language=r["language"],
            status=r["status"]
        )
        for r in rows
    ]

    return PaginatedBeneficiaries(
        total=total,
        limit=limit,
        offset=offset,
        items=items,
        demo_notice=DEMO_NOTICE
    )

@router.get("/beneficiaries/{id}", response_model=BeneficiaryDetailOut)
def get_beneficiary(id: str, db: sqlite3.Connection = Depends(get_db)):
    """Retrieve detailed beneficiary profile by integer ID or pseudonymous ID (e.g. BEN-KA-0001)."""
    cursor = db.cursor()
    
    # Check if id is integer or pseudonymous string
    if id.isdigit():
        cursor.execute("""
        SELECT b.id, b.pseudonymous_beneficiary_id, b.name_for_demo, b.registered_fps_id, b.language, b.status, f.name as registered_fps_name
        FROM beneficiaries b
        LEFT JOIN fps f ON b.registered_fps_id = f.fps_id
        WHERE b.id = ?;
        """, (int(id),))
    else:
        cursor.execute("""
        SELECT b.id, b.pseudonymous_beneficiary_id, b.name_for_demo, b.registered_fps_id, b.language, b.status, f.name as registered_fps_name
        FROM beneficiaries b
        LEFT JOIN fps f ON b.registered_fps_id = f.fps_id
        WHERE b.pseudonymous_beneficiary_id = ?;
        """, (id.strip(),))

    row = cursor.fetchone()
    if not row:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Beneficiary with identifier '{id}' not found."
        )

    # Fetch active declared intents
    cursor.execute("""
    SELECT i.id, i.cycle_id, i.intended_fps_id, f.name as intended_fps_name, i.commodity, i.declared_quantity_kg, i.confidence, i.created_at, i.status
    FROM intent i
    LEFT JOIN fps f ON i.intended_fps_id = f.fps_id
    WHERE i.beneficiary_id = ?
    ORDER BY i.commodity ASC;
    """, (row["pseudonymous_beneficiary_id"],))
    intent_rows = cursor.fetchall()
    active_intents = [dict(r) for r in intent_rows]

    return BeneficiaryDetailOut(
        id=row["id"],
        pseudonymous_beneficiary_id=row["pseudonymous_beneficiary_id"],
        name_for_demo=row["name_for_demo"],
        registered_fps_id=row["registered_fps_id"],
        registered_fps_name=row["registered_fps_name"],
        language=row["language"],
        status=row["status"],
        active_intents=active_intents,
        demo_notice=DEMO_NOTICE
    )
