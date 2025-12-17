import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../providers/mood_provider.dart';
import '../../../domain/entities/mood_log.dart';
import '../../../core/constants/routes.dart';
import 'package:go_router/go_router.dart';

class MoodHistoryScreen extends ConsumerStatefulWidget {
  const MoodHistoryScreen({super.key});

  @override
  ConsumerState<MoodHistoryScreen> createState() => _MoodHistoryScreenState();
}

class _MoodHistoryScreenState extends ConsumerState<MoodHistoryScreen> {
  bool _show7Days = true; // true = 7 days, false = 30 days

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final userId = ref.watch(currentUserIdProvider);

    if (userId == null) {
      return const Scaffold(
        body: Center(child: Text('Please sign in to view mood history')),
      );
    }

    final moodLogsAsync = ref.watch(_show7Days
        ? last7DaysMoodLogsProvider(userId)
        : last30DaysMoodLogsProvider(userId));
    final statsAsync = ref.watch(moodStatisticsProvider((
      userId: userId,
      startDate: DateTime.now().subtract(Duration(days: _show7Days ? 7 : 30)),
      endDate: DateTime.now(),
    )));
    final trendAsync = ref.watch(moodTrendProvider((
      userId: userId,
      days: _show7Days ? 7 : 30,
    )));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mood History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () => context.push(Routes.moodCheckIn),
            tooltip: 'Add Mood Log',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(last7DaysMoodLogsProvider);
          ref.invalidate(last30DaysMoodLogsProvider);
          ref.invalidate(moodStatisticsProvider);
          ref.invalidate(moodTrendProvider);
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Time range toggle
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: true, label: Text('7 Days')),
                  ButtonSegment(value: false, label: Text('30 Days')),
                ],
                selected: {_show7Days},
                onSelectionChanged: (Set<bool> newSelection) {
                  setState(() {
                    _show7Days = newSelection.first;
                  });
                },
              ),
              const SizedBox(height: 24),

              // Statistics cards
              statsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) => Center(child: Text('Error: $error')),
                data: (stats) => Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        title: 'Average',
                        value: stats['averageMood']?.toStringAsFixed(1) ?? 'N/A',
                        emoji: '📊',
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        title: 'Total Logs',
                        value: stats['totalLogs']?.toString() ?? '0',
                        emoji: '📝',
                        color: Colors.purple,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Trend card
              trendAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (error, stack) => const SizedBox.shrink(),
                data: (trend) => Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Text(
                          trend == 'improving' ? '📈' : trend == 'declining' ? '📉' : '➡️',
                          style: const TextStyle(fontSize: 32),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Mood Trend',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              Text(
                                trend == 'improving'
                                    ? 'Improving'
                                    : trend == 'declining'
                                        ? 'Declining'
                                        : 'Stable',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: trend == 'improving'
                                      ? Colors.green
                                      : trend == 'declining'
                                          ? Colors.red
                                          : Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Mood logs list
              Text(
                'Recent Logs',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),

              moodLogsAsync.when(
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (error, stack) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Text('Error loading mood logs: $error'),
                  ),
                ),
                data: (logs) {
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
                              onPressed: () => context.push(Routes.moodCheckIn),
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
                },
              ),
            ],
          ),
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
        onTap: () {
          // Could show detail dialog here
        },
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
