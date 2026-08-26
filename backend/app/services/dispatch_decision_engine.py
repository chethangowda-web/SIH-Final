"""PDS Pre-Dispatch Decision Engine.

Converts demand forecasts into actionable, capacity-compliant dispatch recommendations:
Formula: Recommended Dispatch = max(0, Predicted Demand - Current Stock + Safety Buffer)
Capped by: Storage Capacity Headroom = Capacity - Current Stock

Safety Buffer is calculated from configurable operational factors:
- Lead Time (days)
- Stock-out Risk Factor
- Storage Capacity Headroom
- Consumption Volatility (CV)

Supports:
- Explicit mathematical formula exposure
- "Why this quantity?" explainable narrative generator
- 3 Pre-configured Operational Scenarios (Normal, High Demand, Low Stock/High Risk)
- Save Recommendation for downstream constraint validation and manifest generation
"""
import sqlite3
from typing import Dict, Any, List, Optional
from app.core.config import settings
from app.services.forecast_engine import forecast_engine

DEMO_NOTICE = "DEMO DATA — NOT GOVERNMENT DATA"
COMMODITIES = ["Rice", "Wheat"]

class DispatchDecisionEngine:
    """Core Pre-Dispatch Decision Engine."""

    def __init__(self):
        self.default_lead_time_days = 2.0
        self.default_stockout_risk = 0.05
        self.default_volatility_weight = 0.20

    def calculate_safety_buffer(
        self,
        predicted_demand_kg: float,
        lead_time_days: float = 2.0,
        stockout_risk: float = 0.05,
        consumption_volatility: float = 0.08,
        storage_capacity_kg: float = 20000.0,
        current_stock_kg: float = 0.0
    ) -> Dict[str, Any]:
        """
        Calculate safety buffer from operational drivers:
        - Lead time component: (lead_time_days / 30.0) * demand * 0.5
        - Stock-out risk component: stockout_risk * demand * 0.6
        - Volatility component: consumption_volatility * demand * 0.4
        """
        lead_time_days = max(1.0, min(10.0, float(lead_time_days)))
        stockout_risk = max(0.0, min(0.30, float(stockout_risk)))
        consumption_volatility = max(0.01, min(0.40, float(consumption_volatility)))

        # Sub-components
        lead_time_kg = round(predicted_demand_kg * (lead_time_days / 30.0) * 0.50, 1)
        risk_kg = round(predicted_demand_kg * stockout_risk * 0.60, 1)
        volatility_kg = round(predicted_demand_kg * consumption_volatility * 0.40, 1)

        raw_buffer_kg = round(lead_time_kg + risk_kg + volatility_kg, 1)
        # Ensure buffer is at least 3% and at most 25% of demand
        min_buffer = round(predicted_demand_kg * 0.03, 1)
        max_buffer = round(predicted_demand_kg * 0.25, 1)
        safety_buffer_kg = max(min_buffer, min(max_buffer, raw_buffer_kg))

        # Physical ceiling check: cannot exceed available space
        available_space_kg = max(0.0, storage_capacity_kg - current_stock_kg)
        effective_buffer_kg = min(safety_buffer_kg, available_space_kg)

        buffer_pct = round((effective_buffer_kg / predicted_demand_kg * 100.0) if predicted_demand_kg > 0 else 5.0, 1)

        return {
            "safety_buffer_kg": effective_buffer_kg,
            "safety_buffer_pct": buffer_pct,
            "lead_time_days": lead_time_days,
            "lead_time_contribution_kg": lead_time_kg,
            "stockout_risk_factor": stockout_risk,
            "stockout_risk_contribution_kg": risk_kg,
            "consumption_volatility": consumption_volatility,
            "volatility_contribution_kg": volatility_kg
        }

    def generate_decision_narrative(
        self,
        fps_name: str,
        predicted_demand_kg: float,
        current_stock_kg: float,
        safety_buffer_kg: float,
        recommended_dispatch_kg: float,
        storage_capacity_kg: float,
        days_of_stock: float,
        trend_pct: float,
        stockout_frequency: float,
        lead_time_days: float
    ) -> str:
        """
        Generate human-readable explainable 'Why this quantity?' rationale.
        """
        trend_text = f"forecast to increase by +{trend_pct:.1f}%" if trend_pct >= 0 else f"forecast to dip by {trend_pct:.1f}%"
        
        if days_of_stock < 2.0:
            stock_status = f"Current stock ({current_stock_kg:.0f} kg) covers only {days_of_stock:.1f} days of operations (CRITICAL DEPLETION)."
        elif days_of_stock < 4.0:
            stock_status = f"Current stock ({current_stock_kg:.0f} kg) covers approximately {days_of_stock:.1f} days of offtake."
        else:
            stock_status = f"Current stock ({current_stock_kg:.0f} kg) provides healthy baseline coverage of {days_of_stock:.1f} days."

        buffer_reason = f"A {safety_buffer_kg:.0f} kg safety buffer is recommended to account for {lead_time_days:.0f}-day transit lead time and {int(stockout_frequency * 100)}% historical stock-out probability."

        post_stock = current_stock_kg + recommended_dispatch_kg
        headroom = max(0.0, storage_capacity_kg - post_stock)
        util_pct = (post_stock / storage_capacity_kg * 100.0) if storage_capacity_kg > 0 else 0.0
        capacity_text = f"Post-dispatch inventory will reach {post_stock:.0f} kg ({util_pct:.1f}% of {storage_capacity_kg:.0f} kg capacity), preserving {headroom:.0f} kg of emergency headroom."

        return f"Monthly demand for {fps_name} is {trend_text}. {stock_status} {buffer_reason} {capacity_text}"

    def calculate_fps_dispatch_decision(
        self,
        cursor: sqlite3.Cursor,
        fps_id: str,
        cycle_id: str = settings.CURRENT_CYCLE,
        params: Optional[Dict[str, Any]] = None,
        scenario: str = "NORMAL"
    ) -> Dict[str, Any]:
        """
        Calculate full explainable dispatch decision for an FPS.
        """
        params = params or {}

        # 1. Fetch explainable forecast
        fc = forecast_engine.calculate_explainable_fps_forecast(cursor, fps_id, cycle_id=cycle_id)
        fps_name = fc["fps_name"]
        district = fc["district"]

        cursor.execute("SELECT capacity_kg, stockout_frequency, portability_rate FROM fps WHERE fps_id = ?;", (fps_id,))
        fps_row = cursor.fetchone()
        storage_capacity_kg = float(fps_row["capacity_kg"]) if fps_row else 20000.0
        base_stockout_freq = float(fps_row["stockout_frequency"] or 0.05) if fps_row else 0.05

        # 2. Extract Scenario Adjustments
        scenario_upper = scenario.upper()
        if scenario_upper == "HIGH_DEMAND":
            # Scenario 2: High Demand Surge
            demand_multiplier = 1.20
            lead_time_days = float(params.get("lead_time_days", 3.0))
            stockout_risk = float(params.get("stockout_risk", base_stockout_freq * 1.5))
            volatility = 0.14
            scenario_name = "High Demand Surge"
            scenario_desc = "Simulates +20% demand festival surge and 3-day extended transit buffer."
        elif scenario_upper == "LOW_STOCK_HIGH_RISK":
            # Scenario 3: Low Stock / Critical Stockout Risk
            demand_multiplier = 1.0
            lead_time_days = float(params.get("lead_time_days", 4.0))
            stockout_risk = float(params.get("stockout_risk", max(0.15, base_stockout_freq * 2.5)))
            volatility = 0.18
            scenario_name = "Low Stock / Critical Risk"
            scenario_desc = "Simulates critically depleted inventory and elevated stock-out probability."
        else:
            # Scenario 1: Normal Baseline
            demand_multiplier = 1.0
            lead_time_days = float(params.get("lead_time_days", self.default_lead_time_days))
            stockout_risk = float(params.get("stockout_risk", base_stockout_freq))
            volatility = 0.08
            scenario_name = "Normal Operating Baseline"
            scenario_desc = "Standard 2-day godown delivery cycle and steady historical demand baseline."

        # 3. Calculate Aggregated & Commodity Level Dispatch Decisions
        total_predicted_demand = round(fc["summary"]["predicted_demand_kg"] * demand_multiplier, 1)

        # Total current inventory across Rice + Wheat
        cursor.execute("SELECT COALESCE(SUM(available_quantity_kg), 0.0) FROM inventory WHERE fps_id = ?;", (fps_id,))
        total_current_stock = round(float(cursor.fetchone()[0]), 1)
        if scenario_upper == "LOW_STOCK_HIGH_RISK":
            total_current_stock = round(total_current_stock * 0.25, 1)  # Simulate 75% depleted stock

        # Calculate safety buffer
        buffer_metrics = self.calculate_safety_buffer(
            predicted_demand_kg=total_predicted_demand,
            lead_time_days=lead_time_days,
            stockout_risk=stockout_risk,
            consumption_volatility=volatility,
            storage_capacity_kg=storage_capacity_kg,
            current_stock_kg=total_current_stock
        )
        safety_buffer_kg = buffer_metrics["safety_buffer_kg"]

        # Core Formula: max(0, Predicted Demand - Current Stock + Safety Buffer)
        raw_recommended_dispatch = max(0.0, round(total_predicted_demand - total_current_stock + safety_buffer_kg, 1))

        # Storage capacity headroom constraint
        physical_headroom_kg = max(0.0, round(storage_capacity_kg - total_current_stock, 1))
        final_recommended_dispatch_kg = min(raw_recommended_dispatch, physical_headroom_kg)

        post_dispatch_stock_kg = round(total_current_stock + final_recommended_dispatch_kg, 1)
        remaining_capacity_kg = max(0.0, round(storage_capacity_kg - post_dispatch_stock_kg, 1))
        capacity_utilization_pct = round((post_dispatch_stock_kg / storage_capacity_kg * 100.0) if storage_capacity_kg > 0 else 0.0, 1)

        daily_burn_rate = (total_predicted_demand / 30.0) if total_predicted_demand > 0 else 100.0
        days_of_stock = round(total_current_stock / daily_burn_rate, 1)

        # 4. Commodity Level Breakdown
        commodity_decisions = []
        for c in fc["commodity_breakdown"]:
            comm_name = c["commodity"]
            comm_demand = round(c["predicted_demand_kg"] * demand_multiplier, 1)
            cursor.execute("SELECT COALESCE(available_quantity_kg, 0.0) FROM inventory WHERE fps_id = ? AND commodity = ?;", (fps_id, comm_name))
            c_inv_row = cursor.fetchone()
            c_curr_stock = round(float(c_inv_row[0]) if c_inv_row else 0.0, 1)
            if scenario_upper == "LOW_STOCK_HIGH_RISK":
                c_curr_stock = round(c_curr_stock * 0.25, 1)

            c_buffer_kg = round(comm_demand * (safety_buffer_kg / max(1.0, total_predicted_demand)), 1)
            c_raw_dispatch = max(0.0, round(comm_demand - c_curr_stock + c_buffer_kg, 1))
            c_cap = storage_capacity_kg * (0.75 if comm_name == "Rice" else 0.40)
            c_headroom = max(0.0, c_cap - c_curr_stock)
            c_final_dispatch = min(c_raw_dispatch, c_headroom)

            commodity_decisions.append({
                "commodity": comm_name,
                "predicted_demand_kg": comm_demand,
                "current_stock_kg": c_curr_stock,
                "safety_buffer_kg": c_buffer_kg,
                "recommended_dispatch_kg": c_final_dispatch,
                "post_dispatch_stock_kg": round(c_curr_stock + c_final_dispatch, 1),
                "commodity_capacity_kg": c_cap,
                "formula_display": f"{comm_demand:.0f} - {c_curr_stock:.0f} + {c_buffer_kg:.0f} = {c_final_dispatch:.0f} kg"
            })

        # 5. Generate Human-Readable Narrative
        avg_trend_pct = fc["commodity_breakdown"][0]["trend_pct"] if fc["commodity_breakdown"] else 0.0
        narrative = self.generate_decision_narrative(
            fps_name=fps_name,
            predicted_demand_kg=total_predicted_demand,
            current_stock_kg=total_current_stock,
            safety_buffer_kg=safety_buffer_kg,
            recommended_dispatch_kg=final_recommended_dispatch_kg,
            storage_capacity_kg=storage_capacity_kg,
            days_of_stock=days_of_stock,
            trend_pct=avg_trend_pct,
            stockout_frequency=stockout_risk,
            lead_time_days=lead_time_days
        )

        return {
            "status": "success",
            "fps_id": fps_id,
            "fps_name": fps_name,
            "district": district,
            "cycle_id": cycle_id,
            "scenario": {
                "id": scenario_upper,
                "name": scenario_name,
                "description": scenario_desc
            },
            "core_metrics": {
                "predicted_demand_kg": total_predicted_demand,
                "current_stock_kg": total_current_stock,
                "safety_buffer_kg": safety_buffer_kg,
                "recommended_dispatch_kg": final_recommended_dispatch_kg,
                "storage_capacity_kg": storage_capacity_kg,
                "post_dispatch_stock_kg": post_dispatch_stock_kg,
                "remaining_capacity_kg": remaining_capacity_kg,
                "capacity_utilization_pct": capacity_utilization_pct,
                "days_of_stock_coverage": days_of_stock
            },
            "formula": {
                "expression": "Recommended Dispatch = max(0, Predicted Demand - Current Stock + Safety Buffer)",
                "values": f"{total_predicted_demand:.0f} - {total_current_stock:.0f} + {safety_buffer_kg:.0f} = {final_recommended_dispatch_kg:.0f} kg",
                "is_capacity_capped": raw_recommended_dispatch > physical_headroom_kg,
                "capacity_cap_message": "Capped by storage headroom limit" if raw_recommended_dispatch > physical_headroom_kg else "Fully within physical storage capacity"
            },
            "safety_buffer_breakdown": buffer_metrics,
            "decision_explanation": {
                "headline": f"Dispatch Recommendation: {final_recommended_dispatch_kg:.0f} kg for {fps_name}",
                "narrative": narrative,
                "key_drivers": [
                    f"Predicted Demand: {total_predicted_demand:.0f} kg ({scenario_name})",
                    f"On-Hand Stock: {total_current_stock:.0f} kg ({days_of_stock:.1f} days operational buffer)",
                    f"Safety Buffer: +{safety_buffer_kg:.0f} kg ({buffer_metrics['safety_buffer_pct']}% of demand)",
                    f"Storage Utilization: {capacity_utilization_pct:.1f}% post-dispatch"
                ]
            },
            "commodity_breakdown": commodity_decisions,
            "demo_notice": DEMO_NOTICE
        }

    def evaluate_all_scenarios(
        self,
        cursor: sqlite3.Cursor,
        fps_id: str,
        cycle_id: str = settings.CURRENT_CYCLE
    ) -> Dict[str, Any]:
        """
        Evaluate all 3 pre-configured scenarios (Normal, High Demand, Low Stock) for comparison.
        """
        normal_res = self.calculate_fps_dispatch_decision(cursor, fps_id, cycle_id, scenario="NORMAL")
        high_demand_res = self.calculate_fps_dispatch_decision(cursor, fps_id, cycle_id, scenario="HIGH_DEMAND")
        low_stock_res = self.calculate_fps_dispatch_decision(cursor, fps_id, cycle_id, scenario="LOW_STOCK_HIGH_RISK")

        return {
            "status": "success",
            "fps_id": fps_id,
            "fps_name": normal_res["fps_name"],
            "cycle_id": cycle_id,
            "scenarios": [
                {
                    "scenario_id": "NORMAL",
                    "scenario_name": "1. Normal Operating Baseline",
                    "predicted_demand_kg": normal_res["core_metrics"]["predicted_demand_kg"],
                    "current_stock_kg": normal_res["core_metrics"]["current_stock_kg"],
                    "safety_buffer_kg": normal_res["core_metrics"]["safety_buffer_kg"],
                    "recommended_dispatch_kg": normal_res["core_metrics"]["recommended_dispatch_kg"],
                    "formula": normal_res["formula"]["values"],
                    "decision": normal_res
                },
                {
                    "scenario_id": "HIGH_DEMAND",
                    "scenario_name": "2. High Demand Surge (+20%)",
                    "predicted_demand_kg": high_demand_res["core_metrics"]["predicted_demand_kg"],
                    "current_stock_kg": high_demand_res["core_metrics"]["current_stock_kg"],
                    "safety_buffer_kg": high_demand_res["core_metrics"]["safety_buffer_kg"],
                    "recommended_dispatch_kg": high_demand_res["core_metrics"]["recommended_dispatch_kg"],
                    "formula": high_demand_res["formula"]["values"],
                    "decision": high_demand_res
                },
                {
                    "scenario_id": "LOW_STOCK_HIGH_RISK",
                    "scenario_name": "3. Low Stock / Critical Risk",
                    "predicted_demand_kg": low_stock_res["core_metrics"]["predicted_demand_kg"],
                    "current_stock_kg": low_stock_res["core_metrics"]["current_stock_kg"],
                    "safety_buffer_kg": low_stock_res["core_metrics"]["safety_buffer_kg"],
                    "recommended_dispatch_kg": low_stock_res["core_metrics"]["recommended_dispatch_kg"],
                    "formula": low_stock_res["formula"]["values"],
                    "decision": low_stock_res
                }
            ],
            "demo_notice": DEMO_NOTICE
        }

    def save_fps_dispatch_recommendation(
        self,
        db: sqlite3.Connection,
        fps_id: str,
        decision_data: Dict[str, Any],
        cycle_id: str = settings.CURRENT_CYCLE
    ) -> Dict[str, Any]:
        """
        Save calculated dispatch recommendation into the SQLite forecast/dispatch staging tables.
        """
        cursor = db.cursor()
        for comm in decision_data.get("commodity_breakdown", []):
            c_name = comm["commodity"]
            rec_kg = comm["recommended_dispatch_kg"]
            pred_kg = comm["predicted_demand_kg"]

            cursor.execute("""
            INSERT INTO forecast (
                fps_id, cycle_id, commodity, predicted_quantity_kg, recommended_dispatch_kg,
                confidence, risk_level, model_version, status, created_at
            ) VALUES (?, ?, ?, ?, ?, 0.95, 'LOW', 'v1.2-dispatch-decision-engine', 'DRAFT', CURRENT_TIMESTAMP)
            ON CONFLICT(fps_id, cycle_id, commodity) DO UPDATE SET
                predicted_quantity_kg = excluded.predicted_quantity_kg,
                recommended_dispatch_kg = excluded.recommended_dispatch_kg,
                model_version = excluded.model_version,
                created_at = CURRENT_TIMESTAMP;
            """, (fps_id, cycle_id, c_name, pred_kg, rec_kg))

        db.commit()

        return {
            "status": "success",
            "fps_id": fps_id,
            "cycle_id": cycle_id,
            "total_recommended_dispatch_kg": decision_data["core_metrics"]["recommended_dispatch_kg"],
            "saved_scenario": decision_data["scenario"]["name"],
            "message": f"Dispatch recommendation for {fps_id} successfully saved ({decision_data['core_metrics']['recommended_dispatch_kg']:.0f} kg). Ready for constraint validation.",
            "demo_notice": DEMO_NOTICE
        }

dispatch_decision_engine = DispatchDecisionEngine()
