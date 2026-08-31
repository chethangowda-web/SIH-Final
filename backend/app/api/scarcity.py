"""FastAPI Router for AI-Assisted Stockout Risk Prediction & Scarcity Allocation Engine.

Endpoints:
1. GET  /api/admin/scarcity/depot-balance        - Real-time depot supply vs demand deficit check
2. POST /api/admin/scarcity/predict-risk         - Scikit-learn Logistic Regression stockout risk inference
3. POST /api/admin/scarcity/simulate-fair-share  - Deterministic three-tier fair-share allocation simulation
4. POST /api/admin/scarcity/approve-plan         - Authorized DSO/Officer review and operational dispatch freeze
5. GET  /api/admin/scarcity/audit-trail/{plan_id}- Complete immutable audit trail of plan decisions

Governance Rules:
- ML model ONLY calculates continuous stockout risk probabilities and categorical tiers.
- Scarcity allocations are 100% deterministic, rule-based, and statutory-floor protected.
- Simulation endpoints are strictly READ-ONLY regarding operational forecast and dispatch tables.
- Officer authorization is mandatory before any scarcity plan mutates live recommended dispatch.
- forecast.predicted_quantity_kg is NEVER modified by scarcity approval.
"""

import sqlite3
from typing import List, Dict, Any, Optional
from fastapi import APIRouter, Depends, HTTPException, Query, status
from pydantic import BaseModel, Field
from app.core.database import get_db
from app.core.config import settings
from app.core.logging_config import get_logger
from app.models.schemas import DEMO_NOTICE
from app.services.stockout_risk_engine import stockout_risk_engine
from app.services.scarcity_engine import scarcity_allocation_engine
from app.services.workflow_manager import workflow_manager, WorkflowState
from app.core.auth import check_admin_access

logger = get_logger("scarcity")

router = APIRouter(prefix="/admin/scarcity", tags=["Scarcity Allocation Engine"], dependencies=[Depends(check_admin_access)])

VALID_COMMODITIES = ["Rice", "Wheat"]
AUTHORIZED_ROLES = ["DISTRICT_SUPPLY_OFFICER", "DEPOT_MANAGER", "ADMIN", "SUPER_ADMIN"]


# ------------------------------------------------------------------------------
# Request & Response Models
# ------------------------------------------------------------------------------

class DepotBalanceResponse(BaseModel):
    cycle_id: str
    depot_id: str
    depot_name: str
    commodity: str
    aggregate_demand_kg: float
    available_depot_stock_kg: float
    deficit_kg: float
    deficit_percentage: float
    is_scarcity_condition: bool
    scarcity_condition: str
    statutory_floor_total_kg: float
    statutory_floor_status: str
    is_statutory_floor_satisfied: bool
    governance_alert: Optional[str] = None
    demo_notice: str = DEMO_NOTICE


class StockoutRiskRequest(BaseModel):
    cycle_id: str = Field(settings.CURRENT_CYCLE, description="Planning cycle ID")
    commodity: str = Field("Rice", description="Commodity ('Rice' or 'Wheat')")
    fps_id: Optional[str] = Field(None, description="Single target FPS ID")
    fps_ids: Optional[List[str]] = Field(None, description="List of target FPS IDs")
    proposed_allocation_kg: Optional[float] = Field(None, ge=0.0, description="Proposed allocation quantity")


class SingleRiskPredictionItem(BaseModel):
    fps_id: str
    cycle_id: str
    commodity: str
    requested_dispatch_kg: float
    proposed_allocation_kg: float
    stockout_probability: float
    risk_tier: str
    guidance_note: str
    days_of_stock_coverage: float
    deficit_ratio: float
    model_name: str
    features: Dict[str, float]
    governance_notice: str


class RiskPredictionResponse(BaseModel):
    status: str
    cycle_id: str
    commodity: str
    predictions_count: int
    predictions: List[SingleRiskPredictionItem]
    model_metadata: Dict[str, Any]
    demo_notice: str = DEMO_NOTICE


class SimulateScarcityRequest(BaseModel):
    cycle_id: str = Field(settings.CURRENT_CYCLE, description="Planning cycle ID")
    depot_id: str = Field("DEPOT-01", description="Source Depot ID")
    commodity: str = Field("Rice", description="Commodity ('Rice' or 'Wheat')")
    available_depot_stock_kg: float = Field(..., ge=0.0, description="Available depot stock (kg)")
    allocation_strategy: Optional[str] = Field("FAIR_SHARE_RISK_WEIGHTED", description="Strategy: FAIR_SHARE_RISK_WEIGHTED, PRO_RATA, or STATUTORY_FLOOR_PRIORITY")
    persist_candidate: Optional[bool] = Field(False, description="Whether to stage as PENDING_OFFICER_REVIEW in DB")
    actor_name: Optional[str] = Field("District Supply Officer (Demo Admin)", description="Authorizing officer")
    notes: Optional[str] = Field("Simulated candidate plan generated for officer review", description="Remarks")


class ScarcityAllocationItemResponse(BaseModel):
    fps_id: str
    fps_name: str
    baseline_recommended_kg: float
    statutory_floor_kg: float
    reconciled_allocation_kg: float
    statutory_floor_satisfied: bool
    floor_deficit_kg: float
    cut_kg: float
    cut_percentage: float
    predicted_stockout_risk: float
    risk_tier: str
    mitigation_action: str


class ScarcityPlanSummary(BaseModel):
    plan_id: Optional[str] = None
    cycle_id: str
    depot_id: str
    depot_name: str
    commodity: str
    aggregate_demand_kg: float
    available_depot_stock_kg: float
    deficit_kg: float
    deficit_percentage: float
    is_scarcity_condition: bool
    scarcity_condition: str
    statutory_floor_status: str
    is_statutory_floor_satisfied: bool
    governance_alert: Optional[str] = None
    allocation_strategy: str
    total_statutory_floors_kg: float
    total_reconciled_allocation_kg: float
    unallocated_depot_slack_kg: float
    average_cut_percentage: float
    allocated_fps_count: int
    approval_status: str = "PENDING_OFFICER_REVIEW"
    risk_summary: Dict[str, int]
    allocated_items: List[ScarcityAllocationItemResponse]
    demo_notice: str = DEMO_NOTICE


class ApprovePlanRequest(BaseModel):
    plan_id: str = Field(..., description="Candidate plan ID to approve")
    officer_name: str = Field(..., min_length=2, description="Authorized signing officer name")
    officer_role: str = Field(..., description="Officer role: DISTRICT_SUPPLY_OFFICER, DEPOT_MANAGER, or ADMIN")
    approval_notes: Optional[str] = Field("Approved for operational dispatch execution", description="Official approval remarks")


class ApprovePlanResponse(BaseModel):
    status: str
    plan_id: str
    approval_status: str
    approved_by: str
    approved_at: str
    depot_id: str
    commodity: str
    total_reconciled_allocation_kg: float
    allocated_fps_count: int
    message: str
    demo_notice: str = DEMO_NOTICE


# ------------------------------------------------------------------------------
# Endpoints
# ------------------------------------------------------------------------------

@router.get("/depot-balance", response_model=DepotBalanceResponse)
def get_depot_balance(
    cycle_id: str = Query(settings.CURRENT_CYCLE, description="Target planning cycle"),
    depot_id: str = Query("DEPOT-01", description="Depot identifier"),
    commodity: str = Query("Rice", description="Foodgrain commodity ('Rice' or 'Wheat')"),
    db: sqlite3.Connection = Depends(get_db)
):
    """
    Read-only check of current depot available grain inventory vs aggregate downstream demand.
    Identifies scarcity conditions and statutory floor feasibility without mutating state.
    """
    if commodity not in VALID_COMMODITIES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid commodity '{commodity}'. Supported commodities: {VALID_COMMODITIES}"
        )

    cursor = db.cursor()
    cursor.execute("SELECT depot_id, name, district FROM depots WHERE depot_id = ?;", (depot_id,))
    depot_row = cursor.fetchone()
    if not depot_row:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Depot '{depot_id}' not found in master records."
        )

    depot_name = depot_row["name"]

    # 1. Fetch available depot stock from depot_stock_cycles if seeded, else default capacity
    cursor.execute("""
    SELECT available_for_dispatch_kg FROM depot_stock_cycles
    WHERE depot_id = ? AND cycle_id = ? AND commodity = ?;
    """, (depot_id, cycle_id, commodity))
    cycle_stock_row = cursor.fetchone()
    available_stock_kg = float(cycle_stock_row[0]) if cycle_stock_row else 25000.0

    # 2. Compute aggregate downstream recommended demand for FPS on this corridor
    cursor.execute("""
    SELECT COALESCE(SUM(f.recommended_dispatch_kg), 0.0)
    FROM fps p
    JOIN routes r ON p.fps_id = r.destination_fps_id AND r.source_depot_id = ?
    JOIN forecast f ON p.fps_id = f.fps_id AND f.commodity = ? AND f.cycle_id = ?;
    """, (depot_id, commodity, cycle_id))
    agg_row = cursor.fetchone()
    aggregate_demand_kg = float(agg_row[0]) if agg_row and agg_row[0] > 0 else 0.0

    if aggregate_demand_kg == 0.0:
        # Fallback to all district FPS if route join yields zero
        cursor.execute("""
        SELECT COALESCE(SUM(recommended_dispatch_kg), 0.0) FROM forecast
        WHERE commodity = ? AND cycle_id = ?;
        """, (commodity, cycle_id))
        fallback_agg = cursor.fetchone()
        aggregate_demand_kg = float(fallback_agg[0]) if fallback_agg else 5930.8

    # 3. Compute total statutory entitlement floors via canonical engine method
    cursor.execute("SELECT fps_id FROM fps ORDER BY id ASC;")
    fps_ids = [r[0] for r in cursor.fetchall()]
    total_statutory_floors_kg = 0.0
    for fid in fps_ids:
        floor_info = scarcity_allocation_engine.calculate_statutory_floor(cursor, fid, commodity)
        total_statutory_floors_kg += floor_info["statutory_floor_kg"]

    total_statutory_floors_kg = round(total_statutory_floors_kg, 1)

    deficit_kg = max(0.0, round(aggregate_demand_kg - available_stock_kg, 1))
    is_scarcity = deficit_kg > 0.0
    deficit_pct = round((deficit_kg / max(1.0, aggregate_demand_kg)) * 100.0, 1)

    if not is_scarcity:
        scarcity_cond = "NO_SCARCITY"
        floor_status = "STATUTORY_FLOORS_SATISFIED"
        is_floor_sat = True
        gov_alert = None
    elif available_stock_kg >= total_statutory_floors_kg:
        scarcity_cond = "FEASIBLE_SCARCITY"
        floor_status = "STATUTORY_FLOORS_SATISFIED"
        is_floor_sat = True
        gov_alert = None
    else:
        scarcity_cond = "CRITICAL_DEFICIT"
        floor_status = "STATUTORY_FLOORS_UNSATISFIABLE"
        is_floor_sat = False
        floor_deficit = round(total_statutory_floors_kg - available_stock_kg, 1)
        gov_alert = f"STATUTORY_FLOORS_UNSATISFIABLE: Available depot stock ({available_stock_kg:.1f} kg) is insufficient to meet mandatory statutory floors ({total_statutory_floors_kg:.1f} kg). Deficit = {floor_deficit:.1f} kg."

    return DepotBalanceResponse(
        cycle_id=cycle_id,
        depot_id=depot_id,
        depot_name=depot_name,
        commodity=commodity,
        aggregate_demand_kg=round(aggregate_demand_kg, 1),
        available_depot_stock_kg=round(available_stock_kg, 1),
        deficit_kg=deficit_kg,
        deficit_percentage=deficit_pct,
        is_scarcity_condition=is_scarcity,
        scarcity_condition=scarcity_cond,
        statutory_floor_total_kg=round(total_statutory_floors_kg, 1),
        statutory_floor_status=floor_status,
        is_statutory_floor_satisfied=is_floor_sat,
        governance_alert=gov_alert,
        demo_notice=DEMO_NOTICE
    )


@router.post("/predict-risk", response_model=RiskPredictionResponse)
def predict_stockout_risk_api(
    req: StockoutRiskRequest,
    db: sqlite3.Connection = Depends(get_db)
):
    """
    Run ML stockout risk inference using scikit-learn LogisticRegression.
    Features are strictly extracted server-side from SQLite tables to prevent client bypass.
    Read-only regarding operational dispatch.
    """
    if req.commodity not in VALID_COMMODITIES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid commodity '{req.commodity}'. Supported: {VALID_COMMODITIES}"
        )

    cursor = db.cursor()
    target_fps_ids: List[str] = []

    if req.fps_id:
        target_fps_ids = [req.fps_id]
    elif req.fps_ids:
        target_fps_ids = req.fps_ids
    else:
        cursor.execute("SELECT fps_id FROM fps ORDER BY id ASC;")
        target_fps_ids = [r[0] for r in cursor.fetchall()]

    predictions: List[SingleRiskPredictionItem] = []
    for fid in target_fps_ids:
        # Determine candidate allocation to simulate
        if req.proposed_allocation_kg is not None:
            alloc_kg = req.proposed_allocation_kg
        else:
            # Default to statutory floor if no proposed allocation supplied
            floor_info = scarcity_allocation_engine.calculate_statutory_floor(cursor, fid, req.commodity)
            alloc_kg = floor_info["statutory_floor_kg"]

        pred = stockout_risk_engine.predict_stockout_risk(
            cursor=cursor,
            fps_id=fid,
            commodity=req.commodity,
            proposed_allocation_kg=alloc_kg,
            cycle_id=req.cycle_id
        )

        predictions.append(SingleRiskPredictionItem(
            fps_id=pred["fps_id"],
            cycle_id=pred["cycle_id"],
            commodity=pred["commodity"],
            requested_dispatch_kg=pred["requested_dispatch_kg"],
            proposed_allocation_kg=pred["proposed_allocation_kg"],
            stockout_probability=pred["stockout_probability"],
            risk_tier=pred["risk_tier"],
            guidance_note=pred["guidance_note"],
            days_of_stock_coverage=pred["days_of_stock_coverage"],
            deficit_ratio=pred["deficit_ratio"],
            model_name=pred["model_name"],
            features=pred["features"],
            governance_notice=DEMO_NOTICE
        ))

    return RiskPredictionResponse(
        status="success",
        cycle_id=req.cycle_id,
        commodity=req.commodity,
        predictions_count=len(predictions),
        predictions=predictions,
        model_metadata=stockout_risk_engine.get_model_metadata(),
        demo_notice=DEMO_NOTICE
    )


@router.post("/simulate-fair-share", response_model=ScarcityPlanSummary)
def simulate_fair_share_allocation_api(
    req: SimulateScarcityRequest,
    db: sqlite3.Connection = Depends(get_db)
):
    """
    Generate a deterministic three-tier fair-share scarcity allocation plan.
    Strictly read-only by default. When persist_candidate=True, creates a record
    with status PENDING_OFFICER_REVIEW without altering live dispatch records.
    """
    if req.commodity not in VALID_COMMODITIES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid commodity '{req.commodity}'. Supported: {VALID_COMMODITIES}"
        )

    if req.allocation_strategy not in scarcity_allocation_engine.supported_strategies:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid strategy '{req.allocation_strategy}'. Supported: {scarcity_allocation_engine.supported_strategies}"
        )

    # 1. Run deterministic three-tier simulation
    sim = scarcity_allocation_engine.simulate_scarcity_plan(
        db=db,
        depot_id=req.depot_id,
        commodity=req.commodity,
        available_depot_stock_kg=req.available_depot_stock_kg,
        cycle_id=req.cycle_id,
        allocation_strategy=req.allocation_strategy
    )

    plan_id = None
    if req.persist_candidate:
        persist_res = scarcity_allocation_engine.persist_scarcity_plan(
            db=db,
            plan_simulation=sim,
            actor_name=req.actor_name or "District Supply Officer (Demo Admin)",
            notes=req.notes or "Simulated fair-share allocation generated under depot scarcity"
        )
        plan_id = persist_res["plan_id"]

    # Record in Unified Governance Event Trail (Marked explicitly as simulation)
    from app.services.governance_trail import governance_trail
    governance_trail.record_event(
        db=db,
        event_type="SCARCITY_SIMULATION",
        action="SIMULATE_FAIR_SHARE_ALLOCATION",
        entity_type="SCARCITY_PLAN",
        entity_id=plan_id or f"SIM-{sim['depot_id']}-{sim['commodity']}",
        actor_name=req.actor_name or "District Supply Officer (Demo Admin)",
        actor_role="DISTRICT_SUPPLY_OFFICER",
        cycle_id=sim["cycle_id"],
        after_state={
            "deficit_kg": sim["deficit_kg"],
            "available_stock_kg": sim["available_depot_stock_kg"],
            "total_reconciled_allocation_kg": sim["total_reconciled_allocation_kg"],
            "is_statutory_floor_satisfied": sim["is_statutory_floor_satisfied"]
        },
        notes=req.notes or f"Fair-share scarcity simulation computed for depot {sim['depot_id']} ({sim['commodity']})",
        integrity_metadata={"depot_id": sim["depot_id"], "commodity": sim["commodity"]},
        is_success=True,
        is_simulation=True
    )

    return ScarcityPlanSummary(
        plan_id=plan_id,
        cycle_id=sim["cycle_id"],
        depot_id=sim["depot_id"],
        depot_name=sim["depot_name"],
        commodity=sim["commodity"],
        aggregate_demand_kg=sim["aggregate_demand_kg"],
        available_depot_stock_kg=sim["available_depot_stock_kg"],
        deficit_kg=sim["deficit_kg"],
        deficit_percentage=sim["deficit_percentage"],
        is_scarcity_condition=sim["is_scarcity_condition"],
        scarcity_condition=sim["scarcity_condition"],
        statutory_floor_status=sim["statutory_floor_status"],
        is_statutory_floor_satisfied=sim["is_statutory_floor_satisfied"],
        governance_alert=sim["governance_alert"],
        allocation_strategy=sim["allocation_strategy"],
        total_statutory_floors_kg=sim["total_statutory_floors_kg"],
        total_reconciled_allocation_kg=sim["total_reconciled_allocation_kg"],
        unallocated_depot_slack_kg=sim["unallocated_depot_slack_kg"],
        average_cut_percentage=sim["average_cut_percentage"],
        allocated_fps_count=sim["allocated_fps_count"],
        approval_status="PENDING_OFFICER_REVIEW",
        risk_summary=sim["risk_summary"],
        allocated_items=[ScarcityAllocationItemResponse(**it) for it in sim["allocated_items"]],
        demo_notice=DEMO_NOTICE
    )


@router.post("/approve-plan", response_model=ApprovePlanResponse)
def approve_scarcity_plan_api(
    req: ApprovePlanRequest,
    db: sqlite3.Connection = Depends(get_db)
):
    """
    Authorizes and executes a staged fair-share scarcity allocation plan.
    Mandates officer authentication role (DISTRICT_SUPPLY_OFFICER / DEPOT_MANAGER / ADMIN).
    Updates recommended_dispatch_kg in forecast table and marks plan OFFICER_APPROVED.
    CRITICAL: forecast.predicted_quantity_kg (demand forecast) remains unmutated.
    """
    # 1. Authorization Guard
    if req.officer_role.upper() not in AUTHORIZED_ROLES:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=f"Unauthorized: Role '{req.officer_role}' is not authorized to approve scarcity allocation plans. Required: {AUTHORIZED_ROLES}"
        )

    # 2. Retrieve Persisted Plan
    plan = scarcity_allocation_engine.get_scarcity_plan(db, req.plan_id)
    if not plan:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Scarcity allocation plan '{req.plan_id}' not found."
        )

    # 3. Status Guard: Prevent duplicate or invalid approvals
    if plan["approval_status"] == "OFFICER_APPROVED":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Plan '{req.plan_id}' has already been approved by '{plan['approved_by']}' on {plan['approved_at']}."
        )
    if plan["approval_status"] == "REJECTED":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Plan '{req.plan_id}' has been rejected and cannot be approved."
        )

    # 4. Supply & Ceiling Integrity Validations
    total_reconciled = sum(float(item["reconciled_allocation_kg"]) for item in plan["allocated_items"])
    if total_reconciled > plan["available_stock_kg"] + 0.1:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Validation failed: Total plan allocation ({total_reconciled:.1f} kg) exceeds available depot stock ({plan['available_stock_kg']:.1f} kg)."
        )

    cursor = db.cursor()

    # 5. Execute Operational Dispatch Reconciled Update
    # Update forecast.recommended_dispatch_kg and dispatch.quantity_kg without touching predicted_quantity_kg
    for item in plan["allocated_items"]:
        fid = item["fps_id"]
        comm = item["commodity"]
        reconciled_kg = float(item["reconciled_allocation_kg"])
        cycle_id = plan["cycle_id"]

        # Update forecast recommended dispatch
        cursor.execute("""
        UPDATE forecast
        SET recommended_dispatch_kg = ?, status = 'SCARCITY_RECONCILED'
        WHERE fps_id = ? AND commodity = ? AND cycle_id = ?;
        """, (reconciled_kg, fid, comm, cycle_id))

        # Update live dispatch load if record exists
        cursor.execute("""
        UPDATE dispatch
        SET quantity_kg = ?, status = 'SCARCITY_RECONCILED'
        WHERE fps_id = ? AND commodity = ? AND cycle_id = ?;
        """, (reconciled_kg, fid, comm, cycle_id))

    # 6. Update Plan Header Record to OFFICER_APPROVED
    # CONCURRENCY GUARD: WHERE approval_status = 'PENDING_OFFICER_REVIEW' ensures this is
    # an atomic compare-and-set.  If a concurrent request approved the plan between our
    # status-check read (step 3) and this write, rowcount == 0 and we surface a 409.
    cursor.execute("""
    UPDATE scarcity_allocation_plans
    SET approval_status = 'OFFICER_APPROVED',
        approved_by = ?,
        approval_notes = ?,
        approved_at = CURRENT_TIMESTAMP
    WHERE plan_id = ? AND approval_status = 'PENDING_OFFICER_REVIEW';
    """, (
        f"{req.officer_name} ({req.officer_role.upper()})",
        req.approval_notes or "Officially approved for operational dispatch execution",
        req.plan_id
    ))

    if cursor.rowcount == 0:
        # A concurrent request beat us to the approval — surface a clear conflict
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"Plan '{req.plan_id}' was already approved by a concurrent request. "
                   "Re-fetch the plan to see the current approval state."
        )

    # Transition operational state machine to ALLOCATED
    workflow_manager.transition_state(
        db,
        cycle_id=plan["cycle_id"],
        new_state=WorkflowState.ALLOCATED,
        actor_name=req.officer_name,
        actor_role=req.officer_role,
        reason=req.approval_notes or "Scarcity allocation plan approved.",
        force=True
    )

    db.commit()

    logger.info(
        "Scarcity plan approved: plan_id='%s', cycle='%s', depot='%s', commodity='%s', deficit_kg=%.1f, officer='%s', role='%s'",
        req.plan_id, plan["cycle_id"], plan["depot_id"], plan["commodity"], plan["deficit_kg"], req.officer_name, req.officer_role
    )

    # Fetch updated approved_at timestamp
    cursor.execute("SELECT approved_at, approved_by FROM scarcity_allocation_plans WHERE plan_id = ?;", (req.plan_id,))
    app_row = cursor.fetchone()
    approved_at_str = str(app_row[0]) if app_row else "JUST_NOW"
    approved_by_str = str(app_row[1]) if app_row else req.officer_name

    # Record in Unified Governance Event Trail (Operational Commitment)
    from app.services.governance_trail import governance_trail
    governance_trail.record_event(
        db=db,
        event_type="SCARCITY_APPROVAL",
        action="APPROVE_SCARCITY_PLAN",
        entity_type="SCARCITY_PLAN",
        entity_id=req.plan_id,
        actor_name=approved_by_str,
        actor_role=req.officer_role.upper(),
        cycle_id=plan["cycle_id"],
        before_state={"status": "PENDING_OFFICER_REVIEW"},
        after_state={"status": "OFFICER_APPROVED", "total_reconciled_allocation_kg": round(total_reconciled, 1)},
        notes=req.approval_notes or "Officially approved for operational dispatch execution",
        integrity_metadata={"depot_id": plan["depot_id"], "commodity": plan["commodity"]},
        is_success=True,
        is_simulation=False
    )

    return ApprovePlanResponse(
        status="success",
        plan_id=req.plan_id,
        approval_status="OFFICER_APPROVED",
        approved_by=approved_by_str,
        approved_at=approved_at_str,
        depot_id=plan["depot_id"],
        commodity=plan["commodity"],
        total_reconciled_allocation_kg=round(total_reconciled, 1),
        allocated_fps_count=len(plan["allocated_items"]),
        message=f"Plan '{req.plan_id}' successfully approved by {approved_by_str}. Operational dispatch recommendations updated.",
        demo_notice=DEMO_NOTICE
    )


@router.get("/audit-trail/{plan_id}")
def get_scarcity_plan_audit_trail(
    plan_id: str,
    db: sqlite3.Connection = Depends(get_db)
):
    """
    Retrieve comprehensive immutable audit trail for a specific fair-share scarcity plan.
    Includes plan header, officer remarks, timestamps, and itemized allocation metrics.
    """
    plan = scarcity_allocation_engine.get_scarcity_plan(db, plan_id)
    if not plan:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Audit trail record for plan '{plan_id}' not found."
        )

    return {
        "status": "success",
        "plan_id": plan["plan_id"],
        "cycle_id": plan["cycle_id"],
        "depot_id": plan["depot_id"],
        "commodity": plan["commodity"],
        "aggregate_demand_kg": plan["aggregate_demand_kg"],
        "available_stock_kg": plan["available_stock_kg"],
        "deficit_kg": plan["deficit_kg"],
        "allocation_strategy": plan["allocation_strategy"],
        "approval_status": plan["approval_status"],
        "approved_by": plan["approved_by"],
        "approval_notes": plan["approval_notes"],
        "created_at": plan["created_at"],
        "approved_at": plan["approved_at"],
        "allocated_fps_count": plan["allocated_fps_count"],
        "allocated_items": plan["allocated_items"],
        "demo_notice": DEMO_NOTICE
    }
