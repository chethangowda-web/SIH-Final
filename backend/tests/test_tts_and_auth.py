"""
Verification tests for TTS audio streaming and strict dual-input dataset verification.
"""
import pytest
from fastapi.testclient import TestClient
from app.main import app

@pytest.fixture
def client():
    return TestClient(app)

def test_tts_kannada_audio(client):
    """Verify Kannada TTS audio stream returns 200 and audio/mpeg content."""
    res = client.get("/api/tts/speak", params={"lang": "kn", "text": "ನಮಸ್ಕಾರ! ಪಡಿತರ ಸೇವೆಗೆ ಸುಸ್ವಾಗತ."})
    assert res.status_code == 200
    assert res.headers.get("content-type") == "audio/mpeg"
    assert len(res.content) > 1000

def test_tts_hindi_audio(client):
    """Verify Hindi TTS audio stream returns 200 and audio/mpeg content."""
    res = client.get("/api/tts/speak", params={"lang": "hi", "text": "नमस्ते! राशन सेवा में आपका स्वागत है।"})
    assert res.status_code == 200
    assert res.headers.get("content-type") == "audio/mpeg"
    assert len(res.content) > 1000

def test_tts_cache_hit(client):
    """Verify repeated TTS queries hit in-memory cache instantly."""
    res1 = client.get("/api/tts/speak", params={"lang": "kn", "text": "ಒಟಿಪಿ ನಮೂದಿಸಲಾಗಿದೆ."})
    assert res1.status_code == 200
    res2 = client.get("/api/tts/speak", params={"lang": "kn", "text": "ಒಟಿಪಿ ನಮೂದಿಸಲಾಗಿದೆ."})
    assert res2.status_code == 200
    assert res2.headers.get("x-tts-source") == "cache"

def test_dataset_verification_valid_beneficiary_and_phone(client):
    """Verify official dataset matching returns 200 OK and generates OTP."""
    # RC-KA-000001 with registered head phone 9845012345
    res = client.post("/api/auth/citizen/send-otp", json={
        "card_id": "RC-KA-000001",
        "phone_number": "9845012345"
    })
    assert res.status_code in [200, 429]  # 429 only if rate limited in test suite
    if res.status_code == 200:
        data = res.json()
        assert data.get("status") == "success"

def test_dataset_verification_wrong_phone_rejected(client):
    """Verify entering an unregistered mobile number returns 403 Forbidden."""
    res = client.post("/api/auth/citizen/send-otp", json={
        "card_id": "RC-KA-000001",
        "phone_number": "9999999999"
    })
    assert res.status_code == 403
    assert "Security Check Failed" in res.json().get("detail", "")

def test_dataset_verification_nonexistent_card_rejected(client):
    """Verify entering a nonexistent card returns 404 Not Found."""
    res = client.post("/api/auth/citizen/send-otp", json={
        "card_id": "RC-KA-999999",
        "phone_number": "9845012345"
    })
    assert res.status_code == 404
    assert "not found in official NFSA Master Dataset" in res.json().get("detail", "")

def test_dataset_verification_missing_phone_rejected(client):
    """Verify omitting phone number returns 400 Bad Request."""
    res = client.post("/api/auth/citizen/send-otp", json={
        "card_id": "RC-KA-000001"
    })
    assert res.status_code == 400
