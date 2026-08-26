"""Deterministic Fair-Share Scarcity Allocation Engine for PDS DemandSync.

Implements rule-governed, auditable, and statutory-compliant grain allocations
under depot supply deficit / scarcity conditions:
    Aggregate Recommended Demand > Available Depot Stock

Three-Tier Allocation Algorithm:
1. Tier 1 (Statutory Protection): Guarantee statutory floor requirement for each FPS.
2. Tier 2 (Risk-Weighted Fair Share): Distribute remaining unallocated depot stock proportionally
   to baseline demand scaled by ML stockout probability: weight_i = Demand_i * (1.0 + Risk_i).
3. Tier 3 (Physical Ceilings): Cap allocations at storage headroom and baseline demand.

Critical Governance Guarantees:
- ML predictions are strictly non-decisional risk coefficients (weights).
- Final allocations are 100% deterministic, transparent, and reproducible.
- Statutory NFSA minimums are protected before any discretionary distribution.
- Generating a plan creates a PENDING_OFFICER_REVIEW record without mutating live dispatch records.
"""

import json
import uuid
import sqlite3
from typing import Dict, Any, List, Optional, Tuple
from app.core.config import settings
from app.services.stockout_risk_engine import stockout_risk_engine

DEMO_NOTICE = "DEMO DATA — NOT GOVERNMENT DATA (DETERMINISTIC FAIR-SHARE SCARCITY ENGINE)"

STRATEGIES = [
    "FAIR_SHARE_RISK_WEIGHTED",
    "PRO_RATA",
    "STATUTORY_FLOOR_PRIORITY"
]


class ScarcityAllocationEngine:
    """Core Service for Deterministic Fair-Share Allocation under Depot Scarcity."""

    def __init__(self):
        self.supported_strategies = STRATEGIES

    def calculate_statutory_floor(
        self,
        cursor: sqlite3.Cursor,
        fps_id: str,
        commodity: str = "Rice"
    ) -> Dict[str, float]:
        """
        Calculate mandatory statutory entitlement floor for an FPS:
        Statutory Requirement = beneficiaries_count * entitlement_per_card (e.g. 5 kg/person or family quota)
        Statutory Floor = max(0, Statutory Requirement - Current Stock)
        """
        cursor.execute("""
        SELECT beneficiaries_count, entitlement_rice_kg, entitlement_wheat_kg
        FROM fps WHERE fps_id = ?;
        """, (fps_id,))
        fps_row = cursor.fetchone()
        
        if not fps_row:
            beneficiaries = 100
            entitlement_per_unit = 25.0 if commodity == "Rice" else 10.0
        else:
            beneficiaries = int(fps_row["beneficiaries_count"] or 100)
            entitlement_per_unit = float(fps_row["entitlement_rice_kg"] if commodity == "Rice" else fps_row["entitlement_wheat_kg"])

        # Canonical NFSA statutory entitlement requirement: beneficiaries_count * entitlement_per_unit
        statutory_requirement_kg = round(beneficiaries * entitlement_per_unit, 1)

        # Fetch current on-hand stock
        cursor.execute("""
        SELECT COALESCE(available_quantity_kg, 0.0) FROM inventory
        WHERE fps_id = ? AND commodity = ?;
        """, (fps_id, commodity))
        inv_row = cursor.fetchone()
        current_inv_kg = float(inv_row[0]) if inv_row else 0.0

        statutory_floor_kg = max(0.0, round(statutory_requirement_kg - current_inv_kg, 1))

        return {
            "fps_id": fps_id,
            "commodity": commodity,
            "beneficiaries_count": beneficiaries,
            "statutory_requirement_kg": statutory_requirement_kg,
            "current_inventory_kg": current_inv_kg,
            "statutory_floor_kg": statutory_floor_kg
        }

    def simulate_scarcity_plan(
        self,
        db: sqlite3.Connection,
        depot_id: str = "DEPOT-01",
        commodity: str = "Rice",
        available_depot_stock_kg: float = 20000.0,
        cycle_id: str = settings.CURRENT_CYCLE,
        allocation_strategy: str = "FAIR_SHARE_RISK_WEIGHTED"
    ) -> Dict[str, Any]:
        """
        Pure in-memory simulation of deterministic fair-share scarcity allocation.
        Does NOT alter live dispatch records or SQLite database.
        """
        cursor = db.cursor()

        if allocation_strategy not in self.supported_strategies:
            allocation_strategy = "FAIR_SHARE_RISK_WEIGHTED"

        # 1. Fetch Depot Master Details
        cursor.execute("SELECT depot_id, name, district FROM depots WHERE depot_id = ?;", (depot_id,))
        depot_row = cursor.fetchone()
        depot_name = depot_row["name"] if depot_row else "Bengaluru Central FCI Godown (Hebbal)"

        # 2. Fetch all FPS serviced by this Depot
        cursor.execute("""
        SELECT p.fps_id, p.name as fps_name, p.district, p.capacity_kg, p.stockout_frequency,
               COALESCE(i.available_quantity_kg, 0.0) as current_stock_kg,
               COALESCE(f.predicted_quantity_kg, 4500.0) as forecast_kg,
               CASE WHEN f.recommended_dispatch_kg IS NOT NULL AND f.recommended_dispatch_kg > 0 THEN f.recommended_dispatch_kg
                    WHEN f.predicted_quantity_kg IS NOT NULL AND f.predicted_quantity_kg > 0 THEN f.predicted_quantity_kg
                    ELSE 3500.0 END as baseline_recommended_kg
        FROM fps p
        JOIN routes r ON p.fps_id = r.destination_fps_id AND r.source_depot_id = ?
        LEFT JOIN inventory i ON p.fps_id = i.fps_id AND i.commodity = ?
        LEFT JOIN forecast f ON p.fps_id = f.fps_id AND f.commodity = ? AND f.cycle_id = ?
        ORDER BY p.id ASC;
        """, (depot_id, commodity, commodity, cycle_id))
        fps_records = cursor.fetchall()

        if not fps_records:
            # Fallback to all FPS if route join yields none
            cursor.execute("""
            SELECT p.fps_id, p.name as fps_name, p.district, p.capacity_kg, p.stockout_frequency,
                   COALESCE(i.available_quantity_kg, 0.0) as current_stock_kg,
                   COALESCE(f.predicted_quantity_kg, 4500.0) as forecast_kg,
                   CASE WHEN f.recommended_dispatch_kg IS NOT NULL AND f.recommended_dispatch_kg > 0 THEN f.recommended_dispatch_kg
                        WHEN f.predicted_quantity_kg IS NOT NULL AND f.predicted_quantity_kg > 0 THEN f.predicted_quantity_kg
                        ELSE 3500.0 END as baseline_recommended_kg
            FROM fps p
            LEFT JOIN inventory i ON p.fps_id = i.fps_id AND i.commodity = ?
            LEFT JOIN forecast f ON p.fps_id = f.fps_id AND f.commodity = ? AND f.cycle_id = ?
            ORDER BY p.id ASC LIMIT 10;
            """, (commodity, commodity, cycle_id))
            fps_records = cursor.fetchall()

        fps_data: List[Dict[str, Any]] = []
        total_aggregate_demand_kg = 0.0
        total_statutory_floors_kg = 0.0

        for r in fps_records:
            fid = r["fps_id"]
            fname = r["fps_name"]
            cap = float(r["capacity_kg"])
            curr_stock = float(r["current_stock_kg"])
            forecast_kg = float(r["forecast_kg"])
            base_rec = float(r["baseline_recommended_kg"])

            # Compute canonical statutory floor
            floor_info = self.calculate_statutory_floor(cursor, fid, commodity)
            floor_kg = floor_info["statutory_floor_kg"]

            # Baseline ML stockout risk under statutory floor allocation
            initial_risk_res = stockout_risk_engine.predict_stockout_risk(
                cursor=cursor,
                fps_id=fid,
                commodity=commodity,
                proposed_allocation_kg=floor_kg,
                cycle_id=cycle_id
            )

            total_aggregate_demand_kg += base_rec
            total_statutory_floors_kg += floor_kg

            fps_data.append({
                "fps_id": fid,
                "fps_name": fname,
                "capacity_kg": cap,
                "current_stock_kg": curr_stock,
                "forecast_kg": forecast_kg,
                "baseline_recommended_kg": base_rec,
                "statutory_floor_kg": floor_kg,
                "headroom_kg": max(0.0, cap - curr_stock),
                "initial_stockout_risk": initial_risk_res["stockout_probability"],
                "initial_risk_tier": initial_risk_res["risk_tier"]
            })

        deficit_kg = max(0.0, round(total_aggregate_demand_kg - available_depot_stock_kg, 1))
        is_scarcity = deficit_kg > 0.0

        # Governance Status Determination
        if available_depot_stock_kg >= total_aggregate_demand_kg:
            scarcity_condition = "NO_SCARCITY"
            statutory_floor_status = "STATUTORY_FLOORS_SATISFIED"
            is_statutory_floor_satisfied = True
            governance_alert = None
        elif available_depot_stock_kg >= total_statutory_floors_kg:
            scarcity_condition = "FEASIBLE_SCARCITY"
            statutory_floor_status = "STATUTORY_FLOORS_SATISFIED"
            is_statutory_floor_satisfied = True
            governance_alert = None
        else:
            scarcity_condition = "CRITICAL_DEFICIT"
            statutory_floor_status = "STATUTORY_FLOORS_UNSATISFIABLE"
            is_statutory_floor_satisfied = False
            floor_deficit = round(total_statutory_floors_kg - available_depot_stock_kg, 1)
            governance_alert = f"STATUTORY_FLOORS_UNSATISFIABLE: Available depot stock ({available_depot_stock_kg:.1f} kg) is insufficient to meet mandatory statutory entitlement floors ({total_statutory_floors_kg:.1f} kg). Deficit = {floor_deficit:.1f} kg. Emergency buffer transfer required."

        # 3. Three-Tier Deterministic Allocation Algorithm
        allocated_items: List[Dict[str, Any]] = []

        if available_depot_stock_kg >= total_aggregate_demand_kg:
            # Case 0: Normal Feasible Supply (No Scarcity)
            for item in fps_data:
                final_alloc = min(max(item["baseline_recommended_kg"], item["statutory_floor_kg"]), item["headroom_kg"])
                risk_res = stockout_risk_engine.predict_stockout_risk(
                    cursor, item["fps_id"], commodity, final_alloc, cycle_id
                )
                allocated_items.append({
                    "fps_id": item["fps_id"],
                    "fps_name": item["fps_name"],
                    "baseline_recommended_kg": item["baseline_recommended_kg"],
                    "statutory_floor_kg": item["statutory_floor_kg"],
                    "reconciled_allocation_kg": final_alloc,
                    "statutory_floor_satisfied": True,
                    "floor_deficit_kg": 0.0,
                    "cut_kg": 0.0,
                    "cut_percentage": 0.0,
                    "predicted_stockout_risk": risk_res["stockout_probability"],
                    "risk_tier": risk_res["risk_tier"],
                    "mitigation_action": "Standard unconstrained supply dispatch."
                })
        elif available_depot_stock_kg < total_statutory_floors_kg:
            # Case 1: Extreme Scarcity (Stock less than statutory floors -> Infeasible State)
            # Pro-rata allocate all available stock strictly across statutory floors
            for item in fps_data:
                ratio = item["statutory_floor_kg"] / max(1.0, total_statutory_floors_kg)
                final_alloc = round(available_depot_stock_kg * ratio, 1)
                cut_kg = round(item["baseline_recommended_kg"] - final_alloc, 1)
                cut_pct = round((cut_kg / max(1.0, item["baseline_recommended_kg"])) * 100.0, 1)
                floor_def = max(0.0, round(item["statutory_floor_kg"] - final_alloc, 1))

                risk_res = stockout_risk_engine.predict_stockout_risk(
                    cursor, item["fps_id"], commodity, final_alloc, cycle_id
                )
                allocated_items.append({
                    "fps_id": item["fps_id"],
                    "fps_name": item["fps_name"],
                    "baseline_recommended_kg": item["baseline_recommended_kg"],
                    "statutory_floor_kg": item["statutory_floor_kg"],
                    "reconciled_allocation_kg": final_alloc,
                    "statutory_floor_satisfied": final_alloc >= item["statutory_floor_kg"],
                    "floor_deficit_kg": floor_def,
                    "cut_kg": cut_kg,
                    "cut_percentage": cut_pct,
                    "predicted_stockout_risk": risk_res["stockout_probability"],
                    "risk_tier": risk_res["risk_tier"],
                    "mitigation_action": "CRITICAL EMERGENCY: Available depot stock is insufficient to meet mandatory statutory entitlement floor. Inter-depot emergency transfer required."
                })
        else:
            # Case 2: Feasible Scarcity (Statutory Floors 100% guaranteed + Discretionary Fair Share)
            # Tier 1: Satisfy Statutory Floors
            remaining_stock_kg = available_depot_stock_kg - total_statutory_floors_kg

            # Tier 2: Calculate Deterministic Strategy Weights
            weights: List[float] = []
            for item in fps_data:
                if allocation_strategy == "FAIR_SHARE_RISK_WEIGHTED":
                    # Weight by baseline demand AND ML stockout risk multiplier
                    w = item["baseline_recommended_kg"] * (1.0 + item["initial_stockout_risk"])
                elif allocation_strategy == "PRO_RATA":
                    w = item["baseline_recommended_kg"]
                else:  # STATUTORY_FLOOR_PRIORITY
                    w = max(0.0, item["baseline_recommended_kg"] - item["statutory_floor_kg"])
                weights.append(max(0.01, w))

            sum_weights = sum(weights)

            # Tier 3: Distribute remaining stock subject to physical headroom & baseline demand ceilings
            temp_allocations = []
            for idx, item in enumerate(fps_data):
                add_fraction = weights[idx] / sum_weights
                additional_kg = remaining_stock_kg * add_fraction
                unconstrained_alloc = item["statutory_floor_kg"] + additional_kg

                # Ceiling: cannot exceed baseline recommended demand or physical storage headroom
                max_ceiling = min(item["baseline_recommended_kg"], item["headroom_kg"])
                final_alloc = round(max(item["statutory_floor_kg"], min(unconstrained_alloc, max_ceiling)), 1)
                temp_allocations.append(final_alloc)

            # Re-normalize if sum exceeds available stock due to rounding
            total_allocated = sum(temp_allocations)
            if total_allocated > available_depot_stock_kg:
                scale = available_depot_stock_kg / total_allocated
                temp_allocations = [round(a * scale, 1) for a in temp_allocations]

            for idx, item in enumerate(fps_data):
                final_alloc = temp_allocations[idx]
                cut_kg = round(item["baseline_recommended_kg"] - final_alloc, 1)
                cut_pct = round((cut_kg / max(1.0, item["baseline_recommended_kg"])) * 100.0, 1)

                # Re-evaluate final ML stockout risk with proposed allocation
                risk_res = stockout_risk_engine.predict_stockout_risk(
                    cursor, item["fps_id"], commodity, final_alloc, cycle_id
                )

                if risk_res["risk_tier"] == "CRITICAL":
                    action = "Schedule secondary split delivery on Day 12 to prevent depletion."
                elif risk_res["risk_tier"] == "ELEVATED":
                    action = "Monitor ePoS daily burn rate and trigger priority SMS buffer alerts."
                elif cut_pct > 0:
                    action = "Protected baseline entitlement; staggered replenishment recommended."
                else:
                    action = "Full allocation fulfilled without curtailment."

                allocated_items.append({
                    "fps_id": item["fps_id"],
                    "fps_name": item["fps_name"],
                    "baseline_recommended_kg": item["baseline_recommended_kg"],
                    "statutory_floor_kg": item["statutory_floor_kg"],
                    "reconciled_allocation_kg": final_alloc,
                    "statutory_floor_satisfied": True,
                    "floor_deficit_kg": 0.0,
                    "cut_kg": cut_kg,
                    "cut_percentage": cut_pct,
                    "predicted_stockout_risk": risk_res["stockout_probability"],
                    "risk_tier": risk_res["risk_tier"],
                    "mitigation_action": action
                })

        total_reconciled_kg = sum(a["reconciled_allocation_kg"] for a in allocated_items)
        avg_cut_pct = round((sum(a["cut_percentage"] for a in allocated_items) / max(1, len(allocated_items))), 1)
        critical_risk_count = sum(1 for a in allocated_items if a["risk_tier"] == "CRITICAL")
        elevated_risk_count = sum(1 for a in allocated_items if a["risk_tier"] == "ELEVATED")

        return {
            "status": "success",
            "simulation_mode": "READ_ONLY_SIMULATION",
            "cycle_id": cycle_id,
            "depot_id": depot_id,
            "depot_name": depot_name,
            "commodity": commodity,
            "aggregate_demand_kg": round(total_aggregate_demand_kg, 1),
            "available_depot_stock_kg": round(available_depot_stock_kg, 1),
            "deficit_kg": deficit_kg,
            "deficit_percentage": round((deficit_kg / max(1.0, total_aggregate_demand_kg)) * 100.0, 1),
            "is_scarcity_condition": is_scarcity,
            "scarcity_condition": scarcity_condition,
            "statutory_floor_status": statutory_floor_status,
            "is_statutory_floor_satisfied": is_statutory_floor_satisfied,
            "governance_alert": governance_alert,
            "allocation_strategy": allocation_strategy,
            "total_statutory_floors_kg": round(total_statutory_floors_kg, 1),
            "total_reconciled_allocation_kg": round(total_reconciled_kg, 1),
            "unallocated_depot_slack_kg": round(max(0.0, available_depot_stock_kg - total_reconciled_kg), 1),
            "average_cut_percentage": avg_cut_pct,
            "allocated_fps_count": len(allocated_items),
            "risk_summary": {
                "critical_risk_count": critical_risk_count,
                "elevated_risk_count": elevated_risk_count,
                "moderate_risk_count": sum(1 for a in allocated_items if a["risk_tier"] == "MODERATE"),
                "low_risk_count": sum(1 for a in allocated_items if a["risk_tier"] == "LOW")
            },
            "allocated_items": allocated_items,
            "governance_notice": DEMO_NOTICE
        }

    def persist_scarcity_plan(
        self,
        db: sqlite3.Connection,
        plan_simulation: Dict[str, Any],
        actor_name: str = "District Supply Officer (Demo Admin)",
        notes: str = "Simulated fair-share allocation generated under depot scarcity"
    ) -> Dict[str, Any]:
        """
        Persist candidate scarcity plan into SQLite tables:
        scarcity_allocation_plans (status: PENDING_OFFICER_REVIEW) and scarcity_allocation_items.
        Does NOT alter live dispatch records or forecast table.
        """
        cursor = db.cursor()
        cycle_id = plan_simulation["cycle_id"]
        depot_id = plan_simulation["depot_id"]
        commodity = plan_simulation["commodity"]
        plan_id = f"PLAN-SCARCITY-{cycle_id}-{depot_id}-{uuid.uuid4().hex[:6].upper()}"

        # 1. Insert into scarcity_allocation_plans
        cursor.execute("""
        INSERT INTO scarcity_allocation_plans (
            plan_id, cycle_id, depot_id, commodity, aggregate_demand_kg, available_stock_kg,
            deficit_kg, allocation_strategy, approval_status, approved_by, approval_notes,
            allocated_fps_count, created_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'PENDING_OFFICER_REVIEW', NULL, ?, ?, CURRENT_TIMESTAMP);
        """, (
            plan_id,
            cycle_id,
            depot_id,
            commodity,
            plan_simulation["aggregate_demand_kg"],
            plan_simulation["available_depot_stock_kg"],
            plan_simulation["deficit_kg"],
            plan_simulation["allocation_strategy"],
            notes,
            plan_simulation["allocated_fps_count"]
        ))

        # 2. Insert into scarcity_allocation_items
        for item in plan_simulation["allocated_items"]:
            cursor.execute("""
            INSERT INTO scarcity_allocation_items (
                plan_id, fps_id, commodity, baseline_recommended_kg, statutory_floor_kg,
                reconciled_allocation_kg, cut_percentage, predicted_stockout_risk, mitigation_action
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?);
            """, (
                plan_id,
                item["fps_id"],
                commodity,
                item["baseline_recommended_kg"],
                item["statutory_floor_kg"],
                item["reconciled_allocation_kg"],
                item["cut_percentage"],
                item["predicted_stockout_risk"],
                item["mitigation_action"]
            ))

        db.commit()

        return {
            "status": "success",
            "plan_id": plan_id,
            "approval_status": "PENDING_OFFICER_REVIEW",
            "cycle_id": cycle_id,
            "depot_id": depot_id,
            "commodity": commodity,
            "aggregate_demand_kg": plan_simulation["aggregate_demand_kg"],
            "available_stock_kg": plan_simulation["available_depot_stock_kg"],
            "deficit_kg": plan_simulation["deficit_kg"],
            "total_reconciled_allocation_kg": plan_simulation["total_reconciled_allocation_kg"],
            "allocated_fps_count": plan_simulation["allocated_fps_count"],
            "message": f"Scarcity plan '{plan_id}' successfully staged with status PENDING_OFFICER_REVIEW. Live dispatch records are unaltered.",
            "governance_notice": DEMO_NOTICE
        }

    def get_scarcity_plan(
        self,
        db: sqlite3.Connection,
        plan_id: str
    ) -> Optional[Dict[str, Any]]:
        """Retrieve persisted scarcity plan and itemized allocations from SQLite."""
        cursor = db.cursor()
        cursor.execute("SELECT * FROM scarcity_allocation_plans WHERE plan_id = ?;", (plan_id,))
        plan_row = cursor.fetchone()
        if not plan_row:
            return None

        cursor.execute("""
        SELECT i.*, p.name as fps_name
        FROM scarcity_allocation_items i
        JOIN fps p ON i.fps_id = p.fps_id
        WHERE i.plan_id = ?
        ORDER BY i.fps_id ASC;
        """, (plan_id,))
        item_rows = cursor.fetchall()

        return {
            "status": "success",
            "plan_id": plan_row["plan_id"],
            "cycle_id": plan_row["cycle_id"],
            "depot_id": plan_row["depot_id"],
            "commodity": plan_row["commodity"],
            "aggregate_demand_kg": float(plan_row["aggregate_demand_kg"]),
            "available_stock_kg": float(plan_row["available_stock_kg"]),
            "deficit_kg": float(plan_row["deficit_kg"]),
            "allocation_strategy": plan_row["allocation_strategy"],
            "approval_status": plan_row["approval_status"],
            "approved_by": plan_row["approved_by"],
            "approval_notes": plan_row["approval_notes"],
            "allocated_fps_count": int(plan_row["allocated_fps_count"]),
            "created_at": plan_row["created_at"],
            "approved_at": plan_row["approved_at"],
            "allocated_items": [dict(r) for r in item_rows],
            "governance_notice": DEMO_NOTICE
        }


scarcity_allocation_engine = ScarcityAllocationEngine()
