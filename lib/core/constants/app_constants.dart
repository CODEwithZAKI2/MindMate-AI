/// Application-wide constants
class AppConstants {
  // App Info
  static const String appName = 'MindMate AI';
  static const String appVersion = '1.0.0';
  static const String appDescription =
      'Your compassionate mental wellness companion';

  // API Configuration
  static const String apiTimeout = '30'; // seconds
  static const int apiRetryAttempts = 3;

  // Rate Limiting
  static const int maxChatMessagesPerHour = 30;
  static const int maxMoodLogsPerHour = 10;
  static const int maxApiRequestsPerHour = 200;

  // Conversation Memory
  static const int chatContextMessageCount = 10;
  static const int sessionSummaryCount = 5;
  static const int moodContextDays = 7;

  // UI Constants
  static const double defaultPadding = 16.0;
  static const double smallPadding = 8.0;
  static const double largePadding = 24.0;
  static const double borderRadius = 12.0;
  static const double smallBorderRadius = 8.0;

  // Animation Durations
  static const Duration shortAnimation = Duration(milliseconds: 200);
  static const Duration mediumAnimation = Duration(milliseconds: 300);
  static const Duration longAnimation = Duration(milliseconds: 500);

  // Mood Scale
  static const int minMoodScore = 1;
  static const int maxMoodScore = 5;
  static const List<String> moodLabels = [
    'Very Bad',
    'Bad',
    'Okay',
    'Good',
    'Very Good'
  ];
  static const List<String> moodEmojis = ['😢', '😕', '😐', '🙂', '😊'];

  // Chat Configuration
  static const int maxMessageLength = 500;
  static const int maxNoteLength = 500;
  static const String chatLoadingMessage = 'MindMate is thinking...';

  // Data Retention
  static const int defaultChatRetentionDays = 90;
  static const List<int> chatRetentionOptions = [30, 90, 365];

  // Age Gate
  static const int minimumAge = 18;

  // Notification Times
  static const String defaultCheckInTime = '20:00';

  // Session Configuration
  static const int sessionTimeoutMinutes = 30;
  static const int maxConcurrentSessions = 1;

  // Error Messages
  static const String genericErrorMessage =
      'Something went wrong. Please try again.';
  static const String networkErrorMessage =
      'No internet connection. Please check your network.';
  static const String authErrorMessage = 'Authentication failed. Please sign in again.';
  static const String rateLimitErrorMessage =
      'Too many requests. Please try again in a few minutes.';

  // Crisis Detection
  static const String crisisDetectedMessage =
      'I\'m concerned about what you\'ve shared. Your safety matters most right now.';

  // Firestore Collections
  static const String usersCollection = 'users';
  static const String moodLogsCollection = 'moodLogs';
  static const String chatHistoryCollection = 'chatHistory';
  static const String preferencesCollection = 'preferences';
  static const String crisisEventsCollection = 'crisisEvents';

  // SharedPreferences Keys
  static const String keyAuthToken = 'auth_token';
  static const String keyUserId = 'user_id';
  static const String keyOnboardingComplete = 'onboarding_complete';
  static const String keyDisclaimerAccepted = 'disclaimer_accepted';
  static const String keyDarkMode = 'dark_mode';
  static const String keyNotificationsEnabled = 'notifications_enabled';

  // Private Constructor
  AppConstants._();
}
