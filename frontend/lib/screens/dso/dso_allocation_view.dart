import 'package:flutter/material.dart';
import '../../services/dso/dso_service.dart';
import '../../models/dso/dso_models.dart';

class DsoAllocationView extends StatefulWidget {
  final DsoService dsoService;
  final String cycleId;
  final VoidCallback onAllocationApproved;

  const DsoAllocationView({
    super.key,
    required this.dsoService,
    required this.cycleId,
    required this.onAllocationApproved,
  });

  @override
  State<DsoAllocationView> createState() => _DsoAllocationViewState();
}

class _DsoAllocationViewState extends State<DsoAllocationView> {
  bool _loading = true;
  bool _approving = false;
  DsoAllocationPlan? _plan;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAllocationPlan();
  }

  Future<void> _loadAllocationPlan() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await widget.dsoService.getAllocationPlan(cycleId: widget.cycleId);
      setState(() {
        _plan = res;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _handleApprovePlan() async {
    setState(() => _approving = true);
    try {
      await widget.dsoService.approveAllocation(cycleId: widget.cycleId);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Allocation Plan Approved! State advanced to ALLOCATED.'),
          backgroundColor: Color(0xFF16A34A),
        ),
      );
      widget.onAllocationApproved();
      await _loadAllocationPlan();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to approve allocation plan: $e'), backgroundColor: const Color(0xFFDC2626)),
      );
    } finally {
      setState(() => _approving = false);
    }
  }

  void _showOverrideModal(DsoAllocationItem item) {
    final qtyController = TextEditingController(text: '${item.proposedAllocationKg}');
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Override Allocation — ${item.fpsId} (${item.commodity})'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Validated Demand: ${item.validatedRequirementKg} kg | Existing Stock: ${item.existingStockKg} kg'),
            const SizedBox(height: 12),
            TextField(
              controller: qtyController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'New Allocation Quantity (kg)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Statutory Justification Reason', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final newQty = double.tryParse(qtyController.text);
              final reason = reasonController.text.trim();
              if (newQty == null || reason.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter valid quantity and reason.')),
                );
                return;
              }
              Navigator.of(ctx).pop();
              try {
                await widget.dsoService.overrideAllocation(
                  fpsId: item.fpsId,
                  commodity: item.commodity,
                  newAllocationKg: newQty,
                  reason: reason,
                  cycleId: widget.cycleId,
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Allocation override recorded for ${item.fpsId}')),
                );
                await _loadAllocationPlan();
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Override error: $e'), backgroundColor: const Color(0xFFDC2626)),
                );
              }
            },
            child: const Text('Save Override'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Error: $_error', style: const TextStyle(color: Color(0xFFDC2626))),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _loadAllocationPlan, child: const Text('Retry')),
          ],
        ),
      );
    }

    final p = _plan!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner & Action Header
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text('Stage 03: Stock Allocation Plan', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                    Text('Statutory Formula: Net Requirement = Validated Demand − Existing Shop Inventory', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                  ],
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                ),
                onPressed: _approving ? null : _handleApprovePlan,
                child: _approving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Row(
                        children: const [
                          Icon(Icons.check_circle_outline, size: 18),
                          SizedBox(width: 8),
                          Text('APPROVE ALLOCATION PLAN', style: TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Overview Summary Cards
          Row(
            children: [
              _buildSummaryCard('Central Depot Stock', '${p.availableDepotStockMt} MT', const Color(0xFF2563EB)),
              const SizedBox(width: 12),
              _buildSummaryCard('Validated Demand', '${p.totalValidatedDemandMt} MT', const Color(0xFF0284C7)),
              const SizedBox(width: 12),
              _buildSummaryCard('Existing FPS Stock', '${p.totalExistingFpsStockMt} MT', const Color(0xFFD97706)),
              const SizedBox(width: 12),
              _buildSummaryCard('Proposed Allocation', '${p.totalProposedAllocationMt} MT', const Color(0xFF16A34A)),
              const SizedBox(width: 12),
              _buildSummaryCard('Unallocated Depot Stock', '${p.unallocatedDepotBalanceMt} MT', const Color(0xFF7C3AED)),
            ],
          ),
          const SizedBox(height: 24),

          // Allocation Table
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('FPS Allocation Matrix', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  const SizedBox(height: 12),

                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowHeight: 40,
                      columns: const [
                        DataColumn(label: Text('FPS ID', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('FPS Name', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Commodity', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Validated Req (kg)', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('FPS Stock (kg)', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Net Req (kg)', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Proposed Alloc (kg)', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Priority', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Action', style: TextStyle(fontWeight: FontWeight.bold))),
                      ],
                      rows: p.items.map((item) {
                        return DataRow(
                          cells: [
                            DataCell(Text(item.fpsId, style: const TextStyle(fontWeight: FontWeight.bold))),
                            DataCell(Text(item.name)),
                            DataCell(Text(item.commodity)),
                            DataCell(Text('${item.validatedRequirementKg}')),
                            DataCell(Text('${item.existingStockKg}')),
                            DataCell(Text('${item.netRequirementKg}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2563EB)))),
                            DataCell(Text(
                              '${item.proposedAllocationKg}',
                              style: TextStyle(fontWeight: FontWeight.bold, color: item.isOverridden ? const Color(0xFF7C3AED) : const Color(0xFF16A34A)),
                            )),
                            DataCell(_buildPriorityBadge(item.priority)),
                            DataCell(
                              OutlinedButton(
                                onPressed: () => _showOverrideModal(item),
                                child: Text(item.isOverridden ? 'Edit Override' : 'Override'),
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
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String title, String val, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
            const SizedBox(height: 4),
            Text(val, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildPriorityBadge(String prio) {
    Color bg = const Color(0xFFF0FDF4);
    Color fg = const Color(0xFF16A34A);
    if (prio == 'CRITICAL') {
      bg = const Color(0xFFFEF2F2);
      fg = const Color(0xFFDC2626);
    } else if (prio == 'HIGH') {
      bg = const Color(0xFFFFF7ED);
      fg = const Color(0xFFEA580C);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
      child: Text(prio, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: fg)),
    );
  }
}
