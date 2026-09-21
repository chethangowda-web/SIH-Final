import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/constants.dart';
import '../../services/api_service.dart';
import '../../models/inspector/inspector_models.dart';

/// Dedicated Service Client for Field Food Inspector Command Center
/// Government of Karnataka • Department of Food and Civil Supplies
class InspectorService {
  final ApiService apiService;

  InspectorService({required this.apiService});

  String get _baseUrl => AppConstants.apiBaseUrl;

  Map<String, String> get _headers {
    final token = apiService.authSession.token;
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// 1. Inspector Dashboard Overview
  Future<Map<String, dynamic>> fetchDashboardOverview({
    String? district,
    String cycleId = '2026-09',
  }) async {
    final queryParams = {
      'cycle_id': cycleId,
      if (district != null && district.isNotEmpty) 'district': district,
    };
    final uri = Uri.parse('$_baseUrl/officer/inspector/dashboard').replace(queryParameters: queryParams);
    final response = await http.get(uri, headers: _headers);

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to load inspector dashboard overview: ${response.statusCode}');
  }

  /// 2. Candidate Targets
  Future<List<InspectorTarget>> fetchTargets({
    String? district,
    String cycleId = '2026-09',
  }) async {
    final queryParams = {
      'cycle_id': cycleId,
      if (district != null && district.isNotEmpty) 'district': district,
    };
    final uri = Uri.parse('$_baseUrl/officer/inspector/targets').replace(queryParameters: queryParams);
    final response = await http.get(uri, headers: _headers);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final list = (data['targets'] as List<dynamic>?) ?? [];
      return list.map((e) => InspectorTarget.fromJson(e as Map<String, dynamic>)).toList();
    }
    throw Exception('Failed to load inspection targets: ${response.statusCode}');
  }

  /// 3. Target Full Context
  Future<Map<String, dynamic>> fetchTargetFullContext(
    String fpsId, {
    String cycleId = '2026-09',
  }) async {
    final uri = Uri.parse('$_baseUrl/officer/inspector/target/$fpsId?cycle_id=$cycleId');
    final response = await http.get(uri, headers: _headers);

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    // Fallback to inspection-context
    final fbUri = Uri.parse('$_baseUrl/officer/fps/$fpsId/inspection-context');
    final fbRes = await http.get(fbUri, headers: _headers);
    if (fbRes.statusCode == 200) {
      return jsonDecode(fbRes.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to load target FPS context: ${response.statusCode}');
  }

  /// 4. Inbound Dispatch & Truck Tracking
  Future<InboundDispatchInfo> fetchAssignedDispatch(String fpsId) async {
    final uri = Uri.parse('$_baseUrl/officer/fps/$fpsId/assigned-dispatch');
    final response = await http.get(uri, headers: _headers);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final disp = data['dispatch_info'] as Map<String, dynamic>?;
      if (disp != null) {
        return InboundDispatchInfo.fromJson(disp);
      }
    }
    throw Exception('Failed to load inbound dispatch for FPS $fpsId: ${response.statusCode}');
  }

  /// 5. Geofence Verification
  Future<GeofenceVerifyResult> verifyGeofence(
    String fpsId, {
    double? inspectorLat,
    double? inspectorLon,
    String? truckId,
  }) async {
    final uri = Uri.parse('$_baseUrl/officer/inspector/geofence/verify');
    final body = jsonEncode({
      'fps_id': fpsId,
      'inspector_lat': inspectorLat,
      'inspector_lon': inspectorLon,
      'truck_id': truckId,
    });
    final response = await http.post(uri, headers: _headers, body: body);

    if (response.statusCode == 200) {
      return GeofenceVerifyResult.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }
    // Fallback to /officer/geofence/verify
    final fbUri = Uri.parse('$_baseUrl/officer/geofence/verify');
    final fbRes = await http.post(fbUri, headers: _headers, body: body);
    if (fbRes.statusCode == 200) {
      return GeofenceVerifyResult.fromJson(jsonDecode(fbRes.body) as Map<String, dynamic>);
    }
    throw Exception('Failed to verify geofence arrival: ${response.statusCode}');
  }

  /// 6. Accept Inspection Directive
  Future<Map<String, dynamic>> acceptInspectionOrder(String orderId) async {
    final uri = Uri.parse('$_baseUrl/officer/inspection/accept');
    final response = await http.post(
      uri,
      headers: _headers,
      body: jsonEncode({'order_id': orderId}),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to accept inspection assignment: ${response.statusCode}');
  }

  /// 7. Approve Truck Movement
  Future<Map<String, dynamic>> approveTruckMovement(
    String truckId,
    String currentFpsId, {
    String? nextFpsId,
    String? notes,
    String? manifestId,
  }) async {
    final uri = Uri.parse('$_baseUrl/officer/dispatch/approve-movement');
    final body = jsonEncode({
      'truck_id': truckId,
      'current_fps_id': currentFpsId,
      'next_fps_id': nextFpsId,
      'approval_notes': notes ?? 'Field Food Inspector physical delivery verified. Truck cleared for onward movement.',
      'manifest_id': manifestId,
    });
    final response = await http.post(uri, headers: _headers, body: body);

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to grant truck movement clearance: ${response.statusCode}');
  }

  /// 8. Run e-PoS Diagnostic Ping
  Future<Map<String, dynamic>> runEposDiagnostic(String fpsId) async {
    final uri = Uri.parse('$_baseUrl/officer/epos/diagnostic?fps_id=$fpsId');
    final response = await http.get(uri, headers: _headers);

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to execute e-PoS diagnostic ping: ${response.statusCode}');
  }

  /// 9. Record Evidence
  Future<EvidenceItem> uploadEvidence({
    required String fpsId,
    String? inspectionId,
    String evidenceType = 'PHOTOGRAPH',
    required String description,
    String? referencePath,
  }) async {
    final uri = Uri.parse('$_baseUrl/officer/inspection/evidence');
    final body = jsonEncode({
      'fps_id': fpsId,
      'inspection_id': inspectionId,
      'evidence_type': evidenceType,
      'description': description,
      'reference_path': referencePath,
    });
    final response = await http.post(uri, headers: _headers, body: body);

    if (response.statusCode == 200) {
      return EvidenceItem.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }
    throw Exception('Failed to register physical evidence: ${response.statusCode}');
  }

  /// 10. Submit and Cryptographically Seal 6-Point Inspection
  Future<Map<String, dynamic>> submitSealedInspection(Map<String, dynamic> inspectionData) async {
    final uri = Uri.parse('$_baseUrl/officer/inspection/submit');
    final response = await http.post(
      uri,
      headers: _headers,
      body: jsonEncode(inspectionData),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to submit sealed inspection: ${response.statusCode} - ${response.body}');
  }

  /// 11. Fetch Sealed Report
  Future<SealedInspectionReport> fetchSealedReport(String inspectionId) async {
    final uri = Uri.parse('$_baseUrl/officer/inspection/$inspectionId/sealed-report');
    final response = await http.get(uri, headers: _headers);

    if (response.statusCode == 200) {
      return SealedInspectionReport.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }
    throw Exception('Failed to load sealed inspection report: ${response.statusCode}');
  }

  /// 12. Fetch AI Insights
  Future<Map<String, dynamic>> fetchAiInsights({String cycleId = '2026-09'}) async {
    final uri = Uri.parse('$_baseUrl/officer/inspector/ai-insights?cycle_id=$cycleId');
    final response = await http.get(uri, headers: _headers);

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to load AI operational insights: ${response.statusCode}');
  }

  /// 13. Fetch Exception Queue
  Future<List<InspectorExceptionItem>> fetchExceptions({String cycleId = '2026-09'}) async {
    final uri = Uri.parse('$_baseUrl/officer/inspector/exceptions?cycle_id=$cycleId');
    final response = await http.get(uri, headers: _headers);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final list = (data['exceptions'] as List<dynamic>?) ?? [];
      return list.map((e) => InspectorExceptionItem.fromJson(e as Map<String, dynamic>)).toList();
    }
    throw Exception('Failed to load inspector exceptions: ${response.statusCode}');
  }

  /// 14. Fetch Decision Trace
  Future<List<InspectorDecisionTraceEvent>> fetchDecisionTrace() async {
    final uri = Uri.parse('$_baseUrl/officer/inspector/decision-trace');
    final response = await http.get(uri, headers: _headers);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final list = (data['events'] as List<dynamic>?) ?? [];
      return list.map((e) => InspectorDecisionTraceEvent.fromJson(e as Map<String, dynamic>)).toList();
    }
    throw Exception('Failed to load decision trace events: ${response.statusCode}');
  }
}
