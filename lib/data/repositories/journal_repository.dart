import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/journal_entry_model.dart';
import '../../domain/entities/journal_entry.dart';

/// Repository for journal entry management
class JournalRepository {
  final FirebaseFirestore _firestore;

  JournalRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Create a new journal entry
  Future<String> createJournalEntry(JournalEntry entry) async {
    final model = JournalEntryModel.fromEntity(entry);
    final docRef = await _firestore
        .collection('journal_entries')
        .add(model.toFirestore());
    return docRef.id;
  }

  /// Get journal entry by ID
  Future<JournalEntry> getJournalEntry(String entryId) async {
    final doc =
        await _firestore.collection('journal_entries').doc(entryId).get();
    if (!doc.exists) {
      throw Exception('Journal entry not found');
    }
    return JournalEntryModel.fromFirestore(doc).toEntity();
  }

  /// Get user journal entries stream (real-time)
  Stream<List<JournalEntry>> getJournalEntriesStream(String userId) {
    return _firestore
        .collection('journal_entries')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map((doc) => JournalEntryModel.fromFirestore(doc).toEntity())
                  .toList(),
        );
  }

  /// Get all journal entries for a user
  Future<List<JournalEntry>> getAllJournalEntries({
    required String userId,
  }) async {
    final snapshot =
        await _firestore
            .collection('journal_entries')
            .where('userId', isEqualTo: userId)
            .orderBy('createdAt', descending: true)
            .get();

    return snapshot.docs
        .map((doc) => JournalEntryModel.fromFirestore(doc).toEntity())
        .toList();
  }

  /// Get paginated journal entries
  Future<List<JournalEntry>> getJournalEntries({
    required String userId,
    int limit = 20,
    DocumentSnapshot? startAfter,
  }) async {
    Query query = _firestore
        .collection('journal_entries')
        .where('userId', isEqualTo: userId)
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

  /// Get journal entries by date range
  Future<List<JournalEntry>> getJournalEntriesByDateRange({
    required String userId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final snapshot =
        await _firestore
            .collection('journal_entries')
            .where('userId', isEqualTo: userId)
            .where(
              'createdAt',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
            )
            .where(
              'createdAt',
              isLessThanOrEqualTo: Timestamp.fromDate(endDate),
            )
            .orderBy('createdAt', descending: true)
            .get();

    return snapshot.docs
        .map((doc) => JournalEntryModel.fromFirestore(doc).toEntity())
        .toList();
  }

  /// Search journal entries by title or content
  Future<List<JournalEntry>> searchJournalEntries({
    required String userId,
    required String query,
  }) async {
    // Firestore doesn't support full-text search, so we fetch all and filter locally
    // For production, consider Algolia or ElasticSearch
    final allEntries = await getAllJournalEntries(userId: userId);
    final lowerQuery = query.toLowerCase();

    return allEntries.where((entry) {
      return entry.title.toLowerCase().contains(lowerQuery) ||
          entry.content.toLowerCase().contains(lowerQuery) ||
          entry.tags.any((tag) => tag.toLowerCase().contains(lowerQuery));
    }).toList();
  }

  /// Get favorite journal entries
  Future<List<JournalEntry>> getFavoriteEntries(String userId) async {
    final snapshot =
        await _firestore
            .collection('journal_entries')
            .where('userId', isEqualTo: userId)
            .where('isFavorite', isEqualTo: true)
            .orderBy('createdAt', descending: true)
            .get();

    return snapshot.docs
        .map((doc) => JournalEntryModel.fromFirestore(doc).toEntity())
        .toList();
  }

  /// Get recent journal entries (last 7 days)
  Future<List<JournalEntry>> getRecentEntries(String userId) async {
    final now = DateTime.now();
    final sevenDaysAgo = now.subtract(const Duration(days: 7));

    return getJournalEntriesByDateRange(
      userId: userId,
      startDate: sevenDaysAgo,
      endDate: now,
    );
  }

  /// Update journal entry
  Future<void> updateJournalEntry(JournalEntry entry) async {
    final model = JournalEntryModel.fromEntity(entry);
    await _firestore
        .collection('journal_entries')
        .doc(entry.id)
        .update(model.toFirestore());
  }

  /// Toggle favorite status
  Future<void> toggleFavorite(String entryId, bool isFavorite) async {
    await _firestore.collection('journal_entries').doc(entryId).update({
      'isFavorite': isFavorite,
      'updatedAt': Timestamp.now(),
    });
  }

  /// Delete journal entry
  Future<void> deleteJournalEntry(String entryId) async {
    await _firestore.collection('journal_entries').doc(entryId).delete();
  }

  /// Get journal statistics
  Future<Map<String, dynamic>> getJournalStatistics(String userId) async {
    final allEntries = await getAllJournalEntries(userId: userId);

    if (allEntries.isEmpty) {
      return {
        'totalEntries': 0,
        'entriesThisWeek': 0,
        'entriesThisMonth': 0,
        'favoriteCount': 0,
        'averageWordsPerEntry': 0,
        'commonTags': <String>[],
        'currentStreak': 0,
      };
    }

    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));
    final monthAgo = now.subtract(const Duration(days: 30));

    // Calculate entries this week/month
    final entriesThisWeek =
        allEntries.where((e) => e.createdAt.isAfter(weekAgo)).length;
    final entriesThisMonth =
        allEntries.where((e) => e.createdAt.isAfter(monthAgo)).length;
    final favoriteCount = allEntries.where((e) => e.isFavorite).length;

    // Calculate average words per entry
    final totalWords = allEntries.fold<int>(
      0,
      (total, entry) => total + entry.content.split(RegExp(r'\s+')).length,
    );
    final avgWords = totalWords ~/ allEntries.length;

    // Get common tags
    final tagCounts = <String, int>{};
    for (final entry in allEntries) {
      for (final tag in entry.tags) {
        tagCounts[tag] = (tagCounts[tag] ?? 0) + 1;
      }
    }
    final commonTags =
        tagCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    // Calculate streak
    final uniqueDates =
        allEntries
            .map(
              (e) => DateTime(
                e.createdAt.year,
                e.createdAt.month,
                e.createdAt.day,
              ),
            )
            .toSet()
            .toList()
          ..sort((a, b) => b.compareTo(a));

    int streak = 0;
    DateTime cursor = DateTime(now.year, now.month, now.day);
    for (final date in uniqueDates) {
      if (date.isAtSameMomentAs(cursor) ||
          date.isAtSameMomentAs(cursor.subtract(const Duration(days: 1)))) {
        streak++;
        cursor = date.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }

    return {
      'totalEntries': allEntries.length,
      'entriesThisWeek': entriesThisWeek,
      'entriesThisMonth': entriesThisMonth,
      'favoriteCount': favoriteCount,
      'averageWordsPerEntry': avgWords,
      'commonTags': commonTags.take(5).map((e) => e.key).toList(),
      'currentStreak': streak,
    };
  }
}
