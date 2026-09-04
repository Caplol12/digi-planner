import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final VoidCallback? onSearchPressed;
  final VoidCallback? onFavoritesPressed;
  final VoidCallback? onImportPressed;
  final VoidCallback? onSettingsPressed;

  const CustomAppBar({
    super.key,
    this.title = 'PlanWiz',
    this.onSearchPressed,
    this.onFavoritesPressed,
    this.onImportPressed,
    this.onSettingsPressed,
  });

  @override
  Size get preferredSize => const Size.fromHeight(60);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      child: SafeArea(
        bottom: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Left: Logotype "PlanWiz" ("Plan" Bold + "Wiz" Thin/Light)
            RichText(
              text: TextSpan(
                style: GoogleFonts.vazirmatn(
                  fontSize: 24,
                  color: const Color(0xFF2C3437),
                  letterSpacing: -0.5,
                ),
                children: const [
                  TextSpan(
                    text: 'Plan',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  TextSpan(
                    text: 'Wiz',
                    style: TextStyle(fontWeight: FontWeight.w300),
                  ),
                ],
              ),
            ),

            // Right: Search, Import JSON (📥), Heart (Favorites ♡) and Settings (⚙) linear icons
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (onSearchPressed != null)
                  IconButton(
                    onPressed: onSearchPressed,
                    icon: const Icon(
                      Icons.search_rounded,
                      size: 22,
                      color: Color(0xFF64748B),
                    ),
                    tooltip: 'جستجو در قالب‌ها و یادداشت‌ها',
                    visualDensity: VisualDensity.compact,
                  ),
                if (onImportPressed != null)
                  IconButton(
                    onPressed: onImportPressed,
                    icon: const Icon(
                      Icons.file_download_outlined,
                      size: 22,
                      color: Color(0xFF1565C0),
                    ),
                    tooltip: 'ورود برگه/قالب/دفترچه (Import JSON)',
                    visualDensity: VisualDensity.compact,
                  ),
                IconButton(
                  onPressed: onFavoritesPressed,
                  icon: const Icon(
                    Icons.favorite_border_rounded,
                    size: 22,
                    color: Color(0xFF64748B),
                  ),
                  tooltip: 'علاقه‌مندی‌ها',
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 2),
                IconButton(
                  onPressed: onSettingsPressed,
                  icon: const Icon(
                    Icons.settings_outlined,
                    size: 22,
                    color: Color(0xFF64748B),
                  ),
                  tooltip: 'تنظیمات',
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
