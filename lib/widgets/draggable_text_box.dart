import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/text_box_model.dart';
import '../theme/app_theme.dart';

class DraggableTextBoxWidget extends StatefulWidget {
  final TextBoxItem item;
  final bool isSelected;
  final Function(Offset newPosition) onPositionChanged;
  final Function(double newWidth, double newHeight) onSizeChanged;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final Function(String newText) onTextChanged;

  const DraggableTextBoxWidget({
    super.key,
    required this.item,
    required this.isSelected,
    required this.onPositionChanged,
    required this.onSizeChanged,
    required this.onTap,
    required this.onDelete,
    required this.onTextChanged,
  });

  @override
  State<DraggableTextBoxWidget> createState() => _DraggableTextBoxWidgetState();
}

class _DraggableTextBoxWidgetState extends State<DraggableTextBoxWidget> {
  late TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();

  static const double handleSize = 26.0;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.item.text);
    _focusNode.addListener(() {
      if (_focusNode.hasFocus && !widget.isSelected) {
        widget.onTap();
      }
    });
  }

  @override
  void didUpdateWidget(covariant DraggableTextBoxWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.text != widget.item.text && _controller.text != widget.item.text) {
      _controller.text = widget.item.text;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  TextStyle _getTextStyle() {
    FontWeight weight = widget.item.isBold ? FontWeight.bold : FontWeight.w600;
    FontStyle style = widget.item.isItalic ? FontStyle.italic : FontStyle.normal;

    switch (widget.item.fontName) {
      case 'Nunito':
        return GoogleFonts.nunito(
          color: widget.item.inkColor,
          fontSize: widget.item.fontSize,
          fontWeight: weight,
          fontStyle: style,
        );
      case 'Roboto':
        return GoogleFonts.roboto(
          color: widget.item.inkColor,
          fontSize: widget.item.fontSize,
          fontWeight: weight,
          fontStyle: style,
        );
      case 'Courier':
        return GoogleFonts.courierPrime(
          color: widget.item.inkColor,
          fontSize: widget.item.fontSize,
          fontWeight: weight,
          fontStyle: style,
        );
      case 'Vazirmatn':
      default:
        return GoogleFonts.vazirmatn(
          color: widget.item.inkColor,
          fontSize: widget.item.fontSize,
          fontWeight: weight,
          fontStyle: style,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSel = widget.isSelected;
    final highlight = widget.item.highlightColor;

    return Positioned(
      left: widget.item.position.dx,
      top: widget.item.position.dy,
      child: SizedBox(
        width: widget.item.width + (isSel ? handleSize : 0),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Main Text Box Container
            GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () {
                widget.onTap();
                if (!_focusNode.hasFocus) {
                  _focusNode.requestFocus();
                }
              },
              child: Container(
                margin: EdgeInsets.only(
                  top: isSel ? handleSize / 2 : 0,
                  right: isSel ? handleSize / 2 : 0,
                  bottom: isSel ? handleSize / 2 : 0,
                  left: isSel ? handleSize / 2 : 0,
                ),
                width: widget.item.width,
                constraints: const BoxConstraints(minHeight: 34, minWidth: 80),
                decoration: BoxDecoration(
                  color: highlight != null
                      ? highlight.withValues(alpha: 0.35)
                      : (isSel ? const Color(0xFFE2E8F0).withValues(alpha: 0.7) : Colors.transparent),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isSel ? AppTheme.primaryColor : const Color(0xFFE2E8F0).withValues(alpha: 0.5),
                    width: isSel ? 1.5 : 0.8,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    maxLines: null,
                    textAlign: widget.item.textAlign,
                    onTap: () {
                      widget.onTap();
                    },
                    onChanged: widget.onTextChanged,
                    style: _getTextStyle(),
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      fillColor: Colors.transparent,
                      hintText: isSel ? 'متن خود را بنویسید...' : '',
                      hintStyle: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade400,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Top-Left Move Handle (Active when selected)
            if (isSel)
              Positioned(
                left: 0,
                top: 0,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanUpdate: (details) {
                    widget.onPositionChanged(widget.item.position + details.delta);
                  },
                  child: Container(
                    width: handleSize,
                    height: handleSize,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.open_with_rounded,
                        size: 14,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),

            // Top-Right Delete Handle (Active when selected)
            if (isSel)
              Positioned(
                right: 0,
                top: 0,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: widget.onDelete,
                  child: Container(
                    width: handleSize,
                    height: handleSize,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFF4D4F),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.close_rounded,
                        size: 14,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),

            // Bottom-Right Resize Handle (Active when selected)
            if (isSel)
              Positioned(
                right: 0,
                bottom: 0,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanUpdate: (details) {
                    final newW = (widget.item.width + details.delta.dx).clamp(60.0, 500.0);
                    final newH = (widget.item.height + details.delta.dy).clamp(30.0, 500.0);
                    widget.onSizeChanged(newW, newH);
                  },
                  child: Container(
                    width: handleSize,
                    height: handleSize,
                    decoration: BoxDecoration(
                      color: const Color(0xFF007AFF),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.aspect_ratio_rounded,
                        size: 13,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
