import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/routes.dart';
import '../../../domain/entities/mood_log.dart';
import '../../providers/auth_provider.dart';
import '../../providers/mood_provider.dart';
import '../../widgets/custom_charts.dart';

/// Mood History Dashboard with Beautiful Charts
class MoodHistoryDashboardScreen extends ConsumerStatefulWidget {
  const MoodHistoryDashboardScreen({super.key});

  @override
  ConsumerState<MoodHistoryDashboardScreen> createState() => _MoodHistoryDashboardScreenState();
}

class _MoodHistoryDashboardScreenState extends ConsumerState<MoodHistoryDashboardScreen> {
  bool _show7Days = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authState = ref.watch(authStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mood Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded),
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
              return _buildUnauthenticated(context);
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
                
                // Prepare data for charts
                final dataPoints = windowLogs.map((log) => MoodDataPoint(
                  date: log.createdAt,
                  moodScore: log.moodScore.toDouble(),
                )).toList();

                // Mood distribution
                final distribution = <int, int>{};
                for (final log in windowLogs) {
                  distribution[log.moodScore] = (distribution[log.moodScore] ?? 0) + 1;
                }

                // Mood dates for streak calendar
                final moodDates = sortedLogs.map((log) => log.createdAt).toList();

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Period selector
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '📊 Dashboard',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primaryContainer.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: SegmentedButton<bool>(
                              style: SegmentedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                foregroundColor: theme.colorScheme.primary,
                                selectedForegroundColor: Colors.white,
                                selectedBackgroundColor: theme.colorScheme.primary,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              ),
                              segments: const [
                                ButtonSegment(
                                  value: true,
                                  label: Text('7 Days', style: TextStyle(fontWeight: FontWeight.w600)),
                                  icon: Icon(Icons.calendar_view_week_rounded, size: 16),
                                ),
                                ButtonSegment(
                                  value: false,
                                  label: Text('30 Days', style: TextStyle(fontWeight: FontWeight.w600)),
                                  icon: Icon(Icons.calendar_month_rounded, size: 16),
                                ),
                              ],
                              selected: {_show7Days},
                              onSelectionChanged: (value) {
                                setState(() {
                                  _show7Days = value.first;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Overview Stats Cards
                      Row(
                        children: [
                          Expanded(
                            child: _buildOverviewCard(
                              context,
                              icon: Icons.show_chart_rounded,
                              value: windowLogs.isEmpty ? 'N/A' : currentAvg.toStringAsFixed(1),
                              label: 'Average Mood',
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildOverviewCard(
                              context,
                              icon: Icons.event_note_rounded,
                              value: windowLogs.length.toString(),
                              label: 'Check-ins',
                              color: theme.colorScheme.secondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Mood Trend Line Chart
                      if (dataPoints.isNotEmpty) ...[
                        MoodTrendChart(
                          dataPoints: dataPoints.reversed.toList(),
                          period: _show7Days ? '7 Days' : '30 Days',
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Mood Distribution Donut Chart
                      if (distribution.isNotEmpty) ...[
                        MoodDistributionChart(distribution: distribution),
                        const SizedBox(height: 24),
                      ],

                      // Mood Streak Calendar
                      MoodStreakCalendar(
                        moodDates: moodDates,
                        days: 30,
                      ),
                      const SizedBox(height: 24),

                      // Common Tags Section
                      if (windowLogs.isNotEmpty) _buildCommonTags(context, windowLogs),

                      const SizedBox(height: 32),
                      
                      // CTA Button
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: FilledButton.icon(
                          onPressed: () => context.push(Routes.moodCheckIn),
                          icon: const Icon(Icons.add_circle_rounded, size: 24),
                          label: const Text(
                            'Log Your Mood',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
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

  Widget _buildUnauthenticated(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.lock_outline_rounded,
                size: 64,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Sign in to view your mood dashboard',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => context.push(Routes.signIn),
              child: const Text('Sign In'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewCard(
    BuildContext context, {
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withOpacity(0.12),
            color.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 28, color: color),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.7),
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildCommonTags(BuildContext context, List<MoodLog> logs) {
    final theme = Theme.of(context);
    final tagCounts = <String, int>{};
    
    for (final log in logs) {
      for (final tag in log.tags) {
        tagCounts[tag] = (tagCounts[tag] ?? 0) + 1;
      }
    }
    
    final topTags = tagCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final displayTags = topTags.take(5).toList();

    if (displayTags.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Top Emotions',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: displayTags.map((entry) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.tertiaryContainer,
                    theme.colorScheme.tertiaryContainer.withOpacity(0.7),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.tertiary.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    entry.key,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.tertiary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.tertiary.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${entry.value}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.tertiary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  double _averageMood(List<MoodLog> logs) {
    if (logs.isEmpty) return 0;
    final total = logs.fold<int>(0, (sum, log) => sum + log.moodScore);
    return total / logs.length;
  }
}
