import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/journal_entry.dart';
import '../models/journal_entry_model.dart';

/// Repository for Journal entries with full CRUD, search, and statistics
class JournalRepository {
  final FirebaseFirestore _firestore;
  static const String _collection = 'journal_entries';

  JournalRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _entriesRef =>
      _firestore.collection(_collection);

  // ========== CRUD Operations ==========

  /// Create a new journal entry
  Future<String> createEntry(JournalEntry entry) async {
    final model = JournalEntryModel.fromEntity(entry);
    final docRef = await _entriesRef.add(model.toFirestore());
    return docRef.id;
  }

  /// Get a single journal entry by ID
  Future<JournalEntry?> getEntry(String entryId) async {
    final doc = await _entriesRef.doc(entryId).get();
    if (!doc.exists) return null;
    return JournalEntryModel.fromFirestore(doc).toEntity();
  }

  /// Update an existing journal entry
  Future<void> updateEntry(JournalEntry entry) async {
    final model = JournalEntryModel.fromEntity(entry);
    await _entriesRef.doc(entry.id).update(model.toFirestore());
  }

  /// Soft delete a journal entry (30-day recovery)
  Future<void> deleteEntry(String entryId) async {
    await _entriesRef.doc(entryId).update({
      'deletedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  /// Permanently delete a journal entry
  Future<void> permanentlyDelete(String entryId) async {
    await _entriesRef.doc(entryId).delete();
  }

  /// Restore a soft-deleted entry
  Future<void> restoreEntry(String entryId) async {
    await _entriesRef.doc(entryId).update({'deletedAt': null});
  }

  // ========== Query Operations ==========

  /// Get all entries for a user (real-time stream, excludes deleted)
  Stream<List<JournalEntry>> getEntriesStream(String userId) {
    return _entriesRef
        .where('userId', isEqualTo: userId)
        .where('deletedAt', isNull: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map((doc) => JournalEntryModel.fromFirestore(doc).toEntity())
                  .toList(),
        );
  }

  /// Get entries with pagination
  Future<List<JournalEntry>> getEntriesPaginated(
    String userId, {
    int limit = 20,
    DocumentSnapshot? startAfter,
  }) async {
    var query = _entriesRef
        .where('userId', isEqualTo: userId)
        .where('deletedAt', isNull: true)
        .orderBy('createdAt', descending: true)
        .limit(limit);

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    final snapshot = await query.get();
    return snapshot.docs
        .map((doc) => JournalEntryModel.fromFirestore(doc).toEntity())
        .toList();
  }

  /// Get entries by date range
  Future<List<JournalEntry>> getEntriesByDateRange(
    String userId,
    DateTime start,
    DateTime end,
  ) async {
    final snapshot =
        await _entriesRef
            .where('userId', isEqualTo: userId)
            .where('deletedAt', isNull: true)
            .where(
              'createdAt',
              isGreaterThanOrEqualTo: Timestamp.fromDate(start),
            )
            .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(end))
            .orderBy('createdAt', descending: true)
            .get();

    return snapshot.docs
        .map((doc) => JournalEntryModel.fromFirestore(doc).toEntity())
        .toList();
  }

  /// Get favorite entries
  Future<List<JournalEntry>> getFavoriteEntries(String userId) async {
    final snapshot =
        await _entriesRef
            .where('userId', isEqualTo: userId)
            .where('isFavorite', isEqualTo: true)
            .where('deletedAt', isNull: true)
            .orderBy('createdAt', descending: true)
            .get();

    return snapshot.docs
        .map((doc) => JournalEntryModel.fromFirestore(doc).toEntity())
        .toList();
  }

  /// Get entries for a specific month (for calendar view)
  Future<List<JournalEntry>> getEntriesForMonth(
    String userId,
    int year,
    int month,
  ) async {
    final start = DateTime(year, month, 1);
    final end = DateTime(year, month + 1, 0, 23, 59, 59);
    return getEntriesByDateRange(userId, start, end);
  }

  /// Search entries by content or title
  Future<List<JournalEntry>> searchEntries(String userId, String query) async {
    // Firestore doesn't support full-text search, so we fetch and filter locally
    final allEntries =
        await _entriesRef
            .where('userId', isEqualTo: userId)
            .where('deletedAt', isNull: true)
            .orderBy('createdAt', descending: true)
            .get();

    final queryLower = query.toLowerCase();
    return allEntries.docs
        .map((doc) => JournalEntryModel.fromFirestore(doc).toEntity())
        .where(
          (entry) =>
              entry.title.toLowerCase().contains(queryLower) ||
              entry.content.toLowerCase().contains(queryLower) ||
              entry.tags.any((tag) => tag.toLowerCase().contains(queryLower)),
        )
        .toList();
  }

  // ========== AI Reflection Operations ==========

  /// Save AI reflection for an entry
  Future<void> saveAIReflection(
    String entryId,
    String toneSummary,
    List<String> reflectionQuestions,
  ) async {
    await _entriesRef.doc(entryId).update({
      'aiReflection': {
        'toneSummary': toneSummary,
        'reflectionQuestions': reflectionQuestions,
        'generatedAt': Timestamp.fromDate(DateTime.now()),
      },
    });
  }

  /// Save safety flags for an entry
  Future<void> saveSafetyFlags(String entryId, bool crisisDetected) async {
    await _entriesRef.doc(entryId).update({
      'safetyFlags': {
        'crisisDetected': crisisDetected,
        'processedAt': Timestamp.fromDate(DateTime.now()),
      },
    });
  }

  // ========== Statistics ==========

  /// Get journal statistics for a user
  Future<Map<String, dynamic>> getStatistics(String userId) async {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final monthStart = DateTime(now.year, now.month, 1);

    // Get all entries
    final allSnapshot =
        await _entriesRef
            .where('userId', isEqualTo: userId)
            .where('deletedAt', isNull: true)
            .get();

    final entries =
        allSnapshot.docs
            .map((doc) => JournalEntryModel.fromFirestore(doc).toEntity())
            .toList();

    // Calculate stats
    final entriesThisWeek =
        entries.where((e) => e.createdAt.isAfter(weekStart)).length;
    final entriesThisMonth =
        entries.where((e) => e.createdAt.isAfter(monthStart)).length;
    final favoriteCount = entries.where((e) => e.isFavorite).length;

    // Calculate streak
    int streak = 0;
    DateTime checkDate = DateTime(now.year, now.month, now.day);
    while (true) {
      final hasEntry = entries.any(
        (e) =>
            e.createdAt.year == checkDate.year &&
            e.createdAt.month == checkDate.month &&
            e.createdAt.day == checkDate.day,
      );
      if (hasEntry) {
        streak++;
        checkDate = checkDate.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }

    // Word count
    final totalWords = entries.fold<int>(0, (sum, e) => sum + e.wordCount);

    // Tag frequency
    final tagCounts = <String, int>{};
    for (final entry in entries) {
      for (final tag in entry.tags) {
        tagCounts[tag] = (tagCounts[tag] ?? 0) + 1;
      }
    }
    final sortedTags =
        tagCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    return {
      'totalEntries': entries.length,
      'entriesThisWeek': entriesThisWeek,
      'entriesThisMonth': entriesThisMonth,
      'favoriteCount': favoriteCount,
      'currentStreak': streak,
      'totalWords': totalWords,
      'averageWordsPerEntry':
          entries.isEmpty ? 0 : totalWords ~/ entries.length,
      'topTags': sortedTags.take(5).map((e) => e.key).toList(),
    };
  }

  /// Toggle favorite status
  Future<void> toggleFavorite(String entryId, bool isFavorite) async {
    await _entriesRef.doc(entryId).update({'isFavorite': isFavorite});
  }

  /// Toggle lock status
  Future<void> toggleLock(String entryId, bool isLocked) async {
    await _entriesRef.doc(entryId).update({'isLocked': isLocked});
  }
}
