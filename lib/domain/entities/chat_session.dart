import 'package:equatable/equatable.dart';

/// Domain entity representing a chat message
class ChatMessage extends Equatable {
  final String id;
  final String role; // 'user', 'assistant', 'system'
  final String content;
  final DateTime timestamp;
  final bool safetyFlagged;

  const ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.timestamp,
    this.safetyFlagged = false,
  });

  bool get isUser => role == 'user';
  bool get isAssistant => role == 'assistant';
  bool get isSystem => role == 'system';

  ChatMessage copyWith({
    String? id,
    String? role,
    String? content,
    DateTime? timestamp,
    bool? safetyFlagged,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      role: role ?? this.role,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      safetyFlagged: safetyFlagged ?? this.safetyFlagged,
    );
  }

  @override
  List<Object?> get props => [
        id,
        role,
        content,
        timestamp,
        safetyFlagged,
      ];
}

/// Domain entity representing a chat session
class ChatSession extends Equatable {
  final String id;
  final String userId;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int messageCount;
  final List<ChatMessage> messages;
  final String? summary;
  final int? moodAtStart;
  final int? moodAtEnd;

  const ChatSession({
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

  bool get isActive => endedAt == null;

  Duration get duration {
    final end = endedAt ?? DateTime.now();
    return end.difference(startedAt);
  }

  ChatSession copyWith({
    String? id,
    String? userId,
    DateTime? startedAt,
    DateTime? endedAt,
    int? messageCount,
    List<ChatMessage>? messages,
    String? summary,
    int? moodAtStart,
    int? moodAtEnd,
  }) {
    return ChatSession(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      messageCount: messageCount ?? this.messageCount,
      messages: messages ?? this.messages,
      summary: summary ?? this.summary,
      moodAtStart: moodAtStart ?? this.moodAtStart,
      moodAtEnd: moodAtEnd ?? this.moodAtEnd,
    );
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        startedAt,
        endedAt,
        messageCount,
        messages,
        summary,
        moodAtStart,
        moodAtEnd,
      ];
}
