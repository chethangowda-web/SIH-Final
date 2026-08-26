"""Pydantic Request & Response Schemas for PDS DemandSync Demo V1."""
from datetime import datetime
from typing import Optional, List, Dict, Any
from pydantic import BaseModel, Field, ConfigDict

DEMO_NOTICE = "DEMO DATA — NOT GOVERNMENT DATA"

# ----------------- Health Schemas ----------------- #
class HealthResponse(BaseModel):
    status: str = Field(..., json_schema_extra={"example": "healthy"})
    project_name: str = Field(..., json_schema_extra={"example": "PDS DemandSync"})
    subtitle: str = Field(..., json_schema_extra={"example": "Forward-Looking Beneficiary Intent for Pre-Dispatch PDS Demand Forecasting"})
    version: str = Field(..., json_schema_extra={"example": "1.0.0-demo-v1"})
    database_status: str = Field(..., json_schema_extra={"example": "connected"})
    district: str = Field(default="Bengaluru Urban - Demo District")
    active_cycle: str = Field(..., json_schema_extra={"example": "2026-09"})
    historical_cycles: List[str] = Field(default_factory=lambda: ["2026-03", "2026-04", "2026-05", "2026-06", "2026-07", "2026-08"])
    fps_count: int = Field(default=20)
    beneficiaries_count: int = Field(default=2000)
    server_time: str
    demo_notice: str = DEMO_NOTICE

    model_config = ConfigDict(from_attributes=True)

# ----------------- Beneficiary Schemas ----------------- #
class BeneficiaryOut(BaseModel):
    id: int
    pseudonymous_beneficiary_id: str
    name_for_demo: str
    registered_fps_id: str
    language: str
    status: str

    model_config = ConfigDict(from_attributes=True)

class BeneficiaryDetailOut(BaseModel):
    id: int
    pseudonymous_beneficiary_id: str
    name_for_demo: str
    registered_fps_id: str
    registered_fps_name: Optional[str] = None
    language: str
    status: str
    active_intents: List[Dict[str, Any]] = []
    demo_notice: str = DEMO_NOTICE

    model_config = ConfigDict(from_attributes=True)

class PaginatedBeneficiaries(BaseModel):
    total: int
    limit: int
    offset: int
    items: List[BeneficiaryOut]
    demo_notice: str = DEMO_NOTICE

# ----------------- FPS Schemas ----------------- #
class InventoryItem(BaseModel):
    commodity: str
    available_quantity_kg: float

class FPSOut(BaseModel):
    id: int
    fps_id: str
    name: str
    district: str
    latitude: float
    longitude: float
    capacity_kg: float
    status: str
    registered_beneficiaries_count: Optional[int] = 0
    current_inventory_total_kg: Optional[float] = 0.0
    declared_intent_cycle_kg: Optional[float] = 0.0

    model_config = ConfigDict(from_attributes=True)

class FPSDetailOut(BaseModel):
    id: int
    fps_id: str
    name: str
    district: str
    latitude: float
    longitude: float
    capacity_kg: float
    status: str
    registered_beneficiaries_count: int
    inventories: List[InventoryItem]
    current_cycle_intents: Dict[str, Any]
    demo_notice: str = DEMO_NOTICE

    model_config = ConfigDict(from_attributes=True)

# ----------------- Intent Schemas ----------------- #
class IntentCreateIn(BaseModel):
    beneficiary_id: str = Field(..., description="Pseudonymous Beneficiary ID e.g. BEN-KA-0001", json_schema_extra={"example": "BEN-KA-0001"})
    cycle_id: str = Field(default="2026-09", description="Target Allocation Cycle", json_schema_extra={"example": "2026-09"})
    intended_fps_id: str = Field(..., description="Chosen FPS for collection", json_schema_extra={"example": "FPS-KA-BLR-013"})
    commodity: str = Field(..., description="Commodity type: Rice or Wheat", json_schema_extra={"example": "Rice"})
    declared_quantity_kg: float = Field(..., gt=0, description="Declared quota in kg", json_schema_extra={"example": 25.0})
    confidence: Optional[float] = Field(default=0.95, ge=0.0, le=1.0, description="Intent confidence score")

class IntentOut(BaseModel):
    id: int
    beneficiary_id: str
    cycle_id: str
    intended_fps_id: str
    intended_fps_name: Optional[str] = None
    home_fps_id: Optional[str] = None
    is_portability_intent: bool = False
    commodity: str
    declared_quantity_kg: float
    confidence: float
    created_at: Any
    status: str
    demo_notice: str = DEMO_NOTICE

    model_config = ConfigDict(from_attributes=True)

# ----------------- Historical Demand & Inventory Schemas ----------------- #
class HistoricalDemandRecord(BaseModel):
    cycle_id: str
    commodity: str
    actual_quantity_kg: float

class FPSHistoricalDemandOut(BaseModel):
    fps_id: str
    fps_name: str
    records: List[HistoricalDemandRecord]
    rice_trend_kg: List[Dict[str, Any]]
    wheat_trend_kg: List[Dict[str, Any]]
    demo_notice: str = DEMO_NOTICE

class FPSInventoryOut(BaseModel):
    fps_id: str
    fps_name: str
    capacity_kg: float
    total_available_kg: float
    capacity_utilization_pct: float
    items: List[InventoryItem]
    demo_notice: str = DEMO_NOTICE

# ----------------- Dashboard Summary Schema ----------------- #
class DashboardSummaryOut(BaseModel):
    district: str
    total_fps: int
    total_beneficiaries: int
    active_cycle: str
    historical_cycles_count: int
    total_inventory_kg: float
    total_rice_inventory_kg: float
    total_wheat_inventory_kg: float
    total_declared_intent_kg: float
    total_rice_intent_kg: float
    total_wheat_intent_kg: float
    intent_beneficiaries_count: int
    portability_intent_count: int
    portability_intent_pct: float
    demo_notice: str = DEMO_NOTICE

# ----------------- Forecast Schemas ----------------- #
class ForecastRecordOut(BaseModel):
    id: int
    fps_id: str
    fps_name: Optional[str] = None
    cycle_id: str
    commodity: str
    historical_demand_kg: float
    intent_demand_kg: float
    inventory_kg: float
    forecast_demand_kg: float
    recommended_dispatch_kg: float
    confidence: float
    risk_level: str
    model_version: str
    status: str
    created_at: Any
    demo_notice: str = DEMO_NOTICE

    model_config = ConfigDict(from_attributes=True)

class ForecastGenerateOut(BaseModel):
    status: str
    workflow_status: str
    cycle_id: str
    total_fps: int
    generated_records_count: int
    total_historical_demand_kg: float
    total_intent_demand_kg: float
    total_forecast_demand_kg: float
    total_recommended_dispatch_kg: float
    average_confidence: float
    model_version: str
    intent_weight: float
    message: str
    demo_notice: str = DEMO_NOTICE

class ForecastLockOut(BaseModel):
    status: str
    workflow_status: str
    cycle_id: str
    locked_records_count: int
    message: str
    demo_notice: str = DEMO_NOTICE

# ----------------- Dispatch Schemas ----------------- #
class DispatchRecordOut(BaseModel):
    id: int
    forecast_id: Optional[int] = None
    fps_id: str
    fps_name: Optional[str] = None
    cycle_id: str
    commodity: str
    quantity_kg: float
    demo_truck_id: str
    source_godown: str
    status: str
    created_at: Any
    demo_notice: str = DEMO_NOTICE

    model_config = ConfigDict(from_attributes=True)

class VehicleManifestItem(BaseModel):
    truck_id: str
    source_godown: str
    route_name: str
    total_payload_kg: float
    total_payload_mt: float
    stops_count: int
    delivery_stops: List[Dict[str, Any]]

class DispatchManifestOut(BaseModel):
    status: str
    workflow_status: str
    cycle_id: str
    total_dispatch_kg: float
    total_rice_dispatch_kg: float
    total_wheat_dispatch_kg: float
    total_fps_count: int
    total_vehicles_count: int
    vehicles: List[VehicleManifestItem]
    records: List[DispatchRecordOut]
    message: str
    demo_notice: str = DEMO_NOTICE

# ----------------- Phase 6: Distribution, Evaluation & Calibration Schemas ----------------- #

class ActualDistributionRecordOut(BaseModel):
    id: int
    fps_id: str
    fps_name: Optional[str] = None
    cycle_id: str
    commodity: str
    dispatch_quantity_kg: float = 0.0
    actual_quantity_kg: float
    variance_kg: float = 0.0
    variance_pct: float = 0.0
    status: str = "DISTRIBUTED"
    created_at: Any
    demo_notice: str = DEMO_NOTICE

    model_config = ConfigDict(from_attributes=True)

class ActualDistributionSimulationOut(BaseModel):
    status: str
    workflow_status: str
    cycle_id: str
    total_actual_quantity_kg: float
    total_rice_actual_kg: float
    total_wheat_actual_kg: float
    total_dispatch_quantity_kg: float
    total_variance_kg: float
    total_fps_count: int
    simulated_records_count: int
    records: List[ActualDistributionRecordOut]
    message: str
    demo_notice: str = DEMO_NOTICE

class EvaluationFpsItem(BaseModel):
    fps_id: str
    fps_name: str
    commodity: str
    forecast_quantity_kg: float
    actual_quantity_kg: float
    absolute_error_kg: float
    percentage_error: float
    accuracy_pct: float

class ForecastEvaluationOut(BaseModel):
    status: str
    workflow_status: str
    cycle_id: str
    records_evaluated_count: int
    total_forecast_quantity_kg: float
    total_actual_quantity_kg: float
    total_absolute_error_kg: float
    mae_kg: float
    mape_pct: float
    overall_accuracy_pct: float
    rice_mape_pct: float
    wheat_mape_pct: float
    commodity_breakdown: Dict[str, Any]
    fps_evaluations: List[EvaluationFpsItem]
    message: str
    demo_notice: str = DEMO_NOTICE

class ModelCalibrationOut(BaseModel):
    status: str
    workflow_status: str
    cycle_id: str
    target_future_cycle: str
    algorithm: str
    model_version: str
    previous_weight: float
    calibrated_weight: float
    before_mape: float
    after_mape: float
    records_trained: int
    training_features: List[str]
    message: str
    demo_notice: str = DEMO_NOTICE



