import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/journal_entry.dart';

/// Firestore model for Journal Entry with full serialization
class JournalEntryModel {
  final String id;
  final String userId;
  final String title;
  final String content;
  final int? moodScore;
  final String? linkedMoodLogId;
  final List<String> tags;
  final bool isFavorite;
  final bool isLocked;
  final String? promptId;
  final String? promptText;
  final Map<String, dynamic>? aiReflection;
  final bool hasVoiceRecording;
  final String? voiceFilePath;
  final String? voiceTranscript;
  final String? imageUrl;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final Map<String, dynamic>? safetyFlags;

  JournalEntryModel({
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

  /// Create model from domain entity
  factory JournalEntryModel.fromEntity(JournalEntry entity) {
    return JournalEntryModel(
      id: entity.id,
      userId: entity.userId,
      title: entity.title,
      content: entity.content,
      moodScore: entity.moodScore,
      linkedMoodLogId: entity.linkedMoodLogId,
      tags: entity.tags,
      isFavorite: entity.isFavorite,
      isLocked: entity.isLocked,
      promptId: entity.promptId,
      promptText: entity.promptText,
      aiReflection:
          entity.aiReflection != null
              ? {
                'toneSummary': entity.aiReflection!.toneSummary,
                'reflectionQuestions': entity.aiReflection!.reflectionQuestions,
                'generatedAt': Timestamp.fromDate(
                  entity.aiReflection!.generatedAt,
                ),
              }
              : null,
      hasVoiceRecording: entity.hasVoiceRecording,
      voiceFilePath: entity.voiceFilePath,
      voiceTranscript: entity.voiceTranscript,
      imageUrl: entity.imageUrl,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
      deletedAt: entity.deletedAt,
      safetyFlags:
          entity.safetyFlags != null
              ? {
                'crisisDetected': entity.safetyFlags!.crisisDetected,
                'processedAt': Timestamp.fromDate(
                  entity.safetyFlags!.processedAt,
                ),
              }
              : null,
    );
  }

  /// Create model from Firestore document
  factory JournalEntryModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return JournalEntryModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      title: data['title'] ?? '',
      content: data['content'] ?? '',
      moodScore: data['moodScore'],
      linkedMoodLogId: data['linkedMoodLogId'],
      tags: List<String>.from(data['tags'] ?? []),
      isFavorite: data['isFavorite'] ?? false,
      isLocked: data['isLocked'] ?? false,
      promptId: data['promptId'],
      promptText: data['promptText'],
      aiReflection: data['aiReflection'],
      hasVoiceRecording: data['hasVoiceRecording'] ?? false,
      voiceFilePath: data['voiceFilePath'],
      voiceTranscript: data['voiceTranscript'],
      imageUrl: data['imageUrl'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      deletedAt: (data['deletedAt'] as Timestamp?)?.toDate(),
      safetyFlags: data['safetyFlags'],
    );
  }

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'title': title,
      'content': content,
      'moodScore': moodScore,
      'linkedMoodLogId': linkedMoodLogId,
      'tags': tags,
      'isFavorite': isFavorite,
      'isLocked': isLocked,
      'promptId': promptId,
      'promptText': promptText,
      'aiReflection': aiReflection,
      'hasVoiceRecording': hasVoiceRecording,
      'voiceFilePath': voiceFilePath,
      'voiceTranscript': voiceTranscript,
      'imageUrl': imageUrl,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'deletedAt': deletedAt != null ? Timestamp.fromDate(deletedAt!) : null,
      'safetyFlags': safetyFlags,
    };
  }

  /// Convert to domain entity
  JournalEntry toEntity() {
    AIReflection? reflection;
    if (aiReflection != null) {
      reflection = AIReflection(
        toneSummary: aiReflection!['toneSummary'] ?? '',
        reflectionQuestions: List<String>.from(
          aiReflection!['reflectionQuestions'] ?? [],
        ),
        generatedAt:
            (aiReflection!['generatedAt'] as Timestamp?)?.toDate() ??
            DateTime.now(),
      );
    }

    SafetyFlags? safety;
    if (safetyFlags != null) {
      safety = SafetyFlags(
        crisisDetected: safetyFlags!['crisisDetected'] ?? false,
        processedAt:
            (safetyFlags!['processedAt'] as Timestamp?)?.toDate() ??
            DateTime.now(),
      );
    }

    return JournalEntry(
      id: id,
      userId: userId,
      title: title,
      content: content,
      moodScore: moodScore,
      linkedMoodLogId: linkedMoodLogId,
      tags: tags,
      isFavorite: isFavorite,
      isLocked: isLocked,
      promptId: promptId,
      promptText: promptText,
      aiReflection: reflection,
      hasVoiceRecording: hasVoiceRecording,
      voiceFilePath: voiceFilePath,
      voiceTranscript: voiceTranscript,
      imageUrl: imageUrl,
      createdAt: createdAt,
      updatedAt: updatedAt,
      deletedAt: deletedAt,
      safetyFlags: safety,
    );
  }
}
