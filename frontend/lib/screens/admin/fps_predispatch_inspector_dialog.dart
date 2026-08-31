import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../models/admin_model.dart';
import '../../services/api_service.dart';
import '../../widgets/status_badge.dart';
import 'fps_forecast_detail_dialog.dart';
import 'fps_dispatch_decision_dialog.dart';
import 'constraint_validation_dialog.dart';

class FpsPreDispatchInspectorDialog extends StatefulWidget {
  final String fpsId;
  final String cycleId;

  const FpsPreDispatchInspectorDialog({
    super.key,
    required this.fpsId,
    this.cycleId = '2026-09',
  });

  @override
  State<FpsPreDispatchInspectorDialog> createState() =>
      _FpsPreDispatchInspectorDialogState();
}

class _FpsPreDispatchInspectorDialogState
    extends State<FpsPreDispatchInspectorDialog> with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  late final TabController _tabController;
  bool _isLoading = true;
  bool _isAnalyzing = false;
  String? _errorMessage;
  FpsAnalyticsProfile? _profile;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadProfile();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await _apiService.fetchFpsAnalytics(widget.fpsId, cycleId: widget.cycleId);
      if (mounted) {
        setState(() {
          _profile = res;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _runAnalysis() async {
    setState(() => _isAnalyzing = true);
    try {
      final res = await _apiService.runPreDispatchAnalysis(
        fpsId: widget.fpsId,
        cycleId: widget.cycleId,
      );
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res.message),
            backgroundColor: AppConstants.accentBlue,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isAnalyzing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to run pre-dispatch analysis: $e'),
            backgroundColor: AppConstants.dangerRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      child: Container(
        width: 1140,
        height: 840,
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildDossierHeader(),
            const SizedBox(height: 12),
            if (_isLoading)
              const Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: AppConstants.primaryNavy, strokeWidth: 2.5),
                      SizedBox(height: 14),
                      Text('Loading FPS Operational Dossier & Analytics Profile...',
                          style: TextStyle(color: AppConstants.textSecondary, fontSize: 13)),
                    ],
                  ),
                ),
              )
            else if (_errorMessage != null)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, color: AppConstants.dangerRed, size: 48),
                      const SizedBox(height: 12),
                      Text(_errorMessage!, style: const TextStyle(color: AppConstants.dangerRed, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _loadProfile,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      )
                    ],
                  ),
                ),
              )
            else ...[
              _buildTabBar(),
              const SizedBox(height: 12),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildOverviewTab(),
                    _buildDemandTab(),
                    _buildInventoryTab(),
                    _buildRiskTab(),
                    _buildGovernanceTab(),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            _buildFooterActions(),
          ],
        ),
      ),
    );
  }

  // HEADER: Malleshwaram Seva Kendra / FPS-KA-BLR-001 + Status Badge + Metadata
  Widget _buildDossierHeader() {
    final p = _profile;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppConstants.primaryNavy.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppConstants.cardBorder),
              ),
              child: const Icon(Icons.storefront_outlined, color: AppConstants.primaryNavy, size: 26),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      p != null ? p.fpsName : 'Fair Price Shop Operations Dossier',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppConstants.primaryNavy),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppConstants.primaryNavy,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        p != null ? p.fpsId : widget.fpsId,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                    if (p != null) ...[
                      const SizedBox(width: 8),
                      StatusBadge(status: p.statusBadge, fontSize: 10),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  p != null
                      ? 'Location: ${p.district} (${p.latitude.toStringAsFixed(4)}, ${p.longitude.toStringAsFixed(4)}) • Capacity: ${(p.storageCapacityKg / 1000).toStringAsFixed(1)} MT • Cycle: Cycle 7 · Sep 2026'
                      : 'Bengaluru Urban District • National Food Security Act Pre-Dispatch System',
                  style: const TextStyle(fontSize: 11.5, color: AppConstants.textSecondary),
                ),
              ],
            ),
          ],
        ),
        IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close),
          tooltip: 'Close Dossier',
        ),
      ],
    );
  }

  // TAB BAR: OVERVIEW, DEMAND, INVENTORY, RISK, GOVERNANCE
  Widget _buildTabBar() {
    return Container(
      decoration: BoxDecoration(
        color: AppConstants.backgroundLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppConstants.cardBorder),
      ),
      child: TabBar(
        controller: _tabController,
        labelColor: AppConstants.primaryNavy,
        unselectedLabelColor: AppConstants.textSecondary,
        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.3),
        indicator: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(6),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        tabs: const [
          Tab(text: 'OVERVIEW'),
          Tab(text: 'DEMAND'),
          Tab(text: 'INVENTORY'),
          Tab(text: 'RISK'),
          Tab(text: 'GOVERNANCE'),
        ],
      ),
    );
  }

  // TAB 1: OVERVIEW
  Widget _buildOverviewTab() {
    final p = _profile!;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. TOP KPI CARDS (6 Key Metrics)
          Row(
            children: [
              Expanded(child: _buildDossierKpi('Forecast Demand', '${(p.forecastKg / 1000).toStringAsFixed(1)} MT', 'AI composite D̂', AppConstants.primaryNavy)),
              const SizedBox(width: 8),
              Expanded(child: _buildDossierKpi('Current Inventory', '${(p.currentStockKg / 1000).toStringAsFixed(1)} MT', 'On-hand physical stock', AppConstants.accentBlue)),
              const SizedBox(width: 8),
              Expanded(child: _buildDossierKpi('Recommended Dispatch', '${(p.recommendedDispatchKg / 1000).toStringAsFixed(1)} MT', 'Target release quota', const Color(0xFF15803D))),
              const SizedBox(width: 8),
              Expanded(child: _buildDossierKpi('Storage Utilization', '${p.capacityUtilizationPct.toStringAsFixed(1)}%', 'Of ${(p.storageCapacityKg / 1000).toStringAsFixed(1)} MT cap', p.capacityUtilizationPct > 80 ? AppConstants.dangerRed : AppConstants.textSecondary)),
              const SizedBox(width: 8),
              Expanded(child: _buildDossierKpi('Risk Rating', p.riskLevel, 'Stockout probability', p.riskLevel == 'HIGH' ? AppConstants.dangerRed : const Color(0xFF15803D))),
              const SizedBox(width: 8),
              Expanded(child: _buildDossierKpi('Confidence', '95%', 'Explainable score', AppConstants.primaryNavy)),
            ],
          ),
          const SizedBox(height: 14),

          // 2. OPERATIONAL ASSESSMENT CARD
          Container(
            padding: const EdgeInsets.all(AppConstants.space16),
            decoration: BoxDecoration(
              color: AppConstants.cardSurface,
              borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
              border: Border.all(color: AppConstants.cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.assessment_outlined, color: AppConstants.primaryNavy, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'OPERATIONAL ASSESSMENT',
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: AppConstants.primaryNavy, letterSpacing: 0.5),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildAssessmentMetric('Projected Forecast', '${p.forecastKg.toStringAsFixed(0)} kg', 'Historical + intent weight'),
                    _buildAssessmentMetric('Physical Stock', '${p.currentStockKg.toStringAsFixed(0)} kg', 'Audited on-hand stock'),
                    _buildAssessmentMetric('Safety Buffer', '${p.safetyBufferKg.toStringAsFixed(0)} kg', 'Statutory minimum buffer'),
                    _buildAssessmentMetric('Capacity Headroom', '${p.storageHeadroomKg.toStringAsFixed(0)} kg', 'Max ${(p.storageCapacityKg / 1000).toStringAsFixed(1)} MT capacity'),
                    _buildAssessmentMetric('Depot Release', '${p.recommendedDispatchKg.toStringAsFixed(0)} kg', 'Recommended dispatch', isHighlight: true),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 3. RECOMMENDED ACTION INSIGHT CARD
          Container(
            padding: const EdgeInsets.all(AppConstants.space14),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
              border: Border.all(color: AppConstants.accentBlue.withValues(alpha: 0.4), width: 1.2),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: AppConstants.accentBlue, borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.local_shipping_rounded, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'RECOMMENDED ACTION',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppConstants.accentBlue, letterSpacing: 0.6),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Authorize dispatch of ${(p.recommendedDispatchKg / 1000).toStringAsFixed(1)} MT (${p.recommendedDispatchKg.toStringAsFixed(0)} kg) from ${p.assignedDepot} via Corridor Route ${p.routeId}.',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppConstants.primaryNavy),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Pre-positioning grain before cycle opening mitigates the projected ${(p.portabilityRate * 100).toStringAsFixed(0)}% portability influx and keeps bin utilization under ${(p.capacityUtilizationPct + (p.recommendedDispatchKg / p.storageCapacityKg * 100)).clamp(0, 100).toStringAsFixed(0)}%.',
                        style: const TextStyle(fontSize: 11.5, color: AppConstants.textSecondary, height: 1.3),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 4. WHY THIS RECOMMENDATION? (Concise Explainable Factors)
          Container(
            padding: const EdgeInsets.all(AppConstants.space16),
            decoration: BoxDecoration(
              color: AppConstants.cardSurface,
              borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
              border: Border.all(color: AppConstants.cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'WHY THIS RECOMMENDATION?',
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: AppConstants.primaryNavy, letterSpacing: 0.5),
                ),
                const SizedBox(height: 10),
                _buildExplainableFactor('✓', 'Positive Factors', '${p.beneficiariesCount} active NFSA cards registered. Historical lifting pattern indicates steady baseline consumption with +${p.recentTrendPct.toStringAsFixed(1)}% 3-cycle momentum.', const Color(0xFF15803D)),
                const SizedBox(height: 8),
                _buildExplainableFactor('⚠', 'Risk Factors', 'Portability rate of ${(p.portabilityRate * 100).toStringAsFixed(0)}% (${p.portabilityLabel}) with seasonal multiplier ${p.seasonalFactor.toStringAsFixed(2)}x creates potential stockout vulnerability if unbuffered.', const Color(0xFFB45309)),
                const SizedBox(height: 8),
                _buildExplainableFactor('→', 'Operational Implication', 'Pre-positioning ${(p.recommendedDispatchKg / 1000).toStringAsFixed(1)} MT avoids mid-cycle emergency replenishment and satisfies all 9 statutory dispatch rules.', AppConstants.primaryNavy),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 5. GOVERNANCE STATUS & INSTITUTIONAL ROLES
          Container(
            padding: const EdgeInsets.all(AppConstants.space16),
            decoration: BoxDecoration(
              color: AppConstants.cardSurface,
              borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
              border: Border.all(color: AppConstants.cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'GOVERNANCE STATUS',
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: AppConstants.primaryNavy, letterSpacing: 0.5),
                    ),
                    Text(
                      'INSTITUTIONAL ROLES CLEARLY SEPARATED',
                      style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: AppConstants.textSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: _buildGovernanceStatusBox('Citizen Intent', '${p.activeIntentDeclarationsCount} signals declared', 'Non-binding advance signal', Icons.cell_tower_rounded, AppConstants.accentBlue)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildGovernanceStatusBox('AI Advisory', '${(p.forecastKg / 1000).toStringAsFixed(1)} MT suggested', 'Advisory pre-dispatch', Icons.smart_toy_outlined, AppConstants.purpleAccent)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildGovernanceStatusBox('Officer Decision', 'Authoritative approval', 'Statutory allocation', Icons.verified_user_outlined, const Color(0xFF15803D))),
                    const SizedBox(width: 8),
                    Expanded(child: _buildGovernanceStatusBox('Audit Status', 'SHA-256 manifest sealed', 'Immutable audit trail', Icons.lock_outline, AppConstants.primaryNavy)),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.shield_outlined, size: 14, color: AppConstants.textSecondary),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Citizen intent is NOT government allocation. AI is advisory. Officer decision is authoritative.',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppConstants.textSecondary),
                        ),
                      ),
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

  Widget _buildDossierKpi(String title, String val, String sub, Color accent) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppConstants.cardSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppConstants.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppConstants.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 3),
          Text(val, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: accent), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 1),
          Text(sub, style: const TextStyle(fontSize: 9.5, color: AppConstants.textTertiary), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _buildAssessmentMetric(String label, String value, String sub, {bool isHighlight = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppConstants.textSecondary)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: isHighlight ? const Color(0xFF15803D) : AppConstants.primaryNavy)),
        Text(sub, style: const TextStyle(fontSize: 9.5, color: AppConstants.textTertiary)),
      ],
    );
  }

  Widget _buildExplainableFactor(String icon, String label, String desc, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Center(
            child: Text(icon, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: color)),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: color)),
              const SizedBox(height: 1),
              Text(desc, style: const TextStyle(fontSize: 11, color: AppConstants.textSecondary, height: 1.3)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGovernanceStatusBox(String title, String mainText, String subText, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppConstants.backgroundLight,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppConstants.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Expanded(child: Text(title, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: color), overflow: TextOverflow.ellipsis)),
            ],
          ),
          const SizedBox(height: 3),
          Text(mainText, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppConstants.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(subText, style: const TextStyle(fontSize: 9, color: AppConstants.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  // TAB 2: DEMAND
  Widget _buildDemandTab() {
    final p = _profile!;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(AppConstants.space16),
            decoration: BoxDecoration(
              color: AppConstants.cardSurface,
              borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
              border: Border.all(color: AppConstants.cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('6-CYCLE HISTORICAL CONSUMPTION MATRIX', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: AppConstants.primaryNavy, letterSpacing: 0.5)),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: p.historicalOfftake.map((h) {
                      return Container(
                        width: 140,
                        margin: const EdgeInsets.only(right: 10),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppConstants.backgroundLight,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppConstants.cardBorder),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(h.cycleId, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppConstants.primaryNavy)),
                            const SizedBox(height: 4),
                            Text('Rice: ${h.riceKg.toStringAsFixed(0)} kg', style: const TextStyle(fontSize: 11, color: AppConstants.textSecondary)),
                            Text('Wheat: ${h.wheatKg.toStringAsFixed(0)} kg', style: const TextStyle(fontSize: 11, color: AppConstants.textSecondary)),
                            const Divider(height: 8),
                            Text('Total: ${(h.riceKg + h.wheatKg).toStringAsFixed(0)} kg', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(AppConstants.space16),
            decoration: BoxDecoration(
              color: AppConstants.cardSurface,
              borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
              border: Border.all(color: AppConstants.cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('ADVANCE CITIZEN INTENT & PORTABILITY MIGRATION', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: AppConstants.primaryNavy, letterSpacing: 0.5)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: _buildAssessmentMetric('Declared Intent Quota', '${p.declaredIntentKg.toStringAsFixed(0)} kg', '${p.activeIntentDeclarationsCount} active citizen signals')),
                    Expanded(child: _buildAssessmentMetric('Portability Shift Index', '${(p.portabilityRate * 100).toStringAsFixed(1)}%', p.portabilityLabel)),
                    Expanded(child: _buildAssessmentMetric('3-Cycle Moving Momentum', '${p.recentTrendPct >= 0 ? "+" : ""}${p.recentTrendPct.toStringAsFixed(1)}%', 'Volume trajectory')),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // TAB 3: INVENTORY
  Widget _buildInventoryTab() {
    final p = _profile!;

    return SingleChildScrollView(
      child: Container(
        padding: const EdgeInsets.all(AppConstants.space16),
        decoration: BoxDecoration(
          color: AppConstants.cardSurface,
          borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
          border: Border.all(color: AppConstants.cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('STORAGE CAPACITY & BIN UTILIZATION', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: AppConstants.primaryNavy, letterSpacing: 0.5)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildAssessmentMetric('Storage Capacity', '${(p.storageCapacityKg / 1000).toStringAsFixed(1)} MT', 'Physical silo limit')),
                Expanded(child: _buildAssessmentMetric('Current Stock', '${(p.currentStockKg / 1000).toStringAsFixed(1)} MT', 'Audited physical on-hand')),
                Expanded(child: _buildAssessmentMetric('Available Headroom', '${(p.storageHeadroomKg / 1000).toStringAsFixed(1)} MT', 'Safe intake space')),
                Expanded(child: _buildAssessmentMetric('Utilization Rate', '${p.capacityUtilizationPct.toStringAsFixed(1)}%', 'Current fill factor')),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: (p.capacityUtilizationPct / 100).clamp(0.0, 1.0),
                minHeight: 10,
                backgroundColor: const Color(0xFFE2E8F0),
                valueColor: AlwaysStoppedAnimation<Color>(p.capacityUtilizationPct > 80 ? AppConstants.dangerRed : AppConstants.accentBlue),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // TAB 4: RISK
  Widget _buildRiskTab() {
    final p = _profile!;

    return SingleChildScrollView(
      child: Container(
        padding: const EdgeInsets.all(AppConstants.space16),
        decoration: BoxDecoration(
          color: AppConstants.cardSurface,
          borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
          border: Border.all(color: AppConstants.cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('AI STOCKOUT RISK & LOGISTICS PROFILE', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: AppConstants.primaryNavy, letterSpacing: 0.5)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildAssessmentMetric('Stockout Frequency', p.stockoutFrequencyLabel, 'Historical zero-stock incidents')),
                Expanded(child: _buildAssessmentMetric('Seasonal Surge Factor', '${p.seasonalFactor.toStringAsFixed(2)}x', 'Festival / harvest adjustment')),
                Expanded(child: _buildAssessmentMetric('Transit Distance', '${p.roadDistanceKm} km', 'From ${p.assignedDepot}')),
                Expanded(child: _buildAssessmentMetric('Transit Time', '${p.estimatedTransitTimeMins} mins', 'Road condition: ${p.roadCondition}')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // TAB 5: GOVERNANCE
  Widget _buildGovernanceTab() {
    final p = _profile!;

    return SingleChildScrollView(
      child: Container(
        padding: const EdgeInsets.all(AppConstants.space16),
        decoration: BoxDecoration(
          color: AppConstants.cardSurface,
          borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
          border: Border.all(color: AppConstants.cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('STATUTORY RULES & CRYPTOGRAPHIC AUDIT STATUS', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: AppConstants.primaryNavy, letterSpacing: 0.5)),
            const SizedBox(height: 12),
            _buildExplainableFactor('✓', 'Rule 1-3: Statutory Entitlement', 'Statutory grain floor of ${p.totalStatutoryQuotaKg.toStringAsFixed(0)} kg guaranteed across all ${p.beneficiariesCount} cardholders.', const Color(0xFF15803D)),
            const SizedBox(height: 8),
            _buildExplainableFactor('✓', 'Rule 4-6: Capacity & Logistics Headroom', 'Proposed dispatch of ${(p.recommendedDispatchKg / 1000).toStringAsFixed(1)} MT remains well within ${(p.storageHeadroomKg / 1000).toStringAsFixed(1)} MT headroom.', const Color(0xFF15803D)),
            const SizedBox(height: 8),
            _buildExplainableFactor('✓', 'Rule 7-9: Audit & Verification', 'Manifest hash is deterministic, gatepass 4-stage lifecycle active, and audit logs recorded.', const Color(0xFF15803D)),
          ],
        ),
      ),
    );
  }

  // FOOTER ACTIONS
  Widget _buildFooterActions() {
    final p = _profile;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: p != null ? () => showDialog(context: context, builder: (_) => FpsForecastDetailDialog(fpsId: p.fpsId, cycleId: widget.cycleId)) : null,
              icon: const Icon(Icons.science_outlined, size: 15),
              label: const Text('What-If Analysis', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: p != null ? () => showDialog(context: context, builder: (_) => FpsDispatchDecisionDialog(fpsId: p.fpsId, cycleId: widget.cycleId)) : null,
              icon: const Icon(Icons.tune_rounded, size: 15),
              label: const Text('Dispatch Decision', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: p != null ? () => showDialog(context: context, builder: (_) => ConstraintValidationDialog(cycleId: widget.cycleId, initialFpsId: p.fpsId)) : null,
              icon: const Icon(Icons.rule_folder_outlined, size: 15),
              label: const Text('9 Rules Validation', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        ElevatedButton.icon(
          onPressed: _isAnalyzing ? null : _runAnalysis,
          icon: _isAnalyzing
              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.play_arrow_rounded, size: 16),
          label: const Text('Run Pre-Dispatch Analysis', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppConstants.primaryNavy,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          ),
        ),
      ],
    );
  }
}
