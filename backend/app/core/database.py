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

    # 13. routes
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
        cursor.execute(idx_sql)


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


# Migration Registry
MIGRATIONS = [
    (1, "001_core_supply_chain_schema", _migration_001_core_supply_chain),
    (2, "002_scarcity_allocation_engine", _migration_002_scarcity_allocation),
    (3, "003_citizen_requests_and_disputes", _migration_003_citizen_requests_and_disputes),
    (4, "004_unified_governance_trail", _migration_004_unified_governance_trail),
    (5, "005_performance_and_fk_indexes", _migration_005_indexes_and_constraints),
    (6, "006_beneficiary_cycle_receipts", _migration_006_beneficiary_cycle_receipts),
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

    cursor = conn.cursor()
    cursor.execute("PRAGMA foreign_keys = OFF;")
    tables = [
        "schema_migrations",
        "users",
        "workflow_audit_logs",
        "cycle_workflow_states",
        "delivery_disputes",
        "entitlement_policies",
        "governance_audit_logs",
        "citizen_requests",
        "beneficiary_cycle_receipts",
        "scarcity_allocation_items",
        "scarcity_allocation_plans",
        "stockout_risk_predictions",
        "depot_stock_cycles",
        "manifest_audit_logs",
        "manifests",
        "routes",
        "constraint_logs",
        "notifications",
        "gatepasses",
        "vehicles",
        "depots",
        "model_calibration",
        "forecast_evaluation",
        "actual_distribution",
        "dispatch",
        "forecast",
        "inventory",
        "historical_demand",
        "intent",
        "beneficiaries",
        "fps",
        # clean legacy names if any
        "fps_shops",
        "intent_signals",
        "cycle_forecasts",
        "cycle_actuals"
    ]
    for table in tables:
        cursor.execute(f"DROP TABLE IF EXISTS {table};")
    cursor.execute("PRAGMA foreign_keys = ON;")
    conn.commit()

    if should_close:
        conn.close()


def recreate_db() -> None:
    """Completely wipe and recreate the database schema from scratch."""
    conn = get_db_connection()
    drop_all_tables(conn)
    init_db(conn)
    conn.close()
