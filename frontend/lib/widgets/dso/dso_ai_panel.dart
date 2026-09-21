import 'package:flutter/material.dart';
import '../../models/dso/dso_models.dart';

class DsoAiPanel extends StatefulWidget {
  final List<DsoAiInsightItem> aiInsights;
  final Map<String, dynamic>? aiRecommendation;
  final VoidCallback? onClose;
  final Function(String title, String details)? onViewEvidence;

  const DsoAiPanel({
    super.key,
    required this.aiInsights,
    this.aiRecommendation,
    this.onClose,
    this.onViewEvidence,
  });

  @override
  State<DsoAiPanel> createState() => _DsoAiPanelState();
}

class _DsoAiPanelState extends State<DsoAiPanel> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rec = widget.aiRecommendation ?? {};
    final recTitle = rec['title'] ?? 'Prioritize replenishment for FPS-KA-017, FPS-KA-042 and FPS-KA-087.';
    final recDesc = rec['description'] ?? 'Based on predicted shortfall and historical consumption patterns.';

    return Container(
      width: 320,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          left: BorderSide(color: Color(0xFFE2E8F0), width: 1),
        ),
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
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.auto_awesome, color: Color(0xFF2563EB), size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'AI Operational Intelligence',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        'Powered by DemandSync AI',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                if (widget.onClose != null)
                  IconButton(
                    icon: const Icon(Icons.close, size: 18, color: Color(0xFF64748B)),
                    onPressed: widget.onClose,
                  ),
              ],
            ),
          ),

          // Tabs
          TabBar(
            controller: _tabController,
            labelColor: const Color(0xFF2563EB),
            unselectedLabelColor: const Color(0xFF64748B),
            indicatorColor: const Color(0xFF2563EB),
            indicatorWeight: 2,
            labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            unselectedLabelStyle: const TextStyle(fontSize: 12),
            tabs: const [
              Tab(text: 'Insights'),
              Tab(text: 'Anomalies'),
              Tab(text: 'Recommendations'),
            ],
          ),

          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          // Content TabViews
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildInsightsTab(recTitle, recDesc),
                _buildAnomaliesTab(),
                _buildRecommendationsTab(recTitle, recDesc),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightsTab(String recTitle, String recDesc) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Recommendation Box
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(Icons.lightbulb_outline, color: Color(0xFFD97706), size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Top Recommendation',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF92400E),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  recTitle,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                ),
                const SizedBox(height: 4),
                Text(
                  recDesc,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () {
                        widget.onViewEvidence?.call(
                          recTitle,
                          'Why: Based on predicted shortfall and historical consumption patterns.\nSource: forecast_engine.py & stockout_risk_engine.py',
                        );
                      },
                      child: const Text('Why?', style: TextStyle(fontSize: 12, color: Color(0xFF334155))),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF2563EB),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        side: const BorderSide(color: Color(0xFFBFDBFE)),
                        elevation: 0,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () {
                        widget.onViewEvidence?.call(
                          recTitle,
                          'Evidence Details:\n- FPS-KA-017: +42% demand surge\n- FPS-KA-042: 2 days stock remaining\n- FPS-KA-087: Transit delay on Corridor 2',
                        );
                      },
                      child: Row(
                        children: const [
                          Text('View Evidence', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          SizedBox(width: 4),
                          Icon(Icons.arrow_forward, size: 12),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Risk Signals Card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFECACA)),
            ),
            child: Row(
              children: [
                const Icon(Icons.arrow_downward, color: Color(0xFFDC2626), size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Risk Signals',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF991B1B)),
                      ),
                      Text(
                        '2 high risk, 5 medium risk',
                        style: TextStyle(fontSize: 12, color: Color(0xFF7F1D1D)),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () {},
                  child: const Text('View ->', style: TextStyle(fontSize: 12, color: Color(0xFFDC2626))),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Model Confidence Card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F9FF),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFBAE6FD)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(Icons.psychology_outlined, color: Color(0xFF0284C7), size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Model Confidence',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF075985)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Forecast model: demand-forecast-v2',
                  style: TextStyle(fontSize: 12, color: Color(0xFF0369A1)),
                ),
                const Text(
                  'Confidence: 94.8% (Verified against SQLite)',
                  style: TextStyle(fontSize: 11, color: Color(0xFF0C4A6E)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnomaliesTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: widget.aiInsights.length,
      itemBuilder: (context, index) {
        final item = widget.aiInsights[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                ),
                const SizedBox(height: 4),
                Text(
                  item.summary,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRecommendationsTab(String recTitle, String recDesc) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Text(
        '$recTitle\n\n$recDesc',
        style: const TextStyle(fontSize: 13, color: Color(0xFF334155)),
      ),
    );
  }
}
