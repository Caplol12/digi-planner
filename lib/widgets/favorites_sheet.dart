import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/template_model.dart';

class FavoritesSheet extends StatelessWidget {
  final List<JournalTemplate> favoriteTemplates;
  final VoidCallback onAddFavoritesPressed;
  final Function(JournalTemplate) onTemplateSelected;

  const FavoritesSheet({
    super.key,
    required this.favoriteTemplates,
    required this.onAddFavoritesPressed,
    required this.onTemplateSelected,
  });

  static void show(
    BuildContext context, {
    required List<JournalTemplate> favoriteTemplates,
    required VoidCallback onAddFavoritesPressed,
    required Function(JournalTemplate) onTemplateSelected,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FavoritesSheet(
        favoriteTemplates: favoriteTemplates,
        onAddFavoritesPressed: onAddFavoritesPressed,
        onTemplateSelected: onTemplateSelected,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasFavorites = favoriteTemplates.isNotEmpty;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Header Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'علاقه‌مندی‌ها (Favorites)',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimaryLight,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close_rounded, size: 18, color: Colors.black87),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppTheme.dividerLight),

          // Content
          Expanded(
            child: hasFavorites
                ? ListView.separated(
                    padding: const EdgeInsets.all(20),
                    itemCount: favoriteTemplates.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 14),
                    itemBuilder: (context, index) {
                      final template = favoriteTemplates[index];
                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: template.cardBackground,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: template.themeColor.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: template.themeColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(template.icon, color: template.themeColor, size: 24),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    template.title,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    template.subtitle,
                                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                              onPressed: () {
                                Navigator.pop(context);
                                onTemplateSelected(template);
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  )
                : Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Illustration Graphic
                          Container(
                            width: 130,
                            height: 130,
                            decoration: BoxDecoration(
                              color: AppTheme.primaryLight,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.favorite_rounded,
                                size: 64,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          ),
                          const SizedBox(height: 28),
                          const Text(
                            'علاقه‌مندی‌های شما منتظرند\nYour Favorites Await',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textPrimaryLight,
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'قالب‌ها و یادداشت‌های مورد علاقه شما در اینجا نمایش داده می‌شوند. برای افزودن، کافی است روی آیکون قلب هر قالب کلیک کنید.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                              height: 1.6,
                            ),
                          ),
                          const SizedBox(height: 32),
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.pop(context);
                                onAddFavoritesPressed();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryColor,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'افزودن به علاقه‌مندی‌ها (Add Favorites)',
                                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                  ),
                                  SizedBox(width: 8),
                                  Icon(Icons.arrow_forward_rounded, size: 20),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
