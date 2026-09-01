import 'dart:io';
import 'package:flutter/material.dart';
import '../models/template_model.dart';
import '../models/page_style_model.dart';
import '../models/text_box_model.dart';
import '../models/sticker_model.dart';
import 'bounded_writing_zone.dart';
import 'draggable_sticker.dart';
import 'paper_pattern_painter.dart';
import 'natural_page_note_editor.dart';

class InteractiveTemplateSheet extends StatelessWidget {
  final JournalTemplate? template;
  final PageStyleConfig? pageStyle;
  final List<TextBoxItem> textBoxes;
  final List<StickerItem> stickers;
  final String? selectedTextBoxId;
  final String? selectedStickerId;
  final Function(String id) onSelectTextBox;
  final Function(String id, Offset newPos)? onPositionChanged;
  final Function(String id, double newW, double newH)? onSizeChanged;
  final Function(String id, String newText) onTextChanged;
  final Function(String id)? onDeleteTextBox;
  final Function(String currentId)? onAutoAdvance;

  final Function(String id) onSelectSticker;
  final Function(String id, Offset newPos) onStickerPositionChanged;
  final Function(String id, double newScale) onStickerScaleChanged;
  final Function(String id) onDeleteSticker;

  final Function(Offset tapPosition) onCanvasTap;

  // Natural Note-taking parameters (when pageStyle != null)
  final TextEditingController? noteTitleController;
  final TextEditingController? noteBodyController;
  final TextEditingController? cueController;
  final TextEditingController? summaryController;
  final double fontSize;
  final String fontName;
  final Color inkColor;
  final TextAlign textAlign;
  final bool isBold;
  final bool isItalic;
  final Color? highlightColor;

  const InteractiveTemplateSheet({
    super.key,
    this.template,
    this.pageStyle,
    required this.textBoxes,
    required this.stickers,
    required this.selectedTextBoxId,
    required this.selectedStickerId,
    required this.onSelectTextBox,
    this.onPositionChanged,
    this.onSizeChanged,
    required this.onTextChanged,
    this.onDeleteTextBox,
    this.onAutoAdvance,
    required this.onSelectSticker,
    required this.onStickerPositionChanged,
    required this.onStickerScaleChanged,
    required this.onDeleteSticker,
    required this.onCanvasTap,
    this.noteTitleController,
    this.noteBodyController,
    this.cueController,
    this.summaryController,
    this.fontSize = 14.0,
    this.fontName = 'Vazirmatn',
    this.inkColor = const Color(0xFF1E2024),
    this.textAlign = TextAlign.right,
    this.isBold = false,
    this.isItalic = false,
    this.highlightColor,
  });

  Widget _buildBackgroundContent() {
    if (pageStyle != null) {
      return PaperPatternWidget(
        config: pageStyle!,
        child: noteBodyController != null
            ? NaturalPageNoteEditor(
                config: pageStyle!,
                bodyController: noteBodyController!,
                titleController: noteTitleController,
                fontSize: fontSize,
                fontName: fontName,
                inkColor: inkColor,
                textAlign: textAlign,
                isBold: isBold,
                isItalic: isItalic,
                highlightColor: highlightColor,
              )
            : null,
      );
    }

    // Template Mode Image Rendering - Use contain so no section is ever cropped
    if (template?.imageBytes != null && template!.imageBytes!.isNotEmpty) {
      return Image.memory(
        template!.imageBytes!,
        fit: BoxFit.contain,
        errorBuilder: (ctx, err, stack) => _buildFallbackSheet(),
      );
    }

    if (template?.imageAsset != null && template!.imageAsset!.isNotEmpty) {
      final path = template!.imageAsset!;
      if (!path.startsWith('assets/')) {
        final file = File(path);
        if (file.existsSync()) {
          return Image.file(
            file,
            fit: BoxFit.contain,
            errorBuilder: (ctx, err, stack) => _buildFallbackSheet(),
          );
        }
      }
      return Image.asset(
        path,
        fit: BoxFit.contain,
        errorBuilder: (ctx, err, stack) => _buildFallbackSheet(),
      );
    }

    return _buildFallbackSheet();
  }

  @override
  Widget build(BuildContext context) {
    // When a template is active, use its exact original aspect ratio!
    final double aspectRatio = (template != null)
        ? template!.aspectRatio
        : (pageStyle != null ? pageStyle!.effectiveAspectRatio : (848 / 1264));

    return Center(
      child: AspectRatio(
        aspectRatio: aspectRatio,
        child: Container(
          decoration: BoxDecoration(
            color: template != null ? Colors.white : (pageStyle?.backgroundColor ?? Colors.white),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.16),
                blurRadius: 28,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            fit: StackFit.expand,
            children: [
              // Background Layer: Natural Note Paper OR Image Template
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (details) {
                    onCanvasTap(details.localPosition);
                  },
                  child: _buildBackgroundContent(),
                ),
              ),

            // Dynamic Stickers Layer
            ...stickers.map((stk) {
              return DraggableStickerWidget(
                key: ValueKey(stk.id),
                item: stk,
                isSelected: stk.id == selectedStickerId,
                onTap: () => onSelectSticker(stk.id),
                onPositionChanged: (newPos) => onStickerPositionChanged(stk.id, newPos),
                onScaleChanged: (newScale) => onStickerScaleChanged(stk.id, newScale),
                onDelete: () => onDeleteSticker(stk.id),
              );
            }),

            // Structured Bounded Writing Zones Layer (Seamless & subtle dashed blue border on focus)
            if (pageStyle == null)
              ...textBoxes.map((item) {
                return BoundedWritingZoneWidget(
                  key: ValueKey(item.id),
                  item: item,
                  isSelected: item.id == selectedTextBoxId,
                  onTap: () => onSelectTextBox(item.id),
                  onTextChanged: (newText) => onTextChanged(item.id, newText),
                  onAutoAdvance: () {
                    if (onAutoAdvance != null) {
                      onAutoAdvance!(item.id);
                    }
                  },
                );
              }),
          ],
        ),
      ),
    ),
  );
}

  Widget _buildFallbackSheet() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(template?.icon ?? Icons.note_rounded, size: 48, color: template?.themeColor ?? Colors.blueGrey),
            const SizedBox(height: 12),
            Text(
              template?.title ?? 'برگه یادداشت',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'برای افزودن متن، دکمه «+ باکس متن» را در بالای صفحه بزنید.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}
