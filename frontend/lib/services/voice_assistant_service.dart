import 'dart:async';
import 'package:flutter/material.dart';
import '../core/localization.dart';
import 'voice_audio_helper.dart';

/// Central Voice & Audio Assistance Service for low-literacy and elderly beneficiaries.
class VoiceAssistantService extends ChangeNotifier {
  VoiceAssistantService._() {
    LanguageController.instance.onLanguageChangedCallback = onLanguageChanged;
  }
  static final VoiceAssistantService instance = VoiceAssistantService._();

  bool _isSpeaking = false;
  bool _isElderlyMode = false;
  bool _audioAssistanceEnabled = true;
  bool _isVoiceAssistantMode = false;
  Timer? _speakDebounce;

  // Speech Recognition state
  bool _isListening = false;
  String _speechRecognitionStatus = 'idle'; // 'idle', 'listening', 'no_speech', 'permission_denied', 'unsupported', 'error'
  String _recognizedSpeech = '';
  Function(String transcript)? onCommandRecognized;

  String _lastHiText = '';
  String _lastKnText = '';
  String _lastEnText = '';

  bool get isSpeaking => _isSpeaking;
  bool get isElderlyMode => _isElderlyMode;
  bool get audioAssistanceEnabled => _audioAssistanceEnabled;
  bool get isVoiceMuted => !_audioAssistanceEnabled;
  bool get isVoiceAssistantMode => _isVoiceAssistantMode;

  bool get isListening => _isListening;
  String get speechRecognitionStatus => _speechRecognitionStatus;
  String get recognizedSpeech => _recognizedSpeech;
  bool get isSpeechSupported => platformIsSpeechRecognitionSupported();

  String get currentSpokenText {
    final lang = LanguageController.instance.currentLanguage;
    switch (lang) {
      case AppLanguage.hindi:
        return _lastHiText;
      case AppLanguage.kannada:
        return _lastKnText;
      case AppLanguage.english:
        return _lastEnText;
    }
  }

  bool get isHindi => LanguageController.instance.currentLanguage == AppLanguage.hindi;
  bool get isKannada => LanguageController.instance.currentLanguage == AppLanguage.kannada;

  void toggleMute() => toggleAudioAssistance();

  void startVoiceGuidedJourney() {
    _isVoiceAssistantMode = true;
    _audioAssistanceEnabled = true;
    notifyListeners();
    guideBeneficiaryPostLoginWelcome();
  }

  void enableBeneficiaryVoiceMode() {
    _isVoiceAssistantMode = true;
    _audioAssistanceEnabled = true;
    notifyListeners();
  }

  void stopVoiceAssistantMode() {
    _isVoiceAssistantMode = false;
    stop();
    stopListening();
    _recognizedSpeech = '';
    notifyListeners();
  }

  void guideBeneficiaryPostLoginWelcome() {
    speakLocalized(
      hiText: 'स्वागत है। आप मुझसे राशन की मांग कर सकते हैं, अपनी राशन दुकान खोज सकते हैं, राशन ट्रैक कर सकते हैं, ग्रेन एटीएम से राशन ले सकते हैं, या समस्या बता सकते हैं।',
      knText: 'ಸ್ವಾಗತ. ನೀವು ಪಡಿತರ ಆಯ್ಕೆ ಮಾಡಬಹುದು, ನಿಮ್ಮ ಅಂಗಡಿ ಹುಡುಕಬಹುದು, ಪಡಿತರ ಟ್ರ್ಯಾಕ್ ಮಾಡಬಹುದು, ಗ್ರೇನ್ ಎಟಿಎಂನಿಂದ ಪಡೆಯಬಹುದು, ಅಥವಾ ದೂರು ನೀಡಬಹುದು.',
      enText: 'Welcome. You can ask me what you need, find your ration shop, track your ration, collect your ration, or report a problem.',
    );
  }

  void repeatLastSpoken() {
    if (_lastHiText.isNotEmpty || _lastKnText.isNotEmpty || _lastEnText.isNotEmpty) {
      speakLocalized(
        hiText: _lastHiText,
        knText: _lastKnText,
        enText: _lastEnText,
      );
    }
  }

  void onLanguageChanged(AppLanguage newLang) {
    if (_isVoiceAssistantMode) {
      switch (newLang) {
        case AppLanguage.hindi:
          speakLocalized(
            hiText: 'भाषा बदलकर हिंदी कर दी गई है।',
            knText: 'ಭಾಷೆಯನ್ನು ಹಿಂದಿಗೆ ಬದಲಾಯಿಸಲಾಗಿದೆ.',
            enText: 'Language changed to Hindi.',
          );
          break;
        case AppLanguage.kannada:
          speakLocalized(
            hiText: 'भाषा बदलकर कन्नड़ कर दी गई है।',
            knText: 'ಭಾಷೆಯನ್ನು ಕನ್ನಡಕ್ಕೆ ಬದಲಾಯಿಸಲಾಗಿದೆ.',
            enText: 'Language changed to Kannada.',
          );
          break;
        case AppLanguage.english:
          speakLocalized(
            hiText: 'भाषा बदलकर अंग्रेज़ी कर दी गई है।',
            knText: 'ಭಾಷೆಯನ್ನು ಇಂಗ್ಲಿಷ್‌ಗೆ ಬದಲಾಯಿಸಲಾಗಿದೆ.',
            enText: 'Language changed to English.',
          );
          break;
      }
    }
  }

  // -------------------------------------------------------------
  // SPEECH RECOGNITION (VOICE INPUT IN ENGLISH, HINDI, KANNADA)
  // -------------------------------------------------------------
  void startListening({
    String? overrideLangCode,
    Function(String transcript)? onFinalResult,
  }) {
    // 1. Stop any currently playing speech so mic does not pick up speaker audio
    stop();

    final lang = LanguageController.instance.currentLanguage;
    String langCode = overrideLangCode ?? (lang == AppLanguage.hindi ? 'hi-IN' : (lang == AppLanguage.kannada ? 'kn-IN' : 'en-IN'));

    _isListening = true;
    _recognizedSpeech = '';
    _speechRecognitionStatus = 'listening';
    notifyListeners();

    platformStartListening(
      langCode: langCode,
      onStatus: (status, detail) {
        _speechRecognitionStatus = status;
        if (status != 'listening') {
          _isListening = false;
        }
        notifyListeners();

        if (status == 'permission_denied') {
          speakLocalized(
            hiText: 'माइक्रोफ़ोन की अनुमति नहीं दी गई। कृपया अनुमति दें या टाइप करें।',
            knText: 'ಮೈಕ್ರೊಫೋನ್ ಅನುಮತಿಯನ್ನು ನಿರಾಕರಿಸಲಾಗಿದೆ. ದಯವಿಟ್ಟು ಅನುಮತಿಸಿ ಅಥವಾ ಟೈಪ್ ಮಾಡಿ.',
            enText: 'Microphone permission denied. Please allow microphone access or tap directly.',
          );
        } else if (status == 'no_speech') {
          speakLocalized(
            hiText: 'आवाज़ सुनाई नहीं दी। दोबारा बोलने के लिए माइक दबाएं।',
            knText: 'ಯಾವುದೇ ಧ್ವನಿ ಕೇಳಿಸಲಿಲ್ಲ. ಮತ್ತೆ ಮಾತನಾಡಲು ಮೈಕ್ ಒತ್ತಿ.',
            enText: 'No speech heard. Please tap the microphone to speak again.',
          );
        }
      },
      onResult: (transcript, isFinal) {
        _recognizedSpeech = transcript;
        notifyListeners();

        if (isFinal && transcript.trim().isNotEmpty) {
          _isListening = false;
          _speechRecognitionStatus = 'idle';
          notifyListeners();

          if (onFinalResult != null) {
            onFinalResult(transcript);
          } else if (onCommandRecognized != null) {
            onCommandRecognized!(transcript);
          } else {
            handleInteractiveCommand(transcript);
          }
        }
      },
    );
  }

  void stopListening() {
    platformStopListening();
    _isListening = false;
    _speechRecognitionStatus = 'idle';
    notifyListeners();
  }

  void clearRecognizedSpeech() {
    _recognizedSpeech = '';
    notifyListeners();
  }

  // -------------------------------------------------------------
  // DIGIT & NUMBER NORMALIZERS (ENGLISH, HINDI, KANNADA)
  // -------------------------------------------------------------
  static String normalizeSpokenDigits(String spokenText) {
    if (spokenText.isEmpty) return '';

    String text = spokenText.toLowerCase();

    // 1. Replace native Kannada numerals (೦-೯) with standard ASCII digits (0-9)
    const knDigits = ['೦', '೧', '೨', '೩', '೪', '೫', '೬', '೭', '೮', '೯'];
    for (int i = 0; i < knDigits.length; i++) {
      text = text.replaceAll(knDigits[i], '$i');
    }

    // 2. Replace native Devanagari numerals (०-९) with standard ASCII digits (0-9)
    const hiDigits = ['०', '१', '२', '३', '४', '५', '६', '७', '८', '९'];
    for (int i = 0; i < hiDigits.length; i++) {
      text = text.replaceAll(hiDigits[i], '$i');
    }

    // 3. Double / Triple multi-digit expansions
    text = text
        .replaceAll('double zero', '00')
        .replaceAll('double 0', '00')
        .replaceAll('triple zero', '000')
        .replaceAll('triple 0', '000')
        .replaceAll('ಡಬಲ್ ಸೊನ್ನೆ', '00')
        .replaceAll('ಡಬಲ್ 0', '00')
        .replaceAll('डबल जीरो', '00')
        .replaceAll('डबल 0', '00');

    // 4. Word-to-digit dictionary across Kannada, Hindi, and English
    final Map<String, String> wordMap = {
      // Kannada spoken digits
      'ಸೊನ್ನೆ': '0', 'ಶೂನ್ಯ': '0', 'ಜೀರೋ': '0',
      'ಒಂದು': '1', 'ಒಂದ': '1', 'ಒನ್': '1',
      'ಎರಡು': '2', 'ಎರಡ': '2', 'ಟೂ': '2',
      'ಮೂರು': '3', 'ಮೂರ': '3', 'ತ್ರೀ': '3',
      'ನಾಲ್ಕು': '4', 'ನಾಲ್ಕ': '4', 'ಫೋರ್': '4',
      'ಐದು': '5', 'ಐದ': '5', 'ಫೈವ್': '5',
      'ಆರು': '6', 'ಆರ': '6', 'ಸಿಕ್ಸ್': '6',
      'ಏಳು': '7', 'ಏಳ': '7', 'ಸೆವೆನ್': '7',
      'ಎಂಟು': '8', 'ಎಂಟ': '8', 'ಏಟ್': '8',
      'ಒಂಬತ್ತು': '9', 'ಒಂಬತ್ತ': '9', 'ನೈನ್': '9',
      'ಹತ್ತು': '10', 'ಟೆನ್': '10',
      'ಇಪ್ಪತ್ತು': '20', 'ಮೂವತ್ತು': '30', 'ನಲವತ್ತು': '40', 'ಐವತ್ತು': '50',
      'ಅರವತ್ತು': '60', 'ಎಪ್ಪತ್ತು': '70', 'ಎಂಬತ್ತು': '80', 'ತೊಂಬತ್ತು': '90',
      'ನೂರು': '100', 'ಸಾವಿರ': '1000',

      // Hindi spoken digits
      'शून्य': '0', 'जीरो': '0', 'सिफर': '0',
      'एक': '1', 'वन': '1',
      'दो': '2', 'टू': '2',
      'तीन': '3', 'थ्री': '3',
      'चार': '4', 'फोर': '4',
      'पांच': '5', 'पाँच': '5', 'फाइव': '5',
      'छह': '6', 'छ': '6', 'छः': '6', 'सिक्स': '6',
      'सात': '7', 'सेवन': '7',
      'आठ': '8', 'एट': '8',
      'नौ': '9', 'नाइन': '9',
      'दस': '10', 'ग्यारह': '11', 'बारह': '12', 'तेरह': '13', 'चौदह': '14',
      'पंद्रह': '15', 'सोलह': '16', 'सत्रह': '17', 'अठारह': '18', 'उन्नीस': '19',
      'बीस': '20', 'तीस': '30', 'चालीस': '40', 'पचास': '50',
      'साठ': '60', 'सत्तर': '70', 'अस्सी': '80', 'नब्बे': '90',
      'सौ': '100', 'हजार': '1000', 'हज़ार': '1000',

      // English spoken digits
      'zero': '0', 'oh': '0',
      'one': '1', 'won': '1',
      'two': '2', 'to': '2', 'too': '2',
      'three': '3', 'tree': '3',
      'four': '4', 'for': '4', 'fore': '4',
      'five': '5',
      'six': '6',
      'seven': '7',
      'eight': '8', 'ate': '8',
      'nine': '9',
      'ten': '10', 'eleven': '11', 'twelve': '12', 'thirteen': '13', 'fourteen': '14',
      'fifteen': '15', 'sixteen': '16', 'seventeen': '17', 'eighteen': '18', 'nineteen': '19',
      'twenty': '20', 'thirty': '30', 'forty': '40', 'fifty': '50',
      'sixty': '60', 'seventy': '70', 'eighty': '80', 'ninety': '90',
      'hundred': '100', 'thousand': '1000',
    };

    for (final entry in wordMap.entries) {
      text = text.replaceAll(RegExp(r'(^|\s+)' + RegExp.escape(entry.key) + r'($|\s+)'), ' ${entry.value} ');
    }

    return text.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static String extractRationId(String spokenText) {
    final clean = normalizeSpokenDigits(spokenText).toUpperCase();
    final digitsOnly = clean.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.isNotEmpty) {
      if (digitsOnly.length >= 6) {
        final idPart = digitsOnly.substring(digitsOnly.length - 6);
        return 'RC-KA-$idPart';
      } else {
        return 'RC-KA-${digitsOnly.padLeft(6, '0')}';
      }
    }
    return clean.replaceAll(' ', '-');
  }

  static double? extractSpokenQuantity(String spokenText) {
    final clean = normalizeSpokenDigits(spokenText).toLowerCase();
    final regex = RegExp(r'(\d+(?:\.\d+)?)\s*(?:kg|kilos?|kilograms?|किलो|ಕೆಜಿ)?');
    final match = regex.firstMatch(clean);
    if (match != null) {
      return double.tryParse(match.group(1)!);
    }
    return null;
  }

  static String extractPhoneNumber(String spokenText) {
    final clean = normalizeSpokenDigits(spokenText).replaceAll(RegExp(r'[^0-9]'), '');
    if (clean.length >= 10) {
      return clean.substring(clean.length - 10);
    }
    return clean;
  }

  /// Extracts combined Ration Card Number and Registered Mobile Number from a single multilingual spoken sentence
  static Map<String, String?> extractLoginCredentials(String spokenText) {
    if (spokenText.trim().isEmpty) {
      return {'card': null, 'phone': null, 'raw': spokenText};
    }

    String lower = spokenText.toLowerCase();

    // 1. Normalize spoken words for dashes, letters, words
    lower = lower
        .replaceAll('dash', '-')
        .replaceAll('hyphen', '-')
        .replaceAll('डैश', '-')
        .replaceAll('ಡ್ಯಾಶ್', '-')
        .replaceAll(RegExp(r'\br\s*c\b'), 'rc')
        .replaceAll(RegExp(r'\bk\s*a\b'), 'ka');

    final normalized = normalizeSpokenDigits(lower);

    String? foundPhone;
    String? foundCard;

    // 2. Extract 10-digit mobile number starting with 6-9
    final digitsOnlyNoSpaces = normalized.replaceAll(RegExp(r'[^0-9]'), '');
    final phoneRegex = RegExp(r'[6-9]\d{9}');
    final phoneMatch = phoneRegex.firstMatch(digitsOnlyNoSpaces);

    if (phoneMatch != null) {
      foundPhone = phoneMatch.group(0);
    }

    // 3. Extract Ration Card Number
    final rcPattern = RegExp(r'(?:RC|BEN)[-\s]?(?:KA)?[-\s]?(\d{4,6})', caseSensitive: false);
    final rcMatch = rcPattern.firstMatch(lower.toUpperCase());

    if (rcMatch != null) {
      final digits = rcMatch.group(1)!;
      final prefix = lower.toUpperCase().contains('BEN') ? 'BEN-KA' : 'RC-KA';
      foundCard = '$prefix-${digits.padLeft(6, '0')}';
    } else {
      // Check remaining digits after removing phone number if present
      if (foundPhone != null) {
        final remaining = digitsOnlyNoSpaces.replaceFirst(foundPhone, '');
        if (remaining.isNotEmpty) {
          if (remaining.length <= 6) {
            foundCard = 'RC-KA-${remaining.padLeft(6, '0')}';
          } else {
            foundCard = 'RC-KA-${remaining.substring(0, 6)}';
          }
        }
      } else {
        if (digitsOnlyNoSpaces.length >= 10) {
          final pPart = digitsOnlyNoSpaces.substring(digitsOnlyNoSpaces.length - 10);
          if (RegExp(r'^[6-9]\d{9}$').hasMatch(pPart)) {
            foundPhone = pPart;
            final cPart = digitsOnlyNoSpaces.substring(0, digitsOnlyNoSpaces.length - 10);
            if (cPart.isNotEmpty) {
              foundCard = 'RC-KA-${cPart.padLeft(6, '0')}';
            }
          }
        } else if (digitsOnlyNoSpaces.length >= 1 && digitsOnlyNoSpaces.length <= 6) {
          foundCard = 'RC-KA-${digitsOnlyNoSpaces.padLeft(6, '0')}';
        }
      }
    }

    return {
      'card': foundCard,
      'phone': foundPhone,
      'raw': spokenText,
    };
  }

  // -------------------------------------------------------------
  // INTERACTIVE VOICE COMMAND PROCESSOR
  // -------------------------------------------------------------
  void handleInteractiveCommand(String rawTranscript) {
    final text = rawTranscript.trim().toLowerCase();
    if (text.isEmpty) return;

    // Check grain: Rice
    if (text.contains('rice') || text.contains('चावल') || text.contains('ಅಕ್ಕಿ') || text.contains('chawal') || text.contains('akki')) {
      guideGrainSelected('RICE_ONLY');
      return;
    }

    // Check grain: Wheat
    if (text.contains('wheat') || text.contains('गेहूं') || text.contains('गेहूँ') || text.contains('ಗೋಧಿ') || text.contains('gehu') || text.contains('godhi')) {
      guideGrainSelected('WHEAT_ONLY');
      return;
    }

    // Check grain: Both
    if (text.contains('both') || text.contains('दोनों') || text.contains('ಎರಡೂ') || text.contains('dono') || text.contains('eradu')) {
      guideGrainSelected('BOTH');
      return;
    }

    // Check Shop / Location
    if (text.contains('shop') || text.contains('दुकान') || text.contains('ಅಂಗಡಿ') || text.contains('store') || text.contains('kendra') || text.contains('location') || text.contains('स्थान') || text.contains('ಸ್ಥಳ')) {
      guideLocation();
      return;
    }

    // Check Track
    if (text.contains('track') || text.contains('ट्रैक') || text.contains('ಟ್ರ್ಯಾಕ್') || text.contains('status') || text.contains('स्थिति') || text.contains('ಸ್ಥಿತಿ')) {
      guideTracking('Request received and ready for allocation');
      return;
    }

    // Check Help / Grievance
    if (text.contains('help') || text.contains('मदद') || text.contains('ಸಹಾಯ') || text.contains('problem') || text.contains('समस्या') || text.contains('ದೂರು') || text.contains('शिकायत')) {
      guideHelp();
      return;
    }

    // Check Confirm / Proceed
    if (text.contains('confirm') || text.contains('पुष्टि') || text.contains('ದೃಢೀಕರಿಸಿ') || text.contains('proceed') || text.contains('आगे') || text.contains('ಮುಂದುವರಿಯಿರಿ')) {
      guideConfirmation();
      return;
    }

    // Ambiguous
    speakLocalized(
      hiText: 'मुझे समझ नहीं आया। कृपया नीचे दिए गए विकल्पों में से चुनें या दोबारा बोलने के लिए माइक दबाएं।',
      knText: 'ನನಗೆ ಅರ್ಥವಾಗಲಿಲ್ಲ. ದಯವಿಟ್ಟು ಕೆಳಗಿನ ಆಯ್ಕೆಗಳಲ್ಲಿ ಒಂದನ್ನು ಆರಿಸಿ ಅಥವಾ ಮತ್ತೆ ಮಾತನಾಡಲು ಮೈಕ್ರೊಫೋನ್ ಒತ್ತಿರಿ.',
      enText: 'I did not understand. Please choose one of the options below or tap the microphone to say it again.',
    );
  }

  // CITIZEN LOGIN GUIDANCE - STEP 1: RATION CARD
  void guideLoginStepRationId() {
    speakLocalized(
      enText: 'I can help you log in. Please enter or tell me your ration card number.',
      hiText: 'मैं लॉगिन करने में आपकी मदद कर सकता हूँ। कृपया अपना राशन कार्ड नंबर दर्ज करें या बोलकर बताएं।',
      knText: 'ನಾನು ಲಾಗಿನ್ ಮಾಡಲು ನಿಮಗೆ ಸಹಾಯ ಮಾಡಬಲ್ಲೆ. ದಯವಿಟ್ಟು ನಿಮ್ಮ ಪಡಿತರ ಚೀಟಿ ಸಂಖ್ಯೆಯನ್ನು ನಮೂದಿಸಿ ಅಥವಾ ಹೇಳಿ.',
    );
  }

  // CITIZEN LOGIN GUIDANCE - STEP 2: PHONE NUMBER
  void guideLoginStepPhone() {
    if (!_isVoiceAssistantMode) return;
    speakLocalized(
      enText: 'Now enter or tell me your registered mobile number.',
      hiText: 'अब अपना पंजीकृत मोबाइल नंबर दर्ज करें या बोलकर बताएं।',
      knText: 'ಈಗ ನಿಮ್ಮ ನೋಂದಾಯಿತ ಮೊಬೈಲ್ ಸಂಖ್ಯೆಯನ್ನು ನಮೂದಿಸಿ ಅಥವಾ ಹೇಳಿ.',
    );
  }

  // CITIZEN LOGIN GUIDANCE - STEP 3: OTP REQUESTED
  void guideLoginStepOtpRequested() {
    if (!_isVoiceAssistantMode) return;
    speakLocalized(
      enText: 'OTP has been requested. Please enter the OTP.',
      hiText: 'ओटीपी भेज दिया गया है। कृपया प्राप्त हुआ ओटीपी दर्ज करें।',
      knText: 'ಒಟಿಪಿಯನ್ನು ವಿನಂತಿಸಲಾಗಿದೆ. ದಯವಿಟ್ಟು ಒಟಿಪಿಯನ್ನು ನಮೂದಿಸಿ.',
    );
  }

  // CITIZEN LOGIN GUIDANCE - STEP 4: OTP ENTERED
  void guideLoginStepOtpEntered() {
    if (!_isVoiceAssistantMode) return;
    speakLocalized(
      enText: 'OTP entered. Tap Verify and Login to proceed.',
      hiText: 'ओटीपी दर्ज हो गया है। आगे बढ़ने के लिए सत्यापन और लॉगिन दबाएं।',
      knText: 'ಒಟಿಪಿ ನಮೂದಿಸಲಾಗಿದೆ. ಮುಂದುವರಿಯಲು ಪರಿಶೀಲಿಸಿ ಮತ್ತು ಲಾಗಿನ್ ಒತ್ತಿರಿ.',
    );
  }

  // GUIDED STEP 1: LOGIN WELCOME & RATION ID
  void guideLoginWelcome() {
    speakLocalized(
      hiText: 'नमस्ते! राशन सेवा में आपका स्वागत है। मैं पूरी प्रक्रिया में आपकी मदद करूंगा। कृपया अपना राशन कार्ड नंबर दर्ज करें या बोलकर बताएं।',
      knText: 'ನಮಸ್ಕಾರ! ಪಡಿತರ ಸೇವೆಗೆ ಸುಸ್ವಾಗತ. ನಾನು ಸಂಪೂರ್ಣ ಪ್ರಕ್ರಿಯೆಯಲ್ಲಿ ನಿಮಗೆ ಮಾರ್ಗದರ್ಶನ ನೀಡುತ್ತೇನೆ. ದಯವಿಟ್ಟು ನಿಮ್ಮ ಪಡಿತರ ಚೀಟಿ ಸಂಖ್ಯೆಯನ್ನು ನಮೂದಿಸಿ ಅಥವಾ ಹೇಳಿ.',
      enText: 'Welcome. I will guide you step by step. First, please enter or say your ration card number.',
    );
  }

  // GUIDED STEP 2: PHONE NUMBER
  void guideLoginPhone() {
    if (!_isVoiceAssistantMode) return;
    speakLocalized(
      hiText: 'कृपया अपना पंजीकृत मोबाइल नंबर दर्ज करें या बोलें, फिर ओटीपी प्राप्त करें बटन दबाएं।',
      knText: 'ದಯವಿಟ್ಟು ನಿಮ್ಮ ನೋಂದಾಯಿತ ಮೊಬೈಲ್ ಸಂಖ್ಯೆಯನ್ನು ನಮೂದಿಸಿ ಅಥವಾ ಹೇಳಿ, ನಂತರ ಒಟಿಪಿ ಪಡೆಯಿರಿ ಬಟನ್ ಒತ್ತಿರಿ.',
      enText: 'Please enter or say your registered phone number, then tap Get OTP Code.',
    );
  }

  // GUIDED STEP 3: OTP CODE SENT
  void guideLoginOtpSent() {
    if (!_isVoiceAssistantMode) return;
    speakLocalized(
      hiText: 'आपके मोबाइल पर सत्यापन कोड भेजा गया है। कोड यहाँ दर्ज करें, फिर लॉगिन करें दबाएं।',
      knText: 'ನಿಮ್ಮ ಮೊಬೈಲ್‌ಗೆ ಪರಿಶೀಲನಾ ಕೋಡ್ ಕಳುಹಿಸಲಾಗಿದೆ. ಕೋಡ್ ಅನ್ನು ಇಲ್ಲಿ ನಮೂದಿಸಿ, ನಂತರ ಲಾಗಿನ್ ಮಾಡಿ ಒತ್ತಿರಿ.',
      enText: 'A verification code has been sent to your phone. Enter the code here, then tap Verify and Login.',
    );
  }

  // GUIDED STEP 4: HOME SCREEN COMPLETE INTRODUCTION (EXPLAINING ALL 4 FEATURES)
  void guideHome() {
    if (!_isVoiceAssistantMode) return;
    guideBeneficiaryPostLoginWelcome();
  }

  // CYCLE ALREADY RECEIVED
  void guideCycleAlreadyReceived() {
    speakLocalized(
      enText: 'Your ration for this cycle has already been received. You cannot select ration again in this cycle.',
      hiText: 'इस चक्र का आपका राशन पहले ही प्राप्त हो चुका है। आप इस चक्र में दोबारा राशन नहीं चुन सकते।',
      knText: 'ಈ ಚಕ್ರದ ನಿಮ್ಮ ಪಡಿತರವನ್ನು ಈಗಾಗಲೇ ಸ್ವೀಕರಿಸಲಾಗಿದೆ. ಈ ಚಕ್ರದಲ್ಲಿ ನೀವು ಮತ್ತೆ ಪಡಿತರವನ್ನು ಆಯ್ಕೆ ಮಾಡಲು ಸಾಧ್ಯವಿಲ್ಲ.',
    );
  }

  // STATUTORY ENTITLEMENT CEILING EXCEEDED
  void guideStatutoryQuantityError() {
    speakLocalized(
      enText: 'The selected ration quantity is more than your allowed monthly entitlement. Please select the permitted quantity.',
      hiText: 'आपके द्वारा चुनी गई राशन की मात्रा आपकी मासिक पात्रता से अधिक है। कृपया अनुमत मात्रा चुनें।',
      knText: 'ನೀವು ಆಯ್ಕೆ ಮಾಡಿದ ಪಡಿತರ ಪ್ರಮಾಣವು ನಿಮ್ಮ ಮಾಸಿಕ ಅರ್ಹತೆಯ ಪ್ರಮಾಣಕ್ಕಿಂತ ಹೆಚ್ಚಾಗಿದೆ. ದಯವಿಟ್ಟು ಅನುಮತಿಸಲಾದ ಪ್ರಮಾಣವನ್ನು ಆಯ್ಕೆಮಾಡಿ.',
    );
  }

  // GUIDED STEP 5: DEMAND / ENTITLEMENT INTRO
  void guideDemandIntro() {
    if (!_isVoiceAssistantMode) return;
    speakLocalized(
      hiText: 'आपके परिवार का राशन हक यहाँ दिखाया गया है। यह सरकारी नियमों के अनुसार निर्धारित है। विवरण देखें और आगे बढ़ें।',
      knText: 'ನಿಮ್ಮ ಕುಟುಂಬದ ಪಡಿತರ ಹಕ್ಕನ್ನು ಇಲ್ಲಿ ತೋರಿಸಲಾಗಿದೆ. ವಿವರಗಳನ್ನು ಪರಿಶೀಲಿಸಿ ಮತ್ತು ಮುಂದುವರಿಯಿರಿ.',
      enText: "Your family's ration entitlement is displayed here. Please review your eligible quantity and proceed.",
    );
  }

  void guideDemandEntitlement({
    required double totalKg,
    required double riceKg,
    required double wheatKg,
    int? membersCount,
  }) {
    if (!_isVoiceAssistantMode) return;
    final riceStr = (riceKg % 1 == 0) ? riceKg.toInt().toString() : riceKg.toStringAsFixed(1);
    final wheatStr = (wheatKg % 1 == 0) ? wheatKg.toInt().toString() : wheatKg.toStringAsFixed(1);

    String enText;
    String hiText;
    String knText;

    if (riceKg > 0 && wheatKg > 0) {
      enText = "Based on your registered family details, your monthly ration entitlement is $riceStr kilograms of rice and $wheatStr kilograms of wheat.";
      hiText = "आपके पंजीकृत परिवार के विवरण के आधार पर, आपका मासिक राशन $riceStr किलोग्राम चावल और $wheatStr किलोग्राम गेहूं है।";
      knText = "ನಿಮ್ಮ ನೋಂದಾಯಿತ ಕುಟುಂಬದ ವಿವರಗಳ ಆಧಾರದ ಮೇಲೆ, ನಿಮ್ಮ ಮಾಸಿಕ ಪಡಿತರ ಹಕ್ಕು $riceStr ಕಿಲೋಗ್ರಾಂ ಅಕ್ಕಿ ಮತ್ತು $wheatStr ಕಿಲೋಗ್ರಾಂ ಗೋಧಿಯಾಗಿದೆ.";
    } else if (riceKg > 0) {
      enText = "Based on your registered family details, your monthly ration entitlement is $riceStr kilograms of rice.";
      hiText = "आपके पंजीकृत परिवार के विवरण के आधार पर, आपका मासिक राशन $riceStr किलोग्राम चावल है।";
      knText = "ನಿಮ್ಮ ನೋಂದಾಯಿತ ಕುಟುಂಬದ ವಿವರಗಳ ಆಧಾರದ ಮೇಲೆ, ನಿಮ್ಮ ಮಾಸಿಕ ಪಡಿತರ ಹಕ್ಕು $riceStr ಕಿಲೋಗ್ರಾಂ ಅಕ್ಕಿಯಾಗಿದೆ.";
    } else {
      enText = "Based on your registered family details, your monthly ration entitlement is $wheatStr kilograms of wheat.";
      hiText = "आपके पंजीकृत परिवार के विवरण के आधार पर, आपका मासिक राशन $wheatStr किलोग्राम गेहूं है।";
      knText = "ನಿಮ್ಮ ನೋಂದಾಯಿತ ಕುಟುಂಬದ ವಿವರಗಳ ಆಧಾರದ ಮೇಲೆ, ನಿಮ್ಮ ಮಾಸಿಕ ಪಡಿತರ ಹಕ್ಕು $wheatStr ಕಿಲೋಗ್ರಾಂ ಗೋಧಿಯಾಗಿದೆ.";
    }

    speakLocalized(
      enText: enText,
      hiText: hiText,
      knText: knText,
    );
  }

  // GUIDED STEP 6: GRAIN SELECTED
  void guideGrainSelected(String option) {
    if (!_isVoiceAssistantMode) return;
    if (option == 'RICE_ONLY' || option == 'RICE') {
      speakLocalized(
        hiText: 'आपने चावल चुना है। अब नीचे दिए गए आगे बढ़ें बटन पर टैप करें।',
        knText: 'ನೀವು ಅಕ್ಕಿಯನ್ನು ಆಯ್ಕೆ ಮಾಡಿದ್ದೀರಿ. ಈಗ ಕೆಳಗಿನ ಮುಂದುವರಿಯಿರಿ ಬಟನ್ ಒತ್ತಿರಿ.',
        enText: 'You selected Rice. Now tap Proceed to Confirmation.',
      );
    } else if (option == 'WHEAT_ONLY' || option == 'WHEAT') {
      speakLocalized(
        hiText: 'आपने गेहूं चुना है। अब नीचे दिए गए आगे बढ़ें बटन पर टैप करें।',
        knText: 'ನೀವು ಗೋಧಿಯನ್ನು ಆಯ್ಕೆ ಮಾಡಿದ್ದೀರಿ. ಈಗ ಕೆಳಗಿನ ಮುಂದುವರಿಯಿರಿ ಬಟನ್ ಒತ್ತಿರಿ.',
        enText: 'You selected Wheat. Now tap Proceed to Confirmation.',
      );
    } else {
      speakLocalized(
        hiText: 'आपने चावल और गेहूं दोनों चुने हैं। अब नीचे दिए गए आगे बढ़ें बटन पर टैप करें।',
        knText: 'ನೀವು ಅಕ್ಕಿ ಮತ್ತು ಗೋಧಿ ಎರಡನ್ನೂ ಆಯ್ಕೆ ಮಾಡಿದ್ದೀರಿ. ಈಗ ಕೆಳಗಿನ ಮುಂದುವರಿಯಿರಿ ಬಟನ್ ಒತ್ತಿರಿ.',
        enText: 'You selected both Rice and Wheat. Now tap Proceed to Confirmation.',
      );
    }
  }

  // GUIDED STEP 7: SHOP SELECTED / LOCATION SECTION
  void guideShopSelected(String shopName) {
    if (!_isVoiceAssistantMode) return;
    speakLocalized(
      hiText: 'यह आपकी चुनी हुई राशन दुकान है: $shopName। आप मानचित्र पर दुकान का स्थान देख सकते हैं।',
      knText: 'ಇದು ನಿಮ್ಮ ಆಯ್ಕೆಮಾಡಿದ ಪಡಿತರ ಅಂಗಡಿ: $shopName. ನೀವು ನಕ್ಷೆಯಲ್ಲಿ ಅಂಗಡಿಯ ಸ್ಥಳವನ್ನು ನೋಡಬಹುದು.',
      enText: 'This is your selected ration shop: $shopName. You can view the shop location on the map.',
    );
  }

  void guideLocation() {
    if (!_isVoiceAssistantMode) return;
    speakLocalized(
      hiText: 'यह अनुभाग आपकी राशन दुकान का स्थान दिखाता है। दुकान कहां है यह देखने के लिए आप मानचित्र का उपयोग कर सकते हैं।',
      knText: 'ಈ ವಿಭಾಗವು ನಿಮ್ಮ ಪಡಿತರ ಅಂಗಡಿಯ ಸ್ಥಳವನ್ನು ತೋರಿಸುತ್ತದೆ. ಅಂಗಡಿ ಎಲ್ಲಿದೆ ಎಂಬುದನ್ನು ನೋಡಲು ನೀವು ನಕ್ಷೆಯನ್ನು ಬಳಸಬಹುದು.',
      enText: 'This section shows your ration shop location. You can use the map to see where the shop is.',
    );
  }

  // GUIDED STEP 8: CONFIRMATION SCREEN
  void guideConfirmation() {
    if (!_isVoiceAssistantMode) return;
    speakLocalized(
      hiText: 'आपका अनुरोध तैयार है। कृपया अपने राशन का विवरण देखें और अपनी रसीद प्राप्त करने के लिए पुष्टि करें बटन दबाएं।',
      knText: 'ನಿಮ್ಮ ವಿನಂತಿ ಸಿದ್ಧವಾಗಿದೆ. ದಯವಿಟ್ಟು ನಿಮ್ಮ ಪಡಿತರ ವಿವರಗಳನ್ನು ಪರಿಶೀಲಿಸಿ ಮತ್ತು ರಸೀದಿ ಪಡೆಯಲು ದೃಢೀಕರಿಸಿ ಬಟನ್ ಒತ್ತಿರಿ.',
      enText: 'Your request is ready. Please review your ration details and tap Confirm to generate your receipt.',
    );
  }

  // GUIDED STEP 9: RECEIPT GENERATED
  void guideReceiptGenerated() {
    if (!_isVoiceAssistantMode) return;
    speakLocalized(
      hiText: 'आपका अनुरोध सफलतापूर्वक दर्ज हो गया है! आपकी रसीद तैयार है। आप इसे अपने रिकॉर्ड के लिए रख सकते हैं।',
      knText: 'ನಿಮ್ಮ ವಿನಂತಿಯನ್ನು ಯಶಸ್ವಿಯಾಗಿ ಉಳಿಸಲಾಗಿದೆ! ನಿಮ್ಮ ರಸೀದಿ ಸಿದ್ಧವಾಗಿದೆ. ನಿಮ್ಮ ದಾಖಲೆಗಾಗಿ ನೀವು ಇದನ್ನು ಇರಿಸಿಕೊಳ್ಳಬಹುದು.',
      enText: 'Your request has been saved and confirmed! Your receipt is ready. You can show or keep this receipt for your records.',
    );
  }

  // GUIDED STEP 10: TRACKING
  void guideTracking(String statusDesc) {
    if (!_isVoiceAssistantMode) return;
    speakLocalized(
      hiText: 'यहाँ आप अपने राशन की वर्तमान स्थिति देख सकते हैं। आपका कोटा सिस्टम द्वारा प्राप्त कर लिया गया है। स्थिति: $statusDesc।',
      knText: 'ಇಲ್ಲಿ ನೀವು ನಿಮ್ಮ ಪಡಿತರದ ಪ್ರಸ್ತುತ ಸ್ಥಿತಿಯನ್ನು ನೋಡಬಹುದು. ನಿಮ್ಮ ಕೋಟಾವನ್ನು ವ್ಯವಸ್ಥೆಯು ಸ್ವೀಕರಿಸಿದೆ. ಸ್ಥಿತಿ: $statusDesc.',
      enText: 'Here you can see the current status of your ration. Your allocation has been received. Status: $statusDesc.',
    );
  }

  // GUIDED STEP 11: HELP / GRIEVANCE
  void guideHelp() {
    if (!_isVoiceAssistantMode) return;
    speakLocalized(
      hiText: 'यदि अनाज की मात्रा, दुकान बंद होने या गुणवत्ता में कोई समस्या है, तो नीचे से समस्या चुनें और जमा करें दबाएं। हम आपकी सहायता करेंगे।',
      knText: 'ಧಾನ್ಯದ ಪ್ರಮಾಣ, ಅಂಗಡಿ ಮುಚ್ಚುವಿಕೆ ಅಥವಾ ಗುಣಮಟ್ಟದಲ್ಲಿ ಯಾವುದೇ ಸಮಸ್ಯೆ ಇದ್ದರೆ, ಕೆಳಗೆ ಸಮಸ್ಯೆಯನ್ನು ಆರಿಸಿ ಮತ್ತು ಸಲ್ಲಿಸಿ ಒತ್ತಿರಿ. ನಾವು ನಿಮಗೆ ಸಹಾಯ ಮಾಡುತ್ತೇವೆ.',
      enText: 'If you have a problem with grain quantity, shop closure, or quality, choose the problem below and tap submit. We are here to help.',
    );
  }

  void guideFeedbackSubmitted() {
    if (!_isVoiceAssistantMode) return;
    speakLocalized(
      hiText: 'आपकी शिकायत सफलतापूर्वक दर्ज कर ली गई है। विभाग ने इसे रिकॉर्ड कर लिया है।',
      knText: 'ನಿಮ್ಮ ದೂರನ್ನು ಯಶಸ್ವಿಯಾಗಿ ಸಲ್ಲಿಸಲಾಗಿದೆ. ಇಲಾಖೆಯು ನಿಮ್ಮ ದೂರನ್ನು ದಾಖಲಿಸಿದೆ.',
      enText: 'Your feedback has been submitted. The department has recorded your complaint.',
    );
  }

  // SMART GRAIN ATM GUIDANCE
  void guideAtmWelcome() {
    if (!_isVoiceAssistantMode) return;
    speakLocalized(
      hiText: 'राशन वेंडिंग मशीन में आपका स्वागत है। मैं आपको सत्यापन, राशन की उपलब्धता और राशन लेने की पूरी प्रक्रिया में मार्गदर्शन करूंगा।',
      knText: 'ರೇಷನ್ ವೆಂಡಿಂಗ್ ಮೆಷಿನ್‌ಗೆ ಸ್ವಾಗತ. ಪರಿಶೀಲನೆ, ಪಡಿತರ ಲಭ್ಯತೆ ಮತ್ತು ಪಡಿತರ ಪಡೆಯುವ ಸಂಪೂರ್ಣ ಪ್ರಕ್ರಿಯೆಯಲ್ಲಿ ನಾನು ನಿಮಗೆ ಮಾರ್ಗದರ್ಶನ ನೀಡುತ್ತೇನೆ.',
      enText: 'Welcome to the Ration Vending Machine. I will guide you through verification, ration availability, and collection.',
    );
  }

  void guideAtmVerification() {
    if (!_isVoiceAssistantMode) return;
    speakLocalized(
      hiText: 'कृपया अपनी सत्यापन विधि चुनें: राशन कार्ड संख्या, आधार डेमो सत्यापन, या मोबाइल ओटीपी।',
      knText: 'ದಯವಿಟ್ಟು ಪರಿಶೀಲನಾ ವಿಧಾನವನ್ನು ಆಯ್ಕೆಮಾಡಿ: ಪಡಿತರ ಚೀಟಿ ಸಂಖ್ಯೆ, ಆಧಾರ್ ಡೆಮೊ ಪರಿಶೀಲನೆ ಅಥವಾ ಮೊಬೈಲ್ ಒಟಿಪಿ.',
      enText: 'Please choose your verification method: Ration Card ID, Demo Aadhaar verification, or mobile OTP.',
    );
  }

  void guideAtmAuthSuccess() {
    if (!_isVoiceAssistantMode) return;
    speakLocalized(
      hiText: 'आपकी पहचान सत्यापित हो गई है।',
      knText: 'ನಿಮ್ಮ ಗುರುತನ್ನು ಯಶಸ್ವಿಯಾಗಿ ಪರಿಶೀಲಿಸಲಾಗಿದೆ.',
      enText: 'Your identity has been verified.',
    );
  }

  void guideAtmEntitlement(double riceKg, double wheatKg) {
    if (!_isVoiceAssistantMode) return;
    speakLocalized(
      hiText: 'आपकी राशन पात्रता की पुष्टि हो गई है: ${riceKg.toStringAsFixed(0)} किलो चावल। पूरी तरह मुफ्त। राशन लेने के लिए बटन दबाएं।',
      knText: 'ನಿಮ್ಮ ಪಡಿತರ ಹಕ್ಕನ್ನು ದೃಢೀಕರಿಸಲಾಗಿದೆ: ${riceKg.toStringAsFixed(0)} ಕೆಜಿ ಅಕ್ಕಿ. ಸಂಪೂರ್ಣ ಉಚಿತ. ಪಡಿತರ ಪಡೆಯಲು ಬಟನ್ ಒತ್ತಿ.',
      enText: 'Your ration entitlement has been confirmed: ${riceKg.toStringAsFixed(0)} kilograms of rice. 100 percent free. Tap collect to proceed.',
    );
  }

  void guideAtmDispensing() {
    if (!_isVoiceAssistantMode) return;
    speakLocalized(
      hiText: 'आपका राशन अब निकाला जा रहा है। कृपया मशीन के पास प्रतीक्षा करें।',
      knText: 'ನಿಮ್ಮ ಪಡಿತರವನ್ನು ಈಗ ವಿತರಿಸಲಾಗುತ್ತಿದೆ. ದಯವಿಟ್ಟು ಯಂತ್ರದ ಬಳಿ ನಿರೀಕ್ಷಿಸಿ.',
      enText: 'Your ration is now being dispensed. Please stand by.',
    );
  }

  void guideAtmDispensed() {
    if (!_isVoiceAssistantMode) return;
    speakLocalized(
      hiText: 'आपका राशन सफलतापूर्वक प्राप्त हो गया है।',
      knText: 'ನಿಮ್ಮ ಪಡಿತರವನ್ನು ಯಶಸ್ವಿಯಾಗಿ ಸಂಗ್ರಹಿಸಲಾಗಿದೆ.',
      enText: 'Your ration has been successfully collected.',
    );
  }

  void guideAtmAlreadyReceived() {
    if (!_isVoiceAssistantMode) return;
    speakLocalized(
      hiText: 'इस चक्र का आपका राशन पहले ही प्राप्त हो चुका है। आप इस चक्र में दोबारा राशन नहीं ले सकते।',
      knText: 'ಈ ಚಕ್ರದ ನಿಮ್ಮ ಪಡಿತರವನ್ನು ಈಗಾಗಲೇ ಸ್ವೀಕರಿಸಲಾಗಿದೆ. ಈ ಚಕ್ರದಲ್ಲಿ ನೀವು ಮತ್ತೆ ಪಡಿತರವನ್ನು ಪಡೆಯಲು ಸಾಧ್ಯವಿಲ್ಲ.',
      enText: 'Your ration for this cycle has already been received. You cannot collect ration again in this cycle.',
    );
  }

  void guideAtmStockShortage() {
    if (!_isVoiceAssistantMode) return;
    speakLocalized(
      hiText: 'आवश्यक राशन वर्तमान में इस पिकअप पॉइंट पर उपलब्ध नहीं है।',
      knText: 'ಅಗತ್ಯವಿರುವ ಪಡಿತರವು ಪ್ರಸ್ತುತ ಈ ಪಿಕಪ್ ಕೇಂದ್ರದಲ್ಲಿ ಲಭ್ಯವಿಲ್ಲ.',
      enText: 'The required ration is currently not available at this pickup point.',
    );
  }

  void guideAtmAuthFailed() {
    if (!_isVoiceAssistantMode) return;
    speakLocalized(
      hiText: 'क्षमा करें, हम आपके विवरण का सत्यापन नहीं कर सके। कृपया पुनः प्रयास करें।',
      knText: 'ಕ್ಷಮಿಸಿ, ನಿಮ್ಮ ವಿವರಗಳನ್ನು ಪರಿಶೀಲಿಸಲು ಸಾಧ್ಯವಾಗಲಿಲ್ಲ. ದಯವಿಟ್ಟು ಮತ್ತೆ ಪ್ರಯತ್ನಿಸಿ.',
      enText: 'Sorry, we could not verify your details. Please try again.',
    );
  }

  void setElderlyMode(bool value) {
    if (_isElderlyMode != value) {
      _isElderlyMode = value;
      notifyListeners();
      if (_isElderlyMode) {
        speakLocalized(
          hiText: 'बुजुर्ग मोड चालू हो गया है। बड़े बटन और स्पष्ट आवाज़ सक्रिय हैं।',
          knText: 'ಹಿರಿಯರ ಮೋಡ್ ಸಕ್ರಿಯಗೊಳಿಸಲಾಗಿದೆ. ದೊಡ್ಡ ಬಟನ್‌ಗಳು ಮತ್ತು ಸ್ಪಷ್ಟ ಧ್ವನಿ ಲಭ್ಯವಿದೆ.',
          enText: 'Elderly Mode is turned on. Extra large buttons and clear voice are active.',
        );
      }
    }
  }

  void toggleElderlyMode() {
    _isElderlyMode = !_isElderlyMode;
    notifyListeners();
    if (_isElderlyMode) {
      speakLocalized(
        hiText: 'बुजुर्ग मोड चालू हो गया है। बड़े बटन और स्पष्ट आवाज़ सक्रिय हैं।',
        knText: 'ಹಿರಿಯರ ಮೋಡ್ ಸಕ್ರಿಯಗೊಳಿಸಲಾಗಿದೆ. ದೊಡ್ಡ ಬಟನ್‌ಗಳು ಮತ್ತು ಸ್ಪಷ್ಟ ಧ್ವನಿ ಲಭ್ಯವಿದೆ.',
        enText: 'Elderly Mode is turned on. Extra large buttons and clear voice are active.',
      );
    }
  }

  void toggleAudioAssistance() {
    _audioAssistanceEnabled = !_audioAssistanceEnabled;
    notifyListeners();
    if (!_audioAssistanceEnabled) {
      stop();
    }
  }

  /// Speak localized text according to active LanguageController language
  void speakLocalized({
    required String hiText,
    required String knText,
    required String enText,
  }) {
    if (!_audioAssistanceEnabled) return;

    _lastHiText = hiText;
    _lastKnText = knText;
    _lastEnText = enText;

    final lang = LanguageController.instance.currentLanguage;
    String textToSpeak;
    String bcpCode;

    switch (lang) {
      case AppLanguage.hindi:
        textToSpeak = hiText;
        bcpCode = 'hi-IN';
        break;
      case AppLanguage.kannada:
        textToSpeak = knText;
        bcpCode = 'kn-IN';
        break;
      case AppLanguage.english:
        textToSpeak = enText;
        bcpCode = 'en-IN';
        break;
    }

    speak(textToSpeak, langCode: bcpCode);
  }

  /// Play speech for provided text
  void speak(String text, {String langCode = 'hi-IN'}) {
    if (!_audioAssistanceEnabled || text.trim().isEmpty) return;

    _speakDebounce?.cancel();
    _isSpeaking = true;
    notifyListeners();

    platformSpeak(text, langCode);

    final estimatedSeconds = (text.length / 14).clamp(2.0, 14.0);
    _speakDebounce = Timer(Duration(seconds: estimatedSeconds.toInt()), () {
      _isSpeaking = false;
      notifyListeners();
    });
  }

  void stop() {
    _speakDebounce?.cancel();
    platformStop();
    _isSpeaking = false;
    notifyListeners();
  }

  /// Interactive Voice Assistant Dialog with large microphone and one-tap voice commands
  void showVoiceAssistantDialog(
    BuildContext context, {
    required Function(String intentOrAction) onCommand,
  }) {
    final lang = LanguageController.instance.currentLanguage;

    String prompt;
    String langCode;
    switch (lang) {
      case AppLanguage.hindi:
        prompt = 'आप क्या चुनना चाहते हैं? बोलें या नीचे दिए विकल्प पर टैप करें।';
        langCode = 'hi-IN';
        break;
      case AppLanguage.kannada:
        prompt = 'ನೀವು ಏನು ಆಯ್ಕೆ ಮಾಡಲು ಬಯಸುತ್ತೀರಿ? ಮಾತನಾಡಿ ಅಥವಾ ಕೆಳಗಿನ ಆಯ್ಕೆಯನ್ನು ಒತ್ತಿರಿ.';
        langCode = 'kn-IN';
        break;
      case AppLanguage.english:
        prompt = 'What would you like to do? Speak or tap an option below.';
        langCode = 'en-IN';
        break;
    }

    speak(prompt, langCode: langCode);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return _VoiceListeningSheet(
          promptText: prompt,
          langCode: langCode,
          onCommandSelected: (cmd) {
            Navigator.pop(ctx);
            onCommand(cmd);
          },
        );
      },
    );
  }
}

class _VoiceListeningSheet extends StatefulWidget {
  final String promptText;
  final String langCode;
  final Function(String cmd) onCommandSelected;

  const _VoiceListeningSheet({
    required this.promptText,
    required this.langCode,
    required this.onCommandSelected,
  });

  @override
  State<_VoiceListeningSheet> createState() => _VoiceListeningSheetState();
}

class _VoiceListeningSheetState extends State<_VoiceListeningSheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.92, end: 1.12).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = LanguageController.instance.currentLanguage;
    final isHindi = lang == AppLanguage.hindi;
    final isKannada = lang == AppLanguage.kannada;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 20,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.record_voice_over_rounded, color: Color(0xFF15803D), size: 24),
              const SizedBox(width: 8),
              Text(
                isHindi
                    ? 'आवाज़ सहायक (बोलकर बताएं)'
                    : isKannada
                        ? 'ಧ್ವನಿ ಸಹಾಯಕ (ಮಾತನಾಡಿ)'
                        : 'Voice Assistant (Speak or Tap)',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F2942),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Center(
            child: ScaleTransition(
              scale: _pulseAnimation,
              child: Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF15803D), Color(0xFF16A34A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF15803D).withValues(alpha: 0.35),
                      blurRadius: 18,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: const Icon(Icons.mic_rounded, color: Colors.white, size: 38),
              ),
            ),
          ),
          const SizedBox(height: 14),

          Text(
            widget.promptText,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF334155),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),

          Text(
            isHindi
                ? 'या सीधे नीचे दबाएं:'
                : isKannada
                    ? 'ಅಥವಾ ನೇರವಾಗಿ ಆಯ್ಕೆಮಾಡಿ:'
                    : 'Or tap directly:',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 12),

          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: [
              _buildVoiceChip(
                icon: Icons.grain_rounded,
                label: isHindi ? '🌾 चावल चाहिए' : isKannada ? '🌾 ಅಕ್ಕಿ ಬೇಕು' : '🌾 Rice Only',
                onTap: () {
                  VoiceAssistantService.instance.speak(
                    isHindi ? 'चावल चुना गया' : isKannada ? 'ಅಕ್ಕಿ ಆಯ್ಕೆ ಮಾಡಲಾಗಿದೆ' : 'Rice selected',
                  );
                  widget.onCommandSelected('RICE');
                },
              ),
              _buildVoiceChip(
                icon: Icons.grass_rounded,
                label: isHindi ? '🌾 गेहूं चाहिए' : isKannada ? '🌾 ಗೋಧಿ ಬೇಕು' : '🌾 Wheat Only',
                onTap: () {
                  VoiceAssistantService.instance.speak(
                    isHindi ? 'गेहूं चुना गया' : isKannada ? 'ಗೋಧಿ ಆಯ್ಕೆ ಮಾಡಲಾಗಿದೆ' : 'Wheat selected',
                  );
                  widget.onCommandSelected('WHEAT');
                },
              ),
              _buildVoiceChip(
                icon: Icons.all_inclusive_rounded,
                label: isHindi ? '🌾 चावल + गेहूं दोनों' : isKannada ? '🌾 ಅಕ್ಕಿ ಮತ್ತು ಗೋಧಿ' : '🌾 Both Rice & Wheat',
                color: const Color(0xFF15803D),
                textColor: Colors.white,
                onTap: () {
                  VoiceAssistantService.instance.speak(
                    isHindi ? 'चावल और गेहूं दोनों चुने गए' : isKannada ? 'ಎರಡೂ ಆಯ್ಕೆ ಮಾಡಲಾಗಿದೆ' : 'Both selected',
                  );
                  widget.onCommandSelected('BOTH');
                },
              ),
              _buildVoiceChip(
                icon: Icons.storefront_rounded,
                label: isHindi ? '🏪 मेरी राशन दुकान' : isKannada ? '🏪 ನನ್ನ ಪಡಿತರ ಅಂಗಡಿ' : '🏪 My Ration Shop',
                onTap: () => widget.onCommandSelected('SHOP'),
              ),
              _buildVoiceChip(
                icon: Icons.local_shipping_rounded,
                label: isHindi ? '🚚 राशन कहां पहुंचा?' : isKannada ? '🚚 ಪಡಿತರ ಸ್ಥಿತಿ' : '🚚 Ration Status',
                onTap: () => widget.onCommandSelected('STATUS'),
              ),
              _buildVoiceChip(
                icon: Icons.help_outline_rounded,
                label: isHindi ? '🆘 समस्या दर्ज करें' : isKannada ? '🆘 ದೂರು ದಾಖಲಿಸಿ' : '🆘 Report Problem',
                color: const Color(0xFFDC2626),
                textColor: Colors.white,
                onTap: () => widget.onCommandSelected('HELP'),
              ),
            ],
          ),
          const SizedBox(height: 20),

          OutlinedButton(
            onPressed: () {
              VoiceAssistantService.instance.stop();
              Navigator.pop(context);
            },
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              isHindi ? 'बंद करें' : isKannada ? 'ಮುಚ್ಚಿ' : 'Close',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVoiceChip({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
    Color? textColor,
  }) {
    final bg = color ?? const Color(0xFFF1F5F9);
    final fg = textColor ?? const Color(0xFF0F2942);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color != null ? bg : const Color(0xFFCBD5E1), width: 1.2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: fg),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: fg,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Persistent banner displayed across all beneficiary screens whenever Voice Assistant mode is active.
/// Provides spoken text feedback, large microphone input button, recognized speech preview, and repeat button.
class VoiceAssistantBanner extends StatelessWidget {
  final bool showTapToSpeak;

  const VoiceAssistantBanner({super.key, this.showTapToSpeak = true});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        VoiceAssistantService.instance,
        LanguageController.instance,
      ]),
      builder: (context, _) {
        final service = VoiceAssistantService.instance;
        if (!service.isVoiceAssistantMode) {
          return const SizedBox.shrink();
        }

        final isHindi = service.isHindi;
        final isKannada = service.isKannada;
        final currentText = service.currentSpokenText;
        final isListening = service.isListening;

        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isListening ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
              width: isListening ? 2.4 : 1.8,
            ),
            boxShadow: [
              BoxShadow(
                color: (isListening ? const Color(0xFFDC2626) : const Color(0xFF16A34A)).withValues(alpha: 0.15),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Row: Status, Current instruction, Repeat button, Exit button
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: isListening ? const Color(0xFFFEE2E2) : const Color(0xFFDCFCE7),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isListening ? Icons.mic_rounded : Icons.record_voice_over_rounded,
                      color: isListening ? const Color(0xFFDC2626) : const Color(0xFF15803D),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                isListening
                                    ? (isHindi ? '🔴 सुन रहे हैं... (बोलें)' : isKannada ? '🔴 ಆಲಿಸಲಾಗುತ್ತಿದೆ... (ಮಾತನಾಡಿ)' : '🔴 Listening... (Speak now)')
                                    : (isHindi ? '🎙️ आवाज़ सहायक (सक्रिय)' : isKannada ? '🎙️ ಧ್ವನಿ ಸಹಾಯಕ (ಸಕ್ರಿಯ)' : '🎙️ Voice Assistant (Active)'),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: isListening ? const Color(0xFFDC2626) : const Color(0xFF15803D),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (service.isSpeaking) ...[
                              const SizedBox(width: 8),
                              const SizedBox(
                                width: 10,
                                height: 10,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFF15803D),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          currentText.isNotEmpty
                              ? currentText
                              : (isHindi
                                  ? 'कृपया निर्देशों का पालन करें'
                                  : isKannada
                                      ? 'ದಯವಿಟ್ಟು ಸೂಚನೆಗಳನ್ನು ಅನುಸರಿಸಿ'
                                      : 'Please follow the instructions'),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F2942),
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Repeat Button
                  IconButton(
                    tooltip: isHindi ? 'दोबारा सुनें' : isKannada ? 'ಪುನರಾವರ್ತಿಸಿ' : 'Repeat',
                    icon: const Icon(Icons.volume_up_rounded, color: Color(0xFF15803D), size: 24),
                    onPressed: () => service.repeatLastSpoken(),
                  ),
                  // Close Voice Assistant Button
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 22, color: Color(0xFF94A3B8)),
                    tooltip: isHindi ? 'आवाज़ बंद करें' : isKannada ? 'ಧ್ವನಿ ನಿಲ್ಲಿಸಿ' : 'Turn off Voice',
                    onPressed: () => service.stopVoiceAssistantMode(),
                  ),
                ],
              ),

              // Live Spoken Text Recognition Feedback Box
              if (service.recognizedSpeech.isNotEmpty || isListening) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.hearing_rounded,
                        size: 16,
                        color: isListening ? const Color(0xFFDC2626) : const Color(0xFF2563EB),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          service.recognizedSpeech.isNotEmpty
                              ? (isHindi
                                  ? 'आपने कहा: "${service.recognizedSpeech}"'
                                  : isKannada
                                      ? 'ನೀವು ಹೇಳಿದ್ದು: "${service.recognizedSpeech}"'
                                      : 'You said: "${service.recognizedSpeech}"')
                              : (isHindi
                                  ? 'कृपया बोलें... सुन रहे हैं'
                                  : isKannada
                                      ? 'ದಯವಿಟ್ಟು ಮಾತನಾಡಿ... ಆಲಿಸಲಾಗುತ್ತಿದೆ'
                                      : 'Please speak... Listening now'),
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Large Touch-Friendly Microphone Action Button (Tap to Speak)
              if (showTapToSpeak) ...[
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () {
                    if (isListening) {
                      service.stopListening();
                    } else {
                      service.startListening();
                    }
                  },
                  icon: Icon(
                    isListening ? Icons.stop_circle_rounded : Icons.mic_rounded,
                    size: 24,
                  ),
                  label: Text(
                    isListening
                        ? (isHindi ? 'सुनना बंद करें ⏹️' : isKannada ? 'ನಿಲ್ಲಿಸಿ ⏹️' : 'Stop Listening ⏹️')
                        : (isHindi ? 'बोलने के लिए यहाँ दबाएं 🎙️' : isKannada ? 'ಮಾತನಾಡಲು ಇಲ್ಲಿ ಒತ್ತಿ 🎙️' : 'Tap to Speak 🎙️'),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isListening ? const Color(0xFFDC2626) : const Color(0xFF15803D),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 1,
                  ),
                ),
              ],

              // Status messages for no_speech / permission_denied / unsupported
              if (service.speechRecognitionStatus == 'no_speech') ...[
                const SizedBox(height: 6),
                Text(
                  isHindi
                      ? 'आवाज़ सुनाई नहीं दी। कृपया दोबारा माइक दबाकर बोलें।'
                      : isKannada
                          ? 'ಧ್ವನಿ ಕೇಳಿಸಲಿಲ್ಲ. ದಯವಿಟ್ಟು ಮತ್ತೆ ಮೈಕ್ ಒತ್ತಿ ಮಾತನಾಡಿ.'
                          : 'No speech detected. Please tap microphone to speak again.',
                  style: const TextStyle(fontSize: 11.5, color: Color(0xFFB45309), fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                ),
              ] else if (service.speechRecognitionStatus == 'permission_denied') ...[
                const SizedBox(height: 6),
                Text(
                  isHindi
                      ? 'माइक्रोफ़ोन की अनुमति नहीं है। कृपया अनुमति दें या टाइप करें।'
                      : isKannada
                          ? 'ಮೈಕ್ರೊಫೋನ್ ಅನುಮತಿಯನ್ನು ನಿರಾಕರಿಸಲಾಗಿದೆ. ದಯವಿಟ್ಟು ಟೈಪ್ ಮಾಡಿ.'
                          : 'Microphone permission denied. Please allow access or tap buttons directly.',
                  style: const TextStyle(fontSize: 11.5, color: Color(0xFFDC2626), fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                ),
              ] else if (service.speechRecognitionStatus == 'unsupported') ...[
                const SizedBox(height: 6),
                Text(
                  isHindi
                      ? 'इस ब्राउज़र में आवाज़ पहचान उपलब्ध नहीं है। कृपया सीधे विकल्पों पर टैप करें।'
                      : isKannada
                          ? 'ಈ ಬ್ರೌಸರ್‌ನಲ್ಲಿ ಧ್ವನಿ ಇನ್‌ಪುಟ್ ಲಭ್ಯವಿಲ್ಲ. ದಯವಿಟ್ಟು ನೇರವಾಗಿ ಆಯ್ಕೆಗಳನ್ನು ಒತ್ತಿರಿ.'
                          : 'Voice recognition is unavailable in this browser. Please tap options directly.',
                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
