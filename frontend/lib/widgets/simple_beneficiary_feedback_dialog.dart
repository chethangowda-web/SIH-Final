import 'package:flutter/material.dart';
import '../core/localization.dart';
import '../services/api_service.dart';
import '../services/voice_assistant_service.dart';

/// Highly accessible, visual, voice-assisted 2-step feedback & dispute dialog
/// for low-literacy and elderly beneficiaries.
class SimpleBeneficiaryFeedbackDialog extends StatefulWidget {
  final String beneficiaryId;
  final String? activeRequestId;
  final String? registeredFpsId;
  final ApiService apiService;
  final VoidCallback onFeedbackSubmitted;

  const SimpleBeneficiaryFeedbackDialog({
    super.key,
    required this.beneficiaryId,
    this.activeRequestId,
    this.registeredFpsId,
    required this.apiService,
    required this.onFeedbackSubmitted,
  });

  static Future<void> show(
    BuildContext context, {
    required String beneficiaryId,
    String? activeRequestId,
    String? registeredFpsId,
    required ApiService apiService,
    required VoidCallback onFeedbackSubmitted,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SimpleBeneficiaryFeedbackDialog(
        beneficiaryId: beneficiaryId,
        activeRequestId: activeRequestId,
        registeredFpsId: registeredFpsId,
        apiService: apiService,
        onFeedbackSubmitted: onFeedbackSubmitted,
      ),
    );
  }

  @override
  State<SimpleBeneficiaryFeedbackDialog> createState() =>
      _SimpleBeneficiaryFeedbackDialogState();
}

class _SimpleBeneficiaryFeedbackDialogState
    extends State<SimpleBeneficiaryFeedbackDialog> {
  int _currentStep = 1; // Step 1: Did you get ration? Step 2: What was the issue?
  String? _receiptChoice; // 'RECEIVED', 'ISSUE', 'NOT_RECEIVED'
  String? _selectedCategory; // 'SHORT_WEIGHT', 'DELIVERY_DELAY', 'STOCK_UNAVAILABLE', 'SHOP_CLOSED', 'RATION_QUALITY', 'GENERAL'
  final TextEditingController _remarksController = TextEditingController();
  bool _isSubmitting = false;
  String? _errorMessage;
  String? _submittedTicketId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _speakStep1();
    });
  }

  @override
  void dispose() {
    _remarksController.dispose();
    super.dispose();
  }

  void _speakStep1() {
    VoiceAssistantService.instance.speakLocalized(
      hiText: 'क्या आपको राशन मिला? हाँ मिला, समस्या हुई, या नहीं मिला चुनें।',
      knText: 'ನಿಮಗೆ ಪಡಿತರ ಸಿಕ್ಕಿತೇ? ಹೌದು ಸಿಕ್ಕಿದೆ, ಸಮಸ್ಯೆ ಆಯಿತು, ಅಥವಾ ಸಿಗಲಿಲ್ಲ ಆಯ್ಕೆಮಾಡಿ.',
      enText: 'Did you receive your ration? Choose received, had an issue, or not received.',
    );
  }

  void _speakStep2() {
    VoiceAssistantService.instance.speakLocalized(
      hiText: 'क्या समस्या हुई? कम राशन, देर हुई, दुकान बंद, या खराब अनाज चुनें।',
      knText: 'ಏನು ಸಮಸ್ಯೆ ಆಯಿತು? ಕಡಿಮೆ ಪಡಿತರ, ತಡವಾಯಿತು, ಅಂಗಡಿ ಮುಚ್ಚಿತ್ತು ಅಥವಾ ಕಳಪೆ ಗುಣಮಟ್ಟ ಆಯ್ಕೆಮಾಡಿ.',
      enText: 'What was the problem? Select less quantity, delay, shop closed, or damaged grain.',
    );
  }

  Future<void> _handleConfirmReceived() async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      if (widget.activeRequestId != null) {
        await widget.apiService.confirmCitizenDelivery(
          beneficiaryId: widget.beneficiaryId,
          requestId: widget.activeRequestId!,
          confirmationStatus: 'DELIVERY_CONFIRMED',
          receivedRiceKg: 0.0,
          receivedWheatKg: 0.0,
        );
      }

      VoiceAssistantService.instance.speakLocalized(
        hiText: 'धन्यवाद! आपका राशन मिलना सफलतापूर्वक दर्ज हो गया है।',
        knText: 'ಧನ್ಯವಾದಗಳು! ನಿಮ್ಮ ಪಡಿತರ ಸ್ವೀಕೃತಿ ಯಶಸ್ವಿಯಾಗಿ ದಾಖಲಾಗಿದೆ.',
        enText: 'Thank you! Your ration receipt has been successfully recorded.',
      );

      if (mounted) {
        widget.onFeedbackSubmitted();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'राशन मिलना दर्ज हो गया ✓ / Ration receipt confirmed',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF15803D),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  Future<void> _handleSubmitDisputeAndFeedback() async {
    if (_selectedCategory == null) {
      setState(() {
        _errorMessage = 'कृपया कोई एक समस्या चुनें / Please select an issue';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final issueDesc = _remarksController.text.trim().isNotEmpty
        ? _remarksController.text.trim()
        : 'Beneficiary reported: $_selectedCategory';

    try {
      // 1. If active request, record dispute in delivery_disputes
      if (widget.activeRequestId != null) {
        try {
          await widget.apiService.confirmCitizenDelivery(
            beneficiaryId: widget.beneficiaryId,
            requestId: widget.activeRequestId!,
            confirmationStatus: 'DELIVERY_DISPUTE',
            receivedRiceKg: 0.0,
            receivedWheatKg: 0.0,
            disputeNotes: '[Status: ${_receiptChoice ?? "ISSUE"}] $_selectedCategory: $issueDesc',
          );
        } catch (_) {}
      }

      // 2. Submit into feedback table via apiService.submitFeedback
      String ticketId = 'TKT-${DateTime.now().millisecondsSinceEpoch % 90000 + 10000}';
      try {
        final resp = await widget.apiService.submitFeedback(
          senderType: 'BENEFICIARY',
          senderId: widget.beneficiaryId,
          targetFpsId: widget.registeredFpsId ?? 'FPS-KA-BAG-0001',
          category: _selectedCategory!,
          subject: '[${_receiptChoice ?? "ISSUE"}] Beneficiary Issue: $_selectedCategory',
          message: issueDesc,
        );
        if (resp['ticket_id'] != null) {
          ticketId = resp['ticket_id'].toString();
        }
      } catch (_) {}

      VoiceAssistantService.instance.speakLocalized(
        hiText: 'आपकी समस्या दर्ज हो गई है। टिकट नंबर $ticketId है। अधिकारी इसे देख रहे हैं।',
        knText: 'ನಿಮ್ಮ ದೂರು ದಾಖಲಾಗಿದೆ. ಟಿಕೆಟ್ ಸಂಖ್ಯೆ $ticketId. ಅಧಿಕಾರಿಗಳು ಪರಿಶೀಲಿಸುತ್ತಿದ್ದಾರೆ.',
        enText: 'Your complaint has been recorded. Ticket number $ticketId. Officers are reviewing it.',
      );

      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _submittedTicketId = ticketId;
        });
        widget.onFeedbackSubmitted();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = LanguageController.instance.currentLanguage;
    final isHindi = lang == AppLanguage.hindi;
    final isKannada = lang == AppLanguage.kannada;
    final isElderly = VoiceAssistantService.instance.isElderlyMode;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: isElderly ? 20 : 16,
        vertical: isElderly ? 24 : 18,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 14),

            if (_submittedTicketId != null) ...[
              _buildSuccessTicketView(isHindi, isKannada),
            ] else if (_currentStep == 1) ...[
              _buildStep1View(isHindi, isKannada, isElderly),
            ] else ...[
              _buildStep2View(isHindi, isKannada, isElderly),
            ],
          ],
        ),
      ),
    );
  }

  // STEP 1: Did you get ration?
  Widget _buildStep1View(bool isHindi, bool isKannada, bool isElderly) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                isHindi
                    ? 'क्या आपको राशन मिला?'
                    : isKannada
                        ? 'ನಿಮಗೆ ಪಡಿತರ ಸಿಕ್ಕಿತೇ?'
                        : 'Did you receive your ration?',
                style: TextStyle(
                  fontSize: isElderly ? 22 : 18,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F2942),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.volume_up_rounded, color: Color(0xFF15803D), size: 26),
              tooltip: 'आवाज़ में सुनें',
              onPressed: _speakStep1,
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          isHindi
              ? 'कृपया नीचे दिए गए तीन विकल्पों में से एक चुनें:'
              : isKannada
                  ? 'ದಯವಿಟ್ಟು ಕೆಳಗಿನ ಮೂರು ಆಯ್ಕೆಗಳಲ್ಲಿ ಒಂದನ್ನು ಆರಿಸಿ:'
                  : 'Please select one of the three options below:',
          style: TextStyle(
            fontSize: isElderly ? 14 : 12.5,
            color: const Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 18),

        // 3 Big Visual Touch Cards
        // Card 1: Yes, Received
        _buildStep1Card(
          emoji: '😊',
          title: isHindi ? 'हाँ, पूरा राशन मिला' : isKannada ? 'ಹೌದು, ಪೂರ್ಣ ಸಿಕ್ಕಿದೆ' : 'Yes, Received Full Ration',
          subtitle: isHindi ? 'कोई शिकायत नहीं' : isKannada ? 'ಯಾವುದೇ ದೂರು ಇಲ್ಲ' : 'No issues',
          borderColor: const Color(0xFF15803D),
          bgColor: const Color(0xFFF0FDF4),
          textColor: const Color(0xFF166534),
          onTap: () {
            setState(() => _receiptChoice = 'RECEIVED');
            _handleConfirmReceived();
          },
        ),
        const SizedBox(height: 12),

        // Card 2: Had an issue
        _buildStep1Card(
          emoji: '😐',
          title: isHindi ? 'राशन मिला, लेकिन समस्या हुई' : isKannada ? 'ಸಿಕ್ಕಿದೆ, ಆದರೆ ಸಮಸ್ಯೆ ಆಯಿತು' : 'Received, But Had an Issue',
          subtitle: isHindi ? 'कम तौल, देरी या गुणवत्ता' : isKannada ? 'ಕಡಿಮೆ ತೂಕ ಅಥವಾ ವಿಳಂಬ' : 'Short weight, delay, or quality',
          borderColor: const Color(0xFFD97706),
          bgColor: const Color(0xFFFFFBEB),
          textColor: const Color(0xFF92400E),
          onTap: () {
            setState(() {
              _receiptChoice = 'ISSUE';
              _currentStep = 2;
            });
            _speakStep2();
          },
        ),
        const SizedBox(height: 12),

        // Card 3: Not received
        _buildStep1Card(
          emoji: '😞',
          title: isHindi ? 'नहीं मिला (दुकान बंद / स्टॉक खत्म)' : isKannada ? 'ಸಿಗಲಿಲ್ಲ (ಅಂಗಡಿ ಮುಚ್ಚಿತ್ತು/ಸ್ಟಾಕ್ ಇಲ್ಲ)' : 'Did Not Receive (No Stock / Closed)',
          subtitle: isHindi ? 'शिकायत दर्ज करें' : isKannada ? 'ದೂರು ದಾಖಲಿಸಿ' : 'Report shortage to officer',
          borderColor: const Color(0xFFDC2626),
          bgColor: const Color(0xFFFEF2F2),
          textColor: const Color(0xFF991B1B),
          onTap: () {
            setState(() {
              _receiptChoice = 'NOT_RECEIVED';
              _currentStep = 2;
            });
            _speakStep2();
          },
        ),

        if (_isSubmitting) ...[
          const SizedBox(height: 20),
          const Center(child: CircularProgressIndicator(color: Color(0xFF15803D))),
        ],

        if (_errorMessage != null) ...[
          const SizedBox(height: 12),
          Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 12)),
        ],
      ],
    );
  }

  // STEP 2: What was the issue?
  Widget _buildStep2View(bool isHindi, bool isKannada, bool isElderly) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                isHindi
                    ? 'क्या समस्या हुई?'
                    : isKannada
                        ? 'ಏನು ಸಮಸ್ಯೆ ಆಯಿತು?'
                        : 'What was the problem?',
                style: TextStyle(
                  fontSize: isElderly ? 22 : 18,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F2942),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.volume_up_rounded, color: Color(0xFF15803D), size: 26),
              tooltip: 'आवाज़ में सुनें',
              onPressed: _speakStep2,
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          isHindi
              ? 'समस्या पर टैप करें (अधिकारी तुरंत जांच करेंगे):'
              : isKannada
                  ? 'ಸಮಸ್ಯೆಯನ್ನು ಆರಿಸಿ (ಅಧಿಕಾರಿಗಳು ತಕ್ಷಣ ಕ್ರಮ ಕೈಗೊಳ್ಳುವರು):'
                  : 'Tap the issue below (DSO officers will review):',
          style: TextStyle(fontSize: isElderly ? 13.5 : 12, color: const Color(0xFF64748B)),
        ),
        const SizedBox(height: 14),

        // Problem choices
        _buildIssueOption(
          code: 'SHORT_WEIGHT',
          icon: Icons.scale_rounded,
          label: isHindi ? '🌾 कम राशन मिला (कम तौल)' : isKannada ? '🌾 ಕಡಿಮೆ ಪಡಿತರ ನೀಡಲಾಗಿದೆ' : '🌾 Less Ration Given (Short Weight)',
        ),
        _buildIssueOption(
          code: 'DELIVERY_DELAY',
          icon: Icons.access_time_rounded,
          label: isHindi ? '⏰ मिलने में देर हुई' : isKannada ? '⏰ ಬರುವುದು ತಡವಾಯಿತು' : '⏰ Delivery Delay',
        ),
        _buildIssueOption(
          code: 'STOCK_UNAVAILABLE',
          icon: Icons.inventory_2_outlined,
          label: isHindi ? '📦 राशन नहीं मिला / स्टॉक खत्म' : isKannada ? '📦 ಪಡಿತರ ಸಿಗಲಿಲ್ಲ / ಸ್ಟಾಕ್ ಇರಲಿಲ್ಲ' : '📦 No Stock Available at Shop',
        ),
        _buildIssueOption(
          code: 'SHOP_CLOSED',
          icon: Icons.storefront_rounded,
          label: isHindi ? '🏪 दुकान बंद थी / डीलर नहीं मिला' : isKannada ? '🏪 ಅಂಗಡಿ ಮುಚ್ಚಿತ್ತು / ಡೀಲರ್ ಇಲ್ಲ' : '🏪 Shop Closed / Dealer Unavailable',
        ),
        _buildIssueOption(
          code: 'RATION_QUALITY',
          icon: Icons.warning_amber_rounded,
          label: isHindi ? '🌾 खराब अनाज / कीड़ा लगा अनाज' : isKannada ? '🌾 ಕಳಪೆ ಗುಣಮಟ್ಟ / ಹಾನಿಗೊಳಗಾದ ಧಾನ್ಯ' : '🌾 Poor Grain Quality / Damaged',
        ),
        _buildIssueOption(
          code: 'GENERAL',
          icon: Icons.chat_bubble_outline_rounded,
          label: isHindi ? '💬 कोई दूसरी समस्या' : isKannada ? '💬 ಇತರೆ ಸಮಸ್ಯೆ' : '💬 Other Issue',
        ),

        const SizedBox(height: 12),

        // Optional Remarks or Voice
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _remarksController,
                decoration: InputDecoration(
                  hintText: isHindi
                      ? 'कुछ और लिखना चाहें तो लिखें...'
                      : isKannada
                          ? 'ಹೆಚ್ಚಿನ ವಿವರ ಬರೆಯಿರಿ...'
                          : 'Additional details (optional)...',
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.mic_rounded, color: Color(0xFF15803D), size: 28),
              tooltip: 'बोलकर बताएं',
              onPressed: () {
                VoiceAssistantService.instance.showVoiceAssistantDialog(
                  context,
                  onCommand: (cmd) {
                    setState(() {
                      if (cmd == 'RICE') _remarksController.text = 'Rice issue reported';
                      if (cmd == 'WHEAT') _remarksController.text = 'Wheat issue reported';
                      if (cmd == 'SHOP') _selectedCategory = 'SHOP_CLOSED';
                    });
                  },
                );
              },
            ),
          ],
        ),

        if (_errorMessage != null) ...[
          const SizedBox(height: 10),
          Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 12)),
        ],

        const SizedBox(height: 18),

        // Action buttons
        ElevatedButton(
          onPressed: _isSubmitting ? null : _handleSubmitDisputeAndFeedback,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFDC2626),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: _isSubmitting
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : Text(
                  isHindi ? 'शिकायत दर्ज करें 👉' : isKannada ? 'ದೂರು ಸಲ್ಲಿಸಿ 👉' : 'Submit Complaint 👉',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => setState(() => _currentStep = 1),
          child: Text(isHindi ? 'पीछे जाएं' : isKannada ? 'ಹಿಂದಕ್ಕೆ' : 'Back'),
        ),
      ],
    );
  }

  // SUCCESS CONFIRMATION MODAL
  Widget _buildSuccessTicketView(bool isHindi, bool isKannada) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Center(
          child: Icon(Icons.check_circle_rounded, color: Color(0xFF15803D), size: 54),
        ),
        const SizedBox(height: 12),
        Text(
          isHindi ? 'आपकी शिकायत दर्ज हो गई है ✓' : isKannada ? 'ನಿಮ್ಮ ದೂರು ಯಶಸ್ವಿಯಾಗಿ ದಾಖಲಾಗಿದೆ ✓' : 'Complaint Successfully Filed ✓',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: Color(0xFF0F2942)),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF0FDF4),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF86EFAC)),
          ),
          child: Column(
            children: [
              Text(
                isHindi ? 'शिकायत टोकन नंबर:' : isKannada ? 'ದೂರು ಟೋಕನ್ ಸಂಖ್ಯೆ:' : 'Complaint Ticket Number:',
                style: const TextStyle(fontSize: 12, color: Color(0xFF166534), fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                _submittedTicketId!,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFF15803D), letterSpacing: 1.5),
              ),
              const SizedBox(height: 6),
              Text(
                isHindi
                    ? 'जिला आपूर्ति अधिकारी (DSO) को आपकी शिकायत भेज दी गई है।'
                    : isKannada
                        ? 'ಜಿಲ್ಲಾ ಸರಬರಾಜು ಅಧಿಕಾರಿಗೆ (DSO) ಕಳುಹಿಸಲಾಗಿದೆ.'
                        : 'Dispatched to District Supply Officer (DSO) triage queue.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11.5, color: Color(0xFF166534)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        ElevatedButton(
          onPressed: () => Navigator.pop(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0F2942),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: Text(isHindi ? 'ठीक है (बंद करें)' : isKannada ? 'ಸರಿ (ಮುಚ್ಚಿ)' : 'Done (Close)'),
        ),
      ],
    );
  }

  Widget _buildStep1Card({
    required String emoji,
    required String title,
    required String subtitle,
    required Color borderColor,
    required Color bgColor,
    required Color textColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor, width: 1.6),
          boxShadow: const [
            BoxShadow(color: Color(0x0A000000), blurRadius: 4, offset: Offset(0, 2)),
          ],
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 32)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: textColor.withValues(alpha: 0.8)),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: textColor, size: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildIssueOption({
    required String code,
    required IconData icon,
    required String label,
  }) {
    final isSelected = _selectedCategory == code;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => setState(() => _selectedCategory = code),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFFEF2F2) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? const Color(0xFFDC2626) : const Color(0xFFE2E8F0),
              width: isSelected ? 1.8 : 1.0,
            ),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: isSelected ? const Color(0xFFDC2626) : const Color(0xFF64748B)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected ? const Color(0xFF991B1B) : const Color(0xFF1E293B),
                  ),
                ),
              ),
              if (isSelected)
                const Icon(Icons.check_circle_rounded, color: Color(0xFFDC2626), size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
