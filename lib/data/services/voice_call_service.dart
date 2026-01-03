import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

/// Service for managing voice call functionality
/// Handles speech-to-text (STT) and text-to-speech (TTS)
class VoiceCallService {
  FlutterTts? _tts;
  final stt.SpeechToText _stt = stt.SpeechToText();

  bool _sttAvailable = false;
  bool _ttsReady = false;
  bool _isSpeaking = false;
  bool _isListening = false;

  // Callbacks
  Function(String)? onSpeechResult;
  Function(bool)? onListeningStateChanged;
  Function(bool)? onSpeakingStateChanged;
  Function(String)? onError;
  Function()? onTtsReady;

  VoiceCallService();

  /// Initialize TTS engine and wait for it to be ready
  Future<bool> initTts() async {
    debugPrint('Initializing TTS...');

    try {
      // Create new instance to ensure clean state
      _tts = FlutterTts();

      // Check available engines first
      final engines = await _tts!.getEngines;
      debugPrint('Available TTS engines: $engines');

      if (engines == null || (engines is List && engines.isEmpty)) {
        debugPrint('No TTS engines available');
        onError?.call(
          'No text-to-speech engine found. Please install Google Text-to-Speech from Play Store.',
        );
        return false;
      }

      // On Android, explicitly set the engine to Google TTS
      if (Platform.isAndroid) {
        final engineList = engines as List;
        if (engineList.contains('com.google.android.tts')) {
          debugPrint('Setting TTS engine to Google TTS...');
          await _tts!.setEngine('com.google.android.tts');
        }
      }

      // Wait for engine to bind - this is crucial!
      debugPrint('Waiting for TTS engine to bind...');
      await Future.delayed(const Duration(milliseconds: 1500));

      // Configure TTS settings for natural, human-like voice
      // Volume at max for clarity
      await _tts!.setVolume(1.0);
      // Speech rate: 0.5 = natural conversational pace (like ChatGPT/Gemini)
      // Not too fast, not too slow - human-like rhythm
      await _tts!.setSpeechRate(0.5);
      // Pitch: 1.05 = slightly warmer, more human tone
      await _tts!.setPitch(1.05);
      
      // Try to get a more natural voice
      if (Platform.isAndroid) {
        try {
          final voices = await _tts!.getVoices;
          debugPrint('Available TTS voices: ${voices?.length ?? 0}');
          
          // Look for Google's neural/natural voices
          if (voices != null && voices is List) {
            // Prefer neural/natural voices for human-like quality
            final voiceList = voices as List<dynamic>;
            Map<String, dynamic>? bestVoice;
            
            for (final voice in voiceList) {
              if (voice is Map) {
                final name = voice['name']?.toString().toLowerCase() ?? '';
                final locale = voice['locale']?.toString() ?? '';
                
                // Look for US English voices with natural/neural qualities
                if (locale.contains('en') && locale.contains('US')) {
                  // Prefer voices with these keywords (usually better quality)
                  if (name.contains('neural') || name.contains('wavenet') || 
                      name.contains('journey') || name.contains('studio') ||
                      name.contains('polyglot') || name.contains('news')) {
                    bestVoice = voice as Map<String, dynamic>;
                    break;
                  }
                  // Fall back to any female voice (often sounds more natural)
                  if (bestVoice == null && (name.contains('female') || name.contains('en-us-x-sfg'))) {
                    bestVoice = voice as Map<String, dynamic>;
                  }
                }
              }
            }
            
            if (bestVoice != null) {
              debugPrint('Setting TTS voice to: ${bestVoice['name']}');
              await _tts!.setVoice({
                'name': bestVoice['name'],
                'locale': bestVoice['locale'],
              });
            }
          }
        } catch (e) {
          debugPrint('Could not set custom voice: $e');
        }
      }

      // Try to set language with retries
      int retries = 3;
      bool languageSet = false;

      while (retries > 0 && !languageSet) {
        try {
          final langResult = await _tts!.setLanguage('en-US');
          debugPrint('TTS setLanguage result: $langResult (1=success)');

          // Check if language is actually available
          final isLangAvailable = await _tts!.isLanguageAvailable('en-US');
          debugPrint('TTS language available: $isLangAvailable');

          if (langResult == 1 || isLangAvailable == true) {
            languageSet = true;
            break;
          }
        } catch (e) {
          debugPrint('TTS language set attempt failed: $e');
        }

        retries--;
        if (retries > 0) {
          debugPrint('Retrying TTS language setup... ($retries attempts left)');
          await Future.delayed(const Duration(milliseconds: 1000));
        }
      }

      // Set up handlers
      _tts!.setStartHandler(() {
        debugPrint('TTS started speaking');
        _isSpeaking = true;
        onSpeakingStateChanged?.call(true);
      });

      _tts!.setCompletionHandler(() {
        debugPrint('TTS completed speaking');
        _isSpeaking = false;
        onSpeakingStateChanged?.call(false);
        // Auto-restart listening after AI finishes speaking (intelligent turn-taking)
        if (_continuousListening) {
          debugPrint('AI finished speaking - auto-starting listener');
          _scheduleRestartListening();
        }
      });

      _tts!.setErrorHandler((msg) {
        debugPrint('TTS Error: $msg');
        _isSpeaking = false;
        onSpeakingStateChanged?.call(false);
        onError?.call('Speech error: $msg');
      });

      // Enable await speak completion for synchronous behavior
      await _tts!.awaitSpeakCompletion(true);

      _ttsReady = true;
      onTtsReady?.call();
      debugPrint('TTS initialization complete!');
      return true;
    } catch (e) {
      debugPrint('TTS init error: $e');
      onError?.call('Failed to initialize text-to-speech: $e');
      return false;
    }
  }

  /// Initialize speech-to-text
  Future<bool> initStt() async {
    try {
      _sttAvailable = await _stt.initialize(
        onError: (error) {
          debugPrint('STT Error: $error');
          // Handle specific errors
          if (error.errorMsg == 'error_permission') {
            onError?.call('Microphone permission denied. Please grant permission to Google app in Settings.');
          } else if (error.errorMsg == 'error_language_not_supported') {
            debugPrint('Language not supported - will continue without STT');
          } else if (error.errorMsg == 'error_speech_timeout') {
            // Speech timeout - auto restart if in continuous mode
            debugPrint('Speech timeout - will restart if continuous mode');
            _scheduleRestartListening();
          } else if (error.errorMsg == 'error_no_match') {
            // No speech matched - auto restart if in continuous mode
            debugPrint('No speech matched - will restart if continuous mode');
            _scheduleRestartListening();
          } else {
            onError?.call('Speech error: ${error.errorMsg}');
          }
        },
        onStatus: (status) {
          debugPrint('STT Status: $status');
          if (status == 'notListening' || status == 'done') {
            _isListening = false;
            onListeningStateChanged?.call(false);
            // Auto restart if in continuous mode and not speaking
            if (_continuousListening && !_isSpeaking) {
              _scheduleRestartListening();
            }
          }
        },
      );

      if (_sttAvailable) {
        // Get available locales and find the best match
        final locales = await _stt.locales();
        debugPrint(
          'Available STT locales: ${locales.map((l) => l.localeId).toList()}',
        );

        // Try to find en-US or any English locale
        String? bestLocale;
        for (final locale in locales) {
          if (locale.localeId == 'en-US' || locale.localeId == 'en_US') {
            bestLocale = locale.localeId;
            break;
          } else if (locale.localeId.startsWith('en') && bestLocale == null) {
            bestLocale = locale.localeId;
          }
        }

        if (bestLocale != null) {
          _selectedLocale = bestLocale;
          debugPrint('Selected STT locale: $_selectedLocale');
        } else if (locales.isNotEmpty) {
          _selectedLocale = locales.first.localeId;
          debugPrint('Using first available locale: $_selectedLocale');
        }
      }

      debugPrint('STT available: $_sttAvailable');
      return _sttAvailable;
    } catch (e) {
      debugPrint('STT init error: $e');
      onError?.call('Could not initialize speech recognition');
      return false;
    }
  }

  // Selected locale for STT
  String? _selectedLocale;
  
  // Continuous listening mode - keeps listening until manually stopped
  bool _continuousListening = false;
  Timer? _restartTimer;

  /// Check if STT is available
  bool get isSttAvailable => _sttAvailable;

  /// Check if TTS is ready
  bool get isTtsReady => _ttsReady;

  /// Check if currently speaking
  bool get isSpeaking => _isSpeaking;

  /// Check if currently listening
  bool get isListening => _isListening;
  
  /// Check if continuous listening is enabled
  bool get isContinuousListening => _continuousListening;

  /// Start listening for speech input with continuous mode
  /// In continuous mode, listening will auto-restart after silence
  Future<void> startListening({bool continuous = true}) async {
    if (!_sttAvailable) {
      onError?.call('Speech recognition not available');
      return;
    }

    if (_isSpeaking) {
      await stopSpeaking();
      await Future.delayed(const Duration(milliseconds: 300));
    }

    _continuousListening = continuous;
    _isListening = true;
    onListeningStateChanged?.call(true);

    await _startListeningInternal();
  }
  
  /// Internal method to start STT
  Future<void> _startListeningInternal() async {
    try {
      debugPrint('Starting STT with locale: $_selectedLocale (continuous: $_continuousListening)');
      await _stt.listen(
        onResult: (result) {
          debugPrint(
            'STT result: ${result.recognizedWords} (final: ${result.finalResult})',
          );
          onSpeechResult?.call(result.recognizedWords);
          
          // If we got a final result and continuous mode is on,
          // we'll let it timeout and auto-restart
        },
        listenFor: const Duration(minutes: 5), // Listen for up to 5 minutes
        pauseFor: const Duration(seconds: 3), // 3 seconds of silence = user finished speaking (like ChatGPT)
        partialResults: true,
        localeId: _selectedLocale, // Use selected locale
        listenOptions: stt.SpeechListenOptions(
          cancelOnError: false,
          partialResults: true,
          autoPunctuation: true,
          onDevice: false, // Allow cloud-based recognition
        ),
      );
    } catch (e) {
      debugPrint('STT listen error: $e');
      _isListening = false;
      onListeningStateChanged?.call(false);
      onError?.call('Failed to start listening: $e');
    }
  }
  
  /// Restart listening after a short delay (for continuous mode)
  void _scheduleRestartListening() {
    if (!_continuousListening || _isSpeaking) return;
    
    _restartTimer?.cancel();
    _restartTimer = Timer(const Duration(milliseconds: 500), () async {
      if (_continuousListening && !_isSpeaking && !_isListening) {
        debugPrint('Auto-restarting listening (continuous mode)');
        _isListening = true;
        onListeningStateChanged?.call(true);
        await _startListeningInternal();
      }
    });
  }

  /// Stop listening completely (disables continuous mode)
  Future<void> stopListening() async {
    _continuousListening = false;
    _restartTimer?.cancel();
    _isListening = false;
    // Don't call callback here - will be called by dispose
    await _stt.stop();
  }
  
  /// Pause listening temporarily (keeps continuous mode enabled)
  Future<void> pauseListening() async {
    _isListening = false;
    await _stt.stop();
    // Don't disable continuous mode - will restart when needed
  }

  /// Stop listening and notify (for manual stop, not dispose)
  Future<void> stopListeningAndNotify() async {
    _continuousListening = false;
    _restartTimer?.cancel();
    _isListening = false;
    onListeningStateChanged?.call(false);
    await _stt.stop();
  }

  /// Speak text using TTS
  Future<void> speak(String text) async {
    if (text.isEmpty) return;

    // Stop listening while speaking
    if (_isListening) {
      await stopListening();
    }

    if (!_ttsReady || _tts == null) {
      debugPrint('TTS not ready, initializing...');
      final success = await initTts();
      if (!success) {
        debugPrint('TTS initialization failed, cannot speak');
        onError?.call('Voice output unavailable. Showing text instead.');
        // Still trigger speaking state change so UI can show the text
        onSpeakingStateChanged?.call(true);
        await Future.delayed(const Duration(seconds: 2));
        onSpeakingStateChanged?.call(false);
        return;
      }
    }

    _isSpeaking = true;
    onSpeakingStateChanged?.call(true);

    try {
      debugPrint(
        'TTS speaking: "${text.substring(0, text.length > 50 ? 50 : text.length)}..."',
      );
      final result = await _tts!.speak(text);
      debugPrint('TTS speak result: $result');

      if (result != 1) {
        debugPrint('TTS speak failed with result: $result');
        _isSpeaking = false;
        onSpeakingStateChanged?.call(false);
      }
    } catch (e) {
      debugPrint('TTS speak error: $e');
      _isSpeaking = false;
      onSpeakingStateChanged?.call(false);
      onError?.call('Failed to speak: $e');
    }
  }

  /// Stop speaking
  Future<void> stopSpeaking() async {
    if (_tts != null) {
      await _tts!.stop();
    }
    _isSpeaking = false;
    onSpeakingStateChanged?.call(false);
  }

  /// Cleanup resources
  Future<void> dispose() async {
    // Clear callbacks first to prevent setState after dispose
    onSpeechResult = null;
    onListeningStateChanged = null;
    onSpeakingStateChanged = null;
    onError = null;
    onTtsReady = null;
    
    _continuousListening = false;
    _restartTimer?.cancel();
    await stopListening();
    await stopSpeaking();
    await _stt.cancel();
    if (_tts != null) {
      await _tts!.stop();
    }
  }
}
