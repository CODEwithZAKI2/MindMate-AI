import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:cloud_functions/cloud_functions.dart';

/// Service for voice recording and transcription
class VoiceRecordingService {
  final AudioRecorder _recorder = AudioRecorder();
  final FirebaseFunctions _functions;
  String? _currentFilePath;
  bool _isRecording = false;

  VoiceRecordingService({FirebaseFunctions? functions})
    : _functions = functions ?? FirebaseFunctions.instance;

  bool get isRecording => _isRecording;
  String? get currentFilePath => _currentFilePath;

  /// Check and request microphone permission
  Future<bool> hasPermission() async {
    return await _recorder.hasPermission();
  }

  /// Start recording audio
  Future<bool> startRecording() async {
    if (_isRecording) return false;

    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) return false;

    try {
      final dir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      _currentFilePath = '${dir.path}/voice_journal_$timestamp.m4a';

      await _recorder.start(
        RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: _currentFilePath!,
      );

      _isRecording = true;
      return true;
    } catch (e) {
      _isRecording = false;
      return false;
    }
  }

  /// Stop recording and return the file path
  Future<String?> stopRecording() async {
    if (!_isRecording) return null;

    try {
      final path = await _recorder.stop();
      _isRecording = false;
      return path ?? _currentFilePath;
    } catch (e) {
      _isRecording = false;
      return null;
    }
  }

  /// Cancel recording without saving
  Future<void> cancelRecording() async {
    if (_isRecording) {
      await _recorder.stop();
      _isRecording = false;

      // Delete the temp file
      if (_currentFilePath != null) {
        try {
          final file = File(_currentFilePath!);
          if (await file.exists()) {
            await file.delete();
          }
        } catch (_) {}
      }
    }
    _currentFilePath = null;
  }

  /// Get recording duration stream
  Stream<Duration> get durationStream =>
      Stream.periodic(const Duration(milliseconds: 100), (_) => Duration.zero);

  /// Transcribe audio file using Cloud Function
  /// Returns transcribed text or null on error
  Future<String?> transcribeAudio(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return null;

      // Read file as bytes and convert to base64
      final bytes = await file.readAsBytes();
      final base64Audio =
          bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

      // This would call a Cloud Function that uses Google Speech-to-Text
      // For now, we'll use the simpler approach of just noting the audio exists
      // Full transcription requires setting up Google Cloud Speech-to-Text API

      return null; // Placeholder - actual transcription requires more setup
    } catch (e) {
      return null;
    }
  }

  /// Clean up resources
  void dispose() {
    _recorder.dispose();
  }
}

/// Voice recording state for the UI
enum VoiceRecordingState { idle, recording, processing, completed, error }

/// Recording result
class VoiceRecordingResult {
  final String? filePath;
  final String? transcript;
  final Duration? duration;
  final bool hasError;

  VoiceRecordingResult({
    this.filePath,
    this.transcript,
    this.duration,
    this.hasError = false,
  });
}
