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
          backgroundColor: Colors.green.shade700,
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
          backgroundColor: const Color(0xFFF8FAFC),
          body: Stack(
            children: [
              // Subtle Indian Tricolor Ribbon Waves at Bottom Left
              Positioned(
                bottom: 0,
                left: 0,
                child: Opacity(
                  opacity: 0.65,
                  child: Image.asset(
                    'assets/images/ribbon_wave.png',
                    height: 180,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                  ),
                ),
              ),

              // Subtle Parliament / Heritage Building Skyline at Bottom Right
              Positioned(
                bottom: 0,
                right: 0,
                child: Opacity(
                  opacity: 0.45,
                  child: Image.asset(
                    'assets/images/skyline.png',
                    height: 220,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                  ),
                ),
              ),

              // Main Content Area
              SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1140),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Top Navigation & Header Bar
                          _buildTopBar(),

                          const SizedBox(height: 32),

                          // Responsive Two-Column Layout (Hero on Left, Login Card on Right)
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final isWide = constraints.maxWidth >= 900;
                              if (isWide) {
                                return Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      flex: 12,
                                      child: _buildLeftHeroSection(),
                                    ),
                                    const SizedBox(width: 44),
                                    Expanded(
                                      flex: 11,
                                      child: _buildRightLoginCard(),
                                    ),
                                  ],
                                );
                              } else {
                                return Column(
                                  children: [
                                    _buildLeftHeroSection(),
                                    const SizedBox(height: 32),
                                    ConstrainedBox(
                                      constraints: const BoxConstraints(maxWidth: 540),
                                      child: _buildRightLoginCard(),
                                    ),
                                  ],
                                );
                              }
                            },
                          ),

                          const SizedBox(height: 32),
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

  // Widget: Top Government Header Bar
  Widget _buildTopBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Left: Ashoka Emblem & Brand
        Row(
          children: [
            Image.asset(
              'assets/images/emblem.png',
              height: 48,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppConstants.primaryNavy.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.shield_rounded, color: AppConstants.primaryNavy, size: 28),
              ),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr('app.name'),
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                    color: AppConstants.primaryNavy,
                    letterSpacing: -0.4,
                  ),
                ),
                Text(
                  tr('login.dept_title'),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),

        // Right: Tagline & Multilingual Selector
        Row(
          children: [
            Text(
              tr('login.tagline'),
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(width: 16),
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
      ],
    );
  }

  // Widget: Left Hero Section (Fair Distribution, Illustration, 4 Quick Features)
  Widget _buildLeftHeroSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Text(
          '${tr('login.hero_title_1')}\n${tr('login.hero_title_2')}',
          style: const TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.w900,
            color: Color(0xFF0F172A),
            height: 1.18,
            letterSpacing: -0.6,
          ),
        ),
        const SizedBox(height: 12),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Text(
            tr('login.hero_subtitle'),
            style: const TextStyle(
              fontSize: 13.5,
              color: Color(0xFF475569),
              height: 1.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Indian Family & Ration Shop Hero Graphic
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.asset(
              'assets/images/pds_family_hero.png',
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => Container(
                height: 160,
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Center(
                  child: Icon(Icons.storefront_rounded, size: 60, color: AppConstants.accentBlue),
                ),
              ),
            ),
          ),
        ),

        const SizedBox(height: 28),

        // 4 Circular Feature Action Icons
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildFeatureIcon(
                Icons.credit_card_rounded,
                tr('login.feature_check_card'),
                const Color(0xFFEFF6FF),
                const Color(0xFF2563EB),
                () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Ration Card Verification Module active: Entitlements synced with NFSA registry.'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
              _buildFeatureIcon(
                Icons.receipt_long_rounded,
                tr('login.feature_track_entitlements'),
                const Color(0xFFF0FDF4),
                const Color(0xFF16A34A),
                () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Entitlement Tracker: 5 kg grain quota per member guaranteed free under NFSA.'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
              _buildFeatureIcon(
                Icons.location_on_rounded,
                tr('login.feature_find_shop'),
                const Color(0xFFFAF5FF),
                const Color(0xFF9333EA),
                () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('ONORC Shop Locator: 2,400+ Fair Price Shops mapped across Bengaluru Urban.'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
              _buildFeatureIcon(
                Icons.headset_mic_rounded,
                tr('login.feature_get_support'),
                const Color(0xFFFFF7ED),
                const Color(0xFFEA580C),
                () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Toll-Free Grievance Helpline: Dial 1967 or 1800-425-9333 for immediate PDS assistance.'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureIcon(IconData icon, String label, Color bg, Color iconColor, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Column(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: bg,
                shape: BoxShape.circle,
                border: Border.all(color: iconColor.withValues(alpha: 0.2), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: iconColor.withValues(alpha: 0.12),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B),
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Widget: Right Login Card
  Widget _buildRightLoginCard() {
    return Card(
      elevation: 10,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(28.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Card Header: Shield Icon + "Citizen Login"
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: const Icon(Icons.shield_rounded, color: Color(0xFF0F172A), size: 26),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr('login.citizen_login_title'),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.3,
                      ),
                    ),
                    Text(
                      tr('login.citizen_login_sub'),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 22),

            // Capsule 3-Tab Segmented Selector
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  _buildSegmentTab(0, Icons.phone_android_rounded, tr('login.tab_citizen_otp')),
                  const SizedBox(width: 4),
                  _buildSegmentTab(1, Icons.account_balance_outlined, tr('login.tab_department')),
                  const SizedBox(width: 4),
                  _buildSegmentTab(2, Icons.group_outlined, tr('login.tab_demo_personas')),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Active Tab Content
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: _selectedTabIndex == 0
                  ? _buildCitizenOtpTab()
                  : (_selectedTabIndex == 1
                      ? _buildDepartmentLoginTab()
                      : _buildDemoPersonasTab()),
            ),

            const SizedBox(height: 18),

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
                label: Text(
                  tr('login.system_diagnostics'),
                  style: const TextStyle(
                    color: AppConstants.secondaryNavy,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
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
            color: isSelected ? const Color(0xFF0F172A) : Colors.transparent,
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
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? Colors.white : const Color(0xFF475569),
                  ),
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
        Text(
          tr('login.enter_card_number'),
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: Color(0xFF0F172A)),
        ),
        const SizedBox(height: 4),
        Text(
          tr('login.sms_disclaimer'),
          style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 12),

        // Quick Auto-Fill Chips (Swathi, Sunita, Ramesh)
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            Text(tr('login.quick_select'), style: const TextStyle(fontSize: 11, color: AppConstants.textSecondary, fontWeight: FontWeight.w600)),
            _buildQuickCardChip('BEN-KA-0001', 'Swathi'),
            _buildQuickCardChip('BEN-KA-0005', 'Sunita'),
            _buildQuickCardChip('BEN-KA-0015', 'Ramesh'),
          ],
        ),
        const SizedBox(height: 10),

        // Ration Card ID Input
        TextField(
          controller: _citizenCardController,
          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            labelText: tr('login.ration_card_id'),
            hintText: tr('login.ration_card_hint'),
            prefixIcon: const Icon(Icons.credit_card_rounded, size: 18, color: Color(0xFF475569)),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppConstants.accentBlue, width: 1.6)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
        ),
        const SizedBox(height: 14),

        if (!_otpSent)
          ElevatedButton.icon(
            onPressed: _isSendingOtp ? null : _handleSendOtp,
            icon: _isSendingOtp
                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.send_rounded, size: 16),
            label: Text(_isSendingOtp ? tr('login.sending_otp') : tr('login.get_otp_btn')),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppConstants.accentBlue,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 44),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          )
        else ...[
          // OTP Verification Box with 6 Individual Digit Tiles
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(10),
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
                        const Icon(Icons.phone_android_rounded, size: 16, color: Color(0xFF15803D)),
                        const SizedBox(width: 6),
                        Text(
                          tr('login.otp_sent_to_mobile'),
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF15803D)),
                        ),
                      ],
                    ),
                    Text(
                      '${tr('login.expires_in')} ${_formatTimer(_otpCountdownSeconds)}',
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF15803D)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  tr('login.otp_label'),
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
                ),
                const SizedBox(height: 8),

                // 6 Individual Digit Tiles (as in design)
                _buildSixDigitTiles(),

                const SizedBox(height: 8),
                Text(
                  tr('login.demo_otp_hint'),
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF15803D)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Big Emerald Green Button: Verify OTP & Login ->
          ElevatedButton(
            onPressed: _isVerifyingOtp ? null : _handleVerifyOtpAndLogin,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF15803D),
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 46),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 2,
            ),
            child: _isVerifyingOtp
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.check_circle_rounded, size: 17),
                      const SizedBox(width: 8),
                      Text(
                        tr('login.verify_login_btn'),
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward_rounded, size: 17),
                    ],
                  ),
          ),
        ],
      ],
    );
  }

  // Widget: 6 Individual Digit Tiles Matching the Design Mockup
  Widget _buildSixDigitTiles() {
    final otpText = _citizenOtpController.text.padRight(6, ' ');
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(6, (index) {
        final char = otpText[index].trim();
        final hasVal = char.isNotEmpty;
        return Container(
          width: 44,
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: hasVal ? const Color(0xFF16A34A) : const Color(0xFFCBD5E1),
              width: hasVal ? 1.6 : 1.0,
            ),
            boxShadow: const [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 2,
                offset: Offset(0, 1),
              ),
            ],
          ),
          child: Text(
            char.isEmpty ? '•' : char,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: hasVal ? const Color(0xFF0F172A) : const Color(0xFFCBD5E1),
            ),
          ),
        );
      }),
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
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFCBD5E1)),
        ),
        child: Text(
          '$cardId ($name)',
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: isSelected ? Colors.white : const Color(0xFF0F172A),
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
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0F172A) : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFCBD5E1)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
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
        Text(
          tr('login.dept_portal_title'),
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: Color(0xFF0F172A)),
        ),
        const SizedBox(height: 4),
        Text(
          tr('login.dept_portal_sub'),
          style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 10),

        // Quick Role Preset Selector (DSO Admin, Field Officer, Auditor)
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            Text(tr('login.role_presets'), style: const TextStyle(fontSize: 11, color: AppConstants.textSecondary, fontWeight: FontWeight.w600)),
            _buildRolePresetChip('DSO Admin', 'admin_user', 'admin_pass'),
            _buildRolePresetChip('Field Officer', 'dso_user', 'dso_pass'),
            _buildRolePresetChip('Auditor', 'auditor_user', 'auditor_pass'),
          ],
        ),
        const SizedBox(height: 12),

        TextField(
          controller: _adminUsernameController,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            labelText: tr('login.username_label'),
            prefixIcon: const Icon(Icons.person_rounded, size: 18),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
        const SizedBox(height: 10),

        TextField(
          controller: _adminPasswordController,
          obscureText: _isPasswordObscured,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            labelText: tr('login.password_label'),
            prefixIcon: const Icon(Icons.key_rounded, size: 18),
            suffixIcon: IconButton(
              icon: Icon(_isPasswordObscured ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18),
              onPressed: () => setState(() => _isPasswordObscured = !_isPasswordObscured),
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
        const SizedBox(height: 16),

        ElevatedButton.icon(
          onPressed: _isAdminLoggingIn ? null : _handleDepartmentLogin,
          icon: _isAdminLoggingIn
              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.dashboard_rounded, size: 16),
          label: Text(_isAdminLoggingIn ? tr('login.dept_authenticating') : tr('login.dept_signin_btn')),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0F172A),
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 46),
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
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFCBD5E1)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: isSelected ? Colors.white : const Color(0xFF0F172A),
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
        Text(
          tr('login.evaluator_title'),
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: Color(0xFF0F172A)),
        ),
        const SizedBox(height: 4),
        Text(
          tr('login.evaluator_sub'),
          style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
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

        const SizedBox(height: 10),

        ElevatedButton.icon(
          onPressed: _isAuthenticating ? null : _proceedToBeneficiaryHome,
          icon: const Icon(Icons.login_rounded, size: 16),
          label: Text(_isAuthenticating ? tr('login.loading_profile') : tr('login.launch_session')),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppConstants.accentBlue,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 44),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ],
    );
  }
}
