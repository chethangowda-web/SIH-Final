import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/localization.dart';
import '../../models/beneficiary_model.dart';
import '../../services/api_service.dart';
import 'beneficiary_home_screen.dart';
import '../admin/admin_dashboard_screen.dart';
import '../connectivity_screen.dart';

class DemoLoginScreen extends StatefulWidget {
  final ApiService? apiService;
  final String? sessionExpiredMessage;

  const DemoLoginScreen({super.key, this.apiService, this.sessionExpiredMessage});

  @override
  State<DemoLoginScreen> createState() => _DemoLoginScreenState();
}

class _DemoLoginScreenState extends State<DemoLoginScreen> {
  late final ApiService _apiService;
  int _selectedTabIndex = 0; // 0: Citizen OTP, 1: Department, 2: Demo Personas

  // Controllers for Custom Citizen OTP Login (Ration Card + Aadhaar + Phone Number)
  final TextEditingController _citizenCardController = TextEditingController(text: 'BEN-KA-0001');
  final TextEditingController _citizenAadhaarController = TextEditingController(text: '5489 1234 5678');
  final TextEditingController _citizenPhoneController = TextEditingController(text: '98765 43210');
  final TextEditingController _citizenOtpController = TextEditingController();
  bool _otpSent = false;
  String? _generatedOtpForDemo;
  bool _isSendingOtp = false;
  bool _isVerifyingOtp = false;
  int _otpCountdownSeconds = 300;
  Timer? _countdownTimer;

  // Controllers for Department / Admin Login
  final TextEditingController _adminUsernameController = TextEditingController(text: 'admin_user');
  final TextEditingController _adminPasswordController = TextEditingController(text: 'admin_pass');
  bool _isAdminLoggingIn = false;
  bool _isPasswordObscured = true;

  final List<Beneficiary> _beneficiaries = [
    Beneficiary(
      id: 1,
      pseudonymousBeneficiaryId: 'BEN-KA-0001',
      nameForDemo: 'Swathi Bhat',
      registeredFpsId: 'FPS-KA-BLR-001',
      registeredFpsName: 'Malleshwaram Seva Kendra',
      language: 'kn',
      status: 'ACTIVE',
    ),
    Beneficiary(
      id: 2,
      pseudonymousBeneficiaryId: 'BEN-KA-0005',
      nameForDemo: 'Sunita Devi',
      registeredFpsId: 'FPS-KA-BLR-005',
      registeredFpsName: 'Bellandur Outer Ring Road',
      language: 'hi',
      status: 'ACTIVE',
    ),
    Beneficiary(
      id: 3,
      pseudonymousBeneficiaryId: 'BEN-KA-0015',
      nameForDemo: 'Ramesh Kumar',
      registeredFpsId: 'FPS-KA-BLR-013',
      registeredFpsName: 'Peenya Industrial Area',
      language: 'kn',
      status: 'ACTIVE',
    ),
  ];

  Beneficiary? _selectedBeneficiary;
  bool _isAuthenticating = false;

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
    _selectedBeneficiary = _beneficiaries.first;

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

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _citizenCardController.dispose();
    _citizenAadhaarController.dispose();
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

  // Action: Send OTP to Citizen (Requires Ration Card + Aadhaar + Phone Number)
  Future<void> _handleSendOtp() async {
    final cardId = _citizenCardController.text.trim();
    final aadhaar = _citizenAadhaarController.text.trim();
    final phone = _citizenPhoneController.text.trim();

    if (cardId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid Ration Card Number.')),
      );
      return;
    }
    if (aadhaar.isEmpty || aadhaar.replaceAll(' ', '').length < 12) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid 12-digit Aadhaar Number.')),
      );
      return;
    }
    if (phone.isEmpty || phone.replaceAll(RegExp(r'\D'), '').length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid 10-digit Registered Mobile Number.')),
      );
      return;
    }

    setState(() => _isSendingOtp = true);
    try {
      final res = await _apiService.sendCitizenOtp(cardId);
      setState(() {
        _otpSent = true;
        _generatedOtpForDemo = res['demo_otp_code'] as String? ?? '123456';
        _citizenOtpController.text = _generatedOtpForDemo!;
      });
      _startOtpTimer();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  tr('login.otp_sent_success', params: {'code': _generatedOtpForDemo!}),
                ),
              ),
            ],
          ),
          backgroundColor: _govGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('login.otp_send_failed', params: {'error': e.toString()})),
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
    if (otp.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('login.enter_otp_hint'))),
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
          content: Text(tr('login.otp_verify_failed', params: {'error': e.toString()})),
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

    setState(() => _isAdminLoggingIn = true);
    try {
      await _apiService.login(username, password);
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => AdminDashboardScreen(apiService: _apiService),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('login.dept_login_failed', params: {'error': e.toString()})),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      if (mounted) setState(() => _isAdminLoggingIn = false);
    }
  }

  // Action: One-Click Demo Beneficiary Login
  Future<void> _proceedToBeneficiaryHome() async {
    if (_selectedBeneficiary == null) return;
    setState(() => _isAuthenticating = true);
    final pseudoId = _selectedBeneficiary!.pseudonymousBeneficiaryId;

    try {
      await _apiService.login(pseudoId, 'citizen_pass');
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => BeneficiaryHomeScreen(
            beneficiaryId: pseudoId,
            apiService: _apiService,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('login.dept_login_failed', params: {'error': e.toString()})),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      if (mounted) setState(() => _isAuthenticating = false);
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
          backgroundColor: _slate50,
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

                      SizedBox(height: isSmallMobile ? 16 : 22),

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

  // ════════════════════════════════════════════════════════════════
  // TOP BRAND HEADER (Adaptive Mobile Layout)
  // ════════════════════════════════════════════════════════════════
  Widget _buildHeader(bool isSmall) {
    return Row(
      children: [
        // Emblem + Brand
        Image.asset(
          'assets/images/emblem_gov.png',
          height: isSmall ? 32 : 38,
          errorBuilder: (_, __, ___) => Container(
            width: isSmall ? 32 : 38,
            height: isSmall ? 32 : 38,
            decoration: BoxDecoration(
              color: _govNavy,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.shield_rounded, color: Colors.white, size: isSmall ? 18 : 22),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                tr('app.name'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: isSmall ? 16 : 18,
                  fontWeight: FontWeight.w800,
                  color: _govNavy,
                  letterSpacing: -0.3,
                ),
              ),
              Text(
                tr('login.dept_title'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: isSmall ? 10 : 11,
                  color: _slate500,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),

        // Language Switcher (Compact Chips)
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildLangChip('EN', 'en', isSmall),
            const SizedBox(width: 3),
            _buildLangChip('हिंदी', 'hi', isSmall),
            const SizedBox(width: 3),
            _buildLangChip('ಕನ್ನಡ', 'kn', isSmall),
          ],
        ),
      ],
    );
  }

  Widget _buildLangChip(String label, String code, bool isSmall) {
    final currentLang = LanguageController.instance.currentLanguage.code;
    final isSelected = currentLang == code;
    return InkWell(
      onTap: () => LanguageController.instance.setLanguage(AppLanguage.fromCode(code)),
      borderRadius: BorderRadius.circular(6),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.symmetric(
          horizontal: isSmall ? 6 : 8,
          vertical: isSmall ? 3 : 4,
        ),
        decoration: BoxDecoration(
          color: isSelected ? _govNavy : Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: isSelected ? _govNavy : _slate200),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: isSmall ? 10 : 11,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : _slate500,
          ),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  // MAIN LOGIN CARD (Adaptive Mobile Layout)
  // ════════════════════════════════════════════════════════════════
  Widget _buildCard(bool isSmall) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isSmall ? 14 : 16),
        border: Border.all(color: _slate200),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 18,
            offset: Offset(0, 4),
          ),
        ],
      ),
      padding: EdgeInsets.all(isSmall ? 16 : 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Card Title & Subtitle + Tricolor
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome Back',
                      style: TextStyle(
                        fontSize: isSmall ? 19 : 22,
                        fontWeight: FontWeight.w800,
                        color: _slate900,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tr('login.welcome_sub'),
                      style: TextStyle(
                        fontSize: isSmall ? 11.5 : 12.5,
                        color: _slate500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Indian Tricolor Pill Indicator
              Row(
                mainAxisSize: MainAxisSize.min,
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

          // 3-Tab Segment Selector (Adaptive)
          Container(
            padding: const EdgeInsets.all(3.5),
            decoration: BoxDecoration(
              color: _slate100,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                _buildSegmentTab(0, Icons.phone_android_rounded, 'Citizen OTP', _govGreen, isSmall),
                _buildSegmentTab(1, Icons.badge_outlined, 'Department', _govNavy, isSmall),
                _buildSegmentTab(2, Icons.group_outlined, 'Demo Personas', _govGreen, isSmall),
              ],
            ),
          ),

          SizedBox(height: isSmall ? 16 : 20),

          // Tab Content
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: _selectedTabIndex == 0
                ? _buildCitizenOtpTab(isSmall)
                : (_selectedTabIndex == 1
                    ? _buildDepartmentLoginTab(isSmall)
                    : _buildDemoPersonasTab(isSmall)),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentTab(int index, IconData icon, String label, Color activeColor, bool isSmall) {
    final isSelected = _selectedTabIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedTabIndex = index),
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
                    fontSize: isSmall ? 10 : 11.5,
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

  // ════════════════════════════════════════════════════════════════
  // CITIZEN OTP TAB (Mobile Responsive)
  // ════════════════════════════════════════════════════════════════
  Widget _buildCitizenOtpTab(bool isSmall) {
    return Column(
      key: const ValueKey('citizen_otp'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Citizen Portal Access Credentials',
              style: TextStyle(fontSize: isSmall ? 12 : 13, fontWeight: FontWeight.w700, color: _slate900),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: _govGreenBg,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: _govGreenBorder),
              ),
              child: const Text(
                '3-FACTOR CITIZEN AUTH',
                style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w800, color: _govGreen),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),

        // Quick Demo Personas Selection Chips
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            _buildQuickChip('BEN-KA-0001', '5489 1234 5678', '98765 43210', 'Swathi', isSmall),
            _buildQuickChip('BEN-KA-0005', '9123 4567 8901', '98123 45678', 'Sunita', isSmall),
            _buildQuickChip('BEN-KA-0015', '7890 1234 5678', '97654 32109', 'Ramesh', isSmall),
          ],
        ),
        const SizedBox(height: 10),

        // Field 1: Ration Card Number
        Text('Ration Card Number', style: TextStyle(fontSize: isSmall ? 11 : 11.5, fontWeight: FontWeight.w600, color: _slate700)),
        const SizedBox(height: 4),
        TextField(
          controller: _citizenCardController,
          style: TextStyle(fontSize: isSmall ? 13 : 14, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: 'e.g. BEN-KA-0001',
            prefixIcon: Icon(Icons.credit_card_rounded, size: isSmall ? 16 : 18, color: _slate500),
            filled: true,
            fillColor: _slate50,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _slate200)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _slate200)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _govGreen, width: 1.5)),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: isSmall ? 8 : 10),
          ),
        ),

        const SizedBox(height: 10),

        // Field 2: Aadhaar Number
        Text('Aadhaar Number (12 Digits)', style: TextStyle(fontSize: isSmall ? 11 : 11.5, fontWeight: FontWeight.w600, color: _slate700)),
        const SizedBox(height: 4),
        TextField(
          controller: _citizenAadhaarController,
          keyboardType: TextInputType.number,
          style: TextStyle(fontSize: isSmall ? 13 : 14, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: 'e.g. 5489 1234 5678',
            prefixIcon: Icon(Icons.fingerprint_rounded, size: isSmall ? 16 : 18, color: _slate500),
            filled: true,
            fillColor: _slate50,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _slate200)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _slate200)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _govGreen, width: 1.5)),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: isSmall ? 8 : 10),
          ),
        ),

        const SizedBox(height: 10),

        // Field 3: Registered Phone / Mobile Number
        Text('Registered Phone Number (10 Digits)', style: TextStyle(fontSize: isSmall ? 11 : 11.5, fontWeight: FontWeight.w600, color: _slate700)),
        const SizedBox(height: 4),
        TextField(
          controller: _citizenPhoneController,
          keyboardType: TextInputType.phone,
          style: TextStyle(fontSize: isSmall ? 13 : 14, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: 'e.g. 98765 43210',
            prefixIcon: Icon(Icons.phone_android_rounded, size: isSmall ? 16 : 18, color: _slate500),
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
                : Text('Get OTP Code', style: TextStyle(fontSize: isSmall ? 13 : 14, fontWeight: FontWeight.w700)),
          )
        else ...[
          // OTP Received Box (Fully Adaptive to Screen Width)
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
                        Icon(Icons.phone_android_rounded, size: isSmall ? 13 : 14, color: _govGreen),
                        const SizedBox(width: 4),
                        Text(
                          'OTP sent to mobile',
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

                // 6 Input Digits (Expanded layout: Never overflows!)
                Row(
                  children: List.generate(6, (index) {
                    final otpText = _citizenOtpController.text.padRight(6, ' ');
                    final char = otpText[index].trim();
                    final hasVal = char.isNotEmpty;
                    return Expanded(
                      child: Container(
                        margin: EdgeInsets.only(right: index < 5 ? (isSmall ? 4 : 6) : 0),
                        height: isSmall ? 42 : 46,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: hasVal ? _govGreenLight : _slate200,
                            width: hasVal ? 1.5 : 1.0,
                          ),
                        ),
                        child: Text(
                          char.isEmpty ? '•' : char,
                          style: TextStyle(
                            fontSize: isSmall ? 15 : 17,
                            fontWeight: FontWeight.w800,
                            color: hasVal ? _slate900 : _slate400,
                          ),
                        ),
                      ),
                    );
                  }),
                ),

                const SizedBox(height: 8),
                Text(
                  'Demo Code: ${_generatedOtpForDemo ?? "123456"} (Auto-filled)',
                  style: TextStyle(fontSize: isSmall ? 10 : 11, fontWeight: FontWeight.w600, color: _govGreen),
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
                      Text('Verify OTP & Login', style: TextStyle(fontSize: isSmall ? 13 : 14, fontWeight: FontWeight.w700)),
                    ],
                  ),
          ),
        ],
      ],
    );
  }

  Widget _buildQuickChip(String cardId, String aadhaar, String phone, String name, bool isSmall) {
    final isSelected = _citizenCardController.text == cardId;
    return InkWell(
      onTap: () {
        setState(() {
          _citizenCardController.text = cardId;
          _citizenAadhaarController.text = aadhaar;
          _citizenPhoneController.text = phone;
          _otpSent = false;
        });
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: isSmall ? 6 : 8, vertical: 3),
        decoration: BoxDecoration(
          color: isSelected ? _govNavy : _slate100,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          '$cardId ($name)',
          style: TextStyle(
            fontSize: isSmall ? 9.5 : 10.5,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : _slate700,
          ),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  // DEPARTMENT LOGIN TAB (Responsive)
  // ════════════════════════════════════════════════════════════════
  Widget _buildDepartmentLoginTab(bool isSmall) {
    return Column(
      key: const ValueKey('dept_login'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Official Username',
          style: TextStyle(fontSize: isSmall ? 12 : 13, fontWeight: FontWeight.w700, color: _slate900),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _adminUsernameController,
          style: TextStyle(fontSize: isSmall ? 13 : 14, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: 'dso_user / field_officer_user',
            prefixIcon: Icon(Icons.person_outline_rounded, size: isSmall ? 16 : 18, color: _slate500),
            filled: true,
            fillColor: _slate50,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _slate200)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _slate200)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _govNavy, width: 1.5)),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: isSmall ? 10 : 12),
          ),
        ),
        SizedBox(height: isSmall ? 10 : 14),

        Text(
          'Password',
          style: TextStyle(fontSize: isSmall ? 12 : 13, fontWeight: FontWeight.w700, color: _slate900),
        ),
        const SizedBox(height: 6),
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
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: isSmall ? 10 : 12),
          ),
        ),

        const SizedBox(height: 10),
        Text(
          'Quick Role Preset (One-Click Fill):',
          style: TextStyle(fontSize: isSmall ? 10.5 : 11.5, fontWeight: FontWeight.w700, color: _slate500),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _buildRolePresetChip('DSO Officer', 'dso_user', 'dso_pass', Icons.admin_panel_settings_outlined, isSmall),
            _buildRolePresetChip('Field Loading Officer', 'field_officer_user', 'field_pass', Icons.local_shipping_outlined, isSmall),
            _buildRolePresetChip('State Auditor', 'auditor_user', 'auditor_pass', Icons.verified_user_outlined, isSmall),
            _buildRolePresetChip('Super Admin', 'admin_user', 'admin_pass', Icons.security_rounded, isSmall),
          ],
        ),

        SizedBox(height: isSmall ? 12 : 16),

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
              : Text('Sign In as Official', style: TextStyle(fontSize: isSmall ? 13 : 14, fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }

  Widget _buildRolePresetChip(String label, String username, String password, IconData icon, bool isSmall) {
    final isCurrent = _adminUsernameController.text.trim() == username;
    return InkWell(
      onTap: () {
        setState(() {
          _adminUsernameController.text = username;
          _adminPasswordController.text = password;
        });
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isCurrent ? _govNavy.withValues(alpha: 0.1) : _slate100,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: isCurrent ? _govNavy : _slate200, width: isCurrent ? 1.2 : 0.8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: isSmall ? 12 : 13, color: isCurrent ? _govNavy : _slate700),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: isSmall ? 10.5 : 11.5,
                fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w600,
                color: isCurrent ? _govNavy : _slate700,
              ),
            ),
          ],
        ),
      ),
    );
  }


  // ════════════════════════════════════════════════════════════════
  // DEMO PERSONAS TAB (Responsive)
  // ════════════════════════════════════════════════════════════════
  Widget _buildDemoPersonasTab(bool isSmall) {
    return Column(
      key: const ValueKey('demo_personas'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Evaluator Persona',
          style: TextStyle(fontSize: isSmall ? 12 : 13, fontWeight: FontWeight.w700, color: _slate900),
        ),
        const SizedBox(height: 8),

        ..._beneficiaries.map((b) {
          final isSelected = _selectedBeneficiary?.pseudonymousBeneficiaryId == b.pseudonymousBeneficiaryId;
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              onTap: () => setState(() => _selectedBeneficiary = b),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: EdgeInsets.all(isSmall ? 8 : 10),
                decoration: BoxDecoration(
                  color: isSelected ? _slate100 : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected ? _govNavy : _slate200,
                    width: isSelected ? 1.5 : 1.0,
                  ),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: isSmall ? 12 : 14,
                      backgroundColor: isSelected ? _govNavy : _slate200,
                      child: Text(
                        b.nameForDemo.substring(0, 1),
                        style: TextStyle(color: isSelected ? Colors.white : _govNavy, fontSize: isSmall ? 11 : 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${b.nameForDemo} (${b.pseudonymousBeneficiaryId})',
                            style: TextStyle(fontSize: isSmall ? 11.5 : 12.5, fontWeight: FontWeight.w700, color: _slate900),
                          ),
                          Text(
                            b.registeredFpsName ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: isSmall ? 10 : 11, color: _slate500),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                      size: isSmall ? 16 : 18,
                      color: isSelected ? _govNavy : _slate400,
                    ),
                  ],
                ),
              ),
            ),
          );
        }),

        const SizedBox(height: 10),

        ElevatedButton(
          onPressed: _isAuthenticating ? null : _proceedToBeneficiaryHome,
          style: ElevatedButton.styleFrom(
            backgroundColor: _govNavy,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 44),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            elevation: 0,
          ),
          child: _isAuthenticating
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text('Launch Demo Session', style: TextStyle(fontSize: isSmall ? 13 : 14, fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════════
  // FOOTER WITH SYSTEM DIAGNOSTICS (Responsive)
  // ════════════════════════════════════════════════════════════════
  Widget _buildFooter(bool isSmall) {
    return Column(
      children: [
        // System Diagnostics Button
        OutlinedButton.icon(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => ConnectivityScreen(apiService: _apiService),
              ),
            );
          },
          icon: Icon(Icons.monitor_heart_outlined, size: isSmall ? 14 : 15, color: _slate500),
          label: Text(
            tr('login.system_diagnostics'),
            style: TextStyle(fontSize: isSmall ? 11 : 12, fontWeight: FontWeight.w600, color: _slate500),
          ),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: _slate200),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding: EdgeInsets.symmetric(horizontal: isSmall ? 12 : 16, vertical: isSmall ? 8 : 10),
          ),
        ),
        SizedBox(height: isSmall ? 8 : 12),

        // Official Gov Disclaimer
        Text(
          'Department of Food & Civil Supplies • Government of India',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: isSmall ? 10 : 11, color: _slate400),
        ),
      ],
    );
  }
}
