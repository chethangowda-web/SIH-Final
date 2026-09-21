// dso_assignments_table.dart — Operational FPS assignments from allocation plan.
// Source: /admin/dso/allocation-plan (dso_allocation_overrides persisted backend-side).
// No demo records: empty plan renders "No records available for this cycle".
import 'package:flutter/material.dart';
import '../../models/dso/dso_models.dart';

class DsoAssignmentsTable extends StatefulWidget {
  final DsoAllocationPlan? allocationPlan;
  final bool isLoading;
  final Future<void> Function(DsoAllocationItem item, double newKg, String reason)? onOverride;
  final void Function(DsoAllocationItem item)? onViewDetails;

  const DsoAssignmentsTable({
    super.key,
    required this.allocationPlan,
    this.isLoading = false,
    this.onOverride,
    this.onViewDetails,
  });

  @override
  State<DsoAssignmentsTable> createState() => _DsoAssignmentsTableState();
}

class _DsoAssignmentsTableState extends State<DsoAssignmentsTable> {
  final TextEditingController _search = TextEditingController();
  String _priorityFilter = 'ALL';
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.assignment_outlined, color: Color(0xFF2563EB), size: 18),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('DSO ASSIGNMENTS — FPS ALLOCATION ITEMS',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                      Text('Source: /admin/dso/allocation-plan',
                          style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _search,
                    decoration: InputDecoration(
                      hintText: 'Search FPS ID or name',
                      hintStyle: const TextStyle(fontSize: 12),
                      prefixIcon: const Icon(Icons.search_rounded, size: 16),
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
                  ),
                ),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: _priorityFilter,
                  underline: const SizedBox(),
                  style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A)),
                  items: const ['ALL', 'STATUTORY', 'PRIORITY', 'OVERRIDDEN']
                      .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _priorityFilter = v);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (widget.isLoading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            _buildBody(),
        ],
      ),
    );
  }

  Widget _buildBody() {
    final plan = widget.allocationPlan;
    if (plan == null || plan.items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(
          child: Text('No records available for this cycle.',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
        ),
      );
    }
    final filtered = plan.items.where((item) {
      if (_query.isNotEmpty) {
        final hay = '${item.fpsId} ${item.name}'.toLowerCase();
        if (!hay.contains(_query)) return false;
      }
      if (_priorityFilter == 'OVERRIDDEN' && !item.isOverridden) {
        return false;
      }
      if (_priorityFilter != 'ALL' &&
          _priorityFilter != 'OVERRIDDEN' &&
          item.priority.toUpperCase() != _priorityFilter) {
        return false;
      }
      return true;
    }).toList();

    if (filtered.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(
          child: Text('No assignments match the current filter.',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowHeight: 36,
        dataRowMinHeight: 40,
        dataRowMaxHeight: 48,
        columnSpacing: 20,
        horizontalMargin: 16,
        headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
        columns: const [
          DataColumn(label: Text('FPS ID', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
          DataColumn(label: Text('FPS Name', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Commodity', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Validated (kg)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Allocated (kg)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Shortfall (kg)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Status', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Actions', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
        ],
        rows: filtered.take(100).map((item) {
          return DataRow(
            cells: [
              DataCell(Text(item.fpsId, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
              DataCell(SizedBox(
                width: 160,
                child: Text(item.name, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
              )),
              DataCell(Text(item.commodity, style: const TextStyle(fontSize: 12))),
              DataCell(Text(item.validatedRequirementKg.toStringAsFixed(1),
                  style: const TextStyle(fontSize: 12))),
              DataCell(Text(item.proposedAllocationKg.toStringAsFixed(1),
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
              DataCell(Text(
                item.shortfallKg.toStringAsFixed(1),
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: item.shortfallKg > 0 ? const Color(0xFFDC2626) : const Color(0xFF16A34A)),
              )),
              DataCell(_statusChip(item)),
              DataCell(Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.visibility_outlined, size: 16),
                    color: const Color(0xFF2563EB),
                    tooltip: 'View details',
                    onPressed: () => widget.onViewDetails?.call(item),
                  ),
                  if (widget.onOverride != null)
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      color: const Color(0xFFD97706),
                      tooltip: 'Override allocation',
                      onPressed: () => _showOverrideDialog(item),
                    ),
                ],
              )),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _statusChip(DsoAllocationItem item) {
    final overridden = item.isOverridden;
    final label = overridden ? 'OVERRIDDEN' : item.priority;
    final color = overridden ? const Color(0xFFD97706) : const Color(0xFF2563EB);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: color.withOpacity(0.10), borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
    );
  }

  Future<void> _showOverrideDialog(DsoAllocationItem item) async {
    final kgController = TextEditingController(text: item.proposedAllocationKg.toStringAsFixed(1));
    final reasonController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool submitting = false;

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text('Override allocation — ${item.fpsId} (${item.commodity})',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Current allocation: ${item.proposedAllocationKg.toStringAsFixed(1)} kg',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                const SizedBox(height: 12),
                TextFormField(
                  controller: kgController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                      labelText: 'New allocation (kg)', border: OutlineInputBorder(), isDense: true),
                  validator: (v) {
                    final parsed = double.tryParse((v ?? '').trim());
                    if (parsed == null || parsed < 0) return 'Enter a valid non-negative quantity';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: reasonController,
                  decoration: const InputDecoration(
                      labelText: 'Reason (recorded in audit trail)',
                      border: OutlineInputBorder(),
                      isDense: true),
                  validator: (v) =>
                      ((v ?? '').trim().isEmpty) ? 'A reason is required for audit' : null,
                ),
                const SizedBox(height: 8),
                const Text(
                    'Old value, new value, reason, DSO identity, timestamp, cycle and FPS are recorded server-side.',
                    style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: submitting
                  ? null
                  : () async {
                      if (!(formKey.currentState?.validate() ?? false)) return;
                      setDialogState(() => submitting = true);
                      Navigator.pop(ctx, {
                        'kg': kgController.text.trim(),
                        'reason': reasonController.text.trim(),
                      });
                    },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD97706)),
              child: const Text('Record Override'),
            ),
          ],
        ),
      ),
    );

    if (result != null && widget.onOverride != null) {
      final newKg = double.tryParse(result['kg'] ?? '');
      if (newKg != null) {
        await widget.onOverride!(item, newKg, result['reason'] ?? '');
      }
    }
  }
}
