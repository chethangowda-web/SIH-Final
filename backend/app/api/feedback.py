"""Officer <-> Beneficiary & Officer <-> FPS Dealer Feedback & Dispute Management Router."""
import json
import math
import random
import sqlite3
from collections import defaultdict
from typing import List, Optional
from pydantic import BaseModel, Field
from fastapi import APIRouter, Depends, HTTPException, Query, status
from app.core.database import get_db
from app.core.auth import get_current_user
from app.models.schemas import DEMO_NOTICE

router = APIRouter(prefix="/feedback", tags=["Feedback & Case Tickets"])

# ---------------------------------------------------------------------------
# Pydantic Schemas
# ---------------------------------------------------------------------------

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

class EscalateClusterIn(BaseModel):
    cluster_id: str = Field(..., description="Cluster ID to escalate to DSO")
    dso_response: Optional[str] = Field(None, description="Optional DSO directive note")


# ---------------------------------------------------------------------------
# Helpers: Complaint Clustering Engine
# ---------------------------------------------------------------------------

# Category keyword map for simple NLP-based classification
_CATEGORY_KEYWORDS = {
    "SHORT_WEIGHT": ["short weight", "less weight", "weighing", "less quantity", "quantity", "gram", "kg", "kilo", "scale", "measurement"],
    "SHOP_CLOSED": ["shop closed", "closed shop", "not open", "absent", "unavailable", "shop not open", "dealer absent", "locked"],
    "RATION_QUALITY": ["quality", "bad quality", "rotten", "stale", "damaged", "mold", "smell", "poor quality", "expired", "insect", "worm"],
    "DELIVERY_DELAY": ["delay", "late", "not received", "waiting", "delayed", "no stock", "pending", "not delivered", "delayed delivery"],
    "OVERCHARGING": ["overcharge", "extra money", "bribe", "price", "cost", "charge", "demand money", "black market"],
}

def _classify_category(text: str) -> str:
    """Rule-based category classification from complaint text."""
    text_lower = text.lower()
    scores = {}
    for cat, keywords in _CATEGORY_KEYWORDS.items():
        scores[cat] = sum(1 for kw in keywords if kw in text_lower)
    best = max(scores, key=scores.get)
    return best if scores[best] > 0 else "GENERAL"


def _text_similarity(a: str, b: str) -> float:
    """Simple Jaccard similarity between two texts using word-level tokens."""
    words_a = set(a.lower().split())
    words_b = set(b.lower().split())
    # Remove common stop words
    stops = {"the", "a", "an", "is", "are", "was", "were", "to", "of", "in", "i", "my", "and", "or", "not", "it", "at", "by"}
    words_a -= stops
    words_b -= stops
    if not words_a and not words_b:
        return 1.0
    intersection = words_a & words_b
    union = words_a | words_b
    return len(intersection) / len(union) if union else 0.0


def _generate_cluster_summary(category: str, tickets: List[dict]) -> str:
    """Generate a concise AI-style summary for a cluster of complaints."""
    fps_ids = list({t.get("target_fps_id", "Unknown") for t in tickets if t.get("target_fps_id")})
    fps_str = fps_ids[0] if len(fps_ids) == 1 else (", ".join(fps_ids[:3]) + ("..." if len(fps_ids) > 3 else ""))
    count = len(tickets)
    subjects = [t.get("subject", "") for t in tickets[:3]]

    category_labels = {
        "SHORT_WEIGHT": "short weight / quantity fraud",
        "SHOP_CLOSED": "FPS shop closure / dealer absence",
        "RATION_QUALITY": "poor ration quality",
        "DELIVERY_DELAY": "delivery delay / stock unavailability",
        "OVERCHARGING": "overcharging / bribery",
        "GENERAL": "general grievance",
    }

    severity_map = {
        "SHORT_WEIGHT": "HIGH",
        "OVERCHARGING": "HIGH",
        "SHOP_CLOSED": "MEDIUM",
        "DELIVERY_DELAY": "MEDIUM",
        "RATION_QUALITY": "HIGH",
        "GENERAL": "LOW",
    }

    issue_label = category_labels.get(category, "general complaint")
    severity = severity_map.get(category, "MEDIUM")
    sample = subjects[0] if subjects else "Unspecified issue"

    return {
        "summary": (
            f"{count} beneficiaries reported {issue_label} at {fps_str}. "
            f"Representative complaint: \"{sample[:100]}\". "
            f"Pattern identified across multiple tickets — requires DSO-level intervention."
        ),
        "severity": severity,
    }


def _cluster_complaints(tickets: List[dict]) -> List[dict]:
    """
    Group tickets into semantic clusters using category + text similarity.
    Returns list of cluster dicts ready to upsert into complaint_clusters.
    """
    # Phase 1: Category-level grouping
    by_category = defaultdict(list)
    for ticket in tickets:
        combined_text = f"{ticket.get('subject', '')} {ticket.get('message', '')}"
        cat = ticket.get("category") or _classify_category(combined_text)
        by_category[cat].append({**ticket, "_text": combined_text, "_cat": cat})

    clusters = []
    for cat, cat_tickets in by_category.items():
        # Phase 2: Within each category, sub-cluster by text similarity
        sub_clusters: List[List[dict]] = []
        for ticket in cat_tickets:
            placed = False
            for sc in sub_clusters:
                # Compare with representative (first) ticket in sub-cluster
                rep = sc[0]["_text"]
                sim = _text_similarity(ticket["_text"], rep)
                if sim >= 0.15:  # threshold: >=15% word overlap → same cluster
                    sc.append(ticket)
                    placed = True
                    break
            if not placed:
                sub_clusters.append([ticket])

        for sc in sub_clusters:
            info = _generate_cluster_summary(cat, sc)
            fps_counts = defaultdict(int)
            for t in sc:
                fps_counts[t.get("target_fps_id", "UNKNOWN")] += 1
            primary_fps = max(fps_counts, key=fps_counts.get) if fps_counts else None

            clusters.append({
                "category": cat,
                "cluster_label": f"{cat.replace('_', ' ').title()} — {primary_fps or 'Multiple FPS'}",
                "ai_summary": info["summary"],
                "severity": info["severity"],
                "complaint_count": len(sc),
                "ticket_ids": [t["ticket_id"] for t in sc],
                "primary_fps_id": primary_fps,
            })

    return clusters


# ---------------------------------------------------------------------------
# Routes
# ---------------------------------------------------------------------------

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


# ---------------------------------------------------------------------------
# Escalation System Endpoints
# ---------------------------------------------------------------------------

@router.get("/escalation/analysis")
def get_escalation_analysis(
    db: sqlite3.Connection = Depends(get_db),
    current_user: dict = Depends(get_current_user)
):
    """
    AI-powered complaint clustering and escalation analysis.
    
    Groups all OPEN/UNDER_INVESTIGATION tickets by semantic similarity and category,
    upserts cluster records, and returns:
    - Individual complaint list
    - Cluster groups with count, AI summary, severity, escalation status
    - Escalation-ready clusters (unresolved + high count)
    """
    cursor = db.cursor()

    # Ensure the complaint_clusters table exists (idempotent)
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS complaint_clusters (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        cluster_id TEXT NOT NULL UNIQUE,
        cluster_label TEXT NOT NULL,
        ai_summary TEXT NOT NULL,
        category TEXT NOT NULL DEFAULT 'GENERAL',
        complaint_count INTEGER NOT NULL DEFAULT 1,
        ticket_ids_json TEXT NOT NULL DEFAULT '[]',
        primary_fps_id TEXT,
        severity TEXT NOT NULL DEFAULT 'MEDIUM',
        escalation_status TEXT NOT NULL DEFAULT 'PENDING',
        escalated_at TIMESTAMP,
        dso_response TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );
    """)
    db.commit()

    # 1. Fetch all raw tickets (open + under investigation = unresolved)
    cursor.execute("""
    SELECT ticket_id, sender_type, sender_id, target_fps_id, category, subject, message, priority, status, created_at
    FROM feedback
    ORDER BY id DESC LIMIT 500;
    """)
    all_tickets_rows = cursor.fetchall()

    # Generate demo data if table is empty (so the UI always has something meaningful)
    if not all_tickets_rows:
        _seed_demo_complaints(cursor, db)
        cursor.execute("""
        SELECT ticket_id, sender_type, sender_id, target_fps_id, category, subject, message, priority, status, created_at
        FROM feedback ORDER BY id DESC LIMIT 500;
        """)
        all_tickets_rows = cursor.fetchall()

    all_tickets = [dict(r) for r in all_tickets_rows]
    unresolved = [t for t in all_tickets if t.get("status") in ("OPEN", "UNDER_INVESTIGATION")]

    # 2. Cluster unresolved tickets
    clusters_raw = _cluster_complaints(unresolved) if unresolved else []

    # 3. Upsert clusters into complaint_clusters table
    existing_cluster_ids = set()
    cursor.execute("SELECT cluster_id FROM complaint_clusters;")
    for row in cursor.fetchall():
        existing_cluster_ids.add(row["cluster_id"])

    upserted_cluster_ids = []
    for i, cl in enumerate(clusters_raw):
        # Deterministic cluster_id based on category + primary_fps
        cluster_id = f"CLU-{cl['category'][:3]}-{(cl['primary_fps_id'] or 'MULTI')[:8]}-{i+1:03d}"
        ticket_ids_json = json.dumps(cl["ticket_ids"])

        if cluster_id in existing_cluster_ids:
            cursor.execute("""
            UPDATE complaint_clusters 
            SET cluster_label=?, ai_summary=?, complaint_count=?, ticket_ids_json=?,
                primary_fps_id=?, severity=?, updated_at=CURRENT_TIMESTAMP
            WHERE cluster_id=?;
            """, (cl["cluster_label"], cl["ai_summary"], cl["complaint_count"],
                  ticket_ids_json, cl["primary_fps_id"], cl["severity"], cluster_id))
        else:
            cursor.execute("""
            INSERT INTO complaint_clusters 
                (cluster_id, cluster_label, ai_summary, category, complaint_count, 
                 ticket_ids_json, primary_fps_id, severity, escalation_status)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'PENDING');
            """, (cluster_id, cl["cluster_label"], cl["ai_summary"], cl["category"],
                  cl["complaint_count"], ticket_ids_json, cl["primary_fps_id"], cl["severity"]))

        upserted_cluster_ids.append(cluster_id)

    db.commit()

    # 4. Fetch final cluster records
    cursor.execute("""
    SELECT id, cluster_id, cluster_label, ai_summary, category, complaint_count,
           ticket_ids_json, primary_fps_id, severity, escalation_status, escalated_at, 
           dso_response, created_at, updated_at
    FROM complaint_clusters
    ORDER BY complaint_count DESC, severity DESC;
    """)
    cluster_rows = cursor.fetchall()

    clusters_out = []
    for r in cluster_rows:
        clusters_out.append({
            "id": r["id"],
            "cluster_id": r["cluster_id"],
            "cluster_label": r["cluster_label"],
            "ai_summary": r["ai_summary"],
            "category": r["category"],
            "complaint_count": r["complaint_count"],
            "ticket_ids": json.loads(r["ticket_ids_json"] or "[]"),
            "primary_fps_id": r["primary_fps_id"],
            "severity": r["severity"],
            "escalation_status": r["escalation_status"],
            "escalated_at": r["escalated_at"],
            "dso_response": r["dso_response"],
            "created_at": r["created_at"],
            "updated_at": r["updated_at"],
        })

    # 5. Summary stats
    total_complaints = len(all_tickets)
    unresolved_count = len(unresolved)
    escalated_count = sum(1 for c in clusters_out if c["escalation_status"] == "ESCALATED")
    pending_escalation = sum(1 for c in clusters_out if c["escalation_status"] == "PENDING" and c["complaint_count"] >= 2)

    return {
        "summary": {
            "total_complaints": total_complaints,
            "unresolved_complaints": unresolved_count,
            "total_clusters": len(clusters_out),
            "escalated_clusters": escalated_count,
            "pending_escalation": pending_escalation,
        },
        "complaints": all_tickets,
        "clusters": clusters_out,
        "demo_notice": DEMO_NOTICE,
    }


@router.post("/escalation/escalate-cluster")
def escalate_cluster(
    payload: EscalateClusterIn,
    db: sqlite3.Connection = Depends(get_db),
    current_user: dict = Depends(get_current_user)
):
    """Escalate a cluster to DSO as a single unified complaint."""
    cursor = db.cursor()
    cursor.execute("SELECT * FROM complaint_clusters WHERE cluster_id = ?;", (payload.cluster_id,))
    cluster = cursor.fetchone()

    if not cluster:
        raise HTTPException(status_code=404, detail=f"Cluster '{payload.cluster_id}' not found.")

    if cluster["escalation_status"] == "ESCALATED":
        return {
            "status": "already_escalated",
            "cluster_id": payload.cluster_id,
            "message": "This cluster has already been escalated to the DSO.",
        }

    # Update cluster to ESCALATED
    cursor.execute("""
    UPDATE complaint_clusters
    SET escalation_status = 'ESCALATED', escalated_at = CURRENT_TIMESTAMP,
        dso_response = ?, updated_at = CURRENT_TIMESTAMP
    WHERE cluster_id = ?;
    """, (payload.dso_response or "Escalated to DSO for review.", payload.cluster_id))

    # Also mark the constituent feedback tickets as UNDER_INVESTIGATION
    ticket_ids = json.loads(cluster["ticket_ids_json"] or "[]")
    for tid in ticket_ids:
        cursor.execute("""
        UPDATE feedback SET status = 'UNDER_INVESTIGATION'
        WHERE ticket_id = ? AND status = 'OPEN';
        """, (tid,))

    db.commit()

    return {
        "status": "success",
        "cluster_id": payload.cluster_id,
        "complaint_count": cluster["complaint_count"],
        "message": (
            f"Cluster '{payload.cluster_id}' with {cluster['complaint_count']} complaints "
            f"has been escalated to DSO successfully. {len(ticket_ids)} tickets updated to UNDER_INVESTIGATION."
        ),
        "demo_notice": DEMO_NOTICE,
    }


# ---------------------------------------------------------------------------
# Demo seed helper (runs only when feedback table is empty)
# ---------------------------------------------------------------------------

def _seed_demo_complaints(cursor: sqlite3.Cursor, db: sqlite3.Connection) -> None:
    """Insert realistic demo complaint data for demonstration purposes."""
    demo_tickets = [
        # SHORT_WEIGHT cluster
        ("TKT-11001", "BENEFICIARY", "BEN-KA-0001", "FPS-KA-BAG-0001", "SHORT_WEIGHT",
         "Received less than entitled quantity of rice", "I went to FPS shop FPS-KA-BAG-0001 today and received only 18kg of rice against my entitlement of 25kg. The dealer weighed incorrectly."),
        ("TKT-11002", "BENEFICIARY", "BEN-KA-0002", "FPS-KA-BAG-0001", "SHORT_WEIGHT",
         "Less quantity given - short weight rice", "The FPS dealer gave less quantity. I was supposed to get 25kg rice but got only 17kg. The weighing scale seems tampered."),
        ("TKT-11003", "BENEFICIARY", "BEN-KA-0003", "FPS-KA-BAG-0001", "SHORT_WEIGHT",
         "Short weight measurement at FPS shop", "Dealer measured less rice, only 19kg given instead of 25kg entitled quantity. Other beneficiaries also faced short weight issue."),
        ("TKT-11004", "BENEFICIARY", "BEN-KA-0009", "FPS-KA-BAG-0001", "SHORT_WEIGHT",
         "Quantity fraud - less grains given", "FPS dealer FPS-KA-BAG-0001 repeatedly gives less quantity. Today got 16kg rice instead of 25kg. Please check the weighing scale."),

        # SHOP_CLOSED cluster
        ("TKT-11005", "BENEFICIARY", "BEN-KA-0004", "FPS-KA-BAG-0023", "SHOP_CLOSED",
         "FPS shop closed during working hours", "The fair price shop was closed when I visited at 10am. Dealer was absent. I had taken leave from work to collect my ration."),
        ("TKT-11006", "BENEFICIARY", "BEN-KA-0005", "FPS-KA-BAG-0023", "SHOP_CLOSED",
         "Shop not open on scheduled day", "FPS shop FPS-KA-BAG-0023 was not open today. I went three times and it was closed. No notice was given."),
        ("TKT-11007", "BENEFICIARY", "BEN-KA-0006", "FPS-KA-BAG-0023", "SHOP_CLOSED",
         "Dealer absent for multiple days", "The dealer has been absent for 4 days. Shop is locked and we cannot collect our monthly ration."),

        # RATION_QUALITY cluster
        ("TKT-11008", "BENEFICIARY", "BEN-KA-0007", "FPS-KA-BAG-0045", "RATION_QUALITY",
         "Poor quality rice with insects", "The rice received from FPS has insects in it. Very poor quality, cannot eat. This is a health hazard."),
        ("TKT-11009", "BENEFICIARY", "BEN-KA-0008", "FPS-KA-BAG-0045", "RATION_QUALITY",
         "Stale and rotten wheat received", "Wheat received was stale and had bad smell. The quality is very poor and cannot be consumed by family."),
        ("TKT-11010", "BENEFICIARY", "BEN-KA-0010", "FPS-KA-BAG-0045", "RATION_QUALITY",
         "Damaged ration quality - mold found", "Found mold on the wheat received from FPS dealer. The grain quality is unacceptable and damaged."),

        # DELIVERY_DELAY cluster
        ("TKT-11011", "BENEFICIARY", "BEN-KA-0011", "FPS-KA-BAG-0067", "DELIVERY_DELAY",
         "Ration not delivered this month", "It has been 20 days since the monthly cycle started but our FPS has not received stock. We are unable to collect our entitled ration."),
        ("TKT-11012", "BENEFICIARY", "BEN-KA-0012", "FPS-KA-BAG-0067", "DELIVERY_DELAY",
         "Delayed delivery - no stock at FPS", "Stock has not arrived at FPS shop for this month. The dealer says delivery is delayed. We need our ration urgently."),

        # OVERCHARGING cluster
        ("TKT-11013", "BENEFICIARY", "BEN-KA-0013", "FPS-KA-BAG-0089", "OVERCHARGING",
         "FPS dealer demanding extra money", "The dealer demanded ₹50 extra per bag as bribe over and above the official price. This is extortion."),
        ("TKT-11014", "BENEFICIARY", "BEN-KA-0014", "FPS-KA-BAG-0089", "OVERCHARGING",
         "Overcharging - extra payment demanded", "Dealer demanded more money than the official price. Charged ₹80 extra. Refused to give ration without additional payment."),
    ]

    for ticket in demo_tickets:
        try:
            cursor.execute("""
            INSERT INTO feedback (ticket_id, sender_type, sender_id, target_fps_id, category, subject, message, priority, status)
            VALUES (?, ?, ?, ?, ?, ?, ?, 'NORMAL', 'OPEN');
            """, ticket)
        except Exception:
            pass  # Skip duplicates

    db.commit()
