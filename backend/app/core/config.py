"""Application Configuration."""
import os
from pathlib import Path
from typing import Any, List
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
    
    # SQLite Database Path
    DB_PATH: Path = BASE_DIR / "pds_demandsync.db"
    
    # Flutter Web static distribution directory
    STATIC_DIR: Path = BASE_DIR.parent / "frontend" / "build" / "web"
    
    # Logging Configuration
    LOG_LEVEL: str = "INFO"
    LOG_FORMAT: str = "text"  # "text" or "json"
    
    # Server Binding
    HOST: str = "0.0.0.0"
    PORT: int = 8000
    
    # CORS Origins (allow Flutter Web / Desktop)
    CORS_ORIGINS: List[str] = [
        "http://localhost",
        "http://localhost:8000",
        "http://localhost:3000",
        "http://localhost:5000",
        "http://127.0.0.1",
        "http://127.0.0.1:8000",
        "http://127.0.0.1:3000",
        "http://127.0.0.1:5000",
    ]
    
    # Default active cycle for Demo
    CURRENT_CYCLE: str = "2026-09"
    NEXT_CYCLE: str = "2026-10"

    # Deterministic Demand Forecasting Parameters
    INTENT_WEIGHT: float = 0.65       # Parameter w: Weight given to verified beneficiary intent
    SAFETY_BUFFER_PCT: float = 0.05   # 5% safety buffer for operational dispatch

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
                raise RuntimeError(
                    "Production startup failed: Insecure or default SECRET_KEY detected in production environment. "
                    "A strong, unique SECRET_KEY environment variable (at least 32 characters) is required."
                )
            if "*" in self.CORS_ORIGINS:
                raise RuntimeError(
                    "Production startup failed: Wildcard '*' in CORS_ORIGINS is prohibited in production when credentials are supported."
                )
            # Ensure DB directory exists
            if self.DB_PATH.parent:
                self.DB_PATH.parent.mkdir(parents=True, exist_ok=True)

settings = Settings()

