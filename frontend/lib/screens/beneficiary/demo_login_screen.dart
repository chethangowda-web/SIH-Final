import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/localization.dart';
import '../../services/api_service.dart';
import 'beneficiary_home_screen.dart';
import '../admin/dso_dashboard_screen.dart';
import '../admin/system_admin_dashboard_screen.dart';
import '../admin/field_food_inspector_dashboard_screen.dart';
import '../admin/fps_owner_dashboard_screen.dart';
import '../admin/auditor_dashboard_screen.dart';

class DemoLoginScreen extends StatefulWidget {
  final ApiService? apiService;
  final String? sessionExpiredMessage;

  const DemoLoginScreen({super.key, this.apiService, this.sessionExpiredMessage});

  @override
  State<DemoLoginScreen> createState() => _DemoLoginScreenState();
}

class _DemoLoginScreenState extends State<DemoLoginScreen> {
  late final ApiService _apiService;
  int _selectedTabIndex = 0; // 0: Citizen OTP, 1: Department Official

  // Controllers for Citizen Login (Ration Card Number + Phone Number)
  final TextEditingController _citizenCardController = TextEditingController();
  final TextEditingController _citizenPhoneController = TextEditingController();
  final TextEditingController _citizenOtpController = TextEditingController();
  bool _otpSent = false;
  bool _isSendingOtp = false;
  bool _isVerifyingOtp = false;
  int _otpCountdownSeconds = 300;
  String? _receivedOtpCode;
  Timer? _countdownTimer;

  // Controllers for Department / Admin Login
  final TextEditingController _adminUsernameController = TextEditingController();
  final TextEditingController _adminPasswordController = TextEditingController();
  bool _isAdminLoggingIn = false;
  bool _isPasswordObscured = true;
  String _selectedOfficialRole = 'DSO';

  // Government Portal Design System Tokens
  static const Color _govNavy = Color(0xFF0F2942);
  static const Color _govBlue = Color(0xFF1E40AF);
  static const Color _govBlueLight = Color(0xFFEFF6FF);
  static const Color _govBlueBorder = Color(0xFFBFDBFE);
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

    if (widget.sessionExpiredMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.info_outline_rounded, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(widget.sessionExpiredMessage!)),
              ],
            ),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      });
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
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

  // Action: Send Real OTP to Citizen via Twilio SMS
  Future<void> _handleSendOtp() async {
    final cardId = _citizenCardController.text.trim();
    final inputPhone = _citizenPhoneController.text.trim();

    if (cardId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('login.enter_ration_card')),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSendingOtp = true);
    try {
      final res = await _apiService.sendCitizenOtp(cardId, phoneNumber: inputPhone.isNotEmpty ? inputPhone : null);
      if (!mounted) return;

      final otpCode = res['demo_otp_code']?.toString() ??
          res['mock_otp']?.toString() ??
          res['otp']?.toString() ??
          '123456';
      final phone = res['masked_phone']?.toString() ??
          (inputPhone.isNotEmpty ? inputPhone : 'Registered Phone');

      setState(() {
        _otpSent = true;
        _receivedOtpCode = otpCode;
      });
      _citizenOtpController.text = otpCode;
      _startOtpTimer();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Official OTP sent to $phone. Verification code: $otpCode'),
              ),
            ],
          ),
          backgroundColor: _govGreen,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 10),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('login.otp_send_failed', params: {'error': _cleanErrorMessage(e)})),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
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
        SnackBar(
          content: Text(tr('login.enter_valid_otp')),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isVerifyingOtp = true);
    try {
      await _apiService.verifyCitizenOtp(cardId, otp);
      if (!mounted) return;
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
          behavior: SnackBarBehavior.floating,
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
        SnackBar(
          content: Text(tr('login.enter_creds_hint')),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

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
      } else if (role == 'ADMIN' && (uName == 'admin_user' || uName.contains('admin'))) {
        targetScreen = SystemAdminDashboardScreen(apiService: _apiService, username: uName);
      } else {
        // DSO Role & Department Supply Officer Command Console
        targetScreen = DsoDashboardScreen(
          apiService: _apiService,
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
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isAdminLoggingIn = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return ListenableBuilder(
      listenable: LanguageController.instance,
      builder: (context, child) {
        return Scaffold(
          backgroundColor: _slate100,
          body: Column(
            children: [
              // Top Government Accent Bar (Tricolor Band)
              Container(
                height: 4,
                width: double.infinity,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFFFF9933),
                      Color(0xFFFF9933),
                      Color(0xFFFFFFFF),
                      Color(0xFF138808),
                      Color(0xFF138808),
                    ],
                    stops: [0.0, 0.33, 0.5, 0.67, 1.0],
                  ),
                ),
              ),

              // Government Header (Full-width bar with official identity and language selector)
              _buildGovernmentHeader(isMobile),

              // Main Centered Content Area
              Expanded(
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 16.0 : 24.0,
                    vertical: isMobile ? 20.0 : 32.0,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Service Identity Banner
                          _buildServiceIdentity(isMobile),

                          const SizedBox(height: 20),

                          // Main Official Login Card
                          _buildLoginCard(isMobile),

                          const SizedBox(height: 24),

                          // Restrained Government Footer
                          _buildGovernmentFooter(isMobile),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ================================================================
  // 1. TOP GOVERNMENT IDENTITY HEADER
  // ================================================================
  Widget _buildGovernmentHeader(bool isMobile) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 32,
        vertical: isMobile ? 10 : 12,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: _slate200, width: 1)),
        boxShadow: [
          BoxShadow(
            color: Color(0x060F172A),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left: Emblem + Department Branding
          Expanded(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: _slate50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _slate200),
                  ),
                  child: Image.asset(
                    'assets/images/emblem_gold.png',
                    height: isMobile ? 32 : 38,
                    width: isMobile ? 32 : 38,
                    errorBuilder: (_, __, ___) => Icon(
                      Icons.account_balance_rounded,
                      size: isMobile ? 28 : 34,
                      color: _govNavy,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Text(
                            tr('login.portal_title'),
                            style: TextStyle(
                              fontSize: isMobile ? 15 : 17,
                              fontWeight: FontWeight.w800,
                              color: _govNavy,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: _govBlueLight,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: _govBlueBorder),
                            ),
                            child: Text(
                              tr('login.govt_badge'),
                              style: const TextStyle(
                                fontSize: 8.5,
                                fontWeight: FontWeight.w800,
                                color: _govBlue,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 1),
                      Text(
                        tr('login.dept_header'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: isMobile ? 10.5 : 12,
                          fontWeight: FontWeight.w500,
                          color: _slate500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          // Right: Official Multilingual Selector
          const LanguageSelectorWidget(isCompact: true, isLight: true),
        ],
      ),
    );
  }

  // ================================================================
  // 2. SERVICE IDENTITY SECTION
  // ================================================================
  Widget _buildServiceIdentity(bool isMobile) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _govBlueLight,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _govBlueBorder),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.verified_outlined, size: 13, color: _govBlue),
                  const SizedBox(width: 5),
                  Text(
                    tr('login.service_badge'),
                    style: TextStyle(
                      fontSize: isMobile ? 9.5 : 10.5,
                      fontWeight: FontWeight.w800,
                      color: _govBlue,
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          tr('login.service_title'),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: isMobile ? 20 : 24,
            fontWeight: FontWeight.w800,
            color: _slate900,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          tr('login.service_sub'),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: isMobile ? 12 : 13.5,
            color: _slate500,
          ),
        ),
      ],
    );
  }

  // ================================================================
  // 3. MAIN LOGIN CARD
  // ================================================================
  Widget _buildLoginCard(bool isMobile) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _slate200),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A0F172A),
            blurRadius: 20,
            offset: Offset(0, 6),
          ),
          BoxShadow(
            color: Color(0x050F172A),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Card Header Banner
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 18 : 24,
              vertical: isMobile ? 16 : 18,
            ),
            decoration: const BoxDecoration(
              color: _slate50,
              border: Border(bottom: BorderSide(color: _slate200)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr('login.welcome_title'),
                      style: TextStyle(
                        fontSize: isMobile ? 17 : 19,
                        fontWeight: FontWeight.w800,
                        color: _slate900,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tr('login.card_subtitle'),
                      style: TextStyle(
                        fontSize: isMobile ? 11.5 : 12.5,
                        color: _slate500,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                // Tri-color indicator badge
                Row(
                  children: [
                    Container(width: 8, height: 4, decoration: BoxDecoration(color: _saffron, borderRadius: BorderRadius.circular(2))),
                    const SizedBox(width: 3),
                    Container(width: 8, height: 4, decoration: BoxDecoration(color: _slate400, borderRadius: BorderRadius.circular(2))),
                    const SizedBox(width: 3),
                    Container(width: 8, height: 4, decoration: BoxDecoration(color: _govGreenLight, borderRadius: BorderRadius.circular(2))),
                  ],
                ),
              ],
            ),
          ),

          Padding(
            padding: EdgeInsets.all(isMobile ? 16 : 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Clean Tab Switcher: CITIZEN vs DEPARTMENT OFFICIAL
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: _slate100,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _slate200),
                  ),
                  child: Row(
                    children: [
                      _buildTabButton(
                        index: 0,
                        label: tr('login.tab_citizen'),
                        icon: Icons.person_rounded,
                        isMobile: isMobile,
                        activeColor: _govGreen,
                      ),
                      _buildTabButton(
                        index: 1,
                        label: tr('login.tab_official'),
                        icon: Icons.admin_panel_settings_rounded,
                        isMobile: isMobile,
                        activeColor: _govNavy,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Active Tab Content
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: _selectedTabIndex == 0
                      ? _buildCitizenTab(isMobile)
                      : _buildDepartmentTab(isMobile),
                ),

                const SizedBox(height: 20),

                // Professional Security Information Box
                _buildSecurityAssurance(isMobile),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton({
    required int index,
    required String label,
    required IconData icon,
    required bool isMobile,
    required Color activeColor,
  }) {
    final isSelected = _selectedTabIndex == index;
    return Expanded(
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _selectedTabIndex = index),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: EdgeInsets.symmetric(vertical: isMobile ? 8 : 10),
            decoration: BoxDecoration(
              color: isSelected ? Colors.white : Colors.transparent,
              borderRadius: BorderRadius.circular(7),
              boxShadow: isSelected
                  ? const [
                      BoxShadow(
                        color: Color(0x0D000000),
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: isMobile ? 14 : 16,
                  color: isSelected ? activeColor : _slate500,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: isMobile ? 11 : 12.5,
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                      color: isSelected ? activeColor : _slate500,
                      letterSpacing: isSelected ? 0.2 : 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ================================================================
  // 4. CITIZEN LOGIN TAB
  // ================================================================
  Widget _buildCitizenTab(bool isMobile) {
    return Column(
      key: const ValueKey('citizen_tab'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Verified NFSA Dataset Notice
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: _govBlueLight,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _govBlueBorder),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.shield_outlined, size: 18, color: _govBlue),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  tr('login.anti_fraud_notice'),
                  style: TextStyle(
                    fontSize: isMobile ? 10.5 : 11.5,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1E40AF),
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Field 1: Ration Card Number
        Text(
          tr('login.ration_card_label'),
          style: TextStyle(
            fontSize: isMobile ? 11.5 : 12.5,
            fontWeight: FontWeight.w700,
            color: _slate700,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _citizenCardController,
          enabled: !_isSendingOtp && !_isVerifyingOtp,
          style: TextStyle(fontSize: isMobile ? 13.5 : 14.5, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: tr('login.ration_card_input_hint'),
            hintStyle: const TextStyle(color: _slate400, fontSize: 13),
            prefixIcon: Icon(Icons.credit_card_rounded, size: isMobile ? 18 : 20, color: _slate500),
            filled: true,
            fillColor: _slate50,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _slate200)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _slate200)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _govGreen, width: 1.8)),
            contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: isMobile ? 10 : 12),
          ),
        ),

        const SizedBox(height: 12),

        // Field 2: Phone Number
        Text(
          tr('login.phone_label'),
          style: TextStyle(
            fontSize: isMobile ? 11.5 : 12.5,
            fontWeight: FontWeight.w700,
            color: _slate700,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _citizenPhoneController,
          keyboardType: TextInputType.phone,
          enabled: !_isSendingOtp && !_isVerifyingOtp,
          style: TextStyle(fontSize: isMobile ? 13.5 : 14.5, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: tr('login.phone_input_hint'),
            hintStyle: const TextStyle(color: _slate400, fontSize: 13),
            prefixIcon: Icon(Icons.phone_rounded, size: isMobile ? 18 : 20, color: _slate500),
            filled: true,
            fillColor: _slate50,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _slate200)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _slate200)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _govGreen, width: 1.8)),
            contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: isMobile ? 10 : 12),
          ),
        ),

        const SizedBox(height: 16),

        if (!_otpSent)
          ElevatedButton(
            onPressed: _isSendingOtp ? null : _handleSendOtp,
            style: ElevatedButton.styleFrom(
              backgroundColor: _govNavy,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 46),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: _isSendingOtp
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.send_rounded, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        tr('login.get_otp'),
                        style: TextStyle(
                          fontSize: isMobile ? 13.5 : 14.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
          )
        else ...[
          // OTP Received Section
          Container(
            padding: EdgeInsets.all(isMobile ? 12 : 16),
            decoration: BoxDecoration(
              color: _govGreenBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _govGreenBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.mark_email_read_outlined, size: 16, color: _govGreen),
                        const SizedBox(width: 6),
                        Text(
                          tr('login.enter_6_digit_otp'),
                          style: TextStyle(
                            fontSize: isMobile ? 12 : 13,
                            fontWeight: FontWeight.w800,
                            color: _govGreen,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: _govGreenBorder),
                      ),
                      child: Text(
                        _formatTimer(_otpCountdownSeconds),
                        style: TextStyle(
                          fontSize: isMobile ? 11 : 12,
                          fontWeight: FontWeight.w800,
                          color: _govGreen,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                if (_receivedOtpCode != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _govGreenBorder),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.key_rounded, size: 14, color: _govGreen),
                            const SizedBox(width: 6),
                            Text(
                              'Official OTP Code:',
                              style: TextStyle(
                                fontSize: isMobile ? 11 : 12,
                                fontWeight: FontWeight.w700,
                                color: _govGreen,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: _govGreenBg,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _receivedOtpCode!,
                            style: TextStyle(
                              fontSize: isMobile ? 13 : 14,
                              fontWeight: FontWeight.w900,
                              color: _govGreen,
                              letterSpacing: 2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                TextField(
                  controller: _citizenOtpController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: isMobile ? 20 : 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 8,
                    color: _slate900,
                  ),
                  decoration: InputDecoration(
                    hintText: '••••••',
                    counterText: '',
                    hintStyle: const TextStyle(letterSpacing: 8, color: _slate400),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _slate200)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _govGreenBorder)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _govGreen, width: 2)),
                    contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                  ),
                ),

                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      tr('login.sms_dispatched_notice'),
                      style: TextStyle(fontSize: isMobile ? 10 : 11, color: _slate500),
                    ),
                    MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: _isSendingOtp ? null : _handleSendOtp,
                        child: Text(
                          tr('login.resend_otp_btn'),
                          style: TextStyle(
                            fontSize: isMobile ? 11 : 12,
                            fontWeight: FontWeight.w800,
                            color: _govNavy,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          ElevatedButton(
            onPressed: _isVerifyingOtp ? null : _handleVerifyOtpAndLogin,
            style: ElevatedButton.styleFrom(
              backgroundColor: _govGreen,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 46),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: _isVerifyingOtp
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.lock_open_rounded, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        tr('login.verify_signin_btn'),
                        style: TextStyle(
                          fontSize: isMobile ? 13.5 : 14.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ],
    );
  }

  // ================================================================
  // 5. DEPARTMENT OFFICIAL LOGIN TAB
  // ================================================================
  Widget _buildDepartmentTab(bool isMobile) {
    return Column(
      key: const ValueKey('dept_tab'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          tr('login.select_role_window'),
          style: TextStyle(
            fontSize: isMobile ? 11.5 : 12.5,
            fontWeight: FontWeight.w800,
            color: _slate900,
          ),
        ),
        const SizedBox(height: 8),

        // Grid of 4 Role Windows
        GridView.count(
          crossAxisCount: isMobile ? 2 : 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: isMobile ? 2.3 : 2.7,
          children: [
            _buildRoleWindowCard(
              title: tr('login.role_dso_title'),
              subtitle: tr('login.role_dso_sub'),
              icon: Icons.account_balance_outlined,
              color: const Color(0xFF166534),
              bgColor: const Color(0xFFF0FDF4),
              username: 'dso_user',
              password: 'dso_pass',
              role: 'DSO',
              isMobile: isMobile,
            ),
            _buildRoleWindowCard(
              title: tr('login.role_inspector_title'),
              subtitle: tr('login.role_inspector_sub'),
              icon: Icons.assignment_turned_in_outlined,
              color: const Color(0xFF92400E),
              bgColor: const Color(0xFFFFFBEB),
              username: 'inspector_user',
              password: 'inspector_pass',
              role: 'FIELD_FOOD_INSPECTOR',
              isMobile: isMobile,
            ),
            _buildRoleWindowCard(
              title: tr('login.role_fps_title'),
              subtitle: tr('login.role_fps_sub'),
              icon: Icons.storefront_outlined,
              color: const Color(0xFF0F766E),
              bgColor: const Color(0xFFF0FDFA),
              username: 'fps_user',
              password: 'fps_pass',
              role: 'FPS_OWNER',
              isMobile: isMobile,
            ),
            _buildRoleWindowCard(
              title: tr('login.role_auditor_title'),
              subtitle: tr('login.role_auditor_sub'),
              icon: Icons.verified_user_outlined,
              color: const Color(0xFF6B21A8),
              bgColor: const Color(0xFFF3E8FF),
              username: 'auditor_user',
              password: 'auditor_pass',
              role: 'AUDITOR',
              isMobile: isMobile,
            ),
          ],
        ),

        const SizedBox(height: 14),

        // Field 1: Official User ID
        Text(
          tr('login.official_user_id'),
          style: TextStyle(
            fontSize: isMobile ? 11.5 : 12.5,
            fontWeight: FontWeight.w700,
            color: _slate700,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _adminUsernameController,
          enabled: !_isAdminLoggingIn,
          style: TextStyle(fontSize: isMobile ? 13.5 : 14.5, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: tr('login.official_user_placeholder'),
            hintStyle: const TextStyle(color: _slate400, fontSize: 13),
            prefixIcon: Icon(Icons.person_outline_rounded, size: isMobile ? 18 : 20, color: _slate500),
            filled: true,
            fillColor: _slate50,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _slate200)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _slate200)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _govNavy, width: 1.8)),
            contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: isMobile ? 10 : 12),
          ),
        ),

        const SizedBox(height: 12),

        // Field 2: Password
        Text(
          tr('login.password_field'),
          style: TextStyle(
            fontSize: isMobile ? 11.5 : 12.5,
            fontWeight: FontWeight.w700,
            color: _slate700,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _adminPasswordController,
          obscureText: _isPasswordObscured,
          enabled: !_isAdminLoggingIn,
          style: TextStyle(fontSize: isMobile ? 13.5 : 14.5, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: tr('login.password_placeholder'),
            hintStyle: const TextStyle(color: _slate400, fontSize: 13),
            prefixIcon: Icon(Icons.lock_outline_rounded, size: isMobile ? 18 : 20, color: _slate500),
            suffixIcon: IconButton(
              icon: Icon(
                _isPasswordObscured ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                size: isMobile ? 18 : 20,
                color: _slate500,
              ),
              onPressed: () => setState(() => _isPasswordObscured = !_isPasswordObscured),
            ),
            filled: true,
            fillColor: _slate50,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _slate200)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _slate200)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _govNavy, width: 1.8)),
            contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: isMobile ? 10 : 12),
          ),
        ),

        const SizedBox(height: 16),

        ElevatedButton(
          onPressed: _isAdminLoggingIn ? null : _handleDepartmentLogin,
          style: ElevatedButton.styleFrom(
            backgroundColor: _govNavy,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 46),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            elevation: 0,
          ),
          child: _isAdminLoggingIn
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.login_rounded, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      tr('login.signin_workspace_btn'),
                      style: TextStyle(
                        fontSize: isMobile ? 13 : 14,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildRoleWindowCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Color bgColor,
    required String username,
    required String password,
    required String role,
    required bool isMobile,
  }) {
    final isSelected = _selectedOfficialRole == role || _adminUsernameController.text.trim() == username;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          setState(() {
            _selectedOfficialRole = role;
            _adminUsernameController.text = username;
            _adminPasswordController.text = password;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
                  Icon(icon, size: isMobile ? 14 : 16, color: color),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: isMobile ? 11 : 12,
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isSelected)
                    Icon(Icons.check_circle_rounded, size: 14, color: color),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: isMobile ? 9 : 10,
                  fontWeight: FontWeight.w500,
                  color: _slate500,
                  height: 1.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ================================================================
  // 6. SECURITY ASSURANCE FOOTNOTE
  // ================================================================
  Widget _buildSecurityAssurance(bool isMobile) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _slate50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _slate200),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_rounded, size: 16, color: _govNavy),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr('login.security_badge'),
                  style: TextStyle(
                    fontSize: isMobile ? 9.5 : 10.5,
                    fontWeight: FontWeight.w800,
                    color: _govNavy,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  tr('login.security_desc'),
                  style: TextStyle(
                    fontSize: isMobile ? 10 : 11,
                    color: _slate500,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ================================================================
  // 7. RESTRAINED GOVERNMENT FOOTER
  // ================================================================
  Widget _buildGovernmentFooter(bool isMobile) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.shield_rounded, size: 14, color: _govNavy),
            const SizedBox(width: 6),
            Text(
              tr('login.footer_portal_title'),
              style: TextStyle(
                fontSize: isMobile ? 10.5 : 11.5,
                color: _slate700,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          tr('login.footer_legal'),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: isMobile ? 9.5 : 10.5,
            color: _slate400,
            height: 1.35,
          ),
        ),
      ],
    );
  }
}
