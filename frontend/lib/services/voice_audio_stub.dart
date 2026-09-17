/// Platform stub for speech synthesis on non-web platforms.
void platformSpeak(String text, String langCode) {
  // No-op on non-web fallback (or desktop/mobile console)
}

void platformStop() {
  // No-op on non-web fallback
}

typedef SpeechStatusCallback = void Function(String status, String? detail);
typedef SpeechResultCallback = void Function(String transcript, bool isFinal);

bool platformIsSpeechRecognitionSupported() => false;

void platformStartListening({
  required String langCode,
  required SpeechStatusCallback onStatus,
  required SpeechResultCallback onResult,
}) {
  onStatus('unsupported', 'Speech recognition not supported on this platform');
}

void platformStopListening() {
  // No-op on non-web fallback
}

