// dso_workflow_cycle_ring.dart
import 'package:flutter/material.dart';
import '../../models/dso/dso_models.dart';

class DsoWorkflowCycleRing extends StatelessWidget {
  final DsoWorkflowState workflowState;
  final String cycleId;
  final String district;
  final int totalBeneficiaries;
  final int totalFps;
  final VoidCallback? onRefresh;

  const DsoWorkflowCycleRing({
    super.key,
    required this.workflowState,
    required this.cycleId,
    required this.district,
    this.totalBeneficiaries = 0,
    this.totalFps = 0,
    this.onRefresh,
  });

  static const _stages = [
    {'num': 1, 'label': 'Plan &\nForecast'},
    {'num': 2, 'label': 'Validate\nDemand'},
    {'num': 3, 'label': 'Approve\nAllocation'},
    {'num': 4, 'label': 'Optimize\nSupply'},
    {'num': 5, 'label': 'Authorize\nDispatch'},
    {'num': 6, 'label': 'Verify\nDelivery'},
    {'num': 7, 'label': 'Evaluate\n& Close'},
  ];

  DsoStageStatus _statusForStage(int stageNum) {
    final current = workflowState.stageNumber;
    if (workflowState == DsoWorkflowState.cycleClosed) return DsoStageStatus.completed;
    if (stageNum < current) return DsoStageStatus.completed;
    if (stageNum == current) return DsoStageStatus.current;
    return DsoStageStatus.notStarted;
  }

  Color _stageColor(DsoStageStatus status) {
    switch (status) {
      case DsoStageStatus.completed: return const Color(0xFF16A34A);
      case DsoStageStatus.current: return const Color(0xFF2563EB);
      case DsoStageStatus.blocked: return const Color(0xFFDC2626);
      case DsoStageStatus.pending: return const Color(0xFFD97706);
      default: return const Color(0xFF94A3B8);
    }
  }

  Color _stageBg(DsoStageStatus status) {
    switch (status) {
      case DsoStageStatus.completed: return const Color(0xFFDCFCE7);
      case DsoStageStatus.current: return const Color(0xFFEFF6FF);
      case DsoStageStatus.blocked: return const Color(0xFFFEF2F2);
      case DsoStageStatus.pending: return const Color(0xFFFEF3C7);
      default: return const Color(0xFFF1F5F9);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentStageNum = workflowState.stageNumber;
    final progressPct = workflowState == DsoWorkflowState.cycleClosed ? 1.0 : (currentStageNum - 1) / 6.0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [BoxShadow(color: const Color(0xFF0B2942).withOpacity(0.06), blurRadius: 20, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [Color(0xFF0B2942), Color(0xFF1E3A8A)], begin: Alignment.centerLeft, end: Alignment.centerRight),
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.account_balance, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('DSO COMMAND CYCLE', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
                      const SizedBox(height: 2),
                      Text('Cycle $cycleId  •  $district', style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 12)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      workflowState == DsoWorkflowState.cycleClosed ? 'CYCLE CLOSED' : 'Stage $currentStageNum of 7',
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      width: 120,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(value: progressPct, backgroundColor: Colors.white.withOpacity(0.2), valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF34D399)), minHeight: 6),
                      ),
                    ),
                  ],
                ),
                if (onRefresh != null) ...[
                  const SizedBox(width: 16),
                  IconButton(onPressed: onRefresh, icon: const Icon(Icons.refresh, color: Colors.white, size: 18), tooltip: 'Refresh', padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 28, minHeight: 28)),
                ],
              ],
            ),
          ),

          // Stage nodes — horizontal on desktop/tablet, vertical chain on mobile.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: LayoutBuilder(
              builder: (ctx, constraints) {
                if (constraints.maxWidth < 600) {
                  return Column(
                    children: [
                      for (int i = 0; i < _stages.length; i++) ...[
                        _buildStageNodeWide(_stages[i]),
                        if (i < _stages.length - 1) _buildVerticalConnector(_statusForStage(i + 2)),
                      ],
                    ],
                  );
                }
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (int i = 0; i < _stages.length; i++) ...[
                        _buildStageNode(_stages[i], i),
                        if (i < _stages.length - 1) _buildConnector(_statusForStage(i + 2)),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),

          // Footer
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
              border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              children: [
                _buildCtx(Icons.people_outline, totalBeneficiaries > 0 ? '${_fmt(totalBeneficiaries)} Beneficiaries' : 'Beneficiaries: loading...', const Color(0xFF2563EB)),
                const SizedBox(width: 16),
                _buildCtx(Icons.store_outlined, totalFps > 0 ? '$totalFps FPS Shops' : 'FPS: loading...', const Color(0xFF0891B2)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _stageColor(_statusForStage(currentStageNum)).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _stageColor(_statusForStage(currentStageNum)).withOpacity(0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 6, height: 6, decoration: BoxDecoration(color: _stageColor(_statusForStage(currentStageNum)), shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                      Text(workflowState.displayLabel, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _stageColor(_statusForStage(currentStageNum)))),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStageNode(Map<String, Object> stage, int index) {
    final stageNum = stage['num'] as int;
    final status = _statusForStage(stageNum);
    final color = _stageColor(status);
    final bgColor = _stageBg(status);
    final isCurrent = status == DsoStageStatus.current;
    final isCompleted = status == DsoStageStatus.completed;

    return SizedBox(
      width: 86,
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: isCurrent ? 56 : 48,
            height: isCurrent ? 56 : 48,
            decoration: BoxDecoration(
              color: bgColor,
              shape: BoxShape.circle,
              border: Border.all(color: color, width: isCurrent ? 2.5 : 1.5),
              boxShadow: isCurrent ? [BoxShadow(color: color.withOpacity(0.3), blurRadius: 12, spreadRadius: 2)] : null,
            ),
            child: Center(
              child: isCompleted
                  ? Icon(Icons.check_rounded, color: color, size: 20)
                  : Text('0$stageNum', style: TextStyle(color: color, fontSize: isCurrent ? 14 : 12, fontWeight: FontWeight.w800)),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            stage['label'] as String,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isCurrent ? 11 : 10,
              fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
              color: isCurrent ? const Color(0xFF0F172A) : isCompleted ? const Color(0xFF16A34A) : const Color(0xFF64748B),
              height: 1.3,
            ),
          ),
          const SizedBox(height: 4),
          if (isCurrent)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
              child: const Text('CURRENT', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.5)),
            ),
        ],
      ),
    );
  }

  Widget _buildStageNodeWide(Map<String, Object> stage) {
    final stageNum = stage['num'] as int;
    final status = _statusForStage(stageNum);
    final color = _stageColor(status);
    final bgColor = _stageBg(status);
    final isCurrent = status == DsoStageStatus.current;
    final isCompleted = status == DsoStageStatus.completed;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: isCurrent ? 2 : 1),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 1.5),
            ),
            child: Center(
              child: isCompleted
                  ? Icon(Icons.check_rounded, color: color, size: 18)
                  : Text('0$stageNum',
                      style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w800)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              (stage['label'] as String).replaceAll('\n', ' '),
              style: TextStyle(
                fontSize: 13,
                fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                color: const Color(0xFF0F172A),
              ),
            ),
          ),
          Text(
            status.label,
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: color),
          ),
          if (isCurrent) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
              child: const Text('CURRENT',
                  style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: Colors.white)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVerticalConnector(DsoStageStatus nextStatus) {
    final active =
        nextStatus == DsoStageStatus.completed || nextStatus == DsoStageStatus.current;
    return Container(
      width: 2,
      height: 18,
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: active ? const Color(0xFF16A34A) : const Color(0xFFCBD5E1),
        borderRadius: BorderRadius.circular(1),
      ),
    );
  }

  Widget _buildConnector(DsoStageStatus nextStatus) {
    final active = nextStatus == DsoStageStatus.completed || nextStatus == DsoStageStatus.current;
    return Container(
      width: 24,
      height: 2,
      margin: const EdgeInsets.only(bottom: 28),
      decoration: BoxDecoration(
        color: active ? const Color(0xFF16A34A) : const Color(0xFFCBD5E1),
        borderRadius: BorderRadius.circular(1),
      ),
    );
  }

  Widget _buildCtx(IconData icon, String label, Color color) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 14, color: color),
      const SizedBox(width: 5),
      Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF334155))),
    ]);
  }

  String _fmt(int n) {
    if (n >= 100000) return '${(n / 100000).toStringAsFixed(1)}L';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }
}
