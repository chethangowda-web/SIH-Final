import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/constants.dart';
import '../auth_session.dart';
import '../../models/dso/dso_models.dart';

class DsoService {
  final http.Client _client;

  DsoService({http.Client? client}) : _client = client ?? http.Client();

  Future<Map<String, String>> _getHeaders() async {
    // RBAC: DSO workspace requires an authenticated session from the login
    // screen. Never silently log in with hardcoded credentials here.
    final token = AuthSession.instance.token;
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Future<List<String>> getDistricts() async {
    // No hardcoded fallback: districts come from fps.district via backend.
    final headers = await _getHeaders();
    final uri = Uri.parse('${AppConstants.apiBaseUrl}/admin/dso/districts');
    final res = await _client.get(uri, headers: headers);
    if (res.statusCode == 200) {
      final body = json.decode(res.body) as Map<String, dynamic>;
      return (body['districts'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList();
    }
    throw ApiException(res.statusCode, 'Failed to fetch districts');
  }

  String _resolveOfficerName(String? name) {
    if (name != null && name.trim().isNotEmpty) {
      return name.trim();
    }
    final sessionUser = AuthSession.instance.username;
    if (sessionUser != null && sessionUser.trim().isNotEmpty) {
      return sessionUser.trim();
    }
    // Backend requires officer_name; surface honestly instead of inventing one.
    throw ApiException(401, 'DSO session expired. Please log in again.');
  }

  /// Active planning cycle + choice-window state (public endpoint, no auth).
  Future<Map<String, dynamic>> getActiveCycleStatus({String? cycleId}) async {
    final headers = await _getHeaders();
    final q = (cycleId != null && cycleId.trim().isNotEmpty)
        ? '?cycle_id=${Uri.encodeComponent(cycleId.trim())}'
        : '';
    final uri = Uri.parse('${AppConstants.apiBaseUrl}/choice-window/status$q');
    final res = await _client.get(uri, headers: headers);
    if (res.statusCode == 200) {
      return json.decode(res.body) as Map<String, dynamic>;
    }
    throw ApiException(res.statusCode, 'Failed to fetch active cycle status');
  }

  Future<DsoCommandOverview> getCommandOverview({
    String cycleId = '2026-09',
    String district = 'Ramanagara',
  }) async {
    final headers = await _getHeaders();
    final uri = Uri.parse(
        '${AppConstants.apiBaseUrl}/admin/dso/command-overview?cycle_id=$cycleId&district=${Uri.encodeComponent(district)}');
    final res = await _client.get(uri, headers: headers);
    if (res.statusCode == 200) {
      final body = json.decode(res.body) as Map<String, dynamic>;
      return DsoCommandOverview.fromJson(body);
    } else {
      throw ApiException(res.statusCode, 'Failed to fetch DSO command overview');
    }
  }

  Future<Map<String, dynamic>> getDemandValidation({
    String cycleId = '2026-09',
  }) async {
    final headers = await _getHeaders();
    final uri = Uri.parse('${AppConstants.apiBaseUrl}/admin/dso/demand-validation?cycle_id=$cycleId');
    final res = await _client.get(uri, headers: headers);
    if (res.statusCode == 200) {
      return json.decode(res.body) as Map<String, dynamic>;
    } else {
      throw ApiException(res.statusCode, 'Failed to fetch demand validation snapshot');
    }
  }

  Future<Map<String, dynamic>> validateDemand({
    String cycleId = '2026-09',
    String? officerName,
    String? notes,
  }) async {
    final resolvedOfficer = _resolveOfficerName(officerName);
    final headers = await _getHeaders();
    final uri = Uri.parse('${AppConstants.apiBaseUrl}/admin/dso/validate-demand');
    final body = json.encode({
      'cycle_id': cycleId,
      'officer_name': resolvedOfficer,
      'notes': notes ?? 'Statutory demand snapshot validated and sealed with SHA-256.',
    });
    final res = await _client.post(uri, headers: headers, body: body);
    if (res.statusCode == 200) {
      return json.decode(res.body) as Map<String, dynamic>;
    } else {
      throw ApiException(res.statusCode, 'Failed to validate and seal demand');
    }
  }

  Future<DsoAllocationPlan> getAllocationPlan({
    String cycleId = '2026-09',
  }) async {
    final headers = await _getHeaders();
    final uri = Uri.parse('${AppConstants.apiBaseUrl}/admin/dso/allocation-plan?cycle_id=$cycleId');
    final res = await _client.get(uri, headers: headers);
    if (res.statusCode == 200) {
      final body = json.decode(res.body) as Map<String, dynamic>;
      return DsoAllocationPlan.fromJson(body);
    } else {
      throw ApiException(res.statusCode, 'Failed to fetch allocation plan');
    }
  }

  Future<Map<String, dynamic>> overrideAllocation({
    required String fpsId,
    required String commodity,
    required double newAllocationKg,
    required String reason,
    String cycleId = '2026-09',
    String? officerName,
  }) async {
    final resolvedOfficer = _resolveOfficerName(officerName);
    final headers = await _getHeaders();
    final uri = Uri.parse('${AppConstants.apiBaseUrl}/admin/dso/allocation-override');
    final body = json.encode({
      'cycle_id': cycleId,
      'fps_id': fpsId,
      'commodity': commodity,
      'new_allocation_kg': newAllocationKg,
      'reason': reason,
      'officer_name': resolvedOfficer,
    });
    final res = await _client.post(uri, headers: headers, body: body);
    if (res.statusCode == 200) {
      return json.decode(res.body) as Map<String, dynamic>;
    } else {
      throw ApiException(res.statusCode, 'Failed to record allocation override');
    }
  }

  Future<Map<String, dynamic>> approveAllocation({
    String cycleId = '2026-09',
    String? officerName,
  }) async {
    final resolvedOfficer = _resolveOfficerName(officerName);
    final headers = await _getHeaders();
    final uri = Uri.parse(
        '${AppConstants.apiBaseUrl}/admin/dso/allocation-approve?cycle_id=$cycleId&officer_name=${Uri.encodeComponent(resolvedOfficer)}');
    final res = await _client.post(uri, headers: headers);
    if (res.statusCode == 200) {
      return json.decode(res.body) as Map<String, dynamic>;
    } else {
      throw ApiException(res.statusCode, 'Failed to approve allocation plan');
    }
  }

  Future<Map<String, dynamic>> getSupplyRoutes({
    String cycleId = '2026-09',
  }) async {
    final headers = await _getHeaders();
    final uri = Uri.parse('${AppConstants.apiBaseUrl}/admin/dso/supply-routes?cycle_id=$cycleId');
    final res = await _client.get(uri, headers: headers);
    if (res.statusCode == 200) {
      return json.decode(res.body) as Map<String, dynamic>;
    } else {
      throw ApiException(res.statusCode, 'Failed to fetch supply routes');
    }
  }

  Future<Map<String, dynamic>> approveOptimization({
    String cycleId = '2026-09',
    String? officerName,
  }) async {
    final resolvedOfficer = _resolveOfficerName(officerName);
    final headers = await _getHeaders();
    final uri = Uri.parse(
        '${AppConstants.apiBaseUrl}/admin/dso/approve-optimization?cycle_id=$cycleId&officer_name=${Uri.encodeComponent(resolvedOfficer)}');
    final res = await _client.post(uri, headers: headers);
    if (res.statusCode == 200) {
      return json.decode(res.body) as Map<String, dynamic>;
    } else {
      throw ApiException(res.statusCode, 'Failed to approve supply route optimization');
    }
  }

  Future<Map<String, dynamic>> getDispatchManifests({
    String cycleId = '2026-09',
  }) async {
    final headers = await _getHeaders();
    final uri = Uri.parse('${AppConstants.apiBaseUrl}/admin/dso/dispatch-manifests?cycle_id=$cycleId');
    final res = await _client.get(uri, headers: headers);
    if (res.statusCode == 200) {
      return json.decode(res.body) as Map<String, dynamic>;
    } else {
      throw ApiException(res.statusCode, 'Failed to fetch dispatch manifests');
    }
  }

  Future<Map<String, dynamic>> getDispatchCheck({
    required String manifestId,
    String cycleId = '2026-09',
  }) async {
    final headers = await _getHeaders();
    final uri = Uri.parse(
        '${AppConstants.apiBaseUrl}/admin/dso/dispatch-check?manifest_id=$manifestId&cycle_id=$cycleId');
    final res = await _client.get(uri, headers: headers);
    if (res.statusCode == 200) {
      return json.decode(res.body) as Map<String, dynamic>;
    } else {
      throw ApiException(res.statusCode, 'Failed to fetch dispatch check');
    }
  }

  Future<Map<String, dynamic>> authorizeDispatch({
    required String manifestId,
    String cycleId = '2026-09',
    String? officerName,
    String? notes,
  }) async {
    final resolvedOfficer = _resolveOfficerName(officerName);
    final headers = await _getHeaders();
    final uri = Uri.parse('${AppConstants.apiBaseUrl}/admin/dso/dispatch-authorize');
    final body = json.encode({
      'cycle_id': cycleId,
      'manifest_id': manifestId,
      'officer_name': resolvedOfficer,
      'notes': notes ?? 'Statutory pre-dispatch movement authorized by DSO.',
    });
    final res = await _client.post(uri, headers: headers, body: body);
    if (res.statusCode == 200) {
      return json.decode(res.body) as Map<String, dynamic>;
    } else {
      final err = json.decode(res.body);
      throw ApiException(res.statusCode, err['detail'] ?? 'Failed to authorize dispatch');
    }
  }

  Future<Map<String, dynamic>> getDeliveryVerification({
    String cycleId = '2026-09',
  }) async {
    final headers = await _getHeaders();
    final uri = Uri.parse('${AppConstants.apiBaseUrl}/admin/dso/delivery-verification?cycle_id=$cycleId');
    final res = await _client.get(uri, headers: headers);
    if (res.statusCode == 200) {
      return json.decode(res.body) as Map<String, dynamic>;
    } else {
      throw ApiException(res.statusCode, 'Failed to fetch delivery verification');
    }
  }

  Future<Map<String, dynamic>> surpriseInspection({
    required String fpsId,
    required String reason,
    String priority = 'HIGH',
    String? inspectorId,
    String? dsoId,
  }) async {
    final headers = await _getHeaders();
    final uri = Uri.parse('${AppConstants.apiBaseUrl}/admin/dso/surprise-inspection');
    final resolvedDso = (dsoId != null && dsoId.trim().isNotEmpty)
        ? dsoId.trim()
        : (AuthSession.instance.username != null &&
                AuthSession.instance.username!.trim().isNotEmpty
            ? AuthSession.instance.username!.trim()
            : null);
    if (resolvedDso == null) {
      throw ApiException(401, 'DSO session expired. Please log in again.');
    }
    final body = json.encode({
      'fps_id': fpsId,
      'reason': reason,
      'priority': priority,
      if (inspectorId != null && inspectorId.trim().isNotEmpty)
        'inspector_id': inspectorId.trim(),
      'dso_id': resolvedDso,
    });
    final res = await _client.post(uri, headers: headers, body: body);
    if (res.statusCode == 200) {
      return json.decode(res.body) as Map<String, dynamic>;
    } else {
      throw ApiException(res.statusCode, 'Failed to order surprise inspection');
    }
  }

  Future<Map<String, dynamic>> getReconciliation({
    String cycleId = '2026-09',
  }) async {
    final headers = await _getHeaders();
    final uri = Uri.parse('${AppConstants.apiBaseUrl}/admin/dso/reconciliation?cycle_id=$cycleId');
    final res = await _client.get(uri, headers: headers);
    if (res.statusCode == 200) {
      return json.decode(res.body) as Map<String, dynamic>;
    } else {
      throw ApiException(res.statusCode, 'Failed to fetch physical reconciliation');
    }
  }

  Future<Map<String, dynamic>> getCycleEvaluation({
    String cycleId = '2026-09',
  }) async {
    final headers = await _getHeaders();
    final uri = Uri.parse('${AppConstants.apiBaseUrl}/admin/dso/cycle-evaluation?cycle_id=$cycleId');
    final res = await _client.get(uri, headers: headers);
    if (res.statusCode == 200) {
      return json.decode(res.body) as Map<String, dynamic>;
    } else {
      throw ApiException(res.statusCode, 'Failed to fetch cycle evaluation');
    }
  }

  Future<Map<String, dynamic>> closeCycle({
    String cycleId = '2026-09',
    String? officerName,
    String? notes,
  }) async {
    final resolvedOfficer = _resolveOfficerName(officerName);
    final headers = await _getHeaders();
    final uri = Uri.parse('${AppConstants.apiBaseUrl}/admin/dso/close-cycle');
    final body = json.encode({
      'cycle_id': cycleId,
      'officer_name': resolvedOfficer,
      'notes': notes ?? 'Cycle physical reconciliation verified and officially closed.',
    });
    final res = await _client.post(uri, headers: headers, body: body);
    if (res.statusCode == 200) {
      return json.decode(res.body) as Map<String, dynamic>;
    } else {
      throw ApiException(res.statusCode, 'Failed to close cycle');
    }
  }

  Future<List<GovernanceEventItem>> getGovernanceEvents({
    String cycleId = '2026-09',
    int limit = 20,
  }) async {
    final headers = await _getHeaders();
    final uri = Uri.parse(
        '${AppConstants.apiBaseUrl}/admin/governance-events?cycle_id=$cycleId&limit=$limit');
    final res = await _client.get(uri, headers: headers);
    if (res.statusCode == 200) {
      final body = json.decode(res.body) as Map<String, dynamic>;
      final list = (body['events'] as List<dynamic>? ?? [])
          .map((e) => GovernanceEventItem.fromJson(e as Map<String, dynamic>))
          .toList();
      return list;
    } else {
      throw ApiException(res.statusCode, 'Failed to fetch decision trace events');
    }
  }
}
