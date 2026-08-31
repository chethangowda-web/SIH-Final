"""Deterministic Demand Forecasting Engine for PDS DemandSync.

Implements the SIH 2026 Phase 4 Pre-Dispatch Demand Forecasting architecture:
- Historical demand baseline (H) from 6-cycle past distribution records.
- Beneficiary forward-looking intent signal (I) from active cycle declarations.
- Intent confidence weighting (C) and configurable policy weight (w = 0.65).
- Interpretable mathematical formula: D_hat = (1 - w*C)*H + (w*C)*I.
- Inventory buffer and capacity-constrained recommended dispatch calculation.
- 100% deterministic, explainable, and persistent in SQLite database.
"""
import sqlite3
from typing import List, Dict, Any, Optional, Tuple
from pydantic import BaseModel
from app.core.config import settings

DEMO_NOTICE = "DEMO DATA — NOT GOVERNMENT DATA"
COMMODITIES = ["Rice", "Wheat"]

class ForecastItem(BaseModel):
    fps_id: str
    fps_name: str
    cycle_id: str
    commodity: str
    historical_demand_kg: float
    intent_demand_kg: float
    intent_count: int
    intent_confidence: float
    inventory_kg: float
    capacity_kg: float
    forecast_demand_kg: float
    recommended_dispatch_kg: float
    confidence_score: float
    risk_level: str
    risk_reason: str
    model_version: str = "v1.0-weighted-linear"
    status: str = "DRAFT"

class ForecastSummary(BaseModel):
    cycle_id: str
    total_fps: int
    total_records: int
    total_historical_demand_kg: float
    total_intent_demand_kg: float
    total_forecast_demand_kg: float
    total_recommended_dispatch_kg: float
    average_confidence: float
    high_risk_fps_count: int
    medium_risk_fps_count: int
    low_risk_fps_count: int
    workflow_status: str
    model_version: str
    intent_weight: float
    safety_buffer_pct: float
    demo_notice: str = DEMO_NOTICE

class ForecastEngine:
    """Core Deterministic Demand Forecasting and Dispatch Recommendation Service."""

    def __init__(
        self,
        intent_weight: float = settings.INTENT_WEIGHT,
        safety_buffer_pct: float = settings.SAFETY_BUFFER_PCT
    ):
        self.intent_weight = intent_weight
        self.safety_buffer_pct = safety_buffer_pct
        self.model_version = "v1.0-weighted-linear"

    def get_effective_intent_weight(self, cursor: sqlite3.Cursor, cycle_id: str) -> Tuple[float, str]:
        """Retrieve calibrated intent weight w* from model_calibration if available, else default."""
        try:
            cursor.execute("""
            SELECT calibrated_weight, model_version
            FROM model_calibration
            WHERE target_future_cycle = ? OR cycle_id = ?
            ORDER BY id DESC LIMIT 1;
            """, (cycle_id, cycle_id))
            row = cursor.fetchone()
            if row and row[0] is not None:
                return float(row[0]), str(row[1])
        except Exception:
            pass
        return float(self.intent_weight), self.model_version

    def calculate_fps_commodity_forecast(
        self,
        cursor: sqlite3.Cursor,
        fps_id: str,
        commodity: str,
        cycle_id: str = settings.CURRENT_CYCLE
    ) -> Dict[str, Any]:
        """
        Calculate deterministic demand forecast for a single FPS and commodity.
        Formula: D_hat = (1 - w*C)*H + (w*C)*I
        """
        # 1. Historical Baseline H (6-cycle average for this FPS + commodity)
        cursor.execute("""
        SELECT COALESCE(SUM(actual_quantity_kg) / 6.0, 0.0)
        FROM historical_demand
        WHERE fps_id = ? AND commodity = ?;
        """, (fps_id, commodity))
        hist_avg = round(float(cursor.fetchone()[0]), 1)

        # 2. Intent-Derived Demand I and Average Intent Confidence C
        cursor.execute("""
        SELECT 
            COALESCE(SUM(declared_quantity_kg), 0.0) as total_intent_kg,
            COUNT(DISTINCT beneficiary_id) as intent_count,
            COALESCE(AVG(confidence), 0.95) as avg_confidence
        FROM intent
        WHERE intended_fps_id = ? AND cycle_id = ? AND commodity = ?;
        """, (fps_id, cycle_id, commodity))
        intent_row = cursor.fetchone()
        
        intent_kg = round(float(intent_row[0]), 1)
        intent_count = int(intent_row[1])
        avg_confidence = round(float(intent_row[2]), 2)

        # If zero intent declared for this commodity, assume intent aligns with historical baseline
        effective_intent_kg = intent_kg if intent_kg > 0 else hist_avg
        effective_confidence = avg_confidence if intent_kg > 0 else 1.0

        # 3. Deterministic Forecast Formula: D_hat = (1 - w*C)*H + (w*C)*I
        # Dynamically pulls calibrated weight w* if model calibration has occurred
        effective_weight, current_model_version = self.get_effective_intent_weight(cursor, cycle_id)
        alpha = round(effective_weight * effective_confidence, 4)
        raw_forecast = ((1.0 - alpha) * hist_avg) + (alpha * effective_intent_kg)
        forecast_demand_kg = round(max(0.0, raw_forecast), 1)

        # 4. Current Available Inventory
        cursor.execute("""
        SELECT COALESCE(available_quantity_kg, 0.0)
        FROM inventory
        WHERE fps_id = ? AND commodity = ?;
        """, (fps_id, commodity))
        inv_row = cursor.fetchone()
        inventory_kg = round(float(inv_row[0]) if inv_row else 0.0, 1)

        # 5. FPS Capacity Budget for this commodity (e.g. Rice 75% max, Wheat 40% max of total shop capacity)
        cursor.execute("SELECT capacity_kg FROM fps WHERE fps_id = ?;", (fps_id,))
        fps_cap_row = cursor.fetchone()
        total_fps_capacity = float(fps_cap_row[0]) if fps_cap_row else 20000.0
        commodity_cap = total_fps_capacity * (0.75 if commodity == "Rice" else 0.40)

        # 6. Recommended Dispatch Calculation:
        # Target stock = Forecast + 5% Safety Buffer
        target_stock_kg = forecast_demand_kg * (1.0 + self.safety_buffer_pct)
        # Net deficit to be dispatched from godown
        net_needed_kg = max(0.0, target_stock_kg - inventory_kg)
        # Physical space available
        available_space_kg = max(0.0, commodity_cap - inventory_kg)
        # Recommended dispatch capped by storage
        recommended_dispatch_kg = round(min(net_needed_kg, available_space_kg), 1)

        return {
            "fps_id": fps_id,
            "commodity": commodity,
            "cycle_id": cycle_id,
            "historical_demand_kg": hist_avg,
            "intent_demand_kg": intent_kg,
            "intent_count": intent_count,
            "intent_confidence": effective_confidence,
            "inventory_kg": inventory_kg,
            "commodity_capacity_kg": commodity_cap,
            "forecast_demand_kg": forecast_demand_kg,
            "recommended_dispatch_kg": recommended_dispatch_kg,
            "alpha_weight": alpha
        }

    def evaluate_fps_risk_and_confidence(
        self,
        cursor: sqlite3.Cursor,
        fps_id: str,
        total_intent_kg: float,
        total_inventory_kg: float,
        total_capacity_kg: float,
        registered_beneficiaries: int,
        avg_confidence: float
    ) -> Tuple[str, str, float]:
        """
        Evaluate FPS operational risk level (HIGH, MEDIUM, LOW), reasoning, and confidence score.
        """
        # Baseline registered quota estimate (~30kg per beneficiary across commodities)
        baseline_reg = registered_beneficiaries * 30.0
        intent_shift_kg = round(total_intent_kg - baseline_reg, 1)
        intent_shift_pct = (intent_shift_kg / baseline_reg * 100.0) if baseline_reg > 0 else 0.0
        inv_util_pct = (total_inventory_kg / total_capacity_kg * 100.0) if total_capacity_kg > 0 else 0.0

        risk_level = "LOW"
        risk_reasons = []

        if intent_shift_kg > 300 or intent_shift_pct > 15.0:
            risk_level = "HIGH"
            risk_reasons.append(f"Portability Inflow Surge (+{intent_shift_kg:.0f} kg)")
        elif intent_shift_kg > 100 or intent_shift_pct > 5.0:
            risk_level = "MEDIUM"
            risk_reasons.append(f"Moderate Inflow (+{intent_shift_kg:.0f} kg)")

        if inv_util_pct < 15.0:
            risk_level = "HIGH"
            risk_reasons.append(f"Critical Stock Depletion ({inv_util_pct:.0f}% capacity)")
        elif inv_util_pct < 25.0 and risk_level != "HIGH":
            risk_level = "MEDIUM"
            risk_reasons.append(f"Low Inventory Buffer ({inv_util_pct:.0f}%)")
        elif inv_util_pct > 80.0:
            risk_reasons.append(f"Surplus Stock ({inv_util_pct:.0f}%)")

        if not risk_reasons:
            risk_reasons.append("Balanced Demand & Inventory Profile")

        confidence_score = round(max(0.50, min(1.0, avg_confidence)), 2)
        return risk_level, " • ".join(risk_reasons), confidence_score

    # States in which ordinary forecast generation is prohibited.
    # Any state at or beyond FORECAST_LOCKED must not allow accidental
    # regeneration through the normal workflow path.
    LOCKED_STATES = frozenset({
        "FORECAST_LOCKED",
        "DISPATCH_GENERATED",
        "ACTUAL_DISTRIBUTION_SIMULATED",
        "FORECAST_EVALUATED",
        "MODEL_CALIBRATED",
    })

    def generate_and_persist_forecasts(
        self,
        db: sqlite3.Connection,
        cycle_id: str = settings.CURRENT_CYCLE,
        force: bool = False
    ) -> Dict[str, Any]:
        """
        Generate pre-dispatch demand forecasts for all 20 FPS and persist into SQLite forecast table.

        Workflow protection:
        - Ordinary generation (force=False) is rejected for any state at or beyond
          FORECAST_LOCKED: FORECAST_LOCKED, DISPATCH_GENERATED,
          ACTUAL_DISTRIBUTION_SIMULATED, FORECAST_EVALUATED, MODEL_CALIBRATED.
        - Only PLANNING_OPEN and DRAFT_GENERATED allow ordinary re-generation.
        - force=True is an explicit admin-override path (e.g. demo reset recovery).
          It bypasses the guard entirely and is NOT exposed through the normal UI.
        """
        cursor = db.cursor()

        # Check existing workflow status
        current_status = self.get_persisted_workflow_status(db, cycle_id)
        if current_status in self.LOCKED_STATES and not force:
            raise ValueError(
                f"Forecast for cycle '{cycle_id}' is in state '{current_status}' "
                f"and cannot be regenerated. The cycle has progressed beyond FORECAST_LOCKED. "
                f"Use the demo reset to start a new workflow cycle."
            )

        # 1. Fetch all FPS
        cursor.execute("SELECT id, fps_id, name, district, capacity_kg FROM fps ORDER BY id ASC;")
        fps_list = cursor.fetchall()

        generated_items: List[Dict[str, Any]] = []
        total_hist = 0.0
        total_intent = 0.0
        total_forecast = 0.0
        total_dispatch = 0.0
        total_conf_sum = 0.0

        for fps in fps_list:
            fid = fps["fps_id"]
            fname = fps["name"]
            cap = float(fps["capacity_kg"])

            # Beneficiary count
            cursor.execute("SELECT COUNT(*) FROM beneficiaries WHERE registered_fps_id = ?;", (fid,))
            reg_count = int(cursor.fetchone()[0])

            # Calculate for Rice and Wheat
            fps_results = []
            fps_intent_sum = 0.0
            fps_inv_sum = 0.0
            fps_conf_sum = 0.0

            for comm in COMMODITIES:
                res = self.calculate_fps_commodity_forecast(cursor, fid, comm, cycle_id)
                fps_results.append(res)
                fps_intent_sum += res["intent_demand_kg"]
                fps_inv_sum += res["inventory_kg"]
                fps_conf_sum += res["intent_confidence"]

            avg_fps_conf = fps_conf_sum / len(COMMODITIES)
            risk_level, risk_reason, conf_score = self.evaluate_fps_risk_and_confidence(
                cursor, fid, fps_intent_sum, fps_inv_sum, cap, reg_count, avg_fps_conf
            )

            # Persist each commodity record into SQLite forecast table
            for res in fps_results:
                comm = res["commodity"]
                cursor.execute("""
                INSERT INTO forecast (
                    fps_id, cycle_id, commodity, historical_component, intent_component,
                    inventory_component, predicted_quantity_kg, recommended_dispatch_kg,
                    confidence, risk_level, model_version, status, created_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'DRAFT', CURRENT_TIMESTAMP)
                ON CONFLICT(fps_id, cycle_id, commodity) DO UPDATE SET
                    historical_component = excluded.historical_component,
                    intent_component = excluded.intent_component,
                    inventory_component = excluded.inventory_component,
                    predicted_quantity_kg = excluded.predicted_quantity_kg,
                    recommended_dispatch_kg = excluded.recommended_dispatch_kg,
                    confidence = excluded.confidence,
                    risk_level = excluded.risk_level,
                    model_version = excluded.model_version,
                    status = 'DRAFT',
                    created_at = CURRENT_TIMESTAMP;
                """, (
                    fid,
                    cycle_id,
                    comm,
                    res["historical_demand_kg"],
                    res["intent_demand_kg"],
                    res["inventory_kg"],
                    res["forecast_demand_kg"],
                    res["recommended_dispatch_kg"],
                    res["intent_confidence"],
                    risk_level,
                    self.model_version
                ))

                total_hist += res["historical_demand_kg"]
                total_intent += res["intent_demand_kg"]
                total_forecast += res["forecast_demand_kg"]
                total_dispatch += res["recommended_dispatch_kg"]
                total_conf_sum += conf_score

                generated_items.append({
                    "fps_id": fid,
                    "fps_name": fname,
                    "commodity": comm,
                    "historical_demand_kg": res["historical_demand_kg"],
                    "intent_demand_kg": res["intent_demand_kg"],
                    "inventory_kg": res["inventory_kg"],
                    "forecast_demand_kg": res["forecast_demand_kg"],
                    "recommended_dispatch_kg": res["recommended_dispatch_kg"],
                    "confidence": conf_score,
                    "risk_level": risk_level,
                    "status": "DRAFT"
                })

        db.commit()

        # Record in Unified Governance Event Trail
        from app.services.governance_trail import governance_trail
        governance_trail.record_event(
            db=db,
            event_type="FORECAST_GENERATED",
            action="GENERATE_OPERATIONAL_FORECAST",
            entity_type="FORECAST",
            entity_id=f"FORECAST-{cycle_id}",
            actor_name="District Supply Officer (Demo Admin)",
            actor_role="DISTRICT_SUPPLY_OFFICER",
            cycle_id=cycle_id,
            after_state={
                "total_forecast_demand_kg": round(total_forecast, 1),
                "total_recommended_dispatch_kg": round(total_dispatch, 1),
                "fps_count": len(fps_list),
                "generated_records_count": len(generated_items)
            },
            notes=f"Pre-dispatch demand forecast generated across {len(fps_list)} FPS nodes for cycle {cycle_id}",
            is_success=True,
            is_simulation=False
        )

        avg_conf = round(total_conf_sum / max(1, len(generated_items)), 2)

        return {
            "status": "success",
            "workflow_status": "DRAFT_GENERATED",
            "cycle_id": cycle_id,
            "total_fps": len(fps_list),
            "generated_records_count": len(generated_items),
            "total_historical_demand_kg": round(total_hist, 1),
            "total_intent_demand_kg": round(total_intent, 1),
            "total_forecast_demand_kg": round(total_forecast, 1),
            "total_recommended_dispatch_kg": round(total_dispatch, 1),
            "average_confidence": avg_conf,
            "model_version": self.model_version,
            "intent_weight": self.intent_weight,
            "safety_buffer_pct": self.safety_buffer_pct,
            "items": generated_items,
            "message": f"Persisted {len(generated_items)} demand forecasts across all {len(fps_list)} FPS for cycle {cycle_id}.",
            "demo_notice": DEMO_NOTICE
        }

    def lock_operational_forecast(
        self,
        db: sqlite3.Connection,
        cycle_id: str = settings.CURRENT_CYCLE
    ) -> Dict[str, Any]:
        """
        Officially lock the pre-dispatch demand forecast for the active planning cycle.
        Freezes predicted_quantity_kg and recommended_dispatch_kg.
        Transitions workflow to FORECAST_LOCKED.
        """
        cursor = db.cursor()

        # Check if forecasts exist
        cursor.execute("SELECT COUNT(*) FROM forecast WHERE cycle_id = ?;", (cycle_id,))
        count = cursor.fetchone()[0]
        if count == 0:
            # Auto-generate draft first if not yet generated
            self.generate_and_persist_forecasts(db, cycle_id)

        # Check constraint compliance before locking
        from app.services.constraint_engine import constraint_engine
        can_lock, lock_err = constraint_engine.is_manifest_lock_permitted(db, cycle_id)
        if not can_lock:
            raise ValueError(f"Forecast Lock Blocked: {lock_err}")

        # CONCURRENCY GUARD: Conditional UPDATE prevents redundant re-locking.
        # Adding WHERE status != 'FORECAST_LOCKED' makes this call fully idempotent:
        # concurrent requests will simply update 0 rows on the second pass.
        cursor.execute("""
        UPDATE forecast
        SET status = 'FORECAST_LOCKED'
        WHERE cycle_id = ? AND status != 'FORECAST_LOCKED';
        """, (cycle_id,))
        db.commit()

        cursor.execute("SELECT COUNT(*) FROM forecast WHERE cycle_id = ? AND status = 'FORECAST_LOCKED';", (cycle_id,))
        locked_count = cursor.fetchone()[0]

        # Record in Unified Governance Event Trail
        from app.services.governance_trail import governance_trail
        governance_trail.record_event(
            db=db,
            event_type="FORECAST_LOCKED",
            action="LOCK_OPERATIONAL_FORECAST",
            entity_type="FORECAST",
            entity_id=f"FORECAST-{cycle_id}",
            actor_name="District Supply Officer (Demo Admin)",
            actor_role="DISTRICT_SUPPLY_OFFICER",
            cycle_id=cycle_id,
            before_state={"status": "DRAFT"},
            after_state={"status": "FORECAST_LOCKED", "locked_records_count": locked_count},
            notes=f"Operational demand forecast locked and approved for cycle {cycle_id}",
            is_success=True,
            is_simulation=False
        )

        return {
            "status": "success",
            "workflow_status": "FORECAST_LOCKED",
            "cycle_id": cycle_id,
            "locked_records_count": locked_count,
            "message": f"Demand forecast for Cycle {cycle_id} successfully locked. Pre-dispatch allocations frozen.",
            "demo_notice": DEMO_NOTICE
        }

    # Alias for backward compatibility
    lock_persisted_forecast = lock_operational_forecast

    def get_persisted_workflow_status(
        self,
        db: sqlite3.Connection,
        cycle_id: str = settings.CURRENT_CYCLE
    ) -> str:
        """
        Determine persistent workflow status from explicit cycle_workflow_states state machine.
        Maps the new 10 states to legacy states for backward compatibility of test suite.
        """
        cursor = db.cursor()

        # Check if forecasts exist
        cursor.execute("SELECT COUNT(*) FROM forecast WHERE cycle_id = ?;", (cycle_id,))
        if cursor.fetchone()[0] == 0:
            return "PLANNING_OPEN"

        from app.services.workflow_manager import workflow_manager, WorkflowState
        state = workflow_manager.get_current_state(db, cycle_id)

        mapping = {
            WorkflowState.FORECASTED: "DRAFT_GENERATED",
            WorkflowState.VALIDATED: "FORECAST_LOCKED",
            WorkflowState.ALLOCATED: "FORECAST_LOCKED",
            WorkflowState.OPTIMIZED: "FORECAST_LOCKED",
            WorkflowState.MANIFEST_DRAFT: "DISPATCH_GENERATED",
            WorkflowState.MANIFEST_LOCKED: "DISPATCH_GENERATED",
            WorkflowState.GATEPASS_READY: "DISPATCH_GENERATED",
            WorkflowState.DISPATCHED: "ACTUAL_DISTRIBUTION_SIMULATED",
            WorkflowState.VERIFIED: "FORECAST_EVALUATED",
            WorkflowState.EVALUATED: "MODEL_CALIBRATED"
        }
        return mapping.get(state, "PLANNING_OPEN")

    def get_persisted_forecasts_for_cycle(
        self,
        db: sqlite3.Connection,
        cycle_id: str = settings.CURRENT_CYCLE
    ) -> List[Dict[str, Any]]:
        """Retrieve all persisted forecast records for a cycle."""
        cursor = db.cursor()
        cursor.execute("""
        SELECT 
            f.id, f.fps_id, p.name as fps_name, f.cycle_id, f.commodity,
            f.historical_component as historical_demand_kg,
            f.intent_component as intent_demand_kg,
            f.inventory_component as inventory_kg,
            f.predicted_quantity_kg as forecast_demand_kg,
            f.recommended_dispatch_kg,
            f.confidence, f.risk_level, f.model_version, f.status, f.created_at
        FROM forecast f
        LEFT JOIN fps p ON f.fps_id = p.fps_id
        WHERE f.cycle_id = ?
        ORDER BY f.fps_id ASC, f.commodity ASC;
        """, (cycle_id,))
        rows = cursor.fetchall()
        return [dict(r) for r in rows]

    # -------------------------------------------------------------------------
    # PHASE 2: EXPLAINABLE MULTI-FACTOR DEMAND FORECASTING & WHAT-IF ENGINE
    # -------------------------------------------------------------------------

    def calculate_explainable_fps_forecast(
        self,
        cursor: sqlite3.Cursor,
        fps_id: str,
        cycle_id: str = settings.CURRENT_CYCLE,
        overrides: Optional[Dict[str, Any]] = None
    ) -> Dict[str, Any]:
        """
        Calculate an explainable, multi-factor FPS demand forecast.
        Features decomposed:
        1. Historical Recency-Weighted Average (6 past cycles with weights [0.08, 0.10, 0.12, 0.18, 0.22, 0.30])
        2. 3-Cycle Momentum Trend Factor
        3. Seasonal Multiplier
        4. Portability / Intent Shift Adjustment
        5. Stockout Distortion Correction
        6. Confidence Score & 95% Confidence Interval [Lower, Upper]
        7. Step-by-Step Mathematical Explanation Breakdown
        """
        overrides = overrides or {}

        # 1. Fetch FPS Master Data
        cursor.execute("""
        SELECT fps_id, name, district, capacity_kg, stockout_frequency, portability_rate,
               seasonal_factor, beneficiaries_count, entitlement_rice_kg, entitlement_wheat_kg
        FROM fps WHERE fps_id = ?;
        """, (fps_id,))
        fps_row = cursor.fetchone()
        if not fps_row:
            raise ValueError(f"Fair Price Shop '{fps_id}' not found.")

        fps_name = fps_row["name"]
        district = fps_row["district"]
        capacity_kg = float(fps_row["capacity_kg"])

        # Operational parameters (incorporating any What-If overrides)
        beneficiaries_count = int(overrides.get("beneficiaries_count", fps_row["beneficiaries_count"] or 100))
        base_ben_count = int(fps_row["beneficiaries_count"] or 100)
        ben_ratio = (beneficiaries_count / base_ben_count) if base_ben_count > 0 else 1.0

        seasonal_factor = float(overrides.get("seasonal_factor", fps_row["seasonal_factor"] or 1.05))
        portability_rate = float(overrides.get("portability_rate", fps_row["portability_rate"] or 0.12))
        stockout_frequency = float(overrides.get("stockout_frequency", fps_row["stockout_frequency"] or 0.05))

        entitlement_rice = float(fps_row["entitlement_rice_kg"] or 25.0)
        entitlement_wheat = float(fps_row["entitlement_wheat_kg"] or 10.0)

        # 2. Fetch Historical Offtake for past 6 cycles
        cursor.execute("""
        SELECT cycle_id, commodity, actual_quantity_kg
        FROM historical_demand
        WHERE fps_id = ?
        ORDER BY cycle_id ASC, commodity ASC;
        """, (fps_id,))
        hist_rows = cursor.fetchall()

        # Group by commodity -> list of 6 values
        hist_by_comm: Dict[str, List[float]] = {"Rice": [], "Wheat": []}
        cycles_set = []
        for r in hist_rows:
            comm = r["commodity"]
            cid = r["cycle_id"]
            if cid not in cycles_set:
                cycles_set.append(cid)
            if comm in hist_by_comm:
                hist_by_comm[comm].append(float(r["actual_quantity_kg"]))

        # Linear recency weights for 6 cycles (normalized sum = 1.0)
        recency_weights = [0.08, 0.10, 0.12, 0.18, 0.22, 0.30]

        # 3. Calculate per-commodity forecast and explainable feature contributions
        commodity_forecasts = []
        total_predicted_kg = 0.0
        total_hist_weighted_kg = 0.0
        total_trend_adj_kg = 0.0
        total_seasonal_adj_kg = 0.0
        total_portability_adj_kg = 0.0
        total_stockout_adj_kg = 0.0

        for comm in COMMODITIES:
            vals = hist_by_comm.get(comm, [4500.0 if comm == "Rice" else 1500.0] * 6)
            if len(vals) < 6:
                vals = vals + [vals[-1] if vals else 3000.0] * (6 - len(vals))

            # Feature 1: Recency-Weighted Historical Average
            weighted_avg = sum(w * v for w, v in zip(recency_weights, vals[-6:]))

            # Feature 2: 3-Cycle Momentum Trend Factor
            recent_offtake_3 = vals[-3] if len(vals) >= 3 and vals[-3] > 0 else weighted_avg
            recent_offtake_1 = vals[-1] if vals else weighted_avg
            trend_pct = ((recent_offtake_1 - recent_offtake_3) / (2.0 * recent_offtake_3)) if recent_offtake_3 > 0 else 0.0
            trend_pct = max(-0.15, min(0.20, trend_pct))  # Cap trend within [-15%, +20%]
            trend_adj_kg = weighted_avg * trend_pct

            # Feature 3: Seasonal Adjustment
            seasonal_adj_kg = (weighted_avg + trend_adj_kg) * (seasonal_factor - 1.0)

            # Feature 4: Portability & Intent Shift
            cursor.execute("""
            SELECT COALESCE(SUM(declared_quantity_kg), 0.0), COALESCE(AVG(confidence), 0.95)
            FROM intent
            WHERE intended_fps_id = ? AND cycle_id = ? AND commodity = ?;
            """, (fps_id, cycle_id, comm))
            intent_res = cursor.fetchone()
            declared_intent = float(intent_res[0]) if intent_res else 0.0
            intent_conf = float(intent_res[1]) if intent_res else 0.95

            # If intent declarations exist, calculate migrant influx adjustment scaled by calibrated weight w*
            effective_weight, current_model_version = self.get_effective_intent_weight(cursor, cycle_id)
            weight_scaler = effective_weight / 0.65 if effective_weight > 0 else 1.0
            baseline_entitlement = beneficiaries_count * (entitlement_rice if comm == "Rice" else entitlement_wheat)
            if declared_intent > 0:
                intent_diff = declared_intent - (weighted_avg * (declared_intent / max(1.0, baseline_entitlement)))
                portability_adj_kg = intent_diff * portability_rate * intent_conf * weight_scaler
            else:
                portability_adj_kg = weighted_avg * (portability_rate * 0.25) * weight_scaler  # Baseline migrant shift

            # Feature 5: Stockout Distortion Correction
            stockout_adj_kg = weighted_avg * (stockout_frequency * 0.50)

            # Raw Predicted Demand before beneficiary scaling
            base_predicted = weighted_avg + trend_adj_kg + seasonal_adj_kg + portability_adj_kg + stockout_adj_kg
            # Scale by What-If Beneficiary ratio
            predicted_demand_kg = round(max(0.0, base_predicted * ben_ratio), 1)

            # Commodity inventory and headroom
            cursor.execute("SELECT COALESCE(available_quantity_kg, 0.0) FROM inventory WHERE fps_id = ? AND commodity = ?;", (fps_id, comm))
            inv_row = cursor.fetchone()
            curr_inv_kg = float(inv_row[0]) if inv_row else 0.0

            commodity_forecasts.append({
                "commodity": comm,
                "historical_weighted_avg_kg": round(weighted_avg, 1),
                "trend_pct": round(trend_pct * 100.0, 2),
                "trend_adj_kg": round(trend_adj_kg * ben_ratio, 1),
                "seasonal_factor": round(seasonal_factor, 2),
                "seasonal_adj_kg": round(seasonal_adj_kg * ben_ratio, 1),
                "portability_rate": round(portability_rate, 2),
                "portability_adj_kg": round(portability_adj_kg * ben_ratio, 1),
                "stockout_frequency": round(stockout_frequency, 2),
                "stockout_adj_kg": round(stockout_adj_kg * ben_ratio, 1),
                "predicted_demand_kg": predicted_demand_kg,
                "current_inventory_kg": curr_inv_kg,
                "recommended_dispatch_kg": max(0.0, round(predicted_demand_kg - curr_inv_kg + (predicted_demand_kg * 0.10), 1))
            })

            total_predicted_kg += predicted_demand_kg
            total_hist_weighted_kg += weighted_avg * ben_ratio
            total_trend_adj_kg += trend_adj_kg * ben_ratio
            total_seasonal_adj_kg += seasonal_adj_kg * ben_ratio
            total_portability_adj_kg += portability_adj_kg * ben_ratio
            total_stockout_adj_kg += stockout_adj_kg * ben_ratio

        # 4. Volatility & Confidence Score
        # Historical standard deviation across total demand
        cycle_totals = []
        for i in range(min(len(hist_by_comm["Rice"]), len(hist_by_comm["Wheat"]))):
            cycle_totals.append(hist_by_comm["Rice"][i] + hist_by_comm["Wheat"][i])
        
        if cycle_totals:
            mean_demand = sum(cycle_totals) / len(cycle_totals)
            variance = sum((x - mean_demand) ** 2 for x in cycle_totals) / len(cycle_totals)
            std_dev = variance ** 0.5
            coeff_variation = (std_dev / mean_demand) if mean_demand > 0 else 0.05
        else:
            coeff_variation = 0.05

        # Explainable confidence: penalized by volatility & stockout history, rewarded by intent coverage
        confidence_raw = 1.0 - (0.40 * coeff_variation) - (0.30 * stockout_frequency) + 0.05
        confidence_score = round(max(0.70, min(0.98, confidence_raw)), 2)

        # 95% Confidence Interval (Forecast Bounds)
        margin_of_error_kg = round(total_predicted_kg * (1.0 - confidence_score) * 1.96, 1)
        lower_bound_kg = max(0.0, round(total_predicted_kg - margin_of_error_kg, 1))
        upper_bound_kg = round(total_predicted_kg + margin_of_error_kg, 1)

        # 5. Build 6-cycle historical time-series for chart visualizer
        historical_chart_data = []
        for i, cid in enumerate(cycles_set):
            r_val = hist_by_comm["Rice"][i] if i < len(hist_by_comm["Rice"]) else 0.0
            w_val = hist_by_comm["Wheat"][i] if i < len(hist_by_comm["Wheat"]) else 0.0
            historical_chart_data.append({
                "cycle_id": cid,
                "rice_kg": r_val,
                "wheat_kg": w_val,
                "total_kg": round(r_val + w_val, 1)
            })

        # 6. Feature Contribution Explanations
        feature_explanations = [
            {
                "feature": "Historical Offtake Baseline",
                "contribution_kg": round(total_hist_weighted_kg, 1),
                "contribution_pct": round((total_hist_weighted_kg / total_predicted_kg * 100.0) if total_predicted_kg > 0 else 100.0, 1),
                "description": f"6-cycle recency-weighted average baseline ({beneficiaries_count} active ration cards)."
            },
            {
                "feature": "Recent Consumption Trend",
                "contribution_kg": round(total_trend_adj_kg, 1),
                "contribution_pct": round((total_trend_adj_kg / total_predicted_kg * 100.0) if total_predicted_kg > 0 else 0.0, 1),
                "description": f"3-cycle momentum momentum adjustment ({commodity_forecasts[0]['trend_pct']:+.1f}%)."
            },
            {
                "feature": "Seasonal Multiplier",
                "contribution_kg": round(total_seasonal_adj_kg, 1),
                "contribution_pct": round((total_seasonal_adj_kg / total_predicted_kg * 100.0) if total_predicted_kg > 0 else 0.0, 1),
                "description": f"Calendar festival & harvest factor ({seasonal_factor:.2f}x)."
            },
            {
                "feature": "Portability & Intent Shift",
                "contribution_kg": round(total_portability_adj_kg, 1),
                "contribution_pct": round((total_portability_adj_kg / total_predicted_kg * 100.0) if total_predicted_kg > 0 else 0.0, 1),
                "description": f"Migrant worker and intra-district transaction declarations ({int(portability_rate * 100)}% portability)."
            },
            {
                "feature": "Stockout Distortion Correction",
                "contribution_kg": round(total_stockout_adj_kg, 1),
                "contribution_pct": round((total_stockout_adj_kg / total_predicted_kg * 100.0) if total_predicted_kg > 0 else 0.0, 1),
                "description": f"Correction for unmet demand during historical stockout events ({int(stockout_frequency * 100)}% risk)."
            }
        ]

        return {
            "status": "success",
            "fps_id": fps_id,
            "fps_name": fps_name,
            "district": district,
            "cycle_id": cycle_id,
            "is_what_if_simulation": bool(overrides),
            "parameters": {
                "beneficiaries_count": beneficiaries_count,
                "seasonal_factor": seasonal_factor,
                "portability_rate": portability_rate,
                "stockout_frequency": stockout_frequency
            },
            "summary": {
                "predicted_demand_kg": round(total_predicted_kg, 1),
                "confidence_score": confidence_score,
                "confidence_pct": round(confidence_score * 100.0, 1),
                "lower_estimate_kg": lower_bound_kg,
                "upper_estimate_kg": upper_bound_kg,
                "margin_of_error_kg": margin_of_error_kg,
                "model_version": "v1.1-explainable-multi-factor"
            },
            "commodity_breakdown": commodity_forecasts,
            "feature_contributions": feature_explanations,
            "historical_trend": historical_chart_data,
            "demo_notice": DEMO_NOTICE
        }

    def simulate_what_if_forecast(
        self,
        cursor: sqlite3.Cursor,
        fps_id: str,
        what_if_params: Dict[str, Any],
        cycle_id: str = settings.CURRENT_CYCLE
    ) -> Dict[str, Any]:
        """
        Execute real-time What-If forecast simulation comparing baseline vs modified operational parameters.
        """
        baseline_forecast = self.calculate_explainable_fps_forecast(cursor, fps_id, cycle_id, overrides=None)
        simulated_forecast = self.calculate_explainable_fps_forecast(cursor, fps_id, cycle_id, overrides=what_if_params)

        base_val = baseline_forecast["summary"]["predicted_demand_kg"]
        sim_val = simulated_forecast["summary"]["predicted_demand_kg"]
        delta_kg = round(sim_val - base_val, 1)
        delta_pct = round((delta_kg / base_val * 100.0) if base_val > 0 else 0.0, 2)

        return {
            "status": "success",
            "fps_id": fps_id,
            "fps_name": baseline_forecast["fps_name"],
            "cycle_id": cycle_id,
            "baseline": baseline_forecast,
            "simulation": simulated_forecast,
            "comparison": {
                "baseline_demand_kg": base_val,
                "simulated_demand_kg": sim_val,
                "delta_kg": delta_kg,
                "delta_pct": delta_pct,
                "confidence_change_pct": round((simulated_forecast["summary"]["confidence_score"] - baseline_forecast["summary"]["confidence_score"]) * 100.0, 1)
            },
            "demo_notice": DEMO_NOTICE
        }

forecast_engine = ForecastEngine()

