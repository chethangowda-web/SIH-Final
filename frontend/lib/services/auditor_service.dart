import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/constants.dart';
import '../models/auditor_model.dart';
import 'api_service.dart';

/// Production HTTP Client Binding for Auditor Portal Command Center & APIs
class AuditorService {
  final ApiService _apiService;

  AuditorService({ApiService? apiService})
      : _apiService = apiService ?? ApiService();

  String get _baseUrl => AppConstants.apiBaseUrl;

  Map<String, String> get _headers {
    final token = _apiService.authSession.token;
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  /// 1. Fetch Auditor Overview
  Future<AuditOverviewModel> fetchOverview({String cycleId = '2026-09'}) async {
    final uri = Uri.parse('$_baseUrl/auditor/overview?cycle_id=$cycleId');
    final response = await http.get(uri, headers: _headers);

    if (response.statusCode == 200) {
      return AuditOverviewModel.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }
    throw Exception('Failed to fetch auditor overview: ${response.statusCode}');
  }

  /// 2. Fetch Audit Cycles
  Future<List<String>> fetchCycles() async {
    final uri = Uri.parse('$_baseUrl/auditor/cycles');
    final response = await http.get(uri, headers: _headers);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return (data['cycles'] as List<dynamic>? ?? []).map((c) => c.toString()).toList();
    }
    return ['2026-09'];
  }

  /// 3. Fetch Audit Assignments
  Future<List<AuditRecordModel>> fetchAssignments({
    String cycleId = '2026-09',
    String? district,
    String? statusFilter,
    String? riskFilter,
    String? search,
  }) async {
    final queryParams = <String, String>{'cycle_id': cycleId};
    if (district != null && district.isNotEmpty) queryParams['district'] = district;
    if (statusFilter != null && statusFilter.isNotEmpty) queryParams['status_filter'] = statusFilter;
    if (riskFilter != null && riskFilter.isNotEmpty) queryParams['risk_filter'] = riskFilter;
    if (search != null && search.isNotEmpty) queryParams['search'] = search;

    final uri = Uri.parse('$_baseUrl/auditor/assignments').replace(queryParameters: queryParams);
    final response = await http.get(uri, headers: _headers);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final list = data['assignments'] as List<dynamic>? ?? [];
      return list.map((item) => AuditRecordModel.fromJson(Map<String, dynamic>.from(item as Map))).toList();
    }
    throw Exception('Failed to fetch audit assignments: ${response.statusCode}');
  }

  /// 4. Plan & Schedule New Audit Assignment (Stage 01)
  Future<Map<String, dynamic>> createAudit({
    required String fpsId,
    String auditType = 'FULL_AUDIT',
    String cycleId = '2026-09',
    String? scheduledDate,
    String assignedTeam = 'State Vigilance Team Alpha',
  }) async {
    final uri = Uri.parse('$_baseUrl/auditor/audits');
    final body = jsonEncode({
      'fps_id': fpsId,
      'audit_type': auditType,
      'cycle_id': cycleId,
      'scheduled_date': scheduledDate,
      'assigned_team': assignedTeam,
    });

    final response = await http.post(uri, headers: _headers, body: body);

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to create audit assignment: ${response.statusCode}');
  }

  /// 5. Fetch Single Audit Assignment Detail
  Future<AuditRecordModel> fetchAuditDetail(String auditId) async {
    final uri = Uri.parse('$_baseUrl/auditor/audits/$auditId');
    final response = await http.get(uri, headers: _headers);

    if (response.statusCode == 200) {
      return AuditRecordModel.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }
    throw Exception('Failed to fetch audit detail: ${response.statusCode}');
  }

  /// 6. Fetch PDS Data Chain (Stage 02 Record Verification)
  Future<Map<String, dynamic>> fetchAuditPdsChain(String auditId) async {
    final uri = Uri.parse('$_baseUrl/auditor/audits/$auditId/records');
    final response = await http.get(uri, headers: _headers);

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to fetch PDS data chain: ${response.statusCode}');
  }

  /// 7. Mark Records Verified (Stage 02 Transition)
  Future<Map<String, dynamic>> verifyRecords(String auditId) async {
    final uri = Uri.parse('$_baseUrl/auditor/audits/$auditId/verify-records');
    final response = await http.post(uri, headers: _headers);

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to verify audit records: ${response.statusCode}');
  }

  /// 8. Fetch Reconciliation Details (Stage 02/04)
  Future<Map<String, dynamic>> fetchAuditReconciliation(String auditId) async {
    final uri = Uri.parse('$_baseUrl/auditor/audits/$auditId/reconciliation');
    final response = await http.get(uri, headers: _headers);

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to fetch audit reconciliation: ${response.statusCode}');
  }

  /// 9. Fetch Field Food Inspection Records (Stage 03)
  Future<Map<String, dynamic>> fetchAuditInspections(String auditId) async {
    final uri = Uri.parse('$_baseUrl/auditor/audits/$auditId/inspections');
    final response = await http.get(uri, headers: _headers);

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to fetch audit inspections: ${response.statusCode}');
  }

  /// 10. Fetch Exception Queue (Stage 04)
  Future<Map<String, dynamic>> fetchAuditExceptions(String auditId) async {
    final uri = Uri.parse('$_baseUrl/auditor/audits/$auditId/exceptions');
    final response = await http.get(uri, headers: _headers);

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to fetch audit exceptions: ${response.statusCode}');
  }

  /// 11. Add Auditor Finding (Stage 04)
  Future<Map<String, dynamic>> addFinding(
    String auditId, {
    required String findingType,
    required String severity,
    required String title,
    required String description,
    List<String> evidenceRefs = const [],
    String? auditorRecommendation,
  }) async {
    final uri = Uri.parse('$_baseUrl/auditor/audits/$auditId/findings');
    final body = jsonEncode({
      'finding_type': findingType,
      'severity': severity,
      'title': title,
      'description': description,
      'evidence_refs': evidenceRefs,
      'auditor_recommendation': auditorRecommendation ?? '',
    });

    final response = await http.post(uri, headers: _headers, body: body);

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to record audit finding: ${response.statusCode}');
  }

  /// 12. Generate Cryptographically Sealed Report Draft (Stage 05)
  Future<Map<String, dynamic>> generateReport(
    String auditId, {
    String scopeText = 'Statutory Physical & Digital PDS Audit',
    String auditObservations = '',
  }) async {
    final uri = Uri.parse('$_baseUrl/auditor/audits/$auditId/generate-report');
    final body = jsonEncode({
      'scope_text': scopeText,
      'audit_observations': auditObservations,
    });

    final response = await http.post(uri, headers: _headers, body: body);

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to generate audit report: ${response.statusCode}');
  }

  /// 13. Finalize Report (Stage 05)
  Future<Map<String, dynamic>> finalizeReport(String auditId) async {
    final uri = Uri.parse('$_baseUrl/auditor/audits/$auditId/finalize-report');
    final response = await http.post(uri, headers: _headers);

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to finalize audit report: ${response.statusCode}');
  }

  /// 14. Close Audit (Stage 06 Immutable Seal)
  Future<Map<String, dynamic>> closeAudit(
    String auditId, {
    String closureReason = 'Completed statutory verification and reconciliation',
  }) async {
    final uri = Uri.parse('$_baseUrl/auditor/audits/$auditId/close');
    final body = jsonEncode({
      'closure_reason': closureReason,
      'unresolved_exceptions_permitted': false,
    });

    final response = await http.post(uri, headers: _headers, body: body);

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to close audit: ${response.statusCode}');
  }

  /// 15. Cross-Portal End-to-End Trace Engine
  Future<Map<String, dynamic>> fetchCrossPortalTrace(String entityType, String entityId) async {
    final uri = Uri.parse('$_baseUrl/auditor/trace/$entityType/$entityId');
    final response = await http.get(uri, headers: _headers);

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to trace record: ${response.statusCode}');
  }

  /// 16. Fetch AI Insights
  Future<Map<String, dynamic>> fetchAiInsights({String cycleId = '2026-09'}) async {
    final uri = Uri.parse('$_baseUrl/auditor/ai/insights?cycle_id=$cycleId');
    final response = await http.get(uri, headers: _headers);

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    return {'insights': [], 'insights_count': 0};
  }

  /// 17. Fetch AI Anomalies
  Future<Map<String, dynamic>> fetchAiAnomalies({String cycleId = '2026-09'}) async {
    final uri = Uri.parse('$_baseUrl/auditor/ai/anomalies?cycle_id=$cycleId');
    final response = await http.get(uri, headers: _headers);

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    return {'anomalies': [], 'anomalies_count': 0};
  }

  /// 18. Fetch AI Recommendations
  Future<List<Map<String, dynamic>>> fetchAiRecommendations({String cycleId = '2026-09'}) async {
    final uri = Uri.parse('$_baseUrl/auditor/ai/recommendations?cycle_id=$cycleId');
    final response = await http.get(uri, headers: _headers);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final recs = data['recommendations'] as List<dynamic>? ?? [];
      return recs.map((r) => Map<String, dynamic>.from(r as Map)).toList();
    }
    return [];
  }
}
