import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../domain/entities/journal_entry.dart';
import '../../providers/auth_provider.dart';
import '../../providers/journal_provider.dart';
import '../../../core/constants/routes.dart';

class JournalScreen extends ConsumerStatefulWidget {
  const JournalScreen({super.key});

  @override
  ConsumerState<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends ConsumerState<JournalScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  String _searchQuery = '';
  bool _showSearch = false;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final userId = ref.watch(currentUserIdProvider);

    if (userId == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final entriesAsync = ref.watch(journalEntriesStreamProvider(userId));
    final statsAsync = ref.watch(journalStatisticsProvider(userId));

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: CustomScrollView(
        slivers: [
          // Premium App Bar
          SliverAppBar(
            expandedHeight: 180,
            floating: false,
            pinned: true,
            backgroundColor: theme.colorScheme.surface,
            surfaceTintColor: Colors.transparent,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFFE8F5E9),
                      const Color(0xFFC8E6C9).withOpacity(0.5),
                      theme.colorScheme.surface,
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Journal',
                              style: theme.textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                              ),
                            ),
                            // Search toggle
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.8),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: IconButton(
                                icon: Icon(
                                  _showSearch
                                      ? Icons.close
                                      : Icons.search_rounded,
                                  color: theme.colorScheme.primary,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _showSearch = !_showSearch;
                                    if (!_showSearch) {
                                      _searchQuery = '';
                                      _searchController.clear();
                                    }
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Stats row
                        statsAsync.when(
                          data: (stats) => _buildStatsRow(stats, theme),
                          loading: () => _buildStatsRowPlaceholder(theme),
                          error: (_, __) => const SizedBox.shrink(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Search bar (if visible)
          if (_showSearch)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: _buildSearchBar(theme),
              ),
            ),

          // Entries list
          entriesAsync.when(
            data: (entries) {
              final filteredEntries =
                  _searchQuery.isEmpty
                      ? entries
                      : entries
                          .where(
                            (e) =>
                                e.title.toLowerCase().contains(
                                  _searchQuery.toLowerCase(),
                                ) ||
                                e.content.toLowerCase().contains(
                                  _searchQuery.toLowerCase(),
                                ),
                          )
                          .toList();

              if (filteredEntries.isEmpty) {
                return SliverFillRemaining(child: _buildEmptyState(theme));
              }

              return SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final entry = filteredEntries[index];
                    return FadeTransition(
                      opacity: _fadeAnimation,
                      child: _buildJournalCard(entry, theme, index),
                    );
                  }, childCount: filteredEntries.length),
                ),
              );
            },
            loading:
                () => const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                ),
            error:
                (error, _) => SliverFillRemaining(
                  child: Center(child: Text('Error: $error')),
                ),
          ),

          // Bottom padding
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
      floatingActionButton: _buildFAB(theme),
    );
  }

  Widget _buildStatsRow(Map<String, dynamic> stats, ThemeData theme) {
    return Row(
      children: [
        _buildStatChip(
          '${stats['totalEntries'] ?? 0}',
          'entries',
          Icons.book_rounded,
          const Color(0xFF66BB6A),
          theme,
        ),
        const SizedBox(width: 12),
        _buildStatChip(
          '${stats['currentStreak'] ?? 0}',
          'day streak',
          Icons.local_fire_department_rounded,
          const Color(0xFFFF7043),
          theme,
        ),
        const SizedBox(width: 12),
        _buildStatChip(
          '${stats['entriesThisWeek'] ?? 0}',
          'this week',
          Icons.calendar_today_rounded,
          const Color(0xFF42A5F5),
          theme,
        ),
      ],
    );
  }

  Widget _buildStatChip(
    String value,
    String label,
    IconData icon,
    Color color,
    ThemeData theme,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.15),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(
              value,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsRowPlaceholder(ThemeData theme) {
    return Row(
      children: List.generate(
        3,
        (index) => Expanded(
          child: Container(
            height: 70,
            margin: EdgeInsets.only(right: index < 2 ? 12 : 0),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.5),
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.1)),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (value) => setState(() => _searchQuery = value),
        decoration: InputDecoration(
          hintText: 'Search your journal...',
          prefixIcon: Icon(
            Icons.search_rounded,
            color: theme.colorScheme.onSurface.withOpacity(0.5),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildJournalCard(JournalEntry entry, ThemeData theme, int index) {
    final dateFormat = DateFormat('MMM d, yyyy');
    final timeFormat = DateFormat('h:mm a');

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.push('${Routes.journalEntry}/${entry.id}'),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: theme.colorScheme.outline.withOpacity(0.08),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row
                Row(
                  children: [
                    // Date badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        dateFormat.format(entry.createdAt),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const Spacer(),
                    // Time
                    Text(
                      timeFormat.format(entry.createdAt),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.5),
                      ),
                    ),
                    // Favorite indicator
                    if (entry.isFavorite)
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Icon(
                          Icons.favorite_rounded,
                          size: 16,
                          color: Colors.red.shade400,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),

                // Title
                Text(
                  entry.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),

                // Content preview
                Text(
                  entry.contentPreview,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                    height: 1.5,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),

                // Tags and mood
                if (entry.tags.isNotEmpty || entry.moodScore != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      // Mood indicator
                      if (entry.moodScore != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _getMoodColor(
                              entry.moodScore!,
                            ).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _getMoodIcon(entry.moodScore!),
                                size: 14,
                                color: _getMoodColor(entry.moodScore!),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                entry.moodLabel ?? '',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: _getMoodColor(entry.moodScore!),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      // Tags
                      ...entry.tags
                          .take(2)
                          .map(
                            (tag) => Container(
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    theme.colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '#$tag',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.6),
                                ),
                              ),
                            ),
                          ),
                      if (entry.tags.length > 2)
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Text(
                            '+${entry.tags.length - 2}',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurface.withOpacity(
                                0.4,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],

                // AI prompt indicator
                if (entry.isFromPrompt) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        Icons.auto_awesome_rounded,
                        size: 14,
                        color: theme.colorScheme.tertiary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Written from AI prompt',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.tertiary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.book_outlined,
              size: 64,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            _searchQuery.isEmpty ? 'Start Your Journal' : 'No entries found',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isEmpty
                ? 'Capture your thoughts and feelings'
                : 'Try a different search term',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          if (_searchQuery.isEmpty) ...[
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => context.push(Routes.journalEntry),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Write First Entry'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFAB(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary,
            theme.colorScheme.primary.withOpacity(0.85),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withOpacity(0.4),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: FloatingActionButton.extended(
        onPressed: () => context.push(Routes.journalEntry),
        backgroundColor: Colors.transparent,
        elevation: 0,
        icon: const Icon(Icons.edit_rounded, color: Colors.white),
        label: const Text(
          'New Entry',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Color _getMoodColor(int score) {
    switch (score) {
      case 1:
        return const Color(0xFFB5838D);
      case 2:
        return const Color(0xFFE5989B);
      case 3:
        return const Color(0xFFB8C0A9);
      case 4:
        return const Color(0xFF8CB369);
      case 5:
        return const Color(0xFF6A9B7E);
      default:
        return const Color(0xFFB8C0A9);
    }
  }

  IconData _getMoodIcon(int score) {
    switch (score) {
      case 1:
        return Icons.sentiment_very_dissatisfied_rounded;
      case 2:
        return Icons.sentiment_dissatisfied_rounded;
      case 3:
        return Icons.sentiment_neutral_rounded;
      case 4:
        return Icons.sentiment_satisfied_rounded;
      case 5:
        return Icons.sentiment_very_satisfied_rounded;
      default:
        return Icons.sentiment_neutral_rounded;
    }
  }
}
