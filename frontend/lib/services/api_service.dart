import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/constants.dart';
import '../models/health_model.dart';
import '../models/beneficiary_model.dart';
import '../models/admin_model.dart';
import '../models/scarcity_model.dart';
import 'auth_session.dart';

export 'auth_session.dart';

class AuthenticatedClient extends http.BaseClient {
  final http.Client _inner;
  final AuthSession session;

  AuthenticatedClient(this._inner, {AuthSession? session})
      : session = session ?? AuthSession.instance;

  String? get token => session.token;
  set token(String? val) {
    if (val == null) {
      session.clear();
    } else {
      session.setSession(
        token: val,
        username: session.username ?? 'admin_user',
        role: session.role ?? 'ADMIN',
      );
    }
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final isAuthOrHealth = request.url.path.contains('/auth/login') || request.url.path.contains('/health');

    // 1. Check expiration if token exists (skip for login/health)
    if (!isAuthOrHealth && session.token != null && session.isExpired) {
      session.trigger401();
      throw const UnauthorizedException('Session expired. Please log in again.');
    }

    // 2. Automatically inject Authorization header if authenticated
    if (!isAuthOrHealth && session.token != null && session.token!.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer ${session.token}';
    }

    // Ensure Accept header is set
    request.headers.putIfAbsent('Accept', () => 'application/json');

    final response = await _inner.send(request);

    // 3. Intercept 401 / 403 status codes deterministically if authenticated
    if (response.statusCode == 401) {
      if (session.token != null && session.token!.isNotEmpty) {
        session.trigger401();
      }
    } else if (response.statusCode == 403) {
      session.trigger403('Access Denied: You do not have permission for this resource.');
    }

    return response;
  }
}

class ApiService {
  final http.Client client;
  final AuthenticatedClient authClient;

  AuthSession get authSession => authClient.session;

  ApiService({http.Client? client, AuthSession? session}) : 
    this._internal(AuthenticatedClient(client ?? http.Client(), session: session));

  ApiService._internal(AuthenticatedClient authenticated) :
    authClient = authenticated,
    client = authenticated;

  /// Helper to extract clean error message and return appropriate typed ApiException.
  ApiException parseError(http.Response response, [String defaultMessage = 'Request failed']) {
    String detail = defaultMessage;
    dynamic rawJson;
    try {
      rawJson = json.decode(response.body);
      if (rawJson is Map<String, dynamic> && rawJson.containsKey('detail')) {
        final d = rawJson['detail'];
        if (d is List) {
          detail = d.map((e) => e is Map ? (e['msg'] ?? e.toString()) : e.toString()).join('; ');
        } else {
          detail = d.toString();
        }
      } else if (rawJson is String) {
        detail = rawJson;
      }
    } catch (_) {
      detail = '$defaultMessage (status ${response.statusCode})';
    }

    if (response.statusCode == 401) {
      return UnauthorizedException(detail);
    } else if (response.statusCode == 403) {
      return ForbiddenException(detail);
    } else if (response.statusCode == 409) {
      return ConflictException(detail, rawJson);
    } else if (response.statusCode == 422) {
      return ValidationException(detail, rawJson);
    } else if (response.statusCode >= 500) {
      return ServerException(detail, rawJson);
    } else {
      return ApiException(response.statusCode, detail, details: rawJson);
    }
  }

  /// Authenticate credentials and store the returned token into centralized AuthSession.
  Future<Map<String, dynamic>> login(String username, String password) async {
    authSession.clear();
    final response = await client.post(
      Uri.parse('${AppConstants.apiBaseUrl}/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'username': username,
        'password': password,
      }),
    ).timeout(const Duration(seconds: 8));

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      final token = data['access_token'] as String;
      final role = (data['role'] ?? 'BENEFICIARY') as String;
      final beneficiaryId = data['beneficiary_id'] as String?;
      final expiresIn = (data['expires_in'] ?? 36000) as int;

      authSession.setSession(
        token: token,
        username: username,
        role: role,
        beneficiaryId: beneficiaryId,
        expiresInSeconds: expiresIn,
      );
      return data;
    } else {
      throw parseError(response, 'Login failed');
    }
  }

  /// Clear the token and reset the centralized AuthSession on logout.
  void logout() {
    authSession.clear();
  }

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
        throw parseError(response, 
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
      throw parseError(response, 'Failed to fetch beneficiaries: ${response.statusCode}');
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
      throw parseError(response, 'Failed to fetch beneficiary $id: ${response.statusCode}');
    }
  }

  /// Retrieve list of all Fair Price Shops with inventory and capacities
  Future<List<FpsShop>> fetchFpsList() async {
    final response = await client
        .get(Uri.parse('${AppConstants.apiBaseUrl}/fps'),
            headers: {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 8));

    if (response.statusCode == 200) {
      final decoded = json.decode(response.body);
      final List<dynamic> list;
      if (decoded is List) {
        list = decoded;
      } else if (decoded is Map && decoded.containsKey('items') && decoded['items'] is List) {
        list = decoded['items'] as List<dynamic>;
      } else {
        list = [];
      }
      return list.map((item) => FpsShop.fromJson(Map<String, dynamic>.from(item as Map))).toList();
    } else {
      throw parseError(response, 'Failed to fetch FPS list: ${response.statusCode}');
    }
  }

  /// Submit a forward-looking intent declaration for a commodity
  Future<IntentRecord> submitSingleIntent({
    required String beneficiaryId,
    required String intendedFpsId,
    required String commodity,
    double? quantityKg,
    String deliveryMode = 'FPS_COLLECTION',
    String? deliveryAddress,
    double deliveryDistanceKm = 0.0,
    String cycleId = '2026-09',
    double confidence = 0.95,
  }) async {
    final payload = <String, dynamic>{
      'beneficiary_id': beneficiaryId,
      'cycle_id': cycleId,
      'intended_fps_id': intendedFpsId,
      'commodity': commodity,
      'confidence': confidence,
      'delivery_mode': deliveryMode,
      'delivery_address': deliveryAddress,
      'delivery_distance_km': deliveryDistanceKm,
    };
    if (quantityKg != null && quantityKg > 0) {
      payload['declared_quantity_kg'] = quantityKg;
    }

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
      throw parseError(response, 'Failed to submit preference');
    }
  }

  /// Submit intent for selected commodity option ('Rice', 'Wheat', or 'Both')
  Future<List<IntentRecord>> submitIntent({
    required String beneficiaryId,
    required String intendedFpsId,
    required String commodityOption, // 'Rice', 'Wheat', 'Both'
    double? riceQuantityKg,
    double? wheatQuantityKg,
    String deliveryMode = 'FPS_COLLECTION',
    String? deliveryAddress,
    double deliveryDistanceKm = 0.0,
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
        deliveryMode: deliveryMode,
        deliveryAddress: deliveryAddress,
        deliveryDistanceKm: deliveryDistanceKm,
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
        deliveryMode: deliveryMode,
        deliveryAddress: deliveryAddress,
        deliveryDistanceKm: deliveryDistanceKm,
        cycleId: cycleId,
        confidence: confidence,
      );
      results.add(wheatRes);
    }

    return results;
  }

  /// Fetch authoritative government entitlement breakdown and remaining balance
  Future<BeneficiaryEntitlementSummary> fetchBeneficiaryEntitlementSummary(
    String beneficiaryId, {
    String cycleId = '2026-09',
  }) async {
    final url =
        '${AppConstants.apiBaseUrl}/beneficiary/$beneficiaryId/entitlement-summary?cycle_id=$cycleId';
    final response = await client.get(
      Uri.parse(url),
      headers: {'Accept': 'application/json'},
    ).timeout(const Duration(seconds: 8));

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      return BeneficiaryEntitlementSummary.fromJson(data);
    } else {
      throw parseError(response, 
          'Failed to fetch entitlement summary: ${response.statusCode}');
    }
  }

  /// Retrieve citizen active preference and delivery tracking records
  Future<List<CitizenDeliveryRecord>> fetchBeneficiaryDeliveryRecords(
    String beneficiaryId, {
    String cycleId = '2026-09',
  }) async {
    final url =
        '${AppConstants.apiBaseUrl}/beneficiary/$beneficiaryId/delivery-records?cycle_id=$cycleId';
    final response = await client.get(
      Uri.parse(url),
      headers: {'Accept': 'application/json'},
    ).timeout(const Duration(seconds: 8));

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      final list = (data['items'] as List<dynamic>?) ?? [];
      return list.map((e) => CitizenDeliveryRecord.fromJson(e)).toList();
    } else {
      throw parseError(response, 
          'Failed to fetch delivery records: ${response.statusCode}');
    }
  }

  /// Confirm delivery receipt or raise a discrepancy/dispute
  Future<Map<String, dynamic>> confirmCitizenDelivery({
    required String beneficiaryId,
    required String requestId,
    required String confirmationStatus, // 'DELIVERY_CONFIRMED' | 'DELIVERY_DISPUTE'
    double? receivedRiceKg,
    double? receivedWheatKg,
    String? disputeNotes,
  }) async {
    final url =
        '${AppConstants.apiBaseUrl}/beneficiary/$beneficiaryId/confirm-delivery';
    final payload = <String, dynamic>{
      'request_id': requestId,
      'confirmation_status': confirmationStatus,
      'received_rice_kg': receivedRiceKg,
      'received_wheat_kg': receivedWheatKg,
      'dispute_notes': disputeNotes,
    };

    final response = await client.post(
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: json.encode(payload),
    ).timeout(const Duration(seconds: 8));

    if (response.statusCode == 200) {
      return json.decode(response.body) as Map<String, dynamic>;
    } else {
      final err = json.decode(response.body);
      throw parseError(response, 
          'Failed to process confirmation: ${err['detail'] ?? response.statusCode}');
    }
  }

  /// Fetch officer delivery dispute queue
  Future<List<DeliveryDisputeModel>> fetchDeliveryDisputes({
    String cycleId = '2026-09',
    String? status,
  }) async {
    String url =
        '${AppConstants.apiBaseUrl}/admin/delivery-disputes?cycle_id=$cycleId';
    if (status != null && status.isNotEmpty) {
      url += '&status=$status';
    }

    final response = await client.get(
      Uri.parse(url),
      headers: {'Accept': 'application/json'},
    ).timeout(const Duration(seconds: 8));

    if (response.statusCode == 200) {
      final list = json.decode(response.body) as List<dynamic>;
      return list.map((e) => DeliveryDisputeModel.fromJson(e)).toList();
    } else {
      throw parseError(response, 
          'Failed to fetch delivery disputes: ${response.statusCode}');
    }
  }

  /// Resolve a citizen delivery dispute
  Future<Map<String, dynamic>> resolveDeliveryDispute({
    required String disputeId,
    required String decision, // 'OFFICER_RESOLVED' | 'REJECTED'
    required String resolutionNotes,
    String officerName = 'K. Srinivas Murthy (DSO)',
    String officerRole = 'DISTRICT_SUPPLY_OFFICER',
  }) async {
    final url =
        '${AppConstants.apiBaseUrl}/admin/delivery-disputes/$disputeId/resolve';
    final payload = {
      'officer_name': officerName,
      'officer_role': officerRole,
      'decision': decision,
      'resolution_notes': resolutionNotes,
    };

    final response = await client.post(
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: json.encode(payload),
    ).timeout(const Duration(seconds: 8));

    if (response.statusCode == 200) {
      return json.decode(response.body) as Map<String, dynamic>;
    } else {
      final err = json.decode(response.body);
      throw parseError(response, 
          'Failed to resolve dispute: ${err['detail'] ?? response.statusCode}');
    }
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
      final decoded = json.decode(response.body);
      final List<dynamic> list;
      if (decoded is List) {
        list = decoded;
      } else if (decoded is Map && decoded.containsKey('items') && decoded['items'] is List) {
        list = decoded['items'] as List<dynamic>;
      } else {
        list = [];
      }
      return list.map((item) => IntentRecord.fromJson(Map<String, dynamic>.from(item as Map))).toList();
    } else {
      throw parseError(response, 'Failed to fetch intents: ${response.statusCode}');
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
      throw parseError(response, 
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
      throw parseError(response, 
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
      throw parseError(response, 
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
      throw parseError(response, 'Failed to lock forecast: ${response.statusCode}');
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
      throw parseError(response, 'Failed to fetch choice window status: ${response.statusCode}');
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
      throw parseError(response, err['detail'] ?? 'Failed to close choice window: ${response.statusCode}');
    }
  }

  /// Retrieve the frozen demand snapshot for the cycle
  Future<Map<String, dynamic>> fetchDemandSnapshot({String cycleId = '2026-09'}) async {
    final response = await client
        .get(Uri.parse('${AppConstants.apiBaseUrl}/admin/planning-cycle/demand-snapshot?cycle_id=$cycleId'),
            headers: {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 8));

    if (response.statusCode == 200) {
      return json.decode(response.body) as Map<String, dynamic>;
    } else {
      final err = json.decode(response.body);
      throw parseError(response, err['detail'] ?? 'Failed to fetch demand snapshot: ${response.statusCode}');
    }
  }

  /// Set the planning-cycle day for demo simulations (e.g. Day 21..24 -> Day 25)
  Future<Map<String, dynamic>> setPlanningCycleDay(int day, {String cycleId = '2026-09'}) async {
    final response = await client
        .post(Uri.parse('${AppConstants.apiBaseUrl}/admin/planning-cycle/set-day?day=$day&cycle_id=$cycleId'),
            headers: {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 8));

    if (response.statusCode == 200) {
      return json.decode(response.body) as Map<String, dynamic>;
    } else {
      final err = json.decode(response.body);
      throw parseError(response, err['detail'] ?? 'Failed to set planning day: ${response.statusCode}');
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
      throw parseError(response, 
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
      throw parseError(response, 
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
      throw parseError(response, 'Failed to reset demo workflow: ${response.statusCode}');
    }
  }

  /// Retrieve current workflow state, allowed next states, blockers, and transition history
  Future<Map<String, dynamic>> fetchWorkflowStatus(
      {String cycleId = '2026-09'}) async {
    final response = await client
        .get(
            Uri.parse(
                '${AppConstants.apiBaseUrl}/admin/workflow/status?cycle_id=$cycleId'),
            headers: {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 8));

    if (response.statusCode == 200) {
      return json.decode(response.body) as Map<String, dynamic>;
    } else {
      throw parseError(response, 
          'Failed to fetch workflow status: ${response.statusCode}');
    }
  }

  /// Manually trigger a workflow state transition
  Future<Map<String, dynamic>> transitionWorkflowState({
    required String cycleId,
    required String newState,
    required String actorName,
    required String actorRole,
    String? reason,
    String? correlationId,
  }) async {
    final payload = <String, dynamic>{
      'cycle_id': cycleId,
      'new_state': newState,
      'actor_name': actorName,
      'actor_role': actorRole,
      'reason': reason,
      'correlation_id': correlationId,
    };

    final response = await client
        .post(
          Uri.parse('${AppConstants.apiBaseUrl}/admin/workflow/transition'),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: json.encode(payload),
        )
        .timeout(const Duration(seconds: 8));

    if (response.statusCode == 200) {
      return json.decode(response.body) as Map<String, dynamic>;
    } else {
      final err = json.decode(response.body);
      throw parseError(response, 
          'Workflow state transition failed: ${err['detail'] ?? response.statusCode}');
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
      throw parseError(response, 
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
      throw parseError(response, 
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
      throw parseError(response, 
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
      throw parseError(response, 
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
      throw parseError(response, 
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
      throw parseError(response, 
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
      throw parseError(response, 
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
      throw parseError(response, 
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
      throw parseError(response, 
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
      throw parseError(response, 
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
      throw parseError(response, 
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
      throw parseError(response, 
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
      throw parseError(response, 
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
      throw parseError(response, 
          'Failed to fetch supply routes: ${err['detail'] ?? response.statusCode}');
    }
  }

  /// Execute 'Run Pre-Dispatch Analysis' pipeline
  Future<PreDispatchAnalysisResult> runPreDispatchAnalysis(
      {String? fpsId, String cycleId = '2026-09', bool simulateStockShortage = false}) async {
    String url = '${AppConstants.apiBaseUrl}/admin/analysis/run?cycle_id=$cycleId';
    if (fpsId != null && fpsId.isNotEmpty) {
      url += '&fps_id=$fpsId';
    }
    if (simulateStockShortage) {
      url += '&simulate_stock_shortage=true';
    }

    final response = await client
        .post(Uri.parse(url), headers: {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      return PreDispatchAnalysisResult.fromJson(data);
    } else {
      final err = json.decode(response.body);
      throw parseError(response, 
          'Failed to execute pre-dispatch analysis: ${err['detail'] ?? response.statusCode}');
    }
  }

  /// Mark dispatch/order as temporarily delayed (1-2 days) due to government stock shortage
  Future<Map<String, dynamic>> delayDispatch({
    String? fpsId,
    String? requestId,
    String? beneficiaryId,
    String delayDays = '1–2 days',
    String reason = 'Government stock currently unavailable for this dispatch.',
    String cycleId = '2026-09',
  }) async {
    final url = '${AppConstants.apiBaseUrl}/admin/dispatch/delay';
    final payload = {
      'fps_id': fpsId,
      'request_id': requestId,
      'beneficiary_id': beneficiaryId,
      'delay_days': delayDays,
      'reason': reason,
      'cycle_id': cycleId,
    };

    final response = await client.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
      body: json.encode(payload),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body) as Map<String, dynamic>;
    } else {
      final err = json.decode(response.body);
      throw parseError(response, 'Failed to delay dispatch: ${err['detail'] ?? response.statusCode}');
    }
  }

  /// Resume dispatch when government buffer stock is replenished
  Future<Map<String, dynamic>> resumeDispatch({
    String? fpsId,
    String? requestId,
    String? beneficiaryId,
    String cycleId = '2026-09',
  }) async {
    final url = '${AppConstants.apiBaseUrl}/admin/dispatch/resume';
    final payload = {
      'fps_id': fpsId,
      'request_id': requestId,
      'beneficiary_id': beneficiaryId,
      'cycle_id': cycleId,
    };

    final response = await client.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
      body: json.encode(payload),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body) as Map<String, dynamic>;
    } else {
      final err = json.decode(response.body);
      throw parseError(response, 'Failed to resume dispatch: ${err['detail'] ?? response.statusCode}');
    }
  }

  /// Officer dispatches stock shortage delay notification to beneficiary
  Future<Map<String, dynamic>> sendDelayAlert({
    required String beneficiaryId,
    String? beneficiaryName,
    String? fpsId,
    String? requestId,
    String delayDays = '1–2 days',
    String? customMessage,
    String cycleId = '2026-09',
  }) async {
    final url = '${AppConstants.apiBaseUrl}/admin/notifications/send-delay-alert';
    final payload = {
      'beneficiary_id': beneficiaryId,
      'beneficiary_name': beneficiaryName,
      'fps_id': fpsId,
      'request_id': requestId,
      'delay_days': delayDays,
      'custom_message': customMessage,
      'cycle_id': cycleId,
    };

    final response = await client.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
      body: json.encode(payload),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body) as Map<String, dynamic>;
    } else {
      final err = json.decode(response.body);
      throw parseError(response, 'Failed to send delay alert: ${err['detail'] ?? response.statusCode}');
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
      throw parseError(response, 
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
      throw parseError(response, 
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
      throw parseError(response, 
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
      throw parseError(response, 
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
      throw parseError(response, 
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
      throw parseError(response, 
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
      throw parseError(response, 
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
      throw parseError(response, 
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
      throw parseError(response, 
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
      throw parseError(response, 
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
      throw parseError(response, 
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
      throw parseError(response, 
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
      throw parseError(response, 
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
      throw parseError(response, 
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
      throw parseError(response, 
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
      throw parseError(response, 
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
      throw parseError(response, 
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
      throw parseError(response, 
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
      throw parseError(response, 
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
      throw parseError(response, 
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
      throw parseError(response, 
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
      throw parseError(response, 
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
      throw parseError(response, 
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
      throw parseError(response, 
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
      throw parseError(response, 
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
      throw parseError(response, 
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
      throw parseError(response, 
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
    String actorName = 'District Supply Officer (Bengaluru Urban)',
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
      throw parseError(response, 
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
      throw parseError(response, 
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
      throw parseError(response, 
          'Failed to retrieve scarcity audit trail: ${err['detail'] ?? response.statusCode}');
    }
  }

  // ----------------- Citizen Request Review Queue & Authorization APIs ----------------- //

  /// Retrieve Paginated Citizen Request Review Queue with AI Decision Diagnostics
  Future<CitizenRequestQueueResponse> fetchCitizenRequestsQueue({
    String cycleId = '2026-09',
    String? status,
    String? fpsId,
    String? riskLevel,
  }) async {
    String url = '${AppConstants.apiBaseUrl}/admin/citizen-requests?cycle_id=$cycleId';
    if (status != null && status.isNotEmpty && status != 'ALL') {
      url += '&status=$status';
    }
    if (fpsId != null && fpsId.isNotEmpty) {
      url += '&fps_id=$fpsId';
    }
    if (riskLevel != null && riskLevel.isNotEmpty) {
      url += '&risk_level=$riskLevel';
    }

    final response = await client
        .get(Uri.parse(url), headers: {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 8));

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      return CitizenRequestQueueResponse.fromJson(data);
    } else {
      final err = json.decode(response.body);
      throw parseError(response, 'Failed to fetch citizen requests: ${err['detail'] ?? response.statusCode}');
    }
  }

  /// Authorize, Partially Allocate, Redirect, or Defer a Citizen Request
  Future<Map<String, dynamic>> authorizeCitizenRequest({
    required String requestId,
    required String officerName,
    required String officerRole,
    required String decision,
    double? allocatedQuantityKg,
    String? allocatedFpsId,
    required String officerJustification,
  }) async {
    final uri = Uri.parse('${AppConstants.apiBaseUrl}/admin/citizen-requests/$requestId/authorize');
    final response = await client
        .post(
          uri,
          headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
          body: json.encode({
            'officer_name': officerName,
            'officer_role': officerRole,
            'decision': decision,
            if (allocatedQuantityKg != null) 'allocated_quantity_kg': allocatedQuantityKg,
            if (allocatedFpsId != null) 'allocated_fps_id': allocatedFpsId,
            'officer_justification': officerJustification,
          }),
        )
        .timeout(const Duration(seconds: 8));

    if (response.statusCode == 200) {
      return json.decode(response.body) as Map<String, dynamic>;
    } else {
      final err = json.decode(response.body);
      throw parseError(response, 'Authorization failed: ${err['detail'] ?? response.statusCode}');
    }
  }

  // ----------------- End-to-End Causal Pipeline Trace APIs ----------------- //

  /// Fetch complete 7-stage causal trace for an operational planning cycle & FPS
  Future<CausalTraceRun> fetchCausalTrace({
    String cycleId = '2026-09',
    String fpsId = 'FPS-KA-BLR-001',
  }) async {
    final uri = Uri.parse(
        '${AppConstants.apiBaseUrl}/admin/causal-trace?cycle_id=$cycleId&fps_id=$fpsId');
    final response = await client
        .get(uri, headers: {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      return CausalTraceRun.fromJson(data);
    } else {
      final err = json.decode(response.body);
      throw parseError(response, 
          'Failed to fetch causal trace: ${err['detail'] ?? response.statusCode}');
    }
  }

  /// Trigger calculation run of the 7-stage causal pipeline trace
  Future<CausalTraceRun> runCausalTraceCalculation({
    String cycleId = '2026-09',
    String fpsId = 'FPS-KA-BLR-001',
  }) async {
    final uri = Uri.parse(
        '${AppConstants.apiBaseUrl}/admin/causal-trace/run?cycle_id=$cycleId&fps_id=$fpsId');
    final response = await client
        .post(uri, headers: {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      return CausalTraceRun.fromJson(data);
    } else {
      final err = json.decode(response.body);
      throw parseError(response, 
          'Failed to run causal trace calculation: ${err['detail'] ?? response.statusCode}');
    }
  }

  /// Controlled demo: Inject synthetic citizen intent shift and return full downstream delta
  Future<CausalTraceResponse> simulateIntentShiftCausalTrace({
    String cycleId = '2026-09',
    String fpsId = 'FPS-KA-BLR-001',
    double shiftDeltaKg = 150.0,
    String beneficiaryId = 'BEN-KA-0001',
  }) async {
    final uri = Uri.parse(
        '${AppConstants.apiBaseUrl}/admin/causal-trace/simulate-shift');
    final response = await client
        .post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: json.encode({
            'cycle_id': cycleId,
            'fps_id': fpsId,
            'shift_delta_kg': shiftDeltaKg,
            'beneficiary_id': beneficiaryId,
          }),
        )
        .timeout(const Duration(seconds: 12));

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      return CausalTraceResponse.fromJson(data);
    } else {
      final err = json.decode(response.body);
      throw parseError(response, 
          'Failed to simulate intent shift causal trace: ${err['detail'] ?? response.statusCode}');
    }
  }
}

class CitizenRequestModel {
  final int id;
  final String requestId;
  final String beneficiaryId;
  final String beneficiaryName;
  final String cardType;
  final int familyMembersCount;
  final double statutoryEntitlementRiceKg;
  final double statutoryEntitlementWheatKg;
  final double statutoryEntitlementCommodityKg;
  final String cycleId;
  final String registeredFpsId;
  final String registeredFpsName;
  final String intendedFpsId;
  final String intendedFpsName;
  final String commodity;
  final double requestedQuantityKg;
  final double authorizedQuantityKg;
  final String requestType;
  final String status;
  final String? aiRecommendation;
  final double aiRecommendedQtyKg;
  final String? aiRecommendedFpsId;
  final String? aiRecommendedFpsName;
  final String? aiRiskLevel;
  final double aiConfidence;
  final List<String> aiFactors;
  final double fpsCapacityKg;
  final double currentInventoryKg;
  final double statutoryFloorKg;
  final double pendingDemandKg;
  final double capacityHeadroomKg;
  final String replenishmentEta;
  final String? nearbyAlternativeFpsName;
  final double? nearbyAlternativeDistanceKm;
  final String? officerName;
  final String? officerRole;
  final String? officerJustification;
  final String? authorizedAt;
  final String createdAt;

  CitizenRequestModel({
    required this.id,
    required this.requestId,
    required this.beneficiaryId,
    required this.beneficiaryName,
    required this.cardType,
    required this.familyMembersCount,
    required this.statutoryEntitlementRiceKg,
    required this.statutoryEntitlementWheatKg,
    required this.statutoryEntitlementCommodityKg,
    required this.cycleId,
    required this.registeredFpsId,
    required this.registeredFpsName,
    required this.intendedFpsId,
    required this.intendedFpsName,
    required this.commodity,
    required this.requestedQuantityKg,
    required this.authorizedQuantityKg,
    required this.requestType,
    required this.status,
    this.aiRecommendation,
    required this.aiRecommendedQtyKg,
    this.aiRecommendedFpsId,
    this.aiRecommendedFpsName,
    this.aiRiskLevel,
    required this.aiConfidence,
    required this.aiFactors,
    this.fpsCapacityKg = 20000.0,
    required this.currentInventoryKg,
    required this.statutoryFloorKg,
    this.pendingDemandKg = 0.0,
    required this.capacityHeadroomKg,
    required this.replenishmentEta,
    this.nearbyAlternativeFpsName,
    this.nearbyAlternativeDistanceKm,
    this.officerName,
    this.officerRole,
    this.officerJustification,
    this.authorizedAt,
    required this.createdAt,
  });

  factory CitizenRequestModel.fromJson(Map<String, dynamic> json) {
    return CitizenRequestModel(
      id: json['id'] ?? 0,
      requestId: json['request_id'] ?? '',
      beneficiaryId: json['beneficiary_id'] ?? '',
      beneficiaryName: json['beneficiary_name'] ?? 'Beneficiary Citizen',
      cardType: json['card_type'] ?? 'PHH',
      familyMembersCount: json['family_members_count'] ?? 1,
      statutoryEntitlementRiceKg: (json['statutory_entitlement_rice_kg'] as num?)?.toDouble() ?? 0.0,
      statutoryEntitlementWheatKg: (json['statutory_entitlement_wheat_kg'] as num?)?.toDouble() ?? 0.0,
      statutoryEntitlementCommodityKg: (json['statutory_entitlement_commodity_kg'] as num?)?.toDouble() ?? 0.0,
      cycleId: json['cycle_id'] ?? '2026-09',
      registeredFpsId: json['registered_fps_id'] ?? '',
      registeredFpsName: json['registered_fps_name'] ?? '',
      intendedFpsId: json['intended_fps_id'] ?? '',
      intendedFpsName: json['intended_fps_name'] ?? '',
      commodity: json['commodity'] ?? 'Rice',
      requestedQuantityKg: (json['requested_quantity_kg'] as num?)?.toDouble() ?? 0.0,
      authorizedQuantityKg: (json['authorized_quantity_kg'] as num?)?.toDouble() ?? 0.0,
      requestType: json['request_type'] ?? 'PORTABILITY_PREFERENCE',
      status: json['status'] ?? 'PENDING_OFFICER_REVIEW',
      aiRecommendation: json['ai_recommendation'],
      aiRecommendedQtyKg: (json['ai_recommended_qty_kg'] as num?)?.toDouble() ?? 0.0,
      aiRecommendedFpsId: json['ai_recommended_fps_id'],
      aiRecommendedFpsName: json['ai_recommended_fps_name'],
      aiRiskLevel: json['ai_risk_level'],
      aiConfidence: (json['ai_confidence'] as num?)?.toDouble() ?? 0.95,
      aiFactors: (json['ai_factors'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      fpsCapacityKg: (json['fps_capacity_kg'] as num?)?.toDouble() ?? 20000.0,
      currentInventoryKg: (json['current_inventory_kg'] as num?)?.toDouble() ?? 0.0,
      statutoryFloorKg: (json['statutory_floor_kg'] as num?)?.toDouble() ?? 0.0,
      pendingDemandKg: (json['pending_demand_kg'] as num?)?.toDouble() ?? 0.0,
      capacityHeadroomKg: (json['capacity_headroom_kg'] as num?)?.toDouble() ?? 0.0,
      replenishmentEta: json['replenishment_eta'] ?? 'Morning Slot 08:30 AM',
      nearbyAlternativeFpsName: json['nearby_alternative_fps_name'],
      nearbyAlternativeDistanceKm: (json['nearby_alternative_distance_km'] as num?)?.toDouble(),
      officerName: json['officer_name'],
      officerRole: json['officer_role'],
      officerJustification: json['officer_justification'],
      authorizedAt: json['authorized_at'],
      createdAt: json['created_at'] ?? '',
    );
  }
}

class CitizenRequestQueueResponse {
  final int totalCount;
  final int pendingCount;
  final int approvedCount;
  final int delayedCount;
  final int partialCount;
  final int redirectedCount;
  final int deferredCount;
  final String cycleId;
  final List<CitizenRequestModel> items;

  CitizenRequestQueueResponse({
    required this.totalCount,
    required this.pendingCount,
    required this.approvedCount,
    this.delayedCount = 0,
    required this.partialCount,
    required this.redirectedCount,
    required this.deferredCount,
    required this.cycleId,
    required this.items,
  });

  factory CitizenRequestQueueResponse.fromJson(Map<String, dynamic> json) {
    final list = json['items'] as List<dynamic>? ?? [];
    return CitizenRequestQueueResponse(
      totalCount: json['total_count'] ?? 0,
      pendingCount: json['pending_count'] ?? 0,
      approvedCount: json['approved_count'] ?? 0,
      delayedCount: json['delayed_count'] ?? 0,
      partialCount: json['partial_count'] ?? 0,
      redirectedCount: json['redirected_count'] ?? 0,
      deferredCount: json['deferred_count'] ?? 0,
      cycleId: json['cycle_id'] ?? '2026-09',
      items: list.map((e) => CitizenRequestModel.fromJson(e)).toList(),
    );
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



