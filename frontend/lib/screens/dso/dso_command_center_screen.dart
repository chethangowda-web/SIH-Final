// DSO Command Center — WORKFLOW COMMAND CENTER (final rebuild).
// The workflow cycle is the entire UI: header -> workflow identity ->
// 7-stage cycle -> selected-stage workspace. No sidebar, no KPI dashboard,
// no permanent AI/exception panels. All state from /admin/dso/* backends.
import 'package:flutter/material.dart';
import '../../services/dso/dso_service.dart';
import '../../models/dso/dso_models.dart';
import '../../services/auth_session.dart';
import '../../widgets/dso/dso_workflow_cycle.dart';
import '../../widgets/dso/dso_stage_workspace.dart';
import '../../widgets/dso/dso_sheets.dart';

class DsoCommandCenterScreen extends StatefulWidget {
  final dynamic apiService;
  final DsoService? dsoService;
  final String? username;

  const DsoCommandCenterScreen({
    super.key,
    this.apiService,
    this.dsoService,
    this.username,
  });

  @override
  State<DsoCommandCenterScreen> createState() => _DsoCommandCenterScreenState();
}

class _DsoCommandCenterScreenState extends State<DsoCommandCenterScreen> {
  late DsoService _dsoService;

  bool _loading = true;
  String? _error;
  bool _actionLoading = false;

  DsoCommandOverview? _overview;
  List<GovernanceEventItem> _events = [];

  // Per-stage datasets (empty map = unavailable, rendered honestly).
  Map<String, dynamic> _demandValidation = {};
  DsoAllocationPlan? _allocationPlan;
  Map<String, dynamic> _routes = {};
  Map<String, dynamic> _manifests = {};
  Map<String, dynamic> _delivery = {};
  Map<String, dynamic> _evalMetrics = {};
  Map<String, dynamic> _reconciliation = {};

  String _activeCycle = '';
  String _selectedDistrict = '';
  List<String> _availableDistricts = [];
  List<String> _availableCycles = [];
  int _selectedStage = 1;

  String get _officerName {
    final s = AuthSession.instance.username;
    if (s != null && s.trim().isNotEmpty) return s.trim();
    if (widget.username != null && widget.username!.trim().isNotEmpty) {
      return widget.username!.trim();
    }
    return 'DSO Officer';
  }

  @override
  void initState() {
    super.initState();
    // Injectable for widget tests; production always uses the real service.
    _dsoService = widget.dsoService ?? DsoService();
    _init();
  }

  Future<void> _init() async {
    try {
      final status = await _dsoService.getActiveCycleStatus();
      final backendCycle =
          (status['cycle_id'] ?? status['cycleId'] ?? '').toString();
      if (backendCycle.isNotEmpty && mounted) {
        setState(() {
          _activeCycle = backendCycle;
          _availableCycles = [backendCycle];
        });
      }
    } catch (_) {}
    try {
      final districts = await _dsoService.getDistricts();
      if (mounted && districts.isNotEmpty) {
        setState(() {
          _availableDistricts = districts;
          if (_selectedDistrict.isEmpty ||
              !_availableDistricts.contains(_selectedDistrict)) {
            _selectedDistrict = _availableDistricts.first;
          }
        });
      }
    } catch (_) {}
    await _loadAll();
  }

  Future<void> _loadAll() async {
    if (_activeCycle.isEmpty || _selectedDistrict.isEmpty) {
      setState(() {
        _loading = false;
        _error =
            'No cycle or district data available from backend. Check connection and retry.';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final overview = await _dsoService.getCommandOverview(
          cycleId: _activeCycle, district: _selectedDistrict);
      final events =
          await _dsoService.getGovernanceEvents(cycleId: _activeCycle);
      if (!mounted) return;
      setState(() {
        _overview = overview;
        _events = events;
        _selectedStage = overview.workflowState.stageNumber;
      });
      await _loadStageDatasets();
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  /// Best-effort parallel load of every stage dataset. Failures stay empty
  /// and render as "No records / unavailable" — never fabricated.
  Future<void> _loadStageDatasets() async {
    final results = await Future.wait([
      _safe(() => _dsoService.getDemandValidation(cycleId: _activeCycle)),
      _safe(() => _dsoService.getSupplyRoutes(cycleId: _activeCycle)),
      _safe(() => _dsoService.getDispatchManifests(cycleId: _activeCycle)),
      _safe(() => _dsoService.getDeliveryVerification(cycleId: _activeCycle)),
      _safe(() => _dsoService.getCycleEvaluation(cycleId: _activeCycle)),
      _safe(() => _dsoService.getReconciliation(cycleId: _activeCycle)),
    ]);
    DsoAllocationPlan? plan;
    try {
      plan = await _dsoService.getAllocationPlan(cycleId: _activeCycle);
    } catch (_) {
      plan = null;
    }
    if (!mounted) return;
    setState(() {
      _demandValidation = results[0];
      _allocationPlan = plan;
      _routes = results[1];
      _manifests = results[2];
      _delivery = results[3];
      final eval = results[4];
      _evalMetrics = (eval['metrics'] as Map?)?.map(
              (k, v) => MapEntry(k.toString(), v)) ??
          {};
      _reconciliation = results[5];
    });
  }

  Future<Map<String, dynamic>> _safe(
      Future<Map<String, dynamic>> Function() call) async {
    try {
      return await call();
    } catch (_) {
      return {};
    }
  }

  // ── Backend-authoritative actions ─────────────────────────────────────
  Future<void> _runAction(Future<Map<String, dynamic>> Function() call,
      {String fallback = 'Done.'}) async {
    setState(() => _actionLoading = true);
    try {
      final result = await call();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              result['message']?.toString() ?? fallback),
          backgroundColor: const Color(0xFF16A34A),
          duration: const Duration(seconds: 4)));
      await _loadAll();
    } catch (e) {
      if (!mounted) return;
      String detail = e.toString();
      String hint = '';
      if (detail.contains('400')) {
        hint = ' Backend rejected the transition — required records are incomplete.';
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Action failed: $detail$hint'),
          backgroundColor: const Color(0xFFDC2626),
          duration: const Duration(seconds: 6)));
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: Column(
        children: [
          _header(),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? _errorView()
                    : _workflowView(),
          ),
        ],
      ),
    );
  }

  Widget _header() {
    final openEx = _overview?.exceptions.length ?? 0;
    return Container(
      color: const Color(0xFF0B2942),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.account_balance,
                color: Colors.white, size: 20),
          ),
          const SizedBox(width: 10),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('PDS DemandSync',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w800)),
              Text('DSO Command Center',
                  style:
                      TextStyle(color: Color(0xFF93C5FD), fontSize: 11)),
            ],
          ),
          const SizedBox(width: 20),
          _cyclePicker(),
          const SizedBox(width: 8),
          _districtPicker(),
          const SizedBox(width: 16),
          if (openEx > 0)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                  color: const Color(0xFFDC2626).withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(20)),
              child: Row(
                children: [
                  const Icon(Icons.notifications_outlined,
                      color: Colors.white, size: 14),
                  const SizedBox(width: 4),
                  Text('$openEx',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          const SizedBox(width: 10),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
                color:
                    const Color(0xFF16A34A).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20)),
            child: const Row(
              children: [
                Icon(Icons.circle, color: Color(0xFF34D399), size: 8),
                SizedBox(width: 6),
                Text('OPERATIONAL',
                    style: TextStyle(
                        color: Color(0xFF34D399),
                        fontSize: 10,
                        fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(_officerName,
              style: const TextStyle(
                  color: Color(0xFF93C5FD),
                  fontSize: 12,
                  fontWeight: FontWeight.w500)),
          IconButton(
            onPressed: () {
              AuthSession.instance.clear();
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            icon: const Icon(Icons.logout_rounded,
                color: Colors.white, size: 18),
            tooltip: 'Log out',
          ),
          ],
        ),
      ),
    );
  }

  Widget _cyclePicker() {
    if (_availableCycles.isEmpty) {
      return const Text('Cycle: unavailable',
          style: TextStyle(color: Color(0xFF93C5FD), fontSize: 12));
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8)),
      child: DropdownButton<String>(
        value: _availableCycles.contains(_activeCycle)
            ? _activeCycle
            : _availableCycles.first,
        underline: const SizedBox(),
        dropdownColor: const Color(0xFF0B2942),
        style: const TextStyle(
            color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
        items: _availableCycles
            .map((c) => DropdownMenuItem(value: c, child: Text(c)))
            .toList(),
        onChanged: (v) {
          if (v != null) {
            setState(() => _activeCycle = v);
            _loadAll();
          }
        },
      ),
    );
  }

  Widget _districtPicker() {
    if (_availableDistricts.isEmpty) {
      return const Text('District: unavailable',
          style: TextStyle(color: Color(0xFF93C5FD), fontSize: 12));
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8)),
      child: DropdownButton<String>(
        value: _availableDistricts.contains(_selectedDistrict)
            ? _selectedDistrict
            : _availableDistricts.first,
        underline: const SizedBox(),
        dropdownColor: const Color(0xFF0B2942),
        style: const TextStyle(
            color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
        items: _availableDistricts
            .map((d) => DropdownMenuItem(value: d, child: Text(d)))
            .toList(),
        onChanged: (v) {
          if (v != null) {
            setState(() => _selectedDistrict = v);
            _loadAll();
          }
        },
      ),
    );
  }

  Widget _errorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.cloud_off_outlined,
              size: 56, color: Color(0xFFDC2626)),
          const SizedBox(height: 16),
          const Text('Unable to connect to backend',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A))),
          const SizedBox(height: 8),
          Text(_error ?? 'Unknown error',
              style:
                  const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _init,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry Connection'),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB)),
          ),
        ],
      ),
    );
  }

  Widget _workflowView() {
    final overview = _overview!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Workflow identity strip.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [
                Color(0xFFEFF6FF),
                Color(0xFFF0FDF4)
              ]),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'DEMAND → VALIDATION → ALLOCATION → OPTIMIZATION → DISPATCH → DELIVERY → RECONCILIATION → CLOSURE',
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                        color: Color(0xFF1E3A8A)),
                  ),
                ),
                TextButton.icon(
                  onPressed: _loadAll,
                  icon:
                      const Icon(Icons.refresh_rounded, size: 14),
                  label: const Text('Refresh',
                      style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF2563EB)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // THE workflow cycle.
          DsoWorkflowCycle(
            workflowState: overview.workflowState,
            cycleId: _activeCycle,
            district: _selectedDistrict,
            selectedStage: _selectedStage,
            onSelectStage: (n) =>
                setState(() => _selectedStage = n),
            dataLastUpdated: overview.dataLastUpdated,
          ),
          const SizedBox(height: 20),
          // Selected-stage operational workspace.
          DsoStageWorkspace(
            stageNumber: _selectedStage,
            backendStage: overview.workflowState,
            cycleId: _activeCycle,
            district: _selectedDistrict,
            loading: false,
            actionLoading: _actionLoading,
            metrics: overview.metrics,
            demandBreakdown: overview.demandBreakdown,
            exceptions: overview.exceptions,
            aiInsights: overview.aiInsights,
            aiRecommendation: overview.aiRecommendation,
            demandValidation: _demandValidation,
            allocationPlan: _allocationPlan,
            routes: _routes,
            manifests: _manifests,
            delivery: _delivery,
            evalMetrics: _evalMetrics,
            reconciliation: _reconciliation,
            onContinueToValidate: () =>
                setState(() => _selectedStage = 2),
            onValidateDemand: () => _runAction(
                () => _dsoService.validateDemand(
                    cycleId: _activeCycle,
                    officerName: _officerName),
                fallback: 'Demand validated and sealed.'),
            onApproveAllocation: () => _runAction(
                () => _dsoService.approveAllocation(
                    cycleId: _activeCycle,
                    officerName: _officerName),
                fallback: 'Allocation approved.'),
            onOverride: _handleOverride,
            onViewAllocationItem: _showAllocationItem,
            onApproveOptimization: () => _runAction(
                () => _dsoService.approveOptimization(
                    cycleId: _activeCycle,
                    officerName: _officerName),
                fallback: 'Optimization approved.'),
            onAuthorizeManifest: _handleAuthorize,
            onSurpriseInspection: _handleInspection,
            onCloseCycle: () => _runAction(
                () => _dsoService.closeCycle(
                    cycleId: _activeCycle,
                    officerName: _officerName),
                fallback: 'Cycle closed.'),
            onOpenTrace: () => DsoSheets.showDecisionTrace(context,
                events: _events, cycleId: _activeCycle),
            onViewSource: (n) => _showSource(n),
            onReviewExceptions: () =>
                DsoSheets.showExceptions(context,
                    exceptions: overview.exceptions,
                    cycleId: _activeCycle,
                    onOpen: _showException),
          ),
          const SizedBox(height: 16),
          // Provenance footer.
          Text(
            'Source: pds_demandsync.db via /admin/dso/* • Cycle $_activeCycle • All actions RBAC-authorized as $_officerName',
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 11, color: Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Future<void> _handleOverride(
      DsoAllocationItem item, double newKg, String reason) {
    return _runAction(
        () => _dsoService.overrideAllocation(
            fpsId: item.fpsId,
            commodity: item.commodity,
            newAllocationKg: newKg,
            reason: reason,
            cycleId: _activeCycle,
            officerName: _officerName),
        fallback: 'Override recorded with audit trail.');
  }

  Future<void> _handleAuthorize(String manifestId) async {
    await _runAction(
        () => _dsoService.authorizeDispatch(
            manifestId: manifestId,
            cycleId: _activeCycle,
            officerName: _officerName),
        fallback: 'Dispatch authorized.');
  }

  Future<void> _handleInspection(String fpsId, String reason) async {
    await _runAction(
        () => _dsoService.surpriseInspection(
            fpsId: fpsId, reason: reason),
        fallback: 'Surprise inspection ordered.');
  }

  void _showAllocationItem(DsoAllocationItem item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('${item.fpsId} — ${item.commodity}',
            style:
                const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('FPS: ${item.name}'),
            const SizedBox(height: 4),
            Text(
                'Validated requirement: ${item.validatedRequirementKg.toStringAsFixed(1)} kg'),
            Text(
                'Existing FPS stock: ${item.existingStockKg.toStringAsFixed(1)} kg'),
            Text(
                'Net requirement: ${item.netRequirementKg.toStringAsFixed(1)} kg'),
            Text(
                'Proposed allocation: ${item.proposedAllocationKg.toStringAsFixed(1)} kg'),
            Text('Shortfall: ${item.shortfallKg.toStringAsFixed(1)} kg'),
            Text('Priority: ${item.priority}'),
            if (item.isOverridden)
              Text(
                  'Override reason: ${item.overrideReason ?? 'recorded'}'),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close')),
        ],
      ),
    );
  }

  void _showException(DsoExceptionItem exc) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
            exc.type.isNotEmpty ? exc.type : 'Exception',
            style:
                const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                'Exception ID: ${exc.id.isNotEmpty ? exc.id : 'Not provided'}'),
            Text(
                'FPS / Entity: ${exc.fps.isNotEmpty ? exc.fps : 'Not provided'}'),
            Text(
                'Details: ${exc.details.isNotEmpty ? exc.details : 'Not provided'}'),
            Text(
                'Severity: ${exc.severity.isNotEmpty ? exc.severity : 'Not provided'}'),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close')),
        ],
      ),
    );
  }

  void _showSource(int stageNum) {
    const endpoints = {
      1: '/admin/dso/command-overview',
      2: '/admin/dso/demand-validation + /admin/dso/validate-demand',
      3: '/admin/dso/allocation-plan + /admin/dso/allocation-override',
      4: '/admin/dso/supply-routes + /admin/dso/approve-optimization',
      5: '/admin/dso/dispatch-manifests + /admin/dso/dispatch-authorize',
      6: '/admin/dso/delivery-verification + /admin/dso/surprise-inspection',
      7: '/admin/dso/cycle-evaluation + /admin/dso/reconciliation + /admin/dso/close-cycle',
    };
    const tables = {
      1: 'beneficiaries, intent, forecast, inventory, depots, fps',
      2: 'demand_snapshots, intent, forecast',
      3: 'dso_validated_demand, dso_allocation_overrides, inventory, depots',
      4: 'routes, vehicles, manifests (draft)',
      5: 'manifests, manifest_audit_logs, gatepasses, vehicles',
      6: 'truck_telemetry, truck_route_tracking, fps_consignment_receipts, epos_transactions',
      7: 'forecast_evaluation, actual_distribution, model_calibration, cycle_workflow_states',
    };
    DsoSheets.showSource(context,
        stageTitle: 'STAGE 0$stageNum',
        rows: [
          ['Database', 'pds_demandsync.db (SQLite WAL)'],
          ['Tables', tables[stageNum] ?? ''],
        ],
        apiEndpoint: endpoints[stageNum] ?? '',
        cycleId: _activeCycle,
        updatedAt: _overview?.dataLastUpdated ?? '');
  }
}
