import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/chat_session.dart';
import '../../data/repositories/chat_repository.dart';

/// Provider for ChatRepository
final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository();
});

/// Stream provider for user chat sessions
final chatSessionsStreamProvider =
    StreamProvider.family<List<ChatSession>, String>((ref, userId) {
  final chatRepository = ref.watch(chatRepositoryProvider);
  return chatRepository.getChatSessionsStream(userId);
});

/// Future provider for active chat session
final activeChatSessionProvider =
    FutureProvider.family<ChatSession?, String>((ref, userId) {
  final chatRepository = ref.watch(chatRepositoryProvider);
  return chatRepository.getActiveChatSession(userId);
});

/// Future provider for chat session by ID
final chatSessionProvider =
    FutureProvider.family<ChatSession, String>((ref, sessionId) {
  final chatRepository = ref.watch(chatRepositoryProvider);
  return chatRepository.getChatSession(sessionId);
});

/// Stream provider for chat session by ID (real-time updates)
final chatSessionStreamProvider =
    StreamProvider.family<ChatSession, String>((ref, sessionId) {
  final chatRepository = ref.watch(chatRepositoryProvider);
  return chatRepository.getChatSessionStream(sessionId);
});

/// Future provider for chat statistics
final chatStatisticsProvider = FutureProvider.family<Map<String, dynamic>,
    ({String userId, DateTime startDate, DateTime endDate})>((ref, params) {
  final chatRepository = ref.watch(chatRepositoryProvider);
  return chatRepository.getChatStatistics(
    userId: params.userId,
    startDate: params.startDate,
    endDate: params.endDate,
  );
});

/// Future provider for flagged sessions
final flaggedSessionsProvider =
    FutureProvider.family<List<ChatSession>, String>((ref, userId) {
  final chatRepository = ref.watch(chatRepositoryProvider);
  return chatRepository.getFlaggedSessions(userId);
});

/// State notifier for chat actions
class ChatNotifier extends StateNotifier<AsyncValue<void>> {
  final ChatRepository _chatRepository;

  ChatNotifier(this._chatRepository) : super(const AsyncValue.data(null));

  // Create new chat session
  Future<String> createChatSession(ChatSession session) async {
    state = const AsyncValue.loading();
    try {
      final sessionId = await _chatRepository.createChatSession(session);
      state = const AsyncValue.data(null);
      return sessionId;
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      rethrow;
    }
  }

  // Add message to session
  Future<void> addMessageToSession({
    required String sessionId,
    required ChatMessage message,
  }) async {
    try {
      await _chatRepository.addMessageToSession(
        sessionId: sessionId,
        message: message,
      );
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      rethrow;
    }
  }

  // Update chat session
  Future<void> updateChatSession(ChatSession session) async {
    state = const AsyncValue.loading();
    try {
      await _chatRepository.updateChatSession(session);
      state = const AsyncValue.data(null);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      rethrow;
    }
  }

  // End chat session
  Future<void> endChatSession({
    required String sessionId,
    String? summary,
    int? moodAtEnd,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _chatRepository.endChatSession(
        sessionId: sessionId,
        summary: summary,
        moodAtEnd: moodAtEnd,
      );
      state = const AsyncValue.data(null);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      rethrow;
    }
  }

  // Delete chat session
  Future<void> deleteChatSession(String sessionId) async {
    state = const AsyncValue.loading();
    try {
      await _chatRepository.deleteChatSession(sessionId);
      state = const AsyncValue.data(null);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      rethrow;
    }
  }

  // Get chat session
  Future<ChatSession> getChatSession(String sessionId) async {
    try {
      return await _chatRepository.getChatSession(sessionId);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      rethrow;
    }
  }

  // Get user chat sessions with pagination
  Future<List<ChatSession>> getUserChatSessions({
    required String userId,
    int limit = 50,
  }) async {
    try {
      return await _chatRepository.getUserChatSessions(
        userId: userId,
        limit: limit,
      );
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      rethrow;
    }
  }

  // Delete old sessions for privacy
  Future<int> deleteOldSessions({
    required String userId,
    required int retentionDays,
  }) async {
    try {
      return await _chatRepository.deleteOldSessions(
        userId: userId,
        retentionDays: retentionDays,
      );
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      rethrow;
    }
  }
}

/// Provider for ChatNotifier
final chatNotifierProvider =
    StateNotifierProvider<ChatNotifier, AsyncValue<void>>((ref) {
  final chatRepository = ref.watch(chatRepositoryProvider);
  return ChatNotifier(chatRepository);
});

/// Provider for current active session ID
final currentSessionIdProvider = StateProvider<String?>((ref) => null);

/// Provider for message input controller
final messageInputProvider = StateProvider<String>((ref) => '');

/// Provider for chat loading state
final chatLoadingProvider = StateProvider<bool>((ref) => false);
