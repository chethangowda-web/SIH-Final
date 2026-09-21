import 'package:flutter/material.dart';
import '../../../models/inspector/inspector_models.dart';
import '../../../widgets/inspector/inspector_data_source_modal.dart';

/// Stage 01: Select Target & Directive Intake View
/// Government of Karnataka • Department of Food and Civil Supplies
class Stage01SelectTargetView extends StatefulWidget {
  final List<InspectorTarget> targets;
  final InspectorTarget? selectedTarget;
  final ValueChanged<InspectorTarget> onTargetSelected;
  final VoidCallback onStartInspection;
  final String activeCycle;

  const Stage01SelectTargetView({
    super.key,
    required this.targets,
    required this.selectedTarget,
    required this.onTargetSelected,
    required this.onStartInspection,
    required this.activeCycle,
  });

  @override
  State<Stage01SelectTargetView> createState() => _Stage01SelectTargetViewState();
}

class _Stage01SelectTargetViewState extends State<Stage01SelectTargetView> {
  String _searchQuery = '';
  String _filterPriority = 'ALL';

  @override
  Widget build(BuildContext context) {
    final filteredTargets = widget.targets.where((t) {
      final matchesSearch = t.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          t.fpsId.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          t.district.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesPriority = _filterPriority == 'ALL' ||
          (_filterPriority == 'DIRECTIVE' && t.orderId != null) ||
          t.priority == _filterPriority;
      return matchesSearch && matchesPriority;
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Stage Title & Action Banner
          _buildStageHeader(),
          const SizedBox(height: 20),

          // 2. Active Selection Card (Why this FPS?)
          if (widget.selectedTarget != null) ...[
            _buildActiveTargetCard(widget.selectedTarget!),
            const SizedBox(height: 20),
          ],

          // 3. Target Search & Filters
          _buildSearchAndFilters(),
          const SizedBox(height: 14),

          // 4. Candidate Targets Table
          Expanded(
            child: _buildTargetsTable(filteredTargets),
          ),
        ],
      ),
    );
  }

  Widget _buildStageHeader() {
    final directiveCount = widget.targets.where((t) => t.orderId != null).length;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.track_changes, color: Color(0xFF2563EB), size: 28),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'STAGE 01 — SELECT TARGET & DIRECTIVE INTAKE',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(width: 10),
                  if (directiveCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFFECACA)),
                      ),
                      child: Text(
                        '$directiveCount DSO Directives Pending',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFEF4444)),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 2),
              const Text(
                'Select assigned DSO surprise enforcement directive or high-priority FPS store for statutory 6-point verification',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),
        if (widget.selectedTarget != null)
          ElevatedButton.icon(
            icon: const Icon(Icons.play_arrow, size: 18),
            label: const Text('START INSPECTION', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: widget.onStartInspection,
          ),
      ],
    );
  }

  Widget _buildActiveTargetCard(InspectorTarget target) {
    final isDirective = target.orderId != null;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: isDirective ? const Color(0xFF93C5FD) : const Color(0xFFE2E8F0),
          width: isDirective ? 1.5 : 1,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: isDirective ? const Color(0xFFF8FAFC) : Colors.white,
          borderRadius: BorderRadius.circular(10),
        ),
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDirective
                        ? (target.priority == 'URGENT' ? const Color(0xFFEF4444) : const Color(0xFF2563EB))
                        : const Color(0xFF64748B),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    isDirective ? 'DSO DIRECTIVE: ${target.priority ?? "HIGH"}' : 'ROUTINE TARGET',
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '${target.name} (${target.fpsId})',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
                const Spacer(),
                TextButton.icon(
                  icon: const Icon(Icons.storage, size: 14),
                  label: const Text('View Data Source', style: TextStyle(fontSize: 12)),
                  onPressed: () {
                    InspectorDataSourceModal.show(
                      context,
                      title: 'FPS Master & Inventory: ${target.fpsId}',
                      datasetName: 'Fair Price Shop Master & Digital Warehouse',
                      tableName: 'fps JOIN inventory',
                      cycleId: widget.activeCycle,
                      recordCount: '1 authoritative store record',
                      formula: 'SELECT * FROM fps WHERE fps_id = "${target.fpsId}"',
                      apiEndpoint: '/api/v1/officer/inspector/target/${target.fpsId}',
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildTargetMetric('District', target.district),
                _buildTargetMetric('Beneficiaries', '${target.beneficiariesCount} Cards'),
                _buildTargetMetric('Storage Capacity', '${target.capacityKg.toStringAsFixed(0)} kg'),
                _buildTargetMetric('Current Rice Stock', '${target.riceStockKg.toStringAsFixed(1)} kg'),
                _buildTargetMetric('Current Wheat Stock', '${target.wheatStockKg.toStringAsFixed(1)} kg'),
                _buildTargetMetric(
                  'Last Score',
                  target.lastComplianceScore != null ? '${target.lastComplianceScore!.toStringAsFixed(1)}%' : 'None Recorded',
                ),
              ],
            ),
            if (target.reason != null && target.reason!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline, color: Color(0xFF2563EB), size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'WHY THIS FPS WAS SELECTED:',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1E40AF)),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            target.reason!,
                            style: const TextStyle(fontSize: 12, color: Color(0xFF1E3A8A)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTargetMetric(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilters() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search Fair Price Shop by ID, Name, or District...',
                hintStyle: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                prefixIcon: Icon(Icons.search, size: 18, color: Color(0xFF94A3B8)),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 10),
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _filterPriority,
              items: const [
                DropdownMenuItem(value: 'ALL', child: Text('All Targets')),
                DropdownMenuItem(value: 'DIRECTIVE', child: Text('DSO Directives Only')),
                DropdownMenuItem(value: 'URGENT', child: Text('Priority: URGENT')),
                DropdownMenuItem(value: 'HIGH', child: Text('Priority: HIGH')),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _filterPriority = val);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTargetsTable(List<InspectorTarget> targets) {
    if (targets.isEmpty) {
      return const Center(
        child: Text(
          'No Fair Price Shops found matching filter criteria.',
          style: TextStyle(color: Color(0xFF94A3B8)),
        ),
      );
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: ListView.separated(
          itemCount: targets.length,
          separatorBuilder: (context, index) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final t = targets[index];
            final isSelected = widget.selectedTarget?.fpsId == t.fpsId;
            final isDirective = t.orderId != null;

            return ListTile(
              tileColor: isSelected
                  ? const Color(0xFFEFF6FF)
                  : (isDirective ? const Color(0xFFFFFBEB) : Colors.white),
              dense: true,
              leading: Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isDirective
                      ? (t.priority == 'URGENT' ? const Color(0xFFEF4444) : const Color(0xFFF59E0B))
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  isDirective ? Icons.priority_high : Icons.store_outlined,
                  color: isDirective ? Colors.white : const Color(0xFF64748B),
                  size: 18,
                ),
              ),
              title: Row(
                children: [
                  Text(
                    t.name,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      t.fpsId,
                      style: const TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (isDirective) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: t.priority == 'URGENT' ? const Color(0xFFEF4444) : const Color(0xFF2563EB),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'DSO DIRECTIVE: ${t.priority}',
                        style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ],
              ),
              subtitle: Text(
                'District: ${t.district} • Beneficiaries: ${t.beneficiariesCount} • Stock: Rice ${t.riceStockKg.toStringAsFixed(0)} kg, Wheat ${t.wheatStockKg.toStringAsFixed(0)} kg' +
                    (t.reason != null ? ' • Directive: ${t.reason}' : ''),
                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: isSelected
                  ? const Icon(Icons.check_circle, color: Color(0xFF2563EB), size: 20)
                  : const Icon(Icons.chevron_right, color: Color(0xFF94A3B8), size: 20),
              onTap: () => widget.onTargetSelected(t),
            );
          },
        ),
      ),
    );
  }
}
