import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/mood_log_model.dart';
import '../../domain/entities/mood_log.dart';

/// Repository for mood log management
class MoodRepository {
  final FirebaseFirestore _firestore;

  MoodRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  // Create mood log
  Future<String> createMoodLog(MoodLog moodLog) async {
    final model = MoodLogModel.fromEntity(moodLog);
    final docRef = await _firestore
        .collection('mood_logs')
        .add(model.toFirestore());
    return docRef.id;
  }

  // Get mood log by ID
  Future<MoodLog> getMoodLog(String logId) async {
    final doc = await _firestore.collection('mood_logs').doc(logId).get();
    if (!doc.exists) {
      throw Exception('Mood log not found');
    }
    return MoodLogModel.fromFirestore(doc).toEntity();
  }

  // Get user mood logs stream (real-time)
  Stream<List<MoodLog>> getMoodLogsStream(String userId) {
    return _firestore
        .collection('mood_logs')
        .where('userId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => MoodLogModel.fromFirestore(doc).toEntity())
            .toList());
  }

  // Get user mood logs (paginated)
  Future<List<MoodLog>> getUserMoodLogs({
    required String userId,
    int limit = 50,
    DocumentSnapshot? startAfter,
  }) async {
    Query query = _firestore
        .collection('mood_logs')
        .where('userId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .limit(limit);

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    final snapshot = await query.get();
    return snapshot.docs
        .map((doc) => MoodLogModel.fromFirestore(doc).toEntity())
        .toList();
  }

  // Get mood logs for date range
  Future<List<MoodLog>> getMoodLogsByDateRange({
    required String userId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final snapshot = await _firestore
        .collection('mood_logs')
        .where('userId', isEqualTo: userId)
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
        .orderBy('timestamp', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => MoodLogModel.fromFirestore(doc).toEntity())
        .toList();
  }

  // Get last 7 days mood logs
  Future<List<MoodLog>> getLast7DaysMoodLogs(String userId) async {
    final now = DateTime.now();
    final sevenDaysAgo = now.subtract(const Duration(days: 7));
    
    return await getMoodLogsByDateRange(
      userId: userId,
      startDate: sevenDaysAgo,
      endDate: now,
    );
  }

  // Get last 30 days mood logs
  Future<List<MoodLog>> getLast30DaysMoodLogs(String userId) async {
    final now = DateTime.now();
    final thirtyDaysAgo = now.subtract(const Duration(days: 30));
    
    return await getMoodLogsByDateRange(
      userId: userId,
      startDate: thirtyDaysAgo,
      endDate: now,
    );
  }

  // Update mood log
  Future<void> updateMoodLog(MoodLog moodLog) async {
    final model = MoodLogModel.fromEntity(moodLog);
    await _firestore
        .collection('mood_logs')
        .doc(moodLog.id)
        .update(model.toFirestore());
  }

  // Delete mood log
  Future<void> deleteMoodLog(String logId) async {
    await _firestore.collection('mood_logs').doc(logId).delete();
  }

  // Get mood statistics
  Future<Map<String, dynamic>> getMoodStatistics({
    required String userId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final logs = await getMoodLogsByDateRange(
      userId: userId,
      startDate: startDate,
      endDate: endDate,
    );

    if (logs.isEmpty) {
      return {
        'averageMood': 0.0,
        'totalLogs': 0,
        'moodDistribution': <int, int>{},
        'commonTags': <String>[],
      };
    }

    // Calculate average mood
    final totalMood = logs.fold<int>(0, (total, log) => total + log.moodScore);
    final averageMood = totalMood / logs.length;

    // Calculate mood distribution
    final moodDistribution = <int, int>{};
    for (var log in logs) {
      moodDistribution[log.moodScore] = (moodDistribution[log.moodScore] ?? 0) + 1;
    }

    // Get common tags
    final allTags = logs.expand((log) => log.tags).toList();
    final tagCounts = <String, int>{};
    for (var tag in allTags) {
      tagCounts[tag] = (tagCounts[tag] ?? 0) + 1;
    }
    final commonTags = tagCounts.entries
        .toList()
        ..sort((a, b) => b.value.compareTo(a.value));

    return {
      'averageMood': averageMood,
      'totalLogs': logs.length,
      'moodDistribution': moodDistribution,
      'commonTags': commonTags.take(5).map((e) => e.key).toList(),
    };
  }

  // Get mood trend (comparing periods)
  Future<Map<String, dynamic>> getMoodTrend({
    required String userId,
    required int days,
  }) async {
    final now = DateTime.now();
    final periodStart = now.subtract(Duration(days: days));
    final previousPeriodStart = now.subtract(Duration(days: days * 2));

    final currentPeriodLogs = await getMoodLogsByDateRange(
      userId: userId,
      startDate: periodStart,
      endDate: now,
    );

    final previousPeriodLogs = await getMoodLogsByDateRange(
      userId: userId,
      startDate: previousPeriodStart,
      endDate: periodStart,
    );

    double currentAverage = 0;
    double previousAverage = 0;

    if (currentPeriodLogs.isNotEmpty) {
      currentAverage = currentPeriodLogs
              .fold<int>(0, (total, log) => total + log.moodScore) /
          currentPeriodLogs.length;
    }

    if (previousPeriodLogs.isNotEmpty) {
      previousAverage = previousPeriodLogs
              .fold<int>(0, (total, log) => total + log.moodScore) /
          previousPeriodLogs.length;
    }

    final change = currentAverage - previousAverage;
    final percentChange = previousAverage > 0 ? (change / previousAverage) * 100 : 0;

    return {
      'currentAverage': currentAverage,
      'previousAverage': previousAverage,
      'change': change,
      'percentChange': percentChange,
      'trend': change > 0 ? 'improving' : change < 0 ? 'declining' : 'stable',
    };
  }
}
