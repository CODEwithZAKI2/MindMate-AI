import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Google Cloud Text-to-Speech service using Wavenet voices
/// Provides natural, human-like voice synthesis for MindMate AI
class GoogleCloudTtsService {
  static const String _apiEndpoint =
      'https://texttospeech.googleapis.com/v1/text:synthesize';

  // Usage tracking keys
  static const String _usageCountKey = 'google_tts_char_count';
  static const String _usageMonthKey = 'google_tts_usage_month';
  static const String _apiKeyStorageKey = 'google_cloud_tts_api_key';

  // Free tier limit: 4 million characters per month
  static const int _freeCharacterLimit = 4000000;

  // Warning threshold: 90% of free tier
  static const int _warningThreshold = 3600000;

  final AudioPlayer _audioPlayer = AudioPlayer();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  String? _apiKey;
  bool _isInitialized = false;
  bool _isSpeaking = false;

  // Callbacks
  Function(bool)? onSpeakingStateChanged;
  Function(String)? onError;
  Function()? onComplete;
  Function(int usedChars, int limit)? onUsageWarning;

  /// Selected voice configuration
  /// Using Wavenet voices for natural, human-like speech
  String _voiceName = 'en-US-Wavenet-F'; // Female Wavenet voice (warm & caring)
  String _languageCode = 'en-US';
  double _speakingRate = 0.95; // Slightly slower for warmth
  double _pitch = 0.0; // Natural pitch
  double _volumeGainDb = 0.0;

  /// Available Wavenet voices for different tones
  static const Map<String, String> availableVoices = {
    'en-US-Wavenet-A': 'Male (Deep)',
    'en-US-Wavenet-B': 'Male (Warm)',
    'en-US-Wavenet-C': 'Female (Bright)',
    'en-US-Wavenet-D': 'Male (Clear)',
    'en-US-Wavenet-E': 'Female (Soft)',
    'en-US-Wavenet-F': 'Female (Warm)', // Default - best for mental wellness
    'en-US-Wavenet-G': 'Female (Expressive)',
    'en-US-Wavenet-H': 'Female (Natural)',
    'en-US-Wavenet-I': 'Male (Natural)',
    'en-US-Wavenet-J': 'Male (Conversational)',
    // Neural2 voices (even more natural)
    'en-US-Neural2-A': 'Male Neural (Very Natural)',
    'en-US-Neural2-C': 'Female Neural (Very Natural)',
    'en-US-Neural2-D': 'Male Neural (Warm)',
    'en-US-Neural2-E': 'Female Neural (Warm)',
    'en-US-Neural2-F': 'Female Neural (Expressive)',
    // Journey voices (conversational)
    'en-US-Journey-D': 'Male Journey (Conversational)',
    'en-US-Journey-F': 'Female Journey (Conversational)',
  };

  GoogleCloudTtsService();

  /// Initialize the service with API key
  /// API key should be stored securely and passed here
  Future<bool> initialize({String? apiKey}) async {
    try {
      debugPrint('[GoogleCloudTTS] Initializing...');

      // Try to get API key from parameter, secure storage, or environment
      _apiKey = apiKey ?? await _getStoredApiKey();

      if (_apiKey == null || _apiKey!.isEmpty) {
        debugPrint('[GoogleCloudTTS] No API key found');
        onError?.call(
          'Google Cloud TTS API key not configured. Please add your API key.',
        );
        return false;
      }

      // Setup audio player
      _audioPlayer.onPlayerComplete.listen((_) {
        debugPrint('[GoogleCloudTTS] Audio playback completed');
        _isSpeaking = false;
        onSpeakingStateChanged?.call(false);
        onComplete?.call();
      });

      _audioPlayer.onPlayerStateChanged.listen((state) {
        debugPrint('[GoogleCloudTTS] Player state: $state');
        if (state == PlayerState.playing) {
          _isSpeaking = true;
          onSpeakingStateChanged?.call(true);
        } else if (state == PlayerState.stopped ||
            state == PlayerState.completed) {
          _isSpeaking = false;
          onSpeakingStateChanged?.call(false);
        }
      });

      // Reset usage tracking if new month
      await _checkAndResetMonthlyUsage();

      _isInitialized = true;
      debugPrint('[GoogleCloudTTS] Initialized successfully');
      return true;
    } catch (e) {
      debugPrint('[GoogleCloudTTS] Initialization error: $e');
      onError?.call('Failed to initialize voice service: $e');
      return false;
    }
  }

  /// Store API key securely
  Future<void> setApiKey(String apiKey) async {
    await _secureStorage.write(key: _apiKeyStorageKey, value: apiKey);
    _apiKey = apiKey;
    debugPrint('[GoogleCloudTTS] API key stored securely');
  }

  /// Get stored API key
  Future<String?> _getStoredApiKey() async {
    try {
      return await _secureStorage.read(key: _apiKeyStorageKey);
    } catch (e) {
      debugPrint('[GoogleCloudTTS] Error reading API key: $e');
      return null;
    }
  }

  /// Check if API key is configured
  Future<bool> hasApiKey() async {
    final key = await _getStoredApiKey();
    return key != null && key.isNotEmpty;
  }

  /// Set voice configuration
  void setVoice({
    String? voiceName,
    String? languageCode,
    double? speakingRate,
    double? pitch,
    double? volumeGainDb,
  }) {
    if (voiceName != null) _voiceName = voiceName;
    if (languageCode != null) _languageCode = languageCode;
    if (speakingRate != null) _speakingRate = speakingRate.clamp(0.25, 4.0);
    if (pitch != null) _pitch = pitch.clamp(-20.0, 20.0);
    if (volumeGainDb != null) _volumeGainDb = volumeGainDb.clamp(-96.0, 16.0);

    debugPrint('[GoogleCloudTTS] Voice configured: $_voiceName');
  }

  /// Synthesize speech from text
  Future<void> speak(String text) async {
    if (text.isEmpty) {
      debugPrint('[GoogleCloudTTS] Empty text, skipping');
      return;
    }

    if (!_isInitialized || _apiKey == null) {
      debugPrint('[GoogleCloudTTS] Not initialized, attempting initialization');
      final success = await initialize();
      if (!success) {
        onError?.call('Voice service not available');
        return;
      }
    }

    // Check usage before making request
    final usageCheck = await _checkUsageBeforeSpeaking(text.length);
    if (!usageCheck) {
      onError?.call(
        'Monthly TTS character limit reached. Please try again next month or upgrade your plan.',
      );
      return;
    }

    try {
      debugPrint(
        '[GoogleCloudTTS] Speaking: "${text.substring(0, text.length > 50 ? 50 : text.length)}..."',
      );

      // Build request body
      final requestBody = {
        'input': {'text': text},
        'voice': {
          'languageCode': _languageCode,
          'name': _voiceName,
        },
        'audioConfig': {
          'audioEncoding': 'MP3',
          'speakingRate': _speakingRate,
          'pitch': _pitch,
          'volumeGainDb': _volumeGainDb,
          'effectsProfileId': ['headphone-class-device'], // Optimize for device
        },
      };

      // Make API request
      final response = await http.post(
        Uri.parse('$_apiEndpoint?key=$_apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final audioContent = data['audioContent'] as String;

        // Decode base64 audio
        final audioBytes = base64Decode(audioContent);

        // Update usage tracking
        await _updateUsage(text.length);

        // Play audio
        await _playAudio(audioBytes);
      } else {
        debugPrint('[GoogleCloudTTS] API error: ${response.statusCode}');
        debugPrint('[GoogleCloudTTS] Response: ${response.body}');
        _handleApiError(response.statusCode, response.body);
      }
    } catch (e) {
      debugPrint('[GoogleCloudTTS] Speak error: $e');
      _isSpeaking = false;
      onSpeakingStateChanged?.call(false);
      onError?.call('Failed to generate speech: $e');
    }
  }

  /// Play audio from bytes
  Future<void> _playAudio(Uint8List audioBytes) async {
    try {
      // Save to temporary file
      final tempDir = await getTemporaryDirectory();
      final tempFile = File(
        '${tempDir.path}/tts_audio_${DateTime.now().millisecondsSinceEpoch}.mp3',
      );
      await tempFile.writeAsBytes(audioBytes);

      _isSpeaking = true;
      onSpeakingStateChanged?.call(true);

      // Play from file
      await _audioPlayer.play(DeviceFileSource(tempFile.path));

      debugPrint('[GoogleCloudTTS] Audio playback started');
    } catch (e) {
      debugPrint('[GoogleCloudTTS] Audio playback error: $e');
      _isSpeaking = false;
      onSpeakingStateChanged?.call(false);
      onError?.call('Failed to play audio: $e');
    }
  }

  /// Stop speaking
  Future<void> stop() async {
    try {
      await _audioPlayer.stop();
      _isSpeaking = false;
      onSpeakingStateChanged?.call(false);
      debugPrint('[GoogleCloudTTS] Stopped speaking');
    } catch (e) {
      debugPrint('[GoogleCloudTTS] Stop error: $e');
    }
  }

  /// Check if currently speaking
  bool get isSpeaking => _isSpeaking;

  /// Check if service is ready
  bool get isReady => _isInitialized && _apiKey != null;

  // ==================== Usage Tracking ====================

  /// Check usage before speaking
  Future<bool> _checkUsageBeforeSpeaking(int charCount) async {
    final currentUsage = await getCurrentUsage();
    final projectedUsage = currentUsage + charCount;

    // Check if would exceed limit
    if (projectedUsage > _freeCharacterLimit) {
      debugPrint('[GoogleCloudTTS] Would exceed free tier limit');
      return false;
    }

    // Warn if approaching limit
    if (projectedUsage > _warningThreshold) {
      final percentUsed = (projectedUsage / _freeCharacterLimit * 100).round();
      debugPrint('[GoogleCloudTTS] Usage at $percentUsed%');
      onUsageWarning?.call(projectedUsage, _freeCharacterLimit);
    }

    return true;
  }

  /// Update usage after successful speech synthesis
  Future<void> _updateUsage(int charCount) async {
    final prefs = await SharedPreferences.getInstance();
    final currentUsage = prefs.getInt(_usageCountKey) ?? 0;
    await prefs.setInt(_usageCountKey, currentUsage + charCount);
    debugPrint(
      '[GoogleCloudTTS] Usage updated: ${currentUsage + charCount} chars',
    );
  }

  /// Get current month's usage
  Future<int> getCurrentUsage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_usageCountKey) ?? 0;
  }

  /// Get usage percentage
  Future<double> getUsagePercentage() async {
    final usage = await getCurrentUsage();
    return (usage / _freeCharacterLimit) * 100;
  }

  /// Get remaining characters
  Future<int> getRemainingCharacters() async {
    final usage = await getCurrentUsage();
    return _freeCharacterLimit - usage;
  }

  /// Check and reset monthly usage
  Future<void> _checkAndResetMonthlyUsage() async {
    final prefs = await SharedPreferences.getInstance();
    final currentMonth = DateTime.now().month.toString() + DateTime.now().year.toString();
    final storedMonth = prefs.getString(_usageMonthKey);

    if (storedMonth != currentMonth) {
      debugPrint('[GoogleCloudTTS] New month - resetting usage counter');
      await prefs.setInt(_usageCountKey, 0);
      await prefs.setString(_usageMonthKey, currentMonth);
    }
  }

  /// Get usage statistics
  Future<Map<String, dynamic>> getUsageStats() async {
    final usage = await getCurrentUsage();
    return {
      'usedCharacters': usage,
      'remainingCharacters': _freeCharacterLimit - usage,
      'limit': _freeCharacterLimit,
      'percentageUsed': (usage / _freeCharacterLimit * 100).toStringAsFixed(1),
      'warningThreshold': _warningThreshold,
      'isNearLimit': usage > _warningThreshold,
    };
  }

  // ==================== Error Handling ====================

  /// Handle API errors
  void _handleApiError(int statusCode, String responseBody) {
    String errorMessage;

    switch (statusCode) {
      case 400:
        errorMessage = 'Invalid request. Please try again.';
        break;
      case 401:
        errorMessage = 'API key invalid or expired. Please update your API key.';
        break;
      case 403:
        errorMessage =
            'Access denied. Please check API key permissions or billing status.';
        break;
      case 429:
        errorMessage = 'Rate limit exceeded. Please wait a moment.';
        break;
      case 500:
      case 502:
      case 503:
        errorMessage = 'Google Cloud service temporarily unavailable.';
        break;
      default:
        try {
          final error = jsonDecode(responseBody);
          errorMessage = error['error']?['message'] ?? 'Unknown error occurred';
        } catch (_) {
          errorMessage = 'Service error ($statusCode)';
        }
    }

    debugPrint('[GoogleCloudTTS] Error: $errorMessage');
    onError?.call(errorMessage);
  }

  /// Cleanup resources
  Future<void> dispose() async {
    await _audioPlayer.dispose();
    onSpeakingStateChanged = null;
    onError = null;
    onComplete = null;
    onUsageWarning = null;
    debugPrint('[GoogleCloudTTS] Disposed');
  }
}
