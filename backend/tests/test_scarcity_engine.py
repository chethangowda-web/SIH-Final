"""Unit & Integration Tests for ML Stockout Risk Prediction & Scarcity Allocation Engine.

Tests:
1. Model probability bounds: 0.0 <= P <= 1.0
2. Governance risk tier mapping
3. Deterministic predictions for identical inputs
4. Statutory floor protection under feasible scarcity
5. Total allocation never exceeds available depot stock
6. Allocation never exceeds FPS physical storage headroom
7. ML risk weighting proportionally protects higher risk shops
8. ML cannot directly bypass statutory floors
9. Plan generation creates PENDING_OFFICER_REVIEW record
10. Plan generation is read-only regarding live dispatch records
11. Persisted predictions contain valid features JSON
12. Persisted plan items match in-memory simulation
13. Statutory floor matches existing entitlement logic (beneficiaries * entitlement_unit)
14. All statutory floors met when supply is feasible
15. Infeasible statutory floor condition is explicitly flagged (STATUTORY_FLOORS_UNSATISFIABLE)
16. No hidden 50% multiplier (full statutory entitlement is verified)
"""

import json
import pytest
from app.core.database import get_db_connection, init_db, recreate_db
from app.data.seed_data import seed_all_data
from app.services.forecast_engine import forecast_engine
from app.services.stockout_risk_engine import stockout_risk_engine
from app.services.scarcity_engine import scarcity_allocation_engine


@pytest.fixture(scope="module")
def setup_db():
    """Seed test database once for scarcity tests."""
    seed_all_data(recreate=True)
    conn = get_db_connection()
    forecast_engine.generate_and_persist_forecasts(conn, cycle_id="2026-09", force=True)
    yield conn
    conn.close()


def test_stockout_risk_probability_bounds(setup_db):
    """Test 1: Model probability must strictly lie within [0.0, 1.0]."""
    cursor = setup_db.cursor()
    for alloc_kg in [0.0, 500.0, 2000.0, 4500.0, 8000.0]:
        res = stockout_risk_engine.predict_stockout_risk(
            cursor=cursor,
            fps_id="FPS-KA-BLR-001",
            commodity="Rice",
            proposed_allocation_kg=alloc_kg,
            cycle_id="2026-09"
        )
        prob = res["stockout_probability"]
        assert 0.0 <= prob <= 1.0, f"Probability {prob} out of bounds for allocation {alloc_kg}"
        assert res["risk_tier"] in ["CRITICAL", "ELEVATED", "MODERATE", "LOW"]


def test_stockout_risk_tier_mapping(setup_db):
    """Test 2: Risk tier classification adheres to governance presentation thresholds."""
    assert stockout_risk_engine._determine_risk_tier(0.85) == "CRITICAL"
    assert stockout_risk_engine._determine_risk_tier(0.75) == "CRITICAL"
    assert stockout_risk_engine._determine_risk_tier(0.60) == "ELEVATED"
    assert stockout_risk_engine._determine_risk_tier(0.50) == "ELEVATED"
    assert stockout_risk_engine._determine_risk_tier(0.35) == "MODERATE"
    assert stockout_risk_engine._determine_risk_tier(0.25) == "MODERATE"
    assert stockout_risk_engine._determine_risk_tier(0.10) == "LOW"
    assert stockout_risk_engine._determine_risk_tier(0.0) == "LOW"


def test_deterministic_predictions_for_identical_inputs(setup_db):
    """Test 3: Model inference must be 100% deterministic for identical inputs."""
    cursor = setup_db.cursor()
    res1 = stockout_risk_engine.predict_stockout_risk(
        cursor=cursor,
        fps_id="FPS-KA-BLR-001",
        commodity="Rice",
        proposed_allocation_kg=1500.0,
        cycle_id="2026-09"
    )
    res2 = stockout_risk_engine.predict_stockout_risk(
        cursor=cursor,
        fps_id="FPS-KA-BLR-001",
        commodity="Rice",
        proposed_allocation_kg=1500.0,
        cycle_id="2026-09"
    )
    assert res1["stockout_probability"] == res2["stockout_probability"]
    assert res1["risk_tier"] == res2["risk_tier"]
    assert res1["features"] == res2["features"]


def test_statutory_floor_protection(setup_db):
    """Test 4: Allocation must never fall below statutory floor under feasible scarcity."""
    cursor = setup_db.cursor()
    # Calculate sum of all floors across shops
    cursor.execute("""
    SELECT p.fps_id, p.beneficiaries_count, p.entitlement_rice_kg, COALESCE(i.available_quantity_kg, 0.0)
    FROM fps p LEFT JOIN inventory i ON p.fps_id = i.fps_id AND i.commodity = 'Rice';
    """)
    total_floors = sum(max(0.0, float(r[1]) * float(r[2]) - float(r[3])) for r in cursor.fetchall())

    # Supply is sufficient to cover statutory floors (e.g. total_floors + 5000 kg)
    plan = scarcity_allocation_engine.simulate_scarcity_plan(
        db=setup_db,
        depot_id="DEPOT-01",
        commodity="Rice",
        available_depot_stock_kg=total_floors + 1000.0,
        cycle_id="2026-09",
        allocation_strategy="FAIR_SHARE_RISK_WEIGHTED"
    )
    assert plan["status"] == "success"
    assert plan["statutory_floor_status"] == "STATUTORY_FLOORS_SATISFIED"
    assert plan["is_statutory_floor_satisfied"] is True

    for item in plan["allocated_items"]:
        alloc = item["reconciled_allocation_kg"]
        floor = item["statutory_floor_kg"]
        assert alloc >= floor, f"FPS {item['fps_id']}: Allocation ({alloc}) violates statutory floor ({floor})"


def test_allocation_never_exceeds_depot_stock(setup_db):
    """Test 5: Total allocated quantity must never exceed available depot stock."""
    for depot_stock in [5000.0, 12000.0, 18000.0, 25000.0, 40000.0]:
        plan = scarcity_allocation_engine.simulate_scarcity_plan(
            db=setup_db,
            depot_id="DEPOT-01",
            commodity="Rice",
            available_depot_stock_kg=depot_stock,
            cycle_id="2026-09",
            allocation_strategy="FAIR_SHARE_RISK_WEIGHTED"
        )
        total_alloc = plan["total_reconciled_allocation_kg"]
        assert total_alloc <= depot_stock + 0.1, f"Total allocated {total_alloc} exceeds depot stock {depot_stock}"


def test_allocation_never_exceeds_fps_headroom(setup_db):
    """Test 6: Individual FPS allocation must never exceed physical storage headroom."""
    plan = scarcity_allocation_engine.simulate_scarcity_plan(
        db=setup_db,
        depot_id="DEPOT-01",
        commodity="Rice",
        available_depot_stock_kg=30000.0,
        cycle_id="2026-09"
    )
    cursor = setup_db.cursor()
    for item in plan["allocated_items"]:
        fid = item["fps_id"]
        cursor.execute("SELECT capacity_kg FROM fps WHERE fps_id = ?;", (fid,))
        cap = float(cursor.fetchone()[0])
        cursor.execute("SELECT COALESCE(available_quantity_kg, 0.0) FROM inventory WHERE fps_id = ? AND commodity = 'Rice';", (fid,))
        inv = float(cursor.fetchone()[0])
        headroom = cap - inv

        alloc = item["reconciled_allocation_kg"]
        assert alloc <= headroom + 0.1, f"FPS {fid}: Allocation ({alloc}) exceeds storage headroom ({headroom})"


def test_risk_weighting_affects_allocation(setup_db):
    """Test 7: Risk-weighted strategy provides greater allocation protection to higher-risk shops than flat pro-rata."""
    plan_risk = scarcity_allocation_engine.simulate_scarcity_plan(
        db=setup_db,
        depot_id="DEPOT-01",
        commodity="Rice",
        available_depot_stock_kg=20000.0,
        cycle_id="2026-09",
        allocation_strategy="FAIR_SHARE_RISK_WEIGHTED"
    )
    plan_prorata = scarcity_allocation_engine.simulate_scarcity_plan(
        db=setup_db,
        depot_id="DEPOT-01",
        commodity="Rice",
        available_depot_stock_kg=20000.0,
        cycle_id="2026-09",
        allocation_strategy="PRO_RATA"
    )
    alloc_risk_map = {item["fps_id"]: item["reconciled_allocation_kg"] for item in plan_risk["allocated_items"]}
    alloc_prorata_map = {item["fps_id"]: item["reconciled_allocation_kg"] for item in plan_prorata["allocated_items"]}

    high_risk_shops = [item["fps_id"] for item in plan_risk["allocated_items"] if item["predicted_stockout_risk"] > 0.40]
    if high_risk_shops:
        for fid in high_risk_shops:
            assert alloc_risk_map[fid] >= alloc_prorata_map[fid] - 1.0


def test_ml_cannot_bypass_statutory_floors(setup_db):
    """Test 8: ML model cannot force an allocation below legal statutory floor."""
    cursor = setup_db.cursor()
    floor_info = scarcity_allocation_engine.calculate_statutory_floor(cursor, "FPS-KA-BLR-017", "Rice")
    floor_kg = floor_info["statutory_floor_kg"]
    assert floor_kg > 0.0

    # Test with feasible supply covering statutory floors
    cursor.execute("""
    SELECT p.fps_id, p.beneficiaries_count, p.entitlement_rice_kg, COALESCE(i.available_quantity_kg, 0.0)
    FROM fps p LEFT JOIN inventory i ON p.fps_id = i.fps_id AND i.commodity = 'Rice';
    """)
    total_floors = sum(max(0.0, float(r[1]) * float(r[2]) - float(r[3])) for r in cursor.fetchall())

    plan = scarcity_allocation_engine.simulate_scarcity_plan(
        db=setup_db,
        depot_id="DEPOT-01",
        commodity="Rice",
        available_depot_stock_kg=total_floors + 2000.0,
        cycle_id="2026-09",
        allocation_strategy="FAIR_SHARE_RISK_WEIGHTED"
    )
    item_017 = next(it for it in plan["allocated_items"] if it["fps_id"] == "FPS-KA-BLR-017")
    assert item_017["reconciled_allocation_kg"] >= floor_kg


def test_plan_generation_remains_pending_officer_review(setup_db):
    """Test 9: Persisting a plan marks it PENDING_OFFICER_REVIEW and does not auto-approve."""
    sim = scarcity_allocation_engine.simulate_scarcity_plan(
        db=setup_db,
        depot_id="DEPOT-01",
        commodity="Rice",
        available_depot_stock_kg=18000.0,
        cycle_id="2026-09"
    )
    res = scarcity_allocation_engine.persist_scarcity_plan(
        db=setup_db,
        plan_simulation=sim,
        actor_name="DSO Ramesh Kumar",
        notes="Automated SIH Test Scarcity Plan"
    )
    assert res["status"] == "success"
    assert res["approval_status"] == "PENDING_OFFICER_REVIEW"

    plan_id = res["plan_id"]
    retrieved = scarcity_allocation_engine.get_scarcity_plan(setup_db, plan_id)
    assert retrieved is not None
    assert retrieved["approval_status"] == "PENDING_OFFICER_REVIEW"
    assert retrieved["approved_by"] is None


def test_plan_generation_does_not_modify_live_dispatch(setup_db):
    """Test 10: Plan generation is strictly isolated and does not alter live dispatch or forecast tables."""
    cursor = setup_db.cursor()
    cursor.execute("SELECT fps_id, commodity, predicted_quantity_kg, recommended_dispatch_kg FROM forecast WHERE cycle_id = '2026-09';")
    forecast_before = cursor.fetchall()

    sim = scarcity_allocation_engine.simulate_scarcity_plan(
        db=setup_db,
        depot_id="DEPOT-01",
        commodity="Rice",
        available_depot_stock_kg=12000.0,
        cycle_id="2026-09"
    )
    scarcity_allocation_engine.persist_scarcity_plan(setup_db, sim)

    cursor.execute("SELECT fps_id, commodity, predicted_quantity_kg, recommended_dispatch_kg FROM forecast WHERE cycle_id = '2026-09';")
    forecast_after = cursor.fetchall()

    assert forecast_before == forecast_after, "Scarcity plan generation unexpectedly mutated live forecast table!"


def test_persisted_prediction_has_valid_features_json(setup_db):
    """Test 11: Persisted prediction has valid serialized features JSON."""
    cursor = setup_db.cursor()
    pred_res = stockout_risk_engine.predict_stockout_risk(
        cursor=cursor,
        fps_id="FPS-KA-BLR-001",
        commodity="Rice",
        proposed_allocation_kg=1200.0,
        cycle_id="2026-09"
    )
    stockout_risk_engine.persist_prediction(
        db=setup_db,
        fps_id="FPS-KA-BLR-001",
        cycle_id="2026-09",
        commodity="Rice",
        requested_dispatch_kg=pred_res["requested_dispatch_kg"],
        simulated_allocation_kg=1200.0,
        prediction_result=pred_res
    )

    cursor.execute("SELECT features_json, stockout_probability, risk_tier FROM stockout_risk_predictions WHERE fps_id = 'FPS-KA-BLR-001' AND cycle_id = '2026-09' AND commodity = 'Rice';")
    row = cursor.fetchone()
    assert row is not None
    features = json.loads(row[0])
    assert "historical_demand_mean_kg" in features
    assert "days_of_stock_coverage" in features
    assert row[1] == pred_res["stockout_probability"]
    assert row[2] == pred_res["risk_tier"]


def test_persisted_scarcity_allocation_matches_simulation(setup_db):
    """Test 12: Persisted scarcity items in SQLite match in-memory simulation item by item."""
    sim = scarcity_allocation_engine.simulate_scarcity_plan(
        db=setup_db,
        depot_id="DEPOT-01",
        commodity="Rice",
        available_depot_stock_kg=16000.0,
        cycle_id="2026-09"
    )
    res = scarcity_allocation_engine.persist_scarcity_plan(setup_db, sim)
    plan_id = res["plan_id"]

    retrieved = scarcity_allocation_engine.get_scarcity_plan(setup_db, plan_id)
    assert len(retrieved["allocated_items"]) == len(sim["allocated_items"])

    for sim_item, db_item in zip(sim["allocated_items"], retrieved["allocated_items"]):
        assert sim_item["fps_id"] == db_item["fps_id"]
        assert sim_item["reconciled_allocation_kg"] == float(db_item["reconciled_allocation_kg"])
        assert sim_item["statutory_floor_kg"] == float(db_item["statutory_floor_kg"])
        assert sim_item["cut_percentage"] == float(db_item["cut_percentage"])


# ==============================================================================
# AUDIT & GOVERNANCE TESTS (REQUIRED REVIEW TESTS)
# ==============================================================================

def test_statutory_floor_matches_existing_entitlement_logic(setup_db):
    """Test 13: Statutory floor calculation must re-use project's canonical entitlement: beneficiaries * entitlement_unit."""
    cursor = setup_db.cursor()
    cursor.execute("SELECT fps_id, beneficiaries_count, entitlement_rice_kg, entitlement_wheat_kg FROM fps WHERE fps_id = 'FPS-KA-BLR-001';")
    fps_row = cursor.fetchone()
    beneficiaries = int(fps_row[1])
    rice_rate = float(fps_row[2])
    wheat_rate = float(fps_row[3])

    # Check Rice
    rice_res = scarcity_allocation_engine.calculate_statutory_floor(cursor, "FPS-KA-BLR-001", "Rice")
    expected_rice_req = round(beneficiaries * rice_rate, 1)
    assert rice_res["statutory_requirement_kg"] == expected_rice_req
    assert rice_res["statutory_floor_kg"] == max(0.0, round(expected_rice_req - rice_res["current_inventory_kg"], 1))

    # Check Wheat
    wheat_res = scarcity_allocation_engine.calculate_statutory_floor(cursor, "FPS-KA-BLR-001", "Wheat")
    expected_wheat_req = round(beneficiaries * wheat_rate, 1)
    assert wheat_res["statutory_requirement_kg"] == expected_wheat_req
    assert wheat_res["statutory_floor_kg"] == max(0.0, round(expected_wheat_req - wheat_res["current_inventory_kg"], 1))


def test_all_statutory_floors_met_when_supply_is_feasible(setup_db):
    """Test 14: When depot stock >= sum(statutory floors), all allocations are >= statutory floors with SATISFIED status."""
    cursor = setup_db.cursor()
    cursor.execute("""
    SELECT p.fps_id, p.beneficiaries_count, p.entitlement_rice_kg, COALESCE(i.available_quantity_kg, 0.0)
    FROM fps p LEFT JOIN inventory i ON p.fps_id = i.fps_id AND i.commodity = 'Rice';
    """)
    total_floors = sum(max(0.0, float(r[1]) * float(r[2]) - float(r[3])) for r in cursor.fetchall())

    plan = scarcity_allocation_engine.simulate_scarcity_plan(
        db=setup_db,
        depot_id="DEPOT-01",
        commodity="Rice",
        available_depot_stock_kg=total_floors + 2000.0,
        cycle_id="2026-09"
    )
    assert plan["statutory_floor_status"] == "STATUTORY_FLOORS_SATISFIED"
    assert plan["is_statutory_floor_satisfied"] is True
    assert plan["governance_alert"] is None

    for item in plan["allocated_items"]:
        assert item["reconciled_allocation_kg"] >= item["statutory_floor_kg"]
        assert item["statutory_floor_satisfied"] is True
        assert item["floor_deficit_kg"] == 0.0


def test_infeasible_statutory_floor_condition_is_explicit(setup_db):
    """Test 15: When depot stock < sum(statutory floors), engine explicitly flags STATUTORY_FLOORS_UNSATISFIABLE."""
    plan = scarcity_allocation_engine.simulate_scarcity_plan(
        db=setup_db,
        depot_id="DEPOT-01",
        commodity="Rice",
        available_depot_stock_kg=1000.0,  # Far below total statutory floors (~10,000+ kg)
        cycle_id="2026-09"
    )
    assert plan["statutory_floor_status"] == "STATUTORY_FLOORS_UNSATISFIABLE"
    assert plan["is_statutory_floor_satisfied"] is False
    assert plan["governance_alert"] is not None
    assert "STATUTORY_FLOORS_UNSATISFIABLE" in plan["governance_alert"]

    # Verify that items clearly report floor curtailment
    curtailed_items = [it for it in plan["allocated_items"] if not it["statutory_floor_satisfied"]]
    assert len(curtailed_items) > 0
    for item in curtailed_items:
        assert item["floor_deficit_kg"] > 0.0


def test_no_hidden_50_percent_multiplier(setup_db):
    """Test 16: Ensure no hidden 0.50 multiplier is applied to statutory entitlement."""
    cursor = setup_db.cursor()
    cursor.execute("SELECT beneficiaries_count, entitlement_rice_kg FROM fps WHERE fps_id = 'FPS-KA-BLR-001';")
    b_count, rate = cursor.fetchone()
    res = scarcity_allocation_engine.calculate_statutory_floor(cursor, "FPS-KA-BLR-001", "Rice")

    # Full 100% statutory requirement = b_count * rate (e.g. 100 * 25.0 = 2500.0 kg, NOT 1250.0 kg)
    assert res["statutory_requirement_kg"] == float(b_count) * float(rate)
    assert res["statutory_requirement_kg"] != (float(b_count) * float(rate) * 0.50)
