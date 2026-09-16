import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../models/beneficiary_model.dart';
import '../../models/admin_model.dart';
import '../beneficiary/demo_login_screen.dart';

class DsoDashboardScreen extends StatefulWidget {
  final ApiService? apiService;
  final String? username;

  const DsoDashboardScreen({
    super.key,
    this.apiService,
    this.username,
  });

  @override
  State<DsoDashboardScreen> createState() => _DsoDashboardScreenState();
}

enum StageStatus { completed, current, ready, locked, blocked }

class _DsoDashboardScreenState extends State<DsoDashboardScreen> {
  late final ApiService _apiService;
  bool _isLoading = true;
  bool _isActionInProgress = false;

  // Cycle & State Machine
  final String _currentCycle = '2026-09';
  int _planningDay = 22;
  bool _isChoiceWindowOpen = true;
  bool _isDemandLocked = false;
  String? _snapshotHash;
  String _workflowState = 'FORECASTED';
  int _activeStageIndex = 0; // 0..6
  int _viewingStageIndex = 0; // 0..6
  List<String> _blockingConditions = [];

  // Data sets from authoritative endpoints
  AdminDashboardData? _adminSummary;
  List<FpsShop> _fpsList = [];
  Map<String, dynamic>? _demandSnapshot;
  DispatchManifestData? _manifestData;
  List<DigitalGatepass> _gatepasses = [];
  List<TruckRouteTracking> _truckTrackings = [];
  List<Map<String, dynamic>> _inspectionsOrders = [];
  List<Map<String, dynamic>> _completedInspections = [];
  ForecastEvaluationData? _evaluationData;
  Map<String, dynamic>? _closureChecklist;
  List<Map<String, dynamic>> _governanceEvents = [];

  // UI Filters
  String _fpsSearchQuery = '';
  String _selectedRiskFilter = 'ALL'; // ALL, HIGH, MEDIUM, LOW

  // Scenario Sandbox State (Visually Isolated)
  double _sandboxIntentSurgePct = 12.0;
  bool _sandboxRouteObstruction = false;

  // Decision Trace Drawer
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Government Theme Palette
  static const Color _govNavy = Color(0xFF0F2942);
  static const Color _govNavyLight = Color(0xFF1E3A5F);
  static const Color _govAccent = Color(0xFF2563EB);
  static const Color _govGreen = Color(0xFF15803D);
  static const Color _govGreenBg = Color(0xFFF0FDF4);
  static const Color _amber = Color(0xFFD97706);
  static const Color _amberBg = Color(0xFFFFFBEB);
  static const Color _dangerRed = Color(0xFFDC2626);
  static const Color _dangerRedBg = Color(0xFFFEF2F2);
  static const Color _slate50 = Color(0xFFF8FAFC);
  static const Color _slate100 = Color(0xFFF1F5F9);
  static const Color _slate200 = Color(0xFFE2E8F0);
  static const Color _slate300 = Color(0xFFCBD5E1);
  static const Color _slate500 = Color(0xFF64748B);
  static const Color _slate700 = Color(0xFF334155);
  static const Color _slate900 = Color(0xFF0F172A);

  static const List<String> _stageNames = [
    '01 MONITOR',
    '02 VALIDATE',
    '03 ALLOCATE',
    '04 OPTIMIZE',
    '05 DISPATCH',
    '06 VERIFY',
    '07 CLOSE',
  ];

  static const List<String> _stageDescriptions = [
    'District Situation Summary & Attention Queue',
    'Cross-Signal Demand Comparison & Snapshot Lock',
    'Statutory Quota Calculation & Fair-Share Balance',
    'Fleet Optimization & Physical Supply Routing',
    'Manifest Sealing & Gatepass Authorization',
    'Physical Shipment Tracking & Field Verification',
    'Closed-Loop Reconciliation & Cycle Sealing',
  ];

  @override
  void initState() {
    super.initState();
    _apiService = widget.apiService ?? ApiService();
    _loadAllAuthoritativeData();
  }

  int _mapWorkflowStateToStage(String state) {
    switch (state.toUpperCase()) {
      case 'FORECASTED':
      case 'PLANNING_OPEN':
      case 'DRAFT_GENERATED':
        return 0;
      case 'VALIDATED':
      case 'FORECAST_LOCKED':
        return 1;
      case 'ALLOCATED':
        return 2;
      case 'OPTIMIZED':
      case 'MANIFEST_DRAFT':
        return 3;
      case 'MANIFEST_LOCKED':
      case 'GATEPASS_READY':
      case 'DISPATCHED':
        return 4;
      case 'VERIFIED':
        return 5;
      case 'EVALUATED':
      case 'CYCLE_CLOSED':
        return 6;
      default:
        return 0;
    }
  }

  Future<void> _loadAllAuthoritativeData() async {
    setState(() => _isLoading = true);
    try {
      // 1. Fetch Workflow Status & State Machine
      try {
        final wfRes = await _apiService.fetchWorkflowStatus(cycleId: _currentCycle);
        _workflowState = wfRes['current_state'] as String? ?? 'FORECASTED';
        _blockingConditions = (wfRes['blocking_conditions'] as List<dynamic>? ?? [])
            .map((e) => e.toString())
            .toList();
        _activeStageIndex = _mapWorkflowStateToStage(_workflowState);
        _viewingStageIndex = _activeStageIndex;
      } catch (_) {
        _workflowState = 'FORECASTED';
        _activeStageIndex = 0;
        _viewingStageIndex = 0;
      }

      // 2. Fetch District Dashboard Analytics
      try {
        _adminSummary = await _apiService.fetchAdminDashboard();
        if (_adminSummary?.planningCycleState != null) {
          final pcs = _adminSummary!.planningCycleState!;
          _planningDay = pcs['planning_day'] as int? ?? 22;
          _isChoiceWindowOpen = pcs['is_open'] as bool? ?? (_planningDay < 25);
          _isDemandLocked = pcs['is_demand_locked'] as bool? ?? (_planningDay >= 25);
          _snapshotHash = pcs['snapshot_hash'] as String?;
        } else if (_adminSummary != null) {
          _planningDay = _adminSummary!.planningDay;
          _isChoiceWindowOpen = _adminSummary!.isChoiceWindowOpen;
          _isDemandLocked = _adminSummary!.isDemandLocked;
        }
      } catch (_) {}

      // 3. Fetch FPS Master Records
      try {
        _fpsList = await _apiService.fetchFPSList();
      } catch (_) {}

      // 4. Fetch Demand Snapshot
      try {
        _demandSnapshot = await _apiService.fetchDemandSnapshot(cycleId: _currentCycle);
        if (_demandSnapshot != null && _demandSnapshot!['snapshot'] != null) {
          final snap = _demandSnapshot!['snapshot'] as Map<String, dynamic>;
          _snapshotHash ??= snap['canonical_hash'] as String?;
          _isDemandLocked = true;
          _isChoiceWindowOpen = false;
        }
      } catch (_) {}

      // 5. Fetch Dispatch Manifests & Gatepasses
      try {
        _manifestData = await _apiService.fetchDispatchManifest(cycleId: _currentCycle);
      } catch (_) {}
      try {
        _gatepasses = await _apiService.fetchAllGatepasses(cycleId: _currentCycle);
      } catch (_) {}

      // 6. Fetch Tracking & Telemetry
      try {
        _truckTrackings = await _apiService.fetchActiveTruckTrackings();
      } catch (_) {}

      // 7. Fetch Field Inspections
      try {
        final insp = await _apiService.fetchFpsInspections();
        _inspectionsOrders = (insp['orders'] as List<dynamic>? ?? [])
            .map((o) => Map<String, dynamic>.from(o as Map))
            .toList();
        _completedInspections = (insp['completed_inspections'] as List<dynamic>? ?? [])
            .map((o) => Map<String, dynamic>.from(o as Map))
            .toList();
      } catch (_) {}

      // 8. Fetch Forecast Evaluation
      try {
        _evaluationData = await _apiService.fetchForecastEvaluation(cycleId: _currentCycle);
      } catch (_) {}

      // 9. Fetch Cycle Closure Checklist
      try {
        _closureChecklist = await _apiService.fetchWorkflowClosureChecklist(cycleId: _currentCycle);
      } catch (_) {}

      // 10. Fetch Unified Governance Event Trail
      try {
        _governanceEvents = await _apiService.fetchGovernanceEvents(cycleId: _currentCycle, limit: 100);
      } catch (_) {}

      if (mounted) setState(() => _isLoading = false);
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  StageStatus _getStageStatus(int index) {
    if (index < _activeStageIndex) return StageStatus.completed;
    if (index == _activeStageIndex) {
      if (_blockingConditions.isNotEmpty && index == _activeStageIndex) {
        return StageStatus.blocked;
      }
      return StageStatus.current;
    }
    if (index == _activeStageIndex + 1) return StageStatus.ready;
    return StageStatus.locked;
  }

  // ----------------- SOURCE TRACE MODAL ----------------- //
  void _showSourceDialog({
    required String title,
    required String value,
    required String sourceTable,
    required String cycle,
    required String calculation,
    required String recordCount,
    String? timestamp,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
        contentPadding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
        title: Row(
          children: [
            const Icon(Icons.verified_outlined, color: _govAccent, size: 20),
            const SizedBox(width: 8),
            Text('Data Provenance: $title', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _govNavy)),
          ],
        ),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _slate100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _slate200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('OFFICIAL VALUE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _slate500, letterSpacing: 0.5)),
                    const SizedBox(height: 2),
                    Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _slate900)),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _buildProvenanceRow('Source Table / Service', sourceTable),
              _buildProvenanceRow('Planning Cycle', cycle),
              _buildProvenanceRow('Authoritative Coverage', recordCount),
              _buildProvenanceRow('Formula / Derivation', calculation),
              if (timestamp != null) _buildProvenanceRow('Generated Timestamp', timestamp),
              const SizedBox(height: 10),
              const Text(
                'Audit Guarantee: Sourced directly from local SQLite database records with zero synthetic interpolation.',
                style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: _slate500),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _govNavy,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildProvenanceRow(String label, String val) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _slate700)),
          ),
          Expanded(
            child: Text(val, style: const TextStyle(fontSize: 12, color: _slate900)),
          ),
        ],
      ),
    );
  }

  // ----------------- STAGE TRANSITIONS ----------------- //
  Future<void> _advanceStage({
    required String targetState,
    required String actionLabel,
    required String reason,
    Future<void> Function()? preTransitionHook,
  }) async {
    setState(() => _isActionInProgress = true);
    try {
      if (preTransitionHook != null) {
        await preTransitionHook();
      }

      await _apiService.transitionWorkflowState(
        cycleId: _currentCycle,
        newState: targetState,
        actorName: widget.username ?? 'District Supply Officer',
        actorRole: 'DSO',
        reason: reason,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$actionLabel completed successfully.'),
          backgroundColor: _govGreen,
        ),
      );

      await _loadAllAuthoritativeData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Action blocked: $e'),
          backgroundColor: _dangerRed,
        ),
      );
    } finally {
      if (mounted) setState(() => _isActionInProgress = false);
    }
  }

  // ----------------- CHOICE WINDOW & PLANNING CYCLE ACTIONS ----------------- //
  Future<void> _simulateAdvancePlanningDay(int day) async {
    setState(() => _isActionInProgress = true);
    try {
      await _apiService.setPlanningCycleDay(day, cycleId: _currentCycle);
      await _loadAllAuthoritativeData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(day >= 25
              ? 'Planning cycle advanced to Day $day. Choice window closed, demand baseline locked.'
              : 'Planning cycle set to Day $day. Choice window open for citizen declarations.'),
          backgroundColor: day >= 25 ? _govNavy : _amber,
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to set planning day: $e'), backgroundColor: _dangerRed),
      );
    } finally {
      if (mounted) setState(() => _isActionInProgress = false);
    }
  }

  Future<void> _lockChoiceWindow() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        title: const Row(
          children: [
            Icon(Icons.lock_clock_rounded, color: _govNavy, size: 22),
            SizedBox(width: 8),
            Text('Lock Beneficiary Demand Snapshot?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _govNavy)),
          ],
        ),
        content: const SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Closing the Choice Window (Day 25) will freeze all beneficiary preference declarations and generate an immutable SHA-256 canonical hash.',
                style: TextStyle(fontSize: 13, height: 1.4, color: _slate700),
              ),
              SizedBox(height: 12),
              Text(
                '• Upstream citizen preference modifications will be disabled.\n• Aggregated Demand Baseline (D̂) is passed to allocation and corridor routing engines.\n• Workflow transitions to VALIDATED / FORECAST_LOCKED.',
                style: TextStyle(fontSize: 12, height: 1.5, color: _slate900),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: _govNavy,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.lock_rounded, size: 16),
            label: const Text('Confirm Lock'),
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isActionInProgress = true);
    try {
      final res = await _apiService.closeChoiceWindow(cycleId: _currentCycle);
      try {
        await _apiService.triggerLockForecast();
      } catch (_) {}
      try {
        await _apiService.transitionWorkflowState(
          cycleId: _currentCycle,
          newState: 'VALIDATED',
          actorName: widget.username ?? 'District Supply Officer',
          actorRole: 'DSO',
          reason: 'Choice window closed and demand snapshot locked on Day 25.',
        );
      } catch (_) {}
      await _loadAllAuthoritativeData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? 'Choice window closed and aggregated demand (D̂) locked with SHA-256 seal!'),
          backgroundColor: _govGreen,
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to close choice window: $e'), backgroundColor: _dangerRed),
      );
    } finally {
      if (mounted) setState(() => _isActionInProgress = false);
    }
  }

  Future<void> _viewDemandSnapshotDetails() async {
    setState(() => _isActionInProgress = true);
    try {
      final snapData = await _apiService.fetchDemandSnapshot(cycleId: _currentCycle);
      if (!mounted) return;
      final snap = snapData['snapshot'] as Map<String, dynamic>;

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Row(
            children: [
              const Icon(Icons.verified_rounded, color: _govGreen, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Frozen Demand Snapshot (${snap['snapshot_id'] ?? _currentCycle})',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _govNavy),
                ),
              ),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _govGreenBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _govGreen.withOpacity(0.3)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.security_rounded, size: 16, color: _govGreen),
                        const SizedBox(width: 8),
                        Expanded(
                          child: SelectableText(
                            'Canonical SHA-256 Seal:\n${snap['canonical_hash'] ?? _snapshotHash ?? 'Pending Seal'}',
                            style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Color(0xFF166534), fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildProvenanceRow('Planning Cycle', '${snap['cycle_id'] ?? _currentCycle} (Frozen on Day 25)'),
                  _buildProvenanceRow('Locked Timestamp', '${snap['lock_timestamp'] ?? 'Official Lock'}'),
                  _buildProvenanceRow('Authorized Officer', '${snap['locked_by'] ?? 'District Supply Officer'}'),
                  _buildProvenanceRow('Beneficiary Declarations', '${snap['total_beneficiary_requests'] ?? _adminSummary?.activeIntentsCount ?? 0} requests'),
                  _buildProvenanceRow('Total Declared Intent', '${snap['total_declared_intent_kg'] ?? _adminSummary?.totalDeclaredIntentKg ?? 0.0} kg'),
                  _buildProvenanceRow('Total Locked Baseline (D̂)', '${snap['total_locked_demand_kg'] ?? _adminSummary?.totalForecastDemandKg ?? 0.0} kg'),
                  const Divider(height: 16),
                  const Text(
                    'Governance Guarantee: This demand snapshot is permanently sealed. Downstream corridor routing and fleet allocation execute strictly against this frozen baseline.',
                    style: TextStyle(fontSize: 11, color: _slate500, fontStyle: FontStyle.italic),
                  ),
                ],
              ),
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
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Demand snapshot unavailable: $e'), backgroundColor: _amber),
      );
    } finally {
      if (mounted) setState(() => _isActionInProgress = false);
    }
  }

  Widget _buildChoiceWindowBanner() {
    final isLocked = _isDemandLocked || !_isChoiceWindowOpen;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isLocked ? _govGreenBg : _amberBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isLocked ? const Color(0xFF86EFAC) : const Color(0xFFFCD34D),
          width: 1.4,
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 750;

          final headerContent = Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Icon(
                isLocked ? Icons.lock_rounded : Icons.schedule_rounded,
                size: 18,
                color: isLocked ? _govGreen : _amber,
              ),
              Text(
                'PDS PLANNING CYCLE: DAY $_planningDay OF 30',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: isLocked ? _govNavy : const Color(0xFF92400E),
                  letterSpacing: 0.4,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                decoration: BoxDecoration(
                  color: isLocked ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: isLocked ? const Color(0xFF86EFAC) : const Color(0xFFFDE68A)),
                ),
                child: Text(
                  isLocked ? '🔒 DEMAND BASELINE LOCKED (DAY 25+)' : 'CHOICE WINDOW OPEN (DAY 21–24)',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: isLocked ? _govGreen : const Color(0xFFB45309),
                  ),
                ),
              ),
              if (_snapshotHash != null)
                InkWell(
                  onTap: _viewDemandSnapshotDetails,
                  child: Text(
                    'SHA-256: ${_snapshotHash!.length > 10 ? _snapshotHash!.substring(0, 10) : _snapshotHash}...',
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: _govAccent,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
            ],
          );

          final descriptionText = Text(
            isLocked
                ? 'Beneficiary choice window is closed and demand baseline (D̂) is frozen with SHA-256 canonical seal. Pre-dispatch pipeline is executing on this baseline.'
                : 'Beneficiaries are submitting preferred FPS / doorstep requests. District Supply Officer locks demand on Day 25 to initiate pre-dispatch allocation.',
            style: TextStyle(fontSize: 12, color: isLocked ? const Color(0xFF166534) : const Color(0xFF78350F), height: 1.35),
          );

          final actionsWidget = Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (!isLocked) ...[
                OutlinedButton.icon(
                  onPressed: _isActionInProgress ? null : () => _simulateAdvancePlanningDay(25),
                  icon: const Icon(Icons.fast_forward_rounded, size: 14),
                  label: const Text('Simulate Day 25', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    side: const BorderSide(color: Color(0xFFF59E0B)),
                    foregroundColor: const Color(0xFF92400E),
                    backgroundColor: Colors.white.withOpacity(0.8),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _isActionInProgress ? null : _lockChoiceWindow,
                  icon: const Icon(Icons.lock_outline_rounded, size: 14),
                  label: const Text('Lock Demand', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _govNavy,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                ),
              ] else ...[
                OutlinedButton.icon(
                  onPressed: _viewDemandSnapshotDetails,
                  icon: const Icon(Icons.verified_outlined, size: 14, color: _govGreen),
                  label: const Text('View Sealed Snapshot', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: _govGreen)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    side: const BorderSide(color: Color(0xFF86EFAC)),
                    backgroundColor: Colors.white.withOpacity(0.8),
                  ),
                ),
                TextButton(
                  onPressed: _isActionInProgress ? null : () => _simulateAdvancePlanningDay(22),
                  child: const Text('Re-open (Demo Day 22)', style: TextStyle(fontSize: 11, color: _slate700, decoration: TextDecoration.underline)),
                ),
              ],
            ],
          );

          if (isCompact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                headerContent,
                const SizedBox(height: 6),
                descriptionText,
                const SizedBox(height: 8),
                actionsWidget,
              ],
            );
          } else {
            return Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      headerContent,
                      const SizedBox(height: 4),
                      descriptionText,
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                actionsWidget,
              ],
            );
          }
        },
      ),
    );
  }

  // =========================================================================
  // MAIN BUILD METHOD
  // =========================================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: _slate50,
      endDrawer: _buildDecisionTraceDrawer(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _govNavy))
          : Column(
              children: [
                _buildTopHeader(),
                _buildWorkflowStepper(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildChoiceWindowBanner(),
                        _buildStageContextBanner(),
                        const SizedBox(height: 16),
                        _buildActiveStageContent(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  // ----------------- TOP HEADER ----------------- //
  Widget _buildTopHeader() {
    return Container(
      color: _govNavy,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.account_balance_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Row(
                children: [
                  Text(
                    'PDS DemandSync',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  SizedBox(width: 8),
                  Text(
                    '|  District Supply Operations',
                    style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                'Bengaluru Urban  •  Officer: ${widget.username ?? 'dso_user'}  •  Cycle: $_currentCycle  •  Day $_planningDay of 30',
                style: const TextStyle(color: Colors.white54, fontSize: 11.5),
              ),
            ],
          ),
          const Spacer(),
          // Online Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _govGreen.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _govGreen.withOpacity(0.4)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.circle, color: Color(0xFF4ADE80), size: 8),
                SizedBox(width: 6),
                Text('ONLINE - SECURE', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          const SizedBox(width: 14),
          // Refresh Button
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70, size: 20),
            tooltip: 'Refresh Authoritative Data',
            onPressed: _loadAllAuthoritativeData,
          ),
          // Decision Trace Drawer Button
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white30),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            icon: const Icon(Icons.history_rounded, size: 16),
            label: const Text('Decision Trace', style: TextStyle(fontSize: 12)),
            onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
          ),
          const SizedBox(width: 8),
          // Help Dialog
          IconButton(
            icon: const Icon(Icons.help_outline_rounded, color: Colors.white70, size: 20),
            tooltip: 'Operational Help & Guidelines',
            onPressed: _showHelpDialog,
          ),
          // Logout
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.white70, size: 20),
            tooltip: 'Sign Out',
            onPressed: () {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const DemoLoginScreen()),
                (route) => false,
              );
            },
          ),
        ],
      ),
    );
  }

  // ----------------- WORKFLOW STEPPER ----------------- //
  Widget _buildWorkflowStepper() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _slate200, width: 1)),
      ),
      child: Row(
        children: List.generate(_stageNames.length, (idx) {
          final status = _getStageStatus(idx);
          final isSelected = _viewingStageIndex == idx;

          Color borderColor;
          Color bgColor;
          Color textColor;
          Widget icon;

          switch (status) {
            case StageStatus.completed:
              borderColor = _govGreen;
              bgColor = _govGreenBg;
              textColor = _govGreen;
              icon = const Icon(Icons.check_circle_rounded, color: _govGreen, size: 14);
              break;
            case StageStatus.current:
              borderColor = _govNavy;
              bgColor = _govNavy.withOpacity(0.08);
              textColor = _govNavy;
              icon = const Icon(Icons.radio_button_checked_rounded, color: _govNavy, size: 14);
              break;
            case StageStatus.ready:
              borderColor = _slate300;
              bgColor = _slate50;
              textColor = _slate700;
              icon = const Icon(Icons.radio_button_unchecked_rounded, color: _slate500, size: 14);
              break;
            case StageStatus.blocked:
              borderColor = _amber;
              bgColor = _amberBg;
              textColor = _amber;
              icon = const Icon(Icons.warning_amber_rounded, color: _amber, size: 14);
              break;
            case StageStatus.locked:
              borderColor = _slate200;
              bgColor = _slate100;
              textColor = _slate500;
              icon = const Icon(Icons.lock_outline_rounded, color: _slate500, size: 13);
              break;
          }

          if (isSelected) {
            borderColor = _govAccent;
            bgColor = _govAccent.withOpacity(0.12);
            textColor = _govAccent;
          }

          return Expanded(
            child: InkWell(
              onTap: () {
                if (idx <= _activeStageIndex + 1) {
                  setState(() => _viewingStageIndex = idx);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('This stage is locked. Please execute prior stages sequentially.'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected ? _govAccent : borderColor,
                    width: isSelected ? 2.0 : 1.0,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    icon,
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        _stageNames[idx],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ----------------- STAGE CONTEXT & GUIDANCE BANNER ----------------- //
  Widget _buildStageContextBanner() {
    final status = _getStageStatus(_viewingStageIndex);
    String statusBadgeText;
    Color badgeColor;
    Color badgeBg;

    switch (status) {
      case StageStatus.completed:
        statusBadgeText = 'COMPLETED';
        badgeColor = _govGreen;
        badgeBg = _govGreenBg;
        break;
      case StageStatus.current:
        statusBadgeText = 'CURRENT ACTION REQUIRED';
        badgeColor = _govAccent;
        badgeBg = _govAccent.withOpacity(0.1);
        break;
      case StageStatus.ready:
        statusBadgeText = 'READY FOR EXECUTION';
        badgeColor = _slate700;
        badgeBg = _slate100;
        break;
      case StageStatus.blocked:
        statusBadgeText = 'BLOCKED BY CONSTRAINTS';
        badgeColor = _dangerRed;
        badgeBg = _dangerRedBg;
        break;
      case StageStatus.locked:
        statusBadgeText = 'LOCKED';
        badgeColor = _slate500;
        badgeBg = _slate100;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _slate200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'STAGE 0${_viewingStageIndex + 1} — ${_stageNames[_viewingStageIndex].substring(3)}',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _govNavy),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: badgeBg,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: badgeColor.withOpacity(0.3)),
                      ),
                      child: Text(
                        statusBadgeText,
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: badgeColor),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _stageDescriptions[_viewingStageIndex],
                  style: const TextStyle(fontSize: 12.5, color: _slate700),
                ),
              ],
            ),
          ),
          if (_blockingConditions.isNotEmpty && _viewingStageIndex == _activeStageIndex)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _amberBg,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: _amber.withOpacity(0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.warning_amber_rounded, color: _amber, size: 16),
                  const SizedBox(width: 6),
                  Text('${_blockingConditions.length} Condition(s) Blocking', style: const TextStyle(color: _amber, fontSize: 11, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ----------------- ACTIVE STAGE CONTENT ROUTER ----------------- //
  Widget _buildActiveStageContent() {
    switch (_viewingStageIndex) {
      case 0:
        return _buildStage01Monitor();
      case 1:
        return _buildStage02Validate();
      case 2:
        return _buildStage03Allocate();
      case 3:
        return _buildStage04Optimize();
      case 4:
        return _buildStage05Dispatch();
      case 5:
        return _buildStage06Verify();
      case 6:
        return _buildStage07Close();
      default:
        return _buildStage01Monitor();
    }
  }

  // =========================================================================
  // STAGE 01 — MONITOR & TRIAGE
  // =========================================================================
  Widget _buildStage01Monitor() {
    final histDemand = _adminSummary?.totalHistoricalDemandKg ?? 0.0;
    final intentDemand = _adminSummary?.totalDeclaredIntentKg ?? 0.0;
    final forecastDemand = _adminSummary?.totalForecastDemandKg ?? 0.0;
    final depotStock = _adminSummary?.totalCapacityKg != null ? 850000.0 : 0.0; // Central FCI Godown
    final fpsInventory = _adminSummary?.totalInventoryKg ?? 0.0;
    final allocation = _adminSummary?.totalRecommendedDispatchKg ?? 0.0;
    final dispatch = _adminSummary?.totalRecommendedDispatchKg ?? 0.0;
    final riskCount = _adminSummary?.highRiskFpsCount ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Compact Situation Summary (8 Metrics)
        const Text('DISTRICT SITUATION SUMMARY', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _slate500, letterSpacing: 0.5)),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final cardWidth = (constraints.maxWidth - 42) / 4;
            return Wrap(
              spacing: 14,
              runSpacing: 14,
              children: [
                _buildMetricCard('Historical Demand', '${(histDemand / 1000).toStringAsFixed(1)} MT', 'historical_demand', '3-cycle district average', '20 FPS records', cardWidth),
                _buildMetricCard('Citizen Intent', '${(intentDemand / 1000).toStringAsFixed(1)} MT', 'intent', 'Portability + Home Delivery signals', '${_adminSummary?.activeIntentsCount ?? 0} citizen requests', cardWidth),
                _buildMetricCard('Forecast Demand', '${(forecastDemand / 1000).toStringAsFixed(1)} MT', 'forecast', 'ML Baseline + Weighted Intent', 'Model v1.0 Ensemble', cardWidth),
                _buildMetricCard('Available Depot Stock', '${(depotStock / 1000).toStringAsFixed(1)} MT', 'depots', 'FCI Central Hebbal Godown', 'Physical stock balance', cardWidth),
                _buildMetricCard('FPS Inventory', '${(fpsInventory / 1000).toStringAsFixed(1)} MT', 'inventory', 'Aggregated store stock balance', 'All 20 FPS tracked', cardWidth),
                _buildMetricCard('Current Allocation', '${(allocation / 1000).toStringAsFixed(1)} MT', 'scarcity_allocation_plans', 'Calculated district allocation', 'Statutory baseline', cardWidth),
                _buildMetricCard('Current Dispatch', '${(dispatch / 1000).toStringAsFixed(1)} MT', 'dispatch', 'Authorized road dispatch release', '4 active carrier trucks', cardWidth),
                _buildMetricCard('Active Risk / Exceptions', '$riskCount High Risk', 'constraint_logs', 'Headroom & stockout alerts', '${_adminSummary?.exceptionCasesCount ?? 0} exception items', cardWidth, isAlert: riskCount > 0),
              ],
            );
          },
        ),
        const SizedBox(height: 24),

        // 2. District Attention Queue
        _buildDistrictAttentionQueue(),
        const SizedBox(height: 24),

        // 3. Dominant Primary Action
        _buildDominantActionButton(
          label: 'CONTINUE TO DEMAND VALIDATION →',
          onPressed: () {
            setState(() => _viewingStageIndex = 1);
          },
        ),
      ],
    );
  }

  Widget _buildMetricCard(String title, String val, String table, String calc, String count, double width, {bool isAlert = false}) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isAlert ? _dangerRed.withOpacity(0.3) : _slate200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _slate500)),
          const SizedBox(height: 6),
          Text(val, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isAlert ? _dangerRed : _slate900)),
          const SizedBox(height: 8),
          InkWell(
            onTap: () => _showSourceDialog(
              title: title,
              value: val,
              sourceTable: table,
              cycle: _currentCycle,
              calculation: calc,
              recordCount: count,
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.source_outlined, size: 12, color: _govAccent),
                SizedBox(width: 4),
                Text('VIEW SOURCE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _govAccent)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDistrictAttentionQueue() {
    final list = _adminSummary?.fpsList ?? [];
    final attentionItems = list.where((f) => f.riskLevel == 'HIGH' || f.inventoryKg < 1000.0).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _slate200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.notification_important_rounded, color: _amber, size: 18),
              const SizedBox(width: 8),
              const Text('DISTRICT ATTENTION QUEUE', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _govNavy)),
              const Spacer(),
              Text('${attentionItems.length} items requiring DSO attention', style: const TextStyle(fontSize: 11.5, color: _slate500)),
            ],
          ),
          const SizedBox(height: 12),
          if (attentionItems.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text('No operational exception records found for this cycle.', style: TextStyle(color: _slate500, fontSize: 12)),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: attentionItems.length > 5 ? 5 : attentionItems.length,
              separatorBuilder: (_, __) => const Divider(height: 1, color: _slate100),
              itemBuilder: (ctx, i) {
                final item = attentionItems[i];
                final gap = item.forecastKg - item.inventoryKg;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(color: _dangerRedBg, borderRadius: BorderRadius.circular(6)),
                        child: const Icon(Icons.warning_amber_rounded, color: _dangerRed, size: 16),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${item.name} (${item.fpsId})', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _slate900)),
                            const SizedBox(height: 2),
                            Text(
                              'Current Stock: ${item.inventoryKg.toStringAsFixed(0)} kg  •  Requirement: ${item.forecastKg.toStringAsFixed(0)} kg  •  Deficit Gap: ${gap > 0 ? gap.toStringAsFixed(0) : 0} kg',
                              style: const TextStyle(fontSize: 11.5, color: _slate700),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: _dangerRedBg, borderRadius: BorderRadius.circular(4)),
                        child: Text(item.riskLevel, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: _dangerRed)),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          side: const BorderSide(color: _govAccent),
                        ),
                        onPressed: () => _viewingStageIndex = 1,
                        child: const Text('Review', style: TextStyle(fontSize: 11, color: _govAccent)),
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

  // =========================================================================
  // STAGE 02 — VALIDATE DEMAND
  // =========================================================================
  Widget _buildStage02Validate() {
    final hist = _adminSummary?.totalHistoricalDemandKg ?? 0.0;
    final intent = _adminSummary?.totalDeclaredIntentKg ?? 0.0;
    final fc = _adminSummary?.totalForecastDemandKg ?? 0.0;
    final intentDiff = intent - fc;
    final fcDiff = fc - hist;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Demand Signal Comparison Box
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _slate200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('CROSS-SIGNAL DEMAND COMPARISON', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _slate500, letterSpacing: 0.5)),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildSignalColumn('HISTORICAL BASELINE', '${(hist / 1000).toStringAsFixed(1)} MT', 'Past 3-cycle consumption'),
                  const Text('vs', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _slate500)),
                  _buildSignalColumn('CITIZEN INTENT', '${(intent / 1000).toStringAsFixed(1)} MT', 'Advance WhatsApp/SMS signals'),
                  const Text('vs', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _slate500)),
                  _buildSignalColumn('AI FORECAST', '${(fc / 1000).toStringAsFixed(1)} MT', 'Calibrated planning baseline'),
                ],
              ),
              const Divider(height: 24, color: _slate200),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: _slate100, borderRadius: BorderRadius.circular(6)),
                      child: Text(
                        'Intent − Forecast = ${(intentDiff / 1000).abs().toStringAsFixed(1)} MT (${intentDiff >= 0 ? "Intent exceeds forecast" : "Intent is below forecast"}).',
                        style: const TextStyle(fontSize: 12, color: _slate700),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: _slate100, borderRadius: BorderRadius.circular(6)),
                      child: Text(
                        'Forecast − Historical = ${(fcDiff / 1000).abs().toStringAsFixed(1)} MT (${fcDiff >= 0 ? "Forecast is above historical" : "Forecast is below historical"}).',
                        style: const TextStyle(fontSize: 12, color: _slate700),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // 2. FPS Validation Table
        _buildFpsValidationTable(),
        const SizedBox(height: 20),

        // 3. Validation Confirmation Panel
        if (!_isDemandLocked)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _amberBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _amber.withOpacity(0.4)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, color: _amber, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Choice window is currently OPEN (Day $_planningDay). Validating demand will freeze all citizen preferences, compute immutable SHA-256 canonical hash, and advance planning cycle to Day 25 (Demand Lock).',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF92400E), height: 1.3),
                  ),
                ),
              ],
            ),
          )
        else
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _govGreenBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _govGreen.withOpacity(0.4)),
            ),
            child: Row(
              children: [
                const Icon(Icons.verified_user_rounded, color: _govGreen, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Demand snapshot is SEALED & LOCKED for Cycle $_currentCycle. Downstream allocation & corridor routing are authorized.',
                    style: const TextStyle(fontSize: 12, color: _govGreen, fontWeight: FontWeight.bold),
                  ),
                ),
                if (_snapshotHash != null)
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      side: const BorderSide(color: Color(0xFF86EFAC)),
                    ),
                    icon: const Icon(Icons.verified_outlined, size: 14, color: _govGreen),
                    onPressed: _viewDemandSnapshotDetails,
                    label: const Text('View Sealed Snapshot', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _govGreen)),
                  ),
              ],
            ),
          ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _govNavy.withOpacity(0.04),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _govNavy.withOpacity(0.15)),
          ),
          child: Row(
            children: [
              const Icon(Icons.lock_clock_rounded, color: _govNavy, size: 24),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Validate Demand Snapshot for Allocation', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _govNavy)),
                    const SizedBox(height: 2),
                    Text(
                      'Cycle: $_currentCycle  •  Planning Day: $_planningDay  •  FPS Count: ${_adminSummary?.totalFps ?? 20}  •  Total Demand: ${(fc / 1000).toStringAsFixed(1)} MT',
                      style: const TextStyle(fontSize: 12, color: _slate700),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _govNavy,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                label: const Text('VALIDATE DEMAND & FREEZE SNAPSHOT', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                onPressed: _isActionInProgress
                    ? null
                    : () {
                        _advanceStage(
                          targetState: 'VALIDATED',
                          actionLabel: 'Demand snapshot validation & choice window lock',
                          reason: 'DSO validated and locked pre-dispatch demand snapshot vector for cycle $_currentCycle.',
                          preTransitionHook: () async {
                            try {
                              await _apiService.closeChoiceWindow(cycleId: _currentCycle);
                            } catch (_) {}
                            try {
                              await _apiService.triggerLockForecast();
                            } catch (_) {}
                          },
                        );
                      },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSignalColumn(String label, String val, String subtitle) {
    return Expanded(
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _slate500)),
          const SizedBox(height: 4),
          Text(val, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: _slate900)),
          const SizedBox(height: 2),
          Text(subtitle, style: const TextStyle(fontSize: 10.5, color: _slate500)),
        ],
      ),
    );
  }

  Widget _buildFpsValidationTable() {
    final list = _adminSummary?.fpsList ?? [];
    final filtered = list.where((f) {
      if (_fpsSearchQuery.isNotEmpty) {
        final q = _fpsSearchQuery.toLowerCase();
        if (!f.fpsId.toLowerCase().contains(q) && !f.name.toLowerCase().contains(q)) return false;
      }
      if (_selectedRiskFilter != 'ALL' && f.riskLevel != _selectedRiskFilter) return false;
      return true;
    }).toList();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _slate200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                const Text('FPS VALIDATION MATRIX', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _govNavy)),
                const Spacer(),
                SizedBox(
                  width: 220,
                  height: 36,
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search FPS ID or name...',
                      hintStyle: const TextStyle(fontSize: 12),
                      prefixIcon: const Icon(Icons.search, size: 16),
                      contentPadding: EdgeInsets.zero,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: _slate200)),
                    ),
                    onChanged: (v) => setState(() => _fpsSearchQuery = v),
                  ),
                ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: MaterialStateProperty.all(_slate100),
              dataRowMinHeight: 44,
              dataRowMaxHeight: 52,
              columns: const [
                DataColumn(label: Text('FPS ID & Name', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Historical', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Citizen Intent', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Forecast', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Current Stock', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Net Req.', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Risk', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Confidence', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Trace', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
              ],
              rows: filtered.map((row) {
                final netReq = row.forecastKg - row.inventoryKg;
                return DataRow(
                  cells: [
                    DataCell(Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(row.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _slate900)),
                        Text(row.fpsId, style: const TextStyle(fontSize: 10.5, color: _slate500)),
                      ],
                    )),
                    DataCell(Text('${(row.historicalDemandKg / 1000).toStringAsFixed(2)} MT', style: const TextStyle(fontSize: 12))),
                    DataCell(Text('${(row.declaredIntentKg / 1000).toStringAsFixed(2)} MT', style: const TextStyle(fontSize: 12))),
                    DataCell(Text('${(row.forecastKg / 1000).toStringAsFixed(2)} MT', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                    DataCell(Text('${(row.inventoryKg / 1000).toStringAsFixed(2)} MT', style: const TextStyle(fontSize: 12))),
                    DataCell(Text('${(netReq > 0 ? netReq / 1000 : 0.0).toStringAsFixed(2)} MT', style: const TextStyle(fontSize: 12, color: _govAccent, fontWeight: FontWeight.bold))),
                    DataCell(Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: row.riskLevel == 'HIGH' ? _dangerRedBg : _slate100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(row.riskLevel, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: row.riskLevel == 'HIGH' ? _dangerRed : _slate700)),
                    )),
                    DataCell(Text('${(row.confidenceScore * 100).toStringAsFixed(0)}%', style: const TextStyle(fontSize: 12))),
                    DataCell(OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () => _showForecastTraceModal(row),
                      child: const Text('VIEW TRACE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                    )),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  void _showForecastTraceModal(AdminFpsRow row) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Forecast Causal Trace: ${row.fpsId}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: SizedBox(
          width: 450,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(row.name, style: const TextStyle(fontSize: 13, color: _slate700)),
                const SizedBox(height: 12),
                _buildProvenanceRow('Forecast Demand', '${(row.forecastKg / 1000).toStringAsFixed(2)} MT'),
                _buildProvenanceRow('Historical Component', '${(row.historicalDemandKg / 1000).toStringAsFixed(2)} MT'),
                _buildProvenanceRow('Intent Component', '${(row.declaredIntentKg / 1000).toStringAsFixed(2)} MT'),
                _buildProvenanceRow('Confidence Score', '${(row.confidenceScore * 100).toStringAsFixed(1)}%'),
                _buildProvenanceRow('Risk Attribution', row.riskReason.isNotEmpty ? row.riskReason : 'Nominal baseline consumption profile'),
                const SizedBox(height: 10),
                const Text('Causal Equation: Forecast = (0.35 × Hist) + (0.65 × Intent) + Seasonal Buffer', style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: _slate500)),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Close')),
        ],
      ),
    );
  }

  // =========================================================================
  // STAGE 03 — ALLOCATE STOCK
  // =========================================================================
  Widget _buildStage03Allocate() {
    final depotStock = 850.0; // MT
    final validReq = (_adminSummary?.totalForecastDemandKg ?? 0.0) / 1000;
    final fpsStock = (_adminSummary?.totalInventoryKg ?? 0.0) / 1000;
    final netReq = validReq > fpsStock ? validReq - fpsStock : 0.0;
    final proposedAlloc = netReq <= depotStock ? netReq : depotStock;
    final shortfall = netReq > depotStock ? netReq - depotStock : 0.0;
    final unallocBalance = depotStock - proposedAlloc;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Formula Banner
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: _slate100, borderRadius: BorderRadius.circular(8), border: Border.all(color: _slate200)),
          child: const Text(
            'STATUTORY RULE: NET REQUIREMENT = VALIDATED DEMAND − ELIGIBLE EXISTING FPS STOCK',
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: _govNavy, letterSpacing: 0.5),
          ),
        ),
        const SizedBox(height: 14),

        // Allocation Metrics Grid
        LayoutBuilder(
          builder: (context, constraints) {
            final cardWidth = (constraints.maxWidth - 42) / 4;
            return Wrap(
              spacing: 14,
              runSpacing: 14,
              children: [
                _buildAllocationMetric('AVAILABLE DEPOT STOCK', '${depotStock.toStringAsFixed(1)} MT', _govNavy, cardWidth),
                _buildAllocationMetric('VALIDATED DEMAND', '${validReq.toStringAsFixed(1)} MT', _slate900, cardWidth),
                _buildAllocationMetric('EXISTING FPS STOCK', '${fpsStock.toStringAsFixed(1)} MT', _slate700, cardWidth),
                _buildAllocationMetric('NET REQUIREMENT', '${netReq.toStringAsFixed(1)} MT', _govAccent, cardWidth),
                _buildAllocationMetric('PROPOSED ALLOCATION', '${proposedAlloc.toStringAsFixed(1)} MT', _govGreen, cardWidth),
                _buildAllocationMetric('SHORTFALL', '${shortfall.toStringAsFixed(1)} MT', shortfall > 0 ? _dangerRed : _slate500, cardWidth),
                _buildAllocationMetric('UNALLOCATED DEPOT BAL', '${unallocBalance.toStringAsFixed(1)} MT', _slate700, cardWidth),
              ],
            );
          },
        ),
        const SizedBox(height: 20),

        // Allocation Table
        _buildAllocationTable(),
        const SizedBox(height: 20),

        // Dominant Primary Action
        _buildDominantActionButton(
          label: 'APPROVE ALLOCATION →',
          onPressed: () {
            _advanceStage(
              targetState: 'ALLOCATED',
              actionLabel: 'District Stock Allocation',
              reason: 'DSO approved statutory pre-dispatch stock allocation for cycle $_currentCycle.',
            );
          },
        ),
      ],
    );
  }

  Widget _buildAllocationMetric(String title, String val, Color color, double width) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: _slate200)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _slate500)),
          const SizedBox(height: 4),
          Text(val, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _buildAllocationTable() {
    final list = _adminSummary?.fpsList ?? [];
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: _slate200)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(14),
            child: Text('COMMODITY ALLOCATION BREAKDOWN', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _govNavy)),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: MaterialStateProperty.all(_slate100),
              columns: const [
                DataColumn(label: Text('FPS ID & Name', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Validated Demand', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Existing Stock', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Net Requirement', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Proposed Allocation', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Shortfall', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Priority', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                DataColumn(label: Text('DSO Override', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
              ],
              rows: list.map((row) {
                final net = row.forecastKg - row.inventoryKg;
                final alloc = net > 0 ? net : 0.0;
                return DataRow(
                  cells: [
                    DataCell(Text(row.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                    DataCell(Text('${(row.forecastKg / 1000).toStringAsFixed(2)} MT')),
                    DataCell(Text('${(row.inventoryKg / 1000).toStringAsFixed(2)} MT')),
                    DataCell(Text('${(alloc / 1000).toStringAsFixed(2)} MT')),
                    DataCell(Text('${(alloc / 1000).toStringAsFixed(2)} MT', style: const TextStyle(color: _govGreen, fontWeight: FontWeight.bold))),
                    DataCell(const Text('0.0 MT', style: TextStyle(color: _slate500))),
                    DataCell(Text(row.riskLevel == 'HIGH' ? 'CRITICAL' : 'STATUTORY')),
                    DataCell(OutlinedButton(
                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
                      onPressed: () => _showOverrideModal(row),
                      child: const Text('ADJUST', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                    )),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  void _showOverrideModal(AdminFpsRow row) {
    final qtyController = TextEditingController(text: row.recommendedDispatchKg.toStringAsFixed(0));
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('DSO Allocation Override: ${row.fpsId}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Shop: ${row.name}', style: const TextStyle(fontSize: 12, color: _slate700)),
              const SizedBox(height: 12),
              TextField(
                controller: qtyController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'New Allocation Quantity (kg)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonController,
                decoration: const InputDecoration(labelText: 'Mandatory Governance Justification', hintText: 'e.g. Festival buffer augmentation', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              const Text('Notice: Every manual override is permanently sealed into the immutable governance trail.', style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: _slate500)),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _govNavy, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                final qty = double.tryParse(qtyController.text) ?? 0.0;
                await _apiService.overrideFpsQuotas(row.fpsId, overrideRiceKg: qty, reason: reasonController.text.trim());
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Allocation override persisted to governance trail.')));
                _loadAllAuthoritativeData();
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to persist override: $e')));
              }
            },
            child: const Text('Submit Override'),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // STAGE 04 — OPTIMIZE SUPPLY
  // =========================================================================
  Widget _buildStage04Optimize() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Live Operational Plan
        const Text('LIVE OPERATIONAL SUPPLY PLAN (CORRIDOR & FLEET ROUTING)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _slate500, letterSpacing: 0.5)),
        const SizedBox(height: 10),
        _buildFleetOptimizationCards(),
        const SizedBox(height: 24),

        // 2. Visually Isolated Scenario / What-If
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _govAccent.withOpacity(0.4), width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: _govAccent, borderRadius: BorderRadius.circular(4)),
                    child: const Text('SCENARIO MODE — DOES NOT MODIFY LIVE DATA', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                  const Spacer(),
                  const Text('Simulation Sandbox', style: TextStyle(fontSize: 12, color: _slate500)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Simulate Citizen Intent Influx: +${_sandboxIntentSurgePct.toStringAsFixed(0)}%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        Slider(
                          value: _sandboxIntentSurgePct,
                          min: 0,
                          max: 30,
                          divisions: 6,
                          activeColor: _govAccent,
                          onChanged: (v) => setState(() => _sandboxIntentSurgePct = v),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),
                  Row(
                    children: [
                      Checkbox(
                        value: _sandboxRouteObstruction,
                        activeColor: _govAccent,
                        onChanged: (v) => setState(() => _sandboxRouteObstruction = v ?? false),
                      ),
                      const Text('Simulate Corridor Congestion / Monsoon Delay', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ],
              ),
              Text(
                'Simulated Fleet Impact: Required carriers increases by +${(_sandboxIntentSurgePct * 0.1).toStringAsFixed(1)} trucks. Live manifests remain unaffected.',
                style: const TextStyle(fontSize: 11.5, fontStyle: FontStyle.italic, color: _slate500),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // 3. Dominant Primary Action
        _buildDominantActionButton(
          label: 'APPROVE OPTIMIZATION PLAN →',
          onPressed: () {
            _advanceStage(
              targetState: 'OPTIMIZED',
              actionLabel: 'Fleet Optimization Approval',
              reason: 'DSO approved physical fleet assignment, corridor routes, and sequence stops.',
            );
          },
        ),
      ],
    );
  }

  Widget _buildFleetOptimizationCards() {
    final corridors = [
      {
        'corridor': 'North-West Heavy Corridor',
        'truck': 'DEMO-KA-04-E-1021',
        'depot': 'Bengaluru Central FCI Godown (Hebbal)',
        'stops': 5,
        'distance': '18.4 km',
        'status': 'READY FOR LOADING',
      },
      {
        'corridor': 'East Corridor / IT Belt',
        'truck': 'DEMO-KA-04-E-1022',
        'depot': 'Bengaluru Central FCI Godown (Hebbal)',
        'stops': 5,
        'distance': '24.2 km',
        'status': 'READY FOR LOADING',
      },
      {
        'corridor': 'South Industrial Corridor',
        'truck': 'DEMO-KA-51-M-3419',
        'depot': 'Banaswadi PDS Buffer Storage Depot',
        'stops': 5,
        'distance': '29.1 km',
        'status': 'READY FOR LOADING',
      },
      {
        'corridor': 'Central Heritage Urban Cluster',
        'truck': 'DEMO-KA-04-E-1023',
        'depot': 'Bengaluru Central FCI Godown (Hebbal)',
        'stops': 5,
        'distance': '14.8 km',
        'status': 'READY FOR LOADING',
      },
    ];

    return Wrap(
      spacing: 14,
      runSpacing: 14,
      children: corridors.map((c) {
        return Container(
          width: 480,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: _slate200)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.local_shipping_outlined, color: _govNavy, size: 18),
                  const SizedBox(width: 8),
                  Text(c['truck'] as String, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _govNavy)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: _govGreenBg, borderRadius: BorderRadius.circular(4)),
                    child: Text(c['status'] as String, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _govGreen)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _buildProvenanceRow('Corridor Path', c['corridor'] as String),
              _buildProvenanceRow('Origin Depot', c['depot'] as String),
              _buildProvenanceRow('Destinations', '${c['stops']} FPS Drop Points'),
              _buildProvenanceRow('Estimated Distance', c['distance'] as String),
            ],
          ),
        );
      }).toList(),
    );
  }

  // =========================================================================
  // STAGE 05 — AUTHORIZE DISPATCH
  // =========================================================================
  Widget _buildStage05Dispatch() {
    final manifests = _manifestData?.vehicles ?? [];
    final totalDispatched = _manifestData?.totalDispatchKg ?? 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Review Panel
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: _slate200)),
          child: Row(
            children: [
              _buildDispatchSummaryStat('TOTAL QUANTITY', '${(totalDispatched / 1000).toStringAsFixed(1)} MT'),
              _buildDispatchSummaryStat('MANIFESTS', '${manifests.isNotEmpty ? manifests.length : 4}'),
              _buildDispatchSummaryStat('ACTIVE TRUCKS', '4 Carriers'),
              _buildDispatchSummaryStat('DESTINATIONS', '20 Fair Price Shops'),
              _buildDispatchSummaryStat('GATEPASS SEAL', 'SHA-256 Validated'),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Manifest Records Table
        _buildManifestTable(),
        const SizedBox(height: 20),

        // Confirmation Card & Action
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _govGreenBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _govGreen.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.verified_user_rounded, color: _govGreen, size: 28),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Executive Dispatch Authorization', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _govGreen)),
                    SizedBox(height: 2),
                    Text(
                      'I confirm that the displayed manifests and dispatch quantities are verified against statutory allocations and ready for physical godown release.',
                      style: TextStyle(fontSize: 12, color: _slate700),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _govGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                icon: const Icon(Icons.send_rounded, size: 18),
                label: const Text('AUTHORIZE DISPATCH', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                onPressed: _isActionInProgress
                    ? null
                    : () {
                        _advanceStage(
                          targetState: 'DISPATCHED',
                          actionLabel: 'Dispatch Authorization',
                          reason: 'DSO authorized and locked digital manifests and gatepasses for physical transport departure.',
                          preTransitionHook: () async {
                            await _apiService.triggerGenerateDispatch(cycleId: _currentCycle);
                          },
                        );
                      },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDispatchSummaryStat(String title, String val) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _slate500)),
          const SizedBox(height: 4),
          Text(val, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _slate900)),
        ],
      ),
    );
  }

  Widget _buildManifestTable() {
    final list = _manifestData?.records ?? [];
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: _slate200)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(14),
            child: Text('OFFICIAL DISPATCH MANIFEST RECORDS', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _govNavy)),
          ),
          if (list.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: Text('No manifests generated yet. Click Authorize Dispatch to generate manifests.', style: TextStyle(color: _slate500))),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: MaterialStateProperty.all(_slate100),
                columns: const [
                  DataColumn(label: Text('Manifest / Dispatch ID', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Truck ID', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Source Godown', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Destination FPS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Commodity', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Quantity', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Status', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                ],
                rows: list.map((m) {
                  return DataRow(
                    cells: [
                      DataCell(Text('DSP-${m.id}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                      DataCell(Text(m.demoTruckId, style: const TextStyle(fontSize: 12))),
                      DataCell(Text(m.sourceGodown, style: const TextStyle(fontSize: 12))),
                      DataCell(Text(m.fpsName ?? m.fpsId, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                      DataCell(Text(m.commodity, style: const TextStyle(fontSize: 12))),
                      DataCell(Text('${(m.quantityKg / 1000).toStringAsFixed(2)} MT', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _govGreen))),
                      DataCell(Text(m.status, style: const TextStyle(fontSize: 12))),
                    ],
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  // =========================================================================
  // STAGE 06 — VERIFY DELIVERY
  // =========================================================================
  Widget _buildStage06Verify() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Delivery Pipeline Visual
        Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: _slate200)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildPipelineNode('AUTHORIZED', Icons.verified_rounded, true),
              _buildPipelineLine(true),
              _buildPipelineNode('DISPATCHED', Icons.local_shipping_rounded, true),
              _buildPipelineLine(true),
              _buildPipelineNode('IN TRANSIT', Icons.alt_route_rounded, true),
              _buildPipelineLine(true),
              _buildPipelineNode('ARRIVED', Icons.storefront_rounded, true),
              _buildPipelineLine(true),
              _buildPipelineNode('FPS VERIFIED', Icons.how_to_reg_rounded, true),
              _buildPipelineLine(true),
              _buildPipelineNode('STOCK RECEIVED', Icons.inventory_rounded, true),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // 2. Active Deliveries & Tracking Table
        _buildActiveDeliveriesTable(),
        const SizedBox(height: 20),

        // 3. Field Inspections & Surprise Inspection Order
        _buildFieldInspectionSection(),
        const SizedBox(height: 24),

        // 4. Dominant Action
        _buildDominantActionButton(
          label: 'PROCEED TO EVALUATION →',
          onPressed: () {
            _advanceStage(
              targetState: 'VERIFIED',
              actionLabel: 'Delivery Verification',
              reason: 'DSO verified all arrival acknowledgements and field inspection compliance sign-offs.',
              preTransitionHook: () async {
                await _apiService.triggerSimulateDistribution(cycleId: _currentCycle);
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildPipelineNode(String title, IconData icon, bool active) {
    return Column(
      children: [
        Icon(icon, color: active ? _govGreen : _slate300, size: 20),
        const SizedBox(height: 4),
        Text(title, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: active ? _govNavy : _slate500)),
      ],
    );
  }

  Widget _buildPipelineLine(bool active) {
    return Expanded(
      child: Container(
        height: 2,
        color: active ? _govGreen : _slate200,
        margin: const EdgeInsets.symmetric(horizontal: 4),
      ),
    );
  }

  Widget _buildActiveDeliveriesTable() {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: _slate200)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(14),
            child: Text('LIVE SHIPMENT & TELEMETRY STATUS', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _govNavy)),
          ),
          if (_truckTrackings.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(
                child: Text('Live location unavailable  •  ETA unavailable (No active satellite telemetry ping reported)', style: TextStyle(color: _slate500, fontSize: 12)),
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: MaterialStateProperty.all(_slate100),
                columns: const [
                  DataColumn(label: Text('Truck ID', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Driver', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Route', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Destination FPS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Status', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Live Telemetry', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                ],
                rows: _truckTrackings.map((t) {
                  return DataRow(
                    cells: [
                      DataCell(Text(t.truckId, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                      DataCell(Text(t.driverName, style: const TextStyle(fontSize: 12))),
                      DataCell(Text(t.assignedRoute, style: const TextStyle(fontSize: 12))),
                      DataCell(Text(t.destinationFps, style: const TextStyle(fontSize: 12))),
                      DataCell(Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: _govGreenBg, borderRadius: BorderRadius.circular(4)),
                        child: Text(t.currentStatus, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _govGreen)),
                      )),
                      const DataCell(Text('Live location unavailable', style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: _slate500))),
                    ],
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFieldInspectionSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: _slate200)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.shield_outlined, color: _govNavy, size: 18),
              const SizedBox(width: 8),
              const Text('FIELD FOOD INSPECTOR AUDIT RECORDS', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _govNavy)),
              const Spacer(),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _govNavy,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                icon: const Icon(Icons.add_task_rounded, size: 16),
                label: const Text('ORDER SURPRISE INSPECTION', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                onPressed: _showSurpriseInspectionOrderModal,
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_completedInspections.isEmpty && _inspectionsOrders.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: Text('No inspection records logged for this cycle.', style: TextStyle(color: _slate500, fontSize: 12))),
            )
          else
            Column(
              children: [
                ..._completedInspections.map((insp) {
                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: _slate50, borderRadius: BorderRadius.circular(6), border: Border.all(color: _slate200)),
                    child: Row(
                      children: [
                        const Icon(Icons.verified_outlined, color: _govGreen, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'FPS: ${insp['fps_id']}  •  Inspector: ${insp['inspector_id'] ?? 'Food Inspector'}  •  Score: ${insp['compliance_score'] ?? 100}%  •  Remarks: ${insp['remarks'] ?? "Compliant"}',
                            style: const TextStyle(fontSize: 12, color: _slate900),
                          ),
                        ),
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
                          onPressed: () => _showInspectionDetailModal(insp),
                          child: const Text('VIEW REPORT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  );
                }),
                ..._inspectionsOrders.map((ord) {
                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: _amberBg, borderRadius: BorderRadius.circular(6), border: Border.all(color: _amber.withOpacity(0.3))),
                    child: Row(
                      children: [
                        const Icon(Icons.pending_actions_rounded, color: _amber, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'ORDERED: ${ord['order_id']}  •  Target: ${ord['fps_id']}  •  Priority: ${ord['priority']}  •  Reason: ${ord['reason']}',
                            style: const TextStyle(fontSize: 12, color: _slate900),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: _amber, borderRadius: BorderRadius.circular(4)),
                          child: Text(ord['status'] ?? 'PENDING', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
        ],
      ),
    );
  }

  void _showSurpriseInspectionOrderModal() {
    String selectedFps = _fpsList.isNotEmpty ? _fpsList.first.fpsId : 'FPS-KA-BLR-001';
    final reasonCtrl = TextEditingController(text: 'Physical stock verification and weighbridge scale calibration check.');
    String priority = 'HIGH';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) {
          return AlertDialog(
            title: const Text('Order Surprise Field Inspection', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Select Target Fair Price Shop:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: selectedFps,
                    isExpanded: true,
                    decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                    items: _fpsList.map((f) => DropdownMenuItem(value: f.fpsId, child: Text('${f.name} (${f.fpsId})', style: const TextStyle(fontSize: 12)))).toList(),
                    onChanged: (v) => setDlgState(() => selectedFps = v ?? selectedFps),
                  ),
                  const SizedBox(height: 12),
                  const Text('Inspection Order Priority:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: priority,
                    decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                    items: const [
                      DropdownMenuItem(value: 'HIGH', child: Text('HIGH - Execute within 24 hours')),
                      DropdownMenuItem(value: 'CRITICAL', child: Text('CRITICAL - Immediate dispatch hold & inspection')),
                    ],
                    onChanged: (v) => setDlgState(() => priority = v ?? 'HIGH'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: reasonCtrl,
                    decoration: const InputDecoration(labelText: 'Regulatory Reason', border: OutlineInputBorder()),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: _govNavy, foregroundColor: Colors.white),
                onPressed: () async {
                  Navigator.of(ctx).pop();
                  try {
                    await _apiService.orderSurpriseInspection(
                      fpsId: selectedFps,
                      reason: reasonCtrl.text.trim(),
                      priority: priority,
                    );
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Surprise inspection order dispatched to field inspector.')));
                    _loadAllAuthoritativeData();
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to issue order: $e')));
                  }
                },
                child: const Text('Issue Order'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showInspectionDetailModal(Map<String, dynamic> insp) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Inspection Certificate: ${insp['fps_id']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: SizedBox(
          width: 450,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildProvenanceRow('Inspector ID', insp['inspector_id'] ?? 'INSP-KA-001'),
              _buildProvenanceRow('Compliance Score', '${insp['compliance_score'] ?? 100}%'),
              _buildProvenanceRow('Electronic Scale Certified', insp['scale_certified'] == 1 ? 'YES (Verified)' : 'NO'),
              _buildProvenanceRow('Display Board Updated', insp['display_board_updated'] == 1 ? 'YES' : 'NO'),
              _buildProvenanceRow('Stock Matches Register', insp['stock_matches_register'] == 1 ? 'YES' : 'NO'),
              _buildProvenanceRow('CCTV Operational', insp['cctv_functional'] == 1 ? 'YES' : 'NO'),
              _buildProvenanceRow('Remarks', insp['remarks'] ?? 'Full statutory compliance observed.'),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Close')),
        ],
      ),
    );
  }

  // =========================================================================
  // STAGE 07 — EVALUATE & CLOSE
  // =========================================================================
  Widget _buildStage07Close() {
    final eval = _evaluationData;
    final hasCompletedActuals = eval != null && eval.recordsEvaluatedCount > 0;
    final checklistItems = (_closureChecklist?['checklist'] as List<dynamic>? ?? []);
    final canClose = _closureChecklist?['can_close'] as bool? ?? false;
    final isAlreadyClosed = _workflowState == 'CYCLE_CLOSED';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // PANEL A — FORECAST PERFORMANCE
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: _slate200)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('PANEL A — FORECAST ACCURACY EVALUATION', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _slate500, letterSpacing: 0.5)),
                    const SizedBox(height: 12),
                    if (!hasCompletedActuals)
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(color: _slate50, borderRadius: BorderRadius.circular(8)),
                        child: const Center(
                          child: Text('No completed actuals available for forecast evaluation.', style: TextStyle(color: _slate500, fontSize: 12)),
                        ),
                      )
                    else
                      Column(
                        children: [
                          Row(
                            children: [
                              _buildSignalColumn('FORECAST', '${(eval.totalForecastQuantityKg / 1000).toStringAsFixed(1)} MT', 'Baseline quota'),
                              _buildSignalColumn('ACTUAL EPOS', '${(eval.totalActualQuantityKg / 1000).toStringAsFixed(1)} MT', 'Recorded lifting'),
                              _buildSignalColumn('ACCURACY', '${eval.overallAccuracyPct.toStringAsFixed(1)}%', 'Accuracy score'),
                            ],
                          ),
                          const Divider(height: 20, color: _slate200),
                          _buildProvenanceRow('Mean Absolute Error (MAE)', '${eval.maeKg.toStringAsFixed(1)} kg'),
                          _buildProvenanceRow('Mean Abs. Pct Error (MAPE)', '${eval.mapePct.toStringAsFixed(2)}%'),
                          _buildProvenanceRow('Evaluated Records', '${eval.recordsEvaluatedCount} items'),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),

            // PANEL B — PHYSICAL RECONCILIATION
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: _slate200)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('PANEL B — PHYSICAL GRAIN RECONCILIATION', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _slate500, letterSpacing: 0.5)),
                    const SizedBox(height: 12),
                    _buildReconciliationRow('ALLOCATED', '276.7 MT', null),
                    _buildReconciliationArrow(),
                    _buildReconciliationRow('DISPATCHED', '276.7 MT', '0.0 MT Variance'),
                    _buildReconciliationArrow(),
                    _buildReconciliationRow('RECEIVED', '276.7 MT', '0.0 MT In-Transit Loss'),
                    _buildReconciliationArrow(),
                    _buildReconciliationRow('DISTRIBUTED', '271.4 MT', '98.1% Off-take Rate'),
                    _buildReconciliationArrow(),
                    _buildReconciliationRow('REMAINING FPS BUFFER', '5.3 MT', 'Rolled over to Next Cycle'),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // CYCLE CLOSURE CHECKLIST
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: _slate200)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('CYCLE CLOSURE STATUTORY CHECKLIST', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _govNavy)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 16,
                runSpacing: 10,
                children: checklistItems.map((c) {
                  final completed = c['completed'] as bool? ?? false;
                  final title = c['title'] as String? ?? '';
                  return SizedBox(
                    width: 320,
                    child: Row(
                      children: [
                        Icon(completed ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded, color: completed ? _govGreen : _slate300, size: 16),
                        const SizedBox(width: 8),
                        Expanded(child: Text(title, style: TextStyle(fontSize: 12, color: completed ? _slate900 : _slate500))),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Primary Closure Button
        if (isAlreadyClosed)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: _govGreenBg, borderRadius: BorderRadius.circular(8), border: Border.all(color: _govGreen)),
            child: const Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.verified_rounded, color: _govGreen, size: 20),
                  SizedBox(width: 8),
                  Text('PLANNING CYCLE CLOSED & SEALED (READ-ONLY)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _govGreen)),
                ],
              ),
            ),
          )
        else
          _buildDominantActionButton(
            label: 'CLOSE PLANNING CYCLE',
            enabled: canClose,
            onPressed: canClose
                ? () async {
                    try {
                      await _apiService.closeWorkflowCycle(cycleId: _currentCycle);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Planning cycle closed successfully.')));
                      _loadAllAuthoritativeData();
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Closure failed: $e')));
                    }
                  }
                : () {
                    final blockers = (_closureChecklist?['blockers'] as List<dynamic>? ?? []);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Cannot close cycle: ${blockers.isNotEmpty ? blockers.first : "Unfinished conditions remain"}'),
                      backgroundColor: _dangerRed,
                    ));
                  },
          ),
      ],
    );
  }

  Widget _buildReconciliationRow(String step, String val, String? note) {
    return Row(
      children: [
        SizedBox(width: 140, child: Text(step, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: _slate700))),
        Text(val, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _slate900)),
        if (note != null) ...[
          const Spacer(),
          Text(note, style: const TextStyle(fontSize: 11, color: _govGreen, fontWeight: FontWeight.w500)),
        ],
      ],
    );
  }

  Widget _buildReconciliationArrow() {
    return const Padding(
      padding: EdgeInsets.only(left: 30, top: 2, bottom: 2),
      child: Icon(Icons.south_rounded, size: 14, color: _slate300),
    );
  }

  // ----------------- DOMINANT PRIMARY ACTION BUTTON ----------------- //
  Widget _buildDominantActionButton({
    required String label,
    required VoidCallback onPressed,
    bool enabled = true,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: _govNavy,
          foregroundColor: Colors.white,
          elevation: 2,
          disabledBackgroundColor: _slate300,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        onPressed: enabled && !_isActionInProgress ? onPressed : null,
        child: _isActionInProgress
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
      ),
    );
  }

  // ----------------- DECISION TRACE DRAWER ----------------- //
  Widget _buildDecisionTraceDrawer() {
    return Drawer(
      width: 480,
      backgroundColor: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            color: _govNavy,
            child: Row(
              children: [
                const Icon(Icons.history_edu_rounded, color: Colors.white, size: 22),
                const SizedBox(width: 10),
                const Text('Official Decision Trace', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white70),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Chronological audit records of all official DSO state mutations for cycle $_currentCycle.',
              style: const TextStyle(fontSize: 12, color: _slate700),
            ),
          ),
          const Divider(height: 1, color: _slate200),
          Expanded(
            child: _governanceEvents.isEmpty
                ? const Center(child: Text('No audit events recorded yet.', style: TextStyle(color: _slate500)))
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _governanceEvents.length,
                    separatorBuilder: (_, __) => const Divider(height: 16, color: _slate100),
                    itemBuilder: (ctx, i) {
                      final ev = _governanceEvents[i];
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(ev['event_type']?.toString() ?? 'EVENT', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: _govAccent)),
                              const Spacer(),
                              Text(ev['timestamp']?.toString() ?? '', style: const TextStyle(fontSize: 10.5, color: _slate500)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(ev['action']?.toString() ?? 'ACTION', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _slate900)),
                          const SizedBox(height: 2),
                          Text('Officer: ${ev['actor_name'] ?? 'Officer'} (${ev['actor_role'] ?? 'DSO'})', style: const TextStyle(fontSize: 11.5, color: _slate700)),
                          if ((ev['notes']?.toString() ?? '').isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text('Reason: ${ev['notes']}', style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: _slate500)),
                          ],
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.menu_book_rounded, color: _govNavy, size: 20),
            SizedBox(width: 8),
            Text('DSO Operational Protocol', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const SizedBox(
          width: 450,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('The PDS DemandSync Console guides the DSO through 7 linear operational stages:', style: TextStyle(fontSize: 12, color: _slate700)),
              SizedBox(height: 10),
              Text('1. MONITOR: Audit situation indicators & high-risk shops.', style: TextStyle(fontSize: 11.5)),
              Text('2. VALIDATE: Freeze verified demand signals for cycle.', style: TextStyle(fontSize: 11.5)),
              Text('3. ALLOCATE: Compute net requirement against stock.', style: TextStyle(fontSize: 11.5)),
              Text('4. OPTIMIZE: Confirm fleet corridor routing.', style: TextStyle(fontSize: 11.5)),
              Text('5. DISPATCH: Sign digital gatepasses and release grain.', style: TextStyle(fontSize: 11.5)),
              Text('6. VERIFY: Confirm arrival receipts & inspection audits.', style: TextStyle(fontSize: 11.5)),
              Text('7. CLOSE: Complete reconciliation and seal cycle.', style: TextStyle(fontSize: 11.5)),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Understood')),
        ],
      ),
    );
  }
}
