import 'package:flutter/material.dart';
import '../models/template_model.dart';
import '../widgets/template_card.dart';
import '../theme/app_theme.dart';
import '../widgets/responsive_layout.dart';

class TemplatesScreen extends StatefulWidget {
  final List<JournalTemplate> templates;
  final Function(JournalTemplate) onTemplateSelected;
  final Function(JournalTemplate) onFavoriteToggle;
  final VoidCallback? onProBuilderPressed;

  const TemplatesScreen({
    super.key,
    required this.templates,
    required this.onTemplateSelected,
    required this.onFavoriteToggle,
    this.onProBuilderPressed,
  });

  @override
  State<TemplatesScreen> createState() => _TemplatesScreenState();
}

class _TemplatesScreenState extends State<TemplatesScreen> {
  String _selectedCategory = 'all';
  final ScrollController _scrollController = ScrollController();
  bool _showScrollToTop = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.offset > 250 && !_showScrollToTop) {
        setState(() => _showScrollToTop = true);
      } else if (_scrollController.offset <= 250 && _showScrollToTop) {
        setState(() => _showScrollToTop = false);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToTop() {
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredTemplates = _selectedCategory == 'all'
        ? widget.templates
        : widget.templates.where((t) => t.categoryId == _selectedCategory).toList();

    return Stack(
      children: [
        Column(
          children: [
            // AI Vision Pro Template Builder Quick Banner
            if (widget.onProBuilderPressed != null)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFF1EB), Color(0xFFFFE3D8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFFFCCBC)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF7043),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ساخت قالب حرفه‌ای با هوش مصنوعی',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFFBF360C)),
                          ),
                          Text(
                            'آپلود تصویر و تعیین خودکار تمام باکس‌های متن',
                            style: TextStyle(fontSize: 11, color: Color(0xFFD84315)),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: widget.onProBuilderPressed,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF7043),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('شروع', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),

            // Category Chips Row (Smooth horizontal scrolling without overflow)
            SizedBox(
              height: 52,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                itemCount: TemplateCategory.defaultCategories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final cat = TemplateCategory.defaultCategories[index];
                  final isSelected = _selectedCategory == cat.id;

                  return Material(
                    color: isSelected ? AppTheme.primaryColor : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      onTap: () => setState(() => _selectedCategory = cat.id),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected ? AppTheme.primaryColor : AppTheme.dividerLight,
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              cat.icon,
                              size: 16,
                              color: isSelected ? Colors.white : Colors.grey.shade700,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              cat.title,
                              style: TextStyle(
                                color: isSelected ? Colors.white : AppTheme.textPrimaryLight,
                                fontSize: 12.5,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const Divider(height: 1, color: AppTheme.dividerLight),

            // Templates Feed
            Expanded(
              child: filteredTemplates.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.style_outlined, size: 48, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          Text('قالب فعالی در این دسته یافت نشد', style: TextStyle(color: Colors.grey.shade600)),
                        ],
                      ),
                    )
                  : ResponsiveLayout.isDesktop(context) || ResponsiveLayout.isTablet(context)
                      ? GridView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 80),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: ResponsiveLayout.getGridColumnCount(context, tabletCount: 2, desktopCount: 3),
                            childAspectRatio: 0.68,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                          itemCount: filteredTemplates.length,
                          itemBuilder: (context, index) {
                            final template = filteredTemplates[index];
                            return TemplateCard(
                              template: template,
                              onTap: () => widget.onTemplateSelected(template),
                              onFavoriteToggle: () => widget.onFavoriteToggle(template),
                            );
                          },
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.only(top: 8, bottom: 80),
                          itemCount: filteredTemplates.length,
                          itemBuilder: (context, index) {
                            final template = filteredTemplates[index];
                            return SizedBox(
                              height: 480,
                              child: TemplateCard(
                                template: template,
                                onTap: () => widget.onTemplateSelected(template),
                                onFavoriteToggle: () => widget.onFavoriteToggle(template),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),

        // Scroll to Top FAB
        if (_showScrollToTop)
          Positioned(
            right: 20,
            bottom: 20,
            child: FloatingActionButton.small(
              heroTag: 'scroll_top_templates',
              onPressed: _scrollToTop,
              backgroundColor: Colors.white,
              foregroundColor: AppTheme.primaryColor,
              elevation: 4,
              child: const Icon(Icons.keyboard_arrow_up_rounded, size: 24),
            ),
          ),
      ],
    );
  }
}


