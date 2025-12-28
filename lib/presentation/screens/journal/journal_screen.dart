import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'dart:ui';
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
    with TickerProviderStateMixin {
  late AnimationController _headerController;
  late AnimationController _fabController;
  late Animation<double> _headerAnimation;
  late Animation<double> _fabAnimation;
  String _searchQuery = '';
  bool _showSearch = false;
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  double _scrollOffset = 0;

  // Premium color palette - calming, therapeutic tones
  static const _primaryGradient = [
    Color(0xFF667EEA), // Soft indigo
    Color(0xFF764BA2), // Soft purple
  ];
  static const _accentGradient = [
    Color(0xFFF093FB), // Soft pink
    Color(0xFFF5576C), // Coral
  ];
  static const _calmGradient = [
    Color(0xFF4FACFE), // Sky blue
    Color(0xFF00F2FE), // Cyan
  ];

  @override
  void initState() {
    super.initState();
    _headerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fabController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _headerAnimation = CurvedAnimation(
      parent: _headerController,
      curve: Curves.easeOutQuart,
    );
    _fabAnimation = CurvedAnimation(
      parent: _fabController,
      curve: Curves.elasticOut,
    );
    _headerController.forward();
    Future.delayed(const Duration(milliseconds: 400), () {
      _fabController.forward();
    });

    _scrollController.addListener(() {
      setState(() => _scrollOffset = _scrollController.offset);
    });
  }

  @override
  void dispose() {
    _headerController.dispose();
    _fabController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final userId = ref.watch(currentUserIdProvider);
    final size = MediaQuery.of(context).size;

    if (userId == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final entriesAsync = ref.watch(journalEntriesStreamProvider(userId));
    final statsAsync = ref.watch(journalStatisticsProvider(userId));

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          // Premium animated background gradient
          Positioned(
            top: -100 + (_scrollOffset * 0.3),
            left: -50,
            right: -50,
            child: AnimatedBuilder(
              animation: _headerAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: 0.8 + (0.2 * _headerAnimation.value),
                  child: Opacity(
                    opacity: _headerAnimation.value,
                    child: Container(
                      height: 400,
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: Alignment.topCenter,
                          radius: 1.5,
                          colors: [
                            _primaryGradient[0].withOpacity(0.25),
                            _primaryGradient[1].withOpacity(0.15),
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.5, 1.0],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Main content
          CustomScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Premium Header
              SliverToBoxAdapter(
                child: SafeArea(
                  bottom: false,
                  child: AnimatedBuilder(
                    animation: _headerAnimation,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(0, 30 * (1 - _headerAnimation.value)),
                        child: Opacity(
                          opacity: _headerAnimation.value,
                          child: _buildHeader(theme, statsAsync),
                        ),
                      );
                    },
                  ),
                ),
              ),

              // Daily prompt card
              SliverToBoxAdapter(child: _buildDailyPromptCard(theme)),

              // Search bar
              if (_showSearch)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                    child: _buildGlassSearchBar(theme),
                  ),
                ),

              // Section title
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                  child: Row(
                    children: [
                      Text(
                        'Your Reflections',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                          color: const Color(0xFF1E293B),
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _primaryGradient[0].withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.auto_awesome,
                              size: 14,
                              color: _primaryGradient[0],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'AI Enhanced',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: _primaryGradient[0],
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Entries list with staggered animation
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
                        return TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: 1),
                          duration: Duration(milliseconds: 400 + (index * 100)),
                          curve: Curves.easeOutQuart,
                          builder: (context, value, child) {
                            return Transform.translate(
                              offset: Offset(0, 30 * (1 - value)),
                              child: Opacity(
                                opacity: value,
                                child: _buildPremiumJournalCard(
                                  entry,
                                  theme,
                                  index,
                                ),
                              ),
                            );
                          },
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

              const SliverToBoxAdapter(child: SizedBox(height: 120)),
            ],
          ),
        ],
      ),
      floatingActionButton: _buildPremiumFAB(theme),
    );
  }

  Widget _buildHeader(
    ThemeData theme,
    AsyncValue<Map<String, dynamic>> statsAsync,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
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
                    style: theme.textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1.5,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('EEEE, MMMM d').format(DateTime.now()),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  _buildGlassIconButton(
                    icon: _showSearch ? Icons.close : Icons.search_rounded,
                    onTap:
                        () => setState(() {
                          _showSearch = !_showSearch;
                          if (!_showSearch) {
                            _searchQuery = '';
                            _searchController.clear();
                          }
                        }),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Premium stats row with glassmorphism
          statsAsync.when(
            data: (stats) => _buildGlassStatsRow(stats, theme),
            loading: () => _buildStatsPlaceholder(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassIconButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.7),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.3)),
              boxShadow: [
                BoxShadow(
                  color: _primaryGradient[0].withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, color: const Color(0xFF475569), size: 22),
          ),
        ),
      ),
    );
  }

  Widget _buildGlassStatsRow(Map<String, dynamic> stats, ThemeData theme) {
    return Row(
      children: [
        Expanded(
          child: _buildGlassStatCard(
            '${stats['totalEntries'] ?? 0}',
            'Entries',
            Icons.book_rounded,
            _primaryGradient,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildGlassStatCard(
            '${stats['currentStreak'] ?? 0}',
            'Day Streak',
            Icons.local_fire_department_rounded,
            _accentGradient,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildGlassStatCard(
            '${stats['entriesThisWeek'] ?? 0}',
            'This Week',
            Icons.calendar_today_rounded,
            _calmGradient,
          ),
        ),
      ],
    );
  }

  Widget _buildGlassStatCard(
    String value,
    String label,
    IconData icon,
    List<Color> gradient,
  ) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.9),
                Colors.white.withOpacity(0.7),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.5)),
            boxShadow: [
              BoxShadow(
                color: gradient[0].withOpacity(0.15),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: gradient),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: gradient[0].withOpacity(0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              const SizedBox(height: 12),
              Text(
                value,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  foreground:
                      Paint()
                        ..shader = LinearGradient(
                          colors: gradient,
                        ).createShader(const Rect.fromLTWH(0, 0, 50, 40)),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF64748B),
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
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
            height: 130,
            margin: EdgeInsets.only(right: i < 2 ? 12 : 0),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.5),
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDailyPromptCard(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: GestureDetector(
        onTap: () => context.push(Routes.journalEntry),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_primaryGradient[0], _primaryGradient[1]],
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: _primaryGradient[0].withOpacity(0.4),
                blurRadius: 24,
                offset: const Offset(0, 12),
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
                          const Icon(
                            Icons.auto_awesome,
                            size: 14,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            "Today's Prompt",
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'What are you grateful for today?',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tap to start writing...',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.edit_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGlassSearchBar(ThemeData theme) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.8),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.5)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: TextField(
            controller: _searchController,
            onChanged: (value) => setState(() => _searchQuery = value),
            decoration: InputDecoration(
              hintText: 'Search your reflections...',
              hintStyle: TextStyle(color: const Color(0xFF94A3B8)),
              prefixIcon: Icon(
                Icons.search_rounded,
                color: const Color(0xFF94A3B8),
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 16,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPremiumJournalCard(
    JournalEntry entry,
    ThemeData theme,
    int index,
  ) {
    final dateFormat = DateFormat('MMM d');
    final timeFormat = DateFormat('h:mm a');
    final moodColor =
        entry.moodScore != null ? _getMoodColor(entry.moodScore!) : Colors.grey;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: GestureDetector(
        onTap: () => context.push('${Routes.journalEntry}/${entry.id}'),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withOpacity(0.8)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header row with date and favorite
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              _primaryGradient[0].withOpacity(0.1),
                              _primaryGradient[1].withOpacity(0.1),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.calendar_today_rounded,
                              size: 12,
                              color: _primaryGradient[0],
                            ),
                            const SizedBox(width: 6),
                            Text(
                              dateFormat.format(entry.createdAt),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: _primaryGradient[0],
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        timeFormat.format(entry.createdAt),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: const Color(0xFF94A3B8),
                        ),
                      ),
                      const Spacer(),
                      if (entry.isFavorite)
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.favorite_rounded,
                            size: 16,
                            color: Colors.red.shade400,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Title with premium typography
                  Text(
                    entry.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                      color: const Color(0xFF1E293B),
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),

                  // Content preview
                  Text(
                    entry.contentPreview,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF64748B),
                      height: 1.6,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 16),

                  // Bottom row with mood and tags
                  Row(
                    children: [
                      if (entry.moodScore != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                moodColor.withOpacity(0.15),
                                moodColor.withOpacity(0.1),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: moodColor.withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _getMoodIcon(entry.moodScore!),
                                size: 14,
                                color: moodColor,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                entry.moodLabel ?? '',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: moodColor,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ...entry.tags
                          .take(2)
                          .map(
                            (tag) => Container(
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '#$tag',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: const Color(0xFF64748B),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                      if (entry.isFromPrompt) ...[
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: _primaryGradient),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.auto_awesome,
                            size: 12,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    _primaryGradient[0].withOpacity(0.1),
                    _primaryGradient[1].withOpacity(0.1),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: ShaderMask(
                shaderCallback:
                    (bounds) => LinearGradient(
                      colors: _primaryGradient,
                    ).createShader(bounds),
                child: const Icon(
                  Icons.book_rounded,
                  size: 64,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Your journal awaits',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                color: const Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Begin your journey of self-reflection.\nEvery word brings clarity.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF64748B),
                height: 1.6,
              ),
            ),
            const SizedBox(height: 32),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: _primaryGradient),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: _primaryGradient[0].withOpacity(0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: () => context.push(Routes.journalEntry),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: const Icon(Icons.edit_rounded, color: Colors.white),
                label: const Text(
                  'Write First Entry',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumFAB(ThemeData theme) {
    return AnimatedBuilder(
      animation: _fabAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _fabAnimation.value,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: _primaryGradient,
              ),
              boxShadow: [
                BoxShadow(
                  color: _primaryGradient[0].withOpacity(0.5),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: FloatingActionButton.extended(
              onPressed: () => context.push(Routes.journalEntry),
              backgroundColor: Colors.transparent,
              elevation: 0,
              icon: const Icon(Icons.edit_rounded, color: Colors.white),
              label: const Text(
                'Write',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Color _getMoodColor(int score) {
    switch (score) {
      case 1:
        return const Color(0xFFE879F9); // Pink
      case 2:
        return const Color(0xFFFB923C); // Orange
      case 3:
        return const Color(0xFF60A5FA); // Blue
      case 4:
        return const Color(0xFF34D399); // Green
      case 5:
        return const Color(0xFF818CF8); // Indigo
      default:
        return const Color(0xFF94A3B8);
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
