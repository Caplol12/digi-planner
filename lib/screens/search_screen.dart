import 'dart:async';
import 'package:flutter/material.dart';
import '../models/template_model.dart';
import '../models/notebook_model.dart';
import '../theme/app_theme.dart';
import '../widgets/template_card.dart';
import '../widgets/notebook_cover_widget.dart';

class SearchScreen extends StatefulWidget {
  final List<JournalTemplate> templates;
  final List<NotebookModel> notebooks;
  final Function(JournalTemplate) onTemplateSelected;
  final Function(NotebookModel)? onNotebookSelected;
  final Function(JournalTemplate) onFavoriteToggle;

  const SearchScreen({
    super.key,
    required this.templates,
    this.notebooks = const [],
    required this.onTemplateSelected,
    this.onNotebookSelected,
    required this.onFavoriteToggle,
  });

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  Timer? _debounceTimer;

  // Popular Tags (Persian & localized for Planner)
  final List<String> _popularTags = [
    'پلنر ۱۴۰۵',
    'برنامه‌ریزی روزانه',
    'برنامه‌ریزی هفتگی',
    'مطالعه و کنکور',
    'کارهای روزمره',
    'خرید و منزل',
    'یادداشت کلاسی',
    'سلامت و ورزش',
    'اهداف مالی',
    'ایده‌ها و پروژه‌ها',
  ];

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String val) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _searchQuery = val.trim().toLowerCase();
        });
      }
    });
  }

  void _onTagSelected(String tag) {
    _debounceTimer?.cancel();
    _searchController.text = tag;
    setState(() {
      _searchQuery = tag.toLowerCase();
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final isSearching = _searchQuery.isNotEmpty;
    final q = _searchQuery;

    // Filter templates based on query
    final matchedTemplates = widget.templates.where((t) {
      return t.title.toLowerCase().contains(q) ||
          t.subtitle.toLowerCase().contains(q) ||
          t.tags.any((tag) => tag.toLowerCase().contains(q));
    }).toList();

    // Filter notebooks based on query (including text boxes and check items)
    final matchedNotebooks = widget.notebooks.where((nb) {
      return nb.title.toLowerCase().contains(q) ||
          (nb.folderName != null && nb.folderName!.toLowerCase().contains(q)) ||
          nb.pages.any((p) =>
              p.title.toLowerCase().contains(q) ||
              p.noteTitle.toLowerCase().contains(q) ||
              p.noteBody.toLowerCase().contains(q) ||
              p.cueText.toLowerCase().contains(q) ||
              p.summaryText.toLowerCase().contains(q) ||
              p.textBoxes.any((b) => b.text.toLowerCase().contains(q)) ||
              p.checkItems.any((chk) => chk.label.toLowerCase().contains(q)));
    }).toList();

    final hasResults = matchedTemplates.isNotEmpty || matchedNotebooks.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search Input Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              hintText: 'جستجو در قالب‌ها، دفترچه‌ها و نوشته‌ها...',
              prefixIcon: const Icon(Icons.search_rounded, size: 22),
              suffixIcon: isSearching
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 20),
                      onPressed: () {
                        _debounceTimer?.cancel();
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
            ),
          ),
        ),

        // Body: Either Popular Tags List or Search Results
        Expanded(
          child: !isSearching
              ? ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    const SizedBox(height: 8),
                    Text(
                      'برچسب‌های پرطرفدار',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: c.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Popular Tags List
                    ...List.generate(_popularTags.length, (index) {
                      final tag = _popularTags[index];
                      final isEven = index % 2 == 0;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        decoration: BoxDecoration(
                          color: isEven ? c.tagBg : c.cardBackground,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: c.divider),
                        ),
                        child: InkWell(
                          onTap: () => _onTagSelected(tag),
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.search_rounded,
                                  size: 20,
                                  color: c.textSecondary,
                                ),
                                const SizedBox(width: 14),
                                Text(
                                  tag,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: c.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 32),
                  ],
                )
              : !hasResults
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off_rounded, size: 48, color: c.textSecondary),
                          const SizedBox(height: 12),
                          Text(
                            'نتیجه‌ای برای «$_searchQuery» یافت نشد',
                            style: TextStyle(color: c.textSecondary, fontSize: 14),
                          ),
                        ],
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.only(top: 8, bottom: 40, left: 16, right: 16),
                      children: [
                        if (matchedNotebooks.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              'دفترچه‌ها (${matchedNotebooks.length})',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: c.textPrimary),
                            ),
                          ),
                          ...matchedNotebooks.map((nb) => Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                decoration: BoxDecoration(
                                  color: c.cardBackground,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: c.divider),
                                ),
                                child: ListTile(
                                  leading: SizedBox(
                                    width: 40,
                                    height: 52,
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(6),
                                      child: NotebookCoverWidget(
                                        title: nb.title,
                                        coverColor: nb.coverColor,
                                        coverImagePath: nb.coverImagePath,
                                        width: 40,
                                        height: 52,
                                        elevation: 2,
                                        showLabel: false,
                                      ),
                                    ),
                                  ),
                                  title: Text(nb.title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: c.textPrimary)),
                                  subtitle: Text(
                                    '${nb.pages.length} برگه${nb.folderName != null ? ' • پوشه: ${nb.folderName}' : ''}',
                                    style: TextStyle(fontSize: 12, color: c.textSecondary),
                                  ),
                                  trailing: const Icon(Icons.chevron_left_rounded, size: 20),
                                  onTap: () => widget.onNotebookSelected?.call(nb),
                                ),
                              )),
                          const SizedBox(height: 16),
                        ],
                        if (matchedTemplates.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              'قالب‌ها (${matchedTemplates.length})',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: c.textPrimary),
                            ),
                          ),
                          ...matchedTemplates.map((template) => TemplateCard(
                                template: template,
                                onTap: () => widget.onTemplateSelected(template),
                                onFavoriteToggle: () => widget.onFavoriteToggle(template),
                              )),
                        ],
                      ],
                    ),
        ),
      ],
    );
  }
}
