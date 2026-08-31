"""Beneficiary Forward-Looking Intent Declaration API Router."""
import sqlite3
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, Query, status
from app.core.database import get_db
from app.models.schemas import (
    IntentCreateIn,
    IntentOut,
    BeneficiaryEntitlementSummaryOut,
    CitizenDeliveryConfirmIn,
    TransportFeeBreakdownOut,
    DeliveryDisputeOut,
    ChoiceWindowStatusOut,
    DEMO_NOTICE
)

from app.core.auth import get_current_user, verify_owner

router = APIRouter(tags=["Beneficiary Intent"], dependencies=[Depends(get_current_user)])

@router.post("/intent", response_model=IntentOut, status_code=status.HTTP_201_CREATED)
def submit_intent(
    payload: IntentCreateIn,
    db: sqlite3.Connection = Depends(get_db),
    current_user: dict = Depends(get_current_user)
):
    """
    Submit or update a forward-looking voluntary intent declaration for an upcoming PDS cycle.
    Statutory quantity is calculated authoritatively by government entitlement records;
    citizen input represents service selection (FPS Collection vs Home Delivery) and location preference.
    """
    verify_owner(current_user, payload.beneficiary_id)
    cursor = db.cursor()

    # 0. Validate Choice Window Status for target cycle
    from app.services.forecast_engine import forecast_engine
    workflow_status = forecast_engine.get_persisted_workflow_status(db, payload.cycle_id.strip())
    if workflow_status not in ["PLANNING_OPEN", "DRAFT_GENERATED", "DRAFT"]:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Choice window for cycle '{payload.cycle_id.strip()}' is closed and demand is locked for dispatch planning (workflow stage: {workflow_status}). Preferences can no longer be modified."
        )

    # 1. Validate commodity
    if payload.commodity not in ["Rice", "Wheat"]:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
            detail=f"Invalid commodity '{payload.commodity}'. Must be either 'Rice' or 'Wheat'."
        )

    # 1.1 Validate declared quantity if provided
    if payload.declared_quantity_kg is not None and payload.declared_quantity_kg <= 0:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
            detail="Declared quantity must be greater than 0 kg."
        )

    # 2. Validate beneficiary exists
    cursor.execute("SELECT pseudonymous_beneficiary_id, registered_fps_id FROM beneficiaries WHERE pseudonymous_beneficiary_id = ?;", (payload.beneficiary_id.strip(),))
    ben_row = cursor.fetchone()
    if not ben_row:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Beneficiary '{payload.beneficiary_id}' not found."
        )

    home_fps_id = ben_row["registered_fps_id"]

    # 3. Validate intended FPS exists
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

    # 4. Authoritative Server-Side Entitlement & Remaining Balance Calculation
    from app.services.ai_request_advisor import ai_request_advisor
    import json
    entitlement = ai_request_advisor.get_beneficiary_entitlement(
        db, payload.beneficiary_id.strip(), payload.commodity, payload.cycle_id.strip()
    )
    statutory_quota = float(entitlement["statutory_entitlement_commodity_kg"])
    remaining_balance = float(entitlement["remaining_eligible_commodity_kg"])

    # Over-entitlement guard
    if payload.declared_quantity_kg is not None and payload.declared_quantity_kg > statutory_quota * 1.5:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
            detail=f"Citizen declared quantity ({payload.declared_quantity_kg:.1f} kg) exceeds statutory monthly entitlement ceiling of {statutory_quota:.1f} kg for card type {entitlement['card_type']} ({entitlement['family_members_count']} members). Ration quantity is authoritatively determined by government statutory quotas."
        )

    # Authoritative quantity assignment
    authoritative_qty = statutory_quota
    if payload.declared_quantity_kg is not None and 0 < payload.declared_quantity_kg <= statutory_quota:
        authoritative_qty = payload.declared_quantity_kg

    # 5. Transportation Fee Calculation for Home Delivery
    delivery_mode = payload.delivery_mode.upper() if payload.delivery_mode else "FPS_COLLECTION"
    dist_km = float(payload.delivery_distance_km or 0.0)
    fee_breakdown = ai_request_advisor.calculate_transport_fee(
        db, delivery_mode, dist_km, entitlement["card_type"]
    )
    transport_fee = fee_breakdown["total_transport_fee_inr"]

    # 6. Run AI Decision-Support Assessment
    ai_eval = ai_request_advisor.evaluate_request(
        db=db,
        beneficiary_id=payload.beneficiary_id.strip(),
        intended_fps_id=payload.intended_fps_id.strip(),
        commodity=payload.commodity,
        requested_quantity_kg=authoritative_qty,
        cycle_id=payload.cycle_id.strip(),
        delivery_mode=delivery_mode,
        delivery_distance_km=dist_km
    )
    ai_data = ai_eval["ai_assessment"]

    # 7. Insert or Update (UPSERT) Intent
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
        authoritative_qty,
        confidence
    ))

    # 8. Insert or Update (UPSERT) Citizen Request in Review Queue
    req_suffix = payload.beneficiary_id.strip().split("-")[-1]
    request_id = f"REQ-{payload.cycle_id.strip()}-{req_suffix}-{payload.commodity[:1]}"
    req_type = "PORTABILITY_PREFERENCE" if is_portability else "MONTHLY_PREFERENCE_SIGNAL"

    cursor.execute("""
    INSERT INTO citizen_requests (
        request_id, beneficiary_id, card_type, family_members_count,
        statutory_entitlement_rice_kg, statutory_entitlement_wheat_kg,
        cycle_id, registered_fps_id, intended_fps_id, commodity,
        requested_quantity_kg, authorized_quantity_kg, request_type,
        status, ai_recommendation, ai_recommended_qty_kg,
        ai_recommended_fps_id, ai_risk_level, ai_confidence,
        ai_factors_json, delivery_mode, delivery_address,
        delivery_distance_km, transport_fee_inr, delivery_status
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0.0, ?, 'PENDING_OFFICER_REVIEW', ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'SERVICE_REQUESTED')
    ON CONFLICT(request_id) DO UPDATE SET
        intended_fps_id = excluded.intended_fps_id,
        requested_quantity_kg = excluded.requested_quantity_kg,
        request_type = excluded.request_type,
        status = 'PENDING_OFFICER_REVIEW',
        ai_recommendation = excluded.ai_recommendation,
        ai_recommended_qty_kg = excluded.ai_recommended_qty_kg,
        ai_recommended_fps_id = excluded.ai_recommended_fps_id,
        ai_risk_level = excluded.ai_risk_level,
        ai_confidence = excluded.ai_confidence,
        ai_factors_json = excluded.ai_factors_json,
        delivery_mode = excluded.delivery_mode,
        delivery_address = excluded.delivery_address,
        delivery_distance_km = excluded.delivery_distance_km,
        transport_fee_inr = excluded.transport_fee_inr,
        delivery_status = 'SERVICE_REQUESTED',
        updated_at = CURRENT_TIMESTAMP;
    """, (
        request_id,
        payload.beneficiary_id.strip(),
        entitlement["card_type"],
        entitlement["family_members_count"],
        entitlement["statutory_entitlement_rice_kg"],
        entitlement["statutory_entitlement_wheat_kg"],
        payload.cycle_id.strip(),
        home_fps_id,
        payload.intended_fps_id.strip(),
        payload.commodity,
        authoritative_qty,
        req_type,
        ai_data["recommendation"],
        ai_data["recommended_quantity_kg"],
        ai_data["recommended_fps_id"],
        ai_data["risk_level"],
        ai_data["confidence"],
        json.dumps(ai_data["factors"]),
        delivery_mode,
        payload.delivery_address,
        dist_km,
        transport_fee
    ))

    # Log initial submission in unified immutable audit trail
    from app.services.governance_trail import governance_trail
    governance_trail.record_event(
        db=db,
        event_type="CITIZEN_INTENT_SUBMITTED",
        action="SERVICE_PREFERENCE_SUBMITTED",
        entity_type="CITIZEN_REQUEST",
        entity_id=request_id,
        actor_name=payload.beneficiary_id.strip(),
        actor_role="CITIZEN_BENEFICIARY",
        cycle_id=payload.cycle_id.strip(),
        notes=f"Service requested: {delivery_mode} ({authoritative_qty:.1f} kg {payload.commodity}). Target: {intended_fps_name}. Transport Fee: INR {transport_fee:.2f}",
        integrity_metadata={"request_id": request_id, "commodity": payload.commodity, "delivery_mode": delivery_mode},
        is_success=True,
        is_simulation=False
    )

    db.commit()

    cursor.execute("SELECT id, created_at, status FROM intent WHERE beneficiary_id = ? AND cycle_id = ? AND commodity = ?;", (payload.beneficiary_id.strip(), payload.cycle_id.strip(), payload.commodity))
    row = cursor.fetchone()

    return IntentOut(
        id=row["id"],
        beneficiary_id=payload.beneficiary_id.strip(),
        cycle_id=payload.cycle_id.strip(),
        intended_fps_id=payload.intended_fps_id.strip(),
        intended_fps_name=intended_fps_name,
        home_fps_id=home_fps_id,
        is_portability_intent=is_portability,
        commodity=payload.commodity,
        declared_quantity_kg=authoritative_qty,
        confidence=confidence,
        delivery_mode=delivery_mode,
        delivery_address=payload.delivery_address,
        delivery_distance_km=dist_km,
        transport_fee_inr=transport_fee,
        delivery_status="SERVICE_REQUESTED",
        statutory_entitlement_kg=statutory_quota,
        remaining_balance_kg=remaining_balance,
        created_at=row["created_at"],
        status=row["status"],
        demo_notice=DEMO_NOTICE
    )


@router.get("/beneficiary/{beneficiary_id}/entitlement-summary", response_model=BeneficiaryEntitlementSummaryOut)
def get_beneficiary_entitlement_summary(
    beneficiary_id: str,
    cycle_id: str = Query("2026-09", description="Planning cycle ID"),
    db: sqlite3.Connection = Depends(get_db),
    current_user: dict = Depends(get_current_user)
):
    """
    Retrieve authoritative government entitlement records, household metadata,
    previously lifted ration balance, and transport fee policy.
    """
    verify_owner(current_user, beneficiary_id)
    from app.services.ai_request_advisor import ai_request_advisor
    ent = ai_request_advisor.get_beneficiary_entitlement(db, beneficiary_id.strip(), "Rice", cycle_id.strip())
    transport = ai_request_advisor.calculate_transport_fee(db, "FPS_COLLECTION", 0.0, ent["card_type"])

    total_remaining = ent["remaining_eligible_rice_kg"] + ent["remaining_eligible_wheat_kg"]

    return BeneficiaryEntitlementSummaryOut(
        beneficiary_id=ent["beneficiary_id"],
        name=ent["name"],
        card_type=ent["card_type"],
        family_members_count=ent["family_members_count"],
        card_label=ent["card_label"],
        cycle_id=cycle_id.strip(),
        registered_fps_id=ent["registered_fps_id"],
        registered_fps_name=ent["registered_fps_name"],
        statutory_entitlement_rice_kg=ent["statutory_entitlement_rice_kg"],
        statutory_entitlement_wheat_kg=ent["statutory_entitlement_wheat_kg"],
        consumed_rice_kg=ent["consumed_rice_kg"],
        consumed_wheat_kg=ent["consumed_wheat_kg"],
        remaining_eligible_rice_kg=ent["remaining_eligible_rice_kg"],
        remaining_eligible_wheat_kg=ent["remaining_eligible_wheat_kg"],
        total_eligible_balance_kg=total_remaining,
        transport_policy=TransportFeeBreakdownOut(
            delivery_mode="FPS_COLLECTION",
            delivery_distance_km=0.0,
            base_transport_fee_inr=20.0,
            distance_surcharge_inr=0.0,
            total_transport_fee_inr=0.0,
            commodity_cost_inr=0.0,
            total_payable_inr=0.0,
            statutory_notice="Payment applies strictly to door-to-door transportation and does not alter statutory entitlement."
        ),
        demo_notice=DEMO_NOTICE
    )


@router.get("/beneficiary/{beneficiary_id}/delivery-records")
def get_beneficiary_delivery_records(
    beneficiary_id: str,
    cycle_id: str = Query("2026-09", description="Planning cycle ID"),
    db: sqlite3.Connection = Depends(get_db),
    current_user: dict = Depends(get_current_user)
):
    """Retrieve citizen preference requests, live delivery lifecycle status, and confirmation records."""
    verify_owner(current_user, beneficiary_id)
    cursor = db.cursor()
    cursor.execute("""
    SELECT r.*, f1.name as registered_fps_name, f2.name as intended_fps_name
    FROM citizen_requests r
    LEFT JOIN fps f1 ON r.registered_fps_id = f1.fps_id
    LEFT JOIN fps f2 ON r.intended_fps_id = f2.fps_id
    WHERE r.beneficiary_id = ? AND r.cycle_id = ?
    ORDER BY r.created_at DESC;
    """, (beneficiary_id.strip(), cycle_id.strip()))
    rows = cursor.fetchall()

    return {
        "beneficiary_id": beneficiary_id.strip(),
        "cycle_id": cycle_id.strip(),
        "total_requests": len(rows),
        "items": [dict(r) for r in rows],
        "demo_notice": DEMO_NOTICE
    }


@router.post("/beneficiary/{beneficiary_id}/confirm-delivery")
def confirm_delivery_api(
    beneficiary_id: str,
    req: CitizenDeliveryConfirmIn,
    db: sqlite3.Connection = Depends(get_db),
    current_user: dict = Depends(get_current_user)
):
    """
    Citizen Delivery Confirmation & Dispute Workflow.
    Allows citizen to confirm complete receipt of allocated ration (DELIVERY_CONFIRMED)
    or flag a shortfall / dispute (DELIVERY_DISPUTE), which automatically creates an officer review case.
    """
    verify_owner(current_user, beneficiary_id)
    cursor = db.cursor()
    cursor.execute("SELECT * FROM citizen_requests WHERE request_id = ? AND beneficiary_id = ?;", (req.request_id, beneficiary_id.strip()))
    row = cursor.fetchone()
    if not row:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Citizen request '{req.request_id}' not found for beneficiary '{beneficiary_id}'."
        )

    conf_status = req.confirmation_status.upper()

    if conf_status == "DELIVERY_CONFIRMED":
        cursor.execute("""
        UPDATE citizen_requests SET
            delivery_status = 'DELIVERY_CONFIRMED',
            received_rice_kg = ?,
            received_wheat_kg = ?,
            citizen_confirmed_at = CURRENT_TIMESTAMP,
            updated_at = CURRENT_TIMESTAMP
        WHERE request_id = ?;
        """, (
            req.received_rice_kg or row["authorized_quantity_kg"],
            req.received_wheat_kg or 0.0,
            req.request_id
        ))

        from app.services.governance_trail import governance_trail
        governance_trail.record_event(
            db=db,
            event_type="DELIVERY_CONFIRMED",
            action="DELIVERY_CONFIRMED_BY_CITIZEN",
            entity_type="CITIZEN_REQUEST",
            entity_id=req.request_id,
            actor_name=beneficiary_id.strip(),
            actor_role="CITIZEN_BENEFICIARY",
            cycle_id=row["cycle_id"],
            notes=f"Citizen confirmed complete delivery receipt of {row['commodity']} ({row['authorized_quantity_kg']} kg).",
            is_success=True,
            is_simulation=False
        )
        db.commit()

        return {
            "status": "DELIVERY_CONFIRMED",
            "request_id": req.request_id,
            "message": "Delivery confirmed successfully by citizen. Quota fulfillment recorded in audit trail.",
            "demo_notice": DEMO_NOTICE
        }

    elif conf_status == "DELIVERY_DISPUTE":
        allocated_kg = float(row["authorized_quantity_kg"] or row["requested_quantity_kg"])
        received_kg = float(req.received_rice_kg or req.received_wheat_kg or 0.0)
        shortfall_kg = max(0.0, allocated_kg - received_kg)
        dispute_id = f"DSP-{row['cycle_id']}-{row['id']}"

        cursor.execute("""
        UPDATE citizen_requests SET
            delivery_status = 'DELIVERY_DISPUTE',
            received_rice_kg = ?,
            received_wheat_kg = ?,
            dispute_reason = ?,
            citizen_confirmed_at = CURRENT_TIMESTAMP,
            updated_at = CURRENT_TIMESTAMP
        WHERE request_id = ?;
        """, (
            req.received_rice_kg or 0.0,
            req.received_wheat_kg or 0.0,
            req.dispute_notes or "Discrepancy reported by citizen",
            req.request_id
        ))

        cursor.execute("""
        INSERT INTO delivery_disputes (
            dispute_id, request_id, beneficiary_id, cycle_id, commodity,
            allocated_quantity_kg, received_quantity_kg, shortfall_kg,
            dispute_notes, status
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 'PENDING_OFFICER_REVIEW')
        ON CONFLICT(dispute_id) DO UPDATE SET
            received_quantity_kg = excluded.received_quantity_kg,
            shortfall_kg = excluded.shortfall_kg,
            dispute_notes = excluded.dispute_notes,
            status = 'PENDING_OFFICER_REVIEW';
        """, (
            dispute_id,
            req.request_id,
            beneficiary_id.strip(),
            row["cycle_id"],
            row["commodity"],
            allocated_kg,
            received_kg,
            shortfall_kg,
            req.dispute_notes or "Discrepancy reported by citizen"
        ))

        from app.services.governance_trail import governance_trail
        governance_trail.record_event(
            db=db,
            event_type="DELIVERY_DISPUTE_RAISED",
            action="DELIVERY_DISPUTE_RAISED",
            entity_type="DELIVERY_DISPUTE",
            entity_id=dispute_id,
            actor_name=beneficiary_id.strip(),
            actor_role="CITIZEN_BENEFICIARY",
            cycle_id=row["cycle_id"],
            notes=f"Dispute raised: Allocated {allocated_kg:.1f} kg, Received {received_kg:.1f} kg (Shortfall {shortfall_kg:.1f} kg). Notes: {req.dispute_notes}",
            integrity_metadata={"allocated_kg": allocated_kg, "received_kg": received_kg, "shortfall_kg": shortfall_kg},
            is_success=True,
            is_simulation=False
        )
        db.commit()

        return {
            "status": "DELIVERY_DISPUTE",
            "dispute_id": dispute_id,
            "request_id": req.request_id,
            "shortfall_kg": shortfall_kg,
            "message": "Delivery dispute submitted. Case forwarded to District Supply Officer queue for forensic reconciliation.",
            "demo_notice": DEMO_NOTICE
        }

    else:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid confirmation status '{req.confirmation_status}'. Supported: DELIVERY_CONFIRMED, DELIVERY_DISPUTE"
        )


@router.get("/intents", response_model=List[IntentOut])
def list_intents(
    cycle_id: Optional[str] = Query("2026-09", description="Filter by cycle ID"),
    fps_id: Optional[str] = Query(None, description="Filter by intended FPS ID"),
    beneficiary_id: Optional[str] = Query(None, description="Filter by beneficiary ID"),
    limit: int = Query(100, ge=1, le=1000),
    offset: int = Query(0, ge=0),
    db: sqlite3.Connection = Depends(get_db),
    current_user: dict = Depends(get_current_user)
):
    """Retrieve list of declared intent signals with optional filters."""
    if current_user["role"] == "BENEFICIARY":
        if not beneficiary_id or beneficiary_id.strip() != current_user["beneficiary_id"]:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Access Denied: BENEFICIARY role is restricted to filtering by own beneficiary_id."
            )
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


@router.get("/choice-window/status", response_model=ChoiceWindowStatusOut)
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
