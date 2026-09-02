import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class TextFormattingToolbar extends StatelessWidget {
  // Text styling parameters
  final double fontSize;
  final Color inkColor;
  final TextAlign textAlign;
  final bool isBold;
  final bool isItalic;
  final bool isUnderline;

  // Drawing mode parameters
  final bool isDrawingMode;
  final bool isHighlighter;
  final bool isEraser;
  final double penStrokeWidth;

  // Callbacks
  final VoidCallback? onTogglePen;
  final VoidCallback? onToggleHighlighter;
  final VoidCallback? onToggleEraser;
  final VoidCallback? onStrokeWidthTap;
  final VoidCallback? onUndoDrawing;
  final Function(Color)? onQuickColorSelected;
  final VoidCallback? onColorTap;
  final VoidCallback? onToggleBold;
  final VoidCallback? onToggleItalic;
  final VoidCallback? onToggleUnderline;
  final VoidCallback? onPrevField;
  final VoidCallback? onNextField;
  final VoidCallback? onFontTap;
  final VoidCallback? onFontSizeTap;
  final VoidCallback? onAlignTap;
  final VoidCallback? onNumberedListTap;
  final VoidCallback? onChecklistTap;
  final VoidCallback? onInsertTimeTap;
  final VoidCallback? onStickersTap;
  final VoidCallback? onCloseKeyboard;

  // Quick preset palette matching Persian stationery styles
  static const List<Color> quickColors = [
    Color(0xFF1E2024), // Classic Black
    Color(0xFF1976D2), // Royal Blue
    Color(0xFFD32F2F), // Ruby Red
    Color(0xFF2E7D32), // Emerald Green
    Color(0xFFFBC02D), // Highlighter Yellow
    Color(0xFF7B1FA2), // Purple
    Color(0xFFE65100), // Amber Orange
  ];

  const TextFormattingToolbar({
    super.key,
    required this.fontSize,
    required this.inkColor,
    required this.textAlign,
    this.isBold = false,
    this.isItalic = false,
    this.isUnderline = false,
    this.isDrawingMode = false,
    this.isHighlighter = false,
    this.isEraser = false,
    this.penStrokeWidth = 3.0,
    this.onTogglePen,
    this.onToggleHighlighter,
    this.onToggleEraser,
    this.onStrokeWidthTap,
    this.onUndoDrawing,
    this.onQuickColorSelected,
    this.onColorTap,
    this.onToggleBold,
    this.onToggleItalic,
    this.onToggleUnderline,
    this.onPrevField,
    this.onNextField,
    this.onFontTap,
    this.onFontSizeTap,
    this.onAlignTap,
    this.onNumberedListTap,
    this.onChecklistTap,
    this.onInsertTimeTap,
    this.onStickersTap,
    this.onCloseKeyboard,
  });

  @override
  Widget build(BuildContext context) {
    IconData alignIcon;
    switch (textAlign) {
      case TextAlign.left:
        alignIcon = Icons.format_align_left_rounded;
        break;
      case TextAlign.center:
        alignIcon = Icons.format_align_center_rounded;
        break;
      default:
        alignIcon = Icons.format_align_right_rounded;
    }

    final bottomInset = math.max(MediaQuery.of(context).padding.bottom, kIsWeb ? 10.0 : 4.0);

    return Container(
      padding: EdgeInsets.only(bottom: bottomInset, top: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(
          top: BorderSide(color: Color(0xFFE2E8F0), width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Row(
          children: [
            // ----------------------------------------------------
            // بخش ۱: ابزارهای نقاشی و طراحی (Drawing Tools)
            // ----------------------------------------------------
            // ۱.۱. دکمه قلم نقاشی (Pen)
            _buildToolbarButton(
              icon: Icons.draw_rounded,
              tooltip: 'قلم نقاشی آزاد',
              isActive: isDrawingMode && !isHighlighter && !isEraser,
              activeColor: const Color(0xFF1976D2),
              onTap: onTogglePen,
            ),

            // ۱.۲. دکمه هایلایتر (Highlighter)
            _buildToolbarButton(
              icon: Icons.brush_rounded,
              tooltip: 'قلم هایلایتر',
              isActive: isDrawingMode && isHighlighter,
              activeColor: const Color(0xFFF57C00),
              onTap: onToggleHighlighter,
            ),

            // ۱.۳. دکمه پاک‌کن (Eraser)
            _buildToolbarButton(
              icon: Icons.auto_fix_normal_rounded,
              tooltip: 'پاک‌کن خطوط',
              isActive: isDrawingMode && isEraser,
              activeColor: Colors.red.shade700,
              onTap: onToggleEraser,
            ),

            // ۱.۴. دکمه ضخامت قلم (Stroke Width)
            if (isDrawingMode)
              InkWell(
                onTap: onStrokeWidthTap,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: (penStrokeWidth * 1.5).clamp(4.0, 16.0),
                        height: (penStrokeWidth * 1.5).clamp(4.0, 16.0),
                        decoration: BoxDecoration(
                          color: isEraser ? Colors.grey.shade700 : inkColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${penStrokeWidth.toInt()}px',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                      ),
                    ],
                  ),
                ),
              ),

            // ۱.۵. دکمه بازگشت نقاشی (Undo)
            if (isDrawingMode && onUndoDrawing != null)
              IconButton(
                tooltip: 'بازگردانی خط قبلی (Undo)',
                icon: const Icon(Icons.undo_rounded, size: 20, color: Color(0xFF64748B)),
                onPressed: onUndoDrawing,
                visualDensity: VisualDensity.compact,
              ),

            _buildDivider(),

            // ----------------------------------------------------
            // بخش ۲: پالت رنگ‌های سریع (Quick Color Swatches)
            // ----------------------------------------------------
            ...quickColors.map((color) {
              final isSelected = inkColor.toARGB32() == color.toARGB32();
              return GestureDetector(
                onTap: () => onQuickColorSelected?.call(color),
                child: Container(
                  width: 22,
                  height: 22,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? const Color(0xFF007AFF) : Colors.black.withValues(alpha: 0.15),
                      width: isSelected ? 2.5 : 1.0,
                    ),
                    boxShadow: [
                      if (isSelected)
                        BoxShadow(
                          color: color.withValues(alpha: 0.4),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                    ],
                  ),
                  child: isSelected
                      ? Center(
                          child: Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                          ),
                        )
                      : null,
                ),
              );
            }),

            // انتخاب‌گر رنگین‌کمانی پالت کامل
            GestureDetector(
              onTap: onColorTap,
              child: Container(
                width: 24,
                height: 24,
                margin: const EdgeInsets.only(left: 4, right: 3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const SweepGradient(
                    colors: [
                      Colors.red,
                      Colors.yellow,
                      Colors.green,
                      Colors.cyan,
                      Colors.blue,
                      Colors.purple,
                      Colors.red,
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(Icons.colorize_rounded, size: 12, color: Colors.white),
                ),
              ),
            ),

            _buildDivider(),

            // ----------------------------------------------------
            // بخش ۳: فرمت‌های متنی و استایل (Text Styles: B, I, U)
            // ----------------------------------------------------
            // بولد (B)
            _buildTextFormatButton(
              label: 'B',
              tooltip: 'بولد / پررنگ',
              isActive: isBold,
              textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
              onTap: onToggleBold,
            ),

            // ایتالیک (I)
            _buildTextFormatButton(
              label: 'I',
              tooltip: 'ایتالیک / کج',
              isActive: isItalic,
              textStyle: const TextStyle(fontStyle: FontStyle.italic, fontWeight: FontWeight.bold, fontSize: 14),
              onTap: onToggleItalic,
            ),

            // زیرخط (U)
            _buildTextFormatButton(
              label: 'U',
              tooltip: 'زیرخط دار (Underline)',
              isActive: isUnderline,
              textStyle: const TextStyle(
                decoration: TextDecoration.underline,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
              onTap: onToggleUnderline,
            ),

            // فونت (AA)
            InkWell(
              onTap: onFontTap,
              borderRadius: BorderRadius.circular(6),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: const Text(
                  'AA',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1976D2),
                  ),
                ),
              ),
            ),

            // اندازه فونت
            InkWell(
              onTap: onFontSizeTap,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Text(
                  fontSize.toInt().toString(),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ),
            ),

            // ترازبندی
            IconButton(
              tooltip: 'ترازبندی',
              icon: Icon(alignIcon, size: 19, color: const Color(0xFF1976D2)),
              onPressed: onAlignTap,
              visualDensity: VisualDensity.compact,
            ),

            _buildDivider(),

            // ----------------------------------------------------
            // بخش ۴: ابزارهای تکمیلی (لیست، چک‌باکس، ساعت، استیکر)
            // ----------------------------------------------------
            // چک‌لیست / تودو
            IconButton(
              tooltip: 'درج چک‌لیست / تودو',
              icon: const Icon(Icons.check_box_outlined, size: 19, color: Color(0xFF1976D2)),
              onPressed: onChecklistTap,
              visualDensity: VisualDensity.compact,
            ),

            // لیست شماره‌دار
            IconButton(
              tooltip: 'لیست شماره‌دار',
              icon: const Icon(Icons.format_list_numbered_rounded, size: 19, color: Color(0xFF1976D2)),
              onPressed: onNumberedListTap,
              visualDensity: VisualDensity.compact,
            ),

            // ساعت / درج زمان
            IconButton(
              tooltip: 'درج زمان فعلی',
              icon: const Icon(Icons.access_time_rounded, size: 18, color: Color(0xFF1976D2)),
              onPressed: onInsertTimeTap,
              visualDensity: VisualDensity.compact,
            ),

            // استیکرها
            if (onStickersTap != null)
              IconButton(
                tooltip: 'استیکرها و ایموجی‌ها',
                icon: const Icon(Icons.emoji_emotions_outlined, size: 19, color: Color(0xFFFF7043)),
                onPressed: onStickersTap,
                visualDensity: VisualDensity.compact,
              ),

            _buildDivider(),

            // ----------------------------------------------------
            // بخش ۵: کنترل و پیمایش (Navigation & Close)
            // ----------------------------------------------------
            IconButton(
              tooltip: 'فیلد قبلی',
              icon: const Icon(Icons.keyboard_arrow_up_rounded, size: 20, color: Color(0xFF64748B)),
              onPressed: onPrevField,
              visualDensity: VisualDensity.compact,
            ),

            IconButton(
              tooltip: 'فیلد بعدی',
              icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: Color(0xFF64748B)),
              onPressed: onNextField,
              visualDensity: VisualDensity.compact,
            ),

            IconButton(
              tooltip: 'بستن کیبورد',
              icon: const Icon(Icons.keyboard_hide_rounded, size: 20, color: Color(0xFF64748B)),
              onPressed: onCloseKeyboard ?? () => FocusManager.instance.primaryFocus?.unfocus(),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolbarButton({
    required IconData icon,
    required String tooltip,
    required bool isActive,
    required Color activeColor,
    required VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: isActive ? activeColor.withValues(alpha: 0.15) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: isActive ? Border.all(color: activeColor.withValues(alpha: 0.5), width: 1.2) : null,
      ),
      child: IconButton(
        tooltip: tooltip,
        icon: Icon(icon, size: 19, color: isActive ? activeColor : const Color(0xFF475569)),
        onPressed: onTap,
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  Widget _buildTextFormatButton({
    required String label,
    required String tooltip,
    required bool isActive,
    required TextStyle textStyle,
    required VoidCallback? onTap,
  }) {
    const activeColor = Color(0xFF1976D2);
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: 28,
          height: 28,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: isActive ? activeColor.withValues(alpha: 0.16) : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isActive ? activeColor : Colors.grey.shade300,
              width: isActive ? 1.5 : 1.0,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: textStyle.copyWith(
              color: isActive ? activeColor : const Color(0xFF334155),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      width: 1,
      height: 22,
      margin: const EdgeInsets.symmetric(horizontal: 5),
      color: const Color(0xFFE2E8F0),
    );
  }
}
