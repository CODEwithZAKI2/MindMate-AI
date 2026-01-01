import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/entities/journal_entry.dart';
import '../../../data/repositories/journal_repository.dart';
import '../../../data/services/journal_ai_service.dart';

/// Repository provider
final journalRepositoryProvider = Provider<JournalRepository>((ref) {
  return JournalRepository();
});

/// AI Service provider
final journalAIServiceProvider = Provider<JournalAIService>((ref) {
  return JournalAIService();
});

/// Real-time stream of journal entries for a user
final journalEntriesStreamProvider =
    StreamProvider.family<List<JournalEntry>, String>((ref, userId) {
      final repository = ref.watch(journalRepositoryProvider);
      return repository.getEntriesStream(userId);
    });

/// Journal statistics
final journalStatisticsProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, userId) {
      final repository = ref.watch(journalRepositoryProvider);
      return repository.getStatistics(userId);
    });

/// Favorite entries
final favoriteEntriesProvider =
    FutureProvider.family<List<JournalEntry>, String>((ref, userId) {
      final repository = ref.watch(journalRepositoryProvider);
      return repository.getFavoriteEntries(userId);
    });

/// Search results
final journalSearchProvider =
    FutureProvider.family<List<JournalEntry>, ({String userId, String query})>((
      ref,
      params,
    ) {
      final repository = ref.watch(journalRepositoryProvider);
      return repository.searchEntries(params.userId, params.query);
    });

/// Entries for a specific month (calendar view)
final monthEntriesProvider = FutureProvider.family<
  List<JournalEntry>,
  ({String userId, int year, int month})
>((ref, params) {
  final repository = ref.watch(journalRepositoryProvider);
  return repository.getEntriesForMonth(
    params.userId,
    params.year,
    params.month,
  );
});

/// Daily AI-generated prompt based on user's journal history
final dailyPromptProvider = FutureProvider.family<SmartPrompt?, String>((
  ref,
  userId,
) async {
  try {
    final aiService = ref.watch(journalAIServiceProvider);
    final prompts = await aiService.generateSmartPrompts(userId: userId);
    if (prompts.isEmpty) return null;
    // Rotate through prompts based on the day of year
    final dayOfYear =
        DateTime.now().difference(DateTime(DateTime.now().year, 1, 1)).inDays;
    return prompts[dayOfYear % prompts.length];
  } catch (_) {
    return null;
  }
});

/// Journal notifier for async operations (create, update, delete)
class JournalNotifier extends StateNotifier<AsyncValue<void>> {
  final JournalRepository _repository;
  final Ref _ref;

  JournalNotifier(this._repository, this._ref)
    : super(const AsyncValue.data(null));

  /// Create a new journal entry
  Future<String> createEntry(JournalEntry entry) async {
    state = const AsyncValue.loading();
    try {
      final entryId = await _repository.createEntry(entry);
      state = const AsyncValue.data(null);
      _invalidateProviders();
      return entryId;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// Get a single entry by ID
  Future<JournalEntry> getEntry(String entryId) async {
    final entry = await _repository.getEntry(entryId);
    if (entry == null) throw Exception('Entry not found');
    return entry;
  }

  /// Update an existing entry
  Future<void> updateEntry(JournalEntry entry) async {
    state = const AsyncValue.loading();
    try {
      await _repository.updateEntry(entry);
      state = const AsyncValue.data(null);
      _invalidateProviders();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// Soft delete an entry
  Future<void> deleteEntry(String entryId) async {
    state = const AsyncValue.loading();
    try {
      await _repository.deleteEntry(entryId);
      state = const AsyncValue.data(null);
      _invalidateProviders();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// Toggle favorite status
  Future<void> toggleFavorite(String entryId, bool isFavorite) async {
    try {
      await _repository.toggleFavorite(entryId, isFavorite);
      _invalidateProviders();
    } catch (e) {
      rethrow;
    }
  }

  /// Toggle lock status
  Future<void> toggleLock(String entryId, bool isLocked) async {
    try {
      await _repository.toggleLock(entryId, isLocked);
      _invalidateProviders();
    } catch (e) {
      rethrow;
    }
  }

  /// Save AI reflection for an entry
  Future<void> saveReflection(
    String entryId,
    String toneSummary,
    List<String> reflectionQuestions,
  ) async {
    try {
      await _repository.saveAIReflection(
        entryId,
        toneSummary,
        reflectionQuestions,
      );
      _invalidateProviders();
    } catch (e) {
      rethrow;
    }
  }

  void _invalidateProviders() {
    _ref.invalidateSelf();
  }
}

final journalNotifierProvider =
    StateNotifierProvider<JournalNotifier, AsyncValue<void>>((ref) {
      final repository = ref.watch(journalRepositoryProvider);
      return JournalNotifier(repository, ref);
    });

/// Currently selected/editing journal entry
final currentJournalEntryProvider = StateProvider<JournalEntry?>((ref) => null);

/// Editor state for the journal entry screen
class JournalEditorState {
  final String title;
  final String content;
  final int? moodScore;
  final List<String> selectedTags;
  final bool isFavorite;
  final bool isLocked;
  final String? promptText;
  final bool hasChanges;
  final bool isLoading;

  const JournalEditorState({
    this.title = '',
    this.content = '',
    this.moodScore,
    this.selectedTags = const [],
    this.isFavorite = false,
    this.isLocked = false,
    this.promptText,
    this.hasChanges = false,
    this.isLoading = false,
  });

  JournalEditorState copyWith({
    String? title,
    String? content,
    int? moodScore,
    List<String>? selectedTags,
    bool? isFavorite,
    bool? isLocked,
    String? promptText,
    bool? hasChanges,
    bool? isLoading,
  }) {
    return JournalEditorState(
      title: title ?? this.title,
      content: content ?? this.content,
      moodScore: moodScore ?? this.moodScore,
      selectedTags: selectedTags ?? this.selectedTags,
      isFavorite: isFavorite ?? this.isFavorite,
      isLocked: isLocked ?? this.isLocked,
      promptText: promptText ?? this.promptText,
      hasChanges: hasChanges ?? this.hasChanges,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

final journalEditorStateProvider = StateProvider<JournalEditorState>(
  (ref) => const JournalEditorState(),
);

/// AI-generated journal prompts (contextual)
final aiJournalPromptsProvider = Provider<List<Map<String, dynamic>>>((ref) {
  // These will be replaced with AI-generated prompts from backend
  return [
    {
      'category': 'gratitude',
      'prompt': 'What are you grateful for today?',
      'icon': 'favorite',
    },
    {
      'category': 'reflection',
      'prompt': 'What moment stood out to you today?',
      'icon': 'lightbulb',
    },
    {
      'category': 'self-compassion',
      'prompt': 'If a friend was feeling this way, what would you tell them?',
      'icon': 'emoji_people',
    },
    {
      'category': 'growth',
      'prompt': 'What\'s one thing you learned about yourself recently?',
      'icon': 'trending_up',
    },
    {
      'category': 'reframing',
      'prompt': 'What\'s one thing that went better than expected?',
      'icon': 'refresh',
    },
    {
      'category': 'mindfulness',
      'prompt': 'How are you feeling right now, in this moment?',
      'icon': 'spa',
    },
    {
      'category': 'dreams',
      'prompt': 'If you could change one thing about today, what would it be?',
      'icon': 'auto_awesome',
    },
    {
      'category': 'challenges',
      'prompt': 'What challenged you today and how did you respond?',
      'icon': 'fitness_center',
    },
  ];
});

/// Selected prompt for the editor
final selectedPromptProvider = StateProvider<Map<String, dynamic>?>(
  (ref) => null,
);

/// Available emotion tags
final availableTagsProvider = Provider<List<String>>((ref) {
  return [
    'Gratitude',
    'Reflection',
    'Goals',
    'Dreams',
    'Growth',
    'Peace',
    'Family',
    'Work',
    'Health',
    'Love',
    'Mindful',
    'Joy',
    'Anxiety',
    'Stress',
    'Hope',
    'Calm',
  ];
});
