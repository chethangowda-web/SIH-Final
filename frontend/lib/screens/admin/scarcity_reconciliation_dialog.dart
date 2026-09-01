import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../models/scarcity_model.dart';
import '../../services/api_service.dart';

/// Institutional-grade AI Scarcity & Stockout Risk Management Dialog.
///
/// Implements 3 Dedicated Views:
/// - Tab 1: Depot Supply vs Demand Deficit Analysis & Interactive Headroom Simulation
/// - Tab 2: AI Stockout Risk Predictions & Deterministic Fair-Share Allocation Matrix
/// - Tab 3: District Supply Officer (DSO) Formal Authorization & Immutable Audit Trail
class ScarcityReconciliationDialog extends StatefulWidget {
  final String cycleId;
  final String depotId;
  final String initialCommodity;
  final ApiService? apiService;

  const ScarcityReconciliationDialog({
    super.key,
    this.cycleId = '2026-09',
    this.depotId = 'DEPOT-01',
    this.initialCommodity = 'Rice',
    this.apiService,
  });

  static void show(
    BuildContext context, {
    String cycleId = '2026-09',
    String depotId = 'DEPOT-01',
    String initialCommodity = 'Rice',
    ApiService? apiService,
  }) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => ScarcityReconciliationDialog(
        cycleId: cycleId,
        depotId: depotId,
        initialCommodity: initialCommodity,
        apiService: apiService,
      ),
    );
  }

  @override
  State<ScarcityReconciliationDialog> createState() =>
      _ScarcityReconciliationDialogState();
}

class _ScarcityReconciliationDialogState
    extends State<ScarcityReconciliationDialog>
    with SingleTickerProviderStateMixin {
  late final ApiService _apiService;
  late TabController _tabController;

  bool _isLoading = true;
  bool _isSimulating = false;
  bool _isApproving = false;
  String? _errorMessage;

  // Selected parameters
  late String _selectedCommodity;
  double _availableDepotStockKg = 12000.0;
  String _selectedStrategy = 'FAIR_SHARE_RISK_WEIGHTED';

  // Server response states
  DepotBalanceModel? _balanceData;
  ScarcityPlanSummaryModel? _planData;
  ScarcityAuditTrailModel? _auditData;

  // Officer sign-off form state
  final TextEditingController _officerNameCtrl =
      TextEditingController(text: 'District Supply Officer (Bengaluru Urban)');
  final TextEditingController _notesCtrl = TextEditingController(
      text: 'Approved for operational dispatch execution under depot grain deficit');
  String _selectedOfficerRole = 'DISTRICT_SUPPLY_OFFICER';

  @override
  void initState() {
    super.initState();
    _apiService = widget.apiService ?? ApiService();
    _selectedCommodity = widget.initialCommodity;
    _tabController = TabController(length: 3, vsync: this);
    _loadInitialTelemetry();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _officerNameCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadInitialTelemetry() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final balance = await _apiService.fetchScarcityDepotBalance(
        cycleId: widget.cycleId,
        depotId: widget.depotId,
        commodity: _selectedCommodity,
      );

      // Default simulation to 12 MT or current available stock if less
      _availableDepotStockKg = balance.isScarcityCondition
          ? balance.availableDepotStockKg
          : 12000.0;

      final plan = await _apiService.simulateFairShareScarcity(
        cycleId: widget.cycleId,
        depotId: widget.depotId,
        commodity: _selectedCommodity,
        availableDepotStockKg: _availableDepotStockKg,
        allocationStrategy: _selectedStrategy,
        persistCandidate: true,
      );

      if (mounted) {
        setState(() {
          _balanceData = balance;
          _planData = plan;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _runSimulation({double? customStockKg, String? customStrategy}) async {
    final stock = customStockKg ?? _availableDepotStockKg;
    final strat = customStrategy ?? _selectedStrategy;

    setState(() {
      _isSimulating = true;
      _errorMessage = null;
      _availableDepotStockKg = stock;
      _selectedStrategy = strat;
    });

    try {
      final plan = await _apiService.simulateFairShareScarcity(
        cycleId: widget.cycleId,
        depotId: widget.depotId,
        commodity: _selectedCommodity,
        availableDepotStockKg: stock,
        allocationStrategy: strat,
        persistCandidate: true,
      );

      if (mounted) {
        setState(() {
          _planData = plan;
          _isSimulating = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isSimulating = false;
        });
      }
    }
  }

  Future<void> _approvePlan() async {
    if (_planData == null || _planData!.planId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No candidate plan available to approve. Please re-simulate.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_officerNameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Officer Name is mandatory for statutory authorization.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isApproving = true;
      _errorMessage = null;
    });

    try {
      final res = await _apiService.approveScarcityPlan(
        planId: _planData!.planId!,
        officerName: _officerNameCtrl.text.trim(),
        officerRole: _selectedOfficerRole,
        approvalNotes: _notesCtrl.text.trim(),
      );

      final audit = await _apiService.fetchScarcityAuditTrail(_planData!.planId!);

      if (mounted) {
        setState(() {
          _isApproving = false;
          _auditData = audit;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res.message),
            backgroundColor: AppConstants.successGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isApproving = false;
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Container(
        width: 1160,
        height: 840,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            _buildDialogHeader(),
            _buildDisclaimerNotice(),
            _buildTabBar(),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage != null
                      ? _buildErrorBanner()
                      : TabBarView(
                          controller: _tabController,
                          children: [
                            _buildTab1DepotSupplyVsDemand(),
                            _buildTab2AiRiskAndFairShare(),
                            _buildTab3OfficerApprovalAndAudit(),
                          ],
                        ),
            ),
            _buildDialogFooter(),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Header & Navigation
  // ---------------------------------------------------------------------------

  Widget _buildDialogHeader() {
    final isScarcity = _planData?.isScarcityCondition ?? false;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(
        color: AppConstants.primaryNavy,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(14),
          topRight: Radius.circular(14),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.balance_outlined, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Flexible(
                            child: Text(
                              'AI Stockout Risk Prediction & Scarcity Allocation Engine',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.3,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isScarcity ? const Color(0xFFD97706) : AppConstants.successGreen,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              isScarcity ? 'SCARCITY MODE' : 'NORMAL SUPPLY',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Depot: ${widget.depotId} • Corridor: Bengaluru North/West • Planning Cycle: ${widget.cycleId}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.75),
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, color: Colors.white),
            tooltip: 'Close Dialog',
          ),
        ],
      ),
    );
  }

  Widget _buildDisclaimerNotice() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: const Color(0xFFFEF3C7),
      child: const Row(
        children: [
          Icon(Icons.info_outline, color: Color(0xFFB45309), size: 16),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'DEMO SYNTHETIC ML MODEL — TRAINED ON PDS SIMULATION DATA (Production accuracy must be revalidated using real historical allocation/offtake data)',
              style: TextStyle(
                color: Color(0xFF92400E),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      decoration: const BoxDecoration(
        color: AppConstants.bgLight,
        border: Border(bottom: BorderSide(color: AppConstants.cardBorder)),
      ),
      child: TabBar(
        controller: _tabController,
        labelColor: AppConstants.primaryNavy,
        unselectedLabelColor: AppConstants.textSecondary,
        indicatorColor: AppConstants.primaryNavy,
        indicatorWeight: 3,
        tabs: const [
          Tab(
            icon: Icon(Icons.analytics_outlined, size: 18),
            text: '1. Depot Supply vs Demand',
          ),
          Tab(
            icon: Icon(Icons.psychology_alt_outlined, size: 18),
            text: '2. AI Risk + Fair Share',
          ),
          Tab(
            icon: Icon(Icons.verified_user_outlined, size: 18),
            text: '3. Officer Approval + Audit',
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 12),
            Text(
              'Error Loading Telemetry',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 6),
            Text(_errorMessage!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadInitialTelemetry,
              child: const Text('Retry Connection'),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 1: Depot Supply vs Demand Deficit Analysis
  // ---------------------------------------------------------------------------

  Widget _buildTab1DepotSupplyVsDemand() {
    final p = _planData;
    if (p == null) return const SizedBox.shrink();

    final isFloorSat = p.isStatutoryFloorSatisfied;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_balanceData != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                children: [
                  const Icon(Icons.location_on_outlined, size: 16, color: AppConstants.primaryNavy),
                  const SizedBox(width: 6),
                  Text(
                    'Depot Source: ${_balanceData!.depotName} (${_balanceData!.depotId}) • Commodity: ${_balanceData!.commodity}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppConstants.primaryNavy,
                    ),
                  ),
                ],
              ),
            ),
          // 1. Telemetry Metric Cards
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  title: 'AGGREGATE DEMAND',
                  value: '${p.aggregateDemandKg.toStringAsFixed(1)} kg',
                  subtext: 'Sum of 20 FPS Demand Forecasts',
                  color: AppConstants.primaryNavy,
                  icon: Icons.shopping_basket_outlined,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard(
                  title: 'AVAILABLE DEPOT GRAIN',
                  value: '${p.availableDepotStockKg.toStringAsFixed(1)} kg',
                  subtext: '${(p.availableDepotStockKg / 1000).toStringAsFixed(2)} MT at Godown',
                  color: const Color(0xFF0284C7),
                  icon: Icons.warehouse_outlined,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard(
                  title: 'DEFICIT HEADROOM',
                  value: p.deficitKg > 0
                      ? '-${p.deficitKg.toStringAsFixed(1)} kg'
                      : '0.0 kg (SURPLUS)',
                  subtext: 'Curtailment: ${p.deficitPercentage.toStringAsFixed(1)}%',
                  color: p.deficitKg > 0 ? const Color(0xFFDC2626) : AppConstants.successGreen,
                  icon: Icons.trending_down_outlined,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard(
                  title: 'STATUTORY FLOORS TOTAL',
                  value: '${p.totalStatutoryFloorsKg.toStringAsFixed(1)} kg',
                  subtext: 'Mandatory NFSA Entitlements',
                  color: const Color(0xFF7C3AED),
                  icon: Icons.gavel_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 2. Statutory Floor Governance Status Banner
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isFloorSat ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isFloorSat ? const Color(0xFF86EFAC) : const Color(0xFFFCA5A5),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isFloorSat ? Icons.check_circle_outline : Icons.warning_amber_rounded,
                  color: isFloorSat ? AppConstants.successGreen : const Color(0xFFDC2626),
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isFloorSat
                            ? 'STATUTORY FLOORS GUARANTEED (FEASIBLE STATE)'
                            : 'STATUTORY FLOORS UNSATISFIABLE (CRITICAL DEFICIT)',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: isFloorSat
                              ? const Color(0xFF166534)
                              : const Color(0xFF991B1B),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isFloorSat
                            ? 'Available depot stock (${p.availableDepotStockKg.toStringAsFixed(1)} kg) exceeds the mandatory statutory floor (${p.totalStatutoryFloorsKg.toStringAsFixed(1)} kg). Beneficiary legal quotas are 100% protected.'
                            : p.governanceAlert ??
                                'Available depot stock is strictly insufficient to satisfy mandatory NFSA statutory floors across all Fair Price Shops.',
                        style: TextStyle(
                          fontSize: 11,
                          color: isFloorSat
                              ? const Color(0xFF15803D)
                              : const Color(0xFFB91C1C),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 3. Interactive Headroom Simulator
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppConstants.cardBorder),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.tune_outlined, color: AppConstants.primaryNavy, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'INTERACTIVE DEPOT STOCK SHORTAGE SIMULATOR',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: AppConstants.primaryNavy,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'Target Stock: ${_availableDepotStockKg.toStringAsFixed(0)} kg (${(_availableDepotStockKg / 1000).toStringAsFixed(1)} MT)',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0284C7),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: AppConstants.primaryNavy,
                    inactiveTrackColor: Colors.grey.shade200,
                    thumbColor: AppConstants.primaryNavy,
                    overlayColor: AppConstants.primaryNavy.withValues(alpha: 0.15),
                  ),
                  child: Slider(
                    value: _availableDepotStockKg.clamp(1000.0, 30000.0),
                    min: 1000.0,
                    max: 30000.0,
                    divisions: 58,
                    label: '${_availableDepotStockKg.toStringAsFixed(0)} kg',
                    onChanged: (val) {
                      setState(() => _availableDepotStockKg = val);
                    },
                    onChangeEnd: (val) {
                      _runSimulation(customStockKg: val);
                    },
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildPresetButton('Normal Ample (25 MT)', 25000.0),
                    _buildPresetButton('Moderate Scarcity (12 MT)', 12000.0),
                    _buildPresetButton('Tight Supply (8 MT)', 8000.0),
                    _buildPresetButton('Critical Infeasible (2 MT)', 2000.0),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPresetButton(String label, double val) {
    final isSelected = (_availableDepotStockKg - val).abs() < 50.0;

    return OutlinedButton(
      onPressed: () {
        _runSimulation(customStockKg: val);
      },
      style: OutlinedButton.styleFrom(
        backgroundColor: isSelected ? AppConstants.primaryNavy.withValues(alpha: 0.08) : Colors.white,
        side: BorderSide(
          color: isSelected ? AppConstants.primaryNavy : AppConstants.cardBorder,
          width: isSelected ? 1.5 : 1.0,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
          color: isSelected ? AppConstants.primaryNavy : AppConstants.textPrimary,
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtext,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppConstants.bgLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppConstants.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: AppConstants.textSecondary,
                    letterSpacing: 0.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              Icon(icon, size: 16, color: color),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtext,
            style: const TextStyle(
              fontSize: 10,
              color: AppConstants.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 2: AI Risk Predictions & Fair-Share Allocation Matrix
  // ---------------------------------------------------------------------------

  Widget _buildTab2AiRiskAndFairShare() {
    final p = _planData;
    if (p == null) return const SizedBox.shrink();

    return Column(
      children: [
        // Strategy Bar & Risk Summary
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: const BoxDecoration(
            color: AppConstants.bgLight,
            border: Border(bottom: BorderSide(color: AppConstants.cardBorder)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text(
                    'Allocation Strategy:',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(width: 10),
                  DropdownButton<String>(
                    value: _selectedStrategy,
                    underline: const SizedBox.shrink(),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppConstants.primaryNavy,
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'FAIR_SHARE_RISK_WEIGHTED',
                        child: Text('AI Risk-Weighted Fair Share (Recommended)'),
                      ),
                      DropdownMenuItem(
                        value: 'PRO_RATA',
                        child: Text('Pro-Rata Flat Curtailment'),
                      ),
                      DropdownMenuItem(
                        value: 'STATUTORY_FLOOR_PRIORITY',
                        child: Text('Statutory Floor Priority Only'),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        _runSimulation(customStrategy: val);
                      }
                    },
                  ),
                ],
              ),
              Row(
                children: [
                  _buildRiskBadge('Critical Risk', p.riskSummary.criticalRiskCount, const Color(0xFFDC2626)),
                  const SizedBox(width: 8),
                  _buildRiskBadge('Elevated Risk', p.riskSummary.elevatedRiskCount, const Color(0xFFEA580C)),
                  const SizedBox(width: 8),
                  _buildRiskBadge('Moderate Risk', p.riskSummary.moderateRiskCount, const Color(0xFFD97706)),
                  const SizedBox(width: 8),
                  _buildRiskBadge('Low Risk', p.riskSummary.lowRiskCount, AppConstants.successGreen),
                ],
              ),
            ],
          ),
        ),

        // FPS Scarcity Matrix Table
        Expanded(
          child: _isSimulating
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  children: [
                    DataTable(
                      columnSpacing: 16,
                      horizontalMargin: 8,
                      headingRowColor: WidgetStateProperty.all(AppConstants.bgLight),
                      columns: const [
                        DataColumn(label: Text('FAIR PRICE SHOP', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11))),
                        DataColumn(label: Text('BASELINE DEMAND', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11))),
                        DataColumn(label: Text('STATUTORY FLOOR', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11))),
                        DataColumn(label: Text('ML STOCKOUT RISK', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11))),
                        DataColumn(label: Text('RISK TIER', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11))),
                        DataColumn(label: Text('RECONCILED ALLOC', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11))),
                        DataColumn(label: Text('CUT %', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11))),
                        DataColumn(label: Text('MITIGATION ACTION', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11))),
                      ],
                      rows: p.allocatedItems.map((item) {
                        return DataRow(
                          cells: [
                            DataCell(
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(item.fpsName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11)),
                                  Text(item.fpsId, style: const TextStyle(fontSize: 9, color: AppConstants.textTertiary, fontFamily: 'monospace')),
                                ],
                              ),
                            ),
                            DataCell(Text('${item.baselineRecommendedKg.toStringAsFixed(1)} kg', style: const TextStyle(fontSize: 11))),
                            DataCell(Text('${item.statutoryFloorKg.toStringAsFixed(1)} kg', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600))),
                            DataCell(
                              Row(
                                children: [
                                  Text('${(item.predictedStockoutRisk * 100).toStringAsFixed(1)}%', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                  const SizedBox(width: 4),
                                  SizedBox(
                                    width: 36,
                                    child: LinearProgressIndicator(
                                      value: item.predictedStockoutRisk,
                                      backgroundColor: Colors.grey.shade200,
                                      color: _getTierColor(item.riskTier),
                                      minHeight: 4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            DataCell(_buildTierChip(item.riskTier)),
                            DataCell(
                              Text(
                                '${item.reconciledAllocationKg.toStringAsFixed(1)} kg',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppConstants.primaryNavy),
                              ),
                            ),
                            DataCell(
                              Text(
                                '-${item.cutPercentage.toStringAsFixed(1)}%',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: item.cutPercentage > 0 ? const Color(0xFFDC2626) : AppConstants.successGreen,
                                ),
                              ),
                            ),
                            DataCell(
                              Text(
                                item.mitigationAction,
                                style: const TextStyle(fontSize: 10, color: AppConstants.textSecondary),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildRiskBadge(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(
            '$label: $count',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: color),
          ),
        ],
      ),
    );
  }

  Color _getTierColor(String tier) {
    switch (tier.toUpperCase()) {
      case 'CRITICAL':
        return const Color(0xFFDC2626);
      case 'ELEVATED':
        return const Color(0xFFEA580C);
      case 'MODERATE':
        return const Color(0xFFD97706);
      case 'LOW':
      default:
        return AppConstants.successGreen;
    }
  }

  Widget _buildTierChip(String tier) {
    final color = _getTierColor(tier);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        tier,
        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: color),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 3: Officer Formal Authorization & Immutable Audit Trail
  // ---------------------------------------------------------------------------

  Widget _buildTab3OfficerApprovalAndAudit() {
    final p = _planData;
    if (p == null) return const SizedBox.shrink();

    final isApproved = _auditData != null || p.approvalStatus == 'OFFICER_APPROVED';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Candidate Plan Summary Banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppConstants.bgLight,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppConstants.cardBorder),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PLAN ID: ${p.planId ?? "PENDING_STAGING"}',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: AppConstants.primaryNavy,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Strategy: ${p.allocationStrategy} • Total Reconciled: ${p.totalReconciledAllocationKg.toStringAsFixed(1)} kg',
                      style: const TextStyle(fontSize: 11, color: AppConstants.textSecondary),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: isApproved ? AppConstants.successGreen : const Color(0xFFD97706),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isApproved ? 'OFFICER APPROVED' : 'PENDING OFFICER REVIEW',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 2. Formal Sign-off Form
          const Text(
            'DISTRICT SUPPLY OFFICER FORMAL AUTHORIZATION',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppConstants.primaryNavy,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _officerNameCtrl,
                  enabled: !isApproved && !_isApproving,
                  decoration: const InputDecoration(
                    labelText: 'Authorized Officer Name',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedOfficerRole,
                  decoration: const InputDecoration(
                    labelText: 'Officer Role',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: const [
                    DropdownMenuItem(value: 'DISTRICT_SUPPLY_OFFICER', child: Text('District Supply Officer (DSO)')),
                    DropdownMenuItem(value: 'DEPOT_MANAGER', child: Text('Depot Manager (FCI)')),
                    DropdownMenuItem(value: 'ADMIN', child: Text('District Administrator')),
                  ],
                  onChanged: isApproved || _isApproving ? null : (val) {
                    if (val != null) setState(() => _selectedOfficerRole = val);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notesCtrl,
            enabled: !isApproved && !_isApproving,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Statutory Approval Remarks & Justification',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 16),

          // Sign Button
          ElevatedButton.icon(
            onPressed: isApproved || _isApproving ? null : _approvePlan,
            icon: _isApproving
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.verified_outlined, size: 18),
            label: Text(
              isApproved
                  ? 'Plan Officially Approved & Frozen'
                  : 'Sign & Authorize Operational Scarcity Plan',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: isApproved ? Colors.grey.shade600 : AppConstants.successGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            ),
          ),
          const SizedBox(height: 24),

          // 3. Immutable Audit Trail History
          if (_auditData != null) ...[
            const Text(
              'IMMUTABLE AUDIT RECORD',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: AppConstants.primaryNavy,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF86EFAC)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.lock_clock_outlined, color: AppConstants.successGreen, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Approved by ${_auditData!.approvedBy} on ${_auditData!.approvedAt}',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Color(0xFF166534)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Notes: ${_auditData!.approvalNotes ?? "N/A"}',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF15803D)),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Footer
  // ---------------------------------------------------------------------------

  Widget _buildDialogFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: const BoxDecoration(
        color: AppConstants.bgLight,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(14),
          bottomRight: Radius.circular(14),
        ),
        border: Border(top: BorderSide(color: AppConstants.cardBorder)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'PDS DemandSync • Smart India Hackathon 2026 Prototype',
            style: TextStyle(fontSize: 11, color: AppConstants.textTertiary),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
