// dso_stage_workspace.dart — The selected workflow stage as an operational
// action screen (not a dashboard card). Data comes from backend-loaded maps;
// every number renders real records or an honest empty state. Primary actions
// are enabled ONLY on the backend-current stage: a tap never transitions
// state, only a backend success does.
import 'package:flutter/material.dart';
import '../../models/dso/dso_models.dart';
import 'dso_assignments_table.dart';

class DsoStageWorkspace extends StatelessWidget {
  final int stageNumber;
  final DsoWorkflowState backendStage;
  final String cycleId;
  final String district;
  final bool loading;
  final bool actionLoading;

  final Map<String, MetricItem> metrics;
  final Map<String, dynamic> demandBreakdown;
  final List<DsoExceptionItem> exceptions;
  final List<DsoAiInsightItem> aiInsights;
  final Map<String, dynamic> aiRecommendation;

  final Map<String, dynamic> demandValidation;
  final DsoAllocationPlan? allocationPlan;
  final Map<String, dynamic> routes;
  final Map<String, dynamic> manifests;
  final Map<String, dynamic> delivery;
  final Map<String, dynamic> evalMetrics;
  final Map<String, dynamic> reconciliation;

  final VoidCallback onContinueToValidate;
  final VoidCallback onValidateDemand;
  final VoidCallback onApproveAllocation;
  final Future<void> Function(DsoAllocationItem item, double newKg, String reason) onOverride;
  final void Function(DsoAllocationItem item) onViewAllocationItem;
  final VoidCallback onApproveOptimization;
  final Future<void> Function(String manifestId) onAuthorizeManifest;
  final Future<void> Function(String fpsId, String reason) onSurpriseInspection;
  final VoidCallback onCloseCycle;
  final VoidCallback onOpenTrace;
  final void Function(int stageNum) onViewSource;
  final VoidCallback onReviewExceptions;

  const DsoStageWorkspace({
    super.key,
    required this.stageNumber,
    required this.backendStage,
    required this.cycleId,
    required this.district,
    required this.loading,
    required this.actionLoading,
    required this.metrics,
    required this.demandBreakdown,
    required this.exceptions,
    required this.aiInsights,
    required this.aiRecommendation,
    required this.demandValidation,
    required this.allocationPlan,
    required this.routes,
    required this.manifests,
    required this.delivery,
    required this.evalMetrics,
    required this.reconciliation,
    required this.onContinueToValidate,
    required this.onValidateDemand,
    required this.onApproveAllocation,
    required this.onOverride,
    required this.onViewAllocationItem,
    required this.onApproveOptimization,
    required this.onAuthorizeManifest,
    required this.onSurpriseInspection,
    required this.onCloseCycle,
    required this.onOpenTrace,
    required this.onViewSource,
    required this.onReviewExceptions,
  });

  static const _titles = {
    1: 'MONITOR & TRIAGE',
    2: 'VALIDATE DEMAND',
    3: 'ALLOCATE',
    4: 'OPTIMIZE',
    5: 'AUTHORIZE DISPATCH',
    6: 'VERIFY DELIVERY',
    7: 'EVALUATE & CLOSE',
  };

  static const _descriptions = {
    1: 'Live demand conditions and operational exceptions for this cycle.',
    2: 'Freeze the demand snapshot into an immutable, sealed record.',
    3: 'Assign validated stock to each Fair Price Shop.',
    4: 'Confirm corridor routing before trucks are loaded.',
    5: 'Release sealed manifests to trucks, one authorization at a time.',
    6: 'Match dispatched grain against FPS receipts and telemetry.',
    7: 'Score forecast accuracy, reconcile physical grain, close the cycle.',
  };

  bool get _isCurrentStage =>
      backendStage != DsoWorkflowState.unknown &&
      backendStage != DsoWorkflowState.cycleClosed &&
      backendStage.stageNumber == stageNumber;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2563EB), width: 1.5),
        boxShadow: [
          BoxShadow(
              color: const Color(0xFF2563EB).withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(context),
          if (loading)
            const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
          else ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: _stageBody(context),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: _contextualAi(),
            ),
            _footerActions(context),
          ],
        ],
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: const BoxDecoration(
        color: Color(0xFF0B2942),
        borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text('0$stageNumber',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w800)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('STAGE 0$stageNumber OF 7 — ${_titles[stageNumber]}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4)),
                const SizedBox(height: 2),
                Text(_descriptions[stageNumber] ?? '',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _stageChip(),
        ],
      ),
    );
  }

  Widget _stageChip() {
    late final String label;
    late final Color color;
    if (backendStage == DsoWorkflowState.cycleClosed) {
      label = 'SEALED';
      color = const Color(0xFF34D399);
    } else if (backendStage == DsoWorkflowState.unknown) {
      label = 'UNKNOWN';
      color = const Color(0xFF94A3B8);
    } else if (stageNumber < backendStage.stageNumber) {
      label = 'COMPLETED';
      color = const Color(0xFF34D399);
    } else if (_isCurrentStage) {
      label = 'CURRENT — ACTION REQUIRED';
      color = const Color(0xFFFBBF24);
    } else {
      label = 'LOCKED';
      color = const Color(0xFF94A3B8);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.5))),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 10, fontWeight: FontWeight.w800)),
    );
  }

  // ── Per-stage operational bodies ──────────────────────────────────────
  Widget _stageBody(BuildContext context) {
    switch (stageNumber) {
      case 1:
        return _monitorBody(context);
      case 2:
        return _validateBody();
      case 3:
        return _allocateBody();
      case 4:
        return _optimizeBody();
      case 5:
        return _authorizeBody();
      case 6:
        return _verifyBody();
      case 7:
        return _evaluateBody();
      default:
        return const _EmptyNote(message: 'Unknown stage.');
    }
  }

  Widget _monitorBody(BuildContext context) {
    final intent = metrics['intent_demand']?.count ?? 0.0;
    final forecast = metrics['forecast_demand']?.count ?? 0.0;
    final baseline = metrics['baseline_demand']?.count ?? 0.0;
    final hasDemand = intent > 0 || forecast > 0 || baseline > 0;
    final diffIF = intent - forecast;
    final diffFB = forecast - baseline;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _fact('Beneficiaries', _count(metrics['beneficiaries']?.count), 'beneficiaries'),
            _fact('Active Intents', _count(metrics['active_intents']?.count), 'intent'),
            _fact('FPS in District', _count(metrics['fps']?.count), 'fps'),
            _fact('Depot Stock', _mt(metrics['depot_stock_kg']?.count), 'depots'),
            _fact('FPS Inventory', _mt(metrics['fps_inventory_kg']?.count), 'inventory'),
            _fact('Open Exceptions', exceptions.isEmpty ? '0' : '${exceptions.length}',
                'forecast risk'),
          ],
        ),
        const SizedBox(height: 16),
        const Text('DEMAND COMPARISON',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
                color: Color(0xFF475569))),
        const SizedBox(height: 8),
        if (!hasDemand)
          const _EmptyNote(message: 'No demand records available for this cycle.')
        else ...[
          _row('Intent Demand', _mt(intent)),
          _row('Forecast Demand', _mt(forecast)),
          _row('Baseline Demand', _mt(baseline)),
          const Divider(height: 20),
          _row('Intent − Forecast',
              '${diffIF >= 0 ? '+' : ''}${_mt(diffIF)}'),
          _row('Forecast − Baseline',
              '${diffFB >= 0 ? '+' : ''}${_mt(diffFB)}'),
        ],
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          children: [
            OutlinedButton.icon(
              onPressed: () => onViewSource(1),
              icon: const Icon(Icons.storage_outlined, size: 16),
              label: const Text('View Demand Data'),
            ),
            OutlinedButton.icon(
              onPressed: onReviewExceptions,
              icon: Badge(
                label: Text('${exceptions.length}'),
                isLabelVisible: exceptions.isNotEmpty,
                child: const Icon(Icons.warning_amber_outlined, size: 16),
              ),
              label: const Text('Review Exceptions'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _validateBody() {
    final snapId = (demandValidation['snapshot_id'] ??
            demandValidation['validation_id'] ??
            '')
        .toString();
    final hash =
        (demandValidation['sha256_hash'] ?? demandValidation['hash'] ?? '')
            .toString();
    final by =
        (demandValidation['validated_by'] ?? demandValidation['officer_name'] ?? '')
            .toString();
    final at =
        (demandValidation['validated_at'] ?? demandValidation['created_at'] ?? '')
            .toString();
    final sealed = demandValidation['is_sealed'] == true ||
        demandValidation['lock_status'] == 'LOCKED';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (snapId.isEmpty && !sealed)
          const _EmptyNote(
              message: 'No sealed snapshot yet. Validation will freeze the current demand.')
        else ...[
          _row('Snapshot ID', snapId.isNotEmpty ? snapId : 'unavailable'),
          _row('Status', sealed ? 'SEALED — immutable' : 'DRAFT — awaiting validation'),
          _row('Validated By', by.isNotEmpty ? by : '—'),
          _row('Validated At', at.isNotEmpty ? at : '—'),
          if (hash.isNotEmpty)
            _row('SHA-256 Seal',
                hash.length > 24 ? '${hash.substring(0, 24)}…' : hash),
        ],
        const SizedBox(height: 8),
        const Text(
            'Validation freezes the existing snapshot. It never creates demand.',
            style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
        const SizedBox(height: 12),
        _primaryOrLocked(
          enabled: _isCurrentStage && !sealed,
          label: 'VALIDATE DEMAND',
          onPressed: onValidateDemand,
          lockedHint:
              'Available when Stage 02 is the backend-current stage and no sealed snapshot exists.',
        ),
      ],
    );
  }

  Widget _allocateBody() {
    final plan = allocationPlan;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (plan == null)
          const _EmptyNote(
              message: 'No allocation records available for this cycle.')
        else ...[
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _fact('Depot Available', '${plan.availableDepotStockMt.toStringAsFixed(1)} MT', 'depots'),
              _fact('Validated Demand', '${plan.totalValidatedDemandMt.toStringAsFixed(1)} MT', 'dso_validated_demand'),
              _fact('Net Requirement', '${plan.totalNetRequirementMt.toStringAsFixed(1)} MT', 'allocation engine'),
              _fact('Proposed Allocation', '${plan.totalProposedAllocationMt.toStringAsFixed(1)} MT', 'allocation engine'),
              if (plan.totalShortfallMt > 0)
                _fact('Shortfall', '${plan.totalShortfallMt.toStringAsFixed(1)} MT', 'scarcity engine'),
            ],
          ),
          const SizedBox(height: 16),
          DsoAssignmentsTable(
            allocationPlan: plan,
            onOverride: _isCurrentStage ? onOverride : null,
            onViewDetails: onViewAllocationItem,
          ),
          const SizedBox(height: 16),
        ],
        _primaryOrLocked(
          enabled: _isCurrentStage,
          label: 'APPROVE ALLOCATION',
          onPressed: onApproveAllocation,
          lockedHint: 'Available when Stage 03 is the backend-current stage.',
        ),
      ],
    );
  }

  Widget _optimizeBody() {
    final routeList = routes['routes'] as List? ?? [];
    final status = (routes['status'] ?? routes['optimization_status'] ?? '').toString();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (routeList.isEmpty)
          const _EmptyNote(message: 'Optimization data unavailable for this cycle.')
        else ...[
          _row('Corridor Routes', '${routeList.length}'),
          if (status.isNotEmpty) _row('Optimization Status', status),
          const SizedBox(height: 8),
          for (final r in routeList.take(5))
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  const Icon(Icons.route_outlined,
                      size: 14, color: Color(0xFF64748B)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${(r['truck_id'] ?? '').toString()} — ${(r['stops_count'] ?? r['fps_count'] ?? 0).toString()} stops — ${(r['estimated_distance_km'] ?? r['distance_km'] ?? 0).toString()} km — ${(r['load_kg'] ?? r['total_load_kg'] ?? 0).toString()} kg',
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF334155)),
                    ),
                  ),
                ],
              ),
            ),
        ],
        const SizedBox(height: 12),
        _primaryOrLocked(
          enabled: _isCurrentStage,
          label: 'APPROVE OPTIMIZATION',
          onPressed: onApproveOptimization,
          lockedHint: 'Available when Stage 04 is the backend-current stage.',
        ),
      ],
    );
  }

  Widget _authorizeBody() {
    final list = manifests['manifests'] as List? ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (list.isEmpty)
          const _EmptyNote(
              message: 'No dispatch manifests available for this cycle.')
        else
          for (final m in list.take(10))
            _manifestRow(
              (m['manifest_id'] ?? '').toString(),
              (m['truck_id'] ?? '').toString(),
              (m['route_id'] ?? m['corridor'] ?? '').toString(),
              (m['fps_id'] ?? m['destination_fps'] ?? '').toString(),
              (m['commodity'] ?? '').toString(),
              (m['quantity_kg'] ?? m['total_quantity_kg'] ?? '').toString(),
              (m['status'] ?? '').toString(),
              (m['gatepass_status'] ?? m['gatepass'] ?? '').toString(),
            ),
      ],
    );
  }

  Widget _manifestRow(String manifestId, String truckId, String routeId,
      String fps, String commodity, String qty, String status, String gatepass) {
    final canAct = _isCurrentStage && manifestId.isNotEmpty;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          const Icon(Icons.local_shipping_outlined,
              size: 18, color: Color(0xFF0B2942)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    manifestId.isNotEmpty
                        ? manifestId
                        : 'Manifest ID unavailable',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A))),
                Text(
                    'Truck ${truckId.isNotEmpty ? truckId : '—'}  •  Route ${routeId.isNotEmpty ? routeId : '—'}  •  FPS ${fps.isNotEmpty ? fps : '—'}',
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFF475569))),
                Text(
                    '${commodity.isNotEmpty ? commodity : '—'}  •  ${qty.isNotEmpty ? '$qty kg' : 'qty unavailable'}  •  ${status.isNotEmpty ? status : 'status unavailable'}${gatepass.isNotEmpty ? '  •  Gatepass: $gatepass' : ''}',
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFF64748B))),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: !canAct || actionLoading
                ? null
                : () => onAuthorizeManifest(manifestId),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10)),
            child: const Text('AUTHORIZE',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _verifyBody() {
    final shipments = delivery['active_shipments'] as List? ?? [];
    final telemetry = delivery['telemetry_available'] == true;
    final receipts = delivery['fps_receipts'] as List? ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _row('Active Shipments',
            shipments.isEmpty ? 'No records' : '${shipments.length}'),
        _row('Live Location',
            telemetry ? 'Available' : 'Live location unavailable'),
        _row('ETA', telemetry ? _eta() : 'ETA unavailable'),
        _row('FPS Receipts',
            receipts.isEmpty ? 'No records' : '${receipts.length}'),
        if (shipments.isNotEmpty) ...[
          const SizedBox(height: 8),
          for (final s in shipments.take(5))
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                '${(s['truck_id'] ?? '').toString()} — dispatched ${(s['dispatched_qty_kg'] ?? '').toString()} kg → received ${(s['received_qty_kg'] ?? '').toString()} kg — ${(s['status'] ?? '').toString()}',
                style:
                    const TextStyle(fontSize: 12, color: Color(0xFF334155)),
              ),
            ),
        ],
        const SizedBox(height: 12),
        _SurpriseInspectionButton(onSubmit: onSurpriseInspection),
      ],
    );
  }

  String _eta() {
    final v = (delivery['eta'] ?? delivery['estimated_arrival'] ?? '').toString();
    return v.isNotEmpty ? v : 'ETA unavailable';
  }

  Widget _evaluateBody() {
    final rec = reconciliation;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('FORECAST EVALUATION',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
                color: Color(0xFF475569))),
        const SizedBox(height: 8),
        if (evalMetrics.isEmpty)
          const _EmptyNote(message: 'Evaluation metrics unavailable for this cycle.')
        else ...[
          _row('MAE',
              evalMetrics['mae_kg'] != null ? '${evalMetrics['mae_kg']} kg' : 'Data unavailable'),
          _row('MAPE',
              evalMetrics['mape_pct'] != null ? '${evalMetrics['mape_pct']}%' : 'Data unavailable'),
          _row('Bias',
              evalMetrics['bias_kg'] != null ? '${evalMetrics['bias_kg']} kg' : 'Data unavailable'),
          _row('Accuracy',
              evalMetrics['accuracy_score_pct'] != null
                  ? '${evalMetrics['accuracy_score_pct']}%'
                  : 'Data unavailable'),
        ],
        const SizedBox(height: 16),
        const Text('PHYSICAL RECONCILIATION',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
                color: Color(0xFF475569))),
        const SizedBox(height: 8),
        if (rec.isEmpty)
          const _EmptyNote(message: 'No reconciliation records for this cycle.')
        else ...[
          _chain('Allocated', rec['allocated_mt'] ?? rec['allocated_kg']),
          _chain('Dispatched', rec['dispatched_mt'] ?? rec['dispatched_kg']),
          _chain('Received', rec['received_mt'] ?? rec['received_kg']),
          _chain('Distributed', rec['distributed_mt'] ?? rec['distributed_kg']),
          _chain('Remaining',
              rec['remaining_fps_buffer_mt'] ?? rec['remaining_kg']),
        ],
        const SizedBox(height: 12),
        _primaryOrLocked(
          enabled:
              _isCurrentStage || backendStage == DsoWorkflowState.evaluated,
          label: 'CLOSE CYCLE',
          onPressed: onCloseCycle,
          lockedHint:
              'Closure is backend-controlled and blocked until all required records are complete.',
        ),
      ],
    );
  }

  // ── Contextual AI inside the active stage ─────────────────────────────
  Widget _contextualAi() {
    final relevant = _insightsForStage();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF5FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE9D5FF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.auto_awesome,
                  size: 15, color: Color(0xFF7C3AED)),
              SizedBox(width: 6),
              Text('AI — STAGE INSIGHT',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                      color: Color(0xFF6D28D9))),
            ],
          ),
          const SizedBox(height: 8),
          if (relevant.isEmpty)
            const Text('AI insight unavailable for this stage.',
                style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)))
          else
            for (final i in relevant.take(2))
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        i.title.isNotEmpty
                            ? i.title
                            : 'Untitled insight',
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A))),
                    if (i.summary.isNotEmpty)
                      Text(i.summary,
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF475569))),
                    Text(
                        'Evidence: ${i.evidence.isNotEmpty ? i.evidence : 'not provided'}',
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xFF64748B))),
                    Text(
                        'Confidence: ${_confidence()}',
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xFF64748B))),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  String _confidence() {
    final c = aiRecommendation['confidence']?.toString() ?? '';
    return c.isNotEmpty ? c : 'Confidence unavailable';
  }

  List<DsoAiInsightItem> _insightsForStage() {
    const keys = {
      1: ['demand', 'intent', 'baseline', 'exception', 'triage'],
      2: ['valid', 'snapshot', 'seal', 'demand'],
      3: ['alloc', 'fps', 'shortfall', 'stock'],
      4: ['optim', 'route', 'corridor', 'truck'],
      5: ['dispatch', 'manifest', 'gatepass', 'truck'],
      6: ['deliver', 'telemetry', 'receipt', 'inspect'],
      7: ['evalu', 'reconcil', 'mape', 'accuracy', 'forecast'],
    };
    final ks = keys[stageNumber] ?? const [];
    return aiInsights.where((i) {
      final hay = '${i.title} ${i.summary} ${i.why}'.toLowerCase();
      return ks.any(hay.contains);
    }).toList();
  }

  // ── Footer: secondary trace actions ───────────────────────────────────
  Widget _footerActions(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 22),
      child: Wrap(
        spacing: 10,
        children: [
          OutlinedButton.icon(
            onPressed: () => onViewSource(stageNumber),
            icon: const Icon(Icons.storage_outlined, size: 16),
            label: const Text('View Data Source'),
          ),
          OutlinedButton.icon(
            onPressed: onOpenTrace,
            icon: const Icon(Icons.account_tree_outlined, size: 16),
            label: const Text('View Decision Trace'),
          ),
        ],
      ),
    );
  }

  Widget _primaryOrLocked({
    required bool enabled,
    required String label,
    required VoidCallback onPressed,
    required String lockedHint,
  }) {
    if (!enabled) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Text(lockedHint,
            style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
      );
    }
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: actionLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2563EB),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: actionLoading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
            : Text(label,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w800)),
      ),
    );
  }

  // ── Small presentational helpers (display-only, never data) ───────────
  Widget _fact(String title, String value, String source) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF64748B))),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: value == 'No records' || value == 'Data unavailable'
                      ? const Color(0xFF94A3B8)
                      : const Color(0xFF0F172A))),
          Text(source,
              style: const TextStyle(
                  fontSize: 9, color: Color(0xFF94A3B8))),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    final empty =
        value.isEmpty || value == 'No records' || value == 'Data unavailable';
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        children: [
          Expanded(
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFF64748B)))),
          Text(empty ? 'Data unavailable' : value,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: empty
                      ? const Color(0xFF94A3B8)
                      : const Color(0xFF0F172A))),
        ],
      ),
    );
  }

  Widget _chain(String label, dynamic raw) {
    final value =
        raw == null ? 'No records' : '$raw ${label == 'Remaining' ? '' : ''}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          const Icon(Icons.arrow_downward_rounded,
              size: 12, color: Color(0xFFCBD5E1)),
          const SizedBox(width: 6),
          Expanded(
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFF475569)))),
          Text(value,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A))),
        ],
      ),
    );
  }

  String _mt(double? kg) {
    if (kg == null || kg == 0) return 'No records';
    if (kg >= 1000) return '${(kg / 1000).toStringAsFixed(1)} MT';
    return '${kg.toStringAsFixed(0)} kg';
  }

  String _count(double? n) {
    if (n == null || n == 0) return 'No records';
    return n.toInt().toString();
  }
}

class _EmptyNote extends StatelessWidget {
  final String message;
  const _EmptyNote({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Text(message,
          style:
              const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
    );
  }
}

class _SurpriseInspectionButton extends StatefulWidget {
  final Future<void> Function(String fpsId, String reason) onSubmit;
  const _SurpriseInspectionButton({required this.onSubmit});

  @override
  State<_SurpriseInspectionButton> createState() =>
      _SurpriseInspectionButtonState();
}

class _SurpriseInspectionButtonState
    extends State<_SurpriseInspectionButton> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: _busy
          ? null
          : () async {
              final data = await _ask();
              if (data == null) return;
              setState(() => _busy = true);
              try {
                await widget.onSubmit(data[0], data[1]);
              } finally {
                if (mounted) setState(() => _busy = false);
              }
            },
      icon: const Icon(Icons.fact_check_outlined, size: 16),
      label: const Text('Order Surprise Inspection'),
    );
  }

  Future<List<String>?> _ask() {
    final fps = TextEditingController();
    final reason = TextEditingController();
    final key = GlobalKey<FormState>();
    return showDialog<List<String>>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        title: const Text('Surprise Inspection',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        content: Form(
          key: key,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: fps,
                decoration: const InputDecoration(
                    labelText: 'FPS ID', border: OutlineInputBorder(),
                    isDense: true),
                validator: (v) =>
                    ((v ?? '').trim().isEmpty) ? 'FPS ID required' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: reason,
                decoration: const InputDecoration(
                    labelText: 'Reason', border: OutlineInputBorder(),
                    isDense: true),
                validator: (v) =>
                    ((v ?? '').trim().isEmpty) ? 'Reason required' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (!(key.currentState?.validate() ?? false)) return;
              Navigator.pop(
                  ctx, [fps.text.trim(), reason.text.trim()]);
            },
            child: const Text('Submit Order'),
          ),
        ],
      ),
    );
  }
}
