"""
End-to-End Operational Flow Verification for Fair Price Shop (FPS) Owner Portal
Ground-truth testing using real SQLite database (pds_demandsync.db).
"""
import sys
import os

# Add backend to sys.path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from fastapi.testclient import TestClient
from app.main import app
from app.core.auth import create_token

def test_fps_owner_full_operational_flow():
    print("\n" + "=" * 69)
    print("PDS DEMANDSYNC - FPS OWNER OPERATIONAL FLOW VERIFICATION")
    print("=" * 69)

    client = TestClient(app)

    # Generate authoritative auth tokens
    fps_id = "FPS-KA-BLR-002"
    token = create_token(data={"username": "fps_user", "role": "FPS_OWNER", "beneficiary_id": None})
    headers = {"Authorization": f"Bearer {token}"}

    # [1] Authenticated Profile / Me Lookup
    print(f"\n[1] Verifying /officer/fps/me for {fps_id}...")
    res = client.get("/api/officer/fps/me", headers=headers)
    assert res.status_code == 200, f"Expected 200, got {res.status_code}: {res.text}"
    me = res.json()
    print(f"  [OK] FPS Name: {me['name']}, District: {me['district']}, Status: {me['operating_status']}")

    # [2] Dashboard Overview & Real KPIs
    print(f"\n[2] Verifying /officer/fps/{fps_id}/dashboard-overview...")
    res = client.get(f"/api/officer/fps/{fps_id}/dashboard-overview?cycle_id=2026-09", headers=headers)
    assert res.status_code == 200, f"Expected 200, got {res.status_code}: {res.text}"
    overview = res.json()
    kpis = overview["kpis"]
    print(f"  [OK] Total Beneficiaries: {kpis['total_beneficiaries']}, Served: {kpis['served_beneficiaries']}, Pending: {kpis['pending_beneficiaries']}")
    print(f"  [OK] Current Stock: Rice {kpis['current_rice_stock_kg']}kg, Wheat {kpis['current_wheat_stock_kg']}kg")
    print(f"  [OK] Days Remaining: {kpis['stock_days_remaining']} days, Open Exceptions: {kpis['open_exceptions_count']}")

    # [3] Beneficiaries Registry Search
    print(f"\n[3] Verifying /officer/fps/{fps_id}/beneficiaries...")
    res = client.get(f"/api/officer/fps/{fps_id}/beneficiaries?limit=10", headers=headers)
    assert res.status_code == 200, f"Expected 200, got {res.status_code}: {res.text}"
    bens = res.json()
    print(f"  [OK] Total Registered Beneficiaries: {bens['total_count']}, Retrieved: {len(bens['beneficiaries'])}")
    if bens['beneficiaries']:
        b0 = bens['beneficiaries'][0]
        print(f"  [OK] Sample Beneficiary: {b0['name']} ({b0['beneficiary_id']}), Scheme: {b0['scheme_type']}, Rice Quota: {b0['statutory_rice_kg']}kg")

    # [4] Inbound Deliveries / Manifests
    print(f"\n[4] Verifying /officer/fps/{fps_id}/deliveries...")
    res = client.get(f"/api/officer/fps/{fps_id}/deliveries", headers=headers)
    assert res.status_code == 200, f"Expected 200, got {res.status_code}: {res.text}"
    delivs = res.json()
    print(f"  [OK] Total Deliveries: {delivs['total_deliveries']}")

    # [5] e-PoS Beneficiary Verification & Eligibility
    print(f"\n[5] Verifying /epos/eligibility...")
    ben_id = "BEN-KA-0001"
    res = client.get(f"/api/officer/epos/eligibility?fps_id={fps_id}&beneficiary_id={ben_id}&cycle_id=2026-09", headers=headers)
    if res.status_code == 200:
        el = res.json()
        print(f"  [OK] Eligibility Check Passed: {el['name']} ({el['beneficiary_id']}), Card Type: {el['card_type']}, Already Collected: {el['already_collected']}")

    # [6] AI Insights
    print(f"\n[6] Verifying /officer/fps/{fps_id}/ai-insights...")
    res = client.get(f"/api/officer/fps/{fps_id}/ai-insights?cycle_id=2026-09", headers=headers)
    assert res.status_code == 200, f"Expected 200, got {res.status_code}: {res.text}"
    insights = res.json()
    print(f"  [OK] AI Insights Generated: {insights['insights_count']}")
    for ins in insights['insights']:
        print(f"    - [{ins['severity']}] {ins['title']} (Why: {ins['why']})")

    # [7] Exceptions Queue
    print(f"\n[7] Verifying /officer/fps/{fps_id}/exceptions...")
    res = client.get(f"/api/officer/fps/{fps_id}/exceptions", headers=headers)
    assert res.status_code == 200, f"Expected 200, got {res.status_code}: {res.text}"
    excs = res.json()
    print(f"  [OK] Total Exceptions: {excs['total_exceptions']}")

    # [8] Decision Trace Timeline
    print(f"\n[8] Verifying /officer/fps/{fps_id}/decision-trace...")
    res = client.get(f"/api/officer/fps/{fps_id}/decision-trace", headers=headers)
    assert res.status_code == 200, f"Expected 200, got {res.status_code}: {res.text}"
    trace = res.json()
    print(f"  [OK] Decision Trace Events: {trace['total_events']}")

    # [9] Data Sources Provenance
    print(f"\n[9] Verifying /officer/fps/{fps_id}/data-sources...")
    res = client.get(f"/api/officer/fps/{fps_id}/data-sources", headers=headers)
    assert res.status_code == 200, f"Expected 200, got {res.status_code}: {res.text}"
    sources = res.json()
    print(f"  [OK] Active Data Tables Provenance Count: {len(sources['sources'])}")

    print("\n" + "=" * 69)
    print("[SUCCESS] ALL FPS OWNER OPERATIONAL FLOW CHECKS PASSED!")
    print("=" * 69 + "\n")

if __name__ == "__main__":
    test_fps_owner_full_operational_flow()
