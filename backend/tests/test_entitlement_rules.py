import pytest
import sqlite3
import httpx
from app.main import app
from app.core.database import get_db_connection, init_db
from app.services.ai_request_advisor import ai_request_advisor
from app.services.scarcity_engine import scarcity_allocation_engine

@pytest.fixture(autouse=True)
def setup_test_database():
    """Ensure database schema and baseline records are initialized."""
    init_db()

def test_household_entitlement_1_member():
    """1 eligible member -> 4 kg Rice, 1 kg Wheat."""
    with get_db_connection() as conn:
        cursor = conn.cursor()
        card_id = "TEST-PHH-01"
        cursor.execute("DELETE FROM household_members WHERE beneficiary_card_id = ?;", (card_id,))
        cursor.execute("DELETE FROM beneficiaries WHERE pseudonymous_beneficiary_id = ?;", (card_id,))
        cursor.execute("""
        INSERT INTO beneficiaries (pseudonymous_beneficiary_id, name_for_demo, registered_fps_id, scheme_type, members_count)
        VALUES (?, 'Single Member', 'FPS-KA-BLR-001', 'PHH', 1);
        """, (card_id,))
        cursor.execute("""
        INSERT INTO household_members (beneficiary_card_id, member_id, name, relationship, is_eligible)
        VALUES (?, 'M-01', 'Member One', 'Head of Household', 1);
        """, (card_id,))
        conn.commit()

        ent = ai_request_advisor.get_beneficiary_entitlement(conn, card_id, "Both")
        assert ent["eligible_members_count"] == 1
        assert ent["statutory_entitlement_rice_kg"] == 4.0
        assert ent["statutory_entitlement_wheat_kg"] == 1.0
        assert ent["statutory_entitlement_commodity_kg"] == 5.0

def test_household_entitlement_2_members():
    """2 eligible members -> 8 kg Rice, 2 kg Wheat."""
    with get_db_connection() as conn:
        cursor = conn.cursor()
        card_id = "TEST-PHH-02"
        cursor.execute("DELETE FROM household_members WHERE beneficiary_card_id = ?;", (card_id,))
        cursor.execute("DELETE FROM beneficiaries WHERE pseudonymous_beneficiary_id = ?;", (card_id,))
        cursor.execute("""
        INSERT INTO beneficiaries (pseudonymous_beneficiary_id, name_for_demo, registered_fps_id, scheme_type, members_count)
        VALUES (?, 'Two Members', 'FPS-KA-BLR-001', 'PHH', 2);
        """, (card_id,))
        for i in range(1, 3):
            cursor.execute("""
            INSERT INTO household_members (beneficiary_card_id, member_id, name, relationship, is_eligible)
            VALUES (?, ?, ?, 'Family', 1);
            """, (card_id, f"M-{i:02d}", f"Member {i}"))
        conn.commit()

        ent = ai_request_advisor.get_beneficiary_entitlement(conn, card_id, "Both")
        assert ent["eligible_members_count"] == 2
        assert ent["statutory_entitlement_rice_kg"] == 8.0
        assert ent["statutory_entitlement_wheat_kg"] == 2.0
        assert ent["statutory_entitlement_commodity_kg"] == 10.0

def test_household_entitlement_4_members():
    """4 eligible members -> 16 kg Rice, 4 kg Wheat."""
    with get_db_connection() as conn:
        cursor = conn.cursor()
        card_id = "TEST-PHH-04"
        cursor.execute("DELETE FROM household_members WHERE beneficiary_card_id = ?;", (card_id,))
        cursor.execute("DELETE FROM beneficiaries WHERE pseudonymous_beneficiary_id = ?;", (card_id,))
        cursor.execute("""
        INSERT INTO beneficiaries (pseudonymous_beneficiary_id, name_for_demo, registered_fps_id, scheme_type, members_count)
        VALUES (?, 'Four Members', 'FPS-KA-BLR-001', 'PHH', 4);
        """, (card_id,))
        for i in range(1, 5):
            cursor.execute("""
            INSERT INTO household_members (beneficiary_card_id, member_id, name, relationship, is_eligible)
            VALUES (?, ?, ?, 'Family', 1);
            """, (card_id, f"M-{i:02d}", f"Member {i}"))
        conn.commit()

        ent = ai_request_advisor.get_beneficiary_entitlement(conn, card_id, "Both")
        assert ent["eligible_members_count"] == 4
        assert ent["statutory_entitlement_rice_kg"] == 16.0
        assert ent["statutory_entitlement_wheat_kg"] == 4.0
        assert ent["statutory_entitlement_commodity_kg"] == 20.0

def test_household_entitlement_5_members():
    """5 eligible members -> 20 kg Rice, 5 kg Wheat."""
    with get_db_connection() as conn:
        cursor = conn.cursor()
        card_id = "TEST-PHH-05"
        cursor.execute("DELETE FROM household_members WHERE beneficiary_card_id = ?;", (card_id,))
        cursor.execute("DELETE FROM beneficiaries WHERE pseudonymous_beneficiary_id = ?;", (card_id,))
        cursor.execute("""
        INSERT INTO beneficiaries (pseudonymous_beneficiary_id, name_for_demo, registered_fps_id, scheme_type, members_count)
        VALUES (?, 'Five Members', 'FPS-KA-BLR-001', 'PHH', 5);
        """, (card_id,))
        for i in range(1, 6):
            cursor.execute("""
            INSERT INTO household_members (beneficiary_card_id, member_id, name, relationship, is_eligible)
            VALUES (?, ?, ?, 'Family', 1);
            """, (card_id, f"M-{i:02d}", f"Member {i}"))
        conn.commit()

        ent = ai_request_advisor.get_beneficiary_entitlement(conn, card_id, "Both")
        assert ent["eligible_members_count"] == 5
        assert ent["statutory_entitlement_rice_kg"] == 20.0
        assert ent["statutory_entitlement_wheat_kg"] == 5.0
        assert ent["statutory_entitlement_commodity_kg"] == 25.0

def test_ineligible_members_excluded():
    """Household with 5 members total, but 1 member marked is_eligible = 0 -> only 4 eligible (16 kg Rice, 4 kg Wheat)."""
    with get_db_connection() as conn:
        cursor = conn.cursor()
        card_id = "TEST-PHH-INELIGIBLE"
        cursor.execute("DELETE FROM household_members WHERE beneficiary_card_id = ?;", (card_id,))
        cursor.execute("DELETE FROM beneficiaries WHERE pseudonymous_beneficiary_id = ?;", (card_id,))
        cursor.execute("""
        INSERT INTO beneficiaries (pseudonymous_beneficiary_id, name_for_demo, registered_fps_id, scheme_type, members_count)
        VALUES (?, 'Mixed Eligibility', 'FPS-KA-BLR-001', 'PHH', 5);
        """, (card_id,))
        # 4 eligible members
        for i in range(1, 5):
            cursor.execute("""
            INSERT INTO household_members (beneficiary_card_id, member_id, name, relationship, is_eligible)
            VALUES (?, ?, ?, 'Eligible Member', 1);
            """, (card_id, f"M-{i:02d}", f"Eligible {i}"))
        # 1 ineligible member (e.g. unverified/duplicate Aadhaar)
        cursor.execute("""
        INSERT INTO household_members (beneficiary_card_id, member_id, name, relationship, is_eligible)
        VALUES (?, 'M-05', 'Ineligible Member', 'Other', 0);
        """, (card_id,))
        conn.commit()

        ent = ai_request_advisor.get_beneficiary_entitlement(conn, card_id, "Both")
        assert ent["family_members_count"] == 5
        assert ent["eligible_members_count"] == 4
        assert ent["statutory_entitlement_rice_kg"] == 16.0
        assert ent["statutory_entitlement_wheat_kg"] == 4.0
        assert ent["statutory_entitlement_commodity_kg"] == 20.0

def test_aay_scheme_preserves_statutory_quota():
    """AAY households receive statutory 35 kg quota (25 kg Rice + 10 kg Wheat) regardless of family size."""
    with get_db_connection() as conn:
        cursor = conn.cursor()
        card_id = "TEST-AAY-CARD"
        cursor.execute("DELETE FROM household_members WHERE beneficiary_card_id = ?;", (card_id,))
        cursor.execute("DELETE FROM beneficiaries WHERE pseudonymous_beneficiary_id = ?;", (card_id,))
        cursor.execute("""
        INSERT INTO beneficiaries (pseudonymous_beneficiary_id, name_for_demo, registered_fps_id, scheme_type, members_count, monthly_rice_kg, monthly_wheat_kg)
        VALUES (?, 'AAY Household', 'FPS-KA-BLR-001', 'AAY', 2, 25.0, 10.0);
        """, (card_id,))
        cursor.execute("""
        INSERT INTO household_members (beneficiary_card_id, member_id, name, relationship, is_eligible)
        VALUES (?, 'M-01', 'AAY Head', 'Head of Household', 1);
        """, (card_id,))
        cursor.execute("""
        INSERT INTO household_members (beneficiary_card_id, member_id, name, relationship, is_eligible)
        VALUES (?, 'M-02', 'AAY Spouse', 'Spouse', 1);
        """, (card_id,))
        conn.commit()

        ent = ai_request_advisor.get_beneficiary_entitlement(conn, card_id, "Both")
        assert ent["card_type"] == "AAY"
        assert ent["statutory_entitlement_rice_kg"] == 25.0
        assert ent["statutory_entitlement_wheat_kg"] == 10.0
        assert ent["statutory_entitlement_commodity_kg"] == 35.0

@pytest.mark.asyncio
async def test_statutory_validation_rejects_excess_demand():
    """Citizen cannot request quantities exceeding statutory entitlement ceiling."""
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        # Submit 100 kg for a beneficiary with 16 kg quota -> Must be rejected with 422
        bad_payload = {
            "beneficiary_id": "BEN-KA-0001",
            "intended_fps_id": "FPS-KA-BLR-001",
            "commodity": "Rice",
            "declared_quantity_kg": 100.0,
            "cycle_id": "2026-09"
        }
        res = await client.post("/api/intent", json=bad_payload)
        assert res.status_code == 422
        assert "exceeds" in res.json()["detail"].lower() or "statutory" in res.json()["detail"].lower()

def test_scarcity_fair_share_logic_unaffected():
    """Scarcity calculation and statutory floors function as designed."""
    with get_db_connection() as conn:
        cursor = conn.cursor()
        floor = scarcity_allocation_engine.calculate_statutory_floor(cursor, "FPS-KA-BLR-001", "Rice")
        assert "statutory_floor_kg" in floor
        assert floor["statutory_floor_kg"] > 0
        assert floor["statutory_requirement_kg"] > 0
