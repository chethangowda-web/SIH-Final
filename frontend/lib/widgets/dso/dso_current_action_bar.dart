// dso_current_action_bar.dart — Dynamic action bar for current DSO workflow stage
import 'package:flutter/material.dart';
import '../../models/dso/dso_models.dart';

class DsoCurrentActionBar extends StatelessWidget {
  final DsoWorkflowState workflowState;
  final int currentStageNum;
  final bool isActionLoading;
  final VoidCallback? onPrimaryAction;
  final VoidCallback? onViewSource;

  const DsoCurrentActionBar({
    super.key,
    required this.workflowState,
    required this.currentStageNum,
    this.isActionLoading = false,
    this.onPrimaryAction,
    this.onViewSource,
  });

  Color get _accentColor {
    if (workflowState == DsoWorkflowState.cycleClosed) return const Color(0xFF16A34A);
    switch (currentStageNum) {
      case 1: return const Color(0xFF2563EB);
      case 2: return const Color(0xFF7C3AED);
      case 3: return const Color(0xFF0891B2);
      case 4: return const Color(0xFF059669);
      case 5: return const Color(0xFFD97706);
      case 6: return const Color(0xFF0B2942);
      case 7: return const Color(0xFF16A34A);
      default: return const Color(0xFF2563EB);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isClosed = workflowState == DsoWorkflowState.cycleClosed;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _accentColor.withOpacity(0.08),
            _accentColor.withOpacity(0.03),
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _accentColor.withOpacity(0.25)),
        boxShadow: [BoxShadow(color: _accentColor.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: _accentColor.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
                child: Text(
                  isClosed ? 'CYCLE CLOSED' : 'STAGE $currentStageNum OF 7 — ${workflowState.displayLabel.toUpperCase()}',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: _accentColor, letterSpacing: 0.8),
                ),
              ),
              const Spacer(),
              Icon(Icons.info_outline, size: 16, color: _accentColor.withOpacity(0.6)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'CURRENT ACTION',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _accentColor.withOpacity(0.7), letterSpacing: 0.8),
          ),
          const SizedBox(height: 6),
          Text(
            workflowState.currentActionMessage,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF0F172A), height: 1.4),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              if (!isClosed)
                ElevatedButton.icon(
                  onPressed: isActionLoading ? null : onPrimaryAction,
                  icon: isActionLoading
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Icon(_actionIcon, size: 18),
                  label: Text(workflowState.primaryActionLabel, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accentColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              if (!isClosed) const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: onViewSource,
                icon: const Icon(Icons.storage_outlined, size: 16),
                label: const Text('View Source Data', style: TextStyle(fontSize: 13)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF475569),
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData get _actionIcon {
    switch (currentStageNum) {
      case 1: return Icons.verified_outlined;
      case 2: return Icons.assignment_turned_in_outlined;
      case 3: return Icons.route_outlined;
      case 4: return Icons.local_shipping_outlined;
      case 5: return Icons.fact_check_outlined;
      case 6: return Icons.balance_outlined;
      case 7: return Icons.lock_outlined;
      default: return Icons.arrow_forward_rounded;
    }
  }
}
