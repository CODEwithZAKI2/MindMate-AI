import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/notification_provider.dart';

class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final settings = ref.watch(notificationSettingsProvider);
    final notifier = ref.read(notificationSettingsProvider.notifier);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: Container(
          margin: const EdgeInsets.only(left: 12),
          child: IconButton(
            icon: Icon(
              Icons.arrow_back_ios_rounded,
              color: theme.colorScheme.onSurface,
              size: 20,
            ),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        title: Text(
          'Notifications',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header illustration
              Center(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer.withOpacity(0.3),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.notifications_active_rounded,
                    size: 64,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  'Stay on track with gentle reminders',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Daily Reminder Section
              _buildSectionHeader(context, 'Daily Mood Check-in'),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withOpacity(
                    0.4,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    // Enable toggle
                    _buildSettingTile(
                      context: context,
                      icon: Icons.alarm_rounded,
                      title: 'Daily Reminder',
                      subtitle: 'Get reminded to log your mood',
                      trailing: Switch(
                        value: settings.dailyReminderEnabled,
                        onChanged: (value) async {
                          if (value) {
                            // Request permission first
                            await notifier.requestPermissions();
                          }
                          await notifier.toggleDailyReminder(value);
                        },
                      ),
                    ),
                    if (settings.dailyReminderEnabled) ...[
                      Divider(
                        height: 1,
                        indent: 20,
                        endIndent: 20,
                        color: theme.colorScheme.outline.withOpacity(0.1),
                      ),
                      // Time picker
                      _buildSettingTile(
                        context: context,
                        icon: Icons.schedule_rounded,
                        title: 'Reminder Time',
                        subtitle: settings.reminderTimeFormatted,
                        trailing: Icon(
                          Icons.chevron_right_rounded,
                          color: theme.colorScheme.onSurface.withOpacity(0.4),
                        ),
                        onTap: () => _showTimePicker(context, ref),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Streak Reminder Section
              _buildSectionHeader(context, 'Streak Reminders'),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withOpacity(
                    0.4,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: _buildSettingTile(
                  context: context,
                  icon: Icons.local_fire_department_rounded,
                  title: 'Streak Reminder',
                  subtitle: 'Get reminded to maintain your streak',
                  trailing: Switch(
                    value: settings.streakReminderEnabled,
                    onChanged: (value) => notifier.toggleStreakReminder(value),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Test notification button
              Center(
                child: TextButton.icon(
                  onPressed: () async {
                    await notifier.showTestNotification();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Test notification sent!'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.send_rounded),
                  label: const Text('Send Test Notification'),
                ),
              ),
              const SizedBox(height: 24),

              // Info card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: theme.colorScheme.primary.withOpacity(0.1),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      color: theme.colorScheme.primary,
                      size: 24,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        'Notifications help you build a consistent mood tracking habit for better mental wellness.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    final theme = Theme.of(context);
    return Text(
      title,
      style: theme.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
      ),
    );
  }

  Widget _buildSettingTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget trailing,
    VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 22, color: theme.colorScheme.primary),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }

  void _showTimePicker(BuildContext context, WidgetRef ref) async {
    final settings = ref.read(notificationSettingsProvider);
    final notifier = ref.read(notificationSettingsProvider.notifier);

    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: settings.reminderHour,
        minute: settings.reminderMinute,
      ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            timePickerTheme: TimePickerThemeData(
              backgroundColor: Theme.of(context).colorScheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      await notifier.updateReminderTime(picked.hour, picked.minute);
    }
  }
}
