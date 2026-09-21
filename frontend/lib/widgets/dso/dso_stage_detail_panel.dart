// dso_stage_detail_panel.dart — Expandable per-stage detail panel
import 'package:flutter/material.dart';
import '../../models/dso/dso_models.dart';

class DsoStageDetailPanel extends StatefulWidget {
  final DsoWorkflowState workflowState;
  final Map<String, dynamic> stageData;
  final bool isLoading;
  final DsoAllocationPlan? allocationPlan;
  final Future<void> Function(String manifestId)? onAuthorizeManifest;

  const DsoStageDetailPanel({
    super.key,
    required this.workflowState,
    required this.stageData,
    this.isLoading = false,
    this.allocationPlan,
    this.onAuthorizeManifest,
  });

  @override
  State<DsoStageDetailPanel> createState() => _DsoStageDetailPanelState();
}

class _DsoStageDetailPanelState extends State<DsoStageDetailPanel> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final stage = widget.workflowState;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          // Header (collapsible)
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.manage_search_outlined, size: 18, color: Color(0xFF2563EB)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'STAGE ${stage.stageNumber} — ${stage.displayLabel.toUpperCase()}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF2563EB), letterSpacing: 0.5),
                        ),
                        const SizedBox(height: 2),
                        Text(_stageDescription(stage), style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                      ],
                    ),
                  ),
                  Icon(_expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded, color: const Color(0xFF94A3B8)),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
            if (widget.isLoading)
              const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
            else
              _buildStageContent(stage),
          ],
        ],
      ),
    );
  }

  Widget _buildStageContent(DsoWorkflowState stage) {
    final data = widget.stageData;
    if (data.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Text(
          'No records available for this cycle (Stage ${stage.stageNumber}: ${stage.displayLabel}).',
          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
        ),
      );
    }

    switch (stage) {
      case DsoWorkflowState.planningOpen:
        return _buildPlanForecastContent(data);
      case DsoWorkflowState.demandValidated:
        return _buildValidationContent(data);
      case DsoWorkflowState.allocated:
        return _buildAllocationContent(data);
      case DsoWorkflowState.optimized:
        return _buildOptimizationContent(data);
      case DsoWorkflowState.dispatchAuthorized:
        return _buildDispatchContent(data);
      case DsoWorkflowState.deliveryVerification:
        return _buildDeliveryContent(data);
      case DsoWorkflowState.evaluated:
      case DsoWorkflowState.cycleClosed:
        return _buildEvaluationContent(data);
      default:
        return _buildGenericContent(data);
    }
  }

  Widget _buildPlanForecastContent(Map<String, dynamic> data) {
    final intentKg = (data['intent_demand_kg'] as num?)?.toDouble() ?? 0.0;
    final forecastKg = (data['forecast_demand_kg'] as num?)?.toDouble() ?? 0.0;
    final baselineKg = (data['baseline_demand_kg'] as num?)?.toDouble() ?? 0.0;
    final diff = intentKg - forecastKg;
    final hasForecast = forecastKg > 0;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDataRow('Intent Demand', hasForecast ? '${(intentKg / 1000).toStringAsFixed(1)} MT' : 'No records', const Color(0xFF7C3AED)),
          _buildDataRow('Forecast Demand', hasForecast ? '${(forecastKg / 1000).toStringAsFixed(1)} MT' : 'No records', const Color(0xFF2563EB)),
          _buildDataRow('Baseline Demand', baselineKg > 0 ? '${(baselineKg / 1000).toStringAsFixed(1)} MT' : 'No records', const Color(0xFF0891B2)),
          if (hasForecast && intentKg > 0) ...[
            const Divider(height: 16),
            _buildDataRow(
              'Intent − Forecast',
              diff >= 0 ? '+${(diff / 1000).toStringAsFixed(1)} MT' : '${(diff / 1000).toStringAsFixed(1)} MT',
              diff > 0 ? const Color(0xFFD97706) : const Color(0xFF16A34A),
            ),
          ],
          if (!hasForecast)
            const Text(
              'Forecast not yet generated. Run forecast to proceed.',
              style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
            ),
        ],
      ),
    );
  }

  Widget _buildValidationContent(Map<String, dynamic> data) {
    final snapshotId = data['snapshot_id'] ?? data['validation_id'] ?? '';
    final hash = data['sha256_hash'] ?? data['hash'] ?? '';
    final validatedAt = data['validated_at'] ?? data['created_at'] ?? '';
    final validatedBy = data['validated_by'] ?? data['officer_name'] ?? '';

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDataRow('Snapshot ID', snapshotId.isNotEmpty ? snapshotId : 'No records', const Color(0xFF2563EB)),
          _buildDataRow('Validated By', validatedBy.isNotEmpty ? validatedBy : 'No records', const Color(0xFF0891B2)),
          _buildDataRow('Validated At', validatedAt.isNotEmpty ? validatedAt : 'No records', const Color(0xFF059669)),
          if (hash.isNotEmpty)
            _buildDataRow('SHA-256 Seal', hash.length > 20 ? '${hash.substring(0, 20)}...' : hash, const Color(0xFF94A3B8)),
        ],
      ),
    );
  }

  Widget _buildAllocationContent(Map<String, dynamic> data) {
    final plan = widget.allocationPlan;
    if (plan == null) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Text(data.toString().length > 200 ? 'Allocation plan loading...' : 'No allocation records for this cycle.', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDataRow('Depot Stock Available', plan.availableDepotStockMt > 0 ? '${plan.availableDepotStockMt.toStringAsFixed(1)} MT' : 'No records', const Color(0xFF0891B2)),
          _buildDataRow('Total Validated Demand', plan.totalValidatedDemandMt > 0 ? '${plan.totalValidatedDemandMt.toStringAsFixed(1)} MT' : 'No records', const Color(0xFF7C3AED)),
          _buildDataRow('FPS Existing Stock', plan.totalExistingFpsStockMt > 0 ? '${plan.totalExistingFpsStockMt.toStringAsFixed(1)} MT' : 'No records', const Color(0xFF059669)),
          _buildDataRow('Net Requirement', plan.totalNetRequirementMt > 0 ? '${plan.totalNetRequirementMt.toStringAsFixed(1)} MT' : 'No records', const Color(0xFF2563EB)),
          _buildDataRow('Proposed Allocation', plan.totalProposedAllocationMt > 0 ? '${plan.totalProposedAllocationMt.toStringAsFixed(1)} MT' : 'No records', const Color(0xFF16A34A)),
          if (plan.totalShortfallMt > 0)
            _buildDataRow('Shortfall', '${plan.totalShortfallMt.toStringAsFixed(1)} MT', const Color(0xFFDC2626)),
          const Divider(height: 12),
          Text('${plan.items.length} FPS items in allocation plan', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
        ],
      ),
    );
  }

  Widget _buildOptimizationContent(Map<String, dynamic> data) {
    final routes = data['routes'] as List? ?? [];
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDataRow('Active Routes', routes.isEmpty ? 'No records' : routes.length.toString(), const Color(0xFF059669)),
          if (routes.isNotEmpty) ...[
            const SizedBox(height: 8),
            for (final r in routes.take(3))
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    const Icon(Icons.route_outlined, size: 14, color: Color(0xFF64748B)),
                    const SizedBox(width: 6),
                    Expanded(child: Text('${r['truck_id'] ?? 'Truck'} — ${r['stops_count'] ?? 0} stops, ${r['estimated_distance_km'] ?? 0} km', style: const TextStyle(fontSize: 12, color: Color(0xFF334155)))),
                  ],
                ),
              ),
          ] else
            const Text('No route data available for this cycle.', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
        ],
      ),
    );
  }

  Widget _buildDispatchContent(Map<String, dynamic> data) {
    final manifests = data['manifests'] as List? ?? [];
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDataRow('Dispatch Manifests', manifests.isEmpty ? 'No records' : manifests.length.toString(), const Color(0xFFD97706)),
          if (manifests.isNotEmpty)
            for (final m in manifests.take(10))
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    const Icon(Icons.local_shipping_outlined, size: 14, color: Color(0xFF64748B)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${(m['manifest_id'] ?? '').toString()} — ${(m['truck_id'] ?? '').toString()} → ${(m['fps_id'] ?? m['destination_fps'] ?? '').toString()} — ${(m['quantity_kg'] ?? m['total_quantity_kg'] ?? '').toString()} kg — ${(m['status'] ?? '').toString()}',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF334155)),
                      ),
                    ),
                    if (widget.onAuthorizeManifest != null &&
                        (m['manifest_id']?.toString().isNotEmpty ?? false))
                      TextButton(
                        onPressed: () =>
                            widget.onAuthorizeManifest!(m['manifest_id'].toString()),
                        child: const Text('Authorize', style: TextStyle(fontSize: 12)),
                      ),
                  ],
                ),
              )
          else
            const Text('No manifests found. Generate dispatch first.', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
        ],
      ),
    );
  }

  Widget _buildDeliveryContent(Map<String, dynamic> data) {
    final shipments = data['active_shipments'] as List? ?? [];
    final telemetryAvailable = data['telemetry_available'] == true;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDataRow('Active Shipments', shipments.isEmpty ? 'No records' : shipments.length.toString(), const Color(0xFF2563EB)),
          _buildDataRow('Live Location', telemetryAvailable ? 'Available' : 'Live location unavailable', telemetryAvailable ? const Color(0xFF16A34A) : const Color(0xFF94A3B8)),
          _buildDataRow('ETA', telemetryAvailable ? 'From telemetry' : 'ETA unavailable', const Color(0xFF94A3B8)),
        ],
      ),
    );
  }

  Widget _buildEvaluationContent(Map<String, dynamic> data) {
    final metrics = data['metrics'] as Map? ?? {};
    final rec = data['reconciliation'] as Map? ?? {};
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (metrics.isNotEmpty) ...[
            const Text('FORECAST ACCURACY', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF64748B), letterSpacing: 0.5)),
            const SizedBox(height: 8),
            _buildDataRow('MAE', metrics['mae_kg'] != null ? '${metrics['mae_kg']} kg' : 'No data', const Color(0xFF2563EB)),
            _buildDataRow('MAPE', metrics['mape_pct'] != null ? '${metrics['mape_pct']}%' : 'No data', const Color(0xFF7C3AED)),
            _buildDataRow('Accuracy Score', metrics['accuracy_score_pct'] != null ? '${metrics['accuracy_score_pct']}%' : 'No data', const Color(0xFF16A34A)),
          ],
          if (rec.isNotEmpty) ...[
            const Divider(height: 16),
            const Text('PHYSICAL RECONCILIATION', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF64748B), letterSpacing: 0.5)),
            const SizedBox(height: 8),
            _buildDataRow('Allocated', rec['allocated_mt'] != null ? '${rec['allocated_mt']} MT' : 'No records', const Color(0xFF2563EB)),
            _buildDataRow('Dispatched', rec['dispatched_mt'] != null ? '${rec['dispatched_mt']} MT' : 'No records', const Color(0xFFD97706)),
            _buildDataRow('Received', rec['received_mt'] != null ? '${rec['received_mt']} MT' : 'No records', const Color(0xFF059669)),
            _buildDataRow('Distributed', rec['distributed_mt'] != null ? '${rec['distributed_mt']} MT' : 'No records', const Color(0xFF16A34A)),
            _buildDataRow('Remaining', rec['remaining_fps_buffer_mt'] != null ? '${rec['remaining_fps_buffer_mt']} MT' : 'No records', const Color(0xFF0891B2)),
          ],
        ],
      ),
    );
  }

  Widget _buildGenericContent(Map<String, dynamic> data) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Text('Stage data: ${data.keys.take(5).join(', ')}...', style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
    );
  }

  Widget _buildDataRow(String label, String value, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)))),
          Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: value == 'No records' || value == 'No data' ? const Color(0xFF94A3B8) : valueColor)),
        ],
      ),
    );
  }

  String _stageDescription(DsoWorkflowState stage) {
    switch (stage) {
      case DsoWorkflowState.planningOpen: return 'Intent, forecast, and baseline demand comparison';
      case DsoWorkflowState.demandValidated: return 'Sealed demand snapshot with SHA-256 integrity';
      case DsoWorkflowState.allocated: return 'Stock allocation per FPS from validated demand';
      case DsoWorkflowState.optimized: return 'Multi-stop VRP route optimization results';
      case DsoWorkflowState.dispatchAuthorized: return 'Dispatch manifests and gatepass status';
      case DsoWorkflowState.deliveryVerification: return 'Active shipments and delivery verification';
      case DsoWorkflowState.evaluated: return 'Forecast accuracy and physical reconciliation';
      case DsoWorkflowState.cycleClosed: return 'Cycle closed and archived';
      default: return '';
    }
  }
}
