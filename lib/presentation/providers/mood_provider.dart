import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/mood_log.dart';
import '../../data/repositories/mood_repository.dart';

/// Provider for MoodRepository
final moodRepositoryProvider = Provider<MoodRepository>((ref) {
  return MoodRepository();
});

/// Stream provider for user mood logs
final moodLogsStreamProvider =
    StreamProvider.family<List<MoodLog>, String>((ref, userId) {
  final moodRepository = ref.watch(moodRepositoryProvider);
  return moodRepository.getMoodLogsStream(userId);
});

/// Future provider for last 7 days mood logs
final last7DaysMoodLogsProvider =
    FutureProvider.family<List<MoodLog>, String>((ref, userId) {
  final moodRepository = ref.watch(moodRepositoryProvider);
  return moodRepository.getLast7DaysMoodLogs(userId);
});

/// Future provider for last 30 days mood logs
final last30DaysMoodLogsProvider =
    FutureProvider.family<List<MoodLog>, String>((ref, userId) {
  final moodRepository = ref.watch(moodRepositoryProvider);
  return moodRepository.getLast30DaysMoodLogs(userId);
});

/// Future provider for mood statistics
final moodStatisticsProvider = FutureProvider.family<Map<String, dynamic>,
    ({String userId, DateTime startDate, DateTime endDate})>((ref, params) {
  final moodRepository = ref.watch(moodRepositoryProvider);
  return moodRepository.getMoodStatistics(
    userId: params.userId,
    startDate: params.startDate,
    endDate: params.endDate,
  );
});

/// Future provider for mood trend
final moodTrendProvider = FutureProvider.family<Map<String, dynamic>,
    ({String userId, int days})>((ref, params) {
  final moodRepository = ref.watch(moodRepositoryProvider);
  return moodRepository.getMoodTrend(
    userId: params.userId,
    days: params.days,
  );
});

/// Future provider for mood insights (patterns, streaks, tags)
final moodInsightsProvider = FutureProvider.family<Map<String, dynamic>,
    ({String userId, int days})>((ref, params) {
  final moodRepository = ref.watch(moodRepositoryProvider);
  return moodRepository.getMoodInsights(
    userId: params.userId,
    days: params.days,
  );
});

/// State notifier for mood actions
class MoodNotifier extends StateNotifier<AsyncValue<void>> {
  final MoodRepository _moodRepository;

  MoodNotifier(this._moodRepository) : super(const AsyncValue.data(null));

  // Create mood log
  Future<String> createMoodLog(MoodLog moodLog) async {
    state = const AsyncValue.loading();
    try {
      final logId = await _moodRepository.createMoodLog(moodLog);
      state = const AsyncValue.data(null);
      return logId;
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      rethrow;
    }
  }

  // Update mood log
  Future<void> updateMoodLog(MoodLog moodLog) async {
    state = const AsyncValue.loading();
    try {
      await _moodRepository.updateMoodLog(moodLog);
      state = const AsyncValue.data(null);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      rethrow;
    }
  }

  // Delete mood log
  Future<void> deleteMoodLog(String logId) async {
    state = const AsyncValue.loading();
    try {
      await _moodRepository.deleteMoodLog(logId);
      state = const AsyncValue.data(null);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      rethrow;
    }
  }

  // Get mood log
  Future<MoodLog> getMoodLog(String logId) async {
    try {
      return await _moodRepository.getMoodLog(logId);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      rethrow;
    }
  }

  // Get user mood logs with pagination
  Future<List<MoodLog>> getUserMoodLogs({
    required String userId,
    int limit = 50,
  }) async {
    try {
      return await _moodRepository.getUserMoodLogs(
        userId: userId,
        limit: limit,
      );
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      rethrow;
    }
  }

  // Get mood logs by date range
  Future<List<MoodLog>> getMoodLogsByDateRange({
    required String userId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      return await _moodRepository.getMoodLogsByDateRange(
        userId: userId,
        startDate: startDate,
        endDate: endDate,
      );
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      rethrow;
    }
  }
}

/// Provider for MoodNotifier
final moodNotifierProvider =
    StateNotifierProvider<MoodNotifier, AsyncValue<void>>((ref) {
  final moodRepository = ref.watch(moodRepositoryProvider);
  return MoodNotifier(moodRepository);
});

/// Provider for current mood score (used during check-in)
final currentMoodScoreProvider = StateProvider<int>((ref) => 3);

/// Provider for current mood tags (used during check-in)
final currentMoodTagsProvider = StateProvider<List<String>>((ref) => []);

/// Provider for current mood note (used during check-in)
final currentMoodNoteProvider = StateProvider<String>((ref) => '');
