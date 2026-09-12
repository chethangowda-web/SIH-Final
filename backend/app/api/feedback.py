"""Officer <-> Beneficiary & Officer <-> FPS Dealer Feedback & Dispute Management Router."""
import random
import sqlite3
from typing import List, Optional
from pydantic import BaseModel, Field
from fastapi import APIRouter, Depends, HTTPException, Query, status
from app.core.database import get_db
from app.core.auth import get_current_user
from app.models.schemas import DEMO_NOTICE

router = APIRouter(prefix="/feedback", tags=["Feedback & Case Tickets"])

class FeedbackSubmitIn(BaseModel):
    sender_type: str = Field("BENEFICIARY", description="BENEFICIARY or DEALER_FPS")
    sender_id: str = Field(..., description="Card ID or FPS Dealer ID")
    target_fps_id: Optional[str] = Field("FPS-KA-BLR-001", description="Associated FPS ID")
    category: str = Field("GENERAL", description="SHORT_WEIGHT, SHOP_CLOSED, RATION_QUALITY, DELIVERY_DELAY, GENERAL")
    subject: str = Field(..., description="Short summary of feedback or dispute")
    message: str = Field(..., description="Detailed description")

class FeedbackResolveIn(BaseModel):
    officer_response: str = Field(..., description="Official resolution note from DSO")
    status: str = Field("RESOLVED", description="RESOLVED, REJECTED, or UNDER_INVESTIGATION")

@router.post("/submit", status_code=status.HTTP_201_CREATED)
def submit_feedback(
    payload: FeedbackSubmitIn,
    db: sqlite3.Connection = Depends(get_db),
    current_user: dict = Depends(get_current_user)
):
    """Submits a new feedback or dispute ticket from a Citizen or FPS Dealer."""
    cursor = db.cursor()
    ticket_id = f"TKT-{random.randint(10000, 99999)}"

    cursor.execute("""
    INSERT INTO feedback (ticket_id, sender_type, sender_id, target_fps_id, category, subject, message, priority, status)
    VALUES (?, ?, ?, ?, ?, ?, ?, 'NORMAL', 'OPEN');
    """, (ticket_id, payload.sender_type, payload.sender_id, payload.target_fps_id, payload.category, payload.subject, payload.message))
    db.commit()

    return {
        "status": "success",
        "ticket_id": ticket_id,
        "message": "Feedback/Dispute logged successfully. DSO Office notified.",
        "demo_notice": DEMO_NOTICE
    }

@router.get("/list")
def list_feedback_tickets(
    sender_id: Optional[str] = None,
    status_filter: Optional[str] = None,
    db: sqlite3.Connection = Depends(get_db),
    current_user: dict = Depends(get_current_user)
):
    """Retrieves feedback and case tickets for DSO triage queue or citizen status check."""
    cursor = db.cursor()
    query = "SELECT * FROM feedback WHERE 1=1"
    params = []

    if sender_id:
        query += " AND sender_id = ?"
        params.append(sender_id)

    if status_filter:
        query += " AND status = ?"
        params.append(status_filter)

    query += " ORDER BY id DESC LIMIT 50;"
    cursor.execute(query, params)
    rows = cursor.fetchall()

    return [
        {
            "id": r["id"],
            "ticket_id": r["ticket_id"],
            "sender_type": r["sender_type"],
            "sender_id": r["sender_id"],
            "target_fps_id": r["target_fps_id"],
            "category": r["category"],
            "subject": r["subject"],
            "message": r["message"],
            "priority": r["priority"],
            "status": r["status"],
            "officer_response": r["officer_response"],
            "created_at": r["created_at"],
            "resolved_at": r["resolved_at"]
        }
        for r in rows
    ]

@router.post("/{ticket_id}/resolve")
def resolve_feedback_ticket(
    ticket_id: str,
    payload: FeedbackResolveIn,
    db: sqlite3.Connection = Depends(get_db),
    current_user: dict = Depends(get_current_user)
):
    """DSO Officer resolution endpoint to respond and update case ticket status."""
    cursor = db.cursor()
    cursor.execute("""
    UPDATE feedback 
    SET officer_response = ?, status = ?, resolved_at = CURRENT_TIMESTAMP 
    WHERE ticket_id = ?;
    """, (payload.officer_response, payload.status, ticket_id))
    db.commit()

    return {
        "status": "success",
        "ticket_id": ticket_id,
        "new_status": payload.status,
        "message": f"Ticket {ticket_id} updated to '{payload.status}' by DSO Officer."
    }
