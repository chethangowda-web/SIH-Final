import os
import sqlite3
from fastapi.testclient import TestClient
from app.main import app
from app.core.database import get_db

client = TestClient(app)

def override_get_db():
    conn = sqlite3.connect(":memory:")
    conn.row_factory = sqlite3.Row
    
    # Create required tables
    conn.execute('''
    CREATE TABLE intent (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        beneficiary_id TEXT,
        cycle_id TEXT,
        intended_fps_id TEXT,
        commodity TEXT,
        declared_quantity_kg REAL,
        confidence REAL,
        status TEXT,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        UNIQUE(beneficiary_id, cycle_id, commodity)
    )
    ''')
    conn.commit()
    return conn

app.dependency_overrides[get_db] = override_get_db

def test_twilio_webhook():
    payload = {
        "From": "+123456789",
        "Body": "RC-KA-000001 RICE 20KG FPS-KA-BAG-0001"
    }
    
    response = client.post("/api/twilio-webhook", data=payload)
    
    assert response.status_code == 200
    assert "Thank you! Intent for 20.0kg Rice at FPS-KA-BAG-0001 registered successfully for RC-KA-000001." in response.text

if __name__ == "__main__":
    test_twilio_webhook()
    print("Twilio webhook test passed successfully.")
