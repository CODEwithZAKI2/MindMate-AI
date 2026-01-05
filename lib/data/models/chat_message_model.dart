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
    // Firestore Timestamp.toDate() returns DateTime in local timezone
    return ChatMessageModel(
      id: data['id'] as String? ?? '',
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
      // Store timestamp directly - Firestore handles timezone conversion
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
  final String? title;
  final DateTime startedAt;
  final DateTime? endedAt;
  final DateTime? lastMessageAt;
  final int messageCount;
  final List<ChatMessageModel> messages;
  final String? summary;
  final int? moodAtStart;
  final int? moodAtEnd;

  ChatSessionModel({
    required this.id,
    required this.userId,
    this.title,
    required this.startedAt,
    this.endedAt,
    this.lastMessageAt,
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
      title: session.title,
      startedAt: session.startedAt,
      endedAt: session.endedAt,
      lastMessageAt: session.lastMessageAt,
      messageCount: session.messageCount,
      messages:
          session.messages
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
      title: data['title'] as String?,
      startedAt: data['startedAt'] != null
          ? (data['startedAt'] as Timestamp).toDate().toLocal()
          : (data['createdAt'] != null 
              ? (data['createdAt'] as Timestamp).toDate().toLocal()
              : DateTime.now()),
      endedAt:
          data['endedAt'] != null
              ? (data['endedAt'] as Timestamp).toDate().toLocal()
              : null,
      lastMessageAt:
          data['lastMessageAt'] != null
              ? (data['lastMessageAt'] as Timestamp).toDate().toLocal()
              : null,
      messageCount: data['messageCount'] as int,
      messages:
          (data['messages'] as List? ?? [])
              .map(
                (msg) => ChatMessageModel.fromMap(msg as Map<String, dynamic>),
              )
              .toList(),
      summary: data['summary'] as String?,
      moodAtStart: data['moodAtStart'] as int?,
      moodAtEnd: data['moodAtEnd'] as int?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'title': title,
      'startedAt': Timestamp.fromDate(startedAt),
      'endedAt': endedAt != null ? Timestamp.fromDate(endedAt!) : null,
      'lastMessageAt':
          lastMessageAt != null ? Timestamp.fromDate(lastMessageAt!) : null,
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
      title: title,
      startedAt: startedAt,
      endedAt: endedAt,
      lastMessageAt: lastMessageAt,
      messageCount: messageCount,
      messages: messages.map((msg) => msg.toEntity()).toList(),
      summary: summary,
      moodAtStart: moodAtStart,
      moodAtEnd: moodAtEnd,
    );
  }
}
