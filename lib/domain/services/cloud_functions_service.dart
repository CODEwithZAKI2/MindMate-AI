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

  /// Timeout duration for cloud function calls (reduced for faster error detection)
  static const Duration _timeout = Duration(seconds: 15);

  CloudFunctionsService() : _functions = FirebaseFunctions.instance;

  /// Check if device has network connectivity by trying multiple methods
  Future<bool> _hasNetworkConnection() async {
    try {
      // Try to connect to multiple hosts to ensure we're really online
      final hosts = ['8.8.8.8', '1.1.1.1', 'google.com'];

      for (final host in hosts) {
        try {
          final result = await InternetAddress.lookup(
            host,
          ).timeout(const Duration(seconds: 3));
          if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
            print(
              '[CloudFunctionsService] Network check passed with host: $host',
            );
            return true;
          }
        } catch (_) {
          // Try next host
          continue;
        }
      }

      // All hosts failed
      print(
        '[CloudFunctionsService] Network check failed - no hosts reachable',
      );
      return false;
    } catch (e) {
      print('[CloudFunctionsService] Network check error: $e');
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
    print('[CloudFunctionsService] Starting sendChatMessage...');

    // Check network connectivity first
    final hasNetwork = await _hasNetworkConnection();
    print('[CloudFunctionsService] Network check result: $hasNetwork');

    if (!hasNetwork) {
      print('[CloudFunctionsService] No network - throwing NetworkException');
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

      print('[CloudFunctionsService] Calling Cloud Function...');

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
              print('[CloudFunctionsService] Request timed out');
              throw TimeoutException('Request timed out. Please try again.');
            },
          );

      print('[CloudFunctionsService] Got response from Cloud Function');
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
      if (e.code == 'unavailable' ||
          e.code == 'deadline-exceeded' ||
          e.code == 'internal' ||
          e.code == 'unknown') {
        throw NetworkException(
          'Unable to connect to server. Please check your internet connection.',
        );
      }
      throw AIServiceException(e.message ?? 'Service error occurred');
    } on SocketException catch (e) {
      print('[CloudFunctionsService] SocketException: $e');
      throw NetworkException(
        'No internet connection. Please check your network and try again.',
      );
    } on TimeoutException catch (e) {
      print('[CloudFunctionsService] TimeoutException: $e');
      throw NetworkException(
        'Connection timed out. Please check your network and try again.',
      );
    } on HttpException catch (e) {
      print('[CloudFunctionsService] HttpException: $e');
      throw NetworkException(
        'Network error. Please check your connection and try again.',
      );
    } catch (e) {
      print('[CloudFunctionsService] Unexpected error: $e (${e.runtimeType})');
      // Check if it's a network-related error by examining the error message
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('network') ||
          errorStr.contains('socket') ||
          errorStr.contains('connection') ||
          errorStr.contains('host') ||
          errorStr.contains('timeout') ||
          errorStr.contains('unreachable')) {
        throw NetworkException(
          'Network error. Please check your connection and try again.',
        );
      }
      throw AIServiceException('Something went wrong. Please try again.');
    }
  }
}
