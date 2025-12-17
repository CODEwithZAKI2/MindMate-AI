import 'package:equatable/equatable.dart';

/// Domain entity representing a mood log entry
class MoodLog extends Equatable {
  final String id;
  final String userId;
  final int moodScore; // 1-5 (1=Very Bad, 5=Very Good)
  final String? note;
  final List<String> tags;
  final DateTime createdAt;
  final String source; // 'manual' or 'chat_derived'

  const MoodLog({
    required this.id,
    required this.userId,
    required this.moodScore,
    this.note,
    this.tags = const [],
    required this.createdAt,
    this.source = 'manual',
  });

  bool get isValid => moodScore >= 1 && moodScore <= 5;

  String get moodLabel {
    switch (moodScore) {
      case 1:
        return 'Very Bad';
      case 2:
        return 'Bad';
      case 3:
        return 'Okay';
      case 4:
        return 'Good';
      case 5:
        return 'Very Good';
      default:
        return 'Unknown';
    }
  }

  MoodLog copyWith({
    String? id,
    String? userId,
    int? moodScore,
    String? note,
    List<String>? tags,
    DateTime? createdAt,
    String? source,
  }) {
    return MoodLog(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      moodScore: moodScore ?? this.moodScore,
      note: note ?? this.note,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      source: source ?? this.source,
    );
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        moodScore,
        note,
        tags,
        createdAt,
        source,
      ];
}
