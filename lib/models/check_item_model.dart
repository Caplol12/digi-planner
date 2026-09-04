import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

enum CheckboxShape {
  square, // Task checklist ☐
  circle, // Habit tracker dot ◯
  water,  // Water glass tracker 💧
  star,   // Priority star ⭐
  heart,  // Mood / gratitude tracker ❤️
}

enum CheckboxStyle {
  checkmark, // Green/Dark check mark ✓
  filled,    // Solid colored fill ●
  cross,     // Cross mark ✕
}

class InteractiveCheckItem {
  final String id;
  String label;
  double normalizedX;      // 0.0 to 1.0
  double normalizedY;      // 0.0 to 1.0
  double normalizedWidth;  // 0.0 to 1.0 (approx 0.04 to 0.08)
  double normalizedHeight; // 0.0 to 1.0 (approx 0.03 to 0.06)
  bool isChecked;
  CheckboxShape shape;
  CheckboxStyle style;
  Color checkColor;

  InteractiveCheckItem({
    required this.id,
    this.label = '',
    required this.normalizedX,
    required this.normalizedY,
    this.normalizedWidth = 0.05,
    this.normalizedHeight = 0.04,
    this.isChecked = false,
    this.shape = CheckboxShape.square,
    this.style = CheckboxStyle.checkmark,
    this.checkColor = const Color(0xFF2E7D32),
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'normalizedX': normalizedX,
        'normalizedY': normalizedY,
        'normalizedWidth': normalizedWidth,
        'normalizedHeight': normalizedHeight,
        'isChecked': isChecked,
        'shape': shape.name,
        'style': style.name,
        'checkColor': checkColor.toARGB32(),
      };

  factory InteractiveCheckItem.fromJson(Map<String, dynamic> json) {
    final shapeName = json['shape'] as String? ?? 'square';
    final shape = CheckboxShape.values.firstWhere(
      (s) => s.name == shapeName,
      orElse: () => CheckboxShape.square,
    );

    final styleName = json['style'] as String? ?? 'checkmark';
    final style = CheckboxStyle.values.firstWhere(
      (s) => s.name == styleName,
      orElse: () => CheckboxStyle.checkmark,
    );

    final rawId = json['id']?.toString().trim();
    final effectiveId = (rawId != null && rawId.isNotEmpty)
        ? rawId
        : 'chk_${const Uuid().v4()}';

    return InteractiveCheckItem(
      id: effectiveId,
      label: json['label'] as String? ?? '',
      normalizedX: (json['normalizedX'] as num?)?.toDouble() ?? 0.1,
      normalizedY: (json['normalizedY'] as num?)?.toDouble() ?? 0.1,
      normalizedWidth: (json['normalizedWidth'] as num?)?.toDouble() ?? 0.05,
      normalizedHeight: (json['normalizedHeight'] as num?)?.toDouble() ?? 0.04,
      isChecked: json['isChecked'] as bool? ?? false,
      shape: shape,
      style: style,
      checkColor: Color((json['checkColor'] as int?) ?? 0xFF2E7D32),
    );
  }

  InteractiveCheckItem copyWith({
    String? id,
    String? label,
    double? normalizedX,
    double? normalizedY,
    double? normalizedWidth,
    double? normalizedHeight,
    bool? isChecked,
    CheckboxShape? shape,
    CheckboxStyle? style,
    Color? checkColor,
  }) {
    return InteractiveCheckItem(
      id: id ?? this.id,
      label: label ?? this.label,
      normalizedX: normalizedX ?? this.normalizedX,
      normalizedY: normalizedY ?? this.normalizedY,
      normalizedWidth: normalizedWidth ?? this.normalizedWidth,
      normalizedHeight: normalizedHeight ?? this.normalizedHeight,
      isChecked: isChecked ?? this.isChecked,
      shape: shape ?? this.shape,
      style: style ?? this.style,
      checkColor: checkColor ?? this.checkColor,
    );
  }
}
