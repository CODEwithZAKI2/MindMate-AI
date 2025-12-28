import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/journal_entry.dart';
import '../../data/repositories/journal_repository.dart';

/// Provider for JournalRepository
final journalRepositoryProvider = Provider<JournalRepository>((ref) {
  return JournalRepository();
});

/// Stream provider for user journal entries
final journalEntriesStreamProvider =
    StreamProvider.family<List<JournalEntry>, String>((ref, userId) {
      final repository = ref.watch(journalRepositoryProvider);
      return repository.getJournalEntriesStream(userId);
    });

/// Future provider for journal statistics
final journalStatisticsProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, userId) {
      final repository = ref.watch(journalRepositoryProvider);
      return repository.getJournalStatistics(userId);
    });

/// Future provider for favorite entries
final favoriteEntriesProvider =
    FutureProvider.family<List<JournalEntry>, String>((ref, userId) {
      final repository = ref.watch(journalRepositoryProvider);
      return repository.getFavoriteEntries(userId);
    });

/// Future provider for recent entries (last 7 days)
final recentEntriesProvider = FutureProvider.family<List<JournalEntry>, String>(
  (ref, userId) {
    final repository = ref.watch(journalRepositoryProvider);
    return repository.getRecentEntries(userId);
  },
);

/// Search results provider
final journalSearchResultsProvider =
    FutureProvider.family<List<JournalEntry>, ({String userId, String query})>((
      ref,
      params,
    ) {
      final repository = ref.watch(journalRepositoryProvider);
      return repository.searchJournalEntries(
        userId: params.userId,
        query: params.query,
      );
    });

/// State notifier for journal actions
class JournalNotifier extends StateNotifier<AsyncValue<void>> {
  final JournalRepository _repository;

  JournalNotifier(this._repository) : super(const AsyncValue.data(null));

  /// Create a new journal entry
  Future<String> createEntry(JournalEntry entry) async {
    state = const AsyncValue.loading();
    try {
      final entryId = await _repository.createJournalEntry(entry);
      state = const AsyncValue.data(null);
      return entryId;
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      rethrow;
    }
  }

  /// Update an existing journal entry
  Future<void> updateEntry(JournalEntry entry) async {
    state = const AsyncValue.loading();
    try {
      await _repository.updateJournalEntry(entry);
      state = const AsyncValue.data(null);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      rethrow;
    }
  }

  /// Delete a journal entry
  Future<void> deleteEntry(String entryId) async {
    state = const AsyncValue.loading();
    try {
      await _repository.deleteJournalEntry(entryId);
      state = const AsyncValue.data(null);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      rethrow;
    }
  }

  /// Toggle favorite status
  Future<void> toggleFavorite(String entryId, bool isFavorite) async {
    try {
      await _repository.toggleFavorite(entryId, isFavorite);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      rethrow;
    }
  }

  /// Get a single journal entry
  Future<JournalEntry> getEntry(String entryId) async {
    return _repository.getJournalEntry(entryId);
  }

  /// Search entries
  Future<List<JournalEntry>> searchEntries({
    required String userId,
    required String query,
  }) async {
    return _repository.searchJournalEntries(userId: userId, query: query);
  }
}

/// Provider for JournalNotifier
final journalNotifierProvider =
    StateNotifierProvider<JournalNotifier, AsyncValue<void>>((ref) {
      final repository = ref.watch(journalRepositoryProvider);
      return JournalNotifier(repository);
    });

/// Provider for the currently selected/editing journal entry
final currentJournalEntryProvider = StateProvider<JournalEntry?>((ref) => null);

/// Provider for journal entry editor state
final journalEditorStateProvider = StateProvider<JournalEditorState>((ref) {
  return JournalEditorState();
});

/// State class for journal entry editor
class JournalEditorState {
  final String title;
  final String content;
  final int? moodScore;
  final List<String> tags;
  final bool isEditing;

  JournalEditorState({
    this.title = '',
    this.content = '',
    this.moodScore,
    this.tags = const [],
    this.isEditing = false,
  });

  JournalEditorState copyWith({
    String? title,
    String? content,
    int? moodScore,
    List<String>? tags,
    bool? isEditing,
  }) {
    return JournalEditorState(
      title: title ?? this.title,
      content: content ?? this.content,
      moodScore: moodScore ?? this.moodScore,
      tags: tags ?? this.tags,
      isEditing: isEditing ?? this.isEditing,
    );
  }

  void reset() {
    // Reset is handled by replacing the provider state
  }
}

/// AI-generated journal prompts
final aiJournalPromptsProvider = Provider<List<String>>((ref) {
  // These will be replaced by AI-generated prompts based on mood
  return [
    "What made you smile today?",
    "Describe a moment when you felt at peace.",
    "What are you grateful for right now?",
    "What's been on your mind lately?",
    "Write about something that challenged you today.",
    "What would you tell your younger self?",
    "Describe your ideal day.",
    "What emotions are you carrying today?",
    "Write about a goal you're working towards.",
    "What brings you comfort?",
  ];
});

/// Selected AI prompt for new entry
final selectedPromptProvider = StateProvider<String?>((ref) => null);
