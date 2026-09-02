import 'package:flutter/material.dart';

class DrawingPoint {
  final double x;
  final double y;

  const DrawingPoint(this.x, this.y);

  Offset toOffset() => Offset(x, y);

  Map<String, dynamic> toJson() => {'x': x, 'y': y};

  factory DrawingPoint.fromJson(Map<String, dynamic> json) => DrawingPoint(
        (json['x'] as num).toDouble(),
        (json['y'] as num).toDouble(),
      );

  factory DrawingPoint.fromOffset(Offset offset) =>
      DrawingPoint(offset.dx, offset.dy);
}

class DrawingStroke {
  final String id;
  final List<DrawingPoint> points;
  final Color color;
  final double strokeWidth;
  final bool isHighlighter;

  DrawingStroke({
    required this.id,
    required this.points,
    required this.color,
    this.strokeWidth = 3.0,
    this.isHighlighter = false,
  });

  DrawingStroke copyWith({
    String? id,
    List<DrawingPoint>? points,
    Color? color,
    double? strokeWidth,
    bool? isHighlighter,
  }) {
    return DrawingStroke(
      id: id ?? this.id,
      points: points ?? List.from(this.points),
      color: color ?? this.color,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      isHighlighter: isHighlighter ?? this.isHighlighter,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'points': points.map((p) => p.toJson()).toList(),
        'color': color.toARGB32(),
        'strokeWidth': strokeWidth,
        'isHighlighter': isHighlighter,
      };

  factory DrawingStroke.fromJson(Map<String, dynamic> json) => DrawingStroke(
        id: json['id'] as String? ?? 'stroke_${DateTime.now().millisecondsSinceEpoch}',
        points: (json['points'] as List?)
                ?.map((p) => DrawingPoint.fromJson(p as Map<String, dynamic>))
                .toList() ??
            [],
        color: Color(json['color'] as int? ?? 0xFF1E2024),
        strokeWidth: (json['strokeWidth'] as num?)?.toDouble() ?? 3.0,
        isHighlighter: json['isHighlighter'] as bool? ?? false,
      );
}
