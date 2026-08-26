import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../models/admin_model.dart';
import '../../services/api_service.dart';

class FpsDispatchDecisionDialog extends StatefulWidget {
  final String fpsId;
  final String cycleId;

  const FpsDispatchDecisionDialog({
    super.key,
    required this.fpsId,
    this.cycleId = '2026-09',
  });

  @override
  State<FpsDispatchDecisionDialog> createState() =>
      _FpsDispatchDecisionDialogState();
}

class _FpsDispatchDecisionDialogState extends State<FpsDispatchDecisionDialog> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;

  DispatchDecisionProfile? _decision;
  String _selectedScenario = 'NORMAL';
  double _leadTimeDays = 2.0;
  double _stockoutRisk = 0.05;

  @override
  void initState() {
    super.initState();
    _loadDecision();
  }

  Future<void> _loadDecision({String scenario = 'NORMAL'}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _selectedScenario = scenario;
    });

    try {
      final res = await _apiService.fetchDispatchDecision(
        widget.fpsId,
        scenario: scenario,
        cycleId: widget.cycleId,
      );
      if (mounted) {
        setState(() {
          _decision = res;
          _leadTimeDays = res.safetyBufferBreakdown.leadTimeDays;
          _stockoutRisk = res.safetyBufferBreakdown.stockoutRiskFactor;
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

  Future<void> _recalculateCustomParams() async {
    try {
      final res = await _apiService.calculateCustomDispatchDecision(
        widget.fpsId,
        scenario: _selectedScenario,
        leadTimeDays: _leadTimeDays,
        stockoutRisk: _stockoutRisk,
        cycleId: widget.cycleId,
      );
      if (mounted) {
        setState(() {
          _decision = res;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Recalculation failed: $e'),
            backgroundColor: AppConstants.dangerRed,
          ),
        );
      }
    }
  }

  Future<void> _saveRecommendation() async {
    if (_decision == null) return;
    setState(() => _isSaving = true);

    try {
      final res = await _apiService.saveDispatchDecision(
        widget.fpsId,
        scenario: _selectedScenario,
        recommendedDispatchKg: _decision!.coreMetrics.recommendedDispatchKg,
        cycleId: widget.cycleId,
      );

      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message'] ?? 'Dispatch recommendation saved!'),
            backgroundColor: AppConstants.successGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save recommendation: $e'),
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
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Container(
        width: 1100,
        height: 840,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            const SizedBox(height: 12),
            if (_isLoading)
              const Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: AppConstants.primaryNavy),
                      SizedBox(height: 12),
                      Text('Computing Pre-Dispatch Decision & Headroom...',
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
                        onPressed: () => _loadDecision(),
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
                color: AppConstants.successGreen.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.local_shipping_outlined,
                  color: AppConstants.successGreen, size: 24),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Pre-Dispatch Decision Engine & Scenario Evaluator',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppConstants.textPrimary,
                  ),
                ),
                Text(
                  'Demand − Stock + Safety Buffer • Storage Headroom Check • Operational Scenarios',
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
    final d = _decision!;
    final m = d.coreMetrics;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Top Identity & Scenario Selector
          _buildIdentityAndScenarioBar(d),
          const SizedBox(height: 14),

          // 2. Explicit Mathematical Formula Calculation Banner
          _buildExplicitFormulaBanner(d),
          const SizedBox(height: 14),

          // 3. 6 Core Decision KPI Cards Grid
          _buildCoreMetricsGrid(m),
          const SizedBox(height: 14),

          // 4. "Why this quantity?" Explainable Decision Narrative Card
          _buildDecisionNarrativeCard(d),
          const SizedBox(height: 14),

          // 5. Safety Parameter Tuning Sliders & Scenarios Comparison
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 5,
                child: _buildSafetyParameterPanel(d),
              ),
              const SizedBox(width: 14),
              Expanded(
                flex: 5,
                child: _buildScenarioComparisonTable(d),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 6. Commodity-Level Breakdown Table
          _buildCommodityDecisionBreakdown(d),
        ],
      ),
    );
  }

  Widget _buildIdentityAndScenarioBar(DispatchDecisionProfile d) {
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
                  d.fpsId,
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
                    d.fpsName,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppConstants.textPrimary),
                  ),
                  Text(
                    '${d.district} • Target Cycle: ${d.cycleId}',
                    style: const TextStyle(
                        fontSize: 11, color: AppConstants.textSecondary),
                  ),
                ],
              ),
            ],
          ),
          // Scenario selector tabs
          Row(
            children: [
              _buildScenarioButton('NORMAL', '1. Normal Baseline'),
              const SizedBox(width: 6),
              _buildScenarioButton('HIGH_DEMAND', '2. High Demand'),
              const SizedBox(width: 6),
              _buildScenarioButton('LOW_STOCK_HIGH_RISK', '3. Low Stock / Critical'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildScenarioButton(String id, String label) {
    final isSelected = _selectedScenario == id;
    return ElevatedButton(
      onPressed: () => _loadDecision(scenario: id),
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected
            ? AppConstants.primaryNavy
            : Colors.grey.shade200,
        foregroundColor: isSelected ? Colors.white : AppConstants.textPrimary,
        elevation: isSelected ? 2 : 0,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500)),
    );
  }

  Widget _buildExplicitFormulaBanner(DispatchDecisionProfile d) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppConstants.accentBlue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppConstants.accentBlue.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.calculate_outlined,
                  color: AppConstants.accentBlue, size: 22),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'EXPLICIT FORMULA:  Predicted Demand − Current Stock + Safety Buffer',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppConstants.textSecondary,
                        letterSpacing: 0.5),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    d.formula.values,
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'monospace',
                        color: AppConstants.primaryNavy),
                  ),
                ],
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: d.formula.isCapacityCapped
                  ? AppConstants.accentAmber.withValues(alpha: 0.15)
                  : AppConstants.successGreen.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              d.formula.capacityCapMessage,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: d.formula.isCapacityCapped
                    ? AppConstants.accentAmber
                    : AppConstants.successGreen,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoreMetricsGrid(DecisionCoreMetrics m) {
    return Row(
      children: [
        Expanded(
          child: _buildMetricCard(
            'PREDICTED DEMAND',
            '${m.predictedDemandKg.toStringAsFixed(0)} kg',
            'Target Cycle Demand',
            Icons.auto_graph,
            AppConstants.accentBlue,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildMetricCard(
            'CURRENT STOCK',
            '${m.currentStockKg.toStringAsFixed(0)} kg',
            '${m.daysOfStockCoverage.toStringAsFixed(1)} days coverage',
            Icons.inventory_2_outlined,
            m.daysOfStockCoverage < 2.0
                ? AppConstants.dangerRed
                : AppConstants.primaryNavy,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildMetricCard(
            'SAFETY BUFFER',
            '+${m.safetyBufferKg.toStringAsFixed(0)} kg',
            'Buffer for Lead Time & Risk',
            Icons.shield_outlined,
            AppConstants.purpleAccent,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildMetricCard(
            'REC. DISPATCH',
            '${m.recommendedDispatchKg.toStringAsFixed(0)} kg',
            'Actionable Godown Order',
            Icons.local_shipping_outlined,
            AppConstants.successGreen,
            isHighlighted: true,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildMetricCard(
            'FPS CAPACITY',
            '${(m.storageCapacityKg / 1000).toStringAsFixed(0)} MT',
            '${m.capacityUtilizationPct.toStringAsFixed(1)}% Post-Stock',
            Icons.warehouse_outlined,
            AppConstants.secondaryNavy,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildMetricCard(
            'REMAINING HEADROOM',
            '${m.remainingCapacityKg.toStringAsFixed(0)} kg',
            'Emergency Buffer Space',
            Icons.pie_chart_outline,
            AppConstants.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard(String label, String value, String subtitle,
      IconData icon, Color color,
      {bool isHighlighted = false}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isHighlighted ? color.withValues(alpha: 0.08) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: isHighlighted
                ? color
                : AppConstants.cardBorder),
        boxShadow: isHighlighted
            ? [
                BoxShadow(
                    color: color.withValues(alpha: 0.1),
                    blurRadius: 6,
                    offset: const Offset(0, 2))
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label,
                  style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: AppConstants.textSecondary)),
              Icon(icon, size: 14, color: color),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w900, color: color),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(
                fontSize: 9, color: AppConstants.textSecondary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildDecisionNarrativeCard(DispatchDecisionProfile d) {
    final exp = d.decisionExplanation;
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
          Row(
            children: [
              const Icon(Icons.help_outline_rounded,
                  color: AppConstants.accentBlue, size: 18),
              const SizedBox(width: 8),
              Text(
                'Why this quantity? (${d.scenario['name']})',
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppConstants.primaryNavy),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            exp.narrative,
            style: const TextStyle(
                fontSize: 12,
                color: AppConstants.textPrimary,
                height: 1.4,
                fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: exp.keyDrivers.map((driver) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppConstants.backgroundLight,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppConstants.cardBorder),
                ),
                child: Text(driver,
                    style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppConstants.primaryNavy)),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSafetyParameterPanel(DispatchDecisionProfile d) {
    final b = d.safetyBufferBreakdown;
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
                  Icon(Icons.tune_rounded,
                      color: AppConstants.primaryNavy, size: 16),
                  SizedBox(width: 8),
                  Text(
                    'Safety Buffer Parameter Controls',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppConstants.primaryNavy),
                  ),
                ],
              ),
            ],
          ),
          const Divider(height: 14),
          // Lead time slider
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Lead Time (Godown to Shop Transit)',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
              Text('${_leadTimeDays.toStringAsFixed(1)} days',
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppConstants.primaryNavy)),
            ],
          ),
          Slider(
            value: _leadTimeDays.clamp(1.0, 8.0),
            min: 1.0,
            max: 8.0,
            divisions: 14,
            activeColor: AppConstants.accentBlue,
            onChanged: (val) {
              setState(() => _leadTimeDays = val);
              _recalculateCustomParams();
            },
          ),
          // Stockout risk slider
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Stock-Out Risk Factor',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
              Text('${(_stockoutRisk * 100).toInt()}%',
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppConstants.primaryNavy)),
            ],
          ),
          Slider(
            value: _stockoutRisk.clamp(0.0, 0.25),
            min: 0.0,
            max: 0.25,
            divisions: 25,
            activeColor: AppConstants.purpleAccent,
            onChanged: (val) {
              setState(() => _stockoutRisk = val);
              _recalculateCustomParams();
            },
          ),
          // Breakdown tags
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Text('Lead Time: +${b.leadTimeContributionKg.toStringAsFixed(0)} kg',
                  style: const TextStyle(
                      fontSize: 10, color: AppConstants.textSecondary)),
              Text('Risk: +${b.stockoutRiskContributionKg.toStringAsFixed(0)} kg',
                  style: const TextStyle(
                      fontSize: 10, color: AppConstants.textSecondary)),
              Text('Volatility: +${b.volatilityContributionKg.toStringAsFixed(0)} kg',
                  style: const TextStyle(
                      fontSize: 10, color: AppConstants.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildScenarioComparisonTable(DispatchDecisionProfile d) {
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
              Icon(Icons.compare_arrows_rounded,
                  color: AppConstants.primaryNavy, size: 16),
              SizedBox(width: 8),
              Text(
                '3-Scenario Comparative Matrix',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppConstants.primaryNavy),
              ),
            ],
          ),
          const Divider(height: 14),
          ...d.allScenarios.map((scen) {
            final isCurrent = scen.scenarioId == _selectedScenario;
            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: isCurrent
                    ? AppConstants.primaryNavy.withValues(alpha: 0.06)
                    : AppConstants.backgroundLight,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                    color: isCurrent
                        ? AppConstants.primaryNavy
                        : AppConstants.cardBorder),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(scen.scenarioName,
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: isCurrent
                                  ? FontWeight.bold
                                  : FontWeight.w600,
                              color: isCurrent
                                  ? AppConstants.primaryNavy
                                  : AppConstants.textPrimary)),
                      Text('Formula: ${scen.formula}',
                          style: const TextStyle(
                              fontSize: 9,
                              fontFamily: 'monospace',
                              color: AppConstants.textSecondary)),
                    ],
                  ),
                  Text(
                    '${scen.recommendedDispatchKg.toStringAsFixed(0)} kg',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isCurrent
                          ? AppConstants.successGreen
                          : AppConstants.textPrimary,
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

  Widget _buildCommodityDecisionBreakdown(DispatchDecisionProfile d) {
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
                'Commodity-Level Dispatch Calculation Breakdown',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppConstants.primaryNavy),
              ),
            ],
          ),
          const Divider(height: 14),
          Row(
            children: d.commodityBreakdown.map((c) {
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
                          Text('Rec. Dispatch: ${c.recommendedDispatchKg.toStringAsFixed(0)} kg',
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppConstants.successGreen)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text('Formula: ${c.formulaDisplay}',
                          style: const TextStyle(
                              fontSize: 10,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w600,
                              color: AppConstants.textSecondary)),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Current Stock: ${c.currentStockKg.toStringAsFixed(0)} kg',
                              style: const TextStyle(
                                  fontSize: 10, color: AppConstants.textSecondary)),
                          Text('Safety Buffer: +${c.safetyBufferKg.toStringAsFixed(0)} kg',
                              style: const TextStyle(
                                  fontSize: 10, color: AppConstants.purpleAccent)),
                        ],
                      ),
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
          'Notice: DEMO DATA — NOT GOVERNMENT DATA (DISPATCH DECISION ENGINE)',
          style: TextStyle(fontSize: 10, color: AppConstants.textTertiary),
        ),
        Row(
          children: [
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: _isSaving ? null : _saveRecommendation,
              icon: _isSaving
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check_circle_outline, size: 16),
              label: const Text('Save Recommendation for Validation',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppConstants.successGreen,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
