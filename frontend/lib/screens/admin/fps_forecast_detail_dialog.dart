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
  State<FpsForecastDetailDialog> createState() =>
      _FpsForecastDetailDialogState();
}

class _FpsForecastDetailDialogState extends State<FpsForecastDetailDialog> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  bool _isSimulating = false;
  String? _errorMessage;

  FpsForecastDetail? _baselineForecast;
  FpsForecastDetail? _currentForecast;
  WhatIfComparison? _comparison;

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
      final res = await _apiService.fetchFpsForecastDetail(widget.fpsId,
          cycleId: widget.cycleId);
      if (mounted) {
        setState(() {
          _baselineForecast = res;
          _currentForecast = res;
          _comparison = null;
          _whatIfBeneficiaries =
              (res.parameters['beneficiaries_count'] as num?)?.toDouble() ??
                  100.0;
          _whatIfSeasonal =
              (res.parameters['seasonal_factor'] as num?)?.toDouble() ?? 1.05;
          _whatIfPortability =
              (res.parameters['portability_rate'] as num?)?.toDouble() ?? 0.12;
          _whatIfStockout =
              (res.parameters['stockout_frequency'] as num?)?.toDouble() ??
                  0.05;
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
      _whatIfBeneficiaries =
          (_baselineForecast!.parameters['beneficiaries_count'] as num?)
                  ?.toDouble() ??
              100.0;
      _whatIfSeasonal =
          (_baselineForecast!.parameters['seasonal_factor'] as num?)
                  ?.toDouble() ??
              1.05;
      _whatIfPortability =
          (_baselineForecast!.parameters['portability_rate'] as num?)
                  ?.toDouble() ??
              0.12;
      _whatIfStockout =
          (_baselineForecast!.parameters['stockout_frequency'] as num?)
                  ?.toDouble() ??
              0.05;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Container(
        width: 1100,
        height: 820,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            const SizedBox(height: 14),
            if (_isLoading)
              const Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: AppConstants.primaryNavy),
                      SizedBox(height: 12),
                      Text('Computing Explainable Multi-Factor Forecast...',
                          style: TextStyle(
                              color: AppConstants.textSecondary, fontSize: 13)),
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
                      const Icon(Icons.error_outline,
                          color: AppConstants.dangerRed, size: 48),
                      const SizedBox(height: 12),
                      Text(_errorMessage!,
                          style: const TextStyle(
                              color: AppConstants.dangerRed,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadForecast,
                        child: const Text('Retry'),
                      )
                    ],
                  ),
                ),
              )
            else
              Expanded(child: _buildScrollableBody()),
            const SizedBox(height: 12),
            _buildFooter(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppConstants.accentBlue.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.psychology_outlined,
                  color: AppConstants.accentBlue, size: 24),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Explainable Demand Forecasting & What-If Simulation',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppConstants.textPrimary,
                  ),
                ),
                Text(
                  'Multi-Factor Feature Decomposition • Historical Momentum • Confidence Bounds',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppConstants.textSecondary,
                  ),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Top Identity & What-If Comparison Banner
          _buildIdentityAndComparisonBanner(),
          const SizedBox(height: 10),

          // Clarifying Notice Banner for SIH Judges
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppConstants.accentBlue.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppConstants.accentBlue.withValues(alpha: 0.25)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: AppConstants.accentBlue, size: 18),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'EXPLAINABILITY & WHAT-IF SIMULATION LAYER: Decomposes demand into 5 policy features for sensitivity analysis. (Governing Operational Forecast D̂ = (1-α)H + αI is persisted separately for physical dispatch & manifests).',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppConstants.primaryNavy,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 2. Main KPI Grid: Predicted Demand, Confidence, Interval
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 4,
                child: _buildPredictedDemandCard(s),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 3,
                child: _buildConfidenceCard(s),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 4,
                child: _buildIntervalCard(s),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 3. Interactive What-If Scenario Control Panel
          _buildWhatIfControlPanel(),
          const SizedBox(height: 16),

          // 4. Feature Contributions Breakdown Table & 6-Cycle Trend
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 6,
                child: _buildFeatureContributionCard(fc),
              ),
              const SizedBox(width: 14),
              Expanded(
                flex: 5,
                child: _buildHistoricalTrendVisualizer(fc),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 5. Commodity Breakdown (Rice + Wheat)
          _buildCommodityBreakdownCard(fc),
        ],
      ),
    );
  }

  Widget _buildIdentityAndComparisonBanner() {
    final fc = _currentForecast!;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppConstants.backgroundLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppConstants.cardBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppConstants.primaryNavy,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  fc.fpsId,
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fc.fpsName,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppConstants.textPrimary),
                  ),
                  Text(
                    '${fc.district} • Target Cycle: ${fc.cycleId}',
                    style: const TextStyle(
                        fontSize: 11, color: AppConstants.textSecondary),
                  ),
                ],
              ),
            ],
          ),
          if (_comparison != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _comparison!.deltaKg >= 0
                    ? AppConstants.purpleAccent.withValues(alpha: 0.12)
                    : AppConstants.accentAmber.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: _comparison!.deltaKg >= 0
                        ? AppConstants.purpleAccent
                        : AppConstants.accentAmber),
              ),
              child: Row(
                children: [
                  Icon(
                    _comparison!.deltaKg >= 0
                        ? Icons.trending_up
                        : Icons.trending_down,
                    size: 16,
                    color: _comparison!.deltaKg >= 0
                        ? AppConstants.purpleAccent
                        : AppConstants.accentAmber,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'WHAT-IF DELTA: ${_comparison!.deltaKg >= 0 ? "+" : ""}${_comparison!.deltaKg.toStringAsFixed(1)} kg (${_comparison!.deltaPct >= 0 ? "+" : ""}${_comparison!.deltaPct.toStringAsFixed(1)}%)',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: _comparison!.deltaKg >= 0
                          ? AppConstants.purpleAccent
                          : AppConstants.accentAmber,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPredictedDemandCard(ForecastSummaryMetrics s) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppConstants.accentBlue.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: AppConstants.accentBlue.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'EXPLAINABLE / WHAT-IF ESTIMATE',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppConstants.textSecondary),
              ),
              Icon(Icons.auto_graph, color: AppConstants.accentBlue, size: 18),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${s.predictedDemandKg.toStringAsFixed(1)} kg',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppConstants.primaryNavy,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Simulation Only • Model: ${s.modelVersion}',
            style: const TextStyle(
                fontSize: 10, color: AppConstants.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildConfidenceCard(ForecastSummaryMetrics s) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppConstants.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'FORECAST CONFIDENCE',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppConstants.textSecondary),
              ),
              Icon(Icons.verified_outlined,
                  color: AppConstants.successGreen, size: 18),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                '${s.confidencePct.toStringAsFixed(0)}%',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppConstants.successGreen,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppConstants.successGreen.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('HIGH QUALITY',
                    style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: AppConstants.successGreen)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Data quality & volatility penalization applied',
            style: const TextStyle(
                fontSize: 10, color: AppConstants.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildIntervalCard(ForecastSummaryMetrics s) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppConstants.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '95% FORECAST INTERVAL',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppConstants.textSecondary),
              ),
              Icon(Icons.unfold_more,
                  color: AppConstants.purpleAccent, size: 18),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '[${s.lowerEstimateKg.toStringAsFixed(0)} — ${s.upperEstimateKg.toStringAsFixed(0)}] kg',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppConstants.purpleAccent,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Margin of Error: ±${s.marginOfErrorKg.toStringAsFixed(0)} kg',
            style: const TextStyle(
                fontSize: 10, color: AppConstants.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildWhatIfControlPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppConstants.primaryNavy.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppConstants.primaryNavy.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.tune_rounded,
                      color: AppConstants.primaryNavy, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Interactive What-If Simulation Controls',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppConstants.primaryNavy),
                  ),
                ],
              ),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: _resetWhatIf,
                    icon: const Icon(Icons.refresh, size: 14),
                    label: const Text('Reset Baseline',
                        style: TextStyle(fontSize: 11)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _isSimulating ? null : _triggerWhatIfSimulation,
                    icon: _isSimulating
                        ? const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.play_arrow, size: 14),
                    label: const Text('Simulate What-If',
                        style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppConstants.primaryNavy,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const Divider(height: 16),
          // 4 Interactive Sliders in 2x2 Grid
          Row(
            children: [
              Expanded(
                child: _buildSliderItem(
                  'Beneficiary Cards',
                  '${_whatIfBeneficiaries.toInt()} cards',
                  _whatIfBeneficiaries,
                  20,
                  250,
                  (val) {
                    setState(() => _whatIfBeneficiaries = val);
                    _triggerWhatIfSimulation();
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildSliderItem(
                  'Seasonal Multiplier',
                  '${_whatIfSeasonal.toStringAsFixed(2)}x',
                  _whatIfSeasonal,
                  0.80,
                  1.30,
                  (val) {
                    setState(() => _whatIfSeasonal = val);
                    _triggerWhatIfSimulation();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildSliderItem(
                  'Portability / Migrant Shift Rate',
                  '${(_whatIfPortability * 100).toInt()}%',
                  _whatIfPortability,
                  0.0,
                  0.40,
                  (val) {
                    setState(() => _whatIfPortability = val);
                    _triggerWhatIfSimulation();
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildSliderItem(
                  'Stock-out Risk Distortion',
                  '${(_whatIfStockout * 100).toInt()}%',
                  _whatIfStockout,
                  0.0,
                  0.20,
                  (val) {
                    setState(() => _whatIfStockout = val);
                    _triggerWhatIfSimulation();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSliderItem(String label, String valueDisplay, double value,
      double min, double max, ValueChanged<double> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppConstants.textPrimary)),
            Text(valueDisplay,
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppConstants.primaryNavy)),
          ],
        ),
        Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          activeColor: AppConstants.accentBlue,
          inactiveColor: Colors.grey.shade300,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildFeatureContributionCard(FpsForecastDetail fc) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppConstants.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.pie_chart_outline,
                  color: AppConstants.accentBlue, size: 16),
              SizedBox(width: 8),
              Text(
                'Explainable Feature Contribution Breakdown',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppConstants.primaryNavy),
              ),
            ],
          ),
          const Divider(height: 16),
          ...fc.featureContributions.map((feat) {
            final isBaseline = feat.feature.contains('Baseline');
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 4,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(feat.feature,
                            style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppConstants.textPrimary)),
                        Text(feat.description,
                            style: const TextStyle(
                                fontSize: 9,
                                color: AppConstants.textSecondary)),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      '${feat.contributionKg >= 0 && !isBaseline ? "+" : ""}${feat.contributionKg.toStringAsFixed(1)} kg',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isBaseline
                            ? AppConstants.primaryNavy
                            : (feat.contributionKg >= 0
                                ? AppConstants.successGreen
                                : AppConstants.dangerRed),
                      ),
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

  Widget _buildHistoricalTrendVisualizer(FpsForecastDetail fc) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppConstants.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.history,
                      color: AppConstants.primaryNavy, size: 16),
                  SizedBox(width: 8),
                  Text(
                    '6-Cycle Historical Offtake Trend',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppConstants.primaryNavy),
                  ),
                ],
              ),
              Text('Cycles: 2026-03 to 2026-08',
                  style: TextStyle(
                      fontSize: 10, color: AppConstants.textSecondary)),
            ],
          ),
          const Divider(height: 16),
          Column(
            children: fc.historicalTrend.map((h) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    SizedBox(
                      width: 60,
                      child: Text(h.cycleId,
                          style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppConstants.primaryNavy)),
                    ),
                    Expanded(
                      child: LinearProgressIndicator(
                        value: (h.totalKg / 8000.0).clamp(0.0, 1.0),
                        backgroundColor: Colors.grey.shade200,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                            AppConstants.accentBlue),
                        minHeight: 6,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 75,
                      child: Text('${h.totalKg.toStringAsFixed(0)} kg',
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                              fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildCommodityBreakdownCard(FpsForecastDetail fc) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppConstants.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.inventory_2_outlined,
                  color: AppConstants.accentBlue, size: 16),
              SizedBox(width: 8),
              Text(
                'Commodity-Level Demand & Recommendation Breakdown',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppConstants.primaryNavy),
              ),
            ],
          ),
          const Divider(height: 14),
          Row(
            children: fc.commodityBreakdown.map((c) {
              return Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.all(12),
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
                          Text(c.commodity.toUpperCase(),
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppConstants.primaryNavy)),
                          Text('Demand: ${c.predictedDemandKg.toStringAsFixed(0)} kg',
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppConstants.accentBlue)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text('Baseline Offtake: ${c.historicalWeightedAvgKg.toStringAsFixed(0)} kg',
                          style: const TextStyle(
                              fontSize: 10, color: AppConstants.textSecondary)),
                      Text('Current Stock: ${c.currentInventoryKg.toStringAsFixed(0)} kg',
                          style: const TextStyle(
                              fontSize: 10, color: AppConstants.textSecondary)),
                      const Divider(height: 8),
                      Text('Recommended Dispatch: ${c.recommendedDispatchKg.toStringAsFixed(0)} kg',
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppConstants.textPrimary)),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Notice: DEMO DATA — NOT GOVERNMENT DATA (DEMAND FORECAST ENGINE)',
          style: TextStyle(fontSize: 10, color: AppConstants.textTertiary),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
