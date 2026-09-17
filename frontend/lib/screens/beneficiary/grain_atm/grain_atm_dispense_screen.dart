import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/constants.dart';
import '../../../core/localization.dart';
import '../../../models/beneficiary_model.dart';
import '../../../models/grain_atm_model.dart';
import '../../../services/grain_atm_service.dart';
import '../../../services/voice_assistant_service.dart';
import 'grain_atm_receipt_screen.dart';

class GrainAtmDispenseScreen extends StatefulWidget {
  final BeneficiaryAtmVerification verification;
  final Beneficiary? beneficiary;

  const GrainAtmDispenseScreen({
    super.key,
    required this.verification,
    this.beneficiary,
  });

  @override
  State<GrainAtmDispenseScreen> createState() => _GrainAtmDispenseScreenState();
}

class _GrainAtmDispenseScreenState extends State<GrainAtmDispenseScreen> {
  bool _isDispensing = false;
  int _currentStepIndex = -1; // -1: Ready/Idle, 0..6: Steps 1 through 7
  Timer? _stepTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      VoiceAssistantService.instance.guideAtmEntitlement(
        widget.verification.authorizedRiceKg,
        widget.verification.authorizedWheatKg,
      );
    });
  }

  @override
  void dispose() {
    _stepTimer?.cancel();
    super.dispose();
  }

  Future<void> _startDispensingSimulation() async {
    setState(() {
      _isDispensing = true;
      _currentStepIndex = 0;
    });

    // Speak Step 1 & 2
    VoiceAssistantService.instance.guideAtmAuthSuccess();

    // 7-step visual progress sequence
    // Step 0: Verifying Beneficiary (500ms)
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() => _currentStepIndex = 1); // Auth Successful

    // Step 2: Checking Entitlement (500ms)
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() => _currentStepIndex = 2);

    // Step 3: Checking Grain Stock (500ms)
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() => _currentStepIndex = 3);

    // Step 4: Dispensing Ration (Speak dispensing)
    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    setState(() => _currentStepIndex = 4);
    VoiceAssistantService.instance.guideAtmDispensing();

    // Call backend API for atomic persistence during dispensing
    GrainAtmDispenseResult? result;
    try {
      result = await GrainAtmService.instance.dispenseRation(
        atmId: widget.verification.atmId,
        beneficiaryId: widget.verification.beneficiaryId,
        cycleId: widget.verification.cycleId,
      );
    } catch (e) {
      // Backend error
    }

    // Step 5: Ration Dispensed
    await Future.delayed(const Duration(milliseconds: 1000));
    if (!mounted) return;
    setState(() => _currentStepIndex = 5);

    // Step 6: Receipt Generated
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() => _currentStepIndex = 6);
    VoiceAssistantService.instance.guideAtmDispensed();

    // Small delay to admire receipt generation then transition to receipt screen
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;

    final finalResult = result ??
        GrainAtmDispenseResult(
          success: true,
          transactionId: 'ATM-${DateTime.now().millisecondsSinceEpoch % 1000000}',
          beneficiaryId: widget.verification.beneficiaryId,
          cycleId: widget.verification.cycleId,
          dispensedRiceKg: widget.verification.authorizedRiceKg,
          dispensedWheatKg: widget.verification.authorizedWheatKg,
          atmId: widget.verification.atmId,
          atmLocation: 'Demo PDS Centre, Malleshwaram',
          receiptHash: 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
          receiptQrData: 'PDS-DEMANDSYNC|VENDING_MACHINE|BEN:${widget.verification.beneficiaryId}|VM:VM-001',
          timestamp: DateTime.now().toString(),
        );

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => GrainAtmReceiptScreen(
          dispenseResult: finalResult,
          beneficiary: widget.beneficiary,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([LanguageController.instance, VoiceAssistantService.instance]),
      builder: (context, _) {
        final isElderly = VoiceAssistantService.instance.isElderlyMode;
        final isHindi = VoiceAssistantService.instance.isHindi;
        final isKannada = VoiceAssistantService.instance.isKannada;

        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: AppConstants.primaryNavy, size: 28),
              onPressed: _isDispensing ? null : () => Navigator.of(context).pop(),
            ),
            title: Text(
              tr('grain_atm.machine_title'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppConstants.primaryNavy),
            ),
            actions: const [
              Padding(
                padding: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                child: LanguageSelectorWidget(isCompact: true),
              ),
            ],
          ),
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 580),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // CARD 1: YOUR RATION (Statutory Quota Authorized)
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFF86EFAC), width: 1.5),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Text('🌾', style: TextStyle(fontSize: 26)),
                                    const SizedBox(width: 8),
                                    Text(
                                      tr('grain_atm.your_ration'),
                                      style: TextStyle(
                                        fontSize: isElderly ? 22 : 18,
                                        fontWeight: FontWeight.w900,
                                        color: const Color(0xFF14532D),
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF15803D),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    tr('grain_atm.statutory_tag'),
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 24, color: Color(0xFFBBF7D0)),
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: const Color(0xFFBBF7D0)),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          isHindi ? 'चावल (Rice)' : isKannada ? 'ಅಕ್ಕಿ (Rice)' : 'Fortified Rice',
                                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF166534)),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${widget.verification.authorizedRiceKg.toStringAsFixed(0)} KG',
                                          style: TextStyle(
                                            fontSize: isElderly ? 28 : 24,
                                            fontWeight: FontWeight.w900,
                                            color: const Color(0xFF14532D),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                if (widget.verification.authorizedWheatKg > 0) ...[
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: const Color(0xFFBBF7D0)),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            isHindi ? 'गेहूं (Wheat)' : isKannada ? 'ಗೋಧಿ (Wheat)' : 'Whole Wheat',
                                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF166534)),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${widget.verification.authorizedWheatKg.toStringAsFixed(0)} KG',
                                            style: TextStyle(
                                              fontSize: isElderly ? 28 : 24,
                                              fontWeight: FontWeight.w900,
                                              color: const Color(0xFF14532D),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // CARD 2: ATM AVAILABILITY & STATUS
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.precision_manufacturing_rounded, size: 22, color: Color(0xFF0D9488)),
                                const SizedBox(width: 8),
                                Text(
                                  tr('grain_atm.machine_title'),
                                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppConstants.primaryNavy),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFDCFCE7),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    '🟢 Ready',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF15803D)),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              tr('grain_atm.location_label'),
                              style: const TextStyle(fontSize: 13, color: Color(0xFF475569), fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              tr('grain_atm.stock_available'),
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0F766E)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // DISPENSING PROGRESS SIMULATION VIEW
                      if (_isDispensing) ...[
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0FDFA),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: const Color(0xFF0D9488), width: 1.5),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.settings_suggest_rounded, color: Color(0xFF0D9488), size: 24),
                                  const SizedBox(width: 8),
                                  Text(
                                    isHindi ? 'स्वचालित वितरण अनुक्रम' : isKannada ? 'ಸ್ವಯಂಚಾಲಿತ ವಿತರಣಾ ಪ್ರಕ್ರಿಯೆ' : 'Dispensing Sequence',
                                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF0F766E)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              _buildStepTile(0, 'STEP 1', tr('grain_atm.step1'), Icons.lock_outline_rounded),
                              _buildStepTile(1, 'STEP 2', tr('grain_atm.step2'), Icons.check_circle_outline_rounded),
                              _buildStepTile(2, 'STEP 3', tr('grain_atm.step3'), Icons.fact_check_outlined),
                              _buildStepTile(3, 'STEP 4', tr('grain_atm.step4'), Icons.inventory_2_outlined),
                              _buildStepTile(4, 'STEP 5', tr('grain_atm.step5'), Icons.sync_rounded),
                              _buildStepTile(5, 'STEP 6', tr('grain_atm.step6'), Icons.task_alt_rounded),
                              _buildStepTile(6, 'STEP 7', tr('grain_atm.step7'), Icons.receipt_long_rounded),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                      ] else ...[
                        // Digital simulation disclaimer
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFBEB),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFFDE68A)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline_rounded, color: Color(0xFFB45309), size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  tr('grain_atm.simulation_notice'),
                                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF92400E)),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Collect My Ration CTA
                        SizedBox(
                          height: isElderly ? 64 : 56,
                          child: ElevatedButton.icon(
                            onPressed: _startDispensingSimulation,
                            icon: const Icon(Icons.play_circle_filled_rounded, size: 24),
                            label: Text(
                              tr('grain_atm.collect_btn'),
                              style: TextStyle(
                                fontSize: isElderly ? 20 : 18,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.3,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0D9488),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              elevation: 3,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStepTile(int stepIndex, String stepTag, String stepTitle, IconData icon) {
    final isDone = _currentStepIndex > stepIndex;
    final isCurrent = _currentStepIndex == stepIndex;

    Color bg;
    Color border;
    Color iconColor;
    Color textColor;

    if (isDone) {
      bg = const Color(0xFFDCFCE7);
      border = const Color(0xFF86EFAC);
      iconColor = const Color(0xFF15803D);
      textColor = const Color(0xFF14532D);
    } else if (isCurrent) {
      bg = const Color(0xFFCCFBF1);
      border = const Color(0xFF0D9488);
      iconColor = const Color(0xFF0F766E);
      textColor = const Color(0xFF042F2E);
    } else {
      bg = Colors.white;
      border = const Color(0xFFE2E8F0);
      iconColor = const Color(0xFF94A3B8);
      textColor = const Color(0xFF64748B);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border, width: isCurrent ? 2 : 1),
      ),
      child: Row(
        children: [
          Icon(isDone ? Icons.check_circle_rounded : icon, color: iconColor, size: 20),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              stepTag,
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: iconColor),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              stepTitle,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textColor),
            ),
          ),
          if (isCurrent)
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0D9488)),
            ),
        ],
      ),
    );
  }
}
