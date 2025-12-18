import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/chat_message_model.dart';
import '../../domain/entities/chat_session.dart';

/// Repository for chat session and message management
class ChatRepository {
  final FirebaseFirestore _firestore;

  ChatRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  // Create new chat session
  Future<String> createChatSession(ChatSession session) async {
    final model = ChatSessionModel.fromEntity(session);
    final docRef = await _firestore
        .collection('chat_sessions')
        .add(model.toFirestore());
    return docRef.id;
  }

  // Get chat session by ID
  Future<ChatSession> getChatSession(String sessionId) async {
    final doc = await _firestore.collection('chat_sessions').doc(sessionId).get();
    if (!doc.exists) {
      throw Exception('Chat session not found');
    }
    return ChatSessionModel.fromFirestore(doc).toEntity();
  }

  // Get chat session stream (real-time updates)
  Stream<ChatSession> getChatSessionStream(String sessionId) {
    return _firestore
        .collection('chat_sessions')
        .doc(sessionId)
        .snapshots()
        .map((doc) {
      if (!doc.exists) {
        throw Exception('Chat session not found');
      }
      return ChatSessionModel.fromFirestore(doc).toEntity();
    });
  }

  // Get user chat sessions stream (real-time)
  Stream<List<ChatSession>> getChatSessionsStream(String userId) {
    return _firestore
        .collection('chat_sessions')
        .where('userId', isEqualTo: userId)
        .orderBy('startedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ChatSessionModel.fromFirestore(doc).toEntity())
            .toList());
  }

  // Get user chat sessions
  Future<List<ChatSession>> getUserChatSessions({
    required String userId,
    int limit = 50,
    DocumentSnapshot? startAfter,
  }) async {
    Query query = _firestore
        .collection('chat_sessions')
        .where('userId', isEqualTo: userId)
        .orderBy('startedAt', descending: true)
        .limit(limit);

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    final snapshot = await query.get();
    return snapshot.docs
        .map((doc) => ChatSessionModel.fromFirestore(doc).toEntity())
        .toList();
  }

  // Get active chat session
  Future<ChatSession?> getActiveChatSession(String userId) async {
    final snapshot = await _firestore
        .collection('chat_sessions')
        .where('userId', isEqualTo: userId)
        .where('endedAt', isNull: true)
        .orderBy('startedAt', descending: true)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) {
      return null;
    }

    return ChatSessionModel.fromFirestore(snapshot.docs.first).toEntity();
  }

  // Add message to session
  Future<void> addMessageToSession({
    required String sessionId,
    required ChatMessage message,
  }) async {
    final messageModel = ChatMessageModel.fromEntity(message);
    await _firestore.collection('chat_sessions').doc(sessionId).update({
      'messages': FieldValue.arrayUnion([messageModel.toMap()]),
      'messageCount': FieldValue.increment(1),
    });
  }

  // Update session
  Future<void> updateChatSession(ChatSession session) async {
    final model = ChatSessionModel.fromEntity(session);
    await _firestore
        .collection('chat_sessions')
        .doc(session.id)
        .update(model.toFirestore());
  }

  // End chat session
  Future<void> endChatSession({
    required String sessionId,
    String? summary,
    int? moodAtEnd,
  }) async {
    await _firestore.collection('chat_sessions').doc(sessionId).update({
      'endedAt': FieldValue.serverTimestamp(),
      if (summary != null) 'summary': summary,
      if (moodAtEnd != null) 'moodAtEnd': moodAtEnd,
    });
  }

  // Delete chat session
  Future<void> deleteChatSession(String sessionId) async {
    await _firestore.collection('chat_sessions').doc(sessionId).delete();
  }

  // Get sessions by date range
  Future<List<ChatSession>> getChatSessionsByDateRange({
    required String userId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final snapshot = await _firestore
        .collection('chat_sessions')
        .where('userId', isEqualTo: userId)
        .where('startedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('startedAt', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
        .orderBy('startedAt', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => ChatSessionModel.fromFirestore(doc).toEntity())
        .toList();
  }

  // Get chat statistics
  Future<Map<String, dynamic>> getChatStatistics({
    required String userId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final sessions = await getChatSessionsByDateRange(
      userId: userId,
      startDate: startDate,
      endDate: endDate,
    );

    final totalSessions = sessions.length;
    final totalMessages = sessions.fold<int>(
      0,
      (total, session) => total + session.messageCount,
    );

    final averageMessagesPerSession =
        totalSessions > 0 ? totalMessages / totalSessions : 0;

    final sessionsWithMood = sessions.where((s) => s.moodAtEnd != null).length;
    final averageMood = sessionsWithMood > 0
        ? sessions
                .where((s) => s.moodAtEnd != null)
                .fold<double>(0.0, (total, s) => total + s.moodAtEnd!) /
            sessionsWithMood
        : 0.0;

    final flaggedSessions = sessions.where((s) => s.messages.any((m) => m.safetyFlagged)).length;

    return {
      'totalSessions': totalSessions,
      'totalMessages': totalMessages,
      'averageMessagesPerSession': averageMessagesPerSession,
      'averageMood': averageMood,
      'flaggedSessions': flaggedSessions,
    };
  }

  // Delete old sessions (for privacy retention)
  Future<int> deleteOldSessions({
    required String userId,
    required int retentionDays,
  }) async {
    final cutoffDate = DateTime.now().subtract(Duration(days: retentionDays));
    
    final snapshot = await _firestore
        .collection('chat_sessions')
        .where('userId', isEqualTo: userId)
        .where('startedAt', isLessThan: Timestamp.fromDate(cutoffDate))
        .get();

    final batch = _firestore.batch();
    for (var doc in snapshot.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();
    return snapshot.docs.length;
  }

  // Get flagged sessions (sessions with safety-flagged messages)
  Future<List<ChatSession>> getFlaggedSessions(String userId) async {
    final allSessions = await getUserChatSessions(userId: userId, limit: 100);
    
    // Filter sessions that have at least one safety-flagged message
    return allSessions
        .where((session) => session.messages.any((msg) => msg.safetyFlagged))
        .toList();
  }
}
