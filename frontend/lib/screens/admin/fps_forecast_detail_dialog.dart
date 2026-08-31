import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../models/admin_model.dart';
import '../../services/api_service.dart';

class FpsForecastDetailDialog extends StatefulWidget {
  final String fpsId;
  final String cycleId;

  const FpsForecastDetailDialog({
    super.key,
    required this.fpsId,
    this.cycleId = '2026-09',
  });

  @override
  State<FpsForecastDetailDialog> createState() => _FpsForecastDetailDialogState();
}

class _FpsForecastDetailDialogState extends State<FpsForecastDetailDialog> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  bool _isSimulating = false;
  String? _errorMessage;

  FpsForecastDetail? _baselineForecast;
  FpsForecastDetail? _currentForecast;
  WhatIfComparison? _comparison;
  double _operationalForecastKg = 2678.0;

  // What-If Slider States
  double _whatIfBeneficiaries = 100;
  double _whatIfSeasonal = 1.05;
  double _whatIfPortability = 0.12;
  double _whatIfStockout = 0.05;

  @override
  void initState() {
    super.initState();
    _loadForecast();
  }

  Future<void> _loadForecast() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final forecastFuture = _apiService.fetchFpsForecastDetail(widget.fpsId, cycleId: widget.cycleId);
      final analyticsFuture = _apiService.fetchFpsAnalytics(widget.fpsId, cycleId: widget.cycleId);

      final results = await Future.wait([forecastFuture, analyticsFuture]);
      final res = results[0] as FpsForecastDetail;
      final analytics = results[1] as FpsAnalyticsProfile;

      if (mounted) {
        setState(() {
          _baselineForecast = res;
          _currentForecast = res;
          _comparison = null;
          _operationalForecastKg = analytics.forecastKg > 0 ? analytics.forecastKg : 2678.0;
          _whatIfBeneficiaries = (res.parameters['beneficiaries_count'] as num?)?.toDouble() ?? 100.0;
          _whatIfSeasonal = (res.parameters['seasonal_factor'] as num?)?.toDouble() ?? 1.05;
          _whatIfPortability = (res.parameters['portability_rate'] as num?)?.toDouble() ?? 0.12;
          _whatIfStockout = (res.parameters['stockout_frequency'] as num?)?.toDouble() ?? 0.05;
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

  Future<void> _triggerWhatIfSimulation() async {
    setState(() => _isSimulating = true);

    try {
      final res = await _apiService.simulateFpsWhatIfForecast(
        widget.fpsId,
        beneficiariesCount: _whatIfBeneficiaries.toInt(),
        seasonalFactor: _whatIfSeasonal,
        portabilityRate: _whatIfPortability,
        stockoutFrequency: _whatIfStockout,
        cycleId: widget.cycleId,
      );

      if (mounted) {
        setState(() {
          _currentForecast = res.simulation;
          _comparison = res.comparison;
          _isSimulating = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSimulating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('What-If simulation failed: $e'),
            backgroundColor: AppConstants.dangerRed,
          ),
        );
      }
    }
  }

  void _resetWhatIf() {
    if (_baselineForecast == null) return;
    setState(() {
      _currentForecast = _baselineForecast;
      _comparison = null;
      _whatIfBeneficiaries = (_baselineForecast!.parameters['beneficiaries_count'] as num?)?.toDouble() ?? 100.0;
      _whatIfSeasonal = (_baselineForecast!.parameters['seasonal_factor'] as num?)?.toDouble() ?? 1.05;
      _whatIfPortability = (_baselineForecast!.parameters['portability_rate'] as num?)?.toDouble() ?? 0.12;
      _whatIfStockout = (_baselineForecast!.parameters['stockout_frequency'] as num?)?.toDouble() ?? 0.05;
    });
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
        decoration: BoxDecoration(
          color: AppConstants.backgroundLight,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(context),
            const SizedBox(height: 12),
            if (_isLoading)
              const Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(strokeWidth: 2.5, color: AppConstants.primaryNavy),
                      SizedBox(height: 16),
                      Text('Computing Multi-Factor Explainable Forecast Sandbox...',
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
                        onPressed: _loadForecast,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              )
            else
              Expanded(child: _buildScrollableBody()),
            const SizedBox(height: 10),
            _buildFooter(context),
          ],
        ),
      ),
    );
  }

  // HEADER: Demand Forecast — What-If Analysis + Subtitle + SIMULATION ONLY Badge
  Widget _buildHeader(BuildContext context) {
    final fc = _baselineForecast;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: const Icon(Icons.science_outlined, color: Color(0xFFB45309), size: 24),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Demand Forecast — What-If Analysis',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppConstants.primaryNavy,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFFF59E0B)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.info_outline, size: 12, color: Color(0xFFB45309)),
                          SizedBox(width: 4),
                          Text(
                            'SIMULATION ONLY',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFFB45309), letterSpacing: 0.6),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  fc != null
                      ? 'Advisory simulation • Does not modify operational forecast • ${fc.fpsName} (${fc.fpsId}) • Cycle: ${fc.cycleId}'
                      : 'Advisory simulation • Does not modify operational forecast',
                  style: const TextStyle(fontSize: 11.5, color: AppConstants.textSecondary),
                ),
              ],
            ),
          ],
        ),
        IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close),
          tooltip: 'Close',
        ),
      ],
    );
  }

  Widget _buildScrollableBody() {
    final fc = _currentForecast!;
    final s = fc.summary;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. MANDATORY GOVERNANCE SEPARATION BANNER
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: const Row(
              children: [
                Icon(Icons.gavel_outlined, size: 18, color: Color(0xFFB45309)),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Operational Forecast is used by the dispatch pipeline. What-If values are simulation estimates and do not modify operational decisions.',
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF92400E)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 2. TOP CARDS (4 Essential Comparative Cards)
          Row(
            children: [
              Expanded(
                child: _buildTopKpiCard(
                  'OPERATIONAL FORECAST',
                  '${_operationalForecastKg.toStringAsFixed(1)} kg',
                  'Official dispatch pipeline demand',
                  Icons.verified_outlined,
                  AppConstants.primaryNavy,
                  badge: 'AUTHORITATIVE',
                  badgeColor: AppConstants.primaryNavy,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildTopKpiCard(
                  'WHAT-IF BASELINE',
                  '${s.predictedDemandKg.toStringAsFixed(1)} kg',
                  'Multi-factor sensitivity estimate',
                  Icons.science_outlined,
                  AppConstants.accentBlue,
                  badge: 'SANDBOX',
                  badgeColor: AppConstants.accentBlue,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildTopKpiCard(
                  'FORECAST CONFIDENCE',
                  '${s.confidencePct.toStringAsFixed(0)}%',
                  'Quality & volatility adjusted',
                  Icons.health_and_safety_outlined,
                  const Color(0xFF15803D),
                  badge: 'HIGH CONFIDENCE',
                  badgeColor: const Color(0xFF15803D),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildTopKpiCard(
                  '95% INTERVAL',
                  '${s.lowerEstimateKg.toStringAsFixed(0)}–${s.upperEstimateKg.toStringAsFixed(0)} kg',
                  'Margin of Error: ±${s.marginOfErrorKg.toStringAsFixed(0)} kg',
                  Icons.stacked_bar_chart_outlined,
                  const Color(0xFF6B21A8),
                  badge: '±95% BOUND',
                  badgeColor: const Color(0xFF6B21A8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Explanation footnote on why values differ
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              '* Note: Operational Forecast reflects official statutory allocation and locked choice signals, whereas What-If Baseline is an AI multi-factor sandbox estimate for sensitivity testing.',
              style: TextStyle(fontSize: 10.5, fontStyle: FontStyle.italic, color: Colors.grey.shade600),
            ),
          ),
          const SizedBox(height: 14),

          // 3. INTERACTIVE WHAT-IF SLIDER CONTROLS
          _buildWhatIfControlPanel(),
          const SizedBox(height: 14),

          // 4. SCENARIO RESULT CARD (Displayed when simulated)
          if (_comparison != null) ...[
            _buildScenarioResultCard(_comparison!),
            const SizedBox(height: 14),
          ],

          // 5. FEATURE CONTRIBUTION (Clean horizontal contribution visualization)
          _buildFeatureContributionSection(fc),
          const SizedBox(height: 14),

          // 6. HISTORICAL TREND & COMMODITY BREAKDOWN
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 6,
                child: _buildHistoricalTrendVisualizer(fc),
              ),
              const SizedBox(width: 14),
              Expanded(
                flex: 5,
                child: _buildCommodityBreakdownCard(fc),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTopKpiCard(
    String label,
    String value,
    String sub,
    IconData icon,
    Color color, {
    required String badge,
    required Color badgeColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.space14),
      decoration: BoxDecoration(
        color: AppConstants.cardSurface,
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        border: Border.all(color: AppConstants.cardBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: AppConstants.textSecondary, letterSpacing: 0.4),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  badge,
                  style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: badgeColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color, letterSpacing: -0.4),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            sub,
            style: const TextStyle(fontSize: 10, color: AppConstants.textSecondary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // 3. INTERACTIVE WHAT-IF SLIDER CONTROLS
  Widget _buildWhatIfControlPanel() {
    return Container(
      padding: const EdgeInsets.all(AppConstants.space16),
      decoration: BoxDecoration(
        color: AppConstants.cardSurface,
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        border: Border.all(color: AppConstants.cardBorder, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.tune_rounded, color: AppConstants.primaryNavy, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'INTERACTIVE WHAT-IF SCENARIO WORKSPACE',
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: AppConstants.primaryNavy, letterSpacing: 0.5),
                  ),
                ],
              ),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _resetWhatIf,
                    icon: const Icon(Icons.restart_alt_rounded, size: 14),
                    label: const Text('Reset to Baseline', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppConstants.textSecondary,
                      side: const BorderSide(color: AppConstants.cardBorder),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _isSimulating ? null : _triggerWhatIfSimulation,
                    icon: _isSimulating
                        ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.play_arrow_rounded, size: 16),
                    label: const Text('Simulate Scenario', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppConstants.accentBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 4 Sliders in 2x2 layout
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildSliderItem(
                  label: 'Beneficiary Cards',
                  valueStr: '${_whatIfBeneficiaries.toInt()} Cards',
                  explanation: 'Active NFSA cardholder baseline in center catchment',
                  value: _whatIfBeneficiaries,
                  min: 20,
                  max: 300,
                  divisions: 28,
                  onChanged: (v) => setState(() => _whatIfBeneficiaries = v),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildSliderItem(
                  label: 'Seasonal Multiplier',
                  valueStr: '${_whatIfSeasonal.toStringAsFixed(2)}x',
                  explanation: 'Festival surge, harvest cycle, or climatic off-season',
                  value: _whatIfSeasonal,
                  min: 0.80,
                  max: 1.50,
                  divisions: 14,
                  onChanged: (v) => setState(() => _whatIfSeasonal = v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildSliderItem(
                  label: 'Portability Shift Index',
                  valueStr: '${(_whatIfPortability * 100).toStringAsFixed(0)}%',
                  explanation: 'ONORC migrant inflow and interstate portability quota',
                  value: _whatIfPortability,
                  min: 0.0,
                  max: 0.40,
                  divisions: 20,
                  onChanged: (v) => setState(() => _whatIfPortability = v),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildSliderItem(
                  label: 'Stock-out Risk Frequency',
                  valueStr: '${(_whatIfStockout * 100).toStringAsFixed(0)}%',
                  explanation: 'Historical buffer exhaustion and supply disruption probability',
                  value: _whatIfStockout,
                  min: 0.0,
                  max: 0.30,
                  divisions: 15,
                  onChanged: (v) => setState(() => _whatIfStockout = v),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSliderItem({
    required String label,
    required String valueStr,
    required String explanation,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppConstants.backgroundLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppConstants.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: AppConstants.primaryNavy)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppConstants.primaryNavy,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(valueStr, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(explanation, style: const TextStyle(fontSize: 10, color: AppConstants.textSecondary)),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
              activeTrackColor: AppConstants.primaryNavy,
              inactiveTrackColor: const Color(0xFFCBD5E1),
              thumbColor: AppConstants.primaryNavy,
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  // 4. SCENARIO RESULT (Baseline, Scenario, Difference, Percentage Change)
  Widget _buildScenarioResultCard(WhatIfComparison comp) {
    final isPositive = comp.deltaKg >= 0;

    return Container(
      padding: const EdgeInsets.all(AppConstants.space16),
      decoration: BoxDecoration(
        color: isPositive ? const Color(0xFFEFF6FF) : const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        border: Border.all(color: isPositive ? const Color(0xFFBFDBFE) : const Color(0xFFFDE68A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.compare_arrows_rounded, color: AppConstants.primaryNavy, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'SCENARIO SIMULATION RESULT',
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: AppConstants.primaryNavy, letterSpacing: 0.5),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isPositive ? AppConstants.accentBlue : AppConstants.accentAmber,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'DELTA: ${isPositive ? "+" : ""}${comp.deltaKg.toStringAsFixed(1)} kg (${isPositive ? "+" : ""}${comp.deltaPct.toStringAsFixed(1)}%)',
                  style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900, color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildComparisonStat('Baseline Demand', '${comp.baselineDemandKg.toStringAsFixed(1)} kg', AppConstants.textSecondary),
              _buildComparisonStat('Scenario Demand', '${comp.simulatedDemandKg.toStringAsFixed(1)} kg', AppConstants.primaryNavy),
              _buildComparisonStat('Net Difference', '${isPositive ? "+" : ""}${comp.deltaKg.toStringAsFixed(1)} kg', isPositive ? AppConstants.accentBlue : AppConstants.accentAmber),
              _buildComparisonStat('Percentage Shift', '${isPositive ? "+" : ""}${comp.deltaPct.toStringAsFixed(1)}%', isPositive ? AppConstants.accentBlue : AppConstants.accentAmber),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppConstants.textSecondary)),
        const SizedBox(height: 3),
        Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: color)),
      ],
    );
  }

  // 5. FEATURE CONTRIBUTION (Clean horizontal contribution visualization)
  Widget _buildFeatureContributionSection(FpsForecastDetail fc) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.space16),
      decoration: BoxDecoration(
        color: AppConstants.cardSurface,
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        border: Border.all(color: AppConstants.cardBorder, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.bar_chart_rounded, color: AppConstants.primaryNavy, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'FEATURE CONTRIBUTION DECOMPOSITION',
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: AppConstants.primaryNavy, letterSpacing: 0.5),
                  ),
                ],
              ),
              Text(
                'EXPLAINABLE SENSITIVITY BREAKDOWN',
                style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: AppConstants.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...fc.featureContributions.map((feat) {
            final isBaseline = feat.feature.contains('Baseline');
            final isPositive = feat.contributionKg >= 0;

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  SizedBox(
                    width: 220,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(feat.feature, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: AppConstants.textPrimary)),
                        Text(feat.description, style: const TextStyle(fontSize: 10, color: AppConstants.textSecondary)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Stack(
                      children: [
                        Container(
                          height: 12,
                          decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(3)),
                        ),
                        FractionallySizedBox(
                          widthFactor: (feat.contributionPct / 100.0).clamp(0.02, 1.0),
                          child: Container(
                            height: 12,
                            decoration: BoxDecoration(
                              color: isBaseline
                                  ? AppConstants.primaryNavy
                                  : (isPositive ? const Color(0xFF15803D) : AppConstants.accentAmber),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  SizedBox(
                    width: 95,
                    child: Text(
                      '${isPositive && !isBaseline ? "+" : ""}${feat.contributionKg.toStringAsFixed(1)} kg',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: isBaseline ? AppConstants.primaryNavy : (isPositive ? const Color(0xFF15803D) : AppConstants.accentAmber),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 50,
                    child: Text(
                      '${feat.contributionPct.toStringAsFixed(1)}%',
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppConstants.textSecondary),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // 6. HISTORICAL TREND VISUALIZER
  Widget _buildHistoricalTrendVisualizer(FpsForecastDetail fc) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.space16),
      decoration: BoxDecoration(
        color: AppConstants.cardSurface,
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        border: Border.all(color: AppConstants.cardBorder, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'HISTORICAL MONTHLY DEMAND TREND',
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: AppConstants.primaryNavy, letterSpacing: 0.5),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: fc.historicalTrend.map((pt) {
                final height = (pt.totalKg / 80.0).clamp(20.0, 90.0);
                final isCurrentCycle = pt.cycleId == fc.cycleId;
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Column(
                    children: [
                      Text('${pt.totalKg.toStringAsFixed(0)} kg', style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: AppConstants.textSecondary)),
                      const SizedBox(height: 4),
                      Container(
                        width: 32,
                        height: height,
                        decoration: BoxDecoration(
                          color: isCurrentCycle ? AppConstants.accentBlue : AppConstants.primaryNavy,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(pt.cycleId, style: const TextStyle(fontSize: 9.5, color: AppConstants.textSecondary)),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // 7. COMMODITY BREAKDOWN CARD
  Widget _buildCommodityBreakdownCard(FpsForecastDetail fc) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.space16),
      decoration: BoxDecoration(
        color: AppConstants.cardSurface,
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        border: Border.all(color: AppConstants.cardBorder, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'COMMODITY DEMAND BREAKDOWN',
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: AppConstants.primaryNavy, letterSpacing: 0.5),
          ),
          const SizedBox(height: 12),
          ...fc.commodityBreakdown.map((comm) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppConstants.backgroundLight,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppConstants.cardBorder),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(comm.commodity, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppConstants.primaryNavy)),
                        Text('Current Inv: ${comm.currentInventoryKg.toStringAsFixed(0)} kg • Rec Dispatch: ${comm.recommendedDispatchKg.toStringAsFixed(0)} kg', style: const TextStyle(fontSize: 10, color: AppConstants.textSecondary)),
                      ],
                    ),
                    Text(
                      '${comm.predictedDemandKg.toStringAsFixed(1)} kg',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: AppConstants.primaryNavy),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'PDS DemandSync • Explainable AI Sensitivity Sandbox • Advisory Simulation Module',
          style: TextStyle(fontSize: 10.5, color: AppConstants.textSecondary),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppConstants.primaryNavy,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
          child: const Text('Close Workspace', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
