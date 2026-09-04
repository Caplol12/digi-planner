import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../widgets/platform_image_helper.dart';
import 'text_box_model.dart';
import 'check_item_model.dart';

enum DetectedBoxType {
  singleLine, // Header, title, date
  ruledLines, // Writing lines, journal notes
  checklist,  // Task list with checkboxes/bullets
  freeText,   // Blank thoughts, brain dump, scratch
}

class DetectedBox {
  final String id;
  String label;
  DetectedBoxType type;
  double normalizedX;      // 0.0 to 1.0
  double normalizedY;      // 0.0 to 1.0
  double normalizedWidth;  // 0.0 to 1.0
  double normalizedHeight; // 0.0 to 1.0
  int estimatedLines;
  double lineHeightMultiplier;
  String placeholderText;
  bool autoShrink;
  bool preventOverflow;
  double fontSize;
  String fontName;
  Color inkColor;
  TextAlign textAlign;
  bool isBold;
  bool isSelected;

  DetectedBox({
    required this.id,
    required this.label,
    required this.type,
    required this.normalizedX,
    required this.normalizedY,
    required this.normalizedWidth,
    required this.normalizedHeight,
    this.estimatedLines = 1,
    this.lineHeightMultiplier = 1.4,
    this.placeholderText = '',
    this.autoShrink = true,
    this.preventOverflow = true,
    this.fontSize = 13.0,
    this.fontName = 'Vazirmatn',
    this.inkColor = const Color(0xFF1E2024),
    this.textAlign = TextAlign.right,
    this.isBold = false,
    this.isSelected = false,
  });

  Color get badgeColor {
    switch (type) {
      case DetectedBoxType.singleLine:
        return const Color(0xFF1976D2); // Blue
      case DetectedBoxType.ruledLines:
        return const Color(0xFF2E7D32); // Green
      case DetectedBoxType.checklist:
        return const Color(0xFFFF6F00); // Amber/Orange
      case DetectedBoxType.freeText:
        return const Color(0xFF7B1FA2); // Purple
    }
  }

  String get typeTitlePersian {
    switch (type) {
      case DetectedBoxType.singleLine:
        return 'تک‌خطی (عنوان/تاریخ)';
      case DetectedBoxType.ruledLines:
        return 'خطوط یادداشت';
      case DetectedBoxType.checklist:
        return 'چک‌لیست کارها';
      case DetectedBoxType.freeText:
        return 'یادداشت آزاد';
    }
  }

  TextBoxItem toTextBoxItem(Size canvasSize) {
    final dx = normalizedX * canvasSize.width;
    final dy = normalizedY * canvasSize.height;
    final width = (normalizedWidth * canvasSize.width).clamp(30.0, canvasSize.width);
    final height = (normalizedHeight * canvasSize.height).clamp(20.0, canvasSize.height);

    final hint = placeholderText.isNotEmpty
        ? placeholderText
        : (label.isNotEmpty ? label : 'برای نوشتن در این بخش کلیک کنید...');

    return TextBoxItem(
      id: id,
      text: '', // Blank so the user can immediately type without clearing dummy text
      hintText: hint,
      position: Offset(dx, dy),
      width: width,
      height: height,
      fontSize: fontSize,
      fontName: fontName,
      inkColor: inkColor,
      textAlign: textAlign,
      isBold: isBold,
      isSelected: false,
      normalizedX: normalizedX,
      normalizedY: normalizedY,
      normalizedWidth: normalizedWidth,
      normalizedHeight: normalizedHeight,
    );
  }

  static TextAlign _parseTextAlign(dynamic val) {
    if (val is String) {
      try {
        return TextAlign.values.byName(val);
      } catch (_) {}
    } else if (val is int && val >= 0 && val < TextAlign.values.length) {
      return TextAlign.values[val];
    }
    return TextAlign.right;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'type': type.name,
        'normalizedX': normalizedX,
        'normalizedY': normalizedY,
        'normalizedWidth': normalizedWidth,
        'normalizedHeight': normalizedHeight,
        'estimatedLines': estimatedLines,
        'lineHeightMultiplier': lineHeightMultiplier,
        'placeholderText': placeholderText,
        'autoShrink': autoShrink,
        'preventOverflow': preventOverflow,
        'fontSize': fontSize,
        'fontName': fontName,
        'inkColor': inkColor.toARGB32(),
        'textAlign': textAlign.name,
        'isBold': isBold,
      };

  factory DetectedBox.fromJson(Map<String, dynamic> json) {
    final typeName = json['type'] as String? ?? 'freeText';
    final type = DetectedBoxType.values.firstWhere(
      (t) => t.name == typeName,
      orElse: () => DetectedBoxType.freeText,
    );

    final rawId = json['id']?.toString().trim();
    final effectiveId = (rawId != null && rawId.isNotEmpty)
        ? rawId
        : 'box_${const Uuid().v4()}';

    return DetectedBox(
      id: effectiveId,
      label: json['label'] as String? ?? 'باکس متن',
      type: type,
      normalizedX: (json['normalizedX'] as num?)?.toDouble() ?? 0.1,
      normalizedY: (json['normalizedY'] as num?)?.toDouble() ?? 0.1,
      normalizedWidth: (json['normalizedWidth'] as num?)?.toDouble() ?? 0.8,
      normalizedHeight: (json['normalizedHeight'] as num?)?.toDouble() ?? 0.15,
      estimatedLines: (json['estimatedLines'] as num?)?.toInt() ?? 1,
      lineHeightMultiplier: (json['lineHeightMultiplier'] as num?)?.toDouble() ?? 1.4,
      placeholderText: json['placeholderText'] as String? ?? '',
      autoShrink: json['autoShrink'] as bool? ?? true,
      preventOverflow: json['preventOverflow'] as bool? ?? true,
      fontSize: (json['fontSize'] as num?)?.toDouble() ?? 13.0,
      fontName: json['fontName'] as String? ?? 'Vazirmatn',
      inkColor: Color((json['inkColor'] as int?) ?? 0xFF1E2024),
      textAlign: _parseTextAlign(json['textAlign']),
      isBold: json['isBold'] as bool? ?? false,
    );
  }

  DetectedBox copyWith({
    String? id,
    String? label,
    DetectedBoxType? type,
    double? normalizedX,
    double? normalizedY,
    double? normalizedWidth,
    double? normalizedHeight,
    int? estimatedLines,
    double? lineHeightMultiplier,
    String? placeholderText,
    bool? autoShrink,
    bool? preventOverflow,
    double? fontSize,
    String? fontName,
    Color? inkColor,
    TextAlign? textAlign,
    bool? isBold,
    bool? isSelected,
  }) {
    return DetectedBox(
      id: id ?? this.id,
      label: label ?? this.label,
      type: type ?? this.type,
      normalizedX: normalizedX ?? this.normalizedX,
      normalizedY: normalizedY ?? this.normalizedY,
      normalizedWidth: normalizedWidth ?? this.normalizedWidth,
      normalizedHeight: normalizedHeight ?? this.normalizedHeight,
      estimatedLines: estimatedLines ?? this.estimatedLines,
      lineHeightMultiplier: lineHeightMultiplier ?? this.lineHeightMultiplier,
      placeholderText: placeholderText ?? this.placeholderText,
      autoShrink: autoShrink ?? this.autoShrink,
      preventOverflow: preventOverflow ?? this.preventOverflow,
      fontSize: fontSize ?? this.fontSize,
      fontName: fontName ?? this.fontName,
      inkColor: inkColor ?? this.inkColor,
      textAlign: textAlign ?? this.textAlign,
      isBold: isBold ?? this.isBold,
      isSelected: isSelected ?? this.isSelected,
    );
  }
}

class AILayoutResult {
  final String imagePath;
  final Uint8List? imageBytes;
  final double aspectRatio;
  final String title;
  final List<DetectedBox> detectedBoxes;
  final List<InteractiveCheckItem> checkpoints;
  final String analysisEngine;
  final DateTime detectedAt;

  AILayoutResult({
    required this.imagePath,
    this.imageBytes,
    this.aspectRatio = 2 / 3,
    required this.title,
    required this.detectedBoxes,
    this.checkpoints = const [],
    this.analysisEngine = 'AI Vision Engine',
    DateTime? detectedAt,
  }) : detectedAt = detectedAt ?? DateTime.now();

  Map<String, dynamic> toJson() {
    String? b64;
    if (imageBytes != null && imageBytes!.isNotEmpty) {
      final safeBytes = compressImageBytes(imageBytes!, maxDimension: 1024, quality: 75);
      b64 = base64Encode(safeBytes);
    }
    return {
      'imagePath': imagePath,
      if (b64 != null) 'imageBytesBase64': b64,
      'aspectRatio': aspectRatio,
      'title': title,
      'detectedBoxes': detectedBoxes.map((b) => b.toJson()).toList(),
      'checkpoints': checkpoints.map((c) => c.toJson()).toList(),
      'analysisEngine': analysisEngine,
      'detectedAt': detectedAt.toIso8601String(),
    };
  }

  factory AILayoutResult.fromJson(Map<String, dynamic> json) {
    final boxesJson = json['detectedBoxes'] as List? ?? [];
    final checkpointsJson = (json['checkpoints'] ?? json['checkItems'] ?? json['ticks']) as List? ?? [];

    Uint8List? bytes;
    if (json['imageBytesBase64'] != null && (json['imageBytesBase64'] as String).isNotEmpty) {
      try {
        bytes = base64Decode(json['imageBytesBase64'] as String);
      } catch (_) {}
    }

    return AILayoutResult(
      imagePath: json['imagePath'] as String? ?? '',
      imageBytes: bytes,
      aspectRatio: (json['aspectRatio'] as num?)?.toDouble() ?? 2 / 3,
      title: json['title'] as String? ?? 'قالب هوشمند',
      detectedBoxes: boxesJson.map((b) => DetectedBox.fromJson(b as Map<String, dynamic>)).toList(),
      checkpoints: checkpointsJson.map((c) => InteractiveCheckItem.fromJson(c as Map<String, dynamic>)).toList(),
      analysisEngine: json['analysisEngine'] as String? ?? 'AI Vision Engine',
      detectedAt: json['detectedAt'] != null ? DateTime.parse(json['detectedAt']) : DateTime.now(),
    );
  }
}
