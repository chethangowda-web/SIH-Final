"""Automated tests verifying authentication coverage across all 10,000 dataset beneficiaries."""
import pytest
import httpx
from app.main import app
from app.core.database import get_db_connection, init_db, populate_all_dataset_household_members
from app.api.auth import resolve_beneficiary_record

@pytest.fixture(autouse=True)
def setup_dataset():
    """Ensure database is initialized and household members populated."""
    init_db()
    conn = get_db_connection()
    populate_all_dataset_household_members(conn)
    conn.close()

def test_database_beneficiary_coverage():
    """Verify that all 10,000+ beneficiaries exist, have user accounts, and have household members."""
    conn = get_db_connection()
    cursor = conn.cursor()

    cursor.execute("SELECT COUNT(*) FROM beneficiaries;")
    total_bens = cursor.fetchone()[0]
    assert total_bens >= 10000, f"Expected at least 10,000 beneficiaries, found {total_bens}"

    cursor.execute("SELECT COUNT(*) FROM household_members;")
    total_members = cursor.fetchone()[0]
    assert total_members >= 40000, f"Expected at least 40,000 household members, found {total_members}"

    cursor.execute("SELECT COUNT(*) FROM users WHERE role = 'BENEFICIARY';")
    total_users = cursor.fetchone()[0]
    assert total_users >= 10000, f"Expected at least 10,000 beneficiary user accounts, found {total_users}"

    # Check for any beneficiary missing household members
    cursor.execute("""
        SELECT b.pseudonymous_beneficiary_id, COUNT(m.id) as cnt
        FROM beneficiaries b
        LEFT JOIN household_members m ON b.pseudonymous_beneficiary_id = m.beneficiary_card_id
        WHERE b.pseudonymous_beneficiary_id NOT LIKE 'TEST-%'
        GROUP BY b.pseudonymous_beneficiary_id
        HAVING cnt = 0;
    """)
    missing = cursor.fetchall()
    assert len(missing) == 0, f"Found {len(missing)} beneficiaries missing household members"

    # Check for any household without a registered 10-digit phone
    cursor.execute("""
        SELECT pseudonymous_beneficiary_id
        FROM beneficiaries
        WHERE (phone IS NULL OR LENGTH(phone) < 10)
          AND pseudonymous_beneficiary_id NOT LIKE 'TEST-%';
    """)
    no_phone = cursor.fetchall()
    assert len(no_phone) == 0, f"Found {len(no_phone)} households without valid registered phone"
    conn.close()

def test_flexible_card_and_name_resolution():
    """Verify that cards resolve by exact ID, normalized digits, or Head of Household name."""
    conn = get_db_connection()
    cursor = conn.cursor()

    # Exact ID
    res1 = resolve_beneficiary_record(cursor, "RC-KA-000001")
    assert res1 is not None
    assert res1["pseudonymous_beneficiary_id"] == "RC-KA-000001"

    # Alias / Numeric format
    res2 = resolve_beneficiary_record(cursor, "000002")
    assert res2 is not None
    assert res2["pseudonymous_beneficiary_id"] == "RC-KA-000002"

    # Name resolution
    res3 = resolve_beneficiary_record(cursor, "Deepa Reddy")
    assert res3 is not None
    assert res3["name_for_demo"] == "Deepa Reddy"

    # Search directory resolution
    res4 = resolve_beneficiary_record(cursor, "Swathi Joshi")
    assert res4 is not None
    assert res4["pseudonymous_beneficiary_id"] == "RC-KA-000002"
    conn.close()

@pytest.mark.asyncio
async def test_search_beneficiaries_api():
    """Verify GET /api/auth/citizen/search returns matching results across datasets."""
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        # Search by district
        res_district = await client.get("/api/auth/citizen/search?q=Bagalkot&limit=5")
        assert res_district.status_code == 200
        data = res_district.json()
        assert len(data["results"]) == 5
        assert all(r["district"] == "Bagalkot" for r in data["results"])

        # Search by name
        res_name = await client.get("/api/auth/citizen/search?q=Deepa&limit=5")
        assert res_name.status_code == 200
        data_name = res_name.json()
        assert len(data_name["results"]) >= 1
        assert any("Deepa" in r["name_for_demo"] for r in data_name["results"])

@pytest.mark.asyncio
async def test_end_to_end_citizen_login_flow():
    """Verify full login: household-phones -> send-otp -> verify-otp -> token -> beneficiary profile."""
    test_cards = ["RC-KA-000001", "RC-KA-000002", "RC-KA-000005", "BEN-KA-0002"]

    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        for card_id in test_cards:
            # 1. Fetch household phones
            res1 = await client.get(f"/api/auth/citizen/household-phones/{card_id}")
            assert res1.status_code == 200
            phones_data = res1.json()
            members = phones_data["household_phones"]
            assert len(members) >= 1
            first_phone = members[0]["demo_phone"]

            # 2. Request OTP
            res2 = await client.post("/api/auth/citizen/send-otp", json={
                "card_id": card_id,
                "phone_number": first_phone
            })
            assert res2.status_code == 200

            # Get generated OTP from database
            conn = get_db_connection()
            otp_code = conn.execute(
                "SELECT otp_code FROM otp_verifications WHERE identifier = ? ORDER BY id DESC LIMIT 1;",
                (card_id,)
            ).fetchone()[0]
            conn.close()

            # 3. Verify OTP
            res3 = await client.post("/api/auth/citizen/verify-otp", json={
                "card_id": card_id,
                "otp_code": otp_code
            })
            assert res3.status_code == 200
            auth_data = res3.json()
            token = auth_data["access_token"]
            assert token is not None

            # 4. Access beneficiary profile
            res4 = await client.get(
                f"/api/beneficiaries/{card_id}",
                headers={"Authorization": f"Bearer {token}"}
            )
            assert res4.status_code == 200
            detail = res4.json()
            assert detail["pseudonymous_beneficiary_id"] == card_id

@pytest.mark.asyncio
async def test_security_rejections():
    """Verify security controls: 404 for unknown cards, 403 for unregistered phones, 401/403 for invalid OTP."""
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        # Non-existent card
        res1 = await client.get("/api/auth/citizen/household-phones/RC-UNKNOWN-999999")
        assert res1.status_code == 404

        # Unregistered phone for real card
        res2 = await client.post("/api/auth/citizen/send-otp", json={
            "card_id": "RC-KA-000001",
            "phone_number": "+919999999999"
        })
        assert res2.status_code == 403

        # Invalid OTP
        res3 = await client.post("/api/auth/citizen/verify-otp", json={
            "card_id": "RC-KA-000001",
            "otp_code": "000000"
        })
        assert res3.status_code in (401, 403)
