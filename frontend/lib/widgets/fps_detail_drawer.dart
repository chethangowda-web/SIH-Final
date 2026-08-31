import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../models/admin_model.dart';
import 'status_badge.dart';

class FpsDetailDrawer extends StatefulWidget {
  final AdminFpsRow item;
  final VoidCallback onOpenForecast;
  final VoidCallback onOpenDecision;
  final VoidCallback onOpenInspector;

  const FpsDetailDrawer({
    super.key,
    required this.item,
    required this.onOpenForecast,
    required this.onOpenDecision,
    required this.onOpenInspector,
  });

  static void show(
    BuildContext context, {
    required AdminFpsRow item,
    required VoidCallback onOpenForecast,
    required VoidCallback onOpenDecision,
    required VoidCallback onOpenInspector,
  }) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'FPS Details',
      barrierColor: Colors.black.withValues(alpha: 0.35),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (context, anim1, anim2) {
        return Align(
          alignment: Alignment.centerRight,
          child: Material(
            color: Colors.transparent,
            child: SizedBox(
              width: 520,
              height: double.infinity,
              child: FpsDetailDrawer(
                item: item,
                onOpenForecast: onOpenForecast,
                onOpenDecision: onOpenDecision,
                onOpenInspector: onOpenInspector,
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, anim1, anim2, child) {
        final tween = Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero);
        return SlideTransition(
          position: tween.animate(CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic)),
          child: child,
        );
      },
    );
  }

  @override
  State<FpsDetailDrawer> createState() => _FpsDetailDrawerState();
}

class _FpsDetailDrawerState extends State<FpsDetailDrawer> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 16,
            offset: Offset(-4, 0),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drawer Header
          Container(
            padding: const EdgeInsets.all(AppConstants.space20),
            color: AppConstants.primaryNavy,
            child: SafeArea(
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          item.fpsId,
                          style: const TextStyle(
                            fontSize: 11,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white, size: 20),
                        onPressed: () => Navigator.of(context).pop(),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppConstants.space8),
                  Text(
                    item.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: AppConstants.space8),
                  Row(
                    children: [
                      StatusBadge(status: item.riskLevel),
                      const SizedBox(width: 8),
                      StatusBadge(status: item.status),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Drawer Navigation Tabs
          Container(
            color: const Color(0xFFF8FAFC),
            child: TabBar(
              controller: _tabController,
              labelColor: AppConstants.primaryNavy,
              unselectedLabelColor: AppConstants.textSecondary,
              indicatorColor: AppConstants.primaryNavy,
              indicatorWeight: 3,
              labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              tabs: const [
                Tab(text: 'Overview'),
                Tab(text: 'Demand & Risk'),
                Tab(text: 'Inventory'),
                Tab(text: 'Recommendation'),
              ],
            ),
          ),

          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(),
                _buildDemandRiskTab(),
                _buildInventoryTab(),
                _buildRecommendationTab(),
              ],
            ),
          ),

          // Sticky Footer Actions
          Container(
            padding: const EdgeInsets.all(AppConstants.space16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              border: Border(top: BorderSide(color: AppConstants.cardBorder, width: 1)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      widget.onOpenForecast();
                    },
                    icon: const Icon(Icons.insights, size: 16),
                    label: const Text('Explainable AI', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppConstants.primaryNavy,
                      side: const BorderSide(color: AppConstants.cardBorder),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      widget.onOpenDecision();
                    },
                    icon: const Icon(Icons.gavel, size: 16),
                    label: const Text('Pre-Dispatch', style: TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppConstants.primaryNavy,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    final item = widget.item;
    return ListView(
      padding: const EdgeInsets.all(AppConstants.space20),
      children: [
        _buildInfoCard(
          title: 'KEY TELEMETRY METRICS',
          children: [
            _buildDataRow('Historical Baseline Offtake', '${item.historicalDemandKg.toStringAsFixed(1)} kg'),
            _buildDataRow('Declared Citizen Intent', '${item.declaredIntentKg.toStringAsFixed(1)} kg'),
            _buildDataRow('Composite AI Forecast Demand (D̂)', '${item.forecastKg.toStringAsFixed(1)} kg', isBold: true),
            _buildDataRow('Recommended Dispatch Quantity', '${item.recommendedDispatchKg.toStringAsFixed(1)} kg', isBold: true, highlightColor: AppConstants.accentBlue),
            _buildDataRow('Opening Buffer Inventory', '${item.inventoryKg.toStringAsFixed(1)} kg'),
            _buildDataRow('Storage Capacity (Cap)', '${item.capacityKg.toStringAsFixed(1)} kg'),
            _buildDataRow('Safe Storage Headroom', '${(item.capacityKg - item.inventoryKg).toStringAsFixed(1)} kg'),
          ],
        ),
        const SizedBox(height: AppConstants.space16),
        _buildInfoCard(
          title: 'DISTRIBUTION CHANNEL DETAILS',
          children: [
            _buildDataRow('Fair Price Shop ID', item.fpsId),
            _buildDataRow('Facility Name', item.name),
            _buildDataRow('District Jurisdiction', item.district),
            _buildDataRow('Current Lifecycle Status', item.status),
            _buildDataRow('Stockout Risk Tier', item.riskLevel),
          ],
        ),
      ],
    );
  }

  Widget _buildDemandRiskTab() {
    final item = widget.item;
    return ListView(
      padding: const EdgeInsets.all(AppConstants.space20),
      children: [
        _buildInfoCard(
          title: 'EXPLAINABLE DEMAND CONTRIBUTIONS',
          children: [
            _buildDataRow('Base Historical Weight (1 - w*C)', '85% Baseline Offtake'),
            _buildDataRow('Intent Signal Weight (w*C)', '15% Direct Citizen Preference'),
            _buildDataRow('Shift Magnitude vs Baseline', '${(item.forecastKg - item.historicalDemandKg).toStringAsFixed(1)} kg'),
            _buildDataRow('Portability Adjustment Factor', 'Applied via ONORC Registry'),
          ],
        ),
        const SizedBox(height: AppConstants.space16),
        _buildInfoCard(
          title: 'RISK & SAFETY PROFILE',
          children: [
            _buildDataRow('Risk Category', item.riskLevel),
            _buildDataRow('Risk Assessment Reason', item.riskReason.isNotEmpty ? item.riskReason : 'Normal consumption pattern'),
            _buildDataRow('Statutory Floor Protection', 'Enforced (NFSA Sec 3 Compliance)'),
          ],
        ),
      ],
    );
  }

  Widget _buildInventoryTab() {
    final item = widget.item;
    final headroom = item.capacityKg - item.inventoryKg;
    final pctUsed = item.capacityKg > 0 ? (item.inventoryKg / item.capacityKg).clamp(0.0, 1.0) : 0.0;

    return ListView(
      padding: const EdgeInsets.all(AppConstants.space20),
      children: [
        _buildInfoCard(
          title: 'STORAGE CAPACITY UTILIZATION',
          children: [
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Current Utilization: ${(pctUsed * 100).toStringAsFixed(1)}%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                Text('${item.inventoryKg.toStringAsFixed(0)} / ${item.capacityKg.toStringAsFixed(0)} kg', style: const TextStyle(fontSize: 12, color: AppConstants.textSecondary)),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: pctUsed,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(
                pctUsed > 0.85 ? AppConstants.dangerRed : (pctUsed > 0.6 ? AppConstants.accentAmber : AppConstants.accentBlue),
              ),
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 12),
            _buildDataRow('Available Intake Headroom', '${headroom.toStringAsFixed(1)} kg'),
            _buildDataRow('Dispatch Payload Compatibility', headroom >= item.recommendedDispatchKg ? '✓ Fits safely' : '⚠ Exceeds headroom'),
          ],
        ),
      ],
    );
  }

  Widget _buildRecommendationTab() {
    final item = widget.item;
    return ListView(
      padding: const EdgeInsets.all(AppConstants.space20),
      children: [
        Container(
          padding: const EdgeInsets.all(AppConstants.space16),
          decoration: BoxDecoration(
            color: AppConstants.primaryNavy.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
            border: Border.all(color: AppConstants.primaryNavy.withValues(alpha: 0.15)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'OFFICER PRE-DISPATCH DIRECTIVE',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppConstants.primaryNavy, letterSpacing: 0.5),
              ),
              const SizedBox(height: 8),
              Text(
                'Recommended godown dispatch quantity is ${item.recommendedDispatchKg.toStringAsFixed(1)} kg based on forecasted demand of ${item.forecastKg.toStringAsFixed(1)} kg and opening inventory buffer of ${item.inventoryKg.toStringAsFixed(1)} kg.',
                style: const TextStyle(fontSize: 13, height: 1.4, color: AppConstants.textPrimary),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard({required String title, required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.space16),
      decoration: BoxDecoration(
        color: AppConstants.cardSurface,
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        border: Border.all(color: AppConstants.cardBorder, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppConstants.textSecondary,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: AppConstants.space12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildDataRow(String label, String value, {bool isBold = false, Color? highlightColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppConstants.textSecondary),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
              color: highlightColor ?? (isBold ? AppConstants.textPrimary : AppConstants.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
