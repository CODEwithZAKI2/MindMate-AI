/// Route names for the app
class Routes {
  // Splash & Onboarding
  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String disclaimer = '/disclaimer';

  // Auth
  static const String signIn = '/signin';
  static const String signUp = '/signup';
  static const String forgotPassword = '/forgot-password';

  // Main App
  static const String home = '/home';
  static const String chat = '/chat';
  static const String chatHistory = '/chat-history';
  static const String mood = '/mood';
  static const String insights = '/insights';
  static const String exercises = '/exercises';
  static const String settings = '/settings';

  // Nested Routes
  static const String moodHistory = '/mood/history';
  static const String moodCheckIn = '/mood/check-in';
  static const String chatSession = '/chat/:sessionId';
  static const String exerciseDetail = '/exercises/:exerciseId';
  static const String weeklyInsights = '/insights/weekly';
  static const String monthlyInsights = '/insights/monthly';

  // Settings Sub-routes
  static const String profile = '/settings/profile';
  static const String notifications = '/settings/notifications';
  static const String privacy = '/settings/privacy';
  static const String about = '/settings/about';
  static const String help = '/settings/help';

  // Crisis
  static const String crisis = '/crisis';

  // Premium
  static const String premium = '/premium';
  static const String subscription = '/subscription';

  // Private Constructor
  Routes._();
}
