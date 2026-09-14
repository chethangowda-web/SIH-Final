"""SMS Notification Provider Service.

Provides an isolated abstraction layer for sending SMS notifications
via India-focused gateways (Fast2SMS / MSG91) with graceful demo fallback,
phone number masking, and complete failure isolation.
"""

import re
import random
from datetime import datetime
from typing import Dict, Any, Optional
import httpx
from app.core.config import settings
from app.core.logging_config import get_logger

logger = get_logger("sms_provider")


def mask_phone(phone: str) -> str:
    """Mask phone number for privacy and demo logging (e.g., +91-XXXXX10001)."""
    digits = re.sub(r"[^\d]", "", phone)
    if len(digits) >= 10:
        return f"+91-XXXXX{digits[-5:]}"
    elif len(digits) >= 4:
        return f"XXXXX{digits[-4:]}"
    return "XXXXX"


def clean_indian_phone(phone: str) -> str:
    """Extract standard 10-digit Indian mobile number."""
    digits = re.sub(r"[^\d]", "", phone)
    if digits.startswith("91") and len(digits) == 12:
        return digits[2:]
    elif len(digits) > 10 and digits.startswith("0"):
        return digits[-10:]
    return digits[-10:] if len(digits) >= 10 else digits


class BaseSmsProvider:
    """Base interface for SMS providers."""
    def send(self, phone: str, recipient_name: str, message: str, ref_id: str = "") -> Dict[str, Any]:
        raise NotImplementedError


class Fast2SMSProvider(BaseSmsProvider):
    """Fast2SMS Gateway Integration (India Quick SMS / Transactional)."""

    API_URL = "https://www.fast2sms.com/dev/bulkV2"

    def __init__(self, api_key: str, sender_id: str = "DEMAND"):
        self.api_key = api_key
        self.sender_id = sender_id

    def send(self, phone: str, recipient_name: str, message: str, ref_id: str = "") -> Dict[str, Any]:
        clean_num = clean_indian_phone(phone)
        if len(clean_num) != 10:
            logger.warning("Fast2SMS invalid mobile number length '%s' for recipient '%s'", phone, recipient_name)
            return {
                "success": False,
                "status": "FAILED",
                "error": f"Invalid Indian 10-digit phone number: {mask_phone(phone)}",
                "recipient_phone": mask_phone(phone)
            }

        headers = {
            "authorization": self.api_key,
            "Content-Type": "application/json"
        }
        payload = {
            "route": "q",
            "message": message,
            "language": "english",
            "flash": 0,
            "numbers": clean_num
        }

        try:
            with httpx.Client(timeout=10.0) as client:
                response = client.post(self.API_URL, headers=headers, json=payload)
                res_data = response.json() if response.status_code == 200 else {}
                
                if response.status_code == 200 and res_data.get("return") is True:
                    msg_id = res_data.get("request_id") or f"F2S-{random.randint(100000, 999999)}"
                    logger.info("Fast2SMS sent successfully to %s, msg_id=%s", mask_phone(phone), msg_id)
                    return {
                        "success": True,
                        "status": "DELIVERED",
                        "message_id": str(msg_id),
                        "recipient_phone": phone,
                        "provider_response": res_data
                    }
                else:
                    err_msg = res_data.get("message", [response.text])[0] if isinstance(res_data.get("message"), list) else str(res_data.get("message") or response.text)
                    logger.warning("Fast2SMS gateway returned error (%d): %s", response.status_code, err_msg)
                    return {
                        "success": False,
                        "status": "FAILED",
                        "error": f"Gateway error: {err_msg}",
                        "recipient_phone": mask_phone(phone)
                    }
        except Exception as e:
            logger.exception("Fast2SMS HTTP request failed: %s", str(e))
            return {
                "success": False,
                "status": "FAILED",
                "error": str(e),
                "recipient_phone": mask_phone(phone)
            }


class MSG91Provider(BaseSmsProvider):
    """MSG91 Gateway Integration."""

    API_URL = "https://control.msg91.com/api/v5/flow/"

    def __init__(self, auth_key: str, sender_id: str = "DEMAND"):
        self.auth_key = auth_key
        self.sender_id = sender_id

    def send(self, phone: str, recipient_name: str, message: str, ref_id: str = "") -> Dict[str, Any]:
        clean_num = "91" + clean_indian_phone(phone)
        headers = {
            "authkey": self.auth_key,
            "content-type": "application/json"
        }
        payload = {
            "sender": self.sender_id,
            "route": "4",
            "country": "91",
            "sms": [{"message": message, "to": [clean_num]}]
        }

        try:
            with httpx.Client(timeout=10.0) as client:
                response = client.post(self.API_URL, headers=headers, json=payload)
                if response.status_code == 200:
                    msg_id = f"MSG91-{random.randint(100000, 999999)}"
                    logger.info("MSG91 sent successfully to %s", mask_phone(phone))
                    return {
                        "success": True,
                        "status": "DELIVERED",
                        "message_id": msg_id,
                        "recipient_phone": phone
                    }
                else:
                    logger.warning("MSG91 returned error status %d", response.status_code)
                    return {
                        "success": False,
                        "status": "FAILED",
                        "error": f"MSG91 HTTP {response.status_code}",
                        "recipient_phone": mask_phone(phone)
                    }
        except Exception as e:
            logger.exception("MSG91 request failed: %s", str(e))
            return {
                "success": False,
                "status": "FAILED",
                "error": str(e),
                "recipient_phone": mask_phone(phone)
            }


class DemoSmsProvider(BaseSmsProvider):
    """Safe fallback when SMS_ENABLED is False or credentials are not configured."""

    def send(self, phone: str, recipient_name: str, message: str, ref_id: str = "") -> Dict[str, Any]:
        masked = mask_phone(phone)
        msg_id = f"SMS-DEMO-{random.randint(100000, 999999)}"
        logger.info(
            "[DEMO_SMS] Intended send to %s (%s) | Status: DEMO/NOT_CONFIGURED | MsgID: %s | Text: %.60s...",
            masked, recipient_name, msg_id, message.replace('\n', ' ')
        )
        return {
            "success": True,
            "status": "DEMO/NOT_CONFIGURED",
            "message_id": msg_id,
            "recipient_phone": phone,
            "masked_phone": masked,
            "demo_notice": "SMS sending disabled or credentials not configured. Logged for demonstration."
        }


def get_sms_provider() -> BaseSmsProvider:
    """Factory to instantiate configured SMS provider or demo fallback."""
    if not settings.SMS_ENABLED or not settings.SMS_PROVIDER_API_KEY:
        return DemoSmsProvider()

    provider_name = (settings.SMS_PROVIDER or "fast2sms").strip().lower()
    if provider_name == "msg91":
        return MSG91Provider(auth_key=settings.SMS_PROVIDER_API_KEY, sender_id=settings.SMS_SENDER_ID)
    return Fast2SMSProvider(api_key=settings.SMS_PROVIDER_API_KEY, sender_id=settings.SMS_SENDER_ID)


def send_beneficiary_sms(
    recipient_phone: str,
    recipient_name: str,
    message: str,
    ref_id: str = ""
) -> Dict[str, Any]:
    """
    Failure-isolated entrypoint for sending beneficiary SMS.
    Never throws exceptions to caller; always returns a structured delivery status dict.
    """
    try:
        provider = get_sms_provider()
        res = provider.send(
            phone=recipient_phone,
            recipient_name=recipient_name,
            message=message,
            ref_id=ref_id
        )
        return {
            "channel": "SMS",
            "recipient_phone": recipient_phone,
            "recipient_name": recipient_name,
            "status": res.get("status", "DELIVERED"),
            "message_id": res.get("message_id") or f"SMS-GW-{random.randint(100000, 999999)}",
            "delivered_at": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
            "telecom_circle": "KARNATAKA_DO_TRAI",
            "error": res.get("error")
        }
    except Exception as exc:
        logger.exception("Unexpected error in send_beneficiary_sms: %s", str(exc))
        return {
            "channel": "SMS",
            "recipient_phone": mask_phone(recipient_phone),
            "recipient_name": recipient_name,
            "status": "FAILED",
            "message_id": f"SMS-ERR-{random.randint(100000, 999999)}",
            "delivered_at": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
            "error": str(exc)
        }
