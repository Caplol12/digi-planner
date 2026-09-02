import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:journal_app/main.dart';
import 'package:journal_app/screens/choose_page_style_screen.dart';
import 'package:journal_app/screens/pro_template_builder_screen.dart';
import 'package:journal_app/screens/journal_editor_screen.dart';
import 'package:journal_app/models/page_style_model.dart';
import 'package:journal_app/models/ai_layout_model.dart';
import 'package:journal_app/models/text_box_model.dart';
import 'package:journal_app/widgets/draggable_text_box.dart';
import 'package:journal_app/widgets/bounded_writing_zone.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('JournalApp loads main navigation and tabs', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(const JournalApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.textContaining('ژورنال‌ها'), findsWidgets);
    expect(find.textContaining('قالب‌ها'), findsWidgets);
    expect(find.text('ایجاد'), findsOneWidget);

    // Open create modal and verify create page option is present
    await tester.tap(find.text('ایجاد'));
    await tester.pump(const Duration(milliseconds: 500));
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
            onJournalCreated: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Step 1: Verify Image Input Step
    expect(find.textContaining('انتخاب تصویر برگه'), findsWidgets);
    expect(find.textContaining('مرحله اول: تصویر برگه را وارد کنید'), findsOneWidget);
    expect(find.textContaining('انتخاب تصویر از حافظه دستگاه'), findsOneWidget);

    final nextStepFinder = find.textContaining('مرحله بعد: اسکن و ساخت باکس‌های متن با هوش مصنوعی');
    expect(nextStepFinder, findsOneWidget);
    await tester.ensureVisible(nextStepFinder);
    await tester.tap(nextStepFinder);
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 1));

    // Step 2: Verify AI Scanning and Boxes Placement
    expect(find.textContaining('اسکن هوشمند و تعیین باکس‌ها'), findsWidgets);
    expect(find.textContaining('متناسب با خطوط و بخش‌ها قرار داد'), findsOneWidget);

    // Tap on suggestion chip
    final chipFinder = find.text('یک چک‌لیست اولویت‌ها اضافه کن');
    expect(chipFinder, findsOneWidget);
    await tester.tap(chipFinder);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    // Verify proceed button
    expect(find.textContaining('تایید و ورود به ویرایشگر برگه'), findsOneWidget);
  });

  testWidgets('JournalEditorScreen with PageStyle provides natural note typing without floating boxes', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final config = PageStyleConfig(
      sizeOption: PageSizeOption.defaultSizes[0], // A4 / Square
      orientation: PageOrientation.portrait,
      spread: PageSpread.single,
      pageType: PageType.lined,
      backgroundColor: Colors.white,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: JournalEditorScreen(
            pageStyle: config,
            onSave: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify natural note writing exists directly on the paper without floating boxes
    expect(find.byType(TextField), findsOneWidget);

    // Type natural note text directly on the notebook paper
    await tester.enterText(find.byType(TextField), 'سلام این یک یادداشت طبیعی و کاملاً استاندارد روی برگه است.');
    await tester.pumpAndSettle();

    expect(find.text('سلام این یک یادداشت طبیعی و کاملاً استاندارد روی برگه است.'), findsOneWidget);

    // Verify text styling tools are directly visible in page style mode
    expect(find.text('قلم و اندازه'), findsOneWidget);
    expect(find.text('رنگ جوهر'), findsOneWidget);
    expect(find.text('تراز متن'), findsOneWidget);
    expect(find.text('بولد'), findsOneWidget);
    expect(find.text('هایلایتر'), findsOneWidget);
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

  testWidgets('DraggableTextBoxWidget maintains fixed layout position when selected', (WidgetTester tester) async {
    final item = TextBoxItem(
      id: 'test_box',
      text: 'Test content',
      hintText: 'Hint',
      position: const Offset(50, 80),
      width: 200,
      height: 40,
      isSelected: false,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              DraggableTextBoxWidget(
                item: item,
                isSelected: false,
                onPositionChanged: (_) {},
                onSizeChanged: (_, __) {},
                onTap: () {},
                onDelete: () {},
                onTextChanged: (_) {},
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final unselectedRect = tester.getRect(find.byType(TextField));

    // Rebuild with isSelected = true
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              DraggableTextBoxWidget(
                item: item,
                isSelected: true,
                onPositionChanged: (_) {},
                onSizeChanged: (_, __) {},
                onTap: () {},
                onDelete: () {},
                onTextChanged: (_) {},
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final selectedRect = tester.getRect(find.byType(TextField));

    // The TextField position must remain identical (zero layout jump)
    expect(selectedRect.left, equals(unselectedRect.left));
    expect(selectedRect.top, equals(unselectedRect.top));
    expect(selectedRect.width, equals(unselectedRect.width));
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


