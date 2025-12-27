import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/notification_settings.dart';

/// Repository for managing notification settings in local storage
class NotificationRepository {
  static const String _settingsKey = 'notification_settings';

  final SharedPreferences _prefs;

  NotificationRepository(this._prefs);

  /// Get current notification settings
  NotificationSettings getSettings() {
    final jsonString = _prefs.getString(_settingsKey);
    if (jsonString == null) {
      return const NotificationSettings();
    }
    try {
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      return NotificationSettings.fromJson(json);
    } catch (e) {
      return const NotificationSettings();
    }
  }

  /// Save notification settings
  Future<void> saveSettings(NotificationSettings settings) async {
    final jsonString = jsonEncode(settings.toJson());
    await _prefs.setString(_settingsKey, jsonString);
  }

  /// Update daily reminder enabled state
  Future<NotificationSettings> setDailyReminderEnabled(bool enabled) async {
    final settings = getSettings().copyWith(dailyReminderEnabled: enabled);
    await saveSettings(settings);
    return settings;
  }

  /// Update reminder time
  Future<NotificationSettings> setReminderTime(int hour, int minute) async {
    final settings = getSettings().copyWith(
      reminderHour: hour,
      reminderMinute: minute,
    );
    await saveSettings(settings);
    return settings;
  }

  /// Update streak reminder enabled state
  Future<NotificationSettings> setStreakReminderEnabled(bool enabled) async {
    final settings = getSettings().copyWith(streakReminderEnabled: enabled);
    await saveSettings(settings);
    return settings;
  }
}
