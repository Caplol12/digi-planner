import 'package:flutter/material.dart';
import '../models/sticker_model.dart';

class DraggableStickerWidget extends StatelessWidget {
  final StickerItem item;
  final bool isSelected;
  final Function(Offset newPosition) onPositionChanged;
  final Function(double newScale) onScaleChanged;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const DraggableStickerWidget({
    super.key,
    required this.item,
    required this.isSelected,
    required this.onPositionChanged,
    required this.onScaleChanged,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    const baseSize = 48.0;
    final currentSize = baseSize * item.scale;

    return Positioned(
      left: item.position.dx,
      top: item.position.dy,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        onPanUpdate: isSelected
            ? (details) {
                onPositionChanged(item.position + details.delta);
              }
            : null,
        child: Transform.rotate(
          angle: item.rotation,
          child: Container(
            width: currentSize + (isSelected ? 24 : 0),
            height: currentSize + (isSelected ? 24 : 0),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFFD6E4F0).withValues(alpha: 0.4) : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? const Color(0xFF007AFF) : Colors.transparent,
                width: 1.5,
              ),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Sticker Content (Emoji or Stamp)
                Center(
                  child: Text(
                    item.content,
                    style: TextStyle(
                      fontSize: 32 * item.scale,
                    ),
                  ),
                ),

                // Delete Handle (Top Right)
                if (isSelected)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: onDelete,
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: const BoxDecoration(
                          color: Color(0xFFFF4D4F),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close_rounded, size: 14, color: Colors.white),
                      ),
                    ),
                  ),

                // Resize/Scale Handle (Bottom Right)
                if (isSelected)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onPanUpdate: (details) {
                        final newScale = (item.scale + details.delta.dx * 0.02).clamp(0.6, 3.0);
                        onScaleChanged(newScale);
                      },
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: const Color(0xFF007AFF),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        child: const Icon(Icons.aspect_ratio_rounded, size: 12, color: Colors.white),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
