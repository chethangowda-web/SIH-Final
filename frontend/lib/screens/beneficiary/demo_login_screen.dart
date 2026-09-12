import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/constants.dart';
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

  @override
  void initState() {
    super.initState();
    _apiService = widget.apiService ?? ApiService();
    _selectedBeneficiary = _beneficiaries.first;
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
        const SnackBar(content: Text('Please enter a valid Ration Card Number.')),
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
              Expanded(child: Text('OTP sent successfully! Demo Code: $_generatedOtpForDemo (auto-filled)')),
            ],
          ),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send OTP: $e'), backgroundColor: Colors.red.shade700),
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
        const SnackBar(content: Text('Please enter the 6-digit OTP.')),
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
        SnackBar(content: Text('OTP Verification Failed: $e'), backgroundColor: Colors.red.shade700),
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
        const SnackBar(content: Text('Please enter username and password.')),
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
        SnackBar(content: Text('Department Login Failed: $e'), backgroundColor: Colors.red.shade700),
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
          content: Text('Beneficiary login failed: $e'),
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
          backgroundColor: const Color(0xFFF1F5F9),
          body: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Card(
                  elevation: 6,
                  shadowColor: Colors.black12,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(28.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Header Emblems & GovTech Title
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppConstants.primaryNavy.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.shield_rounded, color: AppConstants.primaryNavy, size: 28),
                            ),
                            const SizedBox(width: 12),
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'PDS DemandSync',
                                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppConstants.primaryNavy, letterSpacing: -0.3),
                                ),
                                Text(
                                  'Department of Food & Civil Supplies',
                                  style: TextStyle(fontSize: 12, color: AppConstants.textSecondary, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ],
                        ),

                        const SizedBox(height: 22),

                        // Enhanced Segmented Custom Capsule Buttons (UX-optimized, never clipped)
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            children: [
                              _buildSegmentTab(0, Icons.phone_android_rounded, 'Citizen OTP'),
                              const SizedBox(width: 4),
                              _buildSegmentTab(1, Icons.admin_panel_settings_rounded, 'Department'),
                              const SizedBox(width: 4),
                              _buildSegmentTab(2, Icons.group_rounded, 'Demo Personas'),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Active Tab Body
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: _selectedTabIndex == 0
                              ? _buildCitizenOtpTab()
                              : (_selectedTabIndex == 1
                                  ? _buildDepartmentLoginTab()
                                  : _buildDemoPersonasTab()),
                        ),

                        const SizedBox(height: 14),

                        // Bottom Diagnostics Link
                        Center(
                          child: TextButton.icon(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => ConnectivityScreen(apiService: _apiService),
                                ),
                              );
                            },
                            icon: const Icon(Icons.developer_board_outlined, size: 14, color: AppConstants.secondaryNavy),
                            label: const Text(
                              'System Diagnostics & Health Check',
                              style: TextStyle(color: AppConstants.secondaryNavy, fontSize: 11.5, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSegmentTab(int index, IconData icon, String label) {
    final isSelected = _selectedTabIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedTabIndex = index),
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: isSelected ? AppConstants.primaryNavy : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isSelected
                ? const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 15,
                color: isSelected ? Colors.white : const Color(0xFF475569),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? Colors.white : const Color(0xFF475569),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Widget: Citizen OTP Tab
  Widget _buildCitizenOtpTab() {
    return Column(
      key: const ValueKey('citizen_tab'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Citizen Forward-Looking Intent Login',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: AppConstants.primaryNavy),
            ),
            // Quick Language Selector
            Row(
              children: [
                _buildLangBadge('EN', 'en'),
                const SizedBox(width: 4),
                _buildLangBadge('हिंदी', 'hi'),
                const SizedBox(width: 4),
                _buildLangBadge('ಕನ್ನಡ', 'kn'),
              ],
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Enter your Ration Card Number to receive a 6-digit verification code.',
          style: TextStyle(fontSize: 11.5, color: AppConstants.textSecondary),
        ),
        const SizedBox(height: 12),

        // Quick Auto-Fill Chips (UX feature)
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            const Text('Quick Select:', style: TextStyle(fontSize: 11, color: AppConstants.textSecondary, fontWeight: FontWeight.w600)),
            _buildQuickCardChip('BEN-KA-0001', 'Swathi'),
            _buildQuickCardChip('BEN-KA-0005', 'Sunita'),
            _buildQuickCardChip('BEN-KA-0015', 'Ramesh'),
          ],
        ),
        const SizedBox(height: 10),

        // Ration Card Input
        TextField(
          controller: _citizenCardController,
          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            labelText: 'Ration Card ID',
            hintText: 'e.g. BEN-KA-0001',
            prefixIcon: const Icon(Icons.credit_card_rounded, size: 18),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
        ),
        const SizedBox(height: 12),

        if (!_otpSent)
          ElevatedButton.icon(
            onPressed: _isSendingOtp ? null : _handleSendOtp,
            icon: _isSendingOtp
                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.send_rounded, size: 16),
            label: Text(_isSendingOtp ? 'Sending Verification SMS...' : 'Get Verification OTP'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppConstants.accentBlue,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 44),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          )
        else ...[
          // OTP Entry Box with Countdown
          Container(
            padding: const EdgeInsets.all(12),
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
                    Row(
                      children: [
                        const Icon(Icons.sms_outlined, size: 15, color: Color(0xFF15803D)),
                        const SizedBox(width: 6),
                        Text(
                          'OTP sent to registered mobile',
                          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF15803D)),
                        ),
                      ],
                    ),
                    Text(
                      'Expires in: ${_formatTimer(_otpCountdownSeconds)}',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF15803D)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _citizenOtpController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 4),
                  decoration: InputDecoration(
                    labelText: '6-Digit OTP',
                    prefixIcon: const Icon(Icons.lock_clock_rounded, size: 18),
                    helperText: 'Demo Code: 123456 (auto-filled)',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            onPressed: _isVerifyingOtp ? null : _handleVerifyOtpAndLogin,
            icon: _isVerifyingOtp
                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.verified_user_rounded, size: 16),
            label: Text(_isVerifyingOtp ? 'Verifying...' : 'Verify OTP & Enter Portal'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF15803D),
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 44),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildQuickCardChip(String cardId, String name) {
    final isSelected = _citizenCardController.text == cardId;
    return InkWell(
      onTap: () {
        setState(() {
          _citizenCardController.text = cardId;
          _otpSent = false;
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: isSelected ? AppConstants.primaryNavy : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? AppConstants.primaryNavy : const Color(0xFFCBD5E1)),
        ),
        child: Text(
          '$cardId ($name)',
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: isSelected ? Colors.white : AppConstants.primaryNavy,
          ),
        ),
      ),
    );
  }

  Widget _buildLangBadge(String label, String code) {
    final currentLang = LanguageController.instance.currentLanguage.code;
    final isSelected = currentLang == code;
    return InkWell(
      onTap: () => LanguageController.instance.setLanguage(AppLanguage.fromCode(code)),
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: isSelected ? AppConstants.primaryNavy : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: isSelected ? AppConstants.primaryNavy : const Color(0xFFCBD5E1)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: isSelected ? Colors.white : AppConstants.textSecondary,
          ),
        ),
      ),
    );
  }

  // Widget: Department Password Login Tab
  Widget _buildDepartmentLoginTab() {
    return Column(
      key: const ValueKey('department_tab'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Civil Supplies Official Portal',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: AppConstants.primaryNavy),
        ),
        const SizedBox(height: 4),
        const Text(
          'Restricted access for District Supply Officers (DSO) and Administrators.',
          style: TextStyle(fontSize: 11.5, color: AppConstants.textSecondary),
        ),
        const SizedBox(height: 10),

        // Quick Role Preset Selector (UX feature)
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            const Text('Role Presets:', style: TextStyle(fontSize: 11, color: AppConstants.textSecondary, fontWeight: FontWeight.w600)),
            _buildRolePresetChip('DSO Admin', 'admin_user', 'admin_pass'),
            _buildRolePresetChip('Field Officer', 'dso_user', 'dso_pass'),
            _buildRolePresetChip('Auditor', 'auditor_user', 'auditor_pass'),
          ],
        ),
        const SizedBox(height: 10),

        TextField(
          controller: _adminUsernameController,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            labelText: 'Official Username',
            prefixIcon: const Icon(Icons.person_rounded, size: 18),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
        const SizedBox(height: 8),

        TextField(
          controller: _adminPasswordController,
          obscureText: _isPasswordObscured,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            labelText: 'Password',
            prefixIcon: const Icon(Icons.key_rounded, size: 18),
            suffixIcon: IconButton(
              icon: Icon(_isPasswordObscured ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18),
              onPressed: () => setState(() => _isPasswordObscured = !_isPasswordObscured),
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
        const SizedBox(height: 14),

        ElevatedButton.icon(
          onPressed: _isAdminLoggingIn ? null : _handleDepartmentLogin,
          icon: _isAdminLoggingIn
              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.dashboard_rounded, size: 16),
          label: Text(_isAdminLoggingIn ? 'Authenticating Credentials...' : 'Sign In as Civil Supplies Officer'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppConstants.primaryNavy,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 44),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ],
    );
  }

  Widget _buildRolePresetChip(String label, String u, String p) {
    final isSelected = _adminUsernameController.text == u;
    return InkWell(
      onTap: () {
        setState(() {
          _adminUsernameController.text = u;
          _adminPasswordController.text = p;
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: isSelected ? AppConstants.primaryNavy : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? AppConstants.primaryNavy : const Color(0xFFCBD5E1)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: isSelected ? Colors.white : AppConstants.primaryNavy,
          ),
        ),
      ),
    );
  }

  // Widget: Demo Personas Tab
  Widget _buildDemoPersonasTab() {
    return Column(
      key: const ValueKey('demo_tab'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Evaluator Persona Login',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: AppConstants.primaryNavy),
        ),
        const SizedBox(height: 4),
        const Text(
          'Select a pre-configured synthetic profile for instant demo evaluation.',
          style: TextStyle(fontSize: 11.5, color: AppConstants.textSecondary),
        ),
        const SizedBox(height: 10),

        ..._beneficiaries.map((b) {
          final isSelected = _selectedBeneficiary?.pseudonymousBeneficiaryId == b.pseudonymousBeneficiaryId;
          return Container(
            margin: const EdgeInsets.only(bottom: 6),
            child: InkWell(
              onTap: () => setState(() => _selectedBeneficiary = b),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFFEFF6FF) : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected ? AppConstants.accentBlue : AppConstants.cardBorder,
                    width: isSelected ? 1.6 : 1.0,
                  ),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: isSelected ? AppConstants.accentBlue : const Color(0xFFE2E8F0),
                      child: Text(
                        b.nameForDemo.substring(0, 1),
                        style: TextStyle(color: isSelected ? Colors.white : AppConstants.primaryNavy, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${b.nameForDemo} (${b.pseudonymousBeneficiaryId})',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppConstants.primaryNavy),
                          ),
                          Text(
                            b.registeredFpsName ?? '',
                            style: const TextStyle(fontSize: 10.5, color: AppConstants.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                      size: 16,
                      color: isSelected ? AppConstants.accentBlue : const Color(0xFFCBD5E1),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),

        const SizedBox(height: 8),

        ElevatedButton.icon(
          onPressed: _isAuthenticating ? null : _proceedToBeneficiaryHome,
          icon: const Icon(Icons.login_rounded, size: 16),
          label: Text(_isAuthenticating ? 'Loading Profile...' : 'Launch Beneficiary Session'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppConstants.accentBlue,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 40),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ],
    );
  }
}
