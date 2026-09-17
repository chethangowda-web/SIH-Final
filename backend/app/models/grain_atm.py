"""Pydantic Schemas for Smart Grain ATM / Automated Ration Pickup Module."""
from typing import List, Optional
from pydantic import BaseModel, Field


class GrainAtmStockItem(BaseModel):
    commodity: str = Field(..., description="Commodity name: RICE or WHEAT")
    capacity_kg: float = Field(..., description="Container capacity in KG")
    available_stock_kg: float = Field(..., description="Current stock in KG")
    min_threshold_kg: float = Field(50.0, description="Minimum low stock alert threshold in KG")
    is_low_stock: bool = Field(False, description="True if available_stock <= min_threshold")


class GrainAtmStatusOut(BaseModel):
    atm_id: str = Field("ATM-001", description="Unique ATM machine identifier")
    name: str = Field(..., description="Display name of the machine")
    location: str = Field(..., description="Physical location address")
    district: str = Field("Bengaluru Urban", description="Administrative district")
    status: str = Field("ONLINE", description="Operational status: ONLINE, OFFLINE, MAINTENANCE")
    is_ready: bool = Field(True, description="Ready to dispense")
    is_low_stock: bool = Field(False, description="Any commodity running below safety threshold")
    inventory: List[GrainAtmStockItem] = Field(default_factory=list)
    last_replenished_at: Optional[str] = Field(None, description="Last stock replenishment timestamp")


class BeneficiaryAtmVerificationIn(BaseModel):
    beneficiary_id: str = Field(..., description="Ration Card ID or Pseudonymous Beneficiary ID")
    cycle_id: str = Field("2026-09", description="Distribution cycle ID")
    auth_method: str = Field("DEMO_BIOMETRIC", description="Authentication mode: DEMO_BIOMETRIC, RATION_ID, OTP")
    pin_or_otp: Optional[str] = Field(None, description="Demo OTP or verification PIN")


class BeneficiaryAtmVerificationOut(BaseModel):
    beneficiary_id: str
    name: str
    card_type: str
    cycle_id: str
    statutory_rice_kg: float
    statutory_wheat_kg: float
    authorized_rice_kg: float
    authorized_wheat_kg: float
    already_received: bool = False
    already_received_message: Optional[str] = None
    stock_sufficient: bool = True
    eligible: bool = True
    reason: Optional[str] = None
    atm_id: str = "ATM-001"


class GrainAtmDispenseIn(BaseModel):
    atm_id: str = Field("ATM-001", description="ATM machine ID")
    beneficiary_id: str = Field(..., description="Beneficiary Ration ID")
    cycle_id: str = Field("2026-09", description="Distribution cycle ID")
    auth_method: str = Field("DEMO_BIOMETRIC", description="Authentication method used")


class GrainAtmDispenseOut(BaseModel):
    success: bool
    transaction_id: str
    beneficiary_id: str
    cycle_id: str
    dispensed_rice_kg: float
    dispensed_wheat_kg: float
    atm_id: str
    atm_location: str
    receipt_hash: str
    receipt_qr_data: str
    timestamp: str
    error_message: Optional[str] = None


class AtmOperationalDetail(BaseModel):
    atm_id: str
    name: str
    location: str
    status: str
    rice_stock_kg: float
    wheat_stock_kg: float
    today_transactions: int
    successful_transactions: int
    failed_transactions: int
    last_replenishment: str


class GrainAtmNetworkSummaryOut(BaseModel):
    total_atms: int = 5
    online_atms: int = 4
    low_stock_atms: int = 1
    today_dispensed_rice_kg: float = 842.0
    today_dispensed_wheat_kg: float = 316.0
    atms: List[AtmOperationalDetail] = Field(default_factory=list)
