import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/constants.dart';
import '../models/health_model.dart';
import '../models/beneficiary_model.dart';
import '../models/admin_model.dart';
import '../models/scarcity_model.dart';

class ApiService {
  final http.Client client;

  ApiService({http.Client? client}) : client = client ?? http.Client();

  /// Performs a live health-check diagnostic ping against the FastAPI backend.
  Future<HealthModel> checkHealth({String? customUrl}) async {
    final url = Uri.parse(customUrl ?? '${AppConstants.apiBaseUrl}/health');
    final stopwatch = Stopwatch()..start();

    try {
      final response = await client
          .get(url, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 8));

      stopwatch.stop();
      final latency = stopwatch.elapsedMilliseconds;

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return HealthModel.fromJson(data, latency);
      } else {
        throw Exception(
            'Health-check failed with HTTP status ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      stopwatch.stop();
      rethrow;
    }
  }

  /// Retrieve list of demo beneficiaries for login selector
  Future<List<Beneficiary>> fetchBeneficiaries(
      {int limit = 100, int offset = 0, String? search}) async {
    String endpoint = '${AppConstants.apiBaseUrl}/beneficiaries?limit=$limit&offset=$offset';
    if (search != null && search.isNotEmpty) {
      endpoint += '&search=${Uri.encodeComponent(search)}';
    }

    final response = await client
        .get(Uri.parse(endpoint), headers: {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 8));

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      final items = data['items'] as List<dynamic>;
      return items.map((item) => Beneficiary.fromJson(item)).toList();
    } else {
      throw Exception('Failed to fetch beneficiaries: ${response.statusCode}');
    }
  }

  /// Retrieve detailed beneficiary profile with registered FPS and active intents
  Future<Beneficiary> fetchBeneficiaryDetail(String id) async {
    final response = await client
        .get(Uri.parse('${AppConstants.apiBaseUrl}/beneficiaries/$id'),
            headers: {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 8));

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      return Beneficiary.fromJson(data);
    } else {
      throw Exception('Failed to fetch beneficiary $id: ${response.statusCode}');
    }
  }

  /// Retrieve list of all Fair Price Shops with inventory and capacities
  Future<List<FpsShop>> fetchFpsList() async {
    final response = await client
        .get(Uri.parse('${AppConstants.apiBaseUrl}/fps'),
            headers: {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 8));

    if (response.statusCode == 200) {
      final list = json.decode(response.body) as List<dynamic>;
      return list.map((item) => FpsShop.fromJson(item)).toList();
    } else {
      throw Exception('Failed to fetch FPS list: ${response.statusCode}');
    }
  }

  /// Submit a forward-looking intent declaration for a commodity
  Future<IntentRecord> submitSingleIntent({
    required String beneficiaryId,
    required String intendedFpsId,
    required String commodity,
    required double quantityKg,
    String cycleId = '2026-09',
    double confidence = 0.95,
  }) async {
    final payload = {
      'beneficiary_id': beneficiaryId,
      'cycle_id': cycleId,
      'intended_fps_id': intendedFpsId,
      'commodity': commodity,
      'declared_quantity_kg': quantityKg,
      'confidence': confidence,
    };

    final response = await client
        .post(
          Uri.parse('${AppConstants.apiBaseUrl}/intent'),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: json.encode(payload),
        )
        .timeout(const Duration(seconds: 8));

    if (response.statusCode == 201 || response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      return IntentRecord.fromJson(data);
    } else {
      final err = json.decode(response.body);
      throw Exception(
          'Failed to submit intent: ${err['detail'] ?? response.statusCode}');
    }
  }

  /// Submit intent for selected commodity option ('Rice', 'Wheat', or 'Both')
  Future<List<IntentRecord>> submitIntent({
    required String beneficiaryId,
    required String intendedFpsId,
    required String commodityOption, // 'Rice', 'Wheat', 'Both'
    required double riceQuantityKg,
    required double wheatQuantityKg,
    String cycleId = '2026-09',
    double confidence = 0.95,
  }) async {
    List<IntentRecord> results = [];

    if (commodityOption == 'Rice' || commodityOption == 'Both') {
      final riceRes = await submitSingleIntent(
        beneficiaryId: beneficiaryId,
        intendedFpsId: intendedFpsId,
        commodity: 'Rice',
        quantityKg: riceQuantityKg,
        cycleId: cycleId,
        confidence: confidence,
      );
      results.add(riceRes);
    }

    if (commodityOption == 'Wheat' || commodityOption == 'Both') {
      final wheatRes = await submitSingleIntent(
        beneficiaryId: beneficiaryId,
        intendedFpsId: intendedFpsId,
        commodity: 'Wheat',
        quantityKg: wheatQuantityKg,
        cycleId: cycleId,
        confidence: confidence,
      );
      results.add(wheatRes);
    }

    return results;
  }

  /// Retrieve declared intent history for a beneficiary
  Future<List<IntentRecord>> fetchBeneficiaryIntents(String beneficiaryId,
      {String? cycleId}) async {
    String endpoint =
        '${AppConstants.apiBaseUrl}/intents?beneficiary_id=$beneficiaryId';
    if (cycleId != null && cycleId.isNotEmpty) {
      endpoint += '&cycle_id=$cycleId';
    }

    final response = await client
        .get(Uri.parse(endpoint), headers: {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 8));

    if (response.statusCode == 200) {
      final list = json.decode(response.body) as List<dynamic>;
      return list.map((item) => IntentRecord.fromJson(item)).toList();
    } else {
      throw Exception('Failed to fetch intents: ${response.statusCode}');
    }
  }

  // ----------------- District Admin Endpoints ----------------- //

  /// Retrieve aggregated district admin dashboard metrics and FPS matrix
  Future<AdminDashboardData> fetchAdminDashboard() async {
    final response = await client
        .get(Uri.parse('${AppConstants.apiBaseUrl}/admin/dashboard'),
            headers: {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 8));

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      return AdminDashboardData.fromJson(data);
    } else {
      throw Exception(
          'Failed to load admin dashboard data: ${response.statusCode}');
    }
  }

  /// Retrieve deep-dive analytics for an individual FPS
  Future<AdminFpsDetail> fetchAdminFpsDetail(String fpsId) async {
    final response = await client
        .get(Uri.parse('${AppConstants.apiBaseUrl}/admin/fps/$fpsId'),
            headers: {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 8));

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      return AdminFpsDetail.fromJson(data);
    } else {
      throw Exception(
          'Failed to load admin FPS detail for $fpsId: ${response.statusCode}');
    }
  }

  /// Trigger demand forecast generation across all 20 FPS
  Future<Map<String, dynamic>> triggerGenerateForecast() async {
    final response = await client
        .post(Uri.parse('${AppConstants.apiBaseUrl}/admin/forecast/generate'),
            headers: {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 8));

    if (response.statusCode == 200) {
      return json.decode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception(
          'Failed to trigger forecast generation: ${response.statusCode}');
    }
  }

  /// Lock demand forecast and authorize godown allocations
  Future<Map<String, dynamic>> triggerLockForecast() async {
    final response = await client
        .post(Uri.parse('${AppConstants.apiBaseUrl}/admin/forecast/lock'),
            headers: {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 8));

    if (response.statusCode == 200) {
      return json.decode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Failed to lock forecast: ${response.statusCode}');
    }
  }

  /// Retrieve choice window status, preference count, and demand lock status
  Future<Map<String, dynamic>> fetchChoiceWindowStatus({String cycleId = '2026-09'}) async {
    final response = await client
        .get(Uri.parse('${AppConstants.apiBaseUrl}/choice-window/status?cycle_id=$cycleId'),
            headers: {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 8));

    if (response.statusCode == 200) {
      return json.decode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Failed to fetch choice window status: ${response.statusCode}');
    }
  }

  /// Close the choice window and lock aggregated beneficiary demand
  Future<Map<String, dynamic>> closeChoiceWindow({String cycleId = '2026-09'}) async {
    final response = await client
        .post(Uri.parse('${AppConstants.apiBaseUrl}/admin/choice-window/close?cycle_id=$cycleId'),
            headers: {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 8));

    if (response.statusCode == 200) {
      return json.decode(response.body) as Map<String, dynamic>;
    } else {
      final err = json.decode(response.body);
      throw Exception(err['detail'] ?? 'Failed to close choice window: ${response.statusCode}');
    }
  }

  /// Trigger multi-echelon godown dispatch generation from locked forecasts
  Future<DispatchManifestData> triggerGenerateDispatch(
      {String cycleId = '2026-09', bool force = false}) async {
    final response = await client
        .post(
            Uri.parse(
                '${AppConstants.apiBaseUrl}/admin/dispatch/generate?cycle_id=$cycleId&force=$force'),
            headers: {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 8));

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      return DispatchManifestData.fromJson(data);
    } else {
      final err = json.decode(response.body);
      throw Exception(
          'Failed to generate dispatch: ${err['detail'] ?? response.statusCode}');
    }
  }

  /// Retrieve full dispatch manifest including truck fleet groupings and drops
  Future<DispatchManifestData> fetchDispatchManifest(
      {String cycleId = '2026-09'}) async {
    final response = await client
        .get(
            Uri.parse(
                '${AppConstants.apiBaseUrl}/admin/dispatch/manifest?cycle_id=$cycleId'),
            headers: {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 8));

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      return DispatchManifestData.fromJson(data);
    } else {
      throw Exception(
          'Failed to fetch dispatch manifest: ${response.statusCode}');
    }
  }

  /// Safe demo reset mechanism to return workflow state to PLANNING_OPEN
  Future<Map<String, dynamic>> resetDemoWorkflow(
      {String cycleId = '2026-09'}) async {
    final response = await client
        .post(
            Uri.parse(
                '${AppConstants.apiBaseUrl}/admin/demo/reset?cycle_id=$cycleId'),
            headers: {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 8));

    if (response.statusCode == 200) {
      return json.decode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Failed to reset demo workflow: ${response.statusCode}');
    }
  }

  /// Trigger actual ePoS grain distribution simulation
  Future<ActualDistributionData> triggerSimulateDistribution(
      {String cycleId = '2026-09', bool force = false}) async {
    final response = await client
        .post(
            Uri.parse(
                '${AppConstants.apiBaseUrl}/admin/distribution/simulate?cycle_id=$cycleId&force=$force'),
            headers: {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 8));

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      final list = (data['records'] as List<dynamic>?)
              ?.map((e) => ActualDistributionRecord.fromJson(e))
              .toList() ??
          [];
      return ActualDistributionData(
        status: data['status'] ?? 'success',
        workflowStatus: data['workflow_status'] ?? 'ACTUAL_DISTRIBUTION_SIMULATED',
        cycleId: data['cycle_id'] ?? cycleId,
        totalActualQuantityKg:
            (data['total_actual_quantity_kg'] as num?)?.toDouble() ?? 0.0,
        totalRiceActualKg:
            (data['total_rice_actual_kg'] as num?)?.toDouble() ?? 0.0,
        totalWheatActualKg:
            (data['total_wheat_actual_kg'] as num?)?.toDouble() ?? 0.0,
        totalDispatchQuantityKg:
            (data['total_dispatch_quantity_kg'] as num?)?.toDouble() ?? 0.0,
        totalVarianceKg:
            (data['total_variance_kg'] as num?)?.toDouble() ?? 0.0,
        totalFpsCount: data['total_fps_count'] ?? 0,
        simulatedRecordsCount: data['simulated_records_count'] ?? 0,
        records: list,
        message: data['message'] ?? '',
      );
    } else {
      final err = json.decode(response.body);
      throw Exception(
          'Failed to simulate distribution: ${err['detail'] ?? response.statusCode}');
    }
  }

  /// Retrieve forecast vs actual evaluation metrics (MAE, MAPE, Accuracy)
  Future<ForecastEvaluationData> fetchForecastEvaluation(
      {String cycleId = '2026-09'}) async {
    final response = await client
        .get(
            Uri.parse(
                '${AppConstants.apiBaseUrl}/admin/evaluation?cycle_id=$cycleId'),
            headers: {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 8));

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      return ForecastEvaluationData.fromJson(data);
    } else {
      final err = json.decode(response.body);
      throw Exception(
          'Failed to fetch forecast evaluation: ${err['detail'] ?? response.statusCode}');
    }
  }

  /// Trigger closed-loop ML model calibration using scikit-learn
  Future<ModelCalibrationData> triggerModelCalibration(
      {String cycleId = '2026-09'}) async {
    final response = await client
        .post(
            Uri.parse(
                '${AppConstants.apiBaseUrl}/admin/calibrate?cycle_id=$cycleId'),
            headers: {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 8));

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      return ModelCalibrationData.fromJson(data);
    } else {
      final err = json.decode(response.body);
      throw Exception(
          'Failed to calibrate model: ${err['detail'] ?? response.statusCode}');
    }
  }

  // ----------------- Pre-Dispatch Decision Intelligence APIs ----------------- //

  /// Run district-wide 6-rule constraint validation audit
  Future<DistrictConstraintAudit> fetchConstraintAudit(
      {String cycleId = '2026-09'}) async {
    final response = await client
        .get(
            Uri.parse(
                '${AppConstants.apiBaseUrl}/admin/constraints/validate?cycle_id=$cycleId'),
            headers: {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 8));

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      return DistrictConstraintAudit.fromJson(data);
    } else {
      final err = json.decode(response.body);
      throw Exception(
          'Failed to validate constraints: ${err['detail'] ?? response.statusCode}');
    }
  }

  /// Run single FPS operational constraint validation
  Future<FpsConstraintResult> fetchFpsConstraints(String fpsId,
      {String cycleId = '2026-09'}) async {
    final response = await client
        .get(
            Uri.parse(
                '${AppConstants.apiBaseUrl}/admin/constraints/fps/$fpsId?cycle_id=$cycleId'),
            headers: {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 8));

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      return FpsConstraintResult.fromJson(data);
    } else {
      final err = json.decode(response.body);
      throw Exception(
          'Failed to fetch FPS constraints: ${err['detail'] ?? response.statusCode}');
    }
  }

  /// Run multi-corridor route sequencing, cost modeling, and dispatch scoring
  Future<DistrictOptimizationResult> fetchOptimizationResult(
      {String cycleId = '2026-09'}) async {
    final response = await client
        .get(
            Uri.parse(
                '${AppConstants.apiBaseUrl}/admin/optimization/run?cycle_id=$cycleId'),
            headers: {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 8));

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      return DistrictOptimizationResult.fromJson(data);
    } else {
      final err = json.decode(response.body);
      throw Exception(
          'Failed to run optimization: ${err['detail'] ?? response.statusCode}');
    }
  }

  /// Retrieve all Digital Pre-Dispatch Gatepasses
  Future<List<DigitalGatepass>> fetchAllGatepasses(
      {String cycleId = '2026-09'}) async {
    final response = await client
        .get(
            Uri.parse(
                '${AppConstants.apiBaseUrl}/admin/gatepasses?cycle_id=$cycleId'),
            headers: {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 8));

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      final list = data['gatepasses'] as List<dynamic>? ?? [];
      return list.map((e) => DigitalGatepass.fromJson(e)).toList();
    } else {
      final err = json.decode(response.body);
      throw Exception(
          'Failed to fetch gatepasses: ${err['detail'] ?? response.statusCode}');
    }
  }

  /// Retrieve single truck gatepass
  Future<DigitalGatepass> fetchTruckGatepass(String truckId,
      {String cycleId = '2026-09'}) async {
    final response = await client
        .get(
            Uri.parse(
                '${AppConstants.apiBaseUrl}/admin/gatepass/$truckId?cycle_id=$cycleId'),
            headers: {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 8));

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      return DigitalGatepass.fromJson(data);
    } else {
      final err = json.decode(response.body);
      throw Exception(
          'Failed to fetch truck gatepass: ${err['detail'] ?? response.statusCode}');
    }
  }

  /// Advance gatepass through 5-stage pre-dispatch event pipeline
  Future<DigitalGatepass> advanceGatepassStage(
      String gatepassId, String targetStatus) async {
    final response = await client
        .post(
            Uri.parse(
                '${AppConstants.apiBaseUrl}/admin/gatepass/$gatepassId/advance?target_status=$targetStatus'),
            headers: {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 8));

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      return DigitalGatepass.fromJson(data);
    } else {
      final err = json.decode(response.body);
      throw Exception(
          'Failed to advance gatepass: ${err['detail'] ?? response.statusCode}');
    }
  }

  /// Trigger simulated multi-channel WhatsApp/SMS/IVR alert notifications
  Future<NotificationDispatchResult> triggerAlertNotifications(
      {String cycleId = '2026-09'}) async {
    final response = await client
        .post(
            Uri.parse(
                '${AppConstants.apiBaseUrl}/admin/notifications/dispatch?cycle_id=$cycleId'),
            headers: {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 8));

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      return NotificationDispatchResult.fromJson(data);
    } else {
      final err = json.decode(response.body);
      throw Exception(
          'Failed to dispatch notifications: ${err['detail'] ?? response.statusCode}');
    }
  }

  /// Fetch notification logs
  Future<List<NotificationLogRecord>> fetchNotificationLogs(
      {String cycleId = '2026-09', String? recipientType}) async {
    String url =
        '${AppConstants.apiBaseUrl}/admin/notifications/logs?cycle_id=$cycleId';
    if (recipientType != null) {
      url += '&recipient_type=$recipientType';
    }

    final response = await client
        .get(Uri.parse(url), headers: {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 8));

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      final list = data['logs'] as List<dynamic>? ?? [];
      return list.map((e) => NotificationLogRecord.fromJson(e)).toList();
    } else {
      final err = json.decode(response.body);
      throw Exception(
          'Failed to fetch notification logs: ${err['detail'] ?? response.statusCode}');
    }
  }

  // ----------------- Phase 1: Command Center & Pre-Dispatch Intelligence Layer ----------------- //

  /// Fetch full Command Center dashboard payload
  Future<CommandCenterData> fetchCommandCenter({
    String cycleId = '2026-09',
    String? district,
    String? depotId,
    String? statusFilter,
  }) async {
    String url = '${AppConstants.apiBaseUrl}/admin/command-center?cycle_id=$cycleId';
    if (district != null && district.isNotEmpty) url += '&district=$district';
    if (depotId != null && depotId.isNotEmpty) url += '&depot_id=$depotId';
    if (statusFilter != null && statusFilter.isNotEmpty) {
      url += '&status_filter=$statusFilter';
    }

    final response = await client
        .get(Uri.parse(url), headers: {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 8));

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      return CommandCenterData.fromJson(data);
    } else {
      final err = json.decode(response.body);
      throw Exception(
          'Failed to fetch command center data: ${err['detail'] ?? response.statusCode}');
    }
  }

  /// Fetch deep-dive operational analytics profile for a specific FPS
  Future<FpsAnalyticsProfile> fetchFpsAnalytics(String fpsId,
      {String cycleId = '2026-09'}) async {
    final response = await client
        .get(
            Uri.parse(
                '${AppConstants.apiBaseUrl}/admin/fps/$fpsId/analytics?cycle_id=$cycleId'),
            headers: {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 8));

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      return FpsAnalyticsProfile.fromJson(data);
    } else {
      final err = json.decode(response.body);
      throw Exception(
          'Failed to fetch FPS analytics: ${err['detail'] ?? response.statusCode}');
    }
  }

  /// Retrieve all supply-chain routes
  Future<List<SupplyRoute>> fetchSupplyRoutes() async {
    final response = await client
        .get(Uri.parse('${AppConstants.apiBaseUrl}/admin/routes'),
            headers: {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 8));

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      final list = data['routes'] as List<dynamic>? ?? [];
      return list.map((e) => SupplyRoute.fromJson(e)).toList();
    } else {
      final err = json.decode(response.body);
      throw Exception(
          'Failed to fetch supply routes: ${err['detail'] ?? response.statusCode}');
    }
  }

  /// Execute 'Run Pre-Dispatch Analysis' pipeline
  Future<PreDispatchAnalysisResult> runPreDispatchAnalysis(
      {String? fpsId, String cycleId = '2026-09'}) async {
    String url = '${AppConstants.apiBaseUrl}/admin/analysis/run?cycle_id=$cycleId';
    if (fpsId != null && fpsId.isNotEmpty) {
      url += '&fps_id=$fpsId';
    }

    final response = await client
        .post(Uri.parse(url), headers: {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      return PreDispatchAnalysisResult.fromJson(data);
    } else {
      final err = json.decode(response.body);
      throw Exception(
          'Failed to execute pre-dispatch analysis: ${err['detail'] ?? response.statusCode}');
    }
  }

  // ----------------- Phase 2: Explainable Demand Forecasting & What-If Simulation ----------------- //

  /// Fetch explainable multi-factor forecast for a specific FPS
  Future<FpsForecastDetail> fetchFpsForecastDetail(String fpsId,
      {String cycleId = '2026-09'}) async {
    final response = await client
        .get(
            Uri.parse(
                '${AppConstants.apiBaseUrl}/admin/fps/$fpsId/forecast?cycle_id=$cycleId'),
            headers: {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 8));

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      return FpsForecastDetail.fromJson(data);
    } else {
      final err = json.decode(response.body);
      throw Exception(
          'Failed to fetch FPS forecast detail: ${err['detail'] ?? response.statusCode}');
    }
  }

  /// Run real-time What-If scenario forecasting simulation
  Future<WhatIfSimulationResult> simulateFpsWhatIfForecast(
    String fpsId, {
    int? beneficiariesCount,
    double? seasonalFactor,
    double? portabilityRate,
    double? stockoutFrequency,
    String cycleId = '2026-09',
  }) async {
    final body = json.encode({
      if (beneficiariesCount != null) 'beneficiaries_count': beneficiariesCount,
      if (seasonalFactor != null) 'seasonal_factor': seasonalFactor,
      if (portabilityRate != null) 'portability_rate': portabilityRate,
      if (stockoutFrequency != null) 'stockout_frequency': stockoutFrequency,
    });

    final response = await client
        .post(
            Uri.parse(
                '${AppConstants.apiBaseUrl}/admin/fps/$fpsId/forecast/what-if?cycle_id=$cycleId'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json'
            },
            body: body)
        .timeout(const Duration(seconds: 8));

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      return WhatIfSimulationResult.fromJson(data);
    } else {
      final err = json.decode(response.body);
      throw Exception(
          'Failed to simulate what-if forecast: ${err['detail'] ?? response.statusCode}');
    }
  }

  /// Fetch district aggregated forecast summary
  Future<Map<String, dynamic>> fetchDistrictForecastSummary(
      {String cycleId = '2026-09'}) async {
    final response = await client
        .get(
            Uri.parse(
                '${AppConstants.apiBaseUrl}/admin/forecast/district-summary?cycle_id=$cycleId'),
            headers: {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 8));

    if (response.statusCode == 200) {
      return json.decode(response.body) as Map<String, dynamic>;
    } else {
      final err = json.decode(response.body);
      throw Exception(
          'Failed to fetch district forecast summary: ${err['detail'] ?? response.statusCode}');
    }
  }

  // ----------------- Phase 3: Dispatch Decision Engine & Scenarios ----------------- //

  /// Fetch full dispatch decision dossier and evaluated scenarios
  Future<DispatchDecisionProfile> fetchDispatchDecision(String fpsId,
      {String scenario = 'NORMAL', String cycleId = '2026-09'}) async {
    final response = await client
        .get(
            Uri.parse(
                '${AppConstants.apiBaseUrl}/admin/fps/$fpsId/dispatch-decision?scenario=$scenario&cycle_id=$cycleId'),
            headers: {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 8));

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      return DispatchDecisionProfile.fromJson(data);
    } else {
      final err = json.decode(response.body);
      throw Exception(
          'Failed to fetch dispatch decision: ${err['detail'] ?? response.statusCode}');
    }
  }

  /// Recalculate dispatch decision with custom safety parameters
  Future<DispatchDecisionProfile> calculateCustomDispatchDecision(
    String fpsId, {
    String scenario = 'NORMAL',
    double? leadTimeDays,
    double? stockoutRisk,
    String cycleId = '2026-09',
  }) async {
    final body = json.encode({
      'scenario': scenario,
      if (leadTimeDays != null) 'lead_time_days': leadTimeDays,
      if (stockoutRisk != null) 'stockout_risk': stockoutRisk,
    });

    final response = await client
        .post(
            Uri.parse(
                '${AppConstants.apiBaseUrl}/admin/fps/$fpsId/dispatch-decision/calculate?cycle_id=$cycleId'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json'
            },
            body: body)
        .timeout(const Duration(seconds: 8));

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      return DispatchDecisionProfile.fromJson(data);
    } else {
      final err = json.decode(response.body);
      throw Exception(
          'Failed to recalculate dispatch decision: ${err['detail'] ?? response.statusCode}');
    }
  }

  /// Save dispatch recommendation for downstream constraint validation
  Future<Map<String, dynamic>> saveDispatchDecision(
    String fpsId, {
    String scenario = 'NORMAL',
    double? recommendedDispatchKg,
    String cycleId = '2026-09',
  }) async {
    final body = json.encode({
      'scenario': scenario,
      if (recommendedDispatchKg != null)
        'recommended_dispatch_kg': recommendedDispatchKg,
    });

    final response = await client
        .post(
            Uri.parse(
                '${AppConstants.apiBaseUrl}/admin/fps/$fpsId/dispatch-decision/save?cycle_id=$cycleId'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json'
            },
            body: body)
        .timeout(const Duration(seconds: 8));

    if (response.statusCode == 200) {
      return json.decode(response.body) as Map<String, dynamic>;
    } else {
      final err = json.decode(response.body);
      throw Exception(
          'Failed to save dispatch decision: ${err['detail'] ?? response.statusCode}');
    }
  }

  /// Fetch district aggregated dispatch decisions
  Future<Map<String, dynamic>> fetchDistrictDispatchDecisionsSummary(
      {String cycleId = '2026-09'}) async {
    final response = await client
        .get(
            Uri.parse(
                '${AppConstants.apiBaseUrl}/admin/dispatch-decisions/district-summary?cycle_id=$cycleId'),
            headers: {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 8));

    if (response.statusCode == 200) {
      return json.decode(response.body) as Map<String, dynamic>;
    } else {
      final err = json.decode(response.body);
      throw Exception(
          'Failed to fetch district dispatch summary: ${err['detail'] ?? response.statusCode}');
    }
  }

  // ----------------- Phase 4: 9-Rule Constraint & Validation Engine ----------------- //

  /// Fetch full district-wide 9-rule constraint audit
  Future<ConstraintAuditResult> fetchDistrictConstraints(
      {String cycleId = '2026-09', String scenario = 'NORMAL'}) async {
    final response = await client
        .get(
            Uri.parse(
                '${AppConstants.apiBaseUrl}/admin/constraints/validate?cycle_id=$cycleId&scenario=$scenario'),
            headers: {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 8));

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      return ConstraintAuditResult.fromJson(data);
    } else {
      final err = json.decode(response.body);
      throw Exception(
          'Failed to validate district constraints: ${err['detail'] ?? response.statusCode}');
    }
  }

  /// Fetch single FPS 9-rule constraint evaluation
  Future<SingleFpsConstraintResult> fetchSingleFpsNineRuleConstraints(
      String fpsId,
      {String scenario = 'NORMAL',
      String cycleId = '2026-09'}) async {
    final response = await client
        .get(
            Uri.parse(
                '${AppConstants.apiBaseUrl}/admin/fps/$fpsId/constraints?cycle_id=$cycleId&scenario=$scenario'),
            headers: {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 8));

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      return SingleFpsConstraintResult.fromJson(data);
    } else {
      final err = json.decode(response.body);
      throw Exception(
          'Failed to fetch FPS constraints: ${err['detail'] ?? response.statusCode}');
    }
  }

  /// Execute interactive constraint resolution action
  Future<ResolveConstraintResponse> resolveFpsConstraint(
    String fpsId,
    String action, {
    Map<String, dynamic>? parameters,
    String cycleId = '2026-09',
  }) async {
    final body = json.encode({
      'action': action,
      if (parameters != null) 'parameters': parameters,
    });

    final response = await client
        .post(
            Uri.parse(
                '${AppConstants.apiBaseUrl}/admin/fps/$fpsId/constraints/resolve?cycle_id=$cycleId'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json'
            },
            body: body)
        .timeout(const Duration(seconds: 8));

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      return ResolveConstraintResponse.fromJson(data);
    } else {
      final err = json.decode(response.body);
      throw Exception(
          'Failed to resolve constraint: ${err['detail'] ?? response.statusCode}');
    }
  }

  /// Revalidate all district constraints
  Future<ConstraintAuditResult> revalidateConstraints(
      {String cycleId = '2026-09', String scenario = 'NORMAL'}) async {
    final response = await client
        .post(
            Uri.parse(
                '${AppConstants.apiBaseUrl}/admin/constraints/revalidate?cycle_id=$cycleId&scenario=$scenario'),
            headers: {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 8));

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      return ConstraintAuditResult.fromJson(data);
    } else {
      final err = json.decode(response.body);
      throw Exception(
          'Failed to revalidate constraints: ${err['detail'] ?? response.statusCode}');
    }
  }

  // ----------------- Phase 5: Multi-Candidate Dispatch Optimization Engine ----------------- //

  /// Fetch full district-wide multi-corridor dispatch optimization payload
  Future<DistrictOptimizationPayload> fetchDistrictOptimizationPayload(
      {String cycleId = '2026-09'}) async {
    final response = await client
        .get(
            Uri.parse(
                '${AppConstants.apiBaseUrl}/admin/optimization/run?cycle_id=$cycleId'),
            headers: {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 8));

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      return DistrictOptimizationPayload.fromJson(data);
    } else {
      final err = json.decode(response.body);
      throw Exception(
          'Failed to fetch optimization payload: ${err['detail'] ?? response.statusCode}');
    }
  }

  /// Retrieve corridor optimization dossier and evaluated candidates
  Future<CorridorOptimizationDossier> fetchCorridorOptimization(String truckId,
      {String cycleId = '2026-09'}) async {
    final response = await client
        .get(
            Uri.parse(
                '${AppConstants.apiBaseUrl}/admin/optimization/corridor/$truckId?cycle_id=$cycleId'),
            headers: {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 8));

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      return CorridorOptimizationDossier.fromJson(data);
    } else {
      final err = json.decode(response.body);
      throw Exception(
          'Failed to fetch corridor optimization: ${err['detail'] ?? response.statusCode}');
    }
  }

  /// Simulate What-If optimization with custom vehicle capacity, fuel cost, route condition, or departure window
  Future<CorridorOptimizationDossier> simulateWhatIfOptimization({
    String truckId = 'DEMO-KA-04-E-1021',
    double? vehicleCapacityKg,
    double? fuelCostPerKm,
    String? routeCondition,
    String? departureWindow,
    String cycleId = '2026-09',
  }) async {
    final body = json.encode({
      'truck_id': truckId,
      if (vehicleCapacityKg != null) 'vehicle_capacity_kg': vehicleCapacityKg,
      if (fuelCostPerKm != null) 'fuel_cost_per_km': fuelCostPerKm,
      if (routeCondition != null) 'route_condition': routeCondition,
      if (departureWindow != null) 'departure_window': departureWindow,
    });

    final response = await client
        .post(
            Uri.parse(
                '${AppConstants.apiBaseUrl}/admin/optimization/what-if?cycle_id=$cycleId'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json'
            },
            body: body)
        .timeout(const Duration(seconds: 8));

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      return CorridorOptimizationDossier.fromJson(data);
    } else {
      final err = json.decode(response.body);
      throw Exception(
          'Failed to simulate what-if optimization: ${err['detail'] ?? response.statusCode}');
    }
  }

  // ----------------- Phase 6: Auditable Manifest Generation & Lock APIs ----------------- //

  /// Fetch all manifests for active cycle
  Future<ManifestListPayload> fetchManifestList(
      {String cycleId = '2026-09'}) async {
    final response = await client
        .get(
            Uri.parse(
                '${AppConstants.apiBaseUrl}/admin/manifests?cycle_id=$cycleId'),
            headers: {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 8));

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      return ManifestListPayload.fromJson(data);
    } else {
      final err = json.decode(response.body);
      throw Exception(
          'Failed to fetch manifests list: ${err['detail'] ?? response.statusCode}');
    }
  }

  /// Retrieve full dossier for a specific manifest including immutable audit trail
  Future<DispatchManifestDossier> fetchManifestDetails(
      String manifestId) async {
    final response = await client
        .get(
            Uri.parse(
                '${AppConstants.apiBaseUrl}/admin/manifests/$manifestId'),
            headers: {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 8));

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      return DispatchManifestDossier.fromJson(data);
    } else {
      final err = json.decode(response.body);
      throw Exception(
          'Failed to fetch manifest details: ${err['detail'] ?? response.statusCode}');
    }
  }

  /// Generate or retrieve a pre-dispatch manifest for a vehicle corridor
  Future<DispatchManifestDossier> generateCorridorManifest({
    String truckId = 'DEMO-KA-04-E-1021',
    String cycleId = '2026-09',
  }) async {
    final response = await client
        .post(
            Uri.parse(
                '${AppConstants.apiBaseUrl}/admin/manifests/generate?truck_id=$truckId&cycle_id=$cycleId'),
            headers: {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 8));

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      return DispatchManifestDossier.fromJson(data);
    } else {
      final err = json.decode(response.body);
      throw Exception(
          'Failed to generate corridor manifest: ${err['detail'] ?? response.statusCode}');
    }
  }

  /// Update mutable fields of a DRAFT manifest (quantity, truck, route, window)
  Future<DispatchManifestDossier> updateDraftManifest(
    String manifestId, {
    String? truckId,
    double? totalQuantityKg,
    String? routeType,
    String? departureWindow,
    String? actorName,
    String? actorRole,
    String? modificationReason,
  }) async {
    final body = json.encode({
      if (truckId != null) 'truck_id': truckId,
      if (totalQuantityKg != null) 'total_quantity_kg': totalQuantityKg,
      if (routeType != null) 'route_type': routeType,
      if (departureWindow != null) 'departure_window': departureWindow,
      if (actorName != null) 'actor_name': actorName,
      if (actorRole != null) 'actor_role': actorRole,
      if (modificationReason != null)
        'modification_reason': modificationReason,
    });

    final response = await client
        .post(
            Uri.parse(
                '${AppConstants.apiBaseUrl}/admin/manifests/$manifestId/update'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json'
            },
            body: body)
        .timeout(const Duration(seconds: 8));

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      return DispatchManifestDossier.fromJson(data);
    } else {
      final err = json.decode(response.body);
      throw Exception(
          'Failed to update manifest: ${err['detail'] ?? response.statusCode}');
    }
  }

  /// Lock manifest, generate cryptographic digital seal, and freeze all critical parameters
  Future<DispatchManifestDossier> lockManifest(
    String manifestId, {
    String? actorName,
    String? actorRole,
    String? lockReason,
  }) async {
    final body = json.encode({
      if (actorName != null) 'actor_name': actorName,
      if (actorRole != null) 'actor_role': actorRole,
      if (lockReason != null) 'lock_reason': lockReason,
    });

    final response = await client
        .post(
            Uri.parse(
                '${AppConstants.apiBaseUrl}/admin/manifests/$manifestId/lock'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json'
            },
            body: body)
        .timeout(const Duration(seconds: 8));

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      return DispatchManifestDossier.fromJson(data);
    } else {
      final err = json.decode(response.body);
      throw Exception(
          'Failed to lock manifest: ${err['detail'] ?? response.statusCode}');
    }
  }

  /// Create a new authorized revision of a LOCKED manifest (e.g. v1.0 -> v1.1)
  Future<DispatchManifestDossier> reviseManifest(
    String manifestId, {
    required String revisionReason,
    String? actorName,
    String? actorRole,
  }) async {
    final body = json.encode({
      'revision_reason': revisionReason,
      if (actorName != null) 'actor_name': actorName,
      if (actorRole != null) 'actor_role': actorRole,
    });

    final response = await client
        .post(
            Uri.parse(
                '${AppConstants.apiBaseUrl}/admin/manifests/$manifestId/revise'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json'
            },
            body: body)
        .timeout(const Duration(seconds: 8));

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      return DispatchManifestDossier.fromJson(data);
    } else {
      final err = json.decode(response.body);
      throw Exception(
          'Failed to revise manifest: ${err['detail'] ?? response.statusCode}');
    }
  }

  // ----------------- Phase 8: SIH Demo Mode & Closed-Loop Delivery Feedback APIs ----------------- //

  /// Fetch all available preconfigured SIH demo scenarios
  Future<List<SihDemoScenario>> fetchSihDemoScenarios() async {
    final response = await client
        .get(Uri.parse('${AppConstants.apiBaseUrl}/admin/demo/scenarios'),
            headers: {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 8));

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      final list = (data['scenarios'] as List<dynamic>?)
              ?.map((e) => SihDemoScenario.fromJson(e))
              .toList() ??
          [];
      return list;
    } else {
      final err = json.decode(response.body);
      throw Exception(
          'Failed to fetch SIH demo scenarios: ${err['detail'] ?? response.statusCode}');
    }
  }

  /// Run entire 14-step operational intelligence workflow for a selected scenario
  Future<DemoScenarioExecutionResult> runSihDemoScenario({
    String scenarioId = 'SCENARIO_1',
    String? targetFpsId,
    String cycleId = '2026-09',
  }) async {
    final body = json.encode({
      'scenario_id': scenarioId,
      if (targetFpsId != null) 'target_fps_id': targetFpsId,
      'cycle_id': cycleId,
    });

    final response = await client
        .post(
            Uri.parse('${AppConstants.apiBaseUrl}/admin/demo/scenario/run'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json'
            },
            body: body)
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      return DemoScenarioExecutionResult.fromJson(data);
    } else {
      final err = json.decode(response.body);
      throw Exception(
          'Failed to run SIH demo scenario: ${err['detail'] ?? response.statusCode}');
    }
  }

  /// Record user-entered / simulated actual offtake for an FPS and calculate residual accuracy
  Future<FpsOfftakeFeedbackResult> recordActualOfftake({
    required String fpsId,
    required double actualRiceKg,
    required double actualWheatKg,
    String cycleId = '2026-09',
  }) async {
    final body = json.encode({
      'fps_id': fpsId,
      'actual_rice_kg': actualRiceKg,
      'actual_wheat_kg': actualWheatKg,
      'cycle_id': cycleId,
    });

    final response = await client
        .post(
            Uri.parse(
                '${AppConstants.apiBaseUrl}/admin/evaluation/offtake/record'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json'
            },
            body: body)
        .timeout(const Duration(seconds: 8));

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      return FpsOfftakeFeedbackResult.fromJson(data);
    } else {
      final err = json.decode(response.body);
      throw Exception(
          'Failed to record actual offtake: ${err['detail'] ?? response.statusCode}');
    }
  }

  /// Fetch System Impact Dashboard before vs after metrics & value chain
  Future<SystemImpactDashboardData> fetchSystemImpactData(
      {String cycleId = '2026-09'}) async {
    final response = await client
        .get(
            Uri.parse(
                '${AppConstants.apiBaseUrl}/admin/system-impact?cycle_id=$cycleId'),
            headers: {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 8));

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      return SystemImpactDashboardData.fromJson(data);
    } else {
      final err = json.decode(response.body);
      throw Exception(
          'Failed to fetch system impact metrics: ${err['detail'] ?? response.statusCode}');
    }
  }

  // ----------------- Phase 9: SIH Judge Defense & Architecture View APIs ----------------- //

  /// Fetch SIH Judge View architecture defense and FAQ dossier
  Future<SihJudgeDefenseData> fetchJudgeDefenseView() async {
    final response = await client
        .get(
            Uri.parse('${AppConstants.apiBaseUrl}/admin/judge-view'),
            headers: {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 8));

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      return SihJudgeDefenseData.fromJson(data);
    } else {
      final err = json.decode(response.body);
      throw Exception(
          'Failed to fetch judge defense view: ${err['detail'] ?? response.statusCode}');
    }
  }

  // ----------------- AI-Assisted Stockout Risk & Fair-Share Scarcity Allocation APIs ----------------- //

  /// 1. Fetch real-time depot available stock vs aggregate demand deficit check
  Future<DepotBalanceModel> fetchScarcityDepotBalance({
    String cycleId = '2026-09',
    String depotId = 'DEPOT-01',
    String commodity = 'Rice',
  }) async {
    final uri = Uri.parse(
        '${AppConstants.apiBaseUrl}/admin/scarcity/depot-balance?cycle_id=$cycleId&depot_id=$depotId&commodity=$commodity');
    final response = await client
        .get(uri, headers: {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 8));

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      return DepotBalanceModel.fromJson(data);
    } else {
      final err = json.decode(response.body);
      throw Exception(
          'Failed to fetch depot balance: ${err['detail'] ?? response.statusCode}');
    }
  }

  /// 2. Run server-side ML Logistic Regression stockout risk inference
  Future<RiskPredictionResponseModel> predictStockoutRisk({
    String cycleId = '2026-09',
    String commodity = 'Rice',
    String? fpsId,
    List<String>? fpsIds,
    double? proposedAllocationKg,
  }) async {
    final uri =
        Uri.parse('${AppConstants.apiBaseUrl}/admin/scarcity/predict-risk');
    final Map<String, dynamic> payload = {
      'cycle_id': cycleId,
      'commodity': commodity,
    };
    if (fpsId != null) payload['fps_id'] = fpsId;
    if (fpsIds != null) payload['fps_ids'] = fpsIds;
    if (proposedAllocationKg != null) {
      payload['proposed_allocation_kg'] = proposedAllocationKg;
    }

    final response = await client
        .post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: json.encode(payload),
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      return RiskPredictionResponseModel.fromJson(data);
    } else {
      final err = json.decode(response.body);
      throw Exception(
          'Stockout risk inference failed: ${err['detail'] ?? response.statusCode}');
    }
  }

  /// 3. Simulate three-tier deterministic fair-share scarcity allocation plan
  Future<ScarcityPlanSummaryModel> simulateFairShareScarcity({
    String cycleId = '2026-09',
    String depotId = 'DEPOT-01',
    String commodity = 'Rice',
    required double availableDepotStockKg,
    String allocationStrategy = 'FAIR_SHARE_RISK_WEIGHTED',
    bool persistCandidate = false,
    String actorName = 'District Supply Officer (Demo Admin)',
    String notes = 'Simulated candidate plan generated for officer review',
  }) async {
    final uri = Uri.parse(
        '${AppConstants.apiBaseUrl}/admin/scarcity/simulate-fair-share');
    final payload = {
      'cycle_id': cycleId,
      'depot_id': depotId,
      'commodity': commodity,
      'available_depot_stock_kg': availableDepotStockKg,
      'allocation_strategy': allocationStrategy,
      'persist_candidate': persistCandidate,
      'actor_name': actorName,
      'notes': notes,
    };

    final response = await client
        .post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: json.encode(payload),
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      return ScarcityPlanSummaryModel.fromJson(data);
    } else {
      final err = json.decode(response.body);
      throw Exception(
          'Failed to simulate fair-share scarcity plan: ${err['detail'] ?? response.statusCode}');
    }
  }

  /// 4. Authorize and execute a staged fair-share scarcity allocation plan (DSO sign-off)
  Future<ApprovePlanResponseModel> approveScarcityPlan({
    required String planId,
    required String officerName,
    required String officerRole,
    String approvalNotes = 'Approved for operational dispatch execution',
  }) async {
    final uri =
        Uri.parse('${AppConstants.apiBaseUrl}/admin/scarcity/approve-plan');
    final payload = {
      'plan_id': planId,
      'officer_name': officerName,
      'officer_role': officerRole,
      'approval_notes': approvalNotes,
    };

    final response = await client
        .post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: json.encode(payload),
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      return ApprovePlanResponseModel.fromJson(data);
    } else {
      final err = json.decode(response.body);
      throw Exception(
          'Officer approval failed: ${err['detail'] ?? response.statusCode}');
    }
  }

  /// 5. Retrieve immutable audit trail for a fair-share scarcity plan
  Future<ScarcityAuditTrailModel> fetchScarcityAuditTrail(String planId) async {
    final uri = Uri.parse(
        '${AppConstants.apiBaseUrl}/admin/scarcity/audit-trail/$planId');
    final response = await client
        .get(uri, headers: {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 8));

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      return ScarcityAuditTrailModel.fromJson(data);
    } else {
      final err = json.decode(response.body);
      throw Exception(
          'Failed to retrieve scarcity audit trail: ${err['detail'] ?? response.statusCode}');
    }
  }
}

class ActualDistributionData {
  final String status;
  final String workflowStatus;
  final String cycleId;
  final double totalActualQuantityKg;
  final double totalRiceActualKg;
  final double totalWheatActualKg;
  final double totalDispatchQuantityKg;
  final double totalVarianceKg;
  final int totalFpsCount;
  final int simulatedRecordsCount;
  final List<ActualDistributionRecord> records;
  final String message;

  ActualDistributionData({
    required this.status,
    required this.workflowStatus,
    required this.cycleId,
    required this.totalActualQuantityKg,
    required this.totalRiceActualKg,
    required this.totalWheatActualKg,
    required this.totalDispatchQuantityKg,
    required this.totalVarianceKg,
    required this.totalFpsCount,
    required this.simulatedRecordsCount,
    required this.records,
    required this.message,
  });
}



