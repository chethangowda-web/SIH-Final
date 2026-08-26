"""Pre-Dispatch Multi-Channel Alert & Readiness Notification Engine.

Simulates Proactive Multi-Channel Notifications:
1. WhatsApp Pre-Dispatch Alerts (Rich templates with Gatepass ID & ETA)
2. SMS Broadcasts (Essential delivery summary & collection token)
3. IVR Voice Call Fallback (Simulated automated voice prompt)

Target Audience:
- FPS Dealers (Truck arrival ETA, Gatepass ID, Unloading readiness, Driver contact)
- Beneficiaries / Citizens (Stock arrival confirmation, Portability lifting approval, Token slot)

Includes simulated NotificationService abstraction for WhatsApp, SMS, and IVR.
"""

import sqlite3
import random
from datetime import datetime
from typing import List, Dict, Any, Optional
from app.core.config import settings

DEMO_NOTICE = "DEMO DATA — NOT GOVERNMENT DATA (SIMULATED PRE-DISPATCH ALERTS)"


class NotificationService:
    """Notification Service Abstraction for WhatsApp, SMS, and IVR Channels."""

    def send_whatsapp(self, recipient_phone: str, recipient_name: str, message: str, ref_id: str = "") -> Dict[str, Any]:
        """Simulate WhatsApp delivery with instant read receipt."""
        return {
            "channel": "WHATSAPP",
            "recipient_phone": recipient_phone,
            "recipient_name": recipient_name,
            "status": "DELIVERED",
            "message_id": f"WA-MSG-{random.randint(100000, 999999)}",
            "delivered_at": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
            "read_receipt": True
        }

    def send_sms(self, recipient_phone: str, recipient_name: str, message: str, ref_id: str = "") -> Dict[str, Any]:
        """Simulate statutory SMS telecom gateway delivery."""
        return {
            "channel": "SMS",
            "recipient_phone": recipient_phone,
            "recipient_name": recipient_name,
            "status": "DELIVERED",
            "message_id": f"SMS-GW-{random.randint(100000, 999999)}",
            "delivered_at": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
            "telecom_circle": "KARNATAKA_DO_TRAI"
        }

    def send_ivr(self, recipient_phone: str, recipient_name: str, message: str, ref_id: str = "") -> Dict[str, Any]:
        """Simulate automated IVR voice call prompt with fallback behavior."""
        # 80% answered, 20% fallback
        outcome = "DELIVERED" if random.random() > 0.20 else "FALLBACK_TRIGGERED"
        return {
            "channel": "IVR",
            "recipient_phone": recipient_phone,
            "recipient_name": recipient_name,
            "status": outcome,
            "call_id": f"IVR-CALL-{random.randint(100000, 999999)}",
            "duration_secs": 42 if outcome == "DELIVERED" else 0,
            "delivered_at": datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        }


class NotificationEngine:
    """Core Service for Generating and Managing Pre-Dispatch Multi-Channel Alerts."""

    def __init__(self):
        self.service = NotificationService()

    def dispatch_pre_dispatch_alerts(
        self,
        db: sqlite3.Connection,
        cycle_id: str = settings.CURRENT_CYCLE,
        truck_id: Optional[str] = None
    ) -> Dict[str, Any]:
        """
        Generate and persist simulated WhatsApp, SMS, and IVR alerts for FPS dealers and beneficiary household groups.
        """
        cursor = db.cursor()

        # 1. Fetch dispatch allocations by FPS
        query = """
        SELECT d.fps_id, p.name as fps_name, d.demo_truck_id,
               COALESCE(SUM(d.quantity_kg), 0.0) as total_dispatch_kg,
               COALESCE(SUM(CASE WHEN d.commodity='Rice' THEN d.quantity_kg ELSE 0 END), 0.0) as rice_kg,
               COALESCE(SUM(CASE WHEN d.commodity='Wheat' THEN d.quantity_kg ELSE 0 END), 0.0) as wheat_kg,
               v.driver_name, v.driver_phone
        FROM dispatch d
        JOIN fps p ON d.fps_id = p.fps_id
        LEFT JOIN vehicles v ON d.demo_truck_id = v.truck_id
        WHERE d.cycle_id = ?
        """
        params = [cycle_id]
        if truck_id:
            query += " AND d.demo_truck_id = ?"
            params.append(truck_id)
        query += " GROUP BY d.fps_id;"

        cursor.execute(query, tuple(params))
        fps_allocations = cursor.fetchall()

        if not fps_allocations:
            # Fallback to baseline FPS list
            cursor.execute("SELECT fps_id, name as fps_name FROM fps;")
            fps_allocations = [
                {"fps_id": r["fps_id"], "fps_name": r["fps_name"], "demo_truck_id": truck_id or "DEMO-KA-04-E-1021",
                 "total_dispatch_kg": 3120.0, "rice_kg": 2000.0, "wheat_kg": 1120.0,
                 "driver_name": "Ramesh Kumar", "driver_phone": "+91-9876543210"}
                for r in cursor.fetchall()
            ]

        notifications_created = 0
        dealer_alerts = []
        citizen_alerts = []

        # 2. Generate FPS Dealer Alerts (WhatsApp & SMS)
        for idx, raw_alloc in enumerate(fps_allocations):
            alloc = dict(raw_alloc)
            fid = alloc["fps_id"]
            fname = alloc["fps_name"]
            carrier = alloc.get("demo_truck_id") or "DEMO-KA-04-E-1021"
            total_kg = float(alloc.get("total_dispatch_kg", 0.0))
            rice_kg = float(alloc.get("rice_kg", 0.0))
            wheat_kg = float(alloc.get("wheat_kg", 0.0))
            driver_name = alloc.get("driver_name") or "Ramesh Kumar (Demo Driver)"
            driver_phone = alloc.get("driver_phone") or "+91-9876543210"

            dealer_id = f"DLR-{fid[-3:]}"
            dealer_phone = f"+91-9845{idx+10:02d}{idx+30:04d}"
            dealer_name = f"Dealer In-Charge ({fname.split('(')[0].strip()})"

            eta_time = f"{8 + (idx % 3):02d}:30–{9 + (idx % 3):02d}:15 AM"

            # Realistic Dispatch Readiness Message Content
            wa_title = f"PDS Dispatch Readiness Alert — Cycle {cycle_id}"
            wa_body = (
                f"PDS Dispatch Readiness Alert:\n"
                f"{fid} ({fname.split('(')[0].strip()}) allocation of {total_kg:.0f} kg "
                f"(Rice: {rice_kg:.0f} kg, Wheat: {wheat_kg:.0f} kg) has been dispatched via Carrier {carrier}.\n"
                f"Expected arrival: {eta_time}.\n"
                f"Driver: {driver_name} ({driver_phone}).\n"
                f"Please ensure readiness for unloading and weighment verification."
            )

            # Invoke Notification Service abstraction
            res_wa = self.service.send_whatsapp(dealer_phone, dealer_name, wa_body, ref_id=fid)

            cursor.execute("""
            INSERT INTO notifications (
                cycle_id, recipient_type, recipient_id, recipient_name, recipient_phone,
                fps_id, channel, message_title, message_body, status, sent_at, acknowledged_at
            ) VALUES (?, 'DEALER', ?, ?, ?, ?, 'WHATSAPP', ?, ?, ?, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP);
            """, (cycle_id, dealer_id, dealer_name, dealer_phone, fid, wa_title, wa_body, res_wa["status"]))

            dealer_alerts.append({
                "recipient_id": dealer_id,
                "recipient_name": dealer_name,
                "fps_id": fid,
                "channel": "WHATSAPP",
                "phone": dealer_phone,
                "eta": eta_time,
                "status": res_wa["status"],
                "title": wa_title,
                "message": wa_body
            })
            notifications_created += 1

        # 3. Generate Beneficiary Household Notification Group Alerts (SMS + IVR Fallback)
        cursor.execute("""
        SELECT b.pseudonymous_beneficiary_id, b.name_for_demo, b.registered_fps_id, b.language,
               p.name as fps_name
        FROM beneficiaries b
        JOIN fps p ON b.registered_fps_id = p.fps_id
        LIMIT 25;
        """)
        sample_bens = cursor.fetchall()

        for b in sample_bens:
            ben_id = b["pseudonymous_beneficiary_id"]
            ben_name = b["name_for_demo"]
            fid = b["registered_fps_id"]
            fname = b["fps_name"]
            phone = f"+91-9123{random.randint(100000, 999999)}"
            channel = "SMS" if random.random() > 0.35 else "IVR"

            slot_date = "01-Sep to 05-Sep (08:30 AM - 12:30 PM)"
            sms_title = f"PDS Entitlement Ready — Cycle {cycle_id}"
            sms_body = (
                f"Namaskara {ben_name},\n"
                f"Your monthly PDS foodgrain entitlement for Cycle {cycle_id} is in transit to {fname.split('(')[0].strip()}.\n"
                f"Collection Slot: {slot_date}.\n"
                f"Biometric ePoS and portability lifting active across all centers."
            )

            # Invoke Notification Service abstraction
            res_notify = self.service.send_sms(phone, ben_name, sms_body, ref_id=ben_id) if channel == "SMS" else self.service.send_ivr(phone, ben_name, sms_body, ref_id=ben_id)

            cursor.execute("""
            INSERT INTO notifications (
                cycle_id, recipient_type, recipient_id, recipient_name, recipient_phone,
                fps_id, channel, message_title, message_body, status, sent_at
            ) VALUES (?, 'BENEFICIARY', ?, ?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP);
            """, (cycle_id, ben_id, ben_name, phone, fid, channel, sms_title, sms_body, res_notify["status"]))

            citizen_alerts.append({
                "recipient_id": ben_id,
                "recipient_name": ben_name,
                "fps_id": fid,
                "channel": channel,
                "phone": phone,
                "status": res_notify["status"],
                "title": sms_title,
                "message": sms_body
            })
            notifications_created += 1

        db.commit()

        return {
            "status": "success",
            "cycle_id": cycle_id,
            "notifications_dispatched_count": notifications_created,
            "total_notifications_sent": notifications_created,
            "dealer_alerts_count": len(dealer_alerts),
            "dealer_notifications_count": len(dealer_alerts),
            "citizen_alerts_count": len(citizen_alerts),
            "citizen_notifications_count": len(citizen_alerts),
            "delivery_rate_pct": 98.4,
            "channels_used": ["WHATSAPP", "SMS", "IVR"],
            "channels_utilized": ["WHATSAPP", "SMS", "IVR"],
            "dealer_alerts": dealer_alerts,
            "citizen_alerts": citizen_alerts,
            "summary_message": f"Successfully broadcast {notifications_created} simulated multi-channel readiness alerts ({len(dealer_alerts)} FPS Dealers + {len(citizen_alerts)} Household Groups).",
            "demo_notice": DEMO_NOTICE
        }

    def fetch_notification_logs(
        self,
        db: sqlite3.Connection,
        cycle_id: str = settings.CURRENT_CYCLE,
        recipient_type: Optional[str] = None
    ) -> List[Dict[str, Any]]:
        """Fetch audit log of dispatched notifications."""
        cursor = db.cursor()
        query = "SELECT * FROM notifications WHERE cycle_id = ?"
        params = [cycle_id]
        if recipient_type:
            query += " AND recipient_type = ?"
            params.append(recipient_type.upper())
        query += " ORDER BY sent_at DESC LIMIT 100;"

        cursor.execute(query, tuple(params))
        rows = cursor.fetchall()
        if not rows:
            # Generate initial alert set
            self.dispatch_pre_dispatch_alerts(db, cycle_id)
            cursor.execute(query, tuple(params))
            rows = cursor.fetchall()

        return [dict(r) for r in rows]

    def get_notification_logs(
        self,
        db: sqlite3.Connection,
        cycle_id: str = settings.CURRENT_CYCLE,
        recipient_type: Optional[str] = None
    ) -> List[Dict[str, Any]]:
        """Alias for fetch_notification_logs."""
        return self.fetch_notification_logs(db, cycle_id=cycle_id, recipient_type=recipient_type)


notification_engine = NotificationEngine()

