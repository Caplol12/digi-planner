import 'package:flutter/material.dart';

class TextBoxItem {
  static int _counter = 0;

  final String id;
  String text;
  String hintText;
  Offset position;
  double width;
  double height;
  double fontSize;
  String fontName;
  Color inkColor;
  TextAlign textAlign;
  bool isBold;
  bool isItalic;
  Color? highlightColor;
  bool isSelected;

  // Normalized coordinates (0.0 to 1.0) relative to sheet/template canvas
  double? normalizedX;
  double? normalizedY;
  double? normalizedWidth;
  double? normalizedHeight;

  TextBoxItem({
    required this.id,
    this.text = '',
    this.hintText = '',
    required this.position,
    this.width = 180,
    this.height = 44,
    this.fontSize = 13,
    this.fontName = 'Vazirmatn',
    this.inkColor = const Color(0xFF1E2024),
    this.textAlign = TextAlign.right,
    this.isBold = false,
    this.isItalic = false,
    this.highlightColor,
    this.isSelected = true,
    this.normalizedX,
    this.normalizedY,
    this.normalizedWidth,
    this.normalizedHeight,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'hintText': hintText,
        'dx': position.dx,
        'dy': position.dy,
        'width': width,
        'height': height,
        'fontSize': fontSize,
        'fontName': fontName,
        'color': inkColor.toARGB32(),
        'textAlign': textAlign.index,
        'isBold': isBold,
        'isItalic': isItalic,
        'highlightColor': highlightColor?.toARGB32(),
        if (normalizedX != null) 'nx': normalizedX,
        if (normalizedY != null) 'ny': normalizedY,
        if (normalizedWidth != null) 'nw': normalizedWidth,
        if (normalizedHeight != null) 'nh': normalizedHeight,
      };

  factory TextBoxItem.fromJson(Map<String, dynamic> json) => TextBoxItem(
        id: (json['id']?.toString().isNotEmpty == true)
            ? json['id'].toString()
            : 'tb_${DateTime.now().millisecondsSinceEpoch}_${++_counter}',
        text: json['text'] ?? '',
        hintText: json['hintText'] ?? '',
        position: Offset(json['dx']?.toDouble() ?? 50.0, json['dy']?.toDouble() ?? 50.0),
        width: json['width']?.toDouble() ?? 180.0,
        height: json['height']?.toDouble() ?? 44.0,
        fontSize: json['fontSize']?.toDouble() ?? 13.0,
        fontName: json['fontName'] ?? 'Vazirmatn',
        inkColor: Color(json['color'] ?? 0xFF1E2024),
        textAlign: json['textAlign'] != null ? TextAlign.values[json['textAlign']] : TextAlign.right,
        isBold: json['isBold'] ?? false,
        isItalic: json['isItalic'] ?? false,
        highlightColor: json['highlightColor'] != null ? Color(json['highlightColor']) : null,
        normalizedX: (json['nx'] as num?)?.toDouble() ?? (json['normalizedX'] as num?)?.toDouble(),
        normalizedY: (json['ny'] as num?)?.toDouble() ?? (json['normalizedY'] as num?)?.toDouble(),
        normalizedWidth: (json['nw'] as num?)?.toDouble() ?? (json['normalizedWidth'] as num?)?.toDouble(),
        normalizedHeight: (json['nh'] as num?)?.toDouble() ?? (json['normalizedHeight'] as num?)?.toDouble(),
      );

  TextBoxItem copyWith({
    String? id,
    String? text,
    String? hintText,
    Offset? position,
    double? width,
    double? height,
    double? fontSize,
    String? fontName,
    Color? inkColor,
    TextAlign? textAlign,
    bool? isBold,
    bool? isItalic,
    Color? highlightColor,
    bool? isSelected,
    double? normalizedX,
    double? normalizedY,
    double? normalizedWidth,
    double? normalizedHeight,
  }) {
    return TextBoxItem(
      id: id ?? this.id,
      text: text ?? this.text,
      hintText: hintText ?? this.hintText,
      position: position ?? this.position,
      width: width ?? this.width,
      height: height ?? this.height,
      fontSize: fontSize ?? this.fontSize,
      fontName: fontName ?? this.fontName,
      inkColor: inkColor ?? this.inkColor,
      textAlign: textAlign ?? this.textAlign,
      isBold: isBold ?? this.isBold,
      isItalic: isItalic ?? this.isItalic,
      highlightColor: highlightColor ?? this.highlightColor,
      isSelected: isSelected ?? this.isSelected,
      normalizedX: normalizedX ?? this.normalizedX,
      normalizedY: normalizedY ?? this.normalizedY,
      normalizedWidth: normalizedWidth ?? this.normalizedWidth,
      normalizedHeight: normalizedHeight ?? this.normalizedHeight,
    );
  }
}
