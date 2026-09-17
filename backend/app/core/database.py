"""SQLite Database Connection, Schema Definitions, Deterministic Migrations, and Recovery Utilities."""
import os
import sqlite3
import hashlib
from typing import Generator, List, Dict, Any, Optional
from datetime import datetime
from app.core.config import settings

def get_db_connection(db_path: Optional[str] = None) -> sqlite3.Connection:
    """Create and return a configured SQLite connection with row factory."""
    target_path = db_path or settings.DB_PATH
    conn = sqlite3.connect(
        target_path,
        check_same_thread=False,
        timeout=30.0
    )
    conn.row_factory = sqlite3.Row
    # Enable WAL mode and foreign keys for performance and referential integrity
    conn.execute("PRAGMA journal_mode = WAL;")
    conn.execute("PRAGMA busy_timeout = 30000;")
    conn.execute("PRAGMA foreign_keys = ON;")
    return conn

def get_db() -> Generator[sqlite3.Connection, None, None]:
    """FastAPI Dependency for database connection."""
    conn = get_db_connection()
    try:
        yield conn
    finally:
        conn.close()

# -----------------------------------------------------------------------------
# DETERMINISTIC MIGRATION RUNNER
# -----------------------------------------------------------------------------

def ensure_migration_table(conn: sqlite3.Connection) -> None:
    """Ensure the schema_migrations tracking table exists."""
    cursor = conn.cursor()
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS schema_migrations (
        version INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        applied_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        checksum TEXT
    );
    """)
    conn.commit()

def _migration_001_core_supply_chain(cursor: sqlite3.Cursor) -> None:
    """001: Core Master Tables and Operational Lifecycles."""
    # 1. fps (Master Parent)
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS fps (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        fps_id TEXT NOT NULL UNIQUE,
        name TEXT NOT NULL,
        district TEXT NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        capacity_kg REAL NOT NULL,
        stockout_frequency REAL NOT NULL DEFAULT 0.05,
        portability_rate REAL NOT NULL DEFAULT 0.12,
        seasonal_factor REAL NOT NULL DEFAULT 1.05,
        beneficiaries_count INTEGER NOT NULL DEFAULT 100,
        entitlement_rice_kg REAL NOT NULL DEFAULT 25.0,
        entitlement_wheat_kg REAL NOT NULL DEFAULT 10.0,
        status TEXT NOT NULL DEFAULT 'ACTIVE'
    );
    """)
    for col_def in [
        ("stockout_frequency", "REAL NOT NULL DEFAULT 0.05"),
        ("portability_rate", "REAL NOT NULL DEFAULT 0.12"),
        ("seasonal_factor", "REAL NOT NULL DEFAULT 1.05"),
        ("beneficiaries_count", "INTEGER NOT NULL DEFAULT 100"),
        ("entitlement_rice_kg", "REAL NOT NULL DEFAULT 25.0"),
        ("entitlement_wheat_kg", "REAL NOT NULL DEFAULT 10.0"),
    ]:
        try:
            cursor.execute(f"ALTER TABLE fps ADD COLUMN {col_def[0]} {col_def[1]};")
        except Exception:
            pass

    # 2. depots (Master Parent)
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS depots (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        depot_id TEXT NOT NULL UNIQUE,
        name TEXT NOT NULL,
        district TEXT NOT NULL,
        location TEXT NOT NULL,
        capacity_mt REAL NOT NULL DEFAULT 500.0,
        available_stock_mt REAL NOT NULL DEFAULT 400.0,
        loading_capacity_mt_day REAL NOT NULL DEFAULT 120.0,
        rice_stock_mt REAL NOT NULL DEFAULT 250.0,
        wheat_stock_mt REAL NOT NULL DEFAULT 150.0,
        status TEXT NOT NULL DEFAULT 'OPERATIONAL'
    );
    """)
    for col_def in [
        ("available_stock_mt", "REAL NOT NULL DEFAULT 400.0"),
        ("loading_capacity_mt_day", "REAL NOT NULL DEFAULT 120.0"),
    ]:
        try:
            cursor.execute(f"ALTER TABLE depots ADD COLUMN {col_def[0]} {col_def[1]};")
        except Exception:
            pass

    cursor.execute("""
    INSERT OR IGNORE INTO depots (
        depot_id, name, district, location, capacity_mt, available_stock_mt, loading_capacity_mt_day, rice_stock_mt, wheat_stock_mt, status
    ) VALUES (
        'DEPOT-01', 'Bengaluru Central FCI Godown (Hebbal)', 'Bengaluru Urban', 'Hebbal Corridor, Bengaluru', 1200.0, 850.0, 150.0, 550.0, 300.0, 'OPERATIONAL'
    );
    """)

    # 3. vehicles (Fleet Logistics)
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS vehicles (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        truck_id TEXT NOT NULL UNIQUE,
        model TEXT NOT NULL,
        vehicle_type TEXT NOT NULL DEFAULT '10-Ton Heavy Haulage Carrier',
        corridor TEXT NOT NULL,
        max_payload_kg REAL NOT NULL DEFAULT 10000.0,
        current_location TEXT NOT NULL DEFAULT 'Bengaluru Central FCI Godown (Hebbal)',
        operating_cost_per_km REAL NOT NULL DEFAULT 32.0,
        driver_name TEXT NOT NULL,
        driver_phone TEXT NOT NULL,
        source_depot_id TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'AVAILABLE',
        FOREIGN KEY (source_depot_id) REFERENCES depots (depot_id)
    );
    """)
    for col_def in [
        ("vehicle_type", "TEXT NOT NULL DEFAULT '10-Ton Heavy Haulage Carrier'"),
        ("current_location", "TEXT NOT NULL DEFAULT 'Bengaluru Central FCI Godown (Hebbal)'"),
        ("operating_cost_per_km", "REAL NOT NULL DEFAULT 32.0"),
    ]:
        try:
            cursor.execute(f"ALTER TABLE vehicles ADD COLUMN {col_def[0]} {col_def[1]};")
        except Exception:
            pass

    # 4. beneficiaries (Master Parent)
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS beneficiaries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        pseudonymous_beneficiary_id TEXT NOT NULL UNIQUE,
        name_for_demo TEXT NOT NULL,
        registered_fps_id TEXT NOT NULL,
        language TEXT NOT NULL DEFAULT 'kn',
        status TEXT NOT NULL DEFAULT 'ACTIVE',
        FOREIGN KEY (registered_fps_id) REFERENCES fps (fps_id)
    );
    """)
    for col_def in [
        ("phone", "TEXT"),
        ("scheme_type", "TEXT DEFAULT 'PHH'"),
        ("members_count", "INTEGER DEFAULT 4"),
        ("monthly_entitlement_kg", "REAL DEFAULT 20.0"),
        ("monthly_rice_kg", "REAL DEFAULT 15.0"),
        ("monthly_wheat_kg", "REAL DEFAULT 5.0"),
    ]:
        try:
            cursor.execute(f"ALTER TABLE beneficiaries ADD COLUMN {col_def[0]} {col_def[1]};")
        except Exception:
            pass

    # FPS Inspection & Digital Checklist Tables
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS fps_inspections (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        inspection_id TEXT NOT NULL UNIQUE,
        fps_id TEXT NOT NULL,
        inspector_id TEXT NOT NULL,
        inspection_type TEXT NOT NULL DEFAULT 'ROUTINE',
        scale_certified INTEGER NOT NULL DEFAULT 1,
        display_board_updated INTEGER NOT NULL DEFAULT 1,
        stock_matches_register INTEGER NOT NULL DEFAULT 1,
        cctv_functional INTEGER NOT NULL DEFAULT 1,
        epos_online INTEGER NOT NULL DEFAULT 1,
        hygiene_compliant INTEGER NOT NULL DEFAULT 1,
        compliance_score REAL NOT NULL DEFAULT 100.0,
        remarks TEXT,
        status TEXT NOT NULL DEFAULT 'SUBMITTED',
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (fps_id) REFERENCES fps (fps_id)
    );
    """)
    for col_def in [
        ("order_id", "TEXT"),
        ("geofence_verified", "INTEGER DEFAULT 0"),
        ("geofence_distance_m", "REAL"),
        ("truck_id", "TEXT"),
        ("gatepass_id", "TEXT"),
        ("manifest_id", "TEXT"),
        ("target_confirmed", "INTEGER DEFAULT 0"),
        ("expected_rice_kg", "REAL DEFAULT 0.0"),
        ("observed_rice_kg", "REAL"),
        ("rice_diff_kg", "REAL"),
        ("expected_wheat_kg", "REAL DEFAULT 0.0"),
        ("observed_wheat_kg", "REAL"),
        ("wheat_diff_kg", "REAL"),
        ("moisture_pct", "REAL"),
        ("moisture_result", "TEXT"),
        ("scale_error_g", "REAL"),
        ("scale_result", "TEXT"),
        ("seizure_issued", "INTEGER DEFAULT 0"),
        ("seizure_reason", "TEXT"),
        ("evidence_json", "TEXT DEFAULT '[]'"),
        ("checklist_json", "TEXT DEFAULT '{}'"),
        ("sealed_hash", "TEXT"),
        ("sealed_at", "TIMESTAMP"),
        ("cycle_id", "TEXT DEFAULT '2026-09'"),
    ]:
        try:
            cursor.execute(f"ALTER TABLE fps_inspections ADD COLUMN {col_def[0]} {col_def[1]};")
        except Exception:
            pass


    cursor.execute("""
    CREATE TABLE IF NOT EXISTS surprise_inspection_orders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        order_id TEXT NOT NULL UNIQUE,
        fps_id TEXT NOT NULL,
        dso_id TEXT NOT NULL,
        reason TEXT NOT NULL,
        priority TEXT NOT NULL DEFAULT 'HIGH',
        status TEXT NOT NULL DEFAULT 'PENDING',
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );
    """)

    cursor.execute("""
    CREATE TABLE IF NOT EXISTS inspector_active_sessions (
        inspector_id TEXT PRIMARY KEY,
        fps_id TEXT NOT NULL,
        current_step INTEGER NOT NULL DEFAULT 1,
        workflow_status TEXT NOT NULL DEFAULT 'IN_PROGRESS',
        session_data TEXT NOT NULL DEFAULT '{}',
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );
    """)

    cursor.execute("""
    CREATE TABLE IF NOT EXISTS fps_operational_sessions (
        fps_id TEXT PRIMARY KEY,
        operational_date DATE NOT NULL DEFAULT (DATE('now')),
        active_step INTEGER NOT NULL DEFAULT 0,
        workflow_status TEXT NOT NULL DEFAULT 'SHOP_CLOSED',
        session_data TEXT NOT NULL DEFAULT '{}',
        opened_at TIMESTAMP,
        closed_at TIMESTAMP,
        closure_id TEXT,
        reconciliation_status TEXT NOT NULL DEFAULT 'PENDING',
        reconciliation_exception_reason TEXT,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (fps_id) REFERENCES fps (fps_id)
    );
    """)

    cursor.execute("""
    CREATE TABLE IF NOT EXISTS epos_transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        transaction_id TEXT NOT NULL UNIQUE,
        fps_id TEXT NOT NULL,
        beneficiary_id TEXT NOT NULL,
        cycle_id TEXT NOT NULL,
        rice_kg REAL NOT NULL DEFAULT 0.0,
        wheat_kg REAL NOT NULL DEFAULT 0.0,
        auth_mode TEXT NOT NULL DEFAULT 'AADHAAR_BIOMETRIC',
        status TEXT NOT NULL DEFAULT 'COMPLETED',
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (fps_id) REFERENCES fps (fps_id),
        FOREIGN KEY (beneficiary_id) REFERENCES beneficiaries (pseudonymous_beneficiary_id)
    );
    """)

    # Seed fallback master records for default citizen users if absent
    cursor.execute("""
    INSERT OR IGNORE INTO fps (fps_id, name, district, latitude, longitude, capacity_kg)
    VALUES ('FPS-KA-BAG-0001', 'Fair Price Shop 1 (Bagalkot)', 'Bagalkot', 16.185, 75.696, 5000.0);
    """)
    for test_fps_id in ['FPS-KA-BLR-001', 'FPS-KA-BLR-002', 'FPS-KA-BLR-003', 'FPS-KA-BLR-004', 'FPS-KA-BLR-005']:
        cursor.execute("""
        INSERT OR IGNORE INTO fps (fps_id, name, district, latitude, longitude, capacity_kg)
        VALUES (?, ?, 'Bengaluru Urban', 12.9716, 77.5946, 5000.0);
        """, (test_fps_id, f"Fair Price Shop ({test_fps_id})"))
    cursor.execute("""
    INSERT OR IGNORE INTO beneficiaries (pseudonymous_beneficiary_id, name_for_demo, registered_fps_id, language, scheme_type, members_count, monthly_entitlement_kg, monthly_rice_kg, monthly_wheat_kg)
    VALUES 
        ('BEN-KA-0001', 'Deepa Reddy', 'FPS-KA-BAG-0001', 'en', 'PHH', 2, 10.0, 0.0, 10.0),
        ('RC-KA-000001', 'Deepa Reddy', 'FPS-KA-BAG-0001', 'en', 'PHH', 2, 10.0, 0.0, 10.0);
    """)

    # 5. intent (Forward Beneficiary Signal)
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS intent (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        beneficiary_id TEXT NOT NULL,
        cycle_id TEXT NOT NULL,
        intended_fps_id TEXT NOT NULL,
        commodity TEXT NOT NULL CHECK(commodity IN ('Rice', 'Wheat')),
        declared_quantity_kg REAL NOT NULL CHECK(declared_quantity_kg > 0),
        confidence REAL NOT NULL DEFAULT 1.0 CHECK(confidence >= 0.0 AND confidence <= 1.0),
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        status TEXT NOT NULL DEFAULT 'SUBMITTED',
        FOREIGN KEY (beneficiary_id) REFERENCES beneficiaries (pseudonymous_beneficiary_id),
        FOREIGN KEY (intended_fps_id) REFERENCES fps (fps_id),
        UNIQUE(beneficiary_id, cycle_id, commodity)
    );
    """)

    # 6. historical_demand
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS historical_demand (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        fps_id TEXT NOT NULL,
        cycle_id TEXT NOT NULL,
        commodity TEXT NOT NULL CHECK(commodity IN ('Rice', 'Wheat')),
        actual_quantity_kg REAL NOT NULL CHECK(actual_quantity_kg >= 0),
        FOREIGN KEY (fps_id) REFERENCES fps (fps_id),
        UNIQUE(fps_id, cycle_id, commodity)
    );
    """)

    # 7. inventory
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS inventory (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        fps_id TEXT NOT NULL,
        commodity TEXT NOT NULL CHECK(commodity IN ('Rice', 'Wheat')),
        available_quantity_kg REAL NOT NULL DEFAULT 0.0 CHECK(available_quantity_kg >= 0),
        FOREIGN KEY (fps_id) REFERENCES fps (fps_id),
        UNIQUE(fps_id, commodity)
    );
    """)

    # 8. forecast
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS forecast (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        fps_id TEXT NOT NULL,
        cycle_id TEXT NOT NULL,
        commodity TEXT NOT NULL CHECK(commodity IN ('Rice', 'Wheat')),
        historical_component REAL NOT NULL DEFAULT 0.0,
        intent_component REAL NOT NULL DEFAULT 0.0,
        inventory_component REAL NOT NULL DEFAULT 0.0,
        predicted_quantity_kg REAL NOT NULL DEFAULT 0.0,
        recommended_dispatch_kg REAL NOT NULL DEFAULT 0.0,
        confidence REAL NOT NULL DEFAULT 1.0,
        risk_level TEXT NOT NULL DEFAULT 'BALANCED',
        model_version TEXT NOT NULL DEFAULT 'v1.0-weighted-linear',
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        status TEXT NOT NULL DEFAULT 'DRAFT',
        FOREIGN KEY (fps_id) REFERENCES fps (fps_id),
        UNIQUE(fps_id, cycle_id, commodity)
    );
    """)
    try:
        cursor.execute("ALTER TABLE forecast ADD COLUMN recommended_dispatch_kg REAL NOT NULL DEFAULT 0.0;")
    except Exception:
        pass

    # 9. dispatch
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS dispatch (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        forecast_id INTEGER,
        fps_id TEXT NOT NULL,
        cycle_id TEXT NOT NULL DEFAULT '2026-09',
        commodity TEXT NOT NULL CHECK(commodity IN ('Rice', 'Wheat')),
        quantity_kg REAL NOT NULL CHECK(quantity_kg >= 0),
        demo_truck_id TEXT NOT NULL,
        source_godown TEXT NOT NULL DEFAULT 'Bengaluru Central FCI Godown (Hebbal)',
        status TEXT NOT NULL DEFAULT 'DISPATCH_PLANNED',
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (forecast_id) REFERENCES forecast (id),
        FOREIGN KEY (fps_id) REFERENCES fps (fps_id),
        UNIQUE(fps_id, cycle_id, commodity)
    );
    """)
    for col_def in [
        ("cycle_id", "TEXT NOT NULL DEFAULT '2026-09'"),
        ("source_godown", "TEXT NOT NULL DEFAULT 'Bengaluru Central FCI Godown (Hebbal)'"),
    ]:
        try:
            cursor.execute(f"ALTER TABLE dispatch ADD COLUMN {col_def[0]} {col_def[1]};")
        except Exception:
            pass

    # 10. actual_distribution
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS actual_distribution (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        fps_id TEXT NOT NULL,
        cycle_id TEXT NOT NULL,
        commodity TEXT NOT NULL CHECK(commodity IN ('Rice', 'Wheat')),
        dispatch_quantity_kg REAL NOT NULL DEFAULT 0.0,
        actual_quantity_kg REAL NOT NULL CHECK(actual_quantity_kg >= 0),
        variance_kg REAL NOT NULL DEFAULT 0.0,
        variance_pct REAL NOT NULL DEFAULT 0.0,
        status TEXT NOT NULL DEFAULT 'DISTRIBUTED',
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (fps_id) REFERENCES fps (fps_id),
        UNIQUE(fps_id, cycle_id, commodity)
    );
    """)
    for col_def in [
        ("dispatch_quantity_kg", "REAL NOT NULL DEFAULT 0.0"),
        ("variance_kg", "REAL NOT NULL DEFAULT 0.0"),
        ("variance_pct", "REAL NOT NULL DEFAULT 0.0"),
        ("status", "TEXT NOT NULL DEFAULT 'DISTRIBUTED'"),
    ]:
        try:
            cursor.execute(f"ALTER TABLE actual_distribution ADD COLUMN {col_def[0]} {col_def[1]};")
        except Exception:
            pass

    # 11. forecast_evaluation
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS forecast_evaluation (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        forecast_id INTEGER,
        fps_id TEXT NOT NULL DEFAULT '',
        cycle_id TEXT NOT NULL DEFAULT '2026-09',
        commodity TEXT NOT NULL DEFAULT 'Rice' CHECK(commodity IN ('Rice', 'Wheat')),
        forecast_quantity_kg REAL NOT NULL DEFAULT 0.0,
        actual_quantity_kg REAL NOT NULL,
        absolute_error REAL NOT NULL,
        percentage_error REAL NOT NULL,
        accuracy REAL NOT NULL,
        evaluated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (forecast_id) REFERENCES forecast (id),
        FOREIGN KEY (fps_id) REFERENCES fps (fps_id),
        UNIQUE(fps_id, cycle_id, commodity)
    );
    """)
    for col_def in [
        ("fps_id", "TEXT NOT NULL DEFAULT ''"),
        ("cycle_id", "TEXT NOT NULL DEFAULT '2026-09'"),
        ("commodity", "TEXT NOT NULL DEFAULT 'Rice'"),
        ("forecast_quantity_kg", "REAL NOT NULL DEFAULT 0.0"),
    ]:
        try:
            cursor.execute(f"ALTER TABLE forecast_evaluation ADD COLUMN {col_def[0]} {col_def[1]};")
        except Exception:
            pass

    # 12. model_calibration
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS model_calibration (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        cycle_id TEXT NOT NULL,
        target_future_cycle TEXT NOT NULL,
        algorithm TEXT NOT NULL,
        model_version TEXT NOT NULL,
        previous_weight REAL NOT NULL,
        calibrated_weight REAL NOT NULL,
        before_mape REAL NOT NULL,
        after_mape REAL NOT NULL,
        records_trained INTEGER NOT NULL,
        calibrated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        UNIQUE(cycle_id)
    );
    """)

    # 13. feedback (Officer <-> Beneficiary & Officer <-> FPS Dealer Triage)
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS feedback (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        ticket_id TEXT NOT NULL UNIQUE,
        sender_type TEXT NOT NULL CHECK(sender_type IN ('BENEFICIARY', 'DEALER_FPS')),
        sender_id TEXT NOT NULL,
        target_fps_id TEXT,
        category TEXT NOT NULL DEFAULT 'GENERAL',
        subject TEXT NOT NULL,
        message TEXT NOT NULL,
        priority TEXT NOT NULL DEFAULT 'NORMAL',
        status TEXT NOT NULL DEFAULT 'OPEN',
        officer_response TEXT,
        resolved_at TIMESTAMP,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );
    """)

    # 14. refresh_tokens (Enterprise Auth & Session Security)
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS refresh_tokens (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        username TEXT NOT NULL,
        token_hash TEXT NOT NULL UNIQUE,
        expires_at TIMESTAMP NOT NULL,
        revoked INTEGER NOT NULL DEFAULT 0,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (user_id) REFERENCES users (id)
    );
    """)

    # 15. truck_telemetry (Geofence Route Arrival & Deviation Checking)
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS truck_telemetry (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        truck_id TEXT NOT NULL,
        target_fps_id TEXT NOT NULL,
        current_lat REAL NOT NULL,
        current_lon REAL NOT NULL,
        distance_to_target_km REAL NOT NULL,
        arrival_status TEXT NOT NULL DEFAULT 'EN_ROUTE',
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );
    """)

    # 16. routes
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS routes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        route_id TEXT NOT NULL UNIQUE,
        source_depot_id TEXT NOT NULL,
        destination_fps_id TEXT NOT NULL,
        distance_km REAL NOT NULL,
        estimated_time_mins INTEGER NOT NULL,
        road_condition TEXT NOT NULL DEFAULT 'PAVED_HIGHWAY',
        restriction_status TEXT NOT NULL DEFAULT 'CLEAR',
        FOREIGN KEY (source_depot_id) REFERENCES depots (depot_id),
        FOREIGN KEY (destination_fps_id) REFERENCES fps (fps_id),
        UNIQUE(source_depot_id, destination_fps_id)
    );
    """)

    # 14. gatepasses
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS gatepasses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        gatepass_id TEXT NOT NULL UNIQUE,
        cycle_id TEXT NOT NULL,
        truck_id TEXT NOT NULL,
        source_depot_id TEXT NOT NULL,
        manifest_id TEXT NOT NULL,
        corridor TEXT NOT NULL,
        total_rice_kg REAL NOT NULL DEFAULT 0.0,
        total_wheat_kg REAL NOT NULL DEFAULT 0.0,
        total_payload_kg REAL NOT NULL DEFAULT 0.0,
        loading_bay TEXT NOT NULL DEFAULT 'Bay-03',
        driver_name TEXT NOT NULL,
        driver_phone TEXT NOT NULL,
        security_token TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'GATEPASS_ISSUED',
        issued_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        verified_at TIMESTAMP,
        loaded_at TIMESTAMP,
        dispatched_at TIMESTAMP,
        approving_officer TEXT NOT NULL DEFAULT 'District Supply Officer (Demo)',
        FOREIGN KEY (truck_id) REFERENCES vehicles (truck_id),
        FOREIGN KEY (source_depot_id) REFERENCES depots (depot_id),
        UNIQUE(cycle_id, truck_id)
    );
    """)

    # 15. notifications
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS notifications (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        cycle_id TEXT NOT NULL,
        recipient_type TEXT NOT NULL CHECK(recipient_type IN ('DEALER', 'BENEFICIARY')),
        recipient_id TEXT NOT NULL,
        recipient_name TEXT NOT NULL,
        recipient_phone TEXT NOT NULL,
        fps_id TEXT NOT NULL,
        channel TEXT NOT NULL CHECK(channel IN ('WHATSAPP', 'SMS', 'IVR')),
        message_title TEXT NOT NULL,
        message_body TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'DELIVERED',
        sent_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        acknowledged_at TIMESTAMP,
        FOREIGN KEY (fps_id) REFERENCES fps (fps_id)
    );
    """)

    # 16. constraint_logs
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS constraint_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        cycle_id TEXT NOT NULL,
        fps_id TEXT NOT NULL,
        rule_name TEXT NOT NULL,
        status TEXT NOT NULL CHECK(status IN ('PASS', 'FAIL', 'WARNING')),
        details TEXT NOT NULL,
        recommended_action TEXT,
        checked_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (fps_id) REFERENCES fps (fps_id)
    );
    """)

    # 17. manifests
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS manifests (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        manifest_id TEXT NOT NULL UNIQUE,
        cycle_id TEXT NOT NULL,
        truck_id TEXT NOT NULL,
        source_depot_id TEXT NOT NULL,
        corridor TEXT NOT NULL,
        total_rice_kg REAL NOT NULL DEFAULT 0.0,
        total_wheat_kg REAL NOT NULL DEFAULT 0.0,
        total_quantity_kg REAL NOT NULL DEFAULT 0.0,
        driver_name TEXT NOT NULL,
        driver_phone TEXT NOT NULL,
        driver_license TEXT NOT NULL DEFAULT 'KA-04-2022-88129',
        route_type TEXT NOT NULL DEFAULT 'DIRECT_ARTERIAL',
        departure_window TEXT NOT NULL DEFAULT '08:30 AM',
        delivery_sequence_json TEXT NOT NULL DEFAULT '[]',
        optimization_score REAL NOT NULL DEFAULT 0.0,
        efficiency_pct REAL NOT NULL DEFAULT 85.0,
        status TEXT NOT NULL DEFAULT 'DRAFT',
        version TEXT NOT NULL DEFAULT 'v1.0',
        locked_at TIMESTAMP,
        locked_by TEXT,
        lock_reason TEXT,
        digital_seal_hash TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (truck_id) REFERENCES vehicles (truck_id),
        FOREIGN KEY (source_depot_id) REFERENCES depots (depot_id),
        UNIQUE(cycle_id, truck_id)
    );
    """)

    # 18. manifest_audit_logs
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS manifest_audit_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        manifest_id TEXT NOT NULL,
        cycle_id TEXT NOT NULL,
        version TEXT NOT NULL,
        action TEXT NOT NULL,
        actor_role TEXT NOT NULL DEFAULT 'DISTRICT_SUPPLY_OFFICER',
        actor_name TEXT NOT NULL DEFAULT 'District Supply Officer (Demo Admin)',
        reason TEXT NOT NULL,
        changes_summary TEXT,
        digital_hash TEXT,
        timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (manifest_id) REFERENCES manifests (manifest_id)
    );
    """)

    # 19. cycle_workflow_states & workflow_audit_logs
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS cycle_workflow_states (
        cycle_id TEXT PRIMARY KEY,
        current_state TEXT NOT NULL,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );
    """)
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS workflow_audit_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        cycle_id TEXT NOT NULL,
        previous_state TEXT,
        new_state TEXT NOT NULL,
        actor_name TEXT NOT NULL,
        actor_role TEXT NOT NULL,
        reason TEXT,
        correlation_id TEXT,
        timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );
    """)

    # 20. users
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT UNIQUE NOT NULL,
        password_hash TEXT NOT NULL,
        role TEXT NOT NULL,
        beneficiary_id TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (beneficiary_id) REFERENCES beneficiaries (pseudonymous_beneficiary_id)
    );
    """)

    # Seed core system roles if not present
    from app.core.auth import hash_password
    default_system_users = [
        ("admin_user", hash_password("admin_pass"), "ADMIN", None),
        ("dso_user", hash_password("dso_pass"), "DSO", None),
        ("field_officer_user", hash_password("field_pass"), "FIELD_OFFICER", None),
        ("inspector_user", hash_password("inspector_pass"), "FIELD_FOOD_INSPECTOR", None),
        ("fps_user", hash_password("fps_pass"), "FPS_OWNER", None),
        ("auditor_user", hash_password("auditor_pass"), "AUDITOR", None),
        ("BEN-KA-0001", hash_password("citizen_pass"), "BENEFICIARY", "BEN-KA-0001"),
        ("RC-KA-000001", hash_password("citizen_pass"), "BENEFICIARY", "RC-KA-000001"),
    ]
    cursor.executemany("""
    INSERT OR REPLACE INTO users (username, password_hash, role, beneficiary_id)
    VALUES (?, ?, ?, ?);
    """, default_system_users)


def _migration_002_scarcity_allocation(cursor: sqlite3.Cursor) -> None:
    """002: AI Stockout Prediction & Fair-Share Scarcity Allocation Engine."""
    # 1. depot_stock_cycles
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS depot_stock_cycles (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        depot_id TEXT NOT NULL,
        cycle_id TEXT NOT NULL,
        commodity TEXT NOT NULL CHECK(commodity IN ('Rice', 'Wheat')),
        total_stock_kg REAL NOT NULL,
        reserved_buffer_kg REAL NOT NULL DEFAULT 0.0,
        available_for_dispatch_kg REAL NOT NULL,
        scarcity_status TEXT NOT NULL DEFAULT 'NORMAL' CHECK(scarcity_status IN ('NORMAL', 'SCARCITY_DEFICIT', 'EMERGENCY_RESERVE')),
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (depot_id) REFERENCES depots (depot_id),
        UNIQUE(depot_id, cycle_id, commodity)
    );
    """)

    # 2. stockout_risk_predictions
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS stockout_risk_predictions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        fps_id TEXT NOT NULL,
        cycle_id TEXT NOT NULL,
        commodity TEXT NOT NULL CHECK(commodity IN ('Rice', 'Wheat')),
        requested_dispatch_kg REAL NOT NULL,
        simulated_allocation_kg REAL NOT NULL,
        stockout_probability REAL NOT NULL CHECK(stockout_probability >= 0.0 AND stockout_probability <= 1.0),
        risk_tier TEXT NOT NULL CHECK(risk_tier IN ('CRITICAL', 'ELEVATED', 'MODERATE', 'LOW')),
        model_name TEXT NOT NULL DEFAULT 'LogisticRegression-Stockout-v1.0',
        features_json TEXT NOT NULL,
        predicted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (fps_id) REFERENCES fps (fps_id),
        UNIQUE(fps_id, cycle_id, commodity)
    );
    """)

    # 3. scarcity_allocation_plans
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS scarcity_allocation_plans (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        plan_id TEXT NOT NULL UNIQUE,
        cycle_id TEXT NOT NULL,
        depot_id TEXT NOT NULL,
        commodity TEXT NOT NULL CHECK(commodity IN ('Rice', 'Wheat')),
        aggregate_demand_kg REAL NOT NULL,
        available_stock_kg REAL NOT NULL,
        deficit_kg REAL NOT NULL,
        allocation_strategy TEXT NOT NULL CHECK(allocation_strategy IN ('FAIR_SHARE_RISK_WEIGHTED', 'PRO_RATA', 'STATUTORY_FLOOR_PRIORITY')),
        approval_status TEXT NOT NULL DEFAULT 'PENDING_OFFICER_REVIEW' CHECK(approval_status IN ('PENDING_OFFICER_REVIEW', 'OFFICER_APPROVED', 'REJECTED')),
        approved_by TEXT,
        approval_notes TEXT,
        allocated_fps_count INTEGER NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        approved_at TIMESTAMP,
        FOREIGN KEY (depot_id) REFERENCES depots (depot_id)
    );
    """)

    # 4. scarcity_allocation_items
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS scarcity_allocation_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        plan_id TEXT NOT NULL,
        fps_id TEXT NOT NULL,
        commodity TEXT NOT NULL CHECK(commodity IN ('Rice', 'Wheat')),
        baseline_recommended_kg REAL NOT NULL,
        statutory_floor_kg REAL NOT NULL,
        reconciled_allocation_kg REAL NOT NULL,
        cut_percentage REAL NOT NULL,
        predicted_stockout_risk REAL NOT NULL,
        mitigation_action TEXT,
        FOREIGN KEY (plan_id) REFERENCES scarcity_allocation_plans (plan_id),
        FOREIGN KEY (fps_id) REFERENCES fps (fps_id),
        UNIQUE(plan_id, fps_id, commodity)
    );
    """)


def _migration_003_citizen_requests_and_disputes(cursor: sqlite3.Cursor) -> None:
    """003: Citizen Requests, Policy Rules, and Delivery Disputes."""
    # 1. citizen_requests
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS citizen_requests (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        request_id TEXT NOT NULL UNIQUE,
        beneficiary_id TEXT NOT NULL,
        card_type TEXT NOT NULL DEFAULT 'PHH',
        family_members_count INTEGER NOT NULL DEFAULT 4,
        statutory_entitlement_rice_kg REAL NOT NULL DEFAULT 20.0,
        statutory_entitlement_wheat_kg REAL NOT NULL DEFAULT 5.0,
        cycle_id TEXT NOT NULL DEFAULT '2026-09',
        registered_fps_id TEXT NOT NULL,
        intended_fps_id TEXT NOT NULL,
        commodity TEXT NOT NULL CHECK(commodity IN ('Rice', 'Wheat')),
        requested_quantity_kg REAL NOT NULL CHECK(requested_quantity_kg > 0),
        authorized_quantity_kg REAL NOT NULL DEFAULT 0.0,
        request_type TEXT NOT NULL DEFAULT 'PORTABILITY_PREFERENCE',
        status TEXT NOT NULL DEFAULT 'PENDING_OFFICER_REVIEW',
        
        ai_recommendation TEXT NOT NULL DEFAULT 'APPROVE',
        ai_recommended_qty_kg REAL NOT NULL DEFAULT 0.0,
        ai_recommended_fps_id TEXT,
        ai_risk_level TEXT NOT NULL DEFAULT 'LOW',
        ai_confidence REAL NOT NULL DEFAULT 0.95,
        ai_factors_json TEXT NOT NULL DEFAULT '[]',
        ai_evaluation_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        
        officer_name TEXT,
        officer_role TEXT,
        officer_justification TEXT,
        authorized_at TIMESTAMP,
        
        delivery_mode TEXT NOT NULL DEFAULT 'FPS_COLLECTION',
        delivery_address TEXT,
        delivery_distance_km REAL NOT NULL DEFAULT 0.0,
        transport_fee_inr REAL NOT NULL DEFAULT 0.0,
        delivery_status TEXT NOT NULL DEFAULT 'SERVICE_REQUESTED',
        received_rice_kg REAL DEFAULT 0.0,
        received_wheat_kg REAL DEFAULT 0.0,
        citizen_confirmed_at TIMESTAMP,
        dispute_reason TEXT,
        
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        
        FOREIGN KEY (beneficiary_id) REFERENCES beneficiaries (pseudonymous_beneficiary_id),
        FOREIGN KEY (registered_fps_id) REFERENCES fps (fps_id),
        FOREIGN KEY (intended_fps_id) REFERENCES fps (fps_id)
    );
    """)

    for col_def in [
        ("delivery_mode", "TEXT NOT NULL DEFAULT 'FPS_COLLECTION'"),
        ("delivery_address", "TEXT"),
        ("delivery_distance_km", "REAL NOT NULL DEFAULT 0.0"),
        ("transport_fee_inr", "REAL NOT NULL DEFAULT 0.0"),
        ("delivery_status", "TEXT NOT NULL DEFAULT 'SERVICE_REQUESTED'"),
        ("received_rice_kg", "REAL DEFAULT 0.0"),
        ("received_wheat_kg", "REAL DEFAULT 0.0"),
        ("citizen_confirmed_at", "TIMESTAMP"),
        ("dispute_reason", "TEXT"),
        ("delay_reason", "TEXT"),
        ("expected_delivery_window", "TEXT"),
        ("delay_notified_at", "TIMESTAMP"),
    ]:
        try:
            cursor.execute(f"ALTER TABLE citizen_requests ADD COLUMN {col_def[0]} {col_def[1]};")
        except Exception:
            pass

    # 2. entitlement_policies
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS entitlement_policies (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        card_type TEXT NOT NULL UNIQUE,
        label TEXT NOT NULL,
        rice_per_member_kg REAL NOT NULL DEFAULT 0.0,
        wheat_per_member_kg REAL NOT NULL DEFAULT 0.0,
        family_fixed_rice_kg REAL NOT NULL DEFAULT 0.0,
        family_fixed_wheat_kg REAL NOT NULL DEFAULT 0.0,
        transport_base_fee_inr REAL NOT NULL DEFAULT 20.0,
        transport_per_km_fee_inr REAL NOT NULL DEFAULT 5.0,
        notes TEXT
    );
    """)

    # Seed baseline policies if empty
    cursor.execute("SELECT COUNT(*) FROM entitlement_policies;")
    if cursor.fetchone()[0] == 0:
        policies = [
            ("AAY", "Antyodaya Anna Yojana (AAY)", 0.0, 0.0, 25.0, 10.0, 20.0, 5.0, "NFSA Sec 3: 35kg fixed family allocation"),
            ("PHH", "Priority Household (PHH)", 5.0, 1.25, 20.0, 5.0, 20.0, 5.0, "NFSA Sec 3: 5kg per member (20kg Rice + 5kg Wheat standard family ceiling)"),
            ("NPHH", "Non-Priority Household (NPHH)", 0.0, 0.0, 15.0, 5.0, 25.0, 6.0, "State Scheme: Subsidized standard allocation")
        ]
        cursor.executemany("""
        INSERT OR IGNORE INTO entitlement_policies (
            card_type, label, rice_per_member_kg, wheat_per_member_kg,
            family_fixed_rice_kg, family_fixed_wheat_kg, transport_base_fee_inr,
            transport_per_km_fee_inr, notes
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?);
        """, policies)

    # 3. delivery_disputes
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS delivery_disputes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        dispute_id TEXT NOT NULL UNIQUE,
        request_id TEXT NOT NULL,
        beneficiary_id TEXT NOT NULL,
        cycle_id TEXT NOT NULL DEFAULT '2026-09',
        commodity TEXT NOT NULL CHECK(commodity IN ('Rice', 'Wheat', 'Both')),
        allocated_quantity_kg REAL NOT NULL,
        received_quantity_kg REAL NOT NULL,
        shortfall_kg REAL NOT NULL,
        dispute_notes TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'PENDING_OFFICER_REVIEW' CHECK(status IN ('PENDING_OFFICER_REVIEW', 'OFFICER_RESOLVED', 'REJECTED')),
        resolution_notes TEXT,
        resolved_by TEXT,
        resolved_at TIMESTAMP,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (request_id) REFERENCES citizen_requests (request_id),
        FOREIGN KEY (beneficiary_id) REFERENCES beneficiaries (pseudonymous_beneficiary_id)
    );
    """)


def _migration_004_unified_governance_trail(cursor: sqlite3.Cursor) -> None:
    """004: Immutable Unified Governance Event Trail."""
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS governance_audit_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        event_id TEXT UNIQUE,
        event_type TEXT NOT NULL DEFAULT 'GOVERNANCE_ACTION',
        action TEXT NOT NULL,
        entity_type TEXT NOT NULL,
        entity_id TEXT NOT NULL,
        cycle_id TEXT NOT NULL DEFAULT '2026-09',
        actor_id TEXT,
        actor_name TEXT NOT NULL,
        actor_role TEXT NOT NULL,
        before_state TEXT,
        after_state TEXT,
        notes TEXT NOT NULL,
        correlation_id TEXT,
        is_success INTEGER NOT NULL DEFAULT 1,
        is_simulation INTEGER NOT NULL DEFAULT 0,
        integrity_metadata TEXT,
        timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );
    """)

    for col_def in [
        ("event_id", "TEXT"),
        ("event_type", "TEXT DEFAULT 'GOVERNANCE_ACTION'"),
        ("actor_id", "TEXT"),
        ("before_state", "TEXT"),
        ("after_state", "TEXT"),
        ("correlation_id", "TEXT"),
        ("is_success", "INTEGER NOT NULL DEFAULT 1"),
        ("is_simulation", "INTEGER NOT NULL DEFAULT 0"),
        ("integrity_metadata", "TEXT"),
    ]:
        try:
            cursor.execute(f"ALTER TABLE governance_audit_logs ADD COLUMN {col_def[0]} {col_def[1]};")
        except Exception:
            pass


def _migration_005_indexes_and_constraints(cursor: sqlite3.Cursor) -> None:
    """005: Performance Indexes, Foreign Key Indexes, and Integrity Acceleration."""
    indexes = [
        # Foreign key & relationship indexes
        "CREATE INDEX IF NOT EXISTS idx_beneficiaries_fps ON beneficiaries (registered_fps_id);",
        "CREATE INDEX IF NOT EXISTS idx_intent_lookup ON intent (beneficiary_id, cycle_id);",
        "CREATE INDEX IF NOT EXISTS idx_intent_fps ON intent (intended_fps_id, cycle_id);",
        "CREATE INDEX IF NOT EXISTS idx_intent_beneficiary_id ON intent (beneficiary_id);",
        "CREATE INDEX IF NOT EXISTS idx_history_fps ON historical_demand (fps_id, cycle_id);",
        "CREATE INDEX IF NOT EXISTS idx_inventory_fps ON inventory (fps_id);",
        "CREATE INDEX IF NOT EXISTS idx_forecast_fps_cycle ON forecast (fps_id, cycle_id);",
        "CREATE INDEX IF NOT EXISTS idx_dispatch_fps_cycle ON dispatch (fps_id, cycle_id);",
        "CREATE INDEX IF NOT EXISTS idx_dispatch_forecast_id ON dispatch (forecast_id);",
        "CREATE INDEX IF NOT EXISTS idx_distribution_fps_cycle ON actual_distribution (fps_id, cycle_id);",
        "CREATE INDEX IF NOT EXISTS idx_evaluation_forecast_id ON forecast_evaluation (forecast_id);",
        "CREATE INDEX IF NOT EXISTS idx_evaluation_fps_cycle ON forecast_evaluation (fps_id, cycle_id);",
        "CREATE INDEX IF NOT EXISTS idx_vehicles_depot ON vehicles (source_depot_id);",
        "CREATE INDEX IF NOT EXISTS idx_routes_source ON routes (source_depot_id);",
        "CREATE INDEX IF NOT EXISTS idx_routes_dest ON routes (destination_fps_id);",
        "CREATE INDEX IF NOT EXISTS idx_gatepasses_cycle ON gatepasses (cycle_id);",
        "CREATE INDEX IF NOT EXISTS idx_gatepasses_truck ON gatepasses (truck_id);",
        "CREATE INDEX IF NOT EXISTS idx_gatepasses_depot ON gatepasses (source_depot_id);",
        "CREATE INDEX IF NOT EXISTS idx_notifications_cycle ON notifications (cycle_id, recipient_type);",
        "CREATE INDEX IF NOT EXISTS idx_notifications_fps ON notifications (fps_id);",
        "CREATE INDEX IF NOT EXISTS idx_constraint_logs_fps ON constraint_logs (fps_id, cycle_id);",
        "CREATE INDEX IF NOT EXISTS idx_manifests_cycle ON manifests (cycle_id);",
        "CREATE INDEX IF NOT EXISTS idx_manifests_truck ON manifests (truck_id);",
        "CREATE INDEX IF NOT EXISTS idx_manifests_depot ON manifests (source_depot_id);",
        "CREATE INDEX IF NOT EXISTS idx_manifest_audit_mid ON manifest_audit_logs (manifest_id);",
        "CREATE INDEX IF NOT EXISTS idx_depot_cycles ON depot_stock_cycles (depot_id, cycle_id);",
        "CREATE INDEX IF NOT EXISTS idx_stockout_risk ON stockout_risk_predictions (fps_id, cycle_id);",
        "CREATE INDEX IF NOT EXISTS idx_scarcity_plans ON scarcity_allocation_plans (cycle_id, depot_id);",
        "CREATE INDEX IF NOT EXISTS idx_scarcity_items ON scarcity_allocation_items (plan_id, fps_id);",
        "CREATE INDEX IF NOT EXISTS idx_scarcity_items_fps ON scarcity_allocation_items (fps_id);",
        "CREATE INDEX IF NOT EXISTS idx_citizen_req_cycle ON citizen_requests (cycle_id, status);",
        "CREATE INDEX IF NOT EXISTS idx_citizen_req_fps ON citizen_requests (intended_fps_id, cycle_id);",
        "CREATE INDEX IF NOT EXISTS idx_citizen_req_ben ON citizen_requests (beneficiary_id, cycle_id);",
        "CREATE INDEX IF NOT EXISTS idx_citizen_req_reg_fps ON citizen_requests (registered_fps_id);",
        "CREATE INDEX IF NOT EXISTS idx_disputes_request ON delivery_disputes (request_id);",
        "CREATE INDEX IF NOT EXISTS idx_disputes_beneficiary ON delivery_disputes (beneficiary_id);",
        "CREATE INDEX IF NOT EXISTS idx_gov_audit_entity ON governance_audit_logs (entity_type, entity_id);",
        "CREATE INDEX IF NOT EXISTS idx_gov_audit_cycle ON governance_audit_logs (cycle_id);",
        "CREATE INDEX IF NOT EXISTS idx_gov_audit_event_type ON governance_audit_logs (event_type);",
        "CREATE INDEX IF NOT EXISTS idx_gov_audit_event_id ON governance_audit_logs (event_id);",
        "CREATE INDEX IF NOT EXISTS idx_users_username ON users (username);",
        "CREATE INDEX IF NOT EXISTS idx_users_beneficiary ON users (beneficiary_id);"
    ]
    for idx_sql in indexes:
        try:
            cursor.execute(idx_sql)
        except Exception:
            pass


def _migration_006_beneficiary_cycle_receipts(cursor: sqlite3.Cursor) -> None:
    """006: Durable Beneficiary Distribution Cycle Receipts and Idempotency Tracking."""
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS beneficiary_cycle_receipts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        beneficiary_id TEXT NOT NULL,
        cycle_id TEXT NOT NULL,
        request_id TEXT,
        received_rice_kg REAL DEFAULT 0.0,
        received_wheat_kg REAL DEFAULT 0.0,
        confirmed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        status TEXT NOT NULL DEFAULT 'COMPLETED',
        FOREIGN KEY (beneficiary_id) REFERENCES beneficiaries (pseudonymous_beneficiary_id),
        UNIQUE(beneficiary_id, cycle_id)
    );
    """)
    cursor.execute("CREATE INDEX IF NOT EXISTS idx_cycle_receipts_ben_cycle ON beneficiary_cycle_receipts (beneficiary_id, cycle_id);")


def _migration_007_planning_cycle_tables(cursor: sqlite3.Cursor) -> None:
    """007: Planning Cycle State Machine and Demand Snapshots."""
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS demand_snapshots (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        snapshot_id TEXT UNIQUE NOT NULL,
        cycle_id TEXT NOT NULL,
        version TEXT NOT NULL DEFAULT 'v1.0',
        lock_status TEXT NOT NULL DEFAULT 'LOCKED',
        lock_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        locked_by TEXT NOT NULL,
        total_beneficiary_requests INTEGER NOT NULL,
        total_declared_intent_kg REAL NOT NULL,
        total_locked_demand_kg REAL NOT NULL,
        fps_demand_json TEXT NOT NULL,
        commodity_quantities_json TEXT NOT NULL,
        location_distribution_json TEXT NOT NULL,
        canonical_hash TEXT NOT NULL,
        is_frozen INTEGER NOT NULL DEFAULT 1,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );
    """)
    cursor.execute("CREATE INDEX IF NOT EXISTS idx_demand_snapshots_cycle ON demand_snapshots (cycle_id);")

    cursor.execute("""
    CREATE TABLE IF NOT EXISTS planning_cycle_config (
        cycle_id TEXT PRIMARY KEY,
        planning_day INTEGER NOT NULL DEFAULT 22,
        is_manual_override INTEGER NOT NULL DEFAULT 0,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );
    """)


def _migration_008_sih_v2_features(cursor: sqlite3.Cursor) -> None:
    """008: Feedback, Refresh Tokens, and Truck Telemetry tables."""
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS feedback (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        ticket_id TEXT NOT NULL UNIQUE,
        sender_type TEXT NOT NULL CHECK(sender_type IN ('BENEFICIARY', 'DEALER_FPS')),
        sender_id TEXT NOT NULL,
        target_fps_id TEXT,
        category TEXT NOT NULL DEFAULT 'GENERAL',
        subject TEXT NOT NULL,
        message TEXT NOT NULL,
        priority TEXT NOT NULL DEFAULT 'NORMAL',
        status TEXT NOT NULL DEFAULT 'OPEN',
        officer_response TEXT,
        resolved_at TIMESTAMP,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );
    """)

    cursor.execute("""
    CREATE TABLE IF NOT EXISTS refresh_tokens (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        username TEXT NOT NULL,
        token_hash TEXT NOT NULL UNIQUE,
        expires_at TIMESTAMP NOT NULL,
        revoked INTEGER NOT NULL DEFAULT 0,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (user_id) REFERENCES users (id)
    );
    """)

    cursor.execute("""
    CREATE TABLE IF NOT EXISTS truck_telemetry (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        truck_id TEXT NOT NULL,
        target_fps_id TEXT NOT NULL,
        current_lat REAL NOT NULL,
        current_lon REAL NOT NULL,
        distance_to_target_km REAL NOT NULL,
        arrival_status TEXT NOT NULL DEFAULT 'EN_ROUTE',
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );
    """)

    cursor.execute("""
    CREATE TABLE IF NOT EXISTS epos_transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        transaction_id TEXT NOT NULL UNIQUE,
        fps_id TEXT NOT NULL,
        beneficiary_id TEXT NOT NULL,
        cycle_id TEXT NOT NULL,
        rice_kg REAL NOT NULL DEFAULT 0.0,
        wheat_kg REAL NOT NULL DEFAULT 0.0,
        auth_mode TEXT NOT NULL DEFAULT 'AADHAAR_BIOMETRIC',
        status TEXT NOT NULL DEFAULT 'COMPLETED',
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (fps_id) REFERENCES fps (fps_id),
        FOREIGN KEY (beneficiary_id) REFERENCES beneficiaries (pseudonymous_beneficiary_id)
    );
    """)

    cursor.execute("""
    CREATE TABLE IF NOT EXISTS truck_route_tracking (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        tracking_id TEXT NOT NULL UNIQUE,
        truck_id TEXT NOT NULL UNIQUE,
        gatepass_id TEXT NOT NULL,
        cycle_id TEXT NOT NULL DEFAULT '2026-09',
        driver_name TEXT NOT NULL,
        driver_phone TEXT NOT NULL,
        source_depot_id TEXT NOT NULL,
        source_depot_name TEXT NOT NULL,
        destination_fps_id TEXT NOT NULL,
        destination_fps_name TEXT NOT NULL,
        assigned_route_id TEXT NOT NULL,
        route_name TEXT NOT NULL,
        current_status TEXT NOT NULL DEFAULT 'DISPATCH_CLEARED',
        checkpoints_json TEXT NOT NULL,
        current_checkpoint_idx INTEGER NOT NULL DEFAULT 0,
        current_checkpoint_name TEXT NOT NULL,
        next_checkpoint_name TEXT NOT NULL,
        distance_travelled_km REAL NOT NULL DEFAULT 0.0,
        distance_remaining_km REAL NOT NULL DEFAULT 14.5,
        total_route_distance_km REAL NOT NULL DEFAULT 14.5,
        eta_minutes INTEGER NOT NULL DEFAULT 35,
        expected_arrival_time TEXT NOT NULL,
        delay_status TEXT NOT NULL DEFAULT 'ON_TIME',
        delay_minutes INTEGER NOT NULL DEFAULT 0,
        delay_reason TEXT,
        route_deviation_flag INTEGER NOT NULL DEFAULT 0,
        deviation_reason TEXT,
        last_telemetry_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );
    """)


def _migration_009_beneficiary_phone(cursor: sqlite3.Cursor) -> None:
    """009: Add phone field to beneficiaries and seed first 50 entries."""
    try:
        cursor.execute("ALTER TABLE beneficiaries ADD COLUMN phone TEXT;")
    except Exception:
        pass

    cursor.execute("CREATE INDEX IF NOT EXISTS idx_beneficiaries_phone ON beneficiaries (phone);")

    # Seed phone numbers for the first 50 beneficiaries
    cursor.execute("SELECT id, pseudonymous_beneficiary_id FROM beneficiaries ORDER BY id ASC LIMIT 50;")
    rows = cursor.fetchall()
    demo_phone_override = getattr(settings, "SMS_DEMO_RECIPIENT_PHONE", None)

    for idx, r in enumerate(rows):
        row_id = r[0] if isinstance(r, (list, tuple)) else r["id"]
        # If demo phone override is set, use it for the primary demo card BEN-KA-0001
        if idx == 0 and demo_phone_override:
            phone_val = demo_phone_override.strip()
        else:
            # Deterministic standard Indian mobile numbers
            phone_val = f"+9198450{idx + 10000:05d}"
            
        cursor.execute("UPDATE beneficiaries SET phone = ? WHERE id = ?;", (phone_val, row_id))


def _migration_010_dso_tables(cursor: sqlite3.Cursor) -> None:
    """010: DSO Workflow State, Validated Demand, Overrides, and Dispatch Authorizations."""
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS dso_validated_demand (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        cycle_id TEXT NOT NULL,
        fps_id TEXT NOT NULL,
        commodity TEXT NOT NULL,
        historical_baseline_kg REAL NOT NULL,
        intent_demand_kg REAL NOT NULL,
        forecast_demand_kg REAL NOT NULL,
        validated_demand_kg REAL NOT NULL,
        validated_by TEXT NOT NULL,
        validated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        snapshot_hash TEXT NOT NULL,
        UNIQUE(cycle_id, fps_id, commodity)
    );
    """)
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS dso_allocation_overrides (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        cycle_id TEXT NOT NULL,
        fps_id TEXT NOT NULL,
        commodity TEXT NOT NULL,
        previous_allocation_kg REAL NOT NULL,
        new_allocation_kg REAL NOT NULL,
        reason TEXT NOT NULL,
        officer_name TEXT NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );
    """)
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS dso_dispatch_authorizations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        cycle_id TEXT NOT NULL,
        manifest_id TEXT NOT NULL,
        authorized_by TEXT NOT NULL,
        authorization_reference TEXT NOT NULL,
        authorized_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        notes TEXT,
        UNIQUE(cycle_id, manifest_id)
    );
    """)


def _migration_011_audit_workflow(cursor: sqlite3.Cursor) -> None:
    """010: Persistent Audit Sessions and Sealed Audit Reports for Vigilance Auditor."""
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS audit_sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        cycle_id TEXT NOT NULL UNIQUE,
        auditor_id TEXT NOT NULL DEFAULT 'auditor_user',
        current_step INTEGER NOT NULL DEFAULT 1,
        completed_steps TEXT NOT NULL DEFAULT '[]',
        step_status TEXT NOT NULL DEFAULT '{}',
        manifest_verified INTEGER NOT NULL DEFAULT 0,
        hash_verification_status TEXT NOT NULL DEFAULT 'PENDING',
        anomalies_reviewed INTEGER NOT NULL DEFAULT 0,
        verification_notes TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );
    """)
    cursor.execute("CREATE INDEX IF NOT EXISTS idx_audit_sessions_cycle ON audit_sessions (cycle_id);")

    cursor.execute("""
    CREATE TABLE IF NOT EXISTS audit_reports (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        report_id TEXT NOT NULL UNIQUE,
        cycle_id TEXT NOT NULL,
        auditor_id TEXT NOT NULL DEFAULT 'auditor_user',
        district TEXT NOT NULL DEFAULT 'Bengaluru Urban',
        scope_text TEXT NOT NULL,
        manifest_summary TEXT NOT NULL DEFAULT '{}',
        gatepass_summary TEXT NOT NULL DEFAULT '{}',
        forecast_actual_summary TEXT NOT NULL DEFAULT '{}',
        inspection_summary TEXT NOT NULL DEFAULT '{}',
        anomalies_summary TEXT NOT NULL DEFAULT '{}',
        evidence_summary TEXT NOT NULL DEFAULT '{}',
        audit_observations TEXT NOT NULL,
        integrity_status TEXT NOT NULL DEFAULT 'VERIFIED',
        report_hash TEXT NOT NULL,
        sealed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );
    """)
    cursor.execute("CREATE INDEX IF NOT EXISTS idx_audit_reports_cycle ON audit_reports (cycle_id);")


def _migration_011_fps_operations(cursor: sqlite3.Cursor) -> None:
    """011: Persistent FPS Daily Operations, Consignment Receipts, and Daily Stock Reconciliations."""
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS fps_daily_operations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        fps_id TEXT NOT NULL,
        cycle_id TEXT NOT NULL DEFAULT '2026-09',
        operation_date TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'OPEN',
        opened_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        opened_by TEXT NOT NULL DEFAULT 'fps_user',
        closed_at TIMESTAMP,
        closed_by TEXT,
        opening_checklist_json TEXT NOT NULL DEFAULT '{}',
        closing_checklist_json TEXT NOT NULL DEFAULT '{}',
        notes TEXT,
        UNIQUE(fps_id, cycle_id, operation_date)
    );
    """)
    cursor.execute("CREATE INDEX IF NOT EXISTS idx_fps_daily_ops ON fps_daily_operations (fps_id, cycle_id);")

    cursor.execute("""
    CREATE TABLE IF NOT EXISTS fps_consignment_receipts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        fps_id TEXT NOT NULL,
        cycle_id TEXT NOT NULL DEFAULT '2026-09',
        gatepass_id TEXT NOT NULL,
        manifest_id TEXT,
        truck_id TEXT,
        rice_received_kg REAL NOT NULL DEFAULT 0.0,
        wheat_received_kg REAL NOT NULL DEFAULT 0.0,
        received_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        received_by TEXT NOT NULL DEFAULT 'fps_user',
        status TEXT NOT NULL DEFAULT 'CONFIRMED',
        remarks TEXT,
        UNIQUE(fps_id, gatepass_id)
    );
    """)
    cursor.execute("CREATE INDEX IF NOT EXISTS idx_fps_receipts ON fps_consignment_receipts (fps_id, cycle_id);")

    cursor.execute("""
    CREATE TABLE IF NOT EXISTS fps_daily_reconciliations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        fps_id TEXT NOT NULL,
        cycle_id TEXT NOT NULL DEFAULT '2026-09',
        reconciliation_date TEXT NOT NULL,
        rice_opening_kg REAL NOT NULL DEFAULT 0.0,
        rice_received_kg REAL NOT NULL DEFAULT 0.0,
        rice_dispensed_kg REAL NOT NULL DEFAULT 0.0,
        rice_expected_closing_kg REAL NOT NULL DEFAULT 0.0,
        rice_recorded_closing_kg REAL NOT NULL DEFAULT 0.0,
        rice_variance_kg REAL NOT NULL DEFAULT 0.0,
        wheat_opening_kg REAL NOT NULL DEFAULT 0.0,
        wheat_received_kg REAL NOT NULL DEFAULT 0.0,
        wheat_dispensed_kg REAL NOT NULL DEFAULT 0.0,
        wheat_expected_closing_kg REAL NOT NULL DEFAULT 0.0,
        wheat_recorded_closing_kg REAL NOT NULL DEFAULT 0.0,
        wheat_variance_kg REAL NOT NULL DEFAULT 0.0,
        status TEXT NOT NULL DEFAULT 'RECONCILED',
        reconciled_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        reconciled_by TEXT NOT NULL DEFAULT 'fps_user',
        notes TEXT,
        UNIQUE(fps_id, cycle_id, reconciliation_date)
    );
    """)
    cursor.execute("CREATE INDEX IF NOT EXISTS idx_fps_reconcile ON fps_daily_reconciliations (fps_id, cycle_id);")



def _migration_012_inspector_workflow(cursor: sqlite3.Cursor) -> None:
    """012: Field Food Inspector Operational Workflow, Evidence Attachment, and Cryptographic Sealing."""
    new_cols = [
        ("order_id", "TEXT"),
        ("expected_rice_kg", "REAL DEFAULT 0.0"),
        ("observed_rice_kg", "REAL"),
        ("rice_diff_kg", "REAL"),
        ("expected_wheat_kg", "REAL DEFAULT 0.0"),
        ("observed_wheat_kg", "REAL"),
        ("wheat_diff_kg", "REAL"),
        ("moisture_pct", "REAL"),
        ("moisture_result", "TEXT"),
        ("scale_error_g", "REAL"),
        ("scale_result", "TEXT"),
        ("seizure_issued", "INTEGER DEFAULT 0"),
        ("seizure_reason", "TEXT"),
        ("evidence_json", "TEXT DEFAULT '[]'"),
        ("sealed_hash", "TEXT"),
        ("sealed_at", "TIMESTAMP"),
        ("cycle_id", "TEXT DEFAULT '2026-09'"),
        ("geofence_verified", "INTEGER DEFAULT 0"),
        ("geofence_distance_m", "REAL"),
        ("truck_id", "TEXT"),
        ("gatepass_id", "TEXT"),
        ("manifest_id", "TEXT"),
        ("target_confirmed", "INTEGER DEFAULT 0"),
    ]
    for col_name, col_type in new_cols:
        try:
            cursor.execute(f"ALTER TABLE fps_inspections ADD COLUMN {col_name} {col_type};")
        except Exception:
            pass

    cursor.execute("""
    CREATE TABLE IF NOT EXISTS inspection_evidence (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        evidence_id TEXT NOT NULL UNIQUE,
        inspection_id TEXT,
        fps_id TEXT NOT NULL,
        inspector_id TEXT NOT NULL,
        evidence_type TEXT NOT NULL,
        description TEXT,
        reference_path TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );
    """)
    cursor.execute("CREATE INDEX IF NOT EXISTS idx_insp_evidence_fps ON inspection_evidence (fps_id);")
    cursor.execute("CREATE INDEX IF NOT EXISTS idx_insp_evidence_insp ON inspection_evidence (inspection_id);")


def _migration_013_escalation_system(cursor: sqlite3.Cursor) -> None:
    """013: AI Complaint Escalation System - Cluster table for grouped complaints."""
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS complaint_clusters (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        cluster_id TEXT NOT NULL UNIQUE,
        cluster_label TEXT NOT NULL,
        ai_summary TEXT NOT NULL,
        category TEXT NOT NULL DEFAULT 'GENERAL',
        complaint_count INTEGER NOT NULL DEFAULT 1,
        ticket_ids_json TEXT NOT NULL DEFAULT '[]',
        primary_fps_id TEXT,
        severity TEXT NOT NULL DEFAULT 'MEDIUM',
        escalation_status TEXT NOT NULL DEFAULT 'PENDING',
        escalated_at TIMESTAMP,
        dso_response TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );
    """)
    cursor.execute("CREATE INDEX IF NOT EXISTS idx_complaint_clusters_status ON complaint_clusters (escalation_status);")
    cursor.execute("CREATE INDEX IF NOT EXISTS idx_complaint_clusters_category ON complaint_clusters (category);")


# Migration Registry
MIGRATIONS = [
    (1, "001_core_supply_chain_schema", _migration_001_core_supply_chain),
    (2, "002_scarcity_allocation_engine", _migration_002_scarcity_allocation),
    (3, "003_citizen_requests_and_disputes", _migration_003_citizen_requests_and_disputes),
    (4, "004_unified_governance_trail", _migration_004_unified_governance_trail),
    (5, "005_performance_and_fk_indexes", _migration_005_indexes_and_constraints),
    (6, "006_beneficiary_cycle_receipts", _migration_006_beneficiary_cycle_receipts),
    (7, "007_planning_cycle_tables", _migration_007_planning_cycle_tables),
    (8, "008_sih_v2_features", _migration_008_sih_v2_features),
    (9, "009_beneficiary_phone", _migration_009_beneficiary_phone),
    (10, "010_dso_tables", _migration_010_dso_tables),
    (11, "011_audit_workflow", _migration_011_audit_workflow),
    (12, "012_fps_operations", _migration_011_fps_operations),
    (13, "013_inspector_workflow", _migration_012_inspector_workflow),
    (14, "014_escalation_system", _migration_013_escalation_system),
]


def run_migrations(conn: Optional[sqlite3.Connection] = None) -> List[Dict[str, Any]]:
    """
    Executes unapplied migrations sequentially and idempotently inside transactions.
    Records every applied migration in schema_migrations and updates PRAGMA user_version.
    """
    should_close = False
    if conn is None:
        conn = get_db_connection()
        should_close = True

    ensure_migration_table(conn)
    cursor = conn.cursor()

    cursor.execute("SELECT version FROM schema_migrations ORDER BY version ASC;")
    applied_versions = {row["version"] for row in cursor.fetchall()}

    applied_results = []
    for version, name, migration_func in MIGRATIONS:
        if version not in applied_versions:
            checksum = hashlib.sha256(f"{version}:{name}".encode()).hexdigest()[:16]
            migration_func(cursor)
            cursor.execute("""
            INSERT INTO schema_migrations (version, name, checksum)
            VALUES (?, ?, ?);
            """, (version, name, checksum))
            cursor.execute(f"PRAGMA user_version = {version};")
            conn.commit()
            applied_results.append({
                "version": version,
                "name": name,
                "status": "applied",
                "checksum": checksum
            })

    if should_close:
        conn.close()

    return applied_results


def get_schema_version(conn: Optional[sqlite3.Connection] = None) -> int:
    """Return the current database schema version."""
    should_close = False
    if conn is None:
        conn = get_db_connection()
        should_close = True

    cursor = conn.cursor()
    cursor.execute("PRAGMA user_version;")
    version = cursor.fetchone()[0]

    if should_close:
        conn.close()

    return version


def init_db(conn: Optional[sqlite3.Connection] = None) -> None:
    """Initialize database schemas via deterministic idempotent migration pipeline."""
    should_close = False
    if conn is None:
        conn = get_db_connection()
        should_close = True

    run_migrations(conn)
    cursor = conn.cursor()
    _migration_008_sih_v2_features(cursor)
    conn.commit()

    # Automatically populate full imported CSV master datasets (FPS, Beneficiaries, Historical Demand, Intents, Depots, Fleet)
    try:
        cursor.execute("SELECT COUNT(*) FROM fps;")
        fps_count = cursor.fetchone()[0]
        cursor.execute("SELECT COUNT(*) FROM historical_demand;")
        hist_count = cursor.fetchone()[0]
        cursor.execute("SELECT COUNT(*) FROM intent;")
        intent_count = cursor.fetchone()[0]

        if fps_count < 600 or hist_count == 0 or intent_count == 0:
            import logging
            logger = logging.getLogger(__name__)
            try:
                from app.data.seed_data import seed_all_data
                logger.info("Seeding full CSV datasets into database (621 FPS, 10K Beneficiaries, 22K History, 10K Intents)...")
                seed_all_data(recreate=False)
            except Exception as s_err:
                logger.warning(f"Auto seed all data failed: {s_err}")
    except Exception as e:
        pass

    from app.services.planning_cycle_engine import planning_cycle_engine
    planning_cycle_engine.ensure_tables(conn)

    if should_close:
        conn.close()


# -----------------------------------------------------------------------------
# DATABASE BACKUP, RECOVERY & INTEGRITY DIAGNOSTICS
# -----------------------------------------------------------------------------

def run_database_integrity_check(conn: Optional[sqlite3.Connection] = None) -> Dict[str, Any]:
    """
    Execute deep diagnostic PRAGMA integrity, quick_check, and foreign_key_check.
    Returns structured diagnostic results.
    """
    should_close = False
    if conn is None:
        conn = get_db_connection()
        should_close = True

    cursor = conn.cursor()

    # 1. PRAGMA integrity_check
    cursor.execute("PRAGMA integrity_check;")
    integrity_rows = [r[0] for r in cursor.fetchall()]
    integrity_ok = len(integrity_rows) == 1 and integrity_rows[0] == "ok"

    # 2. PRAGMA quick_check
    cursor.execute("PRAGMA quick_check;")
    quick_rows = [r[0] for r in cursor.fetchall()]
    quick_ok = len(quick_rows) == 1 and quick_rows[0] == "ok"

    # 3. PRAGMA foreign_key_check
    cursor.execute("PRAGMA foreign_key_check;")
    fk_violations = cursor.fetchall()
    fk_ok = (len(fk_violations) == 0)

    # 4. Migration & WAL diagnostics
    cursor.execute("PRAGMA journal_mode;")
    journal_mode = cursor.fetchone()[0]
    cursor.execute("PRAGMA foreign_keys;")
    fk_enabled = bool(cursor.fetchone()[0])
    cursor.execute("PRAGMA user_version;")
    user_version = cursor.fetchone()[0]

    ensure_migration_table(conn)
    cursor.execute("SELECT COUNT(*) FROM schema_migrations;")
    migrations_count = cursor.fetchone()[0]

    is_healthy = integrity_ok and quick_ok and fk_ok

    if should_close:
        conn.close()

    return {
        "status": "HEALTHY" if is_healthy else "UNHEALTHY",
        "integrity_check_passed": integrity_ok,
        "integrity_check_details": integrity_rows,
        "quick_check_passed": quick_ok,
        "foreign_keys_valid": fk_ok,
        "foreign_key_violations_count": len(fk_violations),
        "foreign_key_violations": [dict(r) for r in fk_violations] if fk_violations else [],
        "journal_mode": journal_mode,
        "foreign_keys_pragma_enabled": fk_enabled,
        "user_version": user_version,
        "applied_migrations_count": migrations_count,
        "timestamp": datetime.now().strftime("%Y-%m-%d %H:%M:%S UTC+05:30")
    }


def backup_database(target_path: Optional[str] = None, conn: Optional[sqlite3.Connection] = None) -> str:
    """
    Perform an online, non-blocking snapshot backup of the operational SQLite database.
    Uses SQLite's online backup API to ensure zero write corruption under active WAL mode.
    """
    should_close = False
    if conn is None:
        conn = get_db_connection()
        should_close = True

    if not target_path:
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        backup_dir = os.path.join(os.path.dirname(settings.DB_PATH), "backups")
        os.makedirs(backup_dir, exist_ok=True)
        target_path = os.path.join(backup_dir, f"demand_sync_backup_{timestamp}.db")
    else:
        os.makedirs(os.path.dirname(os.path.abspath(target_path)), exist_ok=True)

    dest_conn = sqlite3.connect(target_path)
    with dest_conn:
        conn.backup(dest_conn, pages=100, sleep=0.01)
    dest_conn.close()

    if should_close:
        conn.close()

    return os.path.abspath(target_path)


def restore_database(source_backup_path: str, target_conn: Optional[sqlite3.Connection] = None) -> Dict[str, Any]:
    """
    Safely restore database from a verified backup snapshot.
    Validates backup integrity before loading into the operational database.
    """
    if not os.path.exists(source_backup_path):
        raise FileNotFoundError(f"Backup file not found at '{source_backup_path}'.")

    # Validate source backup integrity first
    backup_conn = sqlite3.connect(source_backup_path)
    b_cursor = backup_conn.cursor()
    b_cursor.execute("PRAGMA integrity_check;")
    b_res = b_cursor.fetchone()[0]
    if b_res != "ok":
        backup_conn.close()
        raise ValueError(f"Backup file at '{source_backup_path}' failed integrity check: {b_res}")

    should_close = False
    if target_conn is None:
        target_conn = get_db_connection()
        should_close = True

    with target_conn:
        backup_conn.backup(target_conn, pages=100, sleep=0.01)

    backup_conn.close()

    if should_close:
        target_conn.close()

    return {
        "status": "RESTORED",
        "source_backup": source_backup_path,
        "restored_at": datetime.now().strftime("%Y-%m-%d %H:%M:%S UTC+05:30")
    }


def drop_all_tables(conn: Optional[sqlite3.Connection] = None) -> None:
    """Drop all tables cleanly in proper foreign-key order."""
    should_close = False
    if conn is None:
        conn = get_db_connection()
        should_close = True

    conn.execute("PRAGMA foreign_keys = OFF;")
    cursor = conn.cursor()
    cursor.execute("SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%';")
    all_tables = [r[0] for r in cursor.fetchall()]
    for table in all_tables:
        cursor.execute(f"DROP TABLE IF EXISTS {table};")
    conn.commit()
    conn.execute("PRAGMA foreign_keys = ON;")

    if should_close:
        conn.close()


def recreate_db() -> None:
    """Completely wipe and recreate the database schema from scratch."""
    conn = get_db_connection()
    drop_all_tables(conn)
    init_db(conn)
    conn.close()
