"""Synthetic Demo Dataset Generator for PDS DemandSync.

Generates:
- 1 Demo District: 'Bengaluru Urban - Demo District'
- 20 Fair Price Shops with diverse demand profiles (Stable, Increasing, Decreasing, High Intent Shift, Low/High Inventory)
- 2,000 Demo Beneficiaries with pseudonymous IDs and language preferences
- 6 Historical Distribution Cycles (2026-03 to 2026-08) for Rice & Wheat
- Live Inventory Levels per FPS
- Initial Forward-Looking Intent Declarations for Cycle 2026-09

IMPORTANT: All data is 100% synthetic for demonstration purposes.
Notice: DEMO DATA — NOT GOVERNMENT DATA
"""

import sys
import random
import sqlite3
from app.core.database import get_db_connection, recreate_db, init_db

DEMO_NOTICE = "Govt. of Karnataka • Bengaluru Urban PDS Operations (DEMO DATA — NOT GOVERNMENT DATA)"
DEMO_DISTRICT = "Bengaluru Urban District"
HISTORICAL_CYCLES = ["2026-03", "2026-04", "2026-05", "2026-06", "2026-07", "2026-08"]
CURRENT_CYCLE = "2026-09"

# 20 Fair Price Shops Configuration
FPS_CONFIGS = [
    # 1. Stable Demand (FPS 001 - 004) — Normal end-of-cycle replenishment needed
    {"fps_id": "FPS-KA-BLR-001", "name": "Malleshwaram Seva Kendra", "lat": 13.0031, "lng": 77.5643, "capacity_kg": 20000.0, "type": "STABLE", "base_rice": 4500.0, "base_wheat": 1500.0, "inv_pct": 0.20},
    {"fps_id": "FPS-KA-BLR-002", "name": "Jayanagar 4th Block Depot", "lat": 12.9250, "lng": 77.5938, "capacity_kg": 22000.0, "type": "STABLE", "base_rice": 4800.0, "base_wheat": 1600.0, "inv_pct": 0.22},
    {"fps_id": "FPS-KA-BLR-003", "name": "Basavanagudi Grain Center", "lat": 12.9422, "lng": 77.5756, "capacity_kg": 18000.0, "type": "STABLE", "base_rice": 4200.0, "base_wheat": 1400.0, "inv_pct": 0.18},
    {"fps_id": "FPS-KA-BLR-004", "name": "Rajajinagar 1st Stage FPS", "lat": 12.9982, "lng": 77.5530, "capacity_kg": 20000.0, "type": "STABLE", "base_rice": 4600.0, "base_wheat": 1500.0, "inv_pct": 0.20},

    # 2. Increasing Demand Corridors (FPS 005 - 008) — High growth replenishment
    {"fps_id": "FPS-KA-BLR-005", "name": "Bellandur Outer Ring Road FPS", "lat": 12.9260, "lng": 77.6762, "capacity_kg": 25000.0, "type": "INCREASING", "base_rice": 3800.0, "base_wheat": 1200.0, "inv_pct": 0.16},
    {"fps_id": "FPS-KA-BLR-006", "name": "Sarjapur Road Extension FPS", "lat": 12.9081, "lng": 77.6872, "capacity_kg": 24000.0, "type": "INCREASING", "base_rice": 3600.0, "base_wheat": 1100.0, "inv_pct": 0.18},
    {"fps_id": "FPS-KA-BLR-007", "name": "Mahadevapura Sub-Center", "lat": 12.9880, "lng": 77.6890, "capacity_kg": 26000.0, "type": "INCREASING", "base_rice": 4000.0, "base_wheat": 1300.0, "inv_pct": 0.15},
    {"fps_id": "FPS-KA-BLR-008", "name": "Thanisandra Main Road Depot", "lat": 13.0540, "lng": 77.6320, "capacity_kg": 22000.0, "type": "INCREASING", "base_rice": 3500.0, "base_wheat": 1150.0, "inv_pct": 0.19},

    # 3. Decreasing Demand Outflow Centers (FPS 009 - 012) — Surplus inventory, NO dispatch needed
    {"fps_id": "FPS-KA-BLR-009", "name": "Chickpet Heritage Ration Depot", "lat": 12.9698, "lng": 77.5750, "capacity_kg": 15000.0, "type": "DECREASING", "base_rice": 4200.0, "base_wheat": 1400.0, "inv_pct": 0.55},
    {"fps_id": "FPS-KA-BLR-010", "name": "Shivajinagar Central FPS", "lat": 12.9856, "lng": 77.6057, "capacity_kg": 16000.0, "type": "DECREASING", "base_rice": 4400.0, "base_wheat": 1500.0, "inv_pct": 0.60},
    {"fps_id": "FPS-KA-BLR-011", "name": "Cottonpet Old Ward Seva Kendra", "lat": 12.9650, "lng": 77.5680, "capacity_kg": 14000.0, "type": "DECREASING", "base_rice": 3900.0, "base_wheat": 1300.0, "inv_pct": 0.50},
    {"fps_id": "FPS-KA-BLR-012", "name": "Ulsoor Bazaar Ration Counter", "lat": 12.9830, "lng": 77.6250, "capacity_kg": 15000.0, "type": "DECREASING", "base_rice": 4100.0, "base_wheat": 1350.0, "inv_pct": 0.52},

    # 4. High Intent Shift / Migrant Hubs (FPS 013 - 016) — Inflow surge priority
    {"fps_id": "FPS-KA-BLR-013", "name": "Peenya Industrial Area Phase-1", "lat": 13.0280, "lng": 77.5180, "capacity_kg": 30000.0, "type": "HIGH_MIGRANT", "base_rice": 5000.0, "base_wheat": 1800.0, "inv_pct": 0.12},
    {"fps_id": "FPS-KA-BLR-014", "name": "Whitefield IT Corridor FPS", "lat": 12.9698, "lng": 77.7499, "capacity_kg": 28000.0, "type": "HIGH_MIGRANT", "base_rice": 4800.0, "base_wheat": 1700.0, "inv_pct": 0.10},
    {"fps_id": "FPS-KA-BLR-015", "name": "Electronic City Phase-2 Hub", "lat": 12.8399, "lng": 77.6770, "capacity_kg": 26000.0, "type": "HIGH_MIGRANT", "base_rice": 4600.0, "base_wheat": 1600.0, "inv_pct": 0.14},
    {"fps_id": "FPS-KA-BLR-016", "name": "Bommasandra Industrial FPS", "lat": 12.8160, "lng": 77.6920, "capacity_kg": 25000.0, "type": "HIGH_MIGRANT", "base_rice": 4400.0, "base_wheat": 1500.0, "inv_pct": 0.11},

    # 5. Low Inventory Stress Nodes (FPS 017 - 018) — Critical stockout risk
    {"fps_id": "FPS-KA-BLR-017", "name": "Kengeri Satellite Town FPS", "lat": 12.9150, "lng": 77.4830, "capacity_kg": 18000.0, "type": "LOW_INVENTORY", "base_rice": 4000.0, "base_wheat": 1300.0, "inv_pct": 0.08},
    {"fps_id": "FPS-KA-BLR-018", "name": "Yelahanka Old Town Depot", "lat": 13.1007, "lng": 77.5963, "capacity_kg": 20000.0, "type": "LOW_INVENTORY", "base_rice": 4200.0, "base_wheat": 1400.0, "inv_pct": 0.10},

    # 6. High Inventory Surplus Nodes (FPS 019 - 020) — Buffer warehouses, NO dispatch needed
    {"fps_id": "FPS-KA-BLR-019", "name": "Hebbal Godown Distribution Point", "lat": 13.0358, "lng": 77.5970, "capacity_kg": 28000.0, "type": "HIGH_INVENTORY", "base_rice": 4300.0, "base_wheat": 1450.0, "inv_pct": 0.75},
    {"fps_id": "FPS-KA-BLR-020", "name": "Banaswadi Central Stock Depot", "lat": 13.0100, "lng": 77.6500, "capacity_kg": 25000.0, "type": "HIGH_INVENTORY", "base_rice": 4100.0, "base_wheat": 1350.0, "inv_pct": 0.72},
]

DEMO_FIRST_NAMES = [
    "Ramesh", "Suresh", "Manjunath", "Basavaraj", "Venkatesh", "Chennappa", "Anjinappa",
    "Gowramma", "Lakshmi", "Parvathi", "Savithri", "Sunita", "Meenakshi", "Ningamma",
    "Mohammed", "Syed", "Fatima", "Ayesha", "Abdul", "Imran", "Farooq",
    "Rajesh", "Pooja", "Priyanka", "Deepak", "Anil", "Sunil", "Vikram", "Santosh",
    "Gurupreet", "Harpreet", "Manpreet", "Simran", "Balwinder",
    "Murugan", "Karthik", "Selvam", "Muthu", "Priya", "Divya", "Swathi"
]

DEMO_LAST_INITIALS = ["A.", "B.", "C.", "D.", "G.", "H.", "K.", "M.", "N.", "P.", "R.", "S.", "T.", "V.", "Y."]

LANGUAGES = ["kn", "hi", "ta", "te", "en"]
LANGUAGE_WEIGHTS = [0.45, 0.25, 0.12, 0.12, 0.06]

def generate_beneficiaries(total_count=2000):
    """Generate 2,000 synthetic demo beneficiaries evenly distributed across 20 FPS."""
    beneficiaries = []
    random.seed(42)  # Seed for deterministic benchmark reproducibility

    fps_ids = [c["fps_id"] for c in FPS_CONFIGS]
    cards_per_fps = total_count // len(fps_ids)

    idx = 1
    for fps_id in fps_ids:
        for _ in range(cards_per_fps):
            pseudo_id = f"BEN-KA-{idx:04d}"
            if idx == 1:
                name = "Swathi Bhat"
            elif idx == 5:
                name = "Sunita Devi"
            elif idx == 15:
                name = "Ramesh Kumar"
            else:
                name = f"{random.choice(DEMO_FIRST_NAMES)} {random.choice(DEMO_LAST_INITIALS)}"
            lang = random.choices(LANGUAGES, weights=LANGUAGE_WEIGHTS, k=1)[0]
            beneficiaries.append((pseudo_id, name, fps_id, lang, "ACTIVE"))
            idx += 1

    # Remaining if total_count not evenly divisible
    while idx <= total_count:
        pseudo_id = f"BEN-KA-{idx:04d}"
        if idx == 1:
            name = "Swathi Bhat"
        elif idx == 5:
            name = "Sunita Devi"
        elif idx == 15:
            name = "Ramesh Kumar"
        else:
            name = f"{random.choice(DEMO_FIRST_NAMES)} {random.choice(DEMO_LAST_INITIALS)}"
        lang = random.choices(LANGUAGES, weights=LANGUAGE_WEIGHTS, k=1)[0]
        beneficiaries.append((pseudo_id, name, random.choice(fps_ids), lang, "ACTIVE"))
        idx += 1

    return beneficiaries

def generate_historical_demand():
    """
    Generate 6 historical cycles (2026-03 to 2026-08) for Rice & Wheat across all 20 FPS.
    Applies realistic trends per FPS profile.
    """
    records = []
    random.seed(101)

    for cfg in FPS_CONFIGS:
        fps_id = cfg["fps_id"]
        fps_type = cfg["type"]
        base_rice = cfg["base_rice"]
        base_wheat = cfg["base_wheat"]

        for month_idx, cycle_id in enumerate(HISTORICAL_CYCLES):
            # Trend calculation
            if fps_type == "STABLE":
                rice_qty = base_rice + random.uniform(-80, 80)
                wheat_qty = base_wheat + random.uniform(-30, 30)
            elif fps_type == "INCREASING":
                growth_factor = 1.0 + (month_idx * 0.05) + random.uniform(-0.02, 0.02)
                rice_qty = base_rice * growth_factor
                wheat_qty = base_wheat * growth_factor
            elif fps_type == "DECREASING":
                decay_factor = 1.0 - (month_idx * 0.04) + random.uniform(-0.02, 0.02)
                rice_qty = base_rice * decay_factor
                wheat_qty = base_wheat * decay_factor
            elif fps_type == "HIGH_MIGRANT":
                # High fluctuation due to seasonal migrant waves
                migrant_factor = 1.0 + (month_idx * 0.07) + random.uniform(-0.05, 0.08)
                rice_qty = base_rice * migrant_factor
                wheat_qty = base_wheat * migrant_factor
            elif fps_type == "LOW_INVENTORY":
                rice_qty = base_rice + (month_idx * 30) + random.uniform(-50, 50)
                wheat_qty = base_wheat + random.uniform(-20, 20)
            else: # HIGH_INVENTORY
                rice_qty = base_rice + random.uniform(-60, 60)
                wheat_qty = base_wheat + random.uniform(-25, 25)

            records.append((fps_id, cycle_id, "Rice", round(rice_qty, 1)))
            records.append((fps_id, cycle_id, "Wheat", round(wheat_qty, 1)))

    return records

def generate_inventory():
    """Generate current available inventory for each FPS for Rice & Wheat."""
    records = []
    for cfg in FPS_CONFIGS:
        fps_id = cfg["fps_id"]
        capacity = cfg["capacity_kg"]
        inv_pct = cfg["inv_pct"]

        total_available = capacity * inv_pct
        rice_inv = round(total_available * 0.72, 1)  # 72% Rice
        wheat_inv = round(total_available * 0.28, 1) # 28% Wheat

        records.append((fps_id, "Rice", rice_inv))
        records.append((fps_id, "Wheat", wheat_inv))

    return records

def generate_sample_intents(beneficiaries, count=480):
    """
    Generate initial forward-looking intent declarations for upcoming cycle 2026-09.
    Simulates high portability shift into migrant industrial hubs (FPS 013 - 016).
    """
    records = []
    random.seed(777)

    migrant_hub_ids = ["FPS-KA-BLR-013", "FPS-KA-BLR-014", "FPS-KA-BLR-015", "FPS-KA-BLR-016"]
    sampled_beneficiaries = random.sample(beneficiaries, count)

    for b in sampled_beneficiaries:
        pseudo_id, name, home_fps, lang, status = b

        # 35% probability of migrant portability shift to industrial hubs
        if random.random() < 0.35:
            intended_fps = random.choice(migrant_hub_ids)
            confidence = round(random.uniform(0.80, 0.95), 2)
        else:
            intended_fps = home_fps
            confidence = round(random.uniform(0.85, 0.99), 2)

        # Standard quota per beneficiary: Rice: 20-35 kg, Wheat: 5-10 kg
        rice_quota = random.choice([20.0, 25.0, 30.0, 35.0])
        wheat_quota = random.choice([5.0, 10.0])

        records.append((pseudo_id, CURRENT_CYCLE, intended_fps, "Rice", rice_quota, confidence, "SUBMITTED"))
        records.append((pseudo_id, CURRENT_CYCLE, intended_fps, "Wheat", wheat_quota, confidence, "SUBMITTED"))

    return records

def seed_all_data(recreate=False):
    """
    Seeds the SQLite database with 20 FPS, 2,000 Beneficiaries, 6 Cycles, Inventories, and Intents.
    """
    if recreate:
        recreate_db()
    else:
        init_db()

    conn = get_db_connection()
    cursor = conn.cursor()

    # Check if already seeded
    cursor.execute("SELECT COUNT(*) FROM fps;")
    if cursor.fetchone()[0] > 0 and not recreate:
        conn.close()
        return {"status": "already_seeded", "message": "Database already contains seed data."}

    # 1. Insert 20 FPS
    for cfg in FPS_CONFIGS:
        fps_type = cfg["type"]
        stockout_freq = 0.15 if fps_type == "LOW_INVENTORY" else (0.08 if fps_type == "HIGH_MIGRANT" else (0.02 if fps_type == "STABLE" else 0.01))
        port_rate = 0.28 if fps_type == "HIGH_MIGRANT" else (0.14 if fps_type == "INCREASING" else (0.05 if fps_type == "STABLE" else 0.03))
        seas_factor = 1.15 if fps_type == "HIGH_MIGRANT" else (1.10 if fps_type == "INCREASING" else (1.02 if fps_type == "STABLE" else 0.96))

        cursor.execute("""
        INSERT INTO fps (
            fps_id, name, district, latitude, longitude, capacity_kg,
            stockout_frequency, portability_rate, seasonal_factor,
            beneficiaries_count, entitlement_rice_kg, entitlement_wheat_kg, status
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        """, (
            cfg["fps_id"], cfg["name"], DEMO_DISTRICT, cfg["lat"], cfg["lng"], cfg["capacity_kg"],
            stockout_freq, port_rate, seas_factor,
            100, 25.0, 10.0, "ACTIVE"
        ))

    # 2. Insert 2,000 Beneficiaries
    beneficiaries = generate_beneficiaries(2000)
    cursor.executemany("""
    INSERT INTO beneficiaries (pseudonymous_beneficiary_id, name_for_demo, registered_fps_id, language, status)
    VALUES (?, ?, ?, ?, ?);
    """, beneficiaries)

    # 3. Insert Historical Demand (6 Cycles for Rice & Wheat)
    hist_records = generate_historical_demand()
    cursor.executemany("""
    INSERT INTO historical_demand (fps_id, cycle_id, commodity, actual_quantity_kg)
    VALUES (?, ?, ?, ?);
    """, hist_records)

    # 4. Insert Current Inventories
    inv_records = generate_inventory()
    cursor.executemany("""
    INSERT INTO inventory (fps_id, commodity, available_quantity_kg)
    VALUES (?, ?, ?);
    """, inv_records)

    # 5. Insert Initial Intents for Cycle 2026-09
    intent_records = generate_sample_intents(beneficiaries, 480)
    cursor.executemany("""
    INSERT INTO intent (beneficiary_id, cycle_id, intended_fps_id, commodity, declared_quantity_kg, confidence, status)
    VALUES (?, ?, ?, ?, ?, ?, ?);
    """, intent_records)

    # 5.1 Insert Initial Citizen Requests (Citizen Request -> AI Advisory -> Officer Review Queue)
    from app.services.ai_request_advisor import ai_request_advisor
    import json

    citizen_request_rows = []
    # Seed top 35 intents into citizen_requests queue
    for i, it in enumerate(intent_records[:35]):
        ben_id, cyc, int_fps, com, decl_qty, conf, st = it
        # Lookup home FPS
        home_fps = "FPS-KA-BLR-001"
        for b in beneficiaries:
            if b[0] == ben_id:
                home_fps = b[2]
                break

        ent = ai_request_advisor.get_beneficiary_entitlement(conn, ben_id, com)
        ai_res = ai_request_advisor.evaluate_request(
            conn, ben_id, int_fps, com, decl_qty, cyc
        )
        ai_data = ai_res["ai_assessment"]

        req_id = f"REQ-{cyc}-{ben_id.split('-')[-1]}-{com[:1]}"
        req_type = "PORTABILITY_PREFERENCE" if int_fps != home_fps else "MONTHLY_PREFERENCE_SIGNAL"

        # Varied status for demonstration
        if i % 7 == 0:
            req_status = "OFFICER_APPROVED"
            auth_qty = decl_qty
            off_name = "K. Srinivas Murthy (DSO)"
            off_role = "DISTRICT_SUPPLY_OFFICER"
            off_notes = "Verified within card quota; authorized full allocation."
            auth_time = "2026-08-26 14:30:00"
        elif i % 11 == 0:
            req_status = "OFFICER_PARTIAL_APPROVED"
            auth_qty = ai_data["recommended_quantity_kg"]
            off_name = "K. Srinivas Murthy (DSO)"
            off_role = "DISTRICT_SUPPLY_OFFICER"
            off_notes = "Capped to statutory floor/headroom balance."
            auth_time = "2026-08-26 15:15:00"
        elif i % 13 == 0:
            req_status = "OFFICER_REDIRECTED"
            auth_qty = decl_qty
            off_name = "Basavaraj V. (Depot Manager)"
            off_role = "DEPOT_MANAGER"
            off_notes = "Redirected to nearby FPS due to local storage constraint."
            auth_time = "2026-08-26 16:00:00"
        else:
            req_status = "PENDING_OFFICER_REVIEW"
            auth_qty = 0.0
            off_name = None
            off_role = None
            off_notes = None
            auth_time = None

        citizen_request_rows.append((
            req_id, ben_id, ent["card_type"], ent["family_members_count"],
            ent["statutory_entitlement_rice_kg"], ent["statutory_entitlement_wheat_kg"],
            cyc, home_fps, int_fps, com, decl_qty, auth_qty, req_type,
            req_status, ai_data["recommendation"], ai_data["recommended_quantity_kg"],
            ai_data["recommended_fps_id"], ai_data["risk_level"], ai_data["confidence"],
            json.dumps(ai_data["factors"]), off_name, off_role, off_notes, auth_time
        ))

    cursor.executemany("""
    INSERT OR REPLACE INTO citizen_requests (
        request_id, beneficiary_id, card_type, family_members_count,
        statutory_entitlement_rice_kg, statutory_entitlement_wheat_kg,
        cycle_id, registered_fps_id, intended_fps_id, commodity,
        requested_quantity_kg, authorized_quantity_kg, request_type,
        status, ai_recommendation, ai_recommended_qty_kg,
        ai_recommended_fps_id, ai_risk_level, ai_confidence,
        ai_factors_json, officer_name, officer_role, officer_justification,
        authorized_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
    """, citizen_request_rows)

    # 6. Insert Central Depots
    depots_data = [
        ("DEPOT-01", "Bengaluru Central FCI Godown (Hebbal)", DEMO_DISTRICT, "Hebbal Ring Road, Bengaluru", 600.0, 500.0, 150.0, 320.0, 180.0, "OPERATIONAL"),
        ("DEPOT-02", "Banaswadi PDS Buffer Storage Depot", DEMO_DISTRICT, "Banaswadi Industrial Area, Bengaluru", 450.0, 380.0, 120.0, 240.0, 140.0, "OPERATIONAL")
    ]
    cursor.executemany("""
    INSERT OR REPLACE INTO depots (
        depot_id, name, district, location, capacity_mt,
        available_stock_mt, loading_capacity_mt_day, rice_stock_mt, wheat_stock_mt, status
    )
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
    """, depots_data)

    # 7. Insert Fleet Vehicles
    vehicles_data = [
        ("DEMO-KA-04-E-1021", "Eicher Pro 10 MT (North-West Heavy Corridor)", "10-Ton Heavy Haulage Carrier", "NORTH_WEST", 10000.0, "Bengaluru Central FCI Godown (Hebbal)", 32.0, "Ramesh Kumar", "+91-9876543210", "DEPOT-01", "AVAILABLE"),
        ("DEMO-KA-04-E-1022", "Tata Ultra 10 MT (East Corridor / IT Belt)", "10-Ton Heavy Haulage Carrier", "EAST_IT_CORRIDOR", 10000.0, "Bengaluru Central FCI Godown (Hebbal)", 32.0, "Suresh Gowda", "+91-9876543211", "DEPOT-01", "AVAILABLE"),
        ("DEMO-KA-51-M-3419", "BharatBenz 10 MT (South Industrial Corridor)", "10-Ton Heavy Haulage Carrier", "SOUTH_INDUSTRIAL", 10000.0, "Banaswadi PDS Buffer Storage Depot", 32.0, "Manjunath V.", "+91-9876543212", "DEPOT-02", "AVAILABLE"),
        ("DEMO-KA-01-F-7801", "Ashok Leyland 8 MT (Central Urban / Heritage Cluster)", "8-Ton Urban Medium Logistics", "CENTRAL_HERITAGE", 8000.0, "Banaswadi PDS Buffer Storage Depot", 28.0, "Kiran Patil", "+91-9876543213", "DEPOT-02", "AVAILABLE")
    ]
    cursor.executemany("""
    INSERT OR REPLACE INTO vehicles (
        truck_id, model, vehicle_type, corridor, max_payload_kg,
        current_location, operating_cost_per_km, driver_name, driver_phone, source_depot_id, status
    )
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
    """, vehicles_data)

    # 8. Insert Supply Routes (Connecting Depots to 20 FPS)
    routes_data = []
    depot_locations = {
        "DEPOT-01": (13.0358, 77.5970),
        "DEPOT-02": (13.0100, 77.6500)
    }

    import math
    for depot_id, dcoords in depot_locations.items():
        for cfg in FPS_CONFIGS:
            fps_id = cfg["fps_id"]
            lat1, lon1 = dcoords
            lat2, lon2 = cfg["lat"], cfg["lng"]

            # Haversine distance in km
            dlat = math.radians(lat2 - lat1)
            dlon = math.radians(lon2 - lon1)
            a = math.sin(dlat / 2.0)**2 + math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) * math.sin(dlon / 2.0)**2
            c = 2.0 * math.atan2(math.sqrt(a), math.sqrt(1.0 - a))
            dist_km = round(6371.0 * c * 1.3, 1)  # urban road curvature
            if dist_km < 3.0:
                dist_km = 3.2

            # Transit time in minutes (avg 25 km/h urban logistics speed)
            est_mins = int(round((dist_km / 25.0) * 60)) + 10

            road_cond = "PAVED_HIGHWAY" if dist_km > 15 else ("URBAN_CORRIDOR" if dist_km > 6 else "RURAL_FEEDER")
            restr = "PEAK_HOUR_RESTRICTION" if cfg["type"] in ("HIGH_MIGRANT", "DECREASING") and "Central" in cfg["name"] else "CLEAR"
            route_id = f"RT-{depot_id}-{fps_id.split('-')[-1]}"

            routes_data.append((
                route_id, depot_id, fps_id, dist_km, est_mins, road_cond, restr
            ))

    cursor.executemany("""
    INSERT OR REPLACE INTO routes (
        route_id, source_depot_id, destination_fps_id, distance_km,
        estimated_time_mins, road_condition, restriction_status
    )
    VALUES (?, ?, ?, ?, ?, ?, ?);
    """, routes_data)

    # 9. Seed User Accounts
    from app.core.auth import hash_password
    users_data = [
        ("admin_user", hash_password("admin_pass"), "ADMIN", None),
        ("dso_user", hash_password("dso_pass"), "DSO", None),
        ("auditor_user", hash_password("auditor_pass"), "AUDITOR", None)
    ]
    
    cursor.execute("SELECT pseudonymous_beneficiary_id FROM beneficiaries;")
    ben_rows = cursor.fetchall()
    for r in ben_rows:
        ben_id = r["pseudonymous_beneficiary_id"]
        users_data.append((ben_id, hash_password("citizen_pass"), "BENEFICIARY", ben_id))

    cursor.executemany("""
    INSERT OR REPLACE INTO users (
        username, password_hash, role, beneficiary_id
    )
    VALUES (?, ?, ?, ?);
    """, users_data)

    # 10. Initialize Planning Cycle Engine State (Day 22: Choice Window Open by Default)
    cursor.execute("DELETE FROM demand_snapshots WHERE cycle_id = ?;", (CURRENT_CYCLE,))
    cursor.execute("DELETE FROM planning_cycle_config WHERE cycle_id = ?;", (CURRENT_CYCLE,))
    cursor.execute("""
    INSERT OR REPLACE INTO planning_cycle_config (cycle_id, planning_day, is_manual_override, updated_at)
    VALUES (?, 22, 0, CURRENT_TIMESTAMP);
    """, (CURRENT_CYCLE,))

    conn.commit()

    # Verification counts
    cursor.execute("SELECT COUNT(*) FROM fps;")
    fps_count = cursor.fetchone()[0]
    cursor.execute("SELECT COUNT(*) FROM beneficiaries;")
    ben_count = cursor.fetchone()[0]
    cursor.execute("SELECT COUNT(*) FROM historical_demand;")
    hist_count = cursor.fetchone()[0]
    cursor.execute("SELECT COUNT(*) FROM inventory;")
    inv_count = cursor.fetchone()[0]
    cursor.execute("SELECT COUNT(*) FROM intent;")
    intent_count = cursor.fetchone()[0]
    cursor.execute("SELECT COUNT(*) FROM routes;")
    routes_count = cursor.fetchone()[0]
    cursor.execute("SELECT COUNT(*) FROM users;")
    users_count = cursor.fetchone()[0]

    conn.close()

    return {
        "status": "success",
        "notice": DEMO_NOTICE,
        "district": DEMO_DISTRICT,
        "fps_count": fps_count,
        "beneficiaries_count": ben_count,
        "historical_demand_records": hist_count,
        "inventory_records": inv_count,
        "intent_declarations_count": intent_count,
        "routes_count": routes_count,
        "users_count": users_count,
        "historical_cycles": HISTORICAL_CYCLES,
        "active_cycle": CURRENT_CYCLE
    }

if __name__ == "__main__":
    recreate_flag = "--recreate" in sys.argv or "-r" in sys.argv
    result = seed_all_data(recreate=recreate_flag)
    print("Database Seeding Result:", result)
