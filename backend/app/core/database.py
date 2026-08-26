"""SQLite Database Connection, Schema Definitions, and Utilities."""
import os
import sqlite3
from typing import Generator
from app.core.config import settings

def get_db_connection() -> sqlite3.Connection:
    """Create and return a configured SQLite connection with row factory."""
    conn = sqlite3.connect(
        settings.DB_PATH,
        check_same_thread=False
    )
    conn.row_factory = sqlite3.Row
    # Enable WAL mode and foreign keys for performance and data integrity
    conn.execute("PRAGMA journal_mode = WAL;")
    conn.execute("PRAGMA foreign_keys = ON;")
    return conn

def get_db() -> Generator[sqlite3.Connection, None, None]:
    """FastAPI Dependency for database connection."""
    conn = get_db_connection()
    try:
        yield conn
    finally:
        conn.close()

def init_db(conn: sqlite3.Connection = None) -> None:
    """Initialize database tables with exact Demo V1 schemas."""
    should_close = False
    if conn is None:
        conn = get_db_connection()
        should_close = True

    cursor = conn.cursor()

    # 1. beneficiaries
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

    # 2. fps
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

    # 3. intent
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

    # 4. historical_demand
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

    # 5. inventory
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

    # 6. forecast
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

    # Ensure recommended_dispatch_kg column exists if table was created in an earlier migration
    try:
        cursor.execute("ALTER TABLE forecast ADD COLUMN recommended_dispatch_kg REAL NOT NULL DEFAULT 0.0;")
    except Exception:
        pass

    # 7. dispatch
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

    # Ensure cycle_id and source_godown exist if table was created in an earlier migration
    try:
        cursor.execute("ALTER TABLE dispatch ADD COLUMN cycle_id TEXT NOT NULL DEFAULT '2026-09';")
    except Exception:
        pass

    try:
        cursor.execute("ALTER TABLE dispatch ADD COLUMN source_godown TEXT NOT NULL DEFAULT 'Bengaluru Central FCI Godown (Hebbal)';")
    except Exception:
        pass

    # 8. actual_distribution
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

    try:
        cursor.execute("ALTER TABLE actual_distribution ADD COLUMN dispatch_quantity_kg REAL NOT NULL DEFAULT 0.0;")
    except Exception:
        pass
    try:
        cursor.execute("ALTER TABLE actual_distribution ADD COLUMN variance_kg REAL NOT NULL DEFAULT 0.0;")
    except Exception:
        pass
    try:
        cursor.execute("ALTER TABLE actual_distribution ADD COLUMN variance_pct REAL NOT NULL DEFAULT 0.0;")
    except Exception:
        pass
    try:
        cursor.execute("ALTER TABLE actual_distribution ADD COLUMN status TEXT NOT NULL DEFAULT 'DISTRIBUTED';")
    except Exception:
        pass

    # 9. forecast_evaluation
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS forecast_evaluation (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        forecast_id INTEGER,
        fps_id TEXT NOT NULL,
        cycle_id TEXT NOT NULL DEFAULT '2026-09',
        commodity TEXT NOT NULL CHECK(commodity IN ('Rice', 'Wheat')),
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

    try:
        cursor.execute("ALTER TABLE forecast_evaluation ADD COLUMN fps_id TEXT NOT NULL DEFAULT '';")
    except Exception:
        pass
    try:
        cursor.execute("ALTER TABLE forecast_evaluation ADD COLUMN cycle_id TEXT NOT NULL DEFAULT '2026-09';")
    except Exception:
        pass
    try:
        cursor.execute("ALTER TABLE forecast_evaluation ADD COLUMN commodity TEXT NOT NULL DEFAULT 'Rice';")
    except Exception:
        pass
    try:
        cursor.execute("ALTER TABLE forecast_evaluation ADD COLUMN forecast_quantity_kg REAL NOT NULL DEFAULT 0.0;")
    except Exception:
        pass

    # 10. model_calibration
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

    # 11. depots (Central & Buffer Depots)
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

    # 12. vehicles (Dedicated Transport Fleet)
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

    # 13. routes (Supply-Chain Delivery Corridors & Road Conditions)
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

    # 14. gatepasses (Digital Pre-Dispatch Gatepasses)
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

    # 15. notifications (Simulated Multi-Channel Pre-Dispatch Alerts)
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

    # 16. constraint_logs (Audit Trail for Constraint Validation & Fixes)
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

    # 17. manifests (Auditable Dispatch Manifests)
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

    # 18. manifest_audit_logs (Immutable Audit Trail for Manifest Actions)
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

    # 19. depot_stock_cycles (Cycle-specific depot inventory for shortage simulation)
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

    # 20. stockout_risk_predictions (ML Stockout Risk Predictions)
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

    # 21. scarcity_allocation_plans (Fair-Share Scarcity Allocation Plans)
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

    # 22. scarcity_allocation_items (Itemized FPS Scarcity Allocations)
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

    # Indexes for high-performance lookup
    cursor.execute("CREATE INDEX IF NOT EXISTS idx_beneficiaries_fps ON beneficiaries (registered_fps_id);")
    cursor.execute("CREATE INDEX IF NOT EXISTS idx_intent_lookup ON intent (beneficiary_id, cycle_id);")
    cursor.execute("CREATE INDEX IF NOT EXISTS idx_intent_fps ON intent (intended_fps_id, cycle_id);")
    cursor.execute("CREATE INDEX IF NOT EXISTS idx_history_fps ON historical_demand (fps_id, cycle_id);")
    cursor.execute("CREATE INDEX IF NOT EXISTS idx_inventory_fps ON inventory (fps_id);")
    cursor.execute("CREATE INDEX IF NOT EXISTS idx_gatepasses_cycle ON gatepasses (cycle_id);")
    cursor.execute("CREATE INDEX IF NOT EXISTS idx_notifications_cycle ON notifications (cycle_id, recipient_type);")
    cursor.execute("CREATE INDEX IF NOT EXISTS idx_routes_dest ON routes (destination_fps_id);")
    cursor.execute("CREATE INDEX IF NOT EXISTS idx_manifests_cycle ON manifests (cycle_id);")
    cursor.execute("CREATE INDEX IF NOT EXISTS idx_manifest_audit_mid ON manifest_audit_logs (manifest_id);")
    cursor.execute("CREATE INDEX IF NOT EXISTS idx_depot_cycles ON depot_stock_cycles (depot_id, cycle_id);")
    cursor.execute("CREATE INDEX IF NOT EXISTS idx_stockout_risk ON stockout_risk_predictions (fps_id, cycle_id);")
    cursor.execute("CREATE INDEX IF NOT EXISTS idx_scarcity_plans ON scarcity_allocation_plans (cycle_id, depot_id);")
    cursor.execute("CREATE INDEX IF NOT EXISTS idx_scarcity_items ON scarcity_allocation_items (plan_id, fps_id);")

    conn.commit()
    if should_close:
        conn.close()

def drop_all_tables(conn: sqlite3.Connection = None) -> None:
    """Drop all tables cleanly in proper foreign-key order."""
    should_close = False
    if conn is None:
        conn = get_db_connection()
        should_close = True

    cursor = conn.cursor()
    cursor.execute("PRAGMA foreign_keys = OFF;")
    tables = [
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
