import sys
import os
from fastapi.testclient import TestClient

from app.main import app
from app.core.auth import create_token

with TestClient(app) as client:
    print("Starting Inspector & Routing API Test Suite...")
    
    # Generate token inside lifespan initialized context
    token = create_token({"username": "field_officer_user", "role": "FIELD_OFFICER"})
    headers = {"Authorization": f"Bearer {token}", "Accept": "application/json"}

    endpoints_to_test = [
        ("GET", "/api/routing/optimize", None),
        ("GET", "/api/routing/gis-heatmap", None),
        ("POST", "/api/routing/verify-arrival", {"truck_id": "KA-04-GA-9081", "target_fps_id": "FPS-KA-BLR-001", "current_lat": 13.0031, "current_lon": 77.5643}),
        ("GET", "/api/routing/tracking/active", None),
        ("GET", "/api/routing/tracking/KA-04-GA-9081", None),
        ("POST", "/api/routing/tracking/KA-04-GA-9081/advance", None),
        ("POST", "/api/routing/tracking/KA-04-GA-9081/report-delay", {"delay_minutes": 15, "reason": "Highway Traffic"}),
        ("POST", "/api/routing/tracking/KA-04-GA-9081/report-deviation", {"reason": "Detour due to construction"}),
        ("POST", "/api/routing/tracking/KA-04-GA-9081/confirm-arrival", None),
        ("POST", "/api/routing/tracking/KA-04-GA-9081/confirm-delivery", None),
        ("GET", "/api/fps/list", None),
        ("GET", "/api/officer/inspections", None),
        ("POST", "/api/officer/inspection/submit", {
            "fps_id": "FPS-KA-BLR-001",
            "scale_certified": True,
            "display_board_updated": True,
            "stock_matches_register": True,
            "cctv_functional": True,
            "epos_online": True,
            "hygiene_compliant": True,
            "moisture_percentage": 11.5,
            "scale_error_grams": 0.0,
            "issue_seizure_notice": False,
            "seizure_reason": "",
            "remarks": "API Test Inspection Verified"
        })
    ]

    passed = 0
    failed = 0

    for method, url, payload in endpoints_to_test:
        try:
            if method == "GET":
                res = client.get(url, headers=headers)
            elif method == "POST":
                res = client.post(url, json=payload, headers=headers)
            
            if res.status_code in (200, 201):
                print(f"[SUCCESS] {method} {url} -> Status {res.status_code}")
                passed += 1
            else:
                print(f"[FAIL] {method} {url} -> Status {res.status_code}, Body: {res.text}")
                failed += 1
        except Exception as e:
            print(f"[ERROR] {method} {url} -> Exception: {e}")
            failed += 1

    print(f"\nAPI Test Summary: Passed {passed}/{len(endpoints_to_test)}, Failed {failed}")
    if failed > 0:
        sys.exit(1)
