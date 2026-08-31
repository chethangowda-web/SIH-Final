import 'package:flutter/material.dart';
import '../core/constants.dart';

class FeeBreakdownCard extends StatelessWidget {
  final double distanceKm;
  final double baseFeeInr;
  final double distanceSurchargeInr;
  final double totalTransportFeeInr;
  final String? address;
  final TextEditingController? addressController;

  const FeeBreakdownCard({
    super.key,
    required this.distanceKm,
    this.baseFeeInr = 20.0,
    required this.distanceSurchargeInr,
    required this.totalTransportFeeInr,
    this.address,
    this.addressController,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.space16),
      decoration: BoxDecoration(
        color: AppConstants.cardSurface,
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        border: Border.all(color: AppConstants.cardBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.local_shipping_outlined, color: AppConstants.primaryNavy, size: 18),
              SizedBox(width: 8),
              Text(
                'HOME DELIVERY LOGISTICS BREAKDOWN',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppConstants.primaryNavy,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.space12),

          if (addressController != null) ...[
            TextField(
              controller: addressController,
              decoration: InputDecoration(
                labelText: 'Delivery Address',
                hintText: 'Enter complete residential address',
                prefixIcon: const Icon(Icons.home_outlined, size: 18),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
                  borderSide: const BorderSide(color: AppConstants.cardBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
                  borderSide: const BorderSide(color: AppConstants.cardBorder),
                ),
              ),
            ),
            const SizedBox(height: AppConstants.space12),
          ] else if (address != null) ...[
            Container(
              padding: const EdgeInsets.all(AppConstants.space8),
              decoration: BoxDecoration(
                color: AppConstants.backgroundLight,
                borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
              ),
              child: Row(
                children: [
                  const Icon(Icons.location_on_outlined, size: 15, color: AppConstants.textSecondary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      address!,
                      style: const TextStyle(fontSize: 12, color: AppConstants.textPrimary),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppConstants.space12),
          ],

          Container(
            padding: const EdgeInsets.all(AppConstants.space12),
            decoration: BoxDecoration(
              color: AppConstants.backgroundLight,
              borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
              border: Border.all(color: AppConstants.cardBorder, width: 1),
            ),
            child: Column(
              children: [
                _buildFeeRow('Delivery Distance from FPS', '${distanceKm.toStringAsFixed(1)} km'),
                const SizedBox(height: 6),
                _buildFeeRow('Base Doorstep Transport (first 2 km)', '₹${baseFeeInr.toStringAsFixed(2)}'),
                const SizedBox(height: 6),
                _buildFeeRow('Additional Distance Surcharge', '₹${distanceSurchargeInr.toStringAsFixed(2)}'),
                const SizedBox(height: 6),
                _buildFeeRow('Government Ration Foodgrains Cost', '₹0.00 (100% Subsidized)', isHighlight: true),
                const Divider(height: 16),
                _buildFeeRow('Total Logistics Payable', '₹${totalTransportFeeInr.toStringAsFixed(2)}', isTotal: true),
              ],
            ),
          ),
          const SizedBox(height: AppConstants.space10),

          // Reassuring Statutory Notice
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.shield_outlined, size: 14, color: AppConstants.textSecondary),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'You pay only the transportation/logistics fee. Your government ration entitlement remains 100% free and unchanged.',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppConstants.textSecondary,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeeRow(String label, String value, {bool isHighlight = false, bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isTotal ? 13 : 11.5,
            fontWeight: isTotal ? FontWeight.w700 : (isHighlight ? FontWeight.w600 : FontWeight.w500),
            color: isHighlight ? AppConstants.successGreen : (isTotal ? AppConstants.primaryNavy : AppConstants.textSecondary),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isTotal ? 15 : 12,
            fontWeight: isTotal ? FontWeight.w900 : (isHighlight ? FontWeight.w700 : FontWeight.w600),
            color: isHighlight ? AppConstants.successGreen : (isTotal ? AppConstants.primaryNavy : AppConstants.textPrimary),
          ),
        ),
      ],
    );
  }
}
