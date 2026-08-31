import 'package:flutter/material.dart';
import '../models/page_style_model.dart';

class PaperPatternWidget extends StatelessWidget {
  final PageStyleConfig config;
  final bool isThumbnail;
  final Widget? child;

  const PaperPatternWidget({
    super.key,
    required this.config,
    this.isThumbnail = false,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    final isSpread = config.spread == PageSpread.spread;

    return Container(
      decoration: BoxDecoration(
        color: config.backgroundColor,
        borderRadius: BorderRadius.circular(isThumbnail ? 8 : 12),
        boxShadow: isThumbnail
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // If double page spread, render two pages side by side with center spine
          if (isSpread)
            Row(
              children: [
                Expanded(
                  child: CustomPaint(
                    painter: PaperPatternCustomPainter(
                      config: config,
                      isThumbnail: isThumbnail,
                      isLeftHalf: true,
                    ),
                  ),
                ),
                // Center book spine crease / shadow
                Container(
                  width: isThumbnail ? 4 : 12,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.black.withValues(alpha: 0.18),
                        Colors.black.withValues(alpha: 0.02),
                        Colors.black.withValues(alpha: 0.18),
                      ],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                  ),
                ),
                Expanded(
                  child: CustomPaint(
                    painter: PaperPatternCustomPainter(
                      config: config,
                      isThumbnail: isThumbnail,
                      isLeftHalf: false,
                    ),
                  ),
                ),
              ],
            )
          else
            CustomPaint(
              painter: PaperPatternCustomPainter(
                config: config,
                isThumbnail: isThumbnail,
              ),
            ),

          // Child content layer (Text boxes, stickers, etc.)
          if (child != null) child!,
        ],
      ),
    );
  }
}

class PaperPatternCustomPainter extends CustomPainter {
  final PageStyleConfig config;
  final bool isThumbnail;
  final bool? isLeftHalf;

  PaperPatternCustomPainter({
    required this.config,
    required this.isThumbnail,
    this.isLeftHalf,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final lineColor = config.patternLineColor;
    final secondaryColor = config.secondaryPatternColor;
    final marginColor = config.marginLineColor;

    final linePaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = isThumbnail ? 0.75 : 1.0;

    final secondaryPaint = Paint()
      ..color = secondaryColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = isThumbnail ? 1.0 : 1.5;

    final marginPaint = Paint()
      ..color = marginColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = isThumbnail ? 0.8 : 1.2;

    switch (config.pageType) {
      case PageType.blank:
        // No pattern needed
        break;

      case PageType.lined:
        _drawLined(canvas, size, linePaint, marginPaint, lineSpacing: isThumbnail ? 12.0 : 28.0);
        break;

      case PageType.wideLined:
        _drawLined(canvas, size, linePaint, marginPaint, lineSpacing: isThumbnail ? 16.0 : 38.0);
        break;

      case PageType.grid:
        _drawGrid(canvas, size, linePaint, spacing: isThumbnail ? 9.0 : 22.0);
        break;

      case PageType.dotGrid:
        _drawDotGrid(canvas, size, linePaint, spacing: isThumbnail ? 10.0 : 24.0);
        break;

      case PageType.cornell:
        _drawCornell(canvas, size, linePaint, secondaryPaint);
        break;

      case PageType.todo:
        _drawTodo(canvas, size, linePaint, secondaryPaint, spacing: isThumbnail ? 14.0 : 32.0);
        break;

      case PageType.dailySchedule:
        _drawDailySchedule(canvas, size, linePaint, secondaryPaint);
        break;

      case PageType.weeklyPlanner:
        _drawWeeklyPlanner(canvas, size, linePaint, secondaryPaint);
        break;

      case PageType.musicStaff:
        _drawMusicStaff(canvas, size, linePaint);
        break;
    }
  }

  void _drawLined(
    Canvas canvas,
    Size size,
    Paint linePaint,
    Paint marginPaint, {
    required double lineSpacing,
  }) {
    final topPadding = isThumbnail ? 12.0 : 40.0;
    final bottomPadding = isThumbnail ? 8.0 : 30.0;

    // Draw horizontal ruled lines
    for (double y = topPadding; y < size.height - bottomPadding; y += lineSpacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }

    // Draw side margin guide line
    final marginX = isThumbnail ? size.width * 0.15 : 46.0;
    canvas.drawLine(Offset(marginX, 0), Offset(marginX, size.height), marginPaint);
  }

  void _drawGrid(Canvas canvas, Size size, Paint linePaint, {required double spacing}) {
    for (double x = 0; x <= size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), linePaint);
    }
    for (double y = 0; y <= size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }
  }

  void _drawDotGrid(Canvas canvas, Size size, Paint linePaint, {required double spacing}) {
    final dotPaint = Paint()
      ..color = config.patternLineColor.withValues(alpha: 0.8)
      ..style = PaintingStyle.fill;

    final dotRadius = isThumbnail ? 0.7 : 1.25;

    for (double x = spacing; x < size.width; x += spacing) {
      for (double y = spacing; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), dotRadius, dotPaint);
      }
    }
  }

  void _drawCornell(Canvas canvas, Size size, Paint linePaint, Paint secondaryPaint) {
    final headerHeight = isThumbnail ? 16.0 : 50.0;
    final footerHeight = isThumbnail ? 22.0 : 80.0;
    final cueWidth = isThumbnail ? size.width * 0.3 : size.width * 0.28;

    // Header divider line
    canvas.drawLine(Offset(0, headerHeight), Offset(size.width, headerHeight), secondaryPaint);

    // Summary footer divider line
    final summaryY = size.height - footerHeight;
    canvas.drawLine(Offset(0, summaryY), Offset(size.width, summaryY), secondaryPaint);

    // Vertical cue column line
    canvas.drawLine(Offset(cueWidth, headerHeight), Offset(cueWidth, summaryY), secondaryPaint);

    // Lined notes inside the main notes body
    final lineSpacing = isThumbnail ? 10.0 : 24.0;
    for (double y = headerHeight + lineSpacing; y < summaryY; y += lineSpacing) {
      canvas.drawLine(Offset(cueWidth, y), Offset(size.width, y), linePaint);
    }

    // Lined notes inside summary area
    for (double y = summaryY + lineSpacing; y < size.height; y += lineSpacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }
  }

  void _drawTodo(
    Canvas canvas,
    Size size,
    Paint linePaint,
    Paint secondaryPaint, {
    required double spacing,
  }) {
    final topPadding = isThumbnail ? 14.0 : 38.0;
    final boxSize = isThumbnail ? 5.0 : 13.0;
    final boxMarginX = isThumbnail ? 8.0 : 20.0;

    for (double y = topPadding; y < size.height - 20; y += spacing) {
      // Horizontal line
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);

      // Checkbox square or circle
      final boxRect = Rect.fromLTWH(boxMarginX, y - boxSize - (isThumbnail ? 2 : 4), boxSize, boxSize);
      final rrect = RRect.fromRectAndRadius(boxRect, Radius.circular(isThumbnail ? 1.5 : 3.5));
      canvas.drawRRect(rrect, secondaryPaint);
    }
  }

  void _drawDailySchedule(Canvas canvas, Size size, Paint linePaint, Paint secondaryPaint) {
    final colWidth = isThumbnail ? size.width * 0.35 : size.width * 0.3;
    final headerHeight = isThumbnail ? 16.0 : 45.0;

    // Header line
    canvas.drawLine(Offset(0, headerHeight), Offset(size.width, headerHeight), secondaryPaint);

    // Vertical timeline divider
    canvas.drawLine(Offset(colWidth, headerHeight), Offset(colWidth, size.height), secondaryPaint);

    // Schedule hourly horizontal lines
    final lineSpacing = isThumbnail ? 10.0 : 25.0;
    for (double y = headerHeight + lineSpacing; y < size.height; y += lineSpacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }
  }

  void _drawWeeklyPlanner(Canvas canvas, Size size, Paint linePaint, Paint secondaryPaint) {
    final headerHeight = isThumbnail ? 14.0 : 38.0;
    final colWidth = size.width / 7.0;

    // Header line
    canvas.drawLine(Offset(0, headerHeight), Offset(size.width, headerHeight), secondaryPaint);

    // Day column dividers
    for (int i = 1; i < 7; i++) {
      final x = i * colWidth;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), linePaint);
    }

    // Horizontal sub-lines
    final lineSpacing = isThumbnail ? 12.0 : 28.0;
    for (double y = headerHeight + lineSpacing; y < size.height; y += lineSpacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }
  }

  void _drawMusicStaff(Canvas canvas, Size size, Paint linePaint) {
    final staffCount = isThumbnail ? 4 : 8;
    final staveSpacing = size.height / (staffCount + 1);
    final lineGap = isThumbnail ? 3.0 : 7.0;

    for (int s = 1; s <= staffCount; s++) {
      final baseY = s * staveSpacing;
      for (int l = 0; l < 5; l++) {
        final y = baseY + (l * lineGap);
        canvas.drawLine(Offset(10, y), Offset(size.width - 10, y), linePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant PaperPatternCustomPainter oldDelegate) {
    return oldDelegate.config != config ||
        oldDelegate.isThumbnail != isThumbnail ||
        oldDelegate.isLeftHalf != isLeftHalf;
  }
}
