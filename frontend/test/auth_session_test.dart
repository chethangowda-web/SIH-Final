import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pds_demandsync/services/api_service.dart';

void main() {
  group('AuthSession Unit Tests', () {
    late AuthSession session;

    setUp(() {
      session = AuthSession.instance;
      session.clear();
    });

    test('Initial state is unauthenticated', () {
      expect(session.isAuthenticated, isFalse);
      expect(session.token, isNull);
      expect(session.isAdmin, isFalse);
      expect(session.isBeneficiary, isFalse);
      expect(session.isExpired, isFalse);
    });

    test('Setting admin session activates authenticated state and admin role', () {
      session.setSession(
        token: 'test-admin-jwt-token',
        username: 'admin_user',
        role: 'ADMIN',
        expiresInSeconds: 3600,
      );

      expect(session.isAuthenticated, isTrue);
      expect(session.token, 'test-admin-jwt-token');
      expect(session.username, 'admin_user');
      expect(session.role, 'ADMIN');
      expect(session.isAdmin, isTrue);
      expect(session.isBeneficiary, isFalse);
      expect(session.isExpired, isFalse);
    });

    test('Setting beneficiary session activates authenticated state and beneficiary role', () {
      session.setSession(
        token: 'test-citizen-jwt-token',
        username: 'BEN-KA-0001',
        role: 'BENEFICIARY',
        beneficiaryId: 'BEN-KA-0001',
        expiresInSeconds: 3600,
      );

      expect(session.isAuthenticated, isTrue);
      expect(session.token, 'test-citizen-jwt-token');
      expect(session.username, 'BEN-KA-0001');
      expect(session.role, 'BENEFICIARY');
      expect(session.beneficiaryId, 'BEN-KA-0001');
      expect(session.isAdmin, isFalse);
      expect(session.isBeneficiary, isTrue);
    });

    test('Logout clears session completely', () {
      session.setSession(
        token: 'token-to-clear',
        username: 'admin_user',
        role: 'ADMIN',
      );
      expect(session.isAuthenticated, isTrue);

      session.clear();

      expect(session.isAuthenticated, isFalse);
      expect(session.token, isNull);
      expect(session.username, isNull);
      expect(session.role, isNull);
      expect(session.expiresAt, isNull);
    });

    test('Expired token is detected and reports isExpired == true', () {
      session.setSession(
        token: 'expired-token',
        username: 'admin_user',
        role: 'ADMIN',
        expiresInSeconds: -10, // already in the past
      );

      expect(session.isExpired, isTrue);
      expect(session.isAuthenticated, isFalse);
    });

    test('Triggering 401 clears session and invokes onUnauthorized callback', () {
      session.setSession(
        token: 'active-token',
        username: 'admin_user',
        role: 'ADMIN',
      );

      bool unauthorizedCallbackFired = false;
      session.onUnauthorized = () {
        unauthorizedCallbackFired = true;
      };

      session.trigger401();

      expect(unauthorizedCallbackFired, isTrue);
      expect(session.isAuthenticated, isFalse);
      expect(session.token, isNull);
    });

    test('Triggering 403 retains session and invokes onForbidden callback', () {
      session.setSession(
        token: 'active-beneficiary-token',
        username: 'BEN-KA-0001',
        role: 'BENEFICIARY',
      );

      String? forbiddenMessage;
      session.onForbidden = (msg) {
        forbiddenMessage = msg;
      };

      session.trigger403('Access Denied: Admin privileges required.');

      expect(forbiddenMessage, contains('Access Denied'));
      expect(session.isAuthenticated, isTrue);
      expect(session.token, 'active-beneficiary-token');
    });
  });

  group('AuthenticatedClient & ApiService HTTP Interception Tests', () {
    late AuthSession session;

    setUp(() {
      session = AuthSession.instance;
      session.clear();
    });

    test('AuthenticatedClient automatically injects Authorization Bearer header', () async {
      session.setSession(
        token: 'mock-valid-bearer-token',
        username: 'dso_user',
        role: 'DSO',
      );

      String? capturedAuthHeader;
      final mockClient = MockClient((request) async {
        capturedAuthHeader = request.headers['Authorization'];
        return http.Response(json.encode({'status': 'ok'}), 200);
      });

      final apiService = ApiService(client: mockClient, session: session);
      await apiService.client.get(Uri.parse('http://test.local/api/test'));

      expect(capturedAuthHeader, 'Bearer mock-valid-bearer-token');
    });

    test('ApiService.login updates AuthSession on successful response', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          json.encode({
            'access_token': 'newly-issued-jwt-token',
            'token_type': 'bearer',
            'role': 'ADMIN',
            'beneficiary_id': null,
            'expires_in': 1800,
          }),
          200,
        );
      });

      final apiService = ApiService(client: mockClient, session: session);
      final res = await apiService.login('admin_user', 'admin_pass');

      expect(res['access_token'], 'newly-issued-jwt-token');
      expect(session.isAuthenticated, isTrue);
      expect(session.token, 'newly-issued-jwt-token');
      expect(session.role, 'ADMIN');
      expect(session.isAdmin, isTrue);
    });

    test('ApiService.login throws ApiException on invalid credentials', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          json.encode({'detail': 'Incorrect username or password'}),
          401,
        );
      });

      final apiService = ApiService(client: mockClient, session: session);

      await expectLater(
        () => apiService.login('admin_user', 'wrong_pass'),
        throwsA(isA<UnauthorizedException>().having(
          (e) => e.message,
          'message',
          contains('Incorrect username or password'),
        )),
      );
      expect(session.isAuthenticated, isFalse);
    });

    test('401 response from backend triggers session clearing and onUnauthorized', () async {
      session.setSession(
        token: 'invalid-or-revoked-token',
        username: 'admin_user',
        role: 'ADMIN',
      );

      bool unauthorizedTriggered = false;
      session.onUnauthorized = () {
        unauthorizedTriggered = true;
      };

      final mockClient = MockClient((request) async {
        return http.Response(
          json.encode({'detail': 'Could not validate credentials'}),
          401,
        );
      });

      final apiService = ApiService(client: mockClient, session: session);

      await expectLater(
        () => apiService.fetchAdminDashboard(),
        throwsA(isA<UnauthorizedException>()),
      );

      expect(unauthorizedTriggered, isTrue);
      expect(session.isAuthenticated, isFalse);
      expect(session.token, isNull);
    });

    test('403 response from backend throws ForbiddenException and preserves session', () async {
      session.setSession(
        token: 'beneficiary-token',
        username: 'BEN-KA-0001',
        role: 'BENEFICIARY',
      );

      bool forbiddenTriggered = false;
      session.onForbidden = (msg) {
        forbiddenTriggered = true;
      };

      final mockClient = MockClient((request) async {
        return http.Response(
          json.encode({'detail': 'Operation not permitted. Required role: ADMIN. Current: BENEFICIARY.'}),
          403,
        );
      });

      final apiService = ApiService(client: mockClient, session: session);

      await expectLater(
        () => apiService.fetchAdminDashboard(),
        throwsA(isA<ForbiddenException>().having(
          (e) => e.message,
          'message',
          contains('Operation not permitted'),
        )),
      );

      expect(forbiddenTriggered, isTrue);
      expect(session.isAuthenticated, isTrue);
      expect(session.token, 'beneficiary-token');
    });

    test('Expired session throws UnauthorizedException before outbound request', () async {
      session.setSession(
        token: 'stale-token',
        username: 'admin_user',
        role: 'ADMIN',
        expiresInSeconds: -10, // Expired
      );

      bool unauthorizedTriggered = false;
      session.onUnauthorized = () {
        unauthorizedTriggered = true;
      };

      bool networkCalled = false;
      final mockClient = MockClient((request) async {
        networkCalled = true;
        return http.Response('ok', 200);
      });

      final apiService = ApiService(client: mockClient, session: session);

      await expectLater(
        () => apiService.fetchAdminDashboard(),
        throwsA(isA<UnauthorizedException>()),
      );

      expect(networkCalled, isFalse); // Did not make useless network call
      expect(unauthorizedTriggered, isTrue);
      expect(session.isAuthenticated, isFalse);
    });

    test('409 response from backend throws ConflictException with clear message', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          json.encode({'detail': 'Conflict: Scarcity plan has already been approved.'}),
          409,
        );
      });

      final apiService = ApiService(client: mockClient);

      await expectLater(
        () => apiService.approveScarcityPlan(
          planId: 'PLAN-001',
          officerName: 'District Officer',
          officerRole: 'DISTRICT_SUPPLY_OFFICER',
          approvalNotes: 'Approved',
        ),
        throwsA(isA<ConflictException>().having(
          (e) => e.message,
          'message',
          contains('already been approved'),
        )),
      );
    });

    test('422 response with Pydantic validation errors array parses clean formatted detail', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          json.encode({
            'detail': [
              {'loc': ['body', 'commodity'], 'msg': 'Input should be Rice or Wheat', 'type': 'value_error'},
              {'loc': ['body', 'quantity_kg'], 'msg': 'Input should be greater than 0', 'type': 'greater_than'}
            ]
          }),
          422,
        );
      });

      final apiService = ApiService(client: mockClient);

      await expectLater(
        () => apiService.submitSingleIntent(
          beneficiaryId: 'BEN-KA-0001',
          intendedFpsId: 'FPS-01',
          commodity: 'InvalidCommodity',
        ),
        throwsA(isA<ValidationException>().having(
          (e) => e.message,
          'message',
          contains('Input should be Rice or Wheat'),
        )),
      );
    });

    test('500 response from backend throws ServerException without exposing secrets', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          json.encode({'detail': 'Internal Server Error: Database operation failed.'}),
          500,
        );
      });

      final apiService = ApiService(client: mockClient);

      await expectLater(
        () => apiService.fetchAdminDashboard(),
        throwsA(isA<ServerException>().having(
          (e) => e.statusCode,
          'statusCode',
          500,
        )),
      );
    });
  });
}
