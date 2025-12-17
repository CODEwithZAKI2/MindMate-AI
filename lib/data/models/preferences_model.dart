import 'package:cloud_firestore/cloud_firestore.dart';

/// Data model for User Preferences with Firestore serialization
class UserPreferencesModel {
  final String userId;
  final NotificationPreferences notifications;
  final PrivacyPreferences privacy;
  final WellnessPreferences wellness;
  final UIPreferences ui;

  UserPreferencesModel({
    required this.userId,
    required this.notifications,
    required this.privacy,
    required this.wellness,
    required this.ui,
  });

  factory UserPreferencesModel.defaultPreferences(String userId) {
    return UserPreferencesModel(
      userId: userId,
      notifications: NotificationPreferences(),
      privacy: PrivacyPreferences(),
      wellness: WellnessPreferences(),
      ui: UIPreferences(),
    );
  }

  factory UserPreferencesModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserPreferencesModel(
      userId: doc.id,
      notifications: NotificationPreferences.fromMap(
          data['notifications'] as Map<String, dynamic>? ?? {}),
      privacy: PrivacyPreferences.fromMap(
          data['privacy'] as Map<String, dynamic>? ?? {}),
      wellness: WellnessPreferences.fromMap(
          data['wellness'] as Map<String, dynamic>? ?? {}),
      ui: UIPreferences.fromMap(data['ui'] as Map<String, dynamic>? ?? {}),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'notifications': notifications.toMap(),
      'privacy': privacy.toMap(),
      'wellness': wellness.toMap(),
      'ui': ui.toMap(),
    };
  }
}

class NotificationPreferences {
  final bool dailyCheckIn;
  final String dailyCheckInTime; // HH:mm format
  final bool weeklyInsights;
  final bool streakReminders;

  NotificationPreferences({
    this.dailyCheckIn = true,
    this.dailyCheckInTime = '09:00',
    this.weeklyInsights = true,
    this.streakReminders = true,
  });

  factory NotificationPreferences.fromMap(Map<String, dynamic> data) {
    return NotificationPreferences(
      dailyCheckIn: data['dailyCheckIn'] as bool? ?? true,
      dailyCheckInTime: data['dailyCheckInTime'] as String? ?? '09:00',
      weeklyInsights: data['weeklyInsights'] as bool? ?? true,
      streakReminders: data['streakReminders'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'dailyCheckIn': dailyCheckIn,
      'dailyCheckInTime': dailyCheckInTime,
      'weeklyInsights': weeklyInsights,
      'streakReminders': streakReminders,
    };
  }
}

class PrivacyPreferences {
  final bool analyticsEnabled;
  final int chatHistoryRetentionDays; // 30, 90, or 365

  PrivacyPreferences({
    this.analyticsEnabled = true,
    this.chatHistoryRetentionDays = 90,
  });

  factory PrivacyPreferences.fromMap(Map<String, dynamic> data) {
    return PrivacyPreferences(
      analyticsEnabled: data['analyticsEnabled'] as bool? ?? true,
      chatHistoryRetentionDays:
          data['chatHistoryRetentionDays'] as int? ?? 90,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'analyticsEnabled': analyticsEnabled,
      'chatHistoryRetentionDays': chatHistoryRetentionDays,
    };
  }
}

class WellnessPreferences {
  final List<String> preferredExercises;
  final List<String> triggerTopics;

  WellnessPreferences({
    this.preferredExercises = const [],
    this.triggerTopics = const [],
  });

  factory WellnessPreferences.fromMap(Map<String, dynamic> data) {
    return WellnessPreferences(
      preferredExercises:
          List<String>.from(data['preferredExercises'] as List? ?? []),
      triggerTopics: List<String>.from(data['triggerTopics'] as List? ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'preferredExercises': preferredExercises,
      'triggerTopics': triggerTopics,
    };
  }
}

class UIPreferences {
  final bool darkMode;
  final String fontSize; // 'small', 'medium', 'large'

  UIPreferences({
    this.darkMode = false,
    this.fontSize = 'medium',
  });

  factory UIPreferences.fromMap(Map<String, dynamic> data) {
    return UIPreferences(
      darkMode: data['darkMode'] as bool? ?? false,
      fontSize: data['fontSize'] as String? ?? 'medium',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'darkMode': darkMode,
      'fontSize': fontSize,
    };
  }
}
