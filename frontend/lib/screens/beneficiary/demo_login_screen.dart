import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/localization.dart';
import '../../services/api_service.dart';
import 'beneficiary_home_screen.dart';
import '../admin/admin_dashboard_screen.dart';
import '../admin/dso_dashboard_screen.dart';
import '../admin/field_officer_dashboard_screen.dart';
import '../admin/auditor_dashboard_screen.dart';
import '../admin/system_admin_dashboard_screen.dart';
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
  int _selectedTabIndex = 0; // 0: Citizen OTP, 1: Department

  // Controllers for Citizen Login (Ration Card Number + Home FPS Center ID)
  final TextEditingController _citizenCardController = TextEditingController();
  final TextEditingController _citizenFpsIdController = TextEditingController();
  final TextEditingController _citizenOtpController = TextEditingController();
  bool _otpSent = false;
  bool _isSendingOtp = false;
  bool _isVerifyingOtp = false;
  int _otpCountdownSeconds = 300;
  Timer? _countdownTimer;

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
    _citizenFpsIdController.dispose();
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

  // Action: Send Real OTP to Citizen via Twilio SMS
  Future<void> _handleSendOtp() async {
    final cardId = _citizenCardController.text.trim();
    final homeFpsId = _citizenFpsIdController.text.trim();

    if (cardId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your Ration Card Number (e.g. RC-KA-000001)')),
      );
      return;
    }
    if (homeFpsId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your Home FPS Center ID (e.g. FPS-KA-BAG-0001)')),
      );
      return;
    }

    setState(() => _isSendingOtp = true);
    try {
      final res = await _apiService.sendCitizenOtp(
        cardId,
        homeFpsId: homeFpsId,
      );
      setState(() {
        _otpSent = true;
        _citizenOtpController.clear();
      });
      final otpCode = res['demo_otp_code'] as String?;
      setState(() {
        _otpSent = true;
        if (otpCode != null) {
          _citizenOtpController.text = otpCode;
        }
      });
      _startOtpTimer();
      final displayText = otpCode != null ? 'OTP Code: $otpCode' : 'OTP Sent Successfully';

      if (!mounted) return;
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
      final authRes = await _apiService.login(username, password);
      final role = (authRes['role'] as String? ?? 'DSO').toUpperCase();
      final uName = authRes['username'] as String? ?? username;

      Widget targetScreen;
      if (role == 'FIELD_OFFICER') {
        targetScreen = FieldOfficerDashboardScreen(apiService: _apiService, username: uName);
      } else if (role == 'AUDITOR') {
        targetScreen = AuditorDashboardScreen(apiService: _apiService, username: uName);
      } else if (role == 'ADMIN') {
        targetScreen = SystemAdminDashboardScreen(apiService: _apiService, username: uName);
      } else {
        targetScreen = DsoDashboardScreen(apiService: _apiService, username: uName);
      }

      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => targetScreen),
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

  // ================================================================
  // HEADER (Mobile Responsive)
  // ================================================================
  Widget _buildHeader(bool isSmall) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
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
            Column(
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
                ),
                Text(
                  tr('login.dept_title'),
                  style: TextStyle(
                    fontSize: isSmall ? 10 : 11.5,
                    fontWeight: FontWeight.w500,
                    color: _slate500,
                  ),
                ),
              ],
            ),
          ],
        ),
        // Language Toggle inside Login Screen Header
        const LanguageSelectorWidget(isCompact: true, isLight: true),
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
              Column(
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
            child: _selectedTabIndex == 0
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
  // CITIZEN OTP TAB (Mobile Responsive)
  // ================================================================
  Widget _buildCitizenOtpTab(bool isSmall) {
    return Column(
      key: const ValueKey('citizen_otp'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
          child: Row(
            children: const [
              Icon(Icons.shield_outlined, size: 18, color: Color(0xFF1D4ED8)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Anti-Fraud Enforcement Active: Ration Card Number and Home FPS Center ID are cross-verified against the official NFSA Master Dataset.',
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
            filled: true,
            fillColor: _slate50,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _slate200)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _slate200)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _govGreen, width: 1.5)),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: isSmall ? 8 : 10),
          ),
        ),

        const SizedBox(height: 10),

        // Field 2: Home FPS Center ID
        Text('Home Fair Price Shop (FPS) Center ID', style: TextStyle(fontSize: isSmall ? 11 : 11.5, fontWeight: FontWeight.w600, color: _slate700)),
        const SizedBox(height: 4),
        TextField(
          controller: _citizenFpsIdController,
          style: TextStyle(fontSize: isSmall ? 13 : 14, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: 'e.g. FPS-KA-BAG-0001',
            prefixIcon: Icon(Icons.storefront_rounded, size: isSmall ? 16 : 18, color: _slate500),
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
              title: '🚚 Field Officer',
              subtitle: 'Physical Execution & Gatepass',
              icon: Icons.local_shipping_outlined,
              color: const Color(0xFF92400E),
              bgColor: const Color(0xFFFFFBEB),
              borderColor: const Color(0xFFFDE68A),
              username: 'field_officer_user',
              password: 'field_pass',
              role: 'FIELD_OFFICER',
              isSmall: isSmall,
            ),
            _buildRoleCard(
              title: '🔍 Vigilance Auditor',
              subtitle: 'Read-Only Governance Layer',
              icon: Icons.verified_user_outlined,
              color: const Color(0xFF6B21A8),
              bgColor: const Color(0xFFF3E8FF),
              borderColor: const Color(0xFFE9D5FF),
              username: 'auditor_user',
              password: 'auditor_pass',
              role: 'AUDITOR',
              isSmall: isSmall,
            ),
            _buildRoleCard(
              title: '⚡ System Admin',
              subtitle: 'Master Platform Management',
              icon: Icons.admin_panel_settings_rounded,
              color: const Color(0xFF0F172A),
              bgColor: const Color(0xFFF1F5F9),
              borderColor: const Color(0xFFCBD5E1),
              username: 'admin_user',
              password: 'admin1234',
              role: 'ADMIN',
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
  // FOOTER WITH SYSTEM DIAGNOSTICS (Responsive)
  // ================================================================
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
          tr('login.footer_disclaimer'),
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: isSmall ? 10 : 11, color: _slate400),
        ),
      ],
    );
  }
}
