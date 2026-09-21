// dso_ai_insights_section.dart — AI insights from backend (no fabricated data)
import 'package:flutter/material.dart';
import '../../models/dso/dso_models.dart';

class DsoAiInsightsSection extends StatelessWidget {
  final List<DsoAiInsightItem> insights;
  final Map<String, dynamic> aiRecommendation;

  const DsoAiInsightsSection({super.key, required this.insights, required this.aiRecommendation});

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
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [Color(0xFF7C3AED), Color(0xFF5B21B6)], begin: Alignment.centerLeft, end: Alignment.centerRight),
              borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                const Text('AI OPERATIONAL INSIGHTS', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                const Spacer(),
                Text('${insights.length} active', style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 11)),
              ],
            ),
          ),
          if (aiRecommendation.isNotEmpty && aiRecommendation['action'] != null)
            _buildRecommendation(),
          if (insights.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.check_circle_outline, size: 32, color: Color(0xFF16A34A)),
                    SizedBox(height: 8),
                    Text('No anomalies detected for this cycle.', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                    SizedBox(height: 4),
                    Text('AI insight unavailable — no inference data', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                  ],
                ),
              ),
            )
          else
            ...insights.take(4).map((i) => _buildInsightTile(i)),
        ],
      ),
    );
  }

  Widget _buildRecommendation() {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F3FF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFDDD6FE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lightbulb_outline, color: Color(0xFF7C3AED), size: 16),
              const SizedBox(width: 6),
              const Text('Primary Recommendation', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF5B21B6), fontSize: 12)),
              const Spacer(),
              if (aiRecommendation['confidence'] != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(color: const Color(0xFFEDE9FE), borderRadius: BorderRadius.circular(10)),
                  child: Text('${aiRecommendation['confidence']}', style: const TextStyle(fontSize: 10, color: Color(0xFF7C3AED), fontWeight: FontWeight.w700)),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(aiRecommendation['action']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF0F172A))),
          if (aiRecommendation['rationale'] != null) ...[
            const SizedBox(height: 4),
            Text(aiRecommendation['rationale'].toString(), style: const TextStyle(fontSize: 12, color: Color(0xFF475569))),
          ],
        ],
      ),
    );
  }

  Widget _buildInsightTile(DsoAiInsightItem insight) {
    final severityColor = insight.severity.toUpperCase() == 'HIGH' || insight.severity.toUpperCase() == 'CRITICAL'
        ? const Color(0xFFDC2626)
        : insight.severity.toUpperCase() == 'MEDIUM'
            ? const Color(0xFFD97706)
            : const Color(0xFF2563EB);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(color: severityColor.withOpacity(0.10), borderRadius: BorderRadius.circular(8)),
                child: Text(insight.severity.toUpperCase(), style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: severityColor)),
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(insight.title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)))),
            ],
          ),
          const SizedBox(height: 4),
          Text(insight.summary, style: const TextStyle(fontSize: 12, color: Color(0xFF475569))),
          const SizedBox(height: 3),
          Text('Why: ${insight.why}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
          const SizedBox(height: 3),
          Text('Source: ${insight.evidence}', style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
          const Divider(height: 16, color: Color(0xFFF1F5F9)),
        ],
      ),
    );
  }
}
