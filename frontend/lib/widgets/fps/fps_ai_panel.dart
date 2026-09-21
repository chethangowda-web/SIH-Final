import 'package:flutter/material.dart';
import '../../models/fps/fps_models.dart';

/// Persistent AI Operational Intelligence Panel with Explainability Drawers for FPS
class FpsAiPanel extends StatelessWidget {
  final List<FpsAiInsight> insights;
  final VoidCallback onRefresh;
  final Function(String action, FpsAiInsight insight)? onActionTriggered;

  const FpsAiPanel({
    super.key,
    required this.insights,
    required this.onRefresh,
    this.onActionTriggered,
  });

  static const Color _navy = Color(0xFF0F2942);
  static const Color _purple = Color(0xFF7C3AED);

  void _showExplainabilityDialog(BuildContext context, FpsAiInsight insight) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.psychology_alt_rounded, color: _purple, size: 24),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'AI Trace & Explainability: ${insight.title}',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _navy),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 550,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.purple.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.purple.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'RATIONALE & MATHEMATICAL REASONING',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: _purple,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      insight.why,
                      style: const TextStyle(fontSize: 13, color: Colors.black87),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'UNDERLYING DATABASE PROVENANCE',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black54),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final entry in insight.evidence.entries)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${entry.key}: ',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'monospace',
                              ),
                            ),
                            Expanded(
                              child: Text(
                                '${entry.value}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.blueGrey.shade800,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.verified_user_rounded, size: 16, color: Colors.green),
                  const SizedBox(width: 6),
                  const Text(
                    'Data backed by SQLite pds_demandsync.db master tables.',
                    style: TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close Trace'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 320,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(left: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade50,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.psychology_rounded, size: 18, color: _purple),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'AI Intelligence',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: _navy,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  tooltip: 'Recompute Signals',
                  onPressed: onRefresh,
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Insights List
          Expanded(
            child: insights.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'No AI insights available for this cycle.',
                        style: TextStyle(color: Colors.black45, fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: insights.length,
                    itemBuilder: (context, index) {
                      final item = insights[index];
                      final isHigh = item.severity == 'HIGH' || item.severity == 'CRITICAL';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isHigh ? Colors.red.shade50.withOpacity(0.5) : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isHigh ? Colors.red.shade200 : Colors.grey.shade200,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isHigh ? Colors.red.shade100 : Colors.purple.shade100,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    item.category,
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: isHigh ? Colors.red.shade800 : _purple,
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  item.severity,
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: isHigh ? Colors.red.shade700 : Colors.grey.shade700,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              item.title,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: _navy,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item.summary,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade700,
                                height: 1.3,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                TextButton.icon(
                                  onPressed: () => _showExplainabilityDialog(context, item),
                                  icon: const Icon(Icons.info_outline_rounded, size: 12, color: _purple),
                                  label: const Text(
                                    'Why? (Evidence)',
                                    style: TextStyle(fontSize: 10, color: _purple, fontWeight: FontWeight.bold),
                                  ),
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                ),
                                if (onActionTriggered != null && item.action.isNotEmpty)
                                  InkWell(
                                    onTap: () => onActionTriggered!(item.action, item),
                                    child: Text(
                                      'Take Action →',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue.shade800,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
