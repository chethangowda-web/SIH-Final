import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../models/admin_model.dart';
import '../../services/api_service.dart';
import '../../widgets/metric_card.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/fps_detail_drawer.dart';
import 'constraint_validation_dialog.dart';
import 'digital_gatepass_dialog.dart';
import 'readiness_alerts_dialog.dart';
import 'fps_predispatch_inspector_dialog.dart';
import 'fps_forecast_detail_dialog.dart';
import 'fps_dispatch_decision_dialog.dart';
import 'dispatch_optimization_dialog.dart';
import 'manifest_management_dialog.dart';
import 'sih_demo_mode_dialog.dart';
import 'judge_view_dialog.dart';
import 'scarcity_reconciliation_dialog.dart';
import 'citizen_request_queue_dialog.dart';
import 'causal_trace_dialog.dart';
import 'incident_detail_dialog.dart';
import 'predispatch_analysis_dialog.dart';
import '../beneficiary/demo_login_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  final ApiService? apiService;

  const AdminDashboardScreen({super.key, this.apiService});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  late final ApiService _apiService;
  AdminDashboardData? _dashboardData;
  bool _isLoading = true;
  String? _errorMessage;
  String _selectedFilter = 'ALL'; // 'ALL', 'HIGH_RISK', 'LOW_INVENTORY', 'PORTABILITY'
  String _searchQuery = '';
  bool _isActionExecuting = false;
  AdminFpsRow? _selectedDrawerFps;

  // Pre-Dispatch Operational Incidents & Risk Anomaly State
  final List<OperationalIncident> _dashboardIncidents =
      OperationalIncident.getDefaultPreDispatchIncidents();

  int get _activeDashboardIncidentsCount =>
      _dashboardIncidents.where((i) => !i.isAcknowledged).length;

  @override
  void initState() {
    super.initState();
    _apiService = widget.apiService ?? ApiService();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final data = await _apiService.fetchAdminDashboard();

      if (mounted) {
        setState(() {
          _dashboardData = data;
          _isLoading = false;
          if (_selectedDrawerFps != null) {
            _selectedDrawerFps = data.fpsList.firstWhere(
              (f) => f.fpsId == _selectedDrawerFps!.fpsId,
              orElse: () => _selectedDrawerFps!,
            );
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load district admin telemetry: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _runDistrictPreDispatchAnalysis() async {
    await PreDispatchAnalysisDialog.show(
      context,
      cycleId: _dashboardData?.activeCycle ?? '2026-09',
      onDispatchCompleted: () => _loadDashboardData(),
      onDispatchDelayed: () => _loadDashboardData(),
    );
    _loadDashboardData();
  }

  Future<void> _resumeStockDispatch() async {
    setState(() => _isActionExecuting = true);
    try {
      final res = await _apiService.resumeDispatch(cycleId: _dashboardData?.activeCycle ?? '2026-09');
      await _loadDashboardData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? 'Stock replenished! Dispatch resumed and moved to Out for Delivery.'),
          backgroundColor: AppConstants.successGreen,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isActionExecuting = false);
    }
  }

  Future<void> _generateForecast() async {
    setState(() => _isActionExecuting = true);
    try {
      final res = await _apiService.triggerGenerateForecast();
      await _loadDashboardData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? 'Composite demand forecast generated!'),
          backgroundColor: AppConstants.successGreen,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isActionExecuting = false);
    }
  }

  Future<void> _lockForecast() async {
    setState(() => _isActionExecuting = true);
    try {
      final res = await _apiService.closeChoiceWindow();
      await _loadDashboardData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? 'Choice window closed & aggregated demand (D̂) locked!'),
          backgroundColor: AppConstants.primaryNavy,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isActionExecuting = false);
    }
  }

  Future<void> _resetDemoWorkflow() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.restart_alt_rounded, color: AppConstants.accentAmber),
            SizedBox(width: 10),
            Text('Reset Demo Workflow?'),
          ],
        ),
        content: const Text(
          'This will return the admin workflow back to PLANNING_OPEN for the next jury demonstration.\n\nAll 2,000 beneficiaries, Fair Price Shops, and baseline datasets will be preserved.',
          style: TextStyle(fontSize: 12),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppConstants.primaryNavy,
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirm Reset'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isActionExecuting = true);
    try {
      final res = await _apiService.resetDemoWorkflow();
      await _loadDashboardData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? 'Workflow reset to PLANNING_OPEN!'),
          backgroundColor: AppConstants.accentAmber,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isActionExecuting = false);
    }
  }

  void _showConstraintDialog() {
    showDialog(
      context: context,
      builder: (context) => const ConstraintValidationDialog(),
    );
  }

  void _showGatepassDialog() {
    showDialog(
      context: context,
      builder: (context) => const DigitalGatepassDialog(),
    );
  }

  void _showAlertsDialog() {
    showDialog(
      context: context,
      builder: (context) => const ReadinessAlertsDialog(),
    );
  }

  void _showForecastWhatIfDialog(String fpsId) {
    showDialog(
      context: context,
      builder: (context) => FpsForecastDetailDialog(fpsId: fpsId),
    );
  }

  void _showDispatchDecisionDialog(String fpsId) {
    showDialog(
      context: context,
      builder: (context) => FpsDispatchDecisionDialog(fpsId: fpsId),
    );
  }

  void _showDispatchOptimizationDialog({String? truckId}) {
    showDialog(
      context: context,
      builder: (context) => DispatchOptimizationDialog(
        cycleId: _dashboardData?.activeCycle ?? '2026-09',
        initialTruckId: truckId,
      ),
    );
  }

  void _showManifestDialog({String? truckId}) {
    showDialog(
      context: context,
      builder: (context) => ManifestManagementDialog(
        cycleId: _dashboardData?.activeCycle ?? '2026-09',
        initialTruckId: truckId,
      ),
    );
  }

  void _showSihDemoModeDialog() {
    showDialog(
      context: context,
      builder: (context) => SihDemoModeDialog(
        cycleId: _dashboardData?.activeCycle ?? '2026-09',
      ),
    );
  }

  void _showJudgeViewDialog() {
    JudgeViewDialog.show(context);
  }

  void _showScarcityDialog() {
    showDialog(
      context: context,
      builder: (context) => ScarcityReconciliationDialog(
        cycleId: _dashboardData?.activeCycle ?? '2026-09',
        depotId: 'DEPOT-01',
      ),
    ).then((_) => _loadDashboardData());
  }

  void _showCitizenRequestQueueDialog() {
    showDialog(
      context: context,
      builder: (context) => CitizenRequestQueueDialog(
        cycleId: _dashboardData?.activeCycle ?? '2026-09',
      ),
    ).then((_) => _loadDashboardData());
  }

  void _showCausalTraceDialog([String fpsId = 'FPS-KA-BLR-001']) {
    showDialog(
      context: context,
      builder: (context) => CausalTraceDialog(
        apiService: _apiService,
        initialFpsId: fpsId,
        cycleId: _dashboardData?.activeCycle ?? '2026-09',
      ),
    );
  }

  void _showIncidentDetailDialog(OperationalIncident incident) {
    showDialog(
      context: context,
      builder: (ctx) => IncidentDetailDialog(
        incident: incident,
        onAcknowledge: () => setState(() {}),
        onApplyAction: () => setState(() {}),
      ),
    );
  }

  Future<void> _showEvaluationModal() async {
    showDialog(
      context: context,
      builder: (context) {
        return FutureBuilder<ForecastEvaluationData>(
          future: _apiService.fetchForecastEvaluation(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Dialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Container(
                  width: 500,
                  padding: const EdgeInsets.all(32),
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(strokeWidth: 3, color: AppConstants.primaryNavy),
                      SizedBox(height: 16),
                      Text('Computing Forecast vs Actual ePoS Evaluation...', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppConstants.primaryNavy)),
                      SizedBox(height: 4),
                      Text('Analyzing 20 shops & closing machine learning loop', style: TextStyle(fontSize: 11, color: AppConstants.textSecondary)),
                    ],
                  ),
                ),
              );
            }

            if (snapshot.hasError || !snapshot.hasData) {
              return Dialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Container(
                  width: 550,
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.info_outline_rounded, color: AppConstants.accentAmber, size: 48),
                      const SizedBox(height: 12),
                      const Text('Evaluation Data Pending', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppConstants.primaryNavy)),
                      const SizedBox(height: 8),
                      Text(
                        snapshot.error != null
                            ? 'Error: ${snapshot.error}'
                            : 'No evaluation records available. Please simulate actual ePoS distribution to trigger closed-loop accuracy computation.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12, color: AppConstants.textSecondary),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: ElevatedButton.styleFrom(backgroundColor: AppConstants.primaryNavy, foregroundColor: Colors.white),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                ),
              );
            }

            final eval = snapshot.data!;
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Container(
                width: 1140,
                height: 840,
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: AppConstants.backgroundLight,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // HEADER
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppConstants.accentBlue.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppConstants.accentBlue.withValues(alpha: 0.3)),
                          ),
                          child: const Icon(Icons.analytics_outlined, color: AppConstants.accentBlue, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Text('Forecast vs Actual ePoS Evaluation', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppConstants.primaryNavy)),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF0FDF4),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: const Color(0xFF86EFAC)),
                                    ),
                                    child: const Text('CLOSED-LOOP VERIFIED', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: Color(0xFF15803D))),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text('Cycle ${eval.cycleId} • Post-Distribution Accuracy & ML Calibration', style: const TextStyle(fontSize: 11, color: AppConstants.textSecondary)),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          tooltip: 'Close',
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // BODY (Internal Scrollable)
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // 1. Top 5 Metrics Row
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AppConstants.cardSurface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppConstants.cardBorder),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: [
                                  _buildEvaluationHeaderStat('OVERALL ACCURACY', '${eval.overallAccuracyPct.toStringAsFixed(1)}%', const Color(0xFF15803D)),
                                  _buildEvaluationHeaderStat('MAPE (ERROR)', '${eval.mapePct.toStringAsFixed(2)}%', const Color(0xFFB45309)),
                                  _buildEvaluationHeaderStat('MEAN ABS ERROR', '${eval.maeKg.toStringAsFixed(1)} kg', AppConstants.primaryNavy),
                                  _buildEvaluationHeaderStat('TOTAL FORECAST (D̂)', '${(eval.totalForecastQuantityKg / 1000).toStringAsFixed(1)} MT', AppConstants.accentBlue),
                                  _buildEvaluationHeaderStat('TOTAL ACTUAL (ePoS)', '${(eval.totalActualQuantityKg / 1000).toStringAsFixed(1)} MT', AppConstants.primaryNavy),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),

                            // 2. Commodity Breakdown Cards (Rice & Wheat)
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: AppConstants.cardSurface,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: AppConstants.cardBorder),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Row(
                                          children: [
                                            Icon(Icons.grain, color: AppConstants.primaryNavy, size: 16),
                                            SizedBox(width: 6),
                                            Text('Fortified Rice Accuracy', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppConstants.primaryNavy)),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text('Error Metric', style: const TextStyle(fontSize: 11, color: AppConstants.textSecondary)),
                                            Text('MAPE: ${eval.riceMapePct.toStringAsFixed(2)}%', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF15803D))),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(4),
                                          child: LinearProgressIndicator(
                                            value: (1.0 - (eval.riceMapePct / 100)).clamp(0.0, 1.0),
                                            minHeight: 6,
                                            backgroundColor: const Color(0xFFE2E8F0),
                                            valueColor: const AlwaysStoppedAnimation(Color(0xFF15803D)),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text('Accuracy: ${(100.0 - eval.riceMapePct).toStringAsFixed(1)}%', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF15803D))),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: AppConstants.cardSurface,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: AppConstants.cardBorder),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Row(
                                          children: [
                                            Icon(Icons.bakery_dining, color: AppConstants.accentAmber, size: 16),
                                            SizedBox(width: 6),
                                            Text('Whole Wheat Accuracy', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppConstants.primaryNavy)),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text('Error Metric', style: const TextStyle(fontSize: 11, color: AppConstants.textSecondary)),
                                            Text('MAPE: ${eval.wheatMapePct.toStringAsFixed(2)}%', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF15803D))),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(4),
                                          child: LinearProgressIndicator(
                                            value: (1.0 - (eval.wheatMapePct / 100)).clamp(0.0, 1.0),
                                            minHeight: 6,
                                            backgroundColor: const Color(0xFFE2E8F0),
                                            valueColor: const AlwaysStoppedAnimation(Color(0xFF15803D)),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text('Accuracy: ${(100.0 - eval.wheatMapePct).toStringAsFixed(1)}%', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF15803D))),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            // 3. Closed-Loop Machine Learning Weights Calibration Card
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AppConstants.cardSurface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppConstants.cardBorder),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Closed-Loop Machine Learning Calibration', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppConstants.primaryNavy)),
                                  const SizedBox(height: 4),
                                  const Text('Evaluation errors automatically update feature weight coefficients for Cycle 8 demand projections.', style: TextStyle(fontSize: 11, color: AppConstants.textSecondary)),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(color: AppConstants.backgroundLight, borderRadius: BorderRadius.circular(6)),
                                          child: const Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text('HISTORICAL WEIGHT (α)', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppConstants.textSecondary)),
                                              SizedBox(height: 2),
                                              Text('0.42 → 0.38 (-9.5%)', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppConstants.primaryNavy)),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(color: AppConstants.backgroundLight, borderRadius: BorderRadius.circular(6)),
                                          child: const Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text('INTENT WEIGHT (β)', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppConstants.textSecondary)),
                                              SizedBox(height: 2),
                                              Text('0.38 → 0.44 (+15.8%)', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF15803D))),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(color: AppConstants.backgroundLight, borderRadius: BorderRadius.circular(6)),
                                          child: const Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text('MIGRATION INFLUX (γ)', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppConstants.textSecondary)),
                                              SizedBox(height: 2),
                                              Text('0.20 → 0.18 (-10.0%)', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppConstants.accentAmber)),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // STICKY FOOTER
                    Container(
                      padding: const EdgeInsets.only(top: 10),
                      decoration: const BoxDecoration(
                        border: Border(top: BorderSide(color: AppConstants.cardBorder)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Closed-loop calibration results logged into district audit ledger.', style: TextStyle(fontSize: 10.5, color: AppConstants.textSecondary)),
                          ElevatedButton(
                            onPressed: () => Navigator.of(context).pop(),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppConstants.primaryNavy,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                            ),
                            child: const Text('Close', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEvaluationHeaderStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: AppConstants.textSecondary, letterSpacing: 0.4)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: color)),
      ],
    );
  }

  void _inspectFps(String fpsId) {
    showDialog(
      context: context,
      builder: (context) => FpsPreDispatchInspectorDialog(fpsId: fpsId),
    );
  }

  List<AdminFpsRow> _getFilteredFpsList() {
    if (_dashboardData == null) return [];
    var list = _dashboardData!.fpsList;

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((f) => f.name.toLowerCase().contains(q) || f.fpsId.toLowerCase().contains(q)).toList();
    }

    if (_selectedFilter == 'HIGH_RISK') {
      list = list.where((f) => f.riskLevel == 'HIGH').toList();
    } else if (_selectedFilter == 'PORTABILITY') {
      list = list.where((f) => f.intentShiftKg > 150).toList();
    } else if (_selectedFilter == 'LOW_INVENTORY') {
      list = list.where((f) => f.inventoryUtilizationPct < 25.0).toList();
    }

    return list;
  }

  @override
  Widget build(BuildContext context) {
    if (_apiService.authSession.isAuthenticated && !_apiService.authSession.isAdmin) {
      return Scaffold(
        backgroundColor: AppConstants.backgroundLight,
        appBar: AppBar(
          title: const Text('Access Denied • PDS DemandSync'),
          backgroundColor: AppConstants.primaryNavy,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Container(
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.all(32),
            constraints: const BoxConstraints(maxWidth: 520),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppConstants.cardBorder),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.gpp_bad_rounded, size: 48, color: Colors.red.shade700),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Access Restricted',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppConstants.primaryNavy),
                ),
                const SizedBox(height: 10),
                Text(
                  'You are currently logged in as a Citizen Beneficiary (${_apiService.authSession.username}) and do not have administrative privileges to access District Supply Operations.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, color: AppConstants.textSecondary, height: 1.4),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const DemoLoginScreen()),
                      (route) => false,
                    );
                  },
                  icon: const Icon(Icons.arrow_back_rounded, size: 16),
                  label: const Text('Return to Login / Citizen Portal'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppConstants.primaryNavy,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppConstants.backgroundLight,
      appBar: _buildTopNavigationBar(),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(strokeWidth: 2.5, color: AppConstants.primaryNavy),
                  SizedBox(height: 16),
                  Text('Loading PDS Pre-Dispatch Telemetry & Forecasting Pipeline...', style: TextStyle(color: AppConstants.textSecondary, fontSize: 13)),
                ],
              ),
            )
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 48, color: Colors.red.shade400),
                        const SizedBox(height: 12),
                        Text(_errorMessage!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _loadDashboardData,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Try Again'),
                        ),
                      ],
                    ),
                  ),
                )
              : Stack(
                  children: [
                    RefreshIndicator(
                      onRefresh: _loadDashboardData,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: AppConstants.space20, vertical: AppConstants.space20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // SECTION 1: ENTERPRISE COMMAND BAR & 7-STAGE PRIMARY WORKFLOW STEPPER
                            _buildEnterpriseCommandBar(),
                            const SizedBox(height: AppConstants.space16),

                            // SECTION 2: EXECUTIVE KPI ROW (5 Polished KPI Cards)
                            _buildExecutiveKpiRow(),
                            const SizedBox(height: AppConstants.space20),

                            // SECTION 3: OPERATIONAL HEALTH & ATTENTION ITEMS (2x2 Grid + Live Alerts)
                            _buildOperationalHealthAndAlerts(),
                            const SizedBox(height: AppConstants.space20),

                            // SECTION 4: FAIR PRICE SHOP OPERATIONS MATRIX
                            _buildFpsOperationsMatrix(),
                            const SizedBox(height: AppConstants.space20),

                            // Footer Reassurance
                            Center(
                              child: Text(
                                'DEPARTMENT OF FOOD, CIVIL SUPPLIES & CONSUMER AFFAIRS • GOVERNMENT OF KARNATAKA\nPRE-DISPATCH DEMAND INTELLIGENCE & GOVERNANCE PIPELINE • SIH ENTERPRISE EDITION',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: Colors.grey.shade500, height: 1.4),
                              ),
                            ),
                            const SizedBox(height: AppConstants.space16),
                          ],
                        ),
                      ),
                    ),

                    // Slide-over FPS detail drawer
                    if (_selectedDrawerFps != null)
                      Positioned(
                        top: 0,
                        right: 0,
                        bottom: 0,
                        child: Material(
                          elevation: 16,
                          child: SizedBox(
                            width: 520,
                            child: Stack(
                              children: [
                                FpsDetailDrawer(
                                  item: _selectedDrawerFps!,
                                  onOpenForecast: () => _showForecastWhatIfDialog(_selectedDrawerFps!.fpsId),
                                  onOpenDecision: () => _showDispatchDecisionDialog(_selectedDrawerFps!.fpsId),
                                  onOpenInspector: () => _inspectFps(_selectedDrawerFps!.fpsId),
                                ),
                                Positioned(
                                  top: 12,
                                  right: 12,
                                  child: IconButton(
                                    icon: const Icon(Icons.close, size: 20),
                                    onPressed: () => setState(() => _selectedDrawerFps = null),
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

  // TOP NAVIGATION BAR
  PreferredSizeWidget _buildTopNavigationBar() {
    return AppBar(
      backgroundColor: AppConstants.primaryNavy,
      foregroundColor: Colors.white,
      elevation: 0,
      titleSpacing: 16,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.shield_outlined, size: 16, color: Colors.white),
                SizedBox(width: 6),
                Text(
                  'PDS DemandSync',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 0.4),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          const Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'District Supply Operations',
                  style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Bengaluru Urban • Cycle 7 • September 2026',
                  style: TextStyle(fontSize: 10.5, color: Colors.white70),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        // System status
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppConstants.successGreen.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: AppConstants.successGreen.withValues(alpha: 0.4)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.circle, size: 8, color: AppConstants.successGreen),
              SizedBox(width: 6),
              Text(
                'ONLINE · SECURE',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),

        // Refresh
        IconButton(
          tooltip: 'Refresh Telemetry',
          icon: const Icon(Icons.refresh, size: 20),
          onPressed: _loadDashboardData,
        ),

        // Citizen Portal Switcher
        TextButton.icon(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => const DemoLoginScreen()),
            );
          },
          icon: const Icon(Icons.people_alt_outlined, size: 16, color: Colors.white),
          label: const Text('Citizen Portal', style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w700)),
        ),

        // Operations ▾ Secondary Actions Menu
        PopupMenuButton<String>(
          tooltip: 'More Operations & Tools',
          onSelected: (value) {
            if (value == 'CAUSAL_TRACE') _showCausalTraceDialog();
            if (value == 'WHAT_IF') _showForecastWhatIfDialog('FPS-KA-BLR-001');
            if (value == 'ALERTS') _showAlertsDialog();
            if (value == 'CITIZEN_QUEUE') _showCitizenRequestQueueDialog();
            if (value == 'SCARCITY') _showScarcityDialog();
            if (value == 'EVALUATION') _showEvaluationModal();
            if (value == 'GATEPASS') _showGatepassDialog();
            if (value == 'LOCK_FORECAST') _lockForecast();
            if (value == 'RESET') _resetDemoWorkflow();
          },
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.more_horiz_rounded, size: 16, color: Colors.white),
                SizedBox(width: 4),
                Text('Operations ▾', style: TextStyle(fontSize: 11.5, color: Colors.white, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'CAUSAL_TRACE',
              child: Row(
                children: [
                  Icon(Icons.account_tree_outlined, color: AppConstants.accentBlue, size: 18),
                  SizedBox(width: 10),
                  Expanded(child: Text('Decision & Impact Trace', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600))),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'WHAT_IF',
              child: Row(
                children: [
                  Icon(Icons.science_outlined, color: AppConstants.accentBlue, size: 18),
                  SizedBox(width: 10),
                  Expanded(child: Text('What-If Sensitivity Sandbox', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600))),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'ALERTS',
              child: Row(
                children: [
                  Icon(Icons.notifications_active_outlined, color: AppConstants.accentAmber, size: 18),
                  SizedBox(width: 10),
                  Expanded(child: Text('Readiness Alerts & Broadcasts', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600))),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'CITIZEN_QUEUE',
              child: Row(
                children: [
                  Icon(Icons.inbox_outlined, color: AppConstants.accentBlue, size: 18),
                  SizedBox(width: 10),
                  Expanded(child: Text('Citizen Request Queue', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600))),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'SCARCITY',
              child: Row(
                children: [
                  Icon(Icons.balance_outlined, color: AppConstants.accentAmber, size: 18),
                  SizedBox(width: 10),
                  Expanded(child: Text('Scarcity & Fair-Share', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600))),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'EVALUATION',
              child: Row(
                children: [
                  Icon(Icons.query_stats_rounded, color: AppConstants.successGreen, size: 18),
                  SizedBox(width: 10),
                  Expanded(child: Text('Forecast vs Actual Evaluation', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600))),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'GATEPASS',
              child: Row(
                children: [
                  Icon(Icons.qr_code_2_rounded, color: AppConstants.primaryNavy, size: 18),
                  SizedBox(width: 10),
                  Expanded(child: Text('Digital QR Gatepass Clearance', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600))),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'LOCK_FORECAST',
              child: Row(
                children: [
                  Icon(Icons.lock_clock_outlined, color: AppConstants.primaryNavy, size: 18),
                  SizedBox(width: 10),
                  Expanded(child: Text('Lock Aggregated Demand (Close Window)', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600))),
                ],
              ),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem(
              value: 'RESET',
              child: Row(
                children: [
                  Icon(Icons.restart_alt_rounded, color: AppConstants.dangerRed, size: 18),
                  SizedBox(width: 10),
                  Expanded(child: Text('Reset Demo Workflow', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppConstants.dangerRed))),
                ],
              ),
            ),
          ],
        ),

        // Dedicated "Demo & Evaluation" Menu
        PopupMenuButton<String>(
          tooltip: 'Demo & Evaluation',
          onSelected: (value) {
            if (value == 'JUDGE_DEFENSE') _showJudgeViewDialog();
            if (value == 'SCENARIO_RUNNER') _showSihDemoModeDialog();
          },
          icon: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.smart_toy_outlined, size: 15, color: Colors.white),
                SizedBox(width: 4),
                Text('Demo ▾', style: TextStyle(fontSize: 11.5, color: Colors.white, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'JUDGE_DEFENSE',
              child: Row(
                children: [
                  Icon(Icons.gavel_rounded, color: AppConstants.primaryNavy, size: 18),
                  SizedBox(width: 10),
                  Expanded(child: Text('SIH Judge Defense Matrix', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700))),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'SCENARIO_RUNNER',
              child: Row(
                children: [
                  Icon(Icons.play_circle_fill_rounded, color: AppConstants.accentBlue, size: 18),
                  SizedBox(width: 10),
                  Expanded(child: Text('14-Step SIH Demo Simulation', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700))),
                ],
              ),
            ),
          ],
        ),

        // Profile Avatar
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 10),
          child: CircleAvatar(
            radius: 14,
            backgroundColor: Color(0xFF1E3A8A),
            child: Text('DSO', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ),

        // Logout Action
        IconButton(
          tooltip: 'Logout Admin Session',
          icon: const Icon(Icons.logout_rounded, size: 20, color: Colors.white),
          onPressed: () {
            _apiService.logout();
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const DemoLoginScreen()),
              (route) => false,
            );
          },
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  // SECTION 1: ENTERPRISE COMMAND BAR & 7-STAGE PRIMARY WORKFLOW STEPPER
  Widget _buildEnterpriseCommandBar() {
    final status = _dashboardData?.workflowStatus ?? 'PLANNING_OPEN';

    bool isForecastDone = status != 'PLANNING_OPEN';
    bool isForecastActive = status == 'PLANNING_OPEN';

    bool isValidateDone = status != 'PLANNING_OPEN' && status != 'DRAFT_GENERATED';
    bool isValidateActive = status == 'DRAFT_GENERATED';

    bool isAllocateDone = status == 'DISPATCH_GENERATED' ||
        status == 'ACTUAL_DISTRIBUTION_SIMULATED' ||
        status == 'FORECAST_EVALUATED' ||
        status == 'MODEL_CALIBRATED';
    bool isAllocateActive = status == 'FORECAST_LOCKED';

    bool isOptimizeDone = isAllocateDone;
    bool isOptimizeActive = status == 'FORECAST_LOCKED';

    bool isDispatchDone = status == 'ACTUAL_DISTRIBUTION_SIMULATED' ||
        status == 'FORECAST_EVALUATED' ||
        status == 'MODEL_CALIBRATED';
    bool isDispatchActive = status == 'DISPATCH_GENERATED';

    bool isVerifyDone = status == 'FORECAST_EVALUATED' || status == 'MODEL_CALIBRATED';
    bool isVerifyActive = status == 'ACTUAL_DISTRIBUTION_SIMULATED';

    bool isEvaluateDone = status == 'MODEL_CALIBRATED';
    bool isEvaluateActive = status == 'FORECAST_EVALUATED';

    int completedStages = 0;
    if (isForecastDone) completedStages++;
    if (isValidateDone) completedStages++;
    if (isAllocateDone) completedStages++;
    if (isOptimizeDone) completedStages++;
    if (isDispatchDone) completedStages++;
    if (isVerifyDone) completedStages++;
    if (isEvaluateDone) completedStages++;

    return Container(
      padding: const EdgeInsets.all(AppConstants.space16),
      decoration: BoxDecoration(
        color: AppConstants.cardSurface,
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        border: Border.all(color: AppConstants.cardBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Top Executive Status Bar (3-Second Rule: Where am I? What has been completed? What can I do next?)
          Wrap(
            spacing: 12,
            runSpacing: 10,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // WHERE AM I?
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppConstants.primaryNavy.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppConstants.cardBorder),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.calendar_month_outlined, size: 15, color: AppConstants.primaryNavy),
                        SizedBox(width: 6),
                        Text(
                          'Cycle 7 • September 2026',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppConstants.primaryNavy),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  StatusBadge(status: status, fontSize: 10.5),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0xFF86EFAC)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check_circle_rounded, size: 11, color: Color(0xFF15803D)),
                        const SizedBox(width: 4),
                        Text(
                          '$completedStages OF 7 STAGES COMPLETED',
                          style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: Color(0xFF15803D)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // WHAT CAN I DO NEXT?
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _showCausalTraceDialog('FPS-KA-BLR-001'),
                    icon: const Icon(Icons.account_tree_outlined, size: 15, color: AppConstants.primaryNavy),
                    label: const Text('Decision Trace', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppConstants.primaryNavy)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      side: const BorderSide(color: AppConstants.cardBorder),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _isActionExecuting ? null : _runDistrictPreDispatchAnalysis,
                    icon: _isActionExecuting
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.play_arrow_rounded, size: 16),
                    label: const Text('Run Pre-Dispatch Analysis', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppConstants.primaryNavy,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                  ),
                  if (_dashboardData?.workflowStatus == 'DELAYED' || _dashboardData?.workflowStatus == 'STOCK_DELAYED')
                    ElevatedButton.icon(
                      onPressed: _isActionExecuting ? null : _resumeStockDispatch,
                      icon: _isActionExecuting
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.play_circle_filled_rounded, size: 16),
                      label: const Text('Resume Dispatch', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppConstants.successGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 2. PRIMARY 7-STAGE WORKFLOW STEPPER
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildWorkflowStep(
                  1,
                  'Forecast',
                  isForecastDone ? 'Generated (62.7 MT)' : 'Not Generated',
                  isDone: isForecastDone,
                  isActive: isForecastActive,
                  onTap: _generateForecast,
                ),
                _buildStepConnector(isDone: isForecastDone),
                _buildWorkflowStep(
                  2,
                  'Validate',
                  isValidateDone ? '9 Rules Compliant' : (isValidateActive ? 'Validating...' : 'Pending'),
                  isDone: isValidateDone,
                  isActive: isValidateActive,
                  onTap: _showConstraintDialog,
                ),
                _buildStepConnector(isDone: isValidateDone),
                _buildWorkflowStep(
                  3,
                  'Allocate',
                  isAllocateDone ? 'Calculated (3.2 MT)' : 'Pending',
                  isDone: isAllocateDone,
                  isActive: isAllocateActive,
                  onTap: () => _showDispatchDecisionDialog('FPS-KA-BLR-001'),
                ),
                _buildStepConnector(isDone: isAllocateDone),
                _buildWorkflowStep(
                  4,
                  'Optimize',
                  isOptimizeDone ? '4 Fleet Corridors' : 'Pending',
                  isDone: isOptimizeDone,
                  isActive: isOptimizeActive,
                  onTap: () => _showDispatchOptimizationDialog(),
                ),
                _buildStepConnector(isDone: isOptimizeDone),
                _buildWorkflowStep(
                  5,
                  'Dispatch',
                  isDispatchDone ? 'Dispatched' : (isDispatchActive ? 'Gatepasses Ready' : 'Pending'),
                  isDone: isDispatchDone,
                  isActive: isDispatchActive,
                  onTap: () => _showManifestDialog(),
                ),
                _buildStepConnector(isDone: isDispatchDone),
                _buildWorkflowStep(
                  6,
                  'Verify',
                  isVerifyDone ? 'ePoS Lift Synced' : 'Pending',
                  isDone: isVerifyDone,
                  isActive: isVerifyActive,
                  onTap: _showAlertsDialog,
                ),
                _buildStepConnector(isDone: isVerifyDone),
                _buildWorkflowStep(
                  7,
                  'Evaluate',
                  isEvaluateDone ? '94.2% Accuracy' : 'Pending',
                  isDone: isEvaluateDone,
                  isActive: isEvaluateActive,
                  onTap: _showEvaluationModal,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkflowStep(
    int num,
    String title,
    String subtext, {
    bool isDone = false,
    bool isActive = false,
    bool isWarning = false,
    required VoidCallback onTap,
  }) {
    Color bg;
    Color border;
    Color iconBg;
    Color titleColor;
    Color subColor;

    if (isActive) {
      bg = const Color(0xFFEFF6FF);
      border = const Color(0xFF3B82F6);
      iconBg = AppConstants.accentBlue;
      titleColor = AppConstants.primaryNavy;
      subColor = AppConstants.accentBlue;
    } else if (isWarning) {
      bg = const Color(0xFFFEF3C7);
      border = const Color(0xFFF59E0B);
      iconBg = const Color(0xFFB45309);
      titleColor = const Color(0xFFB45309);
      subColor = const Color(0xFF92400E);
    } else if (isDone) {
      bg = const Color(0xFFF0FDF4);
      border = const Color(0xFFBBF7D0);
      iconBg = const Color(0xFF15803D);
      titleColor = AppConstants.primaryNavy;
      subColor = const Color(0xFF15803D);
    } else {
      bg = AppConstants.backgroundLight;
      border = AppConstants.cardBorder;
      iconBg = AppConstants.textSecondary;
      titleColor = AppConstants.textSecondary;
      subColor = AppConstants.textSecondary;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: border, width: isActive ? 1.5 : 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: iconBg,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: isDone
                        ? const Icon(Icons.check, size: 11, color: Colors.white)
                        : (isWarning
                            ? const Icon(Icons.priority_high, size: 11, color: Colors.white)
                            : Text('$num', style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.white))),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: titleColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              subtext,
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: isDone || isActive ? FontWeight.w700 : FontWeight.normal,
                color: subColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepConnector({bool isDone = false}) {
    return Container(
      width: 14,
      height: 2,
      color: isDone ? const Color(0xFF86EFAC) : const Color(0xFFE2E8F0),
    );
  }

  // SECTION 2: EXECUTIVE KPI ROW (5 Polished KPI Cards with Semantic Colors)
  Widget _buildExecutiveKpiRow() {
    final data = _dashboardData;
    final totalHistoricalMT = ((data?.totalHistoricalDemandKg ?? 112500.0) / 1000).toStringAsFixed(1);
    final totalIntentMT = ((data?.totalDeclaredIntentKg ?? 16700.0) / 1000).toStringAsFixed(1);
    final totalForecastMT = ((data?.totalForecastDemandKg ?? 62700.0) / 1000).toStringAsFixed(1);
    final totalRecommendedDispatchMT = ((data?.totalRecommendedDispatchKg ?? 3200.0) / 1000).toStringAsFixed(1);
    final highRiskCount = data?.highRiskFpsCount ?? 2;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 1050;
        final isMedium = constraints.maxWidth > 650;

        final cards = [
          MetricCard(
            label: 'HISTORICAL BASELINE',
            value: '$totalHistoricalMT MT',
            subtitle: 'Previous 3-cycle average',
            icon: Icons.history_rounded,
            accentColor: AppConstants.textSecondary,
          ),
          MetricCard(
            label: 'INTENT DEMAND',
            value: '$totalIntentMT MT',
            subtitle: '+12.4% advance signals',
            icon: Icons.cell_tower_rounded,
            accentColor: AppConstants.accentBlue,
          ),
          MetricCard(
            label: 'FORECAST DEMAND (D̂)',
            value: '$totalForecastMT MT',
            subtitle: 'AI Baseline + Intent',
            icon: Icons.insights_rounded,
            accentColor: AppConstants.primaryNavy,
          ),
          MetricCard(
            label: 'RECOMMENDED DISPATCH',
            value: '$totalRecommendedDispatchMT MT',
            subtitle: 'Optimized depot release',
            icon: Icons.local_shipping_outlined,
            accentColor: AppConstants.successGreen,
          ),
          MetricCard(
            label: 'RISK & CONFIDENCE',
            value: '$highRiskCount High Risk',
            subtitle: '94.2% ML Confidence',
            icon: Icons.shield_outlined,
            accentColor: highRiskCount > 0 ? AppConstants.dangerRed : AppConstants.successGreen,
          ),
        ];

        if (isWide) {
          return Row(
            children: cards.map((c) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: c))).toList(),
          );
        } else if (isMedium) {
          return Column(
            children: [
              Row(children: [Expanded(child: cards[0]), const SizedBox(width: 8), Expanded(child: cards[1]), const SizedBox(width: 8), Expanded(child: cards[2])]),
              const SizedBox(height: 8),
              Row(children: [Expanded(child: cards[3]), const SizedBox(width: 8), Expanded(child: cards[4])]),
            ],
          );
        } else {
          return Column(
            children: cards.map((c) => Padding(padding: const EdgeInsets.only(bottom: 8), child: c)).toList(),
          );
        }
      },
    );
  }

  // SECTION 3: OPERATIONAL HEALTH & LIVE ATTENTION ITEMS (Pre-Dispatch Incident Alerts + 2x2 Grid)
  Widget _buildOperationalHealthAndAlerts() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // PART B: Live Pre-Dispatch Operational Incidents (Festival Surge & FPS Capacity Constraints)
        _buildPreDispatchIncidentsPanel(),
        const SizedBox(height: 14),

        // WHAT NEEDS ATTENTION? Compact Alert Strip
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppConstants.cardSurface,
            borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
            border: Border.all(color: AppConstants.cardBorder, width: 1),
          ),
          child: Row(
            children: [
              const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Color(0xFFB45309), size: 18),
                  SizedBox(width: 8),
                  Text(
                    'OPERATIONAL ATTENTION ITEMS',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppConstants.primaryNavy, letterSpacing: 0.5),
                  ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildAlertItem(
                        badge: 'HIGH RISK FPS',
                        color: AppConstants.dangerRed,
                        desc: '2 shops exceed 75% stockout threshold',
                        onTap: () => setState(() => _selectedFilter = 'HIGH_RISK'),
                      ),
                      const SizedBox(width: 8),
                      _buildAlertItem(
                        badge: 'LOW INVENTORY',
                        color: const Color(0xFFB45309),
                        desc: 'Bellandur Outer Ring Road below 25% buffer',
                        onTap: () => setState(() => _selectedFilter = 'LOW_INVENTORY'),
                      ),
                      const SizedBox(width: 8),
                      _buildAlertItem(
                        badge: 'MIGRANT SURGE',
                        color: AppConstants.accentBlue,
                        desc: 'ONORC portability influx +180 kg detected',
                        onTap: () => setState(() => _selectedFilter = 'PORTABILITY'),
                      ),
                    ],
                  ),
                ),
              ),
              TextButton(
                onPressed: _showAlertsDialog,
                style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(50, 24)),
                child: const Text('View All →', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // 2x2 Visual Cards
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 780;

            final cardA = _buildVisualCard(
              title: 'District Demand Trend',
              subtitle: 'Historical baseline vs Intent vs Forecast across cycles',
              insight: 'Key insight: Forecast demand incorporates +12.8% surge from migration corridors.',
              child: _buildDemandTrendChart(),
            );

            final cardB = _buildVisualCard(
              title: 'Intent Shift / Portability',
              subtitle: 'Geographic demand migration across urban FPS clusters',
              insight: 'Key insight: Intent demand is shifting toward portability hubs in Bellandur & Peenya.',
              child: _buildPortabilityShiftChart(),
            );

            final cardC = _buildVisualCard(
              title: 'Inventory vs Forecast',
              subtitle: 'Current buffer headroom vs projected monthly consumption',
              insight: 'Key insight: 3 shops require immediate buffer replenishment before cycle opening.',
              child: _buildInventoryVsForecastChart(),
            );

            final cardD = _buildVisualCard(
              title: 'FPS Risk Distribution',
              subtitle: 'AI stockout probability classification for district shops',
              insight: 'Key insight: Stockout risk concentrated in high-migration industrial zones.',
              child: _buildRiskDistributionChart(),
            );

            if (isWide) {
              return Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: cardA),
                      const SizedBox(width: 14),
                      Expanded(child: cardB),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: cardC),
                      const SizedBox(width: 14),
                      Expanded(child: cardD),
                    ],
                  ),
                ],
              );
            } else {
              return Column(
                children: [
                  cardA,
                  const SizedBox(height: 12),
                  cardB,
                  const SizedBox(height: 12),
                  cardC,
                  const SizedBox(height: 12),
                  cardD,
                ],
              );
            }
          },
        ),
      ],
    );
  }

  Widget _buildPreDispatchIncidentsPanel() {
    return Container(
      padding: const EdgeInsets.all(AppConstants.space16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB), // Warm alert tint for pre-dispatch awareness
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        border: Border.all(color: const Color(0xFFFDE68A), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD97706).withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFD97706).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.warning_amber_rounded, color: Color(0xFFB45309), size: 20),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PRE-DISPATCH OPERATIONAL INCIDENTS — PREPARE BEFORE TRUCK DEPARTS',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF92400E),
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      '"Don\'t reroute the truck after it leaves. Prepare the demand before it leaves."',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontStyle: FontStyle.italic,
                        color: Color(0xFFB45309),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _activeDashboardIncidentsCount > 0 ? const Color(0xFFFEF2F2) : const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _activeDashboardIncidentsCount > 0 ? const Color(0xFFFECACA) : const Color(0xFFBBF7D0)),
                ),
                child: Text(
                  _activeDashboardIncidentsCount > 0
                      ? '$_activeDashboardIncidentsCount LIVE PRE-DISPATCH ALERTS'
                      : 'ALL ALERTS RESOLVED ✓',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: _activeDashboardIncidentsCount > 0 ? const Color(0xFFDC2626) : const Color(0xFF15803D),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 3 Visibly Distinct Incident Cards (Festival Surge, FPS Capacity Constraint, Stockout Risk)
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 850;
              final cards = _dashboardIncidents.map((inc) {
                Color badgeColor;
                IconData icon;
                if (inc.severity == 'HIGH_RISK') {
                  if (inc.riskCategory.contains('DEMAND SURGE')) {
                    badgeColor = AppConstants.dangerRed;
                    icon = Icons.celebration_rounded;
                  } else {
                    badgeColor = const Color(0xFFEA580C);
                    icon = Icons.emergency_rounded;
                  }
                } else {
                  badgeColor = const Color(0xFF7C3AED);
                  icon = Icons.warehouse_rounded;
                }

                return _buildIncidentCard(
                  title: inc.title,
                  scenarioBadge: inc.scenarioBadge,
                  badgeColor: badgeColor,
                  icon: icon,
                  affectedFps: inc.affectedFps,
                  projectedShortage: inc.projectedShortageOrConstraint,
                  additionalDispatch: inc.supplyAdjustment,
                  recommendation: inc.recommendation,
                  actionLabel: 'Inspect Incident Details →',
                  isActionApplied: inc.isActionApplied,
                  isAcknowledged: inc.isAcknowledged,
                  onAction: () => _showIncidentDetailDialog(inc),
                );
              }).toList();

              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: cards.map((c) => Expanded(child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: c,
                  ))).toList(),
                );
              } else {
                return Column(
                  children: cards.map((c) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: c,
                  )).toList(),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildIncidentCard({
    required String title,
    required String scenarioBadge,
    required Color badgeColor,
    required IconData icon,
    required String affectedFps,
    required String projectedShortage,
    required String additionalDispatch,
    required String recommendation,
    required String actionLabel,
    bool isActionApplied = false,
    bool isAcknowledged = false,
    required VoidCallback onAction,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isActionApplied
              ? const Color(0xFF86EFAC)
              : (isAcknowledged ? const Color(0xFFCBD5E1) : const Color(0xFFFDE68A)),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
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
              Expanded(
                child: Row(
                  children: [
                    Icon(icon, size: 18, color: badgeColor),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppConstants.primaryNavy),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: badgeColor.withValues(alpha: 0.4)),
                ),
                child: Text(
                  scenarioBadge,
                  style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: badgeColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildIncidentField('Affected FPS', affectedFps, Icons.storefront_outlined),
          const SizedBox(height: 4),
          _buildIncidentField('Projected Deficit / Constraint', projectedShortage, Icons.trending_up_rounded, isHighlight: true),
          const SizedBox(height: 4),
          _buildIncidentField('Required Supply Adjustment', additionalDispatch, Icons.local_shipping_outlined),
          const SizedBox(height: 4),
          _buildIncidentField('Recommended Action', recommendation, Icons.lightbulb_outline, isPositive: true),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (isActionApplied)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('✓ Action Applied', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF15803D))),
                )
              else if (isAcknowledged)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('✓ Acknowledged', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('🔴 Live Alert', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFFDC2626))),
                ),
              InkWell(
                onTap: onAction,
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Text(
                    actionLabel,
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: AppConstants.accentBlue),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIncidentField(String label, String value, IconData icon, {bool isHighlight = false, bool isPositive = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: isHighlight ? AppConstants.dangerRed : (isPositive ? AppConstants.successGreen : AppConstants.textSecondary)),
        const SizedBox(width: 6),
        Text('$label: ', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppConstants.textSecondary)),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: isHighlight ? AppConstants.dangerRed : (isPositive ? const Color(0xFF15803D) : AppConstants.primaryNavy),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAlertItem({
    required String badge,
    required Color color,
    required String desc,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(badge, style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.w900, color: Colors.white)),
            ),
            const SizedBox(width: 6),
            Text(desc, style: const TextStyle(fontSize: 10.5, color: AppConstants.textPrimary, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildVisualCard({
    required String title,
    required String subtitle,
    required String insight,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.space16),
      decoration: BoxDecoration(
        color: AppConstants.cardSurface,
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        border: Border.all(color: AppConstants.cardBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppConstants.primaryNavy)),
          const SizedBox(height: 2),
          Text(subtitle, style: const TextStyle(fontSize: 11, color: AppConstants.textSecondary)),
          const SizedBox(height: 12),
          child,
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppConstants.backgroundLight,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                const Icon(Icons.lightbulb_outline, size: 14, color: AppConstants.accentAmber),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(insight, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: AppConstants.textPrimary)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDemandTrendChart() {
    return Container(
      height: 110,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppConstants.backgroundLight,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _buildTrendBar('Cycle 4', 0.65, '55.2 MT', AppConstants.textSecondary),
          _buildTrendBar('Cycle 5', 0.72, '58.4 MT', AppConstants.textSecondary),
          _buildTrendBar('Cycle 6', 0.78, '60.1 MT', AppConstants.accentBlue),
          _buildTrendBar('Cycle 7 (D̂)', 0.88, '62.7 MT', AppConstants.primaryNavy, isCurrent: true),
        ],
      ),
    );
  }

  Widget _buildTrendBar(String label, double heightFraction, String val, Color color, {bool isCurrent = false}) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(val, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: isCurrent ? AppConstants.primaryNavy : AppConstants.textSecondary)),
        const SizedBox(height: 4),
        Container(
          width: 32,
          height: 60 * heightFraction,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 9.5, color: AppConstants.textSecondary)),
      ],
    );
  }

  Widget _buildPortabilityShiftChart() {
    return Container(
      height: 110,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppConstants.backgroundLight,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildShiftRow('Bellandur Hub', '+180 kg Inflow', 0.85, const Color(0xFF15803D)),
          _buildShiftRow('Peenya Hub', '+140 kg Inflow', 0.65, const Color(0xFF15803D)),
          _buildShiftRow('Malleshwaram Resident', '-80 kg Shift Out', 0.40, AppConstants.accentAmber),
        ],
      ),
    );
  }

  Widget _buildShiftRow(String label, String stat, double fill, Color color) {
    return Row(
      children: [
        SizedBox(width: 110, child: Text(label, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600))),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: fill, minHeight: 6, backgroundColor: const Color(0xFFE2E8F0), valueColor: AlwaysStoppedAnimation(color)),
          ),
        ),
        const SizedBox(width: 8),
        Text(stat, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
      ],
    );
  }

  Widget _buildInventoryVsForecastChart() {
    return Container(
      height: 110,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppConstants.backgroundLight,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildInvForecastRow('Malleshwaram', 'Inventory: 4.0 MT', 'Forecast: 5.2 MT', 0.77),
          _buildInvForecastRow('Bellandur ORR', 'Inventory: 8.0 MT', 'Forecast: 7.9 MT', 1.0),
          _buildInvForecastRow('Peenya Ind.', 'Inventory: 7.0 MT', 'Forecast: 9.4 MT', 0.74),
        ],
      ),
    );
  }

  Widget _buildInvForecastRow(String label, String inv, String fcast, double ratio) {
    final isLow = ratio < 0.8;
    return Row(
      children: [
        SizedBox(width: 90, child: Text(label, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600))),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio.clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: const Color(0xFFE2E8F0),
              valueColor: AlwaysStoppedAnimation(isLow ? AppConstants.dangerRed : AppConstants.successGreen),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(inv, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: isLow ? AppConstants.dangerRed : AppConstants.textPrimary)),
      ],
    );
  }

  Widget _buildRiskDistributionChart() {
    final high = _dashboardData?.highRiskFpsCount ?? 4;
    final med = _dashboardData?.mediumRiskFpsCount ?? 6;
    final low = _dashboardData?.lowRiskFpsCount ?? 10;

    return Container(
      height: 110,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppConstants.backgroundLight,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildRiskPill('LOW RISK', '$low FPS', const Color(0xFF15803D), const Color(0xFFDCFCE7)),
          _buildRiskPill('MEDIUM RISK', '$med FPS', const Color(0xFFB45309), const Color(0xFFFEF3C7)),
          _buildRiskPill('HIGH RISK', '$high FPS', const Color(0xFFB91C1C), const Color(0xFFFEE2E2)),
        ],
      ),
    );
  }

  Widget _buildRiskPill(String label, String count, Color textCol, Color bgCol) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bgCol,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: textCol.withValues(alpha: 0.2)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(count, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: textCol)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: textCol, letterSpacing: 0.4)),
        ],
      ),
    );
  }

  // SECTION 4: FAIR PRICE SHOP OPERATIONS MATRIX
  Widget _buildFpsOperationsMatrix() {
    final filteredList = _getFilteredFpsList();

    return Container(
      padding: const EdgeInsets.all(AppConstants.space16),
      decoration: BoxDecoration(
        color: AppConstants.cardSurface,
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        border: Border.all(color: AppConstants.cardBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Section Title & Subtitle
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Fair Price Shops Overview Matrix',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppConstants.primaryNavy),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Demand, inventory, forecast and dispatch readiness',
                    style: TextStyle(fontSize: 11, color: AppConstants.textSecondary),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppConstants.primaryNavy.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Showing ${filteredList.length} of ${_dashboardData?.totalFps ?? 20} Centers',
                  style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppConstants.primaryNavy),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Search & Filter Controls
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Search input
              SizedBox(
                width: 240,
                child: TextField(
                  onChanged: (val) => setState(() => _searchQuery = val.trim()),
                  decoration: InputDecoration(
                    hintText: 'Search center name or FPS code...',
                    hintStyle: const TextStyle(fontSize: 11.5, color: AppConstants.textTertiary),
                    prefixIcon: const Icon(Icons.search, size: 16, color: AppConstants.textSecondary),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: AppConstants.cardBorder)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: AppConstants.cardBorder)),
                  ),
                ),
              ),

              // Filter Chips
              _buildFilterChip('All FPS', 'ALL'),
              _buildFilterChip('High Risk', 'HIGH_RISK'),
              _buildFilterChip('Low Inventory', 'LOW_INVENTORY'),
              _buildFilterChip('Portability Hubs', 'PORTABILITY'),
            ],
          ),
          const SizedBox(height: 14),

          // Matrix Data Table
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowHeight: 38,
              dataRowMinHeight: 48,
              dataRowMaxHeight: 52,
              horizontalMargin: 12,
              columnSpacing: 16,
              headingRowColor: WidgetStateProperty.all(AppConstants.backgroundLight),
              columns: const [
                DataColumn(label: Text('FPS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppConstants.primaryNavy))),
                DataColumn(label: Text('Historical Demand', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppConstants.primaryNavy))),
                DataColumn(label: Text('Intent', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppConstants.primaryNavy))),
                DataColumn(label: Text('Forecast', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppConstants.primaryNavy))),
                DataColumn(label: Text('Inventory', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppConstants.primaryNavy))),
                DataColumn(label: Text('Recommended Dispatch', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppConstants.primaryNavy))),
                DataColumn(label: Text('Risk', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppConstants.primaryNavy))),
                DataColumn(label: Text('Confidence', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppConstants.primaryNavy))),
                DataColumn(label: Text('Status', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppConstants.primaryNavy))),
                DataColumn(label: Text('Actions', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppConstants.primaryNavy))),
              ],
              rows: filteredList.map((fps) {
                final isSelected = _selectedDrawerFps?.fpsId == fps.fpsId;
                return DataRow(
                  selected: isSelected,
                  onSelectChanged: (_) => setState(() => _selectedDrawerFps = fps),
                  cells: [
                    // FPS Name & Code
                    DataCell(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(fps.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppConstants.primaryNavy)),
                          Text('${fps.fpsId} • ${fps.registeredBeneficiaries} Cards', style: const TextStyle(fontSize: 10, color: AppConstants.textSecondary)),
                        ],
                      ),
                    ),
                    // Historical Demand
                    DataCell(Text('${(fps.historicalDemandKg / 1000).toStringAsFixed(1)} MT', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600))),
                    // Intent Demand
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('${(fps.declaredIntentKg / 1000).toStringAsFixed(1)} MT', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                          const SizedBox(width: 4),
                          if (fps.intentShiftKg > 50)
                            const Icon(Icons.arrow_upward_rounded, color: AppConstants.accentAmber, size: 13),
                        ],
                      ),
                    ),
                    // Forecast Demand
                    DataCell(Text('${(fps.forecastKg / 1000).toStringAsFixed(1)} MT', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: AppConstants.primaryNavy))),
                    // Inventory
                    DataCell(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('${(fps.inventoryKg / 1000).toStringAsFixed(1)} MT', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                          Text('${fps.inventoryUtilizationPct.toStringAsFixed(0)}% Cap', style: TextStyle(fontSize: 9.5, color: fps.inventoryUtilizationPct < 25 ? AppConstants.dangerRed : AppConstants.textSecondary)),
                        ],
                      ),
                    ),
                    // Recommended Dispatch
                    DataCell(Text('${((fps.forecastKg - fps.inventoryKg).clamp(0, 99999) / 1000).toStringAsFixed(1)} MT', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF15803D)))),
                    // Risk
                    DataCell(StatusBadge(status: fps.riskLevel, fontSize: 9.5)),
                    // Confidence
                    DataCell(const Text('94%', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600))),
                    // Status
                    DataCell(StatusBadge(status: fps.status, fontSize: 9.5)),
                    // Actions (Dossier, What-If, Decision)
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.info_outline_rounded, size: 17, color: AppConstants.primaryNavy),
                            tooltip: 'View FPS Dossier',
                            onPressed: () => _inspectFps(fps.fpsId),
                            constraints: const BoxConstraints(),
                            padding: const EdgeInsets.all(5),
                          ),
                          IconButton(
                            icon: const Icon(Icons.science_outlined, size: 17, color: AppConstants.accentBlue),
                            tooltip: 'What-If Forecast Analysis',
                            onPressed: () => _showForecastWhatIfDialog(fps.fpsId),
                            constraints: const BoxConstraints(),
                            padding: const EdgeInsets.all(5),
                          ),
                          IconButton(
                            icon: const Icon(Icons.tune_rounded, size: 17, color: Color(0xFFB45309)),
                            tooltip: 'Dispatch Decision Support',
                            onPressed: () => _showDispatchDecisionDialog(fps.fpsId),
                            constraints: const BoxConstraints(),
                            padding: const EdgeInsets.all(5),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String filterKey) {
    final isSelected = _selectedFilter == filterKey;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 11, fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600, color: isSelected ? Colors.white : AppConstants.textPrimary)),
      selected: isSelected,
      selectedColor: AppConstants.primaryNavy,
      backgroundColor: AppConstants.backgroundLight,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      onSelected: (_) => setState(() => _selectedFilter = filterKey),
    );
  }
}
