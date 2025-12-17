import 'package:flutter/material.dart';

/// App color palette
class AppColors {
  // Primary Colors - Calming Blues & Purples
  static const Color primary = Color(0xFF6B4CE6); // Soft Purple
  static const Color primaryLight = Color(0xFF9B7EF7);
  static const Color primaryDark = Color(0xFF4A2FB8);
  static const Color primaryContainer = Color(0xFFE8DEFF);

  // Secondary Colors - Warm & Welcoming
  static const Color secondary = Color(0xFF4ECDC4); // Teal
  static const Color secondaryLight = Color(0xFF7EDDD7);
  static const Color secondaryDark = Color(0xFF2BA89F);
  static const Color secondaryContainer = Color(0xFFD1F5F3);

  // Mood Colors
  static const Color moodVeryBad = Color(0xFFFF6B6B); // Red
  static const Color moodBad = Color(0xFFFFB366); // Orange
  static const Color moodOkay = Color(0xFFFECA57); // Yellow
  static const Color moodGood = Color(0xFF48C9B0); // Green
  static const Color moodVeryGood = Color(0xFF6BCF7F); // Bright Green

  // Background Colors
  static const Color backgroundLight = Color(0xFFFAFAFA);
  static const Color backgroundDark = Color(0xFF121212);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceDark = Color(0xFF1E1E1E);
  static const Color surfaceVariantLight = Color(0xFFF5F5F5);
  static const Color surfaceVariantDark = Color(0xFF2C2C2C);

  // Text Colors
  static const Color textPrimaryLight = Color(0xFF1A1A1A);
  static const Color textSecondaryLight = Color(0xFF666666);
  static const Color textTertiaryLight = Color(0xFF999999);
  static const Color textPrimaryDark = Color(0xFFE8E8E8);
  static const Color textSecondaryDark = Color(0xFFB0B0B0);
  static const Color textTertiaryDark = Color(0xFF808080);

  // Semantic Colors
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFF9800);
  static const Color error = Color(0xFFF44336);
  static const Color info = Color(0xFF2196F3);

  // Crisis & Safety
  static const Color crisis = Color(0xFFE53935);
  static const Color crisisBackground = Color(0xFFFFEBEE);
  static const Color safetyGreen = Color(0xFF43A047);

  // Chat Colors
  static const Color userMessageBg = Color(0xFF6B4CE6);
  static const Color aiMessageBg = Color(0xFFF0F0F0);
  static const Color userMessageBgDark = Color(0xFF7B5CF6);
  static const Color aiMessageBgDark = Color(0xFF2C2C2C);

  // Dividers & Borders
  static const Color dividerLight = Color(0xFFE0E0E0);
  static const Color dividerDark = Color(0xFF3A3A3A);
  static const Color borderLight = Color(0xFFD0D0D0);
  static const Color borderDark = Color(0xFF4A4A4A);

  // Premium
  static const Color premium = Color(0xFFFFD700);
  static const Color premiumGradientStart = Color(0xFFFFD700);
  static const Color premiumGradientEnd = Color(0xFFFFA500);

  // Overlay
  static const Color overlayLight = Color(0x66000000);
  static const Color overlayDark = Color(0x99000000);

  // Shadow
  static const Color shadowLight = Color(0x1A000000);
  static const Color shadowDark = Color(0x3D000000);

  // Gradients
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

  // Private Constructor
  AppColors._();
}
