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
  bool _isAdminLoggingIn = false;

  // Government & Brand Design Tokens
  static const Color _govNavy = Color(0xFF0A2540);
  static const Color _primaryBlue = Color(0xFF0056B3);
  static const Color _slate900 = Color(0xFF0F172A);
  static const Color _slate700 = Color(0xFF334155);
  static const Color _slate600 = Color(0xFF475569);
  static const Color _slate500 = Color(0xFF64748B);
  static const Color _slate400 = Color(0xFF94A3B8);
  static const Color _slate200 = Color(0xFFE2E8F0);

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

  // 1-Click: Department Official / Admin Portal
  Future<void> _enterAsOfficial() async {
    setState(() => _isAdminLoggingIn = true);
    try {
      await _apiService.login('admin_user', 'admin123');
    } catch (_) {
      // Continue into dashboard even if backend network takes time
    } finally {
      if (mounted) {
        setState(() => _isAdminLoggingIn = false);
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => AdminDashboardScreen(apiService: _apiService),
          ),
        );
      }
    }
  }

  // 1-Click: Beneficiary / Citizen Portal
  void _enterAsBeneficiary() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => BeneficiaryHomeScreen(
          beneficiaryId: 'RC-KA-000001',
          apiService: _apiService,
        ),
      ),
    );
  }

  // 1-Click: Diagnostics & Health Check
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
    final cardTop = ((screenH - 580) / 2).clamp(28.0, 72.0);

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

          // 3. Exactly ONE interactive Floating Quick-Access Card on the right
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
                child: _buildQuickAccessCard(isCompact: false),
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

          // 4. Quick Access Card
          Padding(
            padding: const EdgeInsets.all(16),
            child: _buildQuickAccessCard(isCompact: true),
          ),

          // 5. Four Feature Benefits Bar
          _buildMobileBenefitsBar(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  // 1-CLICK QUICK ACCESS CARD (CLEAN DESIGN WITHOUT LOGIN FIELDS)
  // ════════════════════════════════════════════════════════════════
  Widget _buildQuickAccessCard({required bool isCompact}) {
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
              vertical: isCompact ? 16 : 22,
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
                  '1-Click Quick Access • Choose your portal below',
                  style: TextStyle(
                    fontSize: isCompact ? 11.5 : 12.5,
                    color: _slate500,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: isCompact ? 14 : 18),

                // Button 1: Department Official & Admin Portal
                ElevatedButton(
                  onPressed: _isAdminLoggingIn ? null : _enterAsOfficial,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _govNavy,
                    foregroundColor: Colors.white,
                    elevation: 1.5,
                    padding: EdgeInsets.symmetric(horizontal: 14, vertical: isCompact ? 12 : 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _isAdminLoggingIn
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.admin_panel_settings_rounded, size: 20, color: Colors.white),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Sign In as Official',
                                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
                                  ),
                                  Text(
                                    'DSO, Super Admin & Field Officer',
                                    style: TextStyle(fontSize: 10.5, color: Colors.white70, fontWeight: FontWeight.w400),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.arrow_forward_rounded, size: 18, color: Colors.white),
                          ],
                        ),
                ),

                SizedBox(height: isCompact ? 10 : 12),

                // Button 2: Citizen & Beneficiary Portal
                ElevatedButton(
                  onPressed: _enterAsBeneficiary,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryBlue,
                    foregroundColor: Colors.white,
                    elevation: 1.5,
                    padding: EdgeInsets.symmetric(horizontal: 14, vertical: isCompact ? 12 : 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.people_alt_rounded, size: 20, color: Colors.white),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Enter Beneficiary Portal',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
                            ),
                            Text(
                              'Ration Card RC-KA-000001 • Intent Indent',
                              style: TextStyle(fontSize: 10.5, color: Colors.white70, fontWeight: FontWeight.w400),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_rounded, size: 18, color: Colors.white),
                    ],
                  ),
                ),

                SizedBox(height: isCompact ? 12 : 16),

                // Security & Credentials Info Box
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
                      const Icon(Icons.verified_user_outlined, size: 16, color: Color(0xFF0284C7)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Pre-authenticated Instant Access enabled. Direct 1-click entry into all services.',
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

                // Button 3: System Diagnostics & Health Check
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

                SizedBox(height: isCompact ? 14 : 18),

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
