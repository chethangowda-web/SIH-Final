// dso_sheets.dart — On-demand operational sheets (no permanent sidebars).
// Decision trace, data-source traceability, and exception review open ONLY
// when the DSO requests them. Every row renders real backend identifiers;
// empty data renders honest empty states, never fabricated rows.
import 'package:flutter/material.dart';
import '../../models/dso/dso_models.dart';

class DsoSheets {
  static Future<void> showDecisionTrace(
    BuildContext context, {
    required List<GovernanceEventItem> events,
    required String cycleId,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _SheetShell(
        title: 'DECISION TRACE',
        subtitle: 'Cycle ${cycleId.isNotEmpty ? cycleId : 'unavailable'} • governance_audit_logs',
        child: events.isEmpty
            ? const _EmptyState(
                message: 'No activity records available for this cycle.')
            : Column(
                children: events
                    .take(30)
                    .map((e) => _TraceRow(event: e))
                    .toList(),
              ),
      ),
    );
  }

  static Future<void> showExceptions(
    BuildContext context, {
    required List<DsoExceptionItem> exceptions,
    required String cycleId,
    required void Function(DsoExceptionItem item) onOpen,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _SheetShell(
        title: 'EXCEPTION REVIEW',
        subtitle: 'Cycle ${cycleId.isNotEmpty ? cycleId : 'unavailable'} • forecast risk flags',
        child: exceptions.isEmpty
            ? const _EmptyState(message: 'No open exceptions for this cycle.')
            : Column(
                children: exceptions
                    .map((e) => _ExceptionRow(item: e, onOpen: onOpen))
                    .toList(),
              ),
      ),
    );
  }

  static Future<void> showSource(
    BuildContext context, {
    required String stageTitle,
    required List<List<String>> rows,
    required String apiEndpoint,
    required String cycleId,
    required String updatedAt,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _SheetShell(
        title: 'DATA SOURCE — $stageTitle',
        subtitle: apiEndpoint,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final r in rows) _SourceRow(label: r[0], value: r.length > 1 ? r[1] : ''),
            _SourceRow(label: 'API Endpoint', value: apiEndpoint),
            _SourceRow(
                label: 'Cycle',
                value: cycleId.isNotEmpty ? cycleId : 'unavailable'),
            _SourceRow(
                label: 'Last Updated',
                value: updatedAt.isNotEmpty ? updatedAt : 'unavailable'),
          ],
        ),
      ),
    );
  }
}

class _SheetShell extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _SheetShell(
      {required this.title, required this.subtitle, required this.child});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.72,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (ctx, controller) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                                color: Color(0xFF0B2942))),
                        const SizedBox(height: 2),
                        Text(subtitle,
                            style: const TextStyle(
                                fontSize: 11, color: Color(0xFF64748B))),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close_rounded),
                    color: const Color(0xFF64748B),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                controller: controller,
                padding: const EdgeInsets.all(20),
                child: child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String message;
  const _EmptyState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.inbox_outlined,
                size: 36, color: Color(0xFFCBD5E1)),
            const SizedBox(height: 10),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Color(0xFF94A3B8), fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

class _TraceRow extends StatelessWidget {
  final GovernanceEventItem event;
  const _TraceRow({required this.event});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: const BoxDecoration(
                color: Color(0xFFEFF6FF), shape: BoxShape.circle),
            child: const Icon(Icons.event_note_outlined,
                size: 14, color: Color(0xFF2563EB)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    event.action.isNotEmpty
                        ? event.action.replaceAll('_', ' ')
                        : 'Unlabeled event',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A))),
                if (event.entity.isNotEmpty)
                  Text(event.entity,
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF475569))),
                if (event.eventId.isNotEmpty)
                  Text('ID: ${event.eventId}',
                      style: const TextStyle(
                          fontSize: 10, color: Color(0xFF94A3B8))),
                if (event.actor.isNotEmpty)
                  Text(event.actor,
                      style: const TextStyle(
                          fontSize: 10, color: Color(0xFF94A3B8))),
                if (event.notes.isNotEmpty)
                  Text(event.notes,
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF334155))),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            event.timestamp.isNotEmpty
                ? (event.timestamp.length > 16
                    ? event.timestamp.substring(0, 16)
                    : event.timestamp)
                : '',
            style:
                const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
          ),
        ],
      ),
    );
  }
}

class _ExceptionRow extends StatelessWidget {
  final DsoExceptionItem item;
  final void Function(DsoExceptionItem item) onOpen;
  const _ExceptionRow({required this.item, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final critical = item.severity.toUpperCase() == 'CRITICAL';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          Navigator.pop(context);
          onOpen(item);
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Icon(Icons.warning_amber_rounded,
                  color: critical
                      ? const Color(0xFFDC2626)
                      : const Color(0xFFD97706),
                  size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        item.id.isNotEmpty
                            ? '${item.id} — ${item.type}'
                            : item.type,
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A))),
                    if (item.fps.isNotEmpty)
                      Text('FPS: ${item.fps}',
                          style: const TextStyle(
                              fontSize: 11, color: Color(0xFF475569))),
                    if (item.details.isNotEmpty)
                      Text(item.details,
                          style: const TextStyle(
                              fontSize: 11, color: Color(0xFF64748B))),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: Color(0xFF94A3B8)),
            ],
          ),
        ),
      ),
    );
  }
}

class _SourceRow extends StatelessWidget {
  final String label;
  final String value;
  const _SourceRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B))),
          ),
          Expanded(
            child: Text(value.isNotEmpty ? value : 'unavailable',
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F172A))),
          ),
        ],
      ),
    );
  }
}
