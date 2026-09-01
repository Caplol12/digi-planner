import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/notebook_model.dart';
import '../widgets/notebook_card.dart';
import '../widgets/responsive_layout.dart';
import '../theme/app_theme.dart';

class MyJournalsScreen extends StatefulWidget {
  final List<NotebookModel> notebooks;
  final Function(NotebookModel) onNotebookSelected;
  final Function(NotebookModel) onEditNotebook;
  final Function(NotebookModel) onFavoriteToggle;
  final Function(NotebookModel) onDeleteNotebook;
  final Function(NotebookModel)? onDuplicateNotebook;
  final Function(NotebookModel)? onSaveToGallery;
  final Function(NotebookModel)? onSavePdf;
  final Function(NotebookModel)? onPrint;
  final Function(NotebookModel)? onShare;
  final Function(NotebookModel)? onExport;
  final Function(NotebookModel)? onSetToWidget;
  final Function(NotebookModel)? onAddToBook;
  final Function(NotebookModel)? onAddToFolder;
  final VoidCallback onAddNewNotebook;

  const MyJournalsScreen({
    super.key,
    required this.notebooks,
    required this.onNotebookSelected,
    required this.onEditNotebook,
    required this.onFavoriteToggle,
    required this.onDeleteNotebook,
    this.onDuplicateNotebook,
    this.onSaveToGallery,
    this.onSavePdf,
    this.onPrint,
    this.onShare,
    this.onExport,
    this.onSetToWidget,
    this.onAddToBook,
    this.onAddToFolder,
    required this.onAddNewNotebook,
  });

  @override
  State<MyJournalsScreen> createState() => _MyJournalsScreenState();
}

class _MyJournalsScreenState extends State<MyJournalsScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _showScrollToTop = false;
  String _selectedFolder = 'همه';

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

  List<String> _getAvailableFolders() {
    final set = <String>{'همه'};
    for (final nb in widget.notebooks) {
      if (nb.folderName != null && nb.folderName!.isNotEmpty) {
        set.add(nb.folderName!);
      }
    }
    return set.toList();
  }

  @override
  Widget build(BuildContext context) {
    final availableFolders = _getAvailableFolders();
    final filteredNotebooks = _selectedFolder == 'همه'
        ? widget.notebooks
        : widget.notebooks.where((nb) => nb.folderName == _selectedFolder).toList();

    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Folder Filter Bar (Only if folders exist)
            if (availableFolders.length > 1)
              Container(
                height: 46,
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: availableFolders.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, idx) {
                    final folder = availableFolders[idx];
                    final isSelected = _selectedFolder == folder;
                    return ChoiceChip(
                      label: Text(folder),
                      selected: isSelected,
                      selectedColor: const Color(0xFFFF7043),
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : const Color(0xFF334155),
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        fontSize: 12,
                      ),
                      backgroundColor: Colors.white,
                      side: BorderSide(
                        color: isSelected ? const Color(0xFFFF7043) : const Color(0xFFCBD5E1),
                      ),
                      onSelected: (_) {
                        setState(() => _selectedFolder = folder);
                      },
                    );
                  },
                ),
              ),

            // Content Area
            Expanded(
              child: filteredNotebooks.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              decoration: const BoxDecoration(
                                color: Color(0xFFFFEBE5),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.menu_book_rounded, size: 40, color: Color(0xFFFF7043)),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              widget.notebooks.isEmpty ? 'هنوز دفترچه‌ای نساخته‌اید' : 'دفترچه‌ای در این پوشه یافت نشد',
                              style: GoogleFonts.vazirmatn(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              widget.notebooks.isEmpty
                                  ? 'برای شروع ثبت برنامه‌ها و یادداشت‌ها، اولین دفترچه خود را ایجاد کنید.'
                                  : 'می‌توانید با دکمه ··· روی هر دفترچه، آن را به این پوشه اضافه کنید.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                            ),
                            const SizedBox(height: 24),
                            if (widget.notebooks.isEmpty)
                              ElevatedButton.icon(
                                onPressed: widget.onAddNewNotebook,
                                icon: const Icon(Icons.add_rounded),
                                label: const Text('ایجاد دفترچه جدید', style: TextStyle(fontWeight: FontWeight.bold)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFFF7043),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                          ],
                        ),
                      ),
                    )
                  : ResponsiveLayout.isDesktop(context) || ResponsiveLayout.isTablet(context)
                      ? GridView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.only(left: 20, right: 20, top: 16, bottom: 80),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: ResponsiveLayout.getGridColumnCount(context, tabletCount: 2, desktopCount: 3),
                            childAspectRatio: 2.1,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                          ),
                          itemCount: filteredNotebooks.length,
                          itemBuilder: (context, index) {
                            final nb = filteredNotebooks[index];
                            return NotebookCard(
                              notebook: nb,
                              onTap: () => widget.onNotebookSelected(nb),
                              onEditTap: () => widget.onEditNotebook(nb),
                              onFavoriteToggle: () => widget.onFavoriteToggle(nb),
                              onDelete: () => widget.onDeleteNotebook(nb),
                              onDuplicate: () => widget.onDuplicateNotebook?.call(nb),
                              onSaveToGallery: () => widget.onSaveToGallery?.call(nb),
                              onSavePdf: () => widget.onSavePdf?.call(nb),
                              onPrint: () => widget.onPrint?.call(nb),
                              onShare: () => widget.onShare?.call(nb),
                              onExport: () => widget.onExport?.call(nb),
                              onSetToWidget: () => widget.onSetToWidget?.call(nb),
                              onAddToBook: () => widget.onAddToBook?.call(nb),
                              onAddToFolder: () => widget.onAddToFolder?.call(nb),
                            );
                          },
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.only(top: 8, bottom: 80),
                          itemCount: filteredNotebooks.length,
                          itemBuilder: (context, index) {
                            final nb = filteredNotebooks[index];
                            return NotebookCard(
                              notebook: nb,
                              onTap: () => widget.onNotebookSelected(nb),
                              onEditTap: () => widget.onEditNotebook(nb),
                              onFavoriteToggle: () => widget.onFavoriteToggle(nb),
                              onDelete: () => widget.onDeleteNotebook(nb),
                              onDuplicate: () => widget.onDuplicateNotebook?.call(nb),
                              onSaveToGallery: () => widget.onSaveToGallery?.call(nb),
                              onSavePdf: () => widget.onSavePdf?.call(nb),
                              onPrint: () => widget.onPrint?.call(nb),
                              onShare: () => widget.onShare?.call(nb),
                              onExport: () => widget.onExport?.call(nb),
                              onSetToWidget: () => widget.onSetToWidget?.call(nb),
                              onAddToBook: () => widget.onAddToBook?.call(nb),
                              onAddToFolder: () => widget.onAddToFolder?.call(nb),
                            );
                          },
                        ),
            ),
          ],
        ),

        // Scroll to top button
        if (_showScrollToTop)
          Positioned(
            right: 20,
            bottom: 80,
            child: FloatingActionButton.small(
              heroTag: 'scroll_top_notebooks',
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
