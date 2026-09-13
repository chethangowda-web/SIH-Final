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
  int _selectedTabIndex = 0; // 0: Citizen OTP, 1: Department

  // Controllers for Custom Citizen OTP Login (Ration Card + Aadhaar + Phone Number)
  final TextEditingController _citizenCardController = TextEditingController();
  final TextEditingController _citizenAadhaarController = TextEditingController();
  final TextEditingController _citizenPhoneController = TextEditingController();
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

  // Action: Send Real OTP to Citizen via Twilio SMS
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
      final res = await _apiService.sendCitizenOtp(
        cardId,
        phoneNumber: phone,
        aadhaarNumber: aadhaar,
      );
      setState(() {
        _otpSent = true;
        _citizenOtpController.clear();
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
                  res['message'] as String? ?? 'OTP sent to your registered mobile number.',
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
    if (otp.isEmpty || otp.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the 6-digit OTP received on your mobile.')),
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
  // HEADER (Mobile Responsive)
  // ════════════════════════════════════════════════════════════════
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
                  'Department of Food & Civil Supplies',
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
        const LanguageSelectorWidget(isCompact: true),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════════
  // MAIN CARD CONTAINER (Mobile Responsive)
  // ════════════════════════════════════════════════════════════════
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
                _buildSegmentTab(0, Icons.phone_android_rounded, 'Citizen OTP', _govGreen, isSmall),
                _buildSegmentTab(1, Icons.badge_outlined, 'Department Official', _govNavy, isSmall),
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
            Expanded(
              child: Text(
                'Citizen Portal Access Credentials',
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
              child: const Text(
                '3-FACTOR CITIZEN AUTH',
                style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w800, color: _govGreen),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Field 1: Ration Card Number
        Text('Ration Card Number', style: TextStyle(fontSize: isSmall ? 11 : 11.5, fontWeight: FontWeight.w600, color: _slate700)),
        const SizedBox(height: 4),
        TextField(
          controller: _citizenCardController,
          style: TextStyle(fontSize: isSmall ? 13 : 14, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: 'e.g. RC-KA-000001 or BEN-KA-0001',
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
            hintText: 'e.g. +91 8050442666 / 98765 43210',
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
                : Text('Get OTP Code via SMS', style: TextStyle(fontSize: isSmall ? 13 : 14, fontWeight: FontWeight.w700)),
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
                          'Enter 6-Digit SMS Code',
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
                      'SMS dispatched to registered mobile',
                      style: TextStyle(fontSize: isSmall ? 9.5 : 10.5, color: _slate500),
                    ),
                    InkWell(
                      onTap: _isSendingOtp ? null : _handleSendOtp,
                      child: Text(
                        'Resend OTP',
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
                      Text('Verify OTP & Login', style: TextStyle(fontSize: isSmall ? 13 : 14, fontWeight: FontWeight.w700)),
                    ],
                  ),
          ),
        ],
      ],
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
            hintText: 'field_officer_user / dso_user / admin_user',
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
                  'Supports DSO, Super Admin, State Auditor, and Field Loading Officer credentials.',
                  style: TextStyle(fontSize: isSmall ? 10 : 11, color: _slate700, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),

        SizedBox(height: isSmall ? 14 : 18),

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
