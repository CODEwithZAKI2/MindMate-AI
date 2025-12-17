/// Asset paths for images, icons, animations, etc.
class AssetPaths {
  // Base directories
  static const String _images = 'assets/images';
  static const String _icons = 'assets/icons';
  static const String _animations = 'assets/animations';

  // Onboarding Images
  static const String onboarding1 = '$_images/onboarding_1.png';
  static const String onboarding2 = '$_images/onboarding_2.png';
  static const String onboarding3 = '$_images/onboarding_3.png';

  // Logo & Branding
  static const String appLogo = '$_images/logo.png';
  static const String appLogoWhite = '$_images/logo_white.png';
  static const String splashBackground = '$_images/splash_bg.png';

  // Empty States
  static const String emptyChat = '$_images/empty_chat.png';
  static const String emptyMood = '$_images/empty_mood.png';
  static const String emptyInsights = '$_images/empty_insights.png';
  static const String noConnection = '$_images/no_connection.png';

  // Mood Icons
  static const String moodVeryBad = '$_icons/mood_very_bad.svg';
  static const String moodBad = '$_icons/mood_bad.svg';
  static const String moodOkay = '$_icons/mood_okay.svg';
  static const String moodGood = '$_icons/mood_good.svg';
  static const String moodVeryGood = '$_icons/mood_very_good.svg';

  // Feature Icons
  static const String iconChat = '$_icons/chat.svg';
  static const String iconMood = '$_icons/mood.svg';
  static const String iconInsights = '$_icons/insights.svg';
  static const String iconExercises = '$_icons/exercises.svg';
  static const String iconSettings = '$_icons/settings.svg';

  // Crisis & Safety
  static const String crisisIcon = '$_icons/crisis.svg';
  static const String safetyShield = '$_icons/safety_shield.svg';

  // Animations (Lottie)
  static const String loadingAnimation = '$_animations/loading.json';
  static const String successAnimation = '$_animations/success.json';
  static const String breathingAnimation = '$_animations/breathing.json';
  static const String meditationAnimation = '$_animations/meditation.json';

  // Achievement Badges
  static const String badge7DayStreak = '$_icons/badge_7_days.svg';
  static const String badge30DayStreak = '$_icons/badge_30_days.svg';
  static const String badgeFirstChat = '$_icons/badge_first_chat.svg';
  static const String badgeMoodMaster = '$_icons/badge_mood_master.svg';

  // Premium
  static const String premiumBadge = '$_icons/premium_badge.svg';
  static const String premiumBackground = '$_images/premium_bg.png';

  // Social Login
  static const String googleIcon = '$_icons/google.svg';
  static const String appleIcon = '$_icons/apple.svg';

  // Private Constructor
  AssetPaths._();
}

/// Localization asset paths
class L10nPaths {
  static const String enUS = 'assets/l10n/app_en.arb';
  static const String esES = 'assets/l10n/app_es.arb';
  static const String frFR = 'assets/l10n/app_fr.arb';
  static const String deDE = 'assets/l10n/app_de.arb';

  // Private Constructor
  L10nPaths._();
}
