/// Data Models for District Admin Dashboard in PDS DemandSync.

class AdminFpsRow {
  final String fpsId;
  final String name;
  final String district;
  final double latitude;
  final double longitude;
  final double capacityKg;
  final int registeredBeneficiaries;
  final double historicalDemandKg;
  final double declaredIntentKg;
  final double intentShiftKg;
  final double intentShiftPct;
  final double inventoryKg;
  final double inventoryUtilizationPct;
  final double forecastKg;
  final double recommendedDispatchKg;
  final double confidenceScore;
  final String riskLevel; // 'HIGH', 'MEDIUM', 'LOW'
  final String riskReason;
  final String status; // 'Planning', 'Draft', 'Locked'

  AdminFpsRow({
    required this.fpsId,
    required this.name,
    required this.district,
    required this.latitude,
    required this.longitude,
    required this.capacityKg,
    required this.registeredBeneficiaries,
    required this.historicalDemandKg,
    required this.declaredIntentKg,
    required this.intentShiftKg,
    required this.intentShiftPct,
    required this.inventoryKg,
    required this.inventoryUtilizationPct,
    required this.forecastKg,
    this.recommendedDispatchKg = 0.0,
    this.confidenceScore = 0.95,
    required this.riskLevel,
    required this.riskReason,
    required this.status,
  });

  factory AdminFpsRow.fromJson(Map<String, dynamic> json) {
    return AdminFpsRow(
      fpsId: json['fps_id'] ?? '',
      name: json['name'] ?? '',
      district: json['district'] ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      capacityKg: (json['capacity_kg'] as num?)?.toDouble() ?? 0.0,
      registeredBeneficiaries: json['registered_beneficiaries'] ?? 0,
      historicalDemandKg:
          (json['historical_demand_kg'] as num?)?.toDouble() ?? 0.0,
      declaredIntentKg:
          (json['declared_intent_kg'] as num?)?.toDouble() ?? 0.0,
      intentShiftKg: (json['intent_shift_kg'] as num?)?.toDouble() ?? 0.0,
      intentShiftPct: (json['intent_shift_pct'] as num?)?.toDouble() ?? 0.0,
      inventoryKg: (json['inventory_kg'] as num?)?.toDouble() ?? 0.0,
      inventoryUtilizationPct:
          (json['inventory_utilization_pct'] as num?)?.toDouble() ?? 0.0,
      forecastKg: (json['forecast_kg'] as num?)?.toDouble() ?? 0.0,
      recommendedDispatchKg:
          (json['recommended_dispatch_kg'] as num?)?.toDouble() ?? 0.0,
      confidenceScore:
          (json['confidence_score'] as num?)?.toDouble() ?? 0.95,
      riskLevel: json['risk_level'] ?? 'LOW',
      riskReason: json['risk_reason'] ?? '',
      status: json['status'] ?? 'Planning',
    );
  }
}

class DistrictHistoricalTrend {
  final String cycleId;
  final double riceKg;
  final double wheatKg;
  final double totalKg;

  DistrictHistoricalTrend({
    required this.cycleId,
    required this.riceKg,
    required this.wheatKg,
    required this.totalKg,
  });

  factory DistrictHistoricalTrend.fromJson(Map<String, dynamic> json) {
    return DistrictHistoricalTrend(
      cycleId: json['cycle_id'] ?? '',
      riceKg: (json['rice_kg'] as num?)?.toDouble() ?? 0.0,
      wheatKg: (json['wheat_kg'] as num?)?.toDouble() ?? 0.0,
      totalKg: (json['total_kg'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class AdminDashboardData {
  final String district;
  final String activeCycle;
  final int totalFps;
  final int activeIntentsCount;
  final double totalDeclaredIntentKg;
  final double totalHistoricalDemandKg;
  final double totalForecastDemandKg;
  final double totalRecommendedDispatchKg;
  final double averageConfidence;
  final int forecastGeneratedCount;
  final int highRiskFpsCount;
  final int mediumRiskFpsCount;
  final int lowRiskFpsCount;
  final int exceptionCasesCount;
  final double totalInventoryKg;
  final double totalCapacityKg;
  final double averageCapacityUtilizationPct;
  final Map<String, int> riskDistribution;
  final List<DistrictHistoricalTrend> historicalCyclesTrend;
  final List<Map<String, dynamic>> topIntentShiftFps;
  final List<AdminFpsRow> fpsList;
  final String workflowStatus;

  AdminDashboardData({
    required this.district,
    required this.activeCycle,
    required this.totalFps,
    required this.activeIntentsCount,
    required this.totalDeclaredIntentKg,
    this.totalHistoricalDemandKg = 0.0,
    this.totalForecastDemandKg = 0.0,
    this.totalRecommendedDispatchKg = 0.0,
    this.averageConfidence = 0.95,
    required this.forecastGeneratedCount,
    required this.highRiskFpsCount,
    required this.mediumRiskFpsCount,
    required this.lowRiskFpsCount,
    required this.exceptionCasesCount,
    required this.totalInventoryKg,
    required this.totalCapacityKg,
    required this.averageCapacityUtilizationPct,
    required this.riskDistribution,
    required this.historicalCyclesTrend,
    required this.topIntentShiftFps,
    required this.fpsList,
    required this.workflowStatus,
  });

  factory AdminDashboardData.fromJson(Map<String, dynamic> json) {
    return AdminDashboardData(
      district: json['district'] ?? 'Bengaluru Urban PDS Pilot',
      activeCycle: json['active_cycle'] ?? '2026-09',
      totalFps: json['total_fps'] ?? 0,
      activeIntentsCount: json['active_intents_count'] ?? 0,
      totalDeclaredIntentKg:
          (json['total_declared_intent_kg'] as num?)?.toDouble() ?? 0.0,
      totalHistoricalDemandKg:
          (json['total_historical_demand_kg'] as num?)?.toDouble() ?? 0.0,
      totalForecastDemandKg:
          (json['total_forecast_demand_kg'] as num?)?.toDouble() ?? 0.0,
      totalRecommendedDispatchKg:
          (json['total_recommended_dispatch_kg'] as num?)?.toDouble() ?? 0.0,
      averageConfidence:
          (json['average_confidence'] as num?)?.toDouble() ?? 0.95,
      forecastGeneratedCount: json['forecast_generated_count'] ?? 0,
      highRiskFpsCount: json['high_risk_fps_count'] ?? 0,
      mediumRiskFpsCount: json['medium_risk_fps_count'] ?? 0,
      lowRiskFpsCount: json['low_risk_fps_count'] ?? 0,
      exceptionCasesCount: json['exception_cases_count'] ?? 0,
      totalInventoryKg:
          (json['total_inventory_kg'] as num?)?.toDouble() ?? 0.0,
      totalCapacityKg: (json['total_capacity_kg'] as num?)?.toDouble() ?? 0.0,
      averageCapacityUtilizationPct:
          (json['average_capacity_utilization_pct'] as num?)?.toDouble() ?? 0.0,
      riskDistribution:
          Map<String, int>.from(json['risk_distribution'] ?? {}),
      historicalCyclesTrend: (json['historical_cycles_trend'] as List<dynamic>?)
              ?.map((e) => DistrictHistoricalTrend.fromJson(e))
              .toList() ??
          [],
      topIntentShiftFps: (json['top_intent_shift_fps'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e))
              .toList() ??
          [],
      fpsList: (json['fps_list'] as List<dynamic>?)
              ?.map((e) => AdminFpsRow.fromJson(e))
              .toList() ??
          [],
      workflowStatus: json['workflow_status'] ?? 'PLANNING_OPEN',
    );
  }
}

class AdminFpsDetail {
  final String fpsId;
  final String name;
  final String district;
  final double latitude;
  final double longitude;
  final double capacityKg;
  final int registeredBeneficiaries;
  final double historicalDemandKg;
  final double declaredIntentKg;
  final double intentShiftKg;
  final double inventoryKg;
  final double inventoryUtilizationPct;
  final double forecastKg;
  final double recommendedDispatchKg;
  final double confidenceScore;
  final String riskLevel;
  final String riskReason;
  final String status;
  final String? formulaExplanation;
  final Map<String, dynamic>? forecastBreakdown;
  final List<Map<String, dynamic>> historicalRecords;
  final List<Map<String, dynamic>> riceTrendKg;
  final List<Map<String, dynamic>> wheatTrendKg;
  final int intentHomeCount;
  final int intentPortabilityCount;
  final Map<String, dynamic> intentCommodities;
  final List<Map<String, dynamic>> inventoryItems;

  AdminFpsDetail({
    required this.fpsId,
    required this.name,
    required this.district,
    required this.latitude,
    required this.longitude,
    required this.capacityKg,
    required this.registeredBeneficiaries,
    required this.historicalDemandKg,
    required this.declaredIntentKg,
    required this.intentShiftKg,
    required this.inventoryKg,
    required this.inventoryUtilizationPct,
    required this.forecastKg,
    this.recommendedDispatchKg = 0.0,
    this.confidenceScore = 0.95,
    required this.riskLevel,
    required this.riskReason,
    required this.status,
    this.formulaExplanation,
    this.forecastBreakdown,
    required this.historicalRecords,
    required this.riceTrendKg,
    required this.wheatTrendKg,
    required this.intentHomeCount,
    required this.intentPortabilityCount,
    required this.intentCommodities,
    required this.inventoryItems,
  });

  factory AdminFpsDetail.fromJson(Map<String, dynamic> json) {
    return AdminFpsDetail(
      fpsId: json['fps_id'] ?? '',
      name: json['name'] ?? '',
      district: json['district'] ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      capacityKg: (json['capacity_kg'] as num?)?.toDouble() ?? 0.0,
      registeredBeneficiaries: json['registered_beneficiaries'] ?? 0,
      historicalDemandKg:
          (json['historical_demand_kg'] as num?)?.toDouble() ?? 0.0,
      declaredIntentKg:
          (json['declared_intent_kg'] as num?)?.toDouble() ?? 0.0,
      intentShiftKg: (json['intent_shift_kg'] as num?)?.toDouble() ?? 0.0,
      inventoryKg: (json['inventory_kg'] as num?)?.toDouble() ?? 0.0,
      inventoryUtilizationPct:
          (json['inventory_utilization_pct'] as num?)?.toDouble() ?? 0.0,
      forecastKg: (json['forecast_kg'] as num?)?.toDouble() ?? 0.0,
      recommendedDispatchKg:
          (json['recommended_dispatch_kg'] as num?)?.toDouble() ?? 0.0,
      confidenceScore:
          (json['confidence_score'] as num?)?.toDouble() ?? 0.95,
      riskLevel: json['risk_level'] ?? 'LOW',
      riskReason: json['risk_reason'] ?? '',
      status: json['status'] ?? 'Planning',
      formulaExplanation: json['formula_explanation'],
      forecastBreakdown: json['forecast_breakdown'] != null
          ? Map<String, dynamic>.from(json['forecast_breakdown'])
          : null,
      historicalRecords: (json['historical_records'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e))
              .toList() ??
          [],
      riceTrendKg: (json['rice_trend_kg'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e))
              .toList() ??
          [],
      wheatTrendKg: (json['wheat_trend_kg'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e))
              .toList() ??
          [],
      intentHomeCount: json['intent_home_count'] ?? 0,
      intentPortabilityCount: json['intent_portability_count'] ?? 0,
      intentCommodities:
          Map<String, dynamic>.from(json['intent_commodities'] ?? {}),
      inventoryItems: (json['inventory_items'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e))
              .toList() ??
          [],
    );
  }
}

// ----------------- Dispatch Models (Phase 5) ----------------- //

class DispatchRecord {
  final int id;
  final int? forecastId;
  final String fpsId;
  final String fpsName;
  final String cycleId;
  final String commodity;
  final double quantityKg;
  final String demoTruckId;
  final String sourceGodown;
  final String status;
  final String createdAt;

  DispatchRecord({
    required this.id,
    this.forecastId,
    required this.fpsId,
    required this.fpsName,
    required this.cycleId,
    required this.commodity,
    required this.quantityKg,
    required this.demoTruckId,
    required this.sourceGodown,
    required this.status,
    required this.createdAt,
  });

  factory DispatchRecord.fromJson(Map<String, dynamic> json) {
    return DispatchRecord(
      id: json['id'] ?? 0,
      forecastId: json['forecast_id'],
      fpsId: json['fps_id'] ?? '',
      fpsName: json['fps_name'] ?? json['fps_id'] ?? '',
      cycleId: json['cycle_id'] ?? '2026-09',
      commodity: json['commodity'] ?? 'Rice',
      quantityKg: (json['quantity_kg'] as num?)?.toDouble() ?? 0.0,
      demoTruckId: json['demo_truck_id'] ?? '',
      sourceGodown: json['source_godown'] ?? '',
      status: json['status'] ?? 'DISPATCH_PLANNED',
      createdAt: json['created_at']?.toString() ?? '',
    );
  }
}

class VehicleDeliveryStop {
  final String fpsId;
  final String fpsName;
  final double riceKg;
  final double wheatKg;
  final double totalKg;

  VehicleDeliveryStop({
    required this.fpsId,
    required this.fpsName,
    required this.riceKg,
    required this.wheatKg,
    required this.totalKg,
  });

  factory VehicleDeliveryStop.fromJson(Map<String, dynamic> json) {
    return VehicleDeliveryStop(
      fpsId: json['fps_id'] ?? '',
      fpsName: json['fps_name'] ?? '',
      riceKg: (json['rice_kg'] as num?)?.toDouble() ?? 0.0,
      wheatKg: (json['wheat_kg'] as num?)?.toDouble() ?? 0.0,
      totalKg: (json['total_kg'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class VehicleManifest {
  final String truckId;
  final String sourceGodown;
  final String routeName;
  final double totalPayloadKg;
  final double totalPayloadMt;
  final int stopsCount;
  final List<VehicleDeliveryStop> deliveryStops;

  VehicleManifest({
    required this.truckId,
    required this.sourceGodown,
    required this.routeName,
    required this.totalPayloadKg,
    required this.totalPayloadMt,
    required this.stopsCount,
    required this.deliveryStops,
  });

  factory VehicleManifest.fromJson(Map<String, dynamic> json) {
    return VehicleManifest(
      truckId: json['truck_id'] ?? '',
      sourceGodown: json['source_godown'] ?? '',
      routeName: json['route_name'] ?? '',
      totalPayloadKg: (json['total_payload_kg'] as num?)?.toDouble() ?? 0.0,
      totalPayloadMt: (json['total_payload_mt'] as num?)?.toDouble() ?? 0.0,
      stopsCount: json['stops_count'] ?? 0,
      deliveryStops: (json['delivery_stops'] as List<dynamic>?)
              ?.map((e) => VehicleDeliveryStop.fromJson(e))
              .toList() ??
          [],
    );
  }
}

class DispatchManifestData {
  final String status;
  final String workflowStatus;
  final String cycleId;
  final double totalDispatchKg;
  final double totalRiceDispatchKg;
  final double totalWheatDispatchKg;
  final int totalFpsCount;
  final int totalVehiclesCount;
  final List<VehicleManifest> vehicles;
  final List<DispatchRecord> records;
  final String message;

  DispatchManifestData({
    required this.status,
    required this.workflowStatus,
    required this.cycleId,
    required this.totalDispatchKg,
    required this.totalRiceDispatchKg,
    required this.totalWheatDispatchKg,
    required this.totalFpsCount,
    required this.totalVehiclesCount,
    required this.vehicles,
    required this.records,
    required this.message,
  });

  factory DispatchManifestData.fromJson(Map<String, dynamic> json) {
    return DispatchManifestData(
      status: json['status'] ?? 'success',
      workflowStatus: json['workflow_status'] ?? 'DISPATCH_GENERATED',
      cycleId: json['cycle_id'] ?? '2026-09',
      totalDispatchKg: (json['total_dispatch_kg'] as num?)?.toDouble() ?? 0.0,
      totalRiceDispatchKg:
          (json['total_rice_dispatch_kg'] as num?)?.toDouble() ?? 0.0,
      totalWheatDispatchKg:
          (json['total_wheat_dispatch_kg'] as num?)?.toDouble() ?? 0.0,
      totalFpsCount: json['total_fps_count'] ?? 0,
      totalVehiclesCount: json['total_vehicles_count'] ?? 0,
      vehicles: (json['vehicles'] as List<dynamic>?)
              ?.map((e) => VehicleManifest.fromJson(e))
              .toList() ??
          [],
      records: (json['records'] as List<dynamic>?)
              ?.map((e) => DispatchRecord.fromJson(e))
              .toList() ??
          [],
      message: json['message'] ?? '',
    );
  }
}

// ----------------- Phase 6: Distribution, Evaluation & Calibration Models ----------------- //

class ActualDistributionRecord {
  final int id;
  final String fpsId;
  final String fpsName;
  final String cycleId;
  final String commodity;
  final double dispatchQuantityKg;
  final double actualQuantityKg;
  final double varianceKg;
  final double variancePct;
  final String status;
  final String createdAt;

  ActualDistributionRecord({
    required this.id,
    required this.fpsId,
    required this.fpsName,
    required this.cycleId,
    required this.commodity,
    required this.dispatchQuantityKg,
    required this.actualQuantityKg,
    required this.varianceKg,
    required this.variancePct,
    required this.status,
    required this.createdAt,
  });

  factory ActualDistributionRecord.fromJson(Map<String, dynamic> json) {
    return ActualDistributionRecord(
      id: json['id'] ?? 0,
      fpsId: json['fps_id'] ?? '',
      fpsName: json['fps_name'] ?? json['fps_id'] ?? '',
      cycleId: json['cycle_id'] ?? '2026-09',
      commodity: json['commodity'] ?? 'Rice',
      dispatchQuantityKg:
          (json['dispatch_quantity_kg'] as num?)?.toDouble() ?? 0.0,
      actualQuantityKg: (json['actual_quantity_kg'] as num?)?.toDouble() ?? 0.0,
      varianceKg: (json['variance_kg'] as num?)?.toDouble() ?? 0.0,
      variancePct: (json['variance_pct'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] ?? 'DISTRIBUTED',
      createdAt: json['created_at']?.toString() ?? '',
    );
  }
}

class EvaluationFpsItemData {
  final String fpsId;
  final String fpsName;
  final String commodity;
  final double forecastQuantityKg;
  final double actualQuantityKg;
  final double absoluteErrorKg;
  final double percentageError;
  final double accuracyPct;

  EvaluationFpsItemData({
    required this.fpsId,
    required this.fpsName,
    required this.commodity,
    required this.forecastQuantityKg,
    required this.actualQuantityKg,
    required this.absoluteErrorKg,
    required this.percentageError,
    required this.accuracyPct,
  });

  factory EvaluationFpsItemData.fromJson(Map<String, dynamic> json) {
    return EvaluationFpsItemData(
      fpsId: json['fps_id'] ?? '',
      fpsName: json['fps_name'] ?? '',
      commodity: json['commodity'] ?? '',
      forecastQuantityKg:
          (json['forecast_quantity_kg'] as num?)?.toDouble() ?? 0.0,
      actualQuantityKg: (json['actual_quantity_kg'] as num?)?.toDouble() ?? 0.0,
      absoluteErrorKg: (json['absolute_error_kg'] as num?)?.toDouble() ?? 0.0,
      percentageError: (json['percentage_error'] as num?)?.toDouble() ?? 0.0,
      accuracyPct: (json['accuracy_pct'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class ForecastEvaluationData {
  final String status;
  final String workflowStatus;
  final String cycleId;
  final int recordsEvaluatedCount;
  final double totalForecastQuantityKg;
  final double totalActualQuantityKg;
  final double totalAbsoluteErrorKg;
  final double maeKg;
  final double mapePct;
  final double overallAccuracyPct;
  final double riceMapePct;
  final double wheatMapePct;
  final Map<String, dynamic> commodityBreakdown;
  final List<EvaluationFpsItemData> fpsEvaluations;
  final String message;

  ForecastEvaluationData({
    required this.status,
    required this.workflowStatus,
    required this.cycleId,
    required this.recordsEvaluatedCount,
    required this.totalForecastQuantityKg,
    required this.totalActualQuantityKg,
    required this.totalAbsoluteErrorKg,
    required this.maeKg,
    required this.mapePct,
    required this.overallAccuracyPct,
    required this.riceMapePct,
    required this.wheatMapePct,
    required this.commodityBreakdown,
    required this.fpsEvaluations,
    required this.message,
  });

  factory ForecastEvaluationData.fromJson(Map<String, dynamic> json) {
    return ForecastEvaluationData(
      status: json['status'] ?? 'success',
      workflowStatus: json['workflow_status'] ?? 'FORECAST_EVALUATED',
      cycleId: json['cycle_id'] ?? '2026-09',
      recordsEvaluatedCount: json['records_evaluated_count'] ?? 0,
      totalForecastQuantityKg:
          (json['total_forecast_quantity_kg'] as num?)?.toDouble() ?? 0.0,
      totalActualQuantityKg:
          (json['total_actual_quantity_kg'] as num?)?.toDouble() ?? 0.0,
      totalAbsoluteErrorKg:
          (json['total_absolute_error_kg'] as num?)?.toDouble() ?? 0.0,
      maeKg: (json['mae_kg'] as num?)?.toDouble() ?? 0.0,
      mapePct: (json['mape_pct'] as num?)?.toDouble() ?? 0.0,
      overallAccuracyPct:
          (json['overall_accuracy_pct'] as num?)?.toDouble() ?? 0.0,
      riceMapePct: (json['rice_mape_pct'] as num?)?.toDouble() ?? 0.0,
      wheatMapePct: (json['wheat_mape_pct'] as num?)?.toDouble() ?? 0.0,
      commodityBreakdown:
          Map<String, dynamic>.from(json['commodity_breakdown'] ?? {}),
      fpsEvaluations: (json['fps_evaluations'] as List<dynamic>?)
              ?.map((e) => EvaluationFpsItemData.fromJson(e))
              .toList() ??
          [],
      message: json['message'] ?? '',
    );
  }
}

class ModelCalibrationData {
  final String status;
  final String workflowStatus;
  final String cycleId;
  final String targetFutureCycle;
  final String algorithm;
  final String modelVersion;
  final double previousWeight;
  final double calibratedWeight;
  final double beforeMape;
  final double afterMape;
  final int recordsTrained;
  final List<String> trainingFeatures;
  final String message;

  ModelCalibrationData({
    required this.status,
    required this.workflowStatus,
    required this.cycleId,
    required this.targetFutureCycle,
    required this.algorithm,
    required this.modelVersion,
    required this.previousWeight,
    required this.calibratedWeight,
    required this.beforeMape,
    required this.afterMape,
    required this.recordsTrained,
    required this.trainingFeatures,
    required this.message,
  });

  factory ModelCalibrationData.fromJson(Map<String, dynamic> json) {
    return ModelCalibrationData(
      status: json['status'] ?? 'success',
      workflowStatus: json['workflow_status'] ?? 'MODEL_CALIBRATED',
      cycleId: json['cycle_id'] ?? '2026-09',
      targetFutureCycle: json['target_future_cycle'] ?? '2026-10',
      algorithm: json['algorithm'] ?? 'Ridge Regression',
      modelVersion: json['model_version'] ?? 'v1.1-calibrated',
      previousWeight: (json['previous_weight'] as num?)?.toDouble() ?? 0.65,
      calibratedWeight:
          (json['calibrated_weight'] as num?)?.toDouble() ?? 0.72,
      beforeMape: (json['before_mape'] as num?)?.toDouble() ?? 0.0,
      afterMape: (json['after_mape'] as num?)?.toDouble() ?? 0.0,
      recordsTrained: json['records_trained'] ?? 0,
      trainingFeatures: (json['training_features'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      message: json['message'] ?? '',
    );
  }
}


// ─────────────────────────────────────────────────────────────────────────────
// PRE-DISPATCH DECISION INTELLIGENCE DATA MODELS
// ─────────────────────────────────────────────────────────────────────────────

class ConstraintCheckItem {
  final String rule;
  final String ruleId;
  final String name;
  final String status; // 'PASS', 'FAIL', 'WARNING'
  final String severity;
  final String actualValue;
  final String requiredValue;
  final String explanation;
  final String message;
  final String? recommendation;
  final String? suggestedResolution;
  final String? metric;
  final List<String> resolutionActions;

  ConstraintCheckItem({
    required this.rule,
    required this.ruleId,
    required this.name,
    required this.status,
    this.severity = 'CRITICAL',
    this.actualValue = '',
    this.requiredValue = '',
    this.explanation = '',
    required this.message,
    this.recommendation,
    this.suggestedResolution,
    this.metric,
    this.resolutionActions = const [],
  });

  factory ConstraintCheckItem.fromJson(Map<String, dynamic> json) {
    final actions = (json['resolution_actions'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];
    final rId = json['rule_id']?.toString() ?? json['rule']?.toString() ?? '';
    final expl = json['explanation']?.toString() ?? json['message']?.toString() ?? '';
    final rec = json['suggested_resolution']?.toString() ?? json['recommendation']?.toString();
    final actual = json['actual_value']?.toString() ?? json['metric']?.toString() ?? '';

    return ConstraintCheckItem(
      rule: rId,
      ruleId: rId,
      name: json['name'] ?? '',
      status: json['status'] ?? 'PASS',
      severity: json['severity'] ?? 'CRITICAL',
      actualValue: actual,
      requiredValue: json['required_value']?.toString() ?? '',
      explanation: expl,
      message: expl,
      recommendation: rec,
      suggestedResolution: rec,
      metric: actual,
      resolutionActions: actions,
    );
  }
}

class FpsConstraintResult {
  final String fpsId;
  final String fpsName;
  final String overallStatus;
  final double capacityKg;
  final double currentInventoryKg;
  final double recommendedDispatchKg;
  final double storageHeadroomKg;
  final double postDispatchStockKg;
  final List<ConstraintCheckItem> checks;

  FpsConstraintResult({
    required this.fpsId,
    required this.fpsName,
    required this.overallStatus,
    required this.capacityKg,
    required this.currentInventoryKg,
    required this.recommendedDispatchKg,
    required this.storageHeadroomKg,
    required this.postDispatchStockKg,
    required this.checks,
  });

  factory FpsConstraintResult.fromJson(Map<String, dynamic> json) {
    return FpsConstraintResult(
      fpsId: json['fps_id'] ?? '',
      fpsName: json['fps_name'] ?? '',
      overallStatus: json['overall_status'] ?? 'PASS',
      capacityKg: (json['capacity_kg'] as num?)?.toDouble() ?? 0.0,
      currentInventoryKg:
          (json['current_inventory_kg'] as num?)?.toDouble() ?? 0.0,
      recommendedDispatchKg:
          (json['recommended_dispatch_kg'] as num?)?.toDouble() ?? 0.0,
      storageHeadroomKg:
          (json['storage_headroom_kg'] as num?)?.toDouble() ?? 0.0,
      postDispatchStockKg:
          (json['post_dispatch_stock_kg'] as num?)?.toDouble() ?? 0.0,
      checks: (json['checks'] as List<dynamic>?)
              ?.map((e) => ConstraintCheckItem.fromJson(e))
              .toList() ??
          [],
    );
  }
}

class FleetConstraintEvaluation {
  final String truckId;
  final String model;
  final String corridor;
  final String sourceDepot;
  final double totalPayloadKg;
  final double maxPayloadKg;
  final double payloadUtilizationPct;
  final List<ConstraintCheckItem> checks;

  FleetConstraintEvaluation({
    required this.truckId,
    required this.model,
    required this.corridor,
    required this.sourceDepot,
    required this.totalPayloadKg,
    required this.maxPayloadKg,
    required this.payloadUtilizationPct,
    required this.checks,
  });

  factory FleetConstraintEvaluation.fromJson(Map<String, dynamic> json) {
    return FleetConstraintEvaluation(
      truckId: json['truck_id'] ?? '',
      model: json['model'] ?? '',
      corridor: json['corridor'] ?? '',
      sourceDepot: json['source_depot'] ?? '',
      totalPayloadKg: (json['total_payload_kg'] as num?)?.toDouble() ?? 0.0,
      maxPayloadKg: (json['max_payload_kg'] as num?)?.toDouble() ?? 0.0,
      payloadUtilizationPct:
          (json['payload_utilization_pct'] as num?)?.toDouble() ?? 0.0,
      checks: (json['checks'] as List<dynamic>?)
              ?.map((e) => ConstraintCheckItem.fromJson(e))
              .toList() ??
          [],
    );
  }
}

class DistrictConstraintAudit {
  final String status;
  final String districtValidationStatus; // 'PASS', 'FAIL', 'WARNING'
  final String cycleId;
  final int totalFpsAudited;
  final int passCount;
  final int warningCount;
  final int failCount;
  final String summaryMessage;
  final List<FpsConstraintResult> fpsEvaluations;
  final List<FleetConstraintEvaluation> fleetEvaluations;

  DistrictConstraintAudit({
    required this.status,
    required this.districtValidationStatus,
    required this.cycleId,
    required this.totalFpsAudited,
    required this.passCount,
    required this.warningCount,
    required this.failCount,
    required this.summaryMessage,
    required this.fpsEvaluations,
    required this.fleetEvaluations,
  });

  factory DistrictConstraintAudit.fromJson(Map<String, dynamic> json) {
    return DistrictConstraintAudit(
      status: json['status'] ?? 'success',
      districtValidationStatus: json['district_validation_status'] ?? 'PASS',
      cycleId: json['cycle_id'] ?? '2026-09',
      totalFpsAudited: json['total_fps_audited'] ?? 0,
      passCount: json['pass_count'] ?? 0,
      warningCount: json['warning_count'] ?? 0,
      failCount: json['fail_count'] ?? 0,
      summaryMessage: json['summary_message'] ?? '',
      fpsEvaluations: (json['fps_evaluations'] as List<dynamic>?)
              ?.map((e) => FpsConstraintResult.fromJson(e))
              .toList() ??
          [],
      fleetEvaluations: (json['fleet_evaluations'] as List<dynamic>?)
              ?.map((e) => FleetConstraintEvaluation.fromJson(e))
              .toList() ??
          [],
    );
  }
}

class OptimizedStop {
  final int sequenceOrder;
  final String fpsId;
  final String fpsName;
  final String district;
  final double latitude;
  final double longitude;
  final double legDistanceKm;
  final double cumulativeDistanceKm;
  final String timeWindow;
  final String estimatedArrivalWindow;
  final double riceKg;
  final double wheatKg;
  final double totalDropKg;
  final double excessStockRiskIndex;

  OptimizedStop({
    required this.sequenceOrder,
    required this.fpsId,
    required this.fpsName,
    this.district = '',
    this.latitude = 0.0,
    this.longitude = 0.0,
    required this.legDistanceKm,
    required this.cumulativeDistanceKm,
    this.timeWindow = '',
    this.estimatedArrivalWindow = '',
    required this.riceKg,
    required this.wheatKg,
    required this.totalDropKg,
    this.excessStockRiskIndex = 0.0,
  });

  factory OptimizedStop.fromJson(Map<String, dynamic> json) {
    final win = json['estimated_arrival_window']?.toString() ??
        json['time_window']?.toString() ??
        '';
    return OptimizedStop(
      sequenceOrder: json['sequence_order'] ?? 1,
      fpsId: json['fps_id'] ?? '',
      fpsName: json['fps_name'] ?? '',
      district: json['district'] ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      legDistanceKm: (json['leg_distance_km'] as num?)?.toDouble() ?? 0.0,
      cumulativeDistanceKm:
          (json['cumulative_distance_km'] as num?)?.toDouble() ?? 0.0,
      timeWindow: win,
      estimatedArrivalWindow: win,
      riceKg: (json['rice_kg'] as num?)?.toDouble() ?? 0.0,
      wheatKg: (json['wheat_kg'] as num?)?.toDouble() ?? 0.0,
      totalDropKg: (json['total_drop_kg'] as num?)?.toDouble() ?? 0.0,
      excessStockRiskIndex:
          (json['excess_stock_risk_index'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class CorridorOptimization {
  final String truckId;
  final String corridor;
  final String vehicleModel;
  final String sourceDepot;
  final int totalStopsCount;
  final double totalPayloadKg;
  final double maxPayloadKg;
  final double payloadUtilizationPct;
  final double totalRoundtripDistanceKm;
  final double estimatedTransitHours;
  final double estimatedTransportCostInr;
  final double optimizationScore;
  final String dispatchWindow;
  final List<OptimizedStop> optimizedStops;

  CorridorOptimization({
    required this.truckId,
    required this.corridor,
    required this.vehicleModel,
    required this.sourceDepot,
    required this.totalStopsCount,
    required this.totalPayloadKg,
    required this.maxPayloadKg,
    required this.payloadUtilizationPct,
    required this.totalRoundtripDistanceKm,
    required this.estimatedTransitHours,
    required this.estimatedTransportCostInr,
    required this.optimizationScore,
    required this.dispatchWindow,
    required this.optimizedStops,
  });

  factory CorridorOptimization.fromJson(Map<String, dynamic> json) {
    return CorridorOptimization(
      truckId: json['truck_id'] ?? '',
      corridor: json['corridor'] ?? '',
      vehicleModel: json['vehicle_model'] ?? '',
      sourceDepot: json['source_depot'] ?? '',
      totalStopsCount: json['total_stops_count'] ?? 0,
      totalPayloadKg: (json['total_payload_kg'] as num?)?.toDouble() ?? 0.0,
      maxPayloadKg: (json['max_payload_kg'] as num?)?.toDouble() ?? 0.0,
      payloadUtilizationPct:
          (json['payload_utilization_pct'] as num?)?.toDouble() ?? 0.0,
      totalRoundtripDistanceKm:
          (json['total_roundtrip_distance_km'] as num?)?.toDouble() ?? 0.0,
      estimatedTransitHours:
          (json['estimated_transit_hours'] as num?)?.toDouble() ?? 0.0,
      estimatedTransportCostInr:
          (json['estimated_transport_cost_inr'] as num?)?.toDouble() ?? 0.0,
      optimizationScore:
          (json['optimization_score'] as num?)?.toDouble() ?? 0.0,
      dispatchWindow: json['dispatch_window'] ?? '',
      optimizedStops: (json['optimized_stops'] as List<dynamic>?)
              ?.map((e) => OptimizedStop.fromJson(e))
              .toList() ??
          [],
    );
  }
}

class DistrictOptimizationResult {
  final String status;
  final String cycleId;
  final int totalVehiclesOptimized;
  final double totalDistrictDistanceKm;
  final double totalTransportCostInr;
  final double totalAllocatedPayloadKg;
  final double averageOptimizationScore;
  final List<CorridorOptimization> corridorOptimizations;

  DistrictOptimizationResult({
    required this.status,
    required this.cycleId,
    required this.totalVehiclesOptimized,
    required this.totalDistrictDistanceKm,
    required this.totalTransportCostInr,
    required this.totalAllocatedPayloadKg,
    required this.averageOptimizationScore,
    required this.corridorOptimizations,
  });

  factory DistrictOptimizationResult.fromJson(Map<String, dynamic> json) {
    return DistrictOptimizationResult(
      status: json['status'] ?? 'success',
      cycleId: json['cycle_id'] ?? '2026-09',
      totalVehiclesOptimized: json['total_vehicles_optimized'] ?? 0,
      totalDistrictDistanceKm:
          (json['total_district_distance_km'] as num?)?.toDouble() ?? 0.0,
      totalTransportCostInr:
          (json['total_transport_cost_inr'] as num?)?.toDouble() ?? 0.0,
      totalAllocatedPayloadKg:
          (json['total_allocated_payload_kg'] as num?)?.toDouble() ?? 0.0,
      averageOptimizationScore:
          (json['average_optimization_score'] as num?)?.toDouble() ?? 0.0,
      corridorOptimizations: (json['corridor_optimizations'] as List<dynamic>?)
              ?.map((e) => CorridorOptimization.fromJson(e))
              .toList() ??
          [],
    );
  }
}

class WeighbridgeSlip {
  final String slipNumber;
  final double tareWeightKg;
  final double grossWeightKg;
  final double netPayloadKg;
  final String scaleStatus;

  WeighbridgeSlip({
    required this.slipNumber,
    required this.tareWeightKg,
    required this.grossWeightKg,
    required this.netPayloadKg,
    required this.scaleStatus,
  });

  factory WeighbridgeSlip.fromJson(Map<String, dynamic> json) {
    return WeighbridgeSlip(
      slipNumber: json['slip_number'] ?? '',
      tareWeightKg: (json['tare_weight_kg'] as num?)?.toDouble() ?? 0.0,
      grossWeightKg: (json['gross_weight_kg'] as num?)?.toDouble() ?? 0.0,
      netPayloadKg: (json['net_payload_kg'] as num?)?.toDouble() ?? 0.0,
      scaleStatus: json['scale_status'] ?? 'CALIBRATED_VERIFIED',
    );
  }
}

class GatepassTimelineItem {
  final String stage;
  final String title;
  final String officer;
  final String actorRole;
  final String actorName;
  final String referenceId;
  final String status;
  final String timestamp;

  GatepassTimelineItem({
    required this.stage,
    required this.title,
    required this.officer,
    this.actorRole = '',
    this.actorName = '',
    this.referenceId = '',
    required this.status,
    required this.timestamp,
  });

  factory GatepassTimelineItem.fromJson(Map<String, dynamic> json) {
    final actName = json['actor_name'] ?? json['officer'] ?? '';
    return GatepassTimelineItem(
      stage: json['stage'] ?? '',
      title: json['title'] ?? '',
      officer: json['officer'] ?? actName,
      actorRole: json['actor_role'] ?? '',
      actorName: actName,
      referenceId: json['reference_id'] ?? '',
      status: json['status'] ?? 'PENDING',
      timestamp: json['timestamp'] ?? '',
    );
  }
}

class DeliveryStopItem {
  final String fpsId;
  final String fpsName;
  final double riceKg;
  final double wheatKg;
  final double totalKg;

  DeliveryStopItem({
    required this.fpsId,
    required this.fpsName,
    required this.riceKg,
    required this.wheatKg,
    required this.totalKg,
  });

  factory DeliveryStopItem.fromJson(Map<String, dynamic> json) {
    return DeliveryStopItem(
      fpsId: json['fps_id'] ?? '',
      fpsName: json['fps_name'] ?? '',
      riceKg: (json['rice_kg'] as num?)?.toDouble() ?? 0.0,
      wheatKg: (json['wheat_kg'] as num?)?.toDouble() ?? 0.0,
      totalKg: (json['total_kg'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class DigitalGatepass {
  final String gatepassId;
  final String cycleId;
  final String manifestId;
  final String truckId;
  final String truckModel;
  final String corridor;
  final String status;
  final String sourceDepotId;
  final String depotName;
  final String depotLocation;
  final String loadingBay;
  final String loadingWindow;
  final String driverName;
  final String driverPhone;
  final String securityToken;
  final String approvingOfficer;
  final double totalRiceKg;
  final double totalWheatKg;
  final double totalPayloadKg;
  final WeighbridgeSlip? weighbridgeSlip;
  final List<DeliveryStopItem> deliveryStops;
  final List<GatepassTimelineItem> eventTimeline;
  final String qrVerificationString;
  final String demoDisclaimer;

  DigitalGatepass({
    required this.gatepassId,
    required this.cycleId,
    required this.manifestId,
    required this.truckId,
    this.truckModel = 'Eicher Pro 10 MT',
    required this.corridor,
    required this.status,
    required this.sourceDepotId,
    required this.depotName,
    required this.depotLocation,
    required this.loadingBay,
    this.loadingWindow = '07:30 AM – 08:15 AM (Morning Priority Slot)',
    required this.driverName,
    required this.driverPhone,
    required this.securityToken,
    required this.approvingOfficer,
    required this.totalRiceKg,
    required this.totalWheatKg,
    required this.totalPayloadKg,
    this.weighbridgeSlip,
    required this.deliveryStops,
    required this.eventTimeline,
    required this.qrVerificationString,
    this.demoDisclaimer = 'PROTOTYPE / SIMULATED DIGITAL GATEPASS — NOT AN OFFICIAL GOVERNMENT DOCUMENT',
  });

  factory DigitalGatepass.fromJson(Map<String, dynamic> json) {
    return DigitalGatepass(
      gatepassId: json['gatepass_id'] ?? '',
      cycleId: json['cycle_id'] ?? '',
      manifestId: json['manifest_id'] ?? '',
      truckId: json['truck_id'] ?? '',
      truckModel: json['truck_model'] ?? 'Eicher Pro 10 MT',
      corridor: json['corridor'] ?? '',
      status: json['status'] ?? 'GATEPASS_ISSUED',
      sourceDepotId: json['source_depot_id'] ?? '',
      depotName: json['depot_name'] ?? '',
      depotLocation: json['depot_location'] ?? '',
      loadingBay: json['loading_bay'] ?? 'Bay-01',
      loadingWindow: json['loading_window'] ?? '07:30 AM – 08:15 AM (Morning Priority Slot)',
      driverName: json['driver_name'] ?? '',
      driverPhone: json['driver_phone'] ?? '',
      securityToken: json['security_token'] ?? '',
      approvingOfficer: json['approving_officer'] ?? '',
      totalRiceKg: (json['total_rice_kg'] as num?)?.toDouble() ?? 0.0,
      totalWheatKg: (json['total_wheat_kg'] as num?)?.toDouble() ?? 0.0,
      totalPayloadKg: (json['total_payload_kg'] as num?)?.toDouble() ?? 0.0,
      weighbridgeSlip: json['weighbridge_slip'] != null
          ? WeighbridgeSlip.fromJson(json['weighbridge_slip'])
          : null,
      deliveryStops: (json['delivery_stops'] as List<dynamic>?)
              ?.map((e) => DeliveryStopItem.fromJson(e))
              .toList() ??
          [],
      eventTimeline: (json['event_timeline'] as List<dynamic>?)
              ?.map((e) => GatepassTimelineItem.fromJson(e))
              .toList() ??
          [],
      qrVerificationString: json['qr_verification_string'] ?? '',
      demoDisclaimer: json['demo_disclaimer'] ?? 'PROTOTYPE / SIMULATED DIGITAL GATEPASS — NOT AN OFFICIAL GOVERNMENT DOCUMENT',
    );
  }
}

class NotificationLogRecord {
  final int id;
  final String cycleId;
  final String recipientType;
  final String recipientId;
  final String recipientName;
  final String recipientPhone;
  final String fpsId;
  final String fpsName;
  final String channel;
  final String messageTitle;
  final String messageBody;
  final String status;
  final String sentAt;
  final String? acknowledgedAt;

  NotificationLogRecord({
    required this.id,
    required this.cycleId,
    required this.recipientType,
    required this.recipientId,
    required this.recipientName,
    required this.recipientPhone,
    required this.fpsId,
    required this.fpsName,
    required this.channel,
    required this.messageTitle,
    required this.messageBody,
    required this.status,
    required this.sentAt,
    this.acknowledgedAt,
  });

  factory NotificationLogRecord.fromJson(Map<String, dynamic> json) {
    return NotificationLogRecord(
      id: json['id'] ?? 0,
      cycleId: json['cycle_id'] ?? '',
      recipientType: json['recipient_type'] ?? '',
      recipientId: json['recipient_id'] ?? '',
      recipientName: json['recipient_name'] ?? '',
      recipientPhone: json['recipient_phone'] ?? '',
      fpsId: json['fps_id'] ?? '',
      fpsName: json['fps_name'] ?? '',
      channel: json['channel'] ?? 'WHATSAPP',
      messageTitle: json['message_title'] ?? '',
      messageBody: json['message_body'] ?? '',
      status: json['status'] ?? 'DELIVERED',
      sentAt: json['sent_at'] ?? '',
      acknowledgedAt: json['acknowledged_at'],
    );
  }
}

class NotificationDispatchResult {
  final String status;
  final String cycleId;
  final int totalNotificationsSent;
  final int dealerNotificationsCount;
  final int citizenNotificationsCount;
  final String summaryMessage;

  NotificationDispatchResult({
    required this.status,
    required this.cycleId,
    required this.totalNotificationsSent,
    required this.dealerNotificationsCount,
    required this.citizenNotificationsCount,
    required this.summaryMessage,
  });

  factory NotificationDispatchResult.fromJson(Map<String, dynamic> json) {
    return NotificationDispatchResult(
      status: json['status'] ?? 'success',
      cycleId: json['cycle_id'] ?? '2026-09',
      totalNotificationsSent: json['total_notifications_sent'] ?? 0,
      dealerNotificationsCount: json['dealer_notifications_count'] ?? 0,
      citizenNotificationsCount: json['citizen_notifications_count'] ?? 0,
      summaryMessage: json['summary_message'] ?? '',
    );
  }
}

// ----------------- Phase 1: Foundation & Command Dashboard Models ----------------- //

class TopKpiSummary {
  final int fpsMonitored;
  final int forecastCycles;
  final int pendingDispatches;
  final int constraintViolations;
  final int lockedManifests;
  final int activeTrucks;
  final double totalLoadKg;
  final String dispatchStatus;

  TopKpiSummary({
    required this.fpsMonitored,
    required this.forecastCycles,
    required this.pendingDispatches,
    required this.constraintViolations,
    required this.lockedManifests,
    required this.activeTrucks,
    required this.totalLoadKg,
    required this.dispatchStatus,
  });

  factory TopKpiSummary.fromJson(Map<String, dynamic> json) {
    final dt = json['dispatches_today'] as Map<String, dynamic>? ?? {};
    return TopKpiSummary(
      fpsMonitored: json['fps_monitored'] ?? 20,
      forecastCycles: json['forecast_cycles'] ?? 7,
      pendingDispatches: json['pending_dispatches'] ?? 0,
      constraintViolations: json['constraint_violations'] ?? 0,
      lockedManifests: json['locked_manifests'] ?? 0,
      activeTrucks: dt['active_trucks'] ?? 4,
      totalLoadKg: (dt['total_load_kg'] as num?)?.toDouble() ?? 0.0,
      dispatchStatus: dt['status'] ?? 'AWAITING_LOCK',
    );
  }
}

class SupplyRoute {
  final String routeId;
  final String sourceDepotId;
  final String depotName;
  final String destinationFpsId;
  final String fpsName;
  final double distanceKm;
  final int estimatedTimeMins;
  final String roadCondition;
  final String restrictionStatus;

  SupplyRoute({
    required this.routeId,
    required this.sourceDepotId,
    required this.depotName,
    required this.destinationFpsId,
    required this.fpsName,
    required this.distanceKm,
    required this.estimatedTimeMins,
    required this.roadCondition,
    required this.restrictionStatus,
  });

  factory SupplyRoute.fromJson(Map<String, dynamic> json) {
    return SupplyRoute(
      routeId: json['route_id'] ?? '',
      sourceDepotId: json['source_depot_id'] ?? '',
      depotName: json['depot_name'] ?? '',
      destinationFpsId: json['destination_fps_id'] ?? '',
      fpsName: json['fps_name'] ?? '',
      distanceKm: (json['distance_km'] as num?)?.toDouble() ?? 0.0,
      estimatedTimeMins: json['estimated_time_mins'] ?? 0,
      roadCondition: json['road_condition'] ?? 'PAVED_HIGHWAY',
      restrictionStatus: json['restriction_status'] ?? 'CLEAR',
    );
  }
}

class FpsAnalyticsProfile {
  final String fpsId;
  final String fpsName;
  final String district;
  final double latitude;
  final double longitude;
  final String statusBadge;
  final int beneficiariesCount;
  final double entitlementRiceKg;
  final double entitlementWheatKg;
  final double totalStatutoryQuotaKg;
  final double currentStockKg;
  final double storageCapacityKg;
  final double storageHeadroomKg;
  final double capacityUtilizationPct;
  final List<HistoricalOfftakeItem> historicalOfftake;
  final double recentTrendPct;
  final double portabilityRate;
  final String portabilityLabel;
  final double stockoutFrequency;
  final String stockoutFrequencyLabel;
  final double seasonalFactor;
  final String riskLevel;
  final int activeIntentDeclarationsCount;
  final double declaredIntentKg;
  final double forecastKg;
  final double recommendedDispatchKg;
  final double safetyBufferKg;
  final String assignedDepot;
  final String routeId;
  final double roadDistanceKm;
  final int estimatedTransitTimeMins;
  final String roadCondition;
  final String restrictionStatus;
  final FpsConstraintResult? constraintCompliance;

  FpsAnalyticsProfile({
    required this.fpsId,
    required this.fpsName,
    required this.district,
    required this.latitude,
    required this.longitude,
    required this.statusBadge,
    required this.beneficiariesCount,
    required this.entitlementRiceKg,
    required this.entitlementWheatKg,
    required this.totalStatutoryQuotaKg,
    required this.currentStockKg,
    required this.storageCapacityKg,
    required this.storageHeadroomKg,
    required this.capacityUtilizationPct,
    required this.historicalOfftake,
    required this.recentTrendPct,
    required this.portabilityRate,
    required this.portabilityLabel,
    required this.stockoutFrequency,
    required this.stockoutFrequencyLabel,
    required this.seasonalFactor,
    required this.riskLevel,
    required this.activeIntentDeclarationsCount,
    required this.declaredIntentKg,
    required this.forecastKg,
    required this.recommendedDispatchKg,
    required this.safetyBufferKg,
    required this.assignedDepot,
    required this.routeId,
    required this.roadDistanceKm,
    required this.estimatedTransitTimeMins,
    required this.roadCondition,
    required this.restrictionStatus,
    this.constraintCompliance,
  });

  factory FpsAnalyticsProfile.fromJson(Map<String, dynamic> json) {
    final ben = json['beneficiaries'] as Map<String, dynamic>? ?? {};
    final inv = json['inventory'] as Map<String, dynamic>? ?? {};
    final an = json['analytics'] as Map<String, dynamic>? ?? {};
    final rec = json['pre_dispatch_recommendation'] as Map<String, dynamic>? ?? {};
    final log = json['supply_chain_logistics'] as Map<String, dynamic>? ?? {};
    final hist = (json['historical_offtake'] as List<dynamic>?)
            ?.map((e) => HistoricalOfftakeItem.fromJson(e))
            .toList() ??
        [];

    FpsConstraintResult? cc;
    if (json['constraint_compliance'] != null) {
      try {
        cc = FpsConstraintResult.fromJson(json['constraint_compliance']);
      } catch (_) {}
    }

    return FpsAnalyticsProfile(
      fpsId: json['fps_id'] ?? '',
      fpsName: json['fps_name'] ?? '',
      district: json['district'] ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      statusBadge: json['status_badge'] ?? 'ACTIVE',
      beneficiariesCount: ben['count'] ?? 100,
      entitlementRiceKg: (ben['entitlement_rice_kg'] as num?)?.toDouble() ?? 25.0,
      entitlementWheatKg: (ben['entitlement_wheat_kg'] as num?)?.toDouble() ?? 10.0,
      totalStatutoryQuotaKg:
          (ben['total_statutory_quota_kg'] as num?)?.toDouble() ?? 3500.0,
      currentStockKg: (inv['current_stock_kg'] as num?)?.toDouble() ?? 0.0,
      storageCapacityKg:
          (inv['storage_capacity_kg'] as num?)?.toDouble() ?? 20000.0,
      storageHeadroomKg:
          (inv['storage_headroom_kg'] as num?)?.toDouble() ?? 0.0,
      capacityUtilizationPct:
          (inv['capacity_utilization_pct'] as num?)?.toDouble() ?? 0.0,
      historicalOfftake: hist,
      recentTrendPct: (an['recent_trend_pct'] as num?)?.toDouble() ?? 0.0,
      portabilityRate: (an['portability_rate'] as num?)?.toDouble() ?? 0.12,
      portabilityLabel: an['portability_label'] ?? '12% Migrant Transactions',
      stockoutFrequency: (an['stockout_frequency'] as num?)?.toDouble() ?? 0.05,
      stockoutFrequencyLabel:
          an['stockout_frequency_label'] ?? '5% Out-of-Stock Risk',
      seasonalFactor: (an['seasonal_factor'] as num?)?.toDouble() ?? 1.05,
      riskLevel: an['risk_level'] ?? 'NORMAL',
      activeIntentDeclarationsCount:
          an['active_intent_declarations_count'] ?? 0,
      declaredIntentKg:
          (an['declared_intent_kg'] as num?)?.toDouble() ?? 0.0,
      forecastKg: (rec['forecast_kg'] as num?)?.toDouble() ?? 0.0,
      recommendedDispatchKg:
          (rec['recommended_dispatch_kg'] as num?)?.toDouble() ?? 0.0,
      safetyBufferKg: (rec['safety_buffer_kg'] as num?)?.toDouble() ?? 0.0,
      assignedDepot: log['assigned_depot'] ?? '',
      routeId: log['route_id'] ?? '',
      roadDistanceKm: (log['road_distance_km'] as num?)?.toDouble() ?? 0.0,
      estimatedTransitTimeMins: log['estimated_transit_time_mins'] ?? 0,
      roadCondition: log['road_condition'] ?? 'PAVED_HIGHWAY',
      restrictionStatus: log['restriction_status'] ?? 'CLEAR',
      constraintCompliance: cc,
    );
  }
}

class HistoricalOfftakeItem {
  final String cycleId;
  final double riceKg;
  final double wheatKg;
  final double totalKg;

  HistoricalOfftakeItem({
    required this.cycleId,
    required this.riceKg,
    required this.wheatKg,
    required this.totalKg,
  });

  factory HistoricalOfftakeItem.fromJson(Map<String, dynamic> json) {
    return HistoricalOfftakeItem(
      cycleId: json['cycle_id'] ?? '',
      riceKg: (json['rice_kg'] as num?)?.toDouble() ?? 0.0,
      wheatKg: (json['wheat_kg'] as num?)?.toDouble() ?? 0.0,
      totalKg: (json['total_kg'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class PreDispatchAnalysisResult {
  final String status;
  final String analysisMode;
  final String? fpsId;
  final String? fpsName;
  final List<PipelineStageItem> pipelineStages;
  final String message;
  final FpsAnalyticsProfile? dossier;
  final bool stockConstraintDetected;
  final Map<String, dynamic>? stockConstraint;

  PreDispatchAnalysisResult({
    required this.status,
    required this.analysisMode,
    this.fpsId,
    this.fpsName,
    required this.pipelineStages,
    required this.message,
    this.dossier,
    this.stockConstraintDetected = false,
    this.stockConstraint,
  });

  factory PreDispatchAnalysisResult.fromJson(Map<String, dynamic> json) {
    final stages = (json['pipeline_stages'] as List<dynamic>?)
            ?.map((e) => PipelineStageItem.fromJson(e))
            .toList() ??
        [];

    FpsAnalyticsProfile? d;
    if (json['dossier'] != null) {
      try {
        d = FpsAnalyticsProfile.fromJson(json['dossier']);
      } catch (_) {}
    }

    return PreDispatchAnalysisResult(
      status: json['status'] ?? 'success',
      analysisMode: json['analysis_mode'] ?? 'DISTRICT_WIDE',
      fpsId: json['fps_id'],
      fpsName: json['fps_name'],
      pipelineStages: stages,
      message: json['message'] ?? '',
      dossier: d,
      stockConstraintDetected: json['stock_constraint_detected'] ?? false,
      stockConstraint: json['stock_constraint'] as Map<String, dynamic>?,
    );
  }
}

class PipelineStageItem {
  final String stage;
  final String status;
  final String value;
  final int elapsedSeconds;

  PipelineStageItem({
    required this.stage,
    required this.status,
    required this.value,
    this.elapsedSeconds = 0,
  });

  factory PipelineStageItem.fromJson(Map<String, dynamic> json) {
    return PipelineStageItem(
      stage: json['stage'] ?? '',
      status: json['status'] ?? '',
      value: json['value'] ?? '',
      elapsedSeconds: (json['elapsed_seconds'] as num?)?.toInt() ?? 0,
    );
  }
}

class CommandCenterData {
  final String status;
  final String cycleId;
  final String workflowStatus;
  final TopKpiSummary kpis;
  final Map<String, dynamic> sections;
  final Map<String, dynamic> filters;
  final List<FpsAnalyticsSummary> fpsSummaryList;
  final String demoNotice;

  CommandCenterData({
    required this.status,
    required this.cycleId,
    required this.workflowStatus,
    required this.kpis,
    required this.sections,
    required this.filters,
    required this.fpsSummaryList,
    required this.demoNotice,
  });

  factory CommandCenterData.fromJson(Map<String, dynamic> json) {
    final list = (json['fps_summary_list'] as List<dynamic>?)
            ?.map((e) => FpsAnalyticsSummary.fromJson(e))
            .toList() ??
        [];

    return CommandCenterData(
      status: json['status'] ?? 'success',
      cycleId: json['cycle_id'] ?? '2026-09',
      workflowStatus: json['workflow_status'] ?? 'PLANNING_OPEN',
      kpis: TopKpiSummary.fromJson(json['kpis'] ?? {}),
      sections: json['sections'] ?? {},
      filters: json['filters'] ?? {},
      fpsSummaryList: list,
      demoNotice: json['demo_notice'] ?? '',
    );
  }
}

class FpsAnalyticsSummary {
  final String fpsId;
  final String name;
  final String district;
  final double capacityKg;
  final double stockoutFrequency;
  final double portabilityRate;
  final double seasonalFactor;
  final int beneficiariesCount;
  final String status;

  FpsAnalyticsSummary({
    required this.fpsId,
    required this.name,
    required this.district,
    required this.capacityKg,
    required this.stockoutFrequency,
    required this.portabilityRate,
    required this.seasonalFactor,
    required this.beneficiariesCount,
    required this.status,
  });

  factory FpsAnalyticsSummary.fromJson(Map<String, dynamic> json) {
    return FpsAnalyticsSummary(
      fpsId: json['fps_id'] ?? '',
      name: json['name'] ?? '',
      district: json['district'] ?? '',
      capacityKg: (json['capacity_kg'] as num?)?.toDouble() ?? 0.0,
      stockoutFrequency: (json['stockout_frequency'] as num?)?.toDouble() ?? 0.05,
      portabilityRate: (json['portability_rate'] as num?)?.toDouble() ?? 0.12,
      seasonalFactor: (json['seasonal_factor'] as num?)?.toDouble() ?? 1.05,
      beneficiariesCount: json['beneficiaries_count'] ?? 100,
      status: json['status'] ?? 'ACTIVE',
    );
  }
}

// ----------------- Phase 2: Explainable Demand Forecast & What-If Models ----------------- //

class FpsForecastDetail {
  final String status;
  final String fpsId;
  final String fpsName;
  final String district;
  final String cycleId;
  final bool isWhatIfSimulation;
  final Map<String, dynamic> parameters;
  final ForecastSummaryMetrics summary;
  final List<CommodityForecastDetail> commodityBreakdown;
  final List<FeatureContribution> featureContributions;
  final List<HistoricalTrendPoint> historicalTrend;
  final String demoNotice;

  FpsForecastDetail({
    required this.status,
    required this.fpsId,
    required this.fpsName,
    required this.district,
    required this.cycleId,
    required this.isWhatIfSimulation,
    required this.parameters,
    required this.summary,
    required this.commodityBreakdown,
    required this.featureContributions,
    required this.historicalTrend,
    required this.demoNotice,
  });

  factory FpsForecastDetail.fromJson(Map<String, dynamic> json) {
    final commList = (json['commodity_breakdown'] as List<dynamic>?)
            ?.map((e) => CommodityForecastDetail.fromJson(e))
            .toList() ??
        [];
    final featList = (json['feature_contributions'] as List<dynamic>?)
            ?.map((e) => FeatureContribution.fromJson(e))
            .toList() ??
        [];
    final histList = (json['historical_trend'] as List<dynamic>?)
            ?.map((e) => HistoricalTrendPoint.fromJson(e))
            .toList() ??
        [];

    return FpsForecastDetail(
      status: json['status'] ?? 'success',
      fpsId: json['fps_id'] ?? '',
      fpsName: json['fps_name'] ?? '',
      district: json['district'] ?? '',
      cycleId: json['cycle_id'] ?? '2026-09',
      isWhatIfSimulation: json['is_what_if_simulation'] ?? false,
      parameters: json['parameters'] ?? {},
      summary: ForecastSummaryMetrics.fromJson(json['summary'] ?? {}),
      commodityBreakdown: commList,
      featureContributions: featList,
      historicalTrend: histList,
      demoNotice: json['demo_notice'] ?? '',
    );
  }
}

class ForecastSummaryMetrics {
  final double predictedDemandKg;
  final double confidenceScore;
  final double confidencePct;
  final double lowerEstimateKg;
  final double upperEstimateKg;
  final double marginOfErrorKg;
  final String modelVersion;

  ForecastSummaryMetrics({
    required this.predictedDemandKg,
    required this.confidenceScore,
    required this.confidencePct,
    required this.lowerEstimateKg,
    required this.upperEstimateKg,
    required this.marginOfErrorKg,
    required this.modelVersion,
  });

  factory ForecastSummaryMetrics.fromJson(Map<String, dynamic> json) {
    return ForecastSummaryMetrics(
      predictedDemandKg: (json['predicted_demand_kg'] as num?)?.toDouble() ?? 0.0,
      confidenceScore: (json['confidence_score'] as num?)?.toDouble() ?? 0.90,
      confidencePct: (json['confidence_pct'] as num?)?.toDouble() ?? 90.0,
      lowerEstimateKg: (json['lower_estimate_kg'] as num?)?.toDouble() ?? 0.0,
      upperEstimateKg: (json['upper_estimate_kg'] as num?)?.toDouble() ?? 0.0,
      marginOfErrorKg: (json['margin_of_error_kg'] as num?)?.toDouble() ?? 0.0,
      modelVersion: json['model_version'] ?? 'v1.1-explainable-multi-factor',
    );
  }
}

class CommodityForecastDetail {
  final String commodity;
  final double historicalWeightedAvgKg;
  final double trendPct;
  final double trendAdjKg;
  final double seasonalFactor;
  final double seasonalAdjKg;
  final double portabilityRate;
  final double portabilityAdjKg;
  final double stockoutFrequency;
  final double stockoutAdjKg;
  final double predictedDemandKg;
  final double currentInventoryKg;
  final double recommendedDispatchKg;

  CommodityForecastDetail({
    required this.commodity,
    required this.historicalWeightedAvgKg,
    required this.trendPct,
    required this.trendAdjKg,
    required this.seasonalFactor,
    required this.seasonalAdjKg,
    required this.portabilityRate,
    required this.portabilityAdjKg,
    required this.stockoutFrequency,
    required this.stockoutAdjKg,
    required this.predictedDemandKg,
    required this.currentInventoryKg,
    required this.recommendedDispatchKg,
  });

  factory CommodityForecastDetail.fromJson(Map<String, dynamic> json) {
    return CommodityForecastDetail(
      commodity: json['commodity'] ?? '',
      historicalWeightedAvgKg:
          (json['historical_weighted_avg_kg'] as num?)?.toDouble() ?? 0.0,
      trendPct: (json['trend_pct'] as num?)?.toDouble() ?? 0.0,
      trendAdjKg: (json['trend_adj_kg'] as num?)?.toDouble() ?? 0.0,
      seasonalFactor: (json['seasonal_factor'] as num?)?.toDouble() ?? 1.0,
      seasonalAdjKg: (json['seasonal_adj_kg'] as num?)?.toDouble() ?? 0.0,
      portabilityRate: (json['portability_rate'] as num?)?.toDouble() ?? 0.0,
      portabilityAdjKg: (json['portability_adj_kg'] as num?)?.toDouble() ?? 0.0,
      stockoutFrequency:
          (json['stockout_frequency'] as num?)?.toDouble() ?? 0.0,
      stockoutAdjKg: (json['stockout_adj_kg'] as num?)?.toDouble() ?? 0.0,
      predictedDemandKg:
          (json['predicted_demand_kg'] as num?)?.toDouble() ?? 0.0,
      currentInventoryKg:
          (json['current_inventory_kg'] as num?)?.toDouble() ?? 0.0,
      recommendedDispatchKg:
          (json['recommended_dispatch_kg'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class FeatureContribution {
  final String feature;
  final double contributionKg;
  final double contributionPct;
  final String description;

  FeatureContribution({
    required this.feature,
    required this.contributionKg,
    required this.contributionPct,
    required this.description,
  });

  factory FeatureContribution.fromJson(Map<String, dynamic> json) {
    return FeatureContribution(
      feature: json['feature'] ?? '',
      contributionKg: (json['contribution_kg'] as num?)?.toDouble() ?? 0.0,
      contributionPct: (json['contribution_pct'] as num?)?.toDouble() ?? 0.0,
      description: json['description'] ?? '',
    );
  }
}

class HistoricalTrendPoint {
  final String cycleId;
  final double riceKg;
  final double wheatKg;
  final double totalKg;

  HistoricalTrendPoint({
    required this.cycleId,
    required this.riceKg,
    required this.wheatKg,
    required this.totalKg,
  });

  factory HistoricalTrendPoint.fromJson(Map<String, dynamic> json) {
    return HistoricalTrendPoint(
      cycleId: json['cycle_id'] ?? '',
      riceKg: (json['rice_kg'] as num?)?.toDouble() ?? 0.0,
      wheatKg: (json['wheat_kg'] as num?)?.toDouble() ?? 0.0,
      totalKg: (json['total_kg'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class WhatIfSimulationResult {
  final String status;
  final String fpsId;
  final String fpsName;
  final String cycleId;
  final FpsForecastDetail baseline;
  final FpsForecastDetail simulation;
  final WhatIfComparison comparison;
  final String demoNotice;

  WhatIfSimulationResult({
    required this.status,
    required this.fpsId,
    required this.fpsName,
    required this.cycleId,
    required this.baseline,
    required this.simulation,
    required this.comparison,
    required this.demoNotice,
  });

  factory WhatIfSimulationResult.fromJson(Map<String, dynamic> json) {
    return WhatIfSimulationResult(
      status: json['status'] ?? 'success',
      fpsId: json['fps_id'] ?? '',
      fpsName: json['fps_name'] ?? '',
      cycleId: json['cycle_id'] ?? '2026-09',
      baseline: FpsForecastDetail.fromJson(json['baseline'] ?? {}),
      simulation: FpsForecastDetail.fromJson(json['simulation'] ?? {}),
      comparison: WhatIfComparison.fromJson(json['comparison'] ?? {}),
      demoNotice: json['demo_notice'] ?? '',
    );
  }
}

class WhatIfComparison {
  final double baselineDemandKg;
  final double simulatedDemandKg;
  final double deltaKg;
  final double deltaPct;
  final double confidenceChangePct;

  WhatIfComparison({
    required this.baselineDemandKg,
    required this.simulatedDemandKg,
    required this.deltaKg,
    required this.deltaPct,
    required this.confidenceChangePct,
  });

  factory WhatIfComparison.fromJson(Map<String, dynamic> json) {
    return WhatIfComparison(
      baselineDemandKg:
          (json['baseline_demand_kg'] as num?)?.toDouble() ?? 0.0,
      simulatedDemandKg:
          (json['simulated_demand_kg'] as num?)?.toDouble() ?? 0.0,
      deltaKg: (json['delta_kg'] as num?)?.toDouble() ?? 0.0,
      deltaPct: (json['delta_pct'] as num?)?.toDouble() ?? 0.0,
      confidenceChangePct:
          (json['confidence_change_pct'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

// ----------------- Phase 3: Dispatch Decision & Scenarios Models ----------------- //

class DispatchDecisionProfile {
  final String status;
  final String fpsId;
  final String fpsName;
  final String district;
  final String cycleId;
  final Map<String, dynamic> scenario;
  final DecisionCoreMetrics coreMetrics;
  final DecisionFormula formula;
  final SafetyBufferBreakdown safetyBufferBreakdown;
  final DecisionExplanation decisionExplanation;
  final List<CommodityDecision> commodityBreakdown;
  final List<ScenarioOption> allScenarios;
  final String demoNotice;

  DispatchDecisionProfile({
    required this.status,
    required this.fpsId,
    required this.fpsName,
    required this.district,
    required this.cycleId,
    required this.scenario,
    required this.coreMetrics,
    required this.formula,
    required this.safetyBufferBreakdown,
    required this.decisionExplanation,
    required this.commodityBreakdown,
    required this.allScenarios,
    required this.demoNotice,
  });

  factory DispatchDecisionProfile.fromJson(Map<String, dynamic> json) {
    final commList = (json['commodity_breakdown'] as List<dynamic>?)
            ?.map((e) => CommodityDecision.fromJson(e))
            .toList() ??
        [];
    final scenList = (json['all_scenarios'] as List<dynamic>?)
            ?.map((e) => ScenarioOption.fromJson(e))
            .toList() ??
        [];

    return DispatchDecisionProfile(
      status: json['status'] ?? 'success',
      fpsId: json['fps_id'] ?? '',
      fpsName: json['fps_name'] ?? '',
      district: json['district'] ?? '',
      cycleId: json['cycle_id'] ?? '2026-09',
      scenario: json['scenario'] ?? {},
      coreMetrics: DecisionCoreMetrics.fromJson(json['core_metrics'] ?? {}),
      formula: DecisionFormula.fromJson(json['formula'] ?? {}),
      safetyBufferBreakdown: SafetyBufferBreakdown.fromJson(
          json['safety_buffer_breakdown'] ?? {}),
      decisionExplanation:
          DecisionExplanation.fromJson(json['decision_explanation'] ?? {}),
      commodityBreakdown: commList,
      allScenarios: scenList,
      demoNotice: json['demo_notice'] ?? '',
    );
  }
}

class DecisionCoreMetrics {
  final double predictedDemandKg;
  final double currentStockKg;
  final double safetyBufferKg;
  final double recommendedDispatchKg;
  final double storageCapacityKg;
  final double postDispatchStockKg;
  final double remainingCapacityKg;
  final double capacityUtilizationPct;
  final double daysOfStockCoverage;

  DecisionCoreMetrics({
    required this.predictedDemandKg,
    required this.currentStockKg,
    required this.safetyBufferKg,
    required this.recommendedDispatchKg,
    required this.storageCapacityKg,
    required this.postDispatchStockKg,
    required this.remainingCapacityKg,
    required this.capacityUtilizationPct,
    required this.daysOfStockCoverage,
  });

  factory DecisionCoreMetrics.fromJson(Map<String, dynamic> json) {
    return DecisionCoreMetrics(
      predictedDemandKg:
          (json['predicted_demand_kg'] as num?)?.toDouble() ?? 0.0,
      currentStockKg: (json['current_stock_kg'] as num?)?.toDouble() ?? 0.0,
      safetyBufferKg: (json['safety_buffer_kg'] as num?)?.toDouble() ?? 0.0,
      recommendedDispatchKg:
          (json['recommended_dispatch_kg'] as num?)?.toDouble() ?? 0.0,
      storageCapacityKg:
          (json['storage_capacity_kg'] as num?)?.toDouble() ?? 20000.0,
      postDispatchStockKg:
          (json['post_dispatch_stock_kg'] as num?)?.toDouble() ?? 0.0,
      remainingCapacityKg:
          (json['remaining_capacity_kg'] as num?)?.toDouble() ?? 0.0,
      capacityUtilizationPct:
          (json['capacity_utilization_pct'] as num?)?.toDouble() ?? 0.0,
      daysOfStockCoverage:
          (json['days_of_stock_coverage'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class DecisionFormula {
  final String expression;
  final String values;
  final bool isCapacityCapped;
  final String capacityCapMessage;

  DecisionFormula({
    required this.expression,
    required this.values,
    required this.isCapacityCapped,
    required this.capacityCapMessage,
  });

  factory DecisionFormula.fromJson(Map<String, dynamic> json) {
    return DecisionFormula(
      expression: json['expression'] ?? '',
      values: json['values'] ?? '',
      isCapacityCapped: json['is_capacity_capped'] ?? false,
      capacityCapMessage: json['capacity_cap_message'] ?? '',
    );
  }
}

class SafetyBufferBreakdown {
  final double safetyBufferKg;
  final double safetyBufferPct;
  final double leadTimeDays;
  final double leadTimeContributionKg;
  final double stockoutRiskFactor;
  final double stockoutRiskContributionKg;
  final double consumptionVolatility;
  final double volatilityContributionKg;

  SafetyBufferBreakdown({
    required this.safetyBufferKg,
    required this.safetyBufferPct,
    required this.leadTimeDays,
    required this.leadTimeContributionKg,
    required this.stockoutRiskFactor,
    required this.stockoutRiskContributionKg,
    required this.consumptionVolatility,
    required this.volatilityContributionKg,
  });

  factory SafetyBufferBreakdown.fromJson(Map<String, dynamic> json) {
    return SafetyBufferBreakdown(
      safetyBufferKg:
          (json['safety_buffer_kg'] as num?)?.toDouble() ?? 0.0,
      safetyBufferPct:
          (json['safety_buffer_pct'] as num?)?.toDouble() ?? 0.0,
      leadTimeDays: (json['lead_time_days'] as num?)?.toDouble() ?? 2.0,
      leadTimeContributionKg:
          (json['lead_time_contribution_kg'] as num?)?.toDouble() ?? 0.0,
      stockoutRiskFactor:
          (json['stockout_risk_factor'] as num?)?.toDouble() ?? 0.05,
      stockoutRiskContributionKg:
          (json['stockout_risk_contribution_kg'] as num?)?.toDouble() ?? 0.0,
      consumptionVolatility:
          (json['consumption_volatility'] as num?)?.toDouble() ?? 0.08,
      volatilityContributionKg:
          (json['volatility_contribution_kg'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class DecisionExplanation {
  final String headline;
  final String narrative;
  final List<String> keyDrivers;

  DecisionExplanation({
    required this.headline,
    required this.narrative,
    required this.keyDrivers,
  });

  factory DecisionExplanation.fromJson(Map<String, dynamic> json) {
    return DecisionExplanation(
      headline: json['headline'] ?? '',
      narrative: json['narrative'] ?? '',
      keyDrivers: (json['key_drivers'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }
}

class CommodityDecision {
  final String commodity;
  final double predictedDemandKg;
  final double currentStockKg;
  final double safetyBufferKg;
  final double recommendedDispatchKg;
  final double postDispatchStockKg;
  final double commodityCapacityKg;
  final String formulaDisplay;

  CommodityDecision({
    required this.commodity,
    required this.predictedDemandKg,
    required this.currentStockKg,
    required this.safetyBufferKg,
    required this.recommendedDispatchKg,
    required this.postDispatchStockKg,
    required this.commodityCapacityKg,
    required this.formulaDisplay,
  });

  factory CommodityDecision.fromJson(Map<String, dynamic> json) {
    return CommodityDecision(
      commodity: json['commodity'] ?? '',
      predictedDemandKg:
          (json['predicted_demand_kg'] as num?)?.toDouble() ?? 0.0,
      currentStockKg: (json['current_stock_kg'] as num?)?.toDouble() ?? 0.0,
      safetyBufferKg: (json['safety_buffer_kg'] as num?)?.toDouble() ?? 0.0,
      recommendedDispatchKg:
          (json['recommended_dispatch_kg'] as num?)?.toDouble() ?? 0.0,
      postDispatchStockKg:
          (json['post_dispatch_stock_kg'] as num?)?.toDouble() ?? 0.0,
      commodityCapacityKg:
          (json['commodity_capacity_kg'] as num?)?.toDouble() ?? 0.0,
      formulaDisplay: json['formula_display'] ?? '',
    );
  }
}

class ScenarioOption {
  final String scenarioId;
  final String scenarioName;
  final double predictedDemandKg;
  final double currentStockKg;
  final double safetyBufferKg;
  final double recommendedDispatchKg;
  final String formula;

  ScenarioOption({
    required this.scenarioId,
    required this.scenarioName,
    required this.predictedDemandKg,
    required this.currentStockKg,
    required this.safetyBufferKg,
    required this.recommendedDispatchKg,
    required this.formula,
  });

  factory ScenarioOption.fromJson(Map<String, dynamic> json) {
    return ScenarioOption(
      scenarioId: json['scenario_id'] ?? '',
      scenarioName: json['scenario_name'] ?? '',
      predictedDemandKg:
          (json['predicted_demand_kg'] as num?)?.toDouble() ?? 0.0,
      currentStockKg: (json['current_stock_kg'] as num?)?.toDouble() ?? 0.0,
      safetyBufferKg: (json['safety_buffer_kg'] as num?)?.toDouble() ?? 0.0,
      recommendedDispatchKg:
          (json['recommended_dispatch_kg'] as num?)?.toDouble() ?? 0.0,
      formula: json['formula'] ?? '',
    );
  }
}

// ----------------- Phase 4: 9-Rule Constraint & Validation Models ----------------- //

class ConstraintAuditResult {
  final String status;
  final String districtValidationStatus;
  final bool canLockManifest;
  final String cycleId;
  final int totalFpsAudited;
  final int passCount;
  final int warningCount;
  final int failCount;
  final String summaryMessage;
  final List<SingleFpsConstraintResult> fpsEvaluations;
  final String demoNotice;

  ConstraintAuditResult({
    required this.status,
    required this.districtValidationStatus,
    required this.canLockManifest,
    required this.cycleId,
    required this.totalFpsAudited,
    required this.passCount,
    required this.warningCount,
    required this.failCount,
    required this.summaryMessage,
    required this.fpsEvaluations,
    required this.demoNotice,
  });

  factory ConstraintAuditResult.fromJson(Map<String, dynamic> json) {
    final list = (json['fps_evaluations'] as List<dynamic>?)
            ?.map((e) => SingleFpsConstraintResult.fromJson(e))
            .toList() ??
        [];

    return ConstraintAuditResult(
      status: json['status'] ?? 'success',
      districtValidationStatus: json['district_validation_status'] ?? 'PASS',
      canLockManifest: json['can_lock_manifest'] ?? true,
      cycleId: json['cycle_id'] ?? '2026-09',
      totalFpsAudited: json['total_fps_audited'] ?? 20,
      passCount: json['pass_count'] ?? 20,
      warningCount: json['warning_count'] ?? 0,
      failCount: json['fail_count'] ?? 0,
      summaryMessage: json['summary_message'] ?? '',
      fpsEvaluations: list,
      demoNotice: json['demo_notice'] ?? '',
    );
  }
}

class SingleFpsConstraintResult {
  final String status;
  final String fpsId;
  final String fpsName;
  final String district;
  final String cycleId;
  final bool isFailureSimulation;
  final String overallStatus;
  final bool canLockManifest;
  final String? blockingReason;
  final String summaryMessage;
  final int totalRulesChecked;
  final int passCount;
  final int warningCount;
  final int failCount;
  final List<ConstraintCheckItem> checks;
  final String demoNotice;

  SingleFpsConstraintResult({
    required this.status,
    required this.fpsId,
    required this.fpsName,
    required this.district,
    required this.cycleId,
    required this.isFailureSimulation,
    required this.overallStatus,
    required this.canLockManifest,
    this.blockingReason,
    required this.summaryMessage,
    required this.totalRulesChecked,
    required this.passCount,
    required this.warningCount,
    required this.failCount,
    required this.checks,
    required this.demoNotice,
  });

  factory SingleFpsConstraintResult.fromJson(Map<String, dynamic> json) {
    final chkList = (json['checks'] as List<dynamic>?)
            ?.map((e) => ConstraintCheckItem.fromJson(e))
            .toList() ??
        [];

    return SingleFpsConstraintResult(
      status: json['status'] ?? 'success',
      fpsId: json['fps_id'] ?? '',
      fpsName: json['fps_name'] ?? '',
      district: json['district'] ?? '',
      cycleId: json['cycle_id'] ?? '2026-09',
      isFailureSimulation: json['is_failure_simulation'] ?? false,
      overallStatus: json['overall_status'] ?? 'PASS',
      canLockManifest: json['can_lock_manifest'] ?? true,
      blockingReason: json['blocking_reason'],
      summaryMessage: json['summary_message'] ?? '',
      totalRulesChecked: json['total_rules_checked'] ?? 9,
      passCount: json['pass_count'] ?? 9,
      warningCount: json['warning_count'] ?? 0,
      failCount: json['fail_count'] ?? 0,
      checks: chkList,
      demoNotice: json['demo_notice'] ?? '',
    );
  }
}

class ResolveConstraintResponse {
  final String status;
  final String actionExecuted;
  final String message;
  final SingleFpsConstraintResult revalidation;
  final String demoNotice;

  ResolveConstraintResponse({
    required this.status,
    required this.actionExecuted,
    required this.message,
    required this.revalidation,
    required this.demoNotice,
  });

  factory ResolveConstraintResponse.fromJson(Map<String, dynamic> json) {
    return ResolveConstraintResponse(
      status: json['status'] ?? 'success',
      actionExecuted: json['action_executed'] ?? '',
      message: json['message'] ?? '',
      revalidation: SingleFpsConstraintResult.fromJson(json['revalidation'] ?? {}),
      demoNotice: json['demo_notice'] ?? '',
    );
  }
}

// ----------------- Phase 5: Multi-Candidate Dispatch Optimization Models ----------------- //

class CorridorOptimizationDossier {
  final String status;
  final String corridor;
  final String truckId;
  final String sourceDepot;
  final double totalCorridorDemandKg;
  final int totalStopsCount;
  final String routeCondition;
  final double fuelCostPerKm;
  final String selectedCandidateId;
  final String selectedTruck;
  final String selectedTruckModel;
  final double selectedRouteDistanceKm;
  final double selectedTransportCostInr;
  final int selectedDurationMins;
  final double selectedOptimizationScore;
  final double selectedEfficiencyPct;
  final String whySelectedReason;
  final List<OptimizedStop> deliverySequence;
  final List<OptimizationCandidate> evaluatedCandidates;
  final String demoNotice;

  CorridorOptimizationDossier({
    required this.status,
    required this.corridor,
    required this.truckId,
    required this.sourceDepot,
    required this.totalCorridorDemandKg,
    required this.totalStopsCount,
    required this.routeCondition,
    required this.fuelCostPerKm,
    required this.selectedCandidateId,
    required this.selectedTruck,
    required this.selectedTruckModel,
    required this.selectedRouteDistanceKm,
    required this.selectedTransportCostInr,
    required this.selectedDurationMins,
    required this.selectedOptimizationScore,
    required this.selectedEfficiencyPct,
    required this.whySelectedReason,
    required this.deliverySequence,
    required this.evaluatedCandidates,
    required this.demoNotice,
  });

  factory CorridorOptimizationDossier.fromJson(Map<String, dynamic> json) {
    final seq = (json['delivery_sequence'] as List<dynamic>?)
            ?.map((e) => OptimizedStop.fromJson(e))
            .toList() ??
        [];
    final cands = (json['evaluated_candidates'] as List<dynamic>?)
            ?.map((e) => OptimizationCandidate.fromJson(e))
            .toList() ??
        [];

    return CorridorOptimizationDossier(
      status: json['status'] ?? 'success',
      corridor: json['corridor'] ?? '',
      truckId: json['truck_id'] ?? '',
      sourceDepot: json['source_depot'] ?? '',
      totalCorridorDemandKg:
          (json['total_corridor_demand_kg'] as num?)?.toDouble() ?? 0.0,
      totalStopsCount: json['total_stops_count'] ?? seq.length,
      routeCondition: json['route_condition'] ?? 'Standard Urban Arterial',
      fuelCostPerKm: (json['fuel_cost_per_km'] as num?)?.toDouble() ?? 32.0,
      selectedCandidateId: json['selected_candidate_id'] ?? '',
      selectedTruck: json['selected_truck'] ?? '',
      selectedTruckModel: json['selected_truck_model'] ?? '',
      selectedRouteDistanceKm:
          (json['selected_route_distance_km'] as num?)?.toDouble() ?? 0.0,
      selectedTransportCostInr:
          (json['selected_transport_cost_inr'] as num?)?.toDouble() ?? 0.0,
      selectedDurationMins: json['selected_duration_mins'] ?? 0,
      selectedOptimizationScore:
          (json['selected_optimization_score'] as num?)?.toDouble() ?? 0.0,
      selectedEfficiencyPct:
          (json['selected_efficiency_pct'] as num?)?.toDouble() ?? 0.0,
      whySelectedReason: json['why_selected_reason'] ?? '',
      deliverySequence: seq,
      evaluatedCandidates: cands,
      demoNotice: json['demo_notice'] ?? '',
    );
  }
}

class OptimizationCandidate {
  final String candidateId;
  final String candidateName;
  final String truckId;
  final String truckModel;
  final double vehicleCapacityKg;
  final double capacityHeadroomKg;
  final bool isCapacityCompliant;
  final String departureWindow;
  final String routeType;
  final double totalDistanceKm;
  final int estimatedDurationMins;
  final double estimatedTransportCostInr;
  final OptimizationScoreBreakdown scoreBreakdown;
  final double compositePenaltyScore;
  final double optimizationEfficiencyPct;
  final bool isSelected;
  final List<OptimizedStop> stopsSequence;

  OptimizationCandidate({
    required this.candidateId,
    required this.candidateName,
    required this.truckId,
    required this.truckModel,
    required this.vehicleCapacityKg,
    required this.capacityHeadroomKg,
    required this.isCapacityCompliant,
    required this.departureWindow,
    required this.routeType,
    required this.totalDistanceKm,
    required this.estimatedDurationMins,
    required this.estimatedTransportCostInr,
    required this.scoreBreakdown,
    required this.compositePenaltyScore,
    required this.optimizationEfficiencyPct,
    required this.isSelected,
    required this.stopsSequence,
  });

  factory OptimizationCandidate.fromJson(Map<String, dynamic> json) {
    final seq = (json['stops_sequence'] as List<dynamic>?)
            ?.map((e) => OptimizedStop.fromJson(e))
            .toList() ??
        [];

    return OptimizationCandidate(
      candidateId: json['candidate_id'] ?? '',
      candidateName: json['candidate_name'] ?? '',
      truckId: json['truck_id'] ?? '',
      truckModel: json['truck_model'] ?? '',
      vehicleCapacityKg:
          (json['vehicle_capacity_kg'] as num?)?.toDouble() ?? 0.0,
      capacityHeadroomKg:
          (json['capacity_headroom_kg'] as num?)?.toDouble() ?? 0.0,
      isCapacityCompliant: json['is_capacity_compliant'] ?? true,
      departureWindow: json['departure_window'] ?? '08:30 AM',
      routeType: json['route_type'] ?? 'DIRECT_ARTERIAL',
      totalDistanceKm: (json['total_distance_km'] as num?)?.toDouble() ?? 0.0,
      estimatedDurationMins: json['estimated_duration_mins'] ?? 0,
      estimatedTransportCostInr:
          (json['estimated_transport_cost_inr'] as num?)?.toDouble() ?? 0.0,
      scoreBreakdown:
          OptimizationScoreBreakdown.fromJson(json['score_breakdown'] ?? {}),
      compositePenaltyScore:
          (json['composite_penalty_score'] as num?)?.toDouble() ?? 0.0,
      optimizationEfficiencyPct:
          (json['optimization_efficiency_pct'] as num?)?.toDouble() ?? 0.0,
      isSelected: json['is_selected'] ?? false,
      stopsSequence: seq,
    );
  }
}

class OptimizationScoreBreakdown {
  final double transportCostScore;
  final double stockoutRiskPenalty;
  final double excessStockPenalty;
  final double delayPenalty;
  final double compositePenaltyScore;

  OptimizationScoreBreakdown({
    required this.transportCostScore,
    required this.stockoutRiskPenalty,
    required this.excessStockPenalty,
    required this.delayPenalty,
    required this.compositePenaltyScore,
  });

  factory OptimizationScoreBreakdown.fromJson(Map<String, dynamic> json) {
    return OptimizationScoreBreakdown(
      transportCostScore:
          (json['transport_cost_score'] as num?)?.toDouble() ?? 0.0,
      stockoutRiskPenalty:
          (json['stockout_risk_penalty'] as num?)?.toDouble() ?? 0.0,
      excessStockPenalty:
          (json['excess_stock_penalty'] as num?)?.toDouble() ?? 0.0,
      delayPenalty: (json['delay_penalty'] as num?)?.toDouble() ?? 0.0,
      compositePenaltyScore:
          (json['composite_penalty_score'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class DistrictOptimizationPayload {
  final String status;
  final String cycleId;
  final int totalVehiclesOptimized;
  final int totalStopsSequenced;
  final double totalDistrictDistanceKm;
  final double totalTransportCostInr;
  final double averageOptimizationScore;
  final List<CorridorOptimizationDossier> corridorOptimizations;
  final String summaryMessage;
  final String demoNotice;

  DistrictOptimizationPayload({
    required this.status,
    required this.cycleId,
    required this.totalVehiclesOptimized,
    required this.totalStopsSequenced,
    required this.totalDistrictDistanceKm,
    required this.totalTransportCostInr,
    required this.averageOptimizationScore,
    required this.corridorOptimizations,
    required this.summaryMessage,
    required this.demoNotice,
  });

  factory DistrictOptimizationPayload.fromJson(Map<String, dynamic> json) {
    final list = (json['corridor_optimizations'] as List<dynamic>?)
            ?.map((e) => CorridorOptimizationDossier.fromJson(e))
            .toList() ??
        [];

    return DistrictOptimizationPayload(
      status: json['status'] ?? 'success',
      cycleId: json['cycle_id'] ?? '2026-09',
      totalVehiclesOptimized: json['total_vehicles_optimized'] ?? 4,
      totalStopsSequenced: json['total_stops_sequenced'] ?? 20,
      totalDistrictDistanceKm:
          (json['total_district_distance_km'] as num?)?.toDouble() ?? 0.0,
      totalTransportCostInr:
          (json['total_transport_cost_inr'] as num?)?.toDouble() ?? 0.0,
      averageOptimizationScore:
          (json['average_optimization_score'] as num?)?.toDouble() ?? 0.0,
      corridorOptimizations: list,
      summaryMessage: json['summary_message'] ?? '',
      demoNotice: json['demo_notice'] ?? '',
    );
  }
}

// ----------------- Phase 6: Auditable Manifest Generation & Lock Models ----------------- //

class DispatchManifestDossier {
  final String status;
  final String manifestId;
  final String cycleId;
  final String version;
  final String approvalStatus; // 'DRAFT', 'LOCKED', 'REVISED'
  final bool isLocked;
  final String sourceDepotId;
  final String sourceDepotName;
  final String sourceDepotLocation;
  final String corridor;
  final String truckId;
  final String truckModel;
  final double maxPayloadKg;
  final double payloadUtilizationPct;
  final String driverName;
  final String driverPhone;
  final String driverLicense;
  final String routeType;
  final String departureWindow;
  final double totalQuantityKg;
  final double totalRiceKg;
  final double totalWheatKg;
  final List<ManifestCommodityItem> commodities;
  final int totalStopsCount;
  final List<OptimizedStop> deliverySequence;
  final double optimizationScore;
  final double efficiencyPct;
  final String? lockedAt;
  final String? lockedBy;
  final String? lockReason;
  final String? digitalSealHash;
  final String createdAt;
  final String updatedAt;
  final List<ManifestAuditRecord> auditTrail;
  final String demoNotice;

  DispatchManifestDossier({
    required this.status,
    required this.manifestId,
    required this.cycleId,
    required this.version,
    required this.approvalStatus,
    required this.isLocked,
    required this.sourceDepotId,
    required this.sourceDepotName,
    required this.sourceDepotLocation,
    required this.corridor,
    required this.truckId,
    required this.truckModel,
    required this.maxPayloadKg,
    required this.payloadUtilizationPct,
    required this.driverName,
    required this.driverPhone,
    required this.driverLicense,
    required this.routeType,
    required this.departureWindow,
    required this.totalQuantityKg,
    required this.totalRiceKg,
    required this.totalWheatKg,
    required this.commodities,
    required this.totalStopsCount,
    required this.deliverySequence,
    required this.optimizationScore,
    required this.efficiencyPct,
    this.lockedAt,
    this.lockedBy,
    this.lockReason,
    this.digitalSealHash,
    required this.createdAt,
    required this.updatedAt,
    required this.auditTrail,
    required this.demoNotice,
  });

  factory DispatchManifestDossier.fromJson(Map<String, dynamic> json) {
    final comms = (json['commodities'] as List<dynamic>?)
            ?.map((e) => ManifestCommodityItem.fromJson(e))
            .toList() ??
        [];
    final seq = (json['delivery_sequence'] as List<dynamic>?)
            ?.map((e) => OptimizedStop.fromJson(e))
            .toList() ??
        [];
    final audits = (json['audit_trail'] as List<dynamic>?)
            ?.map((e) => ManifestAuditRecord.fromJson(e))
            .toList() ??
        [];

    return DispatchManifestDossier(
      status: json['status'] ?? 'success',
      manifestId: json['manifest_id'] ?? '',
      cycleId: json['cycle_id'] ?? '2026-09',
      version: json['version'] ?? 'v1.0',
      approvalStatus: json['approval_status'] ?? json['status'] ?? 'DRAFT',
      isLocked: json['is_locked'] ?? false,
      sourceDepotId: json['source_depot_id'] ?? '',
      sourceDepotName: json['source_depot_name'] ?? 'Central Godown',
      sourceDepotLocation: json['source_depot_location'] ?? 'Hebbal',
      corridor: json['corridor'] ?? '',
      truckId: json['truck_id'] ?? '',
      truckModel: json['truck_model'] ?? '',
      maxPayloadKg: (json['max_payload_kg'] as num?)?.toDouble() ?? 10000.0,
      payloadUtilizationPct:
          (json['payload_utilization_pct'] as num?)?.toDouble() ?? 0.0,
      driverName: json['driver_name'] ?? '',
      driverPhone: json['driver_phone'] ?? '',
      driverLicense: json['driver_license'] ?? '',
      routeType: json['route_type'] ?? 'DIRECT_ARTERIAL',
      departureWindow: json['departure_window'] ?? '08:30 AM',
      totalQuantityKg:
          (json['total_quantity_kg'] as num?)?.toDouble() ?? 0.0,
      totalRiceKg: (json['total_rice_kg'] as num?)?.toDouble() ?? 0.0,
      totalWheatKg: (json['total_wheat_kg'] as num?)?.toDouble() ?? 0.0,
      commodities: comms,
      totalStopsCount: json['total_stops_count'] ?? seq.length,
      deliverySequence: seq,
      optimizationScore:
          (json['optimization_score'] as num?)?.toDouble() ?? 0.0,
      efficiencyPct: (json['efficiency_pct'] as num?)?.toDouble() ?? 85.0,
      lockedAt: json['locked_at'],
      lockedBy: json['locked_by'],
      lockReason: json['lock_reason'],
      digitalSealHash: json['digital_seal_hash'],
      createdAt: json['created_at'] ?? '',
      updatedAt: json['updated_at'] ?? '',
      auditTrail: audits,
      demoNotice: json['demo_notice'] ?? '',
    );
  }
}

class ManifestCommodityItem {
  final String commodity;
  final double quantityKg;
  final String unit;

  ManifestCommodityItem({
    required this.commodity,
    required this.quantityKg,
    required this.unit,
  });

  factory ManifestCommodityItem.fromJson(Map<String, dynamic> json) {
    return ManifestCommodityItem(
      commodity: json['commodity'] ?? '',
      quantityKg: (json['quantity_kg'] as num?)?.toDouble() ?? 0.0,
      unit: json['unit'] ?? 'kg',
    );
  }
}

class ManifestAuditRecord {
  final int id;
  final String version;
  final String action;
  final String actorRole;
  final String actorName;
  final String reason;
  final String? changesSummary;
  final String? digitalHash;
  final String timestamp;

  ManifestAuditRecord({
    required this.id,
    required this.version,
    required this.action,
    required this.actorRole,
    required this.actorName,
    required this.reason,
    this.changesSummary,
    this.digitalHash,
    required this.timestamp,
  });

  factory ManifestAuditRecord.fromJson(Map<String, dynamic> json) {
    return ManifestAuditRecord(
      id: json['id'] ?? 0,
      version: json['version'] ?? 'v1.0',
      action: json['action'] ?? 'CREATED',
      actorRole: json['actor_role'] ?? 'DISTRICT_SUPPLY_OFFICER',
      actorName: json['actor_name'] ?? 'Officer',
      reason: json['reason'] ?? '',
      changesSummary: json['changes_summary'],
      digitalHash: json['digital_hash'],
      timestamp: json['timestamp'] ?? '',
    );
  }
}

class ManifestListPayload {
  final String status;
  final String cycleId;
  final int totalManifestsCount;
  final List<DispatchManifestDossier> manifests;
  final String demoNotice;

  ManifestListPayload({
    required this.status,
    required this.cycleId,
    required this.totalManifestsCount,
    required this.manifests,
    required this.demoNotice,
  });

  factory ManifestListPayload.fromJson(Map<String, dynamic> json) {
    final list = (json['manifests'] as List<dynamic>?)
            ?.map((e) => DispatchManifestDossier.fromJson(e))
            .toList() ??
        [];

    return ManifestListPayload(
      status: json['status'] ?? 'success',
      cycleId: json['cycle_id'] ?? '2026-09',
      totalManifestsCount: json['total_manifests_count'] ?? list.length,
      manifests: list,
      demoNotice: json['demo_notice'] ?? '',
    );
  }
}

// ----------------- Phase 8: SIH Demo Mode & Delivery Feedback Models ----------------- //

class SihDemoScenario {
  final String id;
  final String title;
  final String badge;
  final String description;
  final String fpsId;
  final String truckId;
  final String scenarioNotes;

  SihDemoScenario({
    required this.id,
    required this.title,
    required this.badge,
    required this.description,
    required this.fpsId,
    required this.truckId,
    required this.scenarioNotes,
  });

  factory SihDemoScenario.fromJson(Map<String, dynamic> json) {
    return SihDemoScenario(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      badge: json['badge'] ?? 'DEMO',
      description: json['description'] ?? '',
      fpsId: json['fps_id'] ?? 'FPS-KA-BLR-001',
      truckId: json['truck_id'] ?? 'DEMO-KA-04-E-1021',
      scenarioNotes: json['scenario_notes'] ?? '',
    );
  }
}

class DemoStepTrace {
  final int stepNumber;
  final String title;
  final String phase;
  final String status;
  final String summary;
  final Map<String, dynamic> details;

  DemoStepTrace({
    required this.stepNumber,
    required this.title,
    required this.phase,
    required this.status,
    required this.summary,
    required this.details,
  });

  factory DemoStepTrace.fromJson(Map<String, dynamic> json) {
    return DemoStepTrace(
      stepNumber: json['step_number'] ?? 0,
      title: json['title'] ?? '',
      phase: json['phase'] ?? '',
      status: json['status'] ?? 'COMPLETED',
      summary: json['summary'] ?? '',
      details: json['details'] as Map<String, dynamic>? ?? {},
    );
  }
}

class DemoScenarioExecutionResult {
  final String status;
  final String scenarioId;
  final String scenarioTitle;
  final String badge;
  final String targetFpsId;
  final String targetTruckId;
  final String cycleId;
  final int totalStepsExecuted;
  final double executionTimeSeconds;
  final List<DemoStepTrace> stepsTrace;
  final Map<String, dynamic> systemImpactSummary;
  final String demoNotice;

  DemoScenarioExecutionResult({
    required this.status,
    required this.scenarioId,
    required this.scenarioTitle,
    required this.badge,
    required this.targetFpsId,
    required this.targetTruckId,
    required this.cycleId,
    required this.totalStepsExecuted,
    required this.executionTimeSeconds,
    required this.stepsTrace,
    required this.systemImpactSummary,
    required this.demoNotice,
  });

  factory DemoScenarioExecutionResult.fromJson(Map<String, dynamic> json) {
    final list = (json['steps_trace'] as List<dynamic>?)
            ?.map((e) => DemoStepTrace.fromJson(e))
            .toList() ??
        [];

    return DemoScenarioExecutionResult(
      status: json['status'] ?? 'success',
      scenarioId: json['scenario_id'] ?? 'SCENARIO_1',
      scenarioTitle: json['scenario_title'] ?? 'Scenario 1: Normal Standard Dispatch',
      badge: json['badge'] ?? 'STANDARD FLOW',
      targetFpsId: json['target_fps_id'] ?? 'FPS-KA-BLR-001',
      targetTruckId: json['target_truck_id'] ?? 'DEMO-KA-04-E-1021',
      cycleId: json['cycle_id'] ?? '2026-09',
      totalStepsExecuted: json['total_steps_executed'] ?? list.length,
      executionTimeSeconds: (json['execution_time_seconds'] as num?)?.toDouble() ?? 1.84,
      stepsTrace: list,
      systemImpactSummary: json['system_impact_summary'] as Map<String, dynamic>? ?? {},
      demoNotice: json['demo_notice'] ?? '',
    );
  }
}

class CommodityFeedbackItem {
  final String commodity;
  final double forecastQuantityKg;
  final double actualQuantityKg;
  final double absoluteErrorKg;
  final double percentageError;
  final double accuracyPct;
  final String biasDirection;

  CommodityFeedbackItem({
    required this.commodity,
    required this.forecastQuantityKg,
    required this.actualQuantityKg,
    required this.absoluteErrorKg,
    required this.percentageError,
    required this.accuracyPct,
    required this.biasDirection,
  });

  factory CommodityFeedbackItem.fromJson(Map<String, dynamic> json) {
    return CommodityFeedbackItem(
      commodity: json['commodity'] ?? '',
      forecastQuantityKg: (json['forecast_quantity_kg'] as num?)?.toDouble() ?? 0.0,
      actualQuantityKg: (json['actual_quantity_kg'] as num?)?.toDouble() ?? 0.0,
      absoluteErrorKg: (json['absolute_error_kg'] as num?)?.toDouble() ?? 0.0,
      percentageError: (json['percentage_error'] as num?)?.toDouble() ?? 0.0,
      accuracyPct: (json['accuracy_pct'] as num?)?.toDouble() ?? 0.0,
      biasDirection: json['bias_direction'] ?? 'OVER_PREDICTED',
    );
  }
}

class AccuracyTrendPoint {
  final String cycle;
  final double accuracyPct;
  final double mapePct;

  AccuracyTrendPoint({
    required this.cycle,
    required this.accuracyPct,
    required this.mapePct,
  });

  factory AccuracyTrendPoint.fromJson(Map<String, dynamic> json) {
    return AccuracyTrendPoint(
      cycle: json['cycle'] ?? '',
      accuracyPct: (json['accuracy_pct'] as num?)?.toDouble() ?? 0.0,
      mapePct: (json['mape_pct'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class FpsOfftakeFeedbackResult {
  final String status;
  final String fpsId;
  final String fpsName;
  final String district;
  final String cycleId;
  final double totalForecastQuantityKg;
  final double totalActualQuantityKg;
  final double totalAbsoluteErrorKg;
  final double percentageError;
  final double overallAccuracyPct;
  final String biasDirection;
  final List<CommodityFeedbackItem> commodities;
  final List<AccuracyTrendPoint> historicalAccuracyTrend;
  final String modelFeedbackStatus;
  final bool datasetUpdated;
  final String trainingSampleCountIncrease;
  final String futureCycleReady;
  final String message;
  final String demoNotice;

  FpsOfftakeFeedbackResult({
    required this.status,
    required this.fpsId,
    required this.fpsName,
    required this.district,
    required this.cycleId,
    required this.totalForecastQuantityKg,
    required this.totalActualQuantityKg,
    required this.totalAbsoluteErrorKg,
    required this.percentageError,
    required this.overallAccuracyPct,
    required this.biasDirection,
    required this.commodities,
    required this.historicalAccuracyTrend,
    required this.modelFeedbackStatus,
    required this.datasetUpdated,
    required this.trainingSampleCountIncrease,
    required this.futureCycleReady,
    required this.message,
    required this.demoNotice,
  });

  factory FpsOfftakeFeedbackResult.fromJson(Map<String, dynamic> json) {
    final comms = (json['commodities'] as List<dynamic>?)
            ?.map((e) => CommodityFeedbackItem.fromJson(e))
            .toList() ??
        [];
    final trends = (json['historical_accuracy_trend'] as List<dynamic>?)
            ?.map((e) => AccuracyTrendPoint.fromJson(e))
            .toList() ??
        [];

    return FpsOfftakeFeedbackResult(
      status: json['status'] ?? 'success',
      fpsId: json['fps_id'] ?? '',
      fpsName: json['fps_name'] ?? '',
      district: json['district'] ?? '',
      cycleId: json['cycle_id'] ?? '2026-09',
      totalForecastQuantityKg: (json['total_forecast_quantity_kg'] as num?)?.toDouble() ?? 0.0,
      totalActualQuantityKg: (json['total_actual_quantity_kg'] as num?)?.toDouble() ?? 0.0,
      totalAbsoluteErrorKg: (json['total_absolute_error_kg'] as num?)?.toDouble() ?? 0.0,
      percentageError: (json['percentage_error'] as num?)?.toDouble() ?? 0.0,
      overallAccuracyPct: (json['overall_accuracy_pct'] as num?)?.toDouble() ?? 0.0,
      biasDirection: json['bias_direction'] ?? 'OVER_PREDICTED',
      commodities: comms,
      historicalAccuracyTrend: trends,
      modelFeedbackStatus: json['model_feedback_status'] ?? 'Feedback captured for next forecasting cycle.',
      datasetUpdated: json['dataset_updated'] ?? true,
      trainingSampleCountIncrease: json['training_sample_count_increase'] ?? '+20 observation cycles',
      futureCycleReady: json['future_cycle_ready'] ?? 'Cycle 2026-10 READY',
      message: json['message'] ?? '',
      demoNotice: json['demo_notice'] ?? '',
    );
  }
}

class ImpactMetricItem {
  final String label;
  final String baselineValue;
  final String optimizedValue;
  final double improvementPct;
  final String unit;
  final double? savingsInr;
  final String description;

  ImpactMetricItem({
    required this.label,
    required this.baselineValue,
    required this.optimizedValue,
    required this.improvementPct,
    required this.unit,
    this.savingsInr,
    required this.description,
  });

  factory ImpactMetricItem.fromJson(Map<String, dynamic> json) {
    return ImpactMetricItem(
      label: json['label'] ?? '',
      baselineValue: json['baseline_value'] ?? '',
      optimizedValue: json['optimized_value'] ?? '',
      improvementPct: (json['improvement_pct'] as num?)?.toDouble() ?? 0.0,
      unit: json['unit'] ?? '',
      savingsInr: (json['savings_inr'] as num?)?.toDouble(),
      description: json['description'] ?? '',
    );
  }
}

class ValueChainStep {
  final int step;
  final String name;
  final String subtext;

  ValueChainStep({
    required this.step,
    required this.name,
    required this.subtext,
  });

  factory ValueChainStep.fromJson(Map<String, dynamic> json) {
    return ValueChainStep(
      step: json['step'] ?? 0,
      name: json['name'] ?? '',
      subtext: json['subtext'] ?? '',
    );
  }
}

class SystemImpactDashboardData {
  final String status;
  final String cycleId;
  final Map<String, ImpactMetricItem> impactMetrics;
  final List<ValueChainStep> systemValueChain;
  final String coreUsp;
  final String prototypeLabel;
  final String demoNotice;

  SystemImpactDashboardData({
    required this.status,
    required this.cycleId,
    required this.impactMetrics,
    required this.systemValueChain,
    required this.coreUsp,
    required this.prototypeLabel,
    required this.demoNotice,
  });

  factory SystemImpactDashboardData.fromJson(Map<String, dynamic> json) {
    final rawMetrics = json['impact_metrics'] as Map<String, dynamic>? ?? {};
    final parsedMetrics = <String, ImpactMetricItem>{};
    rawMetrics.forEach((k, v) {
      if (v is Map<String, dynamic>) {
        parsedMetrics[k] = ImpactMetricItem.fromJson(v);
      }
    });

    final chain = (json['system_value_chain'] as List<dynamic>?)
            ?.map((e) => ValueChainStep.fromJson(e))
            .toList() ??
        [];

    return SystemImpactDashboardData(
      status: json['status'] ?? 'success',
      cycleId: json['cycle_id'] ?? '2026-09',
      impactMetrics: parsedMetrics,
      systemValueChain: chain,
      coreUsp: json['core_usp'] ?? 'Forecast → Decide → Lock → Notify',
      prototypeLabel: json['prototype_label'] ?? 'Prototype simulation',
      demoNotice: json['demo_notice'] ?? '',
    );
  }
}

class WhatExistsPillar {
  final String name;
  final String coverage;
  final String role;

  WhatExistsPillar({
    required this.name,
    required this.coverage,
    required this.role,
  });

  factory WhatExistsPillar.fromJson(Map<String, dynamic> json) {
    return WhatExistsPillar(
      name: json['name'] ?? '',
      coverage: json['coverage'] ?? '',
      role: json['role'] ?? '',
    );
  }
}

class WhatWeAddInnovation {
  final String stage;
  final String description;

  WhatWeAddInnovation({
    required this.stage,
    required this.description,
  });

  factory WhatWeAddInnovation.fromJson(Map<String, dynamic> json) {
    return WhatWeAddInnovation(
      stage: json['stage'] ?? '',
      description: json['description'] ?? '',
    );
  }
}

class ValueChainMatrixStep {
  final int step;
  final String name;
  final String actor;
  final String input;
  final String output;

  ValueChainMatrixStep({
    required this.step,
    required this.name,
    required this.actor,
    required this.input,
    required this.output,
  });

  factory ValueChainMatrixStep.fromJson(Map<String, dynamic> json) {
    return ValueChainMatrixStep(
      step: (json['step'] as num?)?.toInt() ?? 1,
      name: json['name'] ?? '',
      actor: json['actor'] ?? '',
      input: json['input'] ?? '',
      output: json['output'] ?? '',
    );
  }
}

class JudgeFaqItem {
  final String question;
  final String defense;

  JudgeFaqItem({
    required this.question,
    required this.defense,
  });

  factory JudgeFaqItem.fromJson(Map<String, dynamic> json) {
    return JudgeFaqItem(
      question: json['question'] ?? '',
      defense: json['defense'] ?? '',
    );
  }
}

class SihJudgeDefenseData {
  final String status;
  final String title;
  final String subtitle;
  final String projectPositioning;
  final String coreUsp;
  final String prototypeDisclaimer;
  final String whatExistsTitle;
  final String whatExistsDescription;
  final List<WhatExistsPillar> whatExistsPillars;
  final List<String> whatExistsGaps;
  final String whatWeAddTitle;
  final String whatWeAddDescription;
  final List<WhatWeAddInnovation> whatWeAddInnovations;
  final List<ValueChainMatrixStep> valueChainMatrix;
  final List<JudgeFaqItem> judgeFaqDefense;

  SihJudgeDefenseData({
    required this.status,
    required this.title,
    required this.subtitle,
    required this.projectPositioning,
    required this.coreUsp,
    required this.prototypeDisclaimer,
    required this.whatExistsTitle,
    required this.whatExistsDescription,
    required this.whatExistsPillars,
    required this.whatExistsGaps,
    required this.whatWeAddTitle,
    required this.whatWeAddDescription,
    required this.whatWeAddInnovations,
    required this.valueChainMatrix,
    required this.judgeFaqDefense,
  });

  factory SihJudgeDefenseData.fromJson(Map<String, dynamic> json) {
    final rawExists = json['what_exists'] as Map<String, dynamic>? ?? {};
    final pillars = (rawExists['pillars'] as List<dynamic>?)
            ?.map((e) => WhatExistsPillar.fromJson(e))
            .toList() ??
        [];
    final gaps = (rawExists['inherent_gaps'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];

    final rawWeAdd = json['what_we_add'] as Map<String, dynamic>? ?? {};
    final innovations = (rawWeAdd['innovations'] as List<dynamic>?)
            ?.map((e) => WhatWeAddInnovation.fromJson(e))
            .toList() ??
        [];

    final chain = (json['value_chain_matrix'] as List<dynamic>?)
            ?.map((e) => ValueChainMatrixStep.fromJson(e))
            .toList() ??
        [];

    final faqs = (json['judge_faq_defense'] as List<dynamic>?)
            ?.map((e) => JudgeFaqItem.fromJson(e))
            .toList() ??
        [];

    return SihJudgeDefenseData(
      status: json['status'] ?? 'success',
      title: json['title'] ?? 'SIH 2026 Technical Jury Defense',
      subtitle: json['subtitle'] ?? 'PDS Pre-Dispatch Intelligence & Alert System',
      projectPositioning: json['project_positioning'] ?? 'Interoperable Pre-Dispatch Decision Intelligence Layer',
      coreUsp: json['core_usp'] ?? 'Forecast → Decide → Validate → Optimize → Lock → Notify',
      prototypeDisclaimer: json['prototype_disclaimer'] ?? '',
      whatExistsTitle: rawExists['title'] ?? 'Existing PDS Ecosystem',
      whatExistsDescription: rawExists['description'] ?? '',
      whatExistsPillars: pillars,
      whatExistsGaps: gaps,
      whatWeAddTitle: rawWeAdd['title'] ?? 'What PDS DemandSync Adds',
      whatWeAddDescription: rawWeAdd['description'] ?? '',
      whatWeAddInnovations: innovations,
      valueChainMatrix: chain,
      judgeFaqDefense: faqs,
    );
  }
}

// ----------------- End-to-End Causal Pipeline Trace Models ----------------- //

class CausalStageTraceModel {
  final int stageNumber;
  final String stageName;
  final String title;
  final String status;
  final Map<String, dynamic> inputSummary;
  final Map<String, dynamic> outputSummary;
  final String governanceNotes;
  final String timestamp;

  CausalStageTraceModel({
    required this.stageNumber,
    required this.stageName,
    required this.title,
    required this.status,
    required this.inputSummary,
    required this.outputSummary,
    required this.governanceNotes,
    required this.timestamp,
  });

  factory CausalStageTraceModel.fromJson(Map<String, dynamic> json) {
    return CausalStageTraceModel(
      stageNumber: json['stage_number'] ?? 0,
      stageName: json['stage_name'] ?? '',
      title: json['title'] ?? '',
      status: json['status'] ?? 'COMPLETED',
      inputSummary: json['input_summary'] as Map<String, dynamic>? ?? {},
      outputSummary: json['output_summary'] as Map<String, dynamic>? ?? {},
      governanceNotes: json['governance_notes'] ?? '',
      timestamp: json['timestamp'] ?? '',
    );
  }
}

class CausalDeltaSummary {
  final double intentDeltaKg;
  final double forecastDeltaKg;
  final double dispatchDeltaKg;
  final double routePayloadDeltaKg;
  final String manifestVersionDelta;
  final bool sealHashChanged;
  final double statutoryEntitlementDeltaKg;
  final String propagationSummary;

  CausalDeltaSummary({
    required this.intentDeltaKg,
    required this.forecastDeltaKg,
    required this.dispatchDeltaKg,
    required this.routePayloadDeltaKg,
    required this.manifestVersionDelta,
    required this.sealHashChanged,
    required this.statutoryEntitlementDeltaKg,
    required this.propagationSummary,
  });

  factory CausalDeltaSummary.fromJson(Map<String, dynamic> json) {
    return CausalDeltaSummary(
      intentDeltaKg: (json['intent_delta_kg'] as num?)?.toDouble() ?? 0.0,
      forecastDeltaKg: (json['forecast_delta_kg'] as num?)?.toDouble() ?? 0.0,
      dispatchDeltaKg: (json['dispatch_delta_kg'] as num?)?.toDouble() ?? 0.0,
      routePayloadDeltaKg: (json['route_payload_delta_kg'] as num?)?.toDouble() ?? 0.0,
      manifestVersionDelta: json['manifest_version_delta'] ?? '',
      sealHashChanged: json['seal_hash_changed'] ?? false,
      statutoryEntitlementDeltaKg: (json['statutory_entitlement_delta_kg'] as num?)?.toDouble() ?? 0.0,
      propagationSummary: json['propagation_summary'] ?? '',
    );
  }
}

class CausalTraceRun {
  final String runId;
  final String cycleId;
  final String fpsId;
  final String fpsName;
  final String actorSource;
  final String timestamp;
  final CausalStageTraceModel stage1Intent;
  final CausalStageTraceModel stage2Forecast;
  final CausalStageTraceModel stage3Constraints;
  final CausalStageTraceModel stage4Dispatch;
  final CausalStageTraceModel stage5Route;
  final CausalStageTraceModel stage6Manifest;
  final CausalStageTraceModel stage7Seal;
  final double historicalDemandKg;
  final double aggregatedIntentKg;
  final double operationalForecastKg;
  final double recommendedDispatchKg;
  final String assignedCorridor;
  final String assignedTruckId;
  final String manifestId;
  final String manifestVersion;
  final String digitalSealHash;
  final double statutoryEntitlementGuaranteeKg;
  final String demoNotice;

  CausalTraceRun({
    required this.runId,
    required this.cycleId,
    required this.fpsId,
    required this.fpsName,
    required this.actorSource,
    required this.timestamp,
    required this.stage1Intent,
    required this.stage2Forecast,
    required this.stage3Constraints,
    required this.stage4Dispatch,
    required this.stage5Route,
    required this.stage6Manifest,
    required this.stage7Seal,
    required this.historicalDemandKg,
    required this.aggregatedIntentKg,
    required this.operationalForecastKg,
    required this.recommendedDispatchKg,
    required this.assignedCorridor,
    required this.assignedTruckId,
    required this.manifestId,
    required this.manifestVersion,
    required this.digitalSealHash,
    required this.statutoryEntitlementGuaranteeKg,
    required this.demoNotice,
  });

  factory CausalTraceRun.fromJson(Map<String, dynamic> json) {
    return CausalTraceRun(
      runId: json['run_id'] ?? '',
      cycleId: json['cycle_id'] ?? '2026-09',
      fpsId: json['fps_id'] ?? 'FPS-KA-BLR-001',
      fpsName: json['fps_name'] ?? '',
      actorSource: json['actor_source'] ?? 'SYSTEM',
      timestamp: json['timestamp'] ?? '',
      stage1Intent: CausalStageTraceModel.fromJson(json['stage_1_intent'] as Map<String, dynamic>? ?? {}),
      stage2Forecast: CausalStageTraceModel.fromJson(json['stage_2_forecast'] as Map<String, dynamic>? ?? {}),
      stage3Constraints: CausalStageTraceModel.fromJson(json['stage_3_constraints'] as Map<String, dynamic>? ?? {}),
      stage4Dispatch: CausalStageTraceModel.fromJson(json['stage_4_dispatch'] as Map<String, dynamic>? ?? {}),
      stage5Route: CausalStageTraceModel.fromJson(json['stage_5_route'] as Map<String, dynamic>? ?? {}),
      stage6Manifest: CausalStageTraceModel.fromJson(json['stage_6_manifest'] as Map<String, dynamic>? ?? {}),
      stage7Seal: CausalStageTraceModel.fromJson(json['stage_7_seal'] as Map<String, dynamic>? ?? {}),
      historicalDemandKg: (json['historical_demand_kg'] as num?)?.toDouble() ?? 0.0,
      aggregatedIntentKg: (json['aggregated_intent_kg'] as num?)?.toDouble() ?? 0.0,
      operationalForecastKg: (json['operational_forecast_kg'] as num?)?.toDouble() ?? 0.0,
      recommendedDispatchKg: (json['recommended_dispatch_kg'] as num?)?.toDouble() ?? 0.0,
      assignedCorridor: json['assigned_corridor'] ?? '',
      assignedTruckId: json['assigned_truck_id'] ?? '',
      manifestId: json['manifest_id'] ?? '',
      manifestVersion: json['manifest_version'] ?? 'v1.0',
      digitalSealHash: json['digital_seal_hash'] ?? '',
      statutoryEntitlementGuaranteeKg: (json['statutory_entitlement_guarantee_kg'] as num?)?.toDouble() ?? 25.0,
      demoNotice: json['demo_notice'] ?? '',
    );
  }
}

class CausalTraceResponse {
  final String status;
  final CausalTraceRun currentRun;
  final CausalTraceRun? previousRun;
  final CausalDeltaSummary? causalDelta;
  final String message;
  final String demoNotice;

  CausalTraceResponse({
    required this.status,
    required this.currentRun,
    this.previousRun,
    this.causalDelta,
    required this.message,
    required this.demoNotice,
  });

  factory CausalTraceResponse.fromJson(Map<String, dynamic> json) {
    return CausalTraceResponse(
      status: json['status'] ?? 'success',
      currentRun: CausalTraceRun.fromJson(json['current_run'] as Map<String, dynamic>? ?? {}),
      previousRun: json['previous_run'] != null ? CausalTraceRun.fromJson(json['previous_run'] as Map<String, dynamic>) : null,
      causalDelta: json['causal_delta'] != null ? CausalDeltaSummary.fromJson(json['causal_delta'] as Map<String, dynamic>) : null,
      message: json['message'] ?? '',
      demoNotice: json['demo_notice'] ?? '',
    );
  }
}

/// Pre-Dispatch Operational Incident detected during Optimize Simulation
class OperationalIncident {
  final String id;
  final String title;
  final String scenarioBadge;
  final String riskCategory;
  final String severity; // 'HIGH_RISK', 'MEDIUM_RISK'
  final String affectedFps;
  final String affectedFpsId;
  final String affectedTruckId;
  final String projectedShortageOrConstraint;
  final String supplyAdjustment;
  final String explanation;
  final String whyItMatters;
  final String recommendation;
  final String officerActionTitle;
  bool isAcknowledged;
  bool isActionApplied;

  OperationalIncident({
    required this.id,
    required this.title,
    required this.scenarioBadge,
    required this.riskCategory,
    required this.severity,
    required this.affectedFps,
    required this.affectedFpsId,
    required this.affectedTruckId,
    required this.projectedShortageOrConstraint,
    required this.supplyAdjustment,
    required this.explanation,
    required this.whyItMatters,
    required this.recommendation,
    required this.officerActionTitle,
    this.isAcknowledged = false,
    this.isActionApplied = false,
  });

  static List<OperationalIncident> getDefaultPreDispatchIncidents() {
    return [
      OperationalIncident(
        id: 'INC-2026-09-01',
        title: 'Festival Demand Surge Detected',
        scenarioBadge: 'GANESH CHATURTHI SURGE',
        riskCategory: 'DEMAND SURGE / INFLUX',
        severity: 'HIGH_RISK',
        affectedFps: 'FPS-KA-BLR-001 (Malleshwaram Seva Kendra)',
        affectedFpsId: 'FPS-KA-BLR-001',
        affectedTruckId: 'DEMO-KA-04-E-1021 (North-West Heavy Corridor)',
        projectedShortageOrConstraint: '+2,450 kg Rice (Deficit Risk: 88%)',
        supplyAdjustment: '+2.45 MT Statutory Buffer Release Required',
        explanation: 'A sudden +38% spike in declared beneficiary intent signals was detected for the Malleshwaram cluster due to upcoming Ganesh Chaturthi festivities. Projected consumption exceeds baseline allocation by 2.45 MT.',
        whyItMatters: 'Without pre-dispatch intervention, this shop will stock out within 48 hours, causing statutory denial of food grains to over 490 cardholders.',
        recommendation: 'Upgrade corridor carrier to 10 MT Heavy Hauler (KA-04-E-1021) and release +2.45 MT emergency buffer allocation from Central Hebbal Godown before truck departure.',
        officerActionTitle: 'Authorize Fleet Upgrade & Buffer Release',
      ),
      OperationalIncident(
        id: 'INC-2026-09-02',
        title: 'FPS Storage / Headroom Constraint',
        scenarioBadge: 'STORAGE HEADROOM LIMIT',
        riskCategory: 'STORAGE / CAPACITY CONSTRAINT',
        severity: 'MEDIUM_RISK',
        affectedFps: 'FPS-KA-BLR-008 (Thanisandra Main Road Depot)',
        affectedFpsId: 'FPS-KA-BLR-008',
        affectedTruckId: 'DEMO-KA-04-E-1022 (East Corridor / IT Belt)',
        projectedShortageOrConstraint: 'Safe Storage: 12,000 kg • Planned Dispatch: 14,800 kg',
        supplyAdjustment: 'Excess Dispatch: +2,800 kg (123% Bay Overflow)',
        explanation: 'The planned single-tour delivery of 14,800 kg exceeds the physical covered storage bay capacity of 12,000 kg by 2.8 MT.',
        whyItMatters: 'Excess grain sacks stacked outdoors risk rain/moisture damage, pest contamination, and violate PDS Warehousing Rules.',
        recommendation: 'Split delivery schedule into 2 staggered deliveries: Trip 1 (8.0 MT Morning) + Trip 2 (6.8 MT Evening) once initial day lifting clears bay headroom.',
        officerActionTitle: 'Split Into 2 Staggered Delivery Schedules',
      ),
      OperationalIncident(
        id: 'INC-2026-09-03',
        title: 'Low Inventory / Critical Stockout Risk',
        scenarioBadge: 'STOCKOUT RISK (< 18 HRS)',
        riskCategory: 'LOW INVENTORY / STOCKOUT RISK',
        severity: 'HIGH_RISK',
        affectedFps: 'FPS-KA-BLR-015 (K.R. Puram Market Center)',
        affectedFpsId: 'FPS-KA-BLR-015',
        affectedTruckId: 'DEMO-KA-51-M-3419 (South Industrial Corridor)',
        projectedShortageOrConstraint: 'Current Stock: 350 kg • Expected Influx Demand: 3,200 kg',
        supplyAdjustment: 'Critical Depletion: < 18 Hours to Total Zero-Stock',
        explanation: 'Opening inventory has dropped to 350 kg (below the 1,200 kg statutory 3-day buffer threshold) due to high initial lifting rate.',
        whyItMatters: 'Immediate risk of biometric transaction denials at the ePoS terminal during the peak morning ration distribution rush.',
        recommendation: 'Reprioritize K.R. Puram as Sequence Stop #1 in the East Corridor route and expedite digital gatepass clearance with immediate 2.85 MT replenishment.',
        officerActionTitle: 'Reprioritize Route Sequence to Stop #1 & Expedite',
      ),
    ];
  }
}











