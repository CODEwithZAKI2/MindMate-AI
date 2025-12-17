import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/mood_log.dart';

/// Data model for MoodLog with Firestore serialization
class MoodLogModel {
  final String id;
  final String userId;
  final int moodScore;
  final String? note;
  final List<String> tags;
  final DateTime createdAt;
  final String source;

  MoodLogModel({
    required this.id,
    required this.userId,
    required this.moodScore,
    this.note,
    this.tags = const [],
    required this.createdAt,
    this.source = 'manual',
  });

  /// Convert MoodLog entity to MoodLogModel
  factory MoodLogModel.fromEntity(MoodLog moodLog) {
    return MoodLogModel(
      id: moodLog.id,
      userId: moodLog.userId,
      moodScore: moodLog.moodScore,
      note: moodLog.note,
      tags: moodLog.tags,
      createdAt: moodLog.createdAt,
      source: moodLog.source,
    );
  }

  /// Convert Firestore document to MoodLogModel
  factory MoodLogModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MoodLogModel(
      id: doc.id,
      userId: data['userId'] as String,
      moodScore: data['moodScore'] as int,
      note: data['note'] as String?,
      tags: List<String>.from(data['tags'] as List? ?? []),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      source: data['source'] as String? ?? 'manual',
    );
  }

  /// Convert MoodLogModel to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'moodScore': moodScore,
      'note': note,
      'tags': tags,
      'createdAt': Timestamp.fromDate(createdAt),
      'source': source,
    };
  }

  /// Convert MoodLogModel to MoodLog entity
  MoodLog toEntity() {
    return MoodLog(
      id: id,
      userId: userId,
      moodScore: moodScore,
      note: note,
      tags: tags,
      createdAt: createdAt,
      source: source,
    );
  }
}
