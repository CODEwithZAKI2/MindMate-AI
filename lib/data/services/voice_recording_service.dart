import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:firebase_storage/firebase_storage.dart';

/// Service for voice recording and transcription
class VoiceRecordingService {
  final AudioRecorder _recorder = AudioRecorder();
  final FirebaseStorage _storage;
  String? _currentFilePath;
  bool _isRecording = false;

  VoiceRecordingService({FirebaseStorage? storage})
    : _storage = storage ?? FirebaseStorage.instance;

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

  /// Upload audio file to Firebase Storage
  /// Returns the download URL or null on error
  Future<String?> uploadToStorage(String localPath, String userId) async {
    try {
      print('Voice upload: Starting upload for $localPath');
      final file = File(localPath);
      if (!await file.exists()) {
        print('Voice upload: File does not exist at $localPath');
        return null;
      }

      final fileSize = await file.length();
      print('Voice upload: File exists, size: $fileSize bytes');

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'voice_$timestamp.m4a';
      final storagePath = 'voice_notes/$userId/$fileName';
      print('Voice upload: Uploading to $storagePath');

      final ref = _storage.ref().child(storagePath);
      final uploadTask = await ref.putFile(
        file,
        SettableMetadata(contentType: 'audio/mp4'), // m4a uses mp4 container
      );

      print('Voice upload: Upload state: ${uploadTask.state}');

      if (uploadTask.state == TaskState.success) {
        final downloadUrl = await ref.getDownloadURL();
        print('Voice upload: Success! URL: $downloadUrl');

        // Delete local temp file after successful upload
        try {
          await file.delete();
        } catch (_) {}

        return downloadUrl;
      }
      print('Voice upload: Upload did not succeed, state: ${uploadTask.state}');
      return null;
    } catch (e, st) {
      print('Voice upload: ERROR - $e');
      print('Voice upload: Stack trace - $st');
      return null;
    }
  }

  /// Get recording duration stream
  Stream<Duration> get durationStream =>
      Stream.periodic(const Duration(milliseconds: 100), (_) => Duration.zero);

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
