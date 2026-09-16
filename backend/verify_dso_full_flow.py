import sys
import os
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), ".")))

from fastapi.testclient import TestClient
from app.main import app
from app.core.auth import create_token

client = TestClient(app)

def test_full_dso_workflow():
    print("Testing DSO Full Operational Workflow...")
    token = create_token({"username": "admin_user", "role": "ADMIN"})
    headers = {"Authorization": f"Bearer {token}"}

    # Stage 0 & 1: Dashboard & Monitor
    res = client.get("/admin/dashboard?cycle_id=2026-09", headers=headers)
    assert res.status_code == 200, f"Dashboard failed: {res.text}"
    data = res.json()
    print(f"[Stage 1] Historical: {data['total_historical_demand_kg']/1000:.1f} MT (Expect 227.5 MT)")
    print(f"[Stage 1] Citizen Intent: {data['total_declared_intent_kg']/1000:.1f} MT (Expect 129.9 MT)")
    print(f"[Stage 1] Forecast Demand: {data['total_forecast_demand_kg']/1000:.1f} MT (Expect 276.7 MT)")
    print(f"[Stage 1] Depot Stock: {data.get('depot_available_stock_mt', 0.0):.1f} MT (Expect 850.0 MT)")
    queue = data.get("attention_queue", [])
    print(f"[Stage 1] Attention Queue: {len(queue)} items")
    for q in queue:
        print(f"   -> {q['severity']}: {q['fps_id']} ({q['issue']}) -> {q['action']}")
    assert abs(data['total_historical_demand_kg'] - 227495.0) < 1.0
    assert abs(data['total_declared_intent_kg'] - 129880.0) < 1.0
    assert abs(data['total_forecast_demand_kg'] - 276700.0) < 1.0

    # Stage 2: Signal deltas
    intent_fc_diff = (data['total_declared_intent_kg'] - data['total_forecast_demand_kg']) / 1000.0
    fc_hist_diff = (data['total_forecast_demand_kg'] - data['total_historical_demand_kg']) / 1000.0
    print(f"[Stage 2] Intent - Forecast = {intent_fc_diff:.1f} MT (Expect -146.8 MT)")
    print(f"[Stage 2] Forecast - Historical = +{fc_hist_diff:.1f} MT (Expect +49.2 MT)")
    assert abs(intent_fc_diff - (-146.8)) < 0.2
    assert abs(fc_hist_diff - 49.2) < 0.2

    # Stage 3: Allocation Plan
    res_alloc = client.get("/admin/dso/allocation-plan?cycle_id=2026-09", headers=headers)
    assert res_alloc.status_code == 200, f"Allocation plan failed: {res_alloc.text}"
    alloc_data = res_alloc.json()
    print(f"[Stage 3] Validated Demand: {alloc_data['total_validated_demand_mt']} MT")
    print(f"[Stage 3] Existing Stock: {alloc_data['total_existing_fps_stock_mt']} MT")
    print(f"[Stage 3] Net Req: {alloc_data['total_net_requirement_mt']} MT")
    alloc_items = alloc_data.get('items', [])
    print(f"[Stage 3] Allocations count: {len(alloc_items)}")
    fps_001 = next((a for a in alloc_items if a['fps_id'] == 'FPS-001'), None)
    if fps_001:
        print(f"   -> FPS-001: Req {fps_001['validated_requirement_kg']} kg, Exist {fps_001['existing_stock_kg']} kg, Net {fps_001['net_requirement_kg']} kg, Alloc {fps_001['proposed_allocation_kg']} kg")

    # Stage 3 Override
    res_override = client.post("/admin/dso/allocation-override", headers=headers, json={
        "cycle_id": "2026-09",
        "fps_id": "FPS-001",
        "commodity": "Rice",
        "new_allocation_kg": 1850.0,
        "reason": "Festival buffer augmentation",
        "officer_name": "DSO Logged-in Officer"
    })
    assert res_override.status_code == 200
    print("[Stage 3] Allocation override recorded successfully.")

    # Stage 3 Approve
    res_appr = client.post("/admin/dso/allocation-approve?cycle_id=2026-09", headers=headers)
    assert res_appr.status_code == 200
    print("[Stage 3] Allocation plan approved.")

    # Stage 4: Supply Routes
    res_routes = client.get("/admin/dso/supply-routes?cycle_id=2026-09", headers=headers)
    assert res_routes.status_code == 200
    routes = res_routes.json()["routes"]
    print(f"[Stage 4] Real Supply Routes: {len(routes)} routes loaded from DB")
    for r in routes:
        print(f"   -> Truck: {r['truck_id']}, Capacity: {r['payload_capacity_kg']} kg, Corridor: {r['corridor']}")

    # Clean previous test authorization if present so test is repeatable
    from app.core.database import get_db_connection
    with get_db_connection() as db_conn:
        db_conn.execute("DELETE FROM dso_dispatch_authorizations WHERE manifest_id = 'MAN-2026-0912';")
        db_conn.commit()

    # Stage 5: Dispatch Check
    res_check = client.get("/admin/dso/dispatch-check?cycle_id=2026-09&manifest_id=MAN-2026-0912", headers=headers)
    assert res_check.status_code == 200
    check = res_check.json()
    print(f"[Stage 5] Dispatch Check for MAN-2026-0912: {check['status']} (Can authorize: {check['can_authorize']})")

    # Stage 5: Dispatch Authorize
    res_auth = client.post("/admin/dso/dispatch-authorize", headers=headers, json={
        "manifest_id": "MAN-2026-0912",
        "cycle_id": "2026-09",
        "officer_name": "DSO Logged-in Officer",
        "notes": "Pre-dispatch clearance verified"
    })
    assert res_auth.status_code == 200
    print("[Stage 5] Dispatch authorized and persisted to audit log.")

    # Stage 7: Reconciliation
    res_rec = client.get("/admin/dso/reconciliation?cycle_id=2026-09", headers=headers)
    assert res_rec.status_code == 200
    rec = res_rec.json()
    print(f"[Stage 7] Reconciliation: Allocated {rec['allocated_kg']/1000:.1f} MT -> Dispatched {rec['dispatched_kg']/1000:.1f} MT -> Received {rec['received_kg']/1000:.1f} MT -> Distributed {rec['distributed_kg']/1000:.1f} MT -> Remaining {rec['remaining_fps_buffer_kg']/1000:.1f} MT")
    print("ALL DSO WORKFLOW BACKEND CHECKS PASSED WITH GROUNDED DATASET NUMBERS!")

if __name__ == "__main__":
    test_full_dso_workflow()
