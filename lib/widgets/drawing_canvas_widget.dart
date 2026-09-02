import 'package:flutter/material.dart';
import '../models/drawing_stroke_model.dart';

class DrawingPainter extends CustomPainter {
  final List<DrawingStroke> strokes;
  final DrawingStroke? currentStroke;

  const DrawingPainter({
    required this.strokes,
    this.currentStroke,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final stroke in strokes) {
      _drawStroke(canvas, stroke);
    }
    if (currentStroke != null) {
      _drawStroke(canvas, currentStroke!);
    }
  }

  void _drawStroke(Canvas canvas, DrawingStroke stroke) {
    if (stroke.points.isEmpty) return;

    final paint = Paint()
      ..color = stroke.isHighlighter
          ? stroke.color.withValues(alpha: 0.38)
          : stroke.color
      ..strokeWidth = stroke.strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    if (stroke.isHighlighter) {
      paint.blendMode = BlendMode.srcOver;
    }

    if (stroke.points.length == 1) {
      canvas.drawCircle(
        stroke.points.first.toOffset(),
        stroke.strokeWidth / 2,
        Paint()
          ..color = paint.color
          ..style = PaintingStyle.fill,
      );
      return;
    }

    final path = Path();
    path.moveTo(stroke.points.first.x, stroke.points.first.y);

    for (int i = 1; i < stroke.points.length; i++) {
      final p0 = stroke.points[i - 1].toOffset();
      final p1 = stroke.points[i].toOffset();
      final midPoint = Offset((p0.dx + p1.dx) / 2, (p0.dy + p1.dy) / 2);
      path.quadraticBezierTo(p0.dx, p0.dy, midPoint.dx, midPoint.dy);
    }

    path.lineTo(stroke.points.last.x, stroke.points.last.y);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant DrawingPainter oldDelegate) => true;
}

class DrawingCanvasWidget extends StatelessWidget {
  final List<DrawingStroke> strokes;
  final DrawingStroke? currentStroke;
  final bool isDrawingMode;
  final Function(Offset localPos)? onPanStart;
  final Function(Offset localPos)? onPanUpdate;
  final VoidCallback? onPanEnd;

  const DrawingCanvasWidget({
    super.key,
    required this.strokes,
    this.currentStroke,
    this.isDrawingMode = false,
    this.onPanStart,
    this.onPanUpdate,
    this.onPanEnd,
  });

  @override
  Widget build(BuildContext context) {
    final customPaint = CustomPaint(
      painter: DrawingPainter(
        strokes: strokes,
        currentStroke: currentStroke,
      ),
      size: Size.infinite,
    );

    if (!isDrawingMode) {
      return IgnorePointer(child: customPaint);
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: (details) {
        onPanStart?.call(details.localPosition);
      },
      onPanUpdate: (details) {
        onPanUpdate?.call(details.localPosition);
      },
      onPanEnd: (_) {
        onPanEnd?.call();
      },
      child: customPaint,
    );
  }
}
