import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:journal_app/services/ai_subscription_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AiSubscriptionService.instance.init();
    await AiSubscriptionService.instance.resetUsage(setTo: 0);
    await AiSubscriptionService.instance.setPremium(false);
  });

  test('AiSubscriptionService starts with 0 uses and 15 remaining credits', () async {
    expect(AiSubscriptionService.instance.usageCount, 0);
    expect(AiSubscriptionService.instance.remainingFreeUsage, 15);
    expect(AiSubscriptionService.instance.isPremium, isFalse);
    expect(AiSubscriptionService.instance.canUseDefaultAi, isTrue);
  });

  test('consumeUsage consumes credits until maximum free usage of 15', () async {
    for (int i = 1; i <= 15; i++) {
      final consumed = await AiSubscriptionService.instance.consumeUsage();
      expect(consumed, isTrue);
      expect(AiSubscriptionService.instance.usageCount, i);
      expect(AiSubscriptionService.instance.remainingFreeUsage, 15 - i);
    }

    expect(AiSubscriptionService.instance.remainingFreeUsage, 0);
    expect(AiSubscriptionService.instance.canUseDefaultAi, isFalse);

    // Attempt 16th consumption
    final sixteenth = await AiSubscriptionService.instance.consumeUsage();
    expect(sixteenth, isFalse);
    expect(AiSubscriptionService.instance.usageCount, 15);
    expect(AiSubscriptionService.instance.canUseDefaultAi, isFalse);
  });

  test('AiSubscriptionService activates premium with valid promo/license codes', () async {
    expect(AiSubscriptionService.instance.isPremium, isFalse);

    // Test invalid code
    final failResult = await AiSubscriptionService.instance.activateWithCode('INVALID_CODE');
    expect(failResult, isFalse);
    expect(AiSubscriptionService.instance.isPremium, isFalse);

    // Test valid Telegram Metarwa VIP code
    final successResult = await AiSubscriptionService.instance.activateWithCode('METARWA-VIP');
    expect(successResult, isTrue);
    expect(AiSubscriptionService.instance.isPremium, isTrue);
    expect(AiSubscriptionService.instance.canUseDefaultAi, isTrue);

    // When premium, consuming credits always succeeds without decrementing below 0
    final consumed = await AiSubscriptionService.instance.consumeUsage();
    expect(consumed, isTrue);
  });

  test('AiSubscriptionService persists and restores state from SharedPreferences', () async {
    await AiSubscriptionService.instance.consumeUsage();
    await AiSubscriptionService.instance.consumeUsage();
    await AiSubscriptionService.instance.consumeUsage();
    expect(AiSubscriptionService.instance.usageCount, 3);

    // Verify stored in SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('ai_default_usage_count'), 3);

    // Simulate app restart by re-initializing service
    final reloadedService = AiSubscriptionService.instance;
    await reloadedService.init();
    expect(reloadedService.usageCount, 3);
    expect(reloadedService.remainingFreeUsage, 12);
  });
}
