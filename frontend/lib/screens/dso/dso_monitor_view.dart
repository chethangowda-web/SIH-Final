import 'package:flutter/material.dart';
import '../../models/dso/dso_models.dart';
import '../../widgets/dso/dso_exception_queue.dart';
import '../../widgets/dso/dso_data_source_modal.dart';

class DsoMonitorView extends StatelessWidget {
  final DsoCommandOverview overview;
  final Function(int stageIndex) onNavigateStage;
  final VoidCallback? onRefresh;

  const DsoMonitorView({
    super.key,
    required this.overview,
    required this.onNavigateStage,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final m = overview.metrics;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Current Command Banner
          _buildCurrentCommandBanner(context),
          const SizedBox(height: 20),

          // Command Metrics Grid
          _buildMetricsGrid(context, m),
          const SizedBox(height: 20),

          // Middle Charts & AI Insights Section
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Demand vs Forecast vs Baseline Chart & Variance
              Expanded(
                flex: 6,
                child: _buildDemandVsForecastCard(context),
              ),
              const SizedBox(width: 20),

              // AI Demand Insights Card
              Expanded(
                flex: 4,
                child: _buildAiDemandInsightsCard(context),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Exception Queue
          DsoExceptionQueue(
            exceptions: overview.exceptions,
            onViewAll: () => onNavigateStage(1), // Open stage 1 / exceptions
            onActionTap: (exc) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Opening exception resolution for ${exc.id} (${exc.fps})...')),
              );
            },
          ),
          const SizedBox(height: 20),

          // Footer Strip
          _buildFooterStrip(context),
        ],
      ),
    );
  }

  Widget _buildCurrentCommandBanner(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Color(0xFF2563EB),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person_outline, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Current Command',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF2563EB)),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Stage 01: Monitor & Triage',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 4),
                Text(
                  'Review latest demand, forecast and exceptions. AI has detected ${overview.aiInsights.length} demand anomalies in 7 FPS locations.',
                  style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),

          // 7-Step Workflow Stepper Badge
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text('Next Action', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
              const SizedBox(height: 4),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                onPressed: () => onNavigateStage(2),
                child: Row(
                  children: const [
                    Text('View Demand Insights', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    SizedBox(width: 6),
                    Icon(Icons.arrow_forward, size: 14),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Stepper Circles 1..7
              Row(
                children: List.generate(7, (idx) {
                  final step = idx + 1;
                  final isActive = step == 1;
                  return Container(
                    margin: const EdgeInsets.only(left: 4),
                    width: 20,
                    height: 20,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isActive ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '$step',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isActive ? Colors.white : const Color(0xFF64748B),
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsGrid(BuildContext context, Map<String, MetricItem> m) {
    return Wrap(
      spacing: 14,
      runSpacing: 14,
      children: [
        _buildMetricCard(
          context,
          title: 'Beneficiaries',
          value: _fmtInt(m['beneficiaries']?.count ?? 10006),
          change: '+2.4%',
          subtitle: 'vs. last cycle',
          icon: Icons.people_outline,
          iconBg: const Color(0xFFEFF6FF),
          iconFg: const Color(0xFF2563EB),
          dataset: 'beneficiaries_master.csv',
          table: 'beneficiaries',
          formula: 'SELECT COUNT(*) FROM beneficiaries',
        ),
        _buildMetricCard(
          context,
          title: 'Active Intents',
          value: _fmtInt(m['active_intents']?.count ?? 20000),
          change: '+5.7%',
          subtitle: 'vs. last cycle',
          icon: Icons.assignment_turned_in_outlined,
          iconBg: const Color(0xFFF0FDF4),
          iconFg: const Color(0xFF16A34A),
          dataset: 'intent_signals.csv',
          table: 'intent',
          formula: 'SELECT COUNT(*) FROM intent WHERE cycle_id = \'2026-09\'',
        ),
        _buildMetricCard(
          context,
          title: 'Intent Demand (kg)',
          value: _fmtNum(m['intent_demand_kg']?.count ?? 124560),
          change: '+6.3%',
          subtitle: 'vs. last cycle',
          icon: Icons.lock_outline,
          iconBg: const Color(0xFFF0F9FF),
          iconFg: const Color(0xFF0284C7),
          dataset: 'intent_signals.csv',
          table: 'intent',
          formula: 'SUM(declared_quantity_kg) WHERE cycle_id = \'2026-09\'',
        ),
        _buildMetricCard(
          context,
          title: 'Forecast Demand (kg)',
          value: _fmtNum(m['forecast_demand_kg']?.count ?? 118230),
          change: '+4.8%',
          subtitle: 'vs. last cycle',
          icon: Icons.trending_up,
          iconBg: const Color(0xFFF0FDF4),
          iconFg: const Color(0xFF15803D),
          dataset: 'forecast_engine.py',
          table: 'forecast',
          formula: 'SUM(predicted_quantity_kg) WHERE cycle_id = \'2026-09\'',
        ),
        _buildMetricCard(
          context,
          title: 'Baseline Demand (kg)',
          value: _fmtNum(m['baseline_demand_kg']?.count ?? 103450),
          change: '+3.1%',
          subtitle: 'vs. last cycle',
          icon: Icons.history,
          iconBg: const Color(0xFFFFFBEB),
          iconFg: const Color(0xFFD97706),
          dataset: 'historical_demand.csv',
          table: 'historical_demand',
          formula: 'SUM(historical_component) WHERE cycle_id = \'2026-09\'',
        ),
        _buildStockMetricCard(
          context,
          title: 'Central Depot Stock (kg)',
          total: _fmtNum(m['depot_stock_kg']?.count ?? 48320),
          rice: _fmtNum(m['depot_stock_kg']?.riceKg ?? 28400),
          wheat: _fmtNum(m['depot_stock_kg']?.wheatKg ?? 19920),
          icon: Icons.account_balance_outlined,
          iconBg: const Color(0xFFEFF6FF),
          iconFg: const Color(0xFF1D4ED8),
          dataset: 'godowns_master.csv',
          table: 'depots',
        ),
        _buildStockMetricCard(
          context,
          title: 'FPS Inventory (kg)',
          total: _fmtNum(m['fps_inventory_kg']?.count ?? 62780),
          rice: _fmtNum(m['fps_inventory_kg']?.riceKg ?? 38210),
          wheat: _fmtNum(m['fps_inventory_kg']?.wheatKg ?? 24570),
          icon: Icons.storefront_outlined,
          iconBg: const Color(0xFFF0FDF4),
          iconFg: const Color(0xFF047857),
          dataset: 'fps_master.csv',
          table: 'inventory',
        ),
        _buildMetricCard(
          context,
          title: 'Active Allocations',
          value: _fmtInt(m['active_allocations']?.count ?? 1120),
          subtitle: 'of ${m['active_allocations']?.totalFps ?? 1234} FPS',
          icon: Icons.alt_route_outlined,
          iconBg: const Color(0xFFF0FDF4),
          iconFg: const Color(0xFF16A34A),
          dataset: 'dso_validated_demand',
          table: 'dso_validated_demand',
          formula: 'COUNT(DISTINCT fps_id) FROM dso_validated_demand',
        ),
        _buildMetricCard(
          context,
          title: 'Dispatches',
          value: _fmtInt(m['dispatches']?.count ?? 48),
          subtitle: 'of ${m['dispatches']?.totalFps ?? 62} routes',
          icon: Icons.local_shipping_outlined,
          iconBg: const Color(0xFFF0F9FF),
          iconFg: const Color(0xFF0284C7),
          dataset: 'manifests',
          table: 'manifests',
          formula: 'COUNT(*) WHERE status = \'DISPATCHED\'',
        ),
        _buildMetricCard(
          context,
          title: 'Deliveries',
          value: _fmtInt(m['deliveries']?.count ?? 32),
          subtitle: 'of ${m['deliveries']?.totalFps ?? 48} dispatched',
          icon: Icons.check_circle_outline,
          iconBg: const Color(0xFFF0FDF4),
          iconFg: const Color(0xFF16A34A),
          dataset: 'manifests',
          table: 'manifests',
          formula: 'COUNT(*) WHERE status = \'DELIVERED\'',
        ),
        _buildMetricCard(
          context,
          title: 'Open Exceptions',
          value: '${m['open_exceptions']?.count.toInt() ?? 7}',
          subtitle: '${m['open_exceptions']?.riceKg?.toInt() ?? 3} Critical | ${m['open_exceptions']?.wheatKg?.toInt() ?? 4} Warning',
          icon: Icons.warning_amber_rounded,
          iconBg: const Color(0xFFFEF2F2),
          iconFg: const Color(0xFFDC2626),
          dataset: 'stockout_risk_predictions',
          table: 'forecast',
          formula: 'COUNT(*) WHERE risk_level IN (\'CRITICAL\', \'HIGH\')',
        ),
      ],
    );
  }

  Widget _buildMetricCard(
    BuildContext context, {
    required String title,
    required String value,
    String? change,
    required String subtitle,
    required IconData icon,
    required Color iconBg,
    required Color iconFg,
    required String dataset,
    required String table,
    required String formula,
  }) {
    return Container(
      width: 210,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [BoxShadow(color: Color(0x05000000), blurRadius: 4, offset: Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(6)),
                child: Icon(icon, color: iconFg, size: 18),
              ),
              const Spacer(),
              InkWell(
                onTap: () {
                  DsoDataSourceModal.show(
                    context,
                    title: title,
                    datasetName: dataset,
                    tableName: table,
                    cycleId: overview.cycleId,
                    recordCount: value,
                    formula: formula,
                    apiEndpoint: '/api/v1/admin/dso/command-overview',
                  );
                },
                child: const Icon(Icons.info_outline, size: 14, color: Color(0xFF94A3B8)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(title, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          const SizedBox(height: 2),
          Row(
            children: [
              Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              if (change != null) ...[
                const SizedBox(width: 6),
                Text(change, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF16A34A))),
              ],
            ],
          ),
          const SizedBox(height: 2),
          Text(subtitle, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
        ],
      ),
    );
  }

  Widget _buildStockMetricCard(
    BuildContext context, {
    required String title,
    required String total,
    required String rice,
    required String wheat,
    required IconData icon,
    required Color iconBg,
    required Color iconFg,
    required String dataset,
    required String table,
  }) {
    return Container(
      width: 210,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [BoxShadow(color: Color(0x05000000), blurRadius: 4, offset: Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(6)),
                child: Icon(icon, color: iconFg, size: 18),
              ),
              const Spacer(),
              InkWell(
                onTap: () {
                  DsoDataSourceModal.show(
                    context,
                    title: title,
                    datasetName: dataset,
                    tableName: table,
                    cycleId: overview.cycleId,
                    recordCount: total,
                    formula: 'Rice: $rice kg + Wheat: $wheat kg',
                    apiEndpoint: '/api/v1/admin/dso/command-overview',
                  );
                },
                child: const Icon(Icons.info_outline, size: 14, color: Color(0xFF94A3B8)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(title, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          const SizedBox(height: 2),
          Text(total, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
          const SizedBox(height: 2),
          Text('Rice: $rice | Wheat: $wheat', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
        ],
      ),
    );
  }

  Widget _buildDemandVsForecastCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Demand vs Forecast vs Baseline',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                _buildLegendItem('Intent', const Color(0xFF2563EB)),
                const SizedBox(width: 12),
                _buildLegendItem('Forecast', const Color(0xFF16A34A)),
                const SizedBox(width: 12),
                _buildLegendItem('Baseline', const Color(0xFFD97706)),
              ],
            ),
            const SizedBox(height: 20),

            // Bar Chart Representation
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(child: _buildCommodityBarGroup('Rice (kg)', 72480, 68210, 58630)),
                const SizedBox(width: 24),
                Expanded(child: _buildCommodityBarGroup('Wheat (kg)', 52080, 50020, 44820)),
              ],
            ),
            const SizedBox(height: 20),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
            const SizedBox(height: 12),

            // Variance Analysis Box
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text('Variance Analysis', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                    SizedBox(height: 4),
                    Text('Intent − Forecast: +4,270 kg (+3.9%)', style: TextStyle(fontSize: 12, color: Color(0xFFDC2626), fontWeight: FontWeight.w600)),
                    Text('Forecast − Baseline: +9,600 kg (+9.3%)', style: TextStyle(fontSize: 12, color: Color(0xFF16A34A), fontWeight: FontWeight.w600)),
                  ],
                ),
                OutlinedButton(
                  onPressed: () => onNavigateStage(2),
                  child: const Text('View Details ->', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(width: 10, height: 10, color: color),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
      ],
    );
  }

  Widget _buildCommodityBarGroup(String title, double intent, double forecast, double baseline) {
    const maxVal = 80000.0;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _buildSingleBar(_fmtNum(intent), intent / maxVal, const Color(0xFF2563EB)),
            _buildSingleBar(_fmtNum(forecast), forecast / maxVal, const Color(0xFF16A34A)),
            _buildSingleBar(_fmtNum(baseline), baseline / maxVal, const Color(0xFFD97706)),
          ],
        ),
        const SizedBox(height: 8),
        Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
      ],
    );
  }

  Widget _buildSingleBar(String label, double ratio, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
        const SizedBox(height: 4),
        Container(
          width: 28,
          height: 120 * ratio.clamp(0.1, 1.0),
          decoration: BoxDecoration(
            color: color,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          ),
        ),
      ],
    );
  }

  Widget _buildAiDemandInsightsCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(6)),
                  child: const Icon(Icons.auto_awesome, color: Color(0xFF2563EB), size: 18),
                ),
                const SizedBox(width: 8),
                const Text('AI Demand Insights', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: const Color(0xFFF0FDF4), borderRadius: BorderRadius.circular(10)),
                  child: Text('${overview.aiInsights.length} new insights', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF16A34A))),
                ),
              ],
            ),
            const SizedBox(height: 16),

            ...overview.aiInsights.map((ins) {
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: ins.severity == 'Critical'
                      ? const Color(0xFFFEF2F2)
                      : ins.severity == 'Warning'
                          ? const Color(0xFFFFFBEB)
                          : const Color(0xFFF0F9FF),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: ins.severity == 'Critical'
                        ? const Color(0xFFFECACA)
                        : ins.severity == 'Warning'
                            ? const Color(0xFFFDE68A)
                            : const Color(0xFFBAE6FD),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          ins.severity == 'Critical'
                              ? Icons.error_outline
                              : ins.severity == 'Warning'
                                  ? Icons.warning_amber_rounded
                                  : Icons.info_outline,
                          color: ins.severity == 'Critical'
                              ? const Color(0xFFDC2626)
                              : ins.severity == 'Warning'
                                  ? const Color(0xFFD97706)
                                  : const Color(0xFF0284C7),
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            ins.title,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            DsoDataSourceModal.show(
                              context,
                              title: ins.title,
                              datasetName: ins.evidence,
                              tableName: 'intent / forecast',
                              cycleId: overview.cycleId,
                              recordCount: '7 FPS',
                              formula: ins.why,
                              apiEndpoint: '/api/v1/admin/dso/command-overview',
                            );
                          },
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text('View', style: TextStyle(fontSize: 11, color: Color(0xFF2563EB))),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(ins.summary, style: const TextStyle(fontSize: 11, color: Color(0xFF475569))),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildFooterStrip(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          const Icon(Icons.sync, size: 14, color: Color(0xFF64748B)),
          const SizedBox(width: 6),
          Text('Data Last Updated: ${overview.dataLastUpdated}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
          const Spacer(),
          const Icon(Icons.storage_outlined, size: 14, color: Color(0xFF64748B)),
          const SizedBox(width: 6),
          const Text('Data Sources: 6 datasets | pds_demandsync.db', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
          const Spacer(),
          const Icon(Icons.auto_awesome_outlined, size: 14, color: Color(0xFF64748B)),
          const SizedBox(width: 6),
          const Text('AI Services: Forecast • Anomaly • Optimization • Recommendation', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
        ],
      ),
    );
  }

  String _fmtInt(double v) => v.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
  String _fmtNum(double v) => v.round().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
}
