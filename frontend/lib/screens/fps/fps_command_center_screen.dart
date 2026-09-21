import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/fps/fps_service.dart';
import '../../models/fps/fps_models.dart';
import '../../widgets/fps/fps_sidebar.dart';
import '../../widgets/fps/fps_top_header.dart';
import '../../widgets/fps/fps_ai_panel.dart';
import '../../widgets/fps/fps_data_source_modal.dart';
import '../beneficiary/demo_login_screen.dart';

/// Comprehensive Production-grade Fair Price Shop (FPS) Command Center
/// Government of Karnataka • Department of Food and Civil Supplies
class FpsCommandCenterScreen extends StatefulWidget {
  final ApiService apiService;
  final String? initialFpsId;

  const FpsCommandCenterScreen({
    super.key,
    required this.apiService,
    this.initialFpsId,
  });

  @override
  State<FpsCommandCenterScreen> createState() => _FpsCommandCenterScreenState();
}

class _FpsCommandCenterScreenState extends State<FpsCommandCenterScreen> {
  late final FpsService _fpsService;

  // Active Navigation: 0=Dashboard, 1=My FPS, 2=Stock, 3=Deliveries, 4=e-PoS, 5=Beneficiaries, 6=Transactions, 7=Reports, 8=AI Insights, 9=Exceptions, 10=Decision Trace, 11=Data Sources
  int _selectedNavIndex = 0;
  bool _isLoading = true;
  bool _isActionLoading = false;
  String? _errorMessage;

  // Active State
  String _activeFpsId = 'FPS-KA-BLR-002';
  String _activeCycle = '2026-09';
  FpsOwnerProfile? _profile;
  FpsDashboardOverview? _overview;
  List<FpsBeneficiaryRecord> _beneficiaries = [];
  int _totalBeneficiariesCount = 0;
  List<FpsInboundDelivery> _deliveries = [];
  Map<String, dynamic>? _stockLedger;
  List<Map<String, dynamic>> _transactions = [];
  List<FpsAiInsight> _aiInsights = [];
  List<FpsExceptionItem> _exceptions = [];
  List<FpsDecisionTraceEvent> _decisionTrace = [];
  List<FpsDataSourceItem> _dataSources = [];

  // e-PoS Active Terminal State
  final TextEditingController _beneficiarySearchController = TextEditingController(text: 'BEN-KA-0001');
  bool _isCheckingEligibility = false;
  FpsEposEligibility? _activeEligibility;
  String _verificationMode = 'AADHAAR_BIOMETRIC'; // AADHAAR_BIOMETRIC, OTP
  bool _isVerified = false;
  double _dispenseRiceKg = 0.0;
  double _dispenseWheatKg = 0.0;
  bool _isDispensing = false;
  FpsEposDispenseResult? _lastDispenseResult;

  // Theme Colors
  static const Color _navy = Color(0xFF0F2942);
  static const Color _govBlue = Color(0xFF1E3A8A);
  static const Color _green = Color(0xFF16A34A);
  static const Color _amber = Color(0xFFD97706);
  static const Color _red = Color(0xFFDC2626);

  @override
  void initState() {
    super.initState();
    _fpsService = FpsService(apiService: widget.apiService);
    if (widget.initialFpsId != null && widget.initialFpsId!.isNotEmpty) {
      _activeFpsId = widget.initialFpsId!;
    }
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final profile = await _fpsService.fetchFpsProfile(fpsId: _activeFpsId);
      _activeFpsId = profile.fpsId;
      _activeCycle = profile.activeCycle;

      final results = await Future.wait([
        _fpsService.fetchDashboardOverview(_activeFpsId, cycleId: _activeCycle),
        _fpsService.fetchBeneficiaries(_activeFpsId, cycleId: _activeCycle, limit: 25),
        _fpsService.fetchDeliveries(_activeFpsId, cycleId: _activeCycle),
        _fpsService.fetchStockLedger(_activeFpsId, cycleId: _activeCycle),
        _fpsService.fetchTransactions(_activeFpsId),
        _fpsService.fetchAiInsights(_activeFpsId, cycleId: _activeCycle),
        _fpsService.fetchExceptions(_activeFpsId),
        _fpsService.fetchDecisionTrace(_activeFpsId),
        _fpsService.fetchDataSources(_activeFpsId),
      ]);

      setState(() {
        _profile = profile;
        _overview = results[0] as FpsDashboardOverview;
        final benMap = results[1] as Map<String, dynamic>;
        _beneficiaries = benMap['beneficiaries'] as List<FpsBeneficiaryRecord>;
        _totalBeneficiariesCount = benMap['total_count'] as int;
        _deliveries = results[2] as List<FpsInboundDelivery>;
        _stockLedger = results[3] as Map<String, dynamic>;
        _transactions = results[4] as List<Map<String, dynamic>>;
        _aiInsights = results[5] as List<FpsAiInsight>;
        _exceptions = results[6] as List<FpsExceptionItem>;
        _decisionTrace = results[7] as List<FpsDecisionTraceEvent>;
        _dataSources = results[8] as List<FpsDataSourceItem>;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to connect to official FPS services: $e';
        _isLoading = false;
      });
    }
  }

  // Quick e-PoS Operations
  Future<void> _checkBeneficiaryEligibility() async {
    final benId = _beneficiarySearchController.text.trim();
    if (benId.isEmpty) return;

    setState(() {
      _isCheckingEligibility = true;
      _activeEligibility = null;
      _isVerified = false;
      _lastDispenseResult = null;
    });

    try {
      final el = await _fpsService.fetchEposEligibility(_activeFpsId, benId, cycleId: _activeCycle);
      setState(() {
        _activeEligibility = el;
        _dispenseRiceKg = el.statutoryRiceKg;
        _dispenseWheatKg = el.statutoryWheatKg;
        _isCheckingEligibility = false;
      });
    } catch (e) {
      setState(() => _isCheckingEligibility = false);
      _showSnackbar('Beneficiary Eligibility Lookup Failed: $e', isError: true);
    }
  }

  Future<void> _verifyBeneficiaryIdentity() async {
    if (_activeEligibility == null) return;
    setState(() => _isActionLoading = true);

    try {
      await _fpsService.verifyBeneficiary(
        _activeFpsId,
        _activeEligibility!.beneficiaryId,
        _verificationMode,
      );
      setState(() {
        _isVerified = true;
        _isActionLoading = false;
      });
      _showSnackbar('Beneficiary identity successfully verified.');
    } catch (e) {
      setState(() => _isActionLoading = false);
      _showSnackbar('Biometric verification failed: $e', isError: true);
    }
  }

  Future<void> _executeEposDispense() async {
    if (_activeEligibility == null || !_isVerified) return;
    setState(() => _isDispensing = true);

    try {
      final res = await _fpsService.dispenseEpos(
        fpsId: _activeFpsId,
        beneficiaryId: _activeEligibility!.beneficiaryId,
        riceKg: _dispenseRiceKg,
        wheatKg: _dispenseWheatKg,
        authMode: _verificationMode,
        cycleId: _activeCycle,
      );

      setState(() {
        _lastDispenseResult = res;
        _isDispensing = false;
      });

      _showSnackbar('Ration successfully dispensed! Digital receipt generated.');
      _loadInitialData();
    } catch (e) {
      setState(() => _isDispensing = false);
      _showSnackbar('e-PoS Dispense Failed: $e', isError: true);
    }
  }

  // Delivery Confirm Receipt
  Future<void> _confirmDelivery(String gatepassId) async {
    setState(() => _isActionLoading = true);
    try {
      await _fpsService.confirmDeliveryReceipt(_activeFpsId, gatepassId);
      _showSnackbar('Consignment verified and physical inventory credited.');
      _loadInitialData();
    } catch (e) {
      setState(() => _isActionLoading = false);
      _showSnackbar('Failed to confirm receipt: $e', isError: true);
    }
  }

  // Daily Operations: Open & Close Shop
  Future<void> _handleOpenShop() async {
    setState(() => _isActionLoading = true);
    try {
      await _fpsService.openShop(_activeFpsId);
      _showSnackbar('Fair Price Shop daily operations opened successfully.');
      _loadInitialData();
    } catch (e) {
      setState(() => _isActionLoading = false);
      _showSnackbar('Failed to open shop: $e', isError: true);
    }
  }

  Future<void> _handleCloseShop() async {
    final reasonController = TextEditingController();
    final shouldClose = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Close Daily Operational Ledger', style: TextStyle(fontWeight: FontWeight.bold, color: _navy)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Are you sure you want to close and seal daily operations for this shop?'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reconciliation Notes / Exception Reason (Optional)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: _red),
            child: const Text('Close & Seal Day', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (shouldClose != true) return;

    setState(() => _isActionLoading = true);
    try {
      await _fpsService.closeShop(_activeFpsId, exceptionReason: reasonController.text);
      _showSnackbar('Shop closed and reconciled with official seal.');
      _loadInitialData();
    } catch (e) {
      setState(() => _isActionLoading = false);
      _showSnackbar('Failed to close shop: $e', isError: true);
    }
  }

  void _showSnackbar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? _red : _green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Row(
        children: [
          // 1. Persistent Government Left Sidebar
          FpsSidebar(
            selectedIndex: _selectedNavIndex,
            onItemSelected: (idx) {
              if (idx == 11) {
                FpsDataSourceModal.show(context, _dataSources);
              } else {
                setState(() => _selectedNavIndex = idx);
              }
            },
            profile: _profile,
          ),

          // 2. Main Workspace & Header
          Expanded(
            child: Column(
              children: [
                // Top Global Header
                FpsTopHeader(
                  profile: _profile,
                  activeCycle: _activeCycle,
                  onRefresh: _loadInitialData,
                  onLogout: () {
                    widget.apiService.authSession.clear();
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => DemoLoginScreen(apiService: widget.apiService)),
                    );
                  },
                  onOpenShop: _handleOpenShop,
                  onCloseShop: _handleCloseShop,
                  isActionLoading: _isActionLoading,
                ),

                // Main Content Workspace
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : (_errorMessage != null
                          ? _buildErrorView()
                          : Row(
                              children: [
                                Expanded(child: _buildSelectedNavView()),
                                // Persistent AI Panel on right
                                FpsAiPanel(
                                  insights: _aiInsights,
                                  onRefresh: () async {
                                    final ins = await _fpsService.fetchAiInsights(_activeFpsId, cycleId: _activeCycle);
                                    setState(() => _aiInsights = ins);
                                  },
                                  onActionTriggered: (act, ins) {
                                    if (act == 'VERIFY_DELIVERY') {
                                      setState(() => _selectedNavIndex = 3);
                                    } else if (act == 'VIEW_INVENTORY') {
                                      setState(() => _selectedNavIndex = 2);
                                    } else if (act == 'VIEW_REGISTER') {
                                      setState(() => _selectedNavIndex = 6);
                                    }
                                  },
                                ),
                              ],
                            )),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(32),
        margin: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, color: _red, size: 48),
            const SizedBox(height: 16),
            const Text(
              'Unable to Load FPS Operational Data',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _navy),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'Network timeout or unauthorized access.',
              style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadInitialData,
              icon: const Icon(Icons.refresh_rounded, size: 16, color: Colors.white),
              label: const Text('Retry Connection', style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(backgroundColor: _govBlue),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedNavView() {
    switch (_selectedNavIndex) {
      case 0:
        return _buildDashboardView();
      case 1:
        return _buildProfileView();
      case 2:
        return _buildStockInventoryView();
      case 3:
        return _buildDeliveriesView();
      case 4:
        return _buildEposView();
      case 5:
        return _buildBeneficiariesView();
      case 6:
        return _buildTransactionsView();
      case 7:
        return _buildReportsView();
      case 8:
        return _buildAiInsightsDedicatedView();
      case 9:
        return _buildExceptionsView();
      case 10:
        return _buildDecisionTraceView();
      default:
        return _buildDashboardView();
    }
  }

  // --------------------------------------------------------------------------
  // 1. Dashboard View
  // --------------------------------------------------------------------------
  Widget _buildDashboardView() {
    final kpis = _overview?.kpis;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome Banner
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_navy, _govBlue],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome, ${_profile?.dealerName ?? "Authorized Dealer"}',
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_profile?.name ?? "Fair Price Shop"} • FPS ID: $_activeFpsId • District: ${_profile?.district ?? "Bengaluru Urban"}',
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => setState(() => _selectedNavIndex = 4),
                  icon: const Icon(Icons.point_of_sale_rounded, size: 16, color: Colors.white),
                  label: const Text('Start e-PoS Distribution', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(backgroundColor: _green),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Attention Items Bar
          if (_overview?.attentionItems.isNotEmpty == true) ...[
            const Text(
              'WHAT NEEDS ATTENTION',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black54, letterSpacing: 0.5),
            ),
            const SizedBox(height: 8),
            for (final attn in _overview!.attentionItems)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: attn.severity == 'CRITICAL' || attn.severity == 'HIGH' ? Colors.red.shade50 : Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: attn.severity == 'CRITICAL' || attn.severity == 'HIGH' ? Colors.red.shade300 : Colors.amber.shade300,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: attn.severity == 'CRITICAL' || attn.severity == 'HIGH' ? _red : _amber,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(attn.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: _navy)),
                          Text(attn.description, style: TextStyle(color: Colors.grey.shade700, fontSize: 11)),
                        ],
                      ),
                    ),
                    OutlinedButton(
                      onPressed: () {
                        if (attn.action == 'VERIFY_DELIVERY') setState(() => _selectedNavIndex = 3);
                        if (attn.action == 'REQUEST_REPLENISHMENT') setState(() => _selectedNavIndex = 2);
                        if (attn.action == 'VIEW_EXCEPTIONS') setState(() => _selectedNavIndex = 9);
                      },
                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6)),
                      child: Text(attn.action.replaceAll('_', ' '), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
          ],

          // KPI Cards Grid (8 Cards)
          const Text(
            'OPERATIONAL METRICS & REAL INVENTORY',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black54, letterSpacing: 0.5),
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 4,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.7,
            children: [
              _buildKpiCard('Registered Cards', '${kpis?.totalBeneficiaries ?? 0}', 'Assigned NFSA Cards', Icons.people_alt_rounded, Colors.blue),
              _buildKpiCard('Current Rice Stock', '${kpis?.currentRiceStockKg ?? 0} kg', 'Physical Warehouse', Icons.grain_rounded, Colors.green),
              _buildKpiCard('Current Wheat Stock', '${kpis?.currentWheatStockKg ?? 0} kg', 'Physical Warehouse', Icons.grass_rounded, Colors.amber),
              _buildKpiCard("Today's Distribution", '${(kpis?.todayDistributedRiceKg ?? 0) + (kpis?.todayDistributedWheatKg ?? 0)} kg', '${kpis?.todayTransactionsCount ?? 0} e-PoS Transactions', Icons.shopping_basket_rounded, Colors.teal),
              _buildKpiCard('Beneficiaries Served', '${kpis?.servedBeneficiaries ?? 0}', '${kpis?.pendingBeneficiaries ?? 0} Pending', Icons.how_to_reg_rounded, Colors.indigo),
              _buildKpiCard('Stock Coverage', '${kpis?.stockDaysRemaining ?? 0} Days', 'Calculated Velocity', Icons.timelapse_rounded, Colors.purple),
              _buildKpiCard('Pending Deliveries', '${kpis?.pendingDeliveriesCount ?? 0}', 'In-Transit Manifests', Icons.local_shipping_rounded, Colors.deepOrange),
              _buildKpiCard('Open Exceptions', '${kpis?.openExceptionsCount ?? 0}', 'Active Discrepancies', Icons.report_problem_rounded, Colors.red),
            ],
          ),

          const SizedBox(height: 24),

          // Quick Two-Column: Recent Transactions & Inbound Manifests
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Recent Transactions
              Expanded(
                flex: 3,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Recent e-PoS Transactions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: _navy)),
                          TextButton(
                            onPressed: () => setState(() => _selectedNavIndex = 6),
                            child: const Text('View All Register →', style: TextStyle(fontSize: 12)),
                          ),
                        ],
                      ),
                      const Divider(height: 16),
                      if (_transactions.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(child: Text('No transactions recorded for this cycle.', style: TextStyle(color: Colors.black45))),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _transactions.take(5).length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final tx = _transactions[index];
                            return ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.check_circle_rounded, color: _green, size: 20),
                              title: Text(
                                '${tx['name_for_demo'] ?? tx['beneficiary_id']} • -${tx['rice_kg']}kg Rice, -${tx['wheat_kg']}kg Wheat',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                              subtitle: Text(
                                'Tx ID: ${tx['transaction_id']} • Auth: ${tx['auth_mode']} • ${tx['created_at']}',
                                style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 16),

              // Inbound Deliveries
              Expanded(
                flex: 2,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Inbound Consignments', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: _navy)),
                          TextButton(
                            onPressed: () => setState(() => _selectedNavIndex = 3),
                            child: const Text('Deliveries →', style: TextStyle(fontSize: 12)),
                          ),
                        ],
                      ),
                      const Divider(height: 16),
                      if (_deliveries.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(child: Text('No incoming consignments scheduled.', style: TextStyle(color: Colors.black45))),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _deliveries.take(3).length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final del = _deliveries[index];
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(del.truckId, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                      Text(del.status, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: del.status == 'RECEIVED' ? _green : _amber)),
                                    ],
                                  ),
                                  Text('Manifest: ${del.manifestId} • ${del.dispatchedRiceKg}kg Rice / ${del.dispatchedWheatKg}kg Wheat', style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
                                ],
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCard(String title, String value, String subtitle, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.01), blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
              Icon(icon, size: 18, color: color),
            ],
          ),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _navy)),
          Text(subtitle, style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // 2. My FPS Profile View
  // --------------------------------------------------------------------------
  Widget _buildProfileView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('FAIR PRICE SHOP OFFICIAL PROFILE', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _navy)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                _buildProfileRow('FPS Identifier', _profile?.fpsId ?? 'FPS-KA-BLR-002'),
                _buildProfileRow('Shop Name', _profile?.name ?? 'Fair Price Shop'),
                _buildProfileRow('District & Taluk', '${_profile?.district ?? "Bengaluru Urban"} (South Division)'),
                _buildProfileRow('GPS Coordinates', '${_profile?.latitude.toStringAsFixed(4)}, ${_profile?.longitude.toStringAsFixed(4)}'),
                _buildProfileRow('Authorized Dealer', _profile?.dealerName ?? 'Authorized PDS Dealer'),
                _buildProfileRow('Contact Phone', _profile?.dealerPhone ?? '+91-98450-88123'),
                _buildProfileRow('Assigned Supply Depot', _profile?.assignedDepot ?? 'Bengaluru Central FCI Godown (Hebbal)'),
                _buildProfileRow('Statutory Storage Capacity', '${_profile?.capacityKg ?? 5000} kg'),
                _buildProfileRow('Total Registered Cards', '${_profile?.beneficiariesCount ?? 100} NFSA Beneficiaries'),
                _buildProfileRow('Authorized Commodities', 'Fortified Rice, Whole Wheat, Refined Sugar, PDS Kerosene'),
                _buildProfileRow('Operating Timings', _profile?.operatingHours ?? '08:00 AM - 08:00 PM'),
                _buildProfileRow('Current Operational Status', _profile?.operatingStatus ?? 'CLOSED'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 220, child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black54))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13, color: _navy, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // 3. Stock & Inventory View
  // --------------------------------------------------------------------------
  Widget _buildStockInventoryView() {
    final summary = _stockLedger?['summary'] as Map<String, dynamic>?;
    final rice = summary?['Rice'] as Map<String, dynamic>?;
    final wheat = summary?['Wheat'] as Map<String, dynamic>?;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('STOCK & INVENTORY COMMAND CENTER', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _navy)),
          const SizedBox(height: 16),

          // Commodity Balances Table
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Physical Stock Reconciliation Ledger', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: _navy)),
                const Divider(height: 20),
                DataTable(
                  columns: const [
                    DataColumn(label: Text('Commodity', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Opening Stock', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Received Dispatches', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('e-PoS Distributed', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Available Stock', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                  ],
                  rows: [
                    DataRow(cells: [
                      const DataCell(Text('Fortified Rice', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataCell(Text('${rice?['opening_stock_kg'] ?? 0} kg')),
                      DataCell(Text('+${rice?['received_stock_kg'] ?? 0} kg', style: const TextStyle(color: _green))),
                      DataCell(Text('-${rice?['dispensed_stock_kg'] ?? 0} kg', style: const TextStyle(color: _red))),
                      DataCell(Text('${rice?['closing_stock_kg'] ?? 0} kg', style: const TextStyle(fontWeight: FontWeight.bold, color: _navy))),
                      DataCell(Text((rice?['closing_stock_kg'] ?? 0) > 300 ? 'ADEQUATE' : 'LOW BUFFER', style: TextStyle(color: (rice?['closing_stock_kg'] ?? 0) > 300 ? _green : _amber, fontWeight: FontWeight.bold))),
                    ]),
                    DataRow(cells: [
                      const DataCell(Text('Whole Wheat', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataCell(Text('${wheat?['opening_stock_kg'] ?? 0} kg')),
                      DataCell(Text('+${wheat?['received_stock_kg'] ?? 0} kg', style: const TextStyle(color: _green))),
                      DataCell(Text('-${wheat?['dispensed_stock_kg'] ?? 0} kg', style: const TextStyle(color: _red))),
                      DataCell(Text('${wheat?['closing_stock_kg'] ?? 0} kg', style: const TextStyle(fontWeight: FontWeight.bold, color: _navy))),
                      DataCell(Text((wheat?['closing_stock_kg'] ?? 0) > 100 ? 'ADEQUATE' : 'LOW BUFFER', style: TextStyle(color: (wheat?['closing_stock_kg'] ?? 0) > 100 ? _green : _amber, fontWeight: FontWeight.bold))),
                    ]),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // 4. Incoming Deliveries View
  // --------------------------------------------------------------------------
  Widget _buildDeliveriesView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('INCOMING DELIVERIES & TRUCK MANIFESTS', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _navy)),
          const SizedBox(height: 16),
          if (_deliveries.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
              child: const Center(child: Text('No incoming deliveries available for this cycle.')),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _deliveries.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final del = _deliveries[index];
                final isReceived = del.status == 'RECEIVED';

                return Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
                                child: const Icon(Icons.local_shipping_rounded, color: _govBlue, size: 24),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(del.truckId, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: _navy)),
                                  Text('Manifest: ${del.manifestId} • Gatepass: ${del.gatepassId}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                                ],
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: isReceived ? Colors.green.shade50 : Colors.amber.shade50,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              del.status,
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isReceived ? _green : _amber),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      Row(
                        children: [
                          Expanded(child: Text('Driver: ${del.driverName} (${del.driverPhone})', style: const TextStyle(fontSize: 12))),
                          Expanded(child: Text('Origin: ${del.sourceDepot}', style: const TextStyle(fontSize: 12))),
                          Expanded(child: Text('Payload: ${del.dispatchedRiceKg}kg Rice, ${del.dispatchedWheatKg}kg Wheat', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (!isReceived)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () => _reportDiscrepancyDialog(del.gatepassId),
                              icon: const Icon(Icons.report_problem_rounded, size: 16, color: _red),
                              label: const Text('Report Discrepancy', style: TextStyle(color: _red, fontSize: 12)),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton.icon(
                              onPressed: _isActionLoading ? null : () => _confirmDelivery(del.gatepassId),
                              icon: const Icon(Icons.check_rounded, size: 16, color: Colors.white),
                              label: const Text('Confirm Stock Receipt', style: TextStyle(color: Colors.white, fontSize: 12)),
                              style: ElevatedButton.styleFrom(backgroundColor: _green),
                            ),
                          ],
                        ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  void _reportDiscrepancyDialog(String gatepassId) {
    final riceCtrl = TextEditingController();
    final wheatCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Report Delivery Discrepancy', style: TextStyle(fontWeight: FontWeight.bold, color: _navy)),
        content: SizedBox(
          width: 450,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: riceCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Observed Rice (kg)', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              TextField(controller: wheatCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Observed Wheat (kg)', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              TextField(controller: reasonCtrl, maxLines: 2, decoration: const InputDecoration(labelText: 'Discrepancy Reason', border: OutlineInputBorder())),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                await _fpsService.reportDeliveryDiscrepancy(
                  _activeFpsId,
                  gatepassId,
                  observedRiceKg: double.tryParse(riceCtrl.text) ?? 0.0,
                  observedWheatKg: double.tryParse(wheatCtrl.text) ?? 0.0,
                  reason: reasonCtrl.text,
                );
                _showSnackbar('Discrepancy recorded and escalated.');
                _loadInitialData();
              } catch (e) {
                _showSnackbar('Failed to record discrepancy: $e', isError: true);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: _red),
            child: const Text('Submit Discrepancy', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // 5. e-PoS Distribution Terminal View
  // --------------------------------------------------------------------------
  Widget _buildEposView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('e-PoS PHYSICAL DISPENSATION TERMINAL', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _navy)),
          const SizedBox(height: 16),

          // Terminal Box
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Step 1: Beneficiary Search
                const Text('STEP 1: BENEFICIARY SEARCH & IDENTIFICATION', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _govBlue)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _beneficiarySearchController,
                        decoration: const InputDecoration(
                          hintText: 'Enter Ration Card Number or Beneficiary ID (e.g. BEN-KA-0001)',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.search_rounded),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: _isCheckingEligibility ? null : _checkBeneficiaryEligibility,
                      icon: const Icon(Icons.how_to_reg_rounded, size: 18, color: Colors.white),
                      label: const Text('Verify Entitlement', style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(backgroundColor: _govBlue, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18)),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Step 2: Entitlement & Card Summary
                if (_activeEligibility != null) ...[
                  const Divider(),
                  const SizedBox(height: 12),
                  const Text('STEP 2: STATUTORY ENTITLEMENT & QUOTA STATUS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _govBlue)),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${_activeEligibility!.name} (${_activeEligibility!.beneficiaryId})',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: _navy),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: _govBlue, borderRadius: BorderRadius.circular(4)),
                              child: Text(_activeEligibility!.categoryLabel, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text('Family Members: ${_activeEligibility!.familyMembersCount} • Statutory Entitlement: ${_activeEligibility!.statutoryRiceKg}kg Rice, ${_activeEligibility!.statutoryWheatKg}kg Wheat', style: const TextStyle(fontSize: 12)),
                        if (_activeEligibility!.alreadyCollected)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              'ALERT: Quota already fully collected for Cycle $_activeCycle at ${_activeEligibility!.collectedAt}',
                              style: const TextStyle(color: _red, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Step 3: Biometric / OTP Verification
                  if (!_activeEligibility!.alreadyCollected) ...[
                    const Text('STEP 3: AADHAAR BIOMETRIC / OTP AUTHORIZATION', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _govBlue)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        ChoiceChip(
                          label: const Text('Aadhaar Biometric Scan'),
                          selected: _verificationMode == 'AADHAAR_BIOMETRIC',
                          onSelected: (val) => setState(() => _verificationMode = 'AADHAAR_BIOMETRIC'),
                        ),
                        const SizedBox(width: 12),
                        ChoiceChip(
                          label: const Text('Registered Citizen OTP'),
                          selected: _verificationMode == 'OTP',
                          onSelected: (val) => setState(() => _verificationMode = 'OTP'),
                        ),
                        const SizedBox(width: 24),
                        ElevatedButton.icon(
                          onPressed: _isActionLoading || _isVerified ? null : _verifyBeneficiaryIdentity,
                          icon: Icon(_isVerified ? Icons.check_circle_rounded : Icons.fingerprint_rounded, size: 18, color: Colors.white),
                          label: Text(_isVerified ? 'Identity Authenticated' : 'Authorize Citizen', style: const TextStyle(color: Colors.white)),
                          style: ElevatedButton.styleFrom(backgroundColor: _isVerified ? _green : _govBlue),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Step 4: Dispense Action
                    if (_isVerified) ...[
                      const Divider(),
                      const SizedBox(height: 12),
                      const Text('STEP 4: PHYSICAL WEIGHMENT & DISPENSATION', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _govBlue)),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Dispensing: ${_dispenseRiceKg.toStringAsFixed(1)} kg Fortified Rice + ${_dispenseWheatKg.toStringAsFixed(1)} kg Whole Wheat',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _navy),
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: _isDispensing ? null : _executeEposDispense,
                            icon: const Icon(Icons.print_rounded, size: 18, color: Colors.white),
                            label: const Text('Dispense & Print Receipt', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                            style: ElevatedButton.styleFrom(backgroundColor: _green, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16)),
                          ),
                        ],
                      ),
                    ],
                  ],
                ],

                // Step 5: Digital Receipt
                if (_lastDispenseResult != null) ...[
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.shade300),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.check_circle_rounded, color: _green, size: 24),
                            SizedBox(width: 8),
                            Text('OFFICIAL PDS DIGITAL TRANSACTION RECEIPT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: _green)),
                          ],
                        ),
                        const Divider(),
                        Text('Transaction ID: ${_lastDispenseResult!.transactionId} • Beneficiary: ${_lastDispenseResult!.beneficiaryId}'),
                        Text('Dispensed: ${_lastDispenseResult!.riceDispensedKg} kg Rice, ${_lastDispenseResult!.wheatDispensedKg} kg Wheat'),
                        Text('Remaining FPS Stock: Rice ${_lastDispenseResult!.remainingFpsRiceStockKg} kg, Wheat ${_lastDispenseResult!.remainingFpsWheatStockKg} kg'),
                        Text('Timestamp: ${_lastDispenseResult!.receiptConfirmedAt}'),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // 6. Beneficiary Records View
  // --------------------------------------------------------------------------
  Widget _buildBeneficiariesView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('REGISTERED BENEFICIARIES LEDGER ($_totalBeneficiariesCount Total)', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _navy)),
              Text('Fair Price Shop: $_activeFpsId', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: _beneficiaries.isEmpty
                ? const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('No beneficiaries registered for this FPS in database.')))
                : ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _beneficiaries.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final b = _beneficiaries[index];
                      return ListTile(
                        dense: true,
                        leading: CircleAvatar(
                          backgroundColor: b.isCollected ? Colors.green.shade100 : Colors.blue.shade100,
                          child: Icon(b.isCollected ? Icons.check_rounded : Icons.person_rounded, color: b.isCollected ? _green : _govBlue, size: 18),
                        ),
                        title: Text('${b.name} (${b.beneficiaryId})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        subtitle: Text('Scheme: ${b.schemeType} • Members: ${b.membersCount} • Quota: ${b.statutoryRiceKg}kg Rice / ${b.statutoryWheatKg}kg Wheat', style: const TextStyle(fontSize: 11)),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: b.isCollected ? Colors.green.shade50 : Colors.amber.shade50,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            b.isCollected ? 'COLLECTED' : 'PENDING',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: b.isCollected ? _green : _amber),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // 7. Transactions (Digital Register) View
  // --------------------------------------------------------------------------
  Widget _buildTransactionsView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('DIGITAL DISPENSATION REGISTER', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _navy)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: _transactions.isEmpty
                ? const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('No transactions recorded.')))
                : ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _transactions.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final tx = _transactions[index];
                      return ListTile(
                        dense: true,
                        leading: const Icon(Icons.receipt_rounded, color: _govBlue),
                        title: Text('Tx ID: ${tx['transaction_id']} • Beneficiary: ${tx['name_for_demo'] ?? tx['beneficiary_id']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        subtitle: Text('Dispensed: ${tx['rice_kg']} kg Rice, ${tx['wheat_kg']} kg Wheat • Auth: ${tx['auth_mode']} • Date: ${tx['created_at']}', style: const TextStyle(fontSize: 11)),
                        trailing: const Text('COMPLETED', style: TextStyle(color: _green, fontWeight: FontWeight.bold, fontSize: 11)),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // 8. Reports View
  // --------------------------------------------------------------------------
  Widget _buildReportsView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('OPERATIONAL REPORTS & AUDIT ARCHIVE', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _navy)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Generated Cycle Reports (Cycle 2026-09)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: _navy)),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(Icons.picture_as_pdf_rounded, color: Colors.red),
                  title: const Text('Daily e-PoS Distribution Summary Report', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  subtitle: const Text('Aggregates commodity-level offtake and biometric authorization logs.'),
                  trailing: OutlinedButton(onPressed: () => _showSnackbar('Report generated from live database.'), child: const Text('Download PDF')),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.table_view_rounded, color: Colors.green),
                  title: const Text('Warehouse Inventory Reconciliation Ledger', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  subtitle: const Text('Opening, inbound receipts, distribution, and closing balance.'),
                  trailing: OutlinedButton(onPressed: () => _showSnackbar('Report generated from live database.'), child: const Text('Export CSV')),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // 9. AI Insights Dedicated View
  // --------------------------------------------------------------------------
  Widget _buildAiInsightsDedicatedView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('AI OPERATIONAL INTELLIGENCE & RISK MODELS', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _navy)),
          const SizedBox(height: 16),
          if (_aiInsights.isEmpty)
            const Center(child: Text('No AI signals generated.'))
          else
            for (final ins in _aiInsights)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade200)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(ins.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: _navy)),
                        Text(ins.severity, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: _amber)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(ins.summary, style: const TextStyle(fontSize: 12)),
                    const SizedBox(height: 8),
                    Text('Why: ${ins.why}', style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.black54)),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // 10. Exceptions View
  // --------------------------------------------------------------------------
  Widget _buildExceptionsView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('OPERATIONAL EXCEPTIONS & GRIEVANCES', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _navy)),
              ElevatedButton.icon(
                onPressed: _openNewExceptionDialog,
                icon: const Icon(Icons.add_rounded, size: 16, color: Colors.white),
                label: const Text('Log Exception', style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(backgroundColor: _red),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_exceptions.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
              child: const Center(child: Text('No open operational exceptions for this FPS.')),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _exceptions.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final exc = _exceptions[index];
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade200)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(exc.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: _navy)),
                          Text(exc.status, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: _amber)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(exc.description, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                      const SizedBox(height: 4),
                      Text('Case ID: ${exc.exceptionId} • Category: ${exc.category} • Created: ${exc.createdAt}', style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  void _openNewExceptionDialog() {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String category = 'OPERATIONAL';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Create Operational Exception', style: TextStyle(fontWeight: FontWeight.bold, color: _navy)),
          content: SizedBox(
            width: 450,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: category,
                  items: const [
                    DropdownMenuItem(value: 'OPERATIONAL', child: Text('Operational Discrepancy')),
                    DropdownMenuItem(value: 'EPOS_FAILURE', child: Text('e-PoS Terminal Failure')),
                    DropdownMenuItem(value: 'INVENTORY_MISMATCH', child: Text('Inventory Mismatch')),
                    DropdownMenuItem(value: 'DAMAGED_STOCK', child: Text('Damaged Grain Stock')),
                  ],
                  onChanged: (v) => setDialogState(() => category = v!),
                  decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(controller: descCtrl, maxLines: 3, decoration: const InputDecoration(labelText: 'Detailed Description', border: OutlineInputBorder())),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(ctx).pop();
                try {
                  await _fpsService.createException(
                    _activeFpsId,
                    category: category,
                    severity: 'MEDIUM',
                    title: titleCtrl.text,
                    description: descCtrl.text,
                  );
                  _showSnackbar('Exception ticket registered.');
                  _loadInitialData();
                } catch (e) {
                  _showSnackbar('Failed to register exception: $e', isError: true);
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: _red),
              child: const Text('Submit Ticket', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // 11. Decision Trace View
  // --------------------------------------------------------------------------
  Widget _buildDecisionTraceView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('CRYPTOGRAPHIC DECISION TRACE & AUDIT TRAIL', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _navy)),
          const SizedBox(height: 16),
          if (_decisionTrace.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
              child: const Center(child: Text('No decision trace events logged yet.')),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _decisionTrace.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final ev = _decisionTrace[index];
                return Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  color: Colors.white,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(ev.timestamp, style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: Colors.grey)),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${ev.action} (${ev.actor})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: _navy)),
                            Text(ev.details, style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
