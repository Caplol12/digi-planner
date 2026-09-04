import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'app_logger.dart';
import 'supabase_service.dart';

/// Exception thrown when user reaches the free default AI usage limit (15 times)
class AiUsageLimitExceededException implements Exception {
  final String message;
  final int maxFreeLimit;
  final int currentUsage;

  const AiUsageLimitExceededException({
    this.message = 'سقف ۱۵ بار استفاده رایگان از هوش مصنوعی پیش‌فرض به پایان رسیده است.',
    this.maxFreeLimit = 15,
    this.currentUsage = 15,
  });

  @override
  String toString() => message;
}

/// Service managing default AI usage counts (15 free tries) and Premium status
class AiSubscriptionService extends ChangeNotifier {
  static final AiSubscriptionService _instance = AiSubscriptionService._internal();
  static AiSubscriptionService get instance => _instance;

  AiSubscriptionService._internal();

  static const String _keyUsageCount = 'ai_default_usage_count';
  static const String _keyIsPremium = 'is_premium_active';
  static const String _keyActivationCode = 'premium_activation_code';
  static const String _keyDeviceId = 'app_unique_device_id';

  /// Salt for local hash validation to prevent client code scraping
  static const String _hashSalt = 'PW_2026_SECURE_SALT_98x#@';

  static final Set<String> _knownCodeHashes = {
    _computeCodeHash('METARWA-VIP'),
    _computeCodeHash('PRO-2026-VIP'),
  };

  /// Maximum allowed free uses of the default AI
  static const int maxFreeUsage = 15;

  int _usageCount = 0;
  bool _isPremium = false;
  String? _activationCode;
  String? _deviceId;
  bool _isInitialized = false;

  void resetForTesting() {
    _usageCount = 0;
    _isPremium = false;
    _activationCode = null;
    _isInitialized = false;
  }

  /// Current usage count of the default AI
  int get usageCount => _usageCount;

  /// Whether the user has unlocked Premium (unlimited AI usage)
  bool get isPremium => _isPremium;

  /// Activation code used to unlock premium, if any
  String? get activationCode => _activationCode;

  /// Device ID locked to this install
  String get deviceId => _deviceId ?? '';

  /// Remaining free uses (0 to 15, or unlimited if premium)
  int get remainingFreeUsage {
    if (_isPremium) return 999999;
    final remaining = maxFreeUsage - _usageCount;
    return remaining > 0 ? remaining : 0;
  }

  /// Whether user can currently use the default AI
  bool get canUseDefaultAi => _isPremium || remainingFreeUsage > 0;

  static String _computeCodeHash(String rawCode) {
    final clean = rawCode.trim().toUpperCase();
    final bytes = utf8.encode('$clean:$_hashSalt');
    return sha256.convert(bytes).toString();
  }

  /// Initialize and load saved state from SharedPreferences
  Future<void> init() async {
    if (_isInitialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _deviceId = prefs.getString(_keyDeviceId);
      if (_deviceId == null || _deviceId!.isEmpty) {
        _deviceId = const Uuid().v4();
        await prefs.setString(_keyDeviceId, _deviceId!);
      }

      _usageCount = prefs.getInt(_keyUsageCount) ?? 0;
      _isPremium = prefs.getBool(_keyIsPremium) ?? false;
      _activationCode = prefs.getString(_keyActivationCode);
      _isInitialized = true;

      // Sync with Supabase in background if client is available
      _syncUsageWithBackend();

      AppLog.d('Subscription', 'Initialized: usage=$_usageCount/$maxFreeUsage, isPremium=$_isPremium, deviceId=$_deviceId');
    } catch (e, st) {
      AppLog.e('Subscription', 'Error initializing AiSubscriptionService', st);
      _isInitialized = true;
    }
    notifyListeners();
  }

  /// Ensure service is loaded before reading/writing
  Future<void> ensureInitialized() async {
    if (!_isInitialized) {
      await init();
    }
  }

  Future<void> _syncUsageWithBackend() async {
    final client = SupabaseService.client;
    if (client == null || _deviceId == null) return;
    try {
      final response = await client
          .from('ai_usage')
          .select('count, is_premium')
          .eq('device_id', _deviceId!)
          .maybeSingle();

      if (response != null) {
        final serverCount = response['count'] as int? ?? _usageCount;
        final serverPremium = response['is_premium'] as bool? ?? _isPremium;
        if (serverCount > _usageCount) {
          _usageCount = serverCount;
          final prefs = await SharedPreferences.getInstance();
          await prefs.setInt(_keyUsageCount, _usageCount);
        }
        if (serverPremium && !_isPremium) {
          _isPremium = true;
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool(_keyIsPremium, true);
        }
        notifyListeners();
      }
    } catch (_) {
      // Offline fallback
    }
  }

  /// Attempt to consume 1 usage credit for the default AI.
  Future<bool> consumeUsage() async {
    await ensureInitialized();

    if (_isPremium) {
      return true;
    }

    if (_usageCount >= maxFreeUsage) {
      return false;
    }

    _usageCount += 1;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_keyUsageCount, _usageCount);

      // Report count to backend if online
      final client = SupabaseService.client;
      if (client != null && _deviceId != null) {
        client.from('ai_usage').upsert({
          'device_id': _deviceId!,
          'count': _usageCount,
          'updated_at': DateTime.now().toIso8601String(),
        }).catchError((_) {});
      }
    } catch (e, st) {
      AppLog.e('Subscription', 'Error persisting AI usage count', st);
    }

    notifyListeners();
    AppLog.d('Subscription', 'Consumed 1 AI credit: $_usageCount/$maxFreeUsage used ($remainingFreeUsage remaining)');
    return true;
  }

  /// Activates premium using an activation code verified by Supabase or secure salted hash.
  Future<bool> activateWithCode(String code) async {
    await ensureInitialized();
    final cleanCode = code.trim().toUpperCase();
    if (cleanCode.isEmpty) return false;

    final codeHash = _computeCodeHash(cleanCode);

    // 1. First attempt: Verify online with Supabase activation_codes table
    final client = SupabaseService.client;
    if (client != null) {
      try {
        final res = await client
            .from('activation_codes')
            .select('*')
            .or('code_hash.eq.$codeHash,code.eq.$cleanCode')
            .maybeSingle();

        if (res != null) {
          final redeemedBy = res['redeemed_by'] as String?;
          final isRedeemed = res['is_redeemed'] as bool? ?? (redeemedBy != null);

          // Allow if unredeemed, or already redeemed by this exact device
          if (!isRedeemed || redeemedBy == _deviceId) {
            await client.from('activation_codes').update({
              'is_redeemed': true,
              'redeemed_by': _deviceId,
              'redeemed_at': DateTime.now().toIso8601String(),
            }).eq('id', res['id']);

            return await _grantPremium(cleanCode);
          } else {
            AppLog.w('Subscription', 'Code already redeemed by another device');
            return false;
          }
        }
      } catch (e) {
        AppLog.w('Subscription', 'Supabase code check failed: $e, falling back to secure hash');
      }
    }

    // 2. Offline / local fallback: Check known secure salted hashes
    if (_knownCodeHashes.contains(codeHash)) {
      return _grantPremium(cleanCode);
    }

    return false;
  }

  Future<bool> _grantPremium(String code) async {
    _isPremium = true;
    _activationCode = code;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyIsPremium, true);
      await prefs.setString(_keyActivationCode, code);

      final client = SupabaseService.client;
      if (client != null && _deviceId != null) {
        client.from('ai_usage').upsert({
          'device_id': _deviceId!,
          'is_premium': true,
          'count': _usageCount,
          'updated_at': DateTime.now().toIso8601String(),
        }).catchError((_) {});
      }
    } catch (e, st) {
      AppLog.e('Subscription', 'Error saving premium activation', st);
    }
    notifyListeners();
    return true;
  }

  /// Direct admin/system activation
  Future<void> setPremium(bool active) async {
    await ensureInitialized();
    _isPremium = active;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyIsPremium, active);
      if (!active) {
        await prefs.remove(_keyActivationCode);
        _activationCode = null;
      }
    } catch (e, st) {
      AppLog.e('Subscription', 'Error saving premium state', st);
    }
    notifyListeners();
  }

  /// Reset usage count (useful for testing or debugging)
  Future<void> resetUsage({int setTo = 0}) async {
    await ensureInitialized();
    _usageCount = setTo;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_keyUsageCount, setTo);
    } catch (e, st) {
      AppLog.e('Subscription', 'Error resetting AI usage count', st);
    }
    notifyListeners();
  }
}
