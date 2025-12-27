import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import '../../domain/entities/notification_settings.dart';
import '../utils/logger.dart';

/// Service for managing local notifications
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static const int dailyReminderId = 1;
  static const int streakReminderId = 2;

  /// Callback for when a notification is tapped
  static void Function(String? payload)? onNotificationTap;

  /// Initialize the notification service
  Future<void> initialize() async {
    // Android initialization settings
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    // iOS initialization settings
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );

    AppLogger.info('✅ NotificationService initialized');
  }

  /// Handle notification tap
  void _onNotificationResponse(NotificationResponse response) {
    AppLogger.info('📱 Notification tapped: ${response.payload}');
    if (onNotificationTap != null) {
      onNotificationTap!(response.payload);
    }
  }

  /// Request notification permissions
  Future<bool> requestPermissions() async {
    // Request Android permissions
    final androidPlugin =
        _notifications
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
    if (androidPlugin != null) {
      final granted = await androidPlugin.requestNotificationsPermission();
      AppLogger.info('🔔 Android notification permission: $granted');
      return granted ?? false;
    }

    // Request iOS permissions
    final iosPlugin =
        _notifications
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >();
    if (iosPlugin != null) {
      final granted = await iosPlugin.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      AppLogger.info('🔔 iOS notification permission: $granted');
      return granted ?? false;
    }

    return false;
  }

  /// Schedule daily mood check-in reminder
  Future<void> scheduleDailyReminder({
    required int hour,
    required int minute,
  }) async {
    // Cancel any existing daily reminder
    await cancelDailyReminder();

    // Calculate next notification time
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    // If the time has passed today, schedule for tomorrow
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    const androidDetails = AndroidNotificationDetails(
      'mood_reminder',
      'Mood Check-in Reminder',
      channelDescription: 'Daily reminder to log your mood',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.zonedSchedule(
      dailyReminderId,
      'How are you feeling? 💭',
      'Take a moment to check in with yourself and log your mood.',
      scheduledDate,
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time, // Repeat daily
      payload: 'mood_checkin',
    );

    AppLogger.info(
      '📅 Daily reminder scheduled for ${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}',
    );
  }

  /// Cancel daily reminder
  Future<void> cancelDailyReminder() async {
    await _notifications.cancel(dailyReminderId);
    AppLogger.info('🚫 Daily reminder cancelled');
  }

  /// Schedule streak reminder (next day at same time if streak might break)
  Future<void> scheduleStreakReminder({
    required int currentStreak,
    required int hour,
    required int minute,
  }) async {
    // Cancel any existing streak reminder
    await cancelStreakReminder();

    if (currentStreak <= 0) return;

    // Schedule for tomorrow at the same time
    final now = tz.TZDateTime.now(tz.local);
    final scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day + 1,
      hour,
      minute,
    );

    const androidDetails = AndroidNotificationDetails(
      'streak_reminder',
      'Streak Reminder',
      channelDescription: 'Reminder to keep your mood logging streak',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.zonedSchedule(
      streakReminderId,
      "Don't break your streak! 🔥",
      "You're on a $currentStreak-day streak. Log your mood to keep it going!",
      scheduledDate,
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: 'streak_reminder',
    );

    AppLogger.info('📅 Streak reminder scheduled for tomorrow');
  }

  /// Cancel streak reminder
  Future<void> cancelStreakReminder() async {
    await _notifications.cancel(streakReminderId);
  }

  /// Apply notification settings
  Future<void> applySettings(NotificationSettings settings) async {
    if (settings.dailyReminderEnabled) {
      await scheduleDailyReminder(
        hour: settings.reminderHour,
        minute: settings.reminderMinute,
      );
    } else {
      await cancelDailyReminder();
    }

    if (!settings.streakReminderEnabled) {
      await cancelStreakReminder();
    }
  }

  /// Cancel all notifications
  Future<void> cancelAll() async {
    await _notifications.cancelAll();
    AppLogger.info('🚫 All notifications cancelled');
  }

  /// Show an immediate notification (for testing)
  Future<void> showTestNotification() async {
    const androidDetails = AndroidNotificationDetails(
      'test',
      'Test Notifications',
      channelDescription: 'For testing purposes',
      importance: Importance.high,
      priority: Priority.high,
    );

    const details = NotificationDetails(android: androidDetails);

    await _notifications.show(
      999,
      'Test Notification 🎉',
      'Notifications are working correctly!',
      details,
    );
  }

  /// Schedule a test notification in 10 seconds (for testing scheduled alarms)
  Future<void> showScheduledTestNotification() async {
    // Request exact alarm permission on Android 12+
    final androidPlugin =
        _notifications
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();

    if (androidPlugin != null) {
      // Check and request exact alarm permission
      final exactAlarmPermitted =
          await androidPlugin.requestExactAlarmsPermission();
      AppLogger.info('⏰ Exact alarm permission: $exactAlarmPermitted');
    }

    final scheduledTime = tz.TZDateTime.now(
      tz.local,
    ).add(const Duration(seconds: 10));

    const androidDetails = AndroidNotificationDetails(
      'scheduled_test',
      'Scheduled Test',
      channelDescription: 'For testing scheduled notifications',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const details = NotificationDetails(android: androidDetails);

    await _notifications.zonedSchedule(
      998,
      'Scheduled Test Success! 🎯',
      'This notification was scheduled 10 seconds ago.',
      scheduledTime,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: 'scheduled_test',
    );

    AppLogger.info('📅 Scheduled test notification for: $scheduledTime');
  }

  /// Request exact alarm permission (Android 12+)
  Future<bool> requestExactAlarmPermission() async {
    final androidPlugin =
        _notifications
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();

    if (androidPlugin != null) {
      final granted = await androidPlugin.requestExactAlarmsPermission();
      AppLogger.info('⏰ Exact alarm permission granted: $granted');
      return granted ?? false;
    }
    return true; // Non-Android platforms don't need this
  }
}
