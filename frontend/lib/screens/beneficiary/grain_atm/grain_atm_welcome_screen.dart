import 'package:flutter/material.dart';
import '../../../core/constants.dart';
import '../../../core/localization.dart';
import '../../../models/beneficiary_model.dart';
import '../../../services/voice_assistant_service.dart';
import 'grain_atm_verify_screen.dart';

class GrainAtmWelcomeScreen extends StatefulWidget {
  final Beneficiary? beneficiary;
  final String beneficiaryId;

  const GrainAtmWelcomeScreen({
    super.key,
    this.beneficiary,
    required this.beneficiaryId,
  });

  @override
  State<GrainAtmWelcomeScreen> createState() => _GrainAtmWelcomeScreenState();
}

class _GrainAtmWelcomeScreenState extends State<GrainAtmWelcomeScreen> {
  bool _hasSpokenWelcome = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_hasSpokenWelcome && mounted) {
        _hasSpokenWelcome = true;
        VoiceAssistantService.instance.guideAtmWelcome();
      }
    });
  }

  void _navigateToVerification() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => GrainAtmVerifyScreen(
          beneficiary: widget.beneficiary,
          beneficiaryId: widget.beneficiaryId,
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
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Text(
              tr('grain_atm.welcome_title'),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: AppConstants.primaryNavy,
              ),
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
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 580),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Voice Guidance Reassurance Banner
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFBBF7D0)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.record_voice_over_rounded, color: Color(0xFF15803D), size: 22),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                isHindi
                                    ? 'आवाज़ सहायक सक्रिय है • पूरी प्रक्रिया में मार्गदर्शन मिलेगा'
                                    : isKannada
                                        ? 'ಧ್ವನಿ ಸಹಾಯಕ ಸಕ್ರಿಯವಾಗಿದೆ • ಸಂಪೂರ್ಣ ಹಂತಗಳಲ್ಲಿ ನೆರವು'
                                        : 'Voice Assistant Active • Automated Audio Guidance',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF15803D)),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.volume_up_rounded, color: Color(0xFF15803D), size: 22),
                              tooltip: 'Replay audio',
                              onPressed: () => VoiceAssistantService.instance.guideAtmWelcome(),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Large ATM Visual Hero
                      Center(
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF0D9488), Color(0xFF0F766E)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF0D9488).withValues(alpha: 0.3),
                                blurRadius: 24,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.precision_manufacturing_rounded,
                              size: 56,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Title & Subtitle
                      Text(
                        tr('grain_atm.welcome_title'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: isElderly ? 30 : 26,
                          fontWeight: FontWeight.w900,
                          color: AppConstants.primaryNavy,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        tr('grain_atm.welcome_subtitle'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: isElderly ? 16 : 14,
                          color: const Color(0xFF475569),
                          fontWeight: FontWeight.w600,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Simulation & PDS Integration Notice
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.info_outline_rounded, color: Color(0xFF0D9488), size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                isHindi
                                    ? 'पीडीएस डिमांडसिंक निर्णय बुद्धिमत्ता से एकीकृत। यह स्वचालित राशन वेंडिंग मशीन की डिजिटल सिमुलेशन है।'
                                    : isKannada
                                        ? 'ಪಿಡಿಎಸ್ ಡಿಮ್ಯಾಂಡ್‌ಸಿಂಕ್ ನಿರ್ಧಾರ ಬುದ್ಧಿಮತ್ತೆಗೆ ಸಂಪರ್ಕಿಸಲಾಗಿದೆ. ಇದು ಸ್ವಯಂಚಾಲಿತ ರೇಷನ್ ವೆಂಡಿಂಗ್ ಮೆಷಿನ್‌ನ ಡಿಜಿಟಲ್ ಸಿಮ್ಯುಲೇಶನ್ ಆಗಿದೆ.'
                                        : 'Connected with PDS-DemandSync decision intelligence. Digital simulation of automated ration vending machine.',
                                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.35),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 36),

                      // Primary Button: Start
                      SizedBox(
                        height: isElderly ? 64 : 56,
                        child: ElevatedButton.icon(
                          onPressed: _navigateToVerification,
                          icon: const Icon(Icons.arrow_forward_rounded, size: 24),
                          label: Text(
                            tr('grain_atm.start_btn'),
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
                      const SizedBox(height: 14),

                      // Secondary Button: Back
                      SizedBox(
                        height: 50,
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppConstants.primaryNavy,
                            side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.5),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: Text(
                            tr('grain_atm.back_btn'),
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
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
}
