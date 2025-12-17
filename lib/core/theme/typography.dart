import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Typography system for the app
class AppTypography {
  // Font Family
  static TextStyle get _baseTextStyle => GoogleFonts.inter();

  // Display Styles - For large, impactful text
  static TextStyle displayLarge = _baseTextStyle.copyWith(
    fontSize: 57,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.25,
    height: 1.12,
  );

  static TextStyle displayMedium = _baseTextStyle.copyWith(
    fontSize: 45,
    fontWeight: FontWeight.w700,
    letterSpacing: 0,
    height: 1.16,
  );

  static TextStyle displaySmall = _baseTextStyle.copyWith(
    fontSize: 36,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    height: 1.22,
  );

  // Headline Styles - For section headers
  static TextStyle headlineLarge = _baseTextStyle.copyWith(
    fontSize: 32,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    height: 1.25,
  );

  static TextStyle headlineMedium = _baseTextStyle.copyWith(
    fontSize: 28,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    height: 1.29,
  );

  static TextStyle headlineSmall = _baseTextStyle.copyWith(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    height: 1.33,
  );

  // Title Styles - For card titles and list items
  static TextStyle titleLarge = _baseTextStyle.copyWith(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    height: 1.27,
  );

  static TextStyle titleMedium = _baseTextStyle.copyWith(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.15,
    height: 1.50,
  );

  static TextStyle titleSmall = _baseTextStyle.copyWith(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
    height: 1.43,
  );

  // Body Styles - For main content
  static TextStyle bodyLarge = _baseTextStyle.copyWith(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.5,
    height: 1.50,
  );

  static TextStyle bodyMedium = _baseTextStyle.copyWith(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.25,
    height: 1.43,
  );

  static TextStyle bodySmall = _baseTextStyle.copyWith(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.4,
    height: 1.33,
  );

  // Label Styles - For buttons and small text
  static TextStyle labelLarge = _baseTextStyle.copyWith(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.1,
    height: 1.43,
  );

  static TextStyle labelMedium = _baseTextStyle.copyWith(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.5,
    height: 1.33,
  );

  static TextStyle labelSmall = _baseTextStyle.copyWith(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.5,
    height: 1.45,
  );

  // Specialized Styles

  // Chat Message
  static TextStyle chatMessage = bodyMedium.copyWith(
    fontSize: 15,
    height: 1.4,
  );

  // Chat Timestamp
  static TextStyle chatTimestamp = labelSmall.copyWith(
    fontSize: 10,
    color: Colors.grey,
  );

  // Button Text
  static TextStyle button = labelLarge.copyWith(
    fontWeight: FontWeight.w600,
    letterSpacing: 1.25,
  );

  // Input Label
  static TextStyle inputLabel = labelMedium.copyWith(
    fontWeight: FontWeight.w600,
  );

  // Error Text
  static TextStyle errorText = bodySmall.copyWith(
    color: Colors.red,
  );

  // Caption
  static TextStyle caption = labelSmall.copyWith(
    fontStyle: FontStyle.italic,
  );

  // Overline
  static TextStyle overline = labelSmall.copyWith(
    fontWeight: FontWeight.w600,
    letterSpacing: 1.5,
    textBaseline: TextBaseline.alphabetic,
  );

  // Mood Label
  static TextStyle moodLabel = titleMedium.copyWith(
    fontWeight: FontWeight.w500,
  );

  // Stat Number (for insights)
  static TextStyle statNumber = displaySmall.copyWith(
    fontWeight: FontWeight.w700,
    fontFeatures: [const FontFeature.tabularFigures()],
  );

  // Stat Label
  static TextStyle statLabel = bodySmall.copyWith(
    fontWeight: FontWeight.w500,
    letterSpacing: 0.5,
  );

  // Quote (for journaling)
  static TextStyle quote = bodyLarge.copyWith(
    fontStyle: FontStyle.italic,
    height: 1.6,
  );

  // Private Constructor
  AppTypography._();
}

/// Text theme extension for convenience
extension TextStyleHelpers on TextStyle {
  TextStyle get bold => copyWith(fontWeight: FontWeight.bold);
  TextStyle get semiBold => copyWith(fontWeight: FontWeight.w600);
  TextStyle get medium => copyWith(fontWeight: FontWeight.w500);
  TextStyle get regular => copyWith(fontWeight: FontWeight.w400);
  TextStyle get light => copyWith(fontWeight: FontWeight.w300);

  TextStyle withColor(Color color) => copyWith(color: color);
  TextStyle withSize(double size) => copyWith(fontSize: size);
  TextStyle withHeight(double height) => copyWith(height: height);
  TextStyle withSpacing(double spacing) => copyWith(letterSpacing: spacing);
}
