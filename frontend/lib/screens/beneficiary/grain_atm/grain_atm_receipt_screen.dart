import 'package:flutter/material.dart';
import '../../../core/constants.dart';
import '../../../core/localization.dart';
import '../../../models/beneficiary_model.dart';
import '../../../models/grain_atm_model.dart';
import '../../../services/voice_assistant_service.dart';
import '../beneficiary_home_screen.dart';

class GrainAtmReceiptScreen extends StatefulWidget {
  final GrainAtmDispenseResult dispenseResult;
  final Beneficiary? beneficiary;

  const GrainAtmReceiptScreen({
    super.key,
    required this.dispenseResult,
    this.beneficiary,
  });

  @override
  State<GrainAtmReceiptScreen> createState() => _GrainAtmReceiptScreenState();
}

class _GrainAtmReceiptScreenState extends State<GrainAtmReceiptScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      VoiceAssistantService.instance.guideAtmDispensed();
    });
  }

  void _returnHome() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (context) => BeneficiaryHomeScreen(
          beneficiaryId: widget.dispenseResult.beneficiaryId,
        ),
      ),
      (route) => false,
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
            automaticallyImplyLeading: false,
            title: Text(
              tr('grain_atm.receipt_title'),
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
                  constraints: const BoxConstraints(maxWidth: 540),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // SUCCESS BADGE
                      Center(
                        child: Container(
                          width: 68,
                          height: 68,
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCFCE7),
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFF86EFAC), width: 2),
                          ),
                          child: const Icon(Icons.check_circle_rounded, color: Color(0xFF15803D), size: 40),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        isHindi ? 'राशन सफलतापूर्वक प्राप्त हुआ!' : isKannada ? 'ಪಡಿತರ ಯಶಸ್ವಿಯಾಗಿ ಸಂಗ್ರಹಿಸಲಾಗಿದೆ!' : 'Ration Successfully Collected!',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: isElderly ? 22 : 20, fontWeight: FontWeight.w900, color: const Color(0xFF14532D)),
                      ),
                      const SizedBox(height: 20),

                      // DIGITAL RECEIPT SLIP CARD
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'RATION RECEIPT ✓',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.0,
                                    color: AppConstants.primaryNavy,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFDCFCE7),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'COMPLETED',
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF15803D)),
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 24, thickness: 1.2),

                            _buildReceiptRow('Beneficiary ID', widget.dispenseResult.beneficiaryId, isBold: true),
                            _buildReceiptRow('Cycle', 'September 2026 (Cycle 7)'),
                            _buildReceiptRow('Fortified Rice', '${widget.dispenseResult.dispensedRiceKg.toStringAsFixed(0)} KG (₹0.00 Free)', isDominant: true),
                            if (widget.dispenseResult.dispensedWheatKg > 0)
                              _buildReceiptRow('Whole Wheat', '${widget.dispenseResult.dispensedWheatKg.toStringAsFixed(0)} KG (₹0.00 Free)', isDominant: true),
                            _buildReceiptRow('Pickup Point', 'Ration Vending Machine (VM-001)'),
                            _buildReceiptRow('Location', 'Demo PDS Centre, Malleshwaram'),
                            _buildReceiptRow('Transaction ID', widget.dispenseResult.transactionId, isBold: true),
                            _buildReceiptRow('Timestamp', widget.dispenseResult.timestamp.split('.')[0]),

                            const Divider(height: 24, thickness: 1.2),

                            // 2D QR CODE REPRESENTATION
                            Center(
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
                                ),
                                child: Column(
                                  children: [
                                    const Icon(Icons.qr_code_2_rounded, size: 84, color: AppConstants.primaryNavy),
                                    const SizedBox(height: 4),
                                    Text(
                                      'SHA-256 SEAL: ${widget.dispenseResult.receiptHash.length > 16 ? widget.dispenseResult.receiptHash.substring(0, 16) : "INTACT"}...',
                                      style: const TextStyle(
                                        fontFamily: 'monospace',
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Reassurance Banner: Single backend state updated
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFBFDBFE)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.cloud_done_rounded, color: Color(0xFF2563EB), size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                isHindi
                                    ? 'राशन प्राप्ति सरकारी रिकॉर्ड में दर्ज हो चुकी है।'
                                    : isKannada
                                        ? 'ಪಡಿತರ ಸ್ವೀಕೃತಿ ಸರ್ಕಾರಿ ದಾಖಲೆಯಲ್ಲಿ ನಮೂದಾಗಿದೆ.'
                                        : 'Ration receipt authoritatively logged in government PDS records.',
                                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF1E40AF)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // CTAs
                      SizedBox(
                        height: isElderly ? 60 : 54,
                        child: ElevatedButton.icon(
                          onPressed: _returnHome,
                          icon: const Icon(Icons.home_rounded),
                          label: Text(
                            tr('grain_atm.done_home_btn'),
                            style: TextStyle(fontSize: isElderly ? 18 : 16, fontWeight: FontWeight.w900),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppConstants.primaryNavy,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
      },
    );
  }

  Widget _buildReceiptRow(String label, String value, {bool isBold = false, bool isDominant = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: isDominant ? 14 : 13,
                fontWeight: (isBold || isDominant) ? FontWeight.w900 : FontWeight.w700,
                color: isDominant ? const Color(0xFF15803D) : AppConstants.primaryNavy,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
