import 'package:equatable/equatable.dart';

/// Entity representing user notification preferences
class NotificationSettings extends Equatable {
  final bool dailyReminderEnabled;
  final int reminderHour;
  final int reminderMinute;
  final bool streakReminderEnabled;

  const NotificationSettings({
    this.dailyReminderEnabled = false,
    this.reminderHour = 20, // Default: 8 PM
    this.reminderMinute = 0,
    this.streakReminderEnabled = true,
  });

  /// Get reminder time as TimeOfDay-like string
  String get reminderTimeFormatted {
    final hour = reminderHour % 12 == 0 ? 12 : reminderHour % 12;
    final period = reminderHour >= 12 ? 'PM' : 'AM';
    final minute = reminderMinute.toString().padLeft(2, '0');
    return '$hour:$minute $period';
  }

  NotificationSettings copyWith({
    bool? dailyReminderEnabled,
    int? reminderHour,
    int? reminderMinute,
    bool? streakReminderEnabled,
  }) {
    return NotificationSettings(
      dailyReminderEnabled: dailyReminderEnabled ?? this.dailyReminderEnabled,
      reminderHour: reminderHour ?? this.reminderHour,
      reminderMinute: reminderMinute ?? this.reminderMinute,
      streakReminderEnabled:
          streakReminderEnabled ?? this.streakReminderEnabled,
    );
  }

  Map<String, dynamic> toJson() => {
    'dailyReminderEnabled': dailyReminderEnabled,
    'reminderHour': reminderHour,
    'reminderMinute': reminderMinute,
    'streakReminderEnabled': streakReminderEnabled,
  };

  factory NotificationSettings.fromJson(Map<String, dynamic> json) {
    return NotificationSettings(
      dailyReminderEnabled: json['dailyReminderEnabled'] ?? false,
      reminderHour: json['reminderHour'] ?? 20,
      reminderMinute: json['reminderMinute'] ?? 0,
      streakReminderEnabled: json['streakReminderEnabled'] ?? true,
    );
  }

  @override
  List<Object?> get props => [
    dailyReminderEnabled,
    reminderHour,
    reminderMinute,
    streakReminderEnabled,
  ];
}
