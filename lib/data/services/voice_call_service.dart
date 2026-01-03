import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

/// Service for managing voice call functionality
/// Handles speech-to-text (STT) and text-to-speech (TTS)
class VoiceCallService {
  final FlutterTts _tts = FlutterTts();
  final stt.SpeechToText _stt = stt.SpeechToText();

  bool _sttAvailable = false;
  bool _isSpeaking = false;
  bool _isListening = false;

  // Callbacks
  Function(String)? onSpeechResult;
  Function(bool)? onListeningStateChanged;
  Function(bool)? onSpeakingStateChanged;
  Function(String)? onError;

  VoiceCallService() {
    _initTts();
  }

  Future<void> _initTts() async {
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.5); // Slightly slower for clarity
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);

    _tts.setStartHandler(() {
      _isSpeaking = true;
      onSpeakingStateChanged?.call(true);
    });

    _tts.setCompletionHandler(() {
      _isSpeaking = false;
      onSpeakingStateChanged?.call(false);
    });

    _tts.setErrorHandler((msg) {
      _isSpeaking = false;
      onSpeakingStateChanged?.call(false);
      onError?.call('TTS Error: $msg');
    });
  }

  /// Initialize speech-to-text
  Future<bool> initStt() async {
    try {
      _sttAvailable = await _stt.initialize(
        onError: (error) {
          debugPrint('STT Error: $error');
          onError?.call('Speech recognition error: ${error.errorMsg}');
        },
        onStatus: (status) {
          debugPrint('STT Status: $status');
          if (status == 'notListening') {
            _isListening = false;
            onListeningStateChanged?.call(false);
          }
        },
      );
      return _sttAvailable;
    } catch (e) {
      debugPrint('STT init error: $e');
      onError?.call('Could not initialize speech recognition');
      return false;
    }
  }

  /// Check if STT is available
  bool get isSttAvailable => _sttAvailable;

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

    _isSpeaking = true;
    onSpeakingStateChanged?.call(true);
    await _tts.speak(text);
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
