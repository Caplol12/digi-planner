import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:journal_app/services/user_ai_preferences_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('UserAiPreferencesService defaults to developer provider', () async {
    await UserAiPreferencesService.loadPreferences();

    expect(UserAiPreferencesService.activeProvider, AiProviderType.developer);
    expect(UserAiPreferencesService.geminiApiKey, isEmpty);
    expect(UserAiPreferencesService.geminiModel, UserAiPreferencesService.defaultGeminiModel);
    expect(UserAiPreferencesService.hasGeminiApiKey, isFalse);
  });

  test('UserAiPreferencesService saves and loads Google AI Studio preferences', () async {
    await UserAiPreferencesService.savePreferences(
      providerType: AiProviderType.googleAiStudio,
      geminiApiKey: 'AIzaSyFakeKeyTest12345',
      geminiModel: 'gemini-2.0-flash',
    );

    expect(UserAiPreferencesService.activeProvider, AiProviderType.googleAiStudio);
    expect(UserAiPreferencesService.geminiApiKey, 'AIzaSyFakeKeyTest12345');
    expect(UserAiPreferencesService.geminiModel, 'gemini-2.0-flash');
    expect(UserAiPreferencesService.hasGeminiApiKey, isTrue);

    // Verify loading again from SharedPreferences
    await UserAiPreferencesService.loadPreferences();
    expect(UserAiPreferencesService.activeProvider, AiProviderType.googleAiStudio);
    expect(UserAiPreferencesService.geminiApiKey, 'AIzaSyFakeKeyTest12345');
    expect(UserAiPreferencesService.geminiModel, 'gemini-2.0-flash');
  });

  test('UserAiPreferencesService supports custom model name', () async {
    await UserAiPreferencesService.savePreferences(
      providerType: AiProviderType.googleAiStudio,
      geminiApiKey: 'AIzaSyFakeKeyTest12345',
      geminiModel: 'custom',
      customModelName: 'gemini-2.0-flash-lite',
    );

    expect(UserAiPreferencesService.rawModelSelection, 'custom');
    expect(UserAiPreferencesService.customModelName, 'gemini-2.0-flash-lite');
    expect(UserAiPreferencesService.geminiModel, 'gemini-2.0-flash-lite');
  });

  test('UserAiPreferencesService returns failure when testing empty API key', () async {
    final result = await UserAiPreferencesService.testGeminiConnection(
      apiKey: '',
      model: 'gemini-2.5-flash',
    );

    expect(result.isSuccess, isFalse);
    expect(result.message, contains('لطفاً ابتدا کلید API را وارد کنید'));
  });

  test('UserAiPreferencesService returns failure when testing key without AIzaSy prefix', () async {
    final result = await UserAiPreferencesService.testGeminiConnection(
      apiKey: 'invalid_dummy_key_without_aizasy_prefix',
      model: 'gemini-2.5-flash',
    );

    expect(result.isSuccess, isFalse);
    expect(result.message, contains('AIzaSy'));
  });

  test('UserAiPreferencesService has valid list of recommended Gemini models', () {
    expect(UserAiPreferencesService.availableModels, isNotEmpty);
    expect(UserAiPreferencesService.availableModels.any((m) => m.id == 'gemini-2.5-flash'), isTrue);
    expect(UserAiPreferencesService.availableModels.any((m) => m.id == 'gemini-2.5-pro'), isTrue);
    expect(UserAiPreferencesService.availableModels.any((m) => m.id == 'gemini-2.0-flash'), isTrue);
    expect(UserAiPreferencesService.availableModels.any((m) => m.id == 'gemini-2.0-flash-lite'), isTrue);
    expect(UserAiPreferencesService.availableModels.any((m) => m.id == 'gemini-1.5-flash'), isTrue);
    expect(UserAiPreferencesService.availableModels.any((m) => m.id == 'gemini-1.5-pro'), isTrue);
  });
}
