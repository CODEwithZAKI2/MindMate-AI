import 'dart:async';
import 'dart:io';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/timezone.dart' as tzlib;
import '../entities/chat_session.dart';

/// Custom exception for network-related errors
class NetworkException implements Exception {
  final String message;
  NetworkException(this.message);

  @override
  String toString() => message;
}

/// Custom exception for AI service errors
class AIServiceException implements Exception {
  final String message;
  AIServiceException(this.message);

  @override
  String toString() => message;
}

class CloudFunctionsService {
  final FirebaseFunctions _functions;

  /// Timeout duration for cloud function calls
  static const Duration _timeout = Duration(seconds: 30);

  CloudFunctionsService() : _functions = FirebaseFunctions.instance;

  /// Check if device has network connectivity
  Future<bool> _hasNetworkConnection() async {
    try {
      final result = await InternetAddress.lookup(
        'google.com',
      ).timeout(const Duration(seconds: 5));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      return false;
    } on TimeoutException catch (_) {
      return false;
    }
  }

  /// Send a message to the AI and get a response
  /// Throws [NetworkException] if no network connection
  /// Throws [AIServiceException] if AI service fails
  Future<({String response, bool isCrisis})> sendChatMessage({
    required String userId,
    required String sessionId,
    required String message,
    required List<ChatMessage> conversationHistory,
  }) async {
    // Check network connectivity first
    final hasNetwork = await _hasNetworkConnection();
    if (!hasNetwork) {
      throw NetworkException(
        'No internet connection. Please check your network and try again.',
      );
    }

    try {
      // Get user's timezone using flutter_timezone (native platform detection)
      String timezoneName;
      try {
        timezoneName = await FlutterTimezone.getLocalTimezone();
        print(
          '[CloudFunctionsService] Native timezone detected: $timezoneName',
        );
      } catch (e) {
        // Fallback to timezone package (should be set in main.dart)
        timezoneName = tzlib.local.name;
        print(
          '[CloudFunctionsService] Fallback to tzlib.local.name: $timezoneName',
        );
      }

      // Additional debug info
      print(
        '[CloudFunctionsService] DateTime.now().timeZoneName: ${DateTime.now().timeZoneName}',
      );
      print(
        '[CloudFunctionsService] Final timezone sent to API: $timezoneName',
      );

      // Prepare conversation history for API
      final history =
          conversationHistory
              .map((msg) => {'role': msg.role, 'content': msg.content})
              .toList();

      // Call Cloud Function with timeout
      final callable = _functions.httpsCallable(
        'chat',
        options: HttpsCallableOptions(timeout: _timeout),
      );

      final result = await callable
          .call({
            'userId': userId,
            'sessionId': sessionId,
            'message': message,
            'conversationHistory': history,
            'userTimezone': timezoneName,
          })
          .timeout(
            _timeout,
            onTimeout: () {
              throw TimeoutException('Request timed out. Please try again.');
            },
          );

      final data = result.data as Map<String, dynamic>;

      if (data['success'] == true) {
        return (
          response: data['aiResponse'] as String,
          isCrisis: data['isCrisis'] as bool? ?? false,
        );
      } else {
        throw AIServiceException(data['error'] ?? 'Failed to get AI response');
      }
    } on FirebaseFunctionsException catch (e) {
      print(
        '[CloudFunctionsService] Firebase Functions error: ${e.code} - ${e.message}',
      );
      if (e.code == 'unavailable' || e.code == 'deadline-exceeded') {
        throw NetworkException(
          'Unable to connect to server. Please check your internet connection.',
        );
      }
      throw AIServiceException(e.message ?? 'Service error occurred');
    } on SocketException catch (_) {
      throw NetworkException(
        'No internet connection. Please check your network and try again.',
      );
    } on TimeoutException catch (_) {
      throw NetworkException(
        'Connection timed out. Please check your network and try again.',
      );
    } catch (e) {
      print('[CloudFunctionsService] Unexpected error: $e');
      throw AIServiceException('Something went wrong. Please try again.');
    }
  }
}
