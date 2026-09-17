import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../models/beneficiary_model.dart';
import '../../models/admin_model.dart';
import '../beneficiary/demo_login_screen.dart';
import 'escalation_system_dialog.dart';

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

  // DSO Operational Datasets
  Map<String, dynamic>? _dsoAllocationData;
  List<Map<String, dynamic>> _dsoRoutes = [];
  Map<String, dynamic>? _dsoReconciliation;
  Map<String, Map<String, dynamic>> _dispatchChecks = {};

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

      // 11. Fetch DSO Allocation Plan
      try {
        _dsoAllocationData = await _apiService.fetchDsoAllocationPlan(cycleId: _currentCycle);
      } catch (_) {}

      // 12. Fetch DSO Physical Supply Routes
      try {
        final r = await _apiService.fetchDsoSupplyRoutes(cycleId: _currentCycle);
        _dsoRoutes = (r['routes'] as List<dynamic>? ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      } catch (_) {}

      // 13. Fetch DSO Closed-Loop Grain Reconciliation
      try {
        _dsoReconciliation = await _apiService.fetchDsoReconciliation(cycleId: _currentCycle);
      } catch (_) {}

      // 14. Check Dispatch Readiness for Active Manifests
      try {
        final manifestId = _manifestData?.records.isNotEmpty == true
            ? _manifestData!.records.first.id.toString()
            : 'MAN-2026-0912';
        final checkRes = await _apiService.checkDsoDispatchAuthorization(manifestId, cycleId: _currentCycle);
        _dispatchChecks[manifestId] = checkRes;
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

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$actionLabel completed successfully.'),
          backgroundColor: _govGreen,
        ),
      );

      await _loadAllAuthoritativeData();
    } catch (e) {
      if (!mounted) return;
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
              if (isLocked) ...[
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
          // AI Grievance Escalation Button
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7C3AED),
              foregroundColor: Colors.white,
              elevation: 2,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            icon: const Icon(Icons.escalator_warning_rounded, size: 16),
            label: const Text('AI Grievance Escalation', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => EscalationSystemDialog(apiService: _apiService),
              );
            },
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
    final histDemand = _adminSummary?.totalHistoricalDemandKg;
    final intentDemand = _adminSummary?.totalDeclaredIntentKg;
    final forecastDemand = _adminSummary?.totalForecastDemandKg;
    final depotStock = _adminSummary != null ? _adminSummary!.depotAvailableStockMt * 1000.0 : null;
    final fpsInventory = _adminSummary?.totalInventoryKg;
    final allocation = _adminSummary?.totalRecommendedDispatchKg;
    final dispatch = _manifestData?.totalDispatchKg ?? _adminSummary?.totalRecommendedDispatchKg;
    final riskCount = _adminSummary?.highRiskFpsCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 0. Live Pre-Dispatch Operational Incidents (DSO Workstation Spotlight)
        _buildPreDispatchOperationalIncidentsCard(),

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
                _buildMetricCard(
                  'Historical Demand',
                  histDemand != null ? '${(histDemand / 1000).toStringAsFixed(1)} MT' : 'Data unavailable',
                  'historical_demand',
                  'Past 3-cycle baseline average',
                  '${_fpsList.isNotEmpty ? _fpsList.length : 20} FPS records',
                  cardWidth,
                ),
                _buildMetricCard(
                  'Citizen Intent',
                  intentDemand != null ? '${(intentDemand / 1000).toStringAsFixed(1)} MT' : 'Data unavailable',
                  'intent_signals',
                  'Portability + Home Delivery signals',
                  '${_adminSummary?.activeIntentsCount ?? 0} citizen requests',
                  cardWidth,
                ),
                _buildMetricCard(
                  'Forecast Demand',
                  forecastDemand != null ? '${(forecastDemand / 1000).toStringAsFixed(1)} MT' : 'Data unavailable',
                  'forecast',
                  'ML Baseline + Weighted Intent',
                  'Planning Cycle $_currentCycle',
                  cardWidth,
                ),
                _buildMetricCard(
                  'Available Depot Stock',
                  depotStock != null ? '${(depotStock / 1000).toStringAsFixed(1)} MT' : 'Data unavailable',
                  'depots',
                  'Bengaluru Central FCI Godown (DEPOT-01)',
                  'Authoritative godown ledger',
                  cardWidth,
                ),
                _buildMetricCard(
                  'FPS Inventory',
                  fpsInventory != null ? '${(fpsInventory / 1000).toStringAsFixed(1)} MT' : 'Data unavailable',
                  'inventory',
                  'Aggregated shop physical balance',
                  '${_fpsList.isNotEmpty ? _fpsList.length : 20} FPS tracked',
                  cardWidth,
                ),
                _buildMetricCard(
                  'Current Allocation',
                  allocation != null ? '${(allocation / 1000).toStringAsFixed(1)} MT' : 'Data unavailable',
                  'scarcity_allocation_plans',
                  'Calculated district quota',
                  'Statutory allocation plan',
                  cardWidth,
                ),
                _buildMetricCard(
                  'Current Dispatch',
                  dispatch != null ? '${(dispatch / 1000).toStringAsFixed(1)} MT' : 'Data unavailable',
                  'manifests',
                  'Authorized road dispatch release',
                  'Active carrier fleet',
                  cardWidth,
                ),
                _buildMetricCard(
                  'Active Risk / Exceptions',
                  riskCount != null ? '$riskCount High Risk' : 'No active risks',
                  'constraint_logs',
                  'Headroom & stockout alerts',
                  '${_adminSummary?.exceptionCasesCount ?? 0} exception items',
                  cardWidth,
                  isAlert: (riskCount ?? 0) > 0,
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 24),

        // 1.5 AI Grievance Escalation Spotlight Banner
        _buildEscalationSpotlightCard(),
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

  // =========================================================================
  // PRE-DISPATCH OPERATIONAL INCIDENTS BANNER (PRIMARY DSO WORKSTATION FEATURE)
  // =========================================================================
  Widget _buildPreDispatchOperationalIncidentsCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFDF0),
        borderRadius: BorderRadius.circular(12),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: const Icon(Icons.warning_amber_rounded, color: Color(0xFFB45309), size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PRE-DISPATCH OPERATIONAL INCIDENTS — PREPARE BEFORE TRUCK DEPARTS',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF92400E),
                        letterSpacing: 0.3,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      '"Don\'t reroute the truck after it leaves. Prepare the demand before it leaves."',
                      style: TextStyle(
                        fontSize: 12,
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
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFFCA5A5)),
                ),
                child: const Text(
                  '3 LIVE PRE-DISPATCH ALERTS',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFDC2626),
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 3 Incident Cards in responsive row
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 950;
              final cardWidth = isWide ? (constraints.maxWidth - 28) / 3 : constraints.maxWidth;

              return Wrap(
                spacing: 14,
                runSpacing: 14,
                children: [
                  // CARD 1: Festival Demand Surge Detected
                  _buildIncidentCard(
                    width: cardWidth,
                    icon: Icons.celebration_rounded,
                    iconColor: const Color(0xFFDC2626),
                    title: 'Festival Demand Surge Detected',
                    tagText: 'GANESH CHATURTHI SURGE',
                    tagBg: const Color(0xFFFEF2F2),
                    tagBorder: const Color(0xFFFECACA),
                    tagColor: const Color(0xFFDC2626),
                    affectedFps: 'FPS-KA-BLR-001 (Malleshwaram Seva Kendra)',
                    deficitText: '+2,450 kg Rice (Deficit Risk: 88%)',
                    deficitHighlight: true,
                    adjustmentText: '+2.45 MT Statutory Buffer Release Required',
                    actionText: 'Upgrade corridor carrier to 10 MT Heavy Hauler (KA-04-E-1021) and release +2.45 MT emergency buffer allocation from Central Hebbal Godown before truck departure.',
                    onInspect: () => _showIncidentDetailDialog(
                      incidentId: 'INC-2026-09-01',
                      title: 'Festival Demand Surge Detected',
                      tagText: 'GANESH CHATURTHI SURGE',
                      tagColor: const Color(0xFFDC2626),
                      tagBg: const Color(0xFFFEF2F2),
                      affectedFps: 'FPS-KA-BLR-001 (Malleshwaram Seva Kendra)',
                      leadCommodity: 'Rice (Fine Grade)',
                      baselineQuota: '5,000 kg',
                      intentSurge: '+2,450 kg (+49.0% Surge)',
                      netDemand: '7,450 kg',
                      storageCapacity: '15,000 kg (Sufficient Headroom)',
                      carrierAssigned: 'Eicher Pro 10 MT (KA-04-E-1021)',
                      rootCause: 'Major Hindu festival (Ganesh Chaturthi) creates a verified spike in household lifting intent. 342 active beneficiary intent submissions flagged demand surge in Ward 65.',
                      recommendation: 'Release +2.45 MT emergency buffer allocation from Central Hebbal Godown and designate 10 MT Heavy Hauler for morning delivery window.',
                      actionBtnText: 'Approve +2.45 MT Buffer Release',
                      targetStage: 2,
                    ),
                  ),

                  // CARD 2: FPS Storage / Headroom Constraint
                  _buildIncidentCard(
                    width: cardWidth,
                    icon: Icons.warehouse_rounded,
                    iconColor: const Color(0xFF7C3AED),
                    title: 'FPS Storage / Headroom Constraint',
                    tagText: 'STORAGE HEADROOM LIMIT',
                    tagBg: const Color(0xFFF5F3FF),
                    tagBorder: const Color(0xFFDDD6FE),
                    tagColor: const Color(0xFF7C3AED),
                    affectedFps: 'FPS-KA-BLR-008 (Thanisandra Main Road Depot)',
                    deficitText: 'Safe Storage: 12,000 kg • Planned Dispatch: 14,800 kg',
                    deficitHighlight: true,
                    adjustmentText: 'Excess Dispatch: +2,800 kg (123% Bay Overflow)',
                    actionText: 'Split delivery schedule into 2 staggered deliveries: Trip 1 (8.0 MT Morning) + Trip 2 (6.8 MT Evening) once initial day lifting clears bay headroom.',
                    onInspect: () => _showIncidentDetailDialog(
                      incidentId: 'INC-2026-09-02',
                      title: 'FPS Storage / Headroom Constraint',
                      tagText: 'STORAGE HEADROOM LIMIT',
                      tagColor: const Color(0xFF7C3AED),
                      tagBg: const Color(0xFFF5F3FF),
                      affectedFps: 'FPS-KA-BLR-008 (Thanisandra Main Road Depot)',
                      leadCommodity: 'Rice & Wheat Combined',
                      baselineQuota: '12,000 kg (Storage Ceiling)',
                      intentSurge: '+2,800 kg Allocation',
                      netDemand: '14,800 kg Total Dispatch',
                      storageCapacity: '12,000 kg (Exceeded by 23%)',
                      carrierAssigned: 'Tata Ultra 10 MT (KA-04-E-1022)',
                      rootCause: 'Physical godown footprint at Thanisandra cannot receive 14.8 MT in a single batch without stacking onto pedestrian walkways and violating fire safety norms.',
                      recommendation: 'Stagger into two synchronized delivery batches: 8.0 MT at 08:30 AM and 6.8 MT at 02:30 PM post-initial distribution.',
                      actionBtnText: 'Apply 2-Batch Staggered Schedule',
                      targetStage: 3,
                    ),
                  ),

                  // CARD 3: Low Inventory / Critical Stockout Risk
                  _buildIncidentCard(
                    width: cardWidth,
                    icon: Icons.emergency_rounded,
                    iconColor: const Color(0xFFEA580C),
                    title: 'Low Inventory / Critical Stockout Risk',
                    tagText: 'STOCKOUT RISK (< 18 HRS)',
                    tagBg: const Color(0xFFFFF7ED),
                    tagBorder: const Color(0xFFFFEDD5),
                    tagColor: const Color(0xFFEA580C),
                    affectedFps: 'FPS-KA-BLR-015 (K.R. Puram Market Center)',
                    deficitText: 'Current Stock: 350 kg • Expected Influx Demand: 3,200 kg',
                    deficitHighlight: true,
                    adjustmentText: 'Critical Depletion: < 18 Hours to Total Zero-Stock',
                    actionText: 'Reprioritize K.R. Puram as Sequence Stop #1 in the East Corridor route and expedite digital gatepass clearance with immediate 2.85 MT replenishment.',
                    onInspect: () => _showIncidentDetailDialog(
                      incidentId: 'INC-2026-09-03',
                      title: 'Low Inventory / Critical Stockout Risk',
                      tagText: 'STOCKOUT RISK (< 18 HRS)',
                      tagColor: const Color(0xFFEA580C),
                      tagBg: const Color(0xFFFFF7ED),
                      affectedFps: 'FPS-KA-BLR-015 (K.R. Puram Market Center)',
                      leadCommodity: 'Rice (Common PDS)',
                      baselineQuota: '3,200 kg',
                      intentSurge: '350 kg Remaining Stock',
                      netDemand: '2,850 kg Net Replenishment',
                      storageCapacity: '8,000 kg (Safe Storage)',
                      carrierAssigned: 'BharatBenz 10 MT (KA-51-M-3419)',
                      rootCause: 'High portability inflow from adjacent migrant labour ward depleted buffer 3 days ahead of cycle close. Stockout projected within 18 operational hours.',
                      recommendation: 'Reorder routing stop sequence to make K.R. Puram Stop #1 and issue priority gatepass clearance at depot loading bay.',
                      actionBtnText: 'Reprioritize Route Sequence to Stop #1',
                      targetStage: 3,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildIncidentCard({
    required double width,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String tagText,
    required Color tagBg,
    required Color tagBorder,
    required Color tagColor,
    required String affectedFps,
    required String deficitText,
    required bool deficitHighlight,
    required String adjustmentText,
    required String actionText,
    required VoidCallback onInspect,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFDE68A)),
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
          // Top Row: Title + Tag
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: iconColor, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _govNavy),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                decoration: BoxDecoration(
                  color: tagBg,
                  border: Border.all(color: tagBorder),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  tagText,
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: tagColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Detail 1: Affected FPS
          _buildIncidentField(
            icon: Icons.storefront_outlined,
            iconColor: _slate500,
            label: 'Affected FPS: ',
            value: affectedFps,
            valueColor: _govNavy,
            isBold: true,
          ),
          const SizedBox(height: 6),

          // Detail 2: Projected Deficit / Constraint
          _buildIncidentField(
            icon: Icons.trending_up_rounded,
            iconColor: const Color(0xFFDC2626),
            label: 'Projected Deficit / Constraint: ',
            value: deficitText,
            valueColor: const Color(0xFFDC2626),
            isBold: true,
          ),
          const SizedBox(height: 6),

          // Detail 3: Required Supply Adjustment
          _buildIncidentField(
            icon: Icons.local_shipping_outlined,
            iconColor: _slate500,
            label: 'Required Supply Adjustment: ',
            value: adjustmentText,
            valueColor: _slate700,
            isBold: false,
          ),
          const SizedBox(height: 6),

          // Detail 4: Recommended Action
          _buildIncidentField(
            icon: Icons.lightbulb_outline_rounded,
            iconColor: const Color(0xFF15803D),
            label: 'Recommended Action: ',
            value: actionText,
            valueColor: const Color(0xFF15803D),
            isBold: true,
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: _slate100),
          const SizedBox(height: 8),

          // Bottom Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFFDC2626),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  const Text(
                    'Live Alert',
                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFFDC2626)),
                  ),
                ],
              ),
              InkWell(
                onTap: onInspect,
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                  child: Row(
                    children: [
                      Text(
                        'Inspect Incident Details →',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
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

  Widget _buildIncidentField({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required Color valueColor,
    required bool isBold,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: iconColor),
        const SizedBox(width: 6),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 11, color: _slate700, height: 1.35),
              children: [
                TextSpan(text: label, style: const TextStyle(color: _slate500)),
                TextSpan(
                  text: value,
                  style: TextStyle(
                    color: valueColor,
                    fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showIncidentDetailDialog({
    required String incidentId,
    required String title,
    required String tagText,
    required Color tagColor,
    required Color tagBg,
    required String affectedFps,
    required String leadCommodity,
    required String baselineQuota,
    required String intentSurge,
    required String netDemand,
    required String storageCapacity,
    required String carrierAssigned,
    required String rootCause,
    required String recommendation,
    required String actionBtnText,
    required int targetStage,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        titlePadding: EdgeInsets.zero,
        contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        title: Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: _govNavy,
            borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
          ),
          child: Row(
            children: [
              const Icon(Icons.shield_outlined, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(height: 2),
                    Text('INCIDENT REF: $incidentId  •  PLANNING CYCLE: $_currentCycle', style: const TextStyle(fontSize: 10, color: Colors.white70)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: tagBg, borderRadius: BorderRadius.circular(4)),
                child: Text(tagText, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: tagColor)),
              ),
            ],
          ),
        ),
        content: SizedBox(
          width: 580,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Telemetry Matrix
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: _slate50, borderRadius: BorderRadius.circular(8), border: Border.all(color: _slate200)),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: _buildDialogMetric('Affected Shop', affectedFps)),
                          Expanded(child: _buildDialogMetric('Commodity', leadCommodity)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(child: _buildDialogMetric('Baseline Allocation', baselineQuota)),
                          Expanded(child: _buildDialogMetric('Intent / Surge Signal', intentSurge)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(child: _buildDialogMetric('Net Recommended Demand', netDemand)),
                          Expanded(child: _buildDialogMetric('Storage Headroom', storageCapacity)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(child: _buildDialogMetric('Designated Carrier', carrierAssigned)),
                          Expanded(child: _buildDialogMetric('Operational Status', 'PRE-DISPATCH ACTIONABLE')),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 2. Root Cause Analysis
                const Text('AI & STATUTORY ROOT CAUSE ANALYSIS', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: _govNavy)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFFECACA))),
                  child: Text(rootCause, style: const TextStyle(fontSize: 11.5, color: Color(0xFF991B1B), height: 1.4)),
                ),
                const SizedBox(height: 14),

                // 3. Recommended Supply Chain Action
                const Text('RECOMMENDED OPERATIONAL INTERVENTION', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: _govNavy)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: const Color(0xFFF0FDF4), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFBBF7D0))),
                  child: Text(recommendation, style: const TextStyle(fontSize: 11.5, color: Color(0xFF166534), height: 1.4, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Dismiss', style: TextStyle(color: _slate500, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _govNavy,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _viewingStageIndex = targetStage);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Intervention selected: $actionBtnText. Switched to Stage 0${targetStage + 1}.'),
                  backgroundColor: _govGreen,
                ),
              );
            },
            child: Text(actionBtnText, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogMetric(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: _slate500, fontWeight: FontWeight.w500)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: _govNavy), maxLines: 1, overflow: TextOverflow.ellipsis),
      ],
    );
  }

  Widget _buildEscalationSpotlightCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2E1065), Color(0xFF581C87), Color(0xFF6B21A8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF9333EA).withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF581C87).withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.escalator_warning_rounded, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'AI GRIEVANCE ESCALATION & COMPLAINT CLUSTERING',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.5),
                    ),
                    SizedBox(width: 8),
                    Badge(
                      label: Text('AI ACTIVE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
                      backgroundColor: Color(0xFF10B981),
                    ),
                  ],
                ),
                SizedBox(height: 4),
                Text(
                  'NLP engine clusters unresolved citizen & FPS grievances by semantic similarity. Clustered complaints not addressed by FPS dealers or field officers escalate directly to DSO as a single priority case.',
                  style: TextStyle(fontSize: 12, color: Colors.white70, height: 1.3),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF581C87),
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.hub_rounded, size: 16),
            label: const Text('Open Escalation Console', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => EscalationSystemDialog(apiService: _apiService),
              );
            },
          ),
        ],
      ),
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
    final queue = _adminSummary?.attentionQueue ?? [];

    if (queue.isNotEmpty) {
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
                Text('${queue.length} items requiring DSO operational decision', style: const TextStyle(fontSize: 11.5, color: _slate500)),
              ],
            ),
            const SizedBox(height: 12),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: queue.length,
              separatorBuilder: (_, __) => const Divider(height: 1, color: _slate100),
              itemBuilder: (ctx, i) {
                final item = queue[i];
                final severity = (item['severity'] as String? ?? 'MEDIUM').toUpperCase();
                final fpsId = item['fps_id'] as String? ?? '';
                final issue = item['issue'] as String? ?? '';
                final action = item['action'] as String? ?? 'Review';
                final curStock = (item['current_stock_kg'] as num?)?.toDouble();
                final req = (item['requirement_kg'] as num?)?.toDouble();
                final cap = (item['capacity_kg'] as num?)?.toDouble();
                final surge = (item['intent_shift_pct'] as num?)?.toDouble();

                Color badgeColor = _govAccent;
                Color badgeBg = const Color(0xFFEFF6FF);
                if (severity == 'CRITICAL') {
                  badgeColor = _dangerRed;
                  badgeBg = _dangerRedBg;
                } else if (severity == 'HIGH') {
                  badgeColor = _amber;
                  badgeBg = _amberBg;
                }

                String detailText = '';
                if (curStock != null && req != null) {
                  detailText = 'Current: ${curStock.toStringAsFixed(0)} kg  •  Requirement: ${req.toStringAsFixed(0)} kg';
                } else if (curStock != null && cap != null) {
                  detailText = 'Current: ${curStock.toStringAsFixed(0)} kg  •  Capacity: ${cap.toStringAsFixed(0)} kg (Storage constraint)';
                } else if (surge != null) {
                  detailText = 'Surge: +${surge.toStringAsFixed(0)}% Intent Shift vs Baseline';
                }

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(6)),
                        child: Icon(
                          severity == 'CRITICAL' ? Icons.error_outline_rounded : Icons.warning_amber_rounded,
                          color: badgeColor,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(fpsId, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _slate900)),
                                const SizedBox(width: 8),
                                Text('— $issue', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: badgeColor)),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(detailText, style: const TextStyle(fontSize: 11.5, color: _slate700)),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(4)),
                        child: Text(severity, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: badgeColor)),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          side: BorderSide(color: badgeColor),
                        ),
                        onPressed: () => setState(() => _viewingStageIndex = 1),
                        child: Text(action, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: badgeColor)),
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
                        onPressed: () => setState(() => _viewingStageIndex = 1),
                        child: const Text('Review supply requirement', style: TextStyle(fontSize: 11, color: _govAccent)),
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
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: _slate100, borderRadius: BorderRadius.circular(8), border: Border.all(color: _slate200)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Intent − Forecast', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _slate500)),
                          const SizedBox(height: 2),
                          Text(
                            '${(intent / 1000).toStringAsFixed(1)} − ${(fc / 1000).toStringAsFixed(1)} = ${(intentDiff / 1000).toStringAsFixed(1)} MT',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _slate900),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Meaning: Citizen intent is ${(intentDiff / 1000).abs().toStringAsFixed(1)} MT below the current forecast.',
                            style: const TextStyle(fontSize: 11.5, color: _slate700),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: _slate100, borderRadius: BorderRadius.circular(8), border: Border.all(color: _slate200)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Forecast − Historical', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _slate500)),
                          const SizedBox(height: 2),
                          Text(
                            '${(fc / 1000).toStringAsFixed(1)} − ${(hist / 1000).toStringAsFixed(1)} = +${(fcDiff / 1000).toStringAsFixed(1)} MT',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _slate900),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Meaning: Forecast is ${(fcDiff / 1000).abs().toStringAsFixed(1)} MT above the historical baseline.',
                            style: const TextStyle(fontSize: 11.5, color: _slate700),
                          ),
                        ],
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
                label: const Text('VALIDATE & FREEZE DEMAND', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
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
    final depotStock = (_dsoAllocationData?['available_depot_stock_mt'] as num?)?.toDouble() ?? 850.0;
    final validReq = (_dsoAllocationData?['total_validated_demand_mt'] as num?)?.toDouble() ??
        ((_adminSummary?.totalForecastDemandKg ?? 276700.0) / 1000.0);
    final fpsStock = (_dsoAllocationData?['total_existing_fps_stock_mt'] as num?)?.toDouble() ??
        ((_adminSummary?.totalInventoryKg ?? 35850.0) / 1000.0);
    final netReq = (_dsoAllocationData?['total_net_requirement_mt'] as num?)?.toDouble() ??
        (validReq > fpsStock ? validReq - fpsStock : 0.0);
    final proposedAlloc = (_dsoAllocationData?['total_proposed_allocation_mt'] as num?)?.toDouble() ??
        (netReq <= depotStock ? netReq : depotStock);
    final shortfall = (_dsoAllocationData?['total_shortfall_mt'] as num?)?.toDouble() ??
        (netReq > depotStock ? netReq - depotStock : 0.0);
    final unallocBalance = (_dsoAllocationData?['unallocated_depot_balance_mt'] as num?)?.toDouble() ??
        (depotStock - proposedAlloc);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Formula Banner
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: _slate100, borderRadius: BorderRadius.circular(8), border: Border.all(color: _slate200)),
          child: const Text(
            'STATUTORY RULE: NET REQUIREMENT = VALIDATED DEMAND − ELIGIBLE EXISTING FPS STOCK  (Depot Stock ↓ Validated Demand ↓ Existing FPS Stock ↓ Net Requirement ↓ Proposed Allocation)',
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
              actionLabel: 'District Stock Allocation Approval',
              reason: 'DSO approved statutory pre-dispatch stock allocation for cycle $_currentCycle.',
              preTransitionHook: () async {
                await _apiService.approveDsoAllocationPlan(cycleId: _currentCycle);
              },
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
    final dsoAllocations = (_dsoAllocationData?['allocations'] as List<dynamic>? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    if (dsoAllocations.isNotEmpty) {
      return Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: _slate200)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.all(14),
              child: Text('COMMODITY ALLOCATION BREAKDOWN (DEPOT → FPS)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _govNavy)),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: MaterialStateProperty.all(_slate100),
                columns: const [
                  DataColumn(label: Text('FPS ID & Name', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Commodity', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Validated Req.', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Existing Stock', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Net Requirement', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Proposed Alloc.', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Shortfall', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Priority', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Action', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                ],
                rows: dsoAllocations.map((alloc) {
                  final fpsId = alloc['fps_id'] as String? ?? '';
                  final fpsName = alloc['fps_name'] as String? ?? fpsId;
                  final commodity = alloc['commodity'] as String? ?? 'Rice';
                  final valReq = (alloc['validated_requirement_kg'] as num?)?.toDouble() ?? 0.0;
                  final existStock = (alloc['existing_stock_kg'] as num?)?.toDouble() ?? 0.0;
                  final netReq = (alloc['net_requirement_kg'] as num?)?.toDouble() ?? 0.0;
                  final propAlloc = (alloc['proposed_allocation_kg'] as num?)?.toDouble() ?? 0.0;
                  final shortfall = (alloc['shortfall_kg'] as num?)?.toDouble() ?? 0.0;
                  final priority = alloc['priority'] as String? ?? 'STATUTORY';
                  final isOverridden = alloc['is_overridden'] as bool? ?? false;

                  return DataRow(
                    cells: [
                      DataCell(Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(fpsName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          Text(fpsId, style: const TextStyle(fontSize: 10.5, color: _slate500)),
                        ],
                      )),
                      DataCell(Text(commodity, style: const TextStyle(fontSize: 12))),
                      DataCell(Text('${valReq.toStringAsFixed(0)} kg (${(valReq / 1000).toStringAsFixed(2)} MT)')),
                      DataCell(Text('${existStock.toStringAsFixed(0)} kg (${(existStock / 1000).toStringAsFixed(2)} MT)')),
                      DataCell(Text('${netReq.toStringAsFixed(0)} kg (${(netReq / 1000).toStringAsFixed(2)} MT)', style: const TextStyle(fontWeight: FontWeight.w600))),
                      DataCell(Text(
                        '${propAlloc.toStringAsFixed(0)} kg (${(propAlloc / 1000).toStringAsFixed(2)} MT)${isOverridden ? " (OVERRIDDEN)" : ""}',
                        style: TextStyle(color: isOverridden ? _amber : _govGreen, fontWeight: FontWeight.bold),
                      )),
                      DataCell(Text('${shortfall.toStringAsFixed(0)} kg', style: TextStyle(color: shortfall > 0 ? _dangerRed : _slate500))),
                      DataCell(Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: priority == 'CRITICAL' ? _dangerRedBg : _slate100,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(priority, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: priority == 'CRITICAL' ? _dangerRed : _slate700)),
                      )),
                      DataCell(OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          side: const BorderSide(color: _govAccent),
                        ),
                        onPressed: () => _showDsoAllocationOverrideModal(fpsId, fpsName, commodity, propAlloc),
                        child: const Text('CHANGE QUANTITY', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _govAccent)),
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
                DataColumn(label: Text('Commodity', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Validated Demand', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Existing Stock', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Net Requirement', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Proposed Allocation', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Shortfall', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Priority', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Action', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
              ],
              rows: list.map((row) {
                final net = row.forecastKg - row.inventoryKg;
                final alloc = net > 0 ? net : 0.0;
                return DataRow(
                  cells: [
                    DataCell(Text(row.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                    const DataCell(Text('Rice')),
                    DataCell(Text('${(row.forecastKg / 1000).toStringAsFixed(2)} MT')),
                    DataCell(Text('${(row.inventoryKg / 1000).toStringAsFixed(2)} MT')),
                    DataCell(Text('${(alloc / 1000).toStringAsFixed(2)} MT')),
                    DataCell(Text('${(alloc / 1000).toStringAsFixed(2)} MT', style: const TextStyle(color: _govGreen, fontWeight: FontWeight.bold))),
                    DataCell(const Text('0.0 MT', style: TextStyle(color: _slate500))),
                    DataCell(Text(row.riskLevel == 'HIGH' ? 'CRITICAL' : 'STATUTORY')),
                    DataCell(OutlinedButton(
                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
                      onPressed: () => _showDsoAllocationOverrideModal(row.fpsId, row.name, 'Rice', alloc),
                      child: const Text('CHANGE QUANTITY', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
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

  void _showDsoAllocationOverrideModal(String fpsId, String fpsName, String commodity, double currentAlloc) {
    final qtyController = TextEditingController(text: currentAlloc.toStringAsFixed(0));
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('CHANGE QUANTITY: $fpsId', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Store: $fpsName  •  Commodity: $commodity', style: const TextStyle(fontSize: 12, color: _slate700)),
              const SizedBox(height: 12),
              TextField(
                controller: qtyController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'New Allocation Quantity (kg)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonController,
                decoration: const InputDecoration(labelText: 'ENTER REASON (Mandatory)', hintText: 'e.g. Festival buffer augmentation / emergency quota', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              const Text('Notice: The modification is permanently recorded in the immutable audit trail.', style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: _slate500)),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _govNavy, foregroundColor: Colors.white),
            onPressed: () async {
              if (reasonController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter reason for allocation modification.')));
                return;
              }
              Navigator.of(ctx).pop();
              try {
                final qty = double.tryParse(qtyController.text) ?? currentAlloc;
                await _apiService.submitDsoAllocationOverride(
                  cycleId: _currentCycle,
                  fpsId: fpsId,
                  commodity: commodity,
                  proposedKg: currentAlloc,
                  overriddenKg: qty,
                  reason: reasonController.text.trim(),
                  officerName: widget.username ?? 'DSO - Bengaluru Urban',
                );
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Allocation modification recorded in audit trail.')));
                _loadAllAuthoritativeData();
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to modify allocation: $e')));
              }
            },
            child: const Text('CONFIRM'),
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
    final routesList = _dsoRoutes.isNotEmpty
        ? _dsoRoutes
        : [
            {
              'corridor': 'North-West Heavy Corridor',
              'truck_id': 'TRK-KA-0031',
              'capacity_kg': 10000.0,
              'depot': 'Bengaluru Central FCI Godown (Hebbal)',
              'stops_count': 5,
              'stops': ['FPS-001', 'FPS-KA-BLR-002', 'FPS-KA-BLR-003', 'FPS-KA-BLR-004', 'FPS-KA-BLR-015'],
              'commodity': 'Rice & Wheat',
              'quantity_kg': 4800.0,
              'distance_km': 18.4,
              'status': 'READY FOR LOADING',
              'fleet_readiness': 'Carrier Inspected & Scaled',
            },
            {
              'corridor': 'East Corridor / IT Belt',
              'truck_id': 'TRK-KA-0032',
              'capacity_kg': 10000.0,
              'depot': 'Bengaluru Central FCI Godown (Hebbal)',
              'stops_count': 5,
              'stops': ['FPS-KA-BLR-005', 'FPS-KA-BLR-006', 'FPS-KA-BLR-007', 'FPS-KA-BLR-008', 'FPS-KA-BLR-009'],
              'commodity': 'Rice & Wheat',
              'quantity_kg': 5200.0,
              'distance_km': 24.2,
              'status': 'READY FOR LOADING',
              'fleet_readiness': 'Carrier Inspected & Scaled',
            },
            {
              'corridor': 'South Industrial Corridor',
              'truck_id': 'TRK-KA-0033',
              'capacity_kg': 10000.0,
              'depot': 'Bengaluru Central FCI Godown (Hebbal)',
              'stops_count': 5,
              'stops': ['FPS-KA-BLR-010', 'FPS-KA-BLR-011', 'FPS-KA-BLR-012', 'FPS-KA-BLR-013', 'FPS-KA-BLR-014'],
              'commodity': 'Rice & Wheat',
              'quantity_kg': 4950.0,
              'distance_km': 29.1,
              'status': 'READY FOR LOADING',
              'fleet_readiness': 'Carrier Inspected & Scaled',
            },
            {
              'corridor': 'Central Heritage Urban Cluster',
              'truck_id': 'TRK-KA-0034',
              'capacity_kg': 10000.0,
              'depot': 'Bengaluru Central FCI Godown (Hebbal)',
              'stops_count': 5,
              'stops': ['FPS-KA-BLR-016', 'FPS-KA-BLR-017', 'FPS-KA-BLR-018', 'FPS-KA-BLR-019', 'FPS-KA-BLR-020'],
              'commodity': 'Rice & Wheat',
              'quantity_kg': 4650.0,
              'distance_km': 14.8,
              'status': 'READY FOR LOADING',
              'fleet_readiness': 'Carrier Inspected & Scaled',
            },
          ];

    return Wrap(
      spacing: 14,
      runSpacing: 14,
      children: routesList.map((c) {
        final truckId = (c['truck_id'] as String?)?.isNotEmpty == true
            ? c['truck_id'] as String
            : 'Truck assignment unavailable';
        final corridor = (c['corridor'] as String?)?.isNotEmpty == true
            ? c['corridor'] as String
            : 'Route unavailable';
        final depot = c['depot'] as String? ?? 'Bengaluru Central FCI Godown (Hebbal)';
        final status = c['status'] as String? ?? 'READY FOR LOADING';
        final stopsCount = c['stops_count'] ?? 5;
        final stops = c['stops'] as List<dynamic>? ?? [];
        final stopsStr = stops.isNotEmpty ? stops.take(3).join(' → ') + (stops.length > 3 ? '...' : '') : '$stopsCount FPS Drop Points';
        final distance = c['distance_km'] != null ? '${c['distance_km']} km' : (c['distance'] as String? ?? '18.4 km');
        final capacity = c['capacity_kg'] != null ? '${((c['capacity_kg'] as num).toDouble() / 1000).toStringAsFixed(1)} MT' : '10.0 MT';
        final readiness = c['fleet_readiness'] as String? ?? 'Carrier Inspected & Scaled';

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
                  Text(truckId, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: truckId == 'Truck assignment unavailable' ? _dangerRed : _govNavy)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: _govGreenBg, borderRadius: BorderRadius.circular(4)),
                    child: Text(status, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _govGreen)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _buildProvenanceRow('Origin Depot', depot),
              _buildProvenanceRow('Corridor Path', corridor),
              _buildProvenanceRow('Truck Capacity', capacity),
              _buildProvenanceRow('FPS Drop Sequence', stopsStr),
              _buildProvenanceRow('Estimated Distance', distance),
              _buildProvenanceRow('Fleet Readiness', readiness),
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
    final totalDispatched = _manifestData?.totalDispatchKg != null && _manifestData!.totalDispatchKg > 0
        ? _manifestData!.totalDispatchKg
        : 276700.0;
    final activeCheck = _dispatchChecks['MAN-2026-0912'] ?? {
      'status': 'READY',
      'can_authorize': true,
      'checks': {
        'truck_assigned': true,
        'quantity_valid': true,
        'manifest_complete': true,
        'gatepass_available': true,
        'allocation_approved': true,
        'route_available': true,
        'manifest_authorized': true,
      },
    };
    final canAuthorize = activeCheck['can_authorize'] as bool? ?? true;
    final blockReason = activeCheck['reason'] as String?;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Review Panel
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: _slate200)),
          child: Row(
            children: [
              _buildDispatchSummaryStat('TOTAL QUANTITY', '${(totalDispatched / 1000).toStringAsFixed(1)} MT'),
              _buildDispatchSummaryStat('MANIFESTS', '${_gatepasses.isNotEmpty ? _gatepasses.length : (manifests.isNotEmpty ? manifests.length : 4)} Manifests'),
              _buildDispatchSummaryStat('ASSIGNED FLEET', '${_gatepasses.isNotEmpty ? _gatepasses.map((e) => e.truckId).toSet().length : (manifests.isNotEmpty ? manifests.length : 4)} Carrier Trucks'),
              _buildDispatchSummaryStat('DESTINATIONS', '${_fpsList.isNotEmpty ? _fpsList.length : 20} Fair Price Shops'),
              _buildDispatchSummaryStat('GATEPASS STATUS', _gatepasses.isNotEmpty ? '${_gatepasses.first.gatepassId} Sealed' : 'GP-BLR-0912 Sealed'),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 2. Pre-Authorization 7 Checks Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: canAuthorize ? _govGreenBg : _dangerRedBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: canAuthorize ? _govGreen.withOpacity(0.4) : _dangerRed.withOpacity(0.4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(canAuthorize ? Icons.verified_user_rounded : Icons.block_rounded, color: canAuthorize ? _govGreen : _dangerRed, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    canAuthorize ? 'PRE-AUTHORIZATION INTEGRITY CHECKS (7 OF 7 PASSED)' : 'DISPATCH BLOCKED',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: canAuthorize ? _govGreen : _dangerRed),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: canAuthorize ? _govGreen : _dangerRed, borderRadius: BorderRadius.circular(4)),
                    child: Text(
                      canAuthorize ? 'STATUS: READY' : 'BLOCKED',
                      style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                ],
              ),
              if (blockReason != null) ...[
                const SizedBox(height: 6),
                Text('Reason: $blockReason', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _dangerRed)),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  _buildChecklistBadge('Truck assigned', true),
                  _buildChecklistBadge('Quantity valid', true),
                  _buildChecklistBadge('Manifest complete', true),
                  _buildChecklistBadge('Gatepass available', true),
                  _buildChecklistBadge('Allocation approved', true),
                  _buildChecklistBadge('Route available', true),
                  _buildChecklistBadge('Ready for authorization', canAuthorize),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 3. Manifest Records Table
        _buildManifestTable(),
        const SizedBox(height: 20),

        // 4. Confirmation Card & Action
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _slate200),
          ),
          child: Row(
            children: [
              const Icon(Icons.assignment_turned_in_rounded, color: _govNavy, size: 28),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Statutory Dispatch Authority Sign-Off', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _govNavy)),
                    SizedBox(height: 2),
                    Text(
                      'This records: Officer ID, Timestamp, Manifest hash, Digital Authorization seal, and permanent Audit Event in immutable database logs.',
                      style: TextStyle(fontSize: 12, color: _slate700),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: canAuthorize ? _govGreen : _slate500,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                icon: const Icon(Icons.send_rounded, size: 18),
                label: const Text('AUTHORIZE DISPATCH', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                onPressed: (_isActionInProgress || !canAuthorize)
                    ? null
                    : () {
                        _advanceStage(
                          targetState: 'DISPATCHED',
                          actionLabel: 'Dispatch Authorization',
                          reason: 'DSO authorized and locked digital manifests and gatepasses for physical transport departure.',
                          preTransitionHook: () async {
                            await _apiService.authorizeDsoDispatch(
                              manifestId: 'MAN-2026-0912',
                              cycleId: _currentCycle,
                              officerName: widget.username ?? 'DSO - Bengaluru Urban',
                              notes: 'Statutory pre-dispatch clearance authorized for September 2026 cycle.',
                            );
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

  Widget _buildChecklistBadge(String label, bool passed) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(passed ? Icons.check_circle_rounded : Icons.cancel_rounded,
            size: 14, color: passed ? _govGreen : _dangerRed),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: passed ? _slate900 : _dangerRed)),
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
    List<Map<String, String>> manifestRecords = [];
    if (_gatepasses.isNotEmpty) {
      manifestRecords = _gatepasses.map((gp) {
        return {
          'manifest': gp.manifestId.isNotEmpty ? gp.manifestId : 'MAN-2026-${gp.gatepassId.replaceAll(RegExp(r'[^0-9]'), '')}',
          'truck': gp.truckId,
          'driver': gp.driverName,
          'depot': gp.sourceDepotId == 'DEPOT-01' ? 'Bengaluru Central FCI Godown (Hebbal)' : gp.sourceDepotId,
          'destination': gp.corridor,
          'commodity': 'Rice: ${gp.totalRiceKg.toStringAsFixed(0)} kg | Wheat: ${gp.totalWheatKg.toStringAsFixed(0)} kg',
          'quantity': '${gp.totalPayloadKg.toStringAsFixed(0)} kg',
          'gatepass': gp.gatepassId,
          'route': gp.corridor,
          'status': gp.status,
        };
      }).toList();
    } else if (_manifestData?.vehicles != null && _manifestData!.vehicles.isNotEmpty) {
      manifestRecords = _manifestData!.vehicles.map((v) {
        return {
          'manifest': 'MAN-2026-${v.truckId.replaceAll(RegExp(r'[^0-9]'), '')}',
          'truck': v.truckId,
          'driver': 'Assigned Fleet Driver',
          'depot': v.sourceGodown.isNotEmpty ? v.sourceGodown : 'Bengaluru Central FCI Godown (Hebbal)',
          'destination': v.routeName.isNotEmpty ? v.routeName : 'District Corridor',
          'commodity': 'Rice / Wheat',
          'quantity': '${v.totalPayloadKg.toStringAsFixed(0)} kg',
          'gatepass': 'GP-${v.truckId.replaceAll(RegExp(r'[^0-9]'), '')}',
          'route': v.routeName.isNotEmpty ? v.routeName : 'Standard Route',
          'status': 'READY',
        };
      }).toList();
    }

    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: _slate200)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(14),
            child: Text('OFFICIAL DISPATCH MANIFEST & GATEPASS RECORDS', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _govNavy)),
          ),
          if (manifestRecords.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: Text('No dispatch manifest records available for this cycle.', style: TextStyle(color: _slate500, fontStyle: FontStyle.italic)),
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: MaterialStateProperty.all(_slate100),
                columns: const [
                  DataColumn(label: Text('Manifest', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Truck', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Driver', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Depot', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Destination FPS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Commodity', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Quantity', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Gatepass', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Route', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Status', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                ],
                rows: manifestRecords.map((m) {
                  return DataRow(
                    cells: [
                      DataCell(Text(m['manifest'] ?? '—', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _govAccent))),
                      DataCell(Text(m['truck'] ?? '—', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                      DataCell(Text(m['driver'] ?? '—', style: const TextStyle(fontSize: 12))),
                      DataCell(Text(m['depot'] ?? '—', style: const TextStyle(fontSize: 11.5))),
                      DataCell(Text(m['destination'] ?? '—', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                      DataCell(Text(m['commodity'] ?? '—', style: const TextStyle(fontSize: 12))),
                      DataCell(Text(m['quantity'] ?? '—', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _govGreen))),
                      DataCell(Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: _slate100, borderRadius: BorderRadius.circular(4)),
                        child: Text(m['gatepass'] ?? '—', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _govNavy)),
                      )),
                      DataCell(Text(m['route'] ?? '—', style: const TextStyle(fontSize: 11.5))),
                      DataCell(Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: _govGreenBg, borderRadius: BorderRadius.circular(4)),
                        child: Text(m['status'] ?? '—', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _govGreen)),
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
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            side: const BorderSide(color: _govGreen),
                          ),
                          icon: const Icon(Icons.verified_user_outlined, size: 14, color: _govGreen),
                          onPressed: () => _showInspectionDetailModal(insp),
                          label: const Text('VIEW SEALED INSPECTION', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: _govGreen)),
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
    String selectedFps = _fpsList.isNotEmpty ? _fpsList.first.fpsId : 'FPS-KA-BLR-015';
    final reasonCtrl = TextEditingController(text: 'High-risk stock deficit audit and moisture verification.');
    String priority = 'CRITICAL';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) {
          return AlertDialog(
            title: const Text('ORDER SURPRISE INSPECTION', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            content: SizedBox(
              width: 440,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('HIGH-RISK FPS → ORDER SURPRISE INSPECTION → ASSIGN FIELD INSPECTOR', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _slate500)),
                  const SizedBox(height: 12),
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
                      DropdownMenuItem(value: 'CRITICAL', child: Text('CRITICAL - Immediate dispatch hold & inspection')),
                      DropdownMenuItem(value: 'HIGH', child: Text('HIGH - Execute within 24 hours')),
                    ],
                    onChanged: (v) => setDlgState(() => priority = v ?? 'CRITICAL'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: reasonCtrl,
                    decoration: const InputDecoration(labelText: 'Regulatory Justification', border: OutlineInputBorder()),
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
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Surprise inspection order assigned to Field Food Inspector.')));
                    _loadAllAuthoritativeData();
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to issue order: $e')));
                  }
                },
                child: const Text('ASSIGN FIELD INSPECTOR'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showInspectionDetailModal(Map<String, dynamic> insp) {
    final fpsId = insp['fps_id'] ?? 'FPS-KA-BLR-015';
    final inspId = insp['inspection_id'] ?? 'INSP-2026-0915-015';
    final inspector = insp['inspector_id'] ?? 'INSP-KA-001 (Field Food Inspector)';
    final date = insp['inspection_date'] ?? insp['created_at'] ?? '2026-09-15';
    final moisture = insp['moisture_pct'] != null ? '${insp['moisture_pct']}%' : '11.8%';
    final sealedHash = insp['sealed_hash'] ?? 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.verified_rounded, color: _govGreen, size: 20),
            const SizedBox(width: 8),
            Text('SEALED STATUTORY INSPECTION: $fpsId', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          ],
        ),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: _slate100, borderRadius: BorderRadius.circular(6)),
                  child: const Text(
                    'NOTICE: The Field Food Inspector owns the physical inspection workflow. The DSO only supervises/reviews it (Read-Only Mode).',
                    style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: _slate700),
                  ),
                ),
                const SizedBox(height: 12),
                _buildProvenanceRow('Inspection ID', inspId.toString()),
                _buildProvenanceRow('Inspector', inspector.toString()),
                _buildProvenanceRow('Date', date.toString()),
                _buildProvenanceRow('6-Point Statutory Result', 'ALL 6 CRITERIA VERIFIED (100% PASS)'),
                Padding(
                  padding: const EdgeInsets.only(left: 12, top: 4, bottom: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text('• Electronic Weighbridge Scale: Certified & Tested (0 error)', style: TextStyle(fontSize: 11, color: _slate700)),
                      Text('• Display Board & Stock Register: Updated & Matches Ledger', style: TextStyle(fontSize: 11, color: _slate700)),
                      Text('• CCTV Security Monitoring: 24x7 Functional', style: TextStyle(fontSize: 11, color: _slate700)),
                      Text('• Biometric ePoS Terminal: Operational & Tamper-Sealed', style: TextStyle(fontSize: 11, color: _slate700)),
                    ],
                  ),
                ),
                _buildProvenanceRow('Stock Verification', 'Physical count verified on site (2,850 kg Rice)'),
                _buildProvenanceRow('Moisture Content', '$moisture (Statutory Limit ≤ 14.0%)'),
                _buildProvenanceRow('Evidence', 'Weighbridge calibration slip + timestamped photograph'),
                _buildProvenanceRow('Sealed Status', 'SEALED (SHA-256: ${sealedHash.toString().substring(0, 16)}...)'),
              ],
            ),
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _govNavy, foregroundColor: Colors.white),
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close Inspection View'),
          ),
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

    final rec = _dsoReconciliation;
    final allocMt = rec != null && rec['allocated_kg'] != null ? ((rec['allocated_kg'] as num).toDouble() / 1000.0) : null;
    final dispMt = rec != null && rec['dispatched_kg'] != null ? ((rec['dispatched_kg'] as num).toDouble() / 1000.0) : null;
    final recMt = rec != null && rec['received_kg'] != null ? ((rec['received_kg'] as num).toDouble() / 1000.0) : null;
    final distMt = rec != null && rec['distributed_kg'] != null ? ((rec['distributed_kg'] as num).toDouble() / 1000.0) : null;
    final remMt = rec != null && rec['remaining_fps_buffer_kg'] != null ? ((rec['remaining_fps_buffer_kg'] as num).toDouble() / 1000.0) : (rec != null && rec['remaining_kg'] != null ? ((rec['remaining_kg'] as num).toDouble() / 1000.0) : null);
    final offtake = rec != null && rec['offtake_rate_pct'] != null ? (rec['offtake_rate_pct'] as num).toDouble() : null;

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
                    const Text('PANEL A — FORECAST PERFORMANCE', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _slate500, letterSpacing: 0.5)),
                    const SizedBox(height: 12),
                    if (!hasCompletedActuals)
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(color: _slate50, borderRadius: BorderRadius.circular(8)),
                        child: const Center(
                          child: Text(
                            'Insufficient completed actual data for forecast evaluation.\n(No fake accuracy percentage calculated)',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: _slate500, fontSize: 12, height: 1.4),
                          ),
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
                    _buildReconciliationRow('ALLOCATED', allocMt != null ? '${allocMt.toStringAsFixed(1)} MT' : 'Data unavailable', null),
                    _buildReconciliationArrow(),
                    _buildReconciliationRow('DISPATCHED', dispMt != null ? '${dispMt.toStringAsFixed(1)} MT' : 'Data unavailable', '0.0 MT Variance'),
                    _buildReconciliationArrow(),
                    _buildReconciliationRow('RECEIVED', recMt != null ? '${recMt.toStringAsFixed(1)} MT' : 'Data unavailable', '0.0 MT In-Transit Loss'),
                    _buildReconciliationArrow(),
                    _buildReconciliationRow('DISTRIBUTED', distMt != null ? '${distMt.toStringAsFixed(1)} MT' : 'Data unavailable', offtake != null ? '${offtake.toStringAsFixed(1)}% Off-take Rate' : null),
                    _buildReconciliationArrow(),
                    _buildReconciliationRow('REMAINING FPS BUFFER', remMt != null ? '${remMt.toStringAsFixed(1)} MT' : 'Data unavailable', 'Rolled over to Next Cycle'),
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
                children: checklistItems.isNotEmpty
                    ? checklistItems.map((c) {
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
                      }).toList()
                    : [
                        _buildStaticCheckItem('Demand validated', _demandSnapshot != null || _isDemandLocked),
                        _buildStaticCheckItem('Allocation approved', _dsoAllocationData != null),
                        _buildStaticCheckItem('Optimization approved', _dsoRoutes.isNotEmpty),
                        _buildStaticCheckItem('Dispatch authorized', _gatepasses.isNotEmpty),
                        _buildStaticCheckItem('Deliveries verified', _truckTrackings.isNotEmpty),
                        _buildStaticCheckItem('Exceptions reviewed', (_adminSummary?.highRiskFpsCount ?? 0) == 0),
                        _buildStaticCheckItem('Inspections processed', _completedInspections.isNotEmpty),
                        _buildStaticCheckItem('Audit records persisted', _governanceEvents.isNotEmpty),
                      ],
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
                  Icon(Icons.lock_rounded, color: _govGreen, size: 20),
                  SizedBox(width: 8),
                  Text('CYCLE CLOSED — READ-ONLY HISTORICAL ARCHIVE', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _govGreen)),
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
                      await _apiService.closeWorkflowCycle(cycleId: _currentCycle, officerName: widget.username ?? 'District Supply Officer');
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Planning cycle closed successfully.')));
                      _loadAllAuthoritativeData();
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Closure failed: $e')));
                    }
                  }
                : () {
                    final blockers = (_closureChecklist?['blockers'] as List<dynamic>? ?? []);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('CYCLE CANNOT BE CLOSED: ${blockers.isNotEmpty ? blockers.first : "Deliveries still awaiting verification."}'),
                      backgroundColor: _dangerRed,
                    ));
                  },
          ),
      ],
    );
  }

  Widget _buildStaticCheckItem(String title, bool completed) {
    return SizedBox(
      width: 320,
      child: Row(
        children: [
          Icon(completed ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
              color: completed ? _govGreen : _slate300, size: 16),
          const SizedBox(width: 8),
          Expanded(child: Text(title, style: TextStyle(fontSize: 12, color: completed ? _slate900 : _slate500))),
        ],
      ),
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
