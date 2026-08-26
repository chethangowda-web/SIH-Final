import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../models/admin_model.dart';
import '../../services/api_service.dart';
import 'fps_forecast_detail_dialog.dart';
import 'fps_dispatch_decision_dialog.dart';
import 'constraint_validation_dialog.dart';
import 'delivery_feedback_dialog.dart';

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
    extends State<FpsPreDispatchInspectorDialog> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  bool _isAnalyzing = false;
  String? _errorMessage;
  FpsAnalyticsProfile? _profile;
  PreDispatchAnalysisResult? _analysisResult;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await _apiService.fetchFpsAnalytics(widget.fpsId,
          cycleId: widget.cycleId);
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
          _analysisResult = res;
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
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Container(
        width: 1050,
        height: 780,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            const SizedBox(height: 16),
            if (_isLoading)
              const Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: AppConstants.primaryNavy),
                      SizedBox(height: 12),
                      Text('Loading Fair Price Shop Operational Profile...',
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
                        onPressed: _loadProfile,
                        child: const Text('Retry'),
                      )
                    ],
                  ),
                ),
              )
            else ...[
              _buildTopIdentityBar(),
              const SizedBox(height: 14),
              Expanded(child: _buildDetailsScrollable()),
            ],
            const SizedBox(height: 14),
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
                color: AppConstants.primaryNavy.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.storefront_outlined,
                  color: AppConstants.primaryNavy, size: 24),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Fair Price Shop Pre-Dispatch Decision Dossier',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppConstants.textPrimary,
                  ),
                ),
                Text(
                  'Pre-Dispatch Intelligence • Historical Consumption • Migrant Shift • Corridor Routing',
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

  Widget _buildTopIdentityBar() {
    final p = _profile!;
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
                  p.fpsId,
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
                    p.fpsName,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppConstants.textPrimary),
                  ),
                  Text(
                    '${p.district} • Coordinates: ${p.latitude.toStringAsFixed(4)}, ${p.longitude.toStringAsFixed(4)}',
                    style: const TextStyle(
                        fontSize: 11, color: AppConstants.textSecondary),
                  ),
                ],
              ),
            ],
          ),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => FpsForecastDetailDialog(
                      fpsId: p.fpsId,
                      cycleId: widget.cycleId,
                    ),
                  );
                },
                icon: const Icon(Icons.psychology_outlined, size: 16),
                label: const Text('Forecast & What-If',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppConstants.primaryNavy,
                  side: const BorderSide(color: AppConstants.primaryNavy),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                ),
              ),
              const SizedBox(width: 6),
              OutlinedButton.icon(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => FpsDispatchDecisionDialog(
                      fpsId: p.fpsId,
                      cycleId: widget.cycleId,
                    ),
                  );
                },
                icon: const Icon(Icons.local_shipping_outlined, size: 16),
                label: const Text('Dispatch Decision',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppConstants.successGreen,
                  side: const BorderSide(color: AppConstants.successGreen),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                ),
              ),
              const SizedBox(width: 6),
              OutlinedButton.icon(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => ConstraintValidationDialog(
                      cycleId: widget.cycleId,
                      initialFpsId: p.fpsId,
                    ),
                  );
                },
                icon: const Icon(Icons.rule_folder_outlined, size: 16),
                label: const Text('9 Rules',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF0284C7),
                  side: const BorderSide(color: Color(0xFF0284C7)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                ),
              ),
              const SizedBox(width: 6),
              OutlinedButton.icon(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => DeliveryFeedbackDialog(
                      fpsId: p.fpsId,
                      cycleId: widget.cycleId,
                    ),
                  );
                },
                icon: const Icon(Icons.rate_review_outlined, size: 16),
                label: const Text('Feedback',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF0D9488),
                  side: const BorderSide(color: Color(0xFF0D9488)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _isAnalyzing ? null : _runAnalysis,
                icon: _isAnalyzing
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.play_circle_filled_rounded, size: 16),
                label: const Text('Run Pre-Dispatch Analysis',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppConstants.accentBlue,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsScrollable() {
    final p = _profile!;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_analysisResult != null) ...[
            _buildPipelineResultCard(_analysisResult!),
            const SizedBox(height: 16),
          ],

          // 4-Column Operational Stats Grid
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildMetricCard(
                  'Beneficiary Quota',
                  '${p.beneficiariesCount} Cards',
                  'Entitlement: Rice ${p.entitlementRiceKg.toStringAsFixed(0)}kg + Wheat ${p.entitlementWheatKg.toStringAsFixed(0)}kg',
                  Icons.people_alt_outlined,
                  AppConstants.accentBlue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard(
                  'Current Stock vs Cap',
                  '${p.currentStockKg.toStringAsFixed(0)} / ${p.storageCapacityKg.toStringAsFixed(0)} kg',
                  'Headroom: ${p.storageHeadroomKg.toStringAsFixed(0)} kg (${p.capacityUtilizationPct.toStringAsFixed(1)}% full)',
                  Icons.inventory_2_outlined,
                  p.capacityUtilizationPct > 80
                      ? AppConstants.dangerRed
                      : AppConstants.successGreen,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard(
                  'Portability & Trends',
                  p.portabilityLabel,
                  'Recent 3-Cycle Trend: ${p.recentTrendPct >= 0 ? "+" : ""}${p.recentTrendPct.toStringAsFixed(1)}%',
                  Icons.swap_horiz_rounded,
                  p.portabilityRate > 0.20
                      ? AppConstants.purpleAccent
                      : AppConstants.primaryNavy,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard(
                  'Stock-out & Risk Rating',
                  p.stockoutFrequencyLabel,
                  'Seasonal Multiplier: ${p.seasonalFactor.toStringAsFixed(2)}x • Risk: ${p.riskLevel}',
                  Icons.health_and_safety_outlined,
                  p.stockoutFrequency > 0.10
                      ? AppConstants.accentAmber
                      : AppConstants.tealAccent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 6-Cycle Historical Offtake Matrix
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppConstants.cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.history_toggle_off,
                            color: AppConstants.primaryNavy, size: 18),
                        SizedBox(width: 8),
                        Text(
                          '6-Cycle Multi-Month Consumption & Offtake History',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppConstants.primaryNavy),
                        ),
                      ],
                    ),
                    Text(
                      'Baseline Cycles: 2026-03 to 2026-08',
                      style: TextStyle(
                          fontSize: 11, color: AppConstants.textSecondary),
                    ),
                  ],
                ),
                const Divider(height: 16),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: p.historicalOfftake.map((h) {
                      return Container(
                        width: 145,
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
                            Text(
                              h.cycleId,
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppConstants.primaryNavy),
                            ),
                            const SizedBox(height: 6),
                            Text('Rice: ${h.riceKg.toStringAsFixed(0)} kg',
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: AppConstants.textSecondary)),
                            Text('Wheat: ${h.wheatKg.toStringAsFixed(0)} kg',
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: AppConstants.textSecondary)),
                            const Divider(height: 8),
                            Text('Total: ${h.totalKg.toStringAsFixed(0)} kg',
                                style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: AppConstants.textPrimary)),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Supply Chain Logistics & Corridor Routing
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppConstants.cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.alt_route_rounded,
                        color: AppConstants.accentBlue, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Supply-Chain Corridor Route & Depot Assignment',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppConstants.primaryNavy),
                    ),
                  ],
                ),
                const Divider(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildDetailRow('Source Depot', p.assignedDepot),
                          _buildDetailRow('Designated Route ID', p.routeId),
                          _buildDetailRow('Road Distance',
                              '${p.roadDistanceKm.toStringAsFixed(1)} km'),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildDetailRow('Estimated Transit Time',
                              '${p.estimatedTransitTimeMins} minutes'),
                          _buildDetailRow('Road Infrastructure', p.roadCondition),
                          _buildDetailRow('Transit Restrictions',
                              p.restrictionStatus == 'CLEAR'
                                  ? '✓ Clear Route (No restrictions)'
                                  : '⚠️ ${p.restrictionStatus.replaceAll("_", " ")}'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPipelineResultCard(PreDispatchAnalysisResult res) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppConstants.primaryNavy.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppConstants.accentBlue.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.check_circle_outline,
                      color: AppConstants.successGreen, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Pre-Dispatch Pipeline Execution: ${res.analysisMode}',
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppConstants.primaryNavy),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppConstants.successGreen.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('ALL 6 STAGES COMPLETED',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppConstants.successGreen)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: res.pipelineStages.map((stg) {
                return Container(
                  width: 155,
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppConstants.cardBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(stg.stage,
                          style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppConstants.primaryNavy)),
                      const SizedBox(height: 4),
                      Text(stg.value,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppConstants.textPrimary)),
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

  Widget _buildMetricCard(
      String title, String value, String subtext, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppConstants.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppConstants.textSecondary)),
              Icon(icon, size: 16, color: color),
            ],
          ),
          const SizedBox(height: 6),
          Text(value,
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 4),
          Text(subtext,
              style: const TextStyle(
                  fontSize: 10, color: AppConstants.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 11, color: AppConstants.textSecondary)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppConstants.textPrimary)),
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
          'Notice: DEMO DATA — NOT GOVERNMENT DATA (PRE-DISPATCH INTELLIGENCE)',
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
