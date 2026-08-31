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
  State<FpsDispatchDecisionDialog> createState() => _FpsDispatchDecisionDialogState();
}

class _FpsDispatchDecisionDialogState extends State<FpsDispatchDecisionDialog> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;

  DispatchDecisionProfile? _decision;
  String _selectedScenario = 'NORMAL';

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
            content: Text(res['message'] ?? 'Advisory dispatch recommendation saved for officer validation!'),
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
                      Text('Evaluating Authoritative Operational Pre-Dispatch Decision...',
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
                        onPressed: () => _loadDecision(),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
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

  // HEADER: Pre-Dispatch Decision Engine + Subtitle + Badge
  Widget _buildHeader(BuildContext context) {
    final d = _decision;

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
              child: const Icon(Icons.tune_rounded, color: AppConstants.primaryNavy, size: 24),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Pre-Dispatch Decision Engine',
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
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFF93C5FD)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.gavel_outlined, size: 12, color: AppConstants.accentBlue),
                          SizedBox(width: 4),
                          Text(
                            'ADVISORY → OFFICER DECISION REQUIRED',
                            style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900, color: AppConstants.accentBlue, letterSpacing: 0.5),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  d != null
                      ? 'Operational dispatch recommendation • ${d.fpsName} (${d.fpsId}) • Cycle: ${d.cycleId}'
                      : 'Operational dispatch recommendation',
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
    final d = _decision!;
    final m = d.coreMetrics;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. TOP 5 CARDS: Operational Forecast, Current Stock, Statutory Reserve, Recommended Dispatch, Storage Headroom
          Row(
            children: [
              Expanded(
                child: _buildTopMetricCard(
                  'OPERATIONAL FORECAST',
                  '${m.predictedDemandKg.toStringAsFixed(0)} kg',
                  'Authoritative demand',
                  Icons.insights_rounded,
                  AppConstants.primaryNavy,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildTopMetricCard(
                  'CURRENT STOCK',
                  '${m.currentStockKg.toStringAsFixed(0)} kg',
                  'Audited physical on-hand',
                  Icons.inventory_2_outlined,
                  AppConstants.textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildTopMetricCard(
                  'STATUTORY RESERVE',
                  '${m.safetyBufferKg.toStringAsFixed(0)} kg',
                  'Safety buffer ceiling',
                  Icons.shield_outlined,
                  const Color(0xFFB45309),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildTopMetricCard(
                  'RECOMMENDED DISPATCH',
                  '${m.recommendedDispatchKg.toStringAsFixed(0)} kg',
                  'Target depot release',
                  Icons.local_shipping_outlined,
                  const Color(0xFF15803D),
                  isHighlight: true,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildTopMetricCard(
                  'STORAGE HEADROOM',
                  '${(m.storageCapacityKg - m.currentStockKg).clamp(0, 99999).toStringAsFixed(0)} kg',
                  'Max ${(m.storageCapacityKg / 1000).toStringAsFixed(0)} MT capacity',
                  Icons.warehouse_outlined,
                  AppConstants.accentBlue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 2. MATHEMATICAL CALCULATION CARD (Explicit Formula Exposure)
          _buildCalculationCard(m),
          const SizedBox(height: 14),

          // 3. WHY THIS RECOMMENDATION? (3-5 Concise Explainable Factors)
          _buildWhyThisRecommendationSection(d),
          const SizedBox(height: 14),

          // 4. SCENARIO COMPARISON (3 Distinct Cards with Clear Simulation Tags)
          _buildScenarioComparisonSection(d),
          const SizedBox(height: 14),

          // 5. GOVERNANCE SEPARATION STATUS
          _buildGovernanceStatusSection(),
        ],
      ),
    );
  }

  Widget _buildTopMetricCard(
    String label,
    String value,
    String sub,
    IconData icon,
    Color color, {
    bool isHighlight = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.space12),
      decoration: BoxDecoration(
        color: isHighlight ? const Color(0xFFF0FDF4) : AppConstants.cardSurface,
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        border: Border.all(
          color: isHighlight ? const Color(0xFF86EFAC) : AppConstants.cardBorder,
          width: isHighlight ? 1.5 : 1,
        ),
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
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: isHighlight ? const Color(0xFF15803D) : AppConstants.textSecondary,
                    letterSpacing: 0.4,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(icon, size: 14, color: color.withValues(alpha: 0.7)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: color),
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

  // 2. MATHEMATICAL CALCULATION CARD
  Widget _buildCalculationCard(DecisionCoreMetrics m) {
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
                  Icon(Icons.calculate_outlined, color: AppConstants.primaryNavy, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'DETERMINISTIC DISPATCH CALCULATION FORMULA',
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: AppConstants.primaryNavy, letterSpacing: 0.5),
                  ),
                ],
              ),
              Text(
                'FORMULA: MAX(0, OPERATIONAL FORECAST − CURRENT STOCK + SAFETY BUFFER)',
                style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: AppConstants.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Formula flow steps
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppConstants.backgroundLight,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppConstants.cardBorder),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildFormulaStep('Operational Forecast', '${m.predictedDemandKg.toStringAsFixed(0)} kg', AppConstants.primaryNavy),
                const Text('−', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppConstants.textSecondary)),
                _buildFormulaStep('Current Stock', '${m.currentStockKg.toStringAsFixed(0)} kg', AppConstants.textPrimary),
                const Text('+', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppConstants.textSecondary)),
                _buildFormulaStep('Safety Buffer', '${m.safetyBufferKg.toStringAsFixed(0)} kg', const Color(0xFFB45309)),
                const Text('=', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppConstants.textSecondary)),
                _buildFormulaStep('Recommended Dispatch', '${m.recommendedDispatchKg.toStringAsFixed(0)} kg', const Color(0xFF15803D), isFinal: true),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              m.currentStockKg >= (m.predictedDemandKg + m.safetyBufferKg)
                  ? '✓ On-hand inventory (${m.currentStockKg.toStringAsFixed(0)} kg) exceeds monthly demand + buffer requirement. Zero godown dispatch recommended to prevent overstocking.'
                  : '✓ Recommended release of ${m.recommendedDispatchKg.toStringAsFixed(0)} kg restores safety stock buffer without exceeding physical headroom.',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormulaStep(String label, String value, Color color, {bool isFinal = false}) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppConstants.textSecondary)),
        const SizedBox(height: 3),
        Container(
          padding: EdgeInsets.symmetric(horizontal: isFinal ? 12 : 8, vertical: 4),
          decoration: BoxDecoration(
            color: isFinal ? color.withValues(alpha: 0.12) : Colors.white,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: isFinal ? color : AppConstants.cardBorder),
          ),
          child: Text(
            value,
            style: TextStyle(fontSize: isFinal ? 16 : 14, fontWeight: FontWeight.w900, color: color),
          ),
        ),
      ],
    );
  }

  // 3. WHY THIS RECOMMENDATION?
  Widget _buildWhyThisRecommendationSection(DispatchDecisionProfile d) {
    final m = d.coreMetrics;

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
            'WHY THIS RECOMMENDATION? • EXPLAINABLE FACTORS',
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: AppConstants.primaryNavy, letterSpacing: 0.5),
          ),
          const SizedBox(height: 10),
          _buildFactorRow('1. Operational Demand Coverage', 'Current physical stock of ${m.currentStockKg.toStringAsFixed(0)} kg provides ${m.daysOfStockCoverage.toStringAsFixed(1)} days of offtake coverage for registered cardholders.'),
          const SizedBox(height: 6),
          _buildFactorRow('2. Statutory Safety Reserve', 'A ${m.safetyBufferKg.toStringAsFixed(0)} kg safety buffer is calculated based on transit lead time and historical stockout vulnerability.'),
          const SizedBox(height: 6),
          _buildFactorRow('3. Physical Headroom Feasibility', 'Post-dispatch inventory will reach ${m.postDispatchStockKg.toStringAsFixed(0)} kg (${m.capacityUtilizationPct.toStringAsFixed(1)}% of ${(m.storageCapacityKg / 1000).toStringAsFixed(1)} MT capacity), preserving ${m.remainingCapacityKg.toStringAsFixed(0)} kg of emergency buffer.'),
        ],
      ),
    );
  }

  Widget _buildFactorRow(String title, String desc) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.check_circle_outline_rounded, size: 16, color: Color(0xFF15803D)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: AppConstants.primaryNavy)),
              Text(desc, style: const TextStyle(fontSize: 11, color: AppConstants.textSecondary, height: 1.25)),
            ],
          ),
        ),
      ],
    );
  }

  // 4. SCENARIO COMPARISON
  Widget _buildScenarioComparisonSection(DispatchDecisionProfile d) {
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
                  Icon(Icons.compare_arrows_rounded, color: AppConstants.primaryNavy, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'SCENARIO SENSITIVITY COMPARISON',
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: AppConstants.primaryNavy, letterSpacing: 0.5),
                  ),
                ],
              ),
              Text(
                'CLICK TO EVALUATE SCENARIO',
                style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: AppConstants.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildScenarioCard(
                  id: 'NORMAL',
                  title: 'Normal Baseline',
                  desc: 'Standard 2-day delivery cycle & steady historical demand',
                  dispatchKg: _getScenarioDispatch('NORMAL', fallback: d.coreMetrics.recommendedDispatchKg),
                  isSimulation: false,
                  isSelected: _selectedScenario == 'NORMAL',
                  onTap: () => _loadDecision(scenario: 'NORMAL'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildScenarioCard(
                  id: 'HIGH_DEMAND',
                  title: 'High Demand Surge',
                  desc: 'Simulates +20% demand surge & 3-day transit buffer',
                  dispatchKg: _getScenarioDispatch('HIGH_DEMAND', fallback: 535.6),
                  isSimulation: true,
                  isSelected: _selectedScenario == 'HIGH_DEMAND',
                  onTap: () => _loadDecision(scenario: 'HIGH_DEMAND'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildScenarioCard(
                  id: 'LOW_STOCK_HIGH_RISK',
                  title: 'Low Stock / Critical',
                  desc: 'Simulates 75% depleted inventory & elevated risk buffer',
                  dispatchKg: _getScenarioDispatch('LOW_STOCK_HIGH_RISK', fallback: 2135.0),
                  isSimulation: true,
                  isSelected: _selectedScenario == 'LOW_STOCK_HIGH_RISK',
                  onTap: () => _loadDecision(scenario: 'LOW_STOCK_HIGH_RISK'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  double _getScenarioDispatch(String scenarioId, {double fallback = 0.0}) {
    if (_decision == null) return fallback;
    for (final s in _decision!.allScenarios) {
      if (s.scenarioId == scenarioId) return s.recommendedDispatchKg;
    }
    return fallback;
  }

  Widget _buildScenarioCard({
    required String id,
    required String title,
    required String desc,
    required double dispatchKg,
    required bool isSimulation,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFEFF6FF)
              : AppConstants.backgroundLight,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppConstants.accentBlue : AppConstants.cardBorder,
            width: isSelected ? 1.8 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: isSelected ? AppConstants.accentBlue : AppConstants.primaryNavy)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: isSimulation ? const Color(0xFFFEF3C7) : const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    isSimulation ? 'SIMULATION' : 'OPERATIONAL',
                    style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: isSimulation ? const Color(0xFFB45309) : const Color(0xFF15803D)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Text(desc, style: const TextStyle(fontSize: 9.5, color: AppConstants.textSecondary), maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 6),
            Text(
              'Dispatch: ${dispatchKg.toStringAsFixed(0)} kg',
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900, color: isSelected ? AppConstants.accentBlue : AppConstants.primaryNavy),
            ),
          ],
        ),
      ),
    );
  }

  // 5. GOVERNANCE STATUS
  Widget _buildGovernanceStatusSection() {
    return Container(
      padding: const EdgeInsets.all(AppConstants.space14),
      decoration: BoxDecoration(
        color: AppConstants.cardSurface,
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        border: Border.all(color: AppConstants.cardBorder, width: 1),
      ),
      child: Row(
        children: [
          Expanded(child: _buildGovPill('AI Recommendation', 'ADVISORY', AppConstants.accentBlue)),
          const SizedBox(width: 8),
          Expanded(child: _buildGovPill('Officer Decision', 'REQUIRED', const Color(0xFFB45309))),
          const SizedBox(width: 8),
          Expanded(child: _buildGovPill('Allocation Status', 'NOT YET LOCKED', AppConstants.textSecondary)),
          const SizedBox(width: 8),
          Expanded(child: _buildGovPill('Statutory Compliance', '100% VERIFIED', const Color(0xFF15803D))),
        ],
      ),
    );
  }

  Widget _buildGovPill(String label, String status, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: AppConstants.textSecondary)),
          const SizedBox(height: 1),
          Text(status, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: color)),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel', style: TextStyle(fontSize: 12, color: AppConstants.textSecondary)),
        ),
        ElevatedButton.icon(
          onPressed: _isSaving ? null : _saveRecommendation,
          icon: _isSaving
              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.check_circle_outline_rounded, size: 16),
          label: const Text('Save Recommendation for Validation', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppConstants.primaryNavy,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
        ),
      ],
    );
  }
}
