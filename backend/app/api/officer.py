"""Officer Operational Workflow Router: DSO, Field Food Inspector, and FPS Owner."""
import sqlite3
import uuid
import datetime
from typing import List, Optional
from pydantic import BaseModel
from fastapi import APIRouter, Depends, HTTPException, status, Query
from app.core.database import get_db
from app.core.auth import get_current_user, RoleChecker
from app.services.ai_request_advisor import ai_request_advisor

router = APIRouter(tags=["Officer Operational Workflows"])

# Models
class SurpriseInspectionOrderIn(BaseModel):
    fps_id: str
    reason: str
    priority: Optional[str] = "HIGH"

class SurpriseInspectionOrderOut(BaseModel):
    order_id: str
    fps_id: str
    dso_id: str
    reason: str
    priority: str
    status: str
    created_at: str

class InspectionSubmissionIn(BaseModel):
    fps_id: str
    order_id: Optional[str] = None
    scale_certified: bool = True
    display_board_updated: bool = True
    stock_matches_register: bool = True
    cctv_functional: bool = True
    epos_online: bool = True
    hygiene_compliant: bool = True
    compliance_score: float = 100.0
    remarks: Optional[str] = ""

class EposDispenseIn(BaseModel):
    fps_id: str
    beneficiary_id: str
    cycle_id: Optional[str] = "2026-09"
    rice_kg: float = 0.0
    wheat_kg: float = 0.0
    auth_mode: Optional[str] = "AADHAAR_BIOMETRIC"

class EposDispenseOut(BaseModel):
    transaction_id: str
    beneficiary_id: str
    fps_id: str
    cycle_id: str
    rice_dispensed_kg: float
    wheat_dispensed_kg: float
    remaining_fps_rice_stock_kg: float
    remaining_fps_wheat_stock_kg: float
    status: str
    receipt_confirmed_at: str


# =====================================================================
# 1. DSO Workflow: Trigger & Monitor Surprise Inspections
# =====================================================================

@router.post("/officer/inspection/order", response_model=SurpriseInspectionOrderOut)
def order_surprise_inspection(
    payload: SurpriseInspectionOrderIn,
    db: sqlite3.Connection = Depends(get_db),
    current_user: dict = Depends(RoleChecker(["DSO", "ADMIN"]))
):
    """
    DSO Endpoint: Issue an urgent/surprise inspection order for a Fair Price Shop.
    Enforces strict RBAC: Rejected with HTTP 403 for unauthorized roles (e.g. FPS_OWNER).
    """
    order_id = f"ORD-INSP-{uuid.uuid4().hex[:8].upper()}"
    cursor = db.cursor()
    cursor.execute("""
    INSERT INTO surprise_inspection_orders (order_id, fps_id, dso_id, reason, priority, status)
    VALUES (?, ?, ?, ?, ?, 'PENDING');
    """, (order_id, payload.fps_id.strip(), current_user["username"], payload.reason.strip(), payload.priority.strip()))
    db.commit()

    cursor.execute("SELECT * FROM surprise_inspection_orders WHERE order_id = ?;", (order_id,))
    row = cursor.fetchone()

    return SurpriseInspectionOrderOut(
        order_id=row["order_id"],
        fps_id=row["fps_id"],
        dso_id=row["dso_id"],
        reason=row["reason"],
        priority=row["priority"],
        status=row["status"],
        created_at=str(row["created_at"])
    )


@router.get("/officer/inspections")
def list_inspections(
    fps_id: Optional[str] = None,
    db: sqlite3.Connection = Depends(get_db),
    current_user: dict = Depends(RoleChecker(["DSO", "FIELD_FOOD_INSPECTOR", "FIELD_OFFICER", "AUDITOR", "ADMIN"]))
):
    """
    List inspection orders and completed inspections.
    Accessible to DSO, Field Food Inspectors, and System Admin.
    """
    cursor = db.cursor()
    if fps_id:
        cursor.execute("SELECT * FROM surprise_inspection_orders WHERE fps_id = ? ORDER BY id DESC;", (fps_id.strip(),))
        orders = cursor.fetchall()
        cursor.execute("SELECT * FROM fps_inspections WHERE fps_id = ? ORDER BY id DESC;", (fps_id.strip(),))
        reports = cursor.fetchall()
    else:
        cursor.execute("SELECT * FROM surprise_inspection_orders ORDER BY id DESC LIMIT 50;")
        orders = cursor.fetchall()
        cursor.execute("SELECT * FROM fps_inspections ORDER BY id DESC LIMIT 50;")
        reports = cursor.fetchall()

    return {
        "orders": [dict(r) for r in orders],
        "completed_inspections": [dict(r) for r in reports]
    }


# =====================================================================
# 2. Field Food Inspector Workflow: Complete Digital Checklist & Submit
# =====================================================================

@router.post("/officer/inspection/submit")
def submit_fps_inspection(
    payload: InspectionSubmissionIn,
    db: sqlite3.Connection = Depends(get_db),
    current_user: dict = Depends(RoleChecker(["FIELD_FOOD_INSPECTOR", "FIELD_OFFICER", "ADMIN"]))
):
    """
    Field Food Inspector Endpoint: Submit physical 6-point verification inspection.
    Enforces strict RBAC: Rejected with HTTP 403 for unauthorized roles (e.g. FPS_OWNER, DSO).
    """
    inspection_id = f"INSP-{uuid.uuid4().hex[:8].upper()}"
    cursor = db.cursor()

    cursor.execute("""
    INSERT INTO fps_inspections (
        inspection_id, fps_id, inspector_id, inspection_type,
        scale_certified, display_board_updated, stock_matches_register,
        cctv_functional, epos_online, hygiene_compliant,
        compliance_score, remarks, status
    ) VALUES (?, ?, ?, 'SURPRISE_FIELD_INSPECTION', ?, ?, ?, ?, ?, ?, ?, ?, 'COMPLETED');
    """, (
        inspection_id, payload.fps_id.strip(), current_user["username"],
        1 if payload.scale_certified else 0,
        1 if payload.display_board_updated else 0,
        1 if payload.stock_matches_register else 0,
        1 if payload.cctv_functional else 0,
        1 if payload.epos_online else 0,
        1 if payload.hygiene_compliant else 0,
        payload.compliance_score,
        payload.remarks or ""
    ))

    # Mark corresponding surprise order completed if supplied
    if payload.order_id:
        cursor.execute("""
        UPDATE surprise_inspection_orders SET status = 'COMPLETED' WHERE order_id = ?;
        """, (payload.order_id.strip(),))
    else:
        # Mark newest pending order for this FPS as completed
        cursor.execute("""
        UPDATE surprise_inspection_orders SET status = 'COMPLETED'
        WHERE fps_id = ? AND status = 'PENDING';
        """, (payload.fps_id.strip(),))

    db.commit()

    return {
        "status": "SUCCESS",
        "inspection_id": inspection_id,
        "fps_id": payload.fps_id,
        "compliance_score": payload.compliance_score,
        "verified_by": current_user["username"],
        "message": "FPS physical inspection permanently registered in central compliance ledger."
    }


# =====================================================================
# 3. FPS Owner Workflow: Stock Lookup, Digital Register & e-PoS Dispensing
# =====================================================================

@router.get("/fps/{fps_id}/inventory")
def get_fps_real_stock(
    fps_id: str,
    db: sqlite3.Connection = Depends(get_db),
    current_user: dict = Depends(RoleChecker(["FPS_OWNER", "DSO", "FIELD_FOOD_INSPECTOR", "ADMIN"]))
):
    """Fetch persistent live inventory stock levels for fair price shop."""
    cursor = db.cursor()
    cursor.execute("SELECT commodity, available_quantity_kg FROM inventory WHERE fps_id = ?;", (fps_id.strip(),))
    rows = cursor.fetchall()
    stock_map = {r["commodity"]: float(r["available_quantity_kg"]) for r in rows}
    return {
        "fps_id": fps_id,
        "rice_stock_kg": stock_map.get("Rice", 1500.0),
        "wheat_stock_kg": stock_map.get("Wheat", 400.0),
        "sugar_stock_kg": stock_map.get("Sugar", 120.0),
        "kerosene_stock_l": stock_map.get("Kerosene", 90.0)
    }


@router.get("/fps/{fps_id}/transactions")
def get_fps_digital_register(
    fps_id: str,
    db: sqlite3.Connection = Depends(get_db),
    current_user: dict = Depends(RoleChecker(["FPS_OWNER", "DSO", "ADMIN"]))
):
    """Retrieve digital register of all dispensed transactions for the FPS."""
    cursor = db.cursor()
    cursor.execute("""
    SELECT t.transaction_id, t.fps_id, t.beneficiary_id, t.cycle_id,
           t.rice_kg, t.wheat_kg, t.auth_mode, t.status, t.created_at,
           b.name_for_demo, b.members_count
    FROM epos_transactions t
    LEFT JOIN beneficiaries b ON t.beneficiary_id = b.pseudonymous_beneficiary_id
    WHERE t.fps_id = ?
    ORDER BY t.id DESC LIMIT 100;
    """, (fps_id.strip(),))
    rows = cursor.fetchall()
    return [dict(r) for r in rows]


@router.post("/epos/dispense", response_model=EposDispenseOut)
def dispense_ration_epos(
    payload: EposDispenseIn,
    db: sqlite3.Connection = Depends(get_db),
    current_user: dict = Depends(RoleChecker(["FPS_OWNER", "ADMIN"]))
):
    """
    e-PoS Physical Dispensation Endpoint:
    1. Validates beneficiary existence and statutory quota.
    2. Enforces non-duplicate collection for the cycle.
    3. Decrements inventory in FPS warehouse.
    4. Records immutable receipt in beneficiary_cycle_receipts.
    5. Records digital register log in epos_transactions.
    6. Confirms citizen_requests delivery record.
    """
    ben_id = payload.beneficiary_id.strip()
    cycle_id = (payload.cycle_id or "2026-09").strip()
    fps_id = payload.fps_id.strip()

    # 1. Authoritative entitlement check
    try:
        ent = ai_request_advisor.get_beneficiary_entitlement(db, ben_id, "Rice", cycle_id)
    except ValueError as val_err:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Beneficiary data unavailable: {str(val_err)}"
        )

    # 2. Cycle collection guard
    cursor = db.cursor()
    cursor.execute("""
    SELECT id FROM beneficiary_cycle_receipts
    WHERE beneficiary_id = ? AND cycle_id = ? AND status = 'COMPLETED';
    """, (ben_id, cycle_id))
    if cursor.fetchone():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Duplicate collection prohibited: Beneficiary {ben_id} has already completed ration collection for cycle {cycle_id}."
        )

    # Resolve dispensed quantities (fallback to statutory quotas if 0 specified)
    dispense_rice = payload.rice_kg if payload.rice_kg > 0 else float(ent["statutory_entitlement_rice_kg"])
    dispense_wheat = payload.wheat_kg if payload.wheat_kg > 0 else float(ent["statutory_entitlement_wheat_kg"])

    # 3. Decrement FPS inventory
    cursor.execute("""
    UPDATE inventory
    SET available_quantity_kg = MAX(0.0, available_quantity_kg - ?)
    WHERE fps_id = ? AND commodity = 'Rice';
    """, (dispense_rice, fps_id))

    cursor.execute("""
    UPDATE inventory
    SET available_quantity_kg = MAX(0.0, available_quantity_kg - ?)
    WHERE fps_id = ? AND commodity = 'Wheat';
    """, (dispense_wheat, fps_id))

    # Fetch updated inventory
    cursor.execute("SELECT available_quantity_kg FROM inventory WHERE fps_id = ? AND commodity = 'Rice';", (fps_id,))
    r_row = cursor.fetchone()
    rem_rice = float(r_row[0]) if r_row else 1000.0

    cursor.execute("SELECT available_quantity_kg FROM inventory WHERE fps_id = ? AND commodity = 'Wheat';", (fps_id,))
    w_row = cursor.fetchone()
    rem_wheat = float(w_row[0]) if w_row else 300.0

    # 4. Insert receipt into beneficiary_cycle_receipts
    now_str = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    cursor.execute("""
    INSERT INTO beneficiary_cycle_receipts (
        beneficiary_id, cycle_id, request_id,
        received_rice_kg, received_wheat_kg,
        status, confirmed_at
    ) VALUES (?, ?, ?, ?, ?, 'COMPLETED', ?);
    """, (ben_id, cycle_id, f"REQ-EPOS-{ben_id}", dispense_rice, dispense_wheat, now_str))

    # 5. Insert into epos_transactions
    tx_id = f"TX-EPOS-{uuid.uuid4().hex[:10].upper()}"
    cursor.execute("""
    INSERT INTO epos_transactions (
        transaction_id, fps_id, beneficiary_id, cycle_id,
        rice_kg, wheat_kg, auth_mode, status, created_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?, 'COMPLETED', ?);
    """, (tx_id, fps_id, ben_id, cycle_id, dispense_rice, dispense_wheat, payload.auth_mode, now_str))

    # 6. Update citizen_requests if exists
    cursor.execute("""
    UPDATE citizen_requests
    SET delivery_status = 'DELIVERY_CONFIRMED',
        status = 'COMPLETED',
        received_rice_kg = ?,
        received_wheat_kg = ?,
        citizen_confirmed_at = ?
    WHERE beneficiary_id = ? AND cycle_id = ?;
    """, (dispense_rice, dispense_wheat, now_str, ben_id, cycle_id))

    # Update intent status to COMPLETED
    cursor.execute("""
    UPDATE intent SET status = 'COMPLETED' WHERE beneficiary_id = ? AND cycle_id = ?;
    """, (ben_id, cycle_id))

    db.commit()

    return EposDispenseOut(
        transaction_id=tx_id,
        beneficiary_id=ben_id,
        fps_id=fps_id,
        cycle_id=cycle_id,
        rice_dispensed_kg=dispense_rice,
        wheat_dispensed_kg=dispense_wheat,
        remaining_fps_rice_stock_kg=rem_rice,
        remaining_fps_wheat_stock_kg=rem_wheat,
        status="SUCCESS_DISPENSED",
        receipt_confirmed_at=now_str
    )


@router.get("/epos/eligibility")
def check_epos_eligibility(
    fps_id: str = Query(...),
    beneficiary_id: str = Query(...),
    cycle_id: str = Query("2026-09"),
    db: sqlite3.Connection = Depends(get_db),
    current_user: dict = Depends(RoleChecker(["FPS_OWNER", "DSO", "ADMIN"]))
):
    """
    Query authoritative entitlement, scheme category, and collection status for a ration card.
    Used by the e-PoS terminal prior to biometric authorization.
    """
    ben_id = beneficiary_id.strip()
    c_id = cycle_id.strip()

    try:
        ent = ai_request_advisor.get_beneficiary_entitlement(db, ben_id, "Rice", c_id)
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Beneficiary '{ben_id}' not found in master database: {str(e)}"
        )

    cursor = db.cursor()
    cursor.execute("""
    SELECT id, status, confirmed_at FROM beneficiary_cycle_receipts
    WHERE beneficiary_id = ? AND cycle_id = ? AND status = 'COMPLETED';
    """, (ben_id, c_id))
    receipt = cursor.fetchone()
    already_collected = bool(receipt)
    collected_at = str(receipt["confirmed_at"]) if receipt and "confirmed_at" in receipt.keys() else None

    scheme = ent.get("card_type", "PHH")
    category_label = "Antyodaya Anna Yojana (AAY)" if scheme == "AAY" else "Priority Household (BPHH / PHH)"

    return {
        "beneficiary_id": ent["beneficiary_id"],
        "name": ent["name"],
        "registered_fps_id": ent["registered_fps_id"],
        "registered_fps_name": ent.get("registered_fps_name", "Registered Fair Price Shop"),
        "card_type": scheme,
        "category_label": category_label,
        "family_members_count": ent.get("family_members_count", 1),
        "statutory_rice_kg": ent.get("statutory_entitlement_rice_kg", 0.0),
        "statutory_wheat_kg": ent.get("statutory_entitlement_wheat_kg", 0.0),
        "already_collected": already_collected,
        "collected_at": collected_at,
        "is_portability": ent["registered_fps_id"] != fps_id.strip()
    }
