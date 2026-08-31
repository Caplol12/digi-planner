import 'package:flutter/material.dart';
import '../models/journal_model.dart';
import '../widgets/journal_card.dart';
import '../theme/app_theme.dart';
import '../widgets/responsive_layout.dart';

class MyJournalsScreen extends StatefulWidget {
  final List<JournalItem> journals;
  final Function(JournalItem) onJournalSelected;
  final Function(JournalItem) onFavoriteToggle;
  final VoidCallback onUpgradePressed;

  const MyJournalsScreen({
    super.key,
    required this.journals,
    required this.onJournalSelected,
    required this.onFavoriteToggle,
    required this.onUpgradePressed,
  });

  @override
  State<MyJournalsScreen> createState() => _MyJournalsScreenState();
}

class _MyJournalsScreenState extends State<MyJournalsScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _showScrollToTop = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.offset > 200 && !_showScrollToTop) {
        setState(() => _showScrollToTop = true);
      } else if (_scrollController.offset <= 200 && _showScrollToTop) {
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
    final journals = widget.journals;

    return Stack(
      children: [
        journals.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.menu_book_rounded, size: 64, color: Colors.grey.shade400),
                    const SizedBox(height: 16),
                    const Text(
                      'هنوز ژورنالی نساخته‌اید',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'برای شروع، یک قالب انتخاب کنید یا دکمه + را بزنید.',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              )
            : ResponsiveLayout.isDesktop(context) || ResponsiveLayout.isTablet(context)
                ? GridView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.only(left: 20, right: 20, top: 16, bottom: 120),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: ResponsiveLayout.getGridColumnCount(context, tabletCount: 2, desktopCount: 3),
                      childAspectRatio: 1.1,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    itemCount: journals.length,
                    itemBuilder: (context, index) {
                      final journal = journals[index];
                      return JournalCard(
                        journal: journal,
                        onTap: () => widget.onJournalSelected(journal),
                        onFavoriteToggle: () => widget.onFavoriteToggle(journal),
                      );
                    },
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.only(top: 8, bottom: 140),
                    itemCount: journals.length,
                    itemBuilder: (context, index) {
                      final journal = journals[index];
                      return JournalCard(
                        journal: journal,
                        onTap: () => widget.onJournalSelected(journal),
                        onFavoriteToggle: () => widget.onFavoriteToggle(journal),
                      );
                    },
                  ),

        // Scroll to top button (Matching screenshots 3, 4, 5)
        if (_showScrollToTop)
          Positioned(
            right: 20,
            bottom: 110,
            child: FloatingActionButton.small(
              heroTag: 'scroll_top_journals',
              onPressed: _scrollToTop,
              backgroundColor: Colors.white,
              foregroundColor: AppTheme.primaryColor,
              elevation: 4,
              child: const Icon(Icons.keyboard_arrow_up_rounded, size: 24),
            ),
          ),

        // Upgrade Banner Card (Matching screenshots 3 and 4)
        Positioned(
          left: 16,
          right: 16,
          bottom: 12,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.dividerLight, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 20,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${journals.length} از ۳ ژورنال ساخته شده است',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimaryLight,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'برای ساخت نامحدود، به نسخه ویژه ارتقا دهید.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton(
                    onPressed: widget.onUpgradePressed,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.auto_awesome_rounded, size: 18),
                          SizedBox(width: 8),
                          Text('ارتقا به نسخه ویژه', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
