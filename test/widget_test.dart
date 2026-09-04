import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:journal_app/main.dart';
import 'package:journal_app/screens/choose_page_style_screen.dart';
import 'package:journal_app/screens/pro_template_builder_screen.dart';
import 'package:journal_app/models/page_style_model.dart';
import 'package:journal_app/models/ai_layout_model.dart';
import 'package:journal_app/services/ai_subscription_service.dart';
import 'package:journal_app/services/notebook_storage_service.dart';
import 'package:journal_app/services/user_ai_preferences_service.dart';
import 'package:journal_app/models/text_box_model.dart';
import 'package:journal_app/widgets/bounded_writing_zone.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    NotebookStorageService.instance.resetForTesting();
    AiSubscriptionService.instance.resetForTesting();
    UserAiPreferencesService.resetForTesting();
    await AiSubscriptionService.instance.init();
  });

  testWidgets('JournalApp loads main navigation and tabs', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(const JournalApp());
    for (int i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }

    expect(find.textContaining('ژورنال‌ها'), findsWidgets);
    expect(find.textContaining('قالب‌ها'), findsWidgets);
    expect(find.text('ایجاد'), findsOneWidget);

    // Open create modal and verify create page option is present
    await tester.tap(find.text('ایجاد'));
    for (int i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(find.textContaining('ساخت برگه با سبک دلخواه'), findsOneWidget);
  });

  testWidgets('ChoosePageStyleScreen renders style options and can trigger Begin New Planner', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    PageStyleConfig? selectedConfig;

    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.ltr,
          child: ChoosePageStyleScreen(
            onBeginPlanner: (config) {
              selectedConfig = config;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify header and sections
    expect(find.text('انتخاب سبک برگه'), findsOneWidget);
    expect(find.text('اندازه و ابعاد برگه'), findsOneWidget);
    expect(find.text('چیدمان و جهت صفحه'), findsOneWidget);
    expect(find.text('رنگ پس‌زمینه برگه'), findsOneWidget);
    expect(find.text('الگو و خط‌کشی کاغذ یادداشت'), findsOneWidget);
    expect(find.text('شروع پلنر جدید'), findsOneWidget);

    // Verify sizes
    expect(find.text('Square'), findsOneWidget);
    expect(find.text('iPhone'), findsOneWidget);
    expect(find.text('Letter'), findsOneWidget);
    expect(find.text('A4'), findsOneWidget);

    // Tap on A4
    await tester.tap(find.text('A4'));
    await tester.pumpAndSettle();

    // Tap on Landscape (افقی)
    await tester.tap(find.text('افقی'));
    await tester.pumpAndSettle();

    // Scroll to find Lined if needed and tap it
    final linedFinder = find.text('Lined');
    await tester.ensureVisible(linedFinder);
    await tester.tap(linedFinder);
    await tester.pumpAndSettle();

    // Tap on 'شروع پلنر جدید'
    await tester.tap(find.text('شروع پلنر جدید'));
    await tester.pumpAndSettle();

    expect(selectedConfig, isNotNull);
    expect(selectedConfig!.sizeOption.id, 'a4');
    expect(selectedConfig!.pageType, PageType.lined);
    expect(selectedConfig!.orientation, PageOrientation.landscape);
  });

  testWidgets('ProTemplateBuilderScreen operates step-by-step (Step 1 Image -> Step 2 AI Scan & Boxes)', (WidgetTester tester) async {
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
    await tester.pumpAndSettle();

    // Step 1: Verify Image Input Step
    expect(find.textContaining('انتخاب تصویر برگه'), findsWidgets);
    expect(find.textContaining('مرحله اول: تصویر برگه را وارد کنید'), findsOneWidget);
    expect(find.textContaining('انتخاب تصویر از حافظه دستگاه'), findsOneWidget);

    final nextStepFinder = find.widgetWithText(ElevatedButton, 'مرحله بعد: اسکن و ساخت باکس‌های متن با هوش مصنوعی');
    expect(nextStepFinder, findsOneWidget);
    await tester.ensureVisible(nextStepFinder);
    await tester.tap(nextStepFinder);
    await tester.pump();
    for (int i = 0; i < 15; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }

    // Step 2: Verify AI Scanning and Boxes Placement
    print('STEP 2 ALL TEXTS: ${tester.allWidgets.whereType<Text>().map((t) => t.data).where((t) => t != null && t.isNotEmpty).toList()}');
    print('IS ANALYZING: ${find.byType(CircularProgressIndicator).evaluate().isNotEmpty}');

    final chipFinder = find.text('یک چک‌لیست اولویت‌ها اضافه کن');
    await tester.ensureVisible(chipFinder);
    expect(chipFinder, findsOneWidget);
    await tester.tap(chipFinder);
    for (int i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }

    // Verify proceed button
    final proceedFinder = find.textContaining('تایید و ورود به ویرایشگر برگه');
    await tester.ensureVisible(proceedFinder);
    expect(proceedFinder, findsOneWidget);
  });

  test('DetectedBox and TextBoxItem deserialization generates unique IDs', () {
    final box1 = DetectedBox.fromJson({'label': 'Box 1'});
    final box2 = DetectedBox.fromJson({'label': 'Box 2'});
    expect(box1.id, isNotEmpty);
    expect(box2.id, isNotEmpty);
    expect(box1.id, isNot(equals(box2.id)));

    final tb1 = TextBoxItem.fromJson({'text': 'Hello'});
    final tb2 = TextBoxItem.fromJson({'text': 'World'});
    expect(tb1.id, isNotEmpty);
    expect(tb2.id, isNotEmpty);
    expect(tb1.id, isNot(equals(tb2.id)));
  });

  test('DetectedBox toTextBoxItem produces empty text with hintText', () {
    final detected = DetectedBox(
      id: 'box_test_1',
      label: 'یادداشت روزانه',
      type: DetectedBoxType.ruledLines,
      normalizedX: 0.1,
      normalizedY: 0.2,
      normalizedWidth: 0.8,
      normalizedHeight: 0.3,
      placeholderText: 'اینجا بنویسید...',
    );

    final tb = detected.toTextBoxItem(const Size(420, 630));
    expect(tb.text, isEmpty); // Blank so user doesn't have to backspace placeholder text
    expect(tb.hintText, 'اینجا بنویسید...');
    expect(tb.position.dx, 42.0);
    expect(tb.position.dy, 126.0);
  });

  testWidgets('BoundedWritingZoneWidget renders dashed border when focused and triggers autoAdvance on submit', (WidgetTester tester) async {
    bool autoAdvanced = false;

    final item = TextBoxItem(
      id: 'zone_1',
      text: 'Schedule item',
      hintText: '9 AM Meeting',
      position: const Offset(40, 100),
      width: 200,
      height: 28,
      isSelected: false,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              BoundedWritingZoneWidget(
                item: item,
                isSelected: true,
                onTap: () {},
                onTextChanged: (_) {},
                onAutoAdvance: () => autoAdvanced = true,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify CustomPaint with DashedRectPainter is present
    expect(find.byType(CustomPaint), findsWidgets);
    expect(find.text('Schedule item'), findsOneWidget);

    // Tap and submit TextField to test auto-advance
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    await tester.showKeyboard(find.byType(TextField));
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pumpAndSettle();

    expect(autoAdvanced, isTrue);
  });
}
