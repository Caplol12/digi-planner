import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:journal_app/screens/pro_template_builder_screen.dart';
import 'package:journal_app/services/user_ai_preferences_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('ProTemplateBuilderScreen renders AI Engine Status card and opens settings sheet', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: ProTemplateBuilderScreen(
            onTemplateCreated: (_, __) {},
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Verify AI Engine card is present in Step 1
    expect(find.textContaining('موتور هوش مصنوعی:'), findsWidgets);
    expect(find.textContaining('تنظیمات کلید'), findsOneWidget);

    // Tap on settings button to open bottom sheet
    await tester.tap(find.text('تنظیمات کلید'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verify Sheet Header and Options
    expect(find.text('تنظیمات موتور هوش مصنوعی'), findsOneWidget);
    expect(find.textContaining('هوش مصنوعی پیش‌فرض برنامه'), findsOneWidget);
    expect(find.text('Google AI Studio (کلید شخصی شما)'), findsOneWidget);

    // Tap Google AI Studio option
    await tester.tap(find.text('Google AI Studio (کلید شخصی شما)'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Verify Gemini Model dropdown and API Key input appear
    expect(find.textContaining('انتخاب مدل جمنای'), findsOneWidget);
    expect(find.textContaining('کلید اختصاصی API Key:'), findsOneWidget);
    expect(find.text('تست اتصال به سرور Google AI'), findsOneWidget);

    // Test entering API Key
    final apiKeyFinder = find.byType(TextField).first;
    await tester.enterText(apiKeyFinder, 'AIzaSySampleApiKeyForTesting');
    await tester.pump();

    // Tap Save button
    await tester.tap(find.text('ذخیره و اعمال تنظیمات'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Verify preferences were persisted
    expect(UserAiPreferencesService.activeProvider, AiProviderType.googleAiStudio);
    expect(UserAiPreferencesService.geminiApiKey, 'AIzaSySampleApiKeyForTesting');
  });
}
