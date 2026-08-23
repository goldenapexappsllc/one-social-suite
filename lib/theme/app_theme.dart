import 'package:flutter/material.dart';

/// 1PrivateSocial brand theme — black & gold.
/// Gold values matched to goldenapexapps.com's site palette for full
/// cross-platform brand consistency (website, iOS, Android all share
/// the exact same gold tones).
class AppColors {
  AppColors._();

  static const Color black = Color(0xFF000000);
  static const Color surface = Color(0xFF141414);
  static const Color surfaceAlt = Color(0xFF1A1A1A);
  static const Color gold = Color(0xFFC99A2E);      // site --gold
  static const Color goldDeep = Color(0xFF8A6A1F);  // deeper shadow gold
  static const Color goldGlow = Color(0xFFF2D27A);  // site --gold2, highlight
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textMuted = Color(0xFF9E9E9E);
  static const Color border = Color(0x33C99A2E);    // gold @ 20%
}

class AppTheme {
  AppTheme._();

  static ThemeData get dark {
    final ThemeData base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.black,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.gold,
        secondary: AppColors.goldDeep,
        surface: AppColors.surface,
        onPrimary: AppColors.black,
        onSurface: AppColors.textPrimary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.black,
        foregroundColor: AppColors.gold,
        elevation: 0,
        centerTitle: true,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.black,
        selectedItemColor: AppColors.gold,
        unselectedItemColor: AppColors.textMuted,
        type: BottomNavigationBarType.fixed,
        showUnselectedLabels: true,
      ),
      textTheme: base.textTheme.apply(
        bodyColor: AppColors.textPrimary,
        displayColor: AppColors.textPrimary,
      ),
    );
  }
}
