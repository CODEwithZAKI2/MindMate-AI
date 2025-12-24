import 'package:flutter/material.dart';

/// Therapeutic color palette for mental health app
/// Designed to feel: Calm, Safe, Warm, Human, Premium
class AppColors {
  // Primary Colors - Serene Blue (Trust, Calm, Safety)
  static const Color primary = Color(0xFF5B8FB9); // Serene Blue
  static const Color primaryLight = Color(0xFF7EAFD4);
  static const Color primaryDark = Color(0xFF3D6B8E);
  static const Color primaryContainer = Color(0xFFE8F3F8);

  // Secondary Colors - Soft Coral (Hope, Energy, Connection)
  static const Color secondary = Color(0xFFE88B6C); // Soft Coral
  static const Color secondaryLight = Color(0xFFF3AB91);
  static const Color secondaryDark = Color(0xFFC86A48);
  static const Color secondaryContainer = Color(0xFFFFF0EC);

  // Tertiary Colors - Sage Green (Growth, Peace, Nature)
  static const Color tertiary = Color(0xFF88B0A8); // Sage Green
  static const Color tertiaryLight = Color(0xFFA8C9C2);
  static const Color tertiaryDark = Color(0xFF6A8E86);
  static const Color tertiaryContainer = Color(0xFFE8F3F1);

  // Mood Colors - Refined for emotional context
  static const Color moodVeryBad = Color(0xFFE07A7A); // Soft red
  static const Color moodBad = Color(0xFFF4A574); // Warm orange
  static const Color moodOkay = Color(0xFFF9C86D); // Golden yellow
  static const Color moodGood = Color(0xFF8BC48A); // Gentle green
  static const Color moodVeryGood = Color(0xFF7AC29A); // Vibrant green

  // Background Colors - Soft, Warm Neutrals
  static const Color backgroundLight = Color(0xFFF8F9FA);
  static const Color backgroundDark = Color(0xFF121212);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceDark = Color(0xFF1E1E1E);
  static const Color surfaceVariantLight = Color(0xFFF3F4F6);
  static const Color surfaceVariantDark = Color(0xFF2C2C2C);

  // Text Colors - Softer than pure black
  static const Color textPrimaryLight = Color(0xFF2C3E50);
  static const Color textSecondaryLight = Color(0xFF6B7280);
  static const Color textTertiaryLight = Color(0xFF9CA3AF);
  static const Color textPrimaryDark = Color(0xFFE8E8E8);
  static const Color textSecondaryDark = Color(0xFFB0B0B0);
  static const Color textTertiaryDark = Color(0xFF808080);

  // Semantic Colors
  static const Color success = Color(0xFF7AC29A);
  static const Color warning = Color(0xFFF4A574);
  static const Color error = Color(0xFFE07A7A);
  static const Color info = Color(0xFF5B8FB9);

  // Crisis & Safety
  static const Color crisis = Color(0xFFE07A7A);
  static const Color crisisBackground = Color(0xFFFFF0EC);
  static const Color safetyGreen = Color(0xFF7AC29A);

  // Chat Colors
  static const Color userMessageBg = Color(0xFF5B8FB9);
  static const Color aiMessageBg = Color(0xFFF3F4F6);
  static const Color userMessageBgDark = Color(0xFF7EAFD4);
  static const Color aiMessageBgDark = Color(0xFF2C2C2C);

  // Dividers & Borders
  static const Color dividerLight = Color(0xFFE5E7EB);
  static const Color dividerDark = Color(0xFF3A3A3A);
  static const Color borderLight = Color(0xFFD1D5DB);
  static const Color borderDark = Color(0xFF4A4A4A);

  // Premium
  static const Color premium = Color(0xFFFFD700);
  static const Color premiumGradientStart = Color(0xFFFFD700);
  static const Color premiumGradientEnd = Color(0xFFFFA500);

  // Overlay
  static const Color overlayLight = Color(0x66000000);
  static const Color overlayDark = Color(0x99000000);

  // Shadow - Softer shadows
  static const Color shadowLight = Color(0x0F000000); // rgba(0,0,0,0.06)
  static const Color shadowDark = Color(0x3D000000);

  // Gradients - Therapeutic and calming
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, primaryLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient secondaryGradient = LinearGradient(
    colors: [secondary, secondaryLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient tertiaryGradient = LinearGradient(
    colors: [tertiary, tertiaryLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient premiumGradient = LinearGradient(
    colors: [premiumGradientStart, premiumGradientEnd],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient moodGradient = LinearGradient(
    colors: [moodVeryBad, moodBad, moodOkay, moodGood, moodVeryGood],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  // Warm welcome gradient
  static const LinearGradient welcomeGradient = LinearGradient(
    colors: [
      Color(0xFFE8F3F8), // primaryContainer
      Color(0xFFFFF0EC), // secondaryContainer
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Private Constructor
  AppColors._();
}
