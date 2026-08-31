import 'package:flutter/material.dart';
import '../core/constants.dart';

class DecisionFormulaCard extends StatelessWidget {
  final double predictedDemandKg;
  final double currentStockKg;
  final double safetyBufferKg;
  final double recommendedDispatchKg;

  const DecisionFormulaCard({
    super.key,
    required this.predictedDemandKg,
    required this.currentStockKg,
    required this.safetyBufferKg,
    required this.recommendedDispatchKg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.space20),
      decoration: BoxDecoration(
        color: AppConstants.primaryNavy.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        border: Border.all(color: AppConstants.accentBlue.withValues(alpha: 0.3), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.functions, size: 18, color: AppConstants.primaryNavy),
                  SizedBox(width: 8),
                  Text(
                    'GOVERNMENT PRE-DISPATCH DECISION FORMULA',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppConstants.primaryNavy,
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppConstants.accentBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'DETERMINISTIC RULE',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: AppConstants.accentBlue,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.space16),

          // Formula Breakdown Blocks
          LayoutBuilder(
            builder: (context, constraints) {
              final isSmall = constraints.maxWidth < 650;

              if (isSmall) {
                return Column(
                  children: [
                    _buildFormulaTile('Predicted Demand (D̂)', '${predictedDemandKg.toStringAsFixed(1)} kg', AppConstants.textPrimary),
                    const SizedBox(height: 6),
                    _buildOperatorTile('-'),
                    const SizedBox(height: 6),
                    _buildFormulaTile('Current Stock (S)', '${currentStockKg.toStringAsFixed(1)} kg', AppConstants.textSecondary),
                    const SizedBox(height: 6),
                    _buildOperatorTile('+'),
                    const SizedBox(height: 6),
                    _buildFormulaTile('Safety Buffer (B)', '${safetyBufferKg.toStringAsFixed(1)} kg', AppConstants.accentAmber),
                    const SizedBox(height: 6),
                    _buildOperatorTile('='),
                    const SizedBox(height: 6),
                    _buildFormulaTile('Recommended Dispatch (Q*)', '${recommendedDispatchKg.toStringAsFixed(1)} kg', AppConstants.accentBlue, isResult: true),
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(flex: 3, child: _buildFormulaTile('Predicted Demand (D̂)', '${predictedDemandKg.toStringAsFixed(1)} kg', AppConstants.textPrimary)),
                  _buildOperatorTile('-'),
                  Expanded(flex: 3, child: _buildFormulaTile('Current Stock (S)', '${currentStockKg.toStringAsFixed(1)} kg', AppConstants.textSecondary)),
                  _buildOperatorTile('+'),
                  Expanded(flex: 3, child: _buildFormulaTile('Safety Buffer (B)', '${safetyBufferKg.toStringAsFixed(1)} kg', AppConstants.accentAmber)),
                  _buildOperatorTile('='),
                  Expanded(flex: 4, child: _buildFormulaTile('Recommended Dispatch (Q*)', '${recommendedDispatchKg.toStringAsFixed(1)} kg', AppConstants.accentBlue, isResult: true)),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFormulaTile(String label, String value, Color color, {bool isResult = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isResult ? AppConstants.primaryNavy : Colors.white,
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        border: Border.all(
          color: isResult ? AppConstants.primaryNavy : AppConstants.cardBorder,
          width: isResult ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: isResult ? Colors.white70 : AppConstants.textSecondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: isResult ? 16 : 14,
              fontWeight: FontWeight.w800,
              color: isResult ? Colors.white : color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOperatorTile(String op) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Text(
        op,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w900,
          color: AppConstants.primaryNavy,
        ),
      ),
    );
  }
}
