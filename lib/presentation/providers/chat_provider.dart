import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/chat_session.dart';
import '../../data/repositories/chat_repository.dart';

/// Provider for ChatRepository
final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository();
});

/// Provider for network connectivity status
final connectivityProvider = StreamProvider<List<ConnectivityResult>>((ref) {
  return Connectivity().onConnectivityChanged;
});

/// Provider for checking if currently online
final isOnlineProvider = Provider<bool>((ref) {
  final connectivity = ref.watch(connectivityProvider);
  return connectivity.when(
    data: (results) => !results.contains(ConnectivityResult.none),
    loading: () => true, // Assume online while loading
    error: (_, __) => true, // Assume online on error
  );
});

/// Stream provider for user chat sessions
final chatSessionsStreamProvider =
    StreamProvider.family<List<ChatSession>, String>((ref, userId) {
      final chatRepository = ref.watch(chatRepositoryProvider);
      return chatRepository.getChatSessionsStream(userId);
    });

/// Future provider for active chat session
final activeChatSessionProvider = FutureProvider.family<ChatSession?, String>((
  ref,
  userId,
) {
  final chatRepository = ref.watch(chatRepositoryProvider);
  return chatRepository.getActiveChatSession(userId);
});

/// Future provider for chat session by ID
final chatSessionProvider = FutureProvider.family<ChatSession, String>((
  ref,
  sessionId,
) {
  final chatRepository = ref.watch(chatRepositoryProvider);
  return chatRepository.getChatSession(sessionId);
});

/// Stream provider for chat session by ID (real-time updates)
final chatSessionStreamProvider = StreamProvider.family<ChatSession, String>((
  ref,
  sessionId,
) {
  final chatRepository = ref.watch(chatRepositoryProvider);
  return chatRepository.getChatSessionStream(sessionId);
});

/// Future provider for chat statistics
final chatStatisticsProvider = FutureProvider.family<
  Map<String, dynamic>,
  ({String userId, DateTime startDate, DateTime endDate})
>((ref, params) {
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

/// Model for a pending message in the queue
class PendingMessage {
  final String id;
  final String content;
  final DateTime timestamp;
  final String sessionId;
  final String userId;
  final int retryCount;
  final bool isSending;

  PendingMessage({
    required this.id,
    required this.content,
    required this.timestamp,
    required this.sessionId,
    required this.userId,
    this.retryCount = 0,
    this.isSending = false,
  });

  PendingMessage copyWith({
    String? id,
    String? content,
    DateTime? timestamp,
    String? sessionId,
    String? userId,
    int? retryCount,
    bool? isSending,
  }) {
    return PendingMessage(
      id: id ?? this.id,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      sessionId: sessionId ?? this.sessionId,
      userId: userId ?? this.userId,
      retryCount: retryCount ?? this.retryCount,
      isSending: isSending ?? this.isSending,
    );
  }
}

/// Provider for tracking pending messages (offline queue)
final pendingMessagesProvider =
    StateNotifierProvider<PendingMessagesNotifier, List<PendingMessage>>((ref) {
      return PendingMessagesNotifier();
    });

/// Notifier for pending messages queue
class PendingMessagesNotifier extends StateNotifier<List<PendingMessage>> {
  PendingMessagesNotifier() : super([]);

  void addPendingMessage(PendingMessage message) {
    // Don't add duplicate messages
    if (state.any((m) => m.id == message.id)) return;
    state = [...state, message];
  }

  void removePendingMessage(String id) {
    state = state.where((m) => m.id != id).toList();
  }

  void markAsSending(String id) {
    state =
        state.map((m) {
          if (m.id == id) {
            return m.copyWith(isSending: true);
          }
          return m;
        }).toList();
  }

  void markAsNotSending(String id) {
    state =
        state.map((m) {
          if (m.id == id) {
            return m.copyWith(isSending: false, retryCount: m.retryCount + 1);
          }
          return m;
        }).toList();
  }

  void clearPendingMessages() {
    state = [];
  }

  PendingMessage? getPendingMessage(String id) {
    try {
      return state.firstWhere((m) => m.id == id);
    } catch (e) {
      return null;
    }
  }

  List<PendingMessage> getPendingForSession(String sessionId) {
    return state.where((m) => m.sessionId == sessionId).toList();
  }
}

/// Model for a failed message that can be retried (legacy - for compatibility)
class FailedMessage {
  final String id;
  final String content;
  final DateTime timestamp;
  final String sessionId;
  final String userId;

  FailedMessage({
    required this.id,
    required this.content,
    required this.timestamp,
    required this.sessionId,
    required this.userId,
  });
}

/// Provider for tracking failed messages (legacy - for compatibility)
final failedMessagesProvider =
    StateNotifierProvider<FailedMessagesNotifier, List<FailedMessage>>((ref) {
      return FailedMessagesNotifier();
    });

/// Notifier for failed messages (legacy - for compatibility)
class FailedMessagesNotifier extends StateNotifier<List<FailedMessage>> {
  FailedMessagesNotifier() : super([]);

  void addFailedMessage(FailedMessage message) {
    state = [...state, message];
  }

  void removeFailedMessage(String id) {
    state = state.where((m) => m.id != id).toList();
  }

  void clearFailedMessages() {
    state = [];
  }

  FailedMessage? getFailedMessage(String id) {
    try {
      return state.firstWhere((m) => m.id == id);
    } catch (e) {
      return null;
    }
  }
}
