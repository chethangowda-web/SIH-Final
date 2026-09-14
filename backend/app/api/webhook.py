import sqlite3
from fastapi import APIRouter, Depends, Request, Form
from fastapi.responses import PlainTextResponse
from app.core.database import get_db
import logging

logger = logging.getLogger(__name__)
router = APIRouter(tags=["Webhooks"])

@router.post("/twilio-webhook")
def twilio_webhook(
    request: Request,
    From: str = Form(...),
    Body: str = Form(...),
    db: sqlite3.Connection = Depends(get_db)
):
    """
    Twilio Webhook Endpoint for Real SMS and WhatsApp messages.
    Parses incoming texts to register intent.
    """
    cursor = db.cursor()
    raw_message = Body.strip().upper()
    
    # 1. Look up Beneficiary by Phone if available
    clean_from = From.replace("whatsapp:", "").replace("+", "").strip()
    beneficiary_id = None
    beneficiary_name = "Beneficiary"

    if clean_from:
        phone_suffix = clean_from[-10:] if len(clean_from) >= 10 else clean_from
        try:
            cursor.execute(
                "SELECT pseudonymous_beneficiary_id, name_for_demo FROM beneficiaries WHERE phone LIKE ? LIMIT 1;",
                (f"%{phone_suffix}%",)
            )
            b_row = cursor.fetchone()
            if b_row:
                beneficiary_id = b_row["pseudonymous_beneficiary_id"]
                beneficiary_name = b_row["name_for_demo"] or beneficiary_id
        except Exception:
            pass

    # 2. Parse Beneficiary Card ID from message text if explicitly provided
    for word in raw_message.split():
        if word.startswith("RC-KA-") or word.startswith("BEN-KA-"):
            beneficiary_id = word
            break
            
    if not beneficiary_id:
        beneficiary_id = "RC-KA-000001"

    cycle_id = "2026-09"

    # 3. Check if user is querying an existing collection plan (e.g. "HI", "STATUS", "PLAN", "RECEIPT")
    is_query = any(k in raw_message for k in ["HI", "HELLO", "STATUS", "PLAN", "RECEIPT", "COLLECTION", "PASS", "JOIN"]) and not ("KG" in raw_message and "FPS-" in raw_message)

    if is_query:
        try:
            cursor.execute("""
                SELECT i.id, i.cycle_id, i.commodity, i.declared_quantity_kg, i.delivery_mode, i.status,
                       COALESCE(f.name, i.intended_fps_id) as fps_name, i.intended_fps_id
                FROM intent i
                LEFT JOIN fps f ON i.intended_fps_id = f.fps_id
                WHERE i.beneficiary_id = ?
                ORDER BY i.created_at DESC LIMIT 1;
            """, (beneficiary_id,))
            plan_row = cursor.fetchone()
        except Exception:
            plan_row = None

        if plan_row:
            req_id = f"REQ-2026-09-{plan_row['id']:05d}"
            mode_str = "Doorstep Home Delivery" if plan_row.get("delivery_mode") == "HOME_DELIVERY" else "Collect at Fair Price Shop"
            reply_msg = (
                f"🌾 *PDS DemandSync • Govt of Karnataka*\n"
                f"Department of Food, Civil Supplies & Consumer Affairs\n\n"
                f"Namaskara {beneficiary_name},\n"
                f"Your PDS Advance Collection Plan is *ACTIVE & RECORDED*!\n\n"
                f"📋 *Receipt ID:* {req_id}\n"
                f"🗓️ *Cycle:* September 2026 (Cycle 7)\n"
                f"🏪 *Selected Center:* {plan_row['fps_name']} ({plan_row['intended_fps_id']})\n"
                f"📦 *Allocated Quota:* {plan_row['declared_quantity_kg']:.1f} kg {plan_row['commodity']} (₹0.00 FREE)\n"
                f"🚚 *Service Mode:* {mode_str}\n"
                f"💰 *Foodgrain Cost:* ₹0.00 (100% Subsidized)\n\n"
                f"✅ *Status:* Staged in Pre-Dispatch Demand Plan.\n"
                f"You will receive an instant arrival notification when grain arrives at your shop."
            )
            twiml_response = f"""<?xml version="1.0" encoding="UTF-8"?>
<Response>
    <Message>{reply_msg}</Message>
</Response>"""
            return PlainTextResponse(content=twiml_response, media_type="text/xml")

    # 4. Parse FPS ID
    intended_fps = "FPS-KA-BAG-0001"
    for word in raw_message.split():
        if word.startswith("FPS-"):
            intended_fps = word
            break

    # 5. Parse Commodity & Qty
    commodity = "Wheat" if "WHEAT" in raw_message else "Rice"
    qty = 20.0
    if "10KG" in raw_message:
        qty = 10.0
    elif "25KG" in raw_message:
        qty = 25.0
    elif "35KG" in raw_message:
        qty = 35.0

    # Upsert intent
    cursor.execute("""
    INSERT INTO intent (beneficiary_id, cycle_id, intended_fps_id, commodity, declared_quantity_kg, confidence, status)
    VALUES (?, ?, ?, ?, ?, 0.95, 'SUBMITTED')
    ON CONFLICT(beneficiary_id, cycle_id, commodity) DO UPDATE SET
        intended_fps_id = excluded.intended_fps_id,
        declared_quantity_kg = excluded.declared_quantity_kg,
        confidence = excluded.confidence,
        status = 'SUBMITTED';
    """, (beneficiary_id, cycle_id, intended_fps, commodity, qty))
    db.commit()

    reply_msg = (
        f"Thank you! Intent for {qty}kg {commodity} at {intended_fps} registered successfully for {beneficiary_id}.\n\n"
        f"🌾 PDS DemandSync • Govt of Karnataka\n"
        f"Collection Plan Recorded for Cycle 2026-09. Quota: {qty:.1f} kg {commodity} (₹0.00 Free). "
        f"Your digital pass is active."
    )
    twiml_response = f"""<?xml version="1.0" encoding="UTF-8"?>
<Response>
    <Message>{reply_msg}</Message>
</Response>"""
    return PlainTextResponse(content=twiml_response, media_type="text/xml")
