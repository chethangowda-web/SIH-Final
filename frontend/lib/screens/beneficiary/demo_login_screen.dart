import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/localization.dart';
import '../../services/api_service.dart';
import '../../services/voice_assistant_service.dart';
import 'beneficiary_home_screen.dart';
import '../admin/admin_dashboard_screen.dart';
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

  // Household member phone options
  List<Map<String, dynamic>> _householdPhones = [];
  bool _isLoadingHousehold = false;
  String? _selectedMemberName;
  Timer? _cardDebounceTimer;

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
    _citizenCardController.addListener(_onCardIdChanged);

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

  void _onCardIdChanged() {
    _cardDebounceTimer?.cancel();
    final cardId = _citizenCardController.text.trim();
    if (cardId.length >= 3) {
      _cardDebounceTimer = Timer(const Duration(milliseconds: 350), () {
        if (mounted) _fetchHouseholdMembers(cardId);
      });
    } else if (cardId.isEmpty && _householdPhones.isNotEmpty) {
      setState(() {
        _householdPhones = [];
        _selectedMemberName = null;
      });
    }
  }

  Future<void> _fetchHouseholdMembers(String cardId) async {
    final cleanId = cardId.trim();
    if (cleanId.isEmpty) return;
    setState(() => _isLoadingHousehold = true);
    try {
      final res = await _apiService.fetchHouseholdPhones(cleanId);
      if (!mounted) return;
      final rawList = res['household_phones'] as List<dynamic>? ?? [];
      final List<Map<String, dynamic>> phones = rawList.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      setState(() {
        _householdPhones = phones;
        // If phone controller is empty and members exist, prefill with head/first member
        if (_citizenPhoneController.text.trim().isEmpty && phones.isNotEmpty) {
          final first = phones.first;
          final demoPhone = (first['demo_phone'] ?? '').toString();
          final cleanPhone = demoPhone.replaceAll('+91', '').replaceAll(' ', '');
          final last4 = (first['phone_last4'] ?? '').toString();
          _citizenPhoneController.text = cleanPhone.isNotEmpty
              ? cleanPhone
              : (last4.isNotEmpty ? '98450${last4.padLeft(5, '0')}' : '');
          _selectedMemberName = first['name']?.toString();
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() => _householdPhones = []);
      }
    } finally {
      if (mounted) setState(() => _isLoadingHousehold = false);
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
    _cardDebounceTimer?.cancel();
    _citizenOtpController.removeListener(_onOtpChanged);
    _citizenCardController.removeListener(_onCardIdChanged);
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

  void _listenForRationCard() {
    final voice = VoiceAssistantService.instance;
    voice.startListening(onFinalResult: (transcript) {
      if (!mounted) return;
      final digits = VoiceAssistantService.normalizeSpokenDigits(transcript).replaceAll(RegExp(r'[^0-9]'), '');
      if (digits.isNotEmpty) {
        setState(() {
          _citizenCardController.text = 'RC-KA-${digits.padLeft(6, '0')}';
        });
        voice.guideLoginStepPhone();
      } else if (transcript.trim().isNotEmpty) {
        setState(() {
          _citizenCardController.text = transcript.trim().toUpperCase().replaceAll(' ', '-');
        });
        voice.guideLoginStepPhone();
      }
    });
  }

  void _listenForPhone() {
    final voice = VoiceAssistantService.instance;
    voice.startListening(onFinalResult: (transcript) {
      if (!mounted) return;
      final phone = VoiceAssistantService.extractPhoneNumber(transcript);
      if (phone.isNotEmpty) {
        setState(() {
          _citizenPhoneController.text = phone;
        });
      }
    });
  }

  void _listenForOtp() {
    final voice = VoiceAssistantService.instance;
    voice.startListening(onFinalResult: (transcript) {
      if (!mounted) return;
      final digits = VoiceAssistantService.normalizeSpokenDigits(transcript).replaceAll(RegExp(r'[^0-9]'), '');
      if (digits.isNotEmpty) {
        setState(() {
          _citizenOtpController.text = digits.length > 6 ? digits.substring(0, 6) : digits;
        });
        voice.guideLoginStepOtpEntered();
      }
    });
  }

  // Action: Send Real OTP to Citizen via Twilio SMS
  Future<void> _handleSendOtp() async {
    final cardId = _citizenCardController.text.trim();
    final phoneNumber = _citizenPhoneController.text.trim();

    if (cardId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('login.enter_ration_card'))),
      );
      return;
    }

    setState(() => _isSendingOtp = true);
    try {
      final res = await _apiService.sendCitizenOtp(cardId, phoneNumber: phoneNumber.isNotEmpty ? phoneNumber : null);
      if (!mounted) return;

      setState(() {
        _otpSent = true;
      });
      _startOtpTimer();

      final mode = res['mode'] ?? 'DEMO';
      final phone = res['masked_phone'] ?? res['phone'] ?? '+91 98450*****';
      final mockOtp = (res['mock_otp'] ?? res['demo_otp_code'] ?? res['otp'] ?? '123456').toString();

      String displayText;
      if (mode == 'TWILIO_LIVE' || mode == 'LIVE') {
        displayText = 'SMS OTP sent to $phone. (Demo test code: $mockOtp)';
      } else {
        displayText = 'Demo Mode: OTP sent to $phone (Test code: $mockOtp)';
      }
      _citizenOtpController.text = mockOtp;

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

  // Action: Verify OTP & Login
  Future<void> _handleVerifyOtpAndLogin() async {
    final cardId = _citizenCardController.text.trim();
    final otp = _citizenOtpController.text.trim();
    if (otp.isEmpty || otp.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('login.enter_valid_otp'))),
      );
      return;
    }

    setState(() => _isVerifyingOtp = true);
    try {
      await _apiService.verifyCitizenOtp(cardId, otp);
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
      if (role == 'FIELD_FOOD_INSPECTOR' || role == 'FIELD_OFFICER' || uName == 'inspector_user' || uName == 'field_officer_user' || uName.startsWith('INSP-')) {
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
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
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
          ),
        ),
        const SizedBox(width: 8),
        // Language Toggle inside Login Screen Header
        const LanguageSelectorWidget(isCompact: true, isLight: true),
      ],
    );
  }

  void _selectBeneficiary(String cardId, [String? memberName]) {
    setState(() {
      _citizenCardController.text = cardId;
      _citizenPhoneController.clear();
      _selectedMemberName = memberName;
    });
    _fetchHouseholdMembers(cardId);
    if (_selectedTabIndex == 0 && VoiceAssistantService.instance.isVoiceAssistantMode) {
      VoiceAssistantService.instance.guideLoginStepPhone();
    }
  }

  void _showBeneficiarySearchDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _BeneficiarySearchModal(
        apiService: _apiService,
        onSelect: (cardId, name) {
          _selectBeneficiary(cardId, name);
        },
      ),
    );
  }

  Widget _buildQuickSelectChip({
    required String cardId,
    required String name,
    required String scheme,
    required String district,
  }) {
    final currentCard = _citizenCardController.text.trim();
    final isSelected = currentCard == cardId;
    final isAay = scheme == 'AAY';

    return InkWell(
      onTap: () => _selectBeneficiary(cardId, name),
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF0FDF4) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? const Color(0xFF15803D) : _slate200,
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? const [BoxShadow(color: Color(0x1F15803D), blurRadius: 4, offset: Offset(0, 2))]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: isAay ? const Color(0xFFFEF3C7) : const Color(0xFFDBEAFE),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                scheme,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: isAay ? const Color(0xFFB45309) : const Color(0xFF1D4ED8),
                ),
              ),
            ),
            const SizedBox(width: 5),
            Text(
              name,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected ? const Color(0xFF15803D) : _slate900,
              ),
            ),
            const SizedBox(width: 3),
            Text(
              '($district)',
              style: const TextStyle(
                fontSize: 9.5,
                color: _slate500,
              ),
            ),
          ],
        ),
      ),
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

        // Beneficiary Fast Selector & Directory Search
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    LanguageController.instance.currentLanguage == AppLanguage.hindi
                        ? 'त्वरित लाभार्थी चयन:'
                        : LanguageController.instance.currentLanguage == AppLanguage.kannada
                            ? 'ತ್ವರಿತ ಫಲಾನುಭವಿ ಆಯ್ಕೆ:'
                            : 'Quick Beneficiary Selection:',
                    style: TextStyle(
                      fontSize: isSmall ? 10.5 : 11,
                      fontWeight: FontWeight.w700,
                      color: _slate700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: _showBeneficiarySearchDialog,
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.search_rounded, size: 14, color: _govGreen),
                        const SizedBox(width: 4),
                        Text(
                          LanguageController.instance.currentLanguage == AppLanguage.hindi
                              ? '10,000+ कार्ड खोजें'
                              : LanguageController.instance.currentLanguage == AppLanguage.kannada
                                  ? '10,000+ ಕಾರ್ಡ್ ಹುಡುಕಿ'
                                  : 'Search 10,000+ Cards',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: _govGreen,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildQuickSelectChip(
                    cardId: 'RC-KA-000001',
                    name: 'Deepa Reddy',
                    scheme: 'PHH',
                    district: 'Bagalkot',
                  ),
                  const SizedBox(width: 6),
                  _buildQuickSelectChip(
                    cardId: 'RC-KA-000002',
                    name: 'Swathi Joshi',
                    scheme: 'PHH',
                    district: 'Bagalkot',
                  ),
                  const SizedBox(width: 6),
                  _buildQuickSelectChip(
                    cardId: 'RC-KA-000005',
                    name: 'Manoj Sharma',
                    scheme: 'AAY',
                    district: 'Bagalkot',
                  ),
                  const SizedBox(width: 6),
                  _buildQuickSelectChip(
                    cardId: 'BEN-KA-0002',
                    name: 'Suresh S.',
                    scheme: 'PHH',
                    district: 'Bengaluru',
                  ),
                  const SizedBox(width: 6),
                  _buildQuickSelectChip(
                    cardId: 'BEN-KA-0010',
                    name: 'Vijay Kulkarni',
                    scheme: 'AAY',
                    district: 'Belagavi',
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Field 1: Ration Card Number
        Text(tr('login.ration_num_label'), style: TextStyle(fontSize: isSmall ? 11 : 11.5, fontWeight: FontWeight.w600, color: _slate700)),
        const SizedBox(height: 4),
        TextField(
          controller: _citizenCardController,
          style: TextStyle(fontSize: isSmall ? 13 : 14, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: 'e.g. RC-KA-000001 or Beneficiary Name',
            prefixIcon: Icon(Icons.credit_card_rounded, size: isSmall ? 16 : 18, color: _slate500),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.search_rounded, color: _slate500, size: 20),
                  tooltip: 'Search Beneficiary Directory',
                  onPressed: _showBeneficiarySearchDialog,
                ),
                IconButton(
                  icon: const Icon(Icons.mic_rounded, color: Color(0xFF15803D), size: 20),
                  tooltip: 'Speak Ration Card Number',
                  onPressed: _listenForRationCard,
                ),
              ],
            ),
            filled: true,
            fillColor: _slate50,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _slate200)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _slate200)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _govGreen, width: 1.5)),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: isSmall ? 8 : 10),
          ),
        ),

        // Household Members Loading indicator
        if (_isLoadingHousehold)
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Row(
              children: [
                const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.5, color: _govGreen)),
                const SizedBox(width: 8),
                Text(
                  LanguageController.instance.currentLanguage == AppLanguage.hindi
                      ? 'परिवार के पंजीकृत मोबाइल खोज रहे हैं...'
                      : LanguageController.instance.currentLanguage == AppLanguage.kannada
                          ? 'ಕುಟುಂಬದ ನೋಂದಾಯಿತ ಮೊಬೈಲ್ ಹುಡುಕಲಾಗುತ್ತಿದೆ...'
                          : 'Loading registered family members...',
                  style: const TextStyle(fontSize: 10.5, color: _slate500, fontStyle: FontStyle.italic),
                ),
              ],
            ),
          )
        else if (_householdPhones.isNotEmpty) ...[
          const SizedBox(height: 10),
          _buildHouseholdMemberPhoneSelector(isSmall),
        ],

        const SizedBox(height: 10),

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

  Widget _buildHouseholdMemberPhoneSelector(bool isSmall) {
    return Container(
      padding: EdgeInsets.all(isSmall ? 8 : 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF86EFAC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.people_alt_rounded, size: 14, color: Color(0xFF15803D)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _selectedMemberName != null && _selectedMemberName!.isNotEmpty
                      ? (LanguageController.instance.currentLanguage == AppLanguage.hindi
                          ? 'पंजीकृत परिवार का मोबाइल: $_selectedMemberName'
                          : LanguageController.instance.currentLanguage == AppLanguage.kannada
                              ? 'ಕುಟುಂಬದ ಮೊಬೈಲ್: $_selectedMemberName'
                              : 'Family Member: $_selectedMemberName')
                      : (LanguageController.instance.currentLanguage == AppLanguage.hindi
                          ? 'पंजीकृत परिवार के सदस्य का मोबाइल चुनें:'
                          : LanguageController.instance.currentLanguage == AppLanguage.kannada
                              ? 'ನೋಂದಾಯಿತ ಕುಟುಂಬ ಸದಸ್ಯರ ಮೊಬೈಲ್ ಆಯ್ಕೆಮಾಡಿ:'
                              : 'Select registered family mobile number:'),
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF166534)),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _householdPhones.map((m) {
              final name = m['name']?.toString() ?? 'Member';
              final masked = m['masked_phone']?.toString() ?? '';
              final demoPhone = m['demo_phone']?.toString() ?? '';
              final phoneLast4 = m['phone_last4']?.toString() ?? '';
              final isHead = m['is_head'] == true;
              final currentVal = _citizenPhoneController.text.trim();
              final cleanDemo = demoPhone.replaceAll('+91', '').replaceAll(' ', '');
              final isSelected = (currentVal.isNotEmpty &&
                  (currentVal == demoPhone ||
                      currentVal == cleanDemo ||
                      (phoneLast4.isNotEmpty && currentVal.endsWith(phoneLast4)) ||
                      (masked.isNotEmpty && currentVal.endsWith(masked.replaceAll('*', '')))));

              return InkWell(
                onTap: () {
                  setState(() {
                    if (demoPhone.isNotEmpty) {
                      _citizenPhoneController.text = cleanDemo;
                    } else if (phoneLast4.isNotEmpty) {
                      _citizenPhoneController.text = '98450${phoneLast4.padLeft(5, '0')}';
                    }
                    _selectedMemberName = name;
                  });
                },
                borderRadius: BorderRadius.circular(8),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF15803D) : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected ? const Color(0xFF15803D) : const Color(0xFFBBF7D0),
                      width: isSelected ? 1.5 : 1,
                    ),
                    boxShadow: isSelected
                        ? const [BoxShadow(color: Color(0x1F15803D), blurRadius: 4, offset: Offset(0, 2))]
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isSelected ? Icons.check_circle_rounded : (isHead ? Icons.star_rounded : Icons.person_rounded),
                        size: 13,
                        color: isSelected ? Colors.white : (isHead ? const Color(0xFFD97706) : const Color(0xFF15803D)),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '$name ($masked)',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                          color: isSelected ? Colors.white : const Color(0xFF0F2942),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
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

class _BeneficiarySearchModal extends StatefulWidget {
  final ApiService apiService;
  final void Function(String cardId, String? name) onSelect;

  const _BeneficiarySearchModal({
    required this.apiService,
    required this.onSelect,
  });

  @override
  State<_BeneficiarySearchModal> createState() => _BeneficiarySearchModalState();
}

class _BeneficiarySearchModalState extends State<_BeneficiarySearchModal> {
  final TextEditingController _queryController = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  bool _isLoading = false;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _performSearch('');
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _queryController.dispose();
    super.dispose();
  }

  void _onQueryChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 250), () {
      _performSearch(query);
    });
  }

  Future<void> _performSearch(String query) async {
    setState(() => _isLoading = true);
    try {
      final res = await widget.apiService.searchBeneficiaries(query, limit: 25);
      if (mounted) {
        setState(() {
          _results = res;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    return Container(
      height: mediaQuery.size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 4),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              children: [
                const Icon(Icons.people_alt_rounded, color: Color(0xFF15803D), size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        LanguageController.instance.currentLanguage == AppLanguage.hindi
                            ? 'लाभार्थी खोज निर्देशिका'
                            : LanguageController.instance.currentLanguage == AppLanguage.kannada
                                ? 'ಫಲಾನುಭವಿಗಳ ಹುಡುಕಾಟ ಕೋಶ'
                                : 'Beneficiary Directory Search',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F2942)),
                      ),
                      Text(
                        LanguageController.instance.currentLanguage == AppLanguage.hindi
                            ? 'राशन कार्ड, नाम या जिले से खोजें (10,000+ कार्ड)'
                            : LanguageController.instance.currentLanguage == AppLanguage.kannada
                                ? 'ರೇಷನ್ ಕಾರ್ಡ್, ಹೆಸರು ಅಥವಾ ಜಿಲ್ಲೆಯಿಂದ ಹುಡುಕಿ (10,000+ ಕಾರ್ಡ್‌ಗಳು)'
                                : 'Search by card number, name, or district (10,000+ cards)',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          // Search Input
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _queryController,
              autofocus: true,
              onChanged: _onQueryChanged,
              decoration: InputDecoration(
                hintText: LanguageController.instance.currentLanguage == AppLanguage.hindi
                    ? 'उदा. RC-KA-000002, Deepa, Swathi, Bagalkot...'
                    : LanguageController.instance.currentLanguage == AppLanguage.kannada
                        ? 'ಉದಾ. RC-KA-000002, Deepa, Swathi, Bagalkot...'
                        : 'Search by card ID, name, or district...',
                prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF15803D)),
                suffixIcon: _queryController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () {
                          _queryController.clear();
                          _performSearch('');
                        },
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFF15803D), width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
            ),
          ),
          if (_isLoading)
            const LinearProgressIndicator(minHeight: 2, color: Color(0xFF15803D)),
          // Results list
          Expanded(
            child: _results.isEmpty
                ? Center(
                    child: _isLoading
                        ? const SizedBox()
                        : const Text(
                            'No matching beneficiaries found',
                            style: TextStyle(color: Color(0xFF64748B), fontStyle: FontStyle.italic),
                          ),
                  )
                : ListView.separated(
                    itemCount: _results.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    itemBuilder: (ctx, i) {
                      final item = _results[i];
                      final cardId = (item['pseudonymous_beneficiary_id'] ?? '').toString();
                      final name = (item['name_for_demo'] ?? 'Beneficiary').toString();
                      final scheme = (item['scheme_type'] ?? 'PHH').toString();
                      final district = (item['district'] ?? '').toString();
                      final taluk = (item['taluk'] ?? '').toString();
                      final members = item['members_count']?.toString() ?? '1';
                      final isAay = scheme == 'AAY';

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isAay ? const Color(0xFFFEF3C7) : const Color(0xFFDCFCE7),
                          child: Icon(
                            isAay ? Icons.stars_rounded : Icons.person_rounded,
                            color: isAay ? const Color(0xFFB45309) : const Color(0xFF15803D),
                            size: 20,
                          ),
                        ),
                        title: Row(
                          children: [
                            Text(
                              name,
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF0F2942)),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: isAay ? const Color(0xFFFEF3C7) : const Color(0xFFDBEAFE),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                scheme,
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                  color: isAay ? const Color(0xFFB45309) : const Color(0xFF1D4ED8),
                                ),
                              ),
                            ),
                          ],
                        ),
                        subtitle: Text(
                          '$cardId • $district${taluk.isNotEmpty ? ' ($taluk)' : ''} • $members Members',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF94A3B8)),
                        onTap: () {
                          Navigator.of(context).pop();
                          widget.onSelect(cardId, name);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
