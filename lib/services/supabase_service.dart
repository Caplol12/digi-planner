import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AiConfig {
  final String baseUrl;
  final String apiKey;
  final String model;

  const AiConfig({
    required this.baseUrl,
    required this.apiKey,
    required this.model,
  });

  static const AiConfig defaults = AiConfig(
    baseUrl: 'https://generativelanguage.googleapis.com/v1beta/openai',
    apiKey: 'AQ.Ab8RN6LmIeeGMLmBusGOMOBYZpjfmGyq1zNGgW1ReaeKR99Iqg',
    model: 'gemini-3.1-flash-lite-preview',
  );

  factory AiConfig.fromJson(Map<String, dynamic> json) {
    final rawBaseUrl = (json['base_url'] as String?)?.trim();
    final rawApiKey = (json['api_key'] as String?)?.trim();
    final rawModel = (json['model'] as String?)?.trim();

    return AiConfig(
      baseUrl: (rawBaseUrl != null && rawBaseUrl.isNotEmpty) ? rawBaseUrl : defaults.baseUrl,
      apiKey: (rawApiKey != null && rawApiKey.isNotEmpty) ? rawApiKey : defaults.apiKey,
      model: (rawModel != null && rawModel.isNotEmpty) ? rawModel : defaults.model,
    );
  }

  Map<String, dynamic> toJson() => {
        'base_url': baseUrl,
        'api_key': apiKey,
        'model': model,
      };

  AiConfig copyWith({
    String? baseUrl,
    String? apiKey,
    String? model,
  }) {
    return AiConfig(
      baseUrl: baseUrl ?? this.baseUrl,
      apiKey: apiKey ?? this.apiKey,
      model: model ?? this.model,
    );
  }
}

class SupabaseService {
  static const String supabaseUrl = 'https://bpkirnkocjlcqotyplgk.supabase.co';
  static const String supabaseAnonKey = 'sb_publishable_nmc4bWjfOu1haqLivpbjlg_NNMicp8P';

  static bool _isInitialized = false;
  static bool get isInitialized => _isInitialized;

  static SupabaseClient? get client {
    if (!_isInitialized) return null;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  /// Initialize Supabase Flutter SDK
  static Future<void> initialize() async {
    if (_isInitialized) return;
    try {
      await Supabase.initialize(
        url: supabaseUrl,
        publishableKey: supabaseAnonKey,
      );
      _isInitialized = true;
      debugPrint('✅ Supabase initialized successfully.');
      // Pre-fetch AI configuration from Supabase in background
      AiConfigService.fetchConfigFromSupabase();
    } catch (e) {
      debugPrint('⚠️ Supabase init warning: $e');
    }
  }
}

class AiConfigService {
  static AiConfig _cachedConfig = AiConfig.defaults;
  static DateTime? _lastFetchTime;

  static AiConfig get currentConfig => _cachedConfig;

  /// Get AI configuration (cached or fresh from Supabase)
  static Future<AiConfig> getConfig({bool forceRefresh = false}) async {
    if (!forceRefresh && _lastFetchTime != null) {
      final difference = DateTime.now().difference(_lastFetchTime!);
      if (difference.inMinutes < 5) {
        return _cachedConfig;
      }
    }

    final fresh = await fetchConfigFromSupabase();
    return fresh;
  }

  /// Fetch AI config from Supabase database table `ai_configs` or `app_settings`
  static Future<AiConfig> fetchConfigFromSupabase() async {
    final client = SupabaseService.client;
    if (client == null) {
      return _cachedConfig;
    }

    try {
      // 1. Try reading from ai_configs table
      final response = await client
          .from('ai_configs')
          .select('*')
          .limit(1)
          .maybeSingle();

      if (response != null) {
        _cachedConfig = AiConfig.fromJson(response);
        _lastFetchTime = DateTime.now();
        debugPrint('✅ Loaded AI config from Supabase: model=${_cachedConfig.model}, url=${_cachedConfig.baseUrl}');
        return _cachedConfig;
      }
    } catch (e) {
      debugPrint('ℹ️ Supabase ai_configs check: $e (using defaults)');
    }

    try {
      // 2. Try reading from app_settings table as fallback
      final response = await client
          .from('app_settings')
          .select('*')
          .eq('key', 'ai_config')
          .maybeSingle();

      if (response != null && response['value'] != null) {
        final val = response['value'] as Map<String, dynamic>;
        _cachedConfig = AiConfig.fromJson(val);
        _lastFetchTime = DateTime.now();
        return _cachedConfig;
      }
    } catch (_) {}

    _lastFetchTime = DateTime.now();
    return _cachedConfig;
  }

  /// Save or update AI config in Supabase
  static Future<bool> saveConfigToSupabase(AiConfig config) async {
    _cachedConfig = config;
    final client = SupabaseService.client;
    if (client == null) return false;

    try {
      await client.from('ai_configs').upsert({
        'id': 'default',
        'base_url': config.baseUrl,
        'api_key': config.apiKey,
        'model': config.model,
        'updated_at': DateTime.now().toIso8601String(),
      });
      return true;
    } catch (e) {
      debugPrint('⚠️ Could not save config to Supabase: $e');
      return false;
    }
  }
}
