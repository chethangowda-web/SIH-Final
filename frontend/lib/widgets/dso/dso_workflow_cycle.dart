// dso_workflow_cycle.dart — The DSO workflow IS the UI.
// Desktop: circular 7-stage operational cycle with dominant active stage.
// Mobile (<600px): vertical 01 -> 07 connected chain (same concept, not a shrunk desktop).
// Stage status derives ONLY from backend DsoWorkflowState. Tapping a stage
// selects it for inspection in the workspace below; a tap is never a transition.
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../models/dso/dso_models.dart';

class DsoWorkflowCycle extends StatelessWidget {
  final DsoWorkflowState workflowState;
  final String cycleId;
  final String district;
  final int selectedStage;
  final ValueChanged<int> onSelectStage;
  final String dataLastUpdated;

  const DsoWorkflowCycle({
    super.key,
    required this.workflowState,
    required this.cycleId,
    required this.district,
    required this.selectedStage,
    required this.onSelectStage,
    required this.dataLastUpdated,
  });

  static const _stages = [
    {'num': 1, 'title': 'MONITOR', 'sub': '& Triage'},
    {'num': 2, 'title': 'VALIDATE', 'sub': 'Demand'},
    {'num': 3, 'title': 'ALLOCATE', 'sub': 'Stock'},
    {'num': 4, 'title': 'OPTIMIZE', 'sub': 'Routes'},
    {'num': 5, 'title': 'AUTHORIZE', 'sub': 'Dispatch'},
    {'num': 6, 'title': 'VERIFY', 'sub': 'Delivery'},
    {'num': 7, 'title': 'EVALUATE', 'sub': '& Close'},
  ];

  DsoStageStatus _statusFor(int stageNum) {
    final current = workflowState.stageNumber;
    if (workflowState == DsoWorkflowState.cycleClosed) return DsoStageStatus.completed;
    if (workflowState == DsoWorkflowState.unknown) return DsoStageStatus.notStarted;
    if (stageNum < current) return DsoStageStatus.completed;
    if (stageNum == current) return DsoStageStatus.current;
    return DsoStageStatus.notStarted;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
              color: const Color(0xFF0B2942).withValues(alpha: 0.06),
              blurRadius: 20,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        children: [
          _buildIdentityHeader(),
          LayoutBuilder(
            builder: (ctx, constraints) {
              if (constraints.maxWidth < 620) {
                return _buildVerticalChain();
              }
              return _buildCircularCycle(constraints.maxWidth);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildIdentityHeader() {
    final current = workflowState.stageNumber;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
            colors: [Color(0xFF0B2942), Color(0xFF1E3A8A)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('DSO COMMAND CENTER',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2)),
                const SizedBox(height: 2),
                Text(
                  'Cycle ${cycleId.isNotEmpty ? cycleId : 'unavailable'}  •  ${district.isNotEmpty ? district : 'unavailable'}',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 12),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                workflowState == DsoWorkflowState.cycleClosed
                    ? 'CYCLE CLOSED'
                    : 'STAGE $current OF 7 — ${workflowState.displayLabel.toUpperCase()}',
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 2),
              Text(
                dataLastUpdated.isNotEmpty ? 'Updated $dataLastUpdated' : 'Update time unavailable',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Desktop: true circular cycle ──────────────────────────────────────
  Widget _buildCircularCycle(double maxWidth) {
    const size = 460.0;
    const centerBox = 168.0;
    const nodeBox = 104.0;
    final radius = (size / 2) - (nodeBox / 2) - 8;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Ring track.
            Container(
              width: size - nodeBox,
              height: size - nodeBox,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE2E8F0), width: 2),
              ),
            ),
            // Center hub: the operational answer in 5 seconds.
            _buildHub(centerBox),
            // 7 stage nodes around the ring, starting at top going clockwise.
            for (int i = 0; i < _stages.length; i++)
              _buildOrbitNode(_stages[i], i, radius, size, nodeBox),
          ],
        ),
      ),
    );
  }

  Widget _buildHub(double box) {
    final current = workflowState.stageNumber;
    final progress =
        workflowState == DsoWorkflowState.cycleClosed ? 1.0 : (current - 1) / 6.0;
    return Container(
      width: box,
      height: box,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
            colors: [Color(0xFF0B2942), Color(0xFF1E3A8A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
        boxShadow: [
          BoxShadow(
              color: const Color(0xFF1E3A8A).withValues(alpha: 0.35),
              blurRadius: 24,
              spreadRadius: 2)
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('STAGE $current OF 7',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0)),
          const SizedBox(height: 4),
          Text(workflowState.displayLabel,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800, height: 1.2)),
          const SizedBox(height: 8),
          SizedBox(
            width: 96,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF34D399)),
                  minHeight: 6),
            ),
          ),
          const SizedBox(height: 4),
          Text('${(progress * 100).toStringAsFixed(0)}% complete',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7), fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildOrbitNode(Map<String, Object> stage, int index, double radius,
      double size, double nodeBox) {
    final stageNum = stage['num'] as int;
    final status = _statusFor(stageNum);
    // Start at top (-90°) and go clockwise.
    final angle = -math.pi / 2 + (2 * math.pi * index / _stages.length);
    final dx = radius * math.cos(angle);
    final dy = radius * math.sin(angle);
    final isSelected = selectedStage == stageNum;

    return Positioned(
      left: size / 2 + dx - nodeBox / 2,
      top: size / 2 + dy - 34,
      child: GestureDetector(
        onTap: () => onSelectStage(stageNum),
        child: _nodeContent(stage, status, isSelected, compact: false),
      ),
    );
  }

  // ── Mobile: vertical 01 ↓ 07 chain ────────────────────────────────────
  Widget _buildVerticalChain() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Column(
        children: [
          for (int i = 0; i < _stages.length; i++) ...[
            GestureDetector(
              onTap: () => onSelectStage(_stages[i]['num'] as int),
              child: _chainRow(_stages[i]),
            ),
            if (i < _stages.length - 1) _chainArrow(_statusFor(i + 2)),
          ],
        ],
      ),
    );
  }

  Widget _chainRow(Map<String, Object> stage) {
    final stageNum = stage['num'] as int;
    final status = _statusFor(stageNum);
    final color = _colorFor(status);
    final isSelected = selectedStage == stageNum;
    final isCurrent = status == DsoStageStatus.current;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isSelected ? color.withValues(alpha: 0.08) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isSelected ? color : const Color(0xFFE2E8F0),
            width: isSelected ? 2 : 1),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: status == DsoStageStatus.completed
                  ? const Color(0xFFDCFCE7)
                  : isCurrent
                      ? const Color(0xFFEFF6FF)
                      : const Color(0xFFF1F5F9),
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 1.5),
            ),
            child: Center(
              child: status == DsoStageStatus.completed
                  ? Icon(Icons.check_rounded, color: color, size: 18)
                  : status == DsoStageStatus.notStarted
                      ? Icon(Icons.lock_outline_rounded,
                          color: color, size: 15)
                      : Text('0$stageNum',
                          style: TextStyle(
                              color: color,
                              fontSize: 12,
                              fontWeight: FontWeight.w800)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('0$stageNum — ${(stage['title'] as String)} ${(stage['sub'] as String)}',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                Text(status.label,
                    style: TextStyle(
                        fontSize: 10, fontWeight: FontWeight.w800, color: color)),
              ],
            ),
          ),
          if (isCurrent)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration:
                  BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
              child: const Text('CURRENT',
                  style: TextStyle(
                      fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white)),
            ),
        ],
      ),
    );
  }

  Widget _chainArrow(DsoStageStatus next) {
    final active = next == DsoStageStatus.completed || next == DsoStageStatus.current;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Icon(Icons.arrow_downward_rounded,
          size: 16,
          color: active ? const Color(0xFF16A34A) : const Color(0xFFCBD5E1)),
    );
  }

  // ── Shared node content (circular layout) ─────────────────────────────
  Widget _nodeContent(
      Map<String, Object> stage, DsoStageStatus status, bool isSelected,
      {required bool compact}) {
    final stageNum = stage['num'] as int;
    final color = _colorFor(status);
    final isCurrent = status == DsoStageStatus.current;
    final isCompleted = status == DsoStageStatus.completed;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: isCurrent ? 62 : 52,
          height: isCurrent ? 62 : 52,
          decoration: BoxDecoration(
            color: isCompleted
                ? const Color(0xFFDCFCE7)
                : isCurrent
                    ? const Color(0xFFEFF6FF)
                    : Colors.white,
            shape: BoxShape.circle,
            border: Border.all(
                color: isSelected ? const Color(0xFF0B2942) : color,
                width: isSelected ? 3 : (isCurrent ? 2.5 : 1.5)),
            boxShadow: isCurrent
                ? [
                    BoxShadow(
                        color: color.withValues(alpha: 0.35),
                        blurRadius: 14,
                        spreadRadius: 2)
                  ]
                : null,
          ),
          child: Center(
            child: isCompleted
                ? Icon(Icons.check_rounded, color: color, size: 22)
                : status == DsoStageStatus.notStarted
                    ? Icon(Icons.lock_outline_rounded, color: color, size: 17)
                    : Text('0$stageNum',
                        style: TextStyle(
                            color: color,
                            fontSize: isCurrent ? 15 : 13,
                            fontWeight: FontWeight.w800)),
          ),
        ),
        const SizedBox(height: 5),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF0B2942) : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.4)),
          ),
          child: Text(
            '${stage['title']}',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: isSelected ? Colors.white : const Color(0xFF0F172A)),
          ),
        ),
        Text('${stage['sub']}',
            style: const TextStyle(fontSize: 8, color: Color(0xFF64748B))),
      ],
    );
  }

  Color _colorFor(DsoStageStatus status) {
    switch (status) {
      case DsoStageStatus.completed:
        return const Color(0xFF16A34A);
      case DsoStageStatus.current:
        return const Color(0xFF2563EB);
      case DsoStageStatus.blocked:
        return const Color(0xFFDC2626);
      case DsoStageStatus.pending:
        return const Color(0xFFD97706);
      case DsoStageStatus.notStarted:
        return const Color(0xFF94A3B8);
    }
  }
}
