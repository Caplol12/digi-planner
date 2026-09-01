import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/notebook_model.dart';
import 'notebook_cover_widget.dart';
import 'planner_context_menu.dart';

class NotebookCard extends StatelessWidget {
  final NotebookModel notebook;
  final VoidCallback onTap;
  final VoidCallback onEditTap;
  final VoidCallback onFavoriteToggle;
  final VoidCallback onDelete;
  final VoidCallback? onDuplicate;
  final VoidCallback? onSaveToGallery;
  final VoidCallback? onSavePdf;
  final VoidCallback? onPrint;
  final VoidCallback? onShare;
  final VoidCallback? onExport;
  final VoidCallback? onSetToWidget;
  final VoidCallback? onAddToBook;
  final VoidCallback? onAddToFolder;

  const NotebookCard({
    super.key,
    required this.notebook,
    required this.onTap,
    required this.onEditTap,
    required this.onFavoriteToggle,
    required this.onDelete,
    this.onDuplicate,
    this.onSaveToGallery,
    this.onSavePdf,
    this.onPrint,
    this.onShare,
    this.onExport,
    this.onSetToWidget,
    this.onAddToBook,
    this.onAddToFolder,
  });

  void _openContextMenu(BuildContext context) {
    PlannerContextMenu.show(
      context,
      onEdit: onEditTap,
      onSaveToGallery: onSaveToGallery,
      onSavePdf: onSavePdf,
      onPrint: onPrint,
      onShare: onShare,
      onExport: onExport,
      onSetToWidget: onSetToWidget,
      onDuplicate: onDuplicate,
      onAddToBook: onAddToBook,
      onAddToFolder: onAddToFolder,
      onDelete: onDelete,
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy/MM/dd');
    final formattedDate = dateFormat.format(notebook.updatedAt);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(14.0),
            child: Row(
              children: [
                // Notebook 3D Cover Mockup
                NotebookCoverWidget(
                  title: notebook.title,
                  coverColor: notebook.coverColor,
                  coverImagePath: notebook.coverImagePath,
                  width: 82,
                  height: 114,
                  elevation: 6,
                  showLabel: false,
                ),
                const SizedBox(width: 16),

                // Notebook Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              notebook.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.vazirmatn(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF1E293B),
                              ),
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              notebook.isFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
                              color: notebook.isFavorite ? Colors.amber.shade700 : Colors.grey.shade400,
                              size: 22,
                            ),
                            onPressed: onFavoriteToggle,
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // Page Count & Info Badges
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFEBE5),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${notebook.pages.length} برگه',
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFBF360C),
                              ),
                            ),
                          ),
                          if (notebook.folderName != null && notebook.folderName!.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE0F2FE),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.folder_outlined, size: 12, color: Color(0xFF0369A1)),
                                  const SizedBox(width: 3),
                                  Text(
                                    notebook.folderName!,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF0369A1),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.access_time_rounded, size: 13, color: Colors.grey.shade500),
                              const SizedBox(width: 4),
                              Text(
                                formattedDate,
                                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Actions Row: Edit Cover + PlanWiz Context Menu (···)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          InkWell(
                            onTap: onEditTap,
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.edit_note_rounded, size: 16, color: Colors.grey.shade700),
                                  const SizedBox(width: 4),
                                  Text(
                                    'ویرایش جلد',
                                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.grey.shade800),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          InkWell(
                            onTap: () => _openContextMenu(context),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: const Icon(
                                Icons.more_horiz_rounded,
                                size: 18,
                                color: Color(0xFF475569),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
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
