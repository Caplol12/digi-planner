import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
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

  Widget _buildStickerImage(String path, double size) {
    if (path.startsWith('data:image') || path.startsWith('data:')) {
      try {
        final commaIdx = path.indexOf(',');
        final b64 = commaIdx != -1 ? path.substring(commaIdx + 1) : path;
        return Image.memory(
          base64Decode(b64),
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (ctx, err, stack) => const Icon(Icons.broken_image_rounded, color: Colors.grey),
        );
      } catch (_) {}
    }

    if (path.startsWith('assets/')) {
      return Image.asset(
        path,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (ctx, err, stack) => const Icon(Icons.broken_image_rounded, color: Colors.grey),
      );
    }

    if (!kIsWeb) {
      try {
        final file = File(path);
        if (file.existsSync()) {
          return Image.file(
            file,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (ctx, err, stack) => const Icon(Icons.broken_image_rounded, color: Colors.grey),
          );
        }
      } catch (_) {}
    }

    return const Icon(Icons.broken_image_rounded, color: Colors.grey);
  }

  @override
  Widget build(BuildContext context) {
    const baseSize = 56.0;
    final currentSize = baseSize * item.scale;
    final hasImage = item.imagePath != null && item.imagePath!.isNotEmpty;

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
                // Sticker Content: Gallery Photo OR Emoji
                Center(
                  child: hasImage
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: _buildStickerImage(item.imagePath!, currentSize),
                        )
                      : Text(
                          item.content,
                          style: TextStyle(
                            fontSize: 32 * item.scale,
                          ),
                        ),
                ),

                // Selection Overlay Controls
                if (isSelected) ...[
                  // Delete Button (Top-Left)
                  Positioned(
                    top: -6,
                    left: -6,
                    child: GestureDetector(
                      onTap: onDelete,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.redAccent,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(color: Colors.black26, blurRadius: 4),
                          ],
                        ),
                        child: const Icon(Icons.close, size: 14, color: Colors.white),
                      ),
                    ),
                  ),

                  // Scale Handle (Bottom-Right)
                  Positioned(
                    bottom: -6,
                    right: -6,
                    child: GestureDetector(
                      onPanUpdate: (details) {
                        final newScale = (item.scale + details.delta.dx * 0.015).clamp(0.5, 3.5);
                        onScaleChanged(newScale);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Color(0xFF007AFF),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(color: Colors.black26, blurRadius: 4),
                          ],
                        ),
                        child: const Icon(Icons.open_in_full, size: 14, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
