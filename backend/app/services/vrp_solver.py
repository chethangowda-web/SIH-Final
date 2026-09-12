"""
Vehicle Routing Problem (VRP) & Fleet Logistics Optimization Engine.
Computes multi-stop truck dispatch routes, distance matrices, and fuel optimization
from FCI/State Godowns to Fair Price Shops (FPS).
"""

import math
import sqlite3
from typing import List, Dict, Any

class VRPSolverEngine:
    def haversine_distance(self, lat1: float, lon1: float, lat2: float, lon2: float) -> float:
        """Calculate the great-circle distance between two points in km."""
        R = 6371.0  # Earth radius in kilometers
        dlat = math.radians(lat2 - lat1)
        dlon = math.radians(lon2 - lon1)
        a = (math.sin(dlat / 2) ** 2 +
             math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) * math.sin(dlon / 2) ** 2)
        c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
        return R * c

    def optimize_dispatch_routes(
        self,
        db: sqlite3.Connection,
        godown_lat: float = 13.0827,
        godown_lon: float = 77.5877,
        godown_name: str = "Central FCI Godown (Yelahanka Depot)",
        truck_capacity_kg: float = 10000.0
    ) -> Dict[str, Any]:
        """
        Solves multi-stop Capacitated Vehicle Routing Problem (CVRP)
        using Nearest-Neighbor heuristics with capacity constraints.
        """
        cursor = db.cursor()
        
        # 1. Fetch FPS locations and their current required replenishment quantities
        cursor.execute("""
            SELECT f.id, f.fps_id, f.name, f.district, f.latitude, f.longitude,
                   COALESCE(SUM(c.recommended_dispatch_kg), 5000.0) as total_demand_kg
            FROM fps f
            LEFT JOIN forecast c ON f.fps_id = c.fps_id
            GROUP BY f.fps_id
        """)
        fps_rows = cursor.fetchall()

        if not fps_rows:
            return {
                "godown": {"name": godown_name, "latitude": godown_lat, "longitude": godown_lon},
                "total_routes": 0,
                "routes": [],
                "summary": {"total_distance_km": 0, "total_payload_kg": 0, "fuel_saved_liters": 0}
            }

        # Convert to list of dicts for routing
        unvisited = []
        for r in fps_rows:
            unvisited.append({
                "id": r[0],
                "fps_id": r[1],
                "name": r[2],
                "district": r[3],
                "latitude": r[4],
                "longitude": r[5],
                "demand_kg": max(500.0, float(r[6]))
            })

        routes = []
        truck_counter = 1
        total_distance_all_trucks = 0.0
        total_payload_all_trucks = 0.0

        # Heuristic Route Construction: Group nearest FPS until truck capacity is reached
        while unvisited:
            current_lat, current_lon = godown_lat, godown_lon
            current_payload = 0.0
            route_stops = []
            route_distance = 0.0

            while unvisited:
                # Find nearest unvisited FPS to current location
                best_idx = None
                best_dist = float("inf")

                for idx, shop in enumerate(unvisited):
                    if current_payload + shop["demand_kg"] <= truck_capacity_kg:
                        d = self.haversine_distance(current_lat, current_lon, shop["latitude"], shop["longitude"])
                        if d < best_dist:
                            best_dist = d
                            best_idx = idx

                # If no shop fits in this truck, return truck to godown and start new truck
                if best_idx is None:
                    break

                target_shop = unvisited.pop(best_idx)
                route_distance += best_dist
                current_payload += target_shop["demand_kg"]
                current_lat, current_lon = target_shop["latitude"], target_shop["longitude"]

                route_stops.append({
                    "stop_number": len(route_stops) + 1,
                    "fps_id": target_shop["fps_id"],
                    "name": target_shop["name"],
                    "latitude": target_shop["latitude"],
                    "longitude": target_shop["longitude"],
                    "delivered_kg": round(target_shop["demand_kg"], 2),
                    "leg_distance_km": round(best_dist, 2)
                })

            # Return distance from last stop back to godown
            return_dist = self.haversine_distance(current_lat, current_lon, godown_lat, godown_lon)
            route_distance += return_dist

            routes.append({
                "truck_id": f"TRK-KA-01-00{truck_counter}",
                "truck_name": f"10 MT Dispatch Vehicle #{truck_counter}",
                "total_stops": len(route_stops),
                "payload_delivered_kg": round(current_payload, 2),
                "capacity_utilization_pct": round((current_payload / truck_capacity_kg) * 100, 1),
                "total_route_distance_km": round(route_distance, 2),
                "estimated_fuel_liters": round(route_distance * 0.28, 2),  # 3.5 km per liter
                "stops": route_stops
            })

            total_distance_all_trucks += route_distance
            total_payload_all_trucks += current_payload
            truck_counter += 1

        # Unoptimized baseline comparison (each shop gets individual round trip from godown)
        baseline_distance = 0.0
        for shop in fps_rows:
            dist = self.haversine_distance(godown_lat, godown_lon, shop[4], shop[5]) * 2
            baseline_distance += dist

        distance_saved_km = max(0.0, baseline_distance - total_distance_all_trucks)
        fuel_saved_liters = distance_saved_km * 0.28

        return {
            "godown": {
                "name": godown_name,
                "latitude": godown_lat,
                "longitude": godown_lon,
                "district": "Bengaluru Urban"
            },
            "total_routes": len(routes),
            "routes": routes,
            "optimization_summary": {
                "total_distance_optimized_km": round(total_distance_all_trucks, 2),
                "unoptimized_baseline_km": round(baseline_distance, 2),
                "distance_saved_km": round(distance_saved_km, 2),
                "fuel_saved_liters": round(fuel_saved_liters, 2),
                "co2_emissions_avoided_kg": round(fuel_saved_liters * 2.68, 2), # 2.68 kg CO2 per liter diesel
                "total_grain_dispatched_kg": round(total_payload_all_trucks, 2)
            }
        }

vrp_solver = VRPSolverEngine()
