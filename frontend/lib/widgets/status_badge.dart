import 'package:flutter/material.dart';
import '../core/constants.dart';

class StatusBadge extends StatelessWidget {
  final String status;
  final String? customLabel;
  final bool showDot;
  final double fontSize;

  const StatusBadge({
    super.key,
    required this.status,
    this.customLabel,
    this.showDot = true,
    this.fontSize = 11.0,
  });

  @override
  Widget build(BuildContext context) {
    final normalized = status.toUpperCase().replaceAll('-', '_');
    Color bg = const Color(0xFFF1F5F9);
    Color text = AppConstants.textSecondary;
    Color border = const Color(0xFFE2E8F0);
    String display = customLabel ?? status.replaceAll('_', ' ');

    switch (normalized) {
      case 'LOW':
      case 'LOW_RISK':
      case 'CONNECTED':
      case 'ACTIVE':
      case 'APPROVED':
      case 'OFFICER_APPROVED':
      case 'DELIVERED':
      case 'DELIVERY_CONFIRMED':
      case 'EVALUATED':
      case 'STABLE':
      case 'OPTIMIZED':
      case 'NORMAL':
      case 'PASS':
      case 'PASSED':
      case 'PRE_DISPATCH_VALIDATED':
      case 'DIGITAL_SEAL_VERIFIED':
      case 'READY_FOR_DISPATCH':
      case 'SUCCESS':
        bg = const Color(0xFFDCFCE7); // Green 100
        text = const Color(0xFF15803D); // Green 700
        border = const Color(0xFFBBF7D0);
        break;

      case 'MEDIUM':
      case 'MEDIUM_RISK':
      case 'WARNING':
      case 'OFFICER_PARTIAL_APPROVED':
      case 'PARTIAL_ALLOCATION':
      case 'PENDING_OFFICER_REVIEW':
      case 'PENDING':
      case 'DRAFT_GENERATED':
      case 'PORTABILITY':
      case 'AI_RECOMMENDATION':
      case 'ADVISORY':
      case 'DELAYED':
      case 'STOCK_DELAYED':
      case 'STOCK_CONSTRAINT_DETECTED':
      case 'DISPATCH_DELAYED':
        bg = const Color(0xFFFEF3C7); // Amber 100
        text = const Color(0xFFB45309); // Amber 700
        border = const Color(0xFFFDE68A);
        if (customLabel == null && (normalized == 'DELAYED' || normalized == 'STOCK_DELAYED')) {
          display = 'DELAYED — STOCK REPLENISHMENT PENDING';
        }
        break;

      case 'HIGH':
      case 'HIGH_RISK':
      case 'CRITICAL':
      case 'CRITICAL_RISK':
      case 'STOCKOUT':
      case 'DEFICIT':
      case 'DISPUTE':
      case 'DELIVERY_DISPUTE':
      case 'REJECTED':
      case 'DISCONNECTED':
      case 'TAMPERED':
      case 'FAIL':
      case 'FAILED':
      case 'INVARIANT_VIOLATION':
        bg = const Color(0xFFFEE2E2); // Red 100
        text = const Color(0xFFB91C1C); // Red 700
        border = const Color(0xFFFECACA);
        break;

      case 'PLANNING_OPEN':
      case 'PLANNING':
      case 'SERVICE_REQUESTED':
      case 'RECORDED':
      case 'SUBMITTED':
      case 'OUT_FOR_DELIVERY':
      case 'OFFICER_REDIRECTED':
      case 'BENEFICIARY_INTENT':
      case 'FORECAST_DEMAND':
      case 'STATUTORY_ENTITLEMENT':
        bg = const Color(0xFFEFF6FF); // Blue 100
        text = const Color(0xFF1D4ED8); // Blue 700
        border = const Color(0xFFBFDBFE);
        break;

      case 'FORECAST_LOCKED':
      case 'MANIFEST_LOCKED':
      case 'LOCKED':
      case 'SEALED':
      case 'DISPATCH_GENERATED':
      case 'OFFICER_DEFERRED':
        bg = const Color(0xFFF3E8FF); // Purple 100
        text = const Color(0xFF7E22CE); // Purple 700
        border = const Color(0xFFE9D5FF);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: border, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (showDot) ...[
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: text,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5),
          ],
          Text(
            display.toUpperCase(),
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              color: text,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}
