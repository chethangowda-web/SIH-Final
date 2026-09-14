import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/localization.dart';
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
  int _selectedTabIndex = 1; // 0: Citizen OTP, 1: Department Official (matches reference default)

  // Controllers for Department / Admin Login
  final TextEditingController _adminUsernameController =
      TextEditingController(text: 'admin_user');
  final TextEditingController _adminPasswordController =
      TextEditingController(text: 'admin123');
  bool _isAdminLoggingIn = false;
  bool _isPasswordObscured = true;

  // Controllers for Citizen OTP Login
  final TextEditingController _citizenCardController =
      TextEditingController(text: 'RC-KA-000001');
  final TextEditingController _citizenAadhaarController =
      TextEditingController(text: '5489 1234 5678');
  final TextEditingController _citizenPhoneController =
      TextEditingController(text: '9876543210');
  final TextEditingController _citizenOtpController = TextEditingController();
  bool _otpSent = false;
  bool _isSendingOtp = false;
  bool _isVerifyingOtp = false;
  int _otpCountdownSeconds = 300;
  Timer? _countdownTimer;

  // Government & Brand Design Tokens
  static const Color _govNavy = Color(0xFF0A2540);
  static const Color _primaryBlue = Color(0xFF0056B3);
  static const Color _slate900 = Color(0xFF0F172A);
  static const Color _slate700 = Color(0xFF334155);
  static const Color _slate600 = Color(0xFF475569);
  static const Color _slate500 = Color(0xFF64748B);
  static const Color _slate400 = Color(0xFF94A3B8);
  static const Color _slate200 = Color(0xFFE2E8F0);
  static const Color _slate50 = Color(0xFFF8FAFC);
  static const Color _govGreen = Color(0xFF15803D);

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
    _adminUsernameController.dispose();
    _adminPasswordController.dispose();
    _citizenCardController.dispose();
    _citizenAadhaarController.dispose();
    _citizenPhoneController.dispose();
    _citizenOtpController.dispose();
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

  // Action: Department Admin Login
  Future<void> _handleDepartmentLogin() async {
    final username = _adminUsernameController.text.trim();
    final password = _adminPasswordController.text.trim();
    if (username.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your official username and password.')),
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
          content: Text('Department login failed: $e'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      if (mounted) setState(() => _isAdminLoggingIn = false);
    }
  }

  // Action: Citizen Send OTP
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
    if (phone.isEmpty) {
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
      final otpCode = res['demo_otp_code'] as String?;
      final msg = res['message'] as String? ?? 'OTP sent to your registered mobile number.';
      final displayText = otpCode != null ? '$msg (Security Code: $otpCode)' : msg;

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text(displayText)),
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
          content: Text('Failed to send OTP: $e'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSendingOtp = false);
    }
  }

  // Action: Citizen Verify OTP
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
          content: Text('OTP verification failed: $e'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      if (mounted) setState(() => _isVerifyingOtp = false);
    }
  }

  void _openDiagnostics() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ConnectivityScreen(apiService: _apiService),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= 960;

          if (isDesktop) {
            return _buildDesktopLayout(constraints);
          } else {
            return _buildMobileLayout(constraints);
          }
        },
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  // DESKTOP FULL-SCREEN EXACT REFERENCE COMPOSITION (EDGE-TO-EDGE)
  // ════════════════════════════════════════════════════════════════
  Widget _buildDesktopLayout(BoxConstraints constraints) {
    final screenW = constraints.maxWidth;
    final screenH = constraints.maxHeight;

    // Responsive card dimensions and positioning
    final cardWidth = (screenW * 0.28).clamp(360.0, 420.0);
    final cardRight = (screenW * 0.035).clamp(24.0, 56.0);
    final cardTop = ((screenH - 620) / 2).clamp(28.0, 72.0);

    return SizedBox(
      width: screenW,
      height: screenH,
      child: Stack(
        children: [
          // 1. High-Fidelity Clean Background Artwork (Edge-to-Edge, fits entire screen)
          Positioned.fill(
            child: Image.asset(
              'assets/images/pds_login_clean_canvas_v2.jpg',
              fit: BoxFit.cover,
              alignment: Alignment.centerLeft,
              filterQuality: FilterQuality.high,
            ),
          ),

          // 2. Interactive Language Selector at Top Right
          Positioned(
            top: 24,
            right: cardRight,
            child: _buildLanguageSelectorPill(),
          ),

          // 3. Exactly ONE interactive Floating Login Card positioned cleanly on the right
          Positioned(
            top: cardTop,
            right: cardRight,
            width: cardWidth,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: (screenH - cardTop - 16).clamp(300.0, screenH),
              ),
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: _buildLoginCard(isCompact: false),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  // TABLET / MOBILE RESPONSIVE STACKED LAYOUT
  // ════════════════════════════════════════════════════════════════
  Widget _buildMobileLayout(BoxConstraints constraints) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Top Header with Government of India Branding & Language Selector
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Image.asset(
                      'assets/images/ashoka_emblem_clean.png',
                      height: 36,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(Icons.account_balance, color: _govNavy),
                    ),
                    const SizedBox(width: 8),
                    Container(height: 28, width: 1, color: _slate200),
                    const SizedBox(width: 8),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'PDS DemandSync',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: _govNavy,
                            letterSpacing: -0.3,
                          ),
                        ),
                        Text(
                          'Department of Food & Civil Supplies',
                          style: TextStyle(fontSize: 10, color: _slate500, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ],
                ),
                _buildLanguageSelectorPill(isCompact: true),
              ],
            ),
          ),

          // 2. Mission Headline
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Do not reroute the truck\nafter it leaves,',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: _govNavy, height: 1.2),
                ),
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [Color(0xFF0066CC), Color(0xFF059669)],
                  ).createShader(bounds),
                  child: const Text(
                    'prepare the demand',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white, height: 1.2),
                  ),
                ),
                const Text(
                  'before it leaves.',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: _govNavy, height: 1.2),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Smarter planning. Stronger supply chains. Food for every citizen.',
                  style: TextStyle(fontSize: 12, color: _slate600, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),

          // 3. Scene Illustration
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.asset(
                  'assets/images/pds_login_clean_canvas_v2.jpg',
                  fit: BoxFit.cover,
                  alignment: Alignment.centerLeft,
                ),
              ),
            ),
          ),

          // 4. Login Card
          Padding(
            padding: const EdgeInsets.all(16),
            child: _buildLoginCard(isCompact: true),
          ),

          // 5. Four Feature Benefits Bar
          _buildMobileBenefitsBar(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  // INTERACTIVE LOGIN CARD (EXACT REFERENCE DESIGN)
  // ════════════════════════════════════════════════════════════════
  Widget _buildLoginCard({required bool isCompact}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Top Card Header with Ashoka Emblem, Branding & Curved Tricolor Accent
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
            child: Image.asset(
              'assets/images/login_card_header_v2.png',
              fit: BoxFit.fill,
              height: isCompact ? 64 : 76,
              errorBuilder: (_, __, ___) => _buildFallbackCardHeader(),
            ),
          ),

          // 2. Card Body Content
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isCompact ? 16 : 22,
              vertical: isCompact ? 14 : 20,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Title & Subtitle
                Text(
                  'Welcome Back',
                  style: TextStyle(
                    fontSize: isCompact ? 19 : 22,
                    fontWeight: FontWeight.w800,
                    color: _slate900,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Login to access your department services',
                  style: TextStyle(
                    fontSize: isCompact ? 11.5 : 13,
                    color: _slate500,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: isCompact ? 12 : 16),

                // Authentication Selector Tabs [ Citizen OTP ] [ Department Official ]
                _buildAuthSelectorTabs(isCompact),
                SizedBox(height: isCompact ? 12 : 16),

                // Form Fields (Dynamic based on Tab)
                if (_selectedTabIndex == 1)
                  _buildDepartmentOfficialForm(isCompact)
                else
                  _buildCitizenOtpForm(isCompact),

                SizedBox(height: isCompact ? 12 : 16),

                // Card Footer
                Text(
                  'Department of Food & Civil Supplies  •  Government of India',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: isCompact ? 9.5 : 10.5,
                    color: _slate400,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Fallback Card Header if image asset is loading
  Widget _buildFallbackCardHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: const BoxDecoration(
        color: _govNavy,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: const Row(
        children: [
          Icon(Icons.account_balance, color: Colors.white, size: 24),
          SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('PDS DemandSync', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
              Text('Department of Food & Civil Supplies', style: TextStyle(fontSize: 9.5, color: Colors.white70)),
            ],
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  // AUTH SELECTOR TABS [ Citizen OTP ] [ Department Official ]
  // ════════════════════════════════════════════════════════════════
  Widget _buildAuthSelectorTabs(bool isCompact) {
    return Container(
      height: isCompact ? 38 : 42,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: _slate50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _slate200),
      ),
      child: Row(
        children: [
          // Tab 0: Citizen OTP
          Expanded(
            child: InkWell(
              onTap: () => setState(() => _selectedTabIndex = 0),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                decoration: BoxDecoration(
                  color: _selectedTabIndex == 0 ? _primaryBlue : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.person_outline_rounded,
                      size: isCompact ? 14 : 16,
                      color: _selectedTabIndex == 0 ? Colors.white : _slate600,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Citizen OTP',
                      style: TextStyle(
                        fontSize: isCompact ? 11.5 : 12.5,
                        fontWeight: FontWeight.w700,
                        color: _selectedTabIndex == 0 ? Colors.white : _slate600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          // Tab 1: Department Official
          Expanded(
            child: InkWell(
              onTap: () => setState(() => _selectedTabIndex = 1),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                decoration: BoxDecoration(
                  color: _selectedTabIndex == 1 ? _primaryBlue : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.account_balance_outlined,
                      size: isCompact ? 14 : 15,
                      color: _selectedTabIndex == 1 ? Colors.white : _slate600,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Department Official',
                      style: TextStyle(
                        fontSize: isCompact ? 11.5 : 12.5,
                        fontWeight: FontWeight.w700,
                        color: _selectedTabIndex == 1 ? Colors.white : _slate600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  // FORM: DEPARTMENT OFFICIAL LOGIN (MATCHES REFERENCE FORM)
  // ════════════════════════════════════════════════════════════════
  Widget _buildDepartmentOfficialForm(bool isCompact) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Label: Official Username
        Text(
          'Official Username',
          style: TextStyle(fontSize: isCompact ? 11 : 12, fontWeight: FontWeight.w700, color: _slate700),
        ),
        const SizedBox(height: 5),
        // Input: Official Username with Person Icon
        TextField(
          controller: _adminUsernameController,
          style: TextStyle(fontSize: isCompact ? 12.5 : 13.5, fontWeight: FontWeight.w600, color: _slate900),
          decoration: InputDecoration(
            hintText: 'admin_user',
            hintStyle: const TextStyle(color: _slate400, fontSize: 13),
            prefixIcon: const Icon(Icons.person_outline_rounded, size: 18, color: _slate500),
            filled: true,
            fillColor: _slate50,
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: isCompact ? 9 : 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _slate200)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _slate200)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _primaryBlue, width: 1.5)),
          ),
        ),

        SizedBox(height: isCompact ? 10 : 14),

        // Label: Password
        Text(
          'Password',
          style: TextStyle(fontSize: isCompact ? 11 : 12, fontWeight: FontWeight.w700, color: _slate700),
        ),
        const SizedBox(height: 5),
        // Input: Password with Lock Icon and Eye Visibility Toggle
        TextField(
          controller: _adminPasswordController,
          obscureText: _isPasswordObscured,
          style: TextStyle(fontSize: isCompact ? 12.5 : 13.5, fontWeight: FontWeight.w600, color: _slate900),
          decoration: InputDecoration(
            hintText: '••••••••',
            hintStyle: const TextStyle(color: _slate400, fontSize: 13),
            prefixIcon: const Icon(Icons.lock_outline_rounded, size: 18, color: _slate500),
            suffixIcon: IconButton(
              icon: Icon(
                _isPasswordObscured ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                size: 18,
                color: _slate500,
              ),
              onPressed: () => setState(() => _isPasswordObscured = !_isPasswordObscured),
            ),
            filled: true,
            fillColor: _slate50,
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: isCompact ? 9 : 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _slate200)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _slate200)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _primaryBlue, width: 1.5)),
          ),
        ),

        SizedBox(height: isCompact ? 10 : 14),

        // Security Information Box
        Container(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: isCompact ? 8 : 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF0F7FF),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFBAE6FD), width: 0.8),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.shield_outlined, size: 16, color: Color(0xFF0284C7)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Supports DSO, Super Admin, State Auditor, and Field Loading Officer credentials.',
                  style: TextStyle(
                    fontSize: isCompact ? 9.8 : 10.8,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF0369A1),
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ),

        SizedBox(height: isCompact ? 12 : 16),

        // PRIMARY BUTTON: Sign In as Official
        ElevatedButton(
          onPressed: _isAdminLoggingIn ? null : _handleDepartmentLogin,
          style: ElevatedButton.styleFrom(
            backgroundColor: _govNavy,
            foregroundColor: Colors.white,
            elevation: 1,
            minimumSize: Size(double.infinity, isCompact ? 42 : 46),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.symmetric(vertical: 11),
          ),
          child: _isAdminLoggingIn
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.arrow_forward_rounded, size: 16, color: Colors.white),
                    SizedBox(width: 8),
                    Text(
                      'Sign In as Official',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                  ],
                ),
        ),

        SizedBox(height: isCompact ? 8 : 10),

        // SECONDARY BUTTON: System Diagnostics & Health Check
        OutlinedButton(
          onPressed: _openDiagnostics,
          style: OutlinedButton.styleFrom(
            backgroundColor: Colors.white,
            side: const BorderSide(color: _slate200),
            minimumSize: Size(double.infinity, isCompact ? 38 : 42),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.symmetric(vertical: 9),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.monitor_heart_outlined, size: 15, color: _slate600),
              SizedBox(width: 8),
              Text(
                'System Diagnostics & Health Check',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: _slate700),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════════
  // FORM: CITIZEN OTP LOGIN
  // ════════════════════════════════════════════════════════════════
  Widget _buildCitizenOtpForm(bool isCompact) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Ration Card Number
        const Text(
          'Ration Card Number',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _slate700),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: _citizenCardController,
          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: _slate900),
          decoration: InputDecoration(
            hintText: 'e.g. RC-KA-000001',
            hintStyle: const TextStyle(color: _slate400, fontSize: 12),
            prefixIcon: const Icon(Icons.credit_card_rounded, size: 16, color: _slate500),
            filled: true,
            fillColor: _slate50,
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _slate200)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _slate200)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _primaryBlue, width: 1.5)),
          ),
        ),

        const SizedBox(height: 8),

        // Registered Phone Number
        const Text(
          'Registered Mobile Number',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _slate700),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: _citizenPhoneController,
          keyboardType: TextInputType.phone,
          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: _slate900),
          decoration: InputDecoration(
            hintText: 'e.g. 98765 43210',
            hintStyle: const TextStyle(color: _slate400, fontSize: 12),
            prefixIcon: const Icon(Icons.phone_android_rounded, size: 16, color: _slate500),
            filled: true,
            fillColor: _slate50,
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _slate200)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _slate200)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _primaryBlue, width: 1.5)),
          ),
        ),

        const SizedBox(height: 10),

        if (!_otpSent)
          ElevatedButton(
            onPressed: _isSendingOtp ? null : _handleSendOtp,
            style: ElevatedButton.styleFrom(
              backgroundColor: _govNavy,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 40),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: _isSendingOtp
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Get OTP via SMS', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
          )
        else ...[
          // OTP verification box
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF86EFAC)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Enter 6-Digit SMS Code', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _govGreen)),
                    Text(_formatTimer(_otpCountdownSeconds), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _govGreen)),
                  ],
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _citizenOtpController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  maxLength: 6,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 6),
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: '123456',
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 6),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: _slate200)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: _isVerifyingOtp ? null : _handleVerifyOtpAndLogin,
            style: ElevatedButton.styleFrom(
              backgroundColor: _govGreen,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 40),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: _isVerifyingOtp
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Verify OTP & Login', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
          ),
        ],

        const SizedBox(height: 8),

        // Secondary Diagnostics button
        OutlinedButton(
          onPressed: _openDiagnostics,
          style: OutlinedButton.styleFrom(
            backgroundColor: Colors.white,
            side: const BorderSide(color: _slate200),
            minimumSize: const Size(double.infinity, 38),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.monitor_heart_outlined, size: 14, color: _slate600),
              SizedBox(width: 6),
              Text('System Diagnostics & Health Check', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: _slate700)),
            ],
          ),
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════════
  // LANGUAGE SELECTOR PILL (TOP RIGHT)
  // ════════════════════════════════════════════════════════════════
  Widget _buildLanguageSelectorPill({bool isCompact = false}) {
    return PopupMenuButton<AppLanguage>(
      tooltip: 'Select Language',
      onSelected: (language) => LanguageController.instance.setLanguage(language),
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: AppLanguage.english,
          child: Text('English', style: TextStyle(fontWeight: FontWeight.w600)),
        ),
        const PopupMenuItem(
          value: AppLanguage.hindi,
          child: Text('हिन्दी (Hindi)', style: TextStyle(fontWeight: FontWeight.w600)),
        ),
        const PopupMenuItem(
          value: AppLanguage.kannada,
          child: Text('ಕನ್ನಡ (Kannada)', style: TextStyle(fontWeight: FontWeight.w600)),
        ),
      ],
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isCompact ? 10 : 12,
          vertical: isCompact ? 5 : 6,
        ),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _slate200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.language_rounded, size: 14, color: _govNavy),
            const SizedBox(width: 6),
            Text(
              LanguageController.instance.currentLanguage == AppLanguage.hindi
                  ? 'हिन्दी'
                  : (LanguageController.instance.currentLanguage == AppLanguage.kannada ? 'ಕನ್ನಡ' : 'English'),
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: _govNavy,
              ),
            ),
            const SizedBox(width: 2),
            const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: _govNavy),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  // MOBILE BENEFITS BAR (4 FEATURE BLOCKS)
  // ════════════════════════════════════════════════════════════════
  Widget _buildMobileBenefitsBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildBenefitItem(
                  icon: Icons.security_rounded,
                  title: 'Transparent Supply Chain',
                  desc: 'Real-time tracking & accountability',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildBenefitItem(
                  icon: Icons.people_alt_rounded,
                  title: 'Better Access',
                  desc: 'Food security for every citizen',
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildBenefitItem(
                  icon: Icons.schedule_rounded,
                  title: 'Efficient Distribution',
                  desc: 'Right quantity, right time',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildBenefitItem(
                  icon: Icons.eco_rounded,
                  title: 'Stronger India',
                  desc: 'Together for a healthier tomorrow',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBenefitItem({
    required IconData icon,
    required String title,
    required String desc,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: _primaryBlue),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _slate900),
              ),
              Text(
                desc,
                style: const TextStyle(fontSize: 9.5, color: _slate500, height: 1.2),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
