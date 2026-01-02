import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../domain/entities/journal_entry.dart';
import '../../providers/auth_provider.dart';
import '../../providers/journal_provider.dart';
import '../../../core/constants/routes.dart';

/// Journal List Screen with Timeline View
/// Follows specification: calm, minimal interface, slow and intentional
class JournalScreen extends ConsumerStatefulWidget {
  const JournalScreen({super.key});

  /// Route observer for auto-refresh functionality
  static final RouteObserver<ModalRoute<void>> routeObserver =
      RouteObserver<ModalRoute<void>>();

  @override
  ConsumerState<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends ConsumerState<JournalScreen>
    with SingleTickerProviderStateMixin, RouteAware {
  String _searchQuery = '';
  bool _showSearch = false;
  final _searchController = TextEditingController();
  late AnimationController _fabController;

  // Calming color palette
  static const _primaryColor = Color(0xFF6366F1); // Indigo
  static const _secondaryColor = Color(0xFF8B5CF6); // Purple
  static const _surfaceColor = Color(0xFFFAFAFC);
  static const _cardColor = Colors.white;

  @override
  void initState() {
    super.initState();
    _fabController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _fabController.forward();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Subscribe to route changes
    final route = ModalRoute.of(context);
    if (route != null) {
      JournalScreen.routeObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    JournalScreen.routeObserver.unsubscribe(this);
    _searchController.dispose();
    _fabController.dispose();
    super.dispose();
  }

  // Called when returning to this screen from another screen
  @override
  void didPopNext() {
    super.didPopNext();
    _refreshData();
  }

  void _refreshData() {
    final userId = ref.read(currentUserIdProvider);
    if (userId != null) {
      // Invalidate providers to trigger refresh
      ref.invalidate(journalStatisticsProvider(userId));
      ref.invalidate(dailyPromptProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(currentUserIdProvider);
    if (userId == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final entriesAsync = ref.watch(journalEntriesStreamProvider(userId));
    final statsAsync = ref.watch(journalStatisticsProvider(userId));

    return Scaffold(
      backgroundColor: _surfaceColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(statsAsync),
            _buildPromptCard(),
            if (_showSearch) _buildSearchBar(),
            _buildSectionHeader(),
            Expanded(child: _buildEntriesList(entriesAsync)),
          ],
        ),
      ),
      floatingActionButton: _buildFAB(),
    );
  }

  Widget _buildHeader(AsyncValue<Map<String, dynamic>> statsAsync) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Journal',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade900,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('EEEE, MMMM d').format(DateTime.now()),
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade500,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  _buildInsightsButton(),
                  const SizedBox(width: 8),
                  _buildCalendarButton(),
                  const SizedBox(width: 8),
                  _buildSearchButton(),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          statsAsync.when(
            data: (stats) => _buildStatsRow(stats),
            loading: () => _buildStatsPlaceholder(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightsButton() {
    return GestureDetector(
      onTap: () => context.push(Routes.journalInsights),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [_primaryColor, _secondaryColor]),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: _primaryColor.withOpacity(0.25),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Icon(
          Icons.insights_rounded,
          color: Colors.white,
          size: 22,
        ),
      ),
    );
  }

  Widget _buildCalendarButton() {
    return GestureDetector(
      onTap: () => context.push(Routes.journalCalendar),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          Icons.calendar_month_rounded,
          color: _primaryColor,
          size: 22,
        ),
      ),
    );
  }

  Widget _buildSearchButton() {
    return GestureDetector(
      onTap:
          () => setState(() {
            _showSearch = !_showSearch;
            if (!_showSearch) {
              _searchQuery = '';
              _searchController.clear();
            }
          }),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          _showSearch ? Icons.close_rounded : Icons.search_rounded,
          color: _primaryColor,
          size: 22,
        ),
      ),
    );
  }

  Widget _buildStatsRow(Map<String, dynamic> stats) {
    return Row(
      children: [
        _buildStatCard(
          '${stats['totalEntries'] ?? 0}',
          'Entries',
          _primaryColor,
        ),
        const SizedBox(width: 12),
        _buildStatCard(
          '${stats['currentStreak'] ?? 0}',
          'Day Streak',
          const Color(0xFFEC4899),
        ),
        const SizedBox(width: 12),
        _buildStatCard(
          '${stats['entriesThisWeek'] ?? 0}',
          'This Week',
          const Color(0xFF06B6D4),
        ),
      ],
    );
  }

  Widget _buildStatCard(String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsPlaceholder() {
    return Row(
      children: List.generate(
        3,
        (i) => Expanded(
          child: Container(
            height: 80,
            margin: EdgeInsets.only(right: i < 2 ? 12 : 0),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPromptCard() {
    final userId = ref.watch(currentUserIdProvider);
    if (userId == null) return const SizedBox.shrink();

    final promptAsync = ref.watch(dailyPromptProvider(userId));

    // Default prompt if AI fetch fails
    final defaultPrompt = 'What are you grateful for today?';
    final displayPrompt = promptAsync.valueOrNull?.prompt ?? defaultPrompt;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      child: GestureDetector(
        onTap: () => context.push(Routes.journalEntry),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_primaryColor, _secondaryColor],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: _primaryColor.withOpacity(0.3),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.auto_awesome,
                            size: 12,
                            color: Colors.white.withOpacity(0.9),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            "Today's Prompt",
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      displayPrompt,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Tap to start writing...',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.edit_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
      child: Container(
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: TextField(
          controller: _searchController,
          onChanged: (v) => setState(() => _searchQuery = v),
          decoration: InputDecoration(
            hintText: 'Search your reflections...',
            hintStyle: TextStyle(color: Colors.grey.shade400),
            prefixIcon: Icon(Icons.search_rounded, color: Colors.grey.shade400),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
      child: Row(
        children: [
          Text(
            'Your Reflections',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade800,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _primaryColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.auto_awesome, size: 12, color: _primaryColor),
                const SizedBox(width: 4),
                Text(
                  'AI Enhanced',
                  style: TextStyle(
                    fontSize: 10,
                    color: _primaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEntriesList(AsyncValue<List<JournalEntry>> entriesAsync) {
    return entriesAsync.when(
      data: (entries) {
        final filtered =
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

        if (filtered.isEmpty) return _buildEmptyState();

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 100),
          physics: const BouncingScrollPhysics(),
          itemCount: filtered.length,
          itemBuilder: (context, index) => _buildEntryCard(filtered[index]),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }

  Widget _buildEntryCard(JournalEntry entry) {
    final moodColor =
        entry.moodScore != null ? _getMoodColor(entry.moodScore!) : null;

    return GestureDetector(
      onTap: () => context.push('${Routes.journalDetail}/${entry.id}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  DateFormat('MMM d').format(entry.createdAt),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _primaryColor,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  DateFormat('h:mm a').format(entry.createdAt),
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                ),
                const Spacer(),
                if (entry.isFavorite)
                  Icon(
                    Icons.favorite_rounded,
                    size: 16,
                    color: Colors.red.shade400,
                  ),
                if (entry.isLocked) ...[
                  const SizedBox(width: 6),
                  Icon(
                    Icons.lock_rounded,
                    size: 16,
                    color: Colors.grey.shade400,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            Text(
              entry.title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade900,
                height: 1.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Text(
              entry.contentPreview,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
                height: 1.5,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (moodColor != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: moodColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _getMoodIcon(entry.moodScore!),
                          size: 12,
                          color: moodColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          entry.moodLabel ?? '',
                          style: TextStyle(
                            color: moodColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ...entry.tags
                    .take(2)
                    .map(
                      (tag) => Container(
                        margin: const EdgeInsets.only(left: 6),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '#$tag',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                if (entry.hasReflection) ...[
                  const Spacer(),
                  Icon(
                    Icons.psychology_rounded,
                    size: 16,
                    color: _primaryColor.withOpacity(0.6),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: _primaryColor.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.book_rounded, size: 40, color: _primaryColor),
            ),
            const SizedBox(height: 24),
            Text(
              'Your journal awaits',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Start writing to reflect and grow',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFAB() {
    return ScaleTransition(
      scale: _fabController,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(colors: [_primaryColor, _secondaryColor]),
          boxShadow: [
            BoxShadow(
              color: _primaryColor.withOpacity(0.35),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: FloatingActionButton.extended(
          onPressed: () => context.push(Routes.journalEntry),
          backgroundColor: Colors.transparent,
          elevation: 0,
          icon: const Icon(Icons.edit_rounded, color: Colors.white, size: 18),
          label: const Text(
            'Write',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  Color _getMoodColor(int score) {
    switch (score) {
      case 1:
        return const Color(0xFFEF4444);
      case 2:
        return const Color(0xFFF97316);
      case 3:
        return const Color(0xFFEAB308);
      case 4:
        return const Color(0xFF22C55E);
      case 5:
        return const Color(0xFF6366F1);
      default:
        return Colors.grey;
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
