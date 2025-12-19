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
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => MoodLogModel.fromFirestore(doc).toEntity())
            .toList());
  }

  // Get all mood logs for a user (for data export)
  Future<List<MoodLog>> getAllMoodLogs({required String userId}) async {
    final snapshot = await _firestore
        .collection('mood_logs')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => MoodLogModel.fromFirestore(doc).toEntity())
        .toList();
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
      .orderBy('createdAt', descending: true)
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
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
        .orderBy('createdAt', descending: true)
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

  // Compute mood insights for a given window
  Future<Map<String, dynamic>> getMoodInsights({
    required String userId,
    required int days,
  }) async {
    final now = DateTime.now();
    final startDate = now.subtract(Duration(days: days));
    final logs = await getMoodLogsByDateRange(
      userId: userId,
      startDate: startDate,
      endDate: now,
    );

    if (logs.isEmpty) {
      return {
        'averageMood': 0.0,
        'totalLogs': 0,
        'currentStreak': 0,
        'bestDay': null,
        'worstDay': null,
        'bestWeekday': null,
        'commonTags': <String>[],
        'weekOverWeekChange': 0.0,
      };
    }

    // Group logs by date (YYYY-MM-DD)
    final dailyGroups = <String, List<MoodLog>>{};
    for (final log in logs) {
      final key = DateTime(log.createdAt.year, log.createdAt.month, log.createdAt.day)
          .toIso8601String();
      dailyGroups.putIfAbsent(key, () => []).add(log);
    }

    // Daily averages for best/worst day
    final dailyAverages = dailyGroups.entries.map((entry) {
      final avg = entry.value.fold<int>(0, (t, l) => t + l.moodScore) / entry.value.length;
      return {'dateKey': entry.key, 'avg': avg};
    }).toList();

    dailyAverages.sort((a, b) => (b['avg'] as double).compareTo(a['avg'] as double));
    final bestDay = dailyAverages.first;
    final worstDay = dailyAverages.last;

    // Current streak (consecutive days with at least one log, counting back from today)
    final uniqueDates = dailyGroups.keys
        .map((k) => DateTime.parse(k))
        .toList()
      ..sort((a, b) => b.compareTo(a));

    int streak = 0;
    DateTime cursor = DateTime(now.year, now.month, now.day);
    for (final date in uniqueDates) {
      if (date.isAtSameMomentAs(cursor)) {
        streak += 1;
        cursor = cursor.subtract(const Duration(days: 1));
      } else if (date.isAtSameMomentAs(cursor.subtract(const Duration(days: 1)))) {
        streak += 1;
        cursor = cursor.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }

    // Common tags (top 5)
    final tagCounts = <String, int>{};
    for (final log in logs) {
      for (final tag in log.tags) {
        tagCounts[tag] = (tagCounts[tag] ?? 0) + 1;
      }
    }
    final commonTags = tagCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Best weekday by average mood
    final weekdayScores = <int, List<int>>{}; // 1=Mon..7=Sun
    for (final log in logs) {
      final weekday = log.createdAt.weekday;
      weekdayScores.putIfAbsent(weekday, () => []).add(log.moodScore);
    }
    int? bestWeekday;
    double bestWeekdayAvg = -1;
    weekdayScores.forEach((weekday, scores) {
      final avg = scores.reduce((a, b) => a + b) / scores.length;
      if (avg > bestWeekdayAvg) {
        bestWeekdayAvg = avg;
        bestWeekday = weekday;
      }
    });

    // Week-over-week change (last 7 vs previous 7 days within window)
    double _avgForRange(DateTime start, DateTime end) {
      final rangeLogs = logs.where((log) =>
          log.createdAt.isAfter(start.subtract(const Duration(milliseconds: 1))) &&
          log.createdAt.isBefore(end.add(const Duration(milliseconds: 1))));
      if (rangeLogs.isEmpty) return 0;
      return rangeLogs.fold<int>(0, (t, l) => t + l.moodScore) / rangeLogs.length;
    }

    final last7Start = now.subtract(const Duration(days: 7));
    final prev7Start = now.subtract(const Duration(days: 14));
    final last7Avg = _avgForRange(last7Start, now);
    final prev7Avg = _avgForRange(prev7Start, last7Start);
    final weekOverWeekChange = prev7Avg > 0 ? ((last7Avg - prev7Avg) / prev7Avg) * 100 : 0.0;

    return {
      'averageMood': logs.fold<int>(0, (t, l) => t + l.moodScore) / logs.length,
      'totalLogs': logs.length,
      'currentStreak': streak,
      'bestDay': bestDay,
      'worstDay': worstDay,
      'bestWeekday': bestWeekday,
      'commonTags': commonTags.take(5).map((e) => e.key).toList(),
      'weekOverWeekChange': weekOverWeekChange,
    };
  }
}
