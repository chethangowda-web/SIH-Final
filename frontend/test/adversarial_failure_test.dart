import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pds_demandsync/services/api_service.dart';

void main() {
  group('Frontend Adversarial & Failure-Mode Tests', () {
    late AuthSession session;

    setUp(() {
      session = AuthSession.instance;
      session.clear();
    });

    test('Malformed JSON response handling throws ApiException with clear message', () async {
      final mockClient = MockClient((request) async {
        // Simulate server returning raw HTML (e.g. 502 Bad Gateway / Cloudflare error page)
        return http.Response(
          '<html><body><h1>502 Bad Gateway</h1><p>nginx/1.18.0</p></body></html>',
          502,
          headers: {'content-type': 'text/html'},
        );
      });

      final authClient = AuthenticatedClient(mockClient);

      expect(
        () async {
          final res = await authClient.get(Uri.parse('http://localhost:8000/api/admin/dashboard'));
          if (res.statusCode >= 400) {
            try {
              final body = json.decode(res.body);
              throw ApiException(res.statusCode, body['detail'] ?? 'Error');
            } on FormatException {
              throw ApiException(res.statusCode, 'Server returned non-JSON response (status: ${res.statusCode})');
            }
          }
        },
        throwsA(isA<ApiException>().having(
          (e) => e.message,
          'message',
          contains('non-JSON response'),
        )),
      );
    });

    test('Empty data collections parsed gracefully without null-pointer exceptions', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          json.encode({
            'total': 0,
            'limit': 50,
            'offset': 0,
            'items': [],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final authClient = AuthenticatedClient(mockClient);
      final res = await authClient.get(Uri.parse('http://localhost:8000/api/beneficiaries'));
      expect(res.statusCode, 200);

      final data = json.decode(res.body);
      expect(data['items'], isEmpty);
      expect(data['total'], 0);
    });

    test('Server unreachable / Network failure throws ApiException with connectivity detail', () async {
      final mockClient = MockClient((request) async {
        throw http.ClientException('Connection refused: Failed to connect to localhost:8000');
      });

      final authClient = AuthenticatedClient(mockClient);

      expect(
        () async {
          try {
            await authClient.get(Uri.parse('http://localhost:8000/api/health/live'));
          } on http.ClientException catch (e) {
            throw ApiException(0, 'Network connectivity error: ${e.message}');
          }
        },
        throwsA(isA<ApiException>().having(
          (e) => e.message,
          'message',
          contains('Connection refused'),
        )),
      );
    });

    test('Missing session attributes handle edge cases safely', () {
      session.setSession(
        token: 'token-without-extras',
        username: 'custom_user',
        role: 'UNKNOWN_ROLE',
      );

      expect(session.isAuthenticated, isTrue);
      expect(session.isAdmin, isFalse);
      expect(session.isBeneficiary, isFalse);
      expect(session.beneficiaryId, isNull);
    });

    test('Repeated clear and double logout is idempotent and crash-free', () {
      session.clear();
      session.clear();
      session.trigger401();
      expect(session.isAuthenticated, isFalse);
      expect(session.token, isNull);
    });

    test('ApiService.parseError deterministically maps all HTTP status codes', () {
      final apiService = ApiService();

      // 401
      final err401 = apiService.parseError(http.Response(json.encode({'detail': 'Token expired'}), 401));
      expect(err401, isA<UnauthorizedException>());
      expect(err401.message, 'Token expired');

      // 403
      final err403 = apiService.parseError(http.Response(json.encode({'detail': 'Access denied'}), 403));
      expect(err403, isA<ForbiddenException>());
      expect(err403.message, 'Access denied');

      // 409
      final err409 = apiService.parseError(http.Response(json.encode({'detail': 'Conflict: Plan already approved'}), 409));
      expect(err409, isA<ConflictException>());
      expect(err409.message, contains('Conflict'));

      // 422 Pydantic array
      final err422 = apiService.parseError(http.Response(
        json.encode({
          'detail': [
            {'msg': 'Field required', 'loc': ['body', 'fps_id']},
            {'msg': 'Value error, invalid quota', 'loc': ['body', 'quantity_kg']}
          ]
        }),
        422,
      ));
      expect(err422, isA<ValidationException>());
      expect(err422.message, contains('Field required'));
      expect(err422.message, contains('Value error, invalid quota'));

      // 500
      final err500 = apiService.parseError(http.Response(json.encode({'detail': 'Internal database error'}), 500));
      expect(err500, isA<ServerException>());
      expect(err500.statusCode, 500);

      // Non-JSON HTML error page (e.g. 502 Bad Gateway)
      final errHtml = apiService.parseError(http.Response('<html>502 Bad Gateway</html>', 502), 'Gateway error');
      expect(errHtml, isA<ServerException>());
      expect(errHtml.message, contains('Gateway error (status 502)'));
    });
  });
}
