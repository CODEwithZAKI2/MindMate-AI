import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/chat_session.dart';

/// Data model for ChatMessage with Firestore serialization
class ChatMessageModel {
  final String id;
  final String role;
  final String content;
  final DateTime timestamp;
  final bool safetyFlagged;

  ChatMessageModel({
    required this.id,
    required this.role,
    required this.content,
    required this.timestamp,
    this.safetyFlagged = false,
  });

  factory ChatMessageModel.fromEntity(ChatMessage message) {
    return ChatMessageModel(
      id: message.id,
      role: message.role,
      content: message.content,
      timestamp: message.timestamp,
      safetyFlagged: message.safetyFlagged,
    );
  }

  factory ChatMessageModel.fromMap(Map<String, dynamic> data) {
    return ChatMessageModel(
      id: data['id'] as String,
      role: data['role'] as String,
      content: data['content'] as String,
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      safetyFlagged: data['safetyFlagged'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'role': role,
      'content': content,
      'timestamp': Timestamp.fromDate(timestamp),
      'safetyFlagged': safetyFlagged,
    };
  }

  ChatMessage toEntity() {
    return ChatMessage(
      id: id,
      role: role,
      content: content,
      timestamp: timestamp,
      safetyFlagged: safetyFlagged,
    );
  }
}

/// Data model for ChatSession with Firestore serialization
class ChatSessionModel {
  final String id;
  final String userId;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int messageCount;
  final List<ChatMessageModel> messages;
  final String? summary;
  final int? moodAtStart;
  final int? moodAtEnd;

  ChatSessionModel({
    required this.id,
    required this.userId,
    required this.startedAt,
    this.endedAt,
    required this.messageCount,
    required this.messages,
    this.summary,
    this.moodAtStart,
    this.moodAtEnd,
  });

  factory ChatSessionModel.fromEntity(ChatSession session) {
    return ChatSessionModel(
      id: session.id,
      userId: session.userId,
      startedAt: session.startedAt,
      endedAt: session.endedAt,
      messageCount: session.messageCount,
      messages: session.messages
          .map((msg) => ChatMessageModel.fromEntity(msg))
          .toList(),
      summary: session.summary,
      moodAtStart: session.moodAtStart,
      moodAtEnd: session.moodAtEnd,
    );
  }

  factory ChatSessionModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ChatSessionModel(
      id: doc.id,
      userId: data['userId'] as String,
      startedAt: (data['startedAt'] as Timestamp).toDate(),
      endedAt: data['endedAt'] != null
          ? (data['endedAt'] as Timestamp).toDate()
          : null,
      messageCount: data['messageCount'] as int,
      messages: (data['messages'] as List? ?? [])
          .map((msg) =>
              ChatMessageModel.fromMap(msg as Map<String, dynamic>))
          .toList(),
      summary: data['summary'] as String?,
      moodAtStart: data['moodAtStart'] as int?,
      moodAtEnd: data['moodAtEnd'] as int?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'startedAt': Timestamp.fromDate(startedAt),
      'endedAt': endedAt != null ? Timestamp.fromDate(endedAt!) : null,
      'messageCount': messageCount,
      'messages': messages.map((msg) => msg.toMap()).toList(),
      'summary': summary,
      'moodAtStart': moodAtStart,
      'moodAtEnd': moodAtEnd,
    };
  }

  ChatSession toEntity() {
    return ChatSession(
      id: id,
      userId: userId,
      startedAt: startedAt,
      endedAt: endedAt,
      messageCount: messageCount,
      messages: messages.map((msg) => msg.toEntity()).toList(),
      summary: summary,
      moodAtStart: moodAtStart,
      moodAtEnd: moodAtEnd,
    );
  }
}
