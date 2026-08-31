import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:journal_app/main.dart';
import 'package:journal_app/screens/choose_page_style_screen.dart';
import 'package:journal_app/screens/pro_template_builder_screen.dart';
import 'package:journal_app/screens/journal_editor_screen.dart';
import 'package:journal_app/models/page_style_model.dart';

void main() {
  testWidgets('JournalApp loads main navigation and tabs', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(const JournalApp());
    await tester.pumpAndSettle();

    expect(find.textContaining('ژورنال'), findsWidgets);
    expect(find.textContaining('ساخت برگه'), findsWidgets);
    expect(find.textContaining('قالب‌ها'), findsWidgets);
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

    // Verify header and sections from screenshot
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
    expect(find.textContaining('ورود تصویر برگه'), findsWidgets);
    expect(find.textContaining('مرحله اول: تصویر برگه را وارد کنید'), findsOneWidget);
    expect(find.textContaining('آپلود یا انتخاب تصویر از دستگاه'), findsOneWidget);

    final nextStepFinder = find.textContaining('مرحله بعد: اسکن و تعیین باکس‌های متن');
    expect(nextStepFinder, findsOneWidget);
    await tester.ensureVisible(nextStepFinder);
    await tester.tap(nextStepFinder);
    await tester.pumpAndSettle();

    // Step 2: Verify AI Scanning and Boxes Placement
    expect(find.textContaining('اسکن AI و تعیین باکس‌ها'), findsWidgets);
    expect(find.textContaining('باکس متن را متناسب با خطوط تصویر قرار داد'), findsOneWidget);

    // Tap on suggestion chip
    final chipFinder = find.text('یک چک‌لیست اولویت‌ها اضافه کن');
    expect(chipFinder, findsOneWidget);
    await tester.tap(chipFinder);
    await tester.pumpAndSettle();

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
}


