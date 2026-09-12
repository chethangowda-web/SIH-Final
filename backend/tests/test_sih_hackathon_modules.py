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
    """Test real CSV validation and ingestion endpoint."""
    csv_content = (
        "fps_id,name,district,pincode,latitude,longitude,capacity_kg\n"
        "FPS-TEST-001,Test Shop 1,Bengaluru Urban,560001,12.9716,77.5946,12000.0\n"
    )
    file_bytes = io.BytesIO(csv_content.encode("utf-8"))
    files = {"file": ("fps_test.csv", file_bytes, "text/csv")}
    response = client.post("/api/import/fps-csv", files=files)
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "success"
    assert data["successful_imports"] == 1
