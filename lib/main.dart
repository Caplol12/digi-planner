import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme/app_theme.dart';
import 'screens/main_navigation_screen.dart';
import 'services/app_logger.dart';
import 'services/supabase_service.dart';

final ValueNotifier<ThemeMode> appThemeModeNotifier = ValueNotifier<ThemeMode>(ThemeMode.light);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load saved theme preference
  try {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool('is_dark_mode') ?? false;
    appThemeModeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;
  } catch (e, st) {
    AppLog.e('Main', 'Failed to load saved theme', st);
  }

  // Set initial system UI style
  final isDark = appThemeModeNotifier.value == ThemeMode.dark;
  SystemChrome.setSystemUIOverlayStyle(
    SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
    ),
  );

  // Initialize Supabase backend & AI config sync
  await SupabaseService.initialize();

  runApp(const JournalApp());
}

class JournalApp extends StatelessWidget {
  const JournalApp({super.key});

  static Future<void> toggleTheme() async {
    final nextMode = appThemeModeNotifier.value == ThemeMode.light
        ? ThemeMode.dark
        : ThemeMode.light;
    appThemeModeNotifier.value = nextMode;

    final isDark = nextMode == ThemeMode.dark;
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      ),
    );

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_dark_mode', isDark);
    } catch (e, st) {
      AppLog.e('Theme', 'Failed to persist theme mode', st);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: appThemeModeNotifier,
      builder: (context, currentMode, _) {
        return MaterialApp(
          title: 'ژورنال',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: currentMode,
          locale: const Locale('fa'),
          supportedLocales: const [
            Locale('fa'),
            Locale('en'),
          ],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: MainNavigationScreen(
            onToggleTheme: toggleTheme,
            isDarkMode: currentMode == ThemeMode.dark,
          ),
        );
      },
    );
  }
}
