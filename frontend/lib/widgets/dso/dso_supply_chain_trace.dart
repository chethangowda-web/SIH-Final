// dso_supply_chain_trace.dart — Horizontal supply chain visualization
import 'package:flutter/material.dart';
import '../../models/dso/dso_models.dart';

class DsoSupplyChainTrace extends StatelessWidget {
  final DsoWorkflowState workflowState;
  final Map<String, dynamic> demandBreakdown;

  const DsoSupplyChainTrace({
    super.key,
    required this.workflowState,
    required this.demandBreakdown,
  });

  String _nodeStatus(String nodeId) {
    final stage = workflowState.stageNumber;
    switch (nodeId) {
      case 'demand':
        return stage >= 1 ? 'COMPLETED' : 'PENDING';
      case 'validation':
        return stage >= 2 ? 'COMPLETED' : (stage == 1 ? 'PENDING' : 'NOT_STARTED');
      case 'allocation':
        return stage >= 3 ? 'COMPLETED' : (stage == 2 ? 'ACTIVE' : 'NOT_STARTED');
      case 'manifest':
        return stage >= 5 ? 'COMPLETED' : (stage >= 3 ? 'ACTIVE' : 'NOT_STARTED');
      case 'truck':
        return stage >= 5 ? (stage >= 6 ? 'COMPLETED' : 'ACTIVE') : 'NOT_STARTED';
      case 'delivery':
        return stage >= 6 ? 'COMPLETED' : (stage == 5 ? 'ACTIVE' : 'NOT_STARTED');
      case 'fps_receipt':
        return stage >= 6 ? 'COMPLETED' : 'NOT_STARTED';
      case 'epos':
        return stage == 7 ? 'COMPLETED' : 'NOT_STARTED';
      default:
        return 'NOT_STARTED';
    }
  }

  Color _nodeColor(String status) {
    switch (status) {
      case 'COMPLETED': return const Color(0xFF16A34A);
      case 'ACTIVE': return const Color(0xFF2563EB);
      case 'BLOCKED': return const Color(0xFFDC2626);
      case 'PENDING': return const Color(0xFFD97706);
      default: return const Color(0xFF94A3B8);
    }
  }

  @override
  Widget build(BuildContext context) {
    final nodes = [
      {'id': 'demand', 'label': 'DEMAND', 'sub': 'Intent / Baseline'},
      {'id': 'validation', 'label': 'VALIDATION', 'sub': 'DSO Sealed Snapshot'},
      {'id': 'allocation', 'label': 'ALLOCATION', 'sub': 'Stock Assigned'},
      {'id': 'manifest', 'label': 'MANIFEST', 'sub': 'Dispatch Order'},
      {'id': 'truck', 'label': 'TRUCK', 'sub': 'In Transit'},
      {'id': 'delivery', 'label': 'DELIVERY', 'sub': 'FPS Arrival'},
      {'id': 'fps_receipt', 'label': 'FPS RECEIPT', 'sub': 'Received Qty'},
      {'id': 'epos', 'label': 'e-PoS', 'sub': 'Distributed'},
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.account_tree_outlined, size: 18, color: Color(0xFF0891B2)),
              const SizedBox(width: 8),
              const Text('SUPPLY CHAIN TRACE', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A), letterSpacing: 0.5)),
              const Spacer(),
              Text('District: all FPS', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
            ],
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (int i = 0; i < nodes.length; i++) ...[
                  _buildNode(nodes[i]),
                  if (i < nodes.length - 1) _buildArrow(_nodeStatus(nodes[i]['id']!)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNode(Map<String, String> node) {
    final status = _nodeStatus(node['id']!);
    final color = _nodeColor(status);
    final isActive = status == 'ACTIVE' || status == 'COMPLETED';

    return SizedBox(
      width: 100,
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isActive ? color.withOpacity(0.12) : const Color(0xFFF1F5F9),
              shape: BoxShape.circle,
              border: Border.all(color: isActive ? color : const Color(0xFFCBD5E1), width: status == 'ACTIVE' ? 2.0 : 1.5),
            ),
            child: Center(
              child: status == 'COMPLETED'
                  ? Icon(Icons.check_rounded, color: color, size: 20)
                  : status == 'ACTIVE'
                      ? Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle))
                      : Icon(Icons.circle_outlined, color: const Color(0xFFCBD5E1), size: 12),
            ),
          ),
          const SizedBox(height: 6),
          Text(node['label']!, textAlign: TextAlign.center, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: isActive ? const Color(0xFF0F172A) : const Color(0xFF94A3B8), letterSpacing: 0.3)),
          Text(node['sub']!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 8, color: Color(0xFFB0B8C4)), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(color: color.withOpacity(0.10), borderRadius: BorderRadius.circular(8)),
            child: Text(status.replaceAll('_', ' '), style: TextStyle(fontSize: 7, fontWeight: FontWeight.w700, color: color), maxLines: 1),
          ),
        ],
      ),
    );
  }

  Widget _buildArrow(String prevStatus) {
    final active = prevStatus == 'COMPLETED' || prevStatus == 'ACTIVE';
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 16, height: 1.5, color: active ? const Color(0xFF2563EB) : const Color(0xFFCBD5E1)),
          Icon(Icons.arrow_forward_ios_rounded, size: 8, color: active ? const Color(0xFF2563EB) : const Color(0xFFCBD5E1)),
        ],
      ),
    );
  }
}
