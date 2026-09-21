import 'package:flutter/material.dart';

class DsoDataSourceModal extends StatelessWidget {
  final String title;
  final String datasetName;
  final String tableName;
  final String cycleId;
  final String recordCount;
  final String formula;
  final String apiEndpoint;

  const DsoDataSourceModal({
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
      builder: (ctx) => DsoDataSourceModal(
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
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(Icons.storage_rounded, color: Color(0xFF2563EB), size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Data Source Traceability — $title',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Every value displayed in PDS DemandSync is derived directly from real database records and physical datasets.',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 16),

            _buildDetailRow('Source Dataset:', datasetName),
            _buildDetailRow('Database Table:', tableName),
            _buildDetailRow('API Endpoint:', apiEndpoint),
            _buildDetailRow('Active Cycle:', cycleId),
            _buildDetailRow('Evaluated Records:', recordCount),

            const SizedBox(height: 12),
            const Text('Deterministic Calculation Formula:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Text(
                formula,
                style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: Color(0xFF0F172A)),
              ),
            ),
          ],
        ),
      ),
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close Traceability View'),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
          ),
        ],
      ),
    );
  }
}
