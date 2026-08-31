import 'package:flutter/material.dart';
import '../models/journal_model.dart';
import '../models/template_model.dart';
import '../models/page_style_model.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/navigation_rail_bar.dart';
import '../widgets/responsive_layout.dart';
import '../widgets/favorites_sheet.dart';
import 'my_journals_screen.dart';
import 'choose_page_style_screen.dart';
import 'templates_screen.dart';
import 'search_screen.dart';
import 'journal_editor_screen.dart';
import 'pro_template_builder_screen.dart';
import '../widgets/pro_badge.dart';
import '../theme/app_theme.dart';

class MainNavigationScreen extends StatefulWidget {
  final VoidCallback onToggleTheme;
  final bool isDarkMode;

  const MainNavigationScreen({
    super.key,
    required this.onToggleTheme,
    required this.isDarkMode,
  });

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  final List<JournalItem> _journals = List.from(JournalItem.sampleJournals);
  final List<JournalTemplate> _templates = List.from(JournalTemplate.sampleTemplates);

  void _onTabSelected(int index) {
    if (index == 4) {
      // Open Favorites Sheet
      _openFavoritesSheet();
    } else {
      setState(() => _currentIndex = index);
    }
  }

  void _openFavoritesSheet() {
    final favoriteTemplates = _templates.where((t) => t.isFavorite).toList();
    FavoritesSheet.show(
      context,
      favoriteTemplates: favoriteTemplates,
      onAddFavoritesPressed: () {
        setState(() => _currentIndex = 2); // Switch to Templates Tab
      },
      onTemplateSelected: _openEditorWithTemplate,
    );
  }

  void _toggleTemplateFavorite(JournalTemplate template) {
    setState(() {
      template.isFavorite = !template.isFavorite;
    });
  }

  void _toggleJournalFavorite(JournalItem journal) {
    setState(() {
      journal.isFavorite = !journal.isFavorite;
    });
  }

  void _openEditorWithTemplate(JournalTemplate template) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => JournalEditorScreen(
          template: template,
          onSave: (newJournal) {
            setState(() {
              _journals.insert(0, newJournal);
              _currentIndex = 0;
            });
          },
        ),
      ),
    );
  }

  void _openEditorWithPageStyle(PageStyleConfig pageStyle) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => JournalEditorScreen(
          pageStyle: pageStyle,
          onSave: (newJournal) {
            setState(() {
              _journals.insert(0, newJournal);
              _currentIndex = 0;
            });
          },
        ),
      ),
    );
  }

  void _openEditorWithJournal(JournalItem journal) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => JournalEditorScreen(
          existingJournal: journal,
          onSave: (updatedJournal) {
            setState(() {
              final index = _journals.indexWhere((j) => j.id == updatedJournal.id);
              if (index != -1) {
                _journals[index] = updatedJournal;
              }
            });
          },
        ),
      ),
    );
  }

  void _openProTemplateBuilder() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProTemplateBuilderScreen(
          onJournalCreated: (newJournal) {
            setState(() {
              _journals.insert(0, newJournal);
              _currentIndex = 0;
            });
          },
        ),
      ),
    );
  }

  void _showCreateModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SafeArea(
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Text(
                      'ایجاد ژورنال یا قالب جدید',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                    ProBadge(),
                  ],
                ),
                const SizedBox(height: 16),

                // Option 1: AI Vision Pro Template Builder
                Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFF1EB), Color(0xFFFFE3D8)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFFFCCBC), width: 1.5),
                  ),
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF7043),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.auto_awesome_rounded, color: Colors.white),
                    ),
                    title: const Row(
                      children: [
                        Text('ساخت قالب حرفه‌ای', style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFFBF360C))),
                        SizedBox(width: 6),
                        Text('(هوش مصنوعی)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFFF7043))),
                      ],
                    ),
                    subtitle: const Text('آپلود تصویر ژورنال و تعیین خودکار تمام باکس‌های متن با AI Vision'),
                    trailing: const Icon(Icons.chevron_left_rounded, size: 22, color: Color(0xFFBF360C)),
                    onTap: () {
                      Navigator.pop(context);
                      _openProTemplateBuilder();
                    },
                  ),
                ),
                const SizedBox(height: 10),

                // Option 2: Choose Page Style
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEBE5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.draw_rounded, color: Color(0xFFFF7043)),
                  ),
                  title: const Text('ساخت برگه با سبک دلخواه', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('انتخاب ابعاد، خط‌دار، شطرنجی، کورنل و رنگ کاغذ'),
                  trailing: const Icon(Icons.chevron_left_rounded, size: 22),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() => _currentIndex = 1);
                  },
                ),
                const SizedBox(height: 8),

                // Option 3: Ready Templates
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.style_rounded, color: AppTheme.primaryColor),
                  ),
                  title: const Text('انتخاب از بین قالب‌های آماده', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('قالب‌های روزانه، ADHD، بولت ژورنال و خاطرات'),
                  trailing: const Icon(Icons.chevron_left_rounded, size: 22),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() => _currentIndex = 2);
                  },
                ),
                const SizedBox(height: 8),

                // Option 4: Quick Blank Page
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.create_rounded, color: Color(0xFF2E7D32)),
                  ),
                  title: const Text('صفحه سفید سریع', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('شروع نوشتن بدون قالب و خط‌کشی'),
                  trailing: const Icon(Icons.chevron_left_rounded, size: 22),
                  onTap: () {
                    Navigator.pop(context);
                    _openEditorWithPageStyle(PageStyleConfig());
                  },
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.settings_rounded, color: AppTheme.primaryColor),
            SizedBox(width: 10),
            Text('تنظیمات برنامه'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(widget.isDarkMode ? Icons.dark_mode_rounded : Icons.light_mode_rounded),
              title: const Text('حالت شب (Dark Mode)'),
              trailing: Switch(
                value: widget.isDarkMode,
                onChanged: (_) {
                  Navigator.pop(context);
                  widget.onToggleTheme();
                },
                activeColor: AppTheme.primaryColor,
              ),
            ),
            const Divider(),
            const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.language_rounded),
              title: Text('زبان برنامه'),
              trailing: Text('فارسی (پیش‌فرض)', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('بستن'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      // 0: My Journals
      MyJournalsScreen(
        journals: _journals,
        onJournalSelected: _openEditorWithJournal,
        onFavoriteToggle: _toggleJournalFavorite,
        onUpgradePressed: () => _openEditorWithTemplate(_templates[1]),
      ),
      // 1: Choose Page Style (ساخت برگه)
      ChoosePageStyleScreen(
        onBeginPlanner: _openEditorWithPageStyle,
        onClose: () => setState(() => _currentIndex = 0),
      ),
      // 2: Templates
      TemplatesScreen(
        templates: _templates,
        onTemplateSelected: _openEditorWithTemplate,
        onFavoriteToggle: _toggleTemplateFavorite,
        onProBuilderPressed: _openProTemplateBuilder,
      ),
      // 3: Search & Tags
      SearchScreen(
        templates: _templates,
        journals: _journals,
        onTemplateSelected: _openEditorWithTemplate,
        onJournalSelected: _openEditorWithJournal,
        onFavoriteToggle: _toggleTemplateFavorite,
      ),
    ];

    final isWide = ResponsiveLayout.isDesktop(context) || ResponsiveLayout.isTablet(context);

    return Scaffold(
      appBar: isWide
          ? null
          : CustomAppBar(
              title: _currentIndex == 1 ? 'ساخت برگه' : (_currentIndex == 2 ? 'قالب‌ها' : (_currentIndex == 3 ? 'جستجو' : 'ژورنال')),
              onFavoritesPressed: _openFavoritesSheet,
              onSettingsPressed: _showSettingsDialog,
              onSearchPressed: () => setState(() => _currentIndex = 3),
            ),
      body: Row(
        children: [
          // Sidebar on Tablet & Desktop
          if (isWide)
            CustomNavigationRailBar(
              currentIndex: _currentIndex,
              onDestinationSelected: _onTabSelected,
              onCreatePressed: _showCreateModal,
            ),

          // Active Screen
          Expanded(
            child: IndexedStack(
              index: _currentIndex < 4 ? _currentIndex : 0,
              children: screens,
            ),
          ),
        ],
      ),
      bottomNavigationBar: isWide
          ? null
          : CustomBottomNavBar(
              currentIndex: _currentIndex,
              onTap: _onTabSelected,
              onCreatePressed: _showCreateModal,
            ),
    );
  }
}


