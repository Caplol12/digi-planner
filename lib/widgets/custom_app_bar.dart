import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'pro_badge.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final VoidCallback? onFavoritesPressed;
  final VoidCallback? onSettingsPressed;
  final VoidCallback? onSearchPressed;
  final bool showSearchIcon;

  const CustomAppBar({
    super.key,
    this.title = 'ژورنال',
    this.onFavoritesPressed,
    this.onSettingsPressed,
    this.onSearchPressed,
    this.showSearchIcon = true,
  });

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            // Title with stylish logo accent
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                    color: AppTheme.textPrimaryLight,
                  ),
                ),
                const SizedBox(width: 4),
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: AppTheme.primaryColor,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            const ProBadge(),
            const Spacer(),

            // Action Icons
            if (showSearchIcon)
              IconButton(
                onPressed: onSearchPressed,
                icon: const Icon(Icons.search_rounded, size: 24, color: AppTheme.textPrimaryLight),
                tooltip: 'جستجو',
              ),
            IconButton(
              onPressed: onFavoritesPressed,
              icon: const Icon(Icons.favorite_border_rounded, size: 24, color: AppTheme.textPrimaryLight),
              tooltip: 'علاقه‌مندی‌ها',
            ),
            IconButton(
              onPressed: onSettingsPressed,
              icon: const Icon(Icons.settings_outlined, size: 24, color: AppTheme.textPrimaryLight),
              tooltip: 'تنظیمات',
            ),
          ],
        ),
      ),
    );
  }
}
