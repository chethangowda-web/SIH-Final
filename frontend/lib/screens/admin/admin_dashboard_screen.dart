import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../models/admin_model.dart';
import '../../services/api_service.dart';
import 'constraint_validation_dialog.dart';
import 'digital_gatepass_dialog.dart';
import 'readiness_alerts_dialog.dart';
import 'fps_predispatch_inspector_dialog.dart';
import 'fps_forecast_detail_dialog.dart';
import 'fps_dispatch_decision_dialog.dart';
import 'dispatch_optimization_dialog.dart';
import 'manifest_management_dialog.dart';
import 'delivery_feedback_dialog.dart';
import 'sih_demo_mode_dialog.dart';
import 'judge_view_dialog.dart';
import 'scarcity_reconciliation_dialog.dart';
import '../../models/scarcity_model.dart';
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
  DepotBalanceModel? _depotBalance;
  bool _isLoading = true;
  String? _errorMessage;
  String _selectedFilter = 'ALL'; // 'ALL', 'HIGH_RISK', 'MIGRANT', 'LOW_INVENTORY'
  String _searchQuery = '';
  bool _isActionExecuting = false;

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
      DepotBalanceModel? balance;
      try {
        balance = await _apiService.fetchScarcityDepotBalance();
      } catch (_) {}

      if (mounted) {
        setState(() {
          _dashboardData = data;
          _depotBalance = balance;
          _isLoading = false;
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

  Future<void> _generateDispatch() async {
    setState(() => _isActionExecuting = true);
    try {
      final res = await _apiService.triggerGenerateDispatch();
      await _loadDashboardData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.message.isNotEmpty
              ? res.message
              : 'Dispatch manifest generated for locked forecasts!'),
          backgroundColor: AppConstants.successGreen,
        ),
      );
      _showDispatchManifestModal();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isActionExecuting = false);
    }
  }

  Future<void> _simulateDistribution() async {
    setState(() => _isActionExecuting = true);
    try {
      final res = await _apiService.triggerSimulateDistribution();
      await _loadDashboardData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.message.isNotEmpty
              ? res.message
              : 'Actual ePoS distribution lifting simulated!'),
          backgroundColor: AppConstants.accentAmber,
        ),
      );
      _showEvaluationModal();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isActionExecuting = false);
    }
  }

  Future<void> _calibrateModel() async {
    final status = _dashboardData?.workflowStatus ?? 'PLANNING_OPEN';
    if (status == 'PLANNING_OPEN' || status == 'DRAFT_GENERATED' || status == 'FORECAST_LOCKED' || status == 'DISPATCH_GENERATED') {
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: const Row(
            children: [
              Icon(Icons.info_outline, color: Color(0xFF673AB7)),
              SizedBox(width: 10),
              Text('ML Calibration Prerequisite'),
            ],
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Closed-loop Ridge regression learns the optimal intent influence weight (w*) from empirical forecast residuals (A - H vs I - H).',
                style: TextStyle(fontSize: 13, height: 1.4),
              ),
              SizedBox(height: 12),
              Text(
                'Prerequisite: At least 10 paired observation records must exist in actual distribution.\n\nRecommended Step: Click "7. ePoS Simulated" in the workflow ribbon to simulate actual distribution lifting, then return to calibrate the ML model.',
                style: TextStyle(fontSize: 12, color: AppConstants.textSecondary, height: 1.4),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Understood'),
            ),
          ],
        ),
      );
      return;
    }

    setState(() => _isActionExecuting = true);
    try {
      final res = await _apiService.triggerModelCalibration();
      await _loadDashboardData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.message.isNotEmpty
              ? res.message
              : 'Closed-loop ML model calibrated using scikit-learn!'),
          backgroundColor: const Color(0xFF673AB7),
        ),
      );
      _showCalibrationModal(res);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Calibration Notice: $e'), backgroundColor: Colors.red),
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

  void _showDeliveryFeedbackDialog({String fpsId = 'FPS-KA-BLR-001'}) {
    showDialog(
      context: context,
      builder: (context) => DeliveryFeedbackDialog(
        fpsId: fpsId,
        cycleId: _dashboardData?.activeCycle ?? '2026-09',
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

  Future<void> _runDistrictPreDispatchAnalysis() async {
    setState(() => _isActionExecuting = true);
    try {
      final res = await _apiService.runPreDispatchAnalysis();
      await _loadDashboardData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.message),
          backgroundColor: AppConstants.accentBlue,
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

  Future<void> _showDispatchManifestModal() async {
    showDialog(
      context: context,
      builder: (context) {
        return FutureBuilder<DispatchManifestData>(
          future: _apiService.fetchDispatchManifest(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const AlertDialog(
                content: SizedBox(
                  height: 150,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(strokeWidth: 3),
                        SizedBox(height: 16),
                        Text('Retrieving Godown Dispatch Manifest...'),
                      ],
                    ),
                  ),
                ),
              );
            }

            if (snapshot.hasError || !snapshot.hasData) {
              return AlertDialog(
                title: const Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red),
                    SizedBox(width: 10),
                    Text('Dispatch Manifest Notice'),
                  ],
                ),
                content: Text(
                  snapshot.error != null
                      ? 'Error: ${snapshot.error}'
                      : 'No dispatch manifest generated yet. Please ensure forecasts are locked and generate dispatch.',
                  style: const TextStyle(fontSize: 12),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  ),
                ],
              );
            }

            final manifest = snapshot.data!;
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              title: Row(
                children: [
                  const Icon(Icons.local_shipping_outlined, color: AppConstants.primaryNavy),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Multi-Echelon Godown Dispatch Manifest', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                        Text('Cycle ${manifest.cycleId} • PDS DemandSync Simulation', style: TextStyle(fontSize: 11, color: AppConstants.textSecondary)),
                      ],
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 750,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Summary metrics header
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppConstants.primaryNavy.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppConstants.cardBorder),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildManifestHeaderStat('TOTAL DISPATCH', '${(manifest.totalDispatchKg / 1000).toStringAsFixed(1)} MT', AppConstants.primaryNavy),
                            _buildManifestHeaderStat('RICE ALLOCATION', '${(manifest.totalRiceDispatchKg / 1000).toStringAsFixed(1)} MT', AppConstants.primaryNavy),
                            _buildManifestHeaderStat('WHEAT ALLOCATION', '${(manifest.totalWheatDispatchKg / 1000).toStringAsFixed(1)} MT', AppConstants.accentAmber),
                            _buildManifestHeaderStat('VEHICLES DEPLOYED', '${manifest.totalVehiclesCount} Trucks', AppConstants.accentBlue),
                            _buildManifestHeaderStat('TARGET FPS', '${manifest.totalFpsCount} Centers', AppConstants.successGreen),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      const Text(
                        'ASSIGNED VEHICLE FLEET & REGIONAL DELIVERY CORRIDORS',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppConstants.primaryNavy, letterSpacing: 0.5),
                      ),
                      const SizedBox(height: 8),

                      // Vehicle cards
                      ...manifest.vehicles.map((v) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppConstants.bgLight,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppConstants.cardBorder),
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
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppConstants.primaryNavy,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          v.truckId,
                                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white, fontFamily: 'monospace'),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        v.routeName,
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    'Payload: ${v.totalPayloadKg.toStringAsFixed(0)} kg (${v.totalPayloadMt.toStringAsFixed(2)} MT)',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppConstants.primaryNavy),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Origin Godown: ${v.sourceGodown} • Drops: ${v.stopsCount} FPS Stops',
                                style: TextStyle(fontSize: 10, color: AppConstants.textSecondary),
                              ),
                              const Divider(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                children: v.deliveryStops.map((stop) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: AppConstants.cardBorder),
                                    ),
                                    child: Text(
                                      '${stop.fpsId}: ${stop.totalKg.toStringAsFixed(0)} kg (R:${stop.riceKg.toStringAsFixed(0)} W:${stop.wheatKg.toStringAsFixed(0)})',
                                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        );
                      }),

                      const SizedBox(height: 12),
                      Center(
                        child: Text(
                          'DEMO DATA — NOT GOVERNMENT DATA (SIMULATED GODOWN DISPATCH)',
                          style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: Colors.grey.shade500),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Dismiss'),
                ),
              ],
            );
          },
        );
      },
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
              return const AlertDialog(
                content: SizedBox(
                  height: 150,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(strokeWidth: 3),
                        SizedBox(height: 16),
                        Text('Computing Forecast vs Actual Evaluation...'),
                      ],
                    ),
                  ),
                ),
              );
            }

            if (snapshot.hasError || !snapshot.hasData) {
              return AlertDialog(
                title: const Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red),
                    SizedBox(width: 10),
                    Text('Evaluation Notice'),
                  ],
                ),
                content: Text(
                  snapshot.error != null
                      ? 'Error: ${snapshot.error}'
                      : 'No evaluation records available. Please simulate actual distribution first.',
                  style: const TextStyle(fontSize: 12),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  ),
                ],
              );
            }

            final eval = snapshot.data!;
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              title: Row(
                children: [
                  const Icon(Icons.analytics_outlined, color: AppConstants.accentBlue),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Forecast vs Actual ePoS Evaluation', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                        Text('Cycle ${eval.cycleId} • Closed-Loop Intelligence', style: TextStyle(fontSize: 11, color: AppConstants.textSecondary)),
                      ],
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 750,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // KPI Summary Header
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppConstants.accentBlue.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppConstants.cardBorder),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildManifestHeaderStat('OVERALL ACCURACY', '${eval.overallAccuracyPct.toStringAsFixed(1)}%', AppConstants.successGreen),
                            _buildManifestHeaderStat('MAPE (ERROR)', '${eval.mapePct.toStringAsFixed(2)}%', AppConstants.accentAmber),
                            _buildManifestHeaderStat('MEAN ABS ERROR', '${eval.maeKg.toStringAsFixed(1)} kg', AppConstants.primaryNavy),
                            _buildManifestHeaderStat('TOTAL FORECAST', '${(eval.totalForecastQuantityKg / 1000).toStringAsFixed(1)} MT', AppConstants.accentBlue),
                            _buildManifestHeaderStat('TOTAL ACTUAL', '${(eval.totalActualQuantityKg / 1000).toStringAsFixed(1)} MT', AppConstants.primaryNavy),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Mathematical Formula Banner
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppConstants.bgLight,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppConstants.cardBorder),
                        ),
                        child: const Text(
                          'Metric Definitions:  MAPE = (1/N) * Σ (|Actual - Forecast| / Actual) * 100%  |  Accuracy = 100% - MAPE',
                          style: TextStyle(fontSize: 10, fontFamily: 'monospace', fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(height: 14),

                      const Text(
                        'COMMODITY-WISE ACCURACY BREAKDOWN',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppConstants.primaryNavy, letterSpacing: 0.5),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppConstants.bgLight,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppConstants.cardBorder),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Rice Allocation', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                                  const SizedBox(height: 4),
                                  Text('Rice MAPE: ${eval.riceMapePct.toStringAsFixed(2)}% • Accuracy: ${(100 - eval.riceMapePct).toStringAsFixed(2)}%', style: const TextStyle(fontSize: 11, color: AppConstants.primaryNavy, fontWeight: FontWeight.w700)),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppConstants.bgLight,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppConstants.cardBorder),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Wheat Allocation', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                                  const SizedBox(height: 4),
                                  Text('Wheat MAPE: ${eval.wheatMapePct.toStringAsFixed(2)}% • Accuracy: ${(100 - eval.wheatMapePct).toStringAsFixed(2)}%', style: const TextStyle(fontSize: 11, color: AppConstants.accentAmber, fontWeight: FontWeight.w700)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      const Text(
                        'FPS-BY-FPS EVALUATION AUDIT MATRIX',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppConstants.primaryNavy, letterSpacing: 0.5),
                      ),
                      const SizedBox(height: 8),

                      // FPS list table
                      Container(
                        constraints: const BoxConstraints(maxHeight: 250),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppConstants.cardBorder),
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: eval.fpsEvaluations.length,
                          separatorBuilder: (context, index) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final item = eval.fpsEvaluations[index];
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: Text(
                                      '${item.fpsId} • ${item.fpsName} [${item.commodity}]',
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      'F: ${item.forecastQuantityKg.toStringAsFixed(0)} kg | A: ${item.actualQuantityKg.toStringAsFixed(0)} kg',
                                      style: TextStyle(fontSize: 10, color: AppConstants.textSecondary),
                                    ),
                                  ),
                                  Text(
                                    '${item.accuracyPct.toStringAsFixed(1)}% Acc (Err: ${item.percentageError.toStringAsFixed(1)}%)',
                                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppConstants.primaryNavy),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),

                      const SizedBox(height: 12),
                      Center(
                        child: Text(
                          'DEMO DATA — NOT GOVERNMENT DATA (EVALUATION SIMULATION)',
                          style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: Colors.grey.shade500),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _calibrateModel();
                  },
                  icon: const Icon(Icons.psychology_alt, size: 16),
                  label: const Text('Calibrate ML Model'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF673AB7),
                    foregroundColor: Colors.white,
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Dismiss'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showCalibrationModal([ModelCalibrationData? initialData]) {
    showDialog(
      context: context,
      builder: (context) {
        return FutureBuilder<ModelCalibrationData>(
          future: initialData != null
              ? Future.value(initialData)
              : _apiService.triggerModelCalibration(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const AlertDialog(
                content: SizedBox(
                  height: 150,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(strokeWidth: 3),
                        SizedBox(height: 16),
                        Text('Training ML Model with scikit-learn Ridge Regression...'),
                      ],
                    ),
                  ),
                ),
              );
            }

            if (snapshot.hasError || !snapshot.hasData) {
              return AlertDialog(
                title: const Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red),
                    SizedBox(width: 10),
                    Text('Calibration Notice'),
                  ],
                ),
                content: Text(
                  snapshot.error != null
                      ? 'Error: ${snapshot.error}'
                      : 'Unable to load calibration parameters.',
                  style: const TextStyle(fontSize: 12),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  ),
                ],
              );
            }

            final cal = snapshot.data!;
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              title: Row(
                children: [
                  const Icon(Icons.psychology_alt_outlined, color: Color(0xFF673AB7)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Closed-Loop ML Model Calibration (scikit-learn)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                        Text('Algorithm: ${cal.algorithm} • Model Version: ${cal.modelVersion}', style: TextStyle(fontSize: 11, color: AppConstants.textSecondary)),
                      ],
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 650,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Parameter Update Grid
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF673AB7).withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF673AB7).withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildManifestHeaderStat('PREVIOUS INTENT WEIGHT (w)', '${cal.previousWeight.toStringAsFixed(2)}', AppConstants.primaryNavy),
                            const Icon(Icons.arrow_forward, color: Color(0xFF673AB7), size: 24),
                            _buildManifestHeaderStat('CALIBRATED WEIGHT (w*)', '${cal.calibratedWeight.toStringAsFixed(2)}', const Color(0xFF673AB7)),
                            _buildManifestHeaderStat('TARGET FUTURE CYCLE', cal.targetFutureCycle, AppConstants.successGreen),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Before vs After MAPE
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppConstants.bgLight,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppConstants.cardBorder),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildManifestHeaderStat('BEFORE MAPE (w=0.65)', '${cal.beforeMape.toStringAsFixed(2)}%', AppConstants.accentAmber),
                            _buildManifestHeaderStat('AFTER MAPE (w=${cal.calibratedWeight})', '${cal.afterMape.toStringAsFixed(2)}%', AppConstants.successGreen),
                            _buildManifestHeaderStat('TRAINING SAMPLES', '${cal.recordsTrained} FPS records', AppConstants.primaryNavy),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      const Text(
                        'FEATURE ENGINEERING & FORMULATION',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppConstants.primaryNavy, letterSpacing: 0.5),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppConstants.bgLight,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppConstants.cardBorder),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Objective: Minimize loss between predicted demand D̂(w) = (1-w·C)·H + (w·C)·I and actual ePoS lifting A.',
                              style: TextStyle(fontSize: 10, fontFamily: 'monospace', fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Linear Transformation: (A - H) ≈ w · [C · (I - H)] fit via Ridge L2 Regularization.',
                              style: TextStyle(fontSize: 10, fontFamily: 'monospace', fontWeight: FontWeight.w600, color: Color(0xFF673AB7)),
                            ),
                            const Divider(height: 12),
                            const Text('Training Features Used:', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
                            ...cal.trainingFeatures.map((f) => Text(' • $f', style: TextStyle(fontSize: 10, color: AppConstants.textSecondary))),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),
                      Center(
                        child: Text(
                          'DEMO DATA — NOT GOVERNMENT DATA (MACHINE LEARNING CALIBRATION)',
                          style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: Colors.grey.shade500),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Done'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildManifestHeaderStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: AppConstants.textSecondary, letterSpacing: 0.4)),
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
    } else if (_selectedFilter == 'MIGRANT') {
      list = list.where((f) => f.intentShiftKg > 150).toList();
    } else if (_selectedFilter == 'LOW_INVENTORY') {
      list = list.where((f) => f.inventoryUtilizationPct < 25.0).toList();
    }

    return list;
  }

  @override
  Widget build(BuildContext context) {
    final status = _dashboardData?.workflowStatus ?? 'PLANNING_OPEN';
    final isCalibrated = status == 'MODEL_CALIBRATED';
    final isEvaluated = status == 'FORECAST_EVALUATED' || isCalibrated;
    final isDistributionSimulated =
        status == 'ACTUAL_DISTRIBUTION_SIMULATED' || isEvaluated;
    final isDispatchGenerated =
        status == 'DISPATCH_GENERATED' || isDistributionSimulated;
    final isLocked =
        status == 'FORECAST_LOCKED' || isDispatchGenerated;
    final isDraft = status == 'DRAFT_GENERATED';

    return Scaffold(
      backgroundColor: AppConstants.bgLight,
      appBar: AppBar(
        backgroundColor: AppConstants.primaryNavy,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'District Admin Decision Support',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            Text(
              'PDS DemandSync • Demo Nagar (Bengaluru Urban) • Cycle 7 (2026-09)',
              style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.85)),
            ),
          ],
        ),
        actions: [
          ElevatedButton.icon(
            onPressed: _showJudgeViewDialog,
            icon: const Icon(Icons.gavel_rounded, color: Color(0xFFF59E0B), size: 16),
            label: const Text('🏛️ SIH Judge Defense',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F172A),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: const BorderSide(color: Color(0xFFF59E0B), width: 1.5),
              ),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: _showSihDemoModeDialog,
            icon: const Icon(Icons.stars_rounded, color: Colors.amber, size: 16),
            label: const Text('★ Run SIH Demo Scenario',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E3A8A),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: const BorderSide(color: Colors.amber, width: 1.5),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Refresh Live Telemetry',
            icon: const Icon(Icons.refresh),
            onPressed: _loadDashboardData,
          ),
          IconButton(
            tooltip: 'Reset Demo State (Returns to PLANNING_OPEN for Jury Demo)',
            icon: const Icon(Icons.restart_alt_rounded, color: AppConstants.accentAmber),
            onPressed: _isActionExecuting ? null : _resetDemoWorkflow,
          ),
          TextButton.icon(
            onPressed: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => const DemoLoginScreen()),
              );
            },
            icon: const Icon(Icons.swap_horiz_rounded, color: Colors.white, size: 18),
            label: const Text(
              'Citizen Portal',
              style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(strokeWidth: 3),
                  SizedBox(height: 16),
                  Text('Aggregating district pre-dispatch demand signals...'),
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
                        ElevatedButton(onPressed: _loadDashboardData, child: const Text('Try Again')),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadDashboardData,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1280),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // 1. Workflow Actions Bar
                            _buildWorkflowActionBar(
                              isDraft: isDraft,
                              isLocked: isLocked,
                              isDispatchGenerated: isDispatchGenerated,
                              isDistributionSimulated: isDistributionSimulated,
                              isEvaluated: isEvaluated,
                              isCalibrated: isCalibrated,
                            ),
                            const SizedBox(height: 20),

                            // 2. The 5 Real KPI Cards
                            _buildKpiMetricsGrid(),
                            const SizedBox(height: 24),

                            // 3. Four Interactive Visualization Charts
                            _buildVisualizationsSection(),
                            const SizedBox(height: 24),

                            // 4. FPS Overview Matrix Table
                            _buildFpsMatrixSection(),
                            const SizedBox(height: 24),

                            // Synthetic Notice Footer
                            Center(
                              child: Text(
                                'DEMO DATA — NOT GOVERNMENT DATA • PDS DEMANDSYNC SIH 2026',
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

  Widget _buildWorkflowActionBar({
    required bool isDraft,
    required bool isLocked,
    required bool isDispatchGenerated,
    required bool isDistributionSimulated,
    required bool isEvaluated,
    required bool isCalibrated,
  }) {
    Color badgeColor = AppConstants.accentAmber;
    IconData badgeIcon = Icons.pending_actions;
    String badgeText = 'PLANNING STAGE OPEN';

    if (isCalibrated) {
      badgeColor = const Color(0xFF673AB7);
      badgeIcon = Icons.psychology_alt;
      badgeText = 'ML MODEL CALIBRATED (v1.1)';
    } else if (isEvaluated) {
      badgeColor = const Color(0xFF00897B);
      badgeIcon = Icons.analytics_outlined;
      badgeText = 'FORECAST EVALUATED';
    } else if (isDistributionSimulated) {
      badgeColor = Colors.orange.shade800;
      badgeIcon = Icons.storefront;
      badgeText = 'ACTUAL ePoS LIFTING SIMULATED';
    } else if (isDispatchGenerated) {
      badgeColor = AppConstants.successGreen;
      badgeIcon = Icons.local_shipping;
      badgeText = 'DISPATCH MANIFEST GENERATED';
    } else if (isLocked) {
      badgeColor = AppConstants.primaryNavy;
      badgeIcon = Icons.lock_rounded;
      badgeText = 'FORECAST LOCKED';
    } else if (isDraft) {
      badgeColor = AppConstants.accentBlue;
      badgeIcon = Icons.auto_awesome;
      badgeText = 'DRAFT FORECAST READY';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppConstants.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.spaceBetween,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isLocked && !isDispatchGenerated
                      ? AppConstants.primaryNavy
                      : badgeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isLocked && !isDispatchGenerated
                        ? AppConstants.primaryNavy
                        : badgeColor,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      badgeIcon,
                      size: 16,
                      color: isLocked && !isDispatchGenerated ? Colors.white : badgeColor,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      badgeText,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: isLocked && !isDispatchGenerated ? Colors.white : badgeColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Cycle 7 (September 2026)',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppConstants.textSecondary),
              ),
            ],
          ),
          // Action Buttons
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ElevatedButton.icon(
                onPressed: _isActionExecuting ? null : _runDistrictPreDispatchAnalysis,
                icon: const Icon(Icons.flash_on_rounded, size: 16),
                label: const Text('⚡ Run Pre-Dispatch Analysis', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppConstants.accentBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => _showForecastWhatIfDialog('FPS-KA-BLR-001'),
                icon: const Icon(Icons.psychology_outlined, size: 16),
                label: const Text('Forecast Detail & What-If', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppConstants.primaryNavy,
                  side: const BorderSide(color: AppConstants.primaryNavy),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => _showDispatchDecisionDialog('FPS-KA-BLR-001'),
                icon: const Icon(Icons.local_shipping_outlined, size: 16),
                label: const Text('Dispatch Decisions', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppConstants.successGreen,
                  side: const BorderSide(color: AppConstants.successGreen),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                ),
              ),
              ElevatedButton.icon(
                onPressed: _showScarcityDialog,
                icon: const Icon(Icons.balance_outlined, size: 16),
                label: const Text('AI Scarcity & Fair-Share', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFB45309),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                ),
              ),
              ElevatedButton.icon(
                onPressed: (_isActionExecuting || isLocked) ? null : _generateForecast,
                icon: const Icon(Icons.psychology_outlined, size: 16),
                label: const Text('1. Forecast', style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isLocked ? Colors.grey.shade600 : AppConstants.primaryNavy,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                ),
              ),
              ElevatedButton.icon(
                onPressed: (_isActionExecuting || !isDraft || isLocked) ? null : _lockForecast,
                icon: const Icon(Icons.lock_outline, size: 16),
                label: const Text('2. Close Window & Lock Demand', style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isLocked ? Colors.grey.shade600 : AppConstants.primaryNavy,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                ),
              ),
              ElevatedButton.icon(
                onPressed: _showConstraintDialog,
                icon: const Icon(Icons.rule_folder_outlined, size: 16),
                label: const Text('3. Constraints (9 Rules)', style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0284C7),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _showDispatchOptimizationDialog(),
                icon: const Icon(Icons.route_outlined, size: 16),
                label: const Text('4. Optimization (TSP)', style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppConstants.purpleAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  if (!isDispatchGenerated && isLocked) {
                    _generateDispatch();
                  } else {
                    _showManifestDialog();
                  }
                },
                icon: const Icon(Icons.description_outlined, size: 16),
                label: const Text('5. Manifest & Lock', style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppConstants.primaryNavy,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                ),
              ),
              ElevatedButton.icon(
                onPressed: _showGatepassDialog,
                icon: const Icon(Icons.badge_outlined, size: 16),
                label: const Text('6. Digital Gatepass', style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                ),
              ),
              ElevatedButton.icon(
                onPressed: _showAlertsDialog,
                icon: const Icon(Icons.notifications_active_outlined, size: 16),
                label: const Text('7. Readiness Alerts', style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD97706),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                ),
              ),
              ElevatedButton.icon(
                onPressed: (_isActionExecuting || !isDispatchGenerated) ? null : _simulateDistribution,
                icon: const Icon(Icons.storefront_outlined, size: 16),
                label: Text(
                  isDistributionSimulated ? '7. ePoS Simulated' : '7. Simulate Actuals',
                  style: const TextStyle(fontSize: 12),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDistributionSimulated
                      ? Colors.orange.shade800
                      : (isDispatchGenerated ? AppConstants.accentAmber : Colors.grey.shade400),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                ),
              ),
              ElevatedButton.icon(
                onPressed: (_isActionExecuting || !isDistributionSimulated) ? null : _showEvaluationModal,
                icon: const Icon(Icons.analytics_outlined, size: 16),
                label: const Text('8. Evaluation', style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isEvaluated ? const Color(0xFF00897B) : Colors.grey.shade400,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                ),
              ),
              ElevatedButton.icon(
                onPressed: (_isActionExecuting || !isDistributionSimulated) ? null : () => _showCalibrationModal(),
                icon: const Icon(Icons.psychology_alt_outlined, size: 16),
                label: Text(
                  isCalibrated ? 'ML Calibrated' : 'Calibrate ML',
                  style: const TextStyle(fontSize: 12),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isCalibrated
                      ? const Color(0xFF673AB7)
                      : (isEvaluated ? const Color(0xFF673AB7) : Colors.grey.shade400),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _showDeliveryFeedbackDialog(fpsId: 'FPS-KA-BLR-001'),
                icon: const Icon(Icons.rate_review_outlined, size: 16),
                label: const Text('8. Feedback Loop', style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D9488),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                ),
              ),
              ElevatedButton.icon(
                onPressed: _showJudgeViewDialog,
                icon: const Icon(Icons.gavel_rounded, color: Color(0xFFF59E0B), size: 16),
                label: const Text('🏛️ SIH Judge Defense', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: const BorderSide(color: Color(0xFFF59E0B), width: 1.2),
                  ),
                ),
              ),
              ElevatedButton.icon(
                onPressed: _showSihDemoModeDialog,
                icon: const Icon(Icons.stars_rounded, color: Colors.amber, size: 16),
                label: const Text('★ SIH Demo Center', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E3A8A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: const BorderSide(color: Colors.amber, width: 1.2),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKpiMetricsGrid() {
    final d = _dashboardData!;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          SizedBox(
            width: 220,
            child: _buildKpiCard(
              'HISTORICAL BASELINE',
              '${(d.totalHistoricalDemandKg / 1000).toStringAsFixed(1)} MT',
              '6-Cycle Average Demand',
              Icons.history_rounded,
              AppConstants.primaryNavy,
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 220,
            child: _buildKpiCard(
              'INTENT DEMAND',
              '${(d.totalDeclaredIntentKg / 1000).toStringAsFixed(1)} MT',
              '${d.activeIntentsCount} Beneficiary Signals',
              Icons.speed_rounded,
              AppConstants.accentBlue,
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 230,
            child: _buildKpiCard(
              'FORECAST DEMAND (D̂)',
              '${(d.totalForecastDemandKg / 1000).toStringAsFixed(1)} MT',
              d.workflowStatus == 'FORECAST_LOCKED'
                  ? 'Status: LOCKED (D̂=(1-w·C)H+w·C·I)'
                  : (d.workflowStatus == 'DRAFT_GENERATED' ? 'Status: DRAFT (w=0.65)' : 'Status: PLANNING'),
              Icons.auto_graph_rounded,
              AppConstants.secondaryNavy,
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 220,
            child: _buildKpiCard(
              'RECOMMENDED DISPATCH',
              '${(d.totalRecommendedDispatchKg / 1000).toStringAsFixed(1)} MT',
              'Net Supply Needed (+5% Buffer)',
              Icons.local_shipping_outlined,
              AppConstants.successGreen,
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 220,
            child: _buildKpiCard(
              'RISK & CONFIDENCE',
              '${d.highRiskFpsCount} High Risk',
              'Avg Confidence: ${(d.averageConfidence * 100).toStringAsFixed(0)}%',
              Icons.warning_amber_rounded,
              d.highRiskFpsCount > 0 ? AppConstants.dangerRed : AppConstants.accentAmber,
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 240,
            child: _buildKpiCard(
              'DEPOT GRAIN BALANCE',
              _depotBalance == null
                  ? 'DEPOT SUPPLY: NORMAL'
                  : (_depotBalance!.isScarcityCondition
                      ? 'DEPOT SUPPLY: SCARCITY DEFICIT (-${(_depotBalance!.deficitKg / 1000).toStringAsFixed(1)} MT)'
                      : 'DEPOT SUPPLY: NORMAL'),
              _depotBalance == null
                  ? 'Godown Stock Feasible'
                  : (_depotBalance!.isScarcityCondition
                      ? '${(_depotBalance!.availableDepotStockKg / 1000).toStringAsFixed(1)} MT Avail. vs ${(_depotBalance!.aggregateDemandKg / 1000).toStringAsFixed(1)} MT Demand'
                      : '${(_depotBalance!.availableDepotStockKg / 1000).toStringAsFixed(1)} MT Available at FCI Godown'),
              Icons.warehouse_outlined,
              (_depotBalance?.isScarcityCondition ?? false)
                  ? const Color(0xFFDC2626)
                  : AppConstants.successGreen,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCard(String label, String value, String subtitle, IconData icon, Color color) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: AppConstants.cardBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: AppConstants.textSecondary,
                      letterSpacing: 0.6,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(icon, size: 16, color: color),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 10,
                color: AppConstants.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVisualizationsSection() {
    final d = _dashboardData!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'DISTRICT TELEMETRY & INTENT SHIFT VISUALISATIONS',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: AppConstants.textSecondary,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Chart 1: 6-Cycle Historical Demand Trend
            Expanded(
              flex: 3,
              child: _buildChartCard(
                title: '1. District Demand Trend (6 Cycles)',
                subtitle: 'Monthly volume: Rice (Navy) and Wheat (Amber)',
                child: _buildDistrictDemandTrendChart(d.historicalCyclesTrend),
              ),
            ),
            const SizedBox(width: 14),

            // Chart 2: High Intent Shift Comparison
            Expanded(
              flex: 3,
              child: _buildChartCard(
                title: '2. Intent Shift at Portability Hubs',
                subtitle: 'Historical Baseline (Navy) vs Declared Intent (Amber)',
                child: _buildIntentShiftComparisonChart(d.topIntentShiftFps),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Chart 3: Inventory vs Forecast
            Expanded(
              flex: 4,
              child: _buildChartCard(
                title: '3. Inventory Buffer vs Forecast Demand',
                subtitle: 'Supply coverage per shop (Navy Stock vs Blue Forecast)',
                child: _buildInventoryVsForecastChart(d.fpsList.take(6).toList()),
              ),
            ),
            const SizedBox(width: 14),

            // Chart 4: FPS Risk Distribution
            Expanded(
              flex: 3,
              child: _buildChartCard(
                title: '4. FPS Risk Rating Breakdown',
                subtitle: 'Risk distribution across all 20 Centers',
                child: _buildRiskDistributionChart(d.riskDistribution, d.totalFps),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildChartCard({required String title, required String subtitle, required Widget child}) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: AppConstants.cardBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: AppConstants.primaryNavy,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(fontSize: 10, color: AppConstants.textSecondary),
            ),
            const Divider(height: 16),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildDistrictDemandTrendChart(List<DistrictHistoricalTrend> trend) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            _buildChartLegend('Rice', AppConstants.primaryNavy),
            const SizedBox(width: 10),
            _buildChartLegend('Wheat', AppConstants.accentAmber),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: trend.map((t) {
            final riceMt = t.riceKg / 1000.0;
            final wheatMt = t.wheatKg / 1000.0;
            final totalMt = t.totalKg / 1000.0;

            final riceH = (riceMt / 120.0) * 70.0;
            final wheatH = (wheatMt / 120.0) * 70.0;

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${totalMt.toStringAsFixed(0)}T',
                  style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      width: 14,
                      height: riceH.clamp(8.0, 75.0),
                      decoration: const BoxDecoration(
                        color: AppConstants.primaryNavy,
                        borderRadius: BorderRadius.vertical(top: Radius.circular(2)),
                      ),
                    ),
                    const SizedBox(width: 2),
                    Container(
                      width: 14,
                      height: wheatH.clamp(6.0, 75.0),
                      decoration: const BoxDecoration(
                        color: AppConstants.accentAmber,
                        borderRadius: BorderRadius.vertical(top: Radius.circular(2)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  t.cycleId.substring(5),
                  style: TextStyle(fontSize: 9, color: AppConstants.textSecondary),
                ),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildIntentShiftComparisonChart(List<Map<String, dynamic>> topShift) {
    return Column(
      children: topShift.take(4).map((item) {
        final name = (item['name'] as String).replaceAll(' (Demo)', '');
        final hist = (item['historical_kg'] as num).toDouble();
        final intent = (item['intent_kg'] as num).toDouble();
        final shift = (item['shift_kg'] as num).toDouble();
        final isSurge = shift > 0;

        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            children: [
              SizedBox(
                width: 95,
                child: Text(
                  name,
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Expanded(
                child: Stack(
                  children: [
                    Container(
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: (hist / 10000.0).clamp(0.1, 1.0),
                      child: Container(
                        height: 12,
                        decoration: BoxDecoration(
                          color: AppConstants.primaryNavy.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: (intent / 10000.0).clamp(0.05, 1.0),
                      child: Container(
                        height: 12,
                        decoration: BoxDecoration(
                          color: isSurge
                              ? AppConstants.accentAmber.withValues(alpha: 0.85)
                              : AppConstants.accentBlue.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              SizedBox(
                width: 65,
                child: Text(
                  '${isSurge ? "+" : ""}${shift.toStringAsFixed(0)} kg',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: isSurge ? AppConstants.accentAmber : AppConstants.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildInventoryVsForecastChart(List<AdminFpsRow> sampleFps) {
    return Column(
      children: sampleFps.take(5).map((fps) {
        final inv = fps.inventoryKg;
        final fc = fps.forecastKg;
        final isDeficit = inv < fc;

        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            children: [
              SizedBox(
                width: 95,
                child: Text(
                  fps.name.replaceAll(' (Demo)', ''),
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      flex: (inv / 100).round().clamp(1, 200),
                      child: Container(
                        height: 10,
                        decoration: BoxDecoration(
                          color: AppConstants.secondaryNavy,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(width: 3),
                    Expanded(
                      flex: (fc / 100).round().clamp(1, 200),
                      child: Container(
                        height: 10,
                        decoration: BoxDecoration(
                          color: AppConstants.accentBlue,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: (isDeficit ? AppConstants.dangerRed : Colors.green).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  isDeficit ? 'DEFICIT' : 'COVERED',
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                    color: isDeficit ? AppConstants.dangerRed : Colors.green.shade800,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildRiskDistributionChart(Map<String, int> riskDist, int total) {
    final high = riskDist['HIGH'] ?? 0;
    final med = riskDist['MEDIUM'] ?? 0;
    final low = riskDist['LOW'] ?? 0;

    return Column(
      children: [
        _buildRiskBar('High Risk', high, total, AppConstants.dangerRed),
        const SizedBox(height: 8),
        _buildRiskBar('Medium Risk', med, total, AppConstants.accentAmber),
        const SizedBox(height: 8),
        _buildRiskBar('Low Risk', low, total, AppConstants.successGreen),
      ],
    );
  }

  Widget _buildRiskBar(String label, int count, int total, Color color) {
    final pct = total > 0 ? (count / total) : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(label, style: TextStyle(fontSize: 10, color: AppConstants.textSecondary)),
            ),
            Text(
              '$count FPS (${(pct * 100).toStringAsFixed(0)}%)',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color),
            ),
          ],
        ),
        const SizedBox(height: 3),
        LinearProgressIndicator(
          value: pct,
          backgroundColor: Colors.grey.shade200,
          valueColor: AlwaysStoppedAnimation<Color>(color),
          minHeight: 5,
          borderRadius: BorderRadius.circular(2),
        ),
      ],
    );
  }

  Widget _buildFpsMatrixSection() {
    final filteredList = _getFilteredFpsList();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: AppConstants.cardBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Table Header & Search with Wrap for safe responsive layout
            Wrap(
              spacing: 12,
              runSpacing: 10,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'FAIR PRICE SHOPS OVERVIEW MATRIX',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppConstants.primaryNavy,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      'Real-time demand signals and inventory balances (Click row for deep-dive)',
                      style: TextStyle(fontSize: 10, color: AppConstants.textSecondary),
                    ),
                  ],
                ),
                SizedBox(
                  width: 240,
                  height: 36,
                  child: TextField(
                    onChanged: (val) => setState(() => _searchQuery = val),
                    decoration: InputDecoration(
                      hintText: 'Search FPS...',
                      hintStyle: const TextStyle(fontSize: 11),
                      prefixIcon: const Icon(Icons.search, size: 16),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Filter Tabs
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _buildFilterChip('All FPS (20)', 'ALL'),
                _buildFilterChip('High Risk Alerts', 'HIGH_RISK'),
                _buildFilterChip('Migrant Hubs', 'MIGRANT'),
                _buildFilterChip('Low Inventory (<25%)', 'LOW_INVENTORY'),
              ],
            ),
            const SizedBox(height: 14),

            // Table
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(AppConstants.bgLight),
                headingTextStyle: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: AppConstants.primaryNavy,
                ),
                dataTextStyle: const TextStyle(fontSize: 11),
                columnSpacing: 20,
                columns: const [
                  DataColumn(label: Text('FPS ID & NAME')),
                  DataColumn(label: Text('HISTORICAL DEMAND')),
                  DataColumn(label: Text('INTENT DEMAND')),
                  DataColumn(label: Text('CONFIDENCE')),
                  DataColumn(label: Text('OPERATIONAL FORECAST (D̂)')),
                  DataColumn(label: Text('RECOMMENDED DISPATCH')),
                  DataColumn(label: Text('INVENTORY')),
                  DataColumn(label: Text('RISK LEVEL')),
                  DataColumn(label: Text('STATUS')),
                  DataColumn(label: Text('ACTION')),
                ],
                rows: filteredList.map((fps) {
                  final isHigh = fps.riskLevel == 'HIGH';
                  final isMed = fps.riskLevel == 'MEDIUM';
                  final riskColor = isHigh
                      ? AppConstants.dangerRed
                      : (isMed ? AppConstants.accentAmber : AppConstants.successGreen);

                  return DataRow(
                    cells: [
                      DataCell(
                        InkWell(
                          onTap: () => _inspectFps(fps.fpsId),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                fps.name,
                                style: const TextStyle(fontWeight: FontWeight.w700, color: AppConstants.primaryNavy),
                              ),
                              Text(
                                fps.fpsId,
                                style: TextStyle(fontSize: 9, fontFamily: 'monospace', color: AppConstants.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ),
                      DataCell(Text('${fps.historicalDemandKg.toStringAsFixed(0)} kg')),
                      DataCell(
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '${fps.declaredIntentKg.toStringAsFixed(0)} kg',
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            Text(
                              '${fps.intentShiftKg >= 0 ? "+" : ""}${fps.intentShiftKg.toStringAsFixed(0)} kg Shift',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: fps.intentShiftKg > 200
                                    ? AppConstants.accentAmber
                                    : AppConstants.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: (fps.confidenceScore >= 0.85
                                    ? AppConstants.successGreen
                                    : AppConstants.accentAmber)
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${(fps.confidenceScore * 100).toStringAsFixed(0)}%',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: fps.confidenceScore >= 0.85
                                  ? AppConstants.successGreen
                                  : AppConstants.accentAmber,
                            ),
                          ),
                        ),
                      ),
                      DataCell(
                        Text(
                          '${fps.forecastKg.toStringAsFixed(0)} kg',
                          style: const TextStyle(fontWeight: FontWeight.w800, color: AppConstants.accentBlue),
                        ),
                      ),
                      DataCell(
                        Text(
                          '${fps.recommendedDispatchKg.toStringAsFixed(0)} kg',
                          style: const TextStyle(fontWeight: FontWeight.w800, color: AppConstants.primaryNavy),
                        ),
                      ),
                      DataCell(
                        Text(
                          '${fps.inventoryKg.toStringAsFixed(0)} kg (${fps.inventoryUtilizationPct.toStringAsFixed(0)}%)',
                          style: TextStyle(
                            color: fps.inventoryUtilizationPct < 20 ? AppConstants.dangerRed : Colors.black87,
                            fontWeight: fps.inventoryUtilizationPct < 20 ? FontWeight.w700 : FontWeight.normal,
                          ),
                        ),
                      ),
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: riskColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: riskColor.withValues(alpha: 0.4)),
                          ),
                          child: Text(
                            fps.riskLevel,
                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: riskColor),
                          ),
                        ),
                      ),
                      DataCell(Text(fps.status)),
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ElevatedButton.icon(
                              onPressed: () => _inspectFps(fps.fpsId),
                              icon: const Icon(Icons.analytics_outlined, size: 12),
                              label: const Text('Dossier', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppConstants.primaryNavy,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              ),
                            ),
                            const SizedBox(width: 6),
                            OutlinedButton.icon(
                              onPressed: () => _showForecastWhatIfDialog(fps.fpsId),
                              icon: const Icon(Icons.psychology_outlined, size: 12),
                              label: const Text('What-If', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppConstants.accentBlue,
                                side: const BorderSide(color: AppConstants.accentBlue),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              ),
                            ),
                            const SizedBox(width: 6),
                            OutlinedButton.icon(
                              onPressed: () => _showDispatchDecisionDialog(fps.fpsId),
                              icon: const Icon(Icons.local_shipping_outlined, size: 12),
                              label: const Text('Decision', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppConstants.successGreen,
                                side: const BorderSide(color: AppConstants.successGreen),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              ),
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
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 10, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500)),
      selected: isSelected,
      selectedColor: AppConstants.primaryNavy,
      labelStyle: TextStyle(color: isSelected ? Colors.white : AppConstants.primaryNavy),
      onSelected: (selected) {
        if (selected) setState(() => _selectedFilter = value);
      },
    );
  }

  Widget _buildChartLegend(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 10, color: AppConstants.textSecondary)),
      ],
    );
  }
}
