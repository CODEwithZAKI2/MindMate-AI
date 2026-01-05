import 'package:equatable/equatable.dart';

/// Status of message sending
enum MessageSendStatus { sending, sent, failed }

/// Domain entity representing a chat message
class ChatMessage extends Equatable {
  final String id;
  final String role; // 'user', 'assistant', 'system'
  final String content;
  final DateTime timestamp;
  final bool safetyFlagged;
  final MessageSendStatus sendStatus;

  const ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.timestamp,
    this.safetyFlagged = false,
    this.sendStatus = MessageSendStatus.sent,
  });

  bool get isUser => role == 'user';
  bool get isAssistant => role == 'assistant';
  bool get isSystem => role == 'system';
  bool get isSending => sendStatus == MessageSendStatus.sending;
  bool get isFailed => sendStatus == MessageSendStatus.failed;

  ChatMessage copyWith({
    String? id,
    String? role,
    String? content,
    DateTime? timestamp,
    bool? safetyFlagged,
    MessageSendStatus? sendStatus,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      role: role ?? this.role,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      safetyFlagged: safetyFlagged ?? this.safetyFlagged,
      sendStatus: sendStatus ?? this.sendStatus,
    );
  }

  @override
  List<Object?> get props => [
    id,
    role,
    content,
    timestamp,
    safetyFlagged,
    sendStatus,
  ];
}

/// Domain entity representing a chat session
class ChatSession extends Equatable {
  final String id;
  final String userId;
  final String? title;
  final DateTime startedAt;
  final DateTime? endedAt;
  final DateTime? lastMessageAt;
  final int messageCount;
  final List<ChatMessage> messages;
  final String? summary;
  final int? moodAtStart;
  final int? moodAtEnd;

  const ChatSession({
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

  bool get isActive => endedAt == null;

  Duration get duration {
    final end = endedAt ?? DateTime.now();
    return end.difference(startedAt);
  }

  ChatSession copyWith({
    String? id,
    String? userId,
    String? title,
    DateTime? startedAt,
    DateTime? endedAt,
    DateTime? lastMessageAt,
    int? messageCount,
    List<ChatMessage>? messages,
    String? summary,
    int? moodAtStart,
    int? moodAtEnd,
  }) {
    return ChatSession(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
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
    title,
    startedAt,
    endedAt,
    lastMessageAt,
    messageCount,
    messages,
    summary,
    moodAtStart,
    moodAtEnd,
  ];
}
