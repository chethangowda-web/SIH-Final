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

class _DemoLoginScreenState extends State<DemoLoginScreen> with SingleTickerProviderStateMixin {
  late final ApiService _apiService;
  late final TabController _tabController;

  // Controllers for Custom Citizen OTP Login
  final TextEditingController _citizenCardController = TextEditingController(text: 'BEN-KA-0001');
  final TextEditingController _citizenOtpController = TextEditingController();
  bool _otpSent = false;
  String? _generatedOtpForDemo;
  bool _isSendingOtp = false;
  bool _isVerifyingOtp = false;

  // Controllers for Department / Admin Login
  final TextEditingController _adminUsernameController = TextEditingController(text: 'admin_user');
  final TextEditingController _adminPasswordController = TextEditingController(text: 'admin_pass');
  String _selectedRole = 'ADMIN';
  bool _isAdminLoggingIn = false;

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
    _tabController = TabController(length: 3, vsync: this);
    _selectedBeneficiary = _beneficiaries.first;
  }

  @override
  void dispose() {
    _citizenCardController.dispose();
    _citizenOtpController.dispose();
    _adminUsernameController.dispose();
    _adminPasswordController.dispose();
    _tabController.dispose();
    super.dispose();
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
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('OTP sent successfully! Demo Code: $_generatedOtpForDemo'),
          backgroundColor: Colors.green.shade700,
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
      final res = await _apiService.verifyCitizenOtp(cardId, otp);
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
    return ValueListenableBuilder<String>(
      valueListenable: AppLocalization.instance.currentLocale,
      builder: (context, locale, child) {
        return Scaffold(
          backgroundColor: const Color(0xFFF1F5F9),
          body: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 580),
                child: Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Header Emblems & GovTech Title
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
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
                                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppConstants.primaryNavy),
                                ),
                                Text(
                                  'Department of Food & Civil Supplies',
                                  style: TextStyle(fontSize: 12, color: AppConstants.textSecondary, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // Tab Bar: Citizen OTP / Official Login / Demo Personas
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFE2E8F0),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: TabBar(
                            controller: _tabController,
                            indicator: BoxDecoration(
                              color: AppConstants.primaryNavy,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            labelColor: Colors.white,
                            unselectedLabelColor: AppConstants.textSecondary,
                            labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                            tabs: const [
                              Tab(icon: Icon(Icons.phone_android_rounded, size: 16), text: 'Citizen OTP'),
                              Tab(icon: Icon(Icons.admin_panel_settings_rounded, size: 16), text: 'Department'),
                              Tab(icon: Icon(Icons.group_rounded, size: 16), text: 'Demo Personas'),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Tab Views
                        SizedBox(
                          height: 330,
                          child: TabBarView(
                            controller: _tabController,
                            children: [
                              // TAB 1: Citizen OTP Login
                              _buildCitizenOtpTab(),

                              // TAB 2: Department Password Login
                              _buildDepartmentLoginTab(),

                              // TAB 3: Quick Demo Personas
                              _buildDemoPersonasTab(),
                            ],
                          ),
                        ),

                        const SizedBox(height: 12),

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
                              style: TextStyle(color: AppConstants.secondaryNavy, fontSize: 11, fontWeight: FontWeight.w600),
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

  // Widget: Citizen OTP Tab
  Widget _buildCitizenOtpTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Citizen Forward-Looking Intent Login',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppConstants.primaryNavy),
        ),
        const SizedBox(height: 4),
        const Text(
          'Enter your Ration Card Number to receive a 6-digit verification code.',
          style: TextStyle(fontSize: 12, color: AppConstants.textSecondary),
        ),
        const SizedBox(height: 14),

        // Ration Card Input
        TextField(
          controller: _citizenCardController,
          decoration: InputDecoration(
            labelText: 'Ration Card ID (e.g. BEN-KA-0001)',
            prefixIcon: const Icon(Icons.credit_card_rounded, size: 20),
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
            label: Text(_isSendingOtp ? 'Sending OTP...' : 'Get Verification OTP'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppConstants.accentBlue,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 44),
            ),
          )
        else ...[
          TextField(
            controller: _citizenOtpController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Enter 6-Digit OTP',
              prefixIcon: const Icon(Icons.lock_clock_rounded, size: 20),
              helperText: 'Demo Code: 123456 (auto-filled)',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _isVerifyingOtp ? null : _handleVerifyOtpAndLogin,
            icon: _isVerifyingOtp
                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.verified_user_rounded, size: 16),
            label: Text(_isVerifyingOtp ? 'Verifying...' : 'Verify OTP & Enter Portal'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade700,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 44),
            ),
          ),
        ],
      ],
    );
  }

  // Widget: Department Password Login Tab
  Widget _buildDepartmentLoginTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Civil Supplies Official Portal',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppConstants.primaryNavy),
        ),
        const SizedBox(height: 4),
        const Text(
          'Restricted access for District Supply Officers (DSO) and Administrators.',
          style: TextStyle(fontSize: 12, color: AppConstants.textSecondary),
        ),
        const SizedBox(height: 12),

        TextField(
          controller: _adminUsernameController,
          decoration: InputDecoration(
            labelText: 'Username (e.g. admin_user / dso_user)',
            prefixIcon: const Icon(Icons.person_rounded, size: 20),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
        ),
        const SizedBox(height: 10),

        TextField(
          controller: _adminPasswordController,
          obscureText: true,
          decoration: InputDecoration(
            labelText: 'Password (e.g. admin_pass)',
            prefixIcon: const Icon(Icons.key_rounded, size: 20),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
        ),
        const SizedBox(height: 14),

        ElevatedButton.icon(
          onPressed: _isAdminLoggingIn ? null : _handleDepartmentLogin,
          icon: _isAdminLoggingIn
              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.dashboard_rounded, size: 16),
          label: Text(_isAdminLoggingIn ? 'Authenticating...' : 'Sign In as Civil Supplies Officer'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppConstants.primaryNavy,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 44),
          ),
        ),
      ],
    );
  }

  // Widget: Demo Personas Tab
  Widget _buildDemoPersonasTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Evaluator Persona Login',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppConstants.primaryNavy),
        ),
        const SizedBox(height: 4),
        const Text(
          'Select a pre-configured synthetic profile for instant demo evaluation.',
          style: TextStyle(fontSize: 12, color: AppConstants.textSecondary),
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
                      child: Text(
                        '${b.nameForDemo} (${b.pseudonymousBeneficiaryId})',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppConstants.primaryNavy),
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
          label: Text(_isAuthenticating ? 'Loading...' : 'Launch Beneficiary Session'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppConstants.accentBlue,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 40),
          ),
        ),
      ],
    );
  }
}
