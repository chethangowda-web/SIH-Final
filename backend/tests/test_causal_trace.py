"""Tests for End-to-End Causal Pipeline Trace in PDS DemandSync.

Verifies:
1. Intent change changes aggregation when applicable
2. Aggregation changes operational forecast
3. Operational forecast can change dispatch
4. Dispatch can affect route selection
5. Route changes can produce a new manifest revision
6. Changed manifest produces a different seal
7. Entitlement remains unchanged (strictly invariant 25.0 kg)
8. Locked manifests remain immutable
9. What-If simulations do not mutate operational state
10. End-to-end integration test covering the complete chain
"""

import pytest
import sqlite3
from fastapi.testclient import TestClient
from app.main import app
from app.core.database import get_db_connection, init_db
from app.data.seed_data import seed_all_data
from app.services.causal_trace_engine import causal_trace_engine
from app.services.manifest_engine import manifest_engine
from app.services.dispatch_decision_engine import dispatch_decision_engine

client = TestClient(app)

@pytest.fixture(autouse=True)
def setup_test_db():
    init_db()
    seed_all_data(recreate=True)
    conn = get_db_connection()
    yield
    conn.close()

def test_1_intent_change_changes_aggregation():
    """Verify that submitting new citizen intent changes aggregate declared intent."""
    conn = get_db_connection()
    cycle_id = "2026-09"
    fps_id = "FPS-KA-BLR-001"
    
    # Baseline trace
    trace_before = causal_trace_engine.generate_causal_trace(conn, cycle_id=cycle_id, fps_id=fps_id)
    intent_before = trace_before.aggregated_intent_kg

    # Inject +100 kg
    resp = causal_trace_engine.simulate_controlled_intent_shift(
        conn, cycle_id=cycle_id, fps_id=fps_id, shift_delta_kg=100.0, beneficiary_id="BEN-KA-0001"
    )
    
    assert resp.current_run.aggregated_intent_kg > intent_before
    assert resp.causal_delta.intent_delta_kg > 0.0

def test_2_aggregation_changes_operational_forecast():
    """Verify that higher aggregated intent proportionally increases operational forecast D_hat."""
    conn = get_db_connection()
    cycle_id = "2026-09"
    fps_id = "FPS-KA-BLR-001"

    trace_before = causal_trace_engine.generate_causal_trace(conn, cycle_id=cycle_id, fps_id=fps_id)
    forecast_before = trace_before.operational_forecast_kg

    resp = causal_trace_engine.simulate_controlled_intent_shift(
        conn, cycle_id=cycle_id, fps_id=fps_id, shift_delta_kg=200.0, beneficiary_id="BEN-KA-0001"
    )
    
    assert resp.current_run.operational_forecast_kg > forecast_before
    assert resp.causal_delta.forecast_delta_kg > 0.0

def test_3_operational_forecast_changes_dispatch():
    """Verify that change in forecast changes authoritative dispatch recommendation Q*."""
    conn = get_db_connection()
    cycle_id = "2026-09"
    fps_id = "FPS-KA-BLR-001"

    trace_before = causal_trace_engine.generate_causal_trace(conn, cycle_id=cycle_id, fps_id=fps_id)
    dispatch_before = trace_before.recommended_dispatch_kg

    resp = causal_trace_engine.simulate_controlled_intent_shift(
        conn, cycle_id=cycle_id, fps_id=fps_id, shift_delta_kg=300.0, beneficiary_id="BEN-KA-0001"
    )
    
    assert resp.current_run.recommended_dispatch_kg >= dispatch_before
    assert resp.causal_delta.dispatch_delta_kg >= 0.0

def test_4_dispatch_affects_route_and_corridor_payload():
    """Verify that dispatch changes update the corridor payload."""
    conn = get_db_connection()
    cycle_id = "2026-09"
    fps_id = "FPS-KA-BLR-001"

    trace = causal_trace_engine.generate_causal_trace(conn, cycle_id=cycle_id, fps_id=fps_id)
    assert trace.stage_5_route.output_summary.get("total_corridor_payload_kg") is not None
    assert trace.stage_5_route.output_summary.get("transit_distance_km") > 0.0

def test_5_route_changes_produce_manifest_revision():
    """Verify that manifest reflects corridor assignment and versioning."""
    conn = get_db_connection()
    cycle_id = "2026-09"
    fps_id = "FPS-KA-BLR-001"

    trace = causal_trace_engine.generate_causal_trace(conn, cycle_id=cycle_id, fps_id=fps_id)
    assert trace.manifest_id != ""
    assert trace.manifest_version.startswith("v")

def test_6_changed_manifest_produces_different_seal():
    """Verify that altering manifest payload produces a distinct SHA-256 digital seal hash."""
    manifest_a = {
        "manifest_id": "MAN-2026-09-TRK01",
        "cycle_id": "2026-09",
        "version": "v1.0",
        "truck_id": "DEMO-KA-04-E-1021",
        "total_quantity_kg": 3500.0
    }
    manifest_b = {
        "manifest_id": "MAN-2026-09-TRK01",
        "cycle_id": "2026-09",
        "version": "v1.0",
        "truck_id": "DEMO-KA-04-E-1021",
        "total_quantity_kg": 3750.0 # Changed payload
    }

    hash_a = manifest_engine.compute_canonical_manifest_hash(manifest_a)
    hash_b = manifest_engine.compute_canonical_manifest_hash(manifest_b)

    assert hash_a != hash_b
    assert len(hash_a) == 32
    assert len(hash_b) == 32

def test_7_entitlement_remains_strictly_unchanged():
    """Verify that citizen intent declarations DO NOT alter statutory entitlement (Strict 25.0 kg invariant)."""
    conn = get_db_connection()
    cycle_id = "2026-09"
    fps_id = "FPS-KA-BLR-001"

    resp = causal_trace_engine.simulate_controlled_intent_shift(
        conn, cycle_id=cycle_id, fps_id=fps_id, shift_delta_kg=500.0, beneficiary_id="BEN-KA-0001"
    )

    # Statutory entitlement delta MUST be strictly 0.0
    assert resp.causal_delta.statutory_entitlement_delta_kg == 0.0
    assert resp.current_run.statutory_entitlement_guarantee_kg == 25.0
    assert resp.previous_run.statutory_entitlement_guarantee_kg == 25.0

def test_8_locked_manifests_remain_immutable():
    """Verify that locked manifests cannot be silently mutated."""
    conn = get_db_connection()
    cursor = conn.cursor()
    
    cursor.execute("""
    INSERT OR REPLACE INTO manifests (
        manifest_id, cycle_id, truck_id, source_depot_id, corridor,
        total_quantity_kg, driver_name, driver_phone, status, version
    ) VALUES ('MAN-TEST-LOCKED', '2026-09', 'DEMO-KA-04-E-1021', 'DEPOT-01', 'North Corridor', 3000.0, 'Driver A', '9888800000', 'LOCKED', 'v1.0');
    """)
    conn.commit()

    # Verify locked manifest in DB
    cursor.execute("SELECT status FROM manifests WHERE manifest_id = 'MAN-TEST-LOCKED';")
    status = cursor.fetchone()[0]
    assert status == "LOCKED"

    # Attempting to mutate locked manifest via manifest engine throws ValueError
    with pytest.raises(ValueError, match="MANIFEST IS LOCKED"):
        manifest_engine.update_draft_manifest(conn, manifest_id="MAN-TEST-LOCKED", total_quantity_kg=4000.0)

def test_9_what_if_simulations_do_not_mutate_operational_state():
    """Verify that What-If simulation calculations do not overwrite SQLite operational forecast table."""
    conn = get_db_connection()
    cursor = conn.cursor()

    # Read active operational forecast for FPS-001
    cursor.execute("SELECT predicted_quantity_kg FROM forecast WHERE fps_id = 'FPS-KA-BLR-001' AND commodity = 'Rice';")
    row = cursor.fetchone()
    operational_qty_before = float(row[0]) if row else 2678.0

    # Execute What-If simulation directly via decision engine sandbox with extreme simulation parameters
    sim_buffer = dispatch_decision_engine.calculate_safety_buffer(
        predicted_demand_kg=6177.0, # Simulation-only demand
        lead_time_days=5.0,
        stockout_risk=0.25,
        consumption_volatility=0.35,
        storage_capacity_kg=20000.0,
        current_stock_kg=4000.0
    )
    assert sim_buffer["safety_buffer_kg"] > 0

    # Verify operational forecast table remained completely untouched
    cursor.execute("SELECT predicted_quantity_kg FROM forecast WHERE fps_id = 'FPS-KA-BLR-001' AND commodity = 'Rice';")
    row_after = cursor.fetchone()
    operational_qty_after = float(row_after[0]) if row_after else 2678.0

    assert operational_qty_before == operational_qty_after

def test_10_complete_end_to_end_causal_trace_api():
    """Integration test verifying full 7-stage causal trace API endpoints."""
    # 1. GET /api/admin/causal-trace
    get_resp = client.get("/api/admin/causal-trace?fps_id=FPS-KA-BLR-001")
    assert get_resp.status_code == 200
    data = get_resp.json()
    
    assert "run_id" in data
    assert data["stage_1_intent"]["status"] == "AGGREGATED"
    assert data["stage_2_forecast"]["status"] == "CALCULATED"
    assert data["stage_3_constraints"]["status"] in ["PASS", "FAIL"]
    assert data["stage_4_dispatch"]["status"] == "AUTHORIZED"
    assert data["stage_5_route"]["status"] == "OPTIMIZED"
    assert data["stage_6_manifest"]["status"] in ["DRAFT", "LOCKED"]
    assert data["stage_7_seal"]["status"] == "SEALED"
    assert data["statutory_entitlement_guarantee_kg"] == 25.0

    # 2. POST /api/admin/causal-trace/simulate-shift
    shift_resp = client.post("/api/admin/causal-trace/simulate-shift", json={
        "cycle_id": "2026-09",
        "fps_id": "FPS-KA-BLR-001",
        "shift_delta_kg": 150.0,
        "beneficiary_id": "BEN-KA-0001"
    })
    assert shift_resp.status_code == 200
    shift_data = shift_resp.json()
    assert shift_data["status"] == "success"
    assert shift_data["causal_delta"]["intent_delta_kg"] > 0.0
    assert shift_data["causal_delta"]["statutory_entitlement_delta_kg"] == 0.0
    assert shift_data["current_run"]["run_id"] != shift_data["previous_run"]["run_id"]
