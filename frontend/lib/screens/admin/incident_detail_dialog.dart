import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../models/admin_model.dart';

class IncidentDetailDialog extends StatefulWidget {
  final OperationalIncident incident;
  final VoidCallback? onAcknowledge;
  final VoidCallback? onApplyAction;

  const IncidentDetailDialog({
    super.key,
    required this.incident,
    this.onAcknowledge,
    this.onApplyAction,
  });

  @override
  State<IncidentDetailDialog> createState() => _IncidentDetailDialogState();
}

class _IncidentDetailDialogState extends State<IncidentDetailDialog> {
  late bool _isAcknowledged;
  late bool _isActionApplied;

  @override
  void initState() {
    super.initState();
    _isAcknowledged = widget.incident.isAcknowledged;
    _isActionApplied = widget.incident.isActionApplied;
  }

  Color _getSeverityColor() {
    switch (widget.incident.severity) {
      case 'HIGH_RISK':
        return AppConstants.dangerRed;
      case 'MEDIUM_RISK':
        return const Color(0xFFD97706);
      default:
        return AppConstants.accentBlue;
    }
  }

  String _getSeverityLabel() {
    switch (widget.incident.severity) {
      case 'HIGH_RISK':
        return '🔴 HIGH RISK (CRITICAL)';
      case 'MEDIUM_RISK':
        return '🟠 MEDIUM RISK (WARNING)';
      default:
        return '🔵 ADVISORY';
    }
  }

  @override
  Widget build(BuildContext context) {
    final sevColor = _getSeverityColor();
    final inc = widget.incident;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        width: 720,
        constraints: const BoxConstraints(maxHeight: 780),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Alert ID, Severity, Close
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: sevColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.warning_amber_rounded, color: sevColor, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              inc.id,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: AppConstants.textSecondary,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: sevColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: sevColor.withValues(alpha: 0.4)),
                              ),
                              child: Text(
                                _getSeverityLabel(),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: sevColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          inc.title,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            color: AppConstants.primaryNavy,
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
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),

            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Telemetry 2x2 Metric Summary Grid
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppConstants.cardBorder),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _buildDetailMetric(
                                  label: 'AFFECTED LOCATION',
                                  value: inc.affectedFps,
                                  icon: Icons.storefront_rounded,
                                  iconColor: AppConstants.primaryNavy,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildDetailMetric(
                                  label: 'ASSIGNED CORRIDOR / CARRIER',
                                  value: inc.affectedTruckId,
                                  icon: Icons.local_shipping_rounded,
                                  iconColor: AppConstants.accentBlue,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _buildDetailMetric(
                                  label: 'PROJECTED DEFICIT / CONSTRAINT',
                                  value: inc.projectedShortageOrConstraint,
                                  icon: Icons.trending_up_rounded,
                                  iconColor: sevColor,
                                  isHighlight: true,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildDetailMetric(
                                  label: 'REQUIRED SUPPLY ADJUSTMENT',
                                  value: inc.supplyAdjustment,
                                  icon: Icons.inventory_2_outlined,
                                  iconColor: const Color(0xFF15803D),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 2. What Was Detected Section
                    _buildSectionBlock(
                      title: '1. What Was Detected (Telemetry Anomaly)',
                      icon: Icons.search_rounded,
                      iconColor: AppConstants.primaryNavy,
                      content: inc.explanation,
                    ),
                    const SizedBox(height: 14),

                    // 3. Why It Matters Section
                    _buildSectionBlock(
                      title: '2. Why It Matters (Operational Impact)',
                      icon: Icons.crisis_alert_rounded,
                      iconColor: sevColor,
                      content: inc.whyItMatters,
                    ),
                    const SizedBox(height: 14),

                    // 4. Algorithmic Recommendation Section
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFBBF7D0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.lightbulb_rounded, color: Color(0xFF15803D), size: 18),
                              SizedBox(width: 8),
                              Text(
                                '3. Recommended System Action (Pre-Dispatch)',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF166534),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            inc.recommendation,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF14532D),
                              height: 1.45,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Status Indicator
                    if (_isAcknowledged || _isActionApplied) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFA7F3D0)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle_rounded, color: Color(0xFF059669), size: 18),
                            const SizedBox(width: 8),
                            Text(
                              _isActionApplied
                                  ? '✓ Recommendation successfully applied by District Supply Officer.'
                                  : '✓ Incident acknowledged by District Supply Officer.',
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF065F46),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 14),

            // Footer Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'SIH-2026 Pre-Dispatch Anomaly Engine',
                  style: TextStyle(fontSize: 10.5, color: AppConstants.textTertiary),
                ),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () {
                        setState(() {
                          _isAcknowledged = true;
                          widget.incident.isAcknowledged = true;
                        });
                        widget.onAcknowledge?.call();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Incident ${inc.id} acknowledged.'),
                            backgroundColor: AppConstants.primaryNavy,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                      icon: Icon(
                        _isAcknowledged ? Icons.check : Icons.done_all_rounded,
                        size: 16,
                      ),
                      label: Text(_isAcknowledged ? 'Acknowledged' : 'Acknowledge Alert'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _isAcknowledged = true;
                          _isActionApplied = true;
                          widget.incident.isAcknowledged = true;
                          widget.incident.isActionApplied = true;
                        });
                        widget.onApplyAction?.call();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('✓ Action applied: ${inc.officerActionTitle}'),
                            backgroundColor: AppConstants.successGreen,
                            duration: const Duration(seconds: 3),
                          ),
                        );
                      },
                      icon: const Icon(Icons.flash_on_rounded, size: 16),
                      label: Text(
                        _isActionApplied ? 'Action Applied ✓' : inc.officerActionTitle,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isActionApplied ? const Color(0xFF059669) : AppConstants.primaryNavy,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailMetric({
    required String label,
    required String value,
    required IconData icon,
    required Color iconColor,
    bool isHighlight = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 13, color: iconColor),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                color: AppConstants.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: isHighlight ? AppConstants.dangerRed : AppConstants.primaryNavy,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildSectionBlock({
    required String title,
    required IconData icon,
    required Color iconColor,
    required String content,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppConstants.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 16),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: iconColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            content,
            style: const TextStyle(
              fontSize: 11.5,
              color: AppConstants.textPrimary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
