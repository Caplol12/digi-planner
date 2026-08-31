import 'package:flutter/material.dart';

class TextBoxItem {
  final String id;
  String text;
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

  TextBoxItem({
    required this.id,
    this.text = '',
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
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
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
      };

  factory TextBoxItem.fromJson(Map<String, dynamic> json) => TextBoxItem(
        id: json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
        text: json['text'] ?? '',
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
      );

  TextBoxItem copyWith({
    String? id,
    String? text,
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
  }) {
    return TextBoxItem(
      id: id ?? this.id,
      text: text ?? this.text,
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
    );
  }
}

