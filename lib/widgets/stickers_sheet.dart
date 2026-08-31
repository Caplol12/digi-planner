import 'package:flutter/material.dart';
import '../models/sticker_model.dart';
import '../theme/app_theme.dart';

class StickersSheet extends StatefulWidget {
  final Function(String emoji) onStickerSelected;

  const StickersSheet({super.key, required this.onStickerSelected});

  static void show(BuildContext context, {required Function(String emoji) onStickerSelected}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => StickersSheet(onStickerSelected: onStickerSelected),
    );
  }

  @override
  State<StickersSheet> createState() => _StickersSheetState();
}

class _StickersSheetState extends State<StickersSheet> {
  int _selectedCategoryIndex = 0;

  @override
  Widget build(BuildContext context) {
    final categories = StickerCategory.defaults;
    final currentCat = categories[_selectedCategoryIndex];

    return Container(
      height: 380,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.auto_awesome_rounded, color: AppTheme.primaryColor, size: 22),
                  SizedBox(width: 8),
                  Text(
                    'استیکرها و تمبرها (Stickers & Stamps)',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Category Pills
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final isSelected = _selectedCategoryIndex == index;
                return ChoiceChip(
                  label: Text(categories[index].title),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) setState(() => _selectedCategoryIndex = index);
                  },
                  selectedColor: AppTheme.primaryLight,
                  backgroundColor: Colors.grey.shade100,
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected ? AppTheme.primaryColor : Colors.black87,
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  showCheckmark: false,
                );
              },
            ),
          ),
          const SizedBox(height: 16),

          // Stickers Grid
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 6,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: currentCat.stickers.length,
              itemBuilder: (context, index) {
                final sticker = currentCat.stickers[index];
                return InkWell(
                  onTap: () {
                    Navigator.pop(context);
                    widget.onStickerSelected(sticker);
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Center(
                      child: Text(
                        sticker,
                        style: const TextStyle(fontSize: 26),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
