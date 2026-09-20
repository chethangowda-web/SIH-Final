// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:js' as js;

/// Web implementation for speech synthesis using browser window.speechSynthesis
/// with native audio fallback proxy for authentic regional pronunciation (e.g. Kannada, Hindi).
void platformSpeak(String text, String langCode) {
  try {
    final encodedText = js.context.callMethod('encodeURIComponent', [text]) as String;
    final script = """
      (function() {
        try {
          var cleanText = decodeURIComponent('$encodedText');
          if (!cleanText || cleanText.trim() === '') return;

          // Stop any currently playing audio stream
          if (window._pdsVoiceAudio) {
            try {
              window._pdsVoiceAudio.pause();
              window._pdsVoiceAudio.currentTime = 0;
            } catch(e) {}
          }

          var targetLang = '$langCode'.toLowerCase().replace('_', '-');
          var isKannada = targetLang.indexOf('kn') !== -1;
          var isHindi = targetLang.indexOf('hi') !== -1;
          var isEnglish = targetLang.indexOf('en') !== -1;

          function playAudioStream(lang) {
            try {
              var baseUrl = (window.location.origin && window.location.origin !== 'null') ? window.location.origin : '';
              var audioUrl = baseUrl + '/api/tts/speak?lang=' + encodeURIComponent(lang) + '&text=' + encodeURIComponent(cleanText);
              
              if (!window._pdsVoiceAudio) {
                window._pdsVoiceAudio = new Audio();
              }
              window._pdsVoiceAudio.src = audioUrl;
              window._pdsVoiceAudio.playbackRate = 1.0;
              window._pdsVoiceAudio.volume = 1.0;

              var playPromise = window._pdsVoiceAudio.play();
              if (playPromise !== undefined) {
                playPromise.catch(function(err) {
                  console.warn('Direct audio stream failed, attempting WebSpeech fallback:', err);
                  speakWithWebSpeech(null);
                });
              }
            } catch(err) {
              console.warn('playAudioStream exception:', err);
              speakWithWebSpeech(null);
            }
          }

          function speakWithWebSpeech(chosenVoice) {
            if (!('speechSynthesis' in window)) return;
            try {
              window.speechSynthesis.cancel();
              if (window.speechSynthesis.paused) {
                window.speechSynthesis.resume();
              }
              var utterance = new SpeechSynthesisUtterance(cleanText);
              utterance.rate = (isKannada || isHindi) ? 0.95 : 1.0;
              utterance.pitch = 1.0;
              utterance.volume = 1.0;

              if (chosenVoice) {
                utterance.voice = chosenVoice;
                utterance.lang = chosenVoice.lang || (isKannada ? 'kn-IN' : (isHindi ? 'hi-IN' : 'en-US'));
              } else {
                utterance.lang = isKannada ? 'kn-IN' : (isHindi ? 'hi-IN' : 'en-US');
              }

              utterance.onend = function() {
                if (window.speechSynthesis.paused) window.speechSynthesis.resume();
              };
              utterance.onerror = function() {
                if (window.speechSynthesis.paused) window.speechSynthesis.resume();
              };

              setTimeout(function() {
                try {
                  window.speechSynthesis.speak(utterance);
                  if (window.speechSynthesis.paused) window.speechSynthesis.resume();
                } catch(e) {}
              }, 40);
            } catch(e) {
              console.warn('Web speech failed:', e);
            }
          }

          if (isKannada) {
            // For Kannada, always stream high-quality authentic Kannada voice from /api/tts/speak
            playAudioStream('kn');
          } else if (isHindi) {
            // For Hindi, stream authentic neural Hindi voice from /api/tts/speak
            playAudioStream('hi');
          } else {
            // English: Check if local system voice exists or fallback to TTS
            var voices = ('speechSynthesis' in window) ? window.speechSynthesis.getVoices() : [];
            var chosenVoice = null;
            for (var i = 0; i < voices.length; i++) {
              var vl = (voices[i].lang || '').toLowerCase().replace('_', '-');
              if (vl === 'en-in') { chosenVoice = voices[i]; break; }
            }
            if (!chosenVoice) {
              for (var i = 0; i < voices.length; i++) {
                var vl = (voices[i].lang || '').toLowerCase().replace('_', '-');
                var vn = (voices[i].name || '').toLowerCase();
                if (vl.startsWith('en') || vn.indexOf('english') !== -1 || vn.indexOf('david') !== -1 || vn.indexOf('zira') !== -1 || vn.indexOf('mark') !== -1 || vn.indexOf('google') !== -1) {
                  chosenVoice = voices[i];
                  break;
                }
              }
            }
            if (chosenVoice) {
              speakWithWebSpeech(chosenVoice);
            } else {
              playAudioStream('en');
            }
          }
        } catch(e) {
          console.warn('platformSpeak error:', e);
        }
      })()
    """;
    js.context.callMethod('eval', [script]);
  } catch (_) {}
}

void platformStop() {
  try {
    js.context.callMethod('eval', ["""
      (function() {
        try {
          if (window._pdsVoiceAudio) {
            try {
              window._pdsVoiceAudio.pause();
              window._pdsVoiceAudio.currentTime = 0;
            } catch(e) {}
          }
          if ('speechSynthesis' in window) {
            window.speechSynthesis.cancel();
          }
        } catch(e) {}
      })()
    """]);
  } catch (_) {}
}

typedef SpeechStatusCallback = void Function(String status, String? detail);
typedef SpeechResultCallback = void Function(String transcript, bool isFinal);

bool platformIsSpeechRecognitionSupported() {
  try {
    final res = js.context.callMethod('eval', [
      "(function() { return !!(window.SpeechRecognition || window.webkitSpeechRecognition); })()"
    ]);
    return res == true;
  } catch (_) {
    return false;
  }
}

void platformStartListening({
  required String langCode,
  required SpeechStatusCallback onStatus,
  required SpeechResultCallback onResult,
}) {
  try {
    js.context['__pdsOnSpeechStatus'] = js.JsFunction.withThis((_, dynamic status, [dynamic detail]) {
      onStatus(status.toString(), detail?.toString());
    });
    js.context['__pdsOnSpeechResult'] = js.JsFunction.withThis((_, dynamic transcript, [dynamic isFinal]) {
      onResult(transcript.toString(), isFinal == true);
    });

    final script = """
      (function() {
        try {
          var SpeechRec = window.SpeechRecognition || window.webkitSpeechRecognition;
          if (!SpeechRec) {
            if (window.__pdsOnSpeechStatus) window.__pdsOnSpeechStatus('unsupported', 'Browser does not support SpeechRecognition');
            return;
          }

          if (window._pdsSpeechRecognition) {
            try { window._pdsSpeechRecognition.abort(); } catch(e) {}
            window._pdsSpeechRecognition = null;
          }

          window.__pdsLastCapturedTranscript = '';
          window.__pdsFinalDispatched = false;

          function initAndStartRecognition() {
            try {
              var recognition = new SpeechRec();
              window._pdsSpeechRecognition = recognition;

              var targetLang = '$langCode'.replace('_', '-');
              recognition.lang = targetLang;
              recognition.continuous = true;
              recognition.interimResults = true;
              recognition.maxAlternatives = 1;

              recognition.onstart = function() {
                window.__pdsLastCapturedTranscript = '';
                window.__pdsFinalDispatched = false;
                if (window.__pdsOnSpeechStatus) window.__pdsOnSpeechStatus('listening', null);
              };

              recognition.onresult = function(event) {
                var fullTranscript = '';
                var hasFinal = false;
                for (var i = 0; i < event.results.length; ++i) {
                  fullTranscript += event.results[i][0].transcript + ' ';
                  if (event.results[i].isFinal) hasFinal = true;
                }
                fullTranscript = fullTranscript.trim();
                window.__pdsLastCapturedTranscript = fullTranscript;

                if (window.__pdsOnSpeechResult && fullTranscript.length > 0) {
                  window.__pdsOnSpeechResult(fullTranscript, hasFinal);
                  if (hasFinal) window.__pdsFinalDispatched = true;
                }
              };

              recognition.onerror = function(event) {
                var err = event.error || 'error';
                if (err === 'no-speech') {
                  // Ignore harmless transient no-speech if we already captured text
                  if (!window.__pdsLastCapturedTranscript) {
                    if (window.__pdsOnSpeechStatus) window.__pdsOnSpeechStatus('no_speech', 'No speech detected');
                  }
                  return;
                }
                if (window.__pdsOnSpeechStatus) {
                  if (err === 'not-allowed' || err === 'service-not-allowed' || err === 'audio-capture') {
                    window.__pdsOnSpeechStatus('permission_denied', 'Microphone access required');
                  } else if (err !== 'aborted') {
                    window.__pdsOnSpeechStatus('error', err);
                  }
                }
              };

              recognition.onend = function() {
                if (window.__pdsLastCapturedTranscript && !window.__pdsFinalDispatched) {
                  if (window.__pdsOnSpeechResult) {
                    window.__pdsOnSpeechResult(window.__pdsLastCapturedTranscript, true);
                    window.__pdsFinalDispatched = true;
                  }
                }
                if (window.__pdsOnSpeechStatus) window.__pdsOnSpeechStatus('idle', null);
              };

              recognition.start();
            } catch(startErr) {
              if (window.__pdsOnSpeechStatus) window.__pdsOnSpeechStatus('error', String(startErr));
            }
          }

          // Request mic access explicitly first if supported, then start SpeechRecognition
          if (navigator.mediaDevices && navigator.mediaDevices.getUserMedia) {
            navigator.mediaDevices.getUserMedia({ audio: true }).then(function(stream) {
              try { stream.getTracks().forEach(function(t) { t.stop(); }); } catch(e) {}
              initAndStartRecognition();
            }).catch(function(permErr) {
              initAndStartRecognition();
            });
          } else {
            initAndStartRecognition();
          }

        } catch(err) {
          if (window.__pdsOnSpeechStatus) window.__pdsOnSpeechStatus('error', String(err));
        }
      })()
    """;
    js.context.callMethod('eval', [script]);
  } catch (e) {
    onStatus('error', e.toString());
  }
}

void platformStopListening() {
  try {
    js.context.callMethod('eval', ["""
      (function() {
        try {
          if (window._pdsSpeechRecognition) {
            window._pdsSpeechRecognition.stop();
            window._pdsSpeechRecognition = null;
          }
        } catch(e) {}
      })()
    """]);
  } catch (_) {}
}

