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
    district: str = Field(default="Bengaluru Urban PDS Pilot")
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
    beneficiary_id: str = Field(..., max_length=64, description="Pseudonymous Beneficiary ID e.g. BEN-KA-0001", json_schema_extra={"example": "BEN-KA-0001"})
    cycle_id: str = Field(default="2026-09", max_length=32, description="Target Allocation Cycle", json_schema_extra={"example": "2026-09"})
    intended_fps_id: str = Field(..., max_length=64, description="Chosen FPS for collection or dispatch origin", json_schema_extra={"example": "FPS-KA-BLR-013"})
    commodity: str = Field(..., max_length=32, description="Commodity type: Rice or Wheat", json_schema_extra={"example": "Rice"})
    declared_quantity_kg: Optional[float] = Field(default=None, ge=0.0, le=1000.0, description="Optional planning signal. Server automatically computes authoritative statutory quota from entitlement records.")
    delivery_mode: str = Field(default="FPS_COLLECTION", max_length=32, description="Delivery Service: FPS_COLLECTION or HOME_DELIVERY")
    delivery_address: Optional[str] = Field(default=None, max_length=500, description="Optional delivery address for assisted home distribution")
    delivery_distance_km: Optional[float] = Field(default=0.0, ge=0.0, le=500.0, description="Estimated distance from FPS in kilometers")
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
    delivery_mode: str = "FPS_COLLECTION"
    delivery_address: Optional[str] = None
    delivery_distance_km: float = 0.0
    transport_fee_inr: float = 0.0
    delivery_status: str = "SERVICE_REQUESTED"
    statutory_entitlement_kg: float = 20.0
    remaining_balance_kg: float = 20.0
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


# ----------------- Citizen Request & AI Advisor Schemas ----------------- #
class AIRecommendationOut(BaseModel):
    recommendation: str = Field(..., description="APPROVE | PARTIAL_ALLOCATION | REDIRECT_ALTERNATIVE_FPS | DEFER_TO_CYCLE")
    recommended_quantity_kg: float
    recommended_fps_id: Optional[str] = None
    recommended_fps_name: Optional[str] = None
    risk_level: str = Field(default="LOW", description="LOW | ELEVATED | HIGH | CRITICAL")
    confidence: float = 0.95
    is_advisory: bool = True
    factors: List[str] = []
    best_alternative_fps: Optional[Dict[str, Any]] = None


class CitizenRequestOut(BaseModel):
    id: int
    request_id: str
    beneficiary_id: str
    beneficiary_name: Optional[str] = None
    card_type: str = "PHH"
    family_members_count: int = 4
    statutory_entitlement_rice_kg: float = 20.0
    statutory_entitlement_wheat_kg: float = 5.0
    statutory_entitlement_commodity_kg: float = 20.0
    cycle_id: str = "2026-09"
    registered_fps_id: str
    registered_fps_name: Optional[str] = None
    intended_fps_id: str
    intended_fps_name: Optional[str] = None
    commodity: str
    requested_quantity_kg: float
    authorized_quantity_kg: float = 0.0
    request_type: str = "PORTABILITY_PREFERENCE"
    status: str = "PENDING_OFFICER_REVIEW"
    
    # AI Decision Support
    ai_recommendation: str = "APPROVE"
    ai_recommended_qty_kg: float = 0.0
    ai_recommended_fps_id: Optional[str] = None
    ai_recommended_fps_name: Optional[str] = None
    ai_risk_level: str = "LOW"
    ai_confidence: float = 0.95
    ai_factors: List[str] = []
    
    # Target FPS Operational & Capacity Metrics (Institutional Transparency)
    fps_capacity_kg: float = 20000.0
    current_inventory_kg: float = 0.0
    statutory_floor_kg: float = 0.0
    pending_demand_kg: float = 0.0
    capacity_headroom_kg: float = 0.0
    replenishment_eta: str = "Morning Slot 08:30 AM"
    nearby_alternative_fps_name: Optional[str] = None
    nearby_alternative_distance_km: Optional[float] = None
    
    # Officer Authorization
    officer_name: Optional[str] = None
    officer_role: Optional[str] = None
    officer_justification: Optional[str] = None
    authorized_at: Optional[str] = None
    
    created_at: str
    demo_notice: str = DEMO_NOTICE


class CitizenRequestAuthorizeIn(BaseModel):
    officer_name: str = Field(default="K. Srinivas Murthy (Demo DSO)", description="Name of authorizing government officer")
    officer_role: str = Field(default="DISTRICT_SUPPLY_OFFICER", description="Role: DISTRICT_SUPPLY_OFFICER, DEPOT_MANAGER, ADMIN")
    decision: str = Field(..., description="APPROVE | PARTIAL_ALLOCATION | REDIRECT_ALTERNATIVE_FPS | DEFER_TO_CYCLE | REJECT")
    allocated_quantity_kg: Optional[float] = Field(None, description="Approved quantity (if different from requested)")
    allocated_fps_id: Optional[str] = Field(None, description="Redirected FPS ID (if redirecting)")
    officer_justification: str = Field(..., min_length=5, description="Institutional justification string for audit logging")


class CitizenRequestQueueResponse(BaseModel):
    total_count: int
    pending_count: int
    approved_count: int
    delayed_count: int = 0
    partial_count: int
    redirected_count: int
    deferred_count: int
    cycle_id: str
    items: List[CitizenRequestOut]
    demo_notice: str = DEMO_NOTICE


class TransportFeeBreakdownOut(BaseModel):
    delivery_mode: str = "FPS_COLLECTION"
    delivery_distance_km: float = 0.0
    base_transport_fee_inr: float = 0.0
    distance_surcharge_inr: float = 0.0
    total_transport_fee_inr: float = 0.0
    commodity_cost_inr: float = 0.0
    total_payable_inr: float = 0.0
    statutory_notice: str


class BeneficiaryEntitlementSummaryOut(BaseModel):
    beneficiary_id: str
    name: str
    card_type: str
    family_members_count: int
    card_label: str
    cycle_id: str
    registered_fps_id: str
    registered_fps_name: str
    statutory_entitlement_rice_kg: float
    statutory_entitlement_wheat_kg: float
    consumed_rice_kg: float
    consumed_wheat_kg: float
    remaining_eligible_rice_kg: float
    remaining_eligible_wheat_kg: float
    total_eligible_balance_kg: float
    transport_policy: TransportFeeBreakdownOut
    demo_notice: str = DEMO_NOTICE


class CitizenDeliveryConfirmIn(BaseModel):
    request_id: str
    confirmation_status: str = Field(..., description="DELIVERY_CONFIRMED | DELIVERY_DISPUTE")
    received_rice_kg: Optional[float] = Field(None, description="Actual Rice quantity received")
    received_wheat_kg: Optional[float] = Field(None, description="Actual Wheat quantity received")
    dispute_notes: Optional[str] = Field(None, description="Citizen feedback or shortfall explanation")


class DeliveryDisputeOut(BaseModel):
    id: int
    dispute_id: str
    request_id: str
    beneficiary_id: str
    cycle_id: str
    commodity: str
    allocated_quantity_kg: float
    received_quantity_kg: float
    shortfall_kg: float
    dispute_notes: str
    status: str
    resolution_notes: Optional[str] = None
    resolved_by: Optional[str] = None
    resolved_at: Optional[str] = None
    created_at: str
    demo_notice: str = DEMO_NOTICE


class DeliveryDisputeResolveIn(BaseModel):
    officer_name: str = Field(default="K. Srinivas Murthy (DSO)")
    officer_role: str = Field(default="DISTRICT_SUPPLY_OFFICER")
    decision: str = Field(..., description="OFFICER_RESOLVED | REJECTED")
    resolution_notes: str = Field(..., min_length=5, description="Official resolution notes and compensation/corrective directive")


class ChoiceWindowStatusOut(BaseModel):
    cycle_id: str
    is_open: bool
    status: str
    workflow_status: str
    active_intents_count: int
    total_declared_intent_kg: float
    closing_deadline: str
    governance_notice: str
    demo_notice: str = DEMO_NOTICE


class SupplyRouteItem(BaseModel):
    route_id: str
    source_depot_id: str
    depot_name: str
    depot_location: str
    destination_fps_id: str
    fps_name: str
    district: str
    distance_km: float
    estimated_time_mins: int
    road_condition: str
    restriction_status: str


class SupplyRoutesResponse(BaseModel):
    status: str = "success"
    total_routes_count: int
    routes: List[SupplyRouteItem]
    demo_notice: str = DEMO_NOTICE


class DistrictForecastSummaryItem(BaseModel):
    fps_id: str
    fps_name: str
    predicted_demand_kg: float
    confidence_score: float
    lower_estimate_kg: float
    upper_estimate_kg: float


class DistrictForecastSummaryResponse(BaseModel):
    status: str = "success"
    cycle_id: str
    total_fps_count: int
    total_district_predicted_kg: float
    total_rice_predicted_kg: float
    total_wheat_predicted_kg: float
    average_district_confidence: float
    fps_forecasts: List[DistrictForecastSummaryItem]
    demo_notice: str = DEMO_NOTICE


class DistrictDispatchSummaryItem(BaseModel):
    fps_id: str
    fps_name: str
    predicted_demand_kg: float
    current_stock_kg: float
    safety_buffer_kg: float
    recommended_dispatch_kg: float
    formula: str
    capacity_utilization_pct: float


class DistrictDispatchSummaryResponse(BaseModel):
    status: str = "success"
    cycle_id: str
    total_fps_count: int
    total_district_recommended_dispatch_kg: float
    total_district_current_stock_kg: float
    total_district_safety_buffer_kg: float
    total_district_capacity_kg: float
    average_capacity_utilization_pct: float
    fps_decisions: List[DistrictDispatchSummaryItem]
    demo_notice: str = DEMO_NOTICE
