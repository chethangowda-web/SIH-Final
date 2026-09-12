"""Unit and Integration Tests for SIH Hackathon Production Modules: Anomaly Engine, VRP Solver, CSV Import, and Reports."""

import pytest
import io
from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)

def test_anomaly_scan_api():
    """Test AI Anomaly & Fraud Detection scan endpoint."""
    response = client.get("/api/anomaly/scan?cycle_id=2026-09")
    assert response.status_code == 200
    data = response.json()
    assert "cycle_id" in data
    assert "status" in data
    assert "anomalies_detected" in data
    assert "fps_risk_summary" in data

def test_anomaly_summary_api():
    """Test Anomaly Summary endpoint for Admin Dashboard."""
    response = client.get("/api/anomaly/summary?cycle_id=2026-09")
    assert response.status_code == 200
    data = response.json()
    assert data["cycle_id"] == "2026-09"
    assert "high_risk_fps_count" in data

def test_vrp_routing_optimize_api():
    """Test Vehicle Routing Problem (VRP) optimization endpoint."""
    response = client.get("/api/routing/optimize?truck_capacity_kg=10000.0")
    assert response.status_code == 200
    data = response.json()
    assert "godown" in data
    assert "routes" in data
    assert "optimization_summary" in data
    summary = data["optimization_summary"]
    assert "fuel_saved_liters" in summary
    assert "co2_emissions_avoided_kg" in summary

def test_gis_heatmap_api():
    """Test GIS District Heatmap data endpoint."""
    response = client.get("/api/routing/gis-heatmap?cycle_id=2026-09")
    assert response.status_code == 200
    data = response.json()
    assert "points" in data
    assert len(data["points"]) > 0
    first_point = data["points"][0]
    assert "latitude" in first_point
    assert "longitude" in first_point
    assert "risk_level" in first_point
    assert "color_hex" in first_point

def test_allocation_order_report_html():
    """Test Official Printable State Allocation Order endpoint."""
    response = client.get("/api/reports/allocation-order?cycle_id=2026-09")
    assert response.status_code == 200
    assert "GOVERNMENT OF KARNATAKA" in response.text
    assert "PRE-DISPATCH GRAIN ALLOCATION ORDER" in response.text

def test_fps_csv_import_validation():
    """Test CSV FPS bulk import validation endpoint."""
    csv_content = (
        "fps_id,name,district,latitude,longitude,capacity_kg\n"
        "FPS-KA-TEST-001,Test Seva Kendra,Bengaluru Urban,12.9716,77.5946,20000.0\n"
    )
    files = {"file": ("test_fps.csv", io.BytesIO(csv_content.encode("utf-8")), "text/csv")}
    response = client.post("/api/import/fps-csv", files=files)
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "success"
    assert data["successful_imports"] == 1

def test_channel_simulate_api():
    """Test Rural USSD / WhatsApp non-smartphone intent simulation endpoint."""
    response = client.post("/api/intent/simulate-channel", json={
        "channel": "WHATSAPP",
        "beneficiary_card_id": "BEN-KA-0005",
        "raw_message_text": "RICE 20KG FPS-KA-BLR-013",
        "cycle_id": "2026-09"
    })
    assert response.status_code == 201
    data = response.json()
    assert data["status"] == "success"
    assert data["channel"] == "WHATSAPP"
    assert data["parsed_intent"]["declared_quantity_kg"] == 20.0
