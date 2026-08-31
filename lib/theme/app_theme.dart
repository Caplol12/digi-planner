import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Brand & Accent Colors
  static const Color primaryColor = Color(0xFFFF6F48); // Coral / Warm Orange
  static const Color primaryDark = Color(0xFFE55732);
  static const Color primaryLight = Color(0xFFFFECE5);
  static const Color accentGold = Color(0xFFFFB038);

  // Neutral Colors - Light Theme
  static const Color backgroundLight = Color(0xFFF7F8FA);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color textPrimaryLight = Color(0xFF1E2024);
  static const Color textSecondaryLight = Color(0xFF757A82);
  static const Color textMutedLight = Color(0xFF9E9E9E);
  static const Color dividerLight = Color(0xFFEFEFEF);
  static const Color tagBgLight = Color(0xFFEEF0F3);

  // Neutral Colors - Dark Theme
  static const Color backgroundDark = Color(0xFF121316);
  static const Color surfaceDark = Color(0xFF1C1E22);
  static const Color textPrimaryDark = Color(0xFFF5F6F8);
  static const Color textSecondaryDark = Color(0xFFA0A5AD);
  static const Color dividerDark = Color(0xFF2C2F36);
  static const Color tagBgDark = Color(0xFF252830);

  // Pastel Card Colors for Templates
  static const List<Color> pastelPalette = [
    Color(0xFFEBF3FF), // Soft Blue
    Color(0xFFFFF0ED), // Soft Peach
    Color(0xFFF0F9ED), // Soft Green
    Color(0xFFF7EFFE), // Soft Purple
    Color(0xFFFFFBEB), // Soft Yellow
    Color(0xFFE8F8F5), // Soft Teal
  ];

  static ThemeData get lightTheme {
    final baseTextTheme = Typography.material2021().black;
    final textTheme = GoogleFonts.vazirmatnTextTheme(baseTextTheme).copyWith(
      displayLarge: const TextStyle(fontWeight: FontWeight.w800, color: textPrimaryLight, letterSpacing: -0.5),
      displayMedium: const TextStyle(fontWeight: FontWeight.w700, color: textPrimaryLight),
      titleLarge: const TextStyle(fontWeight: FontWeight.w700, color: textPrimaryLight, fontSize: 20),
      titleMedium: const TextStyle(fontWeight: FontWeight.w600, color: textPrimaryLight, fontSize: 16),
      bodyLarge: const TextStyle(fontWeight: FontWeight.w400, color: textPrimaryLight, fontSize: 15),
      bodyMedium: const TextStyle(fontWeight: FontWeight.w400, color: textSecondaryLight, fontSize: 13),
      labelLarge: const TextStyle(fontWeight: FontWeight.w700, color: surfaceLight, fontSize: 14),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: backgroundLight,
      colorScheme: const ColorScheme.light(
        primary: primaryColor,
        secondary: primaryDark,
        surface: surfaceLight,
        onPrimary: Colors.white,
        onSurface: textPrimaryLight,
        onSurfaceVariant: textSecondaryLight,
      ),
      textTheme: textTheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: backgroundLight,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: textPrimaryLight),
        titleTextStyle: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: textPrimaryLight,
        ),
      ),
      cardTheme: CardThemeData(
        color: surfaceLight,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: dividerLight, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF0F2F5),
        hintStyle: const TextStyle(color: textSecondaryLight, fontSize: 14),
        prefixIconColor: textSecondaryLight,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: primaryColor, width: 1.5),
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    final baseTextTheme = Typography.material2021().white;
    final textTheme = GoogleFonts.vazirmatnTextTheme(baseTextTheme).copyWith(
      displayLarge: const TextStyle(fontWeight: FontWeight.w800, color: textPrimaryDark),
      titleLarge: const TextStyle(fontWeight: FontWeight.w700, color: textPrimaryDark, fontSize: 20),
      titleMedium: const TextStyle(fontWeight: FontWeight.w600, color: textPrimaryDark, fontSize: 16),
      bodyLarge: const TextStyle(fontWeight: FontWeight.w400, color: textPrimaryDark, fontSize: 15),
      bodyMedium: const TextStyle(fontWeight: FontWeight.w400, color: textSecondaryDark, fontSize: 13),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: backgroundDark,
      colorScheme: const ColorScheme.dark(
        primary: primaryColor,
        secondary: primaryLight,
        surface: surfaceDark,
        onPrimary: Colors.white,
        onSurface: textPrimaryDark,
        onSurfaceVariant: textSecondaryDark,
      ),
      textTheme: textTheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: backgroundDark,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: textPrimaryDark),
      ),
      cardTheme: CardThemeData(
        color: surfaceDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: dividerDark, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: tagBgDark,
        hintStyle: const TextStyle(color: textSecondaryDark, fontSize: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
