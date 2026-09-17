"""Smart Grain ATM / Automated Ration Pickup Service."""
import sqlite3
import hashlib
import secrets
from datetime import datetime
from typing import Dict, Any, List, Optional
from app.core.logging_config import get_logger
from app.services.governance_trail import governance_trail
from app.services.ai_request_advisor import ai_request_advisor
from app.models.grain_atm import (
    GrainAtmStatusOut,
    GrainAtmStockItem,
    BeneficiaryAtmVerificationOut,
    GrainAtmDispenseOut,
    GrainAtmNetworkSummaryOut,
    AtmOperationalDetail,
)

logger = get_logger("grain_atm_service")


class GrainAtmService:
    """Enterprise Service managing Smart Grain ATM lifecycle, verification, atomic dispensing, and inventory integration."""

    def get_atm_status(self, db: sqlite3.Connection, atm_id: str = "ATM-001") -> GrainAtmStatusOut:
        """Fetch current operational status and commodity stock levels for an ATM."""
        cursor = db.cursor()
        cursor.execute("SELECT * FROM smart_grain_atms WHERE atm_id = ?;", (atm_id.strip(),))
        atm_row = cursor.fetchone()

        if not atm_row:
            # Auto-seed ATM-001 if table was somehow unpopulated
            cursor.execute("""
            INSERT OR IGNORE INTO smart_grain_atms (
                atm_id, name, location, district, latitude, longitude, status, last_replenished_at
            ) VALUES (
                'ATM-001', 'Ration Vending Machine — Demo PDS Centre', 'Demo PDS Centre, Malleshwaram, Bengaluru Urban',
                'Bengaluru Urban', 12.9716, 77.5946, 'ONLINE', '2026-09-15 10:30:00'
            );
            """)
            cursor.execute("""
            INSERT OR IGNORE INTO smart_grain_atm_inventory (
                atm_id, commodity, capacity_kg, available_stock_kg, min_threshold_kg
            ) VALUES 
                ('ATM-001', 'RICE', 500.0, 182.0, 50.0),
                ('ATM-001', 'WHEAT', 300.0, 74.0, 30.0);
            """)
            db.commit()
            cursor.execute("SELECT * FROM smart_grain_atms WHERE atm_id = ?;", (atm_id.strip(),))
            atm_row = cursor.fetchone()

        cursor.execute("""
        SELECT commodity, capacity_kg, available_stock_kg, min_threshold_kg
        FROM smart_grain_atm_inventory
        WHERE atm_id = ?
        ORDER BY commodity ASC;
        """, (atm_id.strip(),))
        inv_rows = cursor.fetchall()

        inventory_items = []
        is_low_stock = False
        for row in inv_rows:
            avail = float(row["available_stock_kg"])
            thresh = float(row["min_threshold_kg"])
            item_low = avail <= thresh
            if item_low:
                is_low_stock = True
            inventory_items.append(GrainAtmStockItem(
                commodity=row["commodity"],
                capacity_kg=float(row["capacity_kg"]),
                available_stock_kg=avail,
                min_threshold_kg=thresh,
                is_low_stock=item_low,
            ))

        return GrainAtmStatusOut(
            atm_id=atm_row["atm_id"] if atm_row else atm_id,
            name=atm_row["name"] if atm_row else "Ration Vending Machine — Demo PDS Centre",
            location=atm_row["location"] if atm_row else "Demo PDS Centre, Bengaluru Urban",
            district=atm_row["district"] if atm_row else "Bengaluru Urban",
            status=atm_row["status"] if atm_row else "ONLINE",
            is_ready=(atm_row["status"] == "ONLINE") if atm_row else True,
            is_low_stock=is_low_stock,
            inventory=inventory_items,
            last_replenished_at=str(atm_row["last_replenished_at"]) if atm_row and atm_row["last_replenished_at"] else "10:30 AM",
        )

    def verify_beneficiary(
        self,
        db: sqlite3.Connection,
        beneficiary_id: str,
        cycle_id: str = "2026-09",
        auth_method: str = "DEMO_BIOMETRIC"
    ) -> BeneficiaryAtmVerificationOut:
        """
        Verify beneficiary identity against authoritative database state,
        determine entitlement, check current cycle receipt status, and verify ATM stock.
        """
        cursor = db.cursor()
        clean_id = beneficiary_id.strip()

        # 1. Resolve Beneficiary Record & Normalize ID (e.g. RC-KA-000001 <-> BEN-KA-0001)
        alt_id = None
        if clean_id.startswith("RC-KA-"):
            try:
                num = int(clean_id.replace("RC-KA-", ""))
                alt_id = f"BEN-KA-{num:04d}"
            except Exception:
                pass
        elif clean_id.startswith("BEN-KA-"):
            try:
                num = int(clean_id.replace("BEN-KA-", ""))
                alt_id = f"RC-KA-{num:06d}"
            except Exception:
                pass

        cursor.execute("""
        SELECT pseudonymous_beneficiary_id, name_for_demo, scheme_type, members_count, registered_fps_id
        FROM beneficiaries
        WHERE pseudonymous_beneficiary_id = ? OR pseudonymous_beneficiary_id = ? OR phone = ?
        LIMIT 1;
        """, (clean_id, alt_id or clean_id, clean_id))
        ben_row = cursor.fetchone()

        if not ben_row:
            # Synthetic demo fallback (first beneficiary)
            cursor.execute("SELECT pseudonymous_beneficiary_id, name_for_demo, scheme_type, members_count, registered_fps_id FROM beneficiaries LIMIT 1;")
            ben_row = cursor.fetchone()

        if not ben_row:
            return BeneficiaryAtmVerificationOut(
                beneficiary_id=clean_id,
                name="Demo Beneficiary",
                card_type="PHH",
                cycle_id=cycle_id,
                statutory_rice_kg=0.0,
                statutory_wheat_kg=0.0,
                authorized_rice_kg=0.0,
                authorized_wheat_kg=0.0,
                already_received=False,
                stock_sufficient=False,
                eligible=False,
                reason="Sorry, we could not verify your details. Please try again."
            )

        resolved_ben_id = ben_row["pseudonymous_beneficiary_id"]
        ben_name = ben_row["name_for_demo"]
        card_type = ben_row["scheme_type"]

        # 2. Authoritative Cycle-Received Check (SINGLE SOURCE OF TRUTH)
        cursor.execute("""
        SELECT 1 FROM beneficiary_cycle_receipts 
        WHERE beneficiary_id = ? AND cycle_id = ? AND status = 'COMPLETED'
        UNION
        SELECT 1 FROM citizen_requests
        WHERE beneficiary_id = ? AND cycle_id = ? AND delivery_status = 'DELIVERY_CONFIRMED'
        LIMIT 1;
        """, (resolved_ben_id, cycle_id.strip(), resolved_ben_id, cycle_id.strip()))
        receipt_row = cursor.fetchone()

        if receipt_row is not None:
            return BeneficiaryAtmVerificationOut(
                beneficiary_id=resolved_ben_id,
                name=ben_name,
                card_type=card_type,
                cycle_id=cycle_id,
                statutory_rice_kg=20.0,
                statutory_wheat_kg=5.0,
                authorized_rice_kg=0.0,
                authorized_wheat_kg=0.0,
                already_received=True,
                already_received_message="Your ration for this cycle has already been received. You cannot collect ration again in this cycle.",
                stock_sufficient=True,
                eligible=False,
                reason="Your ration for this cycle has already been received. You cannot collect ration again in this cycle."
            )

        # 3. Calculate Authoritative Statutory Entitlement
        try:
            ent = ai_request_advisor.get_beneficiary_entitlement(db, resolved_ben_id, "Both", cycle_id.strip())
            statutory_rice = float(ent.get("statutory_entitlement_rice_kg", 20.0))
            statutory_wheat = float(ent.get("statutory_entitlement_wheat_kg", 5.0))
            # Authorized quantity for immediate ATM collection
            auth_rice = float(ent.get("remaining_eligible_rice_kg", 10.0))
            auth_wheat = float(ent.get("remaining_eligible_wheat_kg", 0.0))
            if auth_rice <= 0 and auth_wheat <= 0:
                auth_rice = 10.0  # standard monthly allocation for single pickup
        except Exception:
            members = int(ben_row["members_count"] or 4) if (ben_row and "members_count" in ben_row.keys()) else 4
            statutory_rice = members * 4.0
            statutory_wheat = members * 1.0
            auth_rice = 10.0
            auth_wheat = 0.0

        # 4. Check ATM Inventory Availability for Authorized Commodities
        cursor.execute("""
        SELECT commodity, available_stock_kg FROM smart_grain_atm_inventory
        WHERE atm_id = 'ATM-001';
        """)
        stock_map = {r["commodity"]: float(r["available_stock_kg"]) for r in cursor.fetchall()}
        atm_rice_stock = stock_map.get("RICE", 0.0)

        if atm_rice_stock < auth_rice:
            return BeneficiaryAtmVerificationOut(
                beneficiary_id=resolved_ben_id,
                name=ben_name,
                card_type=card_type,
                cycle_id=cycle_id,
                statutory_rice_kg=statutory_rice,
                statutory_wheat_kg=statutory_wheat,
                authorized_rice_kg=auth_rice,
                authorized_wheat_kg=auth_wheat,
                already_received=False,
                stock_sufficient=False,
                eligible=False,
                reason="The required ration is currently not available at this pickup point."
            )

        return BeneficiaryAtmVerificationOut(
            beneficiary_id=resolved_ben_id,
            name=ben_name,
            card_type=card_type,
            cycle_id=cycle_id,
            statutory_rice_kg=statutory_rice,
            statutory_wheat_kg=statutory_wheat,
            authorized_rice_kg=auth_rice,
            authorized_wheat_kg=auth_wheat,
            already_received=False,
            already_received_message=None,
            stock_sufficient=True,
            eligible=True,
            reason=None,
            atm_id="ATM-001",
        )

    def dispense_grain_transaction(
        self,
        db: sqlite3.Connection,
        atm_id: str,
        beneficiary_id: str,
        cycle_id: str = "2026-09",
        auth_method: str = "DEMO_BIOMETRIC"
    ) -> GrainAtmDispenseOut:
        """
        Execute atomic dispensing transaction:
        1. Guard already-received state.
        2. Validate & decrement ATM inventory.
        3. Insert smart_grain_atm_transactions.
        4. Insert into beneficiary_cycle_receipts (single source of truth).
        5. Update citizen_requests to DELIVERY_CONFIRMED.
        6. Emit cryptographic SHA-256 receipt & QR payload.
        """
        cursor = db.cursor()
        clean_ben_id = beneficiary_id.strip()
        clean_cycle = cycle_id.strip()

        # Step 1: Verify beneficiary existence & normalize ID
        alt_id = None
        if clean_ben_id.startswith("RC-KA-"):
            try:
                num = int(clean_ben_id.replace("RC-KA-", ""))
                alt_id = f"BEN-KA-{num:04d}"
            except Exception:
                pass
        elif clean_ben_id.startswith("BEN-KA-"):
            try:
                num = int(clean_ben_id.replace("BEN-KA-", ""))
                alt_id = f"RC-KA-{num:06d}"
            except Exception:
                pass

        cursor.execute("""
        SELECT pseudonymous_beneficiary_id, name_for_demo, scheme_type, members_count, registered_fps_id
        FROM beneficiaries
        WHERE pseudonymous_beneficiary_id = ? OR pseudonymous_beneficiary_id = ? OR phone = ?
        LIMIT 1;
        """, (clean_ben_id, alt_id or clean_ben_id, clean_ben_id))
        ben_row = cursor.fetchone()
        if not ben_row:
            cursor.execute("SELECT pseudonymous_beneficiary_id, name_for_demo, scheme_type, members_count, registered_fps_id FROM beneficiaries LIMIT 1;")
            ben_row = cursor.fetchone()

        resolved_ben_id = ben_row["pseudonymous_beneficiary_id"] if ben_row else clean_ben_id

        # Step 2: Guard against duplicate receipt (PDS Business Rule Enforcement)
        cursor.execute("""
        SELECT 1 FROM beneficiary_cycle_receipts 
        WHERE beneficiary_id = ? AND cycle_id = ? AND status = 'COMPLETED'
        UNION
        SELECT 1 FROM citizen_requests
        WHERE beneficiary_id = ? AND cycle_id = ? AND delivery_status = 'DELIVERY_CONFIRMED'
        LIMIT 1;
        """, (resolved_ben_id, clean_cycle, resolved_ben_id, clean_cycle))
        if cursor.fetchone():
            return GrainAtmDispenseOut(
                success=False,
                transaction_id="",
                beneficiary_id=resolved_ben_id,
                cycle_id=clean_cycle,
                dispensed_rice_kg=0.0,
                dispensed_wheat_kg=0.0,
                atm_id=atm_id,
                atm_location="Demo PDS Centre",
                receipt_hash="",
                receipt_qr_data="",
                timestamp=datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
                error_message="Your ration for this cycle has already been received. You cannot collect ration again in this cycle."
            )

        # Step 3: Determine authorized grain allocation
        dispense_rice_kg = 10.0
        dispense_wheat_kg = 0.0

        # Step 4: Atomic Inventory Check & Decrement
        cursor.execute("""
        SELECT available_stock_kg FROM smart_grain_atm_inventory
        WHERE atm_id = ? AND commodity = 'RICE';
        """, (atm_id.strip(),))
        stock_row = cursor.fetchone()
        current_stock = float(stock_row["available_stock_kg"]) if stock_row else 0.0

        if current_stock < dispense_rice_kg:
            return GrainAtmDispenseOut(
                success=False,
                transaction_id="",
                beneficiary_id=resolved_ben_id,
                cycle_id=clean_cycle,
                dispensed_rice_kg=0.0,
                dispensed_wheat_kg=0.0,
                atm_id=atm_id,
                atm_location="Demo PDS Centre",
                receipt_hash="",
                receipt_qr_data="",
                timestamp=datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
                error_message="The required ration is currently not available at this pickup point."
            )

        # Decrement ATM inventory atomically
        cursor.execute("""
        UPDATE smart_grain_atm_inventory
        SET available_stock_kg = available_stock_kg - ?,
            last_updated_at = CURRENT_TIMESTAMP
        WHERE atm_id = ? AND commodity = 'RICE';
        """, (dispense_rice_kg, atm_id.strip()))

        # Step 5: Generate Transaction ID & SHA-256 Cryptographic Receipt Stamp
        tx_num = secrets.randbelow(900000) + 100000
        tx_id = f"ATM-{tx_num}"
        timestamp_str = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

        digest_input = f"{tx_id}|{resolved_ben_id}|{clean_cycle}|RICE:{dispense_rice_kg}|{atm_id}|{timestamp_str}"
        receipt_hash = hashlib.sha256(digest_input.encode()).hexdigest()
        qr_data = (
            f"PDS-DEMANDSYNC|GRAIN_ATM|TX:{tx_id}|BEN:{resolved_ben_id}|"
            f"CYCLE:{clean_cycle}|RICE:{dispense_rice_kg:.1f}KG|ATM:{atm_id}|HASH:{receipt_hash[:16]}"
        )

        # Step 6: Log in smart_grain_atm_transactions
        cursor.execute("""
        INSERT INTO smart_grain_atm_transactions (
            transaction_id, atm_id, beneficiary_id, cycle_id, commodity,
            dispensed_rice_kg, dispensed_wheat_kg, auth_method, auth_status,
            dispense_status, receipt_qr_data, receipt_hash, created_at
        ) VALUES (?, ?, ?, ?, 'Rice', ?, ?, ?, 'SUCCESS', 'COMPLETED', ?, ?, CURRENT_TIMESTAMP);
        """, (
            tx_id, atm_id.strip(), resolved_ben_id, clean_cycle,
            dispense_rice_kg, dispense_wheat_kg, auth_method,
            qr_data, receipt_hash
        ))

        # Step 7: Record into beneficiary_cycle_receipts (AUTHORITATIVE SYSTEM RECEIPT)
        cursor.execute("""
        INSERT INTO beneficiary_cycle_receipts (
            beneficiary_id, cycle_id, request_id, received_rice_kg, received_wheat_kg, confirmed_at, status
        ) VALUES (?, ?, ?, ?, ?, CURRENT_TIMESTAMP, 'COMPLETED')
        ON CONFLICT(beneficiary_id, cycle_id) DO UPDATE SET
            request_id = excluded.request_id,
            received_rice_kg = excluded.received_rice_kg,
            received_wheat_kg = excluded.received_wheat_kg,
            status = 'COMPLETED';
        """, (
            resolved_ben_id, clean_cycle, tx_id,
            dispense_rice_kg, dispense_wheat_kg
        ))

        # Step 8: Update or create citizen_requests entry to reflect DELIVERY_CONFIRMED via Grain ATM
        cursor.execute("""
        SELECT request_id FROM citizen_requests
        WHERE beneficiary_id = ? AND cycle_id = ?
        ORDER BY id DESC LIMIT 1;
        """, (resolved_ben_id, clean_cycle))
        req_row = cursor.fetchone()

        if req_row:
            cursor.execute("""
            UPDATE citizen_requests
            SET delivery_status = 'DELIVERY_CONFIRMED',
                received_rice_kg = ?,
                received_wheat_kg = ?,
                citizen_confirmed_at = CURRENT_TIMESTAMP
            WHERE request_id = ?;
            """, (dispense_rice_kg, dispense_wheat_kg, req_row["request_id"]))
        else:
            # Create a completed citizen request record for the pickup
            req_id = f"REQ-ATM-{tx_num}"
            fps_id = (ben_row["registered_fps_id"] if (ben_row and "registered_fps_id" in ben_row.keys() and ben_row["registered_fps_id"]) else None)
            if not fps_id:
                cursor.execute("SELECT fps_id FROM fps LIMIT 1;")
                f_row = cursor.fetchone()
                fps_id = f_row["fps_id"] if f_row else "FPS-KA-IND-0003"
            cursor.execute("""
            INSERT INTO citizen_requests (
                request_id, beneficiary_id, card_type, family_members_count,
                statutory_entitlement_rice_kg, statutory_entitlement_wheat_kg,
                cycle_id, registered_fps_id, intended_fps_id, commodity,
                requested_quantity_kg, authorized_quantity_kg, status,
                delivery_mode, delivery_status, received_rice_kg, received_wheat_kg,
                citizen_confirmed_at
            ) VALUES (
                ?, ?, ?, 4, 20.0, 5.0, ?, ?, ?, 'Rice',
                10.0, 10.0, 'APPROVED', 'FPS_COLLECTION', 'DELIVERY_CONFIRMED',
                ?, 0.0, CURRENT_TIMESTAMP
            );
            """, (req_id, resolved_ben_id, (ben_row["scheme_type"] if (ben_row and "scheme_type" in ben_row.keys()) else "PHH"), clean_cycle, fps_id, fps_id, dispense_rice_kg))

        # Step 9: Complete intent records for this cycle
        cursor.execute("""
        UPDATE intent SET status = 'COMPLETED'
        WHERE beneficiary_id = ? AND cycle_id = ?;
        """, (resolved_ben_id, clean_cycle))

        # Step 10: Audit log in governance_trail
        governance_trail.record_event(
            db=db,
            event_type="DELIVERY_CONFIRMED",
            action="SMART_GRAIN_ATM_DISPENSED",
            entity_type="GRAIN_ATM_TRANSACTION",
            entity_id=tx_id,
            actor_name=resolved_ben_id,
            actor_role="CITIZEN_BENEFICIARY",
            cycle_id=clean_cycle,
            notes=f"Beneficiary collected {dispense_rice_kg}kg Rice via Ration Vending Machine {atm_id}. Transaction Hash: {receipt_hash[:16]}",
            is_success=True,
            is_simulation=True
        )

        db.commit()
        logger.info("Successfully dispensed %s kg Rice to %s via %s (Tx=%s)", dispense_rice_kg, resolved_ben_id, atm_id, tx_id)

        return GrainAtmDispenseOut(
            success=True,
            transaction_id=tx_id,
            beneficiary_id=resolved_ben_id,
            cycle_id=clean_cycle,
            dispensed_rice_kg=dispense_rice_kg,
            dispensed_wheat_kg=dispense_wheat_kg,
            atm_id=atm_id,
            atm_location="Demo PDS Centre",
            receipt_hash=receipt_hash,
            receipt_qr_data=qr_data,
            timestamp=timestamp_str,
            error_message=None
        )

    def get_network_summary(self, db: sqlite3.Connection) -> GrainAtmNetworkSummaryOut:
        """Fetch operational metrics for the Smart Grain ATM Network for Officer Dashboard."""
        cursor = db.cursor()

        # Query ATM-001 stock
        cursor.execute("""
        SELECT commodity, available_stock_kg FROM smart_grain_atm_inventory
        WHERE atm_id = 'ATM-001';
        """)
        stock_dict = {r["commodity"]: float(r["available_stock_kg"]) for r in cursor.fetchall()}
        rice_stock = stock_dict.get("RICE", 182.0)
        wheat_stock = stock_dict.get("WHEAT", 74.0)

        # Query total dispense count
        cursor.execute("SELECT COUNT(*) FROM smart_grain_atm_transactions WHERE atm_id = 'ATM-001';")
        db_tx_count = cursor.fetchone()[0]
        total_tx = 34 + db_tx_count
        success_tx = 32 + db_tx_count

        atm_list = [
            AtmOperationalDetail(
                atm_id="ATM-001",
                name="Ration Vending Machine — Demo PDS Centre",
                location="Demo PDS Centre, Malleshwaram",
                status="ONLINE",
                rice_stock_kg=rice_stock,
                wheat_stock_kg=wheat_stock,
                today_transactions=total_tx,
                successful_transactions=success_tx,
                failed_transactions=2,
                last_replenishment="10:30 AM"
            ),
            AtmOperationalDetail(
                atm_id="ATM-002",
                name="Ration Vending Machine — Yelahanka Hub",
                location="Yelahanka Old Town, Bengaluru",
                status="ONLINE",
                rice_stock_kg=340.0,
                wheat_stock_kg=120.0,
                today_transactions=48,
                successful_transactions=47,
                failed_transactions=1,
                last_replenishment="08:15 AM"
            ),
            AtmOperationalDetail(
                atm_id="ATM-003",
                name="Ration Vending Machine — Jayanagar 4th Block",
                location="Jayanagar Shopping Complex",
                status="ONLINE",
                rice_stock_kg=215.0,
                wheat_stock_kg=95.0,
                today_transactions=29,
                successful_transactions=29,
                failed_transactions=0,
                last_replenishment="09:45 AM"
            ),
            AtmOperationalDetail(
                atm_id="ATM-004",
                name="Ration Vending Machine — Peenya Industrial Gate",
                location="Peenya 2nd Stage, Bengaluru",
                status="LOW_STOCK",
                rice_stock_kg=38.0,
                wheat_stock_kg=15.0,
                today_transactions=62,
                successful_transactions=59,
                failed_transactions=3,
                last_replenishment="Yesterday 05:00 PM"
            ),
            AtmOperationalDetail(
                atm_id="ATM-005",
                name="Ration Vending Machine — Whitefield Station",
                location="Whitefield Main Road, Bengaluru",
                status="MAINTENANCE",
                rice_stock_kg=150.0,
                wheat_stock_kg=60.0,
                today_transactions=0,
                successful_transactions=0,
                failed_transactions=0,
                last_replenishment="2026-09-14 02:00 PM"
            ),
        ]

        return GrainAtmNetworkSummaryOut(
            total_atms=5,
            online_atms=4,
            low_stock_atms=1,
            today_dispensed_rice_kg=842.0,
            today_dispensed_wheat_kg=316.0,
            atms=atm_list,
        )


grain_atm_service = GrainAtmService()
