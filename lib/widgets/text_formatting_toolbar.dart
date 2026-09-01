import 'package:flutter/material.dart';

class TextFormattingToolbar extends StatelessWidget {
  final double fontSize;
  final Color inkColor;
  final TextAlign textAlign;
  final VoidCallback? onPrevField;
  final VoidCallback? onNextField;
  final VoidCallback? onFontTap;
  final VoidCallback? onFontSizeTap;
  final VoidCallback? onColorTap;
  final VoidCallback? onAlignTap;
  final VoidCallback? onNumberedListTap;
  final VoidCallback? onInsertTimeTap;
  final VoidCallback? onCloseKeyboard;

  const TextFormattingToolbar({
    super.key,
    required this.fontSize,
    required this.inkColor,
    required this.textAlign,
    this.onPrevField,
    this.onNextField,
    this.onFontTap,
    this.onFontSizeTap,
    this.onColorTap,
    this.onAlignTap,
    this.onNumberedListTap,
    this.onInsertTimeTap,
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

    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(
          top: BorderSide(color: Color(0xFFE2E8F0), width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Row(
          children: [
            // 1. Prev Field (⌃)
            IconButton(
              tooltip: 'فیلد قبلی',
              icon: const Icon(Icons.keyboard_arrow_up_rounded, size: 20, color: Color(0xFF64748B)),
              onPressed: onPrevField,
              visualDensity: VisualDensity.compact,
            ),

            // 2. Next Field (⌄)
            IconButton(
              tooltip: 'فیلد بعدی',
              icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: Color(0xFF64748B)),
              onPressed: onNextField,
              visualDensity: VisualDensity.compact,
            ),

            const SizedBox(width: 4),

            // 3. AA (Font Style)
            InkWell(
              onTap: onFontTap,
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: const Text(
                  'AA',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1976D2),
                  ),
                ),
              ),
            ),

            const SizedBox(width: 4),

            // 4. Font Size Indicator (e.g. 14 or 31 in rounded box)
            InkWell(
              onTap: onFontSizeTap,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Text(
                  fontSize.toInt().toString(),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ),
            ),

            const SizedBox(width: 6),

            // 5. Text Color Live Preview
            InkWell(
              onTap: onColorTap,
              borderRadius: BorderRadius.circular(6),
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: inkColor,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.grey.shade400),
                ),
              ),
            ),

            const SizedBox(width: 6),

            // 6. Text Alignment
            IconButton(
              tooltip: 'ترازبندی',
              icon: Icon(alignIcon, size: 19, color: const Color(0xFF1976D2)),
              onPressed: onAlignTap,
              visualDensity: VisualDensity.compact,
            ),

            // 7. Numbered List 123
            IconButton(
              tooltip: 'لیست شماره‌دار',
              icon: const Icon(Icons.format_list_numbered_rounded, size: 19, color: Color(0xFF1976D2)),
              onPressed: onNumberedListTap,
              visualDensity: VisualDensity.compact,
            ),

            // 8. Alarm Clock / Insert Time
            IconButton(
              tooltip: 'درج زمان فعلی',
              icon: const Icon(Icons.access_time_rounded, size: 18, color: Color(0xFF1976D2)),
              onPressed: onInsertTimeTap,
              visualDensity: VisualDensity.compact,
            ),

            const SizedBox(width: 4),
            Container(width: 1, height: 24, color: Colors.grey.shade300),
            const SizedBox(width: 4),

            // 9. Close Keyboard Button
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
}
