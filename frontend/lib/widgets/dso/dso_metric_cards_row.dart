// dso_metric_cards_row.dart — Real operational metrics from backend
import 'package:flutter/material.dart';
import '../../models/dso/dso_models.dart';

class DsoMetricCardsRow extends StatelessWidget {
  final DsoCommandOverview overview;

  const DsoMetricCardsRow({super.key, required this.overview});

  @override
  Widget build(BuildContext context) {
    final m = overview.metrics;

    String fmtKg(double? kg) {
      if (kg == null) return 'N/A';
      if (kg == 0) return 'No records';
      if (kg >= 1000000) return '${(kg / 1000000).toStringAsFixed(1)}M kg';
      if (kg >= 1000) return '${(kg / 1000).toStringAsFixed(1)} MT';
      return '${kg.toStringAsFixed(0)} kg';
    }

    String fmtCount(double? count) {
      if (count == null || count == 0) return 'No records';
      if (count >= 100000) return '${(count / 100000).toStringAsFixed(2)}L';
      if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
      return count.toInt().toString();
    }

    final cards = [
      _MetricDef(
        title: 'Total Beneficiaries',
        value: m.containsKey('beneficiaries') ? fmtCount(m['beneficiaries']!.count) : 'No records',
        icon: Icons.people_alt_outlined,
        color: const Color(0xFF2563EB),
        sub: 'Registered in district',
        source: 'beneficiaries table',
      ),
      _MetricDef(
        title: 'FPS Under Management',
        value: m.containsKey('fps') ? (m['fps']!.count.toInt().toString()) : 'No records',
        icon: Icons.store_outlined,
        color: const Color(0xFF0891B2),
        sub: 'Fair Price Shops',
        source: 'fps table',
      ),
      _MetricDef(
        title: 'Intent Demand',
        value: m.containsKey('intent_demand') ? fmtKg(m['intent_demand']!.count) : 'No records',
        icon: Icons.how_to_vote_outlined,
        color: const Color(0xFF7C3AED),
        sub: 'Citizen declared intent',
        source: 'intent table',
      ),
      _MetricDef(
        title: 'Forecast Demand',
        value: m.containsKey('forecast_demand') ? fmtKg(m['forecast_demand']!.count) : 'No records',
        icon: Icons.analytics_outlined,
        color: const Color(0xFF059669),
        sub: 'ML forecast for cycle',
        source: 'forecast table',
      ),
      _MetricDef(
        title: 'Allocated Stock',
        value: m.containsKey('allocated') ? fmtKg(m['allocated']!.count) : 'No records',
        icon: Icons.inventory_2_outlined,
        color: const Color(0xFFD97706),
        sub: 'Approved allocation',
        source: 'forecast/dispatch tables',
      ),
      _MetricDef(
        title: 'Dispatched Stock',
        value: m.containsKey('dispatched') ? fmtKg(m['dispatched']!.count) : 'No records',
        icon: Icons.local_shipping_outlined,
        color: const Color(0xFF0B2942),
        sub: 'In-transit / delivered',
        source: 'manifests table',
      ),
      _MetricDef(
        title: 'Open Exceptions',
        value: overview.exceptions.isEmpty ? '0' : overview.exceptions.length.toString(),
        icon: Icons.warning_amber_rounded,
        color: overview.exceptions.isNotEmpty ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
        sub: overview.exceptions.isEmpty ? 'No active exceptions' : '${overview.exceptions.where((e) => e.severity == 'CRITICAL').length} critical',
        source: 'exceptions / anomaly detection',
      ),
    ];

    return SizedBox(
      height: 110,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: cards.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (ctx, i) => _buildCard(cards[i]),
      ),
    );
  }

  Widget _buildCard(_MetricDef card) {
    return Container(
      width: 190,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [BoxShadow(color: card.color.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: card.color.withOpacity(0.10), borderRadius: BorderRadius.circular(7)),
                child: Icon(card.icon, size: 16, color: card.color),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  card.title,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            card.value,
            style: TextStyle(
              fontSize: card.value.length > 8 ? 15 : 20,
              fontWeight: FontWeight.w800,
              color: card.value == 'No records' ? const Color(0xFF94A3B8) : const Color(0xFF0F172A),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 3),
          Text(card.sub, style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

class _MetricDef {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String sub;
  final String source;
  const _MetricDef({required this.title, required this.value, required this.icon, required this.color, required this.sub, required this.source});
}
