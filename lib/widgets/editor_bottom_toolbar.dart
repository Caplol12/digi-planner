import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class EditorBottomToolbar extends StatelessWidget {
  final bool isPageStyleMode;
  final bool hasSelectedBox;
  final bool hasSelectedSticker;
  final VoidCallback onAddTextBox;
  final VoidCallback onAddSticker;
  final VoidCallback? onAIChatEdit;
  final VoidCallback onDeselect;
  final VoidCallback onFontPicker;
  final VoidCallback onColorPicker;
  final VoidCallback onToggleAlign;
  final VoidCallback onToggleBold;
  final VoidCallback onToggleHighlight;
  final VoidCallback onDeleteSelected;

  const EditorBottomToolbar({
    super.key,
    this.isPageStyleMode = false,
    required this.hasSelectedBox,
    required this.hasSelectedSticker,
    required this.onAddTextBox,
    required this.onAddSticker,
    this.onAIChatEdit,
    required this.onDeselect,
    required this.onFontPicker,
    required this.onColorPicker,
    required this.onToggleAlign,
    required this.onToggleBold,
    required this.onToggleHighlight,
    required this.onDeleteSelected,
  });

  @override
  Widget build(BuildContext context) {
    final hasSelection = hasSelectedBox || hasSelectedSticker;
    final showTextTools = isPageStyleMode || hasSelectedBox;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: AppTheme.dividerLight, width: 1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              // Template Mode: Add Text Box
              if (!isPageStyleMode)
                _buildToolItem(
                  icon: Icons.add_box_rounded,
                  label: '+ باکس متن',
                  isPrimary: true,
                  onTap: onAddTextBox,
                ),

              // Template Mode: AI Assistant / Smart Box
              if (!isPageStyleMode && onAIChatEdit != null)
                _buildToolItem(
                  icon: Icons.auto_awesome_rounded,
                  label: 'دستیار AI',
                  isActive: true,
                  onTap: onAIChatEdit!,
                ),

              // Font & Size
              if (showTextTools)
                _buildToolItem(
                  icon: Icons.font_download_outlined,
                  label: 'قلم و اندازه',
                  onTap: onFontPicker,
                ),

              // Ink Color
              if (showTextTools)
                _buildToolItem(
                  icon: Icons.color_lens_outlined,
                  label: 'رنگ جوهر',
                  onTap: onColorPicker,
                ),

              // Text Align
              if (showTextTools)
                _buildToolItem(
                  icon: Icons.format_align_right_rounded,
                  label: 'تراز متن',
                  onTap: onToggleAlign,
                ),

              // Bold
              if (showTextTools)
                _buildToolItem(
                  icon: Icons.format_bold_rounded,
                  label: 'بولد',
                  onTap: onToggleBold,
                ),

              // Highlighter
              if (showTextTools)
                _buildToolItem(
                  icon: Icons.brush_outlined,
                  label: 'هایلایتر',
                  onTap: onToggleHighlight,
                ),

              // Stickers
              _buildToolItem(
                icon: Icons.emoji_emotions_outlined,
                label: 'استیکرها',
                onTap: onAddSticker,
              ),

              // Deselect
              if (hasSelection)
                _buildToolItem(
                  icon: Icons.crop_free_rounded,
                  label: 'عدم انتخاب',
                  isActive: true,
                  onTap: onDeselect,
                ),

              // Delete Selected
              if (hasSelection)
                _buildToolItem(
                  icon: Icons.delete_outline_rounded,
                  label: 'حذف',
                  isDanger: true,
                  onTap: onDeleteSelected,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToolItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isActive = false,
    bool isPrimary = false,
    bool isDanger = false,
  }) {
    Color color;
    if (isPrimary) {
      color = AppTheme.primaryColor;
    } else if (isDanger) {
      color = Colors.redAccent;
    } else if (isActive) {
      color = const Color(0xFF007AFF);
    } else {
      color = Colors.black87;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: (isPrimary || isActive) ? FontWeight.bold : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
