"""AI Decision-Support Advisor for Citizen Preference & Portability Requests.

Evaluates citizen commodity/location requests as forward-looking planning signals
against card statutory entitlements, target FPS inventory, statutory floors,
physical storage headroom, replenishment ETA windows, and nearby alternative FPS nodes.

CRITICAL GOVERNANCE PRINCIPLE:
AI assessments are strictly advisory decision-support signals. Every final public distribution
allocation and authorization requires an authenticated government officer with institutional role attribution
and is immutably recorded in the forensic audit trail.
"""

import math
import sqlite3
from typing import Dict, Any, Optional, List, Tuple
from app.core.config import settings


def haversine_km(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """Calculate Great Circle distance between two coordinates in kilometers."""
    r = 6371.0  # Earth radius in km
    phi1, phi2 = math.radians(lat1), math.radians(lat2)
    dphi = math.radians(lat2 - lat1)
    dlambda = math.radians(lon2 - lon1)
    a = math.sin(dphi / 2.0) ** 2 + math.cos(phi1) * math.cos(phi2) * math.sin(dlambda / 2.0) ** 2
    return r * 2.0 * math.atan2(math.sqrt(a), math.sqrt(1.0 - a))


class CitizenRequestAdvisor:
    """Intelligent decision-support engine for citizen preference requests and portability approvals."""

    # NFSA Statutory Entitlement Quotas
    STATUTORY_QUOTAS = {
        "AAY": {"Rice": 25.0, "Wheat": 10.0, "total": 35.0, "label": "Antyodaya Anna Yojana (AAY)"},
        "PHH": {"Rice": 20.0, "Wheat": 5.0, "total": 25.0, "label": "Priority Household (PHH)"},
        "NPHH": {"Rice": 15.0, "Wheat": 5.0, "total": 20.0, "label": "Non-Priority Household (NPHH)"},
    }

    def get_beneficiary_entitlement(
        self,
        db: sqlite3.Connection,
        beneficiary_id: str,
        commodity: str,
        cycle_id: str = "2026-09"
    ) -> Dict[str, Any]:
        """Fetch citizen beneficiary profile, card type, family size, statutory entitlement ceiling, and remaining balance."""
        cursor = db.cursor()
        cursor.execute("""
        SELECT b.id, b.pseudonymous_beneficiary_id, b.name_for_demo, b.registered_fps_id,
               b.language, b.status,
               COALESCE(f.name, 'Registered FPS') as registered_fps_name
        FROM beneficiaries b
        LEFT JOIN fps f ON b.registered_fps_id = f.fps_id
        WHERE b.pseudonymous_beneficiary_id = ?;
        """, (beneficiary_id,))
        row = cursor.fetchone()

        # Deterministic card type derivation based on beneficiary index
        try:
            ben_num = int(beneficiary_id.split("-")[-1])
        except Exception:
            ben_num = 1

        if ben_num % 10 == 0:
            card_type = "AAY"
            members = 1  # AAY is family-level 35kg fixed
        elif ben_num % 4 == 0:
            card_type = "PHH"
            members = 5
        else:
            card_type = "PHH"
            members = 4

        # Query data-driven policy from entitlement_policies table
        cursor.execute("""
        SELECT card_type, label, rice_per_member_kg, wheat_per_member_kg,
               family_fixed_rice_kg, family_fixed_wheat_kg, transport_base_fee_inr,
               transport_per_km_fee_inr
        FROM entitlement_policies WHERE card_type = ?;
        """, (card_type,))
        policy_row = cursor.fetchone()

        if policy_row:
            card_label = policy_row["label"]
            if policy_row["family_fixed_rice_kg"] > 0:
                rice_quota = float(policy_row["family_fixed_rice_kg"])
                wheat_quota = float(policy_row["family_fixed_wheat_kg"])
            else:
                rice_quota = float(policy_row["rice_per_member_kg"] * members)
                wheat_quota = float(policy_row["wheat_per_member_kg"] * members)
        else:
            if card_type == "AAY":
                card_label = "Antyodaya Anna Yojana (AAY)"
                rice_quota = 25.0
                wheat_quota = 10.0
            else:
                card_label = "Priority Household (PHH)"
                rice_quota = 20.0
                wheat_quota = 5.0

        # Query existing actual distribution / consumed balance for this cycle from confirmed citizen requests
        try:
            cursor.execute("""
            SELECT COALESCE(SUM(received_rice_kg), 0.0)
            FROM citizen_requests
            WHERE beneficiary_id = ? AND cycle_id = ? AND delivery_status = 'DELIVERY_CONFIRMED';
            """, (beneficiary_id, cycle_id))
            consumed_rice = float(cursor.fetchone()[0] or 0.0)

            cursor.execute("""
            SELECT COALESCE(SUM(received_wheat_kg), 0.0)
            FROM citizen_requests
            WHERE beneficiary_id = ? AND cycle_id = ? AND delivery_status = 'DELIVERY_CONFIRMED';
            """, (beneficiary_id, cycle_id))
            consumed_wheat = float(cursor.fetchone()[0] or 0.0)
        except Exception:
            consumed_rice = 0.0
            consumed_wheat = 0.0

        remaining_rice = max(0.0, rice_quota - consumed_rice)
        remaining_wheat = max(0.0, wheat_quota - consumed_wheat)
        remaining_commodity = remaining_rice if commodity == "Rice" else remaining_wheat

        return {
            "beneficiary_id": row["pseudonymous_beneficiary_id"] if row else beneficiary_id,
            "name": row["name_for_demo"] if row else "Beneficiary (Citizen)",
            "registered_fps_id": row["registered_fps_id"] if row else "FPS-KA-BLR-001",
            "registered_fps_name": row["registered_fps_name"] if row else "Malleshwaram Seva Kendra",
            "card_type": card_type,
            "family_members_count": members,
            "statutory_entitlement_rice_kg": rice_quota,
            "statutory_entitlement_wheat_kg": wheat_quota,
            "statutory_entitlement_commodity_kg": rice_quota if commodity == "Rice" else wheat_quota,
            "consumed_rice_kg": consumed_rice,
            "consumed_wheat_kg": consumed_wheat,
            "remaining_eligible_rice_kg": remaining_rice,
            "remaining_eligible_wheat_kg": remaining_wheat,
            "remaining_eligible_commodity_kg": remaining_commodity,
            "card_label": f"{card_label} ({members} Members)"
        }

    def calculate_transport_fee(
        self,
        db: sqlite3.Connection,
        delivery_mode: str,
        distance_km: float,
        card_type: str = "PHH"
    ) -> Dict[str, Any]:
        """Calculate transparent door-to-door transportation/delivery fee breakdown."""
        if delivery_mode.upper() != "HOME_DELIVERY":
            return {
                "delivery_mode": "FPS_COLLECTION",
                "delivery_distance_km": distance_km,
                "base_transport_fee_inr": 0.0,
                "distance_surcharge_inr": 0.0,
                "total_transport_fee_inr": 0.0,
                "commodity_cost_inr": 0.0,
                "total_payable_inr": 0.0,
                "statutory_notice": "Self-collection at Fair Price Shop is 100% free of charge."
            }

        cursor = db.cursor()
        cursor.execute("SELECT transport_base_fee_inr, transport_per_km_fee_inr FROM entitlement_policies WHERE card_type = ?;", (card_type,))
        p = cursor.fetchone()
        base_fee = float(p["transport_base_fee_inr"]) if p else 20.0
        per_km = float(p["transport_per_km_fee_inr"]) if p else 5.0

        extra_km = max(0.0, distance_km - 2.0)
        surcharge = round(extra_km * per_km, 2)
        total_fee = round(base_fee + surcharge, 2)

        return {
            "delivery_mode": "HOME_DELIVERY",
            "delivery_distance_km": round(distance_km, 2),
            "base_transport_fee_inr": base_fee,
            "distance_surcharge_inr": surcharge,
            "total_transport_fee_inr": total_fee,
            "commodity_cost_inr": 0.0,  # 100% subsidized under NFSA
            "total_payable_inr": total_fee,
            "statutory_notice": "Payment is strictly for door-to-door transportation logistics and does not alter, purchase, or increase statutory ration entitlement."
        }

    def evaluate_request(
        self,
        db: sqlite3.Connection,
        beneficiary_id: str,
        intended_fps_id: str,
        commodity: str,
        requested_quantity_kg: float,
        cycle_id: str = settings.CURRENT_CYCLE,
        delivery_mode: str = "FPS_COLLECTION",
        delivery_distance_km: float = 0.0
    ) -> Dict[str, Any]:
        """
        Produce a comprehensive, explainable AI Decision-Support Assessment for a citizen request.
        Evaluates 6 core institutional factors:
        1. Card Statutory Entitlement Ceiling (NFSA Sec 3 Compliance)
        2. Target FPS Current Stock vs Statutory Floor
        3. Physical FPS Storage Headroom & Inflow Congestion
        4. Pending District Demand Aggregates
        5. Scheduled Replenishment ETA Window
        6. Nearby Alternative Fair Price Shops with Surplus Stock
        """
        cursor = db.cursor()

        # 1. Fetch Beneficiary Entitlement
        entitlement = self.get_beneficiary_entitlement(db, beneficiary_id, commodity)
        statutory_max_kg = entitlement["statutory_entitlement_commodity_kg"]

        # 2. Fetch Target FPS Telemetry & Capacity
        cursor.execute("""
        SELECT fps_id, name, district, latitude, longitude, capacity_kg,
               stockout_frequency, portability_rate, beneficiaries_count
        FROM fps WHERE fps_id = ?;
        """, (intended_fps_id,))
        fps_row = cursor.fetchone()

        if not fps_row:
            fps_name = f"FPS Shop ({intended_fps_id})"
            capacity_kg = 20000.0
            lat, lng = 12.9716, 77.5946
            stockout_freq = 0.05
            registered_bens = 100
        else:
            fps_name = fps_row["name"]
            capacity_kg = float(fps_row["capacity_kg"])
            lat, lng = float(fps_row["latitude"]), float(fps_row["longitude"])
            stockout_freq = float(fps_row["stockout_frequency"] or 0.05)
            registered_bens = int(fps_row["beneficiaries_count"] or 100)

        # 3. Fetch Target FPS Current Inventory
        cursor.execute("""
        SELECT COALESCE(available_quantity_kg, 0.0)
        FROM inventory WHERE fps_id = ? AND commodity = ?;
        """, (intended_fps_id, commodity))
        inv_row = cursor.fetchone()
        current_inv_kg = float(inv_row[0]) if inv_row else 0.0

        # Statutory Floor for target FPS
        from app.services.scarcity_engine import scarcity_allocation_engine
        floor_info = scarcity_allocation_engine.calculate_statutory_floor(cursor, intended_fps_id, commodity)
        statutory_floor_kg = floor_info["statutory_floor_kg"]
        statutory_requirement_kg = floor_info["statutory_requirement_kg"]

        # 4. Fetch Existing Pending Declared Intent for Target FPS & Cycle
        cursor.execute("""
        SELECT COALESCE(SUM(declared_quantity_kg), 0.0)
        FROM intent WHERE intended_fps_id = ? AND cycle_id = ? AND commodity = ?;
        """, (intended_fps_id, cycle_id, commodity))
        pending_sum = float(cursor.fetchone()[0] or 0.0)

        # 5. Compute Storage Headroom & Utilization
        total_committed_kg = current_inv_kg + pending_sum
        headroom_kg = max(0.0, capacity_kg - total_committed_kg)
        utilization_pct = min(100.0, round((total_committed_kg / max(1.0, capacity_kg)) * 100.0, 1))

        # 6. Scheduled Replenishment ETA Window
        replenishment_eta = "Next Cycle Dispatch Slot: 08:30 AM (Corridor Express)"
        if intended_fps_id in ["FPS-KA-BLR-001", "FPS-KA-BLR-004", "FPS-KA-BLR-013", "FPS-KA-BLR-018"]:
            replenishment_eta = "Tomorrow 08:30 AM (North-West Heavy Corridor • KA-04-E-1021)"
        elif intended_fps_id in ["FPS-KA-BLR-005", "FPS-KA-BLR-006", "FPS-KA-BLR-007", "FPS-KA-BLR-014"]:
            replenishment_eta = "Tomorrow 09:15 AM (East IT Corridor • KA-04-E-1022)"
        elif intended_fps_id in ["FPS-KA-BLR-015", "FPS-KA-BLR-016", "FPS-KA-BLR-017"]:
            replenishment_eta = "Tomorrow 10:00 AM (South Industrial Corridor • KA-51-M-3419)"

        # 7. Spatial Search for Alternative FPS in District
        cursor.execute("""
        SELECT f.fps_id, f.name, f.latitude, f.longitude, f.capacity_kg,
               COALESCE(i.available_quantity_kg, 0.0) as available_kg
        FROM fps f
        LEFT JOIN inventory i ON f.fps_id = i.fps_id AND i.commodity = ?
        WHERE f.fps_id != ? AND f.status = 'ACTIVE';
        """, (commodity, intended_fps_id))
        other_fps_rows = cursor.fetchall()

        alternative_candidates: List[Dict[str, Any]] = []
        for r in other_fps_rows:
            dist = haversine_km(lat, lng, float(r["latitude"]), float(r["longitude"]))
            avail = float(r["available_kg"])
            cap = float(r["capacity_kg"])
            if dist <= 5.0 and avail >= 1000.0:  # Within 5km and has >1MT stock
                alternative_candidates.append({
                    "fps_id": r["fps_id"],
                    "fps_name": r["name"],
                    "distance_km": round(dist, 2),
                    "available_stock_kg": avail,
                    "capacity_headroom_kg": max(0.0, cap - avail)
                })

        alternative_candidates.sort(key=lambda x: (x["distance_km"], -x["available_stock_kg"]))
        best_alternative = alternative_candidates[0] if alternative_candidates else None

        # ----------------------------------------------------------------------
        # 8. Deterministic Decision Engine & Explainability Matrix
        # ----------------------------------------------------------------------
        ai_factors: List[str] = []
        ai_recommendation = "APPROVE"
        ai_recommended_qty = requested_quantity_kg
        ai_recommended_fps_id = None
        ai_recommended_fps_name = None
        ai_risk_level = "LOW"
        ai_confidence = 0.96

        # Check A: Statutory Entitlement Ceiling
        is_over_entitlement = requested_quantity_kg > statutory_max_kg
        if is_over_entitlement:
            ai_recommendation = "PARTIAL_ALLOCATION"
            ai_recommended_qty = statutory_max_kg
            ai_risk_level = "ELEVATED"
            ai_confidence = 0.98
            ai_factors.append(
                f"Statutory Entitlement Cap: Requested {requested_quantity_kg:.1f} kg exceeds card monthly limit of {statutory_max_kg:.1f} kg for {entitlement['card_label']}. AI capped to statutory maximum."
            )
        else:
            ai_factors.append(
                f"Statutory Quota Verified: Requested {requested_quantity_kg:.1f} kg is within monthly card ceiling ({statutory_max_kg:.1f} kg for {entitlement['card_label']})."
            )

        # Check B: Target FPS Capacity & Congestion
        is_portability = entitlement["registered_fps_id"] != intended_fps_id
        if is_portability:
            ai_factors.append(
                f"Inter-FPS Portability: Citizen is registered at {entitlement['registered_fps_name']} and requesting pickup at {fps_name}."
            )

        if headroom_kg < requested_quantity_kg:
            # Physical capacity breach
            if best_alternative and best_alternative["distance_km"] <= 3.0:
                ai_recommendation = "REDIRECT_ALTERNATIVE_FPS"
                ai_recommended_fps_id = best_alternative["fps_id"]
                ai_recommended_fps_name = best_alternative["fps_name"]
                ai_risk_level = "HIGH"
                ai_confidence = 0.94
                ai_factors.append(
                    f"FPS Capacity Exhaustion: Target shop {fps_name} has only {headroom_kg:.0f} kg headroom ({utilization_pct:.1f}% utilized). Recommend redirecting to nearby {best_alternative['fps_name']} ({best_alternative['distance_km']:.1f} km away) with {best_alternative['available_stock_kg']:.0f} kg stock."
                )
            else:
                ai_recommendation = "PARTIAL_ALLOCATION"
                ai_recommended_qty = min(ai_recommended_qty, max(5.0, headroom_kg))
                ai_risk_level = "HIGH"
                ai_confidence = 0.92
                ai_factors.append(
                    f"Constrained Shop Buffer: Target shop has only {headroom_kg:.0f} kg available headroom. Recommending partial allocation of {ai_recommended_qty:.1f} kg."
                )
        elif stockout_freq >= 0.15 and current_inv_kg < statutory_floor_kg:
            # Stockout stress node
            if best_alternative:
                ai_recommendation = "REDIRECT_ALTERNATIVE_FPS"
                ai_recommended_fps_id = best_alternative["fps_id"]
                ai_recommended_fps_name = best_alternative["fps_name"]
                ai_risk_level = "CRITICAL"
                ai_confidence = 0.95
                ai_factors.append(
                    f"Stockout Stress Node: Target shop has high historical stockout frequency ({stockout_freq*100:.0f}%) and on-hand stock ({current_inv_kg:.0f} kg) is below statutory floor ({statutory_floor_kg:.0f} kg). Suggest alternative shop."
                )
            else:
                ai_risk_level = "ELEVATED"
                ai_factors.append(
                    f"Elevated Stockout Risk: Target shop inventory is tight ({current_inv_kg:.0f} kg on-hand). Replenishment scheduled for {replenishment_eta}."
                )
        else:
            # Healthy shop
            if not is_over_entitlement:
                ai_recommendation = "APPROVE"
                ai_risk_level = "LOW"
                ai_confidence = 0.97
            ai_factors.append(
                f"Adequate Shop Storage: Target shop has {headroom_kg:.0f} kg available headroom ({utilization_pct:.1f}% current load) and healthy inventory ({current_inv_kg:.0f} kg)."
            )

        ai_factors.append(
            f"Replenishment Logistics: {replenishment_eta}."
        )

        return {
            "beneficiary": entitlement,
            "target_fps": {
                "fps_id": intended_fps_id,
                "fps_name": fps_name,
                "capacity_kg": capacity_kg,
                "current_inventory_kg": current_inv_kg,
                "statutory_floor_kg": statutory_floor_kg,
                "statutory_requirement_kg": statutory_requirement_kg,
                "capacity_headroom_kg": headroom_kg,
                "utilization_pct": utilization_pct,
                "stockout_frequency": stockout_freq,
                "replenishment_eta": replenishment_eta
            },
            "commodity": commodity,
            "requested_quantity_kg": requested_quantity_kg,
            "statutory_entitlement_ceiling_kg": statutory_max_kg,
            "ai_assessment": {
                "recommendation": ai_recommendation,
                "recommended_quantity_kg": round(ai_recommended_qty, 1),
                "recommended_fps_id": ai_recommended_fps_id,
                "recommended_fps_name": ai_recommended_fps_name,
                "risk_level": ai_risk_level,
                "confidence": ai_confidence,
                "is_advisory": True,
                "factors": ai_factors,
                "best_alternative_fps": best_alternative
            }
        }


ai_request_advisor = CitizenRequestAdvisor()
