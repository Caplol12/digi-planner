import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'app_logger.dart';
import 'export_download_helper.dart';
import 'file_storage_helper.dart';
import 'notebook_storage_service.dart';
import 'persian_date_helper.dart';
import '../models/notebook_model.dart';
import '../models/template_model.dart';
import '../models/ai_layout_model.dart';

enum PackageType { template, page, notebook, aiLayout, combinedBundle, unknown }

class ImportResult {
  final PackageType type;
  final JournalTemplate? template;
  final NotebookPageModel? page;
  final NotebookModel? notebook;
  final AILayoutResult? aiLayout;
  final List<NotebookModel>? notebooks;
  final List<JournalTemplate>? templates;
  final List<NotebookPageModel>? pages;
  final String message;
  final bool isSuccess;

  ImportResult({
    required this.type,
    this.template,
    this.page,
    this.notebook,
    this.aiLayout,
    this.notebooks,
    this.templates,
    this.pages,
    required this.message,
    this.isSuccess = true,
  });

  factory ImportResult.error(String message) {
    return ImportResult(
      type: PackageType.unknown,
      message: message,
      isSuccess: false,
    );
  }
}

class ExportResult {
  final bool isSuccess;
  final String fileName;
  final String? filePath;
  final String userMessage;
  final bool isShared;

  ExportResult({
    required this.isSuccess,
    required this.fileName,
    this.filePath,
    required this.userMessage,
    this.isShared = false,
  });

  factory ExportResult.error(String message) {
    return ExportResult(
      isSuccess: false,
      fileName: '',
      userMessage: message,
    );
  }
}

class NotebookExportService {
  static final NotebookExportService instance = NotebookExportService._();
  NotebookExportService._();

  static const int currentSchemaVersion = 1;

  String? _activeWidgetNotebookId;

  String? get activeWidgetNotebookId => _activeWidgetNotebookId;

  void setActiveWidgetNotebook(String notebookId) {
    _activeWidgetNotebookId = notebookId;
  }

  /// Core cross-platform export: Web direct download, Mobile share sheet, Desktop local file
  Future<ExportResult> exportDataSmart({
    required String content,
    required String fileName,
    String mimeType = 'application/json',
    String? shareSubject,
  }) async {
    try {
      if (kIsWeb) {
        final bytes = utf8.encode(content);
        triggerWebDownload(bytes: bytes, fileName: fileName, mimeType: mimeType);
        return ExportResult(
          isSuccess: true,
          fileName: fileName,
          userMessage: 'فایل «$fileName» با موفقیت در مرورگر دانلود شد.',
        );
      }

      // Mobile platforms: Android / iOS (via pure cross-platform XFile.fromData and SharePlus)
      if (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS) {
        final bytes = Uint8List.fromList(utf8.encode(content));
        final xfile = XFile.fromData(bytes, mimeType: mimeType, name: fileName);
        await SharePlus.instance.share(
          ShareParams(
            files: [xfile],
            subject: shareSubject ?? fileName,
            text: 'فایل خروجی PlanWiz: $fileName',
          ),
        );

        return ExportResult(
          isSuccess: true,
          fileName: fileName,
          isShared: true,
          userMessage: 'فایل «$fileName» آماده اشتراک‌گذاری یا ذخیره شد.',
        );
      }

      // Desktop platforms: Save via cross-platform local write
      final success = await writeLocalFile(fileName, content);
      return ExportResult(
        isSuccess: success,
        fileName: fileName,
        userMessage: success ? 'فایل «$fileName» در پوشه برنامه ذخیره شد.' : 'خطا در ذخیره فایل در دیسک.',
      );
    } catch (e, st) {
      AppLog.e('ExportService', 'Export error: $e', st);
      return ExportResult.error('خطا در صدور فایل: $e');
    }
  }

  /// Export single template to JSON
  Future<ExportResult> exportTemplateToJson(JournalTemplate template) async {
    final safeTitle = template.title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final fileName = 'PlanWiz_Template_${safeTitle}_${DateTime.now().millisecondsSinceEpoch}.json';
    final payload = {
      'exportType': 'template',
      'schemaVersion': currentSchemaVersion,
      'appVersion': '1.0',
      'exportedAt': DateTime.now().toIso8601String(),
      'template': template.toJson(),
    };
    final jsonStr = const JsonEncoder.withIndent('  ').convert(payload);
    return await exportDataSmart(content: jsonStr, fileName: fileName, shareSubject: template.title);
  }

  /// Export single page (with associated template if any) to JSON
  Future<ExportResult> exportPageToJson(NotebookPageModel page, {JournalTemplate? associatedTemplate}) async {
    final safeTitle = page.title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final fileName = 'PlanWiz_Page_${safeTitle}_${DateTime.now().millisecondsSinceEpoch}.json';
    final payload = {
      'exportType': 'page',
      'schemaVersion': currentSchemaVersion,
      'appVersion': '1.0',
      'exportedAt': DateTime.now().toIso8601String(),
      'page': page.toJson(),
      'associatedTemplate': associatedTemplate?.toJson(),
    };
    final jsonStr = const JsonEncoder.withIndent('  ').convert(payload);
    return await exportDataSmart(content: jsonStr, fileName: fileName, shareSubject: page.title);
  }

  /// Export complete notebook data as a standalone JSON backup
  Future<ExportResult> exportJsonBackup(NotebookModel notebook) async {
    return exportNotebookToJson(notebook);
  }

  /// Export complete notebook to JSON with all associated custom templates bundled
  Future<ExportResult> exportNotebookToJson(NotebookModel notebook) async {
    final safeTitle = notebook.title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final fileName = 'PlanWiz_Notebook_${safeTitle}_${DateTime.now().millisecondsSinceEpoch}.json';

    // Collect all unique templates used in this notebook's pages
    final List<JournalTemplate> associatedTemplates = [];
    for (final page in notebook.pages) {
      if (page.template != null && !associatedTemplates.any((t) => t.id == page.template!.id)) {
        associatedTemplates.add(page.template!);
      }
    }

    final payload = {
      'exportType': 'notebook',
      'schemaVersion': currentSchemaVersion,
      'appVersion': '1.0',
      'exportedAt': DateTime.now().toIso8601String(),
      'notebook': notebook.toJson(),
      'templates': associatedTemplates.map((t) => t.toJson()).toList(),
    };
    final jsonStr = const JsonEncoder.withIndent('  ').convert(payload);
    return await exportDataSmart(content: jsonStr, fileName: fileName, shareSubject: notebook.title);
  }

  /// Export AI Vision Layout result to JSON
  Future<ExportResult> exportAiLayoutToJson(AILayoutResult layoutResult) async {
    final safeTitle = layoutResult.title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final fileName = 'PlanWiz_AILayout_${safeTitle}_${DateTime.now().millisecondsSinceEpoch}.json';
    final payload = {
      'exportType': 'ai_layout',
      'schemaVersion': currentSchemaVersion,
      'appVersion': '1.0',
      'exportedAt': DateTime.now().toIso8601String(),
      'aiLayout': layoutResult.toJson(),
    };
    final jsonStr = const JsonEncoder.withIndent('  ').convert(payload);
    return await exportDataSmart(content: jsonStr, fileName: fileName, shareSubject: layoutResult.title);
  }

  /// Export combined bundle containing multiple notebooks, templates, and pages
  Future<ExportResult> exportCombinedBundleToJson({
    List<NotebookModel>? notebooks,
    List<JournalTemplate>? templates,
    List<NotebookPageModel>? pages,
    String bundleTitle = 'Combined_Bundle',
  }) async {
    final safeTitle = bundleTitle.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final fileName = 'PlanWiz_Bundle_${safeTitle}_${DateTime.now().millisecondsSinceEpoch}.json';
    final payload = {
      'exportType': 'combined_bundle',
      'schemaVersion': currentSchemaVersion,
      'appVersion': '1.0',
      'exportedAt': DateTime.now().toIso8601String(),
      'notebooks': notebooks?.map((n) => n.toJson()).toList() ?? [],
      'templates': templates?.map((t) => t.toJson()).toList() ?? [],
      'pages': pages?.map((p) => p.toJson()).toList() ?? [],
    };
    final jsonStr = const JsonEncoder.withIndent('  ').convert(payload);
    return await exportDataSmart(content: jsonStr, fileName: fileName, shareSubject: bundleTitle);
  }

  /// Parse and import JSON package string into appropriate domain objects with schema validation
  ImportResult importPackageFromJson(String jsonContent) {
    try {
      if (jsonContent.trim().isEmpty) {
        return ImportResult.error('محتوای فایل خالی است.');
      }

      final decoded = jsonDecode(jsonContent);

      // 1. Direct List Fallback (Legacy notebook array format)
      if (decoded is List) {
        final List<NotebookModel> loadedNotebooks = [];
        for (final item in decoded) {
          try {
            if (item is Map<String, dynamic>) {
              loadedNotebooks.add(NotebookModel.fromJson(item));
            }
          } catch (e) {
            AppLog.e('ExportService', 'Corrupt notebook in list import: $e');
          }
        }
        if (loadedNotebooks.isNotEmpty) {
          return ImportResult(
            type: PackageType.combinedBundle,
            notebooks: loadedNotebooks,
            message: 'تعداد ${loadedNotebooks.length} دفترچه از فایل پشتیبان بازیابی شد.',
          );
        }
      }

      // 2. Map Payload Format with schema check
      if (decoded is Map<String, dynamic>) {
        final schemaVer = decoded['schemaVersion'] as int? ?? 1;
        if (schemaVer > currentSchemaVersion) {
          return ImportResult.error('این فایل با نسخه جدیدتری از برنامه ساخته شده و پشتیبانی نمی‌شود.');
        }

        final String exportType = decoded['exportType'] as String? ?? '';

        // Template package
        if (exportType == 'template' || decoded.containsKey('template')) {
          final tMap = decoded['template'] as Map<String, dynamic>? ?? decoded;
          final template = JournalTemplate.fromJson(tMap);
          return ImportResult(
            type: PackageType.template,
            template: template,
            message: 'قالب «${template.title}» با موفقیت بازیابی شد.',
          );
        }

        // Page package
        if (exportType == 'page' || (decoded.containsKey('page') && !decoded.containsKey('pages'))) {
          final pMap = decoded['page'] as Map<String, dynamic>? ?? decoded;
          final page = NotebookPageModel.fromJson(pMap);
          JournalTemplate? associatedTmpl;
          if (decoded['associatedTemplate'] != null) {
            try {
              associatedTmpl = JournalTemplate.fromJson(decoded['associatedTemplate'] as Map<String, dynamic>);
              JournalTemplate.registerTemplate(associatedTmpl);
              NotebookStorageService.instance.saveOrUpdateCustomTemplate(associatedTmpl);
            } catch (_) {}
          }
          return ImportResult(
            type: PackageType.page,
            page: page,
            template: associatedTmpl,
            message: 'برگه «${page.title}» با موفقیت بازیابی شد.',
          );
        }

        // AI Layout package
        if (exportType == 'ai_layout' || decoded.containsKey('aiLayout')) {
          final lMap = decoded['aiLayout'] as Map<String, dynamic>? ?? decoded;
          final aiLayout = AILayoutResult.fromJson(lMap);
          return ImportResult(
            type: PackageType.aiLayout,
            aiLayout: aiLayout,
            message: 'چیدمان هوش مصنوعی «${aiLayout.title}» بازیابی شد.',
          );
        }

        // Notebook package
        if (exportType == 'notebook' || decoded.containsKey('notebook')) {
          final nbMap = decoded['notebook'] as Map<String, dynamic>? ?? decoded;
          final notebook = NotebookModel.fromJson(nbMap);

          // Register any bundled custom templates
          if (decoded['templates'] != null && decoded['templates'] is List) {
            for (final tJson in decoded['templates']) {
              try {
                final tmpl = JournalTemplate.fromJson(tJson as Map<String, dynamic>);
                JournalTemplate.registerTemplate(tmpl);
                NotebookStorageService.instance.saveOrUpdateCustomTemplate(tmpl);
              } catch (_) {}
            }
          }

          return ImportResult(
            type: PackageType.notebook,
            notebook: notebook,
            message: 'دفترچه «${notebook.title}» با موفقیت بازیابی شد.',
          );
        }

        // Combined Bundle package
        if (exportType == 'combined_bundle' || decoded.containsKey('notebooks')) {
          final List<NotebookModel> loadedNbs = [];
          final List<JournalTemplate> loadedTmpls = [];
          final List<NotebookPageModel> loadedPgs = [];

          if (decoded['templates'] is List) {
            for (final item in decoded['templates']) {
              try {
                final t = JournalTemplate.fromJson(item as Map<String, dynamic>);
                JournalTemplate.registerTemplate(t);
                NotebookStorageService.instance.saveOrUpdateCustomTemplate(t);
                loadedTmpls.add(t);
              } catch (_) {}
            }
          }

          if (decoded['notebooks'] is List) {
            for (final item in decoded['notebooks']) {
              try {
                loadedNbs.add(NotebookModel.fromJson(item as Map<String, dynamic>));
              } catch (_) {}
            }
          }

          if (decoded['pages'] is List) {
            for (final item in decoded['pages']) {
              try {
                loadedPgs.add(NotebookPageModel.fromJson(item as Map<String, dynamic>));
              } catch (_) {}
            }
          }

          return ImportResult(
            type: PackageType.combinedBundle,
            notebooks: loadedNbs,
            templates: loadedTmpls,
            pages: loadedPgs,
            message: 'بسته ترکیبی شامل ${loadedNbs.length} دفترچه و ${loadedTmpls.length} قالب بازیابی شد.',
          );
        }
      }

      return ImportResult.error('فرمت فایل نامعتبر یا ناشناخته است.');
    } catch (e, st) {
      AppLog.e('ExportService', 'Import parse error: $e', st);
      return ImportResult.error('خطا در خواندن محتوای فایل: $e');
    }
  }

  /// Print or export direct PDF document with Persian typography
  Future<bool> printOrShareNotebookPdf(NotebookModel notebook, {bool isDirectPrint = true}) async {
    try {
      final doc = pw.Document();
      final font = await PdfGoogleFonts.vazirmatnRegular();
      final boldFont = await PdfGoogleFonts.vazirmatnBold();

      for (int i = 0; i < notebook.pages.length; i++) {
        final page = notebook.pages[i];
        doc.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            textDirection: pw.TextDirection.rtl,
            theme: pw.ThemeData.withFont(base: font, bold: boldFont),
            build: (pw.Context context) {
              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(notebook.title, style: pw.TextStyle(font: boldFont, fontSize: 18, color: PdfColors.deepOrange)),
                      pw.Text(page.title, style: pw.TextStyle(font: font, fontSize: 12, color: PdfColors.grey700)),
                    ],
                  ),
                  pw.Divider(color: PdfColors.grey300),
                  pw.SizedBox(height: 10),
                  if (page.noteTitle.isNotEmpty)
                    pw.Text(page.noteTitle, style: pw.TextStyle(font: boldFont, fontSize: 14)),
                  if (page.noteBody.isNotEmpty)
                    pw.Paragraph(text: page.noteBody, style: pw.TextStyle(font: font, fontSize: 12)),
                  if (page.cueText.isNotEmpty)
                    pw.Text('نکات کلیدی: ${page.cueText}', style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.blueGrey800)),
                  if (page.summaryText.isNotEmpty)
                    pw.Text('خلاصه: ${page.summaryText}', style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.blueGrey800)),
                  ...page.textBoxes.where((b) => b.text.trim().isNotEmpty).map(
                    (b) => pw.Bullet(text: b.text, style: pw.TextStyle(font: font, fontSize: 11)),
                  ),
                  ...page.checkItems.map(
                    (c) => pw.Text('${c.isChecked ? "[x]" : "[ ]"} ${c.label}', style: pw.TextStyle(font: font, fontSize: 11)),
                  ),
                ],
              );
            },
          ),
        );
      }

      if (isDirectPrint) {
        await Printing.layoutPdf(onLayout: (format) async => doc.save(), name: notebook.title);
      } else {
        await Printing.sharePdf(bytes: await doc.save(), filename: '${notebook.title}.pdf');
      }
      return true;
    } catch (e, st) {
      AppLog.e('ExportService', 'Failed to generate/print PDF', st);
      return false;
    }
  }

  /// Format complete notebook as clean text
  String formatNotebookAsText(NotebookModel notebook) {
    final buffer = StringBuffer();
    buffer.writeln('========================================');
    buffer.writeln('📓 دفترچه: ${notebook.title}');
    buffer.writeln('📅 تاریخ ویرایش: ${notebook.updatedAt.toPersianDateTimeStr()}');
    buffer.writeln('📄 تعداد برگه: ${notebook.pages.length}');
    buffer.writeln('========================================\n');

    for (int i = 0; i < notebook.pages.length; i++) {
      final page = notebook.pages[i];
      buffer.writeln('--- برگه ${i + 1}: ${page.title} ---');
      if (page.scheduledDate != null) {
        buffer.writeln('⏰ تاریخ زمان‌بندی: ${page.scheduledDate!.toPersianDateTimeStr()}');
      }
      if (page.noteTitle.isNotEmpty) {
        buffer.writeln('📌 عنوان: ${page.noteTitle}');
      }
      if (page.noteBody.isNotEmpty) {
        buffer.writeln('\n${page.noteBody}\n');
      }
      if (page.cueText.isNotEmpty) {
        buffer.writeln('💡 نکات کلیدی: ${page.cueText}');
      }
      if (page.summaryText.isNotEmpty) {
        buffer.writeln('📝 خلاصه: ${page.summaryText}');
      }
      if (page.textBoxes.isNotEmpty) {
        buffer.writeln('\n🔲 جعبه‌های متنی:');
        for (final b in page.textBoxes) {
          if (b.text.trim().isNotEmpty) {
            buffer.writeln('  • ${b.text}');
          }
        }
      }
      if (page.checkItems.isNotEmpty) {
        buffer.writeln('\n☑️ چک‌لیست:');
        for (final c in page.checkItems) {
          buffer.writeln('  ${c.isChecked ? "[x]" : "[ ]"} ${c.label}');
        }
      }
      if (page.stickers.isNotEmpty) {
        buffer.writeln('\n🎨 استیکرها: ${page.stickers.map((s) => s.content).join(" ")}');
      }
      if (page.drawingStrokes.isNotEmpty) {
        buffer.writeln('✏️ دست‌نویس: شامل ${page.drawingStrokes.length} خط دست‌نویس');
      }
      buffer.writeln('\n');
    }

    return buffer.toString();
  }

  /// Generate a clean printable HTML document for Save PDF / Print with full handwriting & stickers
  Future<ExportResult> exportHtmlPrintableDocument(NotebookModel notebook) async {
    final safeTitle = notebook.title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final fileName = 'PlanWiz_Print_${safeTitle}_${DateTime.now().millisecondsSinceEpoch}.html';

    final buffer = StringBuffer();
    buffer.writeln('''<!DOCTYPE html>
<html lang="fa" dir="rtl">
<head>
  <meta charset="UTF-8">
  <title>${_escapeHtml(notebook.title)} - PlanWiz</title>
  <style>
    body { font-family: system-ui, -apple-system, sans-serif; background: #f8fafc; color: #1e293b; padding: 30px; margin: 0; }
    .notebook-card { max-width: 800px; margin: 0 auto; background: white; border-radius: 16px; box-shadow: 0 4px 20px rgba(0,0,0,0.08); padding: 36px; }
    .header { border-bottom: 2px solid #e2e8f0; padding-bottom: 18px; margin-bottom: 24px; }
    .title { font-size: 26px; font-weight: 900; color: #e07a5f; margin: 0 0 8px 0; }
    .meta { font-size: 13px; color: #64748b; }
    .page-box { background: #ffffff; border: 1px solid #e2e8f0; border-radius: 12px; padding: 20px; margin-bottom: 20px; page-break-inside: avoid; }
    .page-title { font-size: 18px; font-weight: bold; color: #1e293b; border-bottom: 1px dashed #cbd5e1; padding-bottom: 8px; margin-bottom: 12px; }
    .note-content { font-size: 14px; line-height: 1.8; color: #334155; white-space: pre-wrap; }
    .badge { display: inline-block; background: #ffede8; color: #bf360c; font-size: 12px; padding: 4px 10px; border-radius: 6px; font-weight: bold; }
    @media print {
      body { background: white; padding: 0; }
      .notebook-card { box-shadow: none; padding: 0; }
    }
  </style>
</head>
<body>
  <div class="notebook-card">
    <div class="header">
      <h1 class="title">${_escapeHtml(notebook.title)}</h1>
      <div class="meta">
        <span>تاریخ: ${notebook.updatedAt.toPersianDateTimeStr()}</span> | 
        <span class="badge">${notebook.pages.length} برگه</span>
      </div>
    </div>
''');

    for (int i = 0; i < notebook.pages.length; i++) {
      final page = notebook.pages[i];
      final tmpl = page.template;
      String? imageSrc;
      if (tmpl != null) {
        if (tmpl.imageBytes != null && tmpl.imageBytes!.isNotEmpty) {
          imageSrc = 'data:image/jpeg;base64,${base64Encode(tmpl.imageBytes!)}';
        } else if (tmpl.imageAsset != null && tmpl.imageAsset!.isNotEmpty) {
          if (tmpl.imageAsset!.startsWith('data:') || tmpl.imageAsset!.startsWith('http')) {
            imageSrc = tmpl.imageAsset;
          }
        }
      }

      buffer.writeln('''
    <div class="page-box">
      <div class="page-title">برگه ${i + 1}: ${_escapeHtml(page.title)}</div>
''');

      if (imageSrc != null && tmpl != null) {
        final double canvasAspect = tmpl.aspectRatio > 0 ? tmpl.aspectRatio : 0.67;
        buffer.writeln('''
      <div style="position: relative; width: 100%; max-width: 580px; margin: 0 auto 16px; aspect-ratio: $canvasAspect; border-radius: 12px; overflow: hidden; box-shadow: 0 4px 16px rgba(0,0,0,0.1); background: #ffffff;">
        <img src="$imageSrc" style="width: 100%; height: 100%; object-fit: contain; position: absolute; top: 0; left: 0; display: block;" />
''');
        // Render text boxes
        for (final box in page.textBoxes) {
          final double leftPct = (box.normalizedX ?? (box.position.dx / 420.0)).clamp(0.0, 1.0) * 100;
          final double topPct = (box.normalizedY ?? (box.position.dy / 630.0)).clamp(0.0, 1.0) * 100;
          final double widthPct = (box.normalizedWidth ?? (box.width / 420.0)).clamp(0.05, 1.0) * 100;
          final String colorHex = '#${(box.inkColor.toARGB32() & 0x00FFFFFF).toRadixString(16).padLeft(6, '0')}';
          final String align = box.textAlign == TextAlign.left ? 'left' : (box.textAlign == TextAlign.center ? 'center' : 'right');
          final String txt = box.text.isNotEmpty ? box.text : '';
          if (txt.isNotEmpty) {
            buffer.writeln('''
        <div style="position: absolute; left: ${leftPct.toStringAsFixed(2)}%; top: ${topPct.toStringAsFixed(2)}%; width: ${widthPct.toStringAsFixed(2)}%; font-size: ${box.fontSize}px; color: $colorHex; text-align: $align; font-weight: ${box.isBold ? 'bold' : 'normal'}; line-height: 1.45; white-space: pre-wrap; word-break: break-word; pointer-events: none;">${_escapeHtml(txt)}</div>
''');
          }
        }

        // Render check items
        for (final chk in page.checkItems) {
          final double leftPct = chk.normalizedX.clamp(0.0, 1.0) * 100;
          final double topPct = chk.normalizedY.clamp(0.0, 1.0) * 100;
          buffer.writeln('''
        <div style="position: absolute; left: ${leftPct.toStringAsFixed(2)}%; top: ${topPct.toStringAsFixed(2)}%; font-size: 13px; color: #1e293b; font-weight: 500; pointer-events: none;">${chk.isChecked ? '☑' : '☐'} ${_escapeHtml(chk.label)}</div>
''');
        }

        // Render stickers (Issue 12)
        for (final st in page.stickers) {
          final double left = st.position.dx;
          final double top = st.position.dy;
          final double sz = 56.0 * st.scale;
          if (st.imagePath != null && st.imagePath!.isNotEmpty) {
            buffer.writeln('''
        <img src="${st.imagePath}" style="position: absolute; left: ${left}px; top: ${top}px; width: ${sz}px; height: ${sz}px; transform: rotate(${st.rotation}rad); pointer-events: none;" />
''');
          } else {
            buffer.writeln('''
        <div style="position: absolute; left: ${left}px; top: ${top}px; font-size: ${32 * st.scale}px; transform: rotate(${st.rotation}rad); pointer-events: none;">${st.content}</div>
''');
          }
        }

        // Render handwriting strokes as SVG overlay (Issue 12)
        if (page.drawingStrokes.isNotEmpty) {
          buffer.writeln('''
        <svg style="position: absolute; top: 0; left: 0; width: 100%; height: 100%; pointer-events: none;">
''');
          for (final stroke in page.drawingStrokes) {
            final pointsStr = stroke.points.map((p) => '${p.x.toStringAsFixed(1)},${p.y.toStringAsFixed(1)}').join(' ');
            final strokeHex = '#${(stroke.color.toARGB32() & 0x00FFFFFF).toRadixString(16).padLeft(6, '0')}';
            final opacity = stroke.isHighlighter ? 0.35 : 1.0;
            buffer.writeln('''
          <polyline points="$pointsStr" stroke="$strokeHex" stroke-width="${stroke.strokeWidth}" stroke-opacity="$opacity" fill="none" stroke-linecap="round" stroke-linejoin="round" />
''');
          }
          buffer.writeln('        </svg>');
        }

        buffer.writeln('      </div>');
      } else {
        // Plain Page Style note
        if (page.noteTitle.isNotEmpty) {
          buffer.writeln('      <h3>${_escapeHtml(page.noteTitle)}</h3>');
        }
        if (page.noteBody.isNotEmpty) {
          buffer.writeln('      <div class="note-content">${_escapeHtml(page.noteBody)}</div>');
        }
        if (page.cueText.isNotEmpty) {
          buffer.writeln('      <div style="margin-top: 10px; color: #64748b;"><strong>نکات کلیدی:</strong> ${_escapeHtml(page.cueText)}</div>');
        }
        if (page.summaryText.isNotEmpty) {
          buffer.writeln('      <div style="margin-top: 10px; color: #64748b;"><strong>خلاصه:</strong> ${_escapeHtml(page.summaryText)}</div>');
        }
        if (page.textBoxes.isNotEmpty) {
          buffer.writeln('      <h4>یادداشت‌های اضافی:</h4><ul>');
          for (final b in page.textBoxes) {
            if (b.text.trim().isNotEmpty) {
              buffer.writeln('        <li>${_escapeHtml(b.text)}</li>');
            }
          }
          buffer.writeln('      </ul>');
        }
      }
      buffer.writeln('    </div>');
    }

    buffer.writeln('''
  </div>
</body>
</html>''');

    return await exportDataSmart(
      content: buffer.toString(),
      fileName: fileName,
      mimeType: 'text/html',
      shareSubject: 'سند چاپی ${notebook.title}',
    );
  }

  String _escapeHtml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }
}
