import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
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

class NotebookExportService {
  static final NotebookExportService instance = NotebookExportService._();
  NotebookExportService._();

  String? _activeWidgetNotebookId;

  String? get activeWidgetNotebookId => _activeWidgetNotebookId;

  void setActiveWidgetNotebook(String notebookId) {
    _activeWidgetNotebookId = notebookId;
  }

  /// Helper to get application documents directory for saving export JSON files
  Future<File> _createExportFile(String prefix, String title) async {
    final dir = await getApplicationDocumentsDirectory();
    final safeTitle = title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return File('${dir.path}/${prefix}_${safeTitle}_$timestamp.json');
  }

  /// Export single template to JSON file
  Future<File> exportTemplateToJson(JournalTemplate template) async {
    final file = await _createExportFile('PlanWiz_Template', template.title);
    final payload = {
      'exportType': 'template',
      'appVersion': '1.0',
      'exportedAt': DateTime.now().toIso8601String(),
      'template': template.toJson(),
    };
    final jsonStr = const JsonEncoder.withIndent('  ').convert(payload);
    return await file.writeAsString(jsonStr);
  }

  /// Export single page (with associated template if any) to JSON file
  Future<File> exportPageToJson(NotebookPageModel page, {JournalTemplate? associatedTemplate}) async {
    final file = await _createExportFile('PlanWiz_Page', page.title);
    final payload = {
      'exportType': 'page',
      'appVersion': '1.0',
      'exportedAt': DateTime.now().toIso8601String(),
      'page': page.toJson(),
      'associatedTemplate': associatedTemplate?.toJson(),
    };
    final jsonStr = const JsonEncoder.withIndent('  ').convert(payload);
    return await file.writeAsString(jsonStr);
  }

  /// Export complete notebook data as a standalone JSON backup file
  Future<File> exportJsonBackup(NotebookModel notebook) async {
    return exportNotebookToJson(notebook);
  }

  /// Export complete notebook to JSON file
  Future<File> exportNotebookToJson(NotebookModel notebook) async {
    final file = await _createExportFile('PlanWiz_Notebook', notebook.title);
    final payload = {
      'exportType': 'notebook',
      'appVersion': '1.0',
      'exportedAt': DateTime.now().toIso8601String(),
      'notebook': notebook.toJson(),
    };
    final jsonStr = const JsonEncoder.withIndent('  ').convert(payload);
    return await file.writeAsString(jsonStr);
  }

  /// Export AI Vision Layout result to JSON file
  Future<File> exportAiLayoutToJson(AILayoutResult layoutResult) async {
    final file = await _createExportFile('PlanWiz_AILayout', layoutResult.title);
    final payload = {
      'exportType': 'ai_layout',
      'appVersion': '1.0',
      'exportedAt': DateTime.now().toIso8601String(),
      'aiLayout': layoutResult.toJson(),
    };
    final jsonStr = const JsonEncoder.withIndent('  ').convert(payload);
    return await file.writeAsString(jsonStr);
  }

  /// Export combined bundle containing multiple notebooks, templates, and pages
  Future<File> exportCombinedBundleToJson({
    List<NotebookModel>? notebooks,
    List<JournalTemplate>? templates,
    List<NotebookPageModel>? pages,
    String bundleTitle = 'Combined_Bundle',
  }) async {
    final file = await _createExportFile('PlanWiz_Bundle', bundleTitle);
    final payload = {
      'exportType': 'combined_bundle',
      'appVersion': '1.0',
      'exportedAt': DateTime.now().toIso8601String(),
      'notebooks': notebooks?.map((n) => n.toJson()).toList() ?? [],
      'templates': templates?.map((t) => t.toJson()).toList() ?? [],
      'pages': pages?.map((p) => p.toJson()).toList() ?? [],
    };
    final jsonStr = const JsonEncoder.withIndent('  ').convert(payload);
    return await file.writeAsString(jsonStr);
  }

  /// Parse and import JSON package string into appropriate domain objects
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
          } catch (_) {}
        }
        if (loadedNotebooks.isNotEmpty) {
          return ImportResult(
            type: PackageType.combinedBundle,
            notebooks: loadedNotebooks,
            message: 'تعداد ${loadedNotebooks.length} دفترچه از فایل پشتیبان بازیابی شد.',
          );
        }
      }

      // 2. Map Payload Format
      if (decoded is Map<String, dynamic>) {
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
            } catch (_) {}
          }
          return ImportResult(
            type: PackageType.page,
            page: page,
            template: associatedTmpl,
            message: 'برگه «${page.title}» با موفقیت وارد شد.',
          );
        }

        // Notebook package
        if (exportType == 'notebook' || decoded.containsKey('notebook')) {
          final nMap = decoded['notebook'] as Map<String, dynamic>? ?? decoded;
          final notebook = NotebookModel.fromJson(nMap);
          return ImportResult(
            type: PackageType.notebook,
            notebook: notebook,
            message: 'دفترچه «${notebook.title}» با ${notebook.pages.length} برگه بازیابی شد.',
          );
        }

        // AI Layout package
        if (exportType == 'ai_layout' || decoded.containsKey('aiLayout')) {
          final lMap = decoded['aiLayout'] as Map<String, dynamic>? ?? decoded;
          final aiLayout = AILayoutResult.fromJson(lMap);
          return ImportResult(
            type: PackageType.aiLayout,
            aiLayout: aiLayout,
            message: 'چیدمان هوشمند «${aiLayout.title}» با ${aiLayout.detectedBoxes.length} کادر بازیابی شد.',
          );
        }

        // Combined Bundle package
        if (exportType == 'combined_bundle' || decoded.containsKey('notebooks') || decoded.containsKey('templates')) {
          final loadedNotebooks = (decoded['notebooks'] as List? ?? [])
              .map((n) => NotebookModel.fromJson(n as Map<String, dynamic>))
              .toList();
          final loadedTemplates = (decoded['templates'] as List? ?? [])
              .map((t) => JournalTemplate.fromJson(t as Map<String, dynamic>))
              .toList();
          final loadedPages = (decoded['pages'] as List? ?? [])
              .map((p) => NotebookPageModel.fromJson(p as Map<String, dynamic>))
              .toList();

          return ImportResult(
            type: PackageType.combinedBundle,
            notebooks: loadedNotebooks,
            templates: loadedTemplates,
            pages: loadedPages,
            message: 'بسته ترکیبی شامل ${loadedNotebooks.length} دفترچه و ${loadedTemplates.length} قالب بازیابی شد.',
          );
        }

        // Fallback: try parsing as notebook or template directly
        try {
          if (decoded.containsKey('pages') && decoded.containsKey('title')) {
            final notebook = NotebookModel.fromJson(decoded);
            return ImportResult(
              type: PackageType.notebook,
              notebook: notebook,
              message: 'دفترچه «${notebook.title}» بازیابی شد.',
            );
          }
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('Error parsing JSON package: $e');
      return ImportResult.error('فرمت ساختار فایل JSON معتبر نمی‌باشد: $e');
    }

    return ImportResult.error('ساختار داده‌ای شناخته‌شده برای وارد کردن پیدا نشد.');
  }

  /// Format notebook into clean Persian/English Markdown text for sharing or clipboard
  String formatNotebookAsText(NotebookModel notebook) {
    final dateFormat = DateFormat('yyyy/MM/dd HH:mm');
    final buffer = StringBuffer();
    buffer.writeln('# 📓 ${notebook.title}');
    buffer.writeln('📅 تاریخ ویرایش: ${dateFormat.format(notebook.updatedAt)}');
    if (notebook.folderName != null && notebook.folderName!.isNotEmpty) {
      buffer.writeln('📁 پوشه: ${notebook.folderName}');
    }
    buffer.writeln('📄 تعداد برگه‌ها: ${notebook.pages.length}');
    buffer.writeln('\n---');

    for (int i = 0; i < notebook.pages.length; i++) {
      final page = notebook.pages[i];
      buffer.writeln('\n## برگه ${i + 1}: ${page.title}');
      if (page.scheduledDate != null) {
        buffer.writeln('⏰ تاریخ زمان‌بندی: ${dateFormat.format(page.scheduledDate!)}');
      }
      if (page.noteTitle.isNotEmpty) {
        buffer.writeln('### ${page.noteTitle}');
      }
      if (page.noteBody.isNotEmpty) {
        buffer.writeln(page.noteBody);
      }
      if (page.cueText.isNotEmpty) {
        buffer.writeln('📌 نکات کلیدی (Cues): ${page.cueText}');
      }
      if (page.summaryText.isNotEmpty) {
        buffer.writeln('📝 خلاصه (Summary): ${page.summaryText}');
      }
      if (page.textBoxes.isNotEmpty) {
        buffer.writeln('✍️ یادداشت‌های تکست‌باکس:');
        for (final box in page.textBoxes) {
          buffer.writeln('- ${box.text}');
        }
      }
      buffer.writeln('\n---');
    }

    buffer.writeln('\nایجاد شده با اپلیکیشن PlanWiz ✨');
    return buffer.toString();
  }

  /// Generate a clean printable HTML document for Save PDF / Print
  Future<File> exportHtmlPrintableDocument(NotebookModel notebook) async {
    final dir = await getApplicationDocumentsDirectory();
    final safeTitle = notebook.title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final file = File('${dir.path}/PlanWiz_Print_${safeTitle}_${DateTime.now().millisecondsSinceEpoch}.html');

    final dateFormat = DateFormat('yyyy/MM/dd HH:mm');
    final buffer = StringBuffer();
    buffer.writeln('''<!DOCTYPE html>
<html lang="fa" dir="rtl">
<head>
  <meta charset="UTF-8">
  <title>${notebook.title} - PlanWiz</title>
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
      <h1 class="title">${notebook.title}</h1>
      <div class="meta">
        <span>تاریخ: ${dateFormat.format(notebook.updatedAt)}</span> | 
        <span class="badge">${notebook.pages.length} برگه</span>
      </div>
    </div>
''');

    for (int i = 0; i < notebook.pages.length; i++) {
      final page = notebook.pages[i];
      buffer.writeln('''
    <div class="page-box">
      <div class="page-title">برگه ${i + 1}: ${page.title}</div>
''');
      if (page.noteTitle.isNotEmpty) {
        buffer.writeln('      <h3>${page.noteTitle}</h3>');
      }
      if (page.noteBody.isNotEmpty) {
        buffer.writeln('      <div class="note-content">${page.noteBody}</div>');
      }
      if (page.textBoxes.isNotEmpty) {
        buffer.writeln('      <h4>یادداشت‌های اضافی:</h4><ul>');
        for (final b in page.textBoxes) {
          buffer.writeln('        <li>${b.text}</li>');
        }
        buffer.writeln('      </ul>');
      }
      buffer.writeln('    </div>');
    }

    buffer.writeln('''
  </div>
</body>
</html>''');

    return await file.writeAsString(buffer.toString());
  }
}
