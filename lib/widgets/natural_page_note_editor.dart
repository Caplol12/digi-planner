import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/page_style_model.dart';

class NaturalPageNoteEditor extends StatefulWidget {
  final PageStyleConfig config;
  final TextEditingController bodyController;
  final TextEditingController? titleController;
  final double fontSize;
  final String fontName;
  final Color inkColor;
  final TextAlign textAlign;
  final bool isBold;
  final bool isItalic;
  final Color? highlightColor;

  const NaturalPageNoteEditor({
    super.key,
    required this.config,
    required this.bodyController,
    this.titleController,
    this.fontSize = 15.0,
    this.fontName = 'Vazirmatn',
    this.inkColor = const Color(0xFF1E2024),
    this.textAlign = TextAlign.right,
    this.isBold = false,
    this.isItalic = false,
    this.highlightColor,
  });

  @override
  State<NaturalPageNoteEditor> createState() => _NaturalPageNoteEditorState();
}

class _NaturalPageNoteEditorState extends State<NaturalPageNoteEditor> {
  TextStyle _getTextStyle() {
    final weight = widget.isBold ? FontWeight.bold : FontWeight.w500;
    final style = widget.isItalic ? FontStyle.italic : FontStyle.normal;

    // Line height tuned to natural paper lines
    double lineHeight = 1.75;
    if (widget.config.pageType == PageType.wideLined) {
      lineHeight = 2.2;
    } else if (widget.config.pageType == PageType.grid || widget.config.pageType == PageType.dotGrid) {
      lineHeight = 1.6;
    }

    final baseStyle = TextStyle(
      fontSize: widget.fontSize,
      color: widget.inkColor,
      fontWeight: weight,
      fontStyle: style,
      backgroundColor: widget.highlightColor?.withValues(alpha: 0.35),
      height: lineHeight,
    );

    switch (widget.fontName) {
      case 'Nunito':
        return GoogleFonts.nunito(textStyle: baseStyle);
      case 'Roboto':
        return GoogleFonts.roboto(textStyle: baseStyle);
      case 'Courier':
        return GoogleFonts.courierPrime(textStyle: baseStyle);
      case 'Vazirmatn':
      default:
        return GoogleFonts.vazirmatn(textStyle: baseStyle);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Determine margin padding based on page type
    EdgeInsets padding = const EdgeInsets.symmetric(horizontal: 24, vertical: 20);
    if (widget.config.pageType == PageType.lined || widget.config.pageType == PageType.wideLined) {
      // Offset from side margin line
      padding = const EdgeInsets.only(left: 20, right: 54, top: 32, bottom: 24);
    }

    return Container(
      color: Colors.transparent,
      padding: padding,
      child: TextField(
        controller: widget.bodyController,
        textAlign: widget.textAlign,
        style: _getTextStyle(),
        cursorColor: widget.inkColor,
        cursorWidth: 2.0,
        maxLines: null,
        expands: true,
        keyboardType: TextInputType.multiline,
        textAlignVertical: TextAlignVertical.top,
        decoration: const InputDecoration(
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          filled: false,
          fillColor: Colors.transparent,
          contentPadding: EdgeInsets.zero,
          isDense: true,
        ),
      ),
    );
  }
}

