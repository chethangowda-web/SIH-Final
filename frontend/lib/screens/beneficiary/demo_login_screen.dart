import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/localization.dart';
import '../../services/api_service.dart';
import '../../services/firebase_auth_service.dart';
import '../../services/voice_assistant_service.dart';
import 'beneficiary_home_screen.dart';
import '../admin/admin_dashboard_screen.dart';
import '../admin/dso_dashboard_screen.dart';
import '../admin/field_food_inspector_dashboard_screen.dart';
import '../admin/fps_owner_dashboard_screen.dart';
import '../admin/auditor_dashboard_screen.dart';

class DemoLoginScreen extends StatefulWidget {
  final ApiService? apiService;
  final String? sessionExpiredMessage;
  final int? initialTabIndex;

  const DemoLoginScreen({super.key, this.apiService, this.sessionExpiredMessage, this.initialTabIndex});

  @override
  State<DemoLoginScreen> createState() => _DemoLoginScreenState();
}

class _DemoLoginScreenState extends State<DemoLoginScreen> {
  late final ApiService _apiService;
  int? _selectedTabIndex; // null: Initial Portal Selection, 0: Citizen OTP, 1: Department

  // Controllers for Citizen Login (Ration Card Number + Registered Phone Number)
  final TextEditingController _citizenCardController = TextEditingController();
  final TextEditingController _citizenPhoneController = TextEditingController();
  final TextEditingController _citizenOtpController = TextEditingController();
  bool _otpSent = false;
  bool _isSendingOtp = false;
  bool _isVerifyingOtp = false;
  int _otpCountdownSeconds = 300;
  Timer? _countdownTimer;

  // Firebase Phone Auth Session Variables
  String? _firebaseVerificationId;
  dynamic _firebaseConfirmationResult;
  int? _firebaseResendToken;
  String? _validatedNormalizedPhone;
  bool _isFirebaseOtpSession = false;

  // Controllers for Department / Admin Login
  final TextEditingController _adminUsernameController = TextEditingController();
  final TextEditingController _adminPasswordController = TextEditingController();
  bool _isAdminLoggingIn = false;
  bool _isPasswordObscured = true;

  // Modern GovTech Design System Tokens
  static const Color _govNavy = Color(0xFF0F2942);
  static const Color _govGreen = Color(0xFF15803D);
  static const Color _govGreenLight = Color(0xFF16A34A);
  static const Color _govGreenBg = Color(0xFFF0FDF4);
  static const Color _govGreenBorder = Color(0xFF86EFAC);
  static const Color _saffron = Color(0xFFFF9933);
  static const Color _slate900 = Color(0xFF0F172A);
  static const Color _slate700 = Color(0xFF334155);
  static const Color _slate500 = Color(0xFF64748B);
  static const Color _slate400 = Color(0xFF94A3B8);
  static const Color _slate200 = Color(0xFFE2E8F0);
  static const Color _slate100 = Color(0xFFF1F5F9);
  static const Color _slate50 = Color(0xFFF8FAFC);

  @override
  void initState() {
    super.initState();
    _apiService = widget.apiService ?? ApiService();
    _selectedTabIndex = widget.initialTabIndex;

    // Login screen starts with Voice Assistant stopped
    VoiceAssistantService.instance.stopVoiceAssistantMode();
    VoiceAssistantService.instance.onCommandRecognized = null;

    if (_selectedTabIndex == 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _activateCitizenVoice();
      });
    }

    _citizenOtpController.addListener(_onOtpChanged);

    if (widget.sessionExpiredMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.sessionExpiredMessage!),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      });
    }
  }

  void _onOtpChanged() {
    final text = _citizenOtpController.text.trim();
    if (_otpSent && text.length == 6 && _selectedTabIndex == 0 && VoiceAssistantService.instance.isVoiceAssistantMode) {
      VoiceAssistantService.instance.guideLoginStepOtpEntered();
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _citizenOtpController.removeListener(_onOtpChanged);
    _citizenCardController.dispose();
    _citizenPhoneController.dispose();
    _citizenOtpController.dispose();
    _adminUsernameController.dispose();
    _adminPasswordController.dispose();
    super.dispose();
  }

  void _startOtpTimer() {
    _countdownTimer?.cancel();
    setState(() => _otpCountdownSeconds = 300);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_otpCountdownSeconds > 0) {
        setState(() => _otpCountdownSeconds--);
      } else {
        timer.cancel();
      }
    });
  }

  String _formatTimer(int sec) {
    final m = (sec ~/ 60).toString().padLeft(2, '0');
    final s = (sec % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String _cleanErrorMessage(dynamic e) {
    final str = e.toString();
    if (str.contains('TimeoutException') || str.contains('Future not completed')) {
      return 'Connection timed out while reaching the cloud server. Please retry in a moment.';
    }
    if (e is ApiException) {
      return e.message;
    }
    if (str.startsWith('Exception: ')) {
      return str.replaceFirst('Exception: ', '');
    }
    return str;
  }

  void _activateCitizenVoice() {
    final voice = VoiceAssistantService.instance;
    voice.enableBeneficiaryVoiceMode();
    _setupCitizenVoiceRecognition();
    voice.guideLoginStepRationId();
  }

  void _deactivateCitizenVoice() {
    final voice = VoiceAssistantService.instance;
    voice.stop();
    voice.stopListening();
    voice.stopVoiceAssistantMode();
    voice.onCommandRecognized = null;
  }

  void _handleTabSelection(int index) {
    if (_selectedTabIndex == index) return;
    setState(() {
      _selectedTabIndex = index;
    });

    if (index == 0) {
      _activateCitizenVoice();
    } else {
      _deactivateCitizenVoice();
    }
  }

  void _setupCitizenVoiceRecognition() {
    final voice = VoiceAssistantService.instance;
    voice.onCommandRecognized = (transcript) {
      if (!mounted || _selectedTabIndex != 0) return;
      final lower = transcript.toLowerCase().trim();
      if (lower.isEmpty) return;

      if (lower.contains('hindi') || lower.contains('हिंदी') || lower.contains('हिन्दी')) {
        LanguageController.instance.setLanguage(AppLanguage.hindi);
        return;
      }
      if (lower.contains('kannada') || lower.contains('ಕನ್ನಡ')) {
        LanguageController.instance.setLanguage(AppLanguage.kannada);
        return;
      }
      if (lower.contains('english') || lower.contains('अंग्रेजी') || lower.contains('ಇಂಗ್ಲಿಷ್')) {
        LanguageController.instance.setLanguage(AppLanguage.english);
        return;
      }

      if (_otpSent) {
        if (lower.contains('login') || lower.contains('verify') || lower.contains('सत्यापित') || lower.contains('लॉगिन') || lower.contains('ದೃಢೀಕರಿಸಿ') || lower.contains('ಲಾಗಿನ್')) {
          _handleVerifyOtpAndLogin();
          return;
        }
        final digits = VoiceAssistantService.normalizeSpokenDigits(transcript).replaceAll(RegExp(r'[^0-9]'), '');
        if (digits.length >= 4) {
          setState(() {
            _citizenOtpController.text = digits.length > 6 ? digits.substring(0, 6) : digits;
          });
          voice.guideLoginStepOtpEntered();
          return;
        }
      } else {
        if (lower.contains('get otp') || lower.contains('send otp') || lower.contains('ओटीपी भेजें') || lower.contains('ಒಟಿಪಿ ಪಡೆಯಿರಿ') || lower.contains('otp')) {
          _handleSendOtp();
          return;
        }
        final phone = VoiceAssistantService.extractPhoneNumber(transcript);
        if (phone.length == 10) {
          setState(() {
            _citizenPhoneController.text = phone;
          });
          return;
        }
        if (lower.contains('rc') || lower.contains('card') || lower.contains('कार्ड') || lower.contains('ಕಾರ್ಡ್')) {
          final digits = VoiceAssistantService.normalizeSpokenDigits(transcript).replaceAll(RegExp(r'[^0-9]'), '');
          if (digits.isNotEmpty) {
            setState(() {
              _citizenCardController.text = 'RC-KA-${digits.padLeft(6, '0')}';
            });
            voice.guideLoginStepPhone();
            return;
          }
        }
      }
    };
  }

  void _showVoiceInputModal({
    required String title,
    required String prompt,
    required String fieldType, // 'card', 'phone', 'otp'
    required void Function(String result) onValueRecognized,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return _VoiceInputListeningSheet(
          title: title,
          prompt: prompt,
          fieldType: fieldType,
          onApply: (val) {
            Navigator.pop(ctx);
            onValueRecognized(val);
          },
        );
      },
    );
  }

  void _listenForRationCard() {
    final isKn = LanguageController.instance.currentLanguage == AppLanguage.kannada;
    final isHi = LanguageController.instance.currentLanguage == AppLanguage.hindi;

    final title = isKn
        ? 'ಪಡಿತರ ಚೀಟಿ ಸಂಖ್ಯೆ ಹೇಳಿ'
        : isHi
            ? 'राशन कार्ड नंबर बोलें'
            : 'Speak Ration Card Number';

    final prompt = isKn
        ? 'ಉದಾಹರಣೆಗೆ: ಆರ್ ಸಿ ಕೆ ಎ 0 0 0 0 0 1 ಅಥವಾ 1 ರಿಂದ 8000'
        : isHi
            ? 'उदाहरण के लिए: आर सी के ए 0 0 0 0 0 1 या 1 से 8000'
            : 'Say digits or card number e.g., RC-KA-000001 or 1 to 8000';

    _showVoiceInputModal(
      title: title,
      prompt: prompt,
      fieldType: 'card',
      onValueRecognized: (val) {
        setState(() {
          _citizenCardController.text = val;
        });
        VoiceAssistantService.instance.guideLoginStepPhone();
      },
    );
  }

  void _listenForPhone() {
    final isKn = LanguageController.instance.currentLanguage == AppLanguage.kannada;
    final isHi = LanguageController.instance.currentLanguage == AppLanguage.hindi;

    final title = isKn
        ? 'ನೋಂದಾಯಿತ ಮೊಬೈಲ್ ಸಂಖ್ಯೆ ಹೇಳಿ'
        : isHi
            ? 'पंजीकृत मोबाइल नंबर बोलें'
            : 'Speak Registered Mobile Number';

    final prompt = isKn
        ? 'ನಿಮ್ಮ 10-ಅಂಕಿಯ ಮೊಬೈಲ್ ಸಂಖ್ಯೆಯನ್ನು ಸ್ಪಷ್ಟವಾಗಿ ಹೇಳಿ'
        : isHi
            ? 'अपना 10-अंकीय मोबाइल नंबर स्पष्ट रूप से बोलें'
            : 'Speak your 10-digit registered mobile number';

    _showVoiceInputModal(
      title: title,
      prompt: prompt,
      fieldType: 'phone',
      onValueRecognized: (val) {
        setState(() {
          _citizenPhoneController.text = val;
        });
      },
    );
  }

  void _listenForOtp() {
    final isKn = LanguageController.instance.currentLanguage == AppLanguage.kannada;
    final isHi = LanguageController.instance.currentLanguage == AppLanguage.hindi;

    final title = isKn
        ? 'ಒಟಿಪಿ ಕೋಡ್ ಹೇಳಿ'
        : isHi
            ? 'ओटीपी कोड बोलें'
            : 'Speak 6-Digit OTP Code';

    final prompt = isKn
        ? 'ಎಸ್ಎಂಎಸ್ ಮೂಲಕ ಬಂದ 6-ಅಂಕಿಯ ಒಟಿಪಿ ಹೇಳಿ'
        : isHi
            ? 'एसएमएस से प्राप्त 6-अंकीय ओटीपी बोलें'
            : 'Speak the 6 digits of your SMS OTP';

    _showVoiceInputModal(
      title: title,
      prompt: prompt,
      fieldType: 'otp',
      onValueRecognized: (val) {
        setState(() {
          _citizenOtpController.text = val;
        });
        VoiceAssistantService.instance.guideLoginStepOtpEntered();
      },
    );
  }

  // Action: Multi-Stage Citizen Authentication:
  // 1. Pre-flight Dataset Verification: Ration card exists + Phone belongs to household
  // 2. Firebase Phone Auth: SMS OTP delivered to citizen's phone
  // 3. Fallback Demo OTP for offline / hackathon testing
  Future<void> _handleSendOtp() async {
    final cardId = _citizenCardController.text.trim();
    final phoneNumber = _citizenPhoneController.text.trim();

    if (cardId.isEmpty || phoneNumber.isEmpty) {
      final isHi = LanguageController.instance.currentLanguage == AppLanguage.hindi;
      final isKn = LanguageController.instance.currentLanguage == AppLanguage.kannada;
      final msg = isHi
          ? 'कृपया राशन कार्ड नंबर और पंजीकृत मोबाइल नंबर दोनों दर्ज करें।'
          : isKn
              ? 'ದಯವಿಟ್ಟು ಪಡಿತರ ಚೀಟಿ ಸಂಖ್ಯೆ ಮತ್ತು ನೋಂದಾಯಿತ ಮೊಬೈಲ್ ಸಂಖ್ಯೆ ಎರಡನ್ನೂ ನಮೂದಿಸಿ.'
              : 'Please enter both your Ration Card Number and Registered Mobile Number.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: Colors.orange.shade800,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final digitsOnly = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.length < 10) {
      final isHi = LanguageController.instance.currentLanguage == AppLanguage.hindi;
      final isKn = LanguageController.instance.currentLanguage == AppLanguage.kannada;
      final msg = isHi
          ? 'कृपया एक मान्य 10-अंकीय मोबाइल नंबर दर्ज करें।'
          : isKn
              ? 'ದಯವಿಟ್ಟು ಮಾನ್ಯವಾದ 10-ಅಂಕಿಯ ಮೊಬೈಲ್ ಸಂಖ್ಯೆಯನ್ನು ನಮೂದಿಸಿ.'
              : 'Please enter a valid 10-digit registered mobile number.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: Colors.orange.shade800,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSendingOtp = true);
    try {
      // Step 1: Pre-flight check against official NFSA Government Master Dataset
      final householdValidation = await _apiService.validateHouseholdCredentials(cardId, phoneNumber);
      final normalizedPhone = householdValidation['normalized_phone'] as String? ?? '+91$digitsOnly';
      final maskedPhone = householdValidation['masked_phone'] as String? ?? '+91 ******${digitsOnly.substring(digitsOnly.length - 4)}';
      _validatedNormalizedPhone = normalizedPhone;

      bool firebaseSuccess = false;

      // Step 2: Attempt Firebase Phone Authentication SMS delivery
      try {
        final fbResult = await FirebaseAuthService.instance.sendOtp(
          phoneNumber: normalizedPhone,
          forceResendingToken: _firebaseResendToken,
          onCodeSent: (verificationId, resendToken) {
            _firebaseVerificationId = verificationId;
            _firebaseResendToken = resendToken;
          },
          onVerificationFailed: (errorMsg) {
            debugPrint('[Login] Firebase Phone Auth Notice: $errorMsg');
          },
          onAutoVerified: (idToken) {
            debugPrint('[Login] Firebase Auto-verified phone');
          },
        );

        if (fbResult.isSuccess) {
          firebaseSuccess = true;
          _isFirebaseOtpSession = true;
          _firebaseVerificationId = fbResult.verificationId;
          _firebaseConfirmationResult = fbResult.confirmationResult;
        }
      } catch (fbErr) {
        debugPrint('[Login] Firebase Auth fallback notice: $fbErr');
      }

      if (!mounted) return;

      setState(() {
        _otpSent = true;
      });
      _startOtpTimer();

      String displayText;
      if (firebaseSuccess) {
        displayText = 'Firebase SMS OTP dispatched to $maskedPhone.';
        _citizenOtpController.clear();
      } else {
        // Step 2b: Fallback to PDS DemandSync OTP service
        final fallbackRes = await _apiService.sendCitizenOtp(cardId, phoneNumber: phoneNumber);
        final mockOtp = (fallbackRes['mock_otp'] ?? fallbackRes['demo_otp_code'] ?? fallbackRes['otp'] ?? '123456').toString();
        displayText = 'OTP dispatched to $maskedPhone. (Test code: $mockOtp)';
        _citizenOtpController.text = mockOtp;
      }

      // Spoken guidance step 3: OTP Requested
      if (_selectedTabIndex == 0 && VoiceAssistantService.instance.isVoiceAssistantMode) {
        VoiceAssistantService.instance.guideLoginStepOtpRequested();
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(displayText),
              ),
            ],
          ),
          backgroundColor: _govGreen,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 8),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('login.otp_send_failed', params: {'error': _cleanErrorMessage(e)})),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSendingOtp = false);
    }
  }

  // Action: Verify OTP with Firebase & establish Backend PDS Session
  Future<void> _handleVerifyOtpAndLogin() async {
    final cardId = _citizenCardController.text.trim();
    final otp = _citizenOtpController.text.trim();
    final phoneNumber = _citizenPhoneController.text.trim();

    if (otp.isEmpty || otp.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('login.enter_valid_otp'))),
      );
      return;
    }

    setState(() => _isVerifyingOtp = true);
    try {
      if (_isFirebaseOtpSession && (_firebaseVerificationId != null || _firebaseConfirmationResult != null)) {
        // 1. Verify OTP with Firebase Auth and retrieve verified ID Token
        final idToken = await FirebaseAuthService.instance.verifyOtpAndGetToken(
          smsCode: otp,
          verificationId: _firebaseVerificationId,
          confirmationResult: _firebaseConfirmationResult,
        );

        // 2. Exchange Firebase identity with Backend PDS Security Authority
        await _apiService.firebaseCitizenLogin(
          cardId,
          _validatedNormalizedPhone ?? phoneNumber,
          firebaseIdToken: idToken,
        );
      } else {
        // Fallback standard PDS OTP verification
        await _apiService.verifyCitizenOtp(cardId, otp);
      }

      if (!mounted) return;

      // Crucial: Keep Voice Assistant enabled for authenticated Beneficiary Portal
      VoiceAssistantService.instance.enableBeneficiaryVoiceMode();

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => BeneficiaryHomeScreen(
            beneficiaryId: cardId,
            apiService: _apiService,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('login.otp_verify_failed', params: {'error': _cleanErrorMessage(e)})),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      if (mounted) setState(() => _isVerifyingOtp = false);
    }
  }

  // Action: Department Admin Login
  Future<void> _handleDepartmentLogin() async {
    final username = _adminUsernameController.text.trim();
    final password = _adminPasswordController.text.trim();
    if (username.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('login.enter_creds_hint'))),
      );
      return;
    }

    // Ensure Voice Assistant is completely deactivated for Department Official flow
    _deactivateCitizenVoice();

    setState(() => _isAdminLoggingIn = true);
    try {
      final authRes = await _apiService.login(username, password);
      final role = (authRes['role'] as String? ?? 'DSO').toUpperCase();
      final uName = authRes['username'] as String? ?? username;

      Widget targetScreen;
      if (role == 'DSO' || role == 'DISTRICT_SUPPLY_OFFICER' || role == 'ADMIN' || uName == 'dso_user' || uName == 'admin_user' || uName == 'admin') {
        targetScreen = DsoDashboardScreen(apiService: _apiService, username: uName);
      } else if (role == 'FIELD_FOOD_INSPECTOR' || role == 'FIELD_OFFICER' || uName == 'inspector_user' || uName == 'field_officer_user' || uName.startsWith('INSP-')) {
        targetScreen = FieldFoodInspectorDashboardScreen(apiService: _apiService, username: uName);
      } else if (role == 'FPS_OWNER' || uName.startsWith('FPS') || uName == 'fps_user') {
        targetScreen = FpsOwnerDashboardScreen(apiService: _apiService, username: uName);
      } else if (role == 'AUDITOR' || uName == 'auditor_user') {
        targetScreen = AuditorDashboardScreen(apiService: _apiService, username: uName);
      } else {
        targetScreen = AdminDashboardScreen(
          apiService: _apiService,
          userRole: role,
          username: uName,
        );
      }

      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => targetScreen),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('login.dept_login_failed', params: {'error': _cleanErrorMessage(e)})),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      if (mounted) setState(() => _isAdminLoggingIn = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallMobile = screenWidth < 380;
    final isTabletOrDesktop = screenWidth >= 600;
    final horizontalPad = isSmallMobile ? 12.0 : (isTabletOrDesktop ? 28.0 : 16.0);
    final verticalPad = isSmallMobile ? 16.0 : 24.0;

    return ListenableBuilder(
      listenable: LanguageController.instance,
      builder: (context, child) {
        return Scaffold(
          backgroundColor: Colors.white,
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: horizontalPad, vertical: verticalPad),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Top Responsive Brand Header
                      _buildHeader(isSmallMobile),

                      SizedBox(height: isSmallMobile ? 12 : 16),

                      // Prominent, high-contrast 3-language selector
                      const ProminentLanguageBar(),

                      SizedBox(height: isSmallMobile ? 12 : 14),



                      // Main Login Card
                      _buildCard(isSmallMobile),

                      SizedBox(height: isSmallMobile ? 16 : 20),

                      // Footer with Diagnostics & NIC Branding
                      _buildFooter(isSmallMobile),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ================================================================
  // HEADER (Mobile Responsive)
  // ================================================================
  Widget _buildHeader(bool isSmall) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _slate200),
            boxShadow: const [
              BoxShadow(color: Color(0x08000000), blurRadius: 4, offset: Offset(0, 2)),
            ],
          ),
          child: Image.asset(
            'assets/images/emblem_gold.png',
            height: isSmall ? 28 : 34,
            width: isSmall ? 28 : 34,
            errorBuilder: (_, __, ___) => Icon(
              Icons.account_balance_rounded,
              size: isSmall ? 24 : 30,
              color: _govNavy,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'PDS DemandSync',
                style: TextStyle(
                  fontSize: isSmall ? 16 : 18,
                  fontWeight: FontWeight.w800,
                  color: _govNavy,
                  letterSpacing: -0.3,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                tr('login.dept_title'),
                style: TextStyle(
                  fontSize: isSmall ? 10 : 11.5,
                  fontWeight: FontWeight.w500,
                  color: _slate500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ================================================================
  // MAIN CARD CONTAINER (Mobile Responsive)
  // ================================================================
  Widget _buildCard(bool isSmall) {
    return Container(
      padding: EdgeInsets.all(isSmall ? 16 : 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _slate200),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A0F172A),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr('login.welcome_back'),
                      style: TextStyle(
                        fontSize: isSmall ? 19 : 22,
                        fontWeight: FontWeight.w800,
                        color: _slate900,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tr('login.subtitle'),
                      style: TextStyle(
                        fontSize: isSmall ? 11.5 : 13,
                        color: _slate500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Row(
                children: [
                  Container(width: 8, height: 4, decoration: BoxDecoration(color: _saffron, borderRadius: BorderRadius.circular(2))),
                  const SizedBox(width: 2),
                  Container(width: 8, height: 4, decoration: BoxDecoration(color: _slate200, borderRadius: BorderRadius.circular(2))),
                  const SizedBox(width: 2),
                  Container(width: 8, height: 4, decoration: BoxDecoration(color: _govGreenLight, borderRadius: BorderRadius.circular(2))),
                ],
              ),
            ],
          ),

          SizedBox(height: isSmall ? 16 : 20),

          // 2-Tab Segment Selector (Citizen OTP & Department)
          Container(
            padding: const EdgeInsets.all(3.5),
            decoration: BoxDecoration(
              color: _slate100,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                _buildSegmentTab(0, Icons.phone_android_rounded, tr('login.tab_citizen_otp'), _govGreen, isSmall),
                _buildSegmentTab(1, Icons.badge_outlined, tr('login.tab_dept_official'), _govNavy, isSmall),
              ],
            ),
          ),

          SizedBox(height: isSmall ? 16 : 20),

          // Tab Content
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: _selectedTabIndex == null
                ? _buildInitialRoleSelectionView(isSmall)
                : _selectedTabIndex == 0
                    ? _buildCitizenOtpTab(isSmall)
                    : _buildDepartmentLoginTab(isSmall),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentTab(int index, IconData icon, String label, Color activeColor, bool isSmall) {
    final isSelected = _selectedTabIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () => _handleTabSelection(index),
        borderRadius: BorderRadius.circular(7),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: EdgeInsets.symmetric(vertical: isSmall ? 7 : 8),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
            boxShadow: isSelected
                ? const [BoxShadow(color: Color(0x0D000000), blurRadius: 4, offset: Offset(0, 2))]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: isSmall ? 12 : 14,
                color: isSelected ? activeColor : _slate500,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: isSmall ? 10.5 : 12,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? activeColor : _slate500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ================================================================
  // INITIAL ROLE SELECTION VIEW (Zero Voice Assistant, Zero Mic)
  // ================================================================
  Widget _buildInitialRoleSelectionView(bool isSmall) {
    return Column(
      key: const ValueKey('initial_portal_selection'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          tr('login.select_portal_title'),
          style: TextStyle(fontSize: isSmall ? 13 : 14, fontWeight: FontWeight.w800, color: _slate900),
        ),
        const SizedBox(height: 3),
        Text(
          tr('login.select_portal_sub'),
          style: TextStyle(fontSize: isSmall ? 11 : 12, color: _slate500),
        ),
        const SizedBox(height: 14),

        // Option 1: Citizen OTP / Beneficiary
        InkWell(
          onTap: () => _handleTabSelection(0),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: EdgeInsets.all(isSmall ? 12 : 14),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF86EFAC), width: 1.5),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0815803D),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: isSmall ? 40 : 46,
                  height: isSmall ? 40 : 46,
                  decoration: const BoxDecoration(
                    color: Color(0xFFDCFCE7),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.phone_android_rounded,
                    color: Color(0xFF15803D),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr('login.citizen_card_title'),
                        style: TextStyle(
                          fontSize: isSmall ? 13 : 14,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF166534),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        tr('login.citizen_card_desc'),
                        style: TextStyle(
                          fontSize: isSmall ? 10.5 : 11.5,
                          color: const Color(0xFF15803D),
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            tr('login.citizen_card_btn'),
                            style: TextStyle(
                              fontSize: isSmall ? 11.5 : 12.5,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF15803D),
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.arrow_forward_rounded,
                            size: 14,
                            color: Color(0xFF15803D),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Option 2: Department Official
        InkWell(
          onTap: () => _handleTabSelection(1),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: EdgeInsets.all(isSmall ? 12 : 14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _slate200, width: 1.2),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x060F172A),
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: isSmall ? 40 : 46,
                  height: isSmall ? 40 : 46,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE2E8F0),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.badge_outlined,
                    color: Color(0xFF0F2942),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr('login.official_card_title'),
                        style: TextStyle(
                          fontSize: isSmall ? 13 : 14,
                          fontWeight: FontWeight.w800,
                          color: _govNavy,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        tr('login.official_card_desc'),
                        style: TextStyle(
                          fontSize: isSmall ? 10.5 : 11.5,
                          color: _slate700,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            tr('login.official_card_btn'),
                            style: TextStyle(
                              fontSize: isSmall ? 11.5 : 12.5,
                              fontWeight: FontWeight.w800,
                              color: _govNavy,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.arrow_forward_rounded,
                            size: 14,
                            color: Color(0xFF0F2942),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ================================================================
  // CITIZEN OTP TAB (Mobile Responsive with Voice Guidance)
  // ================================================================
  Widget _buildCitizenOtpTab(bool isSmall) {
    return Column(
      key: const ValueKey('citizen_otp'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Voice Assistant Banner (Available ONLY for Citizen OTP Flow - Tap to Speak removed on login)
        const VoiceAssistantBanner(showTapToSpeak: false),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                tr('login.citizen_portal_credentials'),
                style: TextStyle(fontSize: isSmall ? 12 : 13, fontWeight: FontWeight.w700, color: _slate900),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: _govGreenBg,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: _govGreenBorder),
              ),
              child: Text(
                tr('login.three_factor_auth'),
                style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.w800, color: _govGreen),
              ),
            ),
          ],
        ),
        // Anti-Fraud & Dataset Verification Banner
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFBFDBFE)),
          ),
          child: const Row(
            children: [
              Icon(Icons.shield_outlined, size: 18, color: Color(0xFF1D4ED8)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Anti-Fraud Enforcement Active: Ration Card Number and Registered Mobile Number are cross-verified against official records.',
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFF1E40AF), height: 1.3),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Field 1: Ration Card Number
        Text(tr('login.ration_num_label'), style: TextStyle(fontSize: isSmall ? 11 : 11.5, fontWeight: FontWeight.w600, color: _slate700)),
        const SizedBox(height: 4),
        TextField(
          controller: _citizenCardController,
          style: TextStyle(fontSize: isSmall ? 13 : 14, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: 'e.g. RC-KA-000001',
            prefixIcon: Icon(Icons.credit_card_rounded, size: isSmall ? 16 : 18, color: _slate500),
            suffixIcon: IconButton(
              icon: const Icon(Icons.mic_rounded, color: Color(0xFF15803D), size: 20),
              tooltip: 'Speak Ration Card Number',
              onPressed: _listenForRationCard,
            ),
            filled: true,
            fillColor: _slate50,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _slate200)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _slate200)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _govGreen, width: 1.5)),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: isSmall ? 8 : 10),
          ),
        ),

        const SizedBox(height: 12),

        // Field 2: Registered Mobile / Phone Number
        Text(tr('login.phone_num_label'), style: TextStyle(fontSize: isSmall ? 11 : 11.5, fontWeight: FontWeight.w600, color: _slate700)),
        const SizedBox(height: 4),
        TextField(
          controller: _citizenPhoneController,
          keyboardType: TextInputType.phone,
          style: TextStyle(fontSize: isSmall ? 13 : 14, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: 'e.g. +91 98450 12345 or 9845012345',
            prefixIcon: Icon(Icons.phone_android_rounded, size: isSmall ? 16 : 18, color: _slate500),
            suffixIcon: IconButton(
              icon: const Icon(Icons.mic_rounded, color: Color(0xFF15803D), size: 20),
              tooltip: 'Speak Registered Mobile Number',
              onPressed: _listenForPhone,
            ),
            filled: true,
            fillColor: _slate50,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _slate200)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _slate200)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _govGreen, width: 1.5)),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: isSmall ? 8 : 10),
          ),
        ),

        const SizedBox(height: 14),

        if (!_otpSent)
          ElevatedButton(
            onPressed: _isSendingOtp ? null : _handleSendOtp,
            style: ElevatedButton.styleFrom(
              backgroundColor: _govNavy,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 44),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: _isSendingOtp
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text(tr('login.get_otp_sms'), style: TextStyle(fontSize: isSmall ? 13 : 14, fontWeight: FontWeight.w700)),
          )
        else ...[
          // OTP Received Input Section
          Container(
            padding: EdgeInsets.all(isSmall ? 10 : 14),
            decoration: BoxDecoration(
              color: _govGreenBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _govGreenBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.sms_outlined, size: isSmall ? 13 : 14, color: _govGreen),
                        const SizedBox(width: 4),
                        Text(
                          tr('login.enter_sms_code'),
                          style: TextStyle(fontSize: isSmall ? 11 : 12, fontWeight: FontWeight.w700, color: _govGreen),
                        ),
                      ],
                    ),
                    Text(
                      _formatTimer(_otpCountdownSeconds),
                      style: TextStyle(fontSize: isSmall ? 11 : 11.5, fontWeight: FontWeight.w700, color: _govGreen),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                TextField(
                  controller: _citizenOtpController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: isSmall ? 18 : 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 8,
                    color: _slate900,
                  ),
                  decoration: InputDecoration(
                    hintText: '••••••',
                    counterText: '',
                    hintStyle: const TextStyle(letterSpacing: 8, color: _slate400),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.mic_rounded, color: Color(0xFF15803D), size: 20),
                      tooltip: 'Speak OTP Digits',
                      onPressed: _listenForOtp,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _slate200)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _govGreenBorder)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _govGreen, width: 2)),
                    contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                  ),
                ),

                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      tr('login.sms_dispatched'),
                      style: TextStyle(fontSize: isSmall ? 9.5 : 10.5, color: _slate500),
                    ),
                    InkWell(
                      onTap: _isSendingOtp ? null : _handleSendOtp,
                      child: Text(
                        tr('login.resend_otp'),
                        style: TextStyle(fontSize: isSmall ? 10 : 11, fontWeight: FontWeight.w700, color: _govNavy),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          ElevatedButton(
            onPressed: _isVerifyingOtp ? null : _handleVerifyOtpAndLogin,
            style: ElevatedButton.styleFrom(
              backgroundColor: _govGreen,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 44),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: _isVerifyingOtp
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle_rounded, size: isSmall ? 15 : 16),
                      const SizedBox(width: 6),
                      Text(tr('login.verify_login_btn'), style: TextStyle(fontSize: isSmall ? 13 : 14, fontWeight: FontWeight.w700)),
                    ],
                  ),
          ),
        ],
      ],
    );
  }

  String _selectedOfficialRole = 'DSO';

  Widget _buildRoleCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Color bgColor,
    required Color borderColor,
    required String username,
    required String password,
    required String role,
    required bool isSmall,
  }) {
    final isSelected = _selectedOfficialRole == role || _adminUsernameController.text.trim() == username;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedOfficialRole = role;
          _adminUsernameController.text = username;
          _adminPasswordController.text = password;
        });
      },
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? bgColor : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? color : _slate200,
            width: isSelected ? 1.8 : 1,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: color.withValues(alpha: 0.12), blurRadius: 4, offset: const Offset(0, 2))]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Icon(icon, size: isSmall ? 14 : 15, color: color),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(fontSize: isSmall ? 10.5 : 11.5, fontWeight: FontWeight.w800, color: color),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isSelected)
                  Icon(Icons.check_circle_rounded, size: 12, color: color),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(fontSize: isSmall ? 8.5 : 9.5, fontWeight: FontWeight.w600, color: _slate500, height: 1.2),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // ================================================================
  // DEPARTMENT LOGIN TAB (Responsive)
  // ================================================================
  Widget _buildDepartmentLoginTab(bool isSmall) {
    return Column(
      key: const ValueKey('dept_login'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 4 Specialized Official Role Window Cards
        Text(
          'Select Official Role Window:',
          style: TextStyle(fontSize: isSmall ? 11 : 12, fontWeight: FontWeight.w800, color: _slate900),
        ),
        const SizedBox(height: 8),
        GridView.count(
          crossAxisCount: isSmall ? 2 : 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: isSmall ? 2.5 : 2.8,
          children: [
            _buildRoleCard(
              title: '🏛️ DSO (Command)',
              subtitle: 'Planning & Decision Authority',
              icon: Icons.account_balance_outlined,
              color: const Color(0xFF166534),
              bgColor: const Color(0xFFF0FDF4),
              borderColor: const Color(0xFF86EFAC),
              username: 'dso_user',
              password: 'dso_pass',
              role: 'DSO',
              isSmall: isSmall,
            ),
            _buildRoleCard(
              title: '🔍 Field Food Inspector',
              subtitle: 'Physical Inspection & Checklist',
              icon: Icons.assignment_turned_in_outlined,
              color: const Color(0xFF92400E),
              bgColor: const Color(0xFFFFFBEB),
              borderColor: const Color(0xFFFDE68A),
              username: 'inspector_user',
              password: 'inspector_pass',
              role: 'FIELD_FOOD_INSPECTOR',
              isSmall: isSmall,
            ),
            _buildRoleCard(
              title: '🏪 FPS Officer',
              subtitle: 'Current Stock, Register & e-PoS',
              icon: Icons.storefront_outlined,
              color: const Color(0xFF0F766E),
              bgColor: const Color(0xFFF0FDFA),
              borderColor: const Color(0xFF99F6E4),
              username: 'fps_user',
              password: 'fps_pass',
              role: 'FPS_OWNER',
              isSmall: isSmall,
            ),
            _buildRoleCard(
              title: '🛡️ Vigilance Auditor',
              subtitle: 'Audit Ledger & Compliance Trail',
              icon: Icons.verified_user_outlined,
              color: const Color(0xFF6B21A8),
              bgColor: const Color(0xFFF3E8FF),
              borderColor: const Color(0xFFE9D5FF),
              username: 'auditor_user',
              password: 'auditor_pass',
              role: 'AUDITOR',
              isSmall: isSmall,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          tr('login.official_user_label'),
          style: TextStyle(fontSize: isSmall ? 11 : 12, fontWeight: FontWeight.w700, color: _slate900),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: _adminUsernameController,
          style: TextStyle(fontSize: isSmall ? 13 : 14, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: tr('login.official_user_hint'),
            prefixIcon: Icon(Icons.person_outline_rounded, size: isSmall ? 16 : 18, color: _slate500),
            filled: true,
            fillColor: _slate50,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _slate200)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _slate200)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _govNavy, width: 1.5)),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: isSmall ? 8 : 10),
          ),
        ),
        SizedBox(height: isSmall ? 8 : 10),

        Text(
          tr('login.password_label'),
          style: TextStyle(fontSize: isSmall ? 11 : 12, fontWeight: FontWeight.w700, color: _slate900),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: _adminPasswordController,
          obscureText: _isPasswordObscured,
          style: TextStyle(fontSize: isSmall ? 13 : 14, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: '••••••••',
            prefixIcon: Icon(Icons.lock_outline_rounded, size: isSmall ? 16 : 18, color: _slate500),
            suffixIcon: IconButton(
              icon: Icon(_isPasswordObscured ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: isSmall ? 16 : 18, color: _slate500),
              onPressed: () => setState(() => _isPasswordObscured = !_isPasswordObscured),
            ),
            filled: true,
            fillColor: _slate50,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _slate200)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _slate200)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _govNavy, width: 1.5)),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: isSmall ? 8 : 10),
          ),
        ),

        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: _slate100,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _slate200),
          ),
          child: Row(
            children: [
              Icon(Icons.shield_outlined, size: isSmall ? 14 : 16, color: _govNavy),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  tr('login.official_creds_hint'),
                  style: TextStyle(fontSize: isSmall ? 10 : 11, color: _slate700, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),

        SizedBox(height: isSmall ? 12 : 14),

        ElevatedButton(
          onPressed: _isAdminLoggingIn ? null : _handleDepartmentLogin,
          style: ElevatedButton.styleFrom(
            backgroundColor: _govNavy,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 44),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            elevation: 0,
          ),
          child: _isAdminLoggingIn
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text('Sign In to ${_selectedOfficialRole.replaceAll('_', ' ')} Workspace', style: TextStyle(fontSize: isSmall ? 13 : 14, fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }

  // ================================================================
  // OFFICIAL GOVERNMENT FOOTER (Responsive)
  // ================================================================
  Widget _buildFooter(bool isSmall) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.shield_outlined, size: 14, color: _govNavy),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                'National Food Security Portal • Govt. of Karnataka & India',
                style: TextStyle(fontSize: isSmall ? 10 : 11, color: _slate700, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          tr('login.footer_disclaimer'),
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: isSmall ? 9.5 : 10.5, color: _slate400),
        ),
      ],
    );
  }
}

/// Interactive Voice Listening Sheet providing instant audio & visual waveform feedback
class _VoiceInputListeningSheet extends StatefulWidget {
  final String title;
  final String prompt;
  final String fieldType; // 'card', 'phone', 'otp'
  final void Function(String result) onApply;

  const _VoiceInputListeningSheet({
    required this.title,
    required this.prompt,
    required this.fieldType,
    required this.onApply,
  });

  @override
  State<_VoiceInputListeningSheet> createState() => _VoiceInputListeningSheetState();
}

class _VoiceInputListeningSheetState extends State<_VoiceInputListeningSheet> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  String _liveTranscript = '';
  String _formattedPreview = '';

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    VoiceAssistantService.instance.addListener(_onVoiceServiceUpdate);
    _startRecording();
  }

  @override
  void dispose() {
    VoiceAssistantService.instance.removeListener(_onVoiceServiceUpdate);
    _animController.dispose();
    super.dispose();
  }

  void _onVoiceServiceUpdate() {
    if (!mounted) return;
    final text = VoiceAssistantService.instance.recognizedSpeech;
    if (text != _liveTranscript && text.isNotEmpty) {
      setState(() {
        _liveTranscript = text;
        _formattedPreview = _formatResult(text);
      });
    }
  }

  String _formatResult(String raw) {
    if (raw.trim().isEmpty) return '';
    if (widget.fieldType == 'card') {
      final digits = VoiceAssistantService.normalizeSpokenDigits(raw).replaceAll(RegExp(r'[^0-9]'), '');
      if (digits.isNotEmpty) {
        return 'RC-KA-${digits.padLeft(6, '0')}';
      }
      return raw.trim().toUpperCase().replaceAll(' ', '-');
    } else if (widget.fieldType == 'phone') {
      final phone = VoiceAssistantService.extractPhoneNumber(raw);
      if (phone.isNotEmpty) return phone;
      final digits = VoiceAssistantService.normalizeSpokenDigits(raw).replaceAll(RegExp(r'[^0-9]'), '');
      return digits.length > 10 ? digits.substring(digits.length - 10) : digits;
    } else if (widget.fieldType == 'otp') {
      final digits = VoiceAssistantService.normalizeSpokenDigits(raw).replaceAll(RegExp(r'[^0-9]'), '');
      return digits.length > 6 ? digits.substring(0, 6) : digits;
    }
    return raw.trim();
  }

  void _startRecording() {
    setState(() {
      _liveTranscript = '';
      _formattedPreview = '';
    });
    VoiceAssistantService.instance.startListening(
      onFinalResult: (transcript) {
        if (!mounted) return;
        final formatted = _formatResult(transcript);
        setState(() {
          _liveTranscript = transcript;
          _formattedPreview = formatted;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final voice = VoiceAssistantService.instance;
    final isListening = voice.isListening;
    final isKn = LanguageController.instance.currentLanguage == AppLanguage.kannada;
    final isHi = LanguageController.instance.currentLanguage == AppLanguage.hindi;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top grab handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 16),

            // Header Title
            Text(
              widget.title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F2942)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              widget.prompt,
              style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),

            // Animated Mic Button
            AnimatedBuilder(
              animation: _animController,
              builder: (context, child) {
                final scale = isListening ? (1.0 + _animController.value * 0.15) : 1.0;
                return Transform.scale(
                  scale: scale,
                  child: GestureDetector(
                    onTap: _startRecording,
                    child: Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isListening ? const Color(0xFF15803D) : const Color(0xFF0F2942),
                        boxShadow: [
                          BoxShadow(
                            color: isListening ? const Color(0x6615803D) : Colors.black12,
                            blurRadius: isListening ? (12 + _animController.value * 10) : 6,
                            spreadRadius: isListening ? (_animController.value * 6) : 0,
                          ),
                        ],
                      ),
                      child: Icon(
                        isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
                        color: Colors.white,
                        size: 38,
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),

            // Listening status
            Text(
              isListening
                  ? (isKn ? '🎙️ ಕೇಳಿಸಿಕೊಳ್ಳಲಾಗುತ್ತಿದೆ... ಮಾತನಾಡಿ' : isHi ? '🎙️ सुन रहे हैं... बोलिए' : '🎙️ Listening... Speak now')
                  : (isKn ? 'ಧ್ವನಿ ದಾಖಲಿಸಲು ಮೈಕ್ ಒತ್ತಿ' : isHi ? 'माइक पर टैप करके बोलें' : 'Tap mic to speak'),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isListening ? const Color(0xFF15803D) : Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 16),

            // Live Speech / Formatted Result Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _formattedPreview.isNotEmpty ? const Color(0xFF86EFAC) : const Color(0xFFE2E8F0),
                  width: _formattedPreview.isNotEmpty ? 1.5 : 1.0,
                ),
              ),
              child: Column(
                children: [
                  Text(
                    _formattedPreview.isNotEmpty ? _formattedPreview : (_liveTranscript.isNotEmpty ? _liveTranscript : (isKn ? '...' : isHi ? '...' : '...')),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: widget.fieldType == 'otp' ? 6 : 1,
                      color: _formattedPreview.isNotEmpty ? const Color(0xFF0F2942) : Colors.grey.shade400,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (_liveTranscript.isNotEmpty && _formattedPreview.isNotEmpty && _liveTranscript != _formattedPreview) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Spoken: "$_liveTranscript"',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      side: BorderSide(color: Colors.grey.shade300),
                    ),
                    child: Text(
                      isKn ? 'ರದ್ದುಮಾಡಿ' : isHi ? 'रद्द करें' : 'Cancel',
                      style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _formattedPreview.isNotEmpty
                        ? () => widget.onApply(_formattedPreview)
                        : (_liveTranscript.isNotEmpty ? () => widget.onApply(_liveTranscript) : null),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF15803D),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.check_rounded, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          isKn ? 'ಅನ್ವಯಿಸಿ' : isHi ? 'लागू करें' : 'Apply & Fill',
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}


