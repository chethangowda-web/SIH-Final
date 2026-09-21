import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/constants.dart';
import '../../services/api_service.dart';
import '../../models/fps/fps_models.dart';

/// Dedicated Service Client for Fair Price Shop (FPS) Owner Command Center
/// Government of Karnataka • Department of Food and Civil Supplies
class FpsService {
  final ApiService apiService;

  FpsService({required this.apiService});

  String get _baseUrl => AppConstants.apiBaseUrl;

  Map<String, String> get _headers {
    final token = apiService.authSession.token;
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// 1. Fetch Authenticated FPS Profile
  Future<FpsOwnerProfile> fetchFpsProfile({String? fpsId}) async {
    final queryParams = {
      if (fpsId != null && fpsId.isNotEmpty) 'fps_id': fpsId,
    };
    final uri = Uri.parse('$_baseUrl/officer/fps/me').replace(queryParameters: queryParams);
    final response = await http.get(uri, headers: _headers);

    if (response.statusCode == 200) {
      return FpsOwnerProfile.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }
    throw Exception('Failed to load FPS profile: ${response.statusCode}');
  }

  /// 2. Fetch Operational Dashboard Overview
  Future<FpsDashboardOverview> fetchDashboardOverview(String fpsId, {String cycleId = '2026-09'}) async {
    final uri = Uri.parse('$_baseUrl/officer/fps/$fpsId/dashboard-overview?cycle_id=$cycleId');
    final response = await http.get(uri, headers: _headers);

    if (response.statusCode == 200) {
      return FpsDashboardOverview.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }
    throw Exception('Failed to load FPS dashboard overview: ${response.statusCode}');
  }

  /// 3. Search and Retrieve Registered Beneficiaries
  Future<Map<String, dynamic>> fetchBeneficiaries(
    String fpsId, {
    String? search,
    String? scheme,
    String cycleId = '2026-09',
    int limit = 50,
    int offset = 0,
  }) async {
    final queryParams = {
      'cycle_id': cycleId,
      'limit': limit.toString(),
      'offset': offset.toString(),
      if (search != null && search.isNotEmpty) 'search': search,
      if (scheme != null && scheme.isNotEmpty) 'scheme': scheme,
    };
    final uri = Uri.parse('$_baseUrl/officer/fps/$fpsId/beneficiaries').replace(queryParameters: queryParams);
    final response = await http.get(uri, headers: _headers);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final list = (data['beneficiaries'] as List<dynamic>?) ?? [];
      return {
        'total_count': data['total_count'] ?? 0,
        'beneficiaries': list.map((e) => FpsBeneficiaryRecord.fromJson(e as Map<String, dynamic>)).toList(),
      };
    }
    throw Exception('Failed to load beneficiaries: ${response.statusCode}');
  }

  /// 4. Fetch Inbound Deliveries
  Future<List<FpsInboundDelivery>> fetchDeliveries(String fpsId, {String cycleId = '2026-09'}) async {
    final uri = Uri.parse('$_baseUrl/officer/fps/$fpsId/deliveries?cycle_id=$cycleId');
    final response = await http.get(uri, headers: _headers);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final list = (data['deliveries'] as List<dynamic>?) ?? [];
      return list.map((e) => FpsInboundDelivery.fromJson(e as Map<String, dynamic>)).toList();
    }
    throw Exception('Failed to load deliveries: ${response.statusCode}');
  }

  /// 5. Confirm Delivery Receipt
  Future<Map<String, dynamic>> confirmDeliveryReceipt(String fpsId, String gatepassId) async {
    final uri = Uri.parse('$_baseUrl/officer/fps/$fpsId/consignments/$gatepassId/confirm-receipt');
    final response = await http.post(uri, headers: _headers);

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to confirm delivery receipt: ${response.statusCode}');
  }

  /// 6. Report Delivery Discrepancy
  Future<Map<String, dynamic>> reportDeliveryDiscrepancy(
    String fpsId,
    String gatepassId, {
    required double observedRiceKg,
    required double observedWheatKg,
    required String reason,
  }) async {
    final uri = Uri.parse('$_baseUrl/officer/fps/$fpsId/deliveries/$gatepassId/discrepancy');
    final body = jsonEncode({
      'observed_rice_kg': observedRiceKg,
      'observed_wheat_kg': observedWheatKg,
      'reason': reason,
    });
    final response = await http.post(uri, headers: _headers, body: body);

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to log delivery discrepancy: ${response.statusCode}');
  }

  /// 7. Fetch Stock Ledger & Commodity Movements
  Future<Map<String, dynamic>> fetchStockLedger(String fpsId, {String cycleId = '2026-09'}) async {
    final uri = Uri.parse('$_baseUrl/officer/fps/$fpsId/stock-ledger?cycle_id=$cycleId');
    final response = await http.get(uri, headers: _headers);

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to load stock ledger: ${response.statusCode}');
  }

  /// 8. Check e-PoS Eligibility
  Future<FpsEposEligibility> fetchEposEligibility(String fpsId, String beneficiaryId, {String cycleId = '2026-09'}) async {
    final uri = Uri.parse('$_baseUrl/officer/epos/eligibility?fps_id=$fpsId&beneficiary_id=$beneficiaryId&cycle_id=$cycleId');
    final response = await http.get(uri, headers: _headers);

    if (response.statusCode == 200) {
      return FpsEposEligibility.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }
    throw Exception('Failed to verify e-PoS eligibility: ${response.statusCode}');
  }

  /// 9. Verify Beneficiary (Biometric / OTP)
  Future<Map<String, dynamic>> verifyBeneficiary(
    String fpsId,
    String beneficiaryId,
    String verificationMode, {
    String? otpCode,
  }) async {
    final uri = Uri.parse('$_baseUrl/officer/epos/verify-beneficiary');
    final body = jsonEncode({
      'fps_id': fpsId,
      'beneficiary_id': beneficiaryId,
      'verification_mode': verificationMode,
      'otp_code': otpCode ?? '123456',
    });
    final response = await http.post(uri, headers: _headers, body: body);

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    String errorDetail = 'Status ${response.statusCode}';
    try {
      final err = jsonDecode(response.body);
      if (err is Map && err.containsKey('detail')) {
        errorDetail = err['detail'].toString();
      }
    } catch (_) {}
    throw Exception('Beneficiary verification failed: $errorDetail');
  }

  /// 10. Atomic e-PoS Dispense
  Future<FpsEposDispenseResult> dispenseEpos({
    required String fpsId,
    required String beneficiaryId,
    required double riceKg,
    required double wheatKg,
    String authMode = 'AADHAAR_BIOMETRIC',
    String cycleId = '2026-09',
  }) async {
    final uri = Uri.parse('$_baseUrl/officer/epos/dispense');
    final body = jsonEncode({
      'fps_id': fpsId,
      'beneficiary_id': beneficiaryId,
      'rice_kg': riceKg,
      'wheat_kg': wheatKg,
      'auth_mode': authMode,
      'cycle_id': cycleId,
    });
    final response = await http.post(uri, headers: _headers, body: body);

    if (response.statusCode == 200) {
      return FpsEposDispenseResult.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }
    final err = jsonDecode(response.body);
    throw Exception(err['detail'] ?? 'Failed to execute e-PoS dispense: ${response.statusCode}');
  }

  /// 11. Fetch Digital Transactions Register
  Future<List<Map<String, dynamic>>> fetchTransactions(String fpsId) async {
    final uri = Uri.parse('$_baseUrl/officer/fps/$fpsId/transactions');
    final response = await http.get(uri, headers: _headers);

    if (response.statusCode == 200) {
      final list = jsonDecode(response.body) as List<dynamic>;
      return list.map((e) => e as Map<String, dynamic>).toList();
    }
    throw Exception('Failed to load transaction register: ${response.statusCode}');
  }

  /// 12. Fetch AI Operational Intelligence Insights
  Future<List<FpsAiInsight>> fetchAiInsights(String fpsId, {String cycleId = '2026-09'}) async {
    final uri = Uri.parse('$_baseUrl/officer/fps/$fpsId/ai-insights?cycle_id=$cycleId');
    final response = await http.get(uri, headers: _headers);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final list = (data['insights'] as List<dynamic>?) ?? [];
      return list.map((e) => FpsAiInsight.fromJson(e as Map<String, dynamic>)).toList();
    }
    throw Exception('Failed to load AI insights: ${response.statusCode}');
  }

  /// 13. Fetch Exceptions Queue
  Future<List<FpsExceptionItem>> fetchExceptions(String fpsId) async {
    final uri = Uri.parse('$_baseUrl/officer/fps/$fpsId/exceptions');
    final response = await http.get(uri, headers: _headers);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final list = (data['exceptions'] as List<dynamic>?) ?? [];
      return list.map((e) => FpsExceptionItem.fromJson(e as Map<String, dynamic>)).toList();
    }
    throw Exception('Failed to load exceptions: ${response.statusCode}');
  }

  /// 14. Create Exception Case
  Future<Map<String, dynamic>> createException(
    String fpsId, {
    required String category,
    required String severity,
    required String title,
    required String description,
  }) async {
    final uri = Uri.parse('$_baseUrl/officer/fps/$fpsId/exceptions');
    final body = jsonEncode({
      'category': category,
      'severity': severity,
      'title': title,
      'description': description,
    });
    final response = await http.post(uri, headers: _headers, body: body);

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to create exception: ${response.statusCode}');
  }

  /// 15. Fetch Decision Trace Audit Events
  Future<List<FpsDecisionTraceEvent>> fetchDecisionTrace(String fpsId) async {
    final uri = Uri.parse('$_baseUrl/officer/fps/$fpsId/decision-trace');
    final response = await http.get(uri, headers: _headers);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final list = (data['events'] as List<dynamic>?) ?? [];
      return list.map((e) => FpsDecisionTraceEvent.fromJson(e as Map<String, dynamic>)).toList();
    }
    throw Exception('Failed to load decision trace: ${response.statusCode}');
  }

  /// 16. Fetch Data Sources Provenance
  Future<List<FpsDataSourceItem>> fetchDataSources(String fpsId) async {
    final uri = Uri.parse('$_baseUrl/officer/fps/$fpsId/data-sources');
    final response = await http.get(uri, headers: _headers);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final list = (data['sources'] as List<dynamic>?) ?? [];
      return list.map((e) => FpsDataSourceItem.fromJson(e as Map<String, dynamic>)).toList();
    }
    throw Exception('Failed to load data sources: ${response.statusCode}');
  }

  /// 17. Open Daily Operations
  Future<Map<String, dynamic>> openShop(String fpsId) async {
    final uri = Uri.parse('$_baseUrl/officer/fps/$fpsId/open-shop');
    final response = await http.post(uri, headers: _headers);

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to open shop operations: ${response.statusCode}');
  }

  /// 18. Close Daily Operations
  Future<Map<String, dynamic>> closeShop(String fpsId, {String? exceptionReason}) async {
    final uri = Uri.parse('$_baseUrl/officer/fps/$fpsId/close-shop');
    final body = jsonEncode({
      if (exceptionReason != null && exceptionReason.isNotEmpty) 'exception_reason': exceptionReason,
    });
    final response = await http.post(uri, headers: _headers, body: body);

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    final err = jsonDecode(response.body);
    throw Exception(err['detail'] ?? 'Failed to close shop: ${response.statusCode}');
  }
}
