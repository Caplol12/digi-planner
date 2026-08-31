import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'pro_badge.dart';

class CustomNavigationRailBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onDestinationSelected;
  final VoidCallback onCreatePressed;

  const CustomNavigationRailBar({
    super.key,
    required this.currentIndex,
    required this.onDestinationSelected,
    required this.onCreatePressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: AppTheme.dividerLight, width: 1.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Logo & Pro Badge
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'ژورنال',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.textPrimaryLight,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppTheme.primaryColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const ProBadge(),
              ],
            ),
          ),

          // Primary Create Action Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: onCreatePressed,
                icon: const Icon(Icons.add_rounded, size: 22),
                label: const Text('ژورنال جدید'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Navigation Links
          _buildRailItem(0, Icons.menu_book_outlined, Icons.menu_book_rounded, 'ژورنال‌های من'),
          _buildRailItem(1, Icons.draw_outlined, Icons.draw_rounded, 'ساخت برگه'),
          _buildRailItem(2, Icons.style_outlined, Icons.style_rounded, 'قالب‌ها'),
          _buildRailItem(3, Icons.search_rounded, Icons.saved_search_rounded, 'جستجو و تگ‌ها'),
          _buildRailItem(4, Icons.favorite_border_rounded, Icons.favorite_rounded, 'علاقه‌مندی‌ها'),

          const Spacer(),

          // Footer info
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              'نسخه ۱.۰.۰ • کراس‌پلتفرم',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRailItem(int index, IconData icon, IconData activeIcon, String label) {
    final isSelected = currentIndex == index;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Material(
        color: isSelected ? AppTheme.primaryLight : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () => onDestinationSelected(index),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(
                  isSelected ? activeIcon : icon,
                  color: isSelected ? AppTheme.primaryColor : Colors.grey.shade600,
                  size: 22,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? AppTheme.primaryColor : AppTheme.textPrimaryLight,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
