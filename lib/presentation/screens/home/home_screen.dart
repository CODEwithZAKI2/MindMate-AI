import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../providers/mood_provider.dart';
import '../../../core/constants/routes.dart';
import '../../widgets/custom_charts.dart';
import '../../widgets/mood_widgets.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final authState = ref.watch(authStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('MindMate AI'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_rounded),
            onPressed: () {
              context.push(Routes.settings);
            },
          ),
        ],
      ),
      body: authState.when(
        data: (user) {
          if (user == null) {
            return const Center(child: Text('Not signed in'));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Enhanced Welcome Section
                _buildWelcomeSection(context, user.displayName),
                const SizedBox(height: 32),

                // Daily Wellness - Primary Actions
                _buildSectionHeader(context, 'Daily Wellness'),
                const SizedBox(height: 16),
                _buildPrimaryActionCard(
                  context: context,
                  icon: Icons.chat_bubble_rounded,
                  title: 'Start Conversation',
                  description: 'Talk to your AI companion about anything',
                  gradient: LinearGradient(
                    colors: [
                      theme.colorScheme.primary,
                      theme.colorScheme.primary.withOpacity(0.8),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  onTap: () {
                    context.push(Routes.chat);
                  },
                ),
                const SizedBox(height: 16),
                _buildPrimaryActionCard(
                  context: context,
                  icon: Icons.mood_rounded,
                  title: 'Daily Check-In',
                  description: 'Log your mood and track your journey',
                  gradient: LinearGradient(
                    colors: [
                      theme.colorScheme.secondary,
                      theme.colorScheme.secondary.withOpacity(0.8),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  onTap: () {
                    context.push(Routes.moodCheckIn);
                  },
                ),
                const SizedBox(height: 32),

                // Insights & History - Secondary Actions
                _buildSectionHeader(context, 'Insights & History'),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildSecondaryActionCard(
                        context: context,
                        icon: Icons.history_rounded,
                        title: 'Chat History',
                        color: theme.colorScheme.tertiary,
                        onTap: () {
                          context.push(Routes.chatHistory);
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildSecondaryActionCard(
                        context: context,
                        icon: Icons.insights_rounded,
                        title: 'Mood History',
                        color: theme.colorScheme.primary,
                        onTap: () {
                          context.push(Routes.moodHistory);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // Your Progress - Journey Stats with Progress Rings
                _buildSectionHeader(context, 'Your Progress'),
                const SizedBox(height: 16),
                
                // Fetch mood logs to calculate actual stats
                Consumer(
                  builder: (context, ref, child) {
                    final moodLogsAsync = ref.watch(moodLogsStreamProvider(user.id));
                    
                    return moodLogsAsync.when(
                      data: (logs) {
                        // Calculate day streak
                        final streak = _calculateStreak(logs);
                        final totalCheckIns = logs.length;
                        final streakProgress = streak > 0 ? (streak / 30).clamp(0.0, 1.0) : 0.0;
                        final checkInsProgress = totalCheckIns > 0 ? (totalCheckIns / 100).clamp(0.0, 1.0) : 0.0;
                        
                        return Row(
                          children: [
                            Expanded(
                              child: ProgressRing(
                                progress: streakProgress,
                                value: streak.toString(),
                                label: 'Day Streak',
                                color: Colors.orange,
                                icon: Icons.local_fire_department_rounded,
                                size: 110,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: ProgressRing(
                                progress: checkInsProgress,
                                value: totalCheckIns.toString(),
                                label: 'Check-ins',
                                color: theme.colorScheme.tertiary,
                                icon: Icons.check_circle_rounded,
                                size: 110,
                              ),
                            ),
                          ],
                        );
                      },
                      loading: () => Row(
                        children: [
                          Expanded(
                            child: ProgressRing(
                              progress: 0.0,
                              value: '...',
                              label: 'Day Streak',
                              color: Colors.orange,
                              icon: Icons.local_fire_department_rounded,
                              size: 110,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ProgressRing(
                              progress: 0.0,
                              value: '...',
                              label: 'Check-ins',
                              color: theme.colorScheme.tertiary,
                              icon: Icons.check_circle_rounded,
                              size: 110,
                            ),
                          ),
                        ],
                      ),
                      error: (_, __) => Row(
                        children: [
                          Expanded(
                            child: ProgressRing(
                              progress: 0.0,
                              value: '0',
                              label: 'Day Streak',
                              color: Colors.orange,
                              icon: Icons.local_fire_department_rounded,
                              size: 110,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ProgressRing(
                              progress: 0.0,
                              value: '0',
                              label: 'Check-ins',
                              color: theme.colorScheme.tertiary,
                              icon: Icons.check_circle_rounded,
                              size: 110,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 32),

                // Daily Wellness Tip
                DailyTipCard(
                  tip: 'Take 3 deep breaths and notice how you feel right now.',
                  icon: Icons.spa_rounded,
                ),
                const SizedBox(height: 32),

                // Sign Out Button
                OutlinedButton.icon(
                  onPressed: () async {
                    await ref.read(authNotifierProvider.notifier).signOut();
                    if (context.mounted) {
                      context.go(Routes.signIn);
                    }
                  },
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('Sign Out'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: theme.colorScheme.error,
                    side: BorderSide(color: theme.colorScheme.error),
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Text('Error: $error'),
        ),
      ),
    );
  }

  /// Enhanced welcome section with gradient, date/time, and warm greeting
  Widget _buildWelcomeSection(BuildContext context, String displayName) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final timeOfDay = DateFormat('EEEE, MMMM d').format(now);
    final hour = now.hour;
    
    String greeting;
    if (hour < 12) {
      greeting = 'Good morning';
    } else if (hour < 17) {
      greeting = 'Good afternoon';
    } else {
      greeting = 'Good evening';
    }

    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary,
            theme.colorScheme.secondary,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _getGreetingIcon(hour),
                color: Colors.white.withOpacity(0.9),
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  timeOfDay,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withOpacity(0.85),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '$greeting,',
            style: theme.textTheme.titleLarge?.copyWith(
              color: Colors.white.withOpacity(0.9),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            displayName,
            style: theme.textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: -0.5,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface.withOpacity(0.7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.spa_rounded,
                  size: 16,
                  color: theme.colorScheme.secondary,
                ),
                const SizedBox(width: 8),
                Text(
                  'How are you feeling today?',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Get appropriate greeting icon based on time of day
  IconData _getGreetingIcon(int hour) {
    if (hour < 12) {
      return Icons.wb_sunny_rounded; // Morning
    } else if (hour < 17) {
      return Icons.wb_sunny_outlined; // Afternoon
    } else {
      return Icons.nights_stay_rounded; // Evening
    }
  }

  /// Calculate consecutive day streak from mood logs
  static int _calculateStreak(List<dynamic> logs) {
    if (logs.isEmpty) return 0;
    
    final dateSet = logs.map((log) {
      final createdAt = log.createdAt as DateTime;
      return DateTime(createdAt.year, createdAt.month, createdAt.day);
    }).toSet();
    
    var currentDate = DateTime.now();
    currentDate = DateTime(currentDate.year, currentDate.month, currentDate.day);
    var streak = 0;
    
    while (dateSet.contains(currentDate)) {
      streak++;
      currentDate = currentDate.subtract(const Duration(days: 1));
    }
    
    return streak;
  }

  /// Section header with consistent styling
  Widget _buildSectionHeader(BuildContext context, String title) {
    final theme = Theme.of(context);
    return Text(
      title,
      style: theme.textTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.w700,
        color: theme.colorScheme.onSurface,
        letterSpacing: -0.5,
      ),
    );
  }

  /// Large primary action card with gradient background
  Widget _buildPrimaryActionCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String description,
    required Gradient gradient,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: (gradient.colors.first).withOpacity(0.25),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(24.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  icon,
                  size: 36,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      description,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withOpacity(0.9),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 18,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Compact secondary action card for 2-column grid
  Widget _buildSecondaryActionCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: theme.colorScheme.outline.withOpacity(0.15),
          width: 1.5,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  size: 28,
                  color: color,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: theme.colorScheme.onSurface.withOpacity(0.4),
              ),
            ],
          ),
        ),
      ),
    );
  }

}
