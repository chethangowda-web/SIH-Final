import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../core/localization.dart';
import '../../models/beneficiary_model.dart';
import '../../services/api_service.dart';
import '../../widgets/status_badge.dart';
import 'intent_history_screen.dart';

class IntentConfirmationScreen extends StatefulWidget {
  final Beneficiary beneficiary;
  final FpsShop intendedFps;
  final String commodityOption;
  final List<IntentRecord>? submittedRecords;
  final ApiService? apiService;
  final String deliveryMode;
  final String? deliveryAddress;
  final double deliveryDistanceKm;
  final double transportFeeInr;
  final BeneficiaryEntitlementSummary? entitlementSummary;
  final int eligibleMembersCount;
  final double? customRiceKg;
  final double? customWheatKg;

  const IntentConfirmationScreen({
    super.key,
    required this.beneficiary,
    required this.intendedFps,
    this.commodityOption = 'Both',
    this.submittedRecords,
    this.apiService,
    this.deliveryMode = 'FPS_COLLECTION',
    this.deliveryAddress,
    this.deliveryDistanceKm = 0.6,
    this.transportFeeInr = 0.0,
    this.entitlementSummary,
    this.eligibleMembersCount = 4,
    this.customRiceKg,
    this.customWheatKg,
  });

  @override
  State<IntentConfirmationScreen> createState() => _IntentConfirmationScreenState();
}

class _IntentConfirmationScreenState extends State<IntentConfirmationScreen> {
  late final ApiService _apiService;
  bool _isSubmitting = false;
  String? _errorMessage;
  List<IntentRecord>? _completedRecords;

  @override
  void initState() {
    super.initState();
    _apiService = widget.apiService ?? ApiService();
    _completedRecords = widget.submittedRecords;
  }

  Future<void> _handleSubmitCollectionPlan() async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final riceQuota = widget.customRiceKg ?? (widget.eligibleMembersCount * 4.0);
      final wheatQuota = widget.customWheatKg ?? (widget.eligibleMembersCount * 1.0);

      final results = await _apiService.submitIntent(
        beneficiaryId: widget.beneficiary.pseudonymousBeneficiaryId,
        intendedFpsId: widget.intendedFps.fpsId,
        commodityOption: widget.commodityOption,
        riceQuantityKg: riceQuota,
        wheatQuantityKg: wheatQuota,
        deliveryMode: widget.deliveryMode,
        deliveryAddress: widget.deliveryMode == 'HOME_DELIVERY' ? widget.deliveryAddress : null,
        deliveryDistanceKm: widget.deliveryDistanceKm,
        cycleId: '2026-09',
        confidence: 0.95,
      );

      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _completedRecords = results;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isConfirmed = _completedRecords != null && _completedRecords!.isNotEmpty;

    return AnimatedBuilder(
      animation: LanguageController.instance,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: AppConstants.backgroundLight,
          appBar: AppBar(
            automaticallyImplyLeading: !isConfirmed,
            backgroundColor: AppConstants.primaryNavy,
            foregroundColor: Colors.white,
            elevation: 0,
            titleSpacing: 16,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isConfirmed ? tr('confirm.success_heading') : tr('confirm.review_title'),
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: 0.2),
                ),
                Text(
                  '${tr('app.nfsa_notice')} • ${tr('app.cycle_label')}',
                  style: const TextStyle(fontSize: 10.5, color: Colors.white70),
                ),
              ],
            ),
            actions: const [
              Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: LanguageSelectorWidget(isCompact: true),
              ),
              SizedBox(width: 8),
            ],
          ),
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: AppConstants.space20, vertical: AppConstants.space20),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 680),
                  child: isConfirmed ? _buildSuccessConfirmedView() : _buildReviewStepView(),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // STEP INDICATOR
  Widget _buildStepIndicator({required int activeStep}) {
    final steps = [
      {'num': '1', 'title': tr('intent.step_service')},
      {'num': '2', 'title': tr('intent.step_fps')},
      {'num': '3', 'title': tr('intent.step_review')},
      {'num': '4', 'title': tr('intent.step_confirm')},
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppConstants.space16, vertical: AppConstants.space12),
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
      child: Row(
        children: steps.asMap().entries.map((entry) {
          final idx = entry.key;
          final step = entry.value;
          final stepNum = idx + 1;
          final isCompleted = stepNum < activeStep;
          final isCurrent = stepNum == activeStep;

          return Expanded(
            child: Row(
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? AppConstants.successGreen
                        : (isCurrent ? AppConstants.primaryNavy : const Color(0xFFE2E8F0)),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: isCompleted
                        ? const Icon(Icons.check, size: 13, color: Colors.white)
                        : Text(
                            step['num'] as String,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: isCurrent ? Colors.white : AppConstants.textSecondary,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    step['title'] as String,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isCurrent || isCompleted ? FontWeight.w800 : FontWeight.w500,
                      color: isCurrent ? AppConstants.primaryNavy : (isCompleted ? AppConstants.successGreen : AppConstants.textSecondary),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (idx < steps.length - 1) ...[
                  const SizedBox(width: 6),
                  Expanded(
                    child: Container(
                      height: 1.5,
                      color: isCompleted ? AppConstants.successGreen : const Color(0xFFE2E8F0),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // 1. REVIEW VIEW (Step 3: Review Your Collection Plan)
  Widget _buildReviewStepView() {
    final isHomeDelivery = widget.deliveryMode == 'HOME_DELIVERY';
    final riceKg = widget.customRiceKg ?? (widget.eligibleMembersCount * 4.0);
    final wheatKg = widget.customWheatKg ?? (widget.eligibleMembersCount * 1.0);
    final maxEntitlement = widget.eligibleMembersCount * 5.0;
    final remainingKg = maxEntitlement - (riceKg + wheatKg);
    final locationText = isHomeDelivery
        ? (widget.deliveryAddress ?? 'Registered Home Address, Malleshwaram, Bengaluru')
        : '${widget.intendedFps.name} (${widget.intendedFps.fpsId})';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Stepper: Step 3 Active
        _buildStepIndicator(activeStep: 3),
        const SizedBox(height: AppConstants.space20),

        // Section Title
        Text(
          tr('confirm.review_title').toUpperCase(),
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: AppConstants.primaryNavy,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          tr('confirm.review_subtitle'),
          style: const TextStyle(fontSize: 12, color: AppConstants.textSecondary),
        ),
        const SizedBox(height: AppConstants.space16),

        // Summary Card
        Container(
          padding: const EdgeInsets.all(AppConstants.space20),
          decoration: BoxDecoration(
            color: AppConstants.cardSurface,
            borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
            border: Border.all(color: AppConstants.cardBorder, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildReviewRow(
                label: 'SERVICE',
                value: isHomeDelivery ? tr('service.home_choice_title') : tr('service.fps_choice_title'),
                badgeText: isHomeDelivery ? tr('service.home_choice_badge') : tr('service.fps_choice_badge'),
                badgeColor: isHomeDelivery ? const Color(0xFFD97706) : AppConstants.accentBlue,
                icon: isHomeDelivery ? Icons.local_shipping_outlined : Icons.storefront_outlined,
              ),
              const Divider(height: 20),

              _buildReviewRow(
                label: 'ELIGIBLE HOUSEHOLD',
                value: '${widget.eligibleMembersCount} Persons × 5.0 kg = ${maxEntitlement.toStringAsFixed(1)} kg Max Household Entitlement',
                badgeText: '${widget.eligibleMembersCount} MEMBERS',
                badgeColor: AppConstants.accentBlue,
                icon: Icons.people_alt_outlined,
              ),
              const Divider(height: 20),

              _buildReviewRow(
                label: 'LOCATION',
                value: locationText,
                icon: isHomeDelivery ? Icons.home_outlined : Icons.location_on_outlined,
              ),
              const Divider(height: 20),

              _buildReviewRow(
                label: 'CYCLE',
                value: tr('app.cycle_label'),
                icon: Icons.calendar_today_outlined,
              ),
              const Divider(height: 20),

              // Itemized Commodities Table (Rice & Wheat)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.inventory_2_outlined, size: 18, color: AppConstants.textSecondary),
                      const SizedBox(width: 12),
                      const Text(
                        'ENTITLEMENT',
                        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: AppConstants.textSecondary, letterSpacing: 0.4),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppConstants.backgroundLight,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppConstants.cardBorder),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.grain, size: 16, color: AppConstants.primaryNavy),
                                const SizedBox(width: 6),
                                Text(tr('commodity.rice'), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppConstants.primaryNavy)),
                              ],
                            ),
                            Text('${riceKg.toStringAsFixed(1)} ${tr('commodity.kg')}  •  ₹0.00', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF15803D))),
                          ],
                        ),
                        const Divider(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.bakery_dining, size: 16, color: Color(0xFFD97706)),
                                const SizedBox(width: 6),
                                Text(tr('commodity.wheat'), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppConstants.primaryNavy)),
                              ],
                            ),
                            Text('${wheatKg.toStringAsFixed(1)} ${tr('commodity.kg')}  •  ₹0.00', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF15803D))),
                          ],
                        ),
                        const Divider(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Total Monthly Ration Weight', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: AppConstants.primaryNavy)),
                            Text('${(riceKg + wheatKg).toStringAsFixed(1)} ${tr('commodity.kg')} (${tr('commodity.free_tag')})', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF15803D))),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 20),

              _buildReviewRow(
                label: 'BIOMETRIC HANDOVER REQUIREMENT',
                value: isHomeDelivery
                    ? 'Beneficiary thumb verification required on arrival before doorstep distribution'
                    : 'Biometric thumb verification required at FPS counter ePoS terminal before handover',
                badgeText: 'MANDATORY',
                badgeColor: const Color(0xFFB45309),
                icon: Icons.fingerprint_rounded,
              ),
              const Divider(height: 20),

              _buildReviewRow(
                label: 'REMAINING ENTITLEMENT',
                value: '${remainingKg.toStringAsFixed(1)} ${tr('commodity.kg')} ${tr('entitlement.remaining_balance')}',
                icon: Icons.verified_outlined,
                isDominantGreen: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppConstants.space16),

        // Pricing / "You Pay" Breakdown Card
        Container(
          padding: const EdgeInsets.all(AppConstants.space16),
          decoration: BoxDecoration(
            color: isHomeDelivery ? const Color(0xFFFEF3C7).withValues(alpha: 0.3) : const Color(0xFFF0FDF4),
            borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
            border: Border.all(
              color: isHomeDelivery ? const Color(0xFFFDE68A) : const Color(0xFFBBF7D0),
              width: 1.2,
            ),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Flexible(
                    child: Text('Foodgrain Cost (100% NFSA Subsidized)', style: TextStyle(fontSize: 12, color: AppConstants.textSecondary)),
                  ),
                  const SizedBox(width: 8),
                  Text('₹0.00 (${tr('commodity.free_tag')})', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF15803D))),
                ],
              ),
              if (isHomeDelivery) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Flexible(
                      child: Text('Doorstep Logistics & Conveyance Fee', style: TextStyle(fontSize: 12, color: AppConstants.textSecondary)),
                    ),
                    const SizedBox(width: 8),
                    Text('₹${widget.transportFeeInr.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFB45309))),
                  ],
                ),
              ],
              const Divider(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      tr('confirm.you_pay'),
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppConstants.primaryNavy, letterSpacing: 0.4),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isHomeDelivery ? AppConstants.primaryNavy : const Color(0xFF15803D),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      isHomeDelivery ? '₹${widget.transportFeeInr.toStringAsFixed(2)}' : '₹0.00 (FREE)',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppConstants.space16),

        // Important Governance Notice
        Container(
          padding: const EdgeInsets.all(AppConstants.space12),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.shield_outlined, size: 16, color: AppConstants.primaryNavy),
                  const SizedBox(width: 8),
                  Text(
                    tr('confirm.gov_notice_title'),
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppConstants.primaryNavy, letterSpacing: 0.5),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                tr('confirm.gov_notice_desc'),
                style: const TextStyle(fontSize: 11.5, color: AppConstants.textSecondary, height: 1.35),
              ),
              if (isHomeDelivery) ...[
                const SizedBox(height: 4),
                Text(
                  tr('confirm.gov_transport_note'),
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFFB45309)),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppConstants.space20),

        // What Happens Next
        Container(
          padding: const EdgeInsets.all(AppConstants.space16),
          decoration: BoxDecoration(
            color: AppConstants.cardSurface,
            borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
            border: Border.all(color: AppConstants.cardBorder, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr('confirm.what_next_title'),
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: AppConstants.primaryNavy,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 12),
              _buildNextStepItem('1', tr('confirm.step1_title'), tr('confirm.step1_desc')),
              _buildNextStepItem('2', tr('confirm.step2_title'), tr('confirm.step2_desc')),
              _buildNextStepItem('3', tr('confirm.step3_title'), tr('confirm.step3_desc')),
              _buildNextStepItem('4', tr('confirm.step4_title'), tr('confirm.step4_desc')),
              _buildNextStepItem('5', tr('confirm.step5_title'), tr('confirm.step5_desc'), isLast: true),
            ],
          ),
        ),
        const SizedBox(height: AppConstants.space20),

        // Error message if any
        if (_errorMessage != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFECACA)),
            ),
            child: Text(_errorMessage!, style: const TextStyle(color: AppConstants.dangerRed, fontSize: 12)),
          ),
          const SizedBox(height: AppConstants.space16),
        ],

        // Primary CTA: Submit Collection Plan
        ElevatedButton.icon(
          onPressed: _isSubmitting ? null : _handleSubmitCollectionPlan,
          icon: _isSubmitting
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.send_rounded, size: 18),
          label: Text(
            _isSubmitting ? tr('confirm.btn_submitting') : tr('confirm.btn_submit_plan'),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppConstants.primaryNavy,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.radiusMedium)),
            elevation: 2,
          ),
        ),
        const SizedBox(height: 10),

        // Secondary: Go Back
        OutlinedButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppConstants.primaryNavy,
            side: const BorderSide(color: AppConstants.cardBorder),
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.radiusMedium)),
          ),
          child: Text(tr('confirm.btn_go_back'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(height: AppConstants.space16),
      ],
    );
  }

  Widget _buildReviewRow({
    required String label,
    required String value,
    required IconData icon,
    String? badgeText,
    Color? badgeColor,
    bool isDominantGreen = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: isDominantGreen ? AppConstants.successGreen : AppConstants.textSecondary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: AppConstants.textSecondary, letterSpacing: 0.4),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: TextStyle(
                  fontSize: isDominantGreen ? 14 : 12.5,
                  fontWeight: isDominantGreen ? FontWeight.w800 : FontWeight.w600,
                  color: isDominantGreen ? const Color(0xFF15803D) : AppConstants.textPrimary,
                ),
              ),
            ],
          ),
        ),
        if (badgeText != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: (badgeColor ?? AppConstants.accentBlue).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              badgeText,
              style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: badgeColor ?? AppConstants.accentBlue),
            ),
          ),
      ],
    );
  }

  Widget _buildNextStepItem(String num, String title, String desc, {bool isLast = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: const BoxDecoration(
                color: Color(0xFFEFF6FF),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  num,
                  style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: AppConstants.accentBlue),
                ),
              ),
            ),
            if (!isLast)
              Container(
                width: 1.5,
                height: 26,
                color: const Color(0xFFE2E8F0),
              ),
          ],
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppConstants.primaryNavy)),
                const SizedBox(height: 1),
                Text(desc, style: const TextStyle(fontSize: 11, color: AppConstants.textSecondary, height: 1.3)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // 2. SUCCESS CONFIRMED VIEW (Step 4: Collection Plan Submitted)
  Widget _buildSuccessConfirmedView() {
    final firstRecord = _completedRecords!.first;
    final isHomeDelivery = widget.deliveryMode == 'HOME_DELIVERY';
    final requestId = firstRecord.id > 0 ? 'REQ-2026-09-${firstRecord.id.toString().padLeft(4, '0')}' : 'REQ-2026-09-INGESTED';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Stepper: All 4 Steps Completed
        _buildStepIndicator(activeStep: 4),
        const SizedBox(height: AppConstants.space20),

        // Success Verified Badge
        Center(
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFFDCFCE7),
              shape: BoxShape.circle,
              border: Border.all(color: AppConstants.successGreen, width: 2),
            ),
            child: const Icon(Icons.check_rounded, color: AppConstants.successGreen, size: 40),
          ),
        ),
        const SizedBox(height: AppConstants.space16),

        // Heading
        Text(
          tr('confirm.success_heading'),
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppConstants.primaryNavy,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          tr('confirm.success_desc'),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12.5, color: AppConstants.textSecondary, height: 1.35),
        ),
        const SizedBox(height: AppConstants.space20),

        // Confirmation Digital Receipt Card
        Container(
          padding: const EdgeInsets.all(AppConstants.space20),
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
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    tr('confirm.receipt_title'),
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppConstants.primaryNavy, letterSpacing: 0.6),
                  ),
                  const StatusBadge(status: 'RECORDED'),
                ],
              ),
              const Divider(height: 20),

              _buildReceiptRow('Request ID', requestId, isHighlight: true),
              _buildReceiptRow('Cycle', tr('app.cycle_label')),
              _buildReceiptRow('Eligible Household', '${widget.eligibleMembersCount} Persons (${(widget.eligibleMembersCount * 5.0).toStringAsFixed(1)} kg Max Quota)', isHighlight: true),
              _buildReceiptRow('Selected Service', isHomeDelivery ? tr('service.home_choice_title') : tr('service.fps_choice_title'), isHighlight: true),

              if (isHomeDelivery && widget.deliveryAddress != null)
                _buildReceiptRow('Delivery Destination', widget.deliveryAddress!),

              if (!isHomeDelivery)
                _buildReceiptRow('Collection Center', '${widget.intendedFps.name} (${widget.intendedFps.fpsId})'),

              _buildReceiptRow('Fortified Rice', '${(widget.customRiceKg ?? (widget.eligibleMembersCount * 4.0)).toStringAsFixed(1)} ${tr('commodity.kg')} (₹0.00 Free)'),
              _buildReceiptRow('Whole Wheat', '${(widget.customWheatKg ?? (widget.eligibleMembersCount * 1.0)).toStringAsFixed(1)} ${tr('commodity.kg')} (₹0.00 Free)'),
              _buildReceiptRow('Total Delivery Weight', '${((widget.customRiceKg ?? (widget.eligibleMembersCount * 4.0)) + (widget.customWheatKg ?? (widget.eligibleMembersCount * 1.0))).toStringAsFixed(1)} ${tr('commodity.kg')}'),
              _buildReceiptRow('Biometric Verification', 'REQUIRED AT HANDOVER (ePoS / Mobile)', isHighlight: true),

              if (isHomeDelivery)
                _buildReceiptRow('Doorstep Logistics Fee', '₹${widget.transportFeeInr.toStringAsFixed(2)}', isHighlight: true),

              _buildReceiptRow('Foodgrain Cost', '₹0.00 (${tr('commodity.entitled_free')})', isHighlight: true),
              _buildReceiptRow('Total Amount Payable', isHomeDelivery ? '₹${widget.transportFeeInr.toStringAsFixed(2)}' : '₹0.00 (${tr('commodity.free_tag')})', isHighlight: true),
              const Divider(height: 20),

              // Next Step Note
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline, size: 16, color: AppConstants.accentBlue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(tr('confirm.receipt_next_step'), style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: AppConstants.accentBlue)),
                        const SizedBox(height: 2),
                        Text(
                          tr('confirm.receipt_next_step_desc'),
                          style: const TextStyle(fontSize: 11.5, color: AppConstants.textSecondary, height: 1.35),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppConstants.space20),

        // Action Buttons
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppConstants.primaryNavy,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.radiusMedium)),
          ),
          child: Text(tr('confirm.btn_view_portal'), style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: () {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => IntentHistoryScreen(
                  beneficiary: widget.beneficiary,
                  apiService: _apiService,
                ),
              ),
            );
          },
          style: OutlinedButton.styleFrom(
            foregroundColor: AppConstants.primaryNavy,
            side: const BorderSide(color: AppConstants.cardBorder),
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.radiusMedium)),
          ),
          child: Text(tr('confirm.btn_view_history'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildReceiptRow(String label, String value, {bool isHighlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: AppConstants.textSecondary)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isHighlight ? FontWeight.w800 : FontWeight.w600,
                color: isHighlight ? AppConstants.primaryNavy : AppConstants.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
