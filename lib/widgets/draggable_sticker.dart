import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/sticker_model.dart';
import 'platform_image_helper.dart';

class DraggableStickerWidget extends StatelessWidget {
  final StickerItem item;
  final bool isSelected;
  final Function(Offset newPosition) onPositionChanged;
  final Function(double newScale) onScaleChanged;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback? onInteractionStart;
  final VoidCallback? onInteractionEnd;

  const DraggableStickerWidget({
    super.key,
    required this.item,
    required this.isSelected,
    required this.onPositionChanged,
    required this.onScaleChanged,
    required this.onTap,
    required this.onDelete,
    this.onInteractionStart,
    this.onInteractionEnd,
  });

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
          errorBuilder: (ctx, err, stack) => const Icon(Icons.broken_image_rounded, color: Colors.grey),
        );
      } catch (_) {}
    }

    if (path.startsWith('assets/')) {
      return Image.asset(
        path,
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (ctx, err, stack) => const Icon(Icons.broken_image_rounded, color: Colors.grey),
      );
    }

    return buildPlatformFileImage(
      filePath: path,
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorWidget: const Icon(Icons.broken_image_rounded, color: Colors.grey),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = item.imagePath != null && item.imagePath!.isNotEmpty;
    // Photos get a larger, photo-friendly base dimension (130px) vs emojis (56px)
    final double baseSize = hasImage ? 130.0 : 56.0;
    final currentSize = baseSize * item.scale;

    return Positioned(
      left: item.position.dx,
      top: item.position.dy,
      child: Transform.rotate(
        angle: item.rotation,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // 1. Sticker / Photo Body (Drag to Move & Tap to Select)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              onPanStart: (_) {
                onTap();
                onInteractionStart?.call();
              },
              onPanUpdate: (details) {
                onPositionChanged(item.position + details.delta);
              },
              onPanEnd: (_) {
                onInteractionEnd?.call();
              },
              onPanCancel: () {
                onInteractionEnd?.call();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 100),
                width: currentSize,
                height: currentSize,
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF007AFF).withValues(alpha: 0.08)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(hasImage ? 12 : 8),
                  border: Border.all(
                    color: isSelected ? const Color(0xFF007AFF) : Colors.transparent,
                    width: isSelected ? 2.0 : 0.0,
                  ),
                  boxShadow: hasImage
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isSelected ? 0.22 : 0.10),
                            blurRadius: isSelected ? 12 : 6,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: hasImage
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: _buildStickerImage(item.imagePath!, currentSize),
                        )
                      : Text(
                          item.content,
                          style: TextStyle(
                            fontSize: 32 * item.scale,
                          ),
                        ),
                ),
              ),
            ),

            // 2. Selection Overlay Controls (Separate sibling gesture detectors)
            if (isSelected) ...[
              // Delete Button (Top-Left)
              Positioned(
                top: -10,
                left: -10,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onDelete,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: Colors.red.shade600,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: const [
                        BoxShadow(color: Colors.black38, blurRadius: 4, offset: Offset(0, 2)),
                      ],
                    ),
                    child: const Center(
                      child: Icon(Icons.close_rounded, size: 16, color: Colors.white),
                    ),
                  ),
                ),
              ),

              // Scale Handle (Bottom-Right)
              Positioned(
                bottom: -10,
                right: -10,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanStart: (_) {
                    onInteractionStart?.call();
                  },
                  onPanUpdate: (details) {
                    // Smooth diagonal scaling
                    final delta = (details.delta.dx + details.delta.dy) * 0.012;
                    final newScale = (item.scale + delta).clamp(0.3, 6.0);
                    onScaleChanged(newScale);
                  },
                  onPanEnd: (_) {
                    onInteractionEnd?.call();
                  },
                  onPanCancel: () {
                    onInteractionEnd?.call();
                  },
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: const Color(0xFF007AFF),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: const [
                        BoxShadow(color: Colors.black38, blurRadius: 4, offset: Offset(0, 2)),
                      ],
                    ),
                    child: const Center(
                      child: Icon(Icons.open_in_full_rounded, size: 15, color: Colors.white),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
