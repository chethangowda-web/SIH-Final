import 'dart:async';
import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../core/localization.dart';

class VoicePictorialAssistButton extends StatelessWidget {
  final VoidCallback onTap;
  final bool isCompact;

  const VoicePictorialAssistButton({
    super.key,
    required this.onTap,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isCompact) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        child: ElevatedButton.icon(
          onPressed: onTap,
          icon: const Icon(Icons.mic, color: Colors.amberAccent, size: 18),
          label: const Text(
            '🎙️ Voice Assist',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF006644), // Emerald Gov Green
            foregroundColor: Colors.white,
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: Colors.amber, width: 1.5),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
          ),
        ),
      );
    }

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Colors.amber, width: 2),
      ),
      color: const Color(0xFF0F382C), // Deep Emerald Dark Navy
      child: InkWell(
        onPressed: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  color: Colors.amber,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.record_voice_over, color: Color(0xFF0F382C), size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.amber,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'NEW / नया / ಹೊಸ',
                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.black, color: Colors.black),
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Expanded(
                          child: Text(
                            'Voice & Picture Mode',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'आवाज़ और चित्रों से आसान प्रयोग • ಧ್ವನಿ ಮತ್ತು ಚಿತ್ರ ಸಹಾಯ',
                      style: TextStyle(fontSize: 11, color: Colors.white70),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.amber.shade400,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.touch_app, size: 14, color: Colors.black87),
                    SizedBox(width: 4),
                    Text(
                      'Tap Mic / दबाएं',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.black87),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class VoicePictorialAssistModal extends StatefulWidget {
  final Function(String mode, double riceKg, double wheatKg)? onApplyVoiceIntent;

  const VoicePictorialAssistModal({
    super.key,
    this.onApplyVoiceIntent,
  });

  static Future<void> show(
    BuildContext context, {
    Function(String mode, double riceKg, double wheatKg)? onApplyVoiceIntent,
  }) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => VoicePictorialAssistModal(
        onApplyVoiceIntent: onApplyVoiceIntent,
      ),
    );
  }

  @override
  State<VoicePictorialAssistModal> createState() => _VoicePictorialAssistModalState();
}

class _VoicePictorialAssistModalState extends State<VoicePictorialAssistModal> {
  bool _isListening = false;
  bool _isSpeaking = false;
  String _activeLanguage = 'HI'; // HI, KN, EN
  String _speechTranscript = 'माइक बटन दबाकर बोलें (उदा: "5 किलो चावल चाहिए")';
  String _audioFeedback = '';
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _toggleListening() {
    if (_isListening) {
      _timer?.cancel();
      setState(() {
        _isListening = false;
      });
      return;
    }

    setState(() {
      _isListening = true;
      _speechTranscript = _activeLanguage == 'HI'
          ? 'सुन रहा हूँ... बोलिए ("5 किलो चावल राशन चाहिए")'
          : (_activeLanguage == 'KN'
              ? 'ಕೇಳುತ್ತಿದ್ದೇನೆ... ಮಾತನಾಡಿ ("5 ಕೆಜಿ ಅಕ್ಕಿ ಬೇಕು")'
              : 'Listening... Speak ("I need 5kg Rice ration")');
    });

    _timer?.cancel();
    _timer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _isListening = false;
          if (_activeLanguage == 'HI') {
            _speechTranscript = '✔ पहचाना गया: "मल्लेश्वरम दुकान से 20 किलो चावल और 5 किलो गेहूं"';
            _audioFeedback = '🔊 आपकी राशन मांग चुन ली गई है। नीचे हरा बटन दबाकर पक्का करें।';
          } else if (_activeLanguage == 'KN') {
            _speechTranscript = '✔ ಗುರುತಿಸಲಾಗಿದೆ: "ಮಲ್ಲೇಶ್ವರಂ ಅಂಗಡಿಯಿಂದ 20 ಕೆಜಿ ಅಕ್ಕಿ ಮತ್ತು 5 ಕೆಜಿ ಗೋಧಿ"';
            _audioFeedback = '🔊 ನಿಮ್ಮ ರೇಷನ್ ಬೇಡಿಕೆಯನ್ನು ಆರಿಸಲಾಗಿದೆ. ಕೆಳಗಿನ ಹಸಿರು ಬಟನ್ ಒತ್ತಿ.';
          } else {
            _speechTranscript = '✔ Recognized: "20kg Rice and 5kg Wheat from Malleshwaram FPS"';
            _audioFeedback = '🔊 Ration requirement captured. Tap the green confirmation button below.';
          }
        });
      }
    });
  }

  void _speakText(String text) {
    setState(() {
      _isSpeaking = true;
      _audioFeedback = '🔊 $text';
    });
    _timer?.cancel();
    _timer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() {
          _isSpeaking = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: Color(0xFF101827), // Modern High-Contrast Midnight
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: const BoxDecoration(
              color: Color(0xFF1E293B),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Row(
              children: [
                const Icon(Icons.record_voice_over, color: Colors.amber, size: 28),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Voice & Picture Mode',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      Text(
                        'आवाज़ और चित्र सहायक • ಧ್ವನಿ ಮತ್ತು ಚಿತ್ರ ಸಹಾಯ',
                        style: TextStyle(fontSize: 12, color: Colors.amberAccent),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Language Selector Bar
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.amber.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildLangChip('HI', '🇮🇳 हिंदी (Hindi)'),
                        _buildLangChip('KN', '🌾 ಕನ್ನಡ (Kannada)'),
                        _buildLangChip('EN', '🇬🇧 English'),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Big Mic Voice Command Button
                  GestureDetector(
                    onTap: _toggleListening,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: _isListening
                              ? [Colors.red.shade700, Colors.orange.shade700]
                              : [const Color(0xFF006644), const Color(0xFF008855)],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: (_isListening ? Colors.red : Colors.green).withOpacity(0.4),
                            blurRadius: 16,
                            spreadRadius: 2,
                          )
                        ],
                        border: Border.all(color: Colors.amber, width: 2),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            _isListening ? Icons.graphic_eq : Icons.mic,
                            size: 48,
                            color: Colors.white,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _isListening
                                ? (_activeLanguage == 'HI'
                                    ? 'सुन रहे हैं... बोलें!'
                                    : (_activeLanguage == 'KN' ? 'ಕೇಳುತ್ತಿದ್ದೇವೆ... ಮಾತನಾಡಿ!' : 'Listening... Speak now!'))
                                : (_activeLanguage == 'HI'
                                    ? '🎙️ यहाँ दबाकर बोलें (Tap & Speak)'
                                    : (_activeLanguage == 'KN' ? '🎙️ ಇಲ್ಲೊತ್ತಿ ಮಾತನಾಡಿ (Tap & Speak)' : '🎙️ Tap Here & Speak')),
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _speechTranscript,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 13, color: Colors.amberAccent, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),

                  if (_audioFeedback.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade900.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.amber),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.volume_up, color: Colors.amber),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _audioFeedback,
                              style: const TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),

                  // Section Title: Pictorial Quick Actions
                  Row(
                    children: [
                      const Icon(Icons.grid_view_rounded, color: Colors.amber, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        _activeLanguage == 'HI'
                            ? 'चित्रों पर छूकर चुनें (Touch Pictures)'
                            : (_activeLanguage == 'KN' ? 'ಚಿತ್ರಗಳ ಮೇಲೆ ಸ್ಪರ್ಶಿಸಿ (Touch Pictures)' : 'Visual Quick Actions'),
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Pictorial Grid Cards
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.15,
                    children: [
                      // Card 1: 🍚 Rice & Wheat Quota
                      _buildPictorialCard(
                        icon: '🍚 🌾',
                        bgGradient: [const Color(0xFF1E3A8A), const Color(0xFF3B82F6)],
                        titleHi: 'मेरा राशन कोटा',
                        titleKn: 'ನನ್ನ ರೇಷನ್ ಕೋಟ',
                        subTitleHi: '20kg चावल + 5kg गेहूं',
                        subTitleKn: '20kg ಅಕ್ಕಿ + 5kg ಗೋಧಿ',
                        onTap: () {
                          _speakText(_activeLanguage == 'HI'
                              ? 'आपका इस महीने का राशन कोटा 20 किलो चावल और 5 किलो गेहूं है। मूल्य शून्य रुपये।'
                              : (_activeLanguage == 'KN'
                                  ? 'ಈ ತಿಂಗಳ ನಿಮ್ಮ ರೇಷನ್ ಕೋಟ 20 ಕೆಜಿ ಅಕ್ಕಿ ಮತ್ತು 5 ಕೆಜಿ ಗೋಧಿ. ಉಚಿತ.'
                                  : 'Your monthly quota is 20kg Rice and 5kg Wheat at zero cost.'));
                          widget.onApplyVoiceIntent?.call('FPS_COLLECTION', 20.0, 5.0);
                        },
                      ),

                      // Card 2: 🏪 Select Nearby FPS Shop
                      _buildPictorialCard(
                        icon: '🏪 📍',
                        bgGradient: [const Color(0xFF065F46), const Color(0xFF10B981)],
                        titleHi: 'पास की दुकान (FPS)',
                        titleKn: 'ಹತ್ತಿರದ ಅಂಗಡಿ (FPS)',
                        subTitleHi: 'मल्लेश्वरम दुकान (0.6 km)',
                        subTitleKn: 'ಮಲ್ಲೇಶ್ವರಂ ಅಂಗಡಿ (0.6 km)',
                        onTap: () {
                          _speakText(_activeLanguage == 'HI'
                              ? 'मल्लेश्वरम सरकारी राशन दुकान चुनी गई है। दूरी केवल 600 मीटर है।'
                              : (_activeLanguage == 'KN'
                                  ? 'ಮಲ್ಲೇಶ್ವರಂ ನ್ಯಾಯಬೆಲೆ ಅಂಗಡಿ ಆಯ್ಕೆಯಾಗಿದೆ. ದೂರ 600 ಮೀಟರ್.'
                                  : 'Malleshwaram Fair Price Shop selected. Walking distance 600 meters.'));
                          widget.onApplyVoiceIntent?.call('FPS_COLLECTION', 20.0, 5.0);
                        },
                      ),

                      // Card 3: 🏠 Home Delivery Mode
                      _buildPictorialCard(
                        icon: '🏠 🚚',
                        bgGradient: [const Color(0xFF7C2D12), const Color(0xFFF97316)],
                        titleHi: 'घर पर डिलीवरी',
                        titleKn: 'ಮನೆಗೆ ತಲುಪಿಸಿ',
                        subTitleHi: 'घर के पते पर राशन पाएँ',
                        subTitleKn: 'ಮನೆಯ ವಿಳಾಸಕ್ಕೆ ರೇಷನ್',
                        onTap: () {
                          _speakText(_activeLanguage == 'HI'
                              ? 'घर पर डिलीवरी चुनी गई है। डिलीवरी शुल्क 20 रुपये रहेगा।'
                              : (_activeLanguage == 'KN'
                                  ? 'ಮನೆಗೆ ತಲುಪಿಸುವ ಮೋಡ್ ಆಯ್ಕೆಯಾಗಿದೆ. ತಲುಪಿಸುವ ಶುಲ್ಕ 20 ರೂ.'
                                  : 'Home Delivery mode selected. Convenience fee ₹20 applies.'));
                          widget.onApplyVoiceIntent?.call('HOME_DELIVERY', 20.0, 5.0);
                        },
                      ),

                      // Card 4: 📞 Voice Help Call 1944
                      _buildPictorialCard(
                        icon: '📞 🗣️',
                        bgGradient: [const Color(0xFF581C87), const Color(0xFFA855F7)],
                        titleHi: 'मुफ्त हेल्प कॉल',
                        titleKn: 'ಉಚಿತ ಹೆಲ್ಪ್ ಕರೆ',
                        subTitleHi: '1944 पर अधिकारी से बात करें',
                        subTitleKn: '1944 ಗೆ ಕರೆ ಮಾಡಿ',
                        onTap: () {
                          _speakText(_activeLanguage == 'HI'
                              ? 'राष्ट्रीय खाद्य हेल्पलाइन 1944 पर कॉल मिलाया जा रहा है...'
                              : (_activeLanguage == 'KN'
                                  ? 'ರಾಷ್ಟ್ರೀಯ ಆಹಾರ ಹೆಲ್ಪ್‌ಲೈನ್ 1944 ಗೆ ಕರೆ ಮಾಡಲಾಗುತ್ತಿದೆ...'
                                  : 'Connecting toll-free NFSA helpline 1944...'));
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Big Green Apply Button
                  ElevatedButton.icon(
                    onPressed: () {
                      widget.onApplyVoiceIntent?.call('FPS_COLLECTION', 20.0, 5.0);
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('✔ Voice & Picture intent applied! (आवाज़ आदेश लागू हो गया)'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    },
                    icon: const Icon(Icons.check_circle, size: 24, color: Colors.white),
                    label: Text(
                      _activeLanguage == 'HI'
                          ? '✔ हाँ, यह राशन पक्का करें (Confirm Ration)'
                          : (_activeLanguage == 'KN' ? '✔ ಹೌದು, ಈ ರೇಷನ್ ಖಚಿತಪಡಿಸಿ' : '✔ Confirm My Ration Selection'),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF006644),
                      elevation: 4,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: const BorderSide(color: Colors.amber, width: 1.5),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLangChip(String code, String label) {
    final isSelected = _activeLanguage == code;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: Colors.amber,
      backgroundColor: const Color(0xFF334155),
      labelStyle: TextStyle(
        color: isSelected ? Colors.black : Colors.white70,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 11.5,
      ),
      onSelected: (val) {
        if (val) {
          setState(() {
            _activeLanguage = code;
          });
          _speakText(code == 'HI'
              ? 'हिंदी भाषा चुनी गई'
              : (code == 'KN' ? 'ಕನ್ನಡ ಭಾಷೆ ಆಯ್ಕೆಯಾಗಿದೆ' : 'English language selected'));
        }
      },
    );
  }

  Widget _buildPictorialCard({
    required String icon,
    required List<Color> bgGradient,
    required String titleHi,
    required String titleKn,
    required String subTitleHi,
    required String subTitleKn,
    required VoidCallback onTap,
  }) {
    final title = _activeLanguage == 'HI' ? titleHi : (_activeLanguage == 'KN' ? titleKn : titleHi);
    final subtitle = _activeLanguage == 'HI' ? subTitleHi : (_activeLanguage == 'KN' ? subTitleKn : subTitleHi);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: bgGradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.2), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: bgGradient.last.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(icon, style: const TextStyle(fontSize: 28)),
            const SizedBox(height: 6),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 10.5, color: Colors.white70),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
