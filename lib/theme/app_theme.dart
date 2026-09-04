import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

@immutable
class AppColors extends ThemeExtension<AppColors> {
  final Color surface;
  final Color surfaceContainer;
  final Color background;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color divider;
  final Color tagBg;
  final Color cardBorder;
  final Color cardBackground;
  final Color primary;
  final Color primaryLight;
  final Color primaryDark;
  final Color accentGold;

  const AppColors({
    required this.surface,
    required this.surfaceContainer,
    required this.background,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.divider,
    required this.tagBg,
    required this.cardBorder,
    required this.cardBackground,
    required this.primary,
    required this.primaryLight,
    required this.primaryDark,
    required this.accentGold,
  });

  static const light = AppColors(
    surface: Color(0xFFFFFFFF),
    surfaceContainer: Color(0xFFF0F2F5),
    background: Color(0xFFF7F8FA),
    textPrimary: Color(0xFF1E2024),
    textSecondary: Color(0xFF757A82),
    textMuted: Color(0xFF9E9E9E),
    divider: Color(0xFFEFEFEF),
    tagBg: Color(0xFFEEF0F3),
    cardBorder: Color(0xFFE5E7EB),
    cardBackground: Color(0xFFFFFFFF),
    primary: Color(0xFFFF6F48),
    primaryLight: Color(0xFFFFECE5),
    primaryDark: Color(0xFFE55732),
    accentGold: Color(0xFFFFB038),
  );

  static const dark = AppColors(
    surface: Color(0xFF1C1E22),
    surfaceContainer: Color(0xFF252830),
    background: Color(0xFF121316),
    textPrimary: Color(0xFFF5F6F8),
    textSecondary: Color(0xFFA0A5AD),
    textMuted: Color(0xFF70757E),
    divider: Color(0xFF2C2F36),
    tagBg: Color(0xFF252830),
    cardBorder: Color(0xFF2C2F36),
    cardBackground: Color(0xFF1C1E22),
    primary: Color(0xFFFF6F48),
    primaryLight: Color(0xFF3E2822),
    primaryDark: Color(0xFFE55732),
    accentGold: Color(0xFFFFB038),
  );

  @override
  AppColors copyWith({
    Color? surface,
    Color? surfaceContainer,
    Color? background,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? divider,
    Color? tagBg,
    Color? cardBorder,
    Color? cardBackground,
    Color? primary,
    Color? primaryLight,
    Color? primaryDark,
    Color? accentGold,
  }) {
    return AppColors(
      surface: surface ?? this.surface,
      surfaceContainer: surfaceContainer ?? this.surfaceContainer,
      background: background ?? this.background,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      divider: divider ?? this.divider,
      tagBg: tagBg ?? this.tagBg,
      cardBorder: cardBorder ?? this.cardBorder,
      cardBackground: cardBackground ?? this.cardBackground,
      primary: primary ?? this.primary,
      primaryLight: primaryLight ?? this.primaryLight,
      primaryDark: primaryDark ?? this.primaryDark,
      accentGold: accentGold ?? this.accentGold,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceContainer: Color.lerp(surfaceContainer, other.surfaceContainer, t)!,
      background: Color.lerp(background, other.background, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      tagBg: Color.lerp(tagBg, other.tagBg, t)!,
      cardBorder: Color.lerp(cardBorder, other.cardBorder, t)!,
      cardBackground: Color.lerp(cardBackground, other.cardBackground, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      primaryLight: Color.lerp(primaryLight, other.primaryLight, t)!,
      primaryDark: Color.lerp(primaryDark, other.primaryDark, t)!,
      accentGold: Color.lerp(accentGold, other.accentGold, t)!,
    );
  }
}

extension AppColorsContext on BuildContext {
  AppColors get c =>
      Theme.of(this).extension<AppColors>() ??
      (Theme.of(this).brightness == Brightness.dark ? AppColors.dark : AppColors.light);
}

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
      extensions: const [AppColors.light],
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
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
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
      extensions: const [AppColors.dark],
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
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
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
