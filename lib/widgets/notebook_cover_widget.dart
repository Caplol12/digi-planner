import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class NotebookCoverWidget extends StatelessWidget {
  final String title;
  final Color coverColor;
  final String? coverImagePath;
  final double width;
  final double height;
  final double elevation;
  final bool showLabel;

  const NotebookCoverWidget({
    super.key,
    required this.title,
    required this.coverColor,
    this.coverImagePath,
    this.width = 220,
    this.height = 310,
    this.elevation = 12,
    this.showLabel = true,
  });

  Widget? _buildCoverImage() {
    if (coverImagePath == null || coverImagePath!.trim().isEmpty) return null;
    final path = coverImagePath!.trim();

    // 1. Base64 Data URI (e.g. data:image/png;base64,...)
    if (path.startsWith('data:image') || path.startsWith('data:')) {
      try {
        final commaIdx = path.indexOf(',');
        final base64Str = commaIdx != -1 ? path.substring(commaIdx + 1) : path;
        final bytes = base64Decode(base64Str);
        return Image.memory(
          bytes,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        );
      } catch (_) {
        return null;
      }
    }

    // 2. Asset image
    if (path.startsWith('assets/')) {
      return Image.asset(
        path,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      );
    }

    // 3. Network URL
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return Image.network(
        path,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      );
    }

    // 4. Local File (only on native platforms, never on Web)
    if (!kIsWeb) {
      try {
        final file = File(path);
        if (file.existsSync()) {
          return Image.file(
            file,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          );
        }
      } catch (_) {}
    }

    // 5. Fallback: try raw base64 decode if string is pure base64
    try {
      final bytes = base64Decode(path);
      return Image.memory(
        bytes,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      );
    } catch (_) {}

    return null;
  }

  @override
  Widget build(BuildContext context) {
    // Generate a slightly darker spine color
    final HSLColor hsl = HSLColor.fromColor(coverColor);
    final Color spineColor = hsl.withLightness((hsl.lightness - 0.18).clamp(0.0, 1.0)).toColor();
    final Color spineHighlight = hsl.withLightness((hsl.lightness + 0.10).clamp(0.0, 1.0)).toColor();
    final coverImageWidget = _buildCoverImage();

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(6),
          bottomLeft: Radius.circular(6),
          topRight: Radius.circular(22),
          bottomRight: Radius.circular(22),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: elevation,
            offset: const Offset(4, 8),
            spreadRadius: 1,
          ),
          BoxShadow(
            color: coverColor.withValues(alpha: 0.22),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(6),
          bottomLeft: Radius.circular(6),
          topRight: Radius.circular(22),
          bottomRight: Radius.circular(22),
        ),
        child: Stack(
          children: [
            // Base Color & Texture
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      coverColor,
                      hsl.withLightness((hsl.lightness - 0.06).clamp(0.0, 1.0)).toColor(),
                    ],
                  ),
                ),
              ),
            ),

            // Custom Image if selected from gallery
            if (coverImageWidget != null)
              Positioned.fill(
                child: coverImageWidget,
              ),

            // Subtle texture/sheen overlay
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withValues(alpha: 0.12),
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.08),
                    ],
                  ),
                ),
              ),
            ),

            // Realistic Spine on Left Edge (Image 1 style)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: width * 0.08,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      spineColor.withValues(alpha: 0.8),
                      spineHighlight.withValues(alpha: 0.4),
                      Colors.black.withValues(alpha: 0.25),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.35, 0.85, 1.0],
                  ),
                ),
              ),
            ),

            // Spine indentation crease line
            Positioned(
              left: width * 0.08,
              top: 0,
              bottom: 0,
              width: 2,
              child: Container(
                color: Colors.black.withValues(alpha: 0.12),
              ),
            ),

            // Label Strip on Top (Image 1 style)
            if (showLabel)
              Positioned(
                left: 0,
                top: height * 0.14,
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: width * 0.82,
                    minWidth: width * 0.45,
                    minHeight: height * 0.16,
                  ),
                  padding: EdgeInsets.symmetric(
                    horizontal: width * 0.06,
                    vertical: height * 0.02,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFDF0ED), // Pastel cream/pink matching image 1
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 4,
                        offset: const Offset(1, 2),
                      ),
                    ],
                  ),
                  alignment: Alignment.centerLeft,
                  child: Text(
                    title.isEmpty ? 'دفترچه' : title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.vazirmatn(
                      fontSize: (width * 0.075).clamp(11.0, 18.0),
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF2C3437),
                    ),
                  ),
                ),
              ),

            // Subtle page edge thickness on right
            Positioned(
              right: 0,
              top: 4,
              bottom: 4,
              width: 3,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.35),
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
