// dso_activity_timeline.dart — Governance events timeline from /admin/governance-events
import 'package:flutter/material.dart';
import '../../models/dso/dso_models.dart';

class DsoActivityTimeline extends StatelessWidget {
  final List<GovernanceEventItem> events;
  final bool isLoading;

  const DsoActivityTimeline({super.key, required this.events, this.isLoading = false});

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
                const Icon(Icons.timeline_outlined, size: 18, color: Color(0xFF0B2942)),
                const SizedBox(width: 8),
                const Text('RECENT ACTIVITY', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A), letterSpacing: 0.5)),
                const Spacer(),
                Text('${events.length} events', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          if (isLoading)
            const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
          else if (events.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.history_toggle_off_outlined, size: 32, color: Color(0xFFCBD5E1)),
                    SizedBox(height: 8),
                    Text('No activity records available for this cycle.', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
                  ],
                ),
              ),
            )
          else
            ...events.take(8).map((event) => _buildEventTile(event)),
        ],
      ),
    );
  }

  Widget _buildEventTile(GovernanceEventItem event) {
    final color = _colorForEvent(event.eventType);
    final icon = _iconForEvent(event.eventType);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(color: color.withOpacity(0.10), shape: BoxShape.circle),
            child: Icon(icon, size: 14, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(event.action.replaceAll('_', ' '), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
                const SizedBox(height: 2),
                Text(event.entity, style: const TextStyle(fontSize: 11, color: Color(0xFF475569)), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(event.actor, style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _formatTs(event.timestamp),
            style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
          ),
        ],
      ),
    );
  }

  Color _colorForEvent(String type) {
    if (type.contains('CLOSED') || type.contains('APPROVED') || type.contains('VALIDATED')) return const Color(0xFF16A34A);
    if (type.contains('EXCEPTION') || type.contains('FAILED') || type.contains('DEFICIT')) return const Color(0xFFDC2626);
    if (type.contains('DISPATCH')) return const Color(0xFFD97706);
    if (type.contains('INSPECTION')) return const Color(0xFF7C3AED);
    return const Color(0xFF2563EB);
  }

  IconData _iconForEvent(String type) {
    if (type.contains('CLOSED')) return Icons.lock_outlined;
    if (type.contains('APPROVED') || type.contains('VALIDATED')) return Icons.check_circle_outline;
    if (type.contains('EXCEPTION')) return Icons.warning_amber_outlined;
    if (type.contains('DISPATCH') || type.contains('MANIFEST')) return Icons.local_shipping_outlined;
    if (type.contains('INSPECTION')) return Icons.fact_check_outlined;
    if (type.contains('ALLOCATED')) return Icons.inventory_2_outlined;
    return Icons.event_note_outlined;
  }

  String _formatTs(String ts) {
    if (ts.isEmpty) return '';
    try {
      final dt = DateTime.parse(ts.replaceAll(' UTC+05:30', '').replaceAll(' ', 'T'));
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return '${dt.day}/${dt.month}';
    } catch (_) {
      return ts.length > 10 ? ts.substring(0, 10) : ts;
    }
  }
}
