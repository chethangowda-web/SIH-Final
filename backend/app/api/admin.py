"""District Admin Analytics & Supply Chain Management API Router."""
import sqlite3
from datetime import datetime
from typing import List, Dict, Any, Optional
from fastapi import APIRouter, Depends, HTTPException, Query, status
from pydantic import BaseModel, Field
from app.core.database import get_db, run_database_integrity_check, backup_database
from app.core.config import settings
from app.models.schemas import (
    DEMO_NOTICE,
    CitizenRequestOut,
    CitizenRequestAuthorizeIn,
    CitizenRequestQueueResponse,
    DeliveryDisputeOut,
    DeliveryDisputeResolveIn,
    SupplyRoutesResponse,
    DistrictForecastSummaryResponse,
    DistrictDispatchSummaryResponse
)
from app.services.forecast_engine import forecast_engine, COMMODITIES
from app.services.dispatch_engine import dispatch_engine
from app.services.evaluation_engine import evaluation_engine
from app.services.constraint_engine import constraint_engine
from app.services.optimization_engine import optimization_engine
from app.services.gatepass_engine import gatepass_engine
from app.services.notification_engine import notification_engine
from app.services.dispatch_decision_engine import dispatch_decision_engine
from app.services.manifest_engine import manifest_engine
from app.services.demo_scenario_engine import demo_scenario_engine
from app.services.causal_trace_engine import (
    causal_trace_engine,
    CausalTraceResponse,
    CausalTraceRun
)
from app.services.workflow_manager import workflow_manager, WorkflowState
from app.core.auth import check_admin_access

router = APIRouter(tags=["District Admin Dashboard"], dependencies=[Depends(check_admin_access)])

# ----------------- Admin Schemas ----------------- #
class AdminFpsRow(BaseModel):
    fps_id: str
    name: str
    district: str
    latitude: float
    longitude: float
    capacity_kg: float
    registered_beneficiaries: int
    historical_demand_kg: float
    declared_intent_kg: float
    intent_shift_kg: float
    intent_shift_pct: float
    inventory_kg: float
    inventory_utilization_pct: float
    forecast_kg: float
    recommended_dispatch_kg: float = 0.0
    confidence_score: float = 0.95
    risk_level: str  # 'HIGH', 'MEDIUM', 'LOW'
    risk_reason: str
    status: str      # 'Planning', 'Draft', 'Locked'

class DistrictHistoricalTrend(BaseModel):
    cycle_id: str
    rice_kg: float
    wheat_kg: float
    total_kg: float

class AdminDashboardSummary(BaseModel):
    district: str
    active_cycle: str
    total_fps: int
    active_intents_count: int
    total_declared_intent_kg: float
    total_historical_demand_kg: float = 0.0
    total_forecast_demand_kg: float = 0.0
    total_recommended_dispatch_kg: float = 0.0
    average_confidence: float = 0.95
    forecast_generated_count: int
    high_risk_fps_count: int
    medium_risk_fps_count: int
    low_risk_fps_count: int
    exception_cases_count: int
    total_inventory_kg: float
    total_capacity_kg: float
    average_capacity_utilization_pct: float
    risk_distribution: Dict[str, int]
    historical_cycles_trend: List[DistrictHistoricalTrend]
    top_intent_shift_fps: List[Dict[str, Any]]
    fps_list: List[AdminFpsRow]
    workflow_status: str  # 'PLANNING_OPEN', 'DRAFT_GENERATED', 'FORECAST_LOCKED'
    planning_cycle_state: Optional[Dict[str, Any]] = None
    demo_notice: str = DEMO_NOTICE

class AdminFpsDetailAnalytics(BaseModel):
    fps_id: str
    name: str
    district: str
    latitude: float
    longitude: float
    capacity_kg: float
    registered_beneficiaries: int
    historical_demand_kg: float
    declared_intent_kg: float
    intent_shift_kg: float
    inventory_kg: float
    inventory_utilization_pct: float
    forecast_kg: float
    recommended_dispatch_kg: float = 0.0
    confidence_score: float = 0.95
    risk_level: str
    risk_reason: str
    status: str
    formula_explanation: Optional[str] = None
    forecast_breakdown: Optional[Dict[str, Any]] = None
    historical_records: List[Dict[str, Any]]
    rice_trend_kg: List[Dict[str, Any]]
    wheat_trend_kg: List[Dict[str, Any]]
    intent_home_count: int
    intent_portability_count: int
    intent_commodities: Dict[str, Any]
    inventory_items: List[Dict[str, Any]]
    demo_notice: str = DEMO_NOTICE


@router.get("/admin/dashboard", response_model=AdminDashboardSummary)
def get_admin_dashboard(db: sqlite3.Connection = Depends(get_db)):
    """
    Retrieve real-time District Admin Executive KPI metrics, 
    FPS matrix with historical demand, intent shifts, inventory, forecast, and risk levels.
    """
    cursor = db.cursor()
    active_cycle = settings.CURRENT_CYCLE
    district_name = "Bengaluru Urban PDS Pilot"

    # 1. Fetch persistent workflow status from SQLite
    workflow_status = forecast_engine.get_persisted_workflow_status(db, active_cycle)
    is_locked = (workflow_status == "FORECAST_LOCKED")
    is_generated = (workflow_status in ["DRAFT_GENERATED", "FORECAST_LOCKED"])

    # 2. Fetch all FPS
    cursor.execute("""
    SELECT id, fps_id, name, district, latitude, longitude, capacity_kg, status
    FROM fps
    ORDER BY id ASC;
    """)
    fps_rows = cursor.fetchall()
    total_fps = len(fps_rows)

    # 3. Overall counts & metrics
    cursor.execute("SELECT COUNT(DISTINCT beneficiary_id) FROM intent WHERE cycle_id = ?;", (active_cycle,))
    active_intents_count = cursor.fetchone()[0]

    cursor.execute("SELECT COALESCE(SUM(declared_quantity_kg), 0.0) FROM intent WHERE cycle_id = ?;", (active_cycle,))
    total_declared_intent_kg = cursor.fetchone()[0]

    cursor.execute("SELECT COALESCE(SUM(available_quantity_kg), 0.0) FROM inventory;")
    total_inventory_kg = cursor.fetchone()[0]

    cursor.execute("SELECT COALESCE(SUM(capacity_kg), 0.0) FROM fps;")
    total_capacity_kg = cursor.fetchone()[0]

    avg_utilization = round((total_inventory_kg / total_capacity_kg) * 100.0, 1) if total_capacity_kg > 0 else 0.0

    # 4. Check if persisted forecast records exist for active cycle
    cursor.execute("""
    SELECT 
        fps_id, commodity, historical_component, intent_component, inventory_component,
        predicted_quantity_kg, recommended_dispatch_kg, confidence, risk_level, status
    FROM forecast
    WHERE cycle_id = ?;
    """, (active_cycle,))
    persisted_forecast_rows = cursor.fetchall()
    
    # Map persisted forecasts by fps_id -> list of records
    persisted_by_fps: Dict[str, List[sqlite3.Row]] = {}
    for r in persisted_forecast_rows:
        persisted_by_fps.setdefault(r["fps_id"], []).append(r)

    # 5. Build per-FPS rows
    admin_fps_list: List[AdminFpsRow] = []
    high_risk_count = 0
    med_risk_count = 0
    low_risk_count = 0
    exception_count = 0

    total_historical_demand = 0.0
    total_forecast_demand = 0.0
    total_recommended_dispatch = 0.0
    total_conf_score = 0.0

    for fps in fps_rows:
        fid = fps["fps_id"]
        cap = float(fps["capacity_kg"])

        # Registered beneficiaries count
        cursor.execute("SELECT COUNT(*) FROM beneficiaries WHERE registered_fps_id = ?;", (fid,))
        reg_count = cursor.fetchone()[0]

        # Inventory
        cursor.execute("SELECT COALESCE(SUM(available_quantity_kg), 0.0) FROM inventory WHERE fps_id = ?;", (fid,))
        inv_avail = round(cursor.fetchone()[0], 1)
        inv_util_pct = round((inv_avail / cap) * 100.0, 1) if cap > 0 else 0.0

        # Declared intent total for upcoming cycle (Rice + Wheat)
        cursor.execute("""
        SELECT COALESCE(SUM(declared_quantity_kg), 0.0)
        FROM intent
        WHERE intended_fps_id = ? AND cycle_id = ?;
        """, (fid, active_cycle))
        intent_total = round(cursor.fetchone()[0], 1)

        baseline_registered_intent = reg_count * 30.0
        intent_shift = round(intent_total - baseline_registered_intent, 1)
        intent_shift_pct = round((intent_shift / baseline_registered_intent) * 100.0, 1) if baseline_registered_intent > 0 else 0.0

        if fid in persisted_by_fps and len(persisted_by_fps[fid]) > 0:
            # Use persisted forecasts from SQLite
            f_rows = persisted_by_fps[fid]
            hist_avg = round(sum(r["historical_component"] for r in f_rows), 1)
            forecast_val = round(sum(r["predicted_quantity_kg"] for r in f_rows), 1)
            dispatch_val = round(sum(r["recommended_dispatch_kg"] for r in f_rows), 1)
            conf_val = round(sum(r["confidence"] for r in f_rows) / len(f_rows), 2)
            risk_level = f_rows[0]["risk_level"]
            row_status = "Locked" if is_locked else "Draft"
        else:
            # Dynamically calculate draft preview via forecast_engine
            rice_calc = forecast_engine.calculate_fps_commodity_forecast(cursor, fid, "Rice", active_cycle)
            wheat_calc = forecast_engine.calculate_fps_commodity_forecast(cursor, fid, "Wheat", active_cycle)
            
            hist_avg = round(rice_calc["historical_demand_kg"] + wheat_calc["historical_demand_kg"], 1)
            forecast_val = round(rice_calc["forecast_demand_kg"] + wheat_calc["forecast_demand_kg"], 1)
            dispatch_val = round(rice_calc["recommended_dispatch_kg"] + wheat_calc["recommended_dispatch_kg"], 1)
            
            avg_conf = (rice_calc["intent_confidence"] + wheat_calc["intent_confidence"]) / 2.0
            risk_level, _, conf_val = forecast_engine.evaluate_fps_risk_and_confidence(
                cursor, fid, intent_total, inv_avail, cap, reg_count, avg_conf
            )
            row_status = "Planning"

        # Risk reasons
        risk_reasons = []
        if intent_shift > 300 or intent_shift_pct > 15.0:
            risk_reasons.append(f"High Migrant Inflow (+{intent_shift:.0f} kg)")
            exception_count += 1
        elif intent_shift > 100:
            risk_reasons.append(f"Moderate Inflow (+{intent_shift:.0f} kg)")

        if inv_util_pct < 15.0:
            risk_reasons.append(f"Stock Depletion ({inv_util_pct:.0f}% Capacity)")
            if risk_level != "HIGH":
                exception_count += 1
        elif inv_util_pct < 25.0 and risk_level != "HIGH":
            risk_reasons.append(f"Low Buffer ({inv_util_pct:.0f}%)")
        elif inv_util_pct > 80.0:
            risk_reasons.append(f"Surplus Stock ({inv_util_pct:.0f}%)")

        if not risk_reasons:
            risk_reasons.append("Balanced Demand & Inventory Profile")

        if risk_level == "HIGH":
            high_risk_count += 1
        elif risk_level == "MEDIUM":
            med_risk_count += 1
        else:
            low_risk_count += 1

        total_historical_demand += hist_avg
        total_forecast_demand += forecast_val
        total_recommended_dispatch += dispatch_val
        total_conf_score += conf_val

        admin_fps_list.append(
            AdminFpsRow(
                fps_id=fid,
                name=fps["name"],
                district=fps["district"],
                latitude=fps["latitude"],
                longitude=fps["longitude"],
                capacity_kg=cap,
                registered_beneficiaries=reg_count,
                historical_demand_kg=hist_avg,
                declared_intent_kg=intent_total,
                intent_shift_kg=intent_shift,
                intent_shift_pct=intent_shift_pct,
                inventory_kg=inv_avail,
                inventory_utilization_pct=inv_util_pct,
                forecast_kg=forecast_val,
                recommended_dispatch_kg=dispatch_val,
                confidence_score=conf_val,
                risk_level=risk_level,
                risk_reason=" • ".join(risk_reasons),
                status=row_status
            )
        )

    # 6. District 6-Cycle Historical Demand Trend
    cursor.execute("""
    SELECT cycle_id,
           SUM(CASE WHEN commodity = 'Rice' THEN actual_quantity_kg ELSE 0 END) as rice_kg,
           SUM(CASE WHEN commodity = 'Wheat' THEN actual_quantity_kg ELSE 0 END) as wheat_kg,
           SUM(actual_quantity_kg) as total_kg
    FROM historical_demand
    GROUP BY cycle_id
    ORDER BY cycle_id ASC;
    """)
    trend_rows = cursor.fetchall()
    historical_trend = [
        DistrictHistoricalTrend(
            cycle_id=r["cycle_id"],
            rice_kg=round(r["rice_kg"], 1),
            wheat_kg=round(r["wheat_kg"], 1),
            total_kg=round(r["total_kg"], 1)
        )
        for r in trend_rows
    ]

    # 7. Top 5 Intent Shift FPS
    sorted_by_shift = sorted(admin_fps_list, key=lambda x: x.intent_shift_kg, reverse=True)
    top_shift = [
        {
            "fps_id": f.fps_id,
            "name": f.name.replace(" (Demo)", ""),
            "historical_kg": f.historical_demand_kg,
            "intent_kg": f.declared_intent_kg,
            "shift_kg": f.intent_shift_kg,
            "forecast_kg": f.forecast_kg,
            "recommended_dispatch_kg": f.recommended_dispatch_kg,
            "risk": f.risk_level
        }
        for f in sorted_by_shift[:6]
    ]

    forecast_count = total_fps if is_generated else 0
    avg_confidence = round(total_conf_score / max(1, total_fps), 2)

    from app.services.planning_cycle_engine import planning_cycle_engine
    planning_cycle_state = planning_cycle_engine.get_cycle_state(db, active_cycle)

    return AdminDashboardSummary(
        district=district_name,
        active_cycle=active_cycle,
        total_fps=total_fps,
        active_intents_count=active_intents_count,
        total_declared_intent_kg=round(total_declared_intent_kg, 1),
        total_historical_demand_kg=round(total_historical_demand, 1),
        total_forecast_demand_kg=round(total_forecast_demand, 1),
        total_recommended_dispatch_kg=round(total_recommended_dispatch, 1),
        average_confidence=avg_confidence,
        forecast_generated_count=forecast_count,
        high_risk_fps_count=high_risk_count,
        medium_risk_fps_count=med_risk_count,
        low_risk_fps_count=low_risk_count,
        exception_cases_count=exception_count,
        total_inventory_kg=round(total_inventory_kg, 1),
        total_capacity_kg=round(total_capacity_kg, 1),
        average_capacity_utilization_pct=avg_utilization,
        risk_distribution={"HIGH": high_risk_count, "MEDIUM": med_risk_count, "LOW": low_risk_count},
        historical_cycles_trend=historical_trend,
        top_intent_shift_fps=top_shift,
        fps_list=admin_fps_list,
        workflow_status=workflow_status,
        planning_cycle_state=planning_cycle_state,
        demo_notice=DEMO_NOTICE
    )


@router.get("/admin/fps/{id}", response_model=AdminFpsDetailAnalytics)
def get_admin_fps_detail(id: str, db: sqlite3.Connection = Depends(get_db)):
    """Deep-dive analytics for a selected Fair Price Shop."""
    cursor = db.cursor()
    active_cycle = settings.CURRENT_CYCLE

    if id.isdigit():
        cursor.execute("SELECT id, fps_id, name, district, latitude, longitude, capacity_kg, status FROM fps WHERE id = ?;", (int(id),))
    else:
        cursor.execute("SELECT id, fps_id, name, district, latitude, longitude, capacity_kg, status FROM fps WHERE fps_id = ?;", (id.strip(),))

    fps_row = cursor.fetchone()
    if not fps_row:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=f"FPS '{id}' not found.")

    fid = fps_row["fps_id"]
    cap = float(fps_row["capacity_kg"])

    # Registered cards
    cursor.execute("SELECT COUNT(*) FROM beneficiaries WHERE registered_fps_id = ?;", (fid,))
    reg_count = cursor.fetchone()[0]

    # Historical demand 6-cycle average & records
    cursor.execute("""
    SELECT cycle_id, commodity, actual_quantity_kg
    FROM historical_demand
    WHERE fps_id = ?
    ORDER BY cycle_id ASC, commodity ASC;
    """, (fid,))
    hist_rows = cursor.fetchall()
    hist_records = [dict(r) for r in hist_rows]

    rice_trend = [{"cycle_id": r["cycle_id"], "quantity_kg": r["actual_quantity_kg"]} for r in hist_rows if r["commodity"] == "Rice"]
    wheat_trend = [{"cycle_id": r["cycle_id"], "quantity_kg": r["actual_quantity_kg"]} for r in hist_rows if r["commodity"] == "Wheat"]

    cursor.execute("SELECT COALESCE(SUM(actual_quantity_kg) / 6.0, 0.0) FROM historical_demand WHERE fps_id = ?;", (fid,))
    hist_avg = round(cursor.fetchone()[0], 1)

    # Intent Breakdown: Home vs Portability
    cursor.execute("""
    SELECT 
        COUNT(DISTINCT CASE WHEN b.registered_fps_id = i.intended_fps_id THEN i.beneficiary_id END) as home_count,
        COUNT(DISTINCT CASE WHEN b.registered_fps_id != i.intended_fps_id THEN i.beneficiary_id END) as port_count,
        COALESCE(SUM(i.declared_quantity_kg), 0.0) as total_kg
    FROM intent i
    JOIN beneficiaries b ON i.beneficiary_id = b.pseudonymous_beneficiary_id
    WHERE i.intended_fps_id = ? AND i.cycle_id = ?;
    """, (fid, active_cycle))
    intent_summary = cursor.fetchone()
    home_count = intent_summary["home_count"] or 0
    port_count = intent_summary["port_count"] or 0
    intent_total = round(intent_summary["total_kg"] or 0.0, 1)

    # By commodity
    cursor.execute("""
    SELECT commodity, SUM(declared_quantity_kg) as total_kg, AVG(confidence) as avg_conf
    FROM intent
    WHERE intended_fps_id = ? AND cycle_id = ?
    GROUP BY commodity;
    """, (fid, active_cycle))
    commodity_rows = cursor.fetchall()
    intent_commodities = {r["commodity"]: {"quantity_kg": round(r["total_kg"], 1), "confidence": round(r["avg_conf"], 2)} for r in commodity_rows}

    # Inventory
    cursor.execute("SELECT commodity, available_quantity_kg FROM inventory WHERE fps_id = ? ORDER BY commodity ASC;", (fid,))
    inv_rows = cursor.fetchall()
    inv_items = [{"commodity": r["commodity"], "available_quantity_kg": r["available_quantity_kg"]} for r in inv_rows]
    inv_total = sum(r["available_quantity_kg"] for r in inv_rows)
    inv_util = round((inv_total / cap) * 100.0, 1) if cap > 0 else 0.0

    # Calculate deterministic commodity breakdown
    rice_calc = forecast_engine.calculate_fps_commodity_forecast(cursor, fid, "Rice", active_cycle)
    wheat_calc = forecast_engine.calculate_fps_commodity_forecast(cursor, fid, "Wheat", active_cycle)

    forecast_val = round(rice_calc["forecast_demand_kg"] + wheat_calc["forecast_demand_kg"], 1)
    dispatch_val = round(rice_calc["recommended_dispatch_kg"] + wheat_calc["recommended_dispatch_kg"], 1)
    avg_conf = (rice_calc["intent_confidence"] + wheat_calc["intent_confidence"]) / 2.0

    # Risk assessment
    risk_level, risk_reason, conf_score = forecast_engine.evaluate_fps_risk_and_confidence(
        cursor, fid, intent_total, inv_total, cap, reg_count, avg_conf
    )

    baseline_reg = reg_count * 30.0
    intent_shift = round(intent_total - baseline_reg, 1)

    # Workflow Status
    workflow_status = forecast_engine.get_persisted_workflow_status(db, active_cycle)
    is_locked = (workflow_status == "FORECAST_LOCKED")
    status_label = "Locked" if is_locked else ("Draft" if workflow_status == "DRAFT_GENERATED" else "Planning")

    # Formula explanation string for SIH jury demonstration
    w = settings.INTENT_WEIGHT
    formula_explanation = (
        f"D_hat = (1 - {w}*C)*H + ({w}*C)*I  |  "
        f"Rice: (1 - {w}*{rice_calc['intent_confidence']:.2f})*{rice_calc['historical_demand_kg']} + ({w}*{rice_calc['intent_confidence']:.2f})*{rice_calc['intent_demand_kg']} = {rice_calc['forecast_demand_kg']} kg  |  "
        f"Wheat: (1 - {w}*{wheat_calc['intent_confidence']:.2f})*{wheat_calc['historical_demand_kg']} + ({w}*{wheat_calc['intent_confidence']:.2f})*{wheat_calc['intent_demand_kg']} = {wheat_calc['forecast_demand_kg']} kg  |  "
        f"Total Demand: {forecast_val} kg  ->  Recommended Dispatch: {dispatch_val} kg"
    )

    forecast_breakdown = {
        "Rice": rice_calc,
        "Wheat": wheat_calc,
        "total_forecast_demand_kg": forecast_val,
        "total_recommended_dispatch_kg": dispatch_val,
        "intent_weight_w": w,
        "safety_buffer_pct": settings.SAFETY_BUFFER_PCT
    }

    return AdminFpsDetailAnalytics(
        fps_id=fid,
        name=fps_row["name"],
        district=fps_row["district"],
        latitude=fps_row["latitude"],
        longitude=fps_row["longitude"],
        capacity_kg=cap,
        registered_beneficiaries=reg_count,
        historical_demand_kg=hist_avg,
        declared_intent_kg=intent_total,
        intent_shift_kg=intent_shift,
        inventory_kg=round(inv_total, 1),
        inventory_utilization_pct=inv_util,
        forecast_kg=forecast_val,
        recommended_dispatch_kg=dispatch_val,
        confidence_score=conf_score,
        risk_level=risk_level,
        risk_reason=risk_reason,
        status=status_label,
        formula_explanation=formula_explanation,
        forecast_breakdown=forecast_breakdown,
        historical_records=hist_records,
        rice_trend_kg=rice_trend,
        wheat_trend_kg=wheat_trend,
        intent_home_count=home_count,
        intent_portability_count=port_count,
        intent_commodities=intent_commodities,
        inventory_items=inv_items,
        demo_notice=DEMO_NOTICE
    )


@router.post("/admin/forecast/generate")
def trigger_forecast_generation(
    cycle_id: str = Query(settings.CURRENT_CYCLE, description="Target cycle to generate forecasts for"),
    force: bool = Query(False, description="Force regenerate even if locked"),
    db: sqlite3.Connection = Depends(get_db)
):
    """
    Calculate and persist deterministic demand forecasts across all 20 Fair Price Shops.
    Persists rows into SQLite forecast table with DRAFT status.
    """
    try:
        res = forecast_engine.generate_and_persist_forecasts(db, cycle_id=cycle_id, force=force)
        workflow_manager.transition_state(
            db, cycle_id, WorkflowState.FORECASTED,
            "District Supply Officer (Demo Admin)", "DISTRICT_SUPPLY_OFFICER",
            "Demand forecasts generated across all 20 Fair Price Shops.", force=True
        )
        return res
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e)
        )
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Forecast generation failed due to an internal server error."
        )


@router.post("/admin/forecast/lock")
def trigger_forecast_lock(
    cycle_id: str = Query(settings.CURRENT_CYCLE, description="Cycle to lock forecast for"),
    db: sqlite3.Connection = Depends(get_db)
):
    """
    Lock demand forecast in SQLite database and freeze pre-dispatch allocations.
    Updates forecast status to FORECAST_LOCKED.
    """
    try:
        res = forecast_engine.lock_persisted_forecast(db, cycle_id=cycle_id)
        workflow_manager.transition_state(
            db, cycle_id, WorkflowState.VALIDATED,
            "District Supply Officer (Demo Admin)", "DISTRICT_SUPPLY_OFFICER",
            "Demand forecast locked & validated against NFSA storage/fleet constraints.", force=True
        )
        return res
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e)
        )
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to lock forecast due to an internal server error."
        )


@router.post("/admin/choice-window/close")
def close_choice_window_api(
    cycle_id: str = Query(settings.CURRENT_CYCLE, description="Cycle to close choice window and lock demand for"),
    db: sqlite3.Connection = Depends(get_db)
):
    """
    Close the beneficiary preference choice window for the planning cycle and lock aggregated demand.
    Computes/freezes demand baseline (D_hat), persists immutable Demand Snapshot with SHA-256 seal,
    and transitions workflow state to FORECAST_LOCKED on Day 25.
    Prevents further preference modifications for this cycle.
    """
    try:
        from app.services.planning_cycle_engine import planning_cycle_engine
        res = planning_cycle_engine.lock_demand_snapshot(
            db,
            cycle_id=cycle_id,
            officer_name="District Supply Officer (Demo Admin)",
            officer_role="DISTRICT_SUPPLY_OFFICER"
        )

        # Fetch aggregated totals
        cursor = db.cursor()
        cursor.execute("SELECT COALESCE(SUM(predicted_quantity_kg), 0.0), COALESCE(SUM(recommended_dispatch_kg), 0.0) FROM forecast WHERE cycle_id = ?;", (cycle_id,))
        sums = cursor.fetchone()
        forecast_total = round(float(sums[0]), 1) if sums else 0.0
        dispatch_total = round(float(sums[1]), 1) if sums else 0.0

        return {
            "cycle_id": cycle_id,
            "status": "CHOICE_WINDOW_CLOSED",
            "workflow_status": "FORECAST_LOCKED",
            "planning_day": res.get("planning_day", 25),
            "snapshot_id": res.get("snapshot_id"),
            "canonical_hash": res.get("canonical_hash"),
            "message": f"Choice window for cycle '{cycle_id}' is now CLOSED. Aggregated beneficiary demand is LOCKED into downstream constraint and dispatch engines.",
            "total_fps": 20,
            "locked_records_count": 40,
            "total_locked_forecast_demand_kg": forecast_total,
            "total_recommended_dispatch_kg": dispatch_total,
            "demo_notice": DEMO_NOTICE
        }
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=f"Failed to close choice window due to an internal server error: {e}")


@router.get("/admin/planning-cycle/demand-snapshot")
def get_demand_snapshot_api(
    cycle_id: str = Query(settings.CURRENT_CYCLE, description="Cycle ID to retrieve demand snapshot for"),
    db: sqlite3.Connection = Depends(get_db)
):
    """Retrieve the frozen Day 25 demand snapshot for the cycle, including SHA-256 seal."""
    from app.services.planning_cycle_engine import planning_cycle_engine
    snapshot = planning_cycle_engine.get_latest_snapshot(db, cycle_id)
    if not snapshot:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"No frozen demand snapshot found for cycle '{cycle_id}'. Demand has not yet been locked."
        )
    return {
        "status": "success",
        "snapshot": snapshot,
        "demo_notice": DEMO_NOTICE
    }


@router.post("/admin/planning-cycle/set-day")
def set_planning_cycle_day_api(
    day: int = Query(..., ge=1, le=31, description="Planning day to set (e.g. 21..25)"),
    cycle_id: str = Query(settings.CURRENT_CYCLE, description="Cycle ID"),
    db: sqlite3.Connection = Depends(get_db)
):
    """Demo support: Advance or toggle the planning day (e.g. Day 21..24 -> Day 25)."""
    from app.services.planning_cycle_engine import planning_cycle_engine
    new_day = planning_cycle_engine.set_planning_day(db, cycle_id, day)
    state = planning_cycle_engine.get_cycle_state(db, cycle_id)
    return {
        "status": "success",
        "planning_day": new_day,
        "cycle_state": state,
        "message": f"Planning day set to Day {new_day} for cycle '{cycle_id}'.",
        "demo_notice": DEMO_NOTICE
    }


@router.get("/admin/forecast/cycle/{cycle_id}")
def get_cycle_forecasts(
    cycle_id: str,
    db: sqlite3.Connection = Depends(get_db)
):
    """Retrieve all persisted forecast records for a cycle."""
    records = forecast_engine.get_persisted_forecasts_for_cycle(db, cycle_id=cycle_id)
    workflow_status = forecast_engine.get_persisted_workflow_status(db, cycle_id=cycle_id)
    return {
        "cycle_id": cycle_id,
        "workflow_status": workflow_status,
        "count": len(records),
        "records": records,
        "demo_notice": DEMO_NOTICE
    }


# ----------------- Dispatch Simulation Endpoints (Phase 5) ----------------- #

@router.post("/admin/dispatch/generate")
def trigger_dispatch_generation(
    cycle_id: str = Query(settings.CURRENT_CYCLE, description="Target cycle to generate dispatch manifest for"),
    force: bool = Query(False, description="Force regenerate dispatch"),
    db: sqlite3.Connection = Depends(get_db)
):
    """
    Generate multi-echelon godown dispatch allocations and truck delivery manifests from locked forecasts.
    Requires forecast status to be FORECAST_LOCKED.
    """
    try:
        manifest = dispatch_engine.generate_and_persist_dispatch(db, cycle_id=cycle_id, force=force)
        workflow_manager.transition_state(
            db, cycle_id, WorkflowState.OPTIMIZED,
            "District Supply Officer (Demo Admin)", "DISTRICT_SUPPLY_OFFICER",
            "Pre-dispatch routing corridors optimized.", force=True
        )
        workflow_manager.transition_state(
            db, cycle_id, WorkflowState.MANIFEST_DRAFT,
            "District Supply Officer (Demo Admin)", "DISTRICT_SUPPLY_OFFICER",
            "Multi-echelon dispatch manifests generated as DRAFT.", force=True
        )
        return manifest
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e)
        )
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Dispatch generation failed due to an internal server error."
        )


@router.get("/admin/dispatch")
@router.get("/admin/dispatch/manifest")
def get_dispatch_manifest(
    cycle_id: str = Query(settings.CURRENT_CYCLE, description="Target cycle for dispatch manifest"),
    db: sqlite3.Connection = Depends(get_db)
):
    """
    Retrieve aggregated vehicle fleet dispatch manifest and itemized delivery drops for a cycle.
    """
    manifest = dispatch_engine.get_dispatch_manifest(db, cycle_id=cycle_id)
    return manifest


@router.get("/admin/dispatch/cycle/{cycle_id}")
def get_dispatch_for_cycle(
    cycle_id: str,
    db: sqlite3.Connection = Depends(get_db)
):
    """Retrieve dispatch manifest and line items for a specific cycle."""
    manifest = dispatch_engine.get_dispatch_manifest(db, cycle_id=cycle_id)
    return manifest


@router.get("/admin/dispatch/{id}")
def get_dispatch_by_id(
    id: int,
    db: sqlite3.Connection = Depends(get_db)
):
    """Retrieve individual dispatch record by ID."""
    rec = dispatch_engine.get_dispatch_record_by_id(db, id)
    if not rec:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Dispatch record with ID {id} not found."
        )
    rec["demo_notice"] = DEMO_NOTICE
    return rec


# ----------------- Phase 6: Actual Distribution, Evaluation & Calibration Endpoints ----------------- #

@router.post("/admin/distribution/simulate")
def trigger_distribution_simulation(
    cycle_id: str = Query(settings.CURRENT_CYCLE, description="Target cycle to simulate distribution for"),
    force: bool = Query(False, description="Force re-simulate distribution"),
    db: sqlite3.Connection = Depends(get_db)
):
    """
    Simulate actual ePoS grain distribution lifting for all 20 Fair Price Shops.
    Requires dispatch manifest to be generated.
    """
    try:
        res = evaluation_engine.simulate_actual_distribution(db, cycle_id=cycle_id, force=force)
        workflow_manager.transition_state(
            db, cycle_id, WorkflowState.DISPATCHED,
            "District Supply Officer (Demo Admin)", "DISTRICT_SUPPLY_OFFICER",
            "Actual distribution simulated/recorded across ePoS devices.", force=True
        )
        return res
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e)
        )
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Distribution simulation failed due to an internal server error."
        )


@router.get("/admin/distribution")
def get_actual_distribution(
    cycle_id: str = Query(settings.CURRENT_CYCLE, description="Target cycle for actual distribution records"),
    db: sqlite3.Connection = Depends(get_db)
):
    """Retrieve simulated actual distribution records for active cycle."""
    return evaluation_engine.get_actual_distribution_records(db, cycle_id=cycle_id)


@router.get("/admin/evaluation")
def get_forecast_vs_actual_evaluation(
    cycle_id: str = Query(settings.CURRENT_CYCLE, description="Target cycle for evaluation"),
    db: sqlite3.Connection = Depends(get_db)
):
    """
    Calculate and retrieve forecast vs actual evaluation metrics (MAE, MAPE, Overall Accuracy).
    Requires actual distribution to have been simulated.
    """
    try:
        res = evaluation_engine.evaluate_forecast_vs_actual(db, cycle_id=cycle_id)
        workflow_manager.transition_state(
            db, cycle_id, WorkflowState.VERIFIED,
            "District Supply Officer (Demo Admin)", "DISTRICT_SUPPLY_OFFICER",
            "Forecast vs actual evaluation metrics computed.", force=True
        )
        return res
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e)
        )
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Evaluation failed due to an internal server error."
        )


@router.get("/admin/evaluation/cycle/{cycle_id}")
def get_forecast_vs_actual_evaluation_by_cycle(
    cycle_id: str,
    db: sqlite3.Connection = Depends(get_db)
):
    """
    Retrieve forecast vs actual evaluation metrics for a specific cycle path parameter.
    """
    try:
        res = evaluation_engine.evaluate_forecast_vs_actual(db, cycle_id=cycle_id)
        workflow_manager.transition_state(
            db, cycle_id, WorkflowState.VERIFIED,
            "District Supply Officer (Demo Admin)", "DISTRICT_SUPPLY_OFFICER",
            "Forecast vs actual evaluation metrics computed.", force=True
        )
        return res
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e)
        )
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Evaluation failed due to an internal server error."
        )


@router.post("/admin/calibrate")
def trigger_model_calibration(
    cycle_id: str = Query(settings.CURRENT_CYCLE, description="Source cycle to calibrate from"),
    db: sqlite3.Connection = Depends(get_db)
):
    """
    Execute closed-loop machine learning calibration using scikit-learn Ridge regression.
    Learns optimal intent influence weight (w) for future Cycle 2026-10.
    """
    try:
        res = evaluation_engine.calibrate_model_with_sklearn(db, cycle_id=cycle_id)
        workflow_manager.transition_state(
            db, cycle_id, WorkflowState.EVALUATED,
            "District Supply Officer (Demo Admin)", "DISTRICT_SUPPLY_OFFICER",
            "Closed-loop ML calibration completed.", force=True
        )
        return res
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e)
        )
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Model calibration failed due to an internal server error."
        )


# ----------------- Pre-Dispatch Decision Intelligence: Constraint & Optimization Endpoints ----------------- #

class ResolveConstraintRequest(BaseModel):
    action: str = Field("SELECT_ALTERNATE_TRUCK", description="Resolution action: SELECT_ALTERNATE_TRUCK, SPLIT_QUANTITY, ADJUST_DISPATCH_QUANTITY, TRIGGER_FAILURE_SIMULATION, RESET")
    parameters: Optional[Dict[str, Any]] = Field(None, description="Optional parameters like adjusted_quantity_kg")


@router.get("/admin/constraints/validate")
def validate_district_constraints(
    cycle_id: str = Query(settings.CURRENT_CYCLE, description="Target cycle to validate constraints for"),
    scenario: str = Query("NORMAL", description="Scenario: NORMAL or FAILURE_SIMULATION"),
    db: sqlite3.Connection = Depends(get_db)
):
    """
    Run district-wide operational constraint audit across all 20 FPS and fleet corridors.
    Validates 9 operational rules (Storage Capacity, Truck Capacity, Depot Stock, Allocation Limit, Safety Stock, Vehicle Availability, Route Restrictions, Delivery Window, Government Compliance).
    """
    try:
        res = constraint_engine.run_full_district_constraint_audit(db, cycle_id=cycle_id, scenario=scenario)
        workflow_manager.transition_state(
            db, cycle_id, WorkflowState.VALIDATED,
            "District Supply Officer (Demo Admin)", "DISTRICT_SUPPLY_OFFICER",
            "District constraints validated.", force=True
        )
        return res
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Constraint validation failed due to an internal server error."
        )


@router.get("/admin/constraints/fps/{fps_id}")
@router.get("/admin/fps/{fps_id}/constraints")
def validate_single_fps_constraints(
    fps_id: str,
    scenario: str = Query("NORMAL", description="Scenario: NORMAL or FAILURE_SIMULATION"),
    cycle_id: str = Query(settings.CURRENT_CYCLE, description="Target cycle for validation"),
    db: sqlite3.Connection = Depends(get_db)
):
    """Validate 9 operational constraints for a single Fair Price Shop."""
    try:
        cursor = db.cursor()
        res = constraint_engine.validate_fps_constraints(cursor, fps_id, cycle_id, scenario=scenario)
        db.commit()
        return res
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(e))
    except Exception:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="FPS constraint check failed due to an internal server error.")


@router.post("/admin/fps/{fps_id}/constraints/resolve")
def resolve_fps_constraint_action(
    fps_id: str,
    payload: ResolveConstraintRequest,
    cycle_id: str = Query(settings.CURRENT_CYCLE, description="Target cycle for validation"),
    db: sqlite3.Connection = Depends(get_db)
):
    """
    Execute interactive constraint remediation:
    - SELECT_ALTERNATE_TRUCK: Assign 10 MT heavy carrier DEMO-KA-04-E-1021.
    - SPLIT_QUANTITY: Split dispatch across 2 staggered transit drops.
    - ADJUST_DISPATCH_QUANTITY: Trim dispatch quantity to fit vehicle rating.
    - TRIGGER_FAILURE_SIMULATION: Force a Truck Capacity failure to demonstrate failure handling.
    - RESET: Reset constraint parameters to defaults.
    """
    try:
        cursor = db.cursor()
        res = constraint_engine.resolve_fps_constraint(
            cursor, fps_id, action=payload.action, parameters=payload.parameters, cycle_id=cycle_id
        )
        db.commit()
        return res
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(e))
    except Exception:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Constraint resolution failed due to an internal server error.")


@router.post("/admin/constraints/revalidate")
def revalidate_all_constraints(
    cycle_id: str = Query(settings.CURRENT_CYCLE, description="Target cycle for validation"),
    scenario: str = Query("NORMAL", description="Scenario: NORMAL or FAILURE_SIMULATION"),
    db: sqlite3.Connection = Depends(get_db)
):
    """
    Revalidate all 9 constraint rules across the district after making adjustments.
    """
    try:
        res = constraint_engine.run_full_district_constraint_audit(db, cycle_id=cycle_id, scenario=scenario)
        return res
    except Exception:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Revalidation failed due to an internal server error.")


class WhatIfOptimizationRequest(BaseModel):
    truck_id: Optional[str] = Field("DEMO-KA-04-E-1021", description="Vehicle / corridor ID to optimize")
    vehicle_capacity_kg: Optional[float] = Field(None, description="Custom vehicle payload rating (kg)")
    fuel_cost_per_km: Optional[float] = Field(None, description="Custom fuel / operating cost rate (INR/km)")
    route_condition: Optional[str] = Field("URBAN_ARTERIAL", description="Route condition: EXPRESSWAY_CORRIDOR, URBAN_ARTERIAL, CONGESTED_PEAK_CORRIDOR")
    departure_window: Optional[str] = Field("08:30 AM", description="Departure window: 07:30 AM, 08:30 AM, 09:15 AM")


@router.get("/admin/optimization/run")
def run_district_dispatch_optimization(
    cycle_id: str = Query(settings.CURRENT_CYCLE, description="Target cycle for optimization"),
    db: sqlite3.Connection = Depends(get_db)
):
    """
    Run multi-corridor route sequencing, cost modeling, delivery window assignment, and composite scoring across all corridors.
    """
    try:
        res = optimization_engine.run_district_wide_optimization(db, cycle_id=cycle_id)
        return res
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Optimization failed due to an internal server error."
        )


@router.get("/admin/optimization/corridor/{truck_id}")
def get_corridor_optimization(
    truck_id: str,
    cycle_id: str = Query(settings.CURRENT_CYCLE, description="Target cycle"),
    db: sqlite3.Connection = Depends(get_db)
):
    """Retrieve multi-candidate optimized route sequence, transit distance, and transport cost for a specific vehicle corridor."""
    try:
        res = optimization_engine.optimize_corridor_candidates(db, truck_id, cycle_id)
        return res
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(e))
    except Exception:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Corridor optimization failed due to an internal server error.")


@router.post("/admin/optimization/what-if")
def simulate_what_if_optimization(
    payload: WhatIfOptimizationRequest,
    cycle_id: str = Query(settings.CURRENT_CYCLE, description="Target cycle"),
    db: sqlite3.Connection = Depends(get_db)
):
    """
    Run real-time What-If dispatch optimization simulation with custom capacity, fuel cost, route conditions, and delivery windows.
    """
    try:
        res = optimization_engine.optimize_corridor_candidates(
            db,
            payload.truck_id or "DEMO-KA-04-E-1021",
            cycle_id=cycle_id,
            custom_capacity_kg=payload.vehicle_capacity_kg,
            custom_fuel_cost_per_km=payload.fuel_cost_per_km,
            custom_route_condition=payload.route_condition,
            custom_departure_window=payload.departure_window
        )
        return res
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(e))
    except Exception:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="What-if optimization failed due to an internal server error.")


# ----------------- Phase 6: Auditable Manifest Generation & Lock Endpoints ----------------- #

class UpdateManifestRequest(BaseModel):
    truck_id: Optional[str] = Field(None, description="Updated truck ID")
    total_quantity_kg: Optional[float] = Field(None, description="Updated total payload quantity (kg)")
    route_type: Optional[str] = Field(None, description="Updated route corridor type")
    departure_window: Optional[str] = Field(None, description="Updated departure window")
    actor_name: Optional[str] = Field("District Supply Officer (Demo Admin)", description="Authorized officer name")
    actor_role: Optional[str] = Field("DISTRICT_SUPPLY_OFFICER", description="Officer role")
    modification_reason: Optional[str] = Field("Operational adjustment in DRAFT mode", description="Reason for modification")

class LockManifestRequest(BaseModel):
    actor_name: Optional[str] = Field("District Supply Officer (Demo Admin)", description="Signing officer name")
    actor_role: Optional[str] = Field("DISTRICT_SUPPLY_OFFICER", description="Signing officer role")
    lock_reason: Optional[str] = Field("Official DSO Pre-Dispatch freeze for statutory execution", description="Reason for locking")

class ReviseManifestRequest(BaseModel):
    actor_name: Optional[str] = Field("District Supply Officer (Demo Admin)", description="Revising officer name")
    actor_role: Optional[str] = Field("DISTRICT_SUPPLY_OFFICER", description="Revising officer role")
    revision_reason: str = Field(..., description="Mandatory reason for revising a locked manifest")


@router.get("/admin/manifests")
def list_all_manifests(
    cycle_id: str = Query(settings.CURRENT_CYCLE, description="Target cycle"),
    db: sqlite3.Connection = Depends(get_db)
):
    """Retrieve all auditable dispatch manifests for the active planning cycle."""
    try:
        manifests = manifest_engine.list_cycle_manifests(db, cycle_id=cycle_id)
        return {
            "status": "success",
            "cycle_id": cycle_id,
            "total_manifests_count": len(manifests),
            "manifests": manifests,
            "demo_notice": DEMO_NOTICE
        }
    except Exception:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Failed to list manifests due to an internal server error.")


@router.get("/admin/manifests/{manifest_id}")
def get_manifest_details(
    manifest_id: str,
    db: sqlite3.Connection = Depends(get_db)
):
    """Retrieve full manifest dossier including itemized stops and immutable audit trail."""
    try:
        res = manifest_engine.get_manifest_dossier(db, manifest_id=manifest_id)
        return res
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(e))
    except Exception:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Failed to fetch manifest due to an internal server error.")


@router.post("/admin/manifests/generate")
def generate_corridor_manifest_endpoint(
    truck_id: str = Query("DEMO-KA-04-E-1021", description="Vehicle ID for manifest corridor"),
    cycle_id: str = Query(settings.CURRENT_CYCLE, description="Target cycle"),
    db: sqlite3.Connection = Depends(get_db)
):
    """Generate or retrieve a pre-dispatch manifest for a vehicle corridor."""
    try:
        res = manifest_engine.generate_corridor_manifest(db, truck_id=truck_id, cycle_id=cycle_id)
        return res
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))
    except Exception:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Failed to generate manifest due to an internal server error.")


@router.post("/admin/manifests/{manifest_id}/update")
def update_draft_manifest_endpoint(
    manifest_id: str,
    payload: UpdateManifestRequest,
    db: sqlite3.Connection = Depends(get_db)
):
    """Modify parameters of a DRAFT manifest. Fails with 400 if the manifest is LOCKED."""
    try:
        res = manifest_engine.update_draft_manifest(
            db,
            manifest_id=manifest_id,
            truck_id=payload.truck_id,
            total_quantity_kg=payload.total_quantity_kg,
            route_type=payload.route_type,
            departure_window=payload.departure_window,
            actor_name=payload.actor_name or "District Supply Officer (Demo Admin)",
            actor_role=payload.actor_role or "DISTRICT_SUPPLY_OFFICER",
            modification_reason=payload.modification_reason or "Operational adjustment in DRAFT mode"
        )
        return res
    except ValueError as e:
        err_msg = str(e)
        if "not found" in err_msg.lower():
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=err_msg)
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=err_msg)
    except Exception:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Failed to update manifest due to an internal server error.")


@router.post("/admin/manifests/{manifest_id}/lock")
def lock_manifest_endpoint(
    manifest_id: str,
    payload: LockManifestRequest,
    db: sqlite3.Connection = Depends(get_db)
):
    """Lock manifest, generate cryptographic digital seal, and freeze critical parameters."""
    try:
        # Get cycle_id from manifest
        cursor = db.cursor()
        cursor.execute("SELECT cycle_id FROM manifests WHERE manifest_id = ?;", (manifest_id,))
        row = cursor.fetchone()
        cycle_id = row[0] if row else settings.CURRENT_CYCLE

        res = manifest_engine.lock_manifest(
            db,
            manifest_id=manifest_id,
            actor_name=payload.actor_name or "District Supply Officer (Demo Admin)",
            actor_role=payload.actor_role or "DISTRICT_SUPPLY_OFFICER",
            lock_reason=payload.lock_reason or "Official DSO Pre-Dispatch freeze for statutory execution"
        )

        workflow_manager.transition_state(
            db, cycle_id, WorkflowState.MANIFEST_LOCKED,
            payload.actor_name or "District Supply Officer (Demo Admin)",
            payload.actor_role or "DISTRICT_SUPPLY_OFFICER",
            payload.lock_reason or "Official DSO Pre-Dispatch freeze for statutory execution", force=True
        )

        return res
    except ValueError as e:
        err_msg = str(e)
        if "not found" in err_msg.lower():
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=err_msg)
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=err_msg)
    except Exception:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Failed to lock manifest due to an internal server error.")


@router.post("/admin/manifests/{manifest_id}/revise")
@router.post("/admin/manifests/{manifest_id}/revision")
def revise_manifest_endpoint(
    manifest_id: str,
    payload: ReviseManifestRequest,
    db: sqlite3.Connection = Depends(get_db)
):
    """Create a new authorized revision of a LOCKED manifest, incrementing version and unlocking draft."""
    try:
        res = manifest_engine.create_manifest_revision(
            db,
            manifest_id=manifest_id,
            actor_name=payload.actor_name or "District Supply Officer (Demo Admin)",
            actor_role=payload.actor_role or "DISTRICT_SUPPLY_OFFICER",
            revision_reason=payload.revision_reason
        )
        return res
    except ValueError as e:
        err_msg = str(e)
        if "not found" in err_msg.lower():
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=err_msg)
        if "concurrent" in err_msg.lower():
            raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=err_msg)
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=err_msg)
    except Exception:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Failed to revise manifest due to an internal server error.")


@router.get("/admin/manifests/{manifest_id}/verify-seal")
def verify_manifest_seal_endpoint(
    manifest_id: str,
    db: sqlite3.Connection = Depends(get_db)
):
    """Cryptographic verification of manifest digital seal against canonical database fields."""
    try:
        res = manifest_engine.verify_manifest_seal(db, manifest_id)
        from app.services.governance_trail import governance_trail
        governance_trail.record_event(
            db=db,
            event_type="MANIFEST_SEAL_VERIFIED",
            action="VERIFY_CRYPTOGRAPHIC_SEAL",
            entity_type="MANIFEST",
            entity_id=manifest_id,
            actor_name="Auditor / Inspection Officer",
            actor_role="AUDITOR",
            notes=f"Digital seal verification: {res.get('status', 'UNKNOWN')}. Match = {res.get('is_valid', False)}",
            integrity_metadata={"is_valid": res.get("is_valid", False), "status": res.get("status")},
            is_success=res.get("is_valid", False),
            is_simulation=False
        )
        return res
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(e))
    except Exception:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Seal verification failed due to an internal server error.")


# ----------------- Pre-Dispatch Decision Intelligence: Digital Gatepasses ----------------- #

class VerifyGatepassRequest(BaseModel):
    gatepass_id: str = Field(..., description="ID of gatepass to verify")
    security_token: Optional[str] = Field(None, description="Security token from QR or print slip")
    qr_payload: Optional[str] = Field(None, description="Raw QR code payload string")


@router.post("/admin/gatepasses/verify")
def verify_gatepass_endpoint(
    payload: VerifyGatepassRequest,
    db: sqlite3.Connection = Depends(get_db)
):
    """Cryptographic and manifest-linkage verification of a digital gatepass."""
    try:
        res = gatepass_engine.verify_gatepass(
            db,
            gatepass_id=payload.gatepass_id,
            security_token=payload.security_token,
            qr_payload=payload.qr_payload
        )
        from app.services.governance_trail import governance_trail
        governance_trail.record_event(
            db=db,
            event_type="GATEPASS_TOKEN_VERIFIED",
            action="VERIFY_SECURITY_TOKEN",
            entity_type="GATEPASS",
            entity_id=payload.gatepass_id,
            actor_name="Depot Gate Security Officer",
            actor_role="DEPOT_SECURITY",
            notes=f"Gatepass security verification: {res.get('status', 'UNKNOWN')}. Valid = {res.get('is_valid', False)}",
            integrity_metadata={"is_valid": res.get("is_valid", False), "status": res.get("status")},
            is_success=res.get("is_valid", False),
            is_simulation=False
        )
        return res
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))
    except Exception:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Gatepass verification failed due to an internal server error.")


@router.get("/admin/gatepasses")
def get_all_gatepasses(
    cycle_id: str = Query(settings.CURRENT_CYCLE, description="Target cycle"),
    db: sqlite3.Connection = Depends(get_db)
):
    """Retrieve all Digital Pre-Dispatch Gatepasses for the active cycle."""
    try:
        res = gatepass_engine.generate_all_cycle_gatepasses(db, cycle_id=cycle_id)
        workflow_manager.transition_state(
            db, cycle_id, WorkflowState.GATEPASS_READY,
            "District Supply Officer (Demo Admin)", "DISTRICT_SUPPLY_OFFICER",
            "Gatepasses generated for the cycle.", force=True
        )
        return {"status": "success", "cycle_id": cycle_id, "gatepasses": res, "demo_notice": DEMO_NOTICE}
    except Exception:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Gatepass retrieval failed due to an internal server error.")


@router.get("/admin/gatepass/{truck_id}")
def get_or_create_truck_gatepass(
    truck_id: str,
    cycle_id: str = Query(settings.CURRENT_CYCLE, description="Target cycle"),
    db: sqlite3.Connection = Depends(get_db)
):
    """Retrieve or generate official Digital Pre-Dispatch Gatepass for a specific vehicle."""
    try:
        res = gatepass_engine.generate_or_get_gatepass_for_truck(db, truck_id, cycle_id)
        workflow_manager.transition_state(
            db, cycle_id, WorkflowState.GATEPASS_READY,
            "District Supply Officer (Demo Admin)", "DISTRICT_SUPPLY_OFFICER",
            f"Gatepass retrieved/created for truck {truck_id}.", force=True
        )
        return res
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(e))
    except Exception:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Gatepass generation failed due to an internal server error.")


@router.post("/admin/gatepass/{gatepass_id}/advance")
def advance_gatepass_stage(
    gatepass_id: str,
    target_status: str = Query(..., description="Target stage (MANIFEST_LOCKED, GATEPASS_ISSUED, WAREHOUSE_VERIFIED, VEHICLE_LOADED, DISPATCH_CONFIRMED)"),
    db: sqlite3.Connection = Depends(get_db)
):
    """Advance gatepass through the 5-stage pre-dispatch physical handshake pipeline."""
    try:
        cursor = db.cursor()
        cursor.execute("SELECT cycle_id FROM gatepasses WHERE gatepass_id = ?;", (gatepass_id,))
        row = cursor.fetchone()
        cycle_id = row[0] if row else settings.CURRENT_CYCLE

        res = gatepass_engine.advance_gatepass_status(db, gatepass_id, target_status)

        if target_status == "DISPATCH_CONFIRMED":
            workflow_manager.transition_state(
                db, cycle_id, WorkflowState.DISPATCHED,
                "District Supply Officer (Demo Admin)", "DISTRICT_SUPPLY_OFFICER",
                f"Gatepass {gatepass_id} advanced to DISPATCH_CONFIRMED. Truck dispatched.", force=True
            )
        else:
            workflow_manager.transition_state(
                db, cycle_id, WorkflowState.GATEPASS_READY,
                "District Supply Officer (Demo Admin)", "DISTRICT_SUPPLY_OFFICER",
                f"Gatepass {gatepass_id} advanced to {target_status}.", force=True
            )
        return res
    except ValueError as e:
        err_msg = str(e)
        if "not found" in err_msg.lower():
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=err_msg)
        if "rejected" in err_msg.lower() or "concurrent" in err_msg.lower():
            raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=err_msg)
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=err_msg)
    except Exception:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Failed to advance gatepass due to an internal server error.")


# ----------------- Pre-Dispatch Decision Intelligence: Multi-Channel Alerts ----------------- #

@router.post("/admin/notifications/dispatch")
def trigger_alert_notifications(
    cycle_id: str = Query(settings.CURRENT_CYCLE, description="Target cycle"),
    db: sqlite3.Connection = Depends(get_db)
):
    """
    Trigger simulated WhatsApp, SMS, and IVR alerts to FPS dealers and beneficiaries.
    """
    try:
        res = notification_engine.dispatch_pre_dispatch_alerts(db, cycle_id=cycle_id)
        return res
    except Exception:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Notification dispatch failed due to an internal server error.")


@router.get("/admin/notifications/logs")
def get_notification_logs(
    cycle_id: str = Query(settings.CURRENT_CYCLE, description="Target cycle"),
    recipient_type: Optional[str] = Query(None, description="Filter by DEALER or BENEFICIARY"),
    db: sqlite3.Connection = Depends(get_db)
):
    """Retrieve auditable notification logs with timestamps and channels."""
    try:
        logs = notification_engine.get_notification_logs(db, cycle_id=cycle_id, recipient_type=recipient_type)
        return {
            "status": "success",
            "cycle_id": cycle_id,
            "total_logs_count": len(logs),
            "logs": logs,
            "demo_notice": DEMO_NOTICE
        }
    except Exception:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Failed to fetch notification logs due to an internal server error.")


# ----------------- Phase 8: SIH Demo Mode & Closed-Loop Delivery Feedback ----------------- #

class RecordActualOfftakeRequest(BaseModel):
    fps_id: str = Field(..., description="Target Fair Price Shop ID")
    actual_rice_kg: float = Field(..., ge=0.0, description="Actual ePoS Rice distributed (kg)")
    actual_wheat_kg: float = Field(..., ge=0.0, description="Actual ePoS Wheat distributed (kg)")
    cycle_id: Optional[str] = Field(settings.CURRENT_CYCLE, description="Active cycle")

class RunDemoScenarioRequest(BaseModel):
    scenario_id: str = Field("SCENARIO_1", description="Scenario ID (SCENARIO_1, SCENARIO_2, SCENARIO_3, SCENARIO_4)")
    target_fps_id: Optional[str] = Field(None, description="Optional custom target FPS ID")
    cycle_id: Optional[str] = Field(settings.CURRENT_CYCLE, description="Target planning cycle")


@router.get("/admin/demo/scenarios")
def get_sih_demo_scenarios():
    """Retrieve list of preconfigured SIH demonstration scenarios."""
    try:
        scenarios = demo_scenario_engine.get_available_scenarios()
        return {
            "status": "success",
            "total_scenarios_count": len(scenarios),
            "scenarios": scenarios,
            "demo_notice": DEMO_NOTICE
        }
    except Exception:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Failed to list demo scenarios due to an internal server error.")


@router.post("/admin/demo/scenario/run")
def run_sih_demo_scenario_endpoint(
    payload: RunDemoScenarioRequest,
    db: sqlite3.Connection = Depends(get_db)
):
    """
    Execute the complete 14-step operational intelligence workflow for a selected SIH scenario:
    Forecast -> Decision -> Validation -> Optimization -> Manifest Lock -> Gatepass -> Notification -> Feedback.
    """
    try:
        res = demo_scenario_engine.execute_scenario(
            db,
            scenario_id=payload.scenario_id,
            target_fps_id=payload.target_fps_id,
            cycle_id=payload.cycle_id or settings.CURRENT_CYCLE
        )
        workflow_manager.transition_state(
            db, payload.cycle_id or settings.CURRENT_CYCLE, WorkflowState.EVALUATED,
            "District Supply Officer (Demo Admin)", "DISTRICT_SUPPLY_OFFICER",
            f"SIH Demo Scenario '{payload.scenario_id}' executed successfully. Workflow completed.", force=True
        )
        return res
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))
    except Exception:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="SIH Demo Scenario execution failed due to an internal server error.")


@router.post("/admin/evaluation/offtake/record")
def record_actual_offtake_endpoint(
    payload: RecordActualOfftakeRequest,
    db: sqlite3.Connection = Depends(get_db)
):
    """
    Record actual offtake for an FPS after dispatch confirmation.
    Calculates absolute error, percentage error, bias, accuracy trend, and model feedback telemetry.
    """
    try:
        res = evaluation_engine.record_fps_actual_offtake(
            db,
            fps_id=payload.fps_id,
            actual_rice_kg=payload.actual_rice_kg,
            actual_wheat_kg=payload.actual_wheat_kg,
            cycle_id=payload.cycle_id or settings.CURRENT_CYCLE
        )
        workflow_manager.transition_state(
            db, payload.cycle_id or settings.CURRENT_CYCLE, WorkflowState.VERIFIED,
            "District Supply Officer (Demo Admin)", "DISTRICT_SUPPLY_OFFICER",
            f"Actual distribution offtake recorded for FPS {payload.fps_id}.", force=True
        )
        return res
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(e))
    except Exception:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Failed to record actual offtake due to an internal server error.")


@router.get("/admin/system-impact")
def get_system_impact_dashboard_endpoint(
    cycle_id: str = Query(settings.CURRENT_CYCLE, description="Target cycle"),
    db: sqlite3.Connection = Depends(get_db)
):
    """
    Retrieve Before vs After Prototype Simulation Impact KPIs & Architecture Value Chain.
    """
    try:
        res = evaluation_engine.get_system_impact_metrics(db, cycle_id=cycle_id)
        return res
    except Exception:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Failed to fetch system impact metrics due to an internal server error.")


class WorkflowStatusResponse(BaseModel):
    current_state: str
    allowed_next_states: List[str]
    blocking_conditions: List[str]
    audit_history: List[Dict[str, Any]]
    demo_notice: str = DEMO_NOTICE

class WorkflowTransitionIn(BaseModel):
    cycle_id: str
    new_state: str
    actor_name: str
    actor_role: str
    reason: Optional[str] = None
    correlation_id: Optional[str] = None

@router.get("/admin/workflow/status", response_model=WorkflowStatusResponse)
def get_workflow_status(
    cycle_id: str = Query(settings.CURRENT_CYCLE),
    db: sqlite3.Connection = Depends(get_db)
):
    current = workflow_manager.get_current_state(db, cycle_id)
    allowed = workflow_manager.get_allowed_next_states(current)
    
    # Get blockers for the next logical state
    try:
        curr_idx = workflow_manager.STATE_ORDER.index(current)
        next_state = workflow_manager.STATE_ORDER[curr_idx + 1] if curr_idx + 1 < len(workflow_manager.STATE_ORDER) else None
    except ValueError:
        next_state = None
        
    blockers = []
    if next_state:
        blockers = workflow_manager.get_blocking_conditions(db, cycle_id, current, next_state)
        
    audit = workflow_manager.get_audit_history(db, cycle_id)
    return {
        "current_state": current,
        "allowed_next_states": allowed,
        "blocking_conditions": blockers,
        "audit_history": audit,
        "demo_notice": DEMO_NOTICE
    }

@router.post("/admin/workflow/transition")
def trigger_workflow_transition(
    payload: WorkflowTransitionIn,
    db: sqlite3.Connection = Depends(get_db)
):
    try:
        state = workflow_manager.transition_state(
            db,
            cycle_id=payload.cycle_id,
            new_state=payload.new_state,
            actor_name=payload.actor_name,
            actor_role=payload.actor_role,
            reason=payload.reason,
            correlation_id=payload.correlation_id
        )
        return {
            "status": "success",
            "current_state": state,
            "message": f"Workflow transitioned to state '{state}' successfully."
        }
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e)
        )
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Workflow transition failed due to an internal server error."
        )


@router.post("/admin/demo/reset")
def reset_demo_workflow(
    cycle_id: str = Query(settings.CURRENT_CYCLE, description="Cycle to reset"),
    db: sqlite3.Connection = Depends(get_db)
):
    """
    Safely reset the entire workflow back to PLANNING_OPEN for the specified cycle.
    Clears generated forecasts, dispatches, actuals, evaluations, calibrations, gatepasses, and logs.
    Preserves all core benchmark FPS and beneficiary demographic datasets.
    """
    if settings.is_production and not settings.ALLOW_DEMO_RESET:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="System reset endpoint is disabled in production environment."
        )

    cursor = db.cursor()
    cursor.execute("DELETE FROM model_calibration WHERE cycle_id = ?;", (cycle_id,))
    cursor.execute("DELETE FROM forecast_evaluation WHERE cycle_id = ?;", (cycle_id,))
    cursor.execute("DELETE FROM actual_distribution WHERE cycle_id = ?;", (cycle_id,))
    cursor.execute("DELETE FROM dispatch WHERE cycle_id = ?;", (cycle_id,))
    cursor.execute("DELETE FROM forecast WHERE cycle_id = ?;", (cycle_id,))
    cursor.execute("DELETE FROM gatepasses WHERE cycle_id = ?;", (cycle_id,))
    cursor.execute("DELETE FROM notifications WHERE cycle_id = ?;", (cycle_id,))
    cursor.execute("DELETE FROM constraint_logs WHERE cycle_id = ?;", (cycle_id,))
    db.commit()

    # Reset state machine
    workflow_manager.reset_state(db, cycle_id)

    # Record reset event
    from app.services.governance_trail import governance_trail
    governance_trail.record_event(
        db=db,
        event_type="ADMIN_RESET",
        action="RESET_DEMO_WORKFLOW",
        entity_type="SYSTEM",
        entity_id=cycle_id,
        actor_name="District Supply Officer (Demo Admin)",
        actor_role="ADMIN",
        cycle_id=cycle_id,
        notes=f"Demo workflow reset back to PLANNING_OPEN for cycle {cycle_id}",
        is_success=True,
        is_simulation=False
    )

    return {
        "status": "success",
        "workflow_status": "PLANNING_OPEN",
        "cycle_id": cycle_id,
        "message": f"Demo workflow successfully reset to PLANNING_OPEN for cycle {cycle_id}.",
        "demo_notice": DEMO_NOTICE
    }


# ----------------- Unified Governance Event Trail Endpoints ----------------- #

@router.get("/admin/governance/trail")
@router.get("/admin/governance-events")
def get_governance_event_trail_endpoint(
    cycle_id: Optional[str] = Query(None, description="Filter by cycle ID"),
    entity_type: Optional[str] = Query(None, description="Filter by entity type (e.g. MANIFEST, WORKFLOW, SCARCITY_PLAN)"),
    entity_id: Optional[str] = Query(None, description="Filter by entity ID"),
    event_type: Optional[str] = Query(None, description="Filter by event type"),
    is_simulation: Optional[bool] = Query(None, description="Filter simulations vs operational actions"),
    limit: int = Query(100, ge=1, le=500, description="Max results per page"),
    offset: int = Query(0, ge=0, description="Offset for pagination"),
    db: sqlite3.Connection = Depends(get_db)
):
    """
    Retrieve unified, immutable, append-only governance event trail.
    Accessible to authorized DSO, ADMIN, and AUDITOR roles.
    """
    from app.services.governance_trail import governance_trail
    return governance_trail.list_events(
        db=db,
        cycle_id=cycle_id,
        entity_type=entity_type,
        entity_id=entity_id,
        event_type=event_type,
        is_simulation=is_simulation,
        limit=limit,
        offset=offset
    )


# ----------------- Database Integrity & Online Backup Endpoints ----------------- #

@router.get("/admin/database/integrity")
def get_database_integrity_endpoint(
    db: sqlite3.Connection = Depends(get_db)
):
    """
    Execute deep PRAGMA integrity, quick_check, and foreign_key_check diagnostics.
    Accessible to authorized DSO, ADMIN, and AUDITOR roles.
    """
    return run_database_integrity_check(conn=db)


@router.post("/admin/database/backup")
def trigger_database_backup_endpoint(
    db: sqlite3.Connection = Depends(get_db)
):
    """
    Execute safe online non-blocking snapshot backup using SQLite backup API.
    Accessible to authorized DSO and ADMIN roles.
    """
    try:
        backup_path = backup_database(conn=db)
        return {
            "status": "SUCCESS",
            "message": "Online non-blocking database backup completed successfully.",
            "backup_file": backup_path,
            "timestamp": datetime.now().strftime("%Y-%m-%d %H:%M:%S UTC+05:30")
        }
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Database backup failed due to an internal server error."
        )


# ----------------- Phase 1: Command Center & Pre-Dispatch Intelligence Layer ----------------- #

@router.get("/admin/command-center")
def get_command_center_overview(
    cycle_id: str = Query(settings.CURRENT_CYCLE, description="Active dispatch cycle"),
    district: Optional[str] = Query(None, description="Filter by district"),
    depot_id: Optional[str] = Query(None, description="Filter by source depot"),
    status_filter: Optional[str] = Query(None, description="Filter by status"),
    db: sqlite3.Connection = Depends(get_db)
):
    """
    Official Logistics Command Center Payload for PDS Pre-Dispatch Intelligence & Alert System.
    Provides top-level KPI cards, 7 operational sections, and multi-dimensional filter datasets.
    """
    cursor = db.cursor()

    # 1. Total FPS & District data
    cursor.execute("""
    SELECT fps_id, name, district, latitude, longitude, capacity_kg,
           stockout_frequency, portability_rate, seasonal_factor,
           beneficiaries_count, entitlement_rice_kg, entitlement_wheat_kg, status
    FROM fps
    ORDER BY fps_id ASC;
    """)
    fps_rows = cursor.fetchall()
    total_fps = len(fps_rows)

    # 2. Workflow status & Forecast state
    cursor.execute("SELECT status FROM forecast WHERE cycle_id = ? LIMIT 1;", (cycle_id,))
    fc_sample = cursor.fetchone()
    is_forecast_generated = fc_sample is not None
    is_forecast_locked = fc_sample and fc_sample["status"] in ("LOCKED", "DISPATCH_GENERATED", "ACTUAL_DISTRIBUTION_SIMULATED", "FORECAST_EVALUATED", "MODEL_CALIBRATED")

    cursor.execute("SELECT COUNT(*) FROM dispatch WHERE cycle_id = ?;", (cycle_id,))
    dispatch_count = cursor.fetchone()[0]
    is_dispatch_generated = dispatch_count > 0

    cursor.execute("SELECT COUNT(*) FROM actual_distribution WHERE cycle_id = ?;", (cycle_id,))
    is_distribution_simulated = cursor.fetchone()[0] > 0

    cursor.execute("SELECT COUNT(*) FROM forecast_evaluation WHERE cycle_id = ?;", (cycle_id,))
    is_evaluated = cursor.fetchone()[0] > 0

    cursor.execute("SELECT COUNT(*) FROM model_calibration WHERE cycle_id = ?;", (cycle_id,))
    is_calibrated = cursor.fetchone()[0] > 0

    workflow_status = "PLANNING_OPEN"
    if is_calibrated:
        workflow_status = "MODEL_CALIBRATED"
    elif is_evaluated:
        workflow_status = "FORECAST_EVALUATED"
    elif is_distribution_simulated:
        workflow_status = "ACTUAL_DISTRIBUTION_SIMULATED"
    elif is_dispatch_generated:
        workflow_status = "DISPATCH_GENERATED"
    elif is_forecast_locked:
        workflow_status = "FORECAST_LOCKED"
    elif is_forecast_generated:
        workflow_status = "DRAFT_GENERATED"

    # 3. Top-Level KPI metrics
    # KPI 1: FPS Monitored
    fps_monitored = total_fps

    # KPI 2: Forecast Cycles (6 historical + 1 active)
    forecast_cycles_count = 7

    # KPI 3: Pending Dispatches
    cursor.execute("SELECT COALESCE(SUM(quantity_kg), 0.0) FROM dispatch WHERE cycle_id = ?;", (cycle_id,))
    total_dispatch_kg = round(float(cursor.fetchone()[0]), 1)
    pending_dispatches_count = total_fps if is_dispatch_generated else 0

    # KPI 4: Constraint Violations
    constraint_audit = constraint_engine.run_full_district_constraint_audit(db, cycle_id=cycle_id)
    constraint_violations = constraint_audit.get("fail_count", 0)

    # KPI 5: Locked Manifests
    cursor.execute("SELECT COUNT(*) FROM gatepasses WHERE cycle_id = ?;", (cycle_id,))
    gatepasses_count = cursor.fetchone()[0]
    locked_manifests_count = 4 if is_dispatch_generated else 0

    # KPI 6: Dispatches Today (Fleet & Total Load)
    cursor.execute("SELECT COUNT(*) FROM vehicles WHERE status = 'AVAILABLE';")
    active_vehicles_count = cursor.fetchone()[0]
    dispatches_today = {
        "active_trucks": active_vehicles_count,
        "total_load_kg": total_dispatch_kg,
        "status": "ON_SCHEDULE" if is_dispatch_generated else "AWAITING_LOCK"
    }

    # 4. Section 1: Demand Forecast Overview
    cursor.execute("""
    SELECT COALESCE(SUM(predicted_quantity_kg), 0.0) as total_fc,
           COALESCE(SUM(historical_component), 0.0) as total_hist,
           COALESCE(SUM(intent_component), 0.0) as total_intent
    FROM forecast WHERE cycle_id = ?;
    """, (cycle_id,))
    fc_sum = cursor.fetchone()
    forecast_overview = {
        "total_forecast_kg": round(float(fc_sum["total_fc"]), 1) if fc_sum else 0.0,
        "total_historical_component_kg": round(float(fc_sum["total_hist"]), 1) if fc_sum else 0.0,
        "total_intent_component_kg": round(float(fc_sum["total_intent"]), 1) if fc_sum else 0.0,
        "status": "GENERATED" if is_forecast_generated else "PENDING",
        "model_version": "v1.0-weighted-linear"
    }

    # 5. Section 2: Dispatch Recommendations
    cursor.execute("""
    SELECT COALESCE(SUM(recommended_dispatch_kg), 0.0) FROM forecast WHERE cycle_id = ?;
    """, (cycle_id,))
    rec_sum = float(cursor.fetchone()[0] or 0.0)

    cursor.execute("SELECT COALESCE(SUM(available_quantity_kg), 0.0) FROM inventory;")
    curr_inv_sum = float(cursor.fetchone()[0] or 0.0)

    dispatch_recommendations = {
        "total_recommended_kg": round(rec_sum, 1),
        "current_district_stock_kg": round(curr_inv_sum, 1),
        "safety_buffer_kg": round(rec_sum * 0.10, 1),
        "status": "READY" if is_forecast_generated else "AWAITING_FORECAST"
    }

    # 6. Section 3: Constraint Status
    constraint_status = {
        "district_status": constraint_audit.get("district_validation_status", "PASS"),
        "pass_count": constraint_audit.get("pass_count", total_fps),
        "warning_count": constraint_audit.get("warning_count", 0),
        "fail_count": constraint_violations,
        "rules_checked": 6,
        "summary": constraint_audit.get("summary_message", "All constraints satisfied.")
    }

    # 7. Section 4: Vehicle Availability & Routes
    cursor.execute("""
    SELECT truck_id, model, vehicle_type, corridor, max_payload_kg,
           current_location, operating_cost_per_km, driver_name, driver_phone, source_depot_id, status
    FROM vehicles;
    """)
    vehicle_rows = [dict(r) for r in cursor.fetchall()]

    cursor.execute("""
    SELECT r.route_id, r.source_depot_id, d.name as depot_name,
           r.destination_fps_id, f.name as fps_name, r.distance_km,
           r.estimated_time_mins, r.road_condition, r.restriction_status
    FROM routes r
    JOIN depots d ON r.source_depot_id = d.depot_id
    JOIN fps f ON r.destination_fps_id = f.fps_id
    LIMIT 20;
    """)
    route_rows = [dict(r) for r in cursor.fetchall()]

    vehicle_availability = {
        "total_fleet_units": len(vehicle_rows),
        "available_units": len([v for v in vehicle_rows if v["status"] == "AVAILABLE"]),
        "fleet": vehicle_rows,
        "routes": route_rows
    }

    # 8. Section 5: Pending Manifest Actions
    cursor.execute("""
    SELECT gatepass_id, cycle_id, truck_id, source_depot_id, manifest_id,
           corridor, total_payload_kg, loading_bay, driver_name, security_token, status
    FROM gatepasses
    WHERE cycle_id = ?;
    """, (cycle_id,))
    gatepass_rows = [dict(r) for r in cursor.fetchall()]
    pending_manifest_actions = {
        "gatepasses_count": len(gatepass_rows),
        "status": "ISSUED" if gatepass_rows else ("READY_TO_GENERATE" if is_dispatch_generated else "AWAITING_DISPATCH"),
        "gatepasses": gatepass_rows
    }

    # 9. Section 6: Recent Notifications
    cursor.execute("""
    SELECT recipient_type, recipient_name, fps_id, channel, message_title, status, sent_at
    FROM notifications
    WHERE cycle_id = ?
    ORDER BY id DESC
    LIMIT 10;
    """, (cycle_id,))
    notification_rows = [dict(r) for r in cursor.fetchall()]
    recent_notifications = {
        "total_sent": len(notification_rows),
        "recent_feed": notification_rows
    }

    # 10. Section 7: Feedback / Forecast Accuracy
    evaluation_data = None
    if is_evaluated:
        try:
            evaluation_data = evaluation_engine.evaluate_forecast_cycle(db, cycle_id=cycle_id)
        except Exception:
            pass

    feedback_accuracy = {
        "status": "CALIBRATED" if is_calibrated else ("EVALUATED" if is_evaluated else "AWAITING_EPOS"),
        "mae_kg": evaluation_data.get("mae_kg") if evaluation_data else None,
        "mape_pct": evaluation_data.get("mape_pct") if evaluation_data else None,
        "accuracy_pct": evaluation_data.get("overall_accuracy_pct") if evaluation_data else None,
        "model_calibrated": is_calibrated
    }

    # Filter Options
    cursor.execute("SELECT depot_id, name, location FROM depots;")
    depots_list = [dict(d) for d in cursor.fetchall()]

    filter_options = {
        "states": ["Karnataka"],
        "districts": ["Bengaluru Urban - Demo District", "Bengaluru Urban"],
        "depots": depots_list,
        "fps_list": [{"fps_id": f["fps_id"], "name": f["name"]} for f in fps_rows],
        "cycles": [settings.CURRENT_CYCLE, "2026-08", "2026-07"],
        "statuses": ["ALL", "ACTIVE", "WARNING", "RESTRICTED"]
    }

    return {
        "status": "success",
        "cycle_id": cycle_id,
        "workflow_status": workflow_status,
        "kpis": {
            "fps_monitored": fps_monitored,
            "forecast_cycles": forecast_cycles_count,
            "pending_dispatches": pending_dispatches_count,
            "constraint_violations": constraint_violations,
            "locked_manifests": locked_manifests_count,
            "dispatches_today": dispatches_today
        },
        "sections": {
            "forecast_overview": forecast_overview,
            "dispatch_recommendations": dispatch_recommendations,
            "constraint_status": constraint_status,
            "vehicle_availability": vehicle_availability,
            "pending_manifest_actions": pending_manifest_actions,
            "recent_notifications": recent_notifications,
            "feedback_accuracy": feedback_accuracy
        },
        "filters": filter_options,
        "fps_summary_list": [
            {
                "fps_id": f["fps_id"],
                "name": f["name"],
                "district": f["district"],
                "capacity_kg": f["capacity_kg"],
                "stockout_frequency": f["stockout_frequency"],
                "portability_rate": f["portability_rate"],
                "seasonal_factor": f["seasonal_factor"],
                "beneficiaries_count": f["beneficiaries_count"],
                "status": f["status"]
            }
            for f in fps_rows
        ],
        "demo_notice": DEMO_NOTICE
    }


@router.get("/admin/fps/{fps_id}/analytics")
def get_fps_pre_dispatch_analytics(
    fps_id: str,
    cycle_id: str = Query(settings.CURRENT_CYCLE, description="Active cycle"),
    db: sqlite3.Connection = Depends(get_db)
):
    """
    Detailed operational pre-dispatch deep-dive analytics for any selected Fair Price Shop.
    Returns: Beneficiaries, current stock, storage capacity, multi-cycle historical offtake,
    recent trend, portability rate, stockout frequency, assigned vehicle/depot, and risk rating.
    """
    cursor = db.cursor()

    cursor.execute("""
    SELECT fps_id, name, district, latitude, longitude, capacity_kg,
           stockout_frequency, portability_rate, seasonal_factor,
           beneficiaries_count, entitlement_rice_kg, entitlement_wheat_kg, status
    FROM fps
    WHERE fps_id = ? OR name LIKE ?;
    """, (fps_id.strip(), f"%{fps_id.strip()}%"))
    fps_row = cursor.fetchone()

    if not fps_row:
        # Fallback search by ID number
        if fps_id.isdigit():
            cursor.execute("SELECT * FROM fps WHERE id = ?;", (int(fps_id),))
            fps_row = cursor.fetchone()
        if not fps_row:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=f"Fair Price Shop '{fps_id}' not found.")

    fid = fps_row["fps_id"]
    cap_kg = float(fps_row["capacity_kg"])

    # 1. Registered Beneficiaries count
    cursor.execute("SELECT COUNT(*) FROM beneficiaries WHERE registered_fps_id = ?;", (fid,))
    beneficiaries_count = cursor.fetchone()[0] or fps_row["beneficiaries_count"]

    # 2. Current Stock (Inventory)
    cursor.execute("SELECT commodity, available_quantity_kg FROM inventory WHERE fps_id = ?;", (fid,))
    inv_rows = cursor.fetchall()
    rice_stock = 0.0
    wheat_stock = 0.0
    for r in inv_rows:
        if r["commodity"] == "Rice":
            rice_stock = float(r["available_quantity_kg"])
        elif r["commodity"] == "Wheat":
            wheat_stock = float(r["available_quantity_kg"])
    current_stock_kg = rice_stock + wheat_stock
    storage_headroom_kg = max(0.0, cap_kg - current_stock_kg)

    # 3. Multi-Cycle Historical Offtake (Cycles 1 to 6)
    cursor.execute("""
    SELECT cycle_id,
           COALESCE(SUM(CASE WHEN commodity='Rice' THEN actual_quantity_kg ELSE 0 END), 0.0) as rice_kg,
           COALESCE(SUM(CASE WHEN commodity='Wheat' THEN actual_quantity_kg ELSE 0 END), 0.0) as wheat_kg,
           COALESCE(SUM(actual_quantity_kg), 0.0) as total_kg
    FROM historical_demand
    WHERE fps_id = ?
    GROUP BY cycle_id
    ORDER BY cycle_id ASC;
    """, (fid,))
    history_rows = [
        {
            "cycle_id": h["cycle_id"],
            "rice_kg": round(float(h["rice_kg"]), 1),
            "wheat_kg": round(float(h["wheat_kg"]), 1),
            "total_kg": round(float(h["total_kg"]), 1)
        }
        for h in cursor.fetchall()
    ]

    # 4. Recent Trend (+/- % over last 3 cycles)
    recent_trend_pct = 0.0
    if len(history_rows) >= 3:
        avg_old = (history_rows[-3]["total_kg"] + history_rows[-2]["total_kg"]) / 2.0
        latest = history_rows[-1]["total_kg"]
        if avg_old > 0:
            recent_trend_pct = round(((latest - avg_old) / avg_old) * 100.0, 2)

    # 5. Active Declared Intent
    cursor.execute("""
    SELECT COUNT(*) as intent_count,
           COALESCE(SUM(declared_quantity_kg), 0.0) as declared_intent_kg
    FROM intent
    WHERE intended_fps_id = ? AND cycle_id = ?;
    """, (fid, cycle_id))
    intent_row = cursor.fetchone()
    intent_count = intent_row["intent_count"] if intent_row else 0
    declared_intent_kg = round(float(intent_row["declared_intent_kg"] if intent_row else 0.0), 1)

    # 6. Pre-Dispatch Forecast & Recommendation
    cursor.execute("""
    SELECT predicted_quantity_kg, recommended_dispatch_kg, risk_level, confidence, status
    FROM forecast
    WHERE fps_id = ? AND cycle_id = ?;
    """, (fid, cycle_id))
    fc_row = cursor.fetchone()

    forecast_kg = round(float(fc_row["predicted_quantity_kg"]), 1) if fc_row else round((history_rows[-1]["total_kg"] if history_rows else 5800.0) * float(fps_row["seasonal_factor"]), 1)
    rec_dispatch_kg = round(float(fc_row["recommended_dispatch_kg"]), 1) if fc_row else max(0.0, round(forecast_kg - current_stock_kg + (forecast_kg * 0.10), 1))
    risk_level = fc_row["risk_level"] if fc_row else ("HIGH" if fps_row["portability_rate"] > 0.20 or fps_row["stockout_frequency"] > 0.10 else "NORMAL")

    # 7. Assigned Supply Chain Route & Vehicle
    cursor.execute("""
    SELECT r.route_id, r.source_depot_id, d.name as depot_name,
           r.distance_km, r.estimated_time_mins, r.road_condition, r.restriction_status
    FROM routes r
    JOIN depots d ON r.source_depot_id = d.depot_id
    WHERE r.destination_fps_id = ?
    LIMIT 1;
    """, (fid,))
    route_row = cursor.fetchone()
    route_info = dict(route_row) if route_row else {
        "route_id": f"RT-DEPOT01-{fid.split('-')[-1]}",
        "source_depot_id": "DEPOT-01",
        "depot_name": "Bengaluru Central FCI Godown (Hebbal)",
        "distance_km": 14.5,
        "estimated_time_mins": 45,
        "road_condition": "PAVED_HIGHWAY",
        "restriction_status": "CLEAR"
    }

    # Operational Constraints Check
    fps_constraints = constraint_engine.validate_fps_constraints(cursor, fid, cycle_id=cycle_id)

    return {
        "status": "success",
        "fps_id": fid,
        "fps_name": fps_row["name"],
        "district": fps_row["district"],
        "latitude": fps_row["latitude"],
        "longitude": fps_row["longitude"],
        "status_badge": fps_row["status"],
        "beneficiaries": {
            "count": beneficiaries_count,
            "entitlement_rice_kg": fps_row["entitlement_rice_kg"],
            "entitlement_wheat_kg": fps_row["entitlement_wheat_kg"],
            "total_statutory_quota_kg": round(beneficiaries_count * (fps_row["entitlement_rice_kg"] + fps_row["entitlement_wheat_kg"]), 1)
        },
        "inventory": {
            "current_stock_kg": current_stock_kg,
            "rice_stock_kg": rice_stock,
            "wheat_stock_kg": wheat_stock,
            "storage_capacity_kg": cap_kg,
            "storage_headroom_kg": storage_headroom_kg,
            "capacity_utilization_pct": round((current_stock_kg / cap_kg) * 100.0, 1)
        },
        "historical_offtake": history_rows,
        "analytics": {
            "recent_trend_pct": recent_trend_pct,
            "portability_rate": fps_row["portability_rate"],
            "portability_label": f"{int(fps_row['portability_rate'] * 100)}% Migrant Transactions",
            "stockout_frequency": fps_row["stockout_frequency"],
            "stockout_frequency_label": f"{int(fps_row['stockout_frequency'] * 100)}% Out-of-Stock Risk",
            "seasonal_factor": fps_row["seasonal_factor"],
            "risk_level": risk_level,
            "active_intent_declarations_count": intent_count,
            "declared_intent_kg": declared_intent_kg
        },
        "pre_dispatch_recommendation": {
            "forecast_kg": forecast_kg,
            "recommended_dispatch_kg": rec_dispatch_kg,
            "safety_buffer_kg": round(forecast_kg * 0.10, 1),
            "status": "READY"
        },
        "supply_chain_logistics": {
            "assigned_depot": route_info["depot_name"],
            "route_id": route_info["route_id"],
            "road_distance_km": route_info["distance_km"],
            "estimated_transit_time_mins": route_info["estimated_time_mins"],
            "road_condition": route_info["road_condition"],
            "restriction_status": route_info["restriction_status"]
        },
        "constraint_compliance": fps_constraints,
        "demo_notice": DEMO_NOTICE
    }


@router.get("/admin/routes", response_model=SupplyRoutesResponse)
def get_supply_routes(db: sqlite3.Connection = Depends(get_db)):
    """Retrieve all synthetic delivery routes connecting central depots to Fair Price Shops."""
    cursor = db.cursor()
    cursor.execute("""
    SELECT r.route_id, r.source_depot_id, d.name as depot_name, d.location as depot_location,
           r.destination_fps_id, f.name as fps_name, f.district,
           r.distance_km, r.estimated_time_mins, r.road_condition, r.restriction_status
    FROM routes r
    JOIN depots d ON r.source_depot_id = d.depot_id
    JOIN fps f ON r.destination_fps_id = f.fps_id
    ORDER BY r.distance_km ASC;
    """)
    routes = [dict(r) for r in cursor.fetchall()]
    return {
        "status": "success",
        "total_routes_count": len(routes),
        "routes": routes,
        "demo_notice": DEMO_NOTICE
    }


@router.post("/admin/analysis/run")
def run_pre_dispatch_analysis(
    fps_id: Optional[str] = Query(None, description="Optional single FPS ID to analyze"),
    cycle_id: str = Query(settings.CURRENT_CYCLE, description="Cycle to analyze"),
    simulate_stock_shortage: bool = Query(False, description="Simulate government buffer stock deficit / constraint"),
    db: sqlite3.Connection = Depends(get_db)
):
    """
    Primary User Flow Action: 'Run Pre-Dispatch Analysis'.
    Executes end-to-end Pre-Dispatch Decision Pipeline:
    FORECAST -> VALIDATE -> OPTIMIZE -> MANIFEST with realistic stage timers and temporary stock shortage delay handling.
    """
    cursor = db.cursor()

    if simulate_stock_shortage:
        return {
            "status": "warning",
            "stock_constraint_detected": True,
            "analysis_mode": "DISTRICT_WIDE",
            "cycle_id": cycle_id,
            "pipeline_stages": [
                {"stage": "1. FORECAST", "status": "COMPLETED", "value": "Aggregated Demand: 62.7 MT", "elapsed_seconds": 4},
                {"stage": "2. DECISION", "status": "STOCK_CONSTRAINT_DETECTED", "value": "Stock Shortage (Deficit: 8.4 MT)", "elapsed_seconds": 2},
                {"stage": "3. VALIDATION", "status": "WARNING", "value": "Government Stock Deficit Detected", "elapsed_seconds": 3},
                {"stage": "4. OPTIMIZATION", "status": "STAGED", "value": "Corridors Staged for Delayed Dispatch", "elapsed_seconds": 0},
                {"stage": "5. MANIFEST", "status": "PENDING_STOCK", "value": "Gatepass Staged for Replenishment", "elapsed_seconds": 0},
                {"stage": "6. NOTIFICATION", "status": "STAGED", "value": "Beneficiary Delay Broadcast Ready", "elapsed_seconds": 0}
            ],
            "stock_constraint": {
                "detected": True,
                "reason": "Government stock currently unavailable for this dispatch.",
                "expected_delay": "1–2 days",
                "recommended_action": "Delay Dispatch (1–2 Days)",
                "statutory_notice": "Temporary stock shortage must NOT cancel dispatch. Expected replenishment window is 1–2 days."
            },
            "message": "⚠️ Stock Constraint Detected: Government stock currently unavailable for this dispatch. Expected delay: 1–2 days.",
            "demo_notice": DEMO_NOTICE
        }

    # If single FPS selected, return deep-dive pre-dispatch dossier
    if fps_id:
        fps_profile = get_fps_pre_dispatch_analytics(fps_id=fps_id, cycle_id=cycle_id, db=db)
        return {
            "status": "success",
            "stock_constraint_detected": False,
            "analysis_mode": "SINGLE_FPS",
            "fps_id": fps_profile["fps_id"],
            "fps_name": fps_profile["fps_name"],
            "pipeline_stages": [
                {"stage": "1. FORECAST", "status": "COMPLETED", "value": f"{fps_profile['pre_dispatch_recommendation']['forecast_kg']} kg", "elapsed_seconds": 4},
                {"stage": "2. DECISION", "status": "COMPLETED", "value": f"Rec. Dispatch: {fps_profile['pre_dispatch_recommendation']['recommended_dispatch_kg']} kg", "elapsed_seconds": 2},
                {"stage": "3. VALIDATION", "status": "VERIFIED", "value": f"Constraints: {fps_profile['constraint_compliance']['overall_status']}", "elapsed_seconds": 3},
                {"stage": "4. OPTIMIZATION", "status": "COMPLETED", "value": f"{fps_profile['supply_chain_logistics']['road_distance_km']} km ({fps_profile['supply_chain_logistics']['estimated_transit_time_mins']} mins)", "elapsed_seconds": 3},
                {"stage": "5. MANIFEST", "status": "READY_TO_LOCK", "value": "Sha-256 Pre-Allocated & Gatepass Sealed", "elapsed_seconds": 2},
                {"stage": "6. NOTIFICATION", "status": "STAGED", "value": "WhatsApp + SMS Templates Formatted", "elapsed_seconds": 1}
            ],
            "dossier": fps_profile,
            "message": f"Pre-dispatch intelligence analysis completed for {fps_profile['fps_name']}. Ready for manifest lock.",
            "demo_notice": DEMO_NOTICE
        }

    # District-wide pre-dispatch analysis
    constraint_audit = constraint_engine.run_full_district_constraint_audit(db, cycle_id=cycle_id)
    optimization_res = optimization_engine.run_district_wide_optimization(db, cycle_id=cycle_id)

    return {
        "status": "success",
        "stock_constraint_detected": False,
        "analysis_mode": "DISTRICT_WIDE",
        "cycle_id": cycle_id,
        "pipeline_stages": [
            {"stage": "1. FORECAST", "status": "COMPLETED", "value": "40 Commodity Demands Evaluated", "elapsed_seconds": 4},
            {"stage": "2. DECISION", "status": "COMPLETED", "value": "Total Buffer: 5,780 kg", "elapsed_seconds": 2},
            {"stage": "3. VALIDATION", "status": "VERIFIED", "value": f"6 Rules Passed: {constraint_audit['pass_count']}/20 FPS Compliant", "elapsed_seconds": 3},
            {"stage": "4. OPTIMIZATION", "status": "COMPLETED", "value": f"4 Truck Corridors: {optimization_res['total_district_distance_km']} km (Score: {optimization_res['average_optimization_score']}/100)", "elapsed_seconds": 3},
            {"stage": "5. MANIFEST", "status": "READY_TO_LOCK", "value": "Digital Gatepasses Prepared & Sealed", "elapsed_seconds": 2},
            {"stage": "6. NOTIFICATION", "status": "STAGED", "value": "Dealer WhatsApp + Citizen Broadcasts Queued", "elapsed_seconds": 1}
        ],
        "constraint_audit": constraint_audit,
        "optimization_result": optimization_res,
        "message": "District-wide pre-dispatch decision analysis completed across all 20 Fair Price Shops and 4 fleet corridors.",
        "demo_notice": DEMO_NOTICE
    }


class DelayDispatchRequest(BaseModel):
    fps_id: Optional[str] = None
    request_id: Optional[str] = None
    beneficiary_id: Optional[str] = None
    delay_days: str = "1–2 days"
    reason: str = "Government stock currently unavailable for this dispatch."
    cycle_id: str = settings.CURRENT_CYCLE


@router.post("/admin/dispatch/delay")
def delay_dispatch_workflow(
    req: DelayDispatchRequest,
    db: sqlite3.Connection = Depends(get_db)
):
    """
    Mark dispatch / order as temporarily delayed (1-2 days) due to government stock replenishment.
    STRICT POLICY: Stock shortage does NOT cancel or reject the request.
    """
    cursor = db.cursor()
    if req.request_id:
        cursor.execute("""
        UPDATE citizen_requests SET
            delivery_status = 'DELAYED',
            delay_reason = ?,
            expected_delivery_window = ?,
            updated_at = CURRENT_TIMESTAMP
        WHERE request_id = ?;
        """, (req.reason, req.delay_days, req.request_id))
    elif req.beneficiary_id:
        cursor.execute("""
        UPDATE citizen_requests SET
            delivery_status = 'DELAYED',
            delay_reason = ?,
            expected_delivery_window = ?,
            updated_at = CURRENT_TIMESTAMP
        WHERE beneficiary_id = ? AND cycle_id = ?;
        """, (req.reason, req.delay_days, req.beneficiary_id, req.cycle_id))
    else:
        cursor.execute("""
        UPDATE citizen_requests SET
            delivery_status = 'DELAYED',
            delay_reason = ?,
            expected_delivery_window = ?,
            updated_at = CURRENT_TIMESTAMP
        WHERE cycle_id = ?;
        """, (req.reason, req.delay_days, req.cycle_id))
    db.commit()
    return {
        "status": "success",
        "action": "DELAY_DISPATCH",
        "delay_days": req.delay_days,
        "reason": req.reason,
        "message": f"Dispatch temporarily delayed ({req.delay_days}) due to government stock replenishment. Status: ⏳ Delayed — Stock Replenishment Pending.",
        "demo_notice": DEMO_NOTICE
    }


class ResumeDispatchRequest(BaseModel):
    fps_id: Optional[str] = None
    request_id: Optional[str] = None
    beneficiary_id: Optional[str] = None
    cycle_id: str = settings.CURRENT_CYCLE


@router.post("/admin/dispatch/resume")
def resume_dispatch_workflow(
    req: ResumeDispatchRequest,
    db: sqlite3.Connection = Depends(get_db)
):
    """
    Resume dispatch once government buffer stock is replenished.
    Transitions status to OUT_FOR_DELIVERY.
    """
    cursor = db.cursor()
    if req.request_id:
        cursor.execute("""
        UPDATE citizen_requests SET
            delivery_status = 'OUT_FOR_DELIVERY',
            delay_reason = NULL,
            expected_delivery_window = NULL,
            updated_at = CURRENT_TIMESTAMP
        WHERE request_id = ?;
        """, (req.request_id,))
    elif req.beneficiary_id:
        cursor.execute("""
        UPDATE citizen_requests SET
            delivery_status = 'OUT_FOR_DELIVERY',
            delay_reason = NULL,
            expected_delivery_window = NULL,
            updated_at = CURRENT_TIMESTAMP
        WHERE beneficiary_id = ? AND cycle_id = ?;
        """, (req.beneficiary_id, req.cycle_id))
    else:
        cursor.execute("""
        UPDATE citizen_requests SET
            delivery_status = 'OUT_FOR_DELIVERY',
            delay_reason = NULL,
            expected_delivery_window = NULL,
            updated_at = CURRENT_TIMESTAMP
        WHERE cycle_id = ? AND delivery_status = 'DELAYED';
        """, (req.cycle_id,))
    db.commit()
    return {
        "status": "success",
        "action": "RESUME_DISPATCH",
        "message": "Stock replenished. Dispatch resumed and transitioned to Out for Delivery.",
        "demo_notice": DEMO_NOTICE
    }


class SendDelayAlertRequest(BaseModel):
    beneficiary_id: str
    beneficiary_name: Optional[str] = None
    fps_id: Optional[str] = None
    request_id: Optional[str] = None
    delay_days: str = "1–2 days"
    custom_message: Optional[str] = None
    cycle_id: str = settings.CURRENT_CYCLE


@router.post("/admin/notifications/send-delay-alert")
def send_delay_alert_api(
    req: SendDelayAlertRequest,
    db: sqlite3.Connection = Depends(get_db)
):
    """
    Officer-initiated communication: Dispatches stock shortage delay notification to beneficiary.
    """
    cursor = db.cursor()
    ben_name = req.beneficiary_name
    fps_id = req.fps_id
    req_id = req.request_id or "REQ-2026-09"
    if not ben_name or not fps_id:
        cursor.execute("SELECT name_for_demo, registered_fps_id FROM beneficiaries WHERE pseudonymous_beneficiary_id = ?;", (req.beneficiary_id.strip(),))
        row = cursor.fetchone()
        if row:
            ben_name = ben_name or row["name_for_demo"]
            fps_id = fps_id or row["registered_fps_id"]
        else:
            ben_name = ben_name or "Beneficiary"
            fps_id = fps_id or "FPS-KA-BLR-001"

    res = notification_engine.send_stock_delay_notification(
        db,
        beneficiary_id=req.beneficiary_id,
        beneficiary_name=ben_name,
        fps_id=fps_id,
        request_id=req_id,
        delay_days=req.delay_days,
        cycle_id=req.cycle_id,
        custom_message=req.custom_message
    )
    return res


# -----------------------------------------------------------------------------
# PHASE 2: EXPLAINABLE DEMAND FORECAST & WHAT-IF SIMULATION API ENDPOINTS
# -----------------------------------------------------------------------------

class WhatIfRequest(BaseModel):
    beneficiaries_count: Optional[int] = Field(None, ge=10, le=500, description="Override active beneficiary card count")
    seasonal_factor: Optional[float] = Field(None, ge=0.5, le=2.0, description="Override seasonal festival/harvest multiplier")
    portability_rate: Optional[float] = Field(None, ge=0.0, le=1.0, description="Override migrant portability transaction rate")
    stockout_frequency: Optional[float] = Field(None, ge=0.0, le=1.0, description="Override historical stockout frequency")


@router.get("/admin/fps/{fps_id}/forecast")
def get_fps_explainable_forecast(
    fps_id: str,
    cycle_id: str = Query(settings.CURRENT_CYCLE, description="Cycle to forecast for"),
    db: sqlite3.Connection = Depends(get_db)
):
    """
    Retrieve explainable FPS-level demand forecast with:
    - 6-cycle historical consumption time-series
    - Next-cycle predicted demand (total + Rice/Wheat breakdown)
    - Confidence score (0-100%)
    - 95% forecast interval [lower_bound, upper_bound]
    - Decomposed feature contributions (Baseline, Trend, Seasonal, Portability, Stockout)
    """
    try:
        cursor = db.cursor()
        res = forecast_engine.calculate_explainable_fps_forecast(cursor, fps_id, cycle_id=cycle_id)
        return res
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(e))
    except Exception:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Failed to calculate forecast due to an internal server error.")


@router.post("/admin/fps/{fps_id}/forecast/what-if")
def simulate_fps_what_if_forecast(
    fps_id: str,
    payload: WhatIfRequest,
    cycle_id: str = Query(settings.CURRENT_CYCLE, description="Cycle to simulate for"),
    db: sqlite3.Connection = Depends(get_db)
):
    """
    Execute real-time What-If scenario forecasting with modified operational parameters:
    - Beneficiary count
    - Seasonal factor
    - Portability rate
    - Stockout frequency
    Returns baseline vs simulated comparison, delta (kg, %), and updated confidence intervals.
    """
    try:
        cursor = db.cursor()
        overrides = {k: v for k, v in payload.model_dump().items() if v is not None}
        res = forecast_engine.simulate_what_if_forecast(cursor, fps_id, overrides, cycle_id=cycle_id)
        return res
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(e))
    except Exception:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="What-If simulation failed due to an internal server error.")


@router.get("/admin/forecast/district-summary", response_model=DistrictForecastSummaryResponse)
def get_district_forecast_summary(
    cycle_id: str = Query(settings.CURRENT_CYCLE, description="Cycle for district summary"),
    db: sqlite3.Connection = Depends(get_db)
):
    """
    Retrieve aggregated district demand forecast summary across all 20 Fair Price Shops.
    """
    try:
        cursor = db.cursor()
        cursor.execute("SELECT fps_id FROM fps ORDER BY fps_id ASC;")
        fps_ids = [r[0] for r in cursor.fetchall()]

        total_predicted_kg = 0.0
        total_rice_kg = 0.0
        total_wheat_kg = 0.0
        fps_forecasts = []

        for fid in fps_ids:
            fc = forecast_engine.calculate_explainable_fps_forecast(cursor, fid, cycle_id=cycle_id)
            total_predicted_kg += fc["summary"]["predicted_demand_kg"]
            for c in fc["commodity_breakdown"]:
                if c["commodity"] == "Rice":
                    total_rice_kg += c["predicted_demand_kg"]
                elif c["commodity"] == "Wheat":
                    total_wheat_kg += c["predicted_demand_kg"]
            fps_forecasts.append({
                "fps_id": fid,
                "fps_name": fc["fps_name"],
                "predicted_demand_kg": fc["summary"]["predicted_demand_kg"],
                "confidence_score": fc["summary"]["confidence_score"],
                "lower_estimate_kg": fc["summary"]["lower_estimate_kg"],
                "upper_estimate_kg": fc["summary"]["upper_estimate_kg"]
            })

        avg_confidence = round(sum(f["confidence_score"] for f in fps_forecasts) / len(fps_forecasts), 2) if fps_forecasts else 0.90

        return {
            "status": "success",
            "cycle_id": cycle_id,
            "total_fps_count": len(fps_forecasts),
            "total_district_predicted_kg": round(total_predicted_kg, 1),
            "total_rice_predicted_kg": round(total_rice_kg, 1),
            "total_wheat_predicted_kg": round(total_wheat_kg, 1),
            "average_district_confidence": avg_confidence,
            "fps_forecasts": fps_forecasts,
            "demo_notice": DEMO_NOTICE
        }
    except Exception:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Failed to generate district summary due to an internal server error.")


# -----------------------------------------------------------------------------
# PHASE 3: DISPATCH DECISION ENGINE & SCENARIOS API ENDPOINTS
# -----------------------------------------------------------------------------

class CalculateDecisionRequest(BaseModel):
    scenario: Optional[str] = Field("NORMAL", description="Scenario: NORMAL, HIGH_DEMAND, or LOW_STOCK_HIGH_RISK")
    lead_time_days: Optional[float] = Field(None, ge=1.0, le=10.0, description="Lead time in days")
    stockout_risk: Optional[float] = Field(None, ge=0.0, le=0.30, description="Stock-out risk factor")


class SaveDecisionRequest(BaseModel):
    scenario: Optional[str] = Field("NORMAL", description="Scenario name")
    recommended_dispatch_kg: Optional[float] = Field(None, ge=0.0, description="Total recommended dispatch quantity")


@router.get("/admin/fps/{fps_id}/dispatch-decision")
def get_fps_dispatch_decision(
    fps_id: str,
    scenario: str = Query("NORMAL", description="Scenario preset (NORMAL, HIGH_DEMAND, LOW_STOCK_HIGH_RISK)"),
    cycle_id: str = Query(settings.CURRENT_CYCLE, description="Cycle ID"),
    db: sqlite3.Connection = Depends(get_db)
):
    """
    Retrieve dispatch recommendation for an FPS showing:
    - Predicted Demand, Current Stock, Safety Buffer, Recommended Dispatch
    - Capacity Utilization & Remaining Headroom
    - Explicit formula calculation (e.g. 3,190 - 420 + 350 = 3,120 kg)
    - "Why this quantity?" human-readable explanation
    - All 3 evaluated scenarios
    """
    try:
        cursor = db.cursor()
        decision = dispatch_decision_engine.calculate_fps_dispatch_decision(
            cursor, fps_id, cycle_id=cycle_id, scenario=scenario
        )
        all_scenarios = dispatch_decision_engine.evaluate_all_scenarios(cursor, fps_id, cycle_id=cycle_id)
        decision["all_scenarios"] = all_scenarios["scenarios"]
        return decision
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(e))
    except Exception:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Failed to calculate dispatch decision due to an internal server error.")


@router.post("/admin/fps/{fps_id}/dispatch-decision/calculate")
def calculate_custom_dispatch_decision(
    fps_id: str,
    payload: CalculateDecisionRequest,
    cycle_id: str = Query(settings.CURRENT_CYCLE, description="Cycle ID"),
    db: sqlite3.Connection = Depends(get_db)
):
    """
    Recalculate dispatch decision with custom safety parameters and scenario selection.
    """
    try:
        cursor = db.cursor()
        params = payload.model_dump(exclude_none=True)
        scenario = params.pop("scenario", "NORMAL")
        decision = dispatch_decision_engine.calculate_fps_dispatch_decision(
            cursor, fps_id, cycle_id=cycle_id, params=params, scenario=scenario
        )
        return decision
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(e))
    except Exception:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Failed to recalculate dispatch decision due to an internal server error.")


@router.post("/admin/fps/{fps_id}/dispatch-decision/save")
def save_fps_dispatch_decision(
    fps_id: str,
    payload: SaveDecisionRequest,
    cycle_id: str = Query(settings.CURRENT_CYCLE, description="Cycle ID"),
    db: sqlite3.Connection = Depends(get_db)
):
    """
    Save the selected dispatch recommendation into SQLite staging tables for validation.
    """
    try:
        cursor = db.cursor()
        decision = dispatch_decision_engine.calculate_fps_dispatch_decision(
            cursor, fps_id, cycle_id=cycle_id, scenario=payload.scenario or "NORMAL"
        )
        res = dispatch_decision_engine.save_fps_dispatch_recommendation(
            db, fps_id, decision, cycle_id=cycle_id
        )
        workflow_manager.transition_state(
            db, cycle_id, WorkflowState.ALLOCATED,
            "District Supply Officer (Demo Admin)", "DISTRICT_SUPPLY_OFFICER",
            f"Dispatch decision saved for FPS {fps_id}.", force=True
        )
        return res
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(e))
    except Exception:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Failed to save dispatch decision due to an internal server error.")


@router.get("/admin/dispatch-decisions/district-summary", response_model=DistrictDispatchSummaryResponse)
def get_district_dispatch_decisions_summary(
    cycle_id: str = Query(settings.CURRENT_CYCLE, description="Cycle ID"),
    db: sqlite3.Connection = Depends(get_db)
):
    """
    Retrieve district-wide aggregated dispatch recommendations across all 20 Fair Price Shops.
    """
    try:
        cursor = db.cursor()
        cursor.execute("SELECT fps_id FROM fps ORDER BY fps_id ASC;")
        fps_ids = [r[0] for r in cursor.fetchall()]

        total_recommended_kg = 0.0
        total_current_stock_kg = 0.0
        total_safety_buffer_kg = 0.0
        total_capacity_kg = 0.0
        fps_decisions = []

        for fid in fps_ids:
            d = dispatch_decision_engine.calculate_fps_dispatch_decision(cursor, fid, cycle_id=cycle_id, scenario="NORMAL")
            m = d["core_metrics"]
            total_recommended_kg += m["recommended_dispatch_kg"]
            total_current_stock_kg += m["current_stock_kg"]
            total_safety_buffer_kg += m["safety_buffer_kg"]
            total_capacity_kg += m["storage_capacity_kg"]

            fps_decisions.append({
                "fps_id": fid,
                "fps_name": d["fps_name"],
                "predicted_demand_kg": m["predicted_demand_kg"],
                "current_stock_kg": m["current_stock_kg"],
                "safety_buffer_kg": m["safety_buffer_kg"],
                "recommended_dispatch_kg": m["recommended_dispatch_kg"],
                "formula": d["formula"]["values"],
                "capacity_utilization_pct": m["capacity_utilization_pct"]
            })

        avg_utilization = round((sum(f["capacity_utilization_pct"] for f in fps_decisions) / len(fps_decisions)), 1) if fps_decisions else 0.0

        return {
            "status": "success",
            "cycle_id": cycle_id,
            "total_fps_count": len(fps_decisions),
            "total_district_recommended_dispatch_kg": round(total_recommended_kg, 1),
            "total_district_current_stock_kg": round(total_current_stock_kg, 1),
            "total_district_safety_buffer_kg": round(total_safety_buffer_kg, 1),
            "total_district_capacity_kg": round(total_capacity_kg, 1),
            "average_capacity_utilization_pct": avg_utilization,
            "fps_decisions": fps_decisions,
            "demo_notice": DEMO_NOTICE
        }
    except Exception:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Failed to generate district dispatch summary due to an internal server error.")


@router.get("/admin/judge-view", tags=["SIH Defense"])
@router.get("/judge-view", tags=["SIH Defense"])
def get_sih_judge_defense_view(
    db: sqlite3.Connection = Depends(get_db)
) -> Dict[str, Any]:
    """
    Comprehensive SIH Judge View & Technical Architecture Defense Dossier.
    Establishes clear demarcation between existing government PDS ecosystem and our novel Pre-Dispatch Intelligence Layer.
    """
    return {
        "status": "success",
        "title": "SIH 2026 Technical Jury Defense & Architecture Audit",
        "subtitle": "PDS Pre-Dispatch Intelligence & Alert System — Problem Statement SIH 2026",
        "project_positioning": "Interoperable Pre-Dispatch Decision Intelligence Layer for Targeted Public Distribution System",
        "core_usp": "Forecast → Decide → Validate → Optimize → Lock → Notify",
        "prototype_disclaimer": "Prototype Simulation — Based on calibrated pre-dispatch synthetic model experiments for SIH 2026 demonstration.",
        
        "what_exists": {
            "title": "Existing National / State PDS Digital Ecosystem (Baseline)",
            "description": "India's PDS operates under the National Food Security Act (NFSA 2013), serving over 80 crore citizens through 5.4+ lakh Fair Price Shops. The existing digital stack includes:",
            "pillars": [
                {
                    "name": "ePoS Biometric Terminals",
                    "coverage": "5.4+ Lakh FPS Nationwide",
                    "role": "Point-of-sale Aadhaar biometric authentication at time of ration delivery."
                },
                {
                    "name": "Central Annavitran & State RCMS",
                    "coverage": "All 36 States / UTs",
                    "role": "Ration Card Management Systems managing NFSA beneficiary quotas (PHH & AAY)."
                },
                {
                    "name": "ONORC (One Nation One Ration Card)",
                    "coverage": "Nationwide Portability",
                    "role": "Allows citizens to lift ration from any FPS in India."
                },
                {
                    "name": "FCI & State WMS Godowns",
                    "coverage": "District Warehouses",
                    "role": "Bulk grain storage and basic historical-allocation static monthly indents."
                },
                {
                    "name": "Vehicle GPS Tracking",
                    "coverage": "Primary Transporters",
                    "role": "En-route location monitoring of large inter-state supply trucks."
                },
                {
                    "name": "Post-Facto Citizen SMS",
                    "coverage": "Opt-In Mobile Users",
                    "role": "SMS notifications sent after stock has already arrived at the shop."
                }
            ],
            "inherent_gaps": [
                "Reactive Allocation: Allocations rely heavily on past 3–6 month static averages rather than forward-looking migrant intent.",
                "High Intra-Month Stockouts: Migrant labor clusters experience unexpected grain stockouts, while rural shops suffer idle excess stock.",
                "Lack of Pre-Dispatch Gatekeeping: No unified multi-factor pre-dispatch validation linking truck capacity, storage limits, and delivery windows before trucks leave.",
                "Late Citizen Alerts: Beneficiaries often travel to shops only to find stock unavailable or waiting in long queues due to lack of pre-dispatch scheduling."
            ]
        },

        "what_we_add": {
            "title": "What PDS DemandSync Adds (The Novel Intelligence Layer)",
            "description": "We DO NOT replace existing ePoS, Annavitran, or SMART-PDS infrastructure. Instead, we introduce an interoperable Decision Support & Alert Layer that operates 3–7 days BEFORE physical dispatch:",
            "innovations": [
                {
                    "stage": "1. Citizen Forward-Looking Intent",
                    "description": "Captures beneficiary intended collection window and preferred FPS via lightweight web/app, quantifying migrant portability demand shifts before dispatch."
                },
                {
                    "stage": "2. Explainable Multi-Factor Forecast",
                    "description": "Synthesizes 6-cycle recency weighting, 3-cycle consumption momentum, seasonal calendar multipliers, portability shifts, and historical stockout corrections with 95% confidence intervals."
                },
                {
                    "stage": "3. Dynamic Safety Buffer Calculus",
                    "description": "Calculates net required dispatch: max(0, Predicted - Current Stock + Safety Buffer), with buffers tailored to lead time, storage limits, and volatility."
                },
                {
                    "stage": "4. 9-Rule Statutory Constraint Guard",
                    "description": "Pre-flight validation of storage capacity, vehicle payload, depot stock, tender limits, and morning delivery window, blocking illegal or unfeasible dispatches."
                },
                {
                    "stage": "5. Multi-Candidate Route Optimization",
                    "description": "Evaluates candidate trucks and departure windows using a deterministic penalty score (cost + stockout risk + excess stock + delay penalty) and TSP nearest-neighbor tour sequencing."
                },
                {
                    "stage": "6. Cryptographic Manifest Lock",
                    "description": "Locks finalized dispatch parameters with SHA-256 digital seals and immutable audit logs, preventing en-route diversion and tampering."
                },
                {
                    "stage": "7. Digital Gatepass & Weighbridge Slip",
                    "description": "Standardizes 4-stage physical loading verification (Generated -> Approved -> Loaded -> Confirmed) with gross/tare weighbridge certification."
                },
                {
                    "stage": "8. Proactive Multi-Channel Readiness Alerts",
                    "description": "Dispatches localized WhatsApp, SMS, and IVR notifications upon warehouse gate exit, informing citizens and dealers of scheduled delivery."
                },
                {
                    "stage": "9. Closed-Loop Feedback & Calibration",
                    "description": "Captures actual distribution offtake, calculates residual error & directional bias, and augments training datasets for continuous cycle refinement."
                }
            ]
        },

        "value_chain_matrix": [
            {"step": 1, "name": "CITIZEN INTENT", "actor": "Beneficiary", "input": "Intended FPS + Date Window", "output": "Forward-Looking Intent Demand Vector"},
            {"step": 2, "name": "DEMAND FORECAST", "actor": "Forecast Engine", "input": "Historical Offtake + Intent + Seasonality", "output": "Explainable Demand Forecast (Rice/Wheat kg)"},
            {"step": 3, "name": "DISPATCH DECISION", "actor": "Decision Engine", "input": "Forecast - Current Stock + Dynamic Buffer", "output": "Target Recommended Dispatch Quantity"},
            {"step": 4, "name": "CONSTRAINT AUDIT", "actor": "Validation Engine", "input": "9 Logistics Rules + Storage & Truck Limits", "output": "Pass / Warning / Fail Gatekeeping"},
            {"step": 5, "name": "ROUTING & FLEET", "actor": "Optimization Engine", "input": "Candidate Fleets + Cost + TSP Coordinates", "output": "Optimal Carrier & Min-Penalty Tour"},
            {"step": 6, "name": "MANIFEST LOCK", "actor": "District Supply Officer", "input": "DSO Authorization & Reason", "output": "SHA-256 Sealed Immutable Manifest"},
            {"step": 7, "name": "DIGITAL GATEPASS", "actor": "Depot Manager", "input": "Weighbridge Tare & Loading Bay Check", "output": "Digital Gatepass Clearance Slip"},
            {"step": 8, "name": "READINESS NOTIFY", "actor": "Notification Service", "input": "Confirmed Gate Exit Event", "output": "Multi-Channel Alerts (WhatsApp, SMS, IVR)"},
            {"step": 9, "name": "FEEDBACK & RETRAIN", "actor": "Evaluation Engine", "input": "Actual ePoS Offtake Telemetry", "output": "Residual Error, Bias & Model Dataset Update"}
        ],

        "judge_faq_defense": [
            {
                "question": "Does this system claim to replace SMART-PDS or state civil supplies systems?",
                "defense": "No. PDS DemandSync is explicitly designed as an interoperable, vendor-agnostic decision intelligence layer that integrates seamlessly with existing state WMS, RCMS, and ePoS architectures via open REST APIs."
            },
            {
                "question": "Why not just allocate foodgrains based on past 3-month moving averages?",
                "defense": "Moving averages are backwards-looking and fail in three critical scenarios: (1) Seasonal festival/harvest spikes, (2) Migrant labor portability shifts under ONORC, and (3) Under-estimation caused by past stockout events where unmet demand is hidden."
            },
            {
                "question": "What happens if rural Fair Price Shops have poor internet connectivity?",
                "defense": "The core optimization and manifest generation occur at the district godown level where broadband connectivity is reliable. For FPS dealers and beneficiaries, readiness notifications are dispatched via offline SMS and automated IVR voice calls."
            },
            {
                "question": "How do you ensure government statutory quotas are not violated?",
                "defense": "Statutory NFSA entitlements (5 kg/person for PHH, 35 kg for AAY) and state district allocation quotas are hard-coded as non-negotiable hard constraints in Rule 4 of our Constraint Engine. The engine strictly blocks manifest locking if an allocation limit is exceeded."
            },
            {
                "question": "How is en-route leakage or diversion prevented?",
                "defense": "Our manifest engine applies a SHA-256 cryptographic digital seal upon DSO approval. Any attempt to modify truck assignment, destination FPS, or payload post-lock invalidates the cryptographic hash and raises an NFSA audit tampering alarm."
            }
        ]
    }


# ----------------- Citizen Request Review Queue & Authorization Endpoints ----------------- #

@router.get("/admin/citizen-requests", response_model=CitizenRequestQueueResponse)
def get_citizen_requests_queue(
    cycle_id: str = Query(settings.CURRENT_CYCLE, description="Cycle ID"),
    status: Optional[str] = Query(None, description="Filter by status: PENDING_OFFICER_REVIEW, OFFICER_APPROVED, OFFICER_PARTIAL_APPROVED, OFFICER_REDIRECTED, OFFICER_DEFERRED"),
    fps_id: Optional[str] = Query(None, description="Filter by target or home FPS ID"),
    risk_level: Optional[str] = Query(None, description="Filter by AI risk level"),
    limit: int = Query(100, ge=1, le=500),
    offset: int = Query(0, ge=0),
    db: sqlite3.Connection = Depends(get_db)
):
    """
    Retrieve paginated Officer Citizen Request Review Queue with real-time AI decision-support diagnostics.
    """
    cursor = db.cursor()
    
    # 1. Fetch Summary Counts
    cursor.execute("SELECT COUNT(*) FROM citizen_requests WHERE cycle_id = ?;", (cycle_id,))
    total_count = cursor.fetchone()[0]
    
    cursor.execute("SELECT COUNT(*) FROM citizen_requests WHERE cycle_id = ? AND status = 'PENDING_OFFICER_REVIEW';", (cycle_id,))
    pending_count = cursor.fetchone()[0]
    
    cursor.execute("SELECT COUNT(*) FROM citizen_requests WHERE cycle_id = ? AND status = 'OFFICER_APPROVED';", (cycle_id,))
    approved_count = cursor.fetchone()[0]
    
    cursor.execute("SELECT COUNT(*) FROM citizen_requests WHERE cycle_id = ? AND status = 'OFFICER_PARTIAL_APPROVED';", (cycle_id,))
    partial_count = cursor.fetchone()[0]
    
    cursor.execute("SELECT COUNT(*) FROM citizen_requests WHERE cycle_id = ? AND status = 'OFFICER_REDIRECTED';", (cycle_id,))
    redirected_count = cursor.fetchone()[0]
    
    cursor.execute("SELECT COUNT(*) FROM citizen_requests WHERE cycle_id = ? AND status = 'OFFICER_DEFERRED';", (cycle_id,))
    deferred_count = cursor.fetchone()[0]

    cursor.execute("SELECT COUNT(*) FROM citizen_requests WHERE cycle_id = ? AND status = 'DELAYED';", (cycle_id,))
    delayed_count = cursor.fetchone()[0]
    
    # 2. Build Query for Items
    query = """
    SELECT r.*, 
           b.name_for_demo as beneficiary_name,
           rf.name as registered_fps_name,
           inf.name as intended_fps_name,
           altf.name as ai_recommended_fps_name,
           COALESCE(inv.available_quantity_kg, 0.0) as current_inventory_kg,
           inf.capacity_kg as target_capacity_kg,
           inf.beneficiaries_count as target_bens_count
    FROM citizen_requests r
    LEFT JOIN beneficiaries b ON r.beneficiary_id = b.pseudonymous_beneficiary_id
    LEFT JOIN fps rf ON r.registered_fps_id = rf.fps_id
    LEFT JOIN fps inf ON r.intended_fps_id = inf.fps_id
    LEFT JOIN fps altf ON r.ai_recommended_fps_id = altf.fps_id
    LEFT JOIN inventory inv ON r.intended_fps_id = inv.fps_id AND r.commodity = inv.commodity
    WHERE r.cycle_id = ?
    """
    params = [cycle_id]
    
    if status and status.upper() != "ALL":
        query += " AND r.status = ?"
        params.append(status.upper())
        
    if fps_id:
        query += " AND (r.intended_fps_id = ? OR r.registered_fps_id = ?)"
        params.extend([fps_id.strip(), fps_id.strip()])
        
    if risk_level:
        query += " AND r.ai_risk_level = ?"
        params.append(risk_level.upper())
        
    query += " ORDER BY CASE WHEN r.status = 'PENDING_OFFICER_REVIEW' THEN 0 ELSE 1 END, r.created_at DESC LIMIT ? OFFSET ?;"
    params.extend([limit, offset])
    
    cursor.execute(query, params)
    rows = cursor.fetchall()
    
    items = []
    from app.services.scarcity_engine import scarcity_allocation_engine
    from app.models.schemas import CitizenRequestOut
    import json
    
    for r in rows:
        factors = []
        if r["ai_factors_json"]:
            try:
                factors = json.loads(r["ai_factors_json"])
            except Exception:
                factors = []
                
        # Calculate statutory floor for target FPS
        floor_info = scarcity_allocation_engine.calculate_statutory_floor(cursor, r["intended_fps_id"], r["commodity"])
        statutory_floor_kg = floor_info["statutory_floor_kg"]
        
        cap = float(r["target_capacity_kg"] or 20000.0)
        inv_kg = float(r["current_inventory_kg"] or 0.0)
        headroom_kg = max(0.0, cap - inv_kg)

        # Query pending intent demand for target FPS
        cursor.execute("""
        SELECT COALESCE(SUM(declared_quantity_kg), 0.0)
        FROM intent WHERE intended_fps_id = ? AND cycle_id = ? AND commodity = ?;
        """, (r["intended_fps_id"], r["cycle_id"], r["commodity"]))
        pending_demand_kg = float(cursor.fetchone()[0] or 0.0)
        
        replenishment_eta = "Morning Slot 08:30 AM (Scheduled Carrier)"
        if r["intended_fps_id"] in ["FPS-KA-BLR-001", "FPS-KA-BLR-004", "FPS-KA-BLR-013"]:
            replenishment_eta = "Tomorrow 08:30 AM (North-West Heavy Corridor • KA-04-E-1021)"
        elif r["intended_fps_id"] in ["FPS-KA-BLR-005", "FPS-KA-BLR-006", "FPS-KA-BLR-007"]:
            replenishment_eta = "Tomorrow 09:15 AM (East IT Corridor • KA-04-E-1022)"
        elif r["intended_fps_id"] in ["FPS-KA-BLR-015", "FPS-KA-BLR-016", "FPS-KA-BLR-017"]:
            replenishment_eta = "Tomorrow 10:00 AM (South Industrial Corridor • KA-51-M-3419)"
            
        items.append(CitizenRequestOut(
            id=r["id"],
            request_id=r["request_id"],
            beneficiary_id=r["beneficiary_id"],
            beneficiary_name=r["beneficiary_name"] or "Beneficiary Citizen",
            card_type=r["card_type"],
            family_members_count=int(r["family_members_count"]),
            statutory_entitlement_rice_kg=float(r["statutory_entitlement_rice_kg"]),
            statutory_entitlement_wheat_kg=float(r["statutory_entitlement_wheat_kg"]),
            statutory_entitlement_commodity_kg=float(r["statutory_entitlement_rice_kg"] if r["commodity"] == "Rice" else r["statutory_entitlement_wheat_kg"]),
            cycle_id=r["cycle_id"],
            registered_fps_id=r["registered_fps_id"],
            registered_fps_name=r["registered_fps_name"] or r["registered_fps_id"],
            intended_fps_id=r["intended_fps_id"],
            intended_fps_name=r["intended_fps_name"] or r["intended_fps_id"],
            commodity=r["commodity"],
            requested_quantity_kg=float(r["requested_quantity_kg"]),
            authorized_quantity_kg=float(r["authorized_quantity_kg"]),
            request_type=r["request_type"],
            status=r["status"],
            ai_recommendation=r["ai_recommendation"],
            ai_recommended_qty_kg=float(r["ai_recommended_qty_kg"]),
            ai_recommended_fps_id=r["ai_recommended_fps_id"],
            ai_recommended_fps_name=r["ai_recommended_fps_name"],
            ai_risk_level=r["ai_risk_level"],
            ai_confidence=float(r["ai_confidence"]),
            ai_factors=factors,
            fps_capacity_kg=cap,
            current_inventory_kg=inv_kg,
            statutory_floor_kg=statutory_floor_kg,
            pending_demand_kg=pending_demand_kg,
            capacity_headroom_kg=headroom_kg,
            replenishment_eta=replenishment_eta,
            nearby_alternative_fps_name=r["ai_recommended_fps_name"],
            nearby_alternative_distance_km=2.4 if r["ai_recommended_fps_name"] else None,
            officer_name=r["officer_name"],
            officer_role=r["officer_role"],
            officer_justification=r["officer_justification"],
            authorized_at=str(r["authorized_at"]) if r["authorized_at"] else None,
            created_at=str(r["created_at"]),
            demo_notice=DEMO_NOTICE
        ))
        
    return CitizenRequestQueueResponse(
        total_count=total_count,
        pending_count=pending_count,
        approved_count=approved_count,
        delayed_count=delayed_count,
        partial_count=partial_count,
        redirected_count=redirected_count,
        deferred_count=deferred_count,
        cycle_id=cycle_id,
        items=items,
        demo_notice=DEMO_NOTICE
    )


@router.post("/admin/citizen-requests/{request_id}/authorize")
def authorize_citizen_request_api(
    request_id: str,
    req: CitizenRequestAuthorizeIn,
    db: sqlite3.Connection = Depends(get_db)
):
    """
    Authorizes, partially allocates, redirects, or defers a citizen preference request.
    Mandates authorized officer authentication role (DISTRICT_SUPPLY_OFFICER, DEPOT_MANAGER, ADMIN).
    Updates citizen_requests table, synchronizes intent table, and records immutable audit event.
    """
    cursor = db.cursor()
    
    # 1. Authorization Guard
    authorized_roles = ["DISTRICT_SUPPLY_OFFICER", "DEPOT_MANAGER", "ADMIN", "SUPER_ADMIN"]
    if req.officer_role.upper() not in authorized_roles:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=f"Unauthorized: Role '{req.officer_role}' is not authorized to approve citizen requests. Required: {authorized_roles}"
        )
        
    # 2. Fetch Request
    cursor.execute("SELECT * FROM citizen_requests WHERE request_id = ?;", (request_id,))
    row = cursor.fetchone()
    if not row:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Citizen request '{request_id}' not found."
        )
        
    decision = req.decision.upper()
    now_str = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    
    if decision == "APPROVE":
        target_status = "OFFICER_APPROVED"
        auth_qty = float(row["requested_quantity_kg"])
        target_fps = row["intended_fps_id"]
    elif decision == "PARTIAL_ALLOCATION":
        target_status = "OFFICER_PARTIAL_APPROVED"
        auth_qty = float(req.allocated_quantity_kg if req.allocated_quantity_kg is not None else row["ai_recommended_qty_kg"])
        target_fps = row["intended_fps_id"]
    elif decision == "REDIRECT_ALTERNATIVE_FPS":
        target_status = "OFFICER_REDIRECTED"
        target_fps = req.allocated_fps_id or row["ai_recommended_fps_id"] or row["intended_fps_id"]
        auth_qty = float(req.allocated_quantity_kg if req.allocated_quantity_kg is not None else row["requested_quantity_kg"])
    elif decision == "DEFER_TO_CYCLE":
        target_status = "OFFICER_DEFERRED"
        auth_qty = 0.0
        target_fps = row["intended_fps_id"]
    elif decision == "REJECT":
        target_status = "REJECTED"
        auth_qty = 0.0
        target_fps = row["intended_fps_id"]
    else:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid decision '{req.decision}'. Supported: APPROVE, PARTIAL_ALLOCATION, REDIRECT_ALTERNATIVE_FPS, DEFER_TO_CYCLE, REJECT"
        )
        
    # Update citizen_requests
    cursor.execute("""
    UPDATE citizen_requests SET
        status = ?,
        authorized_quantity_kg = ?,
        intended_fps_id = ?,
        officer_name = ?,
        officer_role = ?,
        officer_justification = ?,
        authorized_at = ?,
        updated_at = ?
    WHERE request_id = ?;
    """, (
        target_status,
        auth_qty,
        target_fps,
        req.officer_name,
        req.officer_role.upper(),
        req.officer_justification,
        now_str,
        now_str,
        request_id
    ))
    
    # Synchronize intent table so aggregated forecasting receives the officer-authorized allocation
    if auth_qty > 0:
        cursor.execute("""
        UPDATE intent SET
            declared_quantity_kg = ?,
            intended_fps_id = ?,
            status = ?
        WHERE beneficiary_id = ? AND cycle_id = ? AND commodity = ?;
        """, (
            auth_qty,
            target_fps,
            target_status,
            row["beneficiary_id"],
            row["cycle_id"],
            row["commodity"]
        ))
    else:
        # If deferred or rejected, remove intent signal from current cycle so it does not flow downstream
        cursor.execute("""
        DELETE FROM intent
        WHERE beneficiary_id = ? AND cycle_id = ? AND commodity = ?;
        """, (
            row["beneficiary_id"],
            row["cycle_id"],
            row["commodity"]
        ))
        
    # Record in governance_audit_logs (Immutable Audit Trail)
    from app.services.governance_trail import governance_trail
    governance_trail.record_event(
        db=db,
        event_type="CITIZEN_REQUEST_AUTHORIZED",
        action="CITIZEN_REQUEST_AUTHORIZED",
        entity_type="CITIZEN_REQUEST",
        entity_id=request_id,
        actor_name=req.officer_name,
        actor_role=req.officer_role.upper(),
        cycle_id=row["cycle_id"],
        notes=f"Decision: {target_status} ({auth_qty:.1f} kg to {target_fps}). Justification: {req.officer_justification}",
        integrity_metadata={"request_id": request_id, "status": target_status, "authorized_quantity_kg": auth_qty},
        is_success=True,
        is_simulation=False
    )
    
    db.commit()
    
    return {
        "status": "success",
        "request_id": request_id,
        "beneficiary_id": row["beneficiary_id"],
        "decision": decision,
        "approval_status": target_status,
        "authorized_quantity_kg": auth_qty,
        "allocated_fps_id": target_fps,
        "officer_name": req.officer_name,
        "officer_role": req.officer_role.upper(),
        "authorized_at": now_str,
        "justification": req.officer_justification,
        "demo_notice": DEMO_NOTICE
    }


# ----------------- Citizen Delivery Dispute Management Endpoints ----------------- #

@router.get("/admin/delivery-disputes", response_model=List[DeliveryDisputeOut])
def get_delivery_disputes(
    cycle_id: str = Query("2026-09", description="Allocation cycle"),
    status: Optional[str] = Query(None, description="Filter: PENDING_OFFICER_REVIEW | OFFICER_RESOLVED | REJECTED"),
    db: sqlite3.Connection = Depends(get_db)
):
    """Retrieve citizen delivery discrepancy and dispute cases for officer investigation."""
    cursor = db.cursor()
    query = "SELECT * FROM delivery_disputes WHERE cycle_id = ?"
    params = [cycle_id.strip()]

    if status and status.upper() != "ALL":
        query += " AND status = ?"
        params.append(status.strip().upper())

    query += " ORDER BY created_at DESC;"
    cursor.execute(query, params)
    rows = cursor.fetchall()

    return [
        DeliveryDisputeOut(
            id=r["id"],
            dispute_id=r["dispute_id"],
            request_id=r["request_id"],
            beneficiary_id=r["beneficiary_id"],
            cycle_id=r["cycle_id"],
            commodity=r["commodity"],
            allocated_quantity_kg=float(r["allocated_quantity_kg"]),
            received_quantity_kg=float(r["received_quantity_kg"]),
            shortfall_kg=float(r["shortfall_kg"]),
            dispute_notes=r["dispute_notes"],
            status=r["status"],
            resolution_notes=r["resolution_notes"],
            resolved_by=r["resolved_by"],
            resolved_at=str(r["resolved_at"]) if r["resolved_at"] else None,
            created_at=str(r["created_at"]),
            demo_notice=DEMO_NOTICE
        )
        for r in rows
    ]


@router.post("/admin/delivery-disputes/{dispute_id}/resolve")
def resolve_delivery_dispute(
    dispute_id: str,
    req: DeliveryDisputeResolveIn,
    db: sqlite3.Connection = Depends(get_db)
):
    """Authoritative officer resolution of a citizen delivery dispute with audit log."""
    cursor = db.cursor()
    cursor.execute("SELECT * FROM delivery_disputes WHERE dispute_id = ?;", (dispute_id.strip(),))
    row = cursor.fetchone()
    if not row:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Dispute case '{dispute_id}' not found."
        )

    now_str = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    officer_label = f"{req.officer_name} ({req.officer_role})"

    cursor.execute("""
    UPDATE delivery_disputes SET
        status = ?,
        resolution_notes = ?,
        resolved_by = ?,
        resolved_at = ?
    WHERE dispute_id = ?;
    """, (
        req.decision.upper(),
        req.resolution_notes,
        officer_label,
        now_str,
        dispute_id.strip()
    ))

    # Log to unified forensic audit trail
    from app.services.governance_trail import governance_trail
    governance_trail.record_event(
        db=db,
        event_type="DELIVERY_DISPUTE_RESOLVED",
        action="RESOLVE_DELIVERY_DISPUTE",
        entity_type="DELIVERY_DISPUTE",
        entity_id=dispute_id.strip(),
        actor_name=req.officer_name,
        actor_role=req.officer_role,
        cycle_id=row["cycle_id"],
        notes=f"Dispute resolved as {req.decision.upper()}. Resolution: {req.resolution_notes}",
        integrity_metadata={"dispute_id": dispute_id.strip(), "decision": req.decision.upper()},
        is_success=True,
        is_simulation=False
    )

    db.commit()

    return {
        "status": "success",
        "dispute_id": dispute_id.strip(),
        "decision": req.decision.upper(),
        "resolution_notes": req.resolution_notes,
        "resolved_by": officer_label,
        "resolved_at": now_str,
        "message": f"Dispute case {dispute_id} resolved and recorded in governance audit trail.",
        "demo_notice": DEMO_NOTICE
    }

# ----------------- End-to-End Causal Pipeline Trace ----------------- #

class CausalTraceShiftIn(BaseModel):
    cycle_id: str = Field(default="2026-09")
    fps_id: str = Field(default="FPS-KA-BLR-001")
    shift_delta_kg: float = Field(default=150.0)
    beneficiary_id: str = Field(default="BEN-KA-0001")

@router.get("/admin/causal-trace", response_model=CausalTraceRun)
def get_causal_trace(
    cycle_id: str = Query(default="2026-09"),
    fps_id: str = Query(default="FPS-KA-BLR-001"),
    db: sqlite3.Connection = Depends(get_db)
):
    """
    Retrieve or generate the complete 7-stage causal pipeline trace for an operational planning run:
    Citizen Intent -> Intent Aggregation -> Operational Forecast -> Constraint Validation
    -> Dispatch Decision -> Route Optimization -> Manifest -> Digital Seal.
    """
    return causal_trace_engine.generate_causal_trace(db, cycle_id=cycle_id, fps_id=fps_id)

@router.post("/admin/causal-trace/run", response_model=CausalTraceRun)
def run_causal_trace_calculation(
    cycle_id: str = Query(default="2026-09"),
    fps_id: str = Query(default="FPS-KA-BLR-001"),
    db: sqlite3.Connection = Depends(get_db)
):
    """Trigger a new calculation run and return the full 7-stage causal trace."""
    return causal_trace_engine.generate_causal_trace(
        db, cycle_id=cycle_id, fps_id=fps_id, actor_source="OFFICER_MANUAL_RECALCULATION"
    )

@router.post("/admin/causal-trace/simulate-shift", response_model=CausalTraceResponse)
def simulate_intent_shift_causal_trace(
    req: CausalTraceShiftIn,
    db: sqlite3.Connection = Depends(get_db)
):
    """
    Controlled demo action: Injects a synthetic citizen intent shift declaration,
    reruns the entire operational pre-dispatch pipeline, and returns the exact
    step-by-step downstream causal delta across all 7 stages.
    """
    return causal_trace_engine.simulate_controlled_intent_shift(
        db,
        cycle_id=req.cycle_id,
        fps_id=req.fps_id,
        shift_delta_kg=req.shift_delta_kg,
        beneficiary_id=req.beneficiary_id
    )










