import pytest
import httpx
from datetime import datetime, timedelta, timezone
from app.main import app
from app.core.database import init_db, get_db_connection
from app.core.config import settings

@pytest.fixture(autouse=True)
def clean_otp_table():
    """Ensure database is initialized and OTP records are cleared before each test."""
    init_db()
    with get_db_connection() as conn:
        conn.execute("DELETE FROM otp_verifications;")
        conn.commit()

@pytest.mark.asyncio
async def test_household_phones_lookup():
    """Verify that household phone numbers can be fetched and are masked for privacy."""
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        # Valid card RC-KA-000001
        res = await client.get("/api/auth/citizen/household-phones/RC-KA-000001")
        assert res.status_code == 200
        data = res.json()
        assert data["card_id"] == "RC-KA-000001"
        assert len(data["household_phones"]) >= 1
        
        # Verify phones are masked
        for item in data["household_phones"]:
            assert "masked_phone" in item
            assert "phone_last4" in item
            assert "name" in item
            assert "*" in item["masked_phone"]

        # Non-existent card returns 404
        res_404 = await client.get("/api/auth/citizen/household-phones/RC-NONEXISTENT")
        assert res_404.status_code == 404

@pytest.mark.asyncio
async def test_send_otp_success_household_phone():
    """Verify that registered household member can request an OTP."""
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        payload = {
            "card_id": "RC-KA-000001",
            "phone_number": "9845012345"  # Deepa Reddy
        }
        res = await client.post("/api/auth/citizen/send-otp", json=payload)
        assert res.status_code == 200
        data = res.json()
        assert data["status"] == "success"
        assert data["member_name"] == "Deepa Reddy"
        assert "demo_otp" in data or data["mode"] == "REAL"

@pytest.mark.asyncio
async def test_send_otp_rejected_for_non_household_phone():
    """Verify that arbitrary / random phone number not belonging to the household is strictly rejected with 403."""
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        payload = {
            "card_id": "RC-KA-000001",
            "phone_number": "9999988888"  # Arbitrary unauthorized phone
        }
        res = await client.post("/api/auth/citizen/send-otp", json=payload)
        assert res.status_code == 403
        data = res.json()
        assert "does not belong to any registered member" in data["detail"]

@pytest.mark.asyncio
async def test_send_otp_cooldown():
    """Verify that rapid OTP resend triggers a cooldown 429 response."""
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        payload = {
            "card_id": "RC-KA-000005",
            "phone_number": "9845020005"  # Manoj Sharma
        }
        # First request succeeds
        res1 = await client.post("/api/auth/citizen/send-otp", json=payload)
        assert res1.status_code == 200

        # Immediate second request should trigger cooldown
        res2 = await client.post("/api/auth/citizen/send-otp", json=payload)
        assert res2.status_code == 429
        assert "Please wait" in res2.json()["detail"]

@pytest.mark.asyncio
async def test_verify_otp_success_demo_mode():
    """Verify successful OTP verification creates a valid beneficiary session with both generated OTP and 123456 bypass."""
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        # Request OTP for RC-KA-000001 / +919845012345
        send_res = await client.post("/api/auth/citizen/send-otp", json={
            "card_id": "RC-KA-000001",
            "phone_number": "9845012345"
        })
        assert send_res.status_code == 200
        demo_otp = send_res.json().get("demo_otp", "123456")

        # Verify with generated demo OTP
        verify_res = await client.post("/api/auth/citizen/verify-otp", json={
            "card_id": "RC-KA-000001",
            "phone_number": "9845012345",
            "otp_code": demo_otp
        })
        assert verify_res.status_code == 200
        data = verify_res.json()
        assert "access_token" in data
        assert data["role"] == "BENEFICIARY"
        assert data["beneficiary_id"] in ["BEN-KA-0001", "RC-KA-000001"]

@pytest.mark.asyncio
async def test_verify_otp_demo_123456_bypass():
    """Verify standard SIH 123456 bypass works in DEMO mode."""
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        # Request OTP
        send_res = await client.post("/api/auth/citizen/send-otp", json={
            "card_id": "RC-KA-000001",
            "phone_number": "9845012345"
        })
        assert send_res.status_code == 200

        # Verify with 123456
        verify_res = await client.post("/api/auth/citizen/verify-otp", json={
            "card_id": "RC-KA-000001",
            "otp": "123456"
        })
        assert verify_res.status_code == 200
        assert "access_token" in verify_res.json()

@pytest.mark.asyncio
async def test_verify_otp_invalid_and_throttling():
    """Verify incorrect OTP is rejected with remaining attempt count and exhausts after 3 tries."""
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        # Request OTP for BEN-KA-0002 / +919845010001
        send_res = await client.post("/api/auth/citizen/send-otp", json={
            "card_id": "BEN-KA-0002",
            "phone_number": "9845010001"
        })
        assert send_res.status_code == 200

        # Attempt 1: Wrong OTP
        res1 = await client.post("/api/auth/citizen/verify-otp", json={
            "card_id": "BEN-KA-0002",
            "otp_code": "000000"
        })
        assert res1.status_code == 401
        assert "2 attempt(s) remaining" in res1.json()["detail"]

        # Attempt 2: Wrong OTP
        res2 = await client.post("/api/auth/citizen/verify-otp", json={
            "card_id": "BEN-KA-0002",
            "otp_code": "000000"
        })
        assert res2.status_code == 401
        assert "1 attempt(s) remaining" in res2.json()["detail"]

        # Attempt 3: Wrong OTP -> Invalidated / Exhausted
        res3 = await client.post("/api/auth/citizen/verify-otp", json={
            "card_id": "BEN-KA-0002",
            "otp_code": "000000"
        })
        assert res3.status_code == 401
        assert "Maximum attempts reached" in res3.json()["detail"]

        # Attempt 4: Should be completely blocked
        res4 = await client.post("/api/auth/citizen/verify-otp", json={
            "card_id": "BEN-KA-0002",
            "otp_code": "000000"
        })
        assert res4.status_code in [401, 403]

@pytest.mark.asyncio
async def test_verify_otp_expired_rejected():
    """Verify expired OTP (>5 min old) is rejected."""
    # Send OTP
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        send_res = await client.post("/api/auth/citizen/send-otp", json={
            "card_id": "RC-KA-000009",
            "phone_number": "9845030009"
        })
        assert send_res.status_code == 200
        code = send_res.json().get("demo_otp")

        # Artificially age the OTP in the database past 5 minutes
        past_time = (datetime.now(timezone.utc).replace(tzinfo=None) - timedelta(minutes=10)).strftime("%Y-%m-%d %H:%M:%S")
        with get_db_connection() as conn:
            conn.execute("UPDATE otp_verifications SET expires_at = ? WHERE identifier = 'RC-KA-000009';", (past_time,))
            conn.commit()

        # Attempt verification with expired code (not 123456)
        res = await client.post("/api/auth/citizen/verify-otp", json={
            "card_id": "RC-KA-000009",
            "otp_code": code
        })
        assert res.status_code == 401
        assert "expired" in res.json()["detail"].lower()

@pytest.mark.asyncio
async def test_real_otp_mode_fallback(monkeypatch):
    """Verify that when OTP_MODE is real but SMS credentials are empty, system safely falls back to demo mode without crashing."""
    monkeypatch.setattr(settings, "OTP_MODE", "real")
    monkeypatch.setattr(settings, "TWILIO_ACCOUNT_SID", None)
    monkeypatch.setattr(settings, "TWILIO_AUTH_TOKEN", None)

    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        res = await client.post("/api/auth/citizen/send-otp", json={
            "card_id": "RC-KA-000009",
            "phone_number": "9845030009"
        })
        assert res.status_code == 200
        data = res.json()
        assert data["status"] == "success"
        # Fallback demo OTP is returned when live SMS provider is unavailable
        assert "demo_otp" in data
