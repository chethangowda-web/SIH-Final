import 'package:flutter/material.dart';
import '../../models/dso/dso_models.dart';

class DsoDecisionTraceDrawer extends StatelessWidget {
  final List<GovernanceEventItem> events;
  final VoidCallback onClose;

  const DsoDecisionTraceDrawer({
    super.key,
    required this.events,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 360,
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFF0F172A),
            ),
            child: Row(
              children: [
                const Icon(Icons.timeline, color: Color(0xFF60A5FA), size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Decision Trace & Audit Log',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      Text(
                        'Immutable Audit Trail • SQLite Backed',
                        style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 20),
                  onPressed: onClose,
                ),
              ],
            ),
          ),

          // Events Timeline List
          Expanded(
            child: events.isEmpty
                ? const Center(child: Text('No decision trace records found.', style: TextStyle(color: Color(0xFF64748B))))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: events.length,
                    itemBuilder: (context, index) {
                      final item = events[index];
                      final isLast = index == events.length - 1;
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Timestamp column
                          SizedBox(
                            width: 54,
                            child: Text(
                              _formatTime(item.timestamp),
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                            ),
                          ),

                          // Node line & indicator
                          Column(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: _getNodeColor(item.eventType),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              if (!isLast)
                                Container(
                                  width: 2,
                                  height: 60,
                                  color: const Color(0xFFCBD5E1),
                                ),
                            ],
                          ),
                          const SizedBox(width: 12),

                          // Event Content Box
                          Expanded(
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.actor,
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    item.notes,
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF475569)),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Entity: ${item.entity}',
                                    style: const TextStyle(fontSize: 10, color: Color(0xFF64748B), fontFamily: 'monospace'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  String _formatTime(String raw) {
    if (raw.contains(' ')) {
      final parts = raw.split(' ');
      return parts.last.length >= 5 ? parts.last.substring(0, 5) : parts.last;
    }
    return raw.length >= 5 ? raw.substring(0, 5) : raw;
  }

  Color _getNodeColor(String type) {
    if (type.contains('AI')) return const Color(0xFF2563EB);
    if (type.contains('DSO')) return const Color(0xFF16A34A);
    if (type.contains('CLOSED')) return const Color(0xFF7C3AED);
    return const Color(0xFF64748B);
  }
}
