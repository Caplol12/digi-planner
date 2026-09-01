import 'package:flutter/material.dart';

class FloatingEditorDock extends StatelessWidget {
  final VoidCallback onAddText;
  final VoidCallback onDrawOrStyle;
  final VoidCallback onAddImage;
  final VoidCallback onMoreTools;

  const FloatingEditorDock({
    super.key,
    required this.onAddText,
    required this.onDrawOrStyle,
    required this.onAddImage,
    required this.onMoreTools,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B), // Dark navy / charcoal capsule
        borderRadius: BorderRadius.circular(36),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. "T" - Add Text
          _buildDockIcon(
            icon: Icons.title_rounded,
            tooltip: 'افزودن متن',
            onTap: onAddText,
          ),
          const SizedBox(width: 8),

          // 2. Pen / Brush tool
          _buildDockIcon(
            icon: Icons.draw_outlined,
            tooltip: 'ابزار قلم و سبک برگه',
            onTap: onDrawOrStyle,
          ),
          const SizedBox(width: 8),

          // 3. Image with Mountain & Sun
          _buildDockIcon(
            icon: Icons.image_outlined,
            tooltip: 'افزودن تصویر / قالب',
            onTap: onAddImage,
          ),
          const SizedBox(width: 8),

          // 4. 2x2 Grid (Tools / Elements)
          _buildDockIcon(
            icon: Icons.grid_view_rounded,
            tooltip: 'استیکرها و ابزارها',
            onTap: onMoreTools,
          ),
        ],
      ),
    );
  }

  Widget _buildDockIcon({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          child: Icon(
            icon,
            color: Colors.white,
            size: 22,
          ),
        ),
      ),
    );
  }
}
