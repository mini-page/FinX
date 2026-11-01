import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_tokens.dart';

/// Centralised [ThemeData] factory for Expensio.
///
/// Use [AppTheme.light] and [AppTheme.dark] instead of building
/// [ThemeData] inline in `main.dart`. This enables global UI updates
/// from a single file and simplifies dark / light theme toggling.
class AppTheme {
  AppTheme._();

  /// Light theme.
  static ThemeData light() {
    return ThemeData(
      scaffoldBackgroundColor: const Color(0xFFF3F7FC),
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primaryBlue,
        primary: AppColors.primaryBlue,
        secondary: AppColors.danger,
        surface: Colors.white,
      ),
      useMaterial3: true,
      textTheme: _textTheme(AppColors.textDark),
      popupMenuTheme: _popupMenuTheme(),
      chipTheme: _chipTheme(Brightness.light),
      snackBarTheme: _snackBarTheme(),
    );
  }

  /// Dark theme.
  static ThemeData dark() {
    return ThemeData(
      scaffoldBackgroundColor: const Color(0xFF0E1626),
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primaryBlueLight,
        brightness: Brightness.dark,
        primary: AppColors.primaryBlueLight,
        secondary: const Color(0xFFFF6C89),
        surface: const Color(0xFF182234),
      ),
      useMaterial3: true,
      textTheme: _textTheme(Colors.white),
      popupMenuTheme: _popupMenuTheme(useDarkTheme: true),
      chipTheme: _chipTheme(Brightness.dark),
      snackBarTheme: _snackBarTheme(),
    );
  }

  static TextTheme _textTheme(Color defaultColor) {
    return TextTheme(
      headlineLarge: AppTextStyles.sectionHeading.copyWith(color: defaultColor),
      headlineMedium: AppTextStyles.sectionHeading
          .copyWith(color: defaultColor, fontSize: 18),
      titleMedium: AppTextStyles.bodyStrong.copyWith(color: defaultColor),
      bodyMedium: AppTextStyles.bodyMuted,
      labelSmall: AppTextStyles.eyebrowOnDark,
    );
  }

  static PopupMenuThemeData _popupMenuTheme({bool useDarkTheme = false}) {
    return PopupMenuThemeData(
      color: useDarkTheme ? const Color(0xFF1A2438) : Colors.white,
      elevation: 0,
      shadowColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.lg),
      ),
      textStyle: TextStyle(
        color: useDarkTheme ? Colors.white : AppColors.textDark,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  static ChipThemeData _chipTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    return ChipThemeData(
      selectedColor: AppColors.primaryBlue,
      secondarySelectedColor: AppColors.primaryBlue,
      backgroundColor: isDark ? const Color(0xFF1A2438) : AppColors.lightBlueBg,
      disabledColor:
          isDark ? const Color(0xFF24334D) : AppColors.surfaceDisabled,
      side: BorderSide(
        color: isDark
            ? AppColors.overlayWhiteSoft
            : AppColors.primaryBlue.withValues(alpha: 0.14),
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      labelStyle: TextStyle(
        color: isDark ? Colors.white : AppColors.textDark,
        fontWeight: FontWeight.w700,
      ),
      secondaryLabelStyle: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w800,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      brightness: brightness,
    );
  }

  static SnackBarThemeData _snackBarTheme() {
    return SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      elevation: 0,
      backgroundColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.lg),
      ),
    );
  }
}
