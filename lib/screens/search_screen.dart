import 'package:flutter/material.dart';
import '../models/template_model.dart';
import '../models/journal_model.dart';
import '../theme/app_theme.dart';
import '../widgets/template_card.dart';

class SearchScreen extends StatefulWidget {
  final List<JournalTemplate> templates;
  final List<JournalItem> journals;
  final Function(JournalTemplate) onTemplateSelected;
  final Function(JournalItem) onJournalSelected;
  final Function(JournalTemplate) onFavoriteToggle;

  const SearchScreen({
    super.key,
    required this.templates,
    required this.journals,
    required this.onTemplateSelected,
    required this.onJournalSelected,
    required this.onFavoriteToggle,
  });

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Popular Tags matching screenshot 2
  final List<String> _popularTags = [
    'September 2026 Planner',
    'Back To School',
    'Mom Planner',
    'Parenting Journal',
    'Grocery Checklist',
    'Class Schedule',
    'Study Planner',
    'Cleaning Checklist',
    'Class Notes',
    'Teacher Planner',
    'Medical Notes',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onTagSelected(String tag) {
    _searchController.text = tag;
    setState(() {
      _searchQuery = tag.toLowerCase();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isSearching = _searchQuery.trim().isNotEmpty;

    // Filter templates based on query
    final matchedTemplates = widget.templates.where((t) {
      final q = _searchQuery;
      return t.title.toLowerCase().contains(q) ||
          t.subtitle.toLowerCase().contains(q) ||
          t.tags.any((tag) => tag.toLowerCase().contains(q));
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search Input Bar (Matching screenshot 2)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: TextField(
            controller: _searchController,
            onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
            decoration: InputDecoration(
              hintText: 'Search here... (جستجو در قالب‌ها)',
              prefixIcon: const Icon(Icons.search_rounded, size: 22),
              suffixIcon: isSearching
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 20),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
            ),
          ),
        ),

        // Body: Either Popular Tags List (Screenshot 2) or Search Results
        Expanded(
          child: !isSearching
              ? ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    const SizedBox(height: 8),
                    const Text(
                      'Popular Tags',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimaryLight,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Popular Tags List matching screenshot 2
                    ...List.generate(_popularTags.length, (index) {
                      final tag = _popularTags[index];
                      final isEven = index % 2 == 0;

                      return Material(
                        color: isEven ? AppTheme.tagBgLight : Colors.white,
                        borderRadius: BorderRadius.circular(12),
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
                                  color: Colors.grey.shade600,
                                ),
                                const SizedBox(width: 14),
                                Text(
                                  tag,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade800,
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
              : matchedTemplates.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off_rounded, size: 48, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          Text(
                            'نتیجه‌ای برای «$_searchQuery» یافت نشد',
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(top: 8, bottom: 40),
                      itemCount: matchedTemplates.length,
                      itemBuilder: (context, index) {
                        final template = matchedTemplates[index];
                        return TemplateCard(
                          template: template,
                          onTap: () => widget.onTemplateSelected(template),
                          onFavoriteToggle: () => widget.onFavoriteToggle(template),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}
