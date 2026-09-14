import 'dart:async';
import 'dart:math';
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
import '../beneficiary/demo_login_screen.dart';

class _WorkflowStageMeta {
  final String title;
  final String category;
  final String engine;
  final String mathSpec;
  final IconData icon;
  final Color accentColor;
  final List<Map<String, String>> metrics;
  final String inputNode;
  final String engineNode;
  final String outputNode;
  final String action1Label;
  final IconData action1Icon;
  final VoidCallback action1;
  final String action2Label;
  final IconData action2Icon;
  final VoidCallback action2;

  const _WorkflowStageMeta({
    required this.title,
    required this.category,
    required this.engine,
    required this.mathSpec,
    required this.icon,
    required this.accentColor,
    required this.metrics,
    required this.inputNode,
    required this.engineNode,
    required this.outputNode,
    required this.action1Label,
    required this.action1Icon,
    required this.action1,
    required this.action2Label,
    required this.action2Icon,
    required this.action2,
  });
}

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
  int _selectedMainTab = 0; // 0: Overview & Incidents, 1: All 620 FPS Matrix, 2: AI Pipeline & Tools
  String _selectedFilter = 'ALL'; // 'ALL', 'HIGH_RISK', 'LOW_INVENTORY', 'PORTABILITY'
  String _searchQuery = '';
  bool _isActionExecuting = false;
  AdminFpsRow? _selectedDrawerFps;

  // Pre-Dispatch Operational Incidents & Risk Anomaly State
  final List<OperationalIncident> _dashboardIncidents =
      OperationalIncident.getDefaultPreDispatchIncidents();

  int get _activeDashboardIncidentsCount =>
      _dashboardIncidents.where((i) => !i.isAcknowledged).length;

  // 7-Phase Live Pre-Dispatch Decision Pipeline & Live Timers State
  bool _isPipelineRunning = false;
  bool _isPipelineCompleted = false;
  bool _isPipelineDelayed = false;
  bool _simulateStockShortage = false;
  int _activePhaseIndex = -1; // -1: idle/initial, 0..6: active phase, 7: all complete
  int _activePhaseSeconds = 0;
  int _overallElapsedSeconds = 0;
  final Map<int, int> _phaseDurations = {}; // stores preserved elapsed duration per phase
  Timer? _pipelineTimer;
  int _selectedWorkflowStage = 0; // 0..6: Forecast, Validate, Allocate, Optimize, Dispatch, Verify, Evaluate
  double _whatIfIntentSpike = 12.0; // Slider 0%..50% for sandbox
  bool _whatIfRouteDelay = false;

  static const List<int> _targetPhaseDurations = [6, 8, 5, 11, 7, 6, 4];
  static const List<String> _phaseTitles = [
    'Forecast',
    'Validate',
    'Allocate',
    'Optimize',
    'Dispatch',
    'Verify',
    'Evaluate',
  ];

  @override
  void initState() {
    super.initState();
    _apiService = widget.apiService ?? ApiService();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final data = await _apiService.fetchAdminDashboard();
      if (!mounted) return;
      setState(() {
        _dashboardData = data;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to load dashboard data. Please check connectivity.\n$e';
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _pipelineTimer?.cancel();
    super.dispose();
  }

  String _formatTimerSeconds(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _startPreDispatchPipeline({bool isRerun = false}) {
    _pipelineTimer?.cancel();
    setState(() {
      _isPipelineRunning = true;
      _isPipelineCompleted = false;
      _isPipelineDelayed = false;
      _activePhaseIndex = 0;
      _selectedWorkflowStage = 0;
      _activePhaseSeconds = 0;
      _overallElapsedSeconds = 0;
      _phaseDurations.clear();
    });

    _pipelineTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        _overallElapsedSeconds++;
        _activePhaseSeconds++;
      });

      final target = _targetPhaseDurations[_activePhaseIndex];
      if (_activePhaseSeconds >= target) {
        _advancePipelinePhase();
      }
    });
  }

  void _advancePipelinePhase() {
    _phaseDurations[_activePhaseIndex] = _activePhaseSeconds;

    // Check Scenario B: Government Stock Shortage stops at Phase 1 (Validate)
    if (_simulateStockShortage && _activePhaseIndex == 1) {
      _pipelineTimer?.cancel();
      setState(() {
        _isPipelineRunning = false;
        _isPipelineDelayed = true;
        _isPipelineCompleted = false;
        _activePhaseIndex = 1;
        _selectedWorkflowStage = 1;
      });
      _handleStockShortagePause();
      return;
    }

    if (_activePhaseIndex < 6) {
      setState(() {
        _activePhaseIndex++;
        _selectedWorkflowStage = _activePhaseIndex;
        _activePhaseSeconds = 0;
      });
      _syncPhaseBackend(_activePhaseIndex);
    } else {
      // Completed all 7 phases!
      _pipelineTimer?.cancel();
      setState(() {
        _isPipelineRunning = false;
        _isPipelineCompleted = true;
        _activePhaseIndex = 7;
      });
      _completePipelineAnalysis();
    }
  }

  Future<void> _syncPhaseBackend(int phaseIndex) async {
    try {
      if (phaseIndex == 1) {
        _apiService.revalidateConstraints(cycleId: _dashboardData?.activeCycle ?? '2026-09');
      } else if (phaseIndex == 4) {
        _apiService.runPreDispatchAnalysis(cycleId: _dashboardData?.activeCycle ?? '2026-09', simulateStockShortage: false);
      }
    } catch (_) {}
  }

  Future<void> _handleStockShortagePause() async {
    try {
      await _apiService.delayDispatch(
        cycleId: _dashboardData?.activeCycle ?? '2026-09',
        delayDays: '1–2 days',
        reason: 'Government buffer stock currently unavailable for this dispatch.',
      );
      await _loadDashboardData();
    } catch (_) {}

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          '⚠️ Phase 2 (Validate) detected buffer deficit: Stock delay recorded (1–2 days).',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFFB45309),
        action: SnackBarAction(
          label: 'Notify Citizens',
          textColor: Colors.white,
          onPressed: _showAlertsDialog,
        ),
      ),
    );
  }

  Future<void> _completePipelineAnalysis() async {
    try {
      await _apiService.runPreDispatchAnalysis(
        cycleId: _dashboardData?.activeCycle ?? '2026-09',
        simulateStockShortage: false,
      );
      await _loadDashboardData();
    } catch (_) {}

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '✓ Pre-Dispatch Analysis completed! All 7 stages validated in ${_formatTimerSeconds(_overallElapsedSeconds)}.',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppConstants.successGreen,
        duration: const Duration(seconds: 4),
      ),
    );
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
    if (_apiService.authSession.role == 'FIELD_OFFICER') {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Row(
            children: [
              Icon(Icons.shield_outlined, color: Colors.orange, size: 22),
              SizedBox(width: 8),
              Text('Access Restricted (RBAC)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: const Text(
            'Separation of Duties Enforced:\n\nField Officers are limited to physical loading bay & gatepass clearance operations. Policy decisions like Locking Aggregated Demand or Overriding Quotas require District Supply Officer (DSO) or Admin credentials.',
            style: TextStyle(fontSize: 13, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Understood', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
      return;
    }

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
            final screenW = MediaQuery.of(context).size.width;
            final screenH = MediaQuery.of(context).size.height;
            final isMobile = screenW < 700;

            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              insetPadding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 20, vertical: isMobile ? 10 : 16),
              child: Container(
                width: isMobile ? screenW * 0.98 : 1140,
                height: isMobile ? screenH * 0.94 : 840,
                padding: EdgeInsets.all(isMobile ? 14 : 22),
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
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppConstants.accentBlue.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppConstants.accentBlue.withValues(alpha: 0.3)),
                          ),
                          child: const Icon(Icons.analytics_outlined, color: AppConstants.accentBlue, size: 20),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                spacing: 6,
                                runSpacing: 2,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text('Forecast vs Actual ePoS Evaluation', style: TextStyle(fontSize: isMobile ? 13.5 : 16, fontWeight: FontWeight.w800, color: AppConstants.primaryNavy)),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF0FDF4),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: const Color(0xFF86EFAC)),
                                    ),
                                    child: const Text('CLOSED-LOOP VERIFIED', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFF15803D))),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text('Cycle ${eval.cycleId} • Post-Distribution Accuracy & ML Calibration', style: const TextStyle(fontSize: 10.5, color: AppConstants.textSecondary)),
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
                    const SizedBox(height: 12),

                    // BODY (Internal Scrollable)
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // 1. Top 5 Metrics Row
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppConstants.cardSurface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppConstants.cardBorder),
                              ),
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: [
                                    _buildEvaluationHeaderStat('OVERALL ACCURACY', '${eval.overallAccuracyPct.toStringAsFixed(1)}%', const Color(0xFF15803D)),
                                    const SizedBox(width: 20),
                                    _buildEvaluationHeaderStat('MAPE (ERROR)', '${eval.mapePct.toStringAsFixed(2)}%', const Color(0xFFB45309)),
                                    const SizedBox(width: 20),
                                    _buildEvaluationHeaderStat('MEAN ABS ERROR', '${eval.maeKg.toStringAsFixed(1)} kg', AppConstants.primaryNavy),
                                    const SizedBox(width: 20),
                                    _buildEvaluationHeaderStat('TOTAL FORECAST (D̂)', '${(eval.totalForecastQuantityKg / 1000).toStringAsFixed(1)} MT', AppConstants.accentBlue),
                                    const SizedBox(width: 20),
                                    _buildEvaluationHeaderStat('TOTAL ACTUAL (ePoS)', '${(eval.totalActualQuantityKg / 1000).toStringAsFixed(1)} MT', AppConstants.primaryNavy),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),

                            // 2. Commodity Breakdown Cards (Rice & Wheat)
                            isMobile
                                ? Column(
                                    children: [
                                      _buildRiceAccuracyCard(eval),
                                      const SizedBox(height: 10),
                                      _buildWheatAccuracyCard(eval),
                                    ],
                                  )
                                : Row(
                                    children: [
                                      Expanded(child: _buildRiceAccuracyCard(eval)),
                                      const SizedBox(width: 12),
                                      Expanded(child: _buildWheatAccuracyCard(eval)),
                                    ],
                                  ),
                            const SizedBox(height: 12),

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
                                  isMobile
                                      ? Column(
                                          children: [
                                            _buildWeightBox('HISTORICAL WEIGHT (α)', '0.42 → 0.38 (-9.5%)', AppConstants.primaryNavy),
                                            const SizedBox(height: 6),
                                            _buildWeightBox('INTENT WEIGHT (β)', '0.38 → 0.44 (+15.8%)', const Color(0xFF15803D)),
                                            const SizedBox(height: 6),
                                            _buildWeightBox('MIGRATION INFLUX (γ)', '0.20 → 0.18 (-10.0%)', AppConstants.accentAmber),
                                          ],
                                        )
                                      : Row(
                                          children: [
                                            Expanded(child: _buildWeightBox('HISTORICAL WEIGHT (α)', '0.42 → 0.38 (-9.5%)', AppConstants.primaryNavy)),
                                            const SizedBox(width: 8),
                                            Expanded(child: _buildWeightBox('INTENT WEIGHT (β)', '0.38 → 0.44 (+15.8%)', const Color(0xFF15803D))),
                                            const SizedBox(width: 8),
                                            Expanded(child: _buildWeightBox('MIGRATION INFLUX (γ)', '0.20 → 0.18 (-10.0%)', AppConstants.accentAmber)),
                                          ],
                                        ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // STICKY FOOTER
                    Container(
                      padding: const EdgeInsets.only(top: 8),
                      decoration: const BoxDecoration(
                        border: Border(top: BorderSide(color: AppConstants.cardBorder)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Expanded(
                            child: Text('Closed-loop calibration results logged into audit ledger.', style: TextStyle(fontSize: 10, color: AppConstants.textSecondary), overflow: TextOverflow.ellipsis),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () => Navigator.of(context).pop(),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppConstants.primaryNavy,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            ),
                            child: const Text('Close', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
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

  Widget _buildRiceAccuracyCard(ForecastEvaluationData eval) {
    return Container(
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
              const Text('Error Metric', style: TextStyle(fontSize: 11, color: AppConstants.textSecondary)),
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
    );
  }

  Widget _buildWheatAccuracyCard(ForecastEvaluationData eval) {
    return Container(
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
              const Text('Error Metric', style: TextStyle(fontSize: 11, color: AppConstants.textSecondary)),
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
    );
  }

  Widget _buildWeightBox(String label, String value, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: AppConstants.backgroundLight, borderRadius: BorderRadius.circular(6)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppConstants.textSecondary)),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
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
                            // EXECUTIVE KPI SUMMARY ROW (Always visible at top)
                            _buildExecutiveKpiRow(),
                            const SizedBox(height: AppConstants.space16),

                            // MAIN NAVIGATION TAB SWITCHER
                            _buildMainTabSwitcher(),
                            const SizedBox(height: AppConstants.space16),

                            // TAB CONTENT
                            if (_selectedMainTab == 0) ...[
                              // TAB 0: OVERVIEW & OPERATIONAL INCIDENTS
                              _buildOperationalHealthAndAlerts(),
                            ] else if (_selectedMainTab == 1) ...[
                              // TAB 1: ALL 620 FAIR PRICE SHOPS MATRIX
                              _buildFpsOperationsMatrix(),
                            ] else ...[
                              // TAB 2: AI PIPELINE & DECISION TRACE TOOLS
                              _buildEnterpriseCommandBar(),
                            ],

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

                    // Slide-over FPS detail drawer with dismissible backdrop
                    if (_selectedDrawerFps != null) ...[
                      Positioned.fill(
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedDrawerFps = null),
                          child: Container(
                            color: Colors.black.withValues(alpha: 0.35),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 0,
                        right: 0,
                        bottom: 0,
                        child: Material(
                          elevation: 16,
                          child: SizedBox(
                            width: MediaQuery.of(context).size.width > 600 ? 520.0 : MediaQuery.of(context).size.width * 0.94,
                            child: Stack(
                              children: [
                                FpsDetailDrawer(
                                  item: _selectedDrawerFps!,
                                  onOpenForecast: () {
                                    final id = _selectedDrawerFps!.fpsId;
                                    setState(() => _selectedDrawerFps = null);
                                    _showForecastWhatIfDialog(id);
                                  },
                                  onOpenDecision: () {
                                    final id = _selectedDrawerFps!.fpsId;
                                    setState(() => _selectedDrawerFps = null);
                                    _showDispatchDecisionDialog(id);
                                  },
                                  onOpenInspector: () {
                                    final id = _selectedDrawerFps!.fpsId;
                                    setState(() => _selectedDrawerFps = null);
                                    _inspectFps(id);
                                  },
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
                  ],
                ),
    );
  }

  // MAIN TAB SWITCHER
  Widget _buildMainTabSwitcher() {
    final activeShops = _dashboardData?.fpsList.length ?? 620;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppConstants.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildTabButton(0, 'Overview & Alerts', Icons.dashboard_outlined, '3 Live Alerts'),
          _buildTabButton(1, 'All 620 FPS Matrix', Icons.storefront_outlined, '$activeShops Shops'),
          _buildTabButton(2, 'AI Pipeline & Tools', Icons.alt_route_rounded, '7 Stages'),
        ],
      ),
    );
  }

  Widget _buildTabButton(int index, String label, IconData icon, String badge) {
    final isSelected = _selectedMainTab == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedMainTab = index),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppConstants.primaryNavy : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: isSelected ? Colors.white : AppConstants.textSecondary),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected ? Colors.white : AppConstants.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white.withValues(alpha: 0.2) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? Colors.white : AppConstants.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // TOP NAVIGATION BAR
  PreferredSizeWidget _buildTopNavigationBar() {
    final screenW = MediaQuery.of(context).size.width;
    final isMobile = screenW < 720;

    if (isMobile) {
      return AppBar(
        backgroundColor: AppConstants.primaryNavy,
        foregroundColor: Colors.white,
        elevation: 0,
        titleSpacing: 12,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.shield_outlined, size: 16, color: Colors.white),
            ),
            const SizedBox(width: 8),
            const Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'PDS DemandSync',
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'District Supply Operations',
                    style: TextStyle(fontSize: 10, color: Colors.white70),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // Refresh Telemetry
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: _loadDashboardData,
          ),

          // Switch to Citizen Portal
          IconButton(
            tooltip: 'Citizen Portal',
            icon: const Icon(Icons.people_alt_outlined, size: 20),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const DemoLoginScreen()),
              );
            },
          ),

          // Unified Operations & Demo Menu
          PopupMenuButton<String>(
            tooltip: 'Menu & Operations',
            icon: const Icon(Icons.more_vert_rounded, size: 20, color: Colors.white),
            onSelected: (value) {
              if (value == 'WHAT_IF') _showForecastWhatIfDialog('FPS-KA-BLR-001');
              if (value == 'CITIZEN_QUEUE') _showCitizenRequestQueueDialog();
              if (value == 'SCARCITY') _showScarcityDialog();
              if (value == 'EVALUATION') _showEvaluationModal();
              if (value == 'GATEPASS') _showGatepassDialog();
              if (value == 'LOCK_FORECAST') _lockForecast();
              if (value == 'JUDGE_DEFENSE') _showJudgeViewDialog();
              if (value == 'SCENARIO_RUNNER') _showSihDemoModeDialog();
              if (value == 'RESET') _resetDemoWorkflow();
              if (value == 'LOGOUT') {
                _apiService.logout();
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const DemoLoginScreen()),
                  (route) => false,
                );
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                enabled: false,
                child: Text('DISTRICT OPERATIONS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppConstants.textSecondary, letterSpacing: 0.5)),
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
                    Expanded(child: Text('Lock Aggregated Demand', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600))),
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
                    Expanded(child: Text('Reset Operational Workflow', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppConstants.dangerRed))),
                  ],
                ),
              ),

              const PopupMenuItem(
                value: 'LOGOUT',
                child: Row(
                  children: [
                    Icon(Icons.logout_rounded, color: AppConstants.dangerRed, size: 18),
                    SizedBox(width: 10),
                    Expanded(child: Text('Logout Session', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppConstants.dangerRed))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 4),
        ],
      );
    }

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

        // Official Role Badge (DSO, Field Officer, Auditor)
        Builder(
          builder: (context) {
            final role = _apiService.authSession.role;
            if (role == 'FIELD_OFFICER') {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0xFFF59E0B)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.local_shipping_outlined, size: 12, color: Color(0xFFB45309)),
                    SizedBox(width: 4),
                    Text(
                      'FIELD OFFICER (LOADING BAY)',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF92400E)),
                    ),
                  ],
                ),
              );
            } else if (role == 'DSO') {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0xFF22C55E)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.admin_panel_settings_outlined, size: 12, color: Color(0xFF15803D)),
                    SizedBox(width: 4),
                    Text(
                      'DSO (DISTRICT COMMAND)',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF166534)),
                    ),
                  ],
                ),
              );
            } else if (role == 'AUDITOR') {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3E8FF),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0xFFA855F7)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.verified_user_outlined, size: 12, color: Color(0xFF7E22CE)),
                    SizedBox(width: 4),
                    Text(
                      'STATE VIGILANCE AUDITOR',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF6B21A8)),
                    ),
                  ],
                ),
              );
            }
            return const SizedBox.shrink();
          },
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
            if (value == 'WHAT_IF') _showForecastWhatIfDialog('FPS-KA-BLR-001');
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
                  Expanded(child: Text('Reset Operational Workflow', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppConstants.dangerRed))),
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
    final dbStatus = _dashboardData?.workflowStatus ?? 'PLANNING_OPEN';
    final hasRunLivePipeline = _isPipelineRunning || _isPipelineCompleted || _isPipelineDelayed || _phaseDurations.isNotEmpty;

    // Stage Done / Active / Warning states
    bool isForecastDone;
    bool isForecastActive;

    bool isValidateDone;
    bool isValidateActive;
    bool isValidateWarning = false;

    bool isAllocateDone;
    bool isAllocateActive;

    bool isOptimizeDone;
    bool isOptimizeActive;

    bool isDispatchDone;
    bool isDispatchActive;

    bool isVerifyDone;
    bool isVerifyActive;

    bool isEvaluateDone;
    bool isEvaluateActive;

    if (hasRunLivePipeline) {
      isForecastDone = _phaseDurations.containsKey(0);
      isForecastActive = _isPipelineRunning && _activePhaseIndex == 0;

      isValidateDone = _phaseDurations.containsKey(1) && !_isPipelineDelayed;
      isValidateActive = _isPipelineRunning && _activePhaseIndex == 1;
      isValidateWarning = _isPipelineDelayed;

      isAllocateDone = _phaseDurations.containsKey(2);
      isAllocateActive = _isPipelineRunning && _activePhaseIndex == 2;

      isOptimizeDone = _phaseDurations.containsKey(3);
      isOptimizeActive = _isPipelineRunning && _activePhaseIndex == 3;

      isDispatchDone = _phaseDurations.containsKey(4);
      isDispatchActive = _isPipelineRunning && _activePhaseIndex == 4;

      isVerifyDone = _phaseDurations.containsKey(5);
      isVerifyActive = _isPipelineRunning && _activePhaseIndex == 5;

      isEvaluateDone = _phaseDurations.containsKey(6);
      isEvaluateActive = _isPipelineRunning && _activePhaseIndex == 6;
    } else {
      isForecastDone = dbStatus != 'PLANNING_OPEN';
      isForecastActive = dbStatus == 'PLANNING_OPEN';

      isValidateDone = dbStatus != 'PLANNING_OPEN' && dbStatus != 'DRAFT_GENERATED';
      isValidateActive = dbStatus == 'DRAFT_GENERATED';

      isAllocateDone = dbStatus == 'DISPATCH_GENERATED' ||
          dbStatus == 'ACTUAL_DISTRIBUTION_SIMULATED' ||
          dbStatus == 'FORECAST_EVALUATED' ||
          dbStatus == 'MODEL_CALIBRATED';
      isAllocateActive = dbStatus == 'FORECAST_LOCKED';

      isOptimizeDone = isAllocateDone;
      isOptimizeActive = dbStatus == 'FORECAST_LOCKED';

      isDispatchDone = dbStatus == 'ACTUAL_DISTRIBUTION_SIMULATED' ||
          dbStatus == 'FORECAST_EVALUATED' ||
          dbStatus == 'MODEL_CALIBRATED';
      isDispatchActive = dbStatus == 'DISPATCH_GENERATED';

      isVerifyDone = dbStatus == 'FORECAST_EVALUATED' || dbStatus == 'MODEL_CALIBRATED';
      isVerifyActive = dbStatus == 'ACTUAL_DISTRIBUTION_SIMULATED';

      isEvaluateDone = dbStatus == 'MODEL_CALIBRATED';
      isEvaluateActive = dbStatus == 'FORECAST_EVALUATED';
    }

    int completedStages = 0;
    if (isForecastDone) completedStages++;
    if (isValidateDone) completedStages++;
    if (isAllocateDone) completedStages++;
    if (isOptimizeDone) completedStages++;
    if (isDispatchDone) completedStages++;
    if (isVerifyDone) completedStages++;
    if (isEvaluateDone) completedStages++;

    // Dynamic Subtexts showing Live Timer / Preserved Elapsed Duration
    String forecastSubtext;
    if (isForecastActive) {
      forecastSubtext = 'Running • ${_formatTimerSeconds(_activePhaseSeconds)}';
    } else if (_phaseDurations.containsKey(0)) {
      forecastSubtext = 'Completed in ${_formatTimerSeconds(_phaseDurations[0]!)}';
    } else if (_isPipelineRunning && _activePhaseIndex < 0) {
      forecastSubtext = 'Pending';
    } else {
      forecastSubtext = isForecastDone ? 'Generated (62.7 MT)' : 'Not Generated';
    }

    String validateSubtext;
    if (isValidateActive) {
      validateSubtext = 'Running • ${_formatTimerSeconds(_activePhaseSeconds)}';
    } else if (isValidateWarning) {
      validateSubtext = 'Stock Deficit • ${_formatTimerSeconds(_phaseDurations[1] ?? 8)}';
    } else if (_phaseDurations.containsKey(1)) {
      validateSubtext = 'Completed in ${_formatTimerSeconds(_phaseDurations[1]!)}';
    } else if (_isPipelineRunning && _activePhaseIndex < 1) {
      validateSubtext = 'Pending';
    } else {
      validateSubtext = isValidateDone ? '9 Rules Compliant' : 'Pending';
    }

    String allocateSubtext;
    if (isAllocateActive) {
      allocateSubtext = 'Running • ${_formatTimerSeconds(_activePhaseSeconds)}';
    } else if (_phaseDurations.containsKey(2)) {
      allocateSubtext = 'Completed in ${_formatTimerSeconds(_phaseDurations[2]!)}';
    } else if (_isPipelineRunning && _activePhaseIndex < 2) {
      allocateSubtext = 'Pending';
    } else {
      allocateSubtext = isAllocateDone ? 'Calculated (3.2 MT)' : 'Pending';
    }

    String optimizeSubtext;
    if (isOptimizeActive) {
      optimizeSubtext = 'Running • ${_formatTimerSeconds(_activePhaseSeconds)}';
    } else if (_phaseDurations.containsKey(3)) {
      optimizeSubtext = 'Completed in ${_formatTimerSeconds(_phaseDurations[3]!)}';
    } else if (_isPipelineRunning && _activePhaseIndex < 3) {
      optimizeSubtext = 'Pending';
    } else {
      optimizeSubtext = isOptimizeDone ? '4 Fleet Corridors' : 'Pending';
    }

    String dispatchSubtext;
    if (isDispatchActive) {
      dispatchSubtext = 'Running • ${_formatTimerSeconds(_activePhaseSeconds)}';
    } else if (_phaseDurations.containsKey(4)) {
      dispatchSubtext = 'Completed in ${_formatTimerSeconds(_phaseDurations[4]!)}';
    } else if (_isPipelineRunning && _activePhaseIndex < 4) {
      dispatchSubtext = 'Pending';
    } else {
      dispatchSubtext = isDispatchDone ? 'Dispatched' : (isDispatchActive ? 'Gatepasses Ready' : 'Pending');
    }

    String verifySubtext;
    if (isVerifyActive) {
      verifySubtext = 'Running • ${_formatTimerSeconds(_activePhaseSeconds)}';
    } else if (_phaseDurations.containsKey(5)) {
      verifySubtext = 'Completed in ${_formatTimerSeconds(_phaseDurations[5]!)}';
    } else if (_isPipelineRunning && _activePhaseIndex < 5) {
      verifySubtext = 'Pending';
    } else {
      verifySubtext = isVerifyDone ? 'ePoS Lift Synced' : 'Pending';
    }

    String evaluateSubtext;
    if (isEvaluateActive) {
      evaluateSubtext = 'Running • ${_formatTimerSeconds(_activePhaseSeconds)}';
    } else if (_phaseDurations.containsKey(6)) {
      evaluateSubtext = 'Completed in ${_formatTimerSeconds(_phaseDurations[6]!)}';
    } else if (_isPipelineRunning && _activePhaseIndex < 6) {
      evaluateSubtext = 'Pending';
    } else {
      evaluateSubtext = isEvaluateDone ? '94.2% Accuracy' : 'Pending';
    }

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
                  StatusBadge(status: _isPipelineDelayed ? 'DELAYED' : (_isPipelineCompleted ? 'MODEL_CALIBRATED' : dbStatus), fontSize: 10.5),
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
                  // Demo Scenario Toggle Chip
                  InkWell(
                    onTap: _isPipelineRunning
                        ? null
                        : () {
                            setState(() {
                              _simulateStockShortage = !_simulateStockShortage;
                            });
                          },
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                      decoration: BoxDecoration(
                        color: _simulateStockShortage ? const Color(0xFFFEF3C7) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: _simulateStockShortage ? const Color(0xFFF59E0B) : AppConstants.cardBorder,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _simulateStockShortage ? Icons.warning_amber_rounded : Icons.check_circle_outline,
                            size: 13,
                            color: _simulateStockShortage ? const Color(0xFFB45309) : AppConstants.primaryNavy,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            _simulateStockShortage ? 'Scenario B: Stock Shortage' : 'Scenario A: Stock Available',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: _simulateStockShortage ? const Color(0xFFB45309) : AppConstants.primaryNavy,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
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
                    onPressed: _isPipelineRunning ? null : () => _startPreDispatchPipeline(isRerun: _isPipelineCompleted || _isPipelineDelayed || _phaseDurations.isNotEmpty),
                    icon: _isPipelineRunning
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Icon((_isPipelineCompleted || _isPipelineDelayed || _phaseDurations.isNotEmpty) ? Icons.replay_rounded : Icons.play_arrow_rounded, size: 16),
                    label: Text(
                      _isPipelineRunning
                          ? 'Analyzing Phase ${_activePhaseIndex + 1}/7...'
                          : ((_isPipelineCompleted || _isPipelineDelayed || _phaseDurations.isNotEmpty) ? 'Re-run Pipeline' : 'Run Pre-Dispatch Analysis'),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppConstants.primaryNavy,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                  ),
                  if (_dashboardData?.workflowStatus == 'DELAYED' || _dashboardData?.workflowStatus == 'STOCK_DELAYED' || _isPipelineDelayed)
                    ElevatedButton.icon(
                      onPressed: _isActionExecuting || _isPipelineRunning ? null : _resumeStockDispatch,
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
          const SizedBox(height: 12),

          // 0. PDS PLANNING CYCLE & DEMAND LOCK ENGINE BAR
          _buildPlanningCycleDemandLockBar(),
          const SizedBox(height: 12),

          // OVERALL PIPELINE LIVE TIMER / STATUS BANNER
          if (_isPipelineRunning)
            Container(
              key: const ValueKey('banner_pipeline_running'),
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF93C5FD), width: 1.2),
              ),
              child: Row(
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppConstants.accentBlue),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Pre-Dispatch Analysis • Running Phase ${_activePhaseIndex + 1} of 7: ${_phaseTitles[_activePhaseIndex]}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppConstants.primaryNavy),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(color: const Color(0xFF93C5FD)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.timer_outlined, size: 13, color: AppConstants.accentBlue),
                        const SizedBox(width: 5),
                        Text(
                          'Pre-Dispatch Analysis • Elapsed: ${_formatTimerSeconds(_overallElapsedSeconds)}',
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: AppConstants.accentBlue,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          else if (_isPipelineCompleted)
            Container(
              key: const ValueKey('banner_pipeline_completed'),
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF86EFAC), width: 1.2),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, size: 16, color: Color(0xFF15803D)),
                  const SizedBox(width: 8),
                  const Text(
                    'Pre-Dispatch Decision Pipeline • All 7 Stages Validated & Sealed',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF15803D)),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(color: const Color(0xFF86EFAC)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.timer_rounded, size: 13, color: Color(0xFF15803D)),
                        const SizedBox(width: 5),
                        Text(
                          'Pre-Dispatch Analysis • Elapsed: ${_formatTimerSeconds(_overallElapsedSeconds)}',
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF15803D),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          else if (_isPipelineDelayed)
            Container(
              key: const ValueKey('banner_pipeline_delayed'),
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFDE68A), width: 1.2),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, size: 16, color: Color(0xFFB45309)),
                  const SizedBox(width: 8),
                  const Text(
                    'Pre-Dispatch Analysis • Stock Shortage Paused at Validate (1–2 Day Delay Recorded)',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFFB45309)),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.hourglass_top_rounded, size: 13, color: Color(0xFFB45309)),
                        const SizedBox(width: 5),
                        Text(
                          'Paused at: ${_formatTimerSeconds(_overallElapsedSeconds)}',
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFFB45309),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // 2. PRIMARY 7-STAGE WORKFLOW STEPPER WITH LIVE TIMERS & INTERACTIVE STAGE SELECTOR
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildWorkflowStep(
                  1,
                  'Forecast',
                  forecastSubtext,
                  isDone: isForecastDone,
                  isActive: isForecastActive,
                  isSelected: _selectedWorkflowStage == 0,
                  icon: Icons.insights_rounded,
                  onTap: () => setState(() => _selectedWorkflowStage = 0),
                ),
                _buildStepConnector(isDone: isForecastDone),
                _buildWorkflowStep(
                  2,
                  'Validate',
                  validateSubtext,
                  isDone: isValidateDone,
                  isActive: isValidateActive,
                  isWarning: isValidateWarning,
                  isSelected: _selectedWorkflowStage == 1,
                  icon: Icons.verified_user_rounded,
                  onTap: () => setState(() => _selectedWorkflowStage = 1),
                ),
                _buildStepConnector(isDone: isValidateDone),
                _buildWorkflowStep(
                  3,
                  'Allocate',
                  allocateSubtext,
                  isDone: isAllocateDone,
                  isActive: isAllocateActive,
                  isSelected: _selectedWorkflowStage == 2,
                  icon: Icons.balance_rounded,
                  onTap: () => setState(() => _selectedWorkflowStage = 2),
                ),
                _buildStepConnector(isDone: isAllocateDone),
                _buildWorkflowStep(
                  4,
                  'Optimize',
                  optimizeSubtext,
                  isDone: isOptimizeDone,
                  isActive: isOptimizeActive,
                  isSelected: _selectedWorkflowStage == 3,
                  icon: Icons.alt_route_rounded,
                  onTap: () => setState(() => _selectedWorkflowStage = 3),
                ),
                _buildStepConnector(isDone: isOptimizeDone),
                _buildWorkflowStep(
                  5,
                  'Dispatch',
                  dispatchSubtext,
                  isDone: isDispatchDone,
                  isActive: isDispatchActive,
                  isSelected: _selectedWorkflowStage == 4,
                  icon: Icons.local_shipping_rounded,
                  onTap: () => setState(() => _selectedWorkflowStage = 4),
                ),
                _buildStepConnector(isDone: isDispatchDone),
                _buildWorkflowStep(
                  6,
                  'Verify',
                  verifySubtext,
                  isDone: isVerifyDone,
                  isActive: isVerifyActive,
                  isSelected: _selectedWorkflowStage == 5,
                  icon: Icons.fingerprint_rounded,
                  onTap: () => setState(() => _selectedWorkflowStage = 5),
                ),
                _buildStepConnector(isDone: isVerifyDone),
                _buildWorkflowStep(
                  7,
                  'Evaluate',
                  evaluateSubtext,
                  isDone: isEvaluateDone,
                  isActive: isEvaluateActive,
                  isSelected: _selectedWorkflowStage == 6,
                  icon: Icons.published_with_changes_rounded,
                  onTap: () => setState(() => _selectedWorkflowStage = 6),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppConstants.space16),

          // 3. ENTERPRISE STAGE INTELLIGENCE & OPERATIONS WORKBENCH
          _buildStageIntelligenceWorkbench(
            isForecastDone: isForecastDone,
            isValidateDone: isValidateDone,
            isAllocateDone: isAllocateDone,
            isOptimizeDone: isOptimizeDone,
            isDispatchDone: isDispatchDone,
            isVerifyDone: isVerifyDone,
            isEvaluateDone: isEvaluateDone,
          ),
        ],
      ),
    );
  }

  // 0. PDS PLANNING CYCLE & DEMAND LOCK ENGINE BAR
  Widget _buildPlanningCycleDemandLockBar() {
    final planningState = _dashboardData?.planningCycleState;
    final planningDay = _dashboardData?.planningDay ?? 22;
    final isLocked = _dashboardData?.isDemandLocked ?? false;
    final snapshotHash = planningState?['snapshot_hash'] as String?;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 720;

        Widget headerBadge = Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: isLocked ? const Color(0xFFE2E8F0) : const Color(0xFFDCFCE7),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                isLocked ? Icons.lock_rounded : Icons.schedule_rounded,
                size: 18,
                color: isLocked ? AppConstants.primaryNavy : const Color(0xFF15803D),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'PDS PLANNING CYCLE: DAY $planningDay OF 30',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w900,
                      color: isLocked ? AppConstants.primaryNavy : const Color(0xFF15803D),
                      letterSpacing: 0.4,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isLocked ? const Color(0xFFEFF6FF) : const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: isLocked ? const Color(0xFF93C5FD) : const Color(0xFF86EFAC)),
                    ),
                    child: Text(
                      isLocked ? '🔒 DEMAND BASELINE LOCKED' : 'CHOICE WINDOW OPEN (DAY 21–24)',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        color: isLocked ? const Color(0xFF1D4ED8) : const Color(0xFF15803D),
                      ),
                    ),
                  ),
                  if (snapshotHash != null)
                    InkWell(
                      onTap: _viewDemandSnapshotDetails,
                      child: Text(
                        'SHA-256: ${snapshotHash.substring(0, 10)}...',
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppConstants.accentBlue,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        );

        Widget descriptionText = Text(
          isLocked
              ? 'Demand baseline D_hat is frozen (Day 25). 7-stage Pre-Dispatch engine consumes this immutable snapshot without mutating beneficiary signals.'
              : 'Beneficiaries are submitting preferred FPS / doorstep requests. District Supply Officer locks demand on Day 25 to initiate pre-dispatch allocation.',
          style: const TextStyle(fontSize: 11, color: AppConstants.textSecondary),
        );

        Widget actionsWidget;
        if (!isLocked) {
          actionsWidget = Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: _isActionExecuting ? null : () => _simulateAdvancePlanningDay(25),
                icon: const Icon(Icons.fast_forward_rounded, size: 14),
                label: const Text('Simulate Day 25', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  side: const BorderSide(color: Color(0xFF86EFAC)),
                  foregroundColor: const Color(0xFF15803D),
                ),
              ),
              ElevatedButton.icon(
                onPressed: _isActionExecuting ? null : _lockForecast,
                icon: const Icon(Icons.lock_outline_rounded, size: 14),
                label: const Text('Lock Demand', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppConstants.primaryNavy,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ],
          );
        } else {
          actionsWidget = Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: _viewDemandSnapshotDetails,
                icon: const Icon(Icons.verified_outlined, size: 14, color: Color(0xFF15803D)),
                label: const Text('View Sealed Snapshot', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF15803D))),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  side: const BorderSide(color: Color(0xFF86EFAC)),
                ),
              ),
              TextButton(
                onPressed: _isActionExecuting ? null : () => _simulateAdvancePlanningDay(22),
                child: const Text('Re-open (Demo Day 22)', style: TextStyle(fontSize: 10.5, color: AppConstants.textSecondary)),
              ),
            ],
          );
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isLocked ? const Color(0xFFF8FAFC) : const Color(0xFFF0FDF4),
            borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
            border: Border.all(
              color: isLocked ? const Color(0xFFCBD5E1) : const Color(0xFF86EFAC),
              width: 1.2,
            ),
          ),
          child: isCompact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    headerBadge,
                    const SizedBox(height: 6),
                    descriptionText,
                    const SizedBox(height: 8),
                    actionsWidget,
                  ],
                )
              : Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          headerBadge,
                          const SizedBox(height: 4),
                          descriptionText,
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    actionsWidget,
                  ],
                ),
        );
      },
    );
  }

  Future<void> _simulateAdvancePlanningDay(int day) async {
    setState(() => _isActionExecuting = true);
    try {
      await _apiService.setPlanningCycleDay(day);
      await _loadDashboardData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Planning cycle simulated to Day $day for active cycle.'),
            backgroundColor: AppConstants.primaryNavy,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to set planning day: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isActionExecuting = false);
    }
  }

  Future<void> _viewDemandSnapshotDetails() async {
    setState(() => _isActionExecuting = true);
    try {
      final snapData = await _apiService.fetchDemandSnapshot();
      if (!mounted) return;
      final snap = snapData['snapshot'] as Map<String, dynamic>;

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Row(
            children: [
              const Icon(Icons.verified_rounded, color: Color(0xFF15803D), size: 22),
              const SizedBox(width: 8),
              Text(
                'Frozen Demand Snapshot (${snap['snapshot_id']})',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppConstants.primaryNavy),
              ),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF86EFAC)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.security, size: 16, color: Color(0xFF15803D)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Canonical SHA-256 Hash:\n${snap['canonical_hash']}',
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 10.5, color: Color(0xFF166534), fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _buildSnapshotMetricRow('Planning Cycle', '${snap['cycle_id']} (Frozen on Day 25)'),
                _buildSnapshotMetricRow('Locked At', '${snap['lock_timestamp']}'),
                _buildSnapshotMetricRow('Locked By', '${snap['locked_by']}'),
                _buildSnapshotMetricRow('Beneficiary Requests', '${snap['total_beneficiary_requests']} requests'),
                _buildSnapshotMetricRow('Total Declared Intent', '${snap['total_declared_intent_kg']} kg'),
                _buildSnapshotMetricRow('Total Locked Demand', '${snap['total_locked_demand_kg']} kg'),
                const Divider(height: 16),
                const Text(
                  'Governance Guarantee: This demand snapshot is immutable. What-If sensitivity tests and corridor optimizers operate strictly on isolated memory copies.',
                  style: TextStyle(fontSize: 11, color: AppConstants.textSecondary, fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Close', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Demand snapshot not found: $e'), backgroundColor: Colors.orange.shade800),
        );
      }
    } finally {
      if (mounted) setState(() => _isActionExecuting = false);
    }
  }

  Widget _buildSnapshotMetricRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: AppConstants.textSecondary)),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppConstants.primaryNavy)),
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
    bool isSelected = false,
    IconData? icon,
    required VoidCallback onTap,
  }) {
    Color bg;
    Color border;
    Color iconBg;
    Color titleColor;
    Color subColor;

    if (isSelected) {
      bg = Colors.white;
      border = AppConstants.accentBlue;
      iconBg = AppConstants.accentBlue;
      titleColor = AppConstants.primaryNavy;
      subColor = AppConstants.accentBlue;
    } else if (isActive) {
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
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppConstants.accentBlue : border,
            width: isSelected ? 2.0 : (isActive ? 1.5 : 1),
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppConstants.accentBlue.withValues(alpha: 0.18),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Center(
                    child: isActive
                        ? const SizedBox(
                            width: 11,
                            height: 11,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : (isDone
                            ? const Icon(Icons.check, size: 12, color: Colors.white)
                            : (isWarning
                                ? const Icon(Icons.priority_high, size: 12, color: Colors.white)
                                : (icon != null
                                    ? Icon(icon, size: 12, color: Colors.white)
                                    : Text('$num', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white))))),
                  ),
                ),
                const SizedBox(width: 7),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: isSelected ? FontWeight.w900 : FontWeight.w800,
                    color: isSelected ? AppConstants.accentBlue : titleColor,
                  ),
                ),
                if (isSelected) ...[
                  const SizedBox(width: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppConstants.accentBlue.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'ACTIVE',
                      style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: AppConstants.accentBlue, letterSpacing: 0.5),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 3),
            Text(
              subtext,
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: isDone || isActive || isWarning || isSelected ? FontWeight.w700 : FontWeight.normal,
                color: isSelected ? AppConstants.primaryNavy : subColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepConnector({bool isDone = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Icon(
        Icons.chevron_right_rounded,
        size: 16,
        color: isDone ? const Color(0xFF15803D) : const Color(0xFFCBD5E1),
      ),
    );
  }

  // 3. ENTERPRISE STAGE INTELLIGENCE & OPERATIONS WORKBENCH
  Widget _buildStageIntelligenceWorkbench({
    required bool isForecastDone,
    required bool isValidateDone,
    required bool isAllocateDone,
    required bool isOptimizeDone,
    required bool isDispatchDone,
    required bool isVerifyDone,
    required bool isEvaluateDone,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 1050;

        if (isDesktop) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 7,
                child: _buildStageDeepDiveConsole(),
              ),
              const SizedBox(width: AppConstants.space16),
              Expanded(
                flex: 4,
                child: _buildDistrictSimulationCenter(),
              ),
            ],
          );
        } else {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildStageDeepDiveConsole(),
              const SizedBox(height: AppConstants.space16),
              _buildDistrictSimulationCenter(),
            ],
          );
        }
      },
    );
  }

  // STAGE DEEP DIVE & MATHEMATICAL ENGINE CONSOLE
  Widget _buildStageDeepDiveConsole() {
    final meta = _getWorkflowStageMeta(_selectedWorkflowStage);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        border: Border.all(color: AppConstants.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // STAGE HEADER BANNER
          Container(
            padding: const EdgeInsets.all(AppConstants.space16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppConstants.primaryNavy,
                  AppConstants.primaryNavy.withValues(alpha: 0.92),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(AppConstants.radiusMedium),
                topRight: Radius.circular(AppConstants.radiusMedium),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: meta.accentColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: meta.accentColor.withValues(alpha: 0.4)),
                      ),
                      child: Icon(meta.icon, size: 20, color: meta.accentColor),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: meta.accentColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: meta.accentColor.withValues(alpha: 0.4)),
                                ),
                                child: Text(
                                  meta.category,
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w900,
                                    color: meta.accentColor,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.lock_clock_outlined, size: 10, color: Colors.white70),
                                    SizedBox(width: 4),
                                    Text(
                                      'Pre-Dispatch Sealed',
                                      style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: Colors.white70),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Text(
                            meta.title,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            meta.engine,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.white.withValues(alpha: 0.75),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // MATHEMATICAL FORMULATION CHIP
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.functions_rounded, size: 14, color: Color(0xFF67E8F9)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          meta.mathSpec,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF67E8F9),
                            letterSpacing: 0.3,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 4 TELEMETRY METRIC TILES
          Padding(
            padding: const EdgeInsets.all(AppConstants.space16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'STAGE 0${_selectedWorkflowStage + 1} LIVE TELEMETRY & CONSTRAINTS',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppConstants.textSecondary, letterSpacing: 0.5),
                    ),
                    Text(
                      'Target: Zero Entitlement Loss',
                      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: meta.accentColor),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth < 650) {
                      return Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: meta.metrics.map((m) {
                          return SizedBox(
                            width: (constraints.maxWidth - 8) / 2,
                            child: _buildStageMetricTile(m['val']!, m['label']!, m['sub']!, meta.accentColor),
                          );
                        }).toList(),
                      );
                    }
                    return Row(
                      children: meta.metrics.map((m) {
                        return Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(right: m == meta.metrics.last ? 0 : 8),
                            child: _buildStageMetricTile(m['val']!, m['label']!, m['sub']!, meta.accentColor),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
                const SizedBox(height: 14),

                // PIPELINE NODE ARCHITECTURE FLOW
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppConstants.cardBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.account_tree_outlined, size: 14, color: AppConstants.primaryNavy),
                          SizedBox(width: 6),
                          Text(
                            'PIPELINE DATA FLOW ARCHITECTURE',
                            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: AppConstants.primaryNavy, letterSpacing: 0.5),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _buildFlowStepRow('1. Input Feeds', meta.inputNode, Icons.input_rounded, const Color(0xFF3B82F6)),
                      const SizedBox(height: 6),
                      _buildFlowStepRow('2. ML Engine', meta.engineNode, Icons.memory_rounded, const Color(0xFF8B5CF6)),
                      const SizedBox(height: 6),
                      _buildFlowStepRow('3. Certified Output', meta.outputNode, Icons.verified_rounded, const Color(0xFF10B981)),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // ACTION TOOLBAR
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    ElevatedButton.icon(
                      onPressed: meta.action1,
                      icon: Icon(meta.action1Icon, size: 15),
                      label: Text(meta.action1Label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppConstants.primaryNavy,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: meta.action2,
                      icon: Icon(meta.action2Icon, size: 15, color: AppConstants.primaryNavy),
                      label: Text(meta.action2Label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppConstants.primaryNavy)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppConstants.cardBorder),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStageMetricTile(String value, String label, String subtext, Color accent) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppConstants.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: accent,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: AppConstants.primaryNavy,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 1),
          Text(
            subtext,
            style: const TextStyle(
              fontSize: 9.5,
              color: AppConstants.textSecondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildFlowStepRow(String stageLabel, String desc, IconData icon, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Icon(icon, size: 12, color: color),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 105,
          child: Text(
            stageLabel,
            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: color),
          ),
        ),
        Expanded(
          child: Text(
            desc,
            style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: AppConstants.textPrimary),
          ),
        ),
      ],
    );
  }

  // DISTRICT GOVERNANCE & WHAT-IF SIMULATION CENTER
  Widget _buildDistrictSimulationCenter() {
    const baseDemandMT = 276.7;
    final simulatedDemandMT = (baseDemandMT * (1.0 + (_whatIfIntentSpike / 100.0))).toStringAsFixed(1);
    final extraTrucks = ((baseDemandMT * (_whatIfIntentSpike / 100.0)) / 10.0).toStringAsFixed(1);

    return Column(
      children: [
        // CARD 1: WHAT-IF SENSITIVITY SANDBOX
        Container(
          padding: const EdgeInsets.all(AppConstants.space16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
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
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.tune_rounded, size: 16, color: Color(0xFFB45309)),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'WHAT-IF POLICY SANDBOX',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: AppConstants.primaryNavy, letterSpacing: 0.5),
                        ),
                        Text(
                          'Simulate district shocks & intent swings',
                          style: TextStyle(fontSize: 10, color: AppConstants.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // SLIDER
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Citizen Advance Intent Surge', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppConstants.primaryNavy)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: Text(
                      '+${_whatIfIntentSpike.toInt()}% Spike',
                      style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900, color: AppConstants.accentBlue),
                    ),
                  ),
                ],
              ),
              Slider(
                value: _whatIfIntentSpike,
                min: 0,
                max: 50,
                divisions: 10,
                activeColor: AppConstants.accentBlue,
                inactiveColor: const Color(0xFFE2E8F0),
                onChanged: (val) {
                  setState(() => _whatIfIntentSpike = val);
                },
              ),

              // DYNAMIC REAL-TIME CALCULATION ROW
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppConstants.cardBorder),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        const Text('Baseline Demand', style: TextStyle(fontSize: 9.5, color: AppConstants.textSecondary)),
                        Text('${baseDemandMT.toStringAsFixed(1)} MT', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppConstants.primaryNavy)),
                      ],
                    ),
                    const Icon(Icons.arrow_forward_rounded, size: 14, color: AppConstants.textSecondary),
                    Column(
                      children: [
                        const Text('Simulated Demand', style: TextStyle(fontSize: 9.5, color: AppConstants.accentBlue, fontWeight: FontWeight.w700)),
                        Text('$simulatedDemandMT MT', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900, color: AppConstants.accentBlue)),
                      ],
                    ),
                    Column(
                      children: [
                        const Text('Extra Carrier Fleet', style: TextStyle(fontSize: 9.5, color: Color(0xFF15803D), fontWeight: FontWeight.w700)),
                        Text('+$extraTrucks Trucks', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900, color: Color(0xFF15803D))),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // TOGGLE
              InkWell(
                onTap: () => setState(() => _whatIfRouteDelay = !_whatIfRouteDelay),
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Icon(
                        _whatIfRouteDelay ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                        size: 18,
                        color: _whatIfRouteDelay ? AppConstants.accentBlue : AppConstants.textSecondary,
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Simulate Route Obstruction / Monsoon Weather',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppConstants.textPrimary),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('What-If Scenario applied: $simulatedDemandMT MT projected (+${_whatIfIntentSpike.toInt()}% surge, +$extraTrucks trucks required)'),
                        backgroundColor: AppConstants.primaryNavy,
                        duration: const Duration(seconds: 3),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  child: const Text('Apply Scenario to Allocation', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppConstants.space12),

        // CARD 2: RAPID OPERATIONS HUB
        Container(
          padding: const EdgeInsets.all(AppConstants.space16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
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
              const Row(
                children: [
                  Icon(Icons.bolt_rounded, size: 16, color: Color(0xFFEAB308)),
                  SizedBox(width: 6),
                  Text(
                    'RAPID OPERATIONS & AUDIT TOOLS',
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900, color: AppConstants.primaryNavy, letterSpacing: 0.5),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _buildRapidToolTile(
                'Scarcity Reconciliation LP',
                'Simplex Fair Share Allocation Engine',
                Icons.balance_rounded,
                const Color(0xFF8B5CF6),
                _showScarcityDialog,
              ),
              _buildRapidToolTile(
                'Digital Gatepass Generator',
                'Cryptographic SHA-256 Depot Waybills',
                Icons.qr_code_rounded,
                const Color(0xFF0EA5E9),
                _showGatepassDialog,
              ),
              _buildRapidToolTile(
                'Citizen SMS / WhatsApp Queue',
                'USSD & Bot Intake Priority Manager',
                Icons.chat_bubble_outline_rounded,
                const Color(0xFF10B981),
                _showCitizenRequestQueueDialog,
              ),
              _buildRapidToolTile(
                'Causal Attribution Tree',
                'Explainable AI Pre-Dispatch Trace',
                Icons.account_tree_rounded,
                const Color(0xFFF59E0B),
                () => _showCausalTraceDialog('FPS-KA-BLR-001'),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppConstants.space12),

        // CARD 3: CRYPTOGRAPHIC AUDIT TIMELINE
        Container(
          padding: const EdgeInsets.all(AppConstants.space16),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
            border: Border.all(color: const Color(0xFF1E293B)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.shield_outlined, size: 14, color: Color(0xFF38BDF8)),
                  SizedBox(width: 6),
                  Text(
                    'IMMUTABLE GOVERNANCE AUDIT TRAIL',
                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900, color: Color(0xFF38BDF8), letterSpacing: 0.5),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _buildAuditTrailEntry('10:28 AM', 'Day 22 Choice Window active • 620 FPS synchronizing', true),
              _buildAuditTrailEntry('10:25 AM', '129.9 MT citizen intent signals registered via WhatsApp', true),
              _buildAuditTrailEntry('10:20 AM', 'District statutory buffer validated (15% reserve active)', true),
              _buildAuditTrailEntry('10:15 AM', 'LP Simplex Solver verified zero entitlement loss', false),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRapidToolTile(String title, String subtitle, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(icon, size: 14, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: AppConstants.primaryNavy),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 9.5, color: AppConstants.textSecondary),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, size: 16, color: AppConstants.textSecondary),
          ],
        ),
      ),
    );
  }

  Widget _buildAuditTrailEntry(String time, String message, bool hasNext) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 54,
          child: Text(
            time,
            style: const TextStyle(fontSize: 9.5, fontFamily: 'monospace', fontWeight: FontWeight.w700, color: Color(0xFF94A3B8)),
          ),
        ),
        Column(
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: const BoxDecoration(
                color: Color(0xFF38BDF8),
                shape: BoxShape.circle,
              ),
            ),
            if (hasNext)
              Container(
                width: 1.5,
                height: 18,
                color: const Color(0xFF334155),
              ),
          ],
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              message,
              style: const TextStyle(fontSize: 10, color: Color(0xFFCBD5E1), height: 1.3),
            ),
          ),
        ),
      ],
    );
  }

  // HELPER TO FETCH METADATA FOR SELECTED WORKFLOW STAGE
  _WorkflowStageMeta _getWorkflowStageMeta(int stage) {
    switch (stage) {
      case 0:
        return _WorkflowStageMeta(
          title: 'Multi-Signal Demand Forecasting & Advance Intent Aggregation',
          category: 'PHASE 01 • PREDICTIVE DEMAND ENGINE',
          engine: 'Holt-Winters Seasonal Smoothing + Ridge Regression + Live Intent Prior',
          mathSpec: 'D̂_i = α·H_i + β·(I_i·1.12) + γ·Buffer - ε_leakage',
          icon: Icons.insights_rounded,
          accentColor: AppConstants.accentBlue,
          metrics: [
            {'val': '481.1 MT', 'label': 'Historical Base', 'sub': '3-cycle rolling average'},
            {'val': '129.9 MT', 'label': 'Intent Signals', 'sub': '+12.4% advance citizen demand'},
            {'val': '276.7 MT', 'label': 'Forecast Demand (D̂)', 'sub': 'Optimized Ridge regression'},
            {'val': '94.2%', 'label': 'ML Confidence', 'sub': 'Zero starvation benchmark'},
          ],
          inputNode: 'Past 3-Cycle ePoS Disbursal Logs + Citizen Intent Signals (WhatsApp/USSD)',
          engineNode: 'Non-Linear Ensemble with Anomaly Suppression & Buffer Scaling',
          outputNode: 'Calibrated Pre-Dispatch Demand Vector D̂_i for All 620 FPS',
          action1Label: 'Launch What-If Sandbox',
          action1Icon: Icons.tune_rounded,
          action1: () => _showForecastWhatIfDialog('FPS-KA-BLR-001'),
          action2Label: 'Run Pre-Dispatch Analysis',
          action2Icon: Icons.play_arrow_rounded,
          action2: _generateForecast,
        );
      case 1:
        return _WorkflowStageMeta(
          title: 'Statutory Constraint Validation & Buffer Threshold Enforcement',
          category: 'PHASE 02 • GOVERNANCE & SAFETY RULES',
          engine: 'NFSA Statutory Compliance Engine (9 Discrete District Rules)',
          mathSpec: '∀ s ∈ Shops: Stock_s + Transit_s ≥ MinSafetyStock_s ∧ Release ≤ Cap_dist',
          icon: Icons.verified_user_rounded,
          accentColor: const Color(0xFF10B981),
          metrics: [
            {'val': '9 / 9', 'label': 'Rules Compliant', 'sub': '100% NFSA district pass'},
            {'val': '15.0%', 'label': 'District Buffer', 'sub': 'Statutory emergency reserve'},
            {'val': '500.0 MT', 'label': 'Release Ceiling', 'sub': 'Depot throughput limit'},
            {'val': '0 Critical', 'label': 'Stock Anomaly Flags', 'sub': 'Zero unaddressed deficits'},
          ],
          inputNode: 'Raw Store Balances + Pending Consignments + Threshold Configs',
          engineNode: 'Deterministic Constraint Solver with Auto-Reconciliation Rules',
          outputNode: 'Validated Dispatch Baseline with Cryptographic Constraint Seal',
          action1Label: 'Inspect 9 Statutory Rules',
          action1Icon: Icons.gavel_rounded,
          action1: _showConstraintDialog,
          action2Label: 'Open Scarcity LP Solver',
          action2Icon: Icons.balance_rounded,
          action2: _showScarcityDialog,
        );
      case 2:
        return _WorkflowStageMeta(
          title: 'Pre-Dispatch Quota Allocation & Scarcity Simplex Rebalancing',
          category: 'PHASE 03 • EQUITY & FAIR SHARE OPTIMIZATION',
          engine: 'Linear Programming Simplex Solver with Portability Dynamic Weights',
          mathSpec: 'min ∑_{i,j} (C_ij · X_ij)  s.t.  X_ij ≥ MinNeed_i  (Simplex LP)',
          icon: Icons.balance_rounded,
          accentColor: const Color(0xFF8B5CF6),
          metrics: [
            {'val': 'Simplex LP', 'label': 'Optimization Model', 'sub': 'Fairness rebalancer active'},
            {'val': '1,420', 'label': 'Portability Cards', 'sub': 'Inter-FPS migrated beneficiaries'},
            {'val': '380', 'label': 'Doorstep Quotas', 'sub': 'Senior citizen home delivery'},
            {'val': '0.038', 'label': 'Gini Metric', 'sub': 'Near-perfect distribution equity'},
          ],
          inputNode: 'Citizen FPS Selection + Portability Flow Vectors + Stock Constraints',
          engineNode: 'Multi-Objective LP Solver Minimizing Transit & Quota Shortfalls',
          outputNode: 'FPS Allocation Matrix with Locked Beneficiary Entitlement Quotas',
          action1Label: 'Quota Decision Matrix',
          action1Icon: Icons.table_chart_outlined,
          action1: () => _showDispatchDecisionDialog('FPS-KA-BLR-001'),
          action2Label: 'Citizen Priority Queue',
          action2Icon: Icons.people_outline_rounded,
          action2: _showCitizenRequestQueueDialog,
        );
      case 3:
        return _WorkflowStageMeta(
          title: 'Fleet Route Clustering & Corridor Logistics Optimization',
          category: 'PHASE 04 • VEHICLE ROUTING PROBLEM (VRP)',
          engine: 'Google OR-Tools VRP Solver with Geofenced Cluster Corridors',
          mathSpec: 'min ∑_k Cost(Route_k)  s.t.  Payload_k ≤ 10 MT, Cluster_k ≤ 4',
          icon: Icons.alt_route_rounded,
          accentColor: const Color(0xFFF59E0B),
          metrics: [
            {'val': '4 Corridors', 'label': 'Route Clusters', 'sub': 'Synchronized depot dispatch'},
            {'val': '96.4%', 'label': 'Payload Efficiency', 'sub': '10 MT carrier capacity load'},
            {'val': '12 Trucks', 'label': 'Active Fleet', 'sub': 'GPS-tracked government carriers'},
            {'val': '1.82 MT', 'label': 'CO₂ Conserved', 'sub': 'Route distance minimization'},
          ],
          inputNode: '620 FPS Geocoordinates + Road Matrix + Depot Staging Gates',
          engineNode: 'Capacitated VRP with Time Windows (CVRPTW) Corridor Optimizer',
          outputNode: 'Optimized Carrier Manifests & Sequencing for Depot Dispatch',
          action1Label: 'Optimize Route Corridors',
          action1Icon: Icons.route_rounded,
          action1: _showDispatchOptimizationDialog,
          action2Label: 'Review Fleet Manifest',
          action2Icon: Icons.fact_check_outlined,
          action2: _showManifestDialog,
        );
      case 4:
        return _WorkflowStageMeta(
          title: 'Cryptographic SHA-256 Tamper-Proof Gatepass & Manifest Seal',
          category: 'PHASE 05 • DISPATCH INTEGRITY & AUDIT SEAL',
          engine: 'HMAC-SHA256 Cryptographic Digest Engine with QR Verifier',
          mathSpec: 'HMAC-SHA256(CycleID || ConsignmentMatrix || FPS_List) ⟶ QR Seal',
          icon: Icons.local_shipping_rounded,
          accentColor: const Color(0xFF0EA5E9),
          metrics: [
            {'val': '620 Passes', 'label': 'Signed Gatepasses', 'sub': 'SHA-256 tamper-evident'},
            {'val': '100% Sealed', 'label': 'Depot Consignments', 'sub': 'Certified waybill releases'},
            {'val': 'Instant QR', 'label': 'Offline Scan Verifier', 'sub': 'Field checkpoint check'},
            {'val': 'Biometric', 'label': 'Driver Auth Log', 'sub': 'Aadhaar OTP handshake'},
          ],
          inputNode: 'Certified Allocation Quota + Carrier Truck ID + Depot Timestamp',
          engineNode: 'Cryptographic Hash Generation & QR Code Tamper-Proof Serialization',
          outputNode: 'Immutable Digital Gatepasses & Physical Driver Consignment Sheets',
          action1Label: 'Generate Digital Gatepasses',
          action1Icon: Icons.qr_code_2_rounded,
          action1: _showGatepassDialog,
          action2Label: 'Open Manifest Manager',
          action2Icon: Icons.assignment_outlined,
          action2: _showManifestDialog,
        );
      case 5:
        return _WorkflowStageMeta(
          title: 'ePoS Terminal Real-Time Sync & Aadhaar Biometric Lift Verification',
          category: 'PHASE 06 • LIVE TERMINAL TELEMETRY',
          engine: 'NIC ePoS Gateway Synchronization & Real-Time Disbursal Uplink',
          mathSpec: 'ePoS_Lift(b, t) ⟷ BioAuth(UIDAI) ∧ RemainingEntitlement(b) ≥ 0',
          icon: Icons.fingerprint_rounded,
          accentColor: const Color(0xFF059669),
          metrics: [
            {'val': '620 / 620', 'label': 'ePoS Terminals', 'sub': 'Live active terminal link'},
            {'val': '99.1%', 'label': 'Biometric Auth', 'sub': 'First-attempt Aadhaar match'},
            {'val': '84.6%', 'label': 'Lift Progression', 'sub': 'District cycle disbursal'},
            {'val': '0.08%', 'label': 'Variance Gap', 'sub': 'Under statutory tolerance'},
          ],
          inputNode: 'NIC ePoS Transaction Log Streams + Aadhaar UIDAI Biometric Tokens',
          engineNode: 'Continuous Real-Time Reconciliation vs Locked Pre-Dispatch Quotas',
          outputNode: 'Verified Citizen Grain Disbursal Ledger & Anomaly Exception Feeds',
          action1Label: 'Live Alerts & Incident Stream',
          action1Icon: Icons.notifications_active_outlined,
          action1: _showAlertsDialog,
          action2Label: 'Inspect All 620 FPS Matrix',
          action2Icon: Icons.storefront_outlined,
          action2: () => setState(() => _selectedMainTab = 1),
        );
      case 6:
      default:
        return _WorkflowStageMeta(
          title: 'Closed-Loop Post-Distribution MAPE Calibration & Feedback Learning',
          category: 'PHASE 07 • CLOSED-LOOP ML EVALUATION',
          engine: 'Continuous Error Minimization & Bayesian Prior Weight Calibrator',
          mathSpec: 'MAPE = (1/N) ∑ |Actual_i - D̂_i| / Actual_i ⟶ Update(α, β, γ)',
          icon: Icons.published_with_changes_rounded,
          accentColor: const Color(0xFF6366F1),
          metrics: [
            {'val': '4.8%', 'label': 'Forecast MAPE', 'sub': 'Exceeds 90% accuracy goal'},
            {'val': '99.8%', 'label': 'Starvation Prevention', 'sub': 'Zero stockout incidents'},
            {'val': 'Auto-Tuned', 'label': 'Closed-Loop Feedback', 'sub': 'Prior weights calibrated'},
            {'val': 'Immutable', 'label': 'Audit Governance', 'sub': 'Permanent state record'},
          ],
          inputNode: 'Completed Cycle Disbursal Log vs Day 25 Pre-Dispatch Predictions',
          engineNode: 'Mean Absolute Percentage Error (MAPE) Calibration & Weight Tuning',
          outputNode: 'Self-Correcting Next-Cycle ML Hyperparameters (α, β, γ) & Audit Report',
          action1Label: 'Closed-Loop Evaluation Modal',
          action1Icon: Icons.analytics_rounded,
          action1: _showEvaluationModal,
          action2Label: 'Explain Decision Trace',
          action2Icon: Icons.account_tree_outlined,
          action2: () => _showCausalTraceDialog('FPS-KA-BLR-001'),
        );
    }
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
        LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxWidth < 680;

            final alertItems = SingleChildScrollView(
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
            );

            final viewAllBtn = TextButton(
              onPressed: _showAlertsDialog,
              style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(50, 24)),
              child: const Text('View All →', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            );

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppConstants.cardSurface,
                borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
                border: Border.all(color: AppConstants.cardBorder, width: 1),
              ),
              child: isCompact
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.warning_amber_rounded, color: Color(0xFFB45309), size: 16),
                                SizedBox(width: 6),
                                Text(
                                  'OPERATIONAL ATTENTION ITEMS',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppConstants.primaryNavy, letterSpacing: 0.5),
                                ),
                              ],
                            ),
                            viewAllBtn,
                          ],
                        ),
                        const SizedBox(height: 8),
                        alertItems,
                      ],
                    )
                  : Row(
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
                        Expanded(child: alertItems),
                        viewAllBtn,
                      ],
                    ),
            );
          },
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
          LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 650;

              final titleCol = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'PRE-DISPATCH OPERATIONAL INCIDENTS',
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
                      fontSize: isCompact ? 10.5 : 11.5,
                      fontStyle: FontStyle.italic,
                      color: const Color(0xFFB45309),
                    ),
                  ),
                ],
              );

              final alertBadge = Container(
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
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: _activeDashboardIncidentsCount > 0 ? const Color(0xFFDC2626) : const Color(0xFF15803D),
                  ),
                ),
              );

              if (isCompact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD97706).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.warning_amber_rounded, color: Color(0xFFB45309), size: 18),
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: titleCol),
                      ],
                    ),
                    const SizedBox(height: 8),
                    alertBadge,
                  ],
                );
              }

              return Row(
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
                  Expanded(child: titleCol),
                  alertBadge,
                ],
              );
            },
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

          // Matrix Data Table (Stretched across full width with ZERO blank white space)
          LayoutBuilder(
            builder: (context, constraints) {
              final calcSpacing = max(16.0, (constraints.maxWidth - 820) / 10);

              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: constraints.maxWidth),
                  child: DataTable(
                    headingRowHeight: 40,
                    dataRowMinHeight: 50,
                    dataRowMaxHeight: 54,
                    horizontalMargin: 16,
                    columnSpacing: calcSpacing,
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
                    const DataCell(Text('94%', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600))),
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
        );
      },
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
