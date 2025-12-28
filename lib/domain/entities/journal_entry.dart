import 'package:equatable/equatable.dart';

/// Domain entity representing a journal entry
class JournalEntry extends Equatable {
  final String id;
  final String userId;
  final String title;
  final String content;
  final int? moodScore; // Optional: 1-5 if linked to mood
  final List<String> tags;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? promptId; // ID of AI prompt if entry was prompted
  final String? promptText; // The actual prompt text
  final bool isFavorite;

  const JournalEntry({
    required this.id,
    required this.userId,
    required this.title,
    required this.content,
    this.moodScore,
    this.tags = const [],
    required this.createdAt,
    required this.updatedAt,
    this.promptId,
    this.promptText,
    this.isFavorite = false,
  });

  /// Check if this entry was created from an AI prompt
  bool get isFromPrompt => promptId != null;

  /// Get a preview of the content (first 100 chars)
  String get contentPreview {
    if (content.length <= 100) return content;
    return '${content.substring(0, 100)}...';
  }

  /// Get mood label if mood is linked
  String? get moodLabel {
    if (moodScore == null) return null;
    switch (moodScore) {
      case 1:
        return 'Struggling';
      case 2:
        return 'Low';
      case 3:
        return 'Okay';
      case 4:
        return 'Good';
      case 5:
        return 'Great';
      default:
        return null;
    }
  }

  /// Get time since creation in readable format
  String get timeAgo {
    final now = DateTime.now();
    final diff = now.difference(createdAt);

    if (diff.inDays > 365) {
      return '${(diff.inDays / 365).floor()}y ago';
    } else if (diff.inDays > 30) {
      return '${(diff.inDays / 30).floor()}mo ago';
    } else if (diff.inDays > 0) {
      return '${diff.inDays}d ago';
    } else if (diff.inHours > 0) {
      return '${diff.inHours}h ago';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  JournalEntry copyWith({
    String? id,
    String? userId,
    String? title,
    String? content,
    int? moodScore,
    List<String>? tags,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? promptId,
    String? promptText,
    bool? isFavorite,
  }) {
    return JournalEntry(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      content: content ?? this.content,
      moodScore: moodScore ?? this.moodScore,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      promptId: promptId ?? this.promptId,
      promptText: promptText ?? this.promptText,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }

  @override
  List<Object?> get props => [
    id,
    userId,
    title,
    content,
    moodScore,
    tags,
    createdAt,
    updatedAt,
    promptId,
    promptText,
    isFavorite,
  ];
}
