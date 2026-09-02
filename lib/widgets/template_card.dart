import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/template_model.dart';
import '../theme/app_theme.dart';

class TemplateCard extends StatelessWidget {
  final JournalTemplate template;
  final VoidCallback onTap;
  final VoidCallback onFavoriteToggle;

  const TemplateCard({
    super.key,
    required this.template,
    required this.onTap,
    required this.onFavoriteToggle,
  });

  Widget _buildTemplateImage() {
    if (template.imageBytes != null && template.imageBytes!.isNotEmpty) {
      return Image.memory(
        template.imageBytes!,
        fit: BoxFit.contain,
        errorBuilder: (ctx, err, stack) => _buildFallbackSheet(),
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
            errorBuilder: (ctx, err, stack) => _buildFallbackSheet(),
          );
        } catch (_) {}
      }

      if (path.startsWith('http://') || path.startsWith('https://') || path.startsWith('blob:')) {
        return Image.network(
          path,
          fit: BoxFit.contain,
          errorBuilder: (ctx, err, stack) => _buildFallbackSheet(),
        );
      }

      if (path.startsWith('assets/')) {
        return Image.asset(
          path,
          fit: BoxFit.contain,
          errorBuilder: (ctx, err, stack) => _buildFallbackSheet(),
        );
      }

      if (!kIsWeb) {
        try {
          final file = File(path);
          if (file.existsSync()) {
            return Image.file(
              file,
              fit: BoxFit.contain,
              errorBuilder: (ctx, err, stack) => _buildFallbackSheet(),
            );
          }
        } catch (_) {}
      }
    }

    return _buildFallbackSheet();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.dividerLight, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Flexible Image Preview Area (Never overflows)
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: template.cardBackground,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Stack(
                  children: [
                    // Centered Template Image
                    Center(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: _buildTemplateImage(),
                      ),
                    ),



                    // Diamond PRO Badge
                    if (template.isPro)
                      Positioned(
                        bottom: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.15),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.diamond_rounded,
                            size: 16,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ),

                    // Favorite Heart Button
                    Positioned(
                      top: 8,
                      right: 8,
                      child: GestureDetector(
                        onTap: onFavoriteToggle,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.12),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(
                            template.isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                            size: 18,
                            color: template.isFavorite ? AppTheme.primaryColor : Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Card Bottom Description & Quick Action
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          template.title,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimaryLight,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          template.subtitle,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: onTap,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: template.themeColor,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      minimumSize: const Size(0, 34),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('انتخاب و نوشتن', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        SizedBox(width: 4),
                        Icon(Icons.arrow_forward_rounded, size: 12),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFallbackSheet() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(template.icon, size: 36, color: template.themeColor),
            const SizedBox(height: 8),
            Text(template.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
