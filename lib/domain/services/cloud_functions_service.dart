import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/timezone.dart' as tzlib;
import '../entities/chat_session.dart';

class CloudFunctionsService {
  final FirebaseFunctions _functions;

  CloudFunctionsService() : _functions = FirebaseFunctions.instance;

  /// Send a message to the AI and get a response
  Future<({String response, bool isCrisis})> sendChatMessage({
    required String userId,
    required String sessionId,
    required String message,
    required List<ChatMessage> conversationHistory,
  }) async {
    try {
      // Get user's timezone using flutter_timezone (native platform detection)
      String timezoneName;
      try {
        timezoneName = await FlutterTimezone.getLocalTimezone();
        print('[CloudFunctionsService] Native timezone detected: $timezoneName');
      } catch (e) {
        // Fallback to timezone package (should be set in main.dart)
        timezoneName = tzlib.local.name;
        print('[CloudFunctionsService] Fallback to tzlib.local.name: $timezoneName');
      }
      
      // Additional debug info
      print('[CloudFunctionsService] DateTime.now().timeZoneName: ${DateTime.now().timeZoneName}');
      print('[CloudFunctionsService] Final timezone sent to API: $timezoneName');
      
      // Prepare conversation history for API
      final history = conversationHistory.map((msg) => {
            'role': msg.role,
            'content': msg.content,
          }).toList();

      // Call Cloud Function
      final callable = _functions.httpsCallable('chat');
      final result = await callable.call({
        'userId': userId,
        'sessionId': sessionId,
        'message': message,
        'conversationHistory': history,
        'userTimezone': timezoneName,
      });

      final data = result.data as Map<String, dynamic>;

      if (data['success'] == true) {
        return (
          response: data['aiResponse'] as String,
          isCrisis: data['isCrisis'] as bool? ?? false,
        );
      } else {
        throw Exception(data['error'] ?? 'Failed to get AI response');
      }
    } catch (e) {
      // Return fallback response on error
      return (
        response: 'I apologize, but I\'m having trouble connecting right now. '
            'Please try again in a moment. If you need immediate support, '
            'please contact your local emergency services.',
        isCrisis: false,
      );
    }
  }
}
