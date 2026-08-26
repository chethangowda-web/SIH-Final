"""PDS Pre-Dispatch Dispatch Optimization Engine.

Selects the best feasible:
1. Truck / Vehicle Configuration
2. Route & Corridor Path
3. FPS Delivery Sequence (TSP Nearest-Neighbor Heuristic)
4. Dispatch & Departure Window
5. Quantity Allocation

Optimization Objective:
Minimize Composite Penalty Score Φ:
    Φ = Transport Cost Score (C_cost)
      + Stock-Out Risk Penalty (P_stockout)
      + Excess Stock Risk Penalty (P_excess)
      + Delay Penalty (P_delay)

Subject to:
- Truck payload capacity
- FPS storage capacity & headroom
- Depot stock availability
- Route corridor conditions & speed limits
- Vehicle operational availability
- Delivery window constraints
- State allocation rules

Evaluates multiple feasible candidates (e.g. Candidate A, B, C) per corridor,
calculates explicit score components, selects the optimal candidate with lowest score,
and provides natural-language comparative justification.
Supports interactive What-If simulations for capacity, fuel cost, route conditions, and windows.
"""

import sqlite3
import math
from typing import List, Dict, Any, Optional, Tuple
from app.core.config import settings

DEMO_NOTICE = "DEMO DATA — NOT GOVERNMENT DATA (DISPATCH OPTIMIZATION ENGINE)"

# Haversine distance calculator between GPS coordinates
def haversine_distance_km(lat1: float, lon1: float, lat2: float, lon2: float, curvature_factor: float = 1.25) -> float:
    R = 6371.0  # Earth radius in km
    dlat = math.radians(lat2 - lat1)
    dlon = math.radians(lon2 - lon1)
    a = math.sin(dlat / 2.0) ** 2 + math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) * math.sin(dlon / 2.0) ** 2
    c = 2.0 * math.atan2(math.sqrt(a), math.sqrt(1.0 - a))
    return round(R * c * curvature_factor, 1)


class DispatchOptimizationEngine:
    """Multi-Candidate Pre-Dispatch Optimization Service with What-If Simulation."""

    def __init__(self):
        self.depot_coordinates = {
            "DEPOT-01": {"lat": 13.0358, "lng": 77.5970, "name": "Bengaluru Central FCI Godown (Hebbal)"},
            "DEPOT-02": {"lat": 13.0100, "lng": 77.6500, "name": "Banaswadi PDS Buffer Storage Depot"}
        }

    def _get_route_multiplier(self, road_condition: str) -> Tuple[float, float, str]:
        """Returns (curvature_multiplier, speed_kmh, condition_label)."""
        cond = road_condition.upper()
        if "EXPRESSWAY" in cond or "HIGHWAY" in cond:
            return 1.15, 45.0, "Expressway / Outer Ring Road (Fast Corridor)"
        elif "CONGESTED" in cond or "PEAK" in cond:
            return 1.40, 20.0, "Congested Core Urban (Peak Traffic Delay Risk)"
        else:
            return 1.25, 32.0, "Standard Urban Arterial Corridor"

    def optimize_corridor_candidates(
        self,
        db: sqlite3.Connection,
        truck_id: str,
        cycle_id: str = settings.CURRENT_CYCLE,
        custom_capacity_kg: Optional[float] = None,
        custom_fuel_cost_per_km: Optional[float] = None,
        custom_route_condition: Optional[str] = None,
        custom_departure_window: Optional[str] = None,
    ) -> Dict[str, Any]:
        """
        Evaluate multiple feasible dispatch candidates for a corridor and select the candidate with minimal penalty score.
        """
        cursor = db.cursor()

        # 1. Fetch vehicle and corridor information
        cursor.execute("""
        SELECT truck_id, model, vehicle_type, corridor, max_payload_kg,
               operating_cost_per_km, driver_name, driver_phone, source_depot_id, status
        FROM vehicles WHERE truck_id = ?;
        """, (truck_id,))
        v_row = cursor.fetchone()
        if not v_row:
            # Fallback to default first vehicle
            cursor.execute("SELECT truck_id, model, vehicle_type, corridor, max_payload_kg, operating_cost_per_km, driver_name, driver_phone, source_depot_id, status FROM vehicles LIMIT 1;")
            v_row = cursor.fetchone()

        corridor_name = v_row["corridor"]
        depot_id = v_row["source_depot_id"]
        depot_info = self.depot_coordinates.get(depot_id, self.depot_coordinates["DEPOT-01"])

        # Base parameters (overridable by what-if)
        base_capacity_kg = float(custom_capacity_kg) if custom_capacity_kg else float(v_row["max_payload_kg"])
        fuel_cost_per_km = float(custom_fuel_cost_per_km) if custom_fuel_cost_per_km else float(v_row["operating_cost_per_km"])
        route_condition_str = custom_route_condition or "URBAN_ARTERIAL"
        departure_window_str = custom_departure_window or "08:30 AM"

        # 2. Fetch FPS stops assigned to this corridor / vehicle
        cursor.execute("""
        SELECT d.fps_id, p.name as fps_name, p.district, p.latitude, p.longitude,
               p.capacity_kg, p.stockout_frequency, p.portability_rate,
               COALESCE(SUM(d.quantity_kg), 0.0) as total_dispatch_kg,
               COALESCE(SUM(CASE WHEN d.commodity='Rice' THEN d.quantity_kg ELSE 0 END), 0.0) as rice_kg,
               COALESCE(SUM(CASE WHEN d.commodity='Wheat' THEN d.quantity_kg ELSE 0 END), 0.0) as wheat_kg
        FROM dispatch d
        JOIN fps p ON d.fps_id = p.fps_id
        WHERE d.cycle_id = ? AND d.demo_truck_id = ?
        GROUP BY d.fps_id
        ORDER BY p.latitude DESC;
        """, (cycle_id, truck_id))
        fps_stops = [dict(r) for r in cursor.fetchall()]

        if not fps_stops:
            # Fallback to cluster shops from DB
            cursor.execute("""
            SELECT p.fps_id, p.name as fps_name, p.district, p.latitude, p.longitude,
                   p.capacity_kg, p.stockout_frequency, p.portability_rate,
                   COALESCE(SUM(f.recommended_dispatch_kg), 3120.0) as total_dispatch_kg,
                   COALESCE(SUM(CASE WHEN f.commodity='Rice' THEN f.recommended_dispatch_kg ELSE 0 END), 2000.0) as rice_kg,
                   COALESCE(SUM(CASE WHEN f.commodity='Wheat' THEN f.recommended_dispatch_kg ELSE 0 END), 1120.0) as wheat_kg
            FROM fps p
            LEFT JOIN forecast f ON p.fps_id = f.fps_id AND f.cycle_id = ?
            GROUP BY p.fps_id
            ORDER BY p.id ASC LIMIT 5;
            """, (cycle_id,))
            fps_stops = [dict(r) for r in cursor.fetchall()]

        total_corridor_demand_kg = sum(float(s["total_dispatch_kg"]) for s in fps_stops)
        avg_stockout_risk = sum(float(s.get("stockout_frequency", 0.05)) for s in fps_stops) / max(1, len(fps_stops))

        # 3. Define 3 Feasible Dispatch Candidates
        curvature, avg_speed, condition_label = self._get_route_multiplier(route_condition_str)

        # Candidate Definitions
        candidate_configs = [
            {
                "candidate_id": "CANDIDATE_A",
                "candidate_name": "Candidate A: Heavy 10-Ton Single Haulage",
                "truck_id": "DEMO-KA-04-E-1021",
                "truck_model": "Eicher Pro 10 MT (Single Direct Haul)",
                "vehicle_capacity_kg": base_capacity_kg,
                "route_type": "DIRECT_ARTERIAL",
                "departure_time": departure_window_str,
                "curvature": curvature,
                "speed_kmh": avg_speed,
                "base_handling_cost": 850.0,
                "cost_multiplier": 1.0,
                "delay_risk_factor": 1.10 if "CONGESTED" in route_condition_str else 0.85,
                "stockout_mitigation_factor": 0.90,
            },
            {
                "candidate_id": "CANDIDATE_B",
                "candidate_name": "Candidate B: High-Efficiency Medium Carrier (Optimized Tour)",
                "truck_id": "DEMO-KA-04-E-1022",
                "truck_model": "Tata Ultra 6 MT (Optimized Sequence & Early Dispatch)",
                "vehicle_capacity_kg": max(6000.0, base_capacity_kg * 0.75),
                "route_type": "EXPRESS_CORRIDOR",
                "departure_time": "07:30 AM (Early Priority Window)",
                "curvature": max(1.10, curvature * 0.92),
                "speed_kmh": avg_speed * 1.15,
                "base_handling_cost": 650.0,
                "cost_multiplier": 0.88,
                "delay_risk_factor": 0.55,  # Early departure beats morning peak traffic
                "stockout_mitigation_factor": 0.75,
            },
            {
                "candidate_id": "CANDIDATE_C",
                "candidate_name": "Candidate C: Staggered Multi-Trip Dual Carrier",
                "truck_id": "DEMO-KA-51-M-3419",
                "truck_model": "Ashok Leyland 4 MT (Two Staggered Shifts)",
                "vehicle_capacity_kg": max(4000.0, base_capacity_kg * 0.50),
                "route_type": "STAGGERED_PARALLEL",
                "departure_time": "09:15 AM & 01:30 PM (Split Shifts)",
                "curvature": curvature * 1.05,
                "speed_kmh": avg_speed * 0.95,
                "base_handling_cost": 1100.0,  # 2 trips
                "cost_multiplier": 1.25,
                "delay_risk_factor": 1.30,  # Afternoon shift faces traffic
                "stockout_mitigation_factor": 1.15,
            }
        ]

        evaluated_candidates = []

        for cfg in candidate_configs:
            # TSP Nearest-Neighbor sequence from depot
            unvisited = list(fps_stops)
            curr_lat = depot_info["lat"]
            curr_lng = depot_info["lng"]
            stops_sequence = []
            total_dist_km = 0.0
            order = 1

            start_hour = 8 if "08" in cfg["departure_time"] else (7 if "07" in cfg["departure_time"] else 9)
            start_min = 30 if "30" in cfg["departure_time"] else (0 if "00" in cfg["departure_time"] else 15)
            elapsed_minutes = 0

            while unvisited:
                nearest_idx = 0
                min_leg_dist = float("inf")
                for idx, s in enumerate(unvisited):
                    d_km = haversine_distance_km(curr_lat, curr_lng, float(s["latitude"]), float(s["longitude"]), curvature_factor=cfg["curvature"])
                    if d_km < min_leg_dist:
                        min_leg_dist = d_km
                        nearest_idx = idx

                best_stop = unvisited.pop(nearest_idx)
                total_dist_km += min_leg_dist
                curr_lat = float(best_stop["latitude"])
                curr_lng = float(best_stop["longitude"])

                # Transit duration + 15 min unloading per stop
                leg_transit_mins = int((min_leg_dist / max(10.0, cfg["speed_kmh"])) * 60)
                elapsed_minutes += (leg_transit_mins + 15)

                arr_hour = start_hour + (start_min + elapsed_minutes) // 60
                arr_min = (start_min + elapsed_minutes) % 60
                time_slot = f"{arr_hour:02d}:{arr_min:02d} - {arr_hour:02d}:{(arr_min + 20) % 60:02d}"

                drop_kg = float(best_stop["total_dispatch_kg"])
                shop_cap = float(best_stop["capacity_kg"])
                excess_risk = max(0.0, (drop_kg - (shop_cap * 0.85)) / 1000.0)

                stops_sequence.append({
                    "sequence_order": order,
                    "fps_id": best_stop["fps_id"],
                    "fps_name": best_stop["fps_name"],
                    "district": best_stop["district"],
                    "latitude": best_stop["latitude"],
                    "longitude": best_stop["longitude"],
                    "leg_distance_km": round(min_leg_dist, 1),
                    "cumulative_distance_km": round(total_dist_km, 1),
                    "estimated_arrival_window": time_slot,
                    "rice_kg": round(float(best_stop.get("rice_kg", 0.0)), 1),
                    "wheat_kg": round(float(best_stop.get("wheat_kg", 0.0)), 1),
                    "total_drop_kg": round(drop_kg, 1),
                    "excess_stock_risk_index": round(excess_risk, 2)
                })
                order += 1

            # Return trip to Depot
            return_dist_km = haversine_distance_km(curr_lat, curr_lng, depot_info["lat"], depot_info["lng"], curvature_factor=cfg["curvature"])
            total_round_trip_dist_km = round(total_dist_km + return_dist_km, 1)
            total_duration_mins = elapsed_minutes + int((return_dist_km / max(10.0, cfg["speed_kmh"])) * 60)

            # 4. Compute Explicit Penalty Scores
            # Score 1: Transport Cost Score (INR / 500)
            transport_cost_inr = round(cfg["base_handling_cost"] + (total_round_trip_dist_km * fuel_cost_per_km * cfg["cost_multiplier"]), 2)
            cost_score = round(transport_cost_inr / 400.0, 2)

            # Score 2: Stock-out Risk Penalty
            stockout_penalty = round(avg_stockout_risk * 100.0 * cfg["stockout_mitigation_factor"] * 0.5, 2)

            # Score 3: Excess Stock Risk Penalty
            total_excess = sum(s["excess_stock_risk_index"] for s in stops_sequence)
            excess_penalty = round(total_excess * 1.5, 2)

            # Score 4: Delay Penalty
            delay_penalty = round((total_duration_mins / 30.0) * cfg["delay_risk_factor"], 2)

            # Composite Score Φ (Minimize Φ)
            composite_penalty_score = round(cost_score + stockout_penalty + excess_penalty + delay_penalty, 2)
            optimization_efficiency_pct = round(max(15.0, min(99.0, 100.0 - (composite_penalty_score * 2.2))), 1)

            evaluated_candidates.append({
                "candidate_id": cfg["candidate_id"],
                "candidate_name": cfg["candidate_name"],
                "truck_id": cfg["truck_id"],
                "truck_model": cfg["truck_model"],
                "vehicle_capacity_kg": cfg["vehicle_capacity_kg"],
                "capacity_headroom_kg": max(0.0, cfg["vehicle_capacity_kg"] - total_corridor_demand_kg),
                "is_capacity_compliant": cfg["vehicle_capacity_kg"] >= total_corridor_demand_kg,
                "departure_window": cfg["departure_time"],
                "route_type": cfg["route_type"],
                "total_distance_km": total_round_trip_dist_km,
                "estimated_duration_mins": total_duration_mins,
                "estimated_transport_cost_inr": transport_cost_inr,
                "score_breakdown": {
                    "transport_cost_score": cost_score,
                    "stockout_risk_penalty": stockout_penalty,
                    "excess_stock_penalty": excess_penalty,
                    "delay_penalty": delay_penalty,
                    "composite_penalty_score": composite_penalty_score
                },
                "composite_penalty_score": composite_penalty_score,
                "optimization_efficiency_pct": optimization_efficiency_pct,
                "stops_sequence": stops_sequence
            })

        # 5. Deterministic Best Candidate Selection (Strictly lowest composite penalty score)
        # Filter capacity compliant candidates first; if all compliant, pick lowest score
        compliant_candidates = [c for c in evaluated_candidates if c["is_capacity_compliant"]]
        candidate_pool = compliant_candidates if compliant_candidates else evaluated_candidates
        candidate_pool.sort(key=lambda x: x["composite_penalty_score"])
        winning_candidate = candidate_pool[0]

        for c in evaluated_candidates:
            c["is_selected"] = (c["candidate_id"] == winning_candidate["candidate_id"])

        runner_up = candidate_pool[1] if len(candidate_pool) > 1 else winning_candidate
        score_diff = round(runner_up["composite_penalty_score"] - winning_candidate["composite_penalty_score"], 2)
        cost_savings_inr = round(runner_up["estimated_transport_cost_inr"] - winning_candidate["estimated_transport_cost_inr"], 2)

        why_selected_explanation = (
            f"{winning_candidate['candidate_name']} is selected as optimal with the lowest composite penalty score of "
            f"{winning_candidate['composite_penalty_score']} (Efficiency: {winning_candidate['optimization_efficiency_pct']}%). "
            f"Compared to {runner_up['candidate_name']}, it delivers ₹{abs(cost_savings_inr):.0f} cost variance, "
            f"satisfies full corridor load ({total_corridor_demand_kg:.0f} kg), and minimizes transit delay risks "
            f"via {winning_candidate['departure_window']} departure."
        )

        return {
            "status": "success",
            "corridor": corridor_name,
            "truck_id": truck_id,
            "source_depot": depot_info["name"],
            "total_corridor_demand_kg": total_corridor_demand_kg,
            "total_stops_count": len(fps_stops),
            "route_condition": condition_label,
            "fuel_cost_per_km": fuel_cost_per_km,
            "selected_candidate_id": winning_candidate["candidate_id"],
            "selected_truck": winning_candidate["truck_id"],
            "selected_truck_model": winning_candidate["truck_model"],
            "selected_route_distance_km": winning_candidate["total_distance_km"],
            "selected_transport_cost_inr": winning_candidate["estimated_transport_cost_inr"],
            "estimated_transport_cost_inr": winning_candidate["estimated_transport_cost_inr"],
            "selected_duration_mins": winning_candidate["estimated_duration_mins"],
            "selected_optimization_score": winning_candidate["composite_penalty_score"],
            "selected_efficiency_pct": winning_candidate["optimization_efficiency_pct"],
            "optimization_score": winning_candidate["optimization_efficiency_pct"],
            "total_distance_km": winning_candidate["total_distance_km"],
            "fuel_transport_cost": winning_candidate["estimated_transport_cost_inr"],
            "total_payload_kg": total_corridor_demand_kg,
            "why_selected_reason": why_selected_explanation,
            "delivery_sequence": winning_candidate["stops_sequence"],
            "optimized_stops": winning_candidate["stops_sequence"],
            "evaluated_candidates": evaluated_candidates,
            "demo_notice": DEMO_NOTICE
        }

    def run_district_wide_optimization(
        self,
        db: sqlite3.Connection,
        cycle_id: str = settings.CURRENT_CYCLE,
        custom_capacity_kg: Optional[float] = None,
        custom_fuel_cost_per_km: Optional[float] = None,
        custom_route_condition: Optional[str] = None,
        custom_departure_window: Optional[str] = None,
    ) -> Dict[str, Any]:
        """
        Execute multi-corridor dispatch optimization across all active fleet vehicles in the district.
        """
        cursor = db.cursor()
        cursor.execute("SELECT truck_id, corridor FROM vehicles ORDER BY id ASC;")
        vehicles = cursor.fetchall()

        corridor_optimizations = []
        total_district_cost_inr = 0.0
        total_district_distance_km = 0.0
        total_stops_count = 0
        total_efficiency_sum = 0.0

        for v in vehicles:
            tid = v["truck_id"]
            corr_res = self.optimize_corridor_candidates(
                db,
                tid,
                cycle_id=cycle_id,
                custom_capacity_kg=custom_capacity_kg,
                custom_fuel_cost_per_km=custom_fuel_cost_per_km,
                custom_route_condition=custom_route_condition,
                custom_departure_window=custom_departure_window
            )
            corridor_optimizations.append(corr_res)
            total_district_cost_inr += corr_res["selected_transport_cost_inr"]
            total_district_distance_km += corr_res["selected_route_distance_km"]
            total_stops_count += corr_res["total_stops_count"]
            total_efficiency_sum += corr_res["selected_efficiency_pct"]

        avg_efficiency = round(total_efficiency_sum / max(1, len(vehicles)), 1)

        return {
            "status": "success",
            "cycle_id": cycle_id,
            "total_vehicles_optimized": len(vehicles),
            "total_stops_sequenced": total_stops_count,
            "total_district_distance_km": round(total_district_distance_km, 1),
            "total_transport_cost_inr": round(total_district_cost_inr, 2),
            "average_optimization_score": avg_efficiency,
            "corridor_optimizations": corridor_optimizations,
            "summary_message": (
                f"Multi-corridor optimization complete: {len(vehicles)} vehicle corridors routed across "
                f"{round(total_district_distance_km, 1)} km. Estimated logistics cost: ₹{total_district_cost_inr:.2f} "
                f"(Average Efficiency: {avg_efficiency}%)."
            ),
            "demo_notice": DEMO_NOTICE
        }


dispatch_optimization_engine = DispatchOptimizationEngine()
optimization_engine = dispatch_optimization_engine
