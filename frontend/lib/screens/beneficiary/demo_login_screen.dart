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

  // Controllers for Custom Citizen OTP Login
  final TextEditingController _citizenCardController = TextEditingController(text: 'BEN-KA-0001');
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

  // Action: Send OTP to Citizen
  Future<void> _handleSendOtp() async {
    final cardId = _citizenCardController.text.trim();
    if (cardId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('login.enter_valid_card'))),
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
    return ListenableBuilder(
      listenable: LanguageController.instance,
      builder: (context, child) {
        return Scaffold(
          backgroundColor: _slate50,
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Top Clean Header
                      _buildHeader(),

                      const SizedBox(height: 24),

                      // Main Login Card
                      _buildCard(),

                      const SizedBox(height: 20),

                      // Footer with Diagnostics & NIC Branding
                      _buildFooter(),
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
  // TOP BRAND HEADER
  // ════════════════════════════════════════════════════════════════
  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Image.asset(
              'assets/images/emblem_gov.png',
              height: 40,
              errorBuilder: (_, __, ___) => Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _govNavy,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.shield_rounded, color: Colors.white, size: 22),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr('app.name'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: _govNavy,
                    letterSpacing: -0.3,
                  ),
                ),
                Text(
                  tr('login.dept_title'),
                  style: const TextStyle(
                    fontSize: 11,
                    color: _slate500,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),

        // Language Switcher
        Row(
          children: [
            _buildLangChip('EN', 'en'),
            const SizedBox(width: 4),
            _buildLangChip('हिंदी', 'hi'),
            const SizedBox(width: 4),
            _buildLangChip('ಕನ್ನಡ', 'kn'),
          ],
        ),
      ],
    );
  }

  Widget _buildLangChip(String label, String code) {
    final currentLang = LanguageController.instance.currentLanguage.code;
    final isSelected = currentLang == code;
    return InkWell(
      onTap: () => LanguageController.instance.setLanguage(AppLanguage.fromCode(code)),
      borderRadius: BorderRadius.circular(6),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? _govNavy : Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: isSelected ? _govNavy : _slate200),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : _slate500,
          ),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  // MAIN LOGIN CARD
  // ════════════════════════════════════════════════════════════════
  Widget _buildCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _slate200),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 20,
            offset: Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Card Title & Subtitle
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Welcome Back',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: _slate900,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      tr('login.welcome_sub'),
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: _slate500,
                      ),
                    ),
                  ],
                ),
              ),
              // Indian Tricolor Pill Indicator
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

          const SizedBox(height: 20),

          // 3-Tab Segment Selector
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: _slate100,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                _buildSegmentTab(0, Icons.phone_android_rounded, tr('login.tab_citizen_otp'), _govGreen),
                _buildSegmentTab(1, Icons.badge_outlined, tr('login.tab_department'), _govNavy),
                _buildSegmentTab(2, Icons.group_outlined, tr('login.tab_demo_personas'), _govGreen),
              ],
            ),
          ),

          const SizedBox(height: 22),

          // Tab Content
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: _selectedTabIndex == 0
                ? _buildCitizenOtpTab()
                : (_selectedTabIndex == 1
                    ? _buildDepartmentLoginTab()
                    : _buildDemoPersonasTab()),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentTab(int index, IconData icon, String label, Color activeColor) {
    final isSelected = _selectedTabIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedTabIndex = index),
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isSelected
                ? const [BoxShadow(color: Color(0x0D000000), blurRadius: 4, offset: Offset(0, 2))]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 14,
                color: isSelected ? activeColor : _slate500,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
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
  // CITIZEN OTP TAB
  // ════════════════════════════════════════════════════════════════
  Widget _buildCitizenOtpTab() {
    return Column(
      key: const ValueKey('citizen_otp'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Ration Card Number',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _slate900),
        ),
        const SizedBox(height: 6),

        // Quick Demo Personas Selection Chips
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            _buildQuickChip('BEN-KA-0001', 'Swathi'),
            _buildQuickChip('BEN-KA-0005', 'Sunita'),
            _buildQuickChip('BEN-KA-0015', 'Ramesh'),
          ],
        ),
        const SizedBox(height: 10),

        TextField(
          controller: _citizenCardController,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: 'e.g. BEN-KA-0001',
            prefixIcon: const Icon(Icons.credit_card_rounded, size: 18, color: _slate500),
            filled: true,
            fillColor: _slate50,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _slate200)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _slate200)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _govGreen, width: 1.5)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),

        const SizedBox(height: 16),

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
                : const Text('Get OTP Code', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          )
        else ...[
          // OTP Received Box
          Container(
            padding: const EdgeInsets.all(14),
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
                    const Row(
                      children: [
                        Icon(Icons.phone_android_rounded, size: 14, color: _govGreen),
                        SizedBox(width: 4),
                        Text(
                          'OTP sent to mobile',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _govGreen),
                        ),
                      ],
                    ),
                    Text(
                      _formatTimer(_otpCountdownSeconds),
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: _govGreen),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // 6 Input Digits
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(6, (index) {
                    final otpText = _citizenOtpController.text.padRight(6, ' ');
                    final char = otpText[index].trim();
                    final hasVal = char.isNotEmpty;
                    return Container(
                      width: 44,
                      height: 44,
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
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: hasVal ? _slate900 : _slate400,
                        ),
                      ),
                    );
                  }),
                ),

                const SizedBox(height: 8),
                Text(
                  'Demo Code: ${_generatedOtpForDemo ?? "123456"} (Auto-filled)',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _govGreen),
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
              minimumSize: const Size(double.infinity, 44),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: _isVerifyingOtp
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle_rounded, size: 16),
                      SizedBox(width: 6),
                      Text('Verify OTP & Login', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                    ],
                  ),
          ),
        ],
      ],
    );
  }

  Widget _buildQuickChip(String cardId, String name) {
    final isSelected = _citizenCardController.text == cardId;
    return InkWell(
      onTap: () {
        setState(() {
          _citizenCardController.text = cardId;
          _otpSent = false;
        });
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: isSelected ? _govNavy : _slate100,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          '$cardId ($name)',
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : _slate700,
          ),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  // DEPARTMENT LOGIN TAB
  // ════════════════════════════════════════════════════════════════
  Widget _buildDepartmentLoginTab() {
    return Column(
      key: const ValueKey('dept_login'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Official Username',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _slate900),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _adminUsernameController,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: 'admin_user',
            prefixIcon: const Icon(Icons.person_outline_rounded, size: 18, color: _slate500),
            filled: true,
            fillColor: _slate50,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _slate200)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _slate200)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _govNavy, width: 1.5)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
        const SizedBox(height: 14),

        const Text(
          'Password',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _slate900),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _adminPasswordController,
          obscureText: _isPasswordObscured,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: '••••••••',
            prefixIcon: const Icon(Icons.lock_outline_rounded, size: 18, color: _slate500),
            suffixIcon: IconButton(
              icon: Icon(_isPasswordObscured ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18, color: _slate500),
              onPressed: () => setState(() => _isPasswordObscured = !_isPasswordObscured),
            ),
            filled: true,
            fillColor: _slate50,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _slate200)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _slate200)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _govNavy, width: 1.5)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),

        const SizedBox(height: 16),

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
              : const Text('Sign In as Official', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════════
  // DEMO PERSONAS TAB
  // ════════════════════════════════════════════════════════════════
  Widget _buildDemoPersonasTab() {
    return Column(
      key: const ValueKey('demo_personas'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select Evaluator Persona',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _slate900),
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
                padding: const EdgeInsets.all(10),
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
                      radius: 14,
                      backgroundColor: isSelected ? _govNavy : _slate200,
                      child: Text(
                        b.nameForDemo.substring(0, 1),
                        style: TextStyle(color: isSelected ? Colors.white : _govNavy, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${b.nameForDemo} (${b.pseudonymousBeneficiaryId})',
                            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: _slate900),
                          ),
                          Text(
                            b.registeredFpsName ?? '',
                            style: const TextStyle(fontSize: 11, color: _slate500),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                      size: 18,
                      color: isSelected ? _govNavy : _slate400,
                    ),
                  ],
                ),
              ),
            ),
          );
        }),

        const SizedBox(height: 12),

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
              : const Text('Launch Demo Session', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════════
  // FOOTER WITH SYSTEM DIAGNOSTICS
  // ════════════════════════════════════════════════════════════════
  Widget _buildFooter() {
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
          icon: const Icon(Icons.monitor_heart_outlined, size: 15, color: _slate500),
          label: Text(
            tr('login.system_diagnostics'),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _slate500),
          ),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: _slate200),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
        ),
        const SizedBox(height: 12),

        // Official Gov Disclaimer
        const Text(
          'Department of Food & Civil Supplies • Government of India',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, color: _slate400),
        ),
      ],
    );
  }
}
