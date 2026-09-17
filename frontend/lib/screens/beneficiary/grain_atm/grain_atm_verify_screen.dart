import 'package:flutter/material.dart';
import '../../../core/constants.dart';
import '../../../core/localization.dart';
import '../../../models/beneficiary_model.dart';
import '../../../models/grain_atm_model.dart';
import '../../../services/grain_atm_service.dart';
import '../../../services/voice_assistant_service.dart';
import 'grain_atm_dispense_screen.dart';

class GrainAtmVerifyScreen extends StatefulWidget {
  final Beneficiary? beneficiary;
  final String beneficiaryId;

  const GrainAtmVerifyScreen({
    super.key,
    this.beneficiary,
    required this.beneficiaryId,
  });

  @override
  State<GrainAtmVerifyScreen> createState() => _GrainAtmVerifyScreenState();
}

class _GrainAtmVerifyScreenState extends State<GrainAtmVerifyScreen> {
  int _selectedMethod = 0; // 0: Ration ID, 1: Demo Biometric / Aadhaar, 2: Mobile OTP
  bool _isVerifying = false;
  BeneficiaryAtmVerification? _verificationResult;
  String? _errorMessage;
  bool _hasSpokenAlreadyReceived = false;

  late final TextEditingController _idController;

  @override
  void initState() {
    super.initState();
    _idController = TextEditingController(
      text: widget.beneficiary?.pseudonymousBeneficiaryId ??
          (widget.beneficiaryId.isNotEmpty ? widget.beneficiaryId : 'RC-KA-000001'),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      VoiceAssistantService.instance.guideAtmVerification();
    });
  }

  @override
  void dispose() {
    _idController.dispose();
    super.dispose();
  }

  Future<void> _handleVerification() async {
    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    final authMethod = _selectedMethod == 1
        ? 'DEMO_BIOMETRIC'
        : (_selectedMethod == 2 ? 'DEMO_OTP' : 'RATION_ID');

    try {
      final res = await GrainAtmService.instance.verifyBeneficiary(
        beneficiaryId: _idController.text.trim(),
        authMethod: authMethod,
      );

      if (!mounted) return;

      setState(() {
        _verificationResult = res;
        _isVerifying = false;
      });

      if (res.alreadyReceived) {
        if (!_hasSpokenAlreadyReceived) {
          _hasSpokenAlreadyReceived = true;
          VoiceAssistantService.instance.guideAtmAlreadyReceived();
        }
      } else if (!res.stockSufficient) {
        VoiceAssistantService.instance.guideAtmStockShortage();
      } else if (res.eligible) {
        VoiceAssistantService.instance.guideAtmAuthSuccess();
        // Automatically navigate to Dispense screen after short confirmation
        await Future.delayed(const Duration(milliseconds: 700));
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => GrainAtmDispenseScreen(
              verification: res,
              beneficiary: widget.beneficiary,
            ),
          ),
        );
      } else {
        VoiceAssistantService.instance.guideAtmAuthFailed();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isVerifying = false;
        _errorMessage = 'Verification error. Please check your details.';
      });
      VoiceAssistantService.instance.guideAtmAuthFailed();
    }
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
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Text(
              tr('grain_atm.verify_title'),
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
                      // Subtitle
                      Text(
                        tr('grain_atm.verify_subtitle'),
                        style: TextStyle(
                          fontSize: isElderly ? 16 : 14,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF475569),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // DEMO NOTICE BADGE (Compliance Requirement)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFFDE68A)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.verified_user_outlined, color: Color(0xFFB45309), size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                tr('grain_atm.demo_badge'),
                                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF92400E)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // ALREADY RECEIVED WARNING CARD (Authoritative Block)
                      if (_verificationResult?.alreadyReceived == true) ...[
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFEF4444), width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.red.withValues(alpha: 0.1),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              const Icon(Icons.check_circle_rounded, color: Color(0xFF15803D), size: 48),
                              const SizedBox(height: 12),
                              Text(
                                tr('grain_atm.already_received_title'),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF991B1B),
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                tr('grain_atm.already_received_desc'),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: isElderly ? 16 : 14,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF7F1D1D),
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: () => VoiceAssistantService.instance.guideAtmAlreadyReceived(),
                                icon: const Icon(Icons.volume_up_rounded),
                                label: Text(isHindi ? 'संदेश दोबारा सुनें' : isKannada ? 'ಮತ್ತೊಮ್ಮೆ ಕೇಳಿ' : 'Listen Again'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFDC2626),
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // INSUFFICIENT STOCK WARNING
                      if (_verificationResult != null &&
                          !_verificationResult!.alreadyReceived &&
                          !_verificationResult!.stockSufficient) ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF7ED),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFF97316)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.warning_amber_rounded, color: Color(0xFFC2410C), size: 28),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  isHindi
                                      ? 'आवश्यक राशन वर्तमान में इस पिकअप पॉइंट पर उपलब्ध नहीं है।'
                                      : isKannada
                                          ? 'ಅಗತ್ಯವಿರುವ ಪಡಿತರವು ಪ್ರಸ್ತುತ ಈ ಪಿಕಪ್ ಕೇಂದ್ರದಲ್ಲಿ ಲಭ್ಯವಿಲ್ಲ.'
                                          : 'The required ration is currently not available at this pickup point.',
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF9A3412)),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],

                      // 3 VERIFICATION METHOD OPTIONS
                      _buildMethodTile(
                        index: 0,
                        icon: Icons.badge_rounded,
                        title: tr('grain_atm.opt_ration_id'),
                        subtitle: 'PDS-KA-100245 / RC-KA-000001',
                        isSelected: _selectedMethod == 0,
                        isElderly: isElderly,
                      ),
                      const SizedBox(height: 12),
                      _buildMethodTile(
                        index: 1,
                        icon: Icons.fingerprint_rounded,
                        title: tr('grain_atm.opt_aadhaar_demo'),
                        subtitle: 'Demo Biometric Authentication',
                        isSelected: _selectedMethod == 1,
                        isElderly: isElderly,
                      ),
                      const SizedBox(height: 12),
                      _buildMethodTile(
                        index: 2,
                        icon: Icons.sms_rounded,
                        title: tr('grain_atm.opt_mobile_otp'),
                        subtitle: 'Demo Registered Mobile OTP (123456)',
                        isSelected: _selectedMethod == 2,
                        isElderly: isElderly,
                      ),
                      const SizedBox(height: 24),

                      // Input Field
                      Text(
                        _selectedMethod == 0
                            ? tr('grain_atm.opt_ration_id')
                            : (_selectedMethod == 1 ? 'Demo Aadhaar / Citizen ID' : 'Mobile Number'),
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppConstants.primaryNavy),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _idController,
                        style: TextStyle(fontSize: isElderly ? 18 : 16, fontWeight: FontWeight.bold),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          prefixIcon: Icon(
                            _selectedMethod == 1 ? Icons.fingerprint_rounded : Icons.credit_card_rounded,
                            color: const Color(0xFF0D9488),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFF0D9488), width: 2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Error message if any
                      if (_errorMessage != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                          ),
                        ),

                      // Submit Verification Button
                      SizedBox(
                        height: isElderly ? 60 : 54,
                        child: ElevatedButton.icon(
                          onPressed: (_isVerifying || _verificationResult?.alreadyReceived == true)
                              ? null
                              : _handleVerification,
                          icon: _isVerifying
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.verified_rounded),
                          label: Text(
                            _isVerifying
                                ? (isHindi ? 'सत्यापन हो रहा है...' : isKannada ? 'ಪರಿಶೀಲಿಸಲಾಗುತ್ತಿದೆ...' : 'Verifying...')
                                : tr('grain_atm.verify_btn'),
                            style: TextStyle(fontSize: isElderly ? 18 : 16, fontWeight: FontWeight.w900),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0D9488),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            elevation: 2,
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

  Widget _buildMethodTile({
    required int index,
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isSelected,
    required bool isElderly,
  }) {
    return InkWell(
      onTap: () => setState(() => _selectedMethod = index),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF0FDFA) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? const Color(0xFF0D9488) : const Color(0xFFE2E8F0),
            width: isSelected ? 2 : 1.2,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF0D9488) : const Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: isSelected ? Colors.white : AppConstants.primaryNavy, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: isElderly ? 16 : 14.5,
                      fontWeight: FontWeight.w800,
                      color: isSelected ? const Color(0xFF0F766E) : AppConstants.primaryNavy,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            Radio<int>(
              value: index,
              groupValue: _selectedMethod,
              activeColor: const Color(0xFF0D9488),
              onChanged: (val) => setState(() => _selectedMethod = val ?? 0),
            ),
          ],
        ),
      ),
    );
  }
}
