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

  String _getPersonaRole(String pseudoId) {
    switch (pseudoId) {
      case 'BEN-KA-0001':
        return tr('login.swathi_role');
      case 'BEN-KA-0005':
        return tr('login.sunita_role');
      case 'BEN-KA-0015':
        return tr('login.ramesh_role');
      default:
        return 'Resident Beneficiary';
    }
  }

  @override
  void initState() {
    super.initState();
    _apiService = widget.apiService ?? ApiService();
    _selectedBeneficiary = _beneficiaries.first;
  }

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

  Future<void> _proceedToAdminDashboard() async {
    setState(() => _isAuthenticating = true);
    try {
      await _apiService.login('admin_user', 'admin_pass');
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => AdminDashboardScreen(
            apiService: _apiService,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Admin authentication failed: $e'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      if (mounted) setState(() => _isAuthenticating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: LanguageController.instance,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: const Color(0xFFF4F7FB),
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 620),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Session Expired Banner if triggered by 401
                      if (widget.sessionExpiredMessage != null) ...[
                        Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.amber.shade400),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.warning_amber_rounded, color: Colors.amber.shade900, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  widget.sessionExpiredMessage!,
                                  style: TextStyle(fontSize: 12.5, color: Colors.amber.shade900, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // Hero Header
                      Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: AppConstants.primaryNavy,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: AppConstants.primaryNavy.withValues(alpha: 0.15),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.hub_outlined, color: Colors.white, size: 26),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  tr('app.name'),
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              tr('app.subtitle'),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFFBFDBFE),
                                fontWeight: FontWeight.w500,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 18),

                      // Section A: District Supply Operations Portal Card (Officer - English)
                      Card(
                        elevation: 1,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(color: AppConstants.cardBorder, width: 1.2),
                        ),
                        color: Colors.white,
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(9),
                                    decoration: BoxDecoration(
                                      color: AppConstants.secondaryNavy.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(9),
                                    ),
                                    child: const Icon(
                                      Icons.admin_panel_settings_outlined,
                                      color: AppConstants.secondaryNavy,
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  const Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'District Supply Operations Portal',
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w800,
                                            color: AppConstants.primaryNavy,
                                          ),
                                        ),
                                        Text(
                                          'Department of Food & Civil Supplies • Bengaluru Urban',
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            color: AppConstants.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              ElevatedButton.icon(
                                onPressed: _isAuthenticating ? null : _proceedToAdminDashboard,
                                icon: _isAuthenticating
                                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                    : const Icon(Icons.dashboard_customize_outlined, size: 17),
                                label: Text(
                                  _isAuthenticating ? 'Authenticating Officer Session...' : 'District Supply Officer — Bengaluru Urban',
                                  style: const TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppConstants.primaryNavy,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 13),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  elevation: 0,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Section B: Beneficiary Portal Card (Citizen - Multilingual)
                      Card(
                        elevation: 1,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(color: AppConstants.cardBorder, width: 1.2),
                        ),
                        color: Colors.white,
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(9),
                                    decoration: BoxDecoration(
                                      color: AppConstants.accentBlue.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(9),
                                    ),
                                    child: const Icon(Icons.person_pin_circle_outlined,
                                        color: AppConstants.accentBlue, size: 22),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          tr('login.citizen_portal_title'),
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w800,
                                            color: AppConstants.primaryNavy,
                                          ),
                                        ),
                                        Text(
                                          tr('login.citizen_portal_subtitle'),
                                          style: const TextStyle(
                                            fontSize: 11.5,
                                            color: AppConstants.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),

                              // Language Switcher Pill inside Beneficiary Login Section
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    tr('lang.selector_title'),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: AppConstants.textSecondary,
                                      letterSpacing: 0.4,
                                    ),
                                  ),
                                  const LanguageSelectorWidget(
                                    isCompact: true,
                                    backgroundColor: Color(0xFFF1F5F9),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),

                              // Header above profile cards
                              Text(
                                tr('login.select_profile'),
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: AppConstants.textSecondary,
                                  letterSpacing: 0.6,
                                ),
                              ),
                              const SizedBox(height: 10),

                              // 3 Clean Profile Selectable Cards (One Selection Mechanism)
                              ..._beneficiaries.map((b) {
                                final isSelected = _selectedBeneficiary?.pseudonymousBeneficiaryId == b.pseudonymousBeneficiaryId;
                                final role = _getPersonaRole(b.pseudonymousBeneficiaryId);

                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: InkWell(
                                    onTap: () {
                                      setState(() {
                                        _selectedBeneficiary = b;
                                      });
                                    },
                                    borderRadius: BorderRadius.circular(10),
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? const Color(0xFFEFF6FF)
                                            : Colors.white,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: isSelected
                                              ? AppConstants.accentBlue
                                              : AppConstants.cardBorder,
                                          width: isSelected ? 1.8 : 1.0,
                                        ),
                                        boxShadow: isSelected
                                            ? [
                                                BoxShadow(
                                                  color: AppConstants.accentBlue.withValues(alpha: 0.1),
                                                  blurRadius: 6,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ]
                                            : null,
                                      ),
                                      child: Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 18,
                                            backgroundColor: isSelected
                                                ? AppConstants.accentBlue
                                                : const Color(0xFFE2E8F0),
                                            child: Text(
                                              b.nameForDemo.substring(0, 1),
                                              style: TextStyle(
                                                color: isSelected ? Colors.white : AppConstants.primaryNavy,
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Text(
                                                      b.nameForDemo,
                                                      style: const TextStyle(
                                                        fontWeight: FontWeight.w800,
                                                        fontSize: 13.5,
                                                        color: AppConstants.primaryNavy,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                                      decoration: BoxDecoration(
                                                        color: isSelected
                                                            ? AppConstants.accentBlue.withValues(alpha: 0.15)
                                                            : const Color(0xFFF1F5F9),
                                                        borderRadius: BorderRadius.circular(4),
                                                      ),
                                                      child: Text(
                                                        b.pseudonymousBeneficiaryId,
                                                        style: TextStyle(
                                                          fontSize: 10,
                                                          fontWeight: FontWeight.w700,
                                                          color: isSelected ? AppConstants.accentBlue : AppConstants.textSecondary,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  role,
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: isSelected ? AppConstants.primaryNavy : AppConstants.textSecondary,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Icon(
                                            isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                                            size: 20,
                                            color: isSelected ? AppConstants.accentBlue : const Color(0xFFCBD5E1),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }),

                              const SizedBox(height: 12),

                              // Single Primary Action: Continue as Beneficiary
                              ElevatedButton.icon(
                                onPressed: (_selectedBeneficiary != null && !_isAuthenticating)
                                    ? _proceedToBeneficiaryHome
                                    : null,
                                icon: _isAuthenticating
                                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                    : const Icon(Icons.login_rounded, size: 18),
                                label: Text(
                                  _isAuthenticating ? tr('login.authenticating') : tr('login.continue_btn'),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppConstants.accentBlue,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  elevation: 0,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 18),

                      // Bottom System Diagnostics Link
                      Center(
                        child: TextButton.icon(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) =>
                                    ConnectivityScreen(apiService: _apiService),
                              ),
                            );
                          },
                          icon: const Icon(Icons.developer_board_outlined,
                              size: 15, color: AppConstants.secondaryNavy),
                          label: Text(
                            tr('login.system_diagnostics'),
                            style: const TextStyle(
                              color: AppConstants.secondaryNavy,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
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
}
