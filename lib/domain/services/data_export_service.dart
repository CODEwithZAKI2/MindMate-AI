import 'dart:convert';
import '../../data/repositories/user_repository.dart';
import '../../data/repositories/mood_repository.dart';
import '../../data/repositories/chat_repository.dart';

/// Service for exporting user data and account deletion
class DataExportService {
  final UserRepository _userRepository;
  final MoodRepository _moodRepository;
  final ChatRepository _chatRepository;

  DataExportService({
    required UserRepository userRepository,
    required MoodRepository moodRepository,
    required ChatRepository chatRepository,
  })  : _userRepository = userRepository,
        _moodRepository = moodRepository,
        _chatRepository = chatRepository;

  /// Export all user data as JSON
  Future<String> exportUserData(String userId) async {
    try {
      // Fetch all user data
      final user = await _userRepository.getUserById(userId);
      final moodLogs = await _moodRepository.getAllMoodLogs(userId: userId);
      final chatSessions = await _chatRepository.getUserChatSessions(
        userId: userId,
        limit: 1000, // Get all sessions
      );

      // Build export data structure
      final exportData = {
        'exportDate': DateTime.now().toIso8601String(),
        'user': {
          'id': user.id,
          'email': user.email,
          'displayName': user.displayName,
          'createdAt': user.createdAt.toIso8601String(),
        },
        'moodLogs': moodLogs.map((log) => {
          'id': log.id,
          'moodScore': log.moodScore,
          'moodLabel': log.moodLabel,
          'tags': log.tags,
          'note': log.note,
          'createdAt': log.createdAt.toIso8601String(),
          'source': log.source,
        }).toList(),
        'chatSessions': chatSessions.map((session) => {
          'id': session.id,
          'startedAt': session.startedAt.toIso8601String(),
          'endedAt': session.endedAt?.toIso8601String(),
          'lastMessageAt': session.lastMessageAt?.toIso8601String(),
          'messageCount': session.messageCount,
          'summary': session.summary,
          'moodAtStart': session.moodAtStart,
          'moodAtEnd': session.moodAtEnd,
          'messages': session.messages.map((msg) => {
            'role': msg.role,
            'content': msg.content,
            'timestamp': msg.timestamp.toIso8601String(),
            'safetyFlagged': msg.safetyFlagged,
          }).toList(),
        }).toList(),
        'statistics': {
          'totalMoodLogs': moodLogs.length,
          'totalChatSessions': chatSessions.length,
          'totalMessages': chatSessions.fold<int>(
            0,
            (sum, session) => sum + session.messageCount,
          ),
        },
      };

      // Convert to pretty JSON
      return const JsonEncoder.withIndent('  ').convert(exportData);
    } catch (e) {
      throw Exception('Failed to export data: $e');
    }
  }

  /// Delete all user data from Firestore
  Future<void> deleteAllUserData(String userId) async {
    try {
      // Delete all mood logs
      final moodLogs = await _moodRepository.getAllMoodLogs(userId: userId);
      for (final log in moodLogs) {
        await _moodRepository.deleteMoodLog(log.id);
      }

      // Delete all chat sessions
      final chatSessions = await _chatRepository.getUserChatSessions(
        userId: userId,
        limit: 1000,
      );
      for (final session in chatSessions) {
        await _chatRepository.deleteChatSession(session.id);
      }

      // Delete user document
      await _userRepository.deleteUser(userId);
    } catch (e) {
      throw Exception('Failed to delete user data: $e');
    }
  }
}
