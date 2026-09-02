import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

enum AiProviderType {
  developer,
  googleAiStudio,
}

class GeminiModelOption {
  final String id;
  final String displayName;
  final String description;
  final bool isRecommended;

  const GeminiModelOption({
    required this.id,
    required this.displayName,
    required this.description,
    this.isRecommended = false,
  });
}

class GeminiConnectionTestResult {
  final bool isSuccess;
  final String message;
  final int? statusCode;

  const GeminiConnectionTestResult({
    required this.isSuccess,
    required this.message,
    this.statusCode,
  });
}

class UserAiPreferencesService {
  static const String _keyProviderType = 'user_ai_provider_type';
  static const String _keyGeminiApiKey = 'user_gemini_api_key';
  static const String _keyGeminiModel = 'user_gemini_model';
  static const String _keyCustomModelName = 'user_gemini_custom_model_name';

  static const String defaultGeminiModel = 'gemini-2.5-flash';

  static const List<GeminiModelOption> availableModels = [
    GeminiModelOption(
      id: 'gemini-2.5-flash',
      displayName: 'Gemini 2.5 Flash',
      description: 'جدیدترین، پرسرعت‌ترین و هوشمندترین مدل بینایی (پیشنهادی)',
      isRecommended: true,
    ),
    GeminiModelOption(
      id: 'gemini-2.0-flash',
      displayName: 'Gemini 2.0 Flash',
      description: 'مدل پرسرعت و بهینه نسل ۲ با درک دیداری عالی',
    ),
    GeminiModelOption(
      id: 'gemini-2.5-pro',
      displayName: 'Gemini 2.5 Pro',
      description: 'قوی‌ترین استدلال و بیشترین دقت برای برگه‌های بسیار شلوغ',
    ),
    GeminiModelOption(
      id: 'gemini-1.5-flash',
      displayName: 'Gemini 1.5 Flash',
      description: 'مدل سبک، سریع و پایدار نسل پیشین',
    ),
    GeminiModelOption(
      id: 'gemini-1.5-pro',
      displayName: 'Gemini 1.5 Pro',
      description: 'مدل حرفه‌ای نسل اول با عمق تحلیل بالا',
    ),
  ];

  static AiProviderType _currentProvider = AiProviderType.developer;
  static String _geminiApiKey = '';
  static String _geminiModel = defaultGeminiModel;
  static String _customModelName = '';
  static bool _isLoaded = false;

  /// Get current active provider
  static AiProviderType get activeProvider => _currentProvider;

  /// Get stored personal Gemini API key
  static String get geminiApiKey => _geminiApiKey;

  /// Get active Gemini model ID
  static String get geminiModel {
    if (_geminiModel == 'custom' && _customModelName.trim().isNotEmpty) {
      return _customModelName.trim();
    }
    return _geminiModel.isNotEmpty ? _geminiModel : defaultGeminiModel;
  }

  /// Get raw selected model ID (might be 'custom')
  static String get rawModelSelection => _geminiModel;

  /// Custom model name if entered
  static String get customModelName => _customModelName;

  /// Whether user has configured a non-empty Gemini API key
  static bool get hasGeminiApiKey => _geminiApiKey.trim().isNotEmpty;

  /// Load settings from SharedPreferences
  static Future<void> loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final providerStr = prefs.getString(_keyProviderType);
      if (providerStr == 'google_ai_studio') {
        _currentProvider = AiProviderType.googleAiStudio;
      } else {
        _currentProvider = AiProviderType.developer;
      }

      _geminiApiKey = prefs.getString(_keyGeminiApiKey) ?? '';
      _geminiModel = prefs.getString(_keyGeminiModel) ?? defaultGeminiModel;
      _customModelName = prefs.getString(_keyCustomModelName) ?? '';
      _isLoaded = true;
      debugPrint('🔑 Loaded AI Preferences: provider=$_currentProvider, model=$geminiModel, hasKey=$hasGeminiApiKey');
    } catch (e) {
      debugPrint('⚠️ Error loading AI Preferences: $e');
      _isLoaded = true;
    }
  }

  /// Ensure preferences are loaded
  static Future<void> ensureLoaded() async {
    if (!_isLoaded) {
      await loadPreferences();
    }
  }

  /// Save preferences
  static Future<void> savePreferences({
    required AiProviderType providerType,
    required String geminiApiKey,
    required String geminiModel,
    String? customModelName,
  }) async {
    _currentProvider = providerType;
    _geminiApiKey = geminiApiKey.trim();
    _geminiModel = geminiModel;
    if (customModelName != null) {
      _customModelName = customModelName.trim();
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyProviderType, providerType == AiProviderType.googleAiStudio ? 'google_ai_studio' : 'developer');
      await prefs.setString(_keyGeminiApiKey, _geminiApiKey);
      await prefs.setString(_keyGeminiModel, _geminiModel);
      await prefs.setString(_keyCustomModelName, _customModelName);
      debugPrint('✅ Saved AI Preferences successfully.');
    } catch (e) {
      debugPrint('⚠️ Error saving AI Preferences: $e');
    }
  }

  /// Test connection to Google AI Studio with given API Key and Model
  static Future<GeminiConnectionTestResult> testGeminiConnection({
    required String apiKey,
    required String model,
  }) async {
    final cleanKey = apiKey.trim();
    if (cleanKey.isEmpty) {
      return const GeminiConnectionTestResult(
        isSuccess: false,
        message: 'لطفاً ابتدا کلید API را وارد کنید.',
      );
    }

    final cleanModel = model.trim();
    final testUrl = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$cleanModel:generateContent?key=$cleanKey',
    );

    try {
      final response = await http.post(
        testUrl,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': 'Hello'}
              ]
            }
          ],
          'generationConfig': {
            'maxOutputTokens': 5,
            'temperature': 0.1,
          },
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return GeminiConnectionTestResult(
          isSuccess: true,
          statusCode: 200,
          message: 'اتصال به Google AI Studio با موفقیت برقرار شد! مدل «$cleanModel» آماده تحلیل است.',
        );
      } else {
        String errorDetail = '';
        try {
          final decoded = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
          if (decoded['error'] != null) {
            final err = decoded['error'];
            final msg = err['message']?.toString() ?? '';
            final status = err['status']?.toString() ?? '';
            if (status == 'API_KEY_INVALID' || msg.toLowerCase().contains('api key not valid')) {
              errorDetail = 'کلید API وارد شده نامعتبر است. لطفاً کلید دریافتی از aistudio.google.com را دوباره بررسی کنید.';
            } else if (msg.toLowerCase().contains('not found') || status == 'NOT_FOUND') {
              errorDetail = 'مدل «$cleanModel» برای این حساب فعال نیست یا نام مدل اشتباه است.';
            } else if (response.statusCode == 429 || msg.toLowerCase().contains('quota')) {
              errorDetail = 'سهمیه مجاز (Quota) شما در گوگل به اتمام رسیده است یا محدودیت درخواست رخ داده است.';
            } else {
              errorDetail = msg.isNotEmpty ? msg : 'خطای سرور گوگل (${response.statusCode})';
            }
          }
        } catch (_) {
          errorDetail = 'خطای وضعیت سرور: ${response.statusCode}';
        }

        return GeminiConnectionTestResult(
          isSuccess: false,
          statusCode: response.statusCode,
          message: errorDetail.isNotEmpty ? errorDetail : 'پاسخ ناموفق از گوگل (${response.statusCode})',
        );
      }
    } catch (e) {
      String msg = 'خطا در برقراری اتصال به گوگل: $e';
      if (e.toString().contains('TimeoutException')) {
        msg = 'زمان درخواست به پایان رسید (Timeout). لطفاً اتصال اینترنت خود را بررسی نمایید.';
      } else if (e.toString().contains('SocketException') || e.toString().contains('HandshakeException')) {
        msg = 'عدم دسترسی به سرورهای گوگل. لطفاً اتصال اینترنت یا پروکسی/فیلترشکن را بررسی کنید.';
      }
      return GeminiConnectionTestResult(
        isSuccess: false,
        message: msg,
      );
    }
  }
}
