import 'package:flutter/material.dart';

class AppColors {
  // Primary Accent: Tangerine / Coral
  static const Color accentTangerine = Color(0xFFFF6A3D);
  static const Color softTangerine = Color(0xFFFFE9E1);

  // Alternative Accents
  static const Color accentGrape = Color(0xFF7C5CFF);
  static const Color softGrape = Color(0xFFECE7FF);

  static const Color accentLime = Color(0xFF12B56A);
  static const Color softLime = Color(0xFFDCF6E8);

  static const Color accentOcean = Color(0xFF0AA5E0);
  static const Color softOcean = Color(0xFFDAF0FB);

  // Base Neutrals
  static const Color bg = Color(0xFFF5F2EC);
  static const Color card = Color(0xFFFFFFFF);
  static const Color darkBg = Color(0xFF0F0E13);
  static const Color backgroundDark = darkBg;
  static const Color darkCard = Color(0xFF191722);
  static const Color cardDark = darkCard;
  static const Color ink = Color(0xFF191722);
  static const Color mut = Color(0xFF726E7C);
  static const Color line = Color(0x1414121E); // rgba(20,18,30,.08)
  static const Color success = Color(0xFF12B56A);
  static const Color warning = Color(0xFFFF9800);
  static const Color error = Color(0xFFE53935);
}

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.bg,
      colorScheme: const ColorScheme.light(
        primary: AppColors.accentTangerine,
        secondary: AppColors.accentGrape,
        surface: AppColors.card,
        error: AppColors.error,
        onPrimary: Colors.white,
        onSurface: AppColors.ink,
      ),
      fontFamily: 'sans-serif',
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: AppColors.ink),
        titleTextStyle: TextStyle(
          color: AppColors.ink,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
      ),
      cardTheme: CardTheme(
        color: AppColors.card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.line, width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accentTangerine,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.ink,
          side: const BorderSide(color: AppColors.line, width: 1),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: AppColors.accentTangerine,
        inactiveTrackColor: AppColors.line,
        thumbColor: AppColors.accentTangerine,
        overlayColor: AppColors.softTangerine.withOpacity(0.5),
        trackHeight: 6,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith<Color>((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.white;
          }
          return Colors.white;
        }),
        trackColor: WidgetStateProperty.resolveWith<Color>((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.accentTangerine;
          }
          return AppColors.line;
        }),
      ),
    );
  }
}
