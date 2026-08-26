/// Data Models for AI-Assisted Stockout Risk Prediction & Fair-Share Scarcity Allocation.
///
/// Strictly mirrors FastAPI response schemas from `/api/admin/scarcity/*`.
/// Non-decisional ML risk representations and deterministic allocation payloads.

/// 1. Depot Supply vs Demand Balance Check Model
class DepotBalanceModel {
  final String cycleId;
  final String depotId;
  final String depotName;
  final String commodity;
  final double aggregateDemandKg;
  final double availableDepotStockKg;
  final double deficitKg;
  final double deficitPercentage;
  final bool isScarcityCondition;
  final String scarcityCondition; // 'NO_SCARCITY', 'FEASIBLE_SCARCITY', 'CRITICAL_DEFICIT'
  final double statutoryFloorTotalKg;
  final String statutoryFloorStatus; // 'STATUTORY_FLOORS_SATISFIED', 'STATUTORY_FLOORS_UNSATISFIABLE'
  final bool isStatutoryFloorSatisfied;
  final String? governanceAlert;
  final String demoNotice;

  DepotBalanceModel({
    required this.cycleId,
    required this.depotId,
    required this.depotName,
    required this.commodity,
    required this.aggregateDemandKg,
    required this.availableDepotStockKg,
    required this.deficitKg,
    required this.deficitPercentage,
    required this.isScarcityCondition,
    required this.scarcityCondition,
    required this.statutoryFloorTotalKg,
    required this.statutoryFloorStatus,
    required this.isStatutoryFloorSatisfied,
    this.governanceAlert,
    required this.demoNotice,
  });

  factory DepotBalanceModel.fromJson(Map<String, dynamic> json) {
    return DepotBalanceModel(
      cycleId: json['cycle_id'] ?? '2026-09',
      depotId: json['depot_id'] ?? '',
      depotName: json['depot_name'] ?? '',
      commodity: json['commodity'] ?? 'Rice',
      aggregateDemandKg: (json['aggregate_demand_kg'] as num?)?.toDouble() ?? 0.0,
      availableDepotStockKg: (json['available_depot_stock_kg'] as num?)?.toDouble() ?? 0.0,
      deficitKg: (json['deficit_kg'] as num?)?.toDouble() ?? 0.0,
      deficitPercentage: (json['deficit_percentage'] as num?)?.toDouble() ?? 0.0,
      isScarcityCondition: json['is_scarcity_condition'] ?? false,
      scarcityCondition: json['scarcity_condition'] ?? 'NO_SCARCITY',
      statutoryFloorTotalKg: (json['statutory_floor_total_kg'] as num?)?.toDouble() ?? 0.0,
      statutoryFloorStatus: json['statutory_floor_status'] ?? 'STATUTORY_FLOORS_SATISFIED',
      isStatutoryFloorSatisfied: json['is_statutory_floor_satisfied'] ?? true,
      governanceAlert: json['governance_alert'],
      demoNotice: json['demo_notice'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'cycle_id': cycleId,
        'depot_id': depotId,
        'depot_name': depotName,
        'commodity': commodity,
        'aggregate_demand_kg': aggregateDemandKg,
        'available_depot_stock_kg': availableDepotStockKg,
        'deficit_kg': deficitKg,
        'deficit_percentage': deficitPercentage,
        'is_scarcity_condition': isScarcityCondition,
        'scarcity_condition': scarcityCondition,
        'statutory_floor_total_kg': statutoryFloorTotalKg,
        'statutory_floor_status': statutoryFloorStatus,
        'is_statutory_floor_satisfied': isStatutoryFloorSatisfied,
        'governance_alert': governanceAlert,
        'demo_notice': demoNotice,
      };
}

/// 2. Single Fair Price Shop Stockout Risk Prediction Model
class StockoutRiskPredictionModel {
  final String fpsId;
  final String cycleId;
  final String commodity;
  final double requestedDispatchKg;
  final double proposedAllocationKg;
  final double stockoutProbability; // 0.0 <= P <= 1.0
  final String riskTier; // 'CRITICAL', 'ELEVATED', 'MODERATE', 'LOW'
  final String guidanceNote;
  final double daysOfStockCoverage;
  final double deficitRatio;
  final String modelName;
  final Map<String, double> features;
  final String governanceNotice;

  StockoutRiskPredictionModel({
    required this.fpsId,
    required this.cycleId,
    required this.commodity,
    required this.requestedDispatchKg,
    required this.proposedAllocationKg,
    required this.stockoutProbability,
    required this.riskTier,
    required this.guidanceNote,
    required this.daysOfStockCoverage,
    required this.deficitRatio,
    required this.modelName,
    required this.features,
    required this.governanceNotice,
  });

  factory StockoutRiskPredictionModel.fromJson(Map<String, dynamic> json) {
    final rawFeatures = json['features'] as Map<String, dynamic>? ?? {};
    final Map<String, double> parsedFeatures = {};
    rawFeatures.forEach((key, value) {
      if (value is num) {
        parsedFeatures[key] = value.toDouble();
      }
    });

    return StockoutRiskPredictionModel(
      fpsId: json['fps_id'] ?? '',
      cycleId: json['cycle_id'] ?? '',
      commodity: json['commodity'] ?? '',
      requestedDispatchKg: (json['requested_dispatch_kg'] as num?)?.toDouble() ?? 0.0,
      proposedAllocationKg: (json['proposed_allocation_kg'] as num?)?.toDouble() ?? 0.0,
      stockoutProbability: (json['stockout_probability'] as num?)?.toDouble() ?? 0.0,
      riskTier: json['risk_tier'] ?? 'LOW',
      guidanceNote: json['guidance_note'] ?? '',
      daysOfStockCoverage: (json['days_of_stock_coverage'] as num?)?.toDouble() ?? 0.0,
      deficitRatio: (json['deficit_ratio'] as num?)?.toDouble() ?? 0.0,
      modelName: json['model_name'] ?? '',
      features: parsedFeatures,
      governanceNotice: json['governance_notice'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'fps_id': fpsId,
        'cycle_id': cycleId,
        'commodity': commodity,
        'requested_dispatch_kg': requestedDispatchKg,
        'proposed_allocation_kg': proposedAllocationKg,
        'stockout_probability': stockoutProbability,
        'risk_tier': riskTier,
        'guidance_note': guidanceNote,
        'days_of_stock_coverage': daysOfStockCoverage,
        'deficit_ratio': deficitRatio,
        'model_name': modelName,
        'features': features,
        'governance_notice': governanceNotice,
      };
}

/// 3. ML Model Metadata Container
class ModelMetadataModel {
  final String modelName;
  final String algorithm;
  final String status;
  final int featuresCount;
  final List<String> featureNames;
  final Map<String, dynamic> metrics;
  final int trainingSamplesCount;
  final String governanceNotice;

  ModelMetadataModel({
    required this.modelName,
    required this.algorithm,
    required this.status,
    required this.featuresCount,
    required this.featureNames,
    required this.metrics,
    required this.trainingSamplesCount,
    required this.governanceNotice,
  });

  factory ModelMetadataModel.fromJson(Map<String, dynamic> json) {
    return ModelMetadataModel(
      modelName: json['model_name'] ?? '',
      algorithm: json['algorithm'] ?? '',
      status: json['status'] ?? '',
      featuresCount: json['features_count'] ?? 0,
      featureNames: (json['feature_names'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      metrics: Map<String, dynamic>.from(json['metrics'] ?? {}),
      trainingSamplesCount: json['training_samples_count'] ?? 0,
      governanceNotice: json['governance_notice'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'model_name': modelName,
        'algorithm': algorithm,
        'status': status,
        'features_count': featuresCount,
        'feature_names': featureNames,
        'metrics': metrics,
        'training_samples_count': trainingSamplesCount,
        'governance_notice': governanceNotice,
      };
}

/// 4. Batch Risk Prediction Response Model
class RiskPredictionResponseModel {
  final String status;
  final String cycleId;
  final String commodity;
  final int predictionsCount;
  final List<StockoutRiskPredictionModel> predictions;
  final ModelMetadataModel? modelMetadata;
  final String demoNotice;

  RiskPredictionResponseModel({
    required this.status,
    required this.cycleId,
    required this.commodity,
    required this.predictionsCount,
    required this.predictions,
    this.modelMetadata,
    required this.demoNotice,
  });

  factory RiskPredictionResponseModel.fromJson(Map<String, dynamic> json) {
    return RiskPredictionResponseModel(
      status: json['status'] ?? '',
      cycleId: json['cycle_id'] ?? '',
      commodity: json['commodity'] ?? '',
      predictionsCount: json['predictions_count'] ?? 0,
      predictions: (json['predictions'] as List<dynamic>?)
              ?.map((e) => StockoutRiskPredictionModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      modelMetadata: json['model_metadata'] != null
          ? ModelMetadataModel.fromJson(json['model_metadata'] as Map<String, dynamic>)
          : null,
      demoNotice: json['demo_notice'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'status': status,
        'cycle_id': cycleId,
        'commodity': commodity,
        'predictions_count': predictionsCount,
        'predictions': predictions.map((e) => e.toJson()).toList(),
        'model_metadata': modelMetadata?.toJson(),
        'demo_notice': demoNotice,
      };
}

/// 5. Itemized Fair-Share Scarcity Allocation for an Individual FPS
class ScarcityAllocationItemModel {
  final String fpsId;
  final String fpsName;
  final double baselineRecommendedKg;
  final double statutoryFloorKg;
  final double reconciledAllocationKg;
  final bool statutoryFloorSatisfied;
  final double floorDeficitKg;
  final double cutKg;
  final double cutPercentage;
  final double predictedStockoutRisk;
  final String riskTier;
  final String mitigationAction;

  ScarcityAllocationItemModel({
    required this.fpsId,
    required this.fpsName,
    required this.baselineRecommendedKg,
    required this.statutoryFloorKg,
    required this.reconciledAllocationKg,
    required this.statutoryFloorSatisfied,
    required this.floorDeficitKg,
    required this.cutKg,
    required this.cutPercentage,
    required this.predictedStockoutRisk,
    required this.riskTier,
    required this.mitigationAction,
  });

  factory ScarcityAllocationItemModel.fromJson(Map<String, dynamic> json) {
    return ScarcityAllocationItemModel(
      fpsId: json['fps_id'] ?? '',
      fpsName: json['fps_name'] ?? '',
      baselineRecommendedKg: (json['baseline_recommended_kg'] as num?)?.toDouble() ?? 0.0,
      statutoryFloorKg: (json['statutory_floor_kg'] as num?)?.toDouble() ?? 0.0,
      reconciledAllocationKg: (json['reconciled_allocation_kg'] as num?)?.toDouble() ?? 0.0,
      statutoryFloorSatisfied: json['statutory_floor_satisfied'] ?? true,
      floorDeficitKg: (json['floor_deficit_kg'] as num?)?.toDouble() ?? 0.0,
      cutKg: (json['cut_kg'] as num?)?.toDouble() ?? 0.0,
      cutPercentage: (json['cut_percentage'] as num?)?.toDouble() ?? 0.0,
      predictedStockoutRisk: (json['predicted_stockout_risk'] as num?)?.toDouble() ?? 0.0,
      riskTier: json['risk_tier'] ?? 'LOW',
      mitigationAction: json['mitigation_action'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'fps_id': fpsId,
        'fps_name': fpsName,
        'baseline_recommended_kg': baselineRecommendedKg,
        'statutory_floor_kg': statutoryFloorKg,
        'reconciled_allocation_kg': reconciledAllocationKg,
        'statutory_floor_satisfied': statutoryFloorSatisfied,
        'floor_deficit_kg': floorDeficitKg,
        'cut_kg': cutKg,
        'cut_percentage': cutPercentage,
        'predicted_stockout_risk': predictedStockoutRisk,
        'risk_tier': riskTier,
        'mitigation_action': mitigationAction,
      };
}

/// 6. Categorical Risk Breakdown Counts
class RiskSummaryModel {
  final int criticalRiskCount;
  final int elevatedRiskCount;
  final int moderateRiskCount;
  final int lowRiskCount;

  RiskSummaryModel({
    required this.criticalRiskCount,
    required this.elevatedRiskCount,
    required this.moderateRiskCount,
    required this.lowRiskCount,
  });

  factory RiskSummaryModel.fromJson(Map<String, dynamic> json) {
    return RiskSummaryModel(
      criticalRiskCount: json['critical_risk_count'] ?? 0,
      elevatedRiskCount: json['elevated_risk_count'] ?? 0,
      moderateRiskCount: json['moderate_risk_count'] ?? 0,
      lowRiskCount: json['low_risk_count'] ?? 0,
    );
  }

  factory RiskSummaryModel.empty() {
    return RiskSummaryModel(
      criticalRiskCount: 0,
      elevatedRiskCount: 0,
      moderateRiskCount: 0,
      lowRiskCount: 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'critical_risk_count': criticalRiskCount,
        'elevated_risk_count': elevatedRiskCount,
        'moderate_risk_count': moderateRiskCount,
        'low_risk_count': lowRiskCount,
      };
}

/// 7. Scarcity Plan Summary (Candidate & Simulated Plan)
class ScarcityPlanSummaryModel {
  final String? planId;
  final String cycleId;
  final String depotId;
  final String depotName;
  final String commodity;
  final double aggregateDemandKg;
  final double availableDepotStockKg;
  final double deficitKg;
  final double deficitPercentage;
  final bool isScarcityCondition;
  final String scarcityCondition;
  final String statutoryFloorStatus;
  final bool isStatutoryFloorSatisfied;
  final String? governanceAlert;
  final String allocationStrategy;
  final double totalStatutoryFloorsKg;
  final double totalReconciledAllocationKg;
  final double unallocatedDepotSlackKg;
  final double averageCutPercentage;
  final int allocatedFpsCount;
  final String approvalStatus; // 'PENDING_OFFICER_REVIEW', 'OFFICER_APPROVED', 'REJECTED'
  final RiskSummaryModel riskSummary;
  final List<ScarcityAllocationItemModel> allocatedItems;
  final String demoNotice;

  ScarcityPlanSummaryModel({
    this.planId,
    required this.cycleId,
    required this.depotId,
    required this.depotName,
    required this.commodity,
    required this.aggregateDemandKg,
    required this.availableDepotStockKg,
    required this.deficitKg,
    required this.deficitPercentage,
    required this.isScarcityCondition,
    required this.scarcityCondition,
    required this.statutoryFloorStatus,
    required this.isStatutoryFloorSatisfied,
    this.governanceAlert,
    required this.allocationStrategy,
    required this.totalStatutoryFloorsKg,
    required this.totalReconciledAllocationKg,
    required this.unallocatedDepotSlackKg,
    required this.averageCutPercentage,
    required this.allocatedFpsCount,
    this.approvalStatus = 'PENDING_OFFICER_REVIEW',
    required this.riskSummary,
    required this.allocatedItems,
    required this.demoNotice,
  });

  factory ScarcityPlanSummaryModel.fromJson(Map<String, dynamic> json) {
    return ScarcityPlanSummaryModel(
      planId: json['plan_id'],
      cycleId: json['cycle_id'] ?? '2026-09',
      depotId: json['depot_id'] ?? '',
      depotName: json['depot_name'] ?? '',
      commodity: json['commodity'] ?? 'Rice',
      aggregateDemandKg: (json['aggregate_demand_kg'] as num?)?.toDouble() ?? 0.0,
      availableDepotStockKg: (json['available_depot_stock_kg'] as num?)?.toDouble() ?? 0.0,
      deficitKg: (json['deficit_kg'] as num?)?.toDouble() ?? 0.0,
      deficitPercentage: (json['deficit_percentage'] as num?)?.toDouble() ?? 0.0,
      isScarcityCondition: json['is_scarcity_condition'] ?? false,
      scarcityCondition: json['scarcity_condition'] ?? 'NO_SCARCITY',
      statutoryFloorStatus: json['statutory_floor_status'] ?? 'STATUTORY_FLOORS_SATISFIED',
      isStatutoryFloorSatisfied: json['is_statutory_floor_satisfied'] ?? true,
      governanceAlert: json['governance_alert'],
      allocationStrategy: json['allocation_strategy'] ?? 'FAIR_SHARE_RISK_WEIGHTED',
      totalStatutoryFloorsKg: (json['total_statutory_floors_kg'] as num?)?.toDouble() ?? 0.0,
      totalReconciledAllocationKg: (json['total_reconciled_allocation_kg'] as num?)?.toDouble() ?? 0.0,
      unallocatedDepotSlackKg: (json['unallocated_depot_slack_kg'] as num?)?.toDouble() ?? 0.0,
      averageCutPercentage: (json['average_cut_percentage'] as num?)?.toDouble() ?? 0.0,
      allocatedFpsCount: json['allocated_fps_count'] ?? 0,
      approvalStatus: json['approval_status'] ?? 'PENDING_OFFICER_REVIEW',
      riskSummary: json['risk_summary'] != null
          ? RiskSummaryModel.fromJson(json['risk_summary'] as Map<String, dynamic>)
          : RiskSummaryModel.empty(),
      allocatedItems: (json['allocated_items'] as List<dynamic>?)
              ?.map((e) => ScarcityAllocationItemModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      demoNotice: json['demo_notice'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'plan_id': planId,
        'cycle_id': cycleId,
        'depot_id': depotId,
        'depot_name': depotName,
        'commodity': commodity,
        'aggregate_demand_kg': aggregateDemandKg,
        'available_depot_stock_kg': availableDepotStockKg,
        'deficit_kg': deficitKg,
        'deficit_percentage': deficitPercentage,
        'is_scarcity_condition': isScarcityCondition,
        'scarcity_condition': scarcityCondition,
        'statutory_floor_status': statutoryFloorStatus,
        'is_statutory_floor_satisfied': isStatutoryFloorSatisfied,
        'governance_alert': governanceAlert,
        'allocation_strategy': allocationStrategy,
        'total_statutory_floors_kg': totalStatutoryFloorsKg,
        'total_reconciled_allocation_kg': totalReconciledAllocationKg,
        'unallocated_depot_slack_kg': unallocatedDepotSlackKg,
        'average_cut_percentage': averageCutPercentage,
        'allocated_fps_count': allocatedFpsCount,
        'approval_status': approvalStatus,
        'risk_summary': riskSummary.toJson(),
        'allocated_items': allocatedItems.map((e) => e.toJson()).toList(),
        'demo_notice': demoNotice,
      };
}

/// 8. DSO Approval Execution Response Model
class ApprovePlanResponseModel {
  final String status;
  final String planId;
  final String approvalStatus;
  final String approvedBy;
  final String approvedAt;
  final String depotId;
  final String commodity;
  final double totalReconciledAllocationKg;
  final int allocatedFpsCount;
  final String message;
  final String demoNotice;

  ApprovePlanResponseModel({
    required this.status,
    required this.planId,
    required this.approvalStatus,
    required this.approvedBy,
    required this.approvedAt,
    required this.depotId,
    required this.commodity,
    required this.totalReconciledAllocationKg,
    required this.allocatedFpsCount,
    required this.message,
    required this.demoNotice,
  });

  factory ApprovePlanResponseModel.fromJson(Map<String, dynamic> json) {
    return ApprovePlanResponseModel(
      status: json['status'] ?? '',
      planId: json['plan_id'] ?? '',
      approvalStatus: json['approval_status'] ?? '',
      approvedBy: json['approved_by'] ?? '',
      approvedAt: json['approved_at'] ?? '',
      depotId: json['depot_id'] ?? '',
      commodity: json['commodity'] ?? '',
      totalReconciledAllocationKg:
          (json['total_reconciled_allocation_kg'] as num?)?.toDouble() ?? 0.0,
      allocatedFpsCount: json['allocated_fps_count'] ?? 0,
      message: json['message'] ?? '',
      demoNotice: json['demo_notice'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'status': status,
        'plan_id': planId,
        'approval_status': approvalStatus,
        'approved_by': approvedBy,
        'approved_at': approvedAt,
        'depot_id': depotId,
        'commodity': commodity,
        'total_reconciled_allocation_kg': totalReconciledAllocationKg,
        'allocated_fps_count': allocatedFpsCount,
        'message': message,
        'demo_notice': demoNotice,
      };
}

/// 9. Scarcity Immutable Audit Trail History Model
class ScarcityAuditTrailModel {
  final String status;
  final String planId;
  final String cycleId;
  final String depotId;
  final String commodity;
  final double aggregateDemandKg;
  final double availableStockKg;
  final double deficitKg;
  final String allocationStrategy;
  final String approvalStatus;
  final String? approvedBy;
  final String? approvalNotes;
  final String createdAt;
  final String? approvedAt;
  final int allocatedFpsCount;
  final List<ScarcityAllocationItemModel> allocatedItems;
  final String demoNotice;

  ScarcityAuditTrailModel({
    required this.status,
    required this.planId,
    required this.cycleId,
    required this.depotId,
    required this.commodity,
    required this.aggregateDemandKg,
    required this.availableStockKg,
    required this.deficitKg,
    required this.allocationStrategy,
    required this.approvalStatus,
    this.approvedBy,
    this.approvalNotes,
    required this.createdAt,
    this.approvedAt,
    required this.allocatedFpsCount,
    required this.allocatedItems,
    required this.demoNotice,
  });

  factory ScarcityAuditTrailModel.fromJson(Map<String, dynamic> json) {
    return ScarcityAuditTrailModel(
      status: json['status'] ?? '',
      planId: json['plan_id'] ?? '',
      cycleId: json['cycle_id'] ?? '',
      depotId: json['depot_id'] ?? '',
      commodity: json['commodity'] ?? '',
      aggregateDemandKg: (json['aggregate_demand_kg'] as num?)?.toDouble() ?? 0.0,
      availableStockKg: (json['available_stock_kg'] as num?)?.toDouble() ?? 0.0,
      deficitKg: (json['deficit_kg'] as num?)?.toDouble() ?? 0.0,
      allocationStrategy: json['allocation_strategy'] ?? '',
      approvalStatus: json['approval_status'] ?? '',
      approvedBy: json['approved_by'],
      approvalNotes: json['approval_notes'],
      createdAt: json['created_at'] ?? '',
      approvedAt: json['approved_at'],
      allocatedFpsCount: json['allocated_fps_count'] ?? 0,
      allocatedItems: (json['allocated_items'] as List<dynamic>?)
              ?.map((e) => ScarcityAllocationItemModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      demoNotice: json['demo_notice'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'status': status,
        'plan_id': planId,
        'cycle_id': cycleId,
        'depot_id': depotId,
        'commodity': commodity,
        'aggregate_demand_kg': aggregateDemandKg,
        'available_stock_kg': availableStockKg,
        'deficit_kg': deficitKg,
        'allocation_strategy': allocationStrategy,
        'approval_status': approvalStatus,
        'approved_by': approvedBy,
        'approval_notes': approvalNotes,
        'created_at': createdAt,
        'approved_at': approvedAt,
        'allocated_fps_count': allocatedFpsCount,
        'allocated_items': allocatedItems.map((e) => e.toJson()).toList(),
        'demo_notice': demoNotice,
      };
}
