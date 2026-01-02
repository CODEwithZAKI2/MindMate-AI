import 'package:equatable/equatable.dart';

/// AI Reflection data generated after journal entry save
class AIReflection extends Equatable {
  final String toneSummary;
  final List<String> reflectionQuestions;
  final DateTime generatedAt;

  const AIReflection({
    required this.toneSummary,
    required this.reflectionQuestions,
    required this.generatedAt,
  });

  @override
  List<Object?> get props => [toneSummary, reflectionQuestions, generatedAt];
}

/// Safety flags for crisis detection
class SafetyFlags extends Equatable {
  final bool crisisDetected;
  final DateTime processedAt;

  const SafetyFlags({required this.crisisDetected, required this.processedAt});

  @override
  List<Object?> get props => [crisisDetected, processedAt];
}

/// Journal Entry entity with full schema as per specification
class JournalEntry extends Equatable {
  final String id;
  final String userId;
  final String title;
  final String content;

  // Mood integration
  final int? moodScore; // 1-5 inline selection
  final String? linkedMoodLogId; // Links to existing mood_logs

  // Organization
  final List<String> tags;
  final bool isFavorite;
  final bool isLocked; // Entry-level privacy

  // AI data
  final String? promptId;
  final String? promptText;
  final AIReflection? aiReflection;

  // Voice
  final bool hasVoiceRecording;
  final String? voiceFilePath;
  final String? voiceTranscript;

  // Image
  final String? imageUrl;

  // Timestamps
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt; // Soft delete

  // Safety
  final SafetyFlags? safetyFlags;

  const JournalEntry({
    required this.id,
    required this.userId,
    required this.title,
    required this.content,
    this.moodScore,
    this.linkedMoodLogId,
    this.tags = const [],
    this.isFavorite = false,
    this.isLocked = false,
    this.promptId,
    this.promptText,
    this.aiReflection,
    this.hasVoiceRecording = false,
    this.voiceFilePath,
    this.voiceTranscript,
    this.imageUrl,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    this.safetyFlags,
  });

  /// Check if entry was created from AI prompt
  bool get isFromPrompt => promptId != null || promptText != null;

  /// Check if entry has AI reflection
  bool get hasReflection => aiReflection != null;

  /// Check if entry is soft deleted
  bool get isDeleted => deletedAt != null;

  /// Get content preview (first 100 chars)
  String get contentPreview {
    if (content.isEmpty) return '';
    return content.length > 100 ? '${content.substring(0, 100)}...' : content;
  }

  /// Get mood label from score
  String? get moodLabel {
    if (moodScore == null) return null;
    switch (moodScore) {
      case 1:
        return 'Sad';
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

  /// Get relative time string
  String get timeAgo {
    final now = DateTime.now();
    final diff = now.difference(createdAt);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${(diff.inDays / 7).floor()}w ago';
  }

  /// Get word count
  int get wordCount {
    if (content.isEmpty) return 0;
    return content.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
  }

  JournalEntry copyWith({
    String? id,
    String? userId,
    String? title,
    String? content,
    int? moodScore,
    String? linkedMoodLogId,
    List<String>? tags,
    bool? isFavorite,
    bool? isLocked,
    String? promptId,
    String? promptText,
    AIReflection? aiReflection,
    bool? hasVoiceRecording,
    String? voiceFilePath,
    String? voiceTranscript,
    String? imageUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
    SafetyFlags? safetyFlags,
  }) {
    return JournalEntry(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      content: content ?? this.content,
      moodScore: moodScore ?? this.moodScore,
      linkedMoodLogId: linkedMoodLogId ?? this.linkedMoodLogId,
      tags: tags ?? this.tags,
      isFavorite: isFavorite ?? this.isFavorite,
      isLocked: isLocked ?? this.isLocked,
      promptId: promptId ?? this.promptId,
      promptText: promptText ?? this.promptText,
      aiReflection: aiReflection ?? this.aiReflection,
      hasVoiceRecording: hasVoiceRecording ?? this.hasVoiceRecording,
      voiceFilePath: voiceFilePath ?? this.voiceFilePath,
      voiceTranscript: voiceTranscript ?? this.voiceTranscript,
      imageUrl: imageUrl ?? this.imageUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      safetyFlags: safetyFlags ?? this.safetyFlags,
    );
  }

  @override
  List<Object?> get props => [
    id,
    userId,
    title,
    content,
    moodScore,
    linkedMoodLogId,
    tags,
    isFavorite,
    isLocked,
    promptId,
    promptText,
    aiReflection,
    hasVoiceRecording,
    voiceFilePath,
    voiceTranscript,
    imageUrl,
    createdAt,
    updatedAt,
    deletedAt,
    safetyFlags,
  ];
}
