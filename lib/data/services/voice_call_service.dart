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

      // Configure TTS settings
      await _tts!.setVolume(1.0);
      await _tts!.setSpeechRate(0.45);
      await _tts!.setPitch(1.0);

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
          } else if (error.errorMsg != 'error_speech_timeout') {
            onError?.call('Speech error: ${error.errorMsg}');
          }
        },
        onStatus: (status) {
          debugPrint('STT Status: $status');
          if (status == 'notListening' || status == 'done') {
            _isListening = false;
            onListeningStateChanged?.call(false);
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

  /// Check if STT is available
  bool get isSttAvailable => _sttAvailable;

  /// Check if TTS is ready
  bool get isTtsReady => _ttsReady;

  /// Check if currently speaking
  bool get isSpeaking => _isSpeaking;

  /// Check if currently listening
  bool get isListening => _isListening;

  /// Start listening for speech input
  Future<void> startListening() async {
    if (!_sttAvailable) {
      onError?.call('Speech recognition not available');
      return;
    }

    if (_isSpeaking) {
      await stopSpeaking();
      await Future.delayed(const Duration(milliseconds: 300));
    }

    _isListening = true;
    onListeningStateChanged?.call(true);

    try {
      debugPrint('Starting STT with locale: $_selectedLocale');
      await _stt.listen(
        onResult: (result) {
          debugPrint(
            'STT result: ${result.recognizedWords} (final: ${result.finalResult})',
          );
          onSpeechResult?.call(result.recognizedWords);
        },
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
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

  /// Stop listening
  Future<void> stopListening() async {
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
    await stopListening();
    await stopSpeaking();
    await _stt.cancel();
    if (_tts != null) {
      await _tts!.stop();
    }
  }
}
