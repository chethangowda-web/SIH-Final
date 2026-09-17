"""Smart Grain ATM / Automated Ration Pickup API Endpoints."""
import sqlite3
from fastapi import APIRouter, Depends, HTTPException, status, Query
from app.core.database import get_db
from app.models.grain_atm import (
    GrainAtmStatusOut,
    BeneficiaryAtmVerificationIn,
    BeneficiaryAtmVerificationOut,
    GrainAtmDispenseIn,
    GrainAtmDispenseOut,
    GrainAtmNetworkSummaryOut,
)
from app.services.grain_atm_service import grain_atm_service

router = APIRouter(prefix="/grain-atm", tags=["Smart Grain ATM"])


@router.get("/status", response_model=GrainAtmStatusOut)
def get_default_atm_status(
    db: sqlite3.Connection = Depends(get_db)
):
    """Fetch live status of default ATM-001."""
    return grain_atm_service.get_atm_status(db, "ATM-001")


@router.get("/network-summary", response_model=GrainAtmNetworkSummaryOut)
def get_atm_network_summary(
    db: sqlite3.Connection = Depends(get_db)
):
    """
    Operational telemetry for Department Officials and Administrators.
    Provides network-wide machine health, low stock indicators, and dispensing throughput.
    """
    return grain_atm_service.get_network_summary(db)


@router.get("/{atm_id}", response_model=GrainAtmStatusOut)
def get_atm_status(
    atm_id: str = "ATM-001",
    db: sqlite3.Connection = Depends(get_db)
):
    """Fetch live machine status, commodity availability, and safety thresholds for a Smart Grain ATM."""
    return grain_atm_service.get_atm_status(db, atm_id)


@router.post("/verify", response_model=BeneficiaryAtmVerificationOut)
def verify_beneficiary_atm(
    payload: BeneficiaryAtmVerificationIn,
    db: sqlite3.Connection = Depends(get_db)
):
    """
    Verify beneficiary eligibility against authoritative PDS-DemandSync database state.
    Returns statutory entitlement, authorized grain allocation, and checks whether ration has already been received.
    """
    return grain_atm_service.verify_beneficiary(
        db=db,
        beneficiary_id=payload.beneficiary_id,
        cycle_id=payload.cycle_id,
        auth_method=payload.auth_method
    )


@router.post("/dispense", response_model=GrainAtmDispenseOut)
def dispense_grain_atm(
    payload: GrainAtmDispenseIn,
    db: sqlite3.Connection = Depends(get_db)
):
    """
    Simulate automated ration dispensing:
    Executes atomic database transaction, decrements machine stock, records durable cycle receipt,
    and returns a cryptographic SHA-256 digital receipt with verifiable QR payload.
    """
    res = grain_atm_service.dispense_grain_transaction(
        db=db,
        atm_id=payload.atm_id,
        beneficiary_id=payload.beneficiary_id,
        cycle_id=payload.cycle_id,
        auth_method=payload.auth_method
    )
    if not res.success and res.error_message and "already been received" in res.error_message:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=res.error_message
        )
    return res
