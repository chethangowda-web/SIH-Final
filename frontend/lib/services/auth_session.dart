import 'dart:async';

/// Base API Exception representing structured HTTP error responses from PDS DemandSync.
class ApiException implements Exception {
  final int statusCode;
  final String message;
  final dynamic details;

  const ApiException(this.statusCode, this.message, {this.details});

  @override
  String toString() => message;
}

/// Specialized 401 Unauthorized Exception when authentication token is missing or expired.
class UnauthorizedException extends ApiException {
  const UnauthorizedException([String message = 'Session expired or unauthorized. Please log in again.'])
      : super(401, message);
}

/// Specialized 403 Forbidden Exception when user role is not permitted for the action.
class ForbiddenException extends ApiException {
  const ForbiddenException([String message = 'Access Denied: You do not have permission for this operation.'])
      : super(403, message);
}

/// Specialized 409 Conflict Exception when concurrent mutation or state collision occurs.
class ConflictException extends ApiException {
  const ConflictException([String message = 'Conflict: The requested operation conflicts with the current server state.', dynamic details])
      : super(409, message, details: details);
}

/// Specialized 422 Validation Exception when payload fails semantic validation.
class ValidationException extends ApiException {
  const ValidationException([String message = 'Validation Error: Invalid input parameters provided.', dynamic details])
      : super(422, message, details: details);
}

/// Specialized 500+ Server Exception when backend encounters an internal error.
class ServerException extends ApiException {
  const ServerException([String message = 'Server Error: The server encountered an internal error. Please try again later.', dynamic details])
      : super(500, message, details: details);
}

/// Centralized Authentication and Session State Manager for PDS DemandSync.
/// Encapsulates access token, active user role, identity, and expiration tracking.
class AuthSession {
  static final AuthSession _instance = AuthSession._internal();
  static AuthSession get instance => _instance;

  AuthSession._internal();

  String? _token;
  String? _username;
  String? _role;
  String? _beneficiaryId;
  DateTime? _expiresAt;

  final StreamController<AuthSession> _streamController = StreamController<AuthSession>.broadcast();
  Stream<AuthSession> get stream => _streamController.stream;

  void Function()? onUnauthorized;
  void Function(String message)? onForbidden;

  String? get token => _token;
  String? get username => _username;
  String? get role => _role;
  String? get beneficiaryId => _beneficiaryId;
  DateTime? get expiresAt => _expiresAt;

  bool get isAuthenticated => _token != null && _token!.isNotEmpty && !isExpired;
  bool get isExpired => _expiresAt != null && DateTime.now().isAfter(_expiresAt!);
  
  bool get isAdmin =>
      isAuthenticated &&
      (_role == 'ADMIN' ||
          _role == 'DSO' ||
          _role == 'AUDITOR' ||
          _role == 'DISTRICT_SUPPLY_OFFICER' ||
          _role == 'DEPOT_MANAGER' ||
          _role == 'SUPER_ADMIN');

  bool get isBeneficiary => isAuthenticated && (_role == 'BENEFICIARY' || _beneficiaryId != null);

  /// Establish an active authenticated session.
  void setSession({
    required String token,
    required String username,
    required String role,
    String? beneficiaryId,
    int expiresInSeconds = 36000,
  }) {
    _token = token;
    _username = username;
    _role = role.toUpperCase();
    _beneficiaryId = beneficiaryId;
    _expiresAt = DateTime.now().add(Duration(seconds: expiresInSeconds));
    _streamController.add(this);
  }

  /// Explicitly clear session state on logout or authentication failure.
  void clear() {
    _token = null;
    _username = null;
    _role = null;
    _beneficiaryId = null;
    _expiresAt = null;
    _streamController.add(this);
  }

  /// Trigger deterministic 401 handling: clears session and invokes unauthorized callback if active session existed.
  void trigger401() {
    final hadSession = _token != null && _token!.isNotEmpty;
    clear();
    if (hadSession) {
      onUnauthorized?.call();
    }
  }

  /// Trigger deterministic 403 handling: notifies access denied without clearing session.
  void trigger403(String message) {
    onForbidden?.call(message);
  }
}
