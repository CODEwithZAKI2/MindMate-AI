import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/routes.dart';
import '../../../domain/entities/mood_log.dart';
import '../../providers/auth_provider.dart';
import '../../providers/mood_provider.dart';

class MoodHistoryScreen extends ConsumerStatefulWidget {
  const MoodHistoryScreen({super.key});

  @override
  ConsumerState<MoodHistoryScreen> createState() => _MoodHistoryScreenState();
}

class _MoodHistoryScreenState extends ConsumerState<MoodHistoryScreen> {
  bool _show7Days = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authState = ref.watch(authStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mood History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () => context.push(Routes.moodCheckIn),
            tooltip: 'Log mood',
          ),
        ],
      ),
      body: SafeArea(
        child: authState.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Text('Error loading user: $error'),
            ),
          ),
          data: (user) {
            if (user == null) {
              return _Unauthenticated(onSignIn: () => context.push(Routes.signIn));
            }

            final moodLogsAsync = ref.watch(moodLogsStreamProvider(user.id));

            return moodLogsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Text('Error loading mood logs: $error'),
                ),
              ),
              data: (logs) {
                final sortedLogs = [...logs]
                  ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
                final days = _show7Days ? 7 : 30;
                final windowStart = DateTime.now().subtract(Duration(days: days));
                final windowLogs = sortedLogs
                    .where((log) => log.createdAt.isAfter(windowStart))
                    .toList();

                final currentAvg = _averageMood(windowLogs);
                final trend = _computeTrend(sortedLogs, days: days);
                final insights = _computeInsights(
                  windowLogs: windowLogs,
                  allLogs: sortedLogs,
                  days: days,
                );

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _show7Days ? 'Last 7 days' : 'Last 30 days',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SegmentedButton<bool>(
                            segments: const [
                              ButtonSegment(value: true, label: Text('7d')),
                              ButtonSegment(value: false, label: Text('30d')),
                            ],
                            selected: {_show7Days},
                            onSelectionChanged: (value) {
                              setState(() {
                                _show7Days = value.first;
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      Row(
                        children: [
                          Expanded(
                            child: _StatCard(
                              title: 'Average mood',
                              value: windowLogs.isEmpty
                                  ? 'N/A'
                                  : currentAvg.toStringAsFixed(1),
                              emoji: '📊',
                              color: Colors.blue,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _StatCard(
                              title: 'Logs',
                              value: windowLogs.length.toString(),
                              emoji: '📝',
                              color: Colors.purple,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),
                      _TrendCard(trend: trend),

                      const SizedBox(height: 12),
                      _InsightsCard(
                        title: _show7Days ? '7-day insights' : '30-day insights',
                        insights: insights,
                      ),

                      const SizedBox(height: 24),
                      Text(
                        _show7Days ? 'Last 7 days' : 'Last 30 days',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _LogsList(
                        logs: windowLogs,
                        theme: theme,
                        onAddFirst: () => context.push(Routes.moodCheckIn),
                      ),

                      const SizedBox(height: 24),
                      Text(
                        'All logs',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _LogsList(
                        logs: sortedLogs,
                        theme: theme,
                        onAddFirst: () => context.push(Routes.moodCheckIn),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  double _averageMood(List<MoodLog> logs) {
    if (logs.isEmpty) return 0;
    final total = logs.fold<int>(0, (sum, log) => sum + log.moodScore);
    return total / logs.length;
  }

  Map<String, dynamic> _computeTrend(List<MoodLog> allLogs, {required int days}) {
    if (allLogs.isEmpty) {
      return {
        'label': 'stable',
        'percent': 0.0,
      };
    }

    final now = DateTime.now();
    final windowStart = now.subtract(Duration(days: days));
    final prevStart = windowStart.subtract(Duration(days: days));

    final currentLogs = allLogs
        .where((log) => log.createdAt.isAfter(windowStart))
        .toList();
    final prevLogs = allLogs
        .where((log) =>
            log.createdAt.isAfter(prevStart) && log.createdAt.isBefore(windowStart))
        .toList();

    final currentAvg = _averageMood(currentLogs);
    final prevAvg = _averageMood(prevLogs);
    final change = currentAvg - prevAvg;
    final percent = prevAvg > 0 ? (change / prevAvg) * 100 : 0.0;

    final label = change > 0
        ? 'improving'
        : change < 0
            ? 'declining'
            : 'stable';

    return {
      'label': label,
      'percent': percent,
    };
  }

  Map<String, dynamic> _computeInsights({
    required List<MoodLog> windowLogs,
    required List<MoodLog> allLogs,
    required int days,
  }) {
    if (windowLogs.isEmpty) {
      return {
        'bestDay': null,
        'worstDay': null,
        'bestWeekday': null,
        'commonTags': <String>[],
        'currentStreak': _computeStreak(allLogs),
        'weekOverWeekChange': 0.0,
      };
    }

    final byDate = <String, List<MoodLog>>{};
    for (final log in windowLogs) {
      final key = DateFormat('yyyy-MM-dd').format(log.createdAt);
      byDate.putIfAbsent(key, () => []).add(log);
    }

    // Find best and worst individual logs (not averages)
    MoodLog? bestLog;
    MoodLog? worstLog;
    
    for (final log in windowLogs) {
      if (bestLog == null || log.moodScore > bestLog.moodScore) {
        bestLog = log;
      }
      if (worstLog == null || log.moodScore < worstLog.moodScore) {
        worstLog = log;
      }
    }

    final byWeekday = <int, List<MoodLog>>{};
    for (final log in windowLogs) {
      final weekday = log.createdAt.weekday; // 1=Mon
      byWeekday.putIfAbsent(weekday, () => []).add(log);
    }

    MapEntry<int, double>? bestWeekday;
    byWeekday.forEach((weekday, weekdayLogs) {
      final avg = _averageMood(weekdayLogs);
      if (bestWeekday == null || avg > bestWeekday!.value) {
        bestWeekday = MapEntry(weekday, avg);
      }
    });

    final tagCounts = <String, int>{};
    for (final log in windowLogs) {
      for (final tag in log.tags) {
        tagCounts[tag] = (tagCounts[tag] ?? 0) + 1;
      }
    }
    final commonTags = tagCounts.entries
        .toList()
        ..sort((a, b) => b.value.compareTo(a.value));

    final streak = _computeStreak(allLogs);
    final weekChange = _weekOverWeekChange(allLogs);

    return {
      'bestDay': bestLog == null
          ? null
          : {
              'dateKey': DateFormat('yyyy-MM-dd').format(bestLog.createdAt),
              'score': bestLog.moodScore,
            },
      'worstDay': worstLog == null
          ? null
          : {
              'dateKey': DateFormat('yyyy-MM-dd').format(worstLog.createdAt),
              'score': worstLog.moodScore,
            },
      'bestWeekday': bestWeekday?.key,
      'commonTags': commonTags.take(5).map((e) => e.key).toList(),
      'currentStreak': streak,
      'weekOverWeekChange': weekChange,
    };
  }

  int _computeStreak(List<MoodLog> logs) {
    if (logs.isEmpty) return 0;

    final dateSet = logs
        .map((log) => DateUtils.dateOnly(log.createdAt))
        .toSet();

    var day = DateUtils.dateOnly(DateTime.now());
    var streak = 0;
    while (dateSet.contains(day)) {
      streak += 1;
      day = day.subtract(const Duration(days: 1));
    }
    return streak;
  }

  double _weekOverWeekChange(List<MoodLog> logs) {
    if (logs.isEmpty) return 0.0;

    final now = DateTime.now();
    final weekStart = now.subtract(const Duration(days: 7));
    final prevWeekStart = now.subtract(const Duration(days: 14));

    final thisWeek = logs
        .where((log) => log.createdAt.isAfter(weekStart))
        .toList();
    final lastWeek = logs
        .where((log) =>
            log.createdAt.isAfter(prevWeekStart) && log.createdAt.isBefore(weekStart))
        .toList();

    final thisAvg = _averageMood(thisWeek);
    final lastAvg = _averageMood(lastWeek);

    if (lastAvg == 0) return 0.0;
    return ((thisAvg - lastAvg) / lastAvg) * 100;
  }
}

class _Unauthenticated extends StatelessWidget {
  final VoidCallback onSignIn;

  const _Unauthenticated({required this.onSignIn});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, size: 64, color: Colors.grey),
            const SizedBox(height: 12),
            Text(
              'Sign in to view mood history',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: onSignIn,
              child: const Text('Sign in'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String emoji;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.emoji,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              emoji,
              style: const TextStyle(fontSize: 32),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrendCard extends StatelessWidget {
  final Map<String, dynamic> trend;

  const _TrendCard({required this.trend});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = trend['label'] as String? ?? 'stable';
    final percent = (trend['percent'] as num? ?? 0).toDouble();
    final color = label == 'improving'
        ? Colors.green
        : label == 'declining'
            ? Colors.red
            : Colors.grey;
    final emoji = label == 'improving'
        ? '📈'
        : label == 'declining'
            ? '📉'
            : '➡️';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 32)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Mood trend',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    label == 'improving'
                        ? 'Improving'
                        : label == 'declining'
                            ? 'Declining'
                            : 'Stable',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    percent == 0
                        ? 'No change vs previous period'
                        : '${percent > 0 ? '+' : ''}${percent.toStringAsFixed(1)}% vs previous period',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InsightRow extends StatelessWidget {
  final String label;
  final String value;

  const _InsightRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _InsightsCard extends StatelessWidget {
  final String title;
  final Map<String, dynamic> insights;

  const _InsightsCard({
    required this.title,
    required this.insights,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bestDay = insights['bestDay'] as Map<String, dynamic>?;
    final worstDay = insights['worstDay'] as Map<String, dynamic>?;
    final bestWeekday = insights['bestWeekday'] as int?;
    final tags = (insights['commonTags'] as List<dynamic>? ?? []).cast<String>();
    final streak = insights['currentStreak'] as int? ?? 0;
    final weekChange = (insights['weekOverWeekChange'] as num? ?? 0).toDouble();

    String formatDay(Map<String, dynamic>? day) {
      if (day == null) return 'N/A';
      final dt = DateTime.parse(day['dateKey'] as String);
      final score = day['score'] as int;
      return '${DateFormat('MMM d').format(dt)} • $score/5';
    }

    String weekdayLabel(int? weekday) {
      const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      if (weekday == null || weekday < 1 || weekday > 7) return 'N/A';
      return names[weekday - 1];
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('💡', style: TextStyle(fontSize: 24)),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _InsightRow(
              label: 'Current streak',
              value: streak > 0 ? '$streak days' : 'No streak yet',
            ),
            _InsightRow(
              label: 'Best day',
              value: formatDay(bestDay),
            ),
            _InsightRow(
              label: 'Lowest day',
              value: formatDay(worstDay),
            ),
            _InsightRow(
              label: 'Best weekday',
              value: weekdayLabel(bestWeekday),
            ),
            _InsightRow(
              label: 'Week over week',
              value: weekChange == 0
                  ? 'No change'
                  : '${weekChange > 0 ? '+' : ''}${weekChange.toStringAsFixed(1)}% vs last week',
            ),
            if (tags.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Common tags',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: tags
                    .map((tag) => Chip(
                          label: Text(tag),
                          backgroundColor:
                              theme.colorScheme.primary.withOpacity(0.1),
                          labelStyle: TextStyle(
                            color: theme.colorScheme.primary,
                          ),
                        ))
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LogsList extends StatelessWidget {
  final List<MoodLog> logs;
  final ThemeData theme;
  final VoidCallback onAddFirst;

  const _LogsList({
    required this.logs,
    required this.theme,
    required this.onAddFirst,
  });

  @override
  Widget build(BuildContext context) {
    if (logs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(48.0),
          child: Column(
            children: [
              const Icon(
                Icons.sentiment_satisfied_alt_rounded,
                size: 80,
                color: Colors.grey,
              ),
              const SizedBox(height: 16),
              Text(
                'No mood logs yet',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Start tracking your mood to see insights',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onAddFirst,
                icon: const Icon(Icons.add),
                label: const Text('Add First Mood Log'),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: logs.length,
      itemBuilder: (context, index) {
        final log = logs[index];
        return _MoodLogCard(log: log);
      },
    );
  }
}

class _MoodLogCard extends ConsumerWidget {
  final MoodLog log;

  const _MoodLogCard({required this.log});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('MMM dd, yyyy');
    final timeFormat = DateFormat('h:mm a');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {},
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    _getMoodEmoji(log.moodScore),
                    style: const TextStyle(fontSize: 32),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getMoodLabel(log.moodScore),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${dateFormat.format(log.createdAt)} at ${timeFormat.format(log.createdAt)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Delete Mood Log'),
                          content: const Text('Are you sure you want to delete this mood log?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Cancel'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('Delete'),
                            ),
                          ],
                        ),
                      );

                      if (confirm == true) {
                        await ref
                            .read(moodNotifierProvider.notifier)
                            .deleteMoodLog(log.id);
                      }
                    },
                  ),
                ],
              ),
              if (log.tags.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: log.tags.map((tag) {
                    return Chip(
                      label: Text(
                        tag,
                        style: const TextStyle(fontSize: 12),
                      ),
                      visualDensity: VisualDensity.compact,
                    );
                  }).toList(),
                ),
              ],
              if (log.note != null && log.note!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  log.note!,
                  style: theme.textTheme.bodyMedium,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _getMoodEmoji(int score) {
    switch (score) {
      case 1:
        return '😢';
      case 2:
        return '😕';
      case 3:
        return '😐';
      case 4:
        return '🙂';
      case 5:
        return '😊';
      default:
        return '😐';
    }
  }

  String _getMoodLabel(int score) {
    switch (score) {
      case 1:
        return 'Very Bad';
      case 2:
        return 'Bad';
      case 3:
        return 'Okay';
      case 4:
        return 'Good';
      case 5:
        return 'Great';
      default:
        return 'Okay';
    }
  }
}
