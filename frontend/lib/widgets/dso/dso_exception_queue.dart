import 'package:flutter/material.dart';
import '../../models/dso/dso_models.dart';

class DsoExceptionQueue extends StatelessWidget {
  final List<DsoExceptionItem> exceptions;
  final VoidCallback? onViewAll;
  final Function(DsoExceptionItem item)? onActionTap;

  const DsoExceptionQueue({
    super.key,
    required this.exceptions,
    this.onViewAll,
    this.onActionTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 18),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Exception Queue',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${exceptions.length} open',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF991B1B),
                    ),
                  ),
                ),
                const Spacer(),
                if (onViewAll != null)
                  TextButton(
                    onPressed: onViewAll,
                    child: const Text('View All ->', style: TextStyle(fontSize: 12, color: Color(0xFF2563EB))),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Table Header & Rows
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowHeight: 36,
                dataRowMinHeight: 40,
                dataRowMaxHeight: 44,
                columnSpacing: 24,
                horizontalMargin: 8,
                headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                columns: const [
                  DataColumn(label: Text('ID', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Type', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('FPS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Details', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Severity', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Detected At', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Action', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                ],
                rows: exceptions.map((e) {
                  return DataRow(
                    cells: [
                      DataCell(Text(e.id, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                      DataCell(Text(e.type, style: TextStyle(fontSize: 12, color: _getTypeColor(e.type)))),
                      DataCell(Text(e.fps, style: const TextStyle(fontSize: 12, color: Color(0xFF334155)))),
                      DataCell(Text(e.details, style: const TextStyle(fontSize: 12, color: Color(0xFF475569)))),
                      DataCell(_buildSeverityBadge(e.severity)),
                      DataCell(Text(e.detectedAt, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)))),
                      DataCell(
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            side: const BorderSide(color: Color(0xFFBFDBFE)),
                          ),
                          onPressed: () => onActionTap?.call(e),
                          child: Text(e.action, style: const TextStyle(fontSize: 11, color: Color(0xFF2563EB))),
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
    );
  }

  Color _getTypeColor(String type) {
    if (type.contains('Demand Anomaly')) return const Color(0xFFDC2626);
    if (type.contains('Stock Shortage')) return const Color(0xFFEA580C);
    if (type.contains('Delay')) return const Color(0xFFD97706);
    return const Color(0xFF2563EB);
  }

  Widget _buildSeverityBadge(String severity) {
    Color bg = const Color(0xFFFEF2F2);
    Color fg = const Color(0xFFDC2626);
    if (severity == 'High') {
      bg = const Color(0xFFFFF7ED);
      fg = const Color(0xFFEA580C);
    } else if (severity == 'Medium') {
      bg = const Color(0xFFFFFBEB);
      fg = const Color(0xFFD97706);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        severity,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: fg),
      ),
    );
  }
}
