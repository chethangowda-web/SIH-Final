"""Application Configuration."""
import os
from pathlib import Path
from typing import Any, List, Optional
from pydantic import ConfigDict, field_validator
from pydantic_settings import BaseSettings

BASE_DIR = Path(__file__).resolve().parent.parent.parent

DEFAULT_DEV_SECRET_KEY = "sih2026_pds_demandsync_default_secret_key_secure_1289"

class Settings(BaseSettings):
    PROJECT_NAME: str = "PDS DemandSync"
    PROJECT_SUBTITLE: str = "Forward-Looking Beneficiary Intent for Pre-Dispatch PDS Demand Forecasting"
    VERSION: str = "1.0.0-demo-v1"
    API_V1_PREFIX: str = "/api"
    
    # Environment mode: "development", "staging", "production", "test"
    ENVIRONMENT: str = "development"
    
    # Secret Key for Token Signatures (HMAC-SHA256)
    SECRET_KEY: str = DEFAULT_DEV_SECRET_KEY
    
    # Test Auth Mock Switch (Strictly ignored/disabled in production)
    ALLOW_TEST_AUTH_MOCK: bool = True
    
    # Administrative Demo Reset Switch in Production (False by default in production)
    ALLOW_DEMO_RESET: bool = True
    SMART_GRAIN_ATM_ENABLED: bool = True
    
    # SQLite Database Path
    DB_PATH: Path = BASE_DIR / "pds_demandsync.db"
    
    # Flutter Web static distribution directory
    STATIC_DIR: Path = (BASE_DIR / "app" / "static_web") if (BASE_DIR / "app" / "static_web").exists() else (BASE_DIR.parent / "frontend" / "build" / "web")
    
    # Logging Configuration
    LOG_LEVEL: str = "INFO"
    LOG_FORMAT: str = "text"  # "text" or "json"
    
    # Server Binding
    HOST: str = "0.0.0.0"
    PORT: int = 8000
    
    # CORS Origins (allow Flutter Web / Desktop)
    CORS_ORIGINS: List[str] = [
        "http://localhost",
        "http://localhost:8080",
        "http://localhost:8000",
        "http://localhost:3000",
        "http://localhost:5000",
        "http://127.0.0.1",
        "http://127.0.0.1:8080",
        "http://127.0.0.1:8000",
        "http://127.0.0.1:3000",
        "http://127.0.0.1:5000",
    ]
    
    # Twilio API Credentials (for real SMS/WhatsApp/IVR integration)
    TWILIO_ACCOUNT_SID: str = "AC5f5cfb44e18f44372e613297f1c8c59b"
    TWILIO_AUTH_TOKEN: str = "14c6067a3b9301749d1c2b9a6b4d0965"
    TWILIO_PHONE_NUMBER: str = "+17372508034"
    TWILIO_DEFAULT_RECIPIENT: str = "+918050442666"

    
    # Default active cycle for Demo
    CURRENT_CYCLE: str = "2026-09"
    NEXT_CYCLE: str = "2026-10"

    # Deterministic Demand Forecasting Parameters
    INTENT_WEIGHT: float = 0.65       # Parameter w: Weight given to verified beneficiary intent
    SAFETY_BUFFER_PCT: float = 0.05   # 5% safety buffer for operational dispatch

    # SMS Gateway Configuration (India Fast2SMS / MSG91 / Twilio)
    OTP_MODE: str = "demo"  # "demo" or "real"
    SMS_PROVIDER_API_KEY: Optional[str] = None
    SMS_SENDER_ID: str = "DEMAND"
    SMS_ENABLED: bool = False
    SMS_PROVIDER: str = "fast2sms"
    SMS_DEMO_RECIPIENT_PHONE: Optional[str] = None

    model_config = ConfigDict(case_sensitive=True, extra="ignore")

    @property
    def is_production(self) -> bool:
        return self.ENVIRONMENT.lower() in ["production", "prod"]

    @field_validator("CORS_ORIGINS", mode="before")
    @classmethod
    def parse_cors_origins(cls, v: Any) -> List[str]:
        if isinstance(v, str):
            return [s.strip() for s in v.split(",") if s.strip()]
        return v

    def validate_production_config(self) -> None:
        """Enforce strict production security checks at startup."""
        if self.is_production:
            if not self.SECRET_KEY or self.SECRET_KEY == DEFAULT_DEV_SECRET_KEY or len(self.SECRET_KEY) < 32:
                raise RuntimeError("Insecure or default SECRET_KEY detected in production environment!")
            if "*" in self.CORS_ORIGINS:
                raise RuntimeError("Wildcard '*' in CORS_ORIGINS is prohibited in production environment!")
        # Ensure DB directory exists
        if self.DB_PATH.parent:
            self.DB_PATH.parent.mkdir(parents=True, exist_ok=True)

settings = Settings()

