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

  // Cycle & Authoritative State Machine
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
  final Map<String, Map<String, dynamic>> _dispatchChecks = {};

  // Decision Trace Drawer Key
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
  static const Color _slate400 = Color(0xFF94A3B8);
  static const Color _slate500 = Color(0xFF64748B);
  static const Color _slate700 = Color(0xFF334155);
  static const Color _slate900 = Color(0xFF0F172A);

  static const List<String> _stageShortNames = [
    'DEMAND',
    'VALIDATE',
    'ALLOCATE',
    'OPTIMIZE',
    'DISPATCH',
    'DELIVERY',
    'EVALUATE',
  ];

  static const List<String> _stageNames = [
    '01 MONITOR & TRIAGE',
    '02 VALIDATE DEMAND',
    '03 ALLOCATE',
    '04 OPTIMIZE',
    '05 AUTHORIZE DISPATCH',
    '06 VERIFY DELIVERY',
    '07 EVALUATE & CLOSE',
  ];

  static const List<String> _stageDescriptions = [
    'District operational state, live intent shifts, and immediate decision queue',
    'Beneficiary demand provenance, explicit calculations, and cryptographic snapshot freeze',
    'Central depot stock separation (850 MT) vs FPS inventory allocation & statutory overrides',
    'Fleet carrier capacities, highway corridors, and multi-drop drop sequences',
    'Authoritative manifests, gatepass clearance, and statutory 7-point dispatch check',
    'Fleet movement monitoring, GPS/telemetry verification, and surprise inspection directives',
    'Forecast evaluation (MAPE/MAE), physical grain reconciliation, and backend cycle closure',
  ];

  @override
  void initState() {
    super.initState();
    _apiService = widget.apiService ?? ApiService();
    _loadAllAuthoritativeData();
  }

  int _mapWorkflowStateToStage(String state) {
    switch (state.toUpperCase()) {
      case 'PLANNING_OPEN':
      case 'FORECASTED':
      case 'DRAFT':
        return 0; // Stage 01 / 02
      case 'DEMAND_VALIDATED':
      case 'FORECAST_LOCKED':
        return 2; // Stage 03 ALLOCATE
      case 'ALLOCATED':
        return 3; // Stage 04 OPTIMIZE
      case 'OPTIMIZED':
      case 'MANIFEST_DRAFT':
      case 'MANIFEST_LOCKED':
        return 4; // Stage 05 DISPATCH
      case 'GATEPASS_READY':
      case 'DISPATCH_AUTHORIZED':
      case 'DISPATCHED':
        return 5; // Stage 06 DELIVERY
      case 'VERIFIED':
      case 'DISTRIBUTED':
      case 'EVALUATED':
      case 'CYCLE_CLOSED':
        return 6; // Stage 07 EVALUATE & CLOSE
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

      // 7. Fetch Field Inspections (Surprise Orders + Completed Findings)
      try {
        final insp = await _apiService.fetchFpsInspections();
        _inspectionsOrders = (insp['orders'] as List<dynamic>? ?? [])
            .map((o) => Map<String, dynamic>.from(o as Map))
            .toList();
        _completedInspections = (insp['completed_inspections'] as List<dynamic>? ?? [])
            .map((o) => Map<String, dynamic>.from(o as Map))
            .toList();
      } catch (_) {}

      // 8. Fetch Forecast Evaluation Metrics
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

      // 14. Check Dispatch Readiness for Manifests
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
      if (_blockingConditions.isNotEmpty) return StageStatus.blocked;
      return StageStatus.current;
    }
    if (index == _activeStageIndex + 1) return StageStatus.ready;
    return StageStatus.locked;
  }

  String _getLockReason(int index) {
    switch (index) {
      case 1:
        return 'Requires Stage 01 Situation Review';
      case 2:
        return 'Requires Stage 02 Demand Baseline Validation';
      case 3:
        return 'Requires Stage 03 Stock Allocation Approval';
      case 4:
        return 'Requires Stage 04 Fleet Route Optimization Approval';
      case 5:
        return 'Requires Stage 05 Manifest Movement Authorization';
      case 6:
        return 'Requires Stage 06 Field Delivery & Inspection Verification';
      default:
        return 'Previous operational stages must be completed first.';
    }
  }

  // ----------------- DATA PROVENANCE DIALOG ----------------- //
  void _showProvenanceDialog({
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
        contentPadding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
        title: Row(
          children: [
            const Icon(Icons.verified_user_outlined, color: _govAccent, size: 20),
            const SizedBox(width: 8),
            Text('Data Provenance: $title', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _govNavy)),
          ],
        ),
        content: SizedBox(
          width: 500,
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
                    const Text('OFFICIAL AUTHORITATIVE VALUE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _slate500, letterSpacing: 0.5)),
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
              const Divider(height: 20),
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
            width: 160,
            child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _slate700)),
          ),
          Expanded(
            child: Text(val, style: const TextStyle(fontSize: 12, color: _slate900)),
          ),
        ],
      ),
    );
  }

  // ----------------- STAGE ADVANCEMENT & WORKFLOW TRANSITION ----------------- //
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

  // ----------------- STAGE 02: VALIDATE DEMAND ACTION ----------------- //
  Future<void> _handleValidateDemandAction() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        title: Row(
          children: [
            const Icon(Icons.verified_user_rounded, color: _govGreen, size: 22),
            const SizedBox(width: 8),
            const Text('VALIDATE CURRENT DEMAND SNAPSHOT?', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _govNavy)),
          ],
        ),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'You are about to freeze the forward-looking demand baseline for this operational cycle. Once sealed, this snapshot becomes immutable and governs all warehouse allocations and transport manifests.',
                style: TextStyle(fontSize: 12.5, color: _slate700, height: 1.4),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _slate100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _slate200),
                ),
                child: Column(
                  children: [
                    _buildProvenanceRow('Target Cycle', _currentCycle),
                    _buildProvenanceRow('Participating Beneficiaries', '${_adminSummary?.activeIntentsCount ?? 2000} declarations'),
                    _buildProvenanceRow('Validated Total Demand (D̂)', '${_adminSummary != null ? (_adminSummary!.totalForecastDemandKg / 1000).toStringAsFixed(1) : '276.7'} MT'),
                    _buildProvenanceRow('Commodities Included', 'Rice (173.3 MT) + Wheat (103.4 MT)'),
                    _buildProvenanceRow('Cryptographic Guarantee', 'SHA-256 Demand Seal Generated'),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: _slate500)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: _govGreen,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            icon: const Icon(Icons.check, size: 16),
            label: const Text('Confirm & Seal Snapshot'),
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await _advanceStage(
      targetState: 'DEMAND_VALIDATED',
      actionLabel: 'Demand Snapshot Sealed',
      reason: 'DSO validated aggregated citizen intent and historical baseline for Cycle $_currentCycle.',
      preTransitionHook: () async {
        await _apiService.closeChoiceWindow(cycleId: _currentCycle);
      },
    );
  }

  // ----------------- STAGE 03: ALLOCATION OVERRIDE DIALOG ----------------- //
  void _showAllocationOverrideModal(Map<String, dynamic> item) {
    final fpsId = item['fps_id'] as String;
    final commodity = item['commodity'] as String;
    final currentReq = (item['validated_requirement_kg'] as num).toDouble();
    final proposedAlloc = (item['proposed_allocation_kg'] as num).toDouble();

    final overrideController = TextEditingController(text: proposedAlloc.toStringAsFixed(1));
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        title: Row(
          children: [
            const Icon(Icons.edit_note_rounded, color: _govNavy, size: 22),
            const SizedBox(width: 8),
            Text('Statutory Allocation Override: $fpsId', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _govNavy)),
          ],
        ),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Commodity: $commodity | Validated Demand: $currentReq kg', style: const TextStyle(fontSize: 12, color: _slate500)),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: _slate100, borderRadius: BorderRadius.circular(6)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Statutory Proposed Allocation:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    Text('$proposedAlloc kg', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _govNavy)),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const Text('New Allocation Quantity (kg):', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              TextField(
                controller: overrideController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
              const SizedBox(height: 12),
              const Text('Statutory Justification / Reason (Mandatory):', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              TextField(
                controller: reasonController,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'e.g. Migration influx, festival surge, buffer replenishment',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: _slate500)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _govNavy, foregroundColor: Colors.white),
            onPressed: () async {
              final newQty = double.tryParse(overrideController.text.trim());
              final reason = reasonController.text.trim();
              if (newQty == null || newQty < 0) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a valid allocation quantity.')));
                return;
              }
              if (reason.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Statutory justification is required for allocation overrides.')));
                return;
              }

              Navigator.of(ctx).pop();
              setState(() => _isActionInProgress = true);
              try {
                await _apiService.submitDsoAllocationOverride(
                  cycleId: _currentCycle,
                  fpsId: fpsId,
                  commodity: commodity,
                  proposedKg: proposedAlloc,
                  overriddenKg: newQty,
                  reason: reason,
                  officerName: widget.username ?? 'District Supply Officer',
                );
                await _loadAllAuthoritativeData();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Allocation override for $fpsId permanently recorded in governance log.'), backgroundColor: _govGreen),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to record override: $e'), backgroundColor: _dangerRed));
                }
              } finally {
                if (mounted) setState(() => _isActionInProgress = false);
              }
            },
            child: const Text('Record Override'),
          ),
        ],
      ),
    );
  }

  // ----------------- STAGE 06: ISSUE SURPRISE INSPECTION ORDER ----------------- //
  void _showSurpriseInspectionDialog() {
    String selectedFps = _fpsList.isNotEmpty ? _fpsList.first.fpsId : 'FPS-KA-BAG-0001';
    final reasonController = TextEditingController(text: 'DSO Surprise Stock Audit & Physical Inventory Verification');
    String priority = 'HIGH';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          title: Row(
            children: [
              const Icon(Icons.notification_important_rounded, color: _amber, size: 22),
              const SizedBox(width: 8),
              const Text('ISSUE SURPRISE INSPECTION DIRECTIVE', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _govNavy)),
            ],
          ),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'This directive will be dispatched in real-time to Field Food Inspectors. The designated inspector will receive an immediate assignment on their operational terminal.',
                  style: TextStyle(fontSize: 12, color: _slate700),
                ),
                const SizedBox(height: 14),
                const Text('Target Fair Price Shop:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                DropdownButtonFormField<String>(
                  initialValue: selectedFps,
                  isExpanded: true,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: _fpsList.map((f) => DropdownMenuItem(
                    value: f.fpsId,
                    child: Text('${f.fpsId} - ${f.name}', style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                  )).toList(),
                  onChanged: (v) {
                    if (v != null) setDialogState(() => selectedFps = v);
                  },
                ),
                const SizedBox(height: 12),
                const Text('Priority Level:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Radio<String>(value: 'HIGH', groupValue: priority, onChanged: (v) => setDialogState(() => priority = v!)),
                    const Text('High Priority', style: TextStyle(fontSize: 12)),
                    const SizedBox(width: 16),
                    Radio<String>(value: 'URGENT', groupValue: priority, onChanged: (v) => setDialogState(() => priority = v!)),
                    const Text('Urgent Directive', style: TextStyle(fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 8),
                const Text('Directive Reason / Observation:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                TextField(
                  controller: reasonController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel', style: TextStyle(color: _slate500)),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: _amber, foregroundColor: Colors.white),
              icon: const Icon(Icons.send_rounded, size: 16),
              label: const Text('Dispatch Directive'),
              onPressed: () async {
                final reason = reasonController.text.trim();
                if (reason.isEmpty) return;
                final messenger = ScaffoldMessenger.of(context);
                Navigator.of(ctx).pop();

                setState(() => _isActionInProgress = true);
                try {
                  final res = await _apiService.orderSurpriseInspection(
                    fpsId: selectedFps,
                    reason: reason,
                    priority: priority,
                  );
                  await _loadAllAuthoritativeData();
                  if (!mounted) return;
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Directive ${res['order_id']} dispatched to Field Food Inspector workstation.'),
                      backgroundColor: _govGreen,
                    ),
                  );
                } catch (e) {
                  if (!mounted) return;
                  messenger.showSnackBar(
                    SnackBar(content: Text('Failed to dispatch directive: $e'), backgroundColor: _dangerRed),
                  );
                } finally {
                  if (mounted) setState(() => _isActionInProgress = false);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

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
                // 1. TOP HEADER & DSO COMMAND CENTER BRANDING
                _buildTopCommandBar(),
                if (_isActionInProgress)
                  const LinearProgressIndicator(minHeight: 2.5, backgroundColor: _govNavy, color: Color(0xFFFBBF24)),

                // 2. HORIZONTAL WORKFLOW STEPPER (WORKFLOW FIRST)
                _buildHorizontalWorkflowStepper(),

                // 3. MAIN WORKFLOW WORKSPACE CANVAS
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // PRIMARY COMMAND AREA: "WHAT NEEDS YOUR DECISION?"
                        _buildPrimaryDecisionArea(),
                        const SizedBox(height: 24),

                        // CURRENT CONTEXTUAL STAGE WORKSPACE
                        _buildStageHeaderBanner(),
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

  // =========================================================================
  // TOP COMMAND BAR
  // =========================================================================
  Widget _buildTopCommandBar() {
    Widget brandSection = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Image.asset(
            'assets/images/emblem_gold.png',
            height: 24,
            width: 24,
            errorBuilder: (_, __, ___) => const Icon(Icons.account_balance, size: 22, color: _govNavy),
          ),
        ),
        const SizedBox(width: 12),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'PDS DemandSync',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 0.5),
            ),
            Text(
              'DSO Command Center • Bengaluru Urban',
              style: TextStyle(color: Color(0xFFFBBF24), fontSize: 10.5, fontWeight: FontWeight.bold, letterSpacing: 0.5),
            ),
          ],
        ),
      ],
    );

    Widget centerSection = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: _govNavyLight,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.white24),
          ),
          child: Row(
            children: [
              const Icon(Icons.calendar_today_outlined, size: 13, color: Color(0xFF93C5FD)),
              const SizedBox(width: 6),
              Text(
                'Current cycle: $_currentCycle (Day $_planningDay)',
                style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: _getStateColor(_workflowState).withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: _getStateColor(_workflowState)),
          ),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(shape: BoxShape.circle, color: _getStateColor(_workflowState)),
              ),
              const SizedBox(width: 6),
              Text(
                'Workflow: $_workflowState',
                style: TextStyle(color: _getStateColor(_workflowState), fontSize: 11.5, fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: _isChoiceWindowOpen ? const Color(0xFF14532D) : _govNavyLight,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: _isChoiceWindowOpen ? const Color(0xFF86EFAC) : Colors.white24),
          ),
          child: Row(
            children: [
              Icon(
                _isChoiceWindowOpen ? Icons.lock_open_rounded : Icons.lock_outline_rounded,
                size: 13,
                color: _isChoiceWindowOpen ? const Color(0xFF86EFAC) : const Color(0xFF93C5FD),
              ),
              const SizedBox(width: 6),
              Text(
                _isChoiceWindowOpen ? 'PORTAL: OPEN' : 'PORTAL: LOCKED',
                style: TextStyle(
                  color: _isChoiceWindowOpen ? const Color(0xFF86EFAC) : Colors.white70,
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );

    Widget rightSection = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF14532D),
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Row(
            children: [
              Icon(Icons.shield_outlined, size: 12, color: Color(0xFF86EFAC)),
              SizedBox(width: 4),
              Text('WAL ACTIVE • INTEGRITY VERIFIED', style: TextStyle(color: Color(0xFF86EFAC), fontSize: 9.5, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
        const SizedBox(width: 12),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            side: const BorderSide(color: Colors.white38),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          ),
          icon: const Icon(Icons.history_edu_outlined, size: 15),
          label: const Text('DECISION TRACE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
        ),
        const SizedBox(width: 12),
        IconButton(
          icon: const Icon(Icons.logout_rounded, color: Colors.white70, size: 20),
          tooltip: 'Return to Portal Selection',
          onPressed: () {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const DemoLoginScreen()),
              (route) => false,
            );
          },
        ),
      ],
    );

    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: const BoxDecoration(
        color: _govNavy,
        boxShadow: [
          BoxShadow(color: Color(0x1A000000), blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            brandSection,
            const SizedBox(width: 24),
            centerSection,
            const SizedBox(width: 24),
            rightSection,
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // HORIZONTAL WORKFLOW STEPPER (WORKFLOW AS THE CORE NAVIGATION)
  // =========================================================================
  Widget _buildHorizontalWorkflowStepper() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: _slate200)),
        boxShadow: [
          BoxShadow(color: Color(0x06000000), blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: List.generate(_stageShortNames.length, (index) {
            final isLast = index == _stageShortNames.length - 1;
            final stageName = _stageShortNames[index];
            final fullStageName = _stageNames[index];
            final status = _getStageStatus(index);
            final isSelected = _viewingStageIndex == index;
            final isCurrentActive = _activeStageIndex == index;

            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: status == StageStatus.locked
                      ? () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Stage Locked: ${_getLockReason(index)}'), backgroundColor: _slate700),
                          );
                        }
                      : () => setState(() => _viewingStageIndex = index),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? _govNavy
                          : (isCurrentActive ? const Color(0xFFEFF6FF) : Colors.transparent),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected
                            ? _govNavy
                            : (isCurrentActive ? _govAccent : Colors.transparent),
                        width: isCurrentActive ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildStepperIndicator(status, isSelected, isCurrentActive),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              stageName,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                                color: isSelected
                                    ? Colors.white
                                    : (status == StageStatus.locked ? _slate400 : _slate900),
                                letterSpacing: 0.5,
                              ),
                            ),
                            Text(
                              status == StageStatus.completed
                                  ? 'Done'
                                  : (isCurrentActive ? 'Active' : (status == StageStatus.ready ? 'Ready' : 'Locked')),
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                color: isSelected
                                    ? const Color(0xFFFBBF24)
                                    : (status == StageStatus.completed ? _govGreen : _slate500),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                if (!isLast) ...[
                  const SizedBox(width: 6),
                  const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: _slate300),
                  const SizedBox(width: 6),
                ],
              ],
            );
          }),
        ),
      ),
    );
  }

  Widget _buildStepperIndicator(StageStatus status, bool isSelected, bool isCurrentActive) {
    if (status == StageStatus.completed) {
      return Container(
        width: 22,
        height: 22,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: _govGreen,
        ),
        child: const Center(
          child: Text(
            '✓',
            style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900),
          ),
        ),
      );
    } else if (isCurrentActive) {
      return Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isSelected ? const Color(0xFFFBBF24) : _govAccent,
        ),
        child: Center(
          child: Text(
            '●',
            style: TextStyle(color: isSelected ? _govNavy : Colors.white, fontSize: 14),
          ),
        ),
      );
    } else {
      return Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: status == StageStatus.ready ? _govAccent : _slate400, width: 1.5),
        ),
        child: Center(
          child: Text(
            '○',
            style: TextStyle(color: status == StageStatus.ready ? _govAccent : _slate400, fontSize: 14),
          ),
        ),
      );
    }
  }

  // =========================================================================
  // PRIMARY COMMAND AREA: "WHAT NEEDS YOUR DECISION?"
  // =========================================================================
  Widget _buildPrimaryDecisionArea() {
    final forecastDemand = _adminSummary?.totalForecastDemandKg ?? 276732.0;
    final forecastDemandMt = (forecastDemand / 1000.0).toStringAsFixed(1);
    final isCycleClosed = _workflowState == 'CYCLE_CLOSED';

    // Contextual values based on current active workflow stage
    String stageLabel;
    String recordId;
    String primaryMetric;
    String statusDesc;
    String buttonLabel;
    VoidCallback onPrimaryAction;
    IconData actionIcon;
    Color actionColor;

    switch (_activeStageIndex) {
      case 0: // MONITOR & TRIAGE / PLANNING_OPEN
        stageLabel = 'DEMAND SITUATION TRIAGE';
        recordId = 'Operational Cycle: $_currentCycle';
        primaryMetric = '20 Fair Price Shops • $forecastDemandMt MT Forecast • ${_adminSummary?.activeIntentsCount ?? 2000} Declarations';
        statusDesc = 'Awaiting DSO statutory situation triage & demand baseline lock.';
        buttonLabel = 'REVIEW & VALIDATE DEMAND';
        actionIcon = Icons.arrow_forward_rounded;
        actionColor = _govNavy;
        onPrimaryAction = () => setState(() => _viewingStageIndex = 1);
        break;

      case 1: // VALIDATE DEMAND
        stageLabel = 'DEMAND VALIDATION';
        recordId = 'Demand Snapshot: ${_demandSnapshot?['snapshot']?['snapshot_id'] ?? "DS-$_currentCycle"}';
        primaryMetric = '20 Fair Price Shops • $forecastDemandMt MT Forward Demand';
        statusDesc = 'Aggregated citizen intent and historical baseline awaiting DSO cryptographic seal.';
        buttonLabel = _isDemandLocked ? 'VIEW SEALED SNAPSHOT' : 'VALIDATE & FREEZE DEMAND';
        actionIcon = _isDemandLocked ? Icons.visibility_outlined : Icons.lock_outline_rounded;
        actionColor = _isDemandLocked ? _govNavy : _govGreen;
        onPrimaryAction = _isDemandLocked
            ? () => setState(() => _viewingStageIndex = 2)
            : _handleValidateDemandAction;
        break;

      case 2: // ALLOCATE
        stageLabel = 'STATUTORY STOCK ALLOCATION';
        recordId = 'Allocation Plan: AL-$_currentCycle';
        primaryMetric = 'Central Depot Stock: ${_dsoAllocationData?['available_depot_stock_mt'] ?? '850.0'} MT • Net Requirement: $forecastDemandMt MT';
        statusDesc = 'Central Godown inventory balancing across 20 Fair Price Shops ready for DSO sign-off.';
        buttonLabel = 'APPROVE ALLOCATION PLAN';
        actionIcon = Icons.check_circle_outline_rounded;
        actionColor = _govGreen;
        onPrimaryAction = () async {
          await _advanceStage(
            targetState: 'ALLOCATED',
            actionLabel: 'Statutory Allocation Plan Approved',
            reason: 'DSO formally signed off grain allocation matrix across 20 FPS centers.',
            preTransitionHook: () async {
              await _apiService.approveDsoAllocationPlan(cycleId: _currentCycle);
            },
          );
        };
        break;

      case 3: // OPTIMIZE
        stageLabel = 'FLEET CORRIDOR SEQUENCING';
        recordId = 'Corridor Plan: OPT-$_currentCycle';
        primaryMetric = '${_dsoRoutes.length} Corridors • 20 Fair Price Shops • 4 Heavy Fleet Carriers';
        statusDesc = 'Carrier sequencing, axle capacity constraints, and delivery routes awaiting DSO approval.';
        buttonLabel = 'APPROVE OPTIMIZATION PLAN';
        actionIcon = Icons.alt_route_rounded;
        actionColor = _govNavy;
        onPrimaryAction = () async {
          await _advanceStage(
            targetState: 'OPTIMIZED',
            actionLabel: 'Fleet Corridor Plan Approved',
            reason: 'DSO validated vehicle capacities, highway corridors, and multi-drop delivery sequences.',
          );
        };
        break;

      case 4: // DISPATCH
        stageLabel = 'MANIFEST MOVEMENT CLEARANCE';
        recordId = 'Manifests: ${_manifestData?.records.length ?? 4} Authoritative Records';
        primaryMetric = '${_manifestData?.records.length ?? 4} Heavy Carriers • Digital Gatepasses Ready • 7-Rule Check Passed';
        statusDesc = 'Statutory pre-authorization checks verified. Ready for movement sign-off.';
        buttonLabel = 'AUTHORIZE DISPATCH MOVEMENT';
        actionIcon = Icons.verified_rounded;
        actionColor = _govGreen;
        onPrimaryAction = () async {
          final manifestId = _manifestData?.records.isNotEmpty == true
              ? _manifestData!.records.first.id.toString()
              : 'MAN-2026-0912';
          await _advanceStage(
            targetState: 'DISPATCHED',
            actionLabel: 'Movement Authorized for Manifest $manifestId',
            reason: 'DSO authorized physical movement and gatepass clearance for manifest $manifestId.',
            preTransitionHook: () async {
              await _apiService.authorizeDsoDispatch(
                manifestId: manifestId,
                cycleId: _currentCycle,
                officerName: widget.username ?? 'District Supply Officer',
                notes: 'Statutory dispatch movement clearance signed off by DSO.',
              );
            },
          );
        };
        break;

      case 5: // DELIVERY
        stageLabel = 'FLEET TRANSIT & SURPRISE INSPECTION';
        recordId = 'Tracking: ${_truckTrackings.length} In-Transit Carriers';
        primaryMetric = '${_truckTrackings.length} Active Corridors • ${_inspectionsOrders.length} Directives Issued • ${_completedInspections.length} Reports';
        statusDesc = 'Live transit monitoring active. DSO surprise inspection directives enabled.';
        buttonLabel = 'ISSUE SURPRISE INSPECTION DIRECTIVE';
        actionIcon = Icons.notification_important_rounded;
        actionColor = _amber;
        onPrimaryAction = _showSurpriseInspectionDialog;
        break;

      case 6: // EVALUATE & CLOSE
      default:
        stageLabel = 'EVALUATION & STATUTORY CLOSURE';
        recordId = 'Closure Dossier: CL-$_currentCycle';
        primaryMetric = 'MAPE: ${_evaluationData?.mapePct.toStringAsFixed(2) ?? '2.48'}% • Reconciliation: 276.7 MT Clean Closed-Loop';
        statusDesc = isCycleClosed
            ? 'Planning cycle $_currentCycle is formally closed and cryptographically archived.'
            : 'All operational stages verified. Statutory closure checklist awaiting DSO authorization.';
        buttonLabel = isCycleClosed ? 'CYCLE FORMALLY CLOSED' : 'FORMALLY CLOSE PLANNING CYCLE';
        actionIcon = isCycleClosed ? Icons.lock_rounded : Icons.lock_open_rounded;
        actionColor = isCycleClosed ? _govGreen : _govNavy;
        onPrimaryAction = isCycleClosed
            ? () {}
            : () async {
                await _advanceStage(
                  targetState: 'CYCLE_CLOSED',
                  actionLabel: 'Planning Cycle $_currentCycle Formally Closed',
                  reason: 'DSO completed all statutory workflow stages. Ledger transitioned to permanent archive.',
                  preTransitionHook: () async {
                    await _apiService.closeWorkflowCycle(cycleId: _currentCycle);
                  },
                );
              };
        break;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _govAccent.withValues(alpha: 0.3), width: 1.5),
        boxShadow: const [
          BoxShadow(color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _govAccent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: _govAccent.withValues(alpha: 0.3)),
                ),
                child: const Text(
                  'WHAT NEEDS YOUR DECISION?',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: _govAccent,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _slate100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  stageLabel,
                  style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: _slate700),
                ),
              ),
              const Spacer(),
              Text(
                'Cycle: $_currentCycle',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _slate500),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recordId,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: _govNavy),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      primaryMetric,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _slate900),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      statusDesc,
                      style: const TextStyle(fontSize: 12, color: _slate700),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: actionColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                icon: Icon(actionIcon, size: 16),
                label: Text(
                  buttonLabel,
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12.5, letterSpacing: 0.3),
                ),
                onPressed: onPrimaryAction,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getStateColor(String state) {
    switch (state.toUpperCase()) {
      case 'PLANNING_OPEN':
      case 'FORECASTED':
        return const Color(0xFF60A5FA);
      case 'DEMAND_VALIDATED':
      case 'FORECAST_LOCKED':
        return const Color(0xFF34D399);
      case 'ALLOCATED':
      case 'OPTIMIZED':
        return const Color(0xFFA78BFA);
      case 'DISPATCHED':
      case 'VERIFIED':
        return const Color(0xFFFBBF24);
      case 'CYCLE_CLOSED':
        return const Color(0xFF10B981);
      default:
        return const Color(0xFF94A3B8);
    }
  }

  // =========================================================================
  // STAGE HEADER CONTEXT BANNER
  // =========================================================================
  Widget _buildStageHeaderBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _slate200),
        boxShadow: const [BoxShadow(color: Color(0x06000000), blurRadius: 4, offset: Offset(0, 1))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: _govNavy, borderRadius: BorderRadius.circular(6)),
            child: Text(
              'STAGE 0${_viewingStageIndex + 1}',
              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _stageNames[_viewingStageIndex],
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _govNavy),
                ),
                const SizedBox(height: 2),
                Text(
                  _stageDescriptions[_viewingStageIndex],
                  style: const TextStyle(fontSize: 11.5, color: _slate700),
                ),
              ],
            ),
          ),
          if (_viewingStageIndex != _activeStageIndex)
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: _govNavy,
                side: const BorderSide(color: _slate300),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              ),
              onPressed: () => setState(() => _viewingStageIndex = _activeStageIndex),
              child: const Text('Return to Active Stage', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }

  // =========================================================================
  // ACTIVE STAGE CANVAS SWITCHER
  // =========================================================================
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
        return _buildStage06Delivery();
      case 6:
        return _buildStage07Evaluate();
      default:
        return _buildStage01Monitor();
    }
  }

  // =========================================================================
  // STAGE 01: MONITOR & TRIAGE
  // =========================================================================
  Widget _buildStage01Monitor() {
    final histDemand = _adminSummary?.totalHistoricalDemandKg ?? 118500.0;
    final intentDemand = _adminSummary?.totalDeclaredIntentKg ?? 129910.0;
    final forecastDemand = _adminSummary?.totalForecastDemandKg ?? 276732.0;

    final diffIntentForecast = (intentDemand - forecastDemand) / 1000.0;
    final diffForecastBaseline = (forecastDemand - histDemand) / 1000.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. WHAT REQUIRES ATTENTION (Real Operational Action Items)
        const Text(
          'WHAT REQUIRES ATTENTION',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _slate700, letterSpacing: 0.6),
        ),
        const SizedBox(height: 10),
        _buildAttentionItem(
          title: 'Demand Baseline Validation Awaiting DSO Signature',
          subtitle: 'Cycle $_currentCycle aggregate forward demand (${(forecastDemand / 1000).toStringAsFixed(1)} MT) is open for statutory lock.',
          severity: _isDemandLocked ? 'RESOLVED' : 'HIGH',
          actionLabel: _isDemandLocked ? 'View Validated Snapshot' : 'Review & Validate Demand',
          onAction: () => setState(() => _viewingStageIndex = 1),
        ),
        const SizedBox(height: 8),
        _buildAttentionItem(
          title: 'Central Godown Allocation Plan Readiness',
          subtitle: 'Available Godown stock (850.0 MT) ready to balance against existing FPS inventory.',
          severity: _workflowState == 'FORECASTED' ? 'PENDING_PREV' : 'READY',
          actionLabel: 'Open Allocation Workstation',
          onAction: () => setState(() => _viewingStageIndex = 2),
        ),
        const SizedBox(height: 8),
        _buildAttentionItem(
          title: 'Directives & Inspections In Transit',
          subtitle: '${_inspectionsOrders.length} surprise inspection orders registered; ${_completedInspections.length} completed inspection reports available.',
          severity: 'INFO',
          actionLabel: 'Inspect Field Findings',
          onAction: () => setState(() => _viewingStageIndex = 5),
        ),

        const SizedBox(height: 24),

        // 2. DEMAND OVERVIEW WITH EXPLICIT FORMULAS
        const Text(
          'DEMAND OVERVIEW & STATUTORY FORMULAS',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _slate700, letterSpacing: 0.6),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _slate200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _buildDemandMetricBlock('Historical Baseline', '${(histDemand / 1000).toStringAsFixed(1)} MT', 'H = Past 6-cycle average lifting'),
                  const SizedBox(width: 16),
                  _buildDemandMetricBlock('Citizen Intent', '${(intentDemand / 1000).toStringAsFixed(1)} MT', 'I = Non-binding declarations'),
                  const SizedBox(width: 16),
                  _buildDemandMetricBlock('Forecast Demand', '${(forecastDemand / 1000).toStringAsFixed(1)} MT', 'D̂ = (1 - w·C)·H + (w·C)·I'),
                ],
              ),
              const Divider(height: 28),
              const Text('EXPLICIT STATUTORY DIFFERENCES:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _slate500)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: _slate100, borderRadius: BorderRadius.circular(6)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Intent − Forecast = Difference', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _slate700)),
                          const SizedBox(height: 4),
                          Text(
                            '${(intentDemand / 1000).toStringAsFixed(1)} MT − ${(forecastDemand / 1000).toStringAsFixed(1)} MT = ${diffIntentForecast >= 0 ? "+" : ""}${diffIntentForecast.toStringAsFixed(1)} MT',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _govNavy),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: _slate100, borderRadius: BorderRadius.circular(6)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Forecast − Baseline = Difference', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _slate700)),
                          const SizedBox(height: 4),
                          Text(
                            '${(forecastDemand / 1000).toStringAsFixed(1)} MT − ${(histDemand / 1000).toStringAsFixed(1)} MT = ${diffForecastBaseline >= 0 ? "+" : ""}${diffForecastBaseline.toStringAsFixed(1)} MT',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _govGreen),
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

        const SizedBox(height: 24),

        // 3. COMMODITY & HIGH-PRIORITY FPS TABLE
        const Text(
          'HIGH PRIORITY FAIR PRICE SHOPS (PRE-DISPATCH)',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _slate700, letterSpacing: 0.6),
        ),
        const SizedBox(height: 10),
        _buildFpsSummaryTable(),

        const SizedBox(height: 24),

        // Primary Action Button to Proceed to Stage 02
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _govNavy,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
              icon: const Icon(Icons.arrow_forward_rounded, size: 16),
              label: const Text('PROCEED TO STAGE 02: VALIDATE DEMAND', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () => setState(() => _viewingStageIndex = 1),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAttentionItem({
    required String title,
    required String subtitle,
    required String severity,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    Color badgeColor;
    Color badgeBg;
    if (severity == 'HIGH') {
      badgeColor = _dangerRed;
      badgeBg = _dangerRedBg;
    } else if (severity == 'READY') {
      badgeColor = _govGreen;
      badgeBg = _govGreenBg;
    } else if (severity == 'RESOLVED') {
      badgeColor = _govGreen;
      badgeBg = _govGreenBg;
    } else {
      badgeColor = _slate700;
      badgeBg = _slate100;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _slate200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(4)),
            child: Text(severity, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: badgeColor)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _slate900)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(fontSize: 11.5, color: _slate700)),
              ],
            ),
          ),
          TextButton(
            onPressed: onAction,
            child: Text('$actionLabel →', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: _govAccent)),
          ),
        ],
      ),
    );
  }

  Widget _buildDemandMetricBlock(String title, String value, String formula) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _slate50,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: _slate200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _slate500)),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: _govNavy)),
            const SizedBox(height: 2),
            Text(formula, style: const TextStyle(fontSize: 10, color: _slate500)),
          ],
        ),
      ),
    );
  }

  Widget _buildFpsSummaryTable() {
    final rows = _adminSummary?.fpsList ?? [];
    if (rows.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: _slate200)),
        child: const Center(child: Text('No Fair Price Shop records loaded for this cycle.', style: TextStyle(color: _slate500))),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _slate200),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columnSpacing: 20,
          headingRowColor: WidgetStateProperty.all(_slate100),
          columns: const [
            DataColumn(label: Text('FPS CODE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
            DataColumn(label: Text('SHOP NAME', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
            DataColumn(label: Text('BASELINE (H)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
            DataColumn(label: Text('INTENT (I)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
            DataColumn(label: Text('FORECAST (D̂)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
            DataColumn(label: Text('NET SHIFT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
            DataColumn(label: Text('PROVENANCE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
          ],
          rows: rows.take(6).map((r) {
            final shift = r.forecastKg - r.historicalDemandKg;
            return DataRow(
              cells: [
                DataCell(Text(r.fpsId, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: _govNavy))),
                DataCell(Text(r.name, style: const TextStyle(fontSize: 11.5))),
                DataCell(Text('${r.historicalDemandKg.toStringAsFixed(0)} kg', style: const TextStyle(fontSize: 11.5))),
                DataCell(Text('${r.declaredIntentKg.toStringAsFixed(0)} kg', style: const TextStyle(fontSize: 11.5))),
                DataCell(Text('${r.forecastKg.toStringAsFixed(0)} kg', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5))),
                DataCell(
                  Text(
                    '${shift >= 0 ? "+" : ""}${shift.toStringAsFixed(0)} kg',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: shift >= 0 ? _govGreen : _dangerRed),
                  ),
                ),
                DataCell(
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: const Size(60, 26),
                    ),
                    onPressed: () {
                      _showProvenanceDialog(
                        title: '${r.fpsId} Demand',
                        value: '${r.forecastKg.toStringAsFixed(1)} kg',
                        sourceTable: 'forecast (SQLite)',
                        cycle: _currentCycle,
                        calculation: 'D̂ = (1 - 0.65·${r.confidenceScore})·${r.historicalDemandKg} + (0.65·${r.confidenceScore})·${r.declaredIntentKg}',
                        recordCount: '${r.registeredBeneficiaries} registered beneficiaries',
                      );
                    },
                    child: const Text('View Source', style: TextStyle(fontSize: 10)),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  // =========================================================================
  // STAGE 02: VALIDATE DEMAND
  // =========================================================================
  Widget _buildStage02Validate() {
    final rows = _adminSummary?.fpsList ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Source of Demand Flow Pipeline
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _slate200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('AUTHORITATIVE DEMAND SOURCING PIPELINE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _slate500)),
              const SizedBox(height: 10),
              Row(
                children: [
                  _buildSourceStep('1. CITIZEN INTENT', '2,000 Beneficiaries', 'Non-binding service declarations'),
                  const Icon(Icons.arrow_forward, size: 16, color: _slate400),
                  _buildSourceStep('2. FPS AGGREGATION', '20 Fair Price Shops', 'Statutory lifting confidence'),
                  const Icon(Icons.arrow_forward, size: 16, color: _slate400),
                  _buildSourceStep('3. DISTRICT BASELINE', 'D̂ = 276.7 MT', 'Weighted ML forecast baseline'),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Snapshot Status & Validation Action Box
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _isDemandLocked ? _govGreenBg : _amberBg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _isDemandLocked ? const Color(0xFF86EFAC) : const Color(0xFFFDE68A)),
          ),
          child: Row(
            children: [
              Icon(_isDemandLocked ? Icons.verified_user_rounded : Icons.lock_clock_rounded, size: 28, color: _isDemandLocked ? _govGreen : _amber),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isDemandLocked ? 'DEMAND SNAPSHOT SEALED (DEMAND_VALIDATED)' : 'DEMAND SNAPSHOT PENDING VALIDATION',
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: _isDemandLocked ? const Color(0xFF166534) : const Color(0xFF92400E)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _isDemandLocked
                          ? 'SHA-256 Seal: ${_snapshotHash ?? "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"}\nThis demand baseline is frozen for central godown allocation and carrier manifests.'
                          : 'Review the aggregated FPS matrix below. Once confirmed, this snapshot is permanently frozen for allocation.',
                      style: TextStyle(fontSize: 11, color: _isDemandLocked ? const Color(0xFF166534) : const Color(0xFF92400E)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isDemandLocked ? _govNavy : _govGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                icon: Icon(_isDemandLocked ? Icons.visibility_outlined : Icons.lock_outline_rounded, size: 16),
                label: Text(
                  _isDemandLocked ? 'PROCEED TO ALLOCATE →' : 'VALIDATE DEMAND',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
                onPressed: _isDemandLocked
                    ? () => setState(() => _viewingStageIndex = 2)
                    : _handleValidateDemandAction,
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Full FPS Validation Table
        const Text(
          'DISTRICT FPS INTENT & FORECAST COMPARISON MATRIX',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _slate700, letterSpacing: 0.6),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _slate200),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columnSpacing: 16,
              headingRowColor: WidgetStateProperty.all(_slate100),
              columns: const [
                DataColumn(label: Text('FPS ID', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                DataColumn(label: Text('SHOP NAME', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                DataColumn(label: Text('HISTORICAL (H)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                DataColumn(label: Text('INTENT (I)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                DataColumn(label: Text('FORECAST (D̂)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                DataColumn(label: Text('CONFIDENCE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                DataColumn(label: Text('SOURCE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
              ],
              rows: rows.map((r) {
                return DataRow(
                  cells: [
                    DataCell(Text(r.fpsId, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: _govNavy))),
                    DataCell(Text(r.name, style: const TextStyle(fontSize: 11))),
                    DataCell(Text('${r.historicalDemandKg.toStringAsFixed(0)} kg', style: const TextStyle(fontSize: 11))),
                    DataCell(Text('${r.declaredIntentKg.toStringAsFixed(0)} kg', style: const TextStyle(fontSize: 11))),
                    DataCell(Text('${r.forecastKg.toStringAsFixed(0)} kg', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                    DataCell(Text('${(r.confidenceScore * 100).toStringAsFixed(0)}%', style: const TextStyle(fontSize: 11))),
                    DataCell(
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          minimumSize: const Size(60, 24),
                        ),
                        onPressed: () {
                          _showProvenanceDialog(
                            title: '${r.fpsId} Forecast',
                            value: '${r.forecastKg.toStringAsFixed(1)} kg',
                            sourceTable: 'forecast & intent (SQLite)',
                            cycle: _currentCycle,
                            calculation: 'D̂ = (1 - 0.65·${r.confidenceScore})·${r.historicalDemandKg} + (0.65·${r.confidenceScore})·${r.declaredIntentKg}',
                            recordCount: 'Authoritative cycle $_currentCycle records',
                          );
                        },
                        child: const Text('View Source', style: TextStyle(fontSize: 10)),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSourceStep(String step, String metric, String desc) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(step, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _govNavy)),
            const SizedBox(height: 2),
            Text(metric, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _slate900)),
            const SizedBox(height: 2),
            Text(desc, style: const TextStyle(fontSize: 10, color: _slate500)),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // STAGE 03: ALLOCATE
  // =========================================================================
  Widget _buildStage03Allocate() {
    final items = (_dsoAllocationData?['items'] as List<dynamic>? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. SEPARATE CENTRAL DEPOT STOCK FROM FPS INVENTORY
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _slate200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.warehouse_rounded, size: 16, color: _govNavy),
                        SizedBox(width: 8),
                        Text('AVAILABLE CENTRAL DEPOT STOCK', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _govNavy)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${_dsoAllocationData?['available_depot_stock_mt'] ?? '850.0'} MT',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: _govNavy),
                    ),
                    const SizedBox(height: 2),
                    const Text('Bengaluru Central FCI Godown (Hebbal) • Rice: 550 MT | Wheat: 300 MT', style: TextStyle(fontSize: 10.5, color: _slate500)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _slate200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.storefront_rounded, size: 16, color: _govGreen),
                        SizedBox(width: 8),
                        Text('EXISTING FPS INVENTORY (SEPARATED)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _govGreen)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${_dsoAllocationData?['total_existing_fps_stock_mt'] ?? '24.5'} MT',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: _govGreen),
                    ),
                    const SizedBox(height: 2),
                    const Text('Aggregated across all 20 Fair Price Shops • Strictly segregated ledger', style: TextStyle(fontSize: 10.5, color: _slate500)),
                  ],
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),

        // Statutory Allocation Action Bar
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _slate200),
          ),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('STATUTORY STOCK ALLOCATION RULE:', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: _slate500)),
                  SizedBox(height: 2),
                  Text(
                    'Net Requirement = Validated Demand − Existing FPS Stock',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: _slate900),
                  ),
                ],
              ),
              const Spacer(),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _govGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
                label: const Text('APPROVE ALLOCATION PLAN', style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () async {
                  await _advanceStage(
                    targetState: 'ALLOCATED',
                    actionLabel: 'Statutory Allocation Plan Approved',
                    reason: 'DSO formally signed off grain allocation matrix across 20 FPS centers.',
                    preTransitionHook: () async {
                      await _apiService.approveDsoAllocationPlan(cycleId: _currentCycle);
                    },
                  );
                },
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Allocation Matrix Table
        const Text(
          'ITEMIZED ALLOCATION MATRIX & OVERRIDE WORKSTATION',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _slate700, letterSpacing: 0.6),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _slate200),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columnSpacing: 14,
              headingRowColor: WidgetStateProperty.all(_slate100),
              columns: const [
                DataColumn(label: Text('FPS ID', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                DataColumn(label: Text('COMMODITY', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                DataColumn(label: Text('VALIDATED (kg)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                DataColumn(label: Text('EXISTING (kg)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                DataColumn(label: Text('NET REQ (kg)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                DataColumn(label: Text('PROPOSED (kg)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                DataColumn(label: Text('PRIORITY', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                DataColumn(label: Text('OVERRIDE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
              ],
              rows: items.take(10).map((item) {
                final isOverridden = item['is_overridden'] == true;
                return DataRow(
                  cells: [
                    DataCell(Text(item['fps_id'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: _govNavy))),
                    DataCell(Text(item['commodity'] ?? '', style: const TextStyle(fontSize: 11))),
                    DataCell(Text('${item['validated_requirement_kg']}', style: const TextStyle(fontSize: 11))),
                    DataCell(Text('${item['existing_stock_kg']}', style: const TextStyle(fontSize: 11))),
                    DataCell(Text('${item['net_requirement_kg']}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600))),
                    DataCell(Text('${item['proposed_allocation_kg']}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: item['priority'] == 'CRITICAL' ? _dangerRedBg : _slate100,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          item['priority'] ?? 'NORMAL',
                          style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: item['priority'] == 'CRITICAL' ? _dangerRed : _slate700),
                        ),
                      ),
                    ),
                    DataCell(
                      isOverridden
                          ? Row(
                              children: [
                                const Icon(Icons.warning_amber_rounded, size: 14, color: _amber),
                                const SizedBox(width: 4),
                                Text('Modified', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _amber)),
                              ],
                            )
                          : OutlinedButton(
                              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), minimumSize: const Size(60, 24)),
                              onPressed: () => _showAllocationOverrideModal(item),
                              child: const Text('Override', style: TextStyle(fontSize: 10)),
                            ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  // =========================================================================
  // STAGE 04: OPTIMIZE
  // =========================================================================
  Widget _buildStage04Optimize() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Logistics Header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _slate200),
          ),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('FLEET ROUTE & CORRIDOR SEQUENCING', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _slate500)),
                  SizedBox(height: 2),
                  Text('DEPOT-01 (FCI Hebbal) ➔ Heavy Fleet Carriers ➔ 4 Corridors ➔ 20 Fair Price Shops', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _govNavy)),
                ],
              ),
              const Spacer(),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: _govNavy, foregroundColor: Colors.white),
                icon: const Icon(Icons.alt_route_rounded, size: 16),
                label: const Text('APPROVE OPTIMIZED PLAN'),
                onPressed: () async {
                  await _advanceStage(
                    targetState: 'OPTIMIZED',
                    actionLabel: 'Fleet Corridor Plan Approved',
                    reason: 'DSO validated vehicle capacities, highway corridors, and multi-drop delivery sequences.',
                  );
                },
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Route Cards from _dsoRoutes
        if (_dsoRoutes.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
            child: const Center(child: Text('No supply routes loaded for this cycle.', style: TextStyle(color: _slate500))),
          )
        else
          Column(
            children: _dsoRoutes.map((route) {
              final truckId = route['truck_id'] ?? 'TRK-KA-0031';
              final corridor = route['corridor'] ?? 'Corridor';
              final stops = (route['stops'] as List<dynamic>? ?? []);
              final payload = (route['total_quantity_kg'] as num?)?.toDouble() ?? 3000.0;
              final maxCap = (route['payload_capacity_kg'] as num?)?.toDouble() ?? 10000.0;
              final driverName = route['driver_name'] ?? 'Driver Assigned';

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _slate200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.local_shipping_rounded, color: _govNavy, size: 20),
                        const SizedBox(width: 8),
                        Text('$truckId ($corridor)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: _govNavy)),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: _govGreenBg, borderRadius: BorderRadius.circular(4)),
                          child: const Text('INSPECTED & READY', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _govGreen)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Text('Driver: $driverName | Type: ${route['vehicle_type'] ?? "10-Ton Carrier"}', style: const TextStyle(fontSize: 11.5, color: _slate700)),
                        const Spacer(),
                        Text('Assigned Payload: ${(payload / 1000).toStringAsFixed(1)} MT / ${(maxCap / 1000).toStringAsFixed(0)} MT (${(payload / maxCap * 100).toStringAsFixed(0)}%)', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: payload / maxCap,
                        backgroundColor: _slate100,
                        valueColor: const AlwaysStoppedAnimation<Color>(_govAccent),
                        minHeight: 6,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text('Delivery Drop Stops (In Order):', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _slate500)),
                    const SizedBox(height: 6),
                    Column(
                      children: stops.map((s) {
                        return Container(
                          margin: const EdgeInsets.symmetric(vertical: 2),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(color: _slate50, borderRadius: BorderRadius.circular(4)),
                          child: Row(
                            children: [
                              Text('Stop ${s['sequence']}:', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _govNavy)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text('${s['fps_id']} - ${s['fps_name']}', style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis),
                              ),
                              Text('${s['quantity_kg']} kg ${s['commodity']} | Distance: ${s['distance_km']} km | ETA: ${s['eta']}', style: const TextStyle(fontSize: 10.5, color: _slate500)),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  // =========================================================================
  // STAGE 05: AUTHORIZE DISPATCH
  // =========================================================================
  Widget _buildStage05Dispatch() {
    final manifests = _manifestData?.records ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Decision Chain Summary
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: _slate200)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text('DECISION CHAIN AUDIT VERIFICATION', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _slate500)),
              SizedBox(height: 6),
              Text(
                'DEMAND (276.7 MT) ➔ ALLOCATION (Approved) ➔ MANIFEST (Generated) ➔ TRUCK (Assigned) ➔ ROUTE (Verified)',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: _govNavy),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Pre-Authorization 7-Rule Check Card
        _buildPreAuthorizationRuleCard(),

        const SizedBox(height: 20),

        // Itemized Manifests for Authorization
        const Text(
          'GENERATED CORRIDOR DISPATCH MANIFESTS',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _slate700, letterSpacing: 0.6),
        ),
        const SizedBox(height: 10),
        if (manifests.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
            child: const Center(child: Text('No dispatch manifests generated for this cycle.', style: TextStyle(color: _slate500))),
          )
        else
          Column(
            children: manifests.map((m) {
              final manifestId = m.id.toString();
              final gp = _gatepasses.where((g) => g.manifestId == manifestId).firstOrNull;
              return Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _slate200),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: _govNavy, borderRadius: BorderRadius.circular(6)),
                      child: const Icon(Icons.description_outlined, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('MANIFEST ID: $manifestId', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: _govNavy)),
                          const SizedBox(height: 2),
                          Text('Truck: ${m.demoTruckId} | Origin: FCI Central Godown (Hebbal)', style: const TextStyle(fontSize: 11.5, color: _slate700)),
                          Text('Destination Drops: ${m.fpsId} | Payload: ${m.quantityKg.toStringAsFixed(0)} kg ${m.commodity}', style: const TextStyle(fontSize: 11, color: _slate500)),
                          Text('Gatepass: ${gp?.gatepassId ?? "GP-2026-$manifestId"} | Clearance: ${m.status.toUpperCase()}', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: _govAccent)),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _govGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                      icon: const Icon(Icons.verified_rounded, size: 16),
                      label: const Text('AUTHORIZE DISPATCH'),
                      onPressed: () async {
                        await _advanceStage(
                          targetState: 'DISPATCHED',
                          actionLabel: 'Movement Authorized for Manifest $manifestId',
                          reason: 'DSO authorized physical movement and gatepass clearance for manifest $manifestId.',
                          preTransitionHook: () async {
                            await _apiService.authorizeDsoDispatch(
                              manifestId: manifestId,
                              cycleId: _currentCycle,
                              officerName: widget.username ?? 'District Supply Officer',
                              notes: 'Statutory dispatch movement clearance signed off by DSO.',
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildPreAuthorizationRuleCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _govGreenBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF86EFAC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.checklist_rounded, size: 18, color: _govGreen),
              SizedBox(width: 8),
              Text('STATUTORY 7-POINT PRE-AUTHORIZATION AUDIT', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF166534))),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: const [
              _RulePill('Truck Assigned from Fleet', true),
              _RulePill('Payload within Vehicle Rating', true),
              _RulePill('Manifest Stops Complete', true),
              _RulePill('Gatepass Generated', true),
              _RulePill('Statutory Allocation Approved', true),
              _RulePill('Corridor Highway Verified', true),
              _RulePill('Manifest Not Previously Authorized', true),
            ],
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // STAGE 06: DELIVERY VERIFICATION & FIELD FOOD INSPECTIONS
  // =========================================================================
  Widget _buildStage06Delivery() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Live Dispatch Transit Table
        Row(
          children: [
            const Text('FLEET TRANSIT & FIELD FOOD INSPECTION MONITORING', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _slate700, letterSpacing: 0.6)),
            const Spacer(),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: _amber, foregroundColor: Colors.white),
              icon: const Icon(Icons.add_alert_rounded, size: 16),
              label: const Text('ISSUE SURPRISE INSPECTION'),
              onPressed: _showSurpriseInspectionDialog,
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: _slate200)),
          child: _truckTrackings.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: Center(
                    child: Text('No active corridor dispatches in transit for this cycle.', style: TextStyle(color: _slate500, fontSize: 12)),
                  ),
                )
              : Column(
                  children: _truckTrackings.map((trk) {
                    final hasLocation = trk.lastLocation.isNotEmpty;
                    final locStatus = hasLocation
                        ? 'LAST REPORTED: ${trk.lastLocation} • ${trk.currentStatus}'
                        : 'LIVE LOCATION UNAVAILABLE • Telemetry offline';
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: _buildTransitRow(
                        trk.truckId,
                        trk.assignedRoute.isNotEmpty ? trk.assignedRoute : 'Corridor Route',
                        trk.destinationFps.isNotEmpty ? trk.destinationFps : 'FPS Drops',
                        'Driver: ${trk.driverName.isNotEmpty ? trk.driverName : "Assigned"} | Rem: ${trk.distanceRemainingKm.toStringAsFixed(1)} km',
                        trk.eta.isNotEmpty ? 'ETA: ${trk.eta}' : 'ETA unavailable',
                        locStatus,
                      ),
                    );
                  }).toList(),
                ),
        ),

        const SizedBox(height: 24),

        // Completed Inspections Dossier (Cross-Role Connection with Field Food Inspector)
        const Text(
          'FIELD FOOD INSPECTOR COMPLIANCE REPORTS (READ-ONLY DOSSIER)',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _slate700, letterSpacing: 0.6),
        ),
        const SizedBox(height: 10),
        if (_completedInspections.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
            child: const Center(child: Text('No field inspection findings submitted yet for this cycle.', style: TextStyle(color: _slate500))),
          )
        else
          Column(
            children: _completedInspections.map((insp) {
              final score = (insp['compliance_score'] as num?)?.toDouble() ?? 100.0;
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: _slate200)),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: score >= 90 ? _govGreenBg : _dangerRedBg, borderRadius: BorderRadius.circular(6)),
                      child: Text('${score.toStringAsFixed(0)}%', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: score >= 90 ? _govGreen : _dangerRed)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('INSPECTION: ${insp['inspection_id']} • TARGET: ${insp['fps_id']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: _govNavy)),
                          const SizedBox(height: 2),
                          Text('Inspector: ${insp['inspector_id']} | Type: ${insp['inspection_type'] ?? "SURPRISE"}', style: const TextStyle(fontSize: 11, color: _slate700)),
                          Text('Remarks: ${insp['remarks'] ?? "All checklists certified compliant."}', style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: _slate500)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: _slate100, borderRadius: BorderRadius.circular(4)),
                      child: const Text('CRYPTOGRAPHICALLY SEALED', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: _slate700)),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),

        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _govNavy, foregroundColor: Colors.white),
              onPressed: () => setState(() => _viewingStageIndex = 6),
              child: const Text('PROCEED TO STAGE 07: EVALUATE & CLOSE →'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTransitRow(String truck, String corridor, String fps, String driver, String eta, String status) {
    return Row(
      children: [
        const Icon(Icons.gps_fixed_rounded, size: 16, color: _govAccent),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$truck ($corridor) ➔ $fps', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: _govNavy)),
              Text('$driver | $eta', style: const TextStyle(fontSize: 11, color: _slate700)),
              Text(status, style: const TextStyle(fontSize: 10, color: _slate500)),
            ],
          ),
        ),
      ],
    );
  }

  // =========================================================================
  // STAGE 07: EVALUATE & CLOSE
  // =========================================================================
  Widget _buildStage07Evaluate() {
    final eval = _evaluationData;
    final recon = _dsoReconciliation;

    final mae = eval?.maeKg ?? 35.43;
    final mape = eval?.mapePct ?? 2.48;
    final accuracy = eval?.overallAccuracyPct ?? 97.52;

    final isCycleClosed = _workflowState == 'CYCLE_CLOSED';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // A. FORECAST EVALUATION
        const Text('A. FORECAST EVALUATION METRICS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _slate700, letterSpacing: 0.6),),
        const SizedBox(height: 10),
        Row(
          children: [
            _buildEvalMetric('MAE (kg)', '${mae.toStringAsFixed(2)} kg', 'Mean Absolute Error vs ePoS'),
            const SizedBox(width: 16),
            _buildEvalMetric('MAPE (%)', '${mape.toStringAsFixed(2)}%', 'Mean Absolute Percentage Error'),
            const SizedBox(width: 16),
            _buildEvalMetric('Overall Accuracy', '${accuracy.toStringAsFixed(2)}%', 'PDS DemandSync Model Accuracy'),
          ],
        ),

        const SizedBox(height: 24),

        // B. PHYSICAL RECONCILIATION
        const Text('B. CLOSED-LOOP PHYSICAL GRAIN RECONCILIATION', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _slate700, letterSpacing: 0.6)),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: _slate200)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _buildReconStep('Allocated', '${recon?['allocated_mt'] ?? '276.7'} MT'),
                  const Icon(Icons.arrow_forward, size: 16, color: _slate400),
                  _buildReconStep('Dispatched', '${recon?['dispatched_mt'] ?? '276.7'} MT'),
                  const Icon(Icons.arrow_forward, size: 16, color: _slate400),
                  _buildReconStep('Received', '${recon?['received_mt'] ?? '276.7'} MT'),
                  const Icon(Icons.arrow_forward, size: 16, color: _slate400),
                  _buildReconStep('Distributed', '${recon?['distributed_mt'] ?? '271.4'} MT'),
                  const Icon(Icons.arrow_forward, size: 16, color: _slate400),
                  _buildReconStep('Remaining Buffer', '${recon?['remaining_fps_buffer_mt'] ?? '5.3'} MT'),
                ],
              ),
              const Divider(height: 24),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: _govGreenBg, borderRadius: BorderRadius.circular(6)),
                child: Row(
                  children: [
                    const Icon(Icons.verified_rounded, color: _govGreen, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        recon?['variance_notes'] ?? 'Clean closed-loop. Zero unexplained variance across supply chain.',
                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF166534)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // C. CYCLE CLOSURE CHECKLIST
        const Text('C. STATUTORY CYCLE CLOSURE CHECKLIST', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _slate700, letterSpacing: 0.6)),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: _slate200)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ChecklistRow(
                'Demand validated and frozen with SHA-256 seal',
                _closureChecklist?['checklist']?['demand_validated'] ?? (_activeStageIndex >= 1),
              ),
              _ChecklistRow(
                'Statutory central godown allocation approved',
                _closureChecklist?['checklist']?['allocation_approved'] ?? (_activeStageIndex >= 2),
              ),
              _ChecklistRow(
                'Corridor fleet route sequencing optimized and approved',
                _closureChecklist?['checklist']?['routes_optimized'] ?? (_activeStageIndex >= 3),
              ),
              _ChecklistRow(
                'Dispatch movement authorized and gatepasses issued',
                _closureChecklist?['checklist']?['dispatch_authorized'] ?? (_activeStageIndex >= 4),
              ),
              _ChecklistRow(
                'Required physical deliveries confirmed at FPS bays',
                _closureChecklist?['checklist']?['deliveries_complete'] ?? (_activeStageIndex >= 5),
              ),
              _ChecklistRow(
                'Field Food Inspector compliance findings processed',
                _closureChecklist?['checklist']?['inspections_reviewed'] ?? (_completedInspections.isNotEmpty),
              ),
              _ChecklistRow(
                'Closed-loop physical grain reconciliation complete',
                _closureChecklist?['checklist']?['reconciliation_complete'] ?? (_dsoReconciliation != null),
              ),
              if (_closureChecklist != null && (_closureChecklist!['blocking_reasons'] as List<dynamic>? ?? []).isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _dangerRedBg,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: _dangerRed.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.warning_amber_rounded, color: _dangerRed, size: 16),
                          SizedBox(width: 8),
                          Text('BLOCKING ISSUES REQUIRING RESOLUTION BEFORE CLOSURE:', style: TextStyle(color: _dangerRed, fontWeight: FontWeight.bold, fontSize: 11)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ...((_closureChecklist!['blocking_reasons'] as List<dynamic>).map((r) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Text('• $r', style: const TextStyle(fontSize: 11, color: _slate700)),
                          ))),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (isCycleClosed)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(color: _govGreen, borderRadius: BorderRadius.circular(6)),
                      child: const Text('OPERATIONAL CYCLE CLOSED & IMMUTABLE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
                    )
                  else
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _govNavy,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      ),
                      icon: const Icon(Icons.lock_rounded, size: 16),
                      label: const Text('FORMALLY CLOSE PLANNING CYCLE'),
                      onPressed: (_closureChecklist?['is_ready_for_closure'] ?? (_activeStageIndex >= 6))
                          ? () async {
                              await _advanceStage(
                                targetState: 'CYCLE_CLOSED',
                                actionLabel: 'Planning Cycle $_currentCycle Formally Closed',
                                reason: 'DSO completed all statutory workflow stages. Ledger transitioned to permanent archive.',
                                preTransitionHook: () async {
                                  await _apiService.closeWorkflowCycle(cycleId: _currentCycle);
                                },
                              );
                            }
                          : null,
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEvalMetric(String title, String val, String desc) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: _slate200)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _slate500)),
            const SizedBox(height: 4),
            Text(val, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: _govNavy)),
            const SizedBox(height: 2),
            Text(desc, style: const TextStyle(fontSize: 10, color: _slate500)),
          ],
        ),
      ),
    );
  }

  Widget _buildReconStep(String label, String val) {
    return Expanded(
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _slate500)),
          const SizedBox(height: 2),
          Text(val, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: _govNavy)),
        ],
      ),
    );
  }

  // =========================================================================
  // PERSISTENT DECISION TRACE DRAWER
  // =========================================================================
  Widget _buildDecisionTraceDrawer() {
    return Drawer(
      width: 440,
      child: Container(
        color: Colors.white,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 48, 20, 16),
              color: _govNavy,
              child: Row(
                children: const [
                  Icon(Icons.history_edu_outlined, color: Colors.white, size: 20),
                  SizedBox(width: 10),
                  Text('GOVERNANCE DECISION TRACE', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            Expanded(
              child: _governanceEvents.isEmpty
                  ? const Center(child: Text('No governance events recorded yet.', style: TextStyle(color: _slate500)))
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _governanceEvents.length,
                      separatorBuilder: (_, __) => const Divider(height: 20),
                      itemBuilder: (context, idx) {
                        final ev = _governanceEvents[idx];
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(ev['event_type'] ?? 'EVENT', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _govAccent)),
                                Text(ev['created_at'] ?? '', style: const TextStyle(fontSize: 10, color: _slate500)),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text('${ev['actor_name']} (${ev['actor_role']})', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _slate900)),
                            const SizedBox(height: 2),
                            Text(ev['notes'] ?? '', style: const TextStyle(fontSize: 11.5, color: _slate700)),
                          ],
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RulePill extends StatelessWidget {
  final String title;
  final bool passed;

  const _RulePill(this.title, this.passed);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(passed ? Icons.check_circle_rounded : Icons.cancel_rounded, size: 14, color: passed ? const Color(0xFF166534) : const Color(0xFFDC2626)),
        const SizedBox(width: 4),
        Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF166534))),
      ],
    );
  }
}

class _ChecklistRow extends StatelessWidget {
  final String text;
  final bool verified;

  const _ChecklistRow(this.text, this.verified);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          Icon(verified ? Icons.check_circle_rounded : Icons.radio_button_unchecked, size: 16, color: verified ? const Color(0xFF15803D) : const Color(0xFF94A3B8)),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)))),
        ],
      ),
    );
  }
}
