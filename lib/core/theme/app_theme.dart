import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class KokColors {
  static const primary = Color(0xFFFF2D78);
  static const primaryLight = Color(0xFFFF6BA0);
  static const accent = Color(0xFF7C3AED);
  static const accentLight = Color(0xFFa78bfa);
  static const background = Color(0xFF0A0A0F);
  static const surface = Color(0xFF16161F);
  static const surfaceLight = Color(0xFF1E1E2A);
  static const cardBg = Color(0xFF1A1A26);
  static const textPrimary = Color(0xFFF8F8FF);
  static const textSecondary = Color(0xFF9E9EB8);
  static const textMuted = Color(0xFF5A5A72);
  static const border = Color(0xFF2A2A3C);
  static const success = Color(0xFF10B981);
  static const warning = Color(0xFFF59E0B);
  static const error = Color(0xFFEF4444);
  static const gradientStart = Color(0xFFFF2D78);
  static const gradientEnd = Color(0xFF7C3AED);
}

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: KokColors.background,
      primaryColor: KokColors.primary,
      colorScheme: const ColorScheme.dark(
        primary: KokColors.primary,
        secondary: KokColors.accent,
        surface: KokColors.surface,
        error: KokColors.error,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: KokColors.textPrimary,
        onError: Colors.white,
      ),
      textTheme: GoogleFonts.interTextTheme(
        const TextTheme(
          displayLarge: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w800,
            color: KokColors.textPrimary,
            letterSpacing: -1.0,
          ),
          headlineMedium: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: KokColors.textPrimary,
            letterSpacing: -0.5,
          ),
          titleLarge: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: KokColors.textPrimary,
          ),
          titleMedium: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: KokColors.textPrimary,
          ),
          bodyLarge: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w400,
            color: KokColors.textPrimary,
            height: 1.6,
          ),
          bodyMedium: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: KokColors.textSecondary,
            height: 1.5,
          ),
          labelLarge: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: KokColors.textPrimary,
            letterSpacing: 0.5,
          ),
          labelSmall: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: KokColors.textMuted,
            letterSpacing: 0.3,
          ),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: KokColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: KokColors.textPrimary,
        ),
        iconTheme: const IconThemeData(color: KokColors.textPrimary),
      ),
      cardTheme: CardThemeData(
        color: KokColors.cardBg,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: KokColors.border, width: 0.5),
        ),
        margin: EdgeInsets.zero,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: KokColors.surfaceLight,
        selectedColor: KokColors.primary.withAlpha(40),
        labelStyle: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: KokColors.textSecondary,
        ),
        side: const BorderSide(color: KokColors.border, width: 0.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: KokColors.surface,
        selectedItemColor: KokColors.primary,
        unselectedItemColor: KokColors.textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      dividerTheme: const DividerThemeData(
        color: KokColors.border,
        thickness: 0.5,
      ),
    );
  }
}
