import 'package:flutter/material.dart';

class AppColors {
  // Brand Colors
  static const Color primaryBlue = Color(0xFF0A6BE8);
  static const Color primaryBlueLight = Color(0xFF5DA2FF);
  static const Color primaryBlueSoft = Color(0xFF3E90FF);

  // Neutral Colors
  static const Color textDark = Color(0xFF152039);
  static const Color textMuted = Color(0xFF90A1BE);
  static const Color textSubtle = Color(0xFF7D8EA9);
  static const Color textSecondary = Color(0xFF6D7D98);
  static const Color textTertiary = Color(0xFF8F9FB7);
  static const Color backgroundLight = Color(0xFFF1F4F9);
  static const Color surfaceLight = Color(0xFFF6F8FC);
  static const Color surfaceMuted = Color(0xFFF7F9FC);
  static const Color surfaceDisabled = Color(0xFFF1F4F8);
  static const Color surfaceAccent = Color(0xFFEFF5FF);
  static const Color cardShadow = Color(0x1209386D);
  static const Color darkBlueShadow = Color(0x2209386D);
  static const Color overlayScrim = Color(0x42000000);
  static const Color overlayWhiteSoft = Color(0x1FFFFFFF);
  static const Color overlayWhiteMedium = Color(0xB3FFFFFF);
  static const Color overlayWhiteStrong = Color(0xCCFFFFFF);
  static const Color overlayWhiteBold = Color(0xD9FFFFFF);
  static const Color disabledContent = Color(0xFFAAB7CB);

  // Semantic Colors
  static const Color success = Color(0xFF1DAA63);
  static const Color danger = Color(0xFFFF446D);
  static const Color warning = Color(0xFFFFB038);

  // Secondary / Accent
  static const Color accentMint = Color(0xFF45D19A);
  static const Color lightBlueBg = Color(0xFFEFF5FF);
  static const Color accentLime = Color(0xFFD6F57C);
  static const Color accentLimeDark = Color(0xFF253411);

  // Purplish & Pink Theme Accent Colors (Finance Tools visual identity)
  static const Color accentPurple = Color(0xFF8B5CF6);
  static const Color accentPurpleDark = Color(0xFF6D28D9);
  static const Color accentPurpleLight = Color(0xFFDDD6FE);
  static const Color accentPurpleBg = Color(0xFFF5F3FF);

  static const Color accentPink = Color(0xFFEC4899);
  static const Color accentPinkDark = Color(0xFFBE185D);
  static const Color accentPinkLight = Color(0xFFFBCFE8);
  static const Color accentPinkBg = Color(0xFFFDF2F8);

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient backgroundGradient = LinearGradient(
    colors: [
      Color(0xFFEDE9FE), // Soft Lavender/Purple
      Color(0xFFFAF5FF), // Lighter Purple
      Colors.white,      // Pure White at bottom
    ],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    stops: [0.0, 0.25, 0.6],
  );
}
