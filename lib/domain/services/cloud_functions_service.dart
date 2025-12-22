import 'package:cloud_functions/cloud_functions.dart';
import '../entities/chat_session.dart';
import '../entities/crisis_resource.dart';

class CloudFunctionsService {
  final FirebaseFunctions _functions;

  CloudFunctionsService() : _functions = FirebaseFunctions.instance;

  /// Send a message to the AI and get a response
  Future<({String response, bool isCrisis, CrisisResource? crisisResources})> sendChatMessage({
    required String userId,
    required String sessionId,
    required String message,
    required List<ChatMessage> conversationHistory,
  }) async {
    try {
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
      });

      final data = result.data as Map<String, dynamic>;

      if (data['success'] == true) {
        CrisisResource? crisisResources;
        if (data['crisisResources'] != null) {
          crisisResources = CrisisResource.fromJson(
            data['crisisResources'] as Map<String, dynamic>,
          );
        }

        return (
          response: data['aiResponse'] as String,
          isCrisis: data['isCrisis'] as bool? ?? false,
          crisisResources: crisisResources,
        );
      } else {
        throw Exception(data['error'] ?? 'Failed to get AI response');
      }
    } catch (e) {
      // Return fallback response on error
      return (
        response: 'I apologize, but I\'m having trouble connecting right now. '
            'Please try again in a moment. If you need immediate support, '
            'please call the National Suicide Prevention Lifeline at 988.',
        isCrisis: false,
        crisisResources: null,
      );
    }
  }
}
