import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../models/beneficiary_model.dart';
import '../../services/api_service.dart';
import 'beneficiary_home_screen.dart';
import '../admin/admin_dashboard_screen.dart';
import '../connectivity_screen.dart';

class DemoLoginScreen extends StatefulWidget {
  final ApiService? apiService;

  const DemoLoginScreen({super.key, this.apiService});

  @override
  State<DemoLoginScreen> createState() => _DemoLoginScreenState();
}

class _DemoLoginScreenState extends State<DemoLoginScreen> {
  late final ApiService _apiService;
  List<Beneficiary> _beneficiaries = [];
  Beneficiary? _selectedBeneficiary;
  bool _isLoading = true;
  String? _errorMessage;

  // Curated demo personas for quick 1-click hackathon evaluation
  final List<Map<String, String>> _curatedPersonas = [
    {
      'id': 'BEN-KA-0001',
      'name': 'Swathi B. (Demo)',
      'fps': 'Malleshwaram Seva Kendra',
      'fps_id': 'FPS-KA-BLR-001',
      'persona': 'Resident Beneficiary (Home FPS Collector)',
    },
    {
      'id': 'BEN-KA-0005',
      'name': 'Sunita Devi (Demo)',
      'fps': 'Bellandur Outer Ring Road',
      'fps_id': 'FPS-KA-BLR-005',
      'persona': 'Migrant Construction Worker (High Portability Surge)',
    },
    {
      'id': 'BEN-KA-0015',
      'name': 'Ramesh K. (Demo)',
      'fps': 'Peenya Industrial Area',
      'fps_id': 'FPS-KA-BLR-013',
      'persona': 'Industrial Sector Beneficiary (Weekly Shift Worker)',
    },
  ];

  @override
  void initState() {
    super.initState();
    _apiService = widget.apiService ?? ApiService();
    _loadBeneficiaries();
  }

  Future<void> _loadBeneficiaries() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final list = await _apiService.fetchBeneficiaries(limit: 60);
      setState(() {
        _beneficiaries = list;
        if (_beneficiaries.isNotEmpty) {
          _selectedBeneficiary = _beneficiaries.first;
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load demo beneficiaries: $e';
        _isLoading = false;
      });
    }
  }

  void _proceedToBeneficiaryHome() {
    if (_selectedBeneficiary == null) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => BeneficiaryHomeScreen(
          beneficiaryId: _selectedBeneficiary!.pseudonymousBeneficiaryId,
          apiService: _apiService,
        ),
      ),
    );
  }

  void _proceedToAdminDashboard() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AdminDashboardScreen(
          apiService: _apiService,
        ),
      ),
    );
  }

  void _selectCuratedPersona(String pseudoId) {
    final match = _beneficiaries.firstWhere(
      (b) => b.pseudonymousBeneficiaryId == pseudoId,
      orElse: () => Beneficiary(
        id: 1,
        pseudonymousBeneficiaryId: pseudoId,
        nameForDemo: 'Demo Citizen',
        registeredFpsId: 'FPS-KA-BLR-001',
        language: 'kn',
        status: 'ACTIVE',
      ),
    );

    setState(() {
      _selectedBeneficiary = match;
    });

    _proceedToBeneficiaryHome();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.bgLight,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // GovTech Header Badge
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppConstants.accentAmber.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppConstants.accentAmber.withValues(alpha: 0.5),
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.lock_clock_outlined,
                              size: 16, color: AppConstants.accentAmber),
                          SizedBox(width: 8),
                          Text(
                            'DEMO MODE — DEMO NAGAR DISTRICT',
                            style: TextStyle(
                              color: AppConstants.accentAmber,
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Brand Icon & Titles
                  Center(
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: AppConstants.primaryNavy,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: AppConstants.primaryNavy.withValues(alpha: 0.25),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.sync_alt_rounded,
                        color: Colors.white,
                        size: 38,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  const Text(
                    AppConstants.appName,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      color: AppConstants.primaryNavy,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Forward-Looking Beneficiary Intent for Pre-Dispatch PDS Demand Forecasting',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppConstants.textSecondary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 28),

                  // District Admin Login Action Card (Top Highlight)
                  Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: AppConstants.secondaryNavy.withValues(alpha: 0.4),
                        width: 1.5,
                      ),
                    ),
                    color: Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppConstants.secondaryNavy
                                      .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.admin_panel_settings_outlined,
                                  color: AppConstants.secondaryNavy,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'District Admin Portal',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        color: AppConstants.primaryNavy,
                                      ),
                                    ),
                                    Text(
                                      'Demo Nagar / Bengaluru Urban Executive Decision Support',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppConstants.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _proceedToAdminDashboard,
                            icon: const Icon(Icons.dashboard_customize_outlined,
                                size: 18),
                            label: const Text(
                              'Login as District Admin (Demo Nagar)',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppConstants.primaryNavy,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Beneficiary Authentication Card
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: AppConstants.cardBorder),
                    ),
                    color: Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(22),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppConstants.accentBlue
                                      .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.person_pin_circle_outlined,
                                    color: AppConstants.accentBlue, size: 22),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Beneficiary Portal Sign-In',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: AppConstants.primaryNavy,
                                      ),
                                    ),
                                    Text(
                                      'Select a citizen profile to simulate forward-looking intent',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppConstants.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),

                          // Quick Curated Personas
                          Text(
                            'QUICK BENCHMARK PERSONAS',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppConstants.textSecondary,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 10),

                          ..._curatedPersonas.map((persona) {
                            final isSelected = _selectedBeneficiary
                                    ?.pseudonymousBeneficiaryId ==
                                persona['id'];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: InkWell(
                                onTap: () =>
                                    _selectCuratedPersona(persona['id']!),
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? AppConstants.accentBlue
                                            .withValues(alpha: 0.08)
                                        : AppConstants.bgLight,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: isSelected
                                          ? AppConstants.accentBlue
                                          : AppConstants.cardBorder,
                                      width: isSelected ? 1.5 : 1.0,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 16,
                                        backgroundColor: isSelected
                                            ? AppConstants.accentBlue
                                            : AppConstants.secondaryNavy,
                                        child: Text(
                                          persona['name']!.substring(0, 1),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              persona['name']!,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 12,
                                                color:
                                                    AppConstants.primaryNavy,
                                              ),
                                            ),
                                            Text(
                                              persona['persona']!,
                                              style: TextStyle(
                                                fontSize: 10,
                                                color:
                                                    AppConstants.textSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Icon(
                                        Icons.arrow_forward_ios,
                                        size: 12,
                                        color: AppConstants.textSecondary,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }),

                          const SizedBox(height: 12),

                          // Dropdown for full list
                          if (_isLoading)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.all(12),
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          else if (_errorMessage != null)
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _errorMessage!,
                                style: TextStyle(
                                    color: Colors.red.shade800, fontSize: 12),
                              ),
                            )
                          else
                            DropdownButtonFormField<Beneficiary>(
                              initialValue: _selectedBeneficiary,
                              decoration: InputDecoration(
                                labelText: 'Or Select from 2,000 Beneficiaries',
                                prefixIcon: const Icon(Icons.people_outline,
                                    color: AppConstants.primaryNavy, size: 20),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 12),
                              ),
                              items: _beneficiaries.map((b) {
                                return DropdownMenuItem<Beneficiary>(
                                  value: b,
                                  child: Text(
                                    '${b.pseudonymousBeneficiaryId} — ${b.nameForDemo}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                );
                              }).toList(),
                              onChanged: (val) {
                                setState(() {
                                  _selectedBeneficiary = val;
                                });
                              },
                            ),

                          const SizedBox(height: 16),

                          // Main CTA
                          ElevatedButton.icon(
                            onPressed: _selectedBeneficiary != null
                                ? _proceedToBeneficiaryHome
                                : null,
                            icon: const Icon(Icons.login_rounded, size: 18),
                            label: const Text(
                              'Continue as Beneficiary',
                              style: TextStyle(
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
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Bottom System Diagnostics Link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) =>
                                  ConnectivityScreen(apiService: _apiService),
                            ),
                          );
                        },
                        icon: const Icon(Icons.developer_board_outlined,
                            size: 16, color: AppConstants.secondaryNavy),
                        label: const Text(
                          'View System Diagnostics & Pipeline Flow',
                          style: TextStyle(
                            color: AppConstants.secondaryNavy,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),
                  Center(
                    child: Text(
                      'DEMO DATA — NOT GOVERNMENT DATA',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0,
                        color: Colors.grey.shade500,
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
  }
}
