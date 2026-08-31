import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../models/admin_model.dart';
import '../../services/api_service.dart';

class AdminFpsDetailDialog extends StatefulWidget {
  final String fpsId;
  final ApiService? apiService;

  const AdminFpsDetailDialog({
    super.key,
    required this.fpsId,
    this.apiService,
  });

  @override
  State<AdminFpsDetailDialog> createState() => _AdminFpsDetailDialogState();
}

class _AdminFpsDetailDialogState extends State<AdminFpsDetailDialog> {
  late final ApiService _apiService;
  AdminFpsDetail? _detail;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _apiService = widget.apiService ?? ApiService();
    _loadFpsDetail();
  }

  Future<void> _loadFpsDetail() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final data = await _apiService.fetchAdminFpsDetail(widget.fpsId);
      setState(() {
        _detail = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load FPS analytics: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1140, maxHeight: 840),
        child: _isLoading
            ? const Padding(
                padding: EdgeInsets.all(48),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(strokeWidth: 3),
                    SizedBox(height: 16),
                    Text('Loading shop demand telemetry...'),
                  ],
                ),
              )
            : _errorMessage != null
                ? Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.error_outline,
                            size: 44, color: Colors.red.shade400),
                        const SizedBox(height: 12),
                        Text(_errorMessage!,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.red.shade700)),
                        const SizedBox(height: 16),
                        ElevatedButton(
                            onPressed: _loadFpsDetail,
                            child: const Text('Retry')),
                      ],
                    ),
                  )
                : _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    final d = _detail!;
    final isHighRisk = d.riskLevel == 'HIGH';
    final isMedRisk = d.riskLevel == 'MEDIUM';
    final riskColor = isHighRisk
        ? AppConstants.dangerRed
        : (isMedRisk ? AppConstants.accentAmber : AppConstants.successGreen);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: AppConstants.primaryNavy,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${d.fpsId} — ${d.name}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            Text(
              '${d.district} • Capacity: ${(d.capacityKg / 1000).toStringAsFixed(0)} Ton',
              style: TextStyle(
                  fontSize: 11, color: Colors.white.withValues(alpha: 0.8)),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Status & Risk Banner
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: riskColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: riskColor.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: riskColor,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${d.riskLevel} RISK',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      d.riskReason,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppConstants.primaryNavy,
                      ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Text(
                      'Status: ${d.status}',
                      style: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // 5 Metrics Grid Cards
            Row(
              children: [
                Expanded(
                  child: _buildMetricMiniCard(
                    'Historical Baseline (H)',
                    '${d.historicalDemandKg.toStringAsFixed(1)} kg',
                    '6-Cycle Past Lifting Avg',
                    Icons.history_rounded,
                    AppConstants.primaryNavy,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMetricMiniCard(
                    'Declared Intent (I)',
                    '${d.declaredIntentKg.toStringAsFixed(1)} kg',
                    '${d.intentShiftKg >= 0 ? "+" : ""}${d.intentShiftKg.toStringAsFixed(0)} kg Shift',
                    Icons.speed_rounded,
                    d.intentShiftKg >= 0
                        ? AppConstants.accentAmber
                        : AppConstants.textSecondary,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMetricMiniCard(
                    'Intent Confidence (C)',
                    '${(d.confidenceScore * 100).toStringAsFixed(0)}%',
                    'Verified Intent Score',
                    Icons.verified_user_outlined,
                    AppConstants.successGreen,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMetricMiniCard(
                    'Forecast Demand (D̂)',
                    '${d.forecastKg.toStringAsFixed(1)} kg',
                    'D̂=(1-w·C)H+w·C·I',
                    Icons.auto_graph_rounded,
                    AppConstants.accentBlue,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMetricMiniCard(
                    'Recommended Dispatch',
                    '${d.recommendedDispatchKg.toStringAsFixed(1)} kg',
                    'Net Supply (+5% Buffer)',
                    Icons.local_shipping_outlined,
                    AppConstants.primaryNavy,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Visual Formula Explanation Card for SIH Jury Demo
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppConstants.primaryNavy.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppConstants.primaryNavy.withValues(alpha: 0.15)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.calculate_outlined, size: 16, color: AppConstants.primaryNavy),
                      const SizedBox(width: 8),
                      const Text(
                        'DEMAND FORECAST & DISPATCH CALCULATION BREAKDOWN',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppConstants.primaryNavy,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    d.formulaExplanation ??
                        'D̂ = (1 - 0.65×C)·H + (0.65×C)·I  →  Recommended Dispatch = max(0, min(D̂×1.05 - Inventory, Capacity - Inventory))',
                    style: const TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                      height: 1.4,
                      color: AppConstants.primaryNavy,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Section: Historical Demand Chart (6 Cycles)
            Text(
              '6-MONTH HISTORICAL DEMAND TIME-SERIES (RICE & WHEAT)',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppConstants.textSecondary,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 10),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppConstants.bgLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppConstants.cardBorder),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      _buildLegendItem('Rice (kg)', AppConstants.primaryNavy),
                      const SizedBox(width: 16),
                      _buildLegendItem('Wheat (kg)', AppConstants.accentAmber),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Render visual bar chart for the 6 cycles
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: d.riceTrendKg.map((riceItem) {
                      final cycleId = riceItem['cycle_id'] as String;
                      final riceQty = (riceItem['quantity_kg'] as num).toDouble();
                      final wheatItem = d.wheatTrendKg.firstWhere(
                        (w) => w['cycle_id'] == cycleId,
                        orElse: () => {'quantity_kg': 0.0},
                      );
                      final wheatQty =
                          (wheatItem['quantity_kg'] as num).toDouble();
                      final total = riceQty + wheatQty;

                      // Height scale (max ~10,000 kg -> 110px max height)
                      final riceHeight = (riceQty / 8000.0) * 90.0;
                      final wheatHeight = (wheatQty / 8000.0) * 90.0;

                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${(total / 1000).toStringAsFixed(1)}k',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppConstants.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Container(
                                width: 14,
                                height: riceHeight.clamp(12.0, 95.0),
                                decoration: BoxDecoration(
                                  color: AppConstants.primaryNavy,
                                  borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(3)),
                                ),
                              ),
                              const SizedBox(width: 3),
                              Container(
                                width: 14,
                                height: wheatHeight.clamp(8.0, 95.0),
                                decoration: BoxDecoration(
                                  color: AppConstants.accentAmber,
                                  borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(3)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            cycleId.substring(5), // '03', '04', etc.
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Section: Intent Contribution & Portability Breakdown
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Portability Inflow Breakdown
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppConstants.bgLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppConstants.cardBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'INTENT SIGNALS BREAKDOWN (CYCLE 7)',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppConstants.textSecondary,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Home Resident Intents:',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: AppConstants.textSecondary),
                            ),
                            Text(
                              '${d.intentHomeCount} Beneficiaries',
                              style: const TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Portability Inflow Intents:',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: AppConstants.textSecondary),
                            ),
                            Text(
                              '${d.intentPortabilityCount} Beneficiaries',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: d.intentPortabilityCount > 15
                                    ? AppConstants.accentAmber
                                    : AppConstants.primaryNavy,
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Total Declared Signals:',
                              style: TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w700),
                            ),
                            Text(
                              '${d.intentHomeCount + d.intentPortabilityCount} Cards',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: AppConstants.accentBlue,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // Live Stock Breakdown
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppConstants.bgLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppConstants.cardBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'STORAGE & INVENTORY UTILIZATION',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppConstants.textSecondary,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...d.inventoryItems.map((inv) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${inv['commodity']} Available:',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: AppConstants.textSecondary),
                                ),
                                Text(
                                  '${(inv['available_quantity_kg'] as num).toDouble().toStringAsFixed(1)} kg',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                          );
                        }),
                        const Divider(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Capacity Utilization:',
                              style: TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w700),
                            ),
                            Text(
                              '${d.inventoryUtilizationPct.toStringAsFixed(0)}% (${(d.capacityKg / 1000).toStringAsFixed(0)}T Total)',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: d.inventoryUtilizationPct < 20
                                    ? AppConstants.dangerRed
                                    : AppConstants.secondaryNavy,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricMiniCard(String title, String value, String subtitle,
      IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppConstants.bgLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppConstants.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppConstants.textSecondary,
                ),
              ),
              Icon(icon, size: 16, color: color),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 9,
              color: AppConstants.textSecondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: AppConstants.textSecondary),
        ),
      ],
    );
  }
}
