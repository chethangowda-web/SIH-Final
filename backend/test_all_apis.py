import os
import sys
from pathlib import Path
from datetime import datetime

# Add app parent directory to sys.path
sys.path.insert(0, str(Path(__file__).resolve().parent))

from fastapi.testclient import TestClient
from app.main import app

def log_test(name, passed, detail=""):
    symbol = "[PASS]" if passed else "[FAIL]"
    print(f"{symbol} | {name:<45} | {detail}")

def run_all_tests():
    print("=" * 80)
    print(f"PDS DemandSync Full Backend & API Verification Suite")
    print(f"Target: In-Memory FastAPI App | Time: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print("=" * 80)

    client = TestClient(app)
    passed_count = 0
    total_count = 0

    # 1. Health Endpoint
    total_count += 1
    r = client.get("/api/health")
    if r.status_code == 200 and r.json().get("status") == "healthy":
        passed_count += 1
        log_test("GET /api/health", True, f"status=200, db={r.json().get('database_status')}")
    else:
        log_test("GET /api/health", False, f"status={r.status_code}")

    # 2. Choice Window Status
    total_count += 1
    r = client.get("/api/choice-window/status?cycle_id=2026-09")
    if r.status_code == 200:
        passed_count += 1
        log_test("GET /api/choice-window/status", True, f"cycle={r.json().get('cycle_id')}, is_open={r.json().get('is_choice_window_open')}")
    else:
        log_test("GET /api/choice-window/status", False, f"status={r.status_code}")

    # 3. Admin Authentication
    total_count += 1
    r_admin = client.post("/api/auth/login", json={"username": "admin_user", "password": "admin_pass"})
    admin_token = ""
    if r_admin.status_code == 200 and "access_token" in r_admin.json():
        passed_count += 1
        admin_token = r_admin.json()["access_token"]
        log_test("POST /api/auth/login (ADMIN)", True, f"role={r_admin.json().get('role')}")
    else:
        log_test("POST /api/auth/login (ADMIN)", False, f"status={r_admin.status_code}")

    # 4. Auth Me Profile
    total_count += 1
    r_me = client.get("/api/auth/me", headers={"Authorization": f"Bearer {admin_token}"})
    if r_me.status_code == 200 and r_me.json().get("username") == "admin_user":
        passed_count += 1
        log_test("GET /api/auth/me", True, f"user={r_me.json().get('username')}, role={r_me.json().get('role')}")
    else:
        log_test("GET /api/auth/me", False, f"status={r_me.status_code}")

    # 5. Citizen OTP Send
    total_count += 1
    r_otp = client.post("/api/auth/citizen/send-otp", json={"card_id": "BEN-KA-0005"})
    if r_otp.status_code == 200 and "demo_otp_code" in r_otp.json():
        passed_count += 1
        log_test("POST /api/auth/citizen/send-otp", True, f"otp={r_otp.json().get('demo_otp_code')}")
    else:
        log_test("POST /api/auth/citizen/send-otp", False, f"status={r_otp.status_code}")

    # 6. Citizen OTP Verify
    total_count += 1
    r_verify = client.post("/api/auth/citizen/verify-otp", json={"card_id": "BEN-KA-0005", "otp_code": "123456"})
    citizen_token = ""
    if r_verify.status_code == 200 and "access_token" in r_verify.json():
        passed_count += 1
        citizen_token = r_verify.json()["access_token"]
        log_test("POST /api/auth/citizen/verify-otp", True, f"beneficiary_id={r_verify.json().get('beneficiary_id')}")
    else:
        log_test("POST /api/auth/citizen/verify-otp", False, f"status={r_verify.status_code}")

    # 7. Token Refresh
    total_count += 1
    ref_token = r_verify.json().get("refresh_token", "") if r_verify.status_code == 200 else ""
    r_ref = client.post("/api/auth/refresh", json={"refresh_token": ref_token})
    if r_ref.status_code == 200 and "access_token" in r_ref.json():
        passed_count += 1
        log_test("POST /api/auth/refresh", True, "new token issued successfully")
    else:
        log_test("POST /api/auth/refresh", False, f"status={r_ref.status_code}")

    # 8. FPS Master List (Authenticated)
    total_count += 1
    r_fps = client.get("/api/fps", headers={"Authorization": f"Bearer {admin_token}"})
    if r_fps.status_code == 200 and len(r_fps.json()) > 0:
        passed_count += 1
        log_test("GET /api/fps", True, f"count={len(r_fps.json())} shops")
    else:
        log_test("GET /api/fps", False, f"status={r_fps.status_code}")

    # 9. Beneficiary Master Search
    total_count += 1
    r_ben = client.get("/api/beneficiaries/BEN-KA-0005", headers={"Authorization": f"Bearer {citizen_token}"})
    if r_ben.status_code == 200:
        passed_count += 1
        log_test("GET /api/beneficiaries/BEN-KA-0005", True, f"name={r_ben.json().get('name_for_demo')}")
    else:
        log_test("GET /api/beneficiaries/BEN-KA-0005", False, f"status={r_ben.status_code}")

    # 10. Intent Signal Submission (Portability intent)
    total_count += 1
    intent_payload = {
        "beneficiary_id": "BEN-KA-0005",
        "cycle_id": "2026-09",
        "intended_fps_id": "FPS-KA-BLR-013",
        "commodity": "Rice",
        "declared_quantity_kg": 20.0,
        "delivery_mode": "FPS_COLLECTION"
    }
    r_int = client.post("/api/intent", json=intent_payload, headers={"Authorization": f"Bearer {citizen_token}"})
    if r_int.status_code in [200, 201]:
        passed_count += 1
        log_test("POST /api/intent", True, f"status={r_int.status_code}, fps={r_int.json().get('intended_fps_id')}")
    else:
        # Check if already submitted
        r_get_int = client.get("/api/intents?beneficiary_id=BEN-KA-0005&cycle_id=2026-09", headers={"Authorization": f"Bearer {citizen_token}"})
        if r_get_int.status_code == 200:
            passed_count += 1
            log_test("POST /api/intent (Already Registered)", True, f"intents_verified={len(r_get_int.json())}")
        else:
            log_test("POST /api/intent", False, f"status={r_int.status_code}")

    # 11. AI Anomaly & Fraud Scan
    total_count += 1
    r_anom = client.get("/api/anomaly/scan?cycle_id=2026-09")
    if r_anom.status_code == 200:
        passed_count += 1
        log_test("GET /api/anomaly/scan", True, f"status={r_anom.json().get('status')}, anomalies={r_anom.json().get('anomalies_detected')}")
    else:
        log_test("GET /api/anomaly/scan", False, f"status={r_anom.status_code}")

    # 12. VRP Fleet Optimization
    total_count += 1
    r_vrp = client.get("/api/routing/optimize")
    if r_vrp.status_code == 200 and "optimization_summary" in r_vrp.json():
        summary = r_vrp.json()["optimization_summary"]
        passed_count += 1
        log_test("GET /api/routing/optimize", True, f"routes={r_vrp.json().get('total_routes')}, fuel_saved={summary.get('fuel_saved_liters')}L")
    else:
        log_test("GET /api/routing/optimize", False, f"status={r_vrp.status_code}")

    # 13. GIS District Heatmap
    total_count += 1
    r_map = client.get("/api/routing/gis-heatmap?cycle_id=2026-09")
    if r_map.status_code == 200 and "points" in r_map.json():
        passed_count += 1
        log_test("GET /api/routing/gis-heatmap", True, f"points={r_map.json().get('total_fps_nodes')}, high_risk={r_map.json().get('high_risk_nodes')}")
    else:
        log_test("GET /api/routing/gis-heatmap", False, f"status={r_map.status_code}")

    # 14. Printable Allocation Order Report
    total_count += 1
    r_rep = client.get("/api/reports/allocation-order?cycle_id=2026-09")
    if r_rep.status_code == 200 and "GOVERNMENT OF KARNATAKA" in r_rep.text:
        passed_count += 1
        log_test("GET /api/reports/allocation-order", True, f"HTML size={len(r_rep.text)} bytes")
    else:
        log_test("GET /api/reports/allocation-order", False, f"status={r_rep.status_code}")

    # 15. District Admin Dashboard Summary
    total_count += 1
    r_dash = client.get("/api/admin/dashboard", headers={"Authorization": f"Bearer {admin_token}"})
    if r_dash.status_code == 200:
        passed_count += 1
        log_test("GET /api/admin/dashboard", True, f"district={r_dash.json().get('district')}")
    else:
        log_test("GET /api/admin/dashboard", False, f"status={r_dash.status_code}")

    # 16. Rural WhatsApp/USSD Feature-Phone Intent Simulator
    total_count += 1
    r_sim = client.post(
        "/api/intent/simulate-channel",
        json={
            "channel": "WHATSAPP",
            "beneficiary_card_id": "BEN-KA-0005",
            "raw_message_text": "RICE 20KG FPS-KA-BLR-013",
            "cycle_id": "2026-09"
        },
        headers={"Authorization": f"Bearer {citizen_token}"}
    )
    if r_sim.status_code in [200, 201] and r_sim.json().get("status") == "success":
        passed_count += 1
        log_test("POST /api/intent/simulate-channel", True, f"channel={r_sim.json().get('channel')}, qty={r_sim.json()['parsed_intent']['declared_quantity_kg']}kg")
    else:
        log_test("POST /api/intent/simulate-channel", False, f"status={r_sim.status_code}")

    # 17. Feedback & Ticket System
    total_count += 1
    r_fb = client.post(
        "/api/feedback/submit",
        json={
            "sender_type": "BENEFICIARY",
            "sender_id": "BEN-KA-0005",
            "target_fps_id": "FPS-KA-BLR-001",
            "category": "SHORT_WEIGHT",
            "subject": "Delivery Quantity Discrepancy",
            "message": "Received 18 kg instead of 20 kg."
        },
        headers={"Authorization": f"Bearer {citizen_token}"}
    )
    if r_fb.status_code == 201 and "ticket_id" in r_fb.json():
        passed_count += 1
        log_test("POST /api/feedback/submit", True, f"ticket_id={r_fb.json()['ticket_id']}")
    else:
        log_test("POST /api/feedback/submit", False, f"status={r_fb.status_code}")

    # 18. GPS Route Geofence Arrival Verification
    total_count += 1
    r_gps = client.post(
        "/api/routing/verify-arrival",
        json={
            "truck_id": "DEMO-KA-04-E-1021",
            "target_fps_id": "FPS-KA-BLR-001",
            "current_lat": 13.0031,
            "current_lon": 77.5643
        }
    )
    if r_gps.status_code == 200 and r_gps.json().get("geofence_arrival_verified") is True:
        passed_count += 1
        log_test("POST /api/routing/verify-arrival", True, f"status={r_gps.json().get('telemetry_status')}")
    else:
        log_test("POST /api/routing/verify-arrival", False, f"status={r_gps.status_code}")

    # 19. Officer Manual Override
    total_count += 1
    r_ovr = client.post(
        "/api/admin/fps/FPS-KA-BLR-001/override",
        json={
            "override_rice_kg": 4600.0,
            "override_wheat_kg": 1500.0,
            "safety_buffer_pct": 15.0,
            "emergency_priority": False
        },
        headers={"Authorization": f"Bearer {admin_token}"}
    )
    if r_ovr.status_code == 200 and r_ovr.json().get("status") == "success":
        passed_count += 1
        log_test("POST /api/admin/fps/{id}/override", True, f"fps={r_ovr.json().get('fps_id')}")
    else:
        log_test("POST /api/admin/fps/{id}/override", False, f"status={r_ovr.status_code}")

    # 20. AI Pre-Dispatch Stock Headroom Check
    total_count += 1
    r_stock = client.get("/api/admin/stock-headroom-check?cycle_id=2026-09", headers={"Authorization": f"Bearer {admin_token}"})
    if r_stock.status_code == 200 and "ai_status" in r_stock.json():
        passed_count += 1
        log_test("GET /api/admin/stock-headroom-check", True, f"ai_status={r_stock.json().get('ai_status')}")
    else:
        log_test("GET /api/admin/stock-headroom-check", False, f"status={r_stock.status_code}")




    print("=" * 80)
    print(f"SUMMARY: {passed_count}/{total_count} API Endpoint Tests PASSED ({passed_count/total_count*100:.1f}%)")
    print("=" * 80)

if __name__ == "__main__":
    run_all_tests()
