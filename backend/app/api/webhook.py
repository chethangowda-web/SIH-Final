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
    
    # 1. Parse Beneficiary Card ID
    beneficiary_id = None
    for word in raw_message.split():
        if word.startswith("RC-KA-"):
            beneficiary_id = word
            break
            
    if not beneficiary_id:
        beneficiary_id = "RC-KA-000001"

    # 2. Parse FPS ID
    intended_fps = "FPS-KA-BAG-0001"
    for word in raw_message.split():
        if word.startswith("FPS-"):
            intended_fps = word
            break

    # 3. Parse Commodity & Qty
    commodity = "Wheat" if "WHEAT" in raw_message else "Rice"
    qty = 20.0
    if "10KG" in raw_message:
        qty = 10.0
    elif "35KG" in raw_message:
        qty = 35.0
        
    cycle_id = "2026-09"

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

    reply_msg = f"Thank you! Intent for {qty}kg {commodity} at {intended_fps} registered successfully for {beneficiary_id}."
    twiml_response = f"""<?xml version="1.0" encoding="UTF-8"?>
<Response>
    <Message>{reply_msg}</Message>
</Response>"""
    return PlainTextResponse(content=twiml_response, media_type="text/xml")
