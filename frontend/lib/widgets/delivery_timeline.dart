import 'package:flutter/material.dart';
import '../core/constants.dart';

class DeliveryTimeline extends StatelessWidget {
  final String currentStatus;

  const DeliveryTimeline({
    super.key,
    required this.currentStatus,
  });

  static const List<Map<String, dynamic>> _steps = [
    {'key': 'SERVICE_REQUESTED', 'label': 'Requested', 'icon': Icons.send_rounded},
    {'key': 'ALLOCATED', 'label': 'Allocated', 'icon': Icons.inventory_2_outlined},
    {'key': 'OUT_FOR_DELIVERY', 'label': 'Out for Delivery', 'icon': Icons.local_shipping_outlined},
    {'key': 'DELIVERED', 'label': 'Delivered', 'icon': Icons.home_outlined},
    {'key': 'DELIVERY_CONFIRMED', 'label': 'Confirmed', 'icon': Icons.verified_outlined},
  ];

  int _getCurrentStepIndex() {
    switch (currentStatus.toUpperCase()) {
      case 'SERVICE_REQUESTED':
      case 'SUBMITTED':
      case 'RECORDED':
        return 0;
      case 'ALLOCATED':
      case 'OFFICER_APPROVED':
      case 'PARTIAL_ALLOCATION':
        return 1;
      case 'OUT_FOR_DELIVERY':
      case 'DISPATCHED':
        return 2;
      case 'DELIVERED':
      case 'ARRIVED':
        return 3;
      case 'DELIVERY_CONFIRMED':
      case 'CONFIRMED':
        return 4;
      case 'DELIVERY_DISPUTE':
      case 'DISPUTE':
        return 3; // Dispute occurs after attempted/received delivery
      default:
        return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = _getCurrentStepIndex();
    final isDispute = currentStatus == 'DELIVERY_DISPUTE';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppConstants.space16, vertical: AppConstants.space12),
      decoration: BoxDecoration(
        color: AppConstants.cardSurface,
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        border: Border.all(color: AppConstants.cardBorder, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'ORDER & DELIVERY TRACKING',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: AppConstants.textSecondary,
                  letterSpacing: 0.5,
                ),
              ),
              if (isDispute)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.orange.shade300),
                  ),
                  child: Text(
                    'DISPUTE UNDER DSO INVESTIGATION',
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.orange.shade900),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppConstants.space12),

          Row(
            children: List.generate(_steps.length * 2 - 1, (index) {
              if (index.isOdd) {
                final stepIndex = index ~/ 2;
                final isPassed = stepIndex < currentIndex;
                return Expanded(
                  child: Container(
                    height: 2,
                    color: isPassed ? AppConstants.successGreen : AppConstants.cardBorder,
                  ),
                );
              }

              final stepIndex = index ~/ 2;
              final step = _steps[stepIndex];
              final isCompleted = stepIndex < currentIndex;
              final isCurrent = stepIndex == currentIndex;

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: isCompleted
                          ? AppConstants.successGreen
                          : (isCurrent
                              ? (isDispute ? Colors.orange.shade800 : AppConstants.primaryNavy)
                              : const Color(0xFFF1F5F9)),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isCompleted
                            ? AppConstants.successGreen
                            : (isCurrent ? (isDispute ? Colors.orange.shade800 : AppConstants.primaryNavy) : AppConstants.cardBorder),
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                      child: isCompleted
                          ? const Icon(Icons.check, size: 14, color: Colors.white)
                          : Icon(
                              step['icon'] as IconData,
                              size: 13,
                              color: isCurrent ? Colors.white : AppConstants.textSecondary,
                            ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    step['label'] as String,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w500,
                      color: isCurrent
                          ? AppConstants.primaryNavy
                          : (isCompleted ? AppConstants.textPrimary : AppConstants.textTertiary),
                    ),
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }
}
