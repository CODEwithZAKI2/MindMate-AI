import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/services/notification_service.dart';
import '../../data/repositories/notification_repository.dart';
import '../../domain/entities/notification_settings.dart';

/// Provider for SharedPreferences instance
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError(
    'SharedPreferences not initialized. Override in main.dart',
  );
});

/// Provider for NotificationRepository
final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return NotificationRepository(prefs);
});

/// Provider for NotificationService singleton
final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

/// StateNotifier for notification settings
class NotificationSettingsNotifier extends StateNotifier<NotificationSettings> {
  final NotificationRepository _repository;
  final NotificationService _service;

  NotificationSettingsNotifier(this._repository, this._service)
    : super(_repository.getSettings()) {
    // Apply current settings on initialization
    _service.applySettings(state);
  }

  /// Toggle daily reminder
  Future<void> toggleDailyReminder(bool enabled) async {
    final newSettings = await _repository.setDailyReminderEnabled(enabled);
    state = newSettings;
    await _service.applySettings(newSettings);
  }

  /// Update reminder time
  Future<void> updateReminderTime(int hour, int minute) async {
    final newSettings = await _repository.setReminderTime(hour, minute);
    state = newSettings;
    if (state.dailyReminderEnabled) {
      await _service.applySettings(newSettings);
    }
  }

  /// Toggle streak reminder
  Future<void> toggleStreakReminder(bool enabled) async {
    final newSettings = await _repository.setStreakReminderEnabled(enabled);
    state = newSettings;
    await _service.applySettings(newSettings);
  }

  /// Request notification permissions
  Future<bool> requestPermissions() async {
    return await _service.requestPermissions();
  }

  /// Show test notification
  Future<void> showTestNotification() async {
    await _service.showTestNotification();
  }
}

/// Provider for NotificationSettingsNotifier
final notificationSettingsProvider =
    StateNotifierProvider<NotificationSettingsNotifier, NotificationSettings>((
      ref,
    ) {
      final repository = ref.watch(notificationRepositoryProvider);
      final service = ref.watch(notificationServiceProvider);
      return NotificationSettingsNotifier(repository, service);
    });
