// DSO Command Center Screen — Complete Workflow-First Rebuild
// Replaces: dso_command_center_screen.dart + all old view files
// Architecture: Single scrollable workflow page, no sidebar
// Data: All from /admin/dso/* real API endpoints
// State machine: Driven by backend WorkflowState

import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/dso/dso_service.dart';
import '../../models/dso/dso_models.dart';
import '../../services/auth_session.dart';
import '../../widgets/dso/dso_workflow_cycle_ring.dart';
import '../../widgets/dso/dso_current_action_bar.dart';
import '../../widgets/dso/dso_metric_cards_row.dart';
import '../../widgets/dso/dso_supply_chain_trace.dart';
import '../../widgets/dso/dso_stage_detail_panel.dart';
import '../../widgets/dso/dso_exception_queue.dart';
import '../../widgets/dso/dso_activity_timeline.dart';
import '../../widgets/dso/dso_ai_insights_section.dart';
import '../../widgets/dso/dso_assignments_table.dart';
import '../../widgets/dso/dso_data_source_modal.dart';

class DsoCommandCenterScreen extends StatefulWidget {
  final ApiService? apiService;
  final String? username;

  const DsoCommandCenterScreen({
    super.key,
    this.apiService,
    this.username,
  });

  @override
  State<DsoCommandCenterScreen> createState() => _DsoCommandCenterScreenState();
}

class _DsoCommandCenterScreenState extends State<DsoCommandCenterScreen> {
  late DsoService _dsoService;
  final ScrollController _scrollController = ScrollController();

  // Core state
  bool _loading = true;
  String? _error;
  DsoCommandOverview? _overview;
  List<GovernanceEventItem> _events = [];

  // Stage data cache
  Map<String, dynamic> _stageData = {};
  DsoAllocationPlan? _allocationPlan;
  bool _stageDataLoading = false;

  // Action state
  bool _actionLoading = false;

  // Cycle + district — authoritative values loaded from backend in _init().
  // Empty = not yet loaded (UI shows loading / "No data available").
  String _activeCycle = '';
  String _selectedDistrict = '';
  List<String> _availableDistricts = [];
  List<String> _availableCycles = [];

  String get _officerName {
    final sessionUser = AuthSession.instance.username;
    if (sessionUser != null && sessionUser.trim().isNotEmpty) return sessionUser.trim();
    if (widget.username != null && widget.username!.trim().isNotEmpty) return widget.username!.trim();
    return 'DSO Officer';
  }

  @override
  void initState() {
    super.initState();
    _dsoService = DsoService();
    _init();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    // 1. Authoritative active cycle from backend choice-window status.
    try {
      final status = await _dsoService.getActiveCycleStatus();
      final backendCycle = (status['cycle_id'] ?? status['cycleId'] ?? '').toString();
      if (backendCycle.isNotEmpty && mounted) {
        setState(() {
          _activeCycle = backendCycle;
          _availableCycles = [backendCycle];
        });
      }
    } catch (_) {
      // _loadAll below will surface the connection error honestly.
    }
    // 2. Authoritative district list from fps.district via backend.
    try {
      final districts = await _dsoService.getDistricts();
      if (mounted && districts.isNotEmpty) {
        setState(() {
          _availableDistricts = districts;
          if (_selectedDistrict.isEmpty || !_availableDistricts.contains(_selectedDistrict)) {
            _selectedDistrict = _availableDistricts.first;
          }
        });
      }
    } catch (_) {
      // _loadAll below will surface the connection error honestly.
    }
    await _loadAll();
  }

  Future<void> _loadAll() async {
    if (_activeCycle.isEmpty || _selectedDistrict.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'No cycle or district data available from backend. Check connection and retry.';
      });
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final overview = await _dsoService.getCommandOverview(
        cycleId: _activeCycle,
        district: _selectedDistrict,
      );
      final events = await _dsoService.getGovernanceEvents(cycleId: _activeCycle);
      if (mounted) {
        setState(() {
          _overview = overview;
          _events = events;
          _loading = false;
        });
        _loadStageData(overview.workflowState);
      }
    } catch (e) {
      if (mounted) {
        setState(() { _error = e.toString(); _loading = false; });
      }
    }
  }

  Future<void> _loadStageData(DsoWorkflowState state) async {
    if (!mounted) return;
    setState(() { _stageDataLoading = true; });
    try {
      Map<String, dynamic> data = {};

      // Allocation plan powers the Assignments table on every stage.
      // Best-effort: absence renders "No records available for this cycle".
      try {
        _allocationPlan = await _dsoService.getAllocationPlan(cycleId: _activeCycle);
      } catch (_) {
        _allocationPlan = null;
      }

      switch (state) {
        case DsoWorkflowState.planningOpen:
          // Demand data already in overview metrics
          final m = _overview?.metrics ?? {};
          data = {
            'intent_demand_kg': m['intent_demand']?.count ?? 0.0,
            'forecast_demand_kg': m['forecast_demand']?.count ?? 0.0,
            'baseline_demand_kg': m['baseline_demand']?.count ?? 0.0,
          };
          break;

        case DsoWorkflowState.demandValidated:
          try {
            final vd = await _dsoService.getDemandValidation(cycleId: _activeCycle);
            data = vd;
          } catch (_) { data = {}; }
          break;

        case DsoWorkflowState.allocated:
          data = {'allocation_plan': 'loaded'};
          break;

        case DsoWorkflowState.optimized:
          try {
            final routes = await _dsoService.getSupplyRoutes(cycleId: _activeCycle);
            data = routes;
          } catch (_) { data = {}; }
          break;

        case DsoWorkflowState.dispatchAuthorized:
          try {
            final manifests = await _dsoService.getDispatchManifests(cycleId: _activeCycle);
            data = manifests;
          } catch (_) { data = {}; }
          break;

        case DsoWorkflowState.deliveryVerification:
          try {
            final delivery = await _dsoService.getDeliveryVerification(cycleId: _activeCycle);
            data = delivery;
          } catch (_) { data = {}; }
          break;

        case DsoWorkflowState.evaluated:
        case DsoWorkflowState.cycleClosed:
          try {
            final eval = await _dsoService.getCycleEvaluation(cycleId: _activeCycle);
            final rec = await _dsoService.getReconciliation(cycleId: _activeCycle);
            data = {'metrics': eval['metrics'] ?? {}, 'reconciliation': rec};
          } catch (_) { data = {}; }
          break;

        default:
          data = {};
      }

      if (mounted) {
        setState(() {
          _stageData = data;
          _stageDataLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() { _stageDataLoading = false; });
    }
  }

  /// Allocation override with full audit trail (old/new/reason/identity/timestamp
  /// recorded server-side in dso_allocation_overrides + governance trail).
  Future<void> _handleAllocationOverride(
      DsoAllocationItem item, double newKg, String reason) async {
    setState(() { _actionLoading = true; });
    try {
      final result = await _dsoService.overrideAllocation(
        fpsId: item.fpsId,
        commodity: item.commodity,
        newAllocationKg: newKg,
        reason: reason,
        cycleId: _activeCycle,
        officerName: _officerName,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(result['message']?.toString() ?? 'Override recorded with audit trail.'),
              backgroundColor: const Color(0xFF16A34A),
              duration: const Duration(seconds: 4)),
        );
        await _loadAll();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Override failed: $e'),
              backgroundColor: const Color(0xFFDC2626), duration: const Duration(seconds: 5)),
        );
      }
    } finally {
      if (mounted) setState(() { _actionLoading = false; });
    }
  }

  /// Per-manifest dispatch authorization against the real backend workflow.
  Future<void> _handleAuthorizeManifest(String manifestId) async {
    setState(() { _actionLoading = true; });
    try {
      final result = await _dsoService.authorizeDispatch(
        manifestId: manifestId,
        cycleId: _activeCycle,
        officerName: _officerName,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(result['message']?.toString() ?? 'Dispatch authorized.'),
              backgroundColor: const Color(0xFF16A34A),
              duration: const Duration(seconds: 4)),
        );
        await _loadAll();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Authorization failed: $e'),
              backgroundColor: const Color(0xFFDC2626), duration: const Duration(seconds: 5)),
        );
      }
    } finally {
      if (mounted) setState(() { _actionLoading = false; });
    }
  }

  void _showAllocationItemDetails(DsoAllocationItem item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('${item.fpsId} — ${item.commodity}',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('FPS: ${item.name}'),
            const SizedBox(height: 4),
            Text('Validated requirement: ${item.validatedRequirementKg.toStringAsFixed(1)} kg'),
            Text('Existing FPS stock: ${item.existingStockKg.toStringAsFixed(1)} kg'),
            Text('Net requirement: ${item.netRequirementKg.toStringAsFixed(1)} kg'),
            Text('Proposed allocation: ${item.proposedAllocationKg.toStringAsFixed(1)} kg'),
            Text('Shortfall: ${item.shortfallKg.toStringAsFixed(1)} kg'),
            Text('Priority: ${item.priority}'),
            if (item.isOverridden) Text('Override reason: ${item.overrideReason ?? 'recorded'}'),
            const SizedBox(height: 8),
            const Divider(),
            Text('Cycle: $_activeCycle',
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  Future<void> _handlePrimaryAction() async {
    final state = _overview?.workflowState ?? DsoWorkflowState.unknown;
    if (state == DsoWorkflowState.unknown) return;

    setState(() { _actionLoading = true; });

    try {
      String message = '';
      switch (state) {
        case DsoWorkflowState.planningOpen:
          final result = await _dsoService.validateDemand(cycleId: _activeCycle, officerName: _officerName);
          message = result['message']?.toString() ?? 'Demand validated and sealed.';
          break;
        case DsoWorkflowState.demandValidated:
          final result = await _dsoService.approveAllocation(cycleId: _activeCycle, officerName: _officerName);
          message = result['message']?.toString() ?? 'Allocation approved.';
          break;
        case DsoWorkflowState.allocated:
          final result = await _dsoService.approveOptimization(cycleId: _activeCycle, officerName: _officerName);
          message = result['message']?.toString() ?? 'Optimization approved.';
          break;
        case DsoWorkflowState.optimized:
          // Go to manifests list to authorize — show snackbar guiding DSO
          message = 'Review manifests below and use Authorize Dispatch per manifest.';
          break;
        case DsoWorkflowState.evaluated:
          final result = await _dsoService.closeCycle(cycleId: _activeCycle, officerName: _officerName);
          message = result['message']?.toString() ?? 'Cycle closed.';
          break;
        default:
          message = 'No action required for current stage.';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: const Color(0xFF16A34A), duration: const Duration(seconds: 4)),
        );
        await _loadAll();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Action failed: ${e.toString()}'), backgroundColor: const Color(0xFFDC2626), duration: const Duration(seconds: 5)),
        );
      }
    } finally {
      if (mounted) setState(() { _actionLoading = false; });
    }
  }

  void _showDataSourceModal() {
    DsoDataSourceModal.show(
      context,
      title: 'DSO Command Center — Data Sources',
      datasetName: 'beneficiaries, intent, forecast, fps, inventory, manifests, vehicles, routes, governance_audit_logs',
      tableName: 'pds_demandsync.db',
      cycleId: _activeCycle,
      recordCount: 'Real SQLite records',
      formula: 'WorkflowState from workflow_manager. Metrics from /admin/dso/command-overview.',
      apiEndpoint: '/admin/dso/command-overview',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? _buildError()
                    : _buildWorkflowContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final highEx = _overview?.exceptions.where((e) => e.severity == 'CRITICAL' || e.severity == 'HIGH').length ?? 0;

    return Container(
      color: const Color(0xFF0B2942),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.account_balance, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('PDS DemandSync', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
              const Text('District Supply Officer — Command Center', style: TextStyle(color: Color(0xFF93C5FD), fontSize: 11)),
            ],
          ),

          const SizedBox(width: 24),

          // Cycle selector — options are backend-confirmed cycles only.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
            child: _availableCycles.isEmpty
                ? const Text('Cycle: unavailable', style: TextStyle(color: Color(0xFF93C5FD), fontSize: 12))
                : DropdownButton<String>(
                    value: _availableCycles.contains(_activeCycle) ? _activeCycle : _availableCycles.first,
                    underline: const SizedBox(),
                    dropdownColor: const Color(0xFF0B2942),
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                    items: _availableCycles.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                    onChanged: (v) {
                      if (v != null) { setState(() => _activeCycle = v); _loadAll(); }
                    },
                  ),
          ),

          const SizedBox(width: 8),

          // District selector — options from fps.district via backend only.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
            child: _availableDistricts.isEmpty
                ? const Text('District: unavailable', style: TextStyle(color: Color(0xFF93C5FD), fontSize: 12))
                : DropdownButton<String>(
                    value: _availableDistricts.contains(_selectedDistrict) ? _selectedDistrict : _availableDistricts.first,
                    underline: const SizedBox(),
                    dropdownColor: const Color(0xFF0B2942),
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                    items: _availableDistricts.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                    onChanged: (v) {
                      if (v != null) { setState(() => _selectedDistrict = v); _loadAll(); }
                    },
                  ),
          ),

          const Spacer(),

          // Officer name
          Text(_officerName, style: const TextStyle(color: Color(0xFF93C5FD), fontSize: 12, fontWeight: FontWeight.w500)),
          const SizedBox(width: 16),

          // Exception badge
          if (highEx > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: const Color(0xFFDC2626).withOpacity(0.85), borderRadius: BorderRadius.circular(20)),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 14),
                  const SizedBox(width: 4),
                  Text('$highEx Exception${highEx > 1 ? 's' : ''}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                ],
              ),
            ),

          const SizedBox(width: 12),

          // System status
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: const Color(0xFF16A34A).withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
            child: Row(
              children: [
                Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFF34D399), shape: BoxShape.circle)),
                const SizedBox(width: 6),
                const Text('LIVE', style: TextStyle(color: Color(0xFF34D399), fontSize: 11, fontWeight: FontWeight.w700)),
              ],
            ),
          ),

          const SizedBox(width: 12),

          // Logout
          IconButton(
            onPressed: () {
              AuthSession.instance.clear();
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            icon: const Icon(Icons.logout_rounded, color: Colors.white, size: 18),
            tooltip: 'Log out',
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.cloud_off_outlined, size: 56, color: Color(0xFFDC2626)),
          const SizedBox(height: 16),
          const Text('Unable to connect to backend', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
          const SizedBox(height: 8),
          Text(_error ?? 'Unknown error', style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _loadAll,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry Connection'),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkflowContent() {
    final overview = _overview!;
    final state = overview.workflowState;
    final totalBen = overview.metrics['beneficiaries']?.count.toInt() ?? 0;
    final totalFps = overview.metrics['fps']?.count.toInt() ?? 0;

    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 1. Welcome + Cycle Context ────────────────────────────────────
          _buildWelcomeBanner(overview),
          const SizedBox(height: 20),

          // ── 2. WORKFLOW CYCLE RING — CENTERPIECE ─────────────────────────
          DsoWorkflowCycleRing(
            workflowState: state,
            cycleId: _activeCycle,
            district: _selectedDistrict,
            totalBeneficiaries: totalBen,
            totalFps: totalFps,
            onRefresh: _loadAll,
          ),
          const SizedBox(height: 20),

          // ── 3. CURRENT ACTION BAR ─────────────────────────────────────────
          DsoCurrentActionBar(
            workflowState: state,
            currentStageNum: state.stageNumber,
            isActionLoading: _actionLoading,
            onPrimaryAction: _handlePrimaryAction,
            onViewSource: _showDataSourceModal,
          ),
          const SizedBox(height: 20),

          // ── 4. OPERATIONAL METRIC CARDS ───────────────────────────────────
          _buildSectionLabel(Icons.bar_chart_rounded, 'OPERATIONAL METRICS', 'Cycle $_activeCycle  •  All from pds_demandsync.db'),
          const SizedBox(height: 10),
          DsoMetricCardsRow(overview: overview),
          const SizedBox(height: 20),

          // ── 5. SUPPLY CHAIN TRACE ─────────────────────────────────────────
          DsoSupplyChainTrace(
            workflowState: state,
            demandBreakdown: overview.demandBreakdown,
          ),
          const SizedBox(height: 20),

          // ── 6. STAGE DETAIL PANEL ─────────────────────────────────────────
          DsoStageDetailPanel(
            workflowState: state,
            stageData: _stageData,
            isLoading: _stageDataLoading,
            allocationPlan: _allocationPlan,
            onAuthorizeManifest: _handleAuthorizeManifest,
          ),
          const SizedBox(height: 20),

          // ── 6b. DSO ASSIGNMENTS (real allocation items, search/filter) ─────
          DsoAssignmentsTable(
            allocationPlan: _allocationPlan,
            isLoading: _stageDataLoading,
            onOverride: _handleAllocationOverride,
            onViewDetails: _showAllocationItemDetails,
          ),
          const SizedBox(height: 20),

          // ── 7. EXCEPTIONS + ACTIVITY (side by side on desktop) ────────────
          LayoutBuilder(
            builder: (ctx, constraints) {
              if (constraints.maxWidth > 900) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 6,
                      child: DsoExceptionQueue(
                        exceptions: overview.exceptions,
                        onActionTap: (exc) => _showExceptionDialog(exc),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 4,
                      child: DsoActivityTimeline(events: _events),
                    ),
                  ],
                );
              }
              return Column(
                children: [
                  DsoExceptionQueue(exceptions: overview.exceptions, onActionTap: _showExceptionDialog),
                  const SizedBox(height: 16),
                  DsoActivityTimeline(events: _events),
                ],
              );
            },
          ),
          const SizedBox(height: 20),

          // ── 8. AI INSIGHTS + DATA SOURCES ─────────────────────────────────
          LayoutBuilder(
            builder: (ctx, constraints) {
              if (constraints.maxWidth > 900) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 6,
                      child: DsoAiInsightsSection(
                        insights: overview.aiInsights,
                        aiRecommendation: overview.aiRecommendation,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 4,
                      child: _buildDataSourcesPanel(),
                    ),
                  ],
                );
              }
              return Column(
                children: [
                  DsoAiInsightsSection(insights: overview.aiInsights, aiRecommendation: overview.aiRecommendation),
                  const SizedBox(height: 16),
                  _buildDataSourcesPanel(),
                ],
              );
            },
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildWelcomeBanner(DsoCommandOverview overview) {
    final now = DateTime.now();
    final greeting = now.hour < 12 ? 'Good morning' : now.hour < 17 ? 'Good afternoon' : 'Good evening';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFEFF6FF), Color(0xFFF0FDF4)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$greeting, $_officerName', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
              const SizedBox(height: 3),
              Text(
                'Cycle $_activeCycle  •  $_selectedDistrict District  •  ${overview.workflowState.displayLabel}',
                style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
              ),
            ],
          ),
          const Spacer(),
          if (overview.dataLastUpdated.isNotEmpty)
            Text('Data updated: ${overview.dataLastUpdated}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
          const SizedBox(width: 12),
          TextButton.icon(
            onPressed: _loadAll,
            icon: const Icon(Icons.refresh_rounded, size: 14),
            label: const Text('Refresh', style: TextStyle(fontSize: 12)),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFF2563EB)),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(IconData icon, String title, String sub) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF64748B)),
        const SizedBox(width: 6),
        Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF475569), letterSpacing: 0.8)),
        const SizedBox(width: 10),
        Text('·  $sub', style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
      ],
    );
  }

  Widget _buildDataSourcesPanel() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: const BoxDecoration(
              color: Color(0xFF0B2942),
              borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(
              children: [
                const Icon(Icons.storage_rounded, color: Colors.white, size: 16),
                const SizedBox(width: 8),
                const Text('DATA SOURCES', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                const Spacer(),
                InkWell(
                  onTap: _showDataSourceModal,
                  child: const Text('View all', style: TextStyle(color: Color(0xFF93C5FD), fontSize: 11)),
                ),
              ],
            ),
          ),
          _buildDsRow('Database', 'pds_demandsync.db', const Color(0xFF2563EB)),
          _buildDsRow('Cycle', _activeCycle, const Color(0xFF059669)),
          _buildDsRow('District', _selectedDistrict, const Color(0xFF0891B2)),
          _buildDsRow('Workflow API', '/admin/dso/command-overview', const Color(0xFF7C3AED)),
          _buildDsRow('Governance', '/admin/governance-events', const Color(0xFF0891B2)),
          _buildDsRow('Allocation', '/admin/dso/allocation-plan', const Color(0xFFD97706)),
          _buildDsRow('Manifests', '/admin/dso/dispatch-manifests', const Color(0xFFD97706)),
          _buildDsRow('Reconciliation', '/admin/dso/reconciliation', const Color(0xFF16A34A)),
          Padding(
            padding: const EdgeInsets.all(14),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _showDataSourceModal,
                icon: const Icon(Icons.open_in_new_rounded, size: 14),
                label: const Text('Full Data Source Audit', style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF0B2942),
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDsRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)))),
          Expanded(
            flex: 2,
            child: Text(
              value,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  void _showExceptionDialog(DsoExceptionItem exc) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: exc.severity == 'CRITICAL' ? const Color(0xFFFEE2E2) : const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(exc.severity, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: exc.severity == 'CRITICAL' ? const Color(0xFFDC2626) : const Color(0xFFD97706))),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(exc.type, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold))),
          ],
        ),
          content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Exception ID: ${exc.id.isNotEmpty ? exc.id : 'Not provided'}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
            const SizedBox(height: 4),
            Text('FPS / Entity: ${exc.fps.isNotEmpty ? exc.fps : 'Not provided'}'),
            const SizedBox(height: 4),
            Text('Details: ${exc.details.isNotEmpty ? exc.details : 'Not provided'}'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }
}
