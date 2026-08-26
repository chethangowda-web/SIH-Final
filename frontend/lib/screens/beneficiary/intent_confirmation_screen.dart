import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../models/beneficiary_model.dart';
import '../../services/api_service.dart';
import 'intent_history_screen.dart';

class IntentConfirmationScreen extends StatelessWidget {
  final Beneficiary beneficiary;
  final FpsShop intendedFps;
  final String commodityOption;
  final List<IntentRecord> submittedRecords;
  final ApiService? apiService;

  const IntentConfirmationScreen({
    super.key,
    required this.beneficiary,
    required this.intendedFps,
    required this.commodityOption,
    required this.submittedRecords,
    this.apiService,
  });

  @override
  Widget build(BuildContext context) {
    final isPortability =
        intendedFps.fpsId != beneficiary.registeredFpsId;
    final totalDeclaredKg = submittedRecords.fold<double>(
        0.0, (acc, curr) => acc + curr.declaredQuantityKg);

    final commodityStr = submittedRecords.map((r) => '${r.commodity} (${r.declaredQuantityKg.toStringAsFixed(0)} kg)').join(' + ');

    return Scaffold(
      backgroundColor: AppConstants.bgLight,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(
          'Intent Signal Recorded',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Green Success Indicator Circle
                  Center(
                    child: Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppConstants.successGreen,
                          width: 3,
                        ),
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        color: AppConstants.successGreen,
                        size: 48,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Confirmation Heading
                  const Text(
                    'Intent Recorded ✓',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: AppConstants.primaryNavy,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Your non-binding demand planning signal has been successfully ingested into the PDS pre-dispatch forecast buffer.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppConstants.textSecondary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Detailed Verification Receipt Card
                  Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: AppConstants.cardBorder),
                    ),
                    color: Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(22),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'INTENT RECEIPT METRICS',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: AppConstants.textSecondary,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(6),
                                  border:
                                      Border.all(color: Colors.green.shade300),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: const BoxDecoration(
                                        color: AppConstants.successGreen,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'RECORDED',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.green.shade800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 24),

                          // Upcoming Cycle
                          _buildReceiptRow(
                            'Upcoming Cycle:',
                            'Cycle 7 (2026-09)',
                            Icons.calendar_today_outlined,
                          ),
                          const SizedBox(height: 14),

                          // Intended FPS
                          _buildReceiptRow(
                            'Intended FPS:',
                            '${intendedFps.fpsId}\n${intendedFps.name}',
                            Icons.storefront_outlined,
                            subtitle: isPortability
                                ? '⚡ Portability Shift (Home: ${beneficiary.registeredFpsId})'
                                : 'Home Base Shop',
                            subtitleColor: isPortability
                                ? AppConstants.accentAmber
                                : Colors.green.shade700,
                          ),
                          const SizedBox(height: 14),

                          // Commodity
                          _buildReceiptRow(
                            'Commodity:',
                            commodityStr.isNotEmpty ? commodityStr : 'Rice & Wheat',
                            Icons.inventory_2_outlined,
                          ),
                          const SizedBox(height: 14),

                          // Planning signal (Quantity)
                          _buildReceiptRow(
                            'Planning signal:',
                            '${totalDeclaredKg.toStringAsFixed(1)} kg Total',
                            Icons.speed_outlined,
                            valueColor: AppConstants.accentBlue,
                            isBold: true,
                          ),
                          const SizedBox(height: 14),

                          // Beneficiary
                          _buildReceiptRow(
                            'Beneficiary:',
                            '${beneficiary.nameForDemo} (${beneficiary.pseudonymousBeneficiaryId})',
                            Icons.badge_outlined,
                          ),
                          const SizedBox(height: 14),

                          // Status
                          _buildReceiptRow(
                            'Status:',
                            'RECORDED (In Pre-Dispatch Buffer)',
                            Icons.check_circle_outline,
                            valueColor: Colors.green.shade800,
                            isBold: true,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Important Reminder Card
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppConstants.secondaryNavy.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppConstants.cardBorder),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.shield_outlined,
                            size: 20, color: AppConstants.secondaryNavy),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'This planning signal helps the district godown dispatch enough stock to ${intendedFps.name} to avoid queue stockouts.',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppConstants.textSecondary,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Actions: View History or Return Home
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => IntentHistoryScreen(
                            beneficiary: beneficiary,
                            apiService: apiService,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.history_rounded, size: 20),
                    label: const Text(
                      'View Intent History',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppConstants.primaryNavy,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop(true);
                    },
                    icon: const Icon(Icons.home_outlined, size: 18),
                    label: const Text('Back to Beneficiary Home'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppConstants.primaryNavy,
                      side: BorderSide(color: AppConstants.cardBorder),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),
                  Center(
                    child: Text(
                      'DEMO DATA — NOT GOVERNMENT DATA',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReceiptRow(
    String label,
    String value,
    IconData icon, {
    String? subtitle,
    Color? subtitleColor,
    Color? valueColor,
    bool isBold = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppConstants.textSecondary),
        const SizedBox(width: 10),
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppConstants.textSecondary,
            ),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
                  color: valueColor ?? AppConstants.primaryNavy,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: subtitleColor ?? AppConstants.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
