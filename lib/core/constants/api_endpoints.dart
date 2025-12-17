/// API endpoint constants
class ApiEndpoints {
  // Base URL - Cloud Functions for mindmate-ai-eada4
  static const String baseUrl =
      'https://us-central1-mindmate-ai-eada4.cloudfunctions.net/api';

  // Auth Endpoints
  static const String signIn = '/auth/signin';
  static const String signUp = '/auth/signup';
  static const String signOut = '/auth/signout';
  static const String refreshToken = '/auth/refresh';

  // Chat Endpoints
  static const String chatMessage = '/chat/message';
  static const String chatSessions = '/chat/sessions';
  static String chatSession(String sessionId) => '/chat/sessions/$sessionId';
  static String deleteSession(String sessionId) =>
      '/chat/sessions/$sessionId';

  // Mood Endpoints
  static const String mood = '/mood';
  static const String moodLogs = '/mood/logs';
  static const String moodTrends = '/mood/trends';
  static String deleteMoodLog(String logId) => '/mood/logs/$logId';

  // User Endpoints
  static const String userProfile = '/user/profile';
  static const String userPreferences = '/user/preferences';
  static const String deleteAccount = '/user/account';

  // Analytics Endpoints
  static const String weeklyInsights = '/analytics/weekly';
  static const String monthlyReport = '/analytics/monthly';

  // Crisis Resources
  static const String crisisResources = '/resources/crisis';

  // Health Check
  static const String healthCheck = '/health';

  // Private Constructor
  ApiEndpoints._();
}

/// External URLs
class ExternalUrls {
  // Crisis Resources
  static const String suicidePreventionLifeline = 'tel:988';
  static const String crisisTextLine = 'sms:741741';
  static const String iaspDirectory =
      'https://www.iasp.info/resources/Crisis_Centres/';

  // Legal
  static const String privacyPolicy = 'https://mindmate-ai.com/privacy';
  static const String termsOfService = 'https://mindmate-ai.com/terms';
  static const String supportEmail = 'mailto:support@mindmate-ai.com';

  // Social
  static const String website = 'https://mindmate-ai.com';
  static const String twitter = 'https://twitter.com/mindmateai';
  static const String instagram = 'https://instagram.com/mindmateai';

  // Private Constructor
  ExternalUrls._();
}
