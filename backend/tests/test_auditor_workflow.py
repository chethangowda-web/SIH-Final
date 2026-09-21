"""
Automated Pytest Suite for Auditor Portal Command Center & Workflow Lifecycle
Verifies:
1. Overview & Cycle Resolution
2. Stage 01: Audit Assignment Planning & Creation
3. Stage 02: PDS Supply Chain Record Verification
4. Stage 02/04: Record Reconciliation
5. Stage 03: Field Food Inspection Records Review
6. Stage 04: Auditor Findings & Compliance Analysis
7. Stage 05: Cryptographic SHA-256 Report Generation & Finalization
8. Stage 06: Audit Validation & Permanent Closure
9. Cross-Portal Traceability Engine
10. RBAC Security & Role Guards
"""

import pytest
import sqlite3
from fastapi.testclient import TestClient
from app.main import app
from app.core.database import init_db
from app.core.auth import create_token

client = TestClient(app)

@pytest.fixture(autouse=True)
def setup_test_db():
    init_db()

def get_auth_header(role: str = "AUDITOR", username: str = "auditor_user"):
    token = create_token({"username": username, "role": role})
    return {"Authorization": f"Bearer {token}"}

def test_1_auditor_overview_and_cycles():
    headers = get_auth_header()
    res = client.get("/api/auditor/overview?cycle_id=2026-09", headers=headers)
    assert res.status_code == 200
    data = res.json()
    assert "summary" in data
    assert "stage_breakdown" in data
    assert data["auditor_id"] == "auditor_user"

    res_cycles = client.get("/api/auditor/cycles", headers=headers)
    assert res_cycles.status_code == 200
    assert "2026-09" in res_cycles.json()["cycles"]

def test_2_stage_01_plan_and_schedule_audit():
    headers = get_auth_header()
    payload = {
        "fps_id": "FPS-KA-BLR-002",
        "audit_type": "FULL_AUDIT",
        "cycle_id": "2026-09",
        "assigned_team": "Vigilance Taskforce Alpha"
    }
    res = client.post("/api/auditor/audits", headers=headers, json=payload)
    assert res.status_code == 200
    data = res.json()
    assert data["status"] == "SUCCESS"
    assert data["fps_id"] == "FPS-KA-BLR-002"
    assert data["current_stage"] == 1
    assert "AUD-" in data["audit_id"]

def test_3_stage_02_verify_pds_supply_chain_records():
    headers = get_auth_header()
    # Create audit
    res_create = client.post("/api/auditor/audits", headers=headers, json={"fps_id": "FPS-KA-BLR-002"})
    audit_id = res_create.json()["audit_id"]

    # Verify PDS data chain lookup
    res_records = client.get(f"/api/auditor/audits/{audit_id}/records", headers=headers)
    assert res_records.status_code == 200
    chain = res_records.json()["chain_verification"]
    assert "beneficiary_records_count" in chain
    assert "inventory_stock" in chain

    # Perform verification transition
    res_verify = client.post(f"/api/auditor/audits/{audit_id}/verify-records", headers=headers)
    assert res_verify.status_code == 200
    assert res_verify.json()["workflow_status"] == "RECORDS_VERIFIED"
    assert res_verify.json()["current_stage"] == 2

def test_4_stage_03_review_field_food_inspections():
    headers = get_auth_header()
    res_create = client.post("/api/auditor/audits", headers=headers, json={"fps_id": "FPS-KA-BLR-002"})
    audit_id = res_create.json()["audit_id"]

    res_insp = client.get(f"/api/auditor/audits/{audit_id}/inspections", headers=headers)
    assert res_insp.status_code == 200
    assert "inspections" in res_insp.json()

def test_5_stage_04_compliance_analysis_and_findings():
    headers = get_auth_header()
    res_create = client.post("/api/auditor/audits", headers=headers, json={"fps_id": "FPS-KA-BLR-002"})
    audit_id = res_create.json()["audit_id"]

    finding_payload = {
        "finding_type": "STOCK_VARIANCE",
        "severity": "HIGH",
        "title": "Minor Inventory Stock Discrepancy",
        "description": "Physical stock count deviates from e-PoS ledger balance by 0.5kg.",
        "evidence_refs": ["inventory", "epos_transactions"],
        "auditor_recommendation": "Conduct follow-up audit next month."
    }
    res_find = client.post(f"/api/auditor/audits/{audit_id}/findings", headers=headers, json=finding_payload)
    assert res_find.status_code == 200
    assert res_find.json()["status"] == "SUCCESS"

def test_6_stage_05_generate_sha256_sealed_report():
    headers = get_auth_header()
    res_create = client.post("/api/auditor/audits", headers=headers, json={"fps_id": "FPS-KA-BLR-002"})
    audit_id = res_create.json()["audit_id"]

    # Generate Report
    report_payload = {
        "scope_text": "Statutory Quarterly Vigilance Audit",
        "audit_observations": "All physical and digital records reconciled."
    }
    res_gen = client.post(f"/api/auditor/audits/{audit_id}/generate-report", headers=headers, json=report_payload)
    assert res_gen.status_code == 200
    rep_data = res_gen.json()
    assert rep_data["workflow_status"] == "REPORT_DRAFT"
    assert rep_data["report_hash"].startswith("sha256-")

    # Finalize Report
    res_fin = client.post(f"/api/auditor/audits/{audit_id}/finalize-report", headers=headers)
    assert res_fin.status_code == 200
    assert res_fin.json()["workflow_status"] == "REPORT_FINALIZED"

def test_7_stage_06_close_and_seal_audit():
    headers = get_auth_header()
    res_create = client.post("/api/auditor/audits", headers=headers, json={"fps_id": "FPS-KA-BLR-002"})
    audit_id = res_create.json()["audit_id"]

    client.post(f"/api/auditor/audits/{audit_id}/generate-report", headers=headers, json={"scope_text": "Audit"})
    client.post(f"/api/auditor/audits/{audit_id}/finalize-report", headers=headers)

    res_close = client.post(f"/api/auditor/audits/{audit_id}/close", headers=headers, json={"closure_reason": "Statutory audit closed"})
    assert res_close.status_code == 200
    assert res_close.json()["workflow_status"] == "AUDIT_CLOSED"
    assert res_close.json()["current_stage"] == 6

def test_8_cross_portal_traceability():
    headers = get_auth_header()
    res = client.get("/api/auditor/trace/FPS/FPS-KA-BLR-002", headers=headers)
    assert res.status_code == 200
    chain = res.json()["trace_chain"]
    assert len(chain) == 9
    assert chain[0]["layer"] == "BENEFICIARY"
    assert chain[8]["layer"] == "AUDIT"

def test_9_ai_compliance_intelligence():
    headers = get_auth_header()
    res_ins = client.get("/api/auditor/ai/insights", headers=headers)
    assert res_ins.status_code == 200
    assert res_ins.json()["insights_count"] > 0

    res_anom = client.get("/api/auditor/ai/anomalies", headers=headers)
    assert res_anom.status_code == 200

    res_rec = client.get("/api/auditor/ai/recommendations", headers=headers)
    assert res_rec.status_code == 200

def test_10_security_rbac_guards():
    # Unauthorized role (e.g. BENEFICIARY) must be rejected with 401 or 403
    token = create_token({"username": "BEN-KA-0001", "role": "BENEFICIARY"})
    headers = {"Authorization": f"Bearer {token}"}
    res = client.get("/api/auditor/overview", headers=headers)
    assert res.status_code in (401, 403)
