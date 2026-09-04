import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class FontOption {
  final String name;
  final String label;
  final String category;

  const FontOption({
    required this.name,
    required this.label,
    this.category = 'فارسی',
  });
}

/// Helper class providing crash-safe Google Font resolution and curated typography choices.
class AppFonts {
  static const String defaultFontName = 'Vazirmatn';

  /// Curated list of verified fonts available in google_fonts package
  static const List<FontOption> availableFonts = [
    FontOption(
      name: 'Vazirmatn',
      label: 'وزیرمتن (استاندارد و خوانا)',
      category: 'فارسی',
    ),
    FontOption(
      name: 'Amiri',
      label: 'امیری (کلاسیک و زیبا - جایگزین ساحل)',
      category: 'فارسی',
    ),
    FontOption(
      name: 'Lalezar',
      label: 'لاله‌زار (فانتزی و نمایشی)',
      category: 'فارسی',
    ),
    FontOption(
      name: 'Markazi Text',
      label: 'مرکزی (کتابی و اداری)',
      category: 'فارسی',
    ),
    FontOption(
      name: 'Rubik',
      label: 'روبیک (مدرن و تمیز)',
      category: 'فارسی',
    ),
    FontOption(
      name: 'Katibeh',
      label: 'کتیبه (هنری و خوشنویسی)',
      category: 'فارسی',
    ),
    FontOption(
      name: 'Playfair Display',
      label: 'Playfair Display (سریف شیک انگلیسی)',
      category: 'لاتین',
    ),
    FontOption(
      name: 'Lora',
      label: 'Lora (رسمی و اداری)',
      category: 'لاتین',
    ),
    FontOption(
      name: 'Caveat',
      label: 'Caveat (دست‌نویس روان)',
      category: 'لاتین',
    ),
    FontOption(
      name: 'Nunito',
      label: 'Nunito (گرد و صمیمی)',
      category: 'لاتین',
    ),
    FontOption(
      name: 'Roboto',
      label: 'Roboto (ساده و استاندارد)',
      category: 'لاتین',
    ),
  ];

  /// Maps non-Google Fonts or legacy names (e.g. Sahel, Shabnam) to safe equivalents.
  static String normalizeFontName(String? rawName) {
    if (rawName == null || rawName.trim().isEmpty) {
      return defaultFontName;
    }
    final trimmed = rawName.trim();
    switch (trimmed.toLowerCase()) {
      case 'sahel':
        return 'Amiri';
      case 'shabnam':
        return 'Vazirmatn';
      case 'courier':
        return 'Courier Prime';
      default:
        return trimmed;
    }
  }

  /// Safely resolves and returns a [TextStyle] for the given [fontName].
  /// Guaranteed to never throw an exception: falls back to Vazirmatn if unavailable.
  static TextStyle getSafeFont(
    String? fontName, {
    TextStyle? textStyle,
    Color? color,
    Color? backgroundColor,
    double? fontSize,
    FontWeight? fontWeight,
    FontStyle? fontStyle,
    double? letterSpacing,
    double? wordSpacing,
    TextBaseline? textBaseline,
    double? height,
    Locale? locale,
    Paint? foreground,
    Paint? background,
    List<Shadow>? shadows,
    TextDecoration? decoration,
    Color? decorationColor,
    TextDecorationStyle? decorationStyle,
    double? decorationThickness,
  }) {
    final effectiveName = normalizeFontName(fontName);

    try {
      if (GoogleFonts.asMap().containsKey(effectiveName)) {
        return GoogleFonts.getFont(
          effectiveName,
          textStyle: textStyle,
          color: color,
          backgroundColor: backgroundColor,
          fontSize: fontSize,
          fontWeight: fontWeight,
          fontStyle: fontStyle,
          letterSpacing: letterSpacing,
          wordSpacing: wordSpacing,
          textBaseline: textBaseline,
          height: height,
          locale: locale,
          foreground: foreground,
          background: background,
          shadows: shadows,
          decoration: decoration,
          decorationColor: decorationColor,
          decorationStyle: decorationStyle,
          decorationThickness: decorationThickness,
        );
      }
    } catch (_) {
      // Graceful fallback to Vazirmatn below
    }

    return GoogleFonts.vazirmatn(
      textStyle: textStyle,
      color: color,
      backgroundColor: backgroundColor,
      fontSize: fontSize,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      letterSpacing: letterSpacing,
      wordSpacing: wordSpacing,
      textBaseline: textBaseline,
      height: height,
      locale: locale,
      foreground: foreground,
      background: background,
      shadows: shadows,
      decoration: decoration,
      decorationColor: decorationColor,
      decorationStyle: decorationStyle,
      decorationThickness: decorationThickness,
    );
  }
}
