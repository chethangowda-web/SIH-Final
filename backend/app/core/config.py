"""Application Configuration."""
import os
from pathlib import Path
from pydantic import ConfigDict
from pydantic_settings import BaseSettings

BASE_DIR = Path(__file__).resolve().parent.parent.parent

class Settings(BaseSettings):
    PROJECT_NAME: str = "PDS DemandSync"
    PROJECT_SUBTITLE: str = "Forward-Looking Beneficiary Intent for Pre-Dispatch PDS Demand Forecasting"
    VERSION: str = "1.0.0-demo-v1"
    API_V1_PREFIX: str = "/api"
    
    # SQLite Database Path
    DB_PATH: Path = BASE_DIR / "pds_demandsync.db"
    
    # CORS Origins (allow Flutter Web / Desktop)
    CORS_ORIGINS: list[str] = [
        "http://localhost",
        "http://localhost:8000",
        "http://localhost:3000",
        "http://127.0.0.1",
        "http://127.0.0.1:8000",
        "http://127.0.0.1:3000",
        "http://localhost:*",
        "*"
    ]
    
    # Default active cycle for Demo
    CURRENT_CYCLE: str = "2026-09"
    NEXT_CYCLE: str = "2026-10"

    # Deterministic Demand Forecasting Parameters
    INTENT_WEIGHT: float = 0.65       # Parameter w: Weight given to verified beneficiary intent
    SAFETY_BUFFER_PCT: float = 0.05   # 5% safety buffer for operational dispatch

    model_config = ConfigDict(case_sensitive=True)

settings = Settings()
