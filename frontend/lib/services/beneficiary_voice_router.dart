import '../core/localization.dart';
import 'voice_assistant_service.dart';

enum BeneficiaryVoiceIntent {
  demandSelection,
  grainAtm,
  rationShop,
  tracking,
  helpFeedback,
  historyReceipts,
  profileCard,
  languageHindi,
  languageKannada,
  languageEnglish,
  repeatHelp,
  unknown,
}

class BeneficiaryVoiceResolution {
  final BeneficiaryVoiceIntent intent;
  final String rawTranscript;
  final String? grainType; // 'RICE', 'WHEAT', 'BOTH'
  final double? quantityKg;
  final String confirmationEn;
  final String confirmationHi;
  final String confirmationKn;

  const BeneficiaryVoiceResolution({
    required this.intent,
    required this.rawTranscript,
    this.grainType,
    this.quantityKg,
    required this.confirmationEn,
    required this.confirmationHi,
    required this.confirmationKn,
  });

  String getConfirmation(AppLanguage lang) {
    switch (lang) {
      case AppLanguage.hindi:
        return confirmationHi;
      case AppLanguage.kannada:
        return confirmationKn;
      case AppLanguage.english:
        return confirmationEn;
    }
  }
}

/// Centralized Beneficiary Voice Command Router / Intent Resolver.
/// Maps natural spoken beneficiary sentences across English, Hindi, and Kannada
/// to real existing portal screens and backend actions.
class BeneficiaryVoiceCommandRouter {
  static BeneficiaryVoiceResolution resolve(String rawTranscript) {
    final clean = rawTranscript.trim().toLowerCase().replaceAll(RegExp(r'[^\w\s\u0900-\u097F\u0C80-\u0CFF]'), ' ');
    final normalized = ' ' + clean.replaceAll(RegExp(r'\s+'), ' ') + ' ';

    // 1. Language Switching Commands
    if (_matches(normalized, [
      'switch to hindi', 'talk in hindi', 'speak in hindi', 'change to hindi', 'hindi me', 'hindi mein',
      'हिंदी में बोलो', 'हिंदी करो', 'हिंदी भाषा', 'हिंदी में बात करो', 'हिंदी',
      'ಹಿಂದಿಯಲ್ಲಿ ಮಾತನಾಡಿ', 'ಹಿಂದಿ ಭಾಷೆ',
    ])) {
      return BeneficiaryVoiceResolution(
        intent: BeneficiaryVoiceIntent.languageHindi,
        rawTranscript: rawTranscript,
        confirmationEn: 'Language changed to Hindi.',
        confirmationHi: 'भाषा बदलकर हिंदी कर दी गई है।',
        confirmationKn: 'ಭಾಷೆಯನ್ನು ಹಿಂದಿಗೆ ಬದಲಾಯಿಸಲಾಗಿದೆ.',
      );
    }

    if (_matches(normalized, [
      'switch to kannada', 'talk in kannada', 'speak in kannada', 'change to kannada', 'kannada me', 'kannada mein',
      'कन्नड़ में बोलो', 'कन्नड़ भाषा', 'कन्नड़',
      'ಕನ್ನಡದಲ್ಲಿ ಮಾತನಾಡಿ', 'ಕನ್ನಡ ಭಾಷೆ', 'ಕನ್ನಡ ಮಾಡಿ', 'ಕನ್ನಡ',
    ])) {
      return BeneficiaryVoiceResolution(
        intent: BeneficiaryVoiceIntent.languageKannada,
        rawTranscript: rawTranscript,
        confirmationEn: 'Language changed to Kannada.',
        confirmationHi: 'भाषा बदलकर कन्नड़ कर दी गई है।',
        confirmationKn: 'ಭಾಷೆಯನ್ನು ಕನ್ನಡಕ್ಕೆ ಬದಲಾಯಿಸಲಾಗಿದೆ.',
      );
    }

    if (_matches(normalized, [
      'switch to english', 'talk in english', 'speak in english', 'change to english', 'english me', 'english mein',
      'अंग्रेज़ी में बोलो', 'अंग्रेज़ी करो', 'अंग्रेज़ी भाषा', 'अंग्रेजी',
      'ಇಂಗ್ಲಿಷ್‌ನಲ್ಲಿ ಮಾತನಾಡಿ', 'ಇಂಗ್ಲಿಷ್ ಭಾಷೆ', 'ಇಂಗ್ಲಿಷ್',
    ])) {
      return BeneficiaryVoiceResolution(
        intent: BeneficiaryVoiceIntent.languageEnglish,
        rawTranscript: rawTranscript,
        confirmationEn: 'Language changed to English.',
        confirmationHi: 'भाषा बदलकर अंग्रेज़ी कर दी गई है।',
        confirmationKn: 'ಭಾಷೆಯನ್ನು ಇಂಗ್ಲಿಷ್‌ಗೆ ಬದಲಾಯಿಸಲಾಗಿದೆ.',
      );
    }

    // 2. Smart Grain ATM / Automated Ration Pickup
    if (_matches(normalized, [
      'vending machine', 'ration vending machine', 'ration vending', 'use vending machine', 'grain atm', 'smart atm', 'use atm', 'use grain atm', 'get my ration', 'collect my ration',
      'collect ration', 'where can i collect my ration', 'vending machine', 'pickup machine',
      'automated pickup', 'atm pickup', 'atm machine', 'dispense ration', 'take ration', 'get ration',
      'राशन वेंडिंग मशीन', 'वेंडिंग मशीन', 'राशन लें', 'एटीएम से राशन', 'ग्रेन एटीएम', 'स्मार्ट एटीएम', 'राशन निकालना है', 'मशीन से राशन',
      'स्वचालित मशीन', 'एटीएम', 'राशन मशीन', 'राशन ले लो',
      'ರೇಷನ್ ವೆಂಡಿಂಗ್ ಮೆಷಿನ್', 'ವೆಂಡಿಂಗ್ ಮೆಷಿನ್', 'ಪಡಿತರ ಪಡೆಯಿರಿ', 'ಗ್ರೇನ್ ಎಟಿಎಂ', 'ಧಾನ್ಯ ಎಟಿಎಂ', 'ಸ್ಮಾರ್ಟ್ ಎಟಿಎಂ', 'ಎಟಿಎಂನಿಂದ ಪಡಿತರ', 'ಯಂತ್ರದಿಂದ ಪಡಿತರ',
      'ಎಟಿಎಂ ಪಿಕಪ್', 'ಎಟಿಎಂ', 'ಪಡಿತರ ತಗೊಳ್ಳಿ',
    ])) {
      return BeneficiaryVoiceResolution(
        intent: BeneficiaryVoiceIntent.grainAtm,
        rawTranscript: rawTranscript,
        confirmationEn: 'Opening Ration Vending Machine.',
        confirmationHi: 'राशन वेंडिंग मशीन खोली जा रही है।',
        confirmationKn: 'ರೇಷನ್ ವೆಂಡಿಂಗ್ ಮೆಷಿನ್ ತೆರೆಯಲಾಗುತ್ತಿದೆ.',
      );
    }

    // 3. Ration Shop / FPS Location & Map
    if (_matches(normalized, [
      'my ration shop', 'where is my ration shop', 'where is my shop', 'show my fps', 'which shop should i go to',
      'which shop', 'shop location', 'show map', 'fps location', 'ration shop', 'fps center', 'shop address',
      'fair price shop', 'how far is my shop', 'view shop', 'shop route', 'my fps',
      'मेरी राशन दुकान', 'राशन दुकान', 'दुकान कहां है', 'दुकान का रास्ता', 'नक्शा दिखाओ', 'राशन केंद्र',
      'मेरी दुकान', 'दुकान कितनी दूर है', 'दुकान का पता', 'राशन शॉप', 'दुकान दिखाओ',
      'ನನ್ನ ಪಡಿತರ ಅಂಗಡಿ', 'ಪಡಿತರ ಅಂಗಡಿ', 'ಅಂಗಡಿ ಎಲ್ಲಿದೆ', 'ಅಂಗಡಿ ದಾರಿ', 'ನಕ್ಷೆ ತೋರಿಸಿ', 'ಪಡಿತರ ಕೇಂದ್ರ',
      'ನನ್ನ ಅಂಗಡಿ', 'ಅಂಗಡಿ ದೂರ', 'ಅಂಗಡಿ ವಿಳಾಸ', 'ಅಂಗಡಿ ತೋರಿಸಿ',
    ])) {
      return BeneficiaryVoiceResolution(
        intent: BeneficiaryVoiceIntent.rationShop,
        rawTranscript: rawTranscript,
        confirmationEn: 'Opening your ration shop details and map.',
        confirmationHi: 'आपकी राशन दुकान और नक्शा खोला जा रहा है।',
        confirmationKn: 'ನಿಮ್ಮ ಪಡಿತರ ಅಂಗಡಿ ಮತ್ತು ನಕ್ಷೆಯನ್ನು ತೆರೆಯಲಾಗುತ್ತಿದೆ.',
      );
    }

    // 4. Tracking / Real-Time Delivery Status
    if (_matches(normalized, [
      'track my ration', 'track ration', 'where is my ration', 'is my ration ready', 'has my ration been delivered',
      'delivery status', 'when will ration arrive', 'ration status', 'order status', 'dispatch status',
      'is ration delivered', 'check status', 'track delivery', 'where has ration reached',
      'राशन कहां पहुंचा', 'ट्रैक राशन', 'राशन ट्रैक करें', 'राशन की स्थिति', 'क्या राशन तैयार है',
      'राशन कब आएगा', 'डिलीवरी स्थिति', 'राशन मिला क्या', 'राशन कहां है', 'स्थिति बताओ',
      'ಪಡಿತರ ಎಲ್ಲಿಗೆ ತಲುಪಿದೆ', 'ಟ್ರ್ಯಾಕ್ ಪಡಿತರ', 'ಪಡಿತರ ಟ್ರ್ಯಾಕ್ ಮಾಡಿ', 'ಪಡಿತರ ಸ್ಥಿತಿ', 'ಪಡಿತರ ಬಂದಿದೆಯೇ',
      'ರವಾನೆ ಸ್ಥಿತಿ', 'ಪಡಿತರ ಸಿದ್ಧವಾಗಿದೆಯೇ', 'ಸ್ಥಿತಿ ತಿಳಿಸಿ',
    ])) {
      return BeneficiaryVoiceResolution(
        intent: BeneficiaryVoiceIntent.tracking,
        rawTranscript: rawTranscript,
        confirmationEn: 'Checking your ration delivery status.',
        confirmationHi: 'राशन वितरण की स्थिति देखी जा रही है।',
        confirmationKn: 'ಪಡಿತರ ವಿತರಣಾ ಸ್ಥಿತಿಯನ್ನು ಪರಿಶೀಲಿಸಲಾಗುತ್ತಿದೆ.',
      );
    }

    // 5. Help / Problem / Grievance / Feedback
    if (_matches(normalized, [
      'i have a problem', 'i need help', 'i did not receive my ration', 'my ration is short', 'i want to complain',
      'give feedback', 'report a problem', 'report problem', 'file complaint', 'file grievance', 'grievance',
      'short ration', 'ration missing', 'help', 'problem', 'support', 'complaint', 'officer help',
      'मुझे समस्या है', 'मदद चाहिए', 'राशन नहीं मिला', 'कम राशन मिला', 'शिकायत करनी है', 'फीडबैक देना है',
      'समस्या बताएं', 'शिकायत दर्ज करें', 'सहायता चाहिए', 'समस्या', 'शिकायत', 'मदद',
      'ಸಮಸ್ಯೆ ಇದೆ', 'ಸಹಾಯ ಬೇಕು', 'ಪಡಿತರ ಸಿಗಲಿಲ್ಲ', 'ಕಡಿಮೆ ಪಡಿತರ', 'ದೂರು ನೀಡಬೇಕು', 'ಪ್ರತಿಕ್ರಿಯೆ ನೀಡಿ',
      'ದೂರು ದಾಖಲಿಸಿ', 'ಸಹಾಯ', 'ಸಮಸ್ಯೆ', 'ದೂರು',
    ])) {
      return BeneficiaryVoiceResolution(
        intent: BeneficiaryVoiceIntent.helpFeedback,
        rawTranscript: rawTranscript,
        confirmationEn: 'Opening help and grievance form.',
        confirmationHi: 'मदद और शिकायत फ़ॉर्म खोला जा रहा है।',
        confirmationKn: 'ಸಹಾಯ ಮತ್ತು ದೂರು ಫಾರ್ಮ್ ತೆರೆಯಲಾಗುತ್ತಿದೆ.',
      );
    }

    // 6. History & Receipts
    if (_matches(normalized, [
      'show history', 'my history', 'past orders', 'past distributions', 'distribution history', 'receipt',
      'receipts', 'show receipts', 'show my receipt', 'previous ration', 'history timeline', 'timeline',
      'इतिहास दिखाओ', 'पिछला राशन', 'रसीद दिखाओ', 'मेरी रसीद', 'वितरण इतिहास', 'पुराना राशन', 'रसीद',
      'ಇತಿಹಾಸ ತೋರಿಸಿ', 'ಹಿಂದಿನ ಪಡಿತರ', 'ರಸೀದಿ ತೋರಿಸಿ', 'ನನ್ನ ರಸೀದಿ', 'ವಿತರಣಾ ಇತಿಹಾಸ', 'ರಸೀದಿ',
    ])) {
      return BeneficiaryVoiceResolution(
        intent: BeneficiaryVoiceIntent.historyReceipts,
        rawTranscript: rawTranscript,
        confirmationEn: 'Opening your ration distribution history and receipts.',
        confirmationHi: 'राशन इतिहास और रसीदें खोली जा रही हैं।',
        confirmationKn: 'ಪಡಿತರ ಇತಿಹಾಸ ಮತ್ತು ರಸೀದಿಗಳನ್ನು ತೆರೆಯಲಾಗುತ್ತಿದೆ.',
      );
    }

    // 7. Profile / Household / Ration Card
    if (_matches(normalized, [
      'my profile', 'ration card', 'show profile', 'my card', 'family members', 'household members',
      'card details', 'who is in my card', 'eligible members',
      'मेरी प्रोफ़ाइल', 'राशन कार्ड', 'मेरा कार्ड', 'परिवार के सदस्य', 'कार्ड विवरण', 'प्रोफ़ाइल दिखाओ',
      'ನನ್ನ ಪ್ರೊಫೈಲ್', 'ಪಡಿತರ ಚೀಟಿ', 'ನನ್ನ ಕಾರ್ಡ್', 'ಕುಟುಂಬದ ಸದಸ್ಯರು', 'ಕಾರ್ಡ್ ವಿವರ', 'ಪ್ರೊಫೈಲ್ ತೋರಿಸಿ',
    ])) {
      return BeneficiaryVoiceResolution(
        intent: BeneficiaryVoiceIntent.profileCard,
        rawTranscript: rawTranscript,
        confirmationEn: 'Opening your ration card profile and family details.',
        confirmationHi: 'राशन कार्ड प्रोफ़ाइल और परिवार का विवरण खोला जा रहा है।',
        confirmationKn: 'ಪಡಿತರ ಚೀಟಿ ಪ್ರೊಫೈಲ್ ಮತ್ತು ಕುಟುಂಬದ ವಿವರಗಳನ್ನು ತೆರೆಯಲಾಗುತ್ತಿದೆ.',
      );
    }

    // 8. Demand / Ration Requirement / Grain Selection
    final isRice = _matches(normalized, ['rice', 'चावल', 'अक्की', 'chawal', 'akki']);
    final isWheat = _matches(normalized, ['wheat', 'गेहूं', 'गेहूँ', 'ಗೋಧಿ', 'gehu', 'godhi']);
    final isBoth = _matches(normalized, ['both', 'दोनों', 'ಎರಡೂ', 'dono', 'eradu']);

    if (_matches(normalized, [
      'i want ration', 'i need ration', 'i need rice', 'i need wheat', 'what do i need next time',
      'select my ration', 'choose my ration', 'select ration', 'choose ration', 'change ration',
      'ration requirement', 'apply for ration', 'ration quota', 'monthly ration', 'food grains',
      'राशन चाहिए', 'मुझे राशन चाहिए', 'चावल चाहिए', 'गेहूं चाहिए', 'अगली बार क्या चाहिए', 'राशन चुनें',
      'राशन पसंद', 'राशन मांग', 'मासिक राशन', 'अनाज चाहिए', 'कोटा',
      'ಪಡಿತರ ಬೇಕು', 'ನನಗೆ ಪಡಿತರ ಬೇಕು', 'ಅಕ್ಕಿ ಬೇಕು', 'ಗೋಧಿ ಬೇಕು', 'ಮುಂದಿನ ಬಾರಿ ಏನು ಬೇಕು', 'ಪಡಿತರ ಆಯ್ಕೆ',
      'ಪಡಿತರ ಆಯ್ಕೆ ಮಾಡಿ', 'ಮಾಸಿಕ ಪಡಿತರ', 'ಧಾನ್ಯ ಬೇಕು',
    ]) || isRice || isWheat || isBoth) {
      String? grainType;
      if (isBoth || (isRice && isWheat)) {
        grainType = 'BOTH';
      } else if (isRice) {
        grainType = 'RICE';
      } else if (isWheat) {
        grainType = 'WHEAT';
      }

      final qty = VoiceAssistantService.extractSpokenQuantity(rawTranscript);

      return BeneficiaryVoiceResolution(
        intent: BeneficiaryVoiceIntent.demandSelection,
        rawTranscript: rawTranscript,
        grainType: grainType,
        quantityKg: qty,
        confirmationEn: 'Opening your ration selection.',
        confirmationHi: 'राशन पसंद स्क्रीन खोली जा रही है।',
        confirmationKn: 'ಪಡಿತರ ಆಯ್ಕೆ ಪರದೆಯನ್ನು ತೆರೆಯಲಾಗುತ್ತಿದೆ.',
      );
    }

    // 9. Repeat Guidance / What can I say
    if (_matches(normalized, [
      'what can i say', 'help me speak', 'what are the commands', 'how to use', 'help me', 'repeat',
      'speak again', 'what to do',
      'मैं क्या बोल सकता हूँ', 'क्या कहूँ', 'कमांड बताओ', 'दोबारा बोलो', 'मदद करो', 'कैसे इस्तेमाल करें',
      'ನಾನು ಏನು ಹೇಳಬಹುದು', 'ಕಮಾಂಡ್‌ಗಳು', 'ಮತ್ತೆ ಹೇಳಿ', 'ಹೇಗೆ ಬಳಸುವುದು',
    ])) {
      return BeneficiaryVoiceResolution(
        intent: BeneficiaryVoiceIntent.repeatHelp,
        rawTranscript: rawTranscript,
        confirmationEn: 'You can ask what you need, find your ration shop, track your ration, collect your ration, or report a problem.',
        confirmationHi: 'आप मुझसे राशन की मांग कर सकते हैं, अपनी राशन दुकान खोज सकते हैं, राशन ट्रैक कर सकते हैं, राशन वेंडिंग मशीन से राशन ले सकते हैं, या समस्या बता सकते हैं।',
        confirmationKn: 'ನೀವು ಪಡಿತರ ಆಯ್ಕೆ ಮಾಡಬಹುದು, ನಿಮ್ಮ ಅಂಗಡಿ ಹುಡುಕಬಹುದು, ಪಡಿತರ ಟ್ರ್ಯಾಕ್ ಮಾಡಬಹುದು, ರೇಷನ್ ವೆಂಡಿಂಗ್ ಮೆಷಿನ್‌ನಿಂದ ಪಡೆಯಬಹುದು, ಅಥವಾ ದೂರು ನೀಡಬಹುದು.',
      );
    }

    // 10. Unknown command
    return BeneficiaryVoiceResolution(
      intent: BeneficiaryVoiceIntent.unknown,
      rawTranscript: rawTranscript,
      confirmationEn: 'I heard: "$rawTranscript". You can ask to select ration, find your shop, track delivery, use vending machine, or report a problem.',
      confirmationHi: 'मैंने सुना: "$rawTranscript"। आप राशन की मांग, दुकान, ट्रैकिंग, वेंडिंग मशीन, या समस्या के बारे में बोल सकते हैं।',
      confirmationKn: 'ನಾನು ಕೇಳಿದ್ದು: "$rawTranscript". ನೀವು ಪಡಿತರ, ಅಂಗಡಿ, ಟ್ರ್ಯಾಕಿಂಗ್, ವೆಂಡಿಂಗ್ ಮೆಷಿನ್, ಅಥವಾ ದೂರಿನ ಬಗ್ಗೆ ಕೇಳಬಹುದು.',
    );
  }

  static bool _matches(String text, List<String> phrases) {
    for (final phrase in phrases) {
      final p = phrase.trim().toLowerCase();
      if (p.isEmpty) continue;
      // Word or boundary match
      if (text.contains(p)) return true;
    }
    return false;
  }
}
