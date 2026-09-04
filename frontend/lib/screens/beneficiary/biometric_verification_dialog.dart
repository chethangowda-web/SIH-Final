import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../core/localization.dart';
import '../../models/beneficiary_model.dart';

enum BiometricVerificationState {
  initial,
  scanning,
  verified,
  failed,
  distributed,
}

class BiometricVerificationDialog extends StatefulWidget {
  final Beneficiary beneficiary;
  final BeneficiaryEntitlementSummary? entitlement;
  final String deliveryMode; // 'FPS_COLLECTION' or 'HOME_DELIVERY'
  final String? deliveryAddress;
  final String? fpsName;
  final double riceQtyKg;
  final double wheatQtyKg;
  final int eligibleMembersCount;
  final Function(double distributedKg, double remainingKg) onDistributionComplete;

  const BiometricVerificationDialog({
    super.key,
    required this.beneficiary,
    this.entitlement,
    required this.deliveryMode,
    this.deliveryAddress,
    this.fpsName,
    required this.riceQtyKg,
    required this.wheatQtyKg,
    required this.eligibleMembersCount,
    required this.onDistributionComplete,
  });

  @override
  State<BiometricVerificationDialog> createState() => _BiometricVerificationDialogState();
}

class _BiometricVerificationDialogState extends State<BiometricVerificationDialog> with SingleTickerProviderStateMixin {
  BiometricVerificationState _state = BiometricVerificationState.initial;
  String? _failureReason;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  Timer? _autoCloseTimer;

  @override
  void dispose() {
    _autoCloseTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  double get _totalOrderQtyKg => widget.riceQtyKg + widget.wheatQtyKg;
  double get _maxHouseholdEntitlementKg => widget.eligibleMembersCount * 5.0;

  void _simulateScan({required bool shouldSucceed}) async {
    setState(() {
      _state = BiometricVerificationState.scanning;
      _failureReason = null;
    });
    _pulseController.repeat(reverse: true);

    await Future.delayed(const Duration(milliseconds: 500));

    if (!mounted) return;
    _pulseController.stop();
    _pulseController.reset();

    if (shouldSucceed) {
      setState(() {
        _state = BiometricVerificationState.verified;
      });
    } else {
      setState(() {
        _state = BiometricVerificationState.failed;
        _failureReason = 'Biometric biometric-minutiae mismatch (Confidence 38% < 85% threshold) or quota lock. Please re-authenticate or report to District Supply Office.';
      });
    }
  }

  void _executeDistribution() {
    final distributed = _totalOrderQtyKg;
    final remaining = (_maxHouseholdEntitlementKg - distributed).clamp(0.0, _maxHouseholdEntitlementKg);

    setState(() {
      _state = BiometricVerificationState.distributed;
    });

    widget.onDistributionComplete(distributed, remaining);

    _autoCloseTimer = Timer(const Duration(milliseconds: 1200), () {
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isHome = widget.deliveryMode == 'HOME_DELIVERY';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: AppConstants.primaryNavy,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.fingerprint_rounded, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isHome ? tr('biometric.title_home') : tr('biometric.title_fps'),
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isHome ? 'Doorstep Assisted Handover Verification' : 'Fair Price Shop ePoS Terminal Verification',
                            style: const TextStyle(fontSize: 11, color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                      onPressed: () => Navigator.of(context).pop(),
                      tooltip: tr('nav.close'),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Household & Quota Context Card
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.person_pin_outlined, size: 16, color: AppConstants.primaryNavy),
                                  const SizedBox(width: 6),
                                  Text(
                                    widget.beneficiary.nameForDemo,
                                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppConstants.primaryNavy),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEFF6FF),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: const Color(0xFFBFDBFE)),
                                ),
                                child: Text(
                                  '${widget.eligibleMembersCount} Members • ${_maxHouseholdEntitlementKg.toStringAsFixed(1)} kg Entitlement',
                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppConstants.accentBlue),
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                isHome ? 'Delivery Address: ${widget.deliveryAddress ?? "Malleshwaram, Bengaluru"}' : 'Collection FPS: ${widget.fpsName ?? "Malleshwaram Seva Kendra"}',
                                style: const TextStyle(fontSize: 11, color: AppConstants.textSecondary),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                'Foodgrain Order: ${widget.riceQtyKg.toStringAsFixed(1)} kg Rice + ${widget.wheatQtyKg.toStringAsFixed(1)} kg Wheat',
                                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppConstants.textPrimary),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${_totalOrderQtyKg.toStringAsFixed(1)} kg Total (₹0.00)',
                                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Color(0xFF15803D)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Biometric Scanner Visualizer
                    Center(
                      child: ScaleTransition(
                        scale: _state == BiometricVerificationState.scanning ? _pulseAnimation : const AlwaysStoppedAnimation(1.0),
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _getScannerBgColor(),
                            border: Border.all(color: _getScannerBorderColor(), width: 2.5),
                            boxShadow: [
                              BoxShadow(
                                color: _getScannerBorderColor().withValues(alpha: 0.2),
                                blurRadius: 16,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Icon(
                            _getScannerIcon(),
                            size: 52,
                            color: _getScannerIconColor(),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Status Text
                    Center(
                      child: Text(
                        _getStatusHeading(),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: _getStatusTextColor(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Center(
                      child: Text(
                        _getStatusSubheading(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 11.5, color: AppConstants.textSecondary, height: 1.35),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Live Verification Diagnostic Steps
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        children: [
                          _buildDiagnosticRow(
                            '1. Citizen Identity & Aadhaar Demographic Match',
                            _state == BiometricVerificationState.verified || _state == BiometricVerificationState.distributed
                                ? 'VERIFIED ✓'
                                : (_state == BiometricVerificationState.failed ? 'MISMATCH ✕' : 'PENDING'),
                            _state == BiometricVerificationState.verified || _state == BiometricVerificationState.distributed
                                ? const Color(0xFF15803D)
                                : (_state == BiometricVerificationState.failed ? const Color(0xFFDC2626) : AppConstants.textSecondary),
                          ),
                          const Divider(height: 12),
                          _buildDiagnosticRow(
                            '2. Ration Card Active & Non-Suspended',
                            _state == BiometricVerificationState.verified || _state == BiometricVerificationState.distributed
                                ? 'ACTIVE (PHH) ✓'
                                : (_state == BiometricVerificationState.failed ? 'CHECK FAILED ✕' : 'PENDING'),
                            _state == BiometricVerificationState.verified || _state == BiometricVerificationState.distributed
                                ? const Color(0xFF15803D)
                                : (_state == BiometricVerificationState.failed ? const Color(0xFFDC2626) : AppConstants.textSecondary),
                          ),
                          const Divider(height: 12),
                          _buildDiagnosticRow(
                            '3. Available Household Quota Ceiling',
                            _state == BiometricVerificationState.verified || _state == BiometricVerificationState.distributed
                                ? '${_maxHouseholdEntitlementKg.toStringAsFixed(1)} kg VALID ✓'
                                : (_state == BiometricVerificationState.failed ? 'LOCKED ✕' : 'PENDING'),
                            _state == BiometricVerificationState.verified || _state == BiometricVerificationState.distributed
                                ? const Color(0xFF15803D)
                                : (_state == BiometricVerificationState.failed ? const Color(0xFFDC2626) : AppConstants.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Interactive Simulation Triggers (Allows testing both Success and Failure)
                    if (_state == BiometricVerificationState.initial || _state == BiometricVerificationState.failed || _state == BiometricVerificationState.scanning) ...[
                      const Text(
                        'DEMO VERIFICATION CONTROLS',
                        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: AppConstants.textSecondary, letterSpacing: 0.5),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              key: const ValueKey('btn_simulate_success'),
                              onPressed: _state == BiometricVerificationState.scanning
                                  ? null
                                  : () => _simulateScan(shouldSucceed: true),
                              icon: const Icon(Icons.check_circle_outline, size: 16),
                              label: const Text(
                                'Simulate Match (✓)',
                                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF15803D),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              key: const ValueKey('btn_simulate_failure'),
                              onPressed: _state == BiometricVerificationState.scanning
                                  ? null
                                  : () => _simulateScan(shouldSucceed: false),
                              icon: const Icon(Icons.cancel_outlined, size: 16),
                              label: const Text(
                                'Simulate Mismatch (✕)',
                                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppConstants.dangerRed,
                                side: const BorderSide(color: Color(0xFFFECACA), width: 1.5),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],

                    // Action Button when Verified
                    if (_state == BiometricVerificationState.verified) ...[
                      ElevatedButton.icon(
                        key: const ValueKey('btn_distribute_foodgrain'),
                        onPressed: _executeDistribution,
                        icon: const Icon(Icons.inventory_rounded, size: 18),
                        label: Text(
                          tr('biometric.distribute_action', params: {'qty': _totalOrderQtyKg.toStringAsFixed(1)}),
                          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppConstants.primaryNavy,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 2,
                        ),
                      ),
                    ],

                    // Success Feedback when Distributed
                    if (_state == BiometricVerificationState.distributed) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF86EFAC)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.task_alt_rounded, color: Color(0xFF15803D), size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                tr('biometric.distribute_success_toast'),
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF15803D)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDiagnosticRow(String label, String status, Color statusColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(label, style: const TextStyle(fontSize: 11, color: AppConstants.textPrimary, fontWeight: FontWeight.w500)),
        ),
        const SizedBox(width: 8),
        Text(
          status,
          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: statusColor),
        ),
      ],
    );
  }

  Color _getScannerBgColor() {
    switch (_state) {
      case BiometricVerificationState.initial:
        return const Color(0xFFEFF6FF);
      case BiometricVerificationState.scanning:
        return const Color(0xFFFEF3C7);
      case BiometricVerificationState.verified:
      case BiometricVerificationState.distributed:
        return const Color(0xFFDCFCE7);
      case BiometricVerificationState.failed:
        return const Color(0xFFFEF2F2);
    }
  }

  Color _getScannerBorderColor() {
    switch (_state) {
      case BiometricVerificationState.initial:
        return AppConstants.accentBlue;
      case BiometricVerificationState.scanning:
        return const Color(0xFFF59E0B);
      case BiometricVerificationState.verified:
      case BiometricVerificationState.distributed:
        return AppConstants.successGreen;
      case BiometricVerificationState.failed:
        return AppConstants.dangerRed;
    }
  }

  IconData _getScannerIcon() {
    switch (_state) {
      case BiometricVerificationState.initial:
      case BiometricVerificationState.scanning:
        return Icons.fingerprint_rounded;
      case BiometricVerificationState.verified:
      case BiometricVerificationState.distributed:
        return Icons.verified_user_rounded;
      case BiometricVerificationState.failed:
        return Icons.gpp_bad_rounded;
    }
  }

  Color _getScannerIconColor() {
    switch (_state) {
      case BiometricVerificationState.initial:
        return AppConstants.accentBlue;
      case BiometricVerificationState.scanning:
        return const Color(0xFFD97706);
      case BiometricVerificationState.verified:
      case BiometricVerificationState.distributed:
        return const Color(0xFF15803D);
      case BiometricVerificationState.failed:
        return const Color(0xFFDC2626);
    }
  }

  String _getStatusHeading() {
    switch (_state) {
      case BiometricVerificationState.initial:
        return 'Ready for Biometric Thumb Scan';
      case BiometricVerificationState.scanning:
        return 'Scanning & Verifying Demographics...';
      case BiometricVerificationState.verified:
        return '✓ Beneficiary Verified & Entitlement Available';
      case BiometricVerificationState.failed:
        return '✕ Verification Failed — Distribution Locked';
      case BiometricVerificationState.distributed:
        return '✓ Ration Handover Authorized & Recorded';
    }
  }

  String _getStatusSubheading() {
    switch (_state) {
      case BiometricVerificationState.initial:
        return tr('biometric.scan_instruction');
      case BiometricVerificationState.scanning:
        return 'Querying state biometric ePoS authentication service...';
      case BiometricVerificationState.verified:
        return 'Identity matches registered household. Foodgrain distribution is unlocked.';
      case BiometricVerificationState.failed:
        return _failureReason ?? tr('biometric.failure_reason');
      case BiometricVerificationState.distributed:
        return 'Foodgrain inventory depleted from active quota and recorded in institutional ledger.';
    }
  }

  Color _getStatusTextColor() {
    switch (_state) {
      case BiometricVerificationState.initial:
      case BiometricVerificationState.scanning:
        return AppConstants.primaryNavy;
      case BiometricVerificationState.verified:
      case BiometricVerificationState.distributed:
        return const Color(0xFF15803D);
      case BiometricVerificationState.failed:
        return const Color(0xFFDC2626);
    }
  }
}
