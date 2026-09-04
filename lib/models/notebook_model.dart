import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'page_style_model.dart';
import 'template_model.dart';
import 'text_box_model.dart';
import 'sticker_model.dart';
import 'check_item_model.dart';
import 'drawing_stroke_model.dart';

class NotebookPageModel {
  final String id;
  String title;
  PageStyleConfig pageStyle;
  String? templateId;
  String noteTitle;
  String noteBody;
  String cueText;
  String summaryText;
  List<TextBoxItem> textBoxes;
  List<StickerItem> stickers;
  List<InteractiveCheckItem> checkItems;
  List<DrawingStroke> drawingStrokes;
  DateTime? scheduledDate;
  DateTime createdAt;
  DateTime updatedAt;

  NotebookPageModel({
    required this.id,
    this.title = 'برگه یادداشت',
    PageStyleConfig? pageStyle,
    this.templateId,
    this.noteTitle = '',
    this.noteBody = '',
    this.cueText = '',
    this.summaryText = '',
    List<TextBoxItem>? textBoxes,
    List<StickerItem>? stickers,
    List<InteractiveCheckItem>? checkItems,
    List<DrawingStroke>? drawingStrokes,
    this.scheduledDate,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : pageStyle = pageStyle ?? PageStyleConfig(),
        textBoxes = textBoxes ?? [],
        stickers = stickers ?? [],
        checkItems = checkItems ?? [],
        drawingStrokes = drawingStrokes ?? [],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  JournalTemplate? get template {
    if (templateId == null) return null;
    return JournalTemplate.findTemplateById(templateId);
  }

  set template(JournalTemplate? tmpl) {
    templateId = tmpl?.id;
  }

  void applyTemplate(JournalTemplate tmpl) {
    templateId = tmpl.id;
    title = tmpl.title.split('(').first.trim();
    // Reset all previous settings so the template is rendered with its original dimensions
    pageStyle = PageStyleConfig(
      pageType: PageType.blank,
      backgroundColor: Colors.white,
    );
    noteTitle = '';
    noteBody = '';
    cueText = '';
    summaryText = '';
    updatedAt = DateTime.now();
  }

  void applyPageStyle(PageStyleConfig newStyle) {
    pageStyle = newStyle;
    templateId = null;
    updatedAt = DateTime.now();
  }

  NotebookPageModel copyWith({
    String? id,
    String? title,
    PageStyleConfig? pageStyle,
    String? templateId,
    String? noteTitle,
    String? noteBody,
    String? cueText,
    String? summaryText,
    List<TextBoxItem>? textBoxes,
    List<StickerItem>? stickers,
    List<InteractiveCheckItem>? checkItems,
    List<DrawingStroke>? drawingStrokes,
    DateTime? scheduledDate,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return NotebookPageModel(
      id: id ?? this.id,
      title: title ?? this.title,
      pageStyle: pageStyle ?? this.pageStyle,
      templateId: templateId ?? this.templateId,
      noteTitle: noteTitle ?? this.noteTitle,
      noteBody: noteBody ?? this.noteBody,
      cueText: cueText ?? this.cueText,
      summaryText: summaryText ?? this.summaryText,
      textBoxes: textBoxes != null
          ? List.from(textBoxes)
          : this.textBoxes.map((e) => e.copyWith()).toList(),
      stickers: stickers != null
          ? List.from(stickers)
          : this.stickers.map((e) => e.copyWith()).toList(),
      checkItems: checkItems != null
          ? List.from(checkItems)
          : this.checkItems.map((e) => e.copyWith()).toList(),
      drawingStrokes: drawingStrokes != null
          ? List.from(drawingStrokes)
          : this.drawingStrokes.map((e) => e.copyWith()).toList(),
      scheduledDate: scheduledDate ?? this.scheduledDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'pageStyle': pageStyle.toJson(),
        'templateId': templateId,
        'noteTitle': noteTitle,
        'noteBody': noteBody,
        'cueText': cueText,
        'summaryText': summaryText,
        'textBoxes': textBoxes.map((e) => e.toJson()).toList(),
        'stickers': stickers.map((e) => e.toJson()).toList(),
        'checkItems': checkItems.map((e) => e.toJson()).toList(),
        'drawingStrokes': drawingStrokes.map((e) => e.toJson()).toList(),
        'scheduledDate': scheduledDate?.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory NotebookPageModel.fromJson(Map<String, dynamic> json) {
    List<TextBoxItem> loadedBoxes = [];
    if (json['textBoxes'] != null && json['textBoxes'] is List) {
      for (final item in json['textBoxes']) {
        try {
          loadedBoxes.add(TextBoxItem.fromJson(item as Map<String, dynamic>));
        } catch (_) {}
      }
    }

    List<StickerItem> loadedStickers = [];
    if (json['stickers'] != null && json['stickers'] is List) {
      for (final item in json['stickers']) {
        try {
          loadedStickers.add(StickerItem.fromJson(item as Map<String, dynamic>));
        } catch (_) {}
      }
    }

    List<InteractiveCheckItem> loadedChecks = [];
    if (json['checkItems'] != null && json['checkItems'] is List) {
      for (final item in json['checkItems']) {
        try {
          loadedChecks.add(InteractiveCheckItem.fromJson(item as Map<String, dynamic>));
        } catch (_) {}
      }
    }

    List<DrawingStroke> loadedStrokes = [];
    if (json['drawingStrokes'] != null && json['drawingStrokes'] is List) {
      for (final item in json['drawingStrokes']) {
        try {
          loadedStrokes.add(DrawingStroke.fromJson(item as Map<String, dynamic>));
        } catch (_) {}
      }
    }

    return NotebookPageModel(
      id: json['id'] as String? ?? 'p_${const Uuid().v4()}',
      title: json['title'] as String? ?? 'برگه یادداشت',
      pageStyle: json['pageStyle'] != null
          ? PageStyleConfig.fromJson(json['pageStyle'] as Map<String, dynamic>)
          : PageStyleConfig(),
      templateId: json['templateId'] as String?,
      noteTitle: json['noteTitle'] as String? ?? '',
      noteBody: json['noteBody'] as String? ?? '',
      cueText: json['cueText'] as String? ?? '',
      summaryText: json['summaryText'] as String? ?? '',
      textBoxes: loadedBoxes,
      stickers: loadedStickers,
      checkItems: loadedChecks,
      drawingStrokes: loadedStrokes,
      scheduledDate: json['scheduledDate'] != null
          ? DateTime.tryParse(json['scheduledDate'] as String)
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  factory NotebookPageModel.fromJournalContent({
    required String id,
    required String title,
    required String content,
    String? templateId,
    PageStyleConfig? defaultPageStyle,
  }) {
    PageStyleConfig? pageStyle = defaultPageStyle;
    String noteTitle = title;
    String noteBody = '';
    String cueText = '';
    String summaryText = '';
    List<TextBoxItem> textBoxes = [];
    List<StickerItem> stickers = [];
    List<InteractiveCheckItem> checkItems = [];
    List<DrawingStroke> drawingStrokes = [];

    if (content.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(content);
        if (decoded is Map<String, dynamic>) {
          if (decoded.containsKey('templateId') && (decoded['templateId'] as String?)?.isNotEmpty == true) {
            templateId = decoded['templateId'] as String;
          }
          if (decoded.containsKey('pageStyle') && decoded['pageStyle'] != null) {
            pageStyle = PageStyleConfig.fromJson(decoded['pageStyle'] as Map<String, dynamic>);
          }
          if (decoded.containsKey('noteTitle')) {
            noteTitle = decoded['noteTitle'] as String? ?? title;
          }
          if (decoded.containsKey('noteBody')) {
            noteBody = decoded['noteBody'] as String? ?? '';
          }
          if (decoded.containsKey('cueText')) {
            cueText = decoded['cueText'] as String? ?? '';
          }
          if (decoded.containsKey('summaryText')) {
            summaryText = decoded['summaryText'] as String? ?? '';
          }
          if (decoded.containsKey('textBoxes') && decoded['textBoxes'] is List) {
            for (final item in decoded['textBoxes']) {
              try {
                textBoxes.add(TextBoxItem.fromJson(item as Map<String, dynamic>));
              } catch (_) {}
            }
          }
          if (decoded.containsKey('stickers') && decoded['stickers'] is List) {
            for (final item in decoded['stickers']) {
              try {
                stickers.add(StickerItem.fromJson(item as Map<String, dynamic>));
              } catch (_) {}
            }
          }
          if (decoded.containsKey('checkItems') && decoded['checkItems'] is List) {
            for (final item in decoded['checkItems']) {
              try {
                checkItems.add(InteractiveCheckItem.fromJson(item as Map<String, dynamic>));
              } catch (_) {}
            }
          }
          if (decoded.containsKey('drawingStrokes') && decoded['drawingStrokes'] is List) {
            for (final item in decoded['drawingStrokes']) {
              try {
                drawingStrokes.add(DrawingStroke.fromJson(item as Map<String, dynamic>));
              } catch (_) {}
            }
          }
        } else if (decoded is List) {
          for (final item in decoded) {
            try {
              textBoxes.add(TextBoxItem.fromJson(item as Map<String, dynamic>));
            } catch (_) {}
          }
        }
      } catch (_) {
        // Plain text fallback
        noteBody = content;
      }
    }

    return NotebookPageModel(
      id: id,
      title: noteTitle.isNotEmpty ? noteTitle : title,
      templateId: templateId,
      pageStyle: pageStyle ?? PageStyleConfig(),
      noteTitle: noteTitle,
      noteBody: noteBody,
      cueText: cueText,
      summaryText: summaryText,
      textBoxes: textBoxes,
      stickers: stickers,
      checkItems: checkItems,
      drawingStrokes: drawingStrokes,
    );
  }
}

class NotebookModel {
  final String id;
  String title;
  Color coverColor;
  String? coverImagePath;
  String? folderName;
  List<NotebookPageModel> pages;
  DateTime createdAt;
  DateTime updatedAt;
  bool isFavorite;

  NotebookModel({
    required this.id,
    required this.title,
    this.coverColor = const Color(0xFFE07A5F), // Terracotta default
    this.coverImagePath,
    this.folderName,
    List<NotebookPageModel>? pages,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.isFavorite = false,
  })  : pages = pages ?? [],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  int get pageCount => pages.length;

  NotebookModel copyWith({
    String? id,
    String? title,
    Color? coverColor,
    String? coverImagePath,
    String? folderName,
    List<NotebookPageModel>? pages,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isFavorite,
  }) {
    return NotebookModel(
      id: id ?? this.id,
      title: title ?? this.title,
      coverColor: coverColor ?? this.coverColor,
      coverImagePath: coverImagePath ?? this.coverImagePath,
      folderName: folderName ?? this.folderName,
      pages: pages != null
          ? List.from(pages)
          : this.pages.map((p) => p.copyWith()).toList(),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'coverColor': coverColor.toARGB32(),
        'coverImagePath': coverImagePath,
        'folderName': folderName,
        'pages': pages.map((p) => p.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'isFavorite': isFavorite,
      };

  factory NotebookModel.fromJson(Map<String, dynamic> json) {
    List<NotebookPageModel> loadedPages = [];
    if (json['pages'] != null && json['pages'] is List) {
      for (final p in json['pages']) {
        try {
          loadedPages.add(NotebookPageModel.fromJson(p as Map<String, dynamic>));
        } catch (_) {}
      }
    }

    return NotebookModel(
      id: json['id'] as String? ?? 'nb_${const Uuid().v4()}',
      title: json['title'] as String? ?? 'دفترچه جدید',
      coverColor: Color(json['coverColor'] as int? ?? 0xFFE07A5F),
      coverImagePath: json['coverImagePath'] as String?,
      folderName: json['folderName'] as String?,
      pages: loadedPages,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      isFavorite: json['isFavorite'] as bool? ?? false,
    );
  }

  static List<NotebookModel> sampleNotebooks = [
    NotebookModel(
      id: 'nb_1',
      title: 'notebook 22',
      coverColor: const Color(0xFFE07A5F), // Matches Image 1 terracotta
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
      pages: [
        NotebookPageModel(
          id: 'p_1_1',
          title: 'برگه سفید اول',
          pageStyle: PageStyleConfig(pageType: PageType.blank),
          noteTitle: 'شروع یادداشت‌ها',
          noteBody: 'به دفترچه جدید خود خوش آمدید. برای ورق زدن، صفحه را به چپ و راست بکشید.',
        ),
        NotebookPageModel(
          id: 'p_1_2',
          title: 'Daily Planner',
          templateId: 't1', // Daily Planner matching Image 2
          noteTitle: 'برنامه امروز من',
          noteBody: 'افکار صبحگاهی و هماهنگی کارهای روزانه',
        ),
        NotebookPageModel(
          id: 'p_1_3',
          title: 'برگه خط‌دار یادداشت‌ها',
          pageStyle: PageStyleConfig(pageType: PageType.lined),
          noteTitle: 'نکات مهم جلسه',
          noteBody: 'لیست وظایف و بررسی پیشرفت تسک‌های این هفته.',
        ),
      ],
      isFavorite: true,
    ),
    NotebookModel(
      id: 'nb_2',
      title: 'Untitled 2',
      coverColor: const Color(0xFF81C784),
      createdAt: DateTime.now().subtract(const Duration(days: 4)),
      pages: [
        NotebookPageModel(
          id: 'p_2_1',
          title: 'صفحه اول',
          pageStyle: PageStyleConfig(pageType: PageType.blank),
        ),
        NotebookPageModel(
          id: 'p_2_2',
          title: 'Daily Planner',
          templateId: 't1',
        ),
        NotebookPageModel(
          id: 'p_2_3',
          title: 'صفحه سوم',
          pageStyle: PageStyleConfig(pageType: PageType.blank),
        ),
      ],
      isFavorite: false,
    ),
    NotebookModel(
      id: 'nb_3',
      title: 'پلنر تمرکز و عادات',
      coverColor: const Color(0xFF90CAF9),
      createdAt: DateTime.now().subtract(const Duration(days: 7)),
      pages: [
        NotebookPageModel(
          id: 'p_3_1',
          title: 'ADHD Focus Planner',
          templateId: 't2',
        ),
        NotebookPageModel(
          id: 'p_3_2',
          title: 'جدول ردیابی عادات',
          templateId: 't4',
        ),
      ],
      isFavorite: true,
    ),
  ];
}
