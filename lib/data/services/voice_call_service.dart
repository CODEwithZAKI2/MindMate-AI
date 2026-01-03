import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

/// Service for managing voice call functionality
/// Handles speech-to-text (STT) and text-to-speech (TTS)
class VoiceCallService {
  final FlutterTts _tts = FlutterTts();
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

    final completer = Completer<bool>();

    try {
      // Set up handlers first
      _tts.setStartHandler(() {
        _isSpeaking = true;
        onSpeakingStateChanged?.call(true);
      });

      _tts.setCompletionHandler(() {
        _isSpeaking = false;
        onSpeakingStateChanged?.call(false);
      });

      _tts.setErrorHandler((msg) {
        debugPrint('TTS Error: $msg');
        _isSpeaking = false;
        onSpeakingStateChanged?.call(false);
      });

      // Check available engines
      final engines = await _tts.getEngines;
      debugPrint('Available TTS engines: $engines');

      if (engines.isEmpty) {
        debugPrint('No TTS engines available');
        return false;
      }

      // Set language and wait for it
      final langResult = await _tts.setLanguage('en-US');
      debugPrint('TTS setLanguage result: $langResult');

      await _tts.setSpeechRate(0.45);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);

      // Wait a moment for engine to fully bind
      await Future.delayed(const Duration(milliseconds: 500));

      // Test if TTS is working
      final isLangAvailable = await _tts.isLanguageAvailable('en-US');
      debugPrint('TTS language available: $isLangAvailable');

      _ttsReady = true;
      onTtsReady?.call();
      return true;
    } catch (e) {
      debugPrint('TTS init error: $e');
      return false;
    }
  }

  /// Initialize speech-to-text
  Future<bool> initStt() async {
    try {
      _sttAvailable = await _stt.initialize(
        onError: (error) {
          debugPrint('STT Error: $error');
          onError?.call('Speech error: ${error.errorMsg}');
        },
        onStatus: (status) {
          debugPrint('STT Status: $status');
          if (status == 'notListening') {
            _isListening = false;
            onListeningStateChanged?.call(false);
          }
        },
      );
      debugPrint('STT available: $_sttAvailable');
      return _sttAvailable;
    } catch (e) {
      debugPrint('STT init error: $e');
      onError?.call('Could not initialize speech recognition');
      return false;
    }
  }

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

    await _stt.listen(
      onResult: (result) {
        onSpeechResult?.call(result.recognizedWords);
      },
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 3),
      partialResults: true,
      listenOptions: stt.SpeechListenOptions(
        cancelOnError: false,
        partialResults: true,
        autoPunctuation: true,
      ),
    );
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

    if (!_ttsReady) {
      debugPrint('TTS not ready, initializing...');
      await initTts();
    }

    _isSpeaking = true;
    onSpeakingStateChanged?.call(true);

    try {
      final result = await _tts.speak(text);
      debugPrint('TTS speak result: $result');
    } catch (e) {
      debugPrint('TTS speak error: $e');
      _isSpeaking = false;
      onSpeakingStateChanged?.call(false);
    }
  }

  /// Stop speaking
  Future<void> stopSpeaking() async {
    await _tts.stop();
    _isSpeaking = false;
    onSpeakingStateChanged?.call(false);
  }

  /// Cleanup resources
  Future<void> dispose() async {
    await stopListening();
    await stopSpeaking();
    await _stt.cancel();
  }
}
