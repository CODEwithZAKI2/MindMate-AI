import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/journal_entry.dart';

/// Data model for JournalEntry with Firestore serialization
class JournalEntryModel {
  final String id;
  final String userId;
  final String title;
  final String content;
  final int? moodScore;
  final List<String> tags;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? promptId;
  final String? promptText;
  final bool isFavorite;

  JournalEntryModel({
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

  /// Convert JournalEntry entity to JournalEntryModel
  factory JournalEntryModel.fromEntity(JournalEntry entry) {
    return JournalEntryModel(
      id: entry.id,
      userId: entry.userId,
      title: entry.title,
      content: entry.content,
      moodScore: entry.moodScore,
      tags: entry.tags,
      createdAt: entry.createdAt,
      updatedAt: entry.updatedAt,
      promptId: entry.promptId,
      promptText: entry.promptText,
      isFavorite: entry.isFavorite,
    );
  }

  /// Convert Firestore document to JournalEntryModel
  factory JournalEntryModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return JournalEntryModel(
      id: doc.id,
      userId: data['userId'] as String,
      title: data['title'] as String? ?? 'Untitled',
      content: data['content'] as String? ?? '',
      moodScore: data['moodScore'] as int?,
      tags: List<String>.from(data['tags'] as List? ?? []),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
      promptId: data['promptId'] as String?,
      promptText: data['promptText'] as String?,
      isFavorite: data['isFavorite'] as bool? ?? false,
    );
  }

  /// Convert JournalEntryModel to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'title': title,
      'content': content,
      'moodScore': moodScore,
      'tags': tags,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'promptId': promptId,
      'promptText': promptText,
      'isFavorite': isFavorite,
    };
  }

  /// Convert JournalEntryModel to JournalEntry entity
  JournalEntry toEntity() {
    return JournalEntry(
      id: id,
      userId: userId,
      title: title,
      content: content,
      moodScore: moodScore,
      tags: tags,
      createdAt: createdAt,
      updatedAt: updatedAt,
      promptId: promptId,
      promptText: promptText,
      isFavorite: isFavorite,
    );
  }
}
