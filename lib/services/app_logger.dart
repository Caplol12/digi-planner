import 'package:flutter/foundation.dart';

/// Centralized logger for PlanWiz application
class AppLog {
  AppLog._();

  static void d(String tag, String message) {
    if (kDebugMode) {
      debugPrint('[$tag] ℹ️ $message');
    }
  }

  static void w(String tag, String message) {
    debugPrint('[$tag] ⚠️ $message');
  }

  static void e(String tag, dynamic error, [StackTrace? stackTrace]) {
    debugPrint('[$tag] ❌ ERROR: $error');
    if (stackTrace != null && kDebugMode) {
      debugPrint('[$tag] StackTrace:\n$stackTrace');
    }
  }
}
