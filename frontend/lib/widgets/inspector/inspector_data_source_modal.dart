import 'package:flutter/material.dart';

/// Transparency & Audit Modal Dialog for Field Food Inspector
/// Shows database table, query, and formula backing any displayed metric
class InspectorDataSourceModal extends StatelessWidget {
  final String title;
  final String datasetName;
  final String tableName;
  final String cycleId;
  final String recordCount;
  final String formula;
  final String apiEndpoint;

  const InspectorDataSourceModal({
    super.key,
    required this.title,
    required this.datasetName,
    required this.tableName,
    required this.cycleId,
    required this.recordCount,
    required this.formula,
    required this.apiEndpoint,
  });

  static void show(
    BuildContext context, {
    required String title,
    required String datasetName,
    required String tableName,
    required String cycleId,
    required String recordCount,
    required String formula,
    required String apiEndpoint,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => InspectorDataSourceModal(
        title: title,
        datasetName: datasetName,
        tableName: tableName,
        cycleId: cycleId,
        recordCount: recordCount,
        formula: formula,
        apiEndpoint: apiEndpoint,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      contentPadding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(Icons.storage, color: Color(0xFF2563EB), size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Data Source & Audit Traceability',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
                Text(
                  title,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      content: SizedBox(
        width: 500,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('Database Engine', 'SQLite 3 (WAL Mode) • backend/pds_demandsync.db'),
            _buildDetailRow('Dataset Source', datasetName),
            _buildDetailRow('Primary Table', tableName),
            _buildDetailRow('Active Cycle Filter', cycleId),
            _buildDetailRow('Authoritative Rows', recordCount),
            _buildDetailRow('API Route', apiEndpoint),
            const SizedBox(height: 12),
            const Text(
              'Calculation Formula & SQL Invariant:',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
            ),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                formula,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  color: Color(0xFF38BDF8),
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close Trace'),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 11, color: Color(0xFF1E293B), fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
