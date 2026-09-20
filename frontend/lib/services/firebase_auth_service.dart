import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Result container for Firebase Phone OTP operations
class FirebasePhoneAuthResult {
  final bool isSuccess;
  final String? verificationId;
  final dynamic confirmationResult; // ConfirmationResult on Flutter Web
  final int? resendToken;
  final String? errorMessage;
  final bool isAutoVerified;
  final String? idToken;

  const FirebasePhoneAuthResult({
    required this.isSuccess,
    this.verificationId,
    this.confirmationResult,
    this.resendToken,
    this.errorMessage,
    this.isAutoVerified = false,
    this.idToken,
  });
}

/// Unified Service for Firebase Phone Authentication across Web, Android, and iOS.
class FirebaseAuthService {
  FirebaseAuthService._internal();
  static final FirebaseAuthService instance = FirebaseAuthService._internal();

  FirebaseAuth? _auth;
  bool _isInitialized = false;

  /// Ensure Firebase is initialized safely
  Future<bool> initialize() async {
    if (_isInitialized) return true;
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
      _auth = FirebaseAuth.instance;
      _isInitialized = true;
      return true;
    } catch (e) {
      debugPrint('[FirebaseAuthService] Firebase initialization notice: $e');
      return false;
    }
  }

  bool get isAvailable => _isInitialized && _auth != null;

  /// Trigger Firebase Phone OTP SMS to the citizen's mobile number.
  Future<FirebasePhoneAuthResult> sendOtp({
    required String phoneNumber,
    required void Function(String verificationId, int? resendToken) onCodeSent,
    required void Function(String errorMessage) onVerificationFailed,
    void Function(String idToken)? onAutoVerified,
    int? forceResendingToken,
  }) async {
    final ready = await initialize();
    if (!ready || _auth == null) {
      return const FirebasePhoneAuthResult(
        isSuccess: false,
        errorMessage: 'Firebase Auth is not initialized on this platform.',
      );
    }

    final normalizedPhone = phoneNumber.startsWith('+') ? phoneNumber : '+91${phoneNumber.replaceAll(RegExp(r'[^0-9]'), '')}';

    try {
      if (kIsWeb) {
        // Flutter Web Phone Auth Flow
        try {
          final confirmationResult = await _auth!.signInWithPhoneNumber(
            normalizedPhone,
            // Uses browser RecaptchaVerifier automatically
          );
          onCodeSent(confirmationResult.verificationId, null);
          return FirebasePhoneAuthResult(
            isSuccess: true,
            verificationId: confirmationResult.verificationId,
            confirmationResult: confirmationResult,
          );
        } catch (webErr) {
          final msg = webErr.toString();
          onVerificationFailed(msg);
          return FirebasePhoneAuthResult(isSuccess: false, errorMessage: msg);
        }
      } else {
        // Mobile (Android / iOS) Phone Auth Flow
        final completer = Completer<FirebasePhoneAuthResult>();

        await _auth!.verifyPhoneNumber(
          phoneNumber: normalizedPhone,
          timeout: const Duration(seconds: 60),
          forceResendingToken: forceResendingToken,
          verificationCompleted: (PhoneAuthCredential credential) async {
            try {
              final userCredential = await _auth!.signInWithCredential(credential);
              final token = await userCredential.user?.getIdToken();
              if (token != null) {
                onAutoVerified?.call(token);
                if (!completer.isCompleted) {
                  completer.complete(
                    FirebasePhoneAuthResult(
                      isSuccess: true,
                      isAutoVerified: true,
                      idToken: token,
                    ),
                  );
                }
              }
            } catch (e) {
              debugPrint('[FirebaseAuthService] Auto verification sign-in: $e');
            }
          },
          verificationFailed: (FirebaseAuthException authEx) {
            final msg = authEx.message ?? 'Phone verification failed (${authEx.code})';
            onVerificationFailed(msg);
            if (!completer.isCompleted) {
              completer.complete(FirebasePhoneAuthResult(isSuccess: false, errorMessage: msg));
            }
          },
          codeSent: (String verificationId, int? resendToken) {
            onCodeSent(verificationId, resendToken);
            if (!completer.isCompleted) {
              completer.complete(
                FirebasePhoneAuthResult(
                  isSuccess: true,
                  verificationId: verificationId,
                  resendToken: resendToken,
                ),
              );
            }
          },
          codeAutoRetrievalTimeout: (String verificationId) {
            debugPrint('[FirebaseAuthService] Auto retrieval timeout for $verificationId');
          },
        );

        return await completer.future;
      }
    } catch (e) {
      final msg = 'Failed to initiate Firebase Phone Auth: $e';
      onVerificationFailed(msg);
      return FirebasePhoneAuthResult(isSuccess: false, errorMessage: msg);
    }
  }

  /// Verify entered SMS OTP code with Firebase and retrieve the secure ID Token.
  Future<String?> verifyOtpAndGetToken({
    required String smsCode,
    String? verificationId,
    dynamic confirmationResult,
  }) async {
    final ready = await initialize();
    if (!ready || _auth == null) {
      throw Exception('Firebase Auth is not available');
    }

    try {
      UserCredential userCredential;
      if (kIsWeb && confirmationResult != null) {
        // ConfirmationResult.confirm on Web
        userCredential = await confirmationResult.confirm(smsCode.trim());
      } else if (verificationId != null) {
        // PhoneAuthProvider.credential on Android / iOS
        final credential = PhoneAuthProvider.credential(
          verificationId: verificationId,
          smsCode: smsCode.trim(),
        );
        userCredential = await _auth!.signInWithCredential(credential);
      } else {
        throw Exception('Missing verification session credentials');
      }

      final idToken = await userCredential.user?.getIdToken();
      return idToken ?? userCredential.user?.uid;
    } on FirebaseAuthException catch (fe) {
      throw Exception(fe.message ?? 'Invalid OTP code (${fe.code})');
    } catch (e) {
      throw Exception('OTP verification failed: $e');
    }
  }

  /// Sign out from Firebase session
  Future<void> signOut() async {
    try {
      await _auth?.signOut();
    } catch (_) {}
  }
}
