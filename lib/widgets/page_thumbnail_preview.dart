import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/notebook_model.dart';
import '../models/template_model.dart';
import '../models/page_style_model.dart';
import '../models/text_box_model.dart';
import '../models/sticker_model.dart';
import '../models/check_item_model.dart';
import '../theme/app_fonts.dart';
import 'paper_pattern_painter.dart';
import 'drawing_canvas_widget.dart';
import 'platform_image_helper.dart';

/// Lightweight, read-only thumbnail preview of a [NotebookPageModel].
/// Accurately renders background template / paper style, text boxes,
/// freehand drawings, check items, stickers, and note text in proportional scale.
class PageThumbnailPreview extends StatelessWidget {
  final NotebookPageModel page;

  const PageThumbnailPreview({
    super.key,
    required this.page,
  });

  @override
  Widget build(BuildContext context) {
    final template = page.template;
    final double aspectRatio = template != null
        ? template.aspectRatio
        : page.pageStyle.effectiveAspectRatio;

    const double baseWidth = 360.0;
    final double baseHeight = baseWidth / aspectRatio;

    return IgnorePointer(
      child: Center(
        child: AspectRatio(
          aspectRatio: aspectRatio,
          child: Container(
            color: template != null ? Colors.white : page.pageStyle.backgroundColor,
            child: FittedBox(
              fit: BoxFit.contain,
              alignment: Alignment.center,
              child: SizedBox(
                width: baseWidth,
                height: baseHeight,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // 1. Background layer: Template or PaperPatternWidget
                    _buildBackground(baseWidth, baseHeight),

                    // 2. Freehand Drawing strokes (if any)
                    if (page.drawingStrokes.isNotEmpty)
                      CustomPaint(
                        painter: DrawingPainter(strokes: page.drawingStrokes),
                        size: Size(baseWidth, baseHeight),
                      ),

                    // 3. Natural page note text (if template is null and noteTitle/noteBody are non-empty)
                    if (page.template == null && (page.noteTitle.isNotEmpty || page.noteBody.isNotEmpty))
                      _buildNaturalNoteContent(baseWidth, baseHeight),

                    // 4. Text Boxes (for both templates and blank/lined pages)
                    ...page.textBoxes.map((item) => _buildTextBox(item, baseWidth, baseHeight)),

                    // 5. Interactive Check Items (checkmarks)
                    ...page.checkItems.map((chk) => _buildCheckItem(chk, baseWidth, baseHeight)),

                    // 6. Stickers & Photos
                    ...page.stickers.map((stk) => _buildSticker(stk)),

                    // 7. Fallback header note if template has no text boxes but has title/body
                    if (page.template != null && page.textBoxes.isEmpty && (page.noteTitle.isNotEmpty || page.noteBody.isNotEmpty))
                      _buildTemplateFallbackNoteContent(baseWidth, baseHeight),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBackground(double baseW, double baseH) {
    final template = page.template;
    if (template != null) {
      if (template.imageBytes != null && template.imageBytes!.isNotEmpty) {
        return Image.memory(
          template.imageBytes!,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => _buildFallbackTemplate(template),
        );
      }

      if (template.imageAsset != null && template.imageAsset!.isNotEmpty) {
        final path = template.imageAsset!;
        if (path.startsWith('data:image') || path.startsWith('data:')) {
          try {
            final commaIdx = path.indexOf(',');
            final b64 = commaIdx != -1 ? path.substring(commaIdx + 1) : path;
            return Image.memory(
              base64Decode(b64),
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => _buildFallbackTemplate(template),
            );
          } catch (_) {}
        }

        if (path.startsWith('http://') || path.startsWith('https://') || path.startsWith('blob:')) {
          return Image.network(
            path,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => _buildFallbackTemplate(template),
          );
        }

        if (path.startsWith('assets/')) {
          return Image.asset(
            path,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => _buildFallbackTemplate(template),
          );
        }

        return buildPlatformFileImage(
          filePath: path,
          fit: BoxFit.contain,
          errorWidget: _buildFallbackTemplate(template),
        );
      }

      return _buildFallbackTemplate(template);
    }

    return PaperPatternWidget(
      config: page.pageStyle,
      isThumbnail: false,
    );
  }

  Widget _buildFallbackTemplate(JournalTemplate tmpl) {
    return Container(
      color: tmpl.cardBackground,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(tmpl.icon, size: 40, color: tmpl.themeColor),
            const SizedBox(height: 8),
            Text(
              tmpl.title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: tmpl.themeColor,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextBox(TextBoxItem item, double baseW, double baseH) {
    if (item.text.trim().isEmpty) return const SizedBox.shrink();

    final hasNormalized = item.normalizedX != null &&
        item.normalizedY != null &&
        item.normalizedWidth != null &&
        item.normalizedHeight != null;

    final double left = hasNormalized
        ? (item.normalizedX! * baseW)
        : item.position.dx.clamp(0.0, baseW - 30.0);
    final double top = hasNormalized
        ? (item.normalizedY! * baseH)
        : item.position.dy.clamp(0.0, baseH - 20.0);
    final double width = hasNormalized
        ? (item.normalizedWidth! * baseW).clamp(24.0, baseW - left)
        : item.width.clamp(24.0, baseW - left);
    final double height = hasNormalized
        ? (item.normalizedHeight! * baseH).clamp(16.0, baseH - top)
        : item.height.clamp(16.0, baseH - top);

    final FontWeight weight = item.isBold ? FontWeight.bold : FontWeight.w500;
    final FontStyle style = item.isItalic ? FontStyle.italic : FontStyle.normal;

    final textStyle = AppFonts.getSafeFont(
      item.fontName,
      color: item.inkColor,
      fontSize: item.fontSize,
      fontWeight: weight,
      fontStyle: style,
      height: 1.45,
    );

    return Positioned(
      left: left,
      top: top,
      width: width,
      height: height,
      child: Container(
        decoration: BoxDecoration(
          color: item.highlightColor?.withValues(alpha: 0.30) ?? Colors.transparent,
          borderRadius: BorderRadius.circular(3),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        child: ClipRect(
          child: Text(
            item.text,
            textAlign: item.textAlign,
            style: textStyle,
            overflow: TextOverflow.ellipsis,
            maxLines: (height / (item.fontSize * 1.45)).floor().clamp(1, 40),
          ),
        ),
      ),
    );
  }

  Widget _buildCheckItem(InteractiveCheckItem chk, double baseW, double baseH) {
    final left = chk.normalizedX * baseW;
    final top = chk.normalizedY * baseH;
    final w = (chk.normalizedWidth * baseW).clamp(18.0, 48.0);
    final h = (chk.normalizedHeight * baseH).clamp(18.0, 48.0);

    if (!chk.isChecked) return const SizedBox.shrink();

    return Positioned(
      left: left,
      top: top,
      width: w,
      height: h,
      child: Center(
        child: Icon(
          Icons.check_circle_rounded,
          size: w * 0.9,
          color: chk.checkColor,
        ),
      ),
    );
  }

  Widget _buildSticker(StickerItem stk) {
    return Positioned(
      left: stk.position.dx,
      top: stk.position.dy,
      child: Transform.rotate(
        angle: stk.rotation,
        child: Transform.scale(
          scale: stk.scale,
          child: stk.imagePath != null
              ? _buildStickerImage(stk.imagePath!, 48.0)
              : Text(
                  stk.content,
                  style: const TextStyle(fontSize: 28),
                ),
        ),
      ),
    );
  }

  Widget _buildStickerImage(String path, double size) {
    if (path.startsWith('data:image') || path.startsWith('data:')) {
      try {
        final commaIdx = path.indexOf(',');
        final b64 = commaIdx != -1 ? path.substring(commaIdx + 1) : path;
        return Image.memory(
          base64Decode(b64),
          width: size,
          height: size,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        );
      } catch (_) {}
    }

    if (path.startsWith('assets/')) {
      return Image.asset(
        path,
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      );
    }

    return buildPlatformFileImage(
      filePath: path,
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorWidget: const SizedBox.shrink(),
    );
  }

  Widget _buildNaturalNoteContent(double baseW, double baseH) {
    EdgeInsets padding = const EdgeInsets.symmetric(horizontal: 24, vertical: 20);
    if (page.pageStyle.pageType == PageType.lined || page.pageStyle.pageType == PageType.wideLined) {
      padding = const EdgeInsets.only(left: 20, right: 54, top: 32, bottom: 24);
    }

    return Positioned.fill(
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (page.noteTitle.isNotEmpty)
              Text(
                page.noteTitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
            if (page.noteBody.isNotEmpty) ...[
              const SizedBox(height: 6),
              Expanded(
                child: Text(
                  page.noteBody,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade800,
                    height: 1.6,
                  ),
                  overflow: TextOverflow.fade,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTemplateFallbackNoteContent(double baseW, double baseH) {
    return Positioned(
      top: 14,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.90),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.black.withValues(alpha: 0.10)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (page.noteTitle.isNotEmpty)
              Text(
                page.noteTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
            if (page.noteBody.isNotEmpty)
              Text(
                page.noteBody,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey.shade700,
                  height: 1.3,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
