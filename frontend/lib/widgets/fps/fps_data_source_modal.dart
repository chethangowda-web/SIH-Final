import 'package:flutter/material.dart';
import '../../models/fps/fps_models.dart';

/// Modal dialog displaying underlying SQLite tables and provenance metadata
class FpsDataSourceModal extends StatelessWidget {
  final List<FpsDataSourceItem> sources;

  const FpsDataSourceModal({super.key, required this.sources});

  static void show(BuildContext context, List<FpsDataSourceItem> sources) {
    showDialog(
      context: context,
      builder: (ctx) => FpsDataSourceModal(sources: sources),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: const [
          Icon(Icons.storage_rounded, color: Color(0xFF1E3A8A), size: 24),
          SizedBox(width: 10),
          Text(
            'Underlying Data Sources & Provenance',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F2942)),
          ),
        ],
      ),
      content: SizedBox(
        width: 650,
        height: 400,
        child: sources.isEmpty
            ? const Center(child: Text('Data sources unavailable.'))
            : ListView.separated(
                itemCount: sources.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final src = sources[index];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(Icons.table_chart_rounded, size: 18, color: Color(0xFF1E3A8A)),
                    ),
                    title: Row(
                      children: [
                        Text(
                          src.tableName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'monospace'),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${src.totalRecords} records',
                            style: TextStyle(fontSize: 10, color: Colors.grey.shade700, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 2),
                        Text(src.description, style: const TextStyle(fontSize: 11, color: Colors.black87)),
                        const SizedBox(height: 2),
                        Text(
                          'Database: ${src.database} • Filter: ${src.fpsFilter} • Synced: ${src.lastSynced}',
                          style: TextStyle(fontSize: 10, color: Colors.grey.shade600, fontFamily: 'monospace'),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
