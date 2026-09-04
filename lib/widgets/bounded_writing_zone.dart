import 'package:flutter/material.dart';
import '../models/text_box_model.dart';
import '../theme/app_fonts.dart';

/// A custom painter that draws a delicate dashed rectangle border
class DashedRectPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double dashWidth;
  final double dashSpace;
  final double borderRadius;

  const DashedRectPainter({
    this.color = const Color(0xFF007AFF),
    this.strokeWidth = 1.2,
    this.dashWidth = 5.0,
    this.dashSpace = 3.5,
    this.borderRadius = 3.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(borderRadius),
    );

    final path = Path()..addRRect(rrect);
    final metrics = path.computeMetrics();

    for (final metric in metrics) {
      double distance = 0.0;
      while (distance < metric.length) {
        final double len = (distance + dashWidth < metric.length)
            ? dashWidth
            : metric.length - distance;
        final extractPath = metric.extractPath(distance, distance + len);
        canvas.drawPath(extractPath, paint);
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant DashedRectPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.dashWidth != dashWidth ||
        oldDelegate.dashSpace != dashSpace ||
        oldDelegate.borderRadius != borderRadius;
  }
}

/// A refined, bounded writing zone that aligns text directly onto sheet lines.
/// It displays a subtle blue dashed border when focused, remains 100% seamless & transparent
/// when inactive, strictly clips text to avoid boundary overflow, and supports auto-advance.
class BoundedWritingZoneWidget extends StatefulWidget {
  final TextBoxItem item;
  final bool isSelected;
  final VoidCallback onTap;
  final Function(String newText) onTextChanged;
  final VoidCallback? onAutoAdvance;

  const BoundedWritingZoneWidget({
    super.key,
    required this.item,
    required this.isSelected,
    required this.onTap,
    required this.onTextChanged,
    this.onAutoAdvance,
  });

  @override
  State<BoundedWritingZoneWidget> createState() => _BoundedWritingZoneWidgetState();
}

class _BoundedWritingZoneWidgetState extends State<BoundedWritingZoneWidget> {
  late TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();

  // Standard line height multiplier for precise alignment with journal/planner lines
  static const double standardLineHeight = 1.45;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.item.text);
    _focusNode.addListener(_handleFocusChange);
  }

  void _handleFocusChange() {
    if (_focusNode.hasFocus && !widget.isSelected) {
      widget.onTap();
    }
  }

  @override
  void didUpdateWidget(covariant BoundedWritingZoneWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.text != widget.item.text && _controller.text != widget.item.text) {
      _controller.text = widget.item.text;
    }
    if (widget.isSelected && !_focusNode.hasFocus) {
      _focusNode.requestFocus();
    } else if (!widget.isSelected && _focusNode.hasFocus) {
      _focusNode.unfocus();
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  TextStyle _getTextStyle() {
    final FontWeight weight = widget.item.isBold ? FontWeight.bold : FontWeight.w500;
    final FontStyle style = widget.item.isItalic ? FontStyle.italic : FontStyle.normal;

    return AppFonts.getSafeFont(
      widget.item.fontName,
      color: widget.item.inkColor,
      fontSize: widget.item.fontSize,
      fontWeight: weight,
      fontStyle: style,
      height: standardLineHeight,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isSel = widget.isSelected;
    final highlight = widget.item.highlightColor;
    final effectiveHint = widget.item.hintText.isNotEmpty
        ? widget.item.hintText
        : (isSel ? 'اینجا بنویسید...' : '');

    // Calculate maximum allowed lines based on the zone height and standard line height
    final double estimatedLineHeight = widget.item.fontSize * standardLineHeight;
    final int maxAllowedLines = (widget.item.height / estimatedLineHeight).floor().clamp(1, 30);
    final bool isSingleLineZone = maxAllowedLines == 1;

    return Positioned(
      left: widget.item.position.dx,
      top: widget.item.position.dy,
      width: widget.item.width,
      height: widget.item.height,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          widget.onTap();
          if (!_focusNode.hasFocus) {
            _focusNode.requestFocus();
          }
        },
        child: Container(
          width: widget.item.width,
          height: widget.item.height,
          decoration: BoxDecoration(
            color: highlight != null
                ? highlight.withValues(alpha: 0.30)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(3),
          ),
          child: CustomPaint(
            // Show delicate blue dashed border only when active/focused
            painter: isSel ? const DashedRectPainter() : null,
            child: ClipRect(
              // Strict boundary clipping ensures text never overflows outside zone edges
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  maxLines: isSingleLineZone ? 1 : maxAllowedLines,
                  minLines: 1,
                  textInputAction: isSingleLineZone ? TextInputAction.next : TextInputAction.newline,
                  textAlign: widget.item.textAlign,
                  textAlignVertical: TextAlignVertical.center,
                  style: _getTextStyle(),
                  onSubmitted: (_) {
                    if (widget.onAutoAdvance != null) {
                      widget.onAutoAdvance!();
                    }
                  },
                  onChanged: (text) {
                    widget.onTextChanged(text);
                  },
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    fillColor: Colors.transparent,
                    hintText: effectiveHint,
                    hintStyle: TextStyle(
                      fontSize: widget.item.fontSize * 0.9,
                      color: Colors.black.withValues(alpha: 0.22),
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
