import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/notebook_model.dart';
import '../models/template_model.dart';
import '../services/notebook_storage_service.dart';
import '../services/notebook_export_service.dart';
import '../widgets/paper_pattern_painter.dart';
import '../widgets/edit_notebook_dialog.dart';
import '../widgets/planner_context_menu.dart';
import '../widgets/responsive_layout.dart';
import 'choose_page_style_screen.dart';
import 'notebook_page_flip_screen.dart';

class NotebookDetailScreen extends StatefulWidget {
  final NotebookModel notebook;
  final Function(NotebookModel) onNotebookUpdated;
  final VoidCallback onNotebookDeleted;

  const NotebookDetailScreen({
    super.key,
    required this.notebook,
    required this.onNotebookUpdated,
    required this.onNotebookDeleted,
  });

  @override
  State<NotebookDetailScreen> createState() => _NotebookDetailScreenState();
}

class _NotebookDetailScreenState extends State<NotebookDetailScreen> {
  late NotebookModel _notebook;

  @override
  void initState() {
    super.initState();
    _notebook = widget.notebook;
  }

  void _saveNotebook() {
    NotebookStorageService.instance.saveOrUpdateNotebook(_notebook);
    widget.onNotebookUpdated(_notebook);
    setState(() {});
  }

  void _openPageFlipAt(int index) async {
    final updated = await Navigator.push<NotebookModel>(
      context,
      MaterialPageRoute(
        builder: (context) => NotebookPageFlipScreen(
          notebook: _notebook,
          initialPageIndex: index,
          onNotebookChanged: (newNb) {
            setState(() => _notebook = newNb);
          },
        ),
      ),
    );

    if (updated != null) {
      setState(() => _notebook = updated);
      widget.onNotebookUpdated(_notebook);
    }
  }

  void _addNewBlankPage() {
    final newPage = NotebookPageModel(
      id: 'p_${DateTime.now().millisecondsSinceEpoch}',
      title: 'برگه ${_notebook.pages.length + 1}',
    );

    setState(() {
      _notebook.pages.add(newPage);
    });
    _saveNotebook();

    // Directly open the newly created page
    _openPageFlipAt(_notebook.pages.length - 1);
  }

  void _editNotebookCover() {
    EditNotebookDialog.show(
      context,
      notebook: _notebook,
      onSave: (updated) {
        setState(() => _notebook = updated);
        _saveNotebook();
      },
    );
  }

  void _openPageStyleSelectorFor(NotebookPageModel page) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChoosePageStyleScreen(
          onBeginPlanner: (newStyle) {
            Navigator.pop(context);
            setState(() {
              page.applyPageStyle(newStyle);
            });
            _saveNotebook();
          },
          onClose: () => Navigator.pop(context),
        ),
      ),
    );
  }

  void _openTemplatePickerFor(NotebookPageModel page) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
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
            Text(
              'انتخاب قالب برای این برگه',
              style: GoogleFonts.vazirmatn(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'یکی از قالب‌های آماده زیر را انتخاب کنید:',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.separated(
                itemCount: JournalTemplate.sampleTemplates.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, idx) {
                  final tmpl = JournalTemplate.sampleTemplates[idx];
                  return ListTile(
                    contentPadding: const EdgeInsets.all(10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(color: Colors.grey.shade200),
                    ),
                    tileColor: tmpl.cardBackground,
                    leading: Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: tmpl.themeColor.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(tmpl.icon, color: tmpl.themeColor),
                    ),
                    title: Text(tmpl.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                    subtitle: Text(tmpl.subtitle, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                    trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                    onTap: () {
                      Navigator.pop(context);
                      setState(() {
                        // Reset all previous style/dimensions and load original template
                        page.applyTemplate(tmpl);
                      });
                      _saveNotebook();
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _renamePage(NotebookPageModel page) {
    final renameCtrl = TextEditingController(text: page.title);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('تغییر نام برگه', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: renameCtrl,
          decoration: const InputDecoration(hintText: 'عنوان برگه', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('انصراف')),
          ElevatedButton(
            onPressed: () {
              if (renameCtrl.text.trim().isNotEmpty) {
                setState(() => page.title = renameCtrl.text.trim());
                _saveNotebook();
              }
              Navigator.pop(context);
            },
            child: const Text('ذخیره'),
          ),
        ],
      ),
    );
  }

  void _deletePageAt(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('حذف برگه', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: const Text('آیا از حذف این برگه مطمئن هستید؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('انصراف')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade600, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _notebook.pages.removeAt(index);
              });
              _saveNotebook();
            },
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportNotebookToJson() async {
    try {
      final file = await NotebookExportService.instance.exportNotebookToJson(_notebook);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✨ فایل لایه‌باز JSON دفترچه ذخیره شد:\n${file.path}'),
            backgroundColor: const Color(0xFF2E7D32),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطا در خروجی گرفتن: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _importJsonToNotebook() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final bytes = result.files.first.bytes;
        final fileStr = bytes != null ? utf8.decode(bytes) : await File(result.files.first.path!).readAsString();
        final importRes = NotebookExportService.instance.importPackageFromJson(fileStr);

        if (importRes.isSuccess) {
          setState(() {
            if (importRes.page != null) {
              _notebook.pages.add(importRes.page!);
            } else if (importRes.pages != null && importRes.pages!.isNotEmpty) {
              _notebook.pages.addAll(importRes.pages!);
            } else if (importRes.notebook != null) {
              _notebook.pages.addAll(importRes.notebook!.pages);
            }
          });
          _saveNotebook();

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(importRes.message), backgroundColor: const Color(0xFF2E7D32)),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(importRes.message), backgroundColor: Colors.red),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطا در بارگذاری فایل JSON: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _deleteNotebook() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('حذف دفترچه', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Text('آیا از حذف کل دفترچه «${_notebook.title}» و همه برگه‌های آن اطمینان دارید؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('انصراف')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade600, foregroundColor: Colors.white),
            onPressed: () async {
              final nav = Navigator.of(context);
              nav.pop(); // close dialog
              await NotebookStorageService.instance.deleteNotebook(_notebook.id);
              if (!mounted) return;
              widget.onNotebookDeleted();
              nav.pop(); // back to home
            },
            child: const Text('حذف قطعی'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalGridItems = _notebook.pages.length + 1; // Existing pages + "Create New" card

    return Scaffold(
      backgroundColor: const Color(0xFFFAFBFD),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: InkWell(
            onTap: () => Navigator.pop(context, _notebook),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: Color(0xFF1E293B)),
            ),
          ),
        ),
        actions: [
          // Import JSON Button
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 2.0),
            child: InkWell(
              onTap: _importJsonToNotebook,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFE3F2FD),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFBBDEFB)),
                ),
                child: const Icon(Icons.file_download_outlined, size: 20, color: Color(0xFF1565C0)),
              ),
            ),
          ),

          // Export JSON Button
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 2.0),
            child: InkWell(
              onTap: _exportNotebookToJson,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFC8E6C9)),
                ),
                child: const Icon(Icons.file_upload_outlined, size: 20, color: Color(0xFF2E7D32)),
              ),
            ),
          ),

          // Edit Notebook Cover Button
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
            child: InkWell(
              onTap: _editNotebookCover,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEBE5),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFFCCBC)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.color_lens_outlined, size: 16, color: Color(0xFFFF7043)),
                    const SizedBox(width: 4),
                    Text(
                      'ویرایش جلد',
                      style: GoogleFonts.vazirmatn(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFFBF360C)),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Add Page (+) Icon Button (Image 2)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
            child: InkWell(
              onTap: _addNewBlankPage,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: 38,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: const Icon(Icons.add_rounded, size: 22, color: Color(0xFF1E293B)),
              ),
            ),
          ),

          // More Options Menu (...) (Image 2 - PlanWiz 10-options context menu)
          Padding(
            padding: const EdgeInsets.only(top: 8.0, bottom: 8.0, left: 8.0, right: 4.0),
            child: InkWell(
              onTap: () {
                PlannerContextMenu.show(
                  context,
                  onEdit: _editNotebookCover,
                  onDelete: _deleteNotebook,
                );
              },
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: const Icon(Icons.more_horiz_rounded, size: 20, color: Color(0xFF1E293B)),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Notebook Title Header (Image 2)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _notebook.title,
                    style: GoogleFonts.vazirmatn(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_notebook.pages.length} برگه',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade700),
                  ),
                ),
              ],
            ),
          ),

          // 2-Column Pages Grid (Image 2)
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: ResponsiveLayout.getGridColumnCount(context, mobileCount: 2, tabletCount: 3, desktopCount: 4),
                childAspectRatio: 0.68,
                crossAxisSpacing: 14,
                mainAxisSpacing: 16,
              ),
              itemCount: totalGridItems,
              itemBuilder: (context, index) {
                // Last item is the Dashed "Create New" Card (Image 2)
                if (index == _notebook.pages.length) {
                  return _buildCreateNewCard();
                }

                final page = _notebook.pages[index];
                return _buildPageCard(page, index);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPageCard(NotebookPageModel page, int index) {
    return GestureDetector(
      onTap: () => _openPageFlipAt(index),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.07),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // Page Preview Content
            Positioned.fill(
              child: page.template != null
                  ? _buildTemplateThumbnail(page.template!)
                  : PaperPatternWidget(
                      config: page.pageStyle,
                      isThumbnail: true,
                      child: (page.noteTitle.isNotEmpty || page.noteBody.isNotEmpty)
                          ? Padding(
                              padding: const EdgeInsets.all(10.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (page.noteTitle.isNotEmpty)
                                    Text(
                                      page.noteTitle,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                  if (page.noteBody.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4.0),
                                      child: Text(
                                        page.noteBody,
                                        maxLines: 5,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(fontSize: 9, color: Colors.grey.shade700, height: 1.3),
                                      ),
                                    ),
                                ],
                              ),
                            )
                          : null,
                    ),
            ),

            // Page Number Badge (Top-left)
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ),

            // Floating 3-Dots Menu Button (...) (Bottom-right, exact Image 2 style)
            Positioned(
              right: 8,
              bottom: 8,
              child: PopupMenuButton<String>(
                icon: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.more_horiz_rounded, size: 18, color: Color(0xFF475569)),
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                onSelected: (val) {
                  switch (val) {
                    case 'open':
                      _openPageFlipAt(index);
                      break;
                    case 'style':
                      _openPageStyleSelectorFor(page);
                      break;
                    case 'template':
                      _openTemplatePickerFor(page);
                      break;
                    case 'rename':
                      _renamePage(page);
                      break;
                    case 'delete':
                      _deletePageAt(index);
                      break;
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'open',
                    child: Row(
                      children: [
                        Icon(Icons.fullscreen_rounded, size: 18, color: Color(0xFFFF7043)),
                        SizedBox(width: 10),
                        Text('ورود به حالت ورق زدن', style: TextStyle(fontSize: 12.5)),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'style',
                    child: Row(
                      children: [
                        Icon(Icons.tune_rounded, size: 18, color: Color(0xFF1976D2)),
                        SizedBox(width: 10),
                        Text('تنظیم استایل برگه', style: TextStyle(fontSize: 12.5)),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'template',
                    child: Row(
                      children: [
                        Icon(Icons.dashboard_customize_outlined, size: 18, color: Color(0xFF2E7D32)),
                        SizedBox(width: 10),
                        Text('وارد کردن قالب', style: TextStyle(fontSize: 12.5)),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'rename',
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined, size: 18, color: Color(0xFF546E7A)),
                        SizedBox(width: 10),
                        Text('تغییر نام', style: TextStyle(fontSize: 12.5)),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
                        SizedBox(width: 10),
                        Text('حذف برگه', style: TextStyle(fontSize: 12.5, color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTemplateThumbnail(JournalTemplate tmpl) {
    if (tmpl.imageAsset != null && tmpl.imageAsset!.isNotEmpty) {
      return Center(
        child: AspectRatio(
          aspectRatio: tmpl.aspectRatio,
          child: Image.asset(tmpl.imageAsset!, fit: BoxFit.contain),
        ),
      );
    }
    return Container(
      color: tmpl.cardBackground,
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(tmpl.icon, size: 36, color: tmpl.themeColor),
          const SizedBox(height: 8),
          Text(
            tmpl.title,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: tmpl.themeColor),
          ),
        ],
      ),
    );
  }

  // Dashed "Create New" Card (Exact Image 2 style)
  Widget _buildCreateNewCard() {
    return GestureDetector(
      onTap: _addNewBlankPage,
      child: CustomPaint(
        painter: _DashedBorderPainter(
          color: const Color(0xFF94A3B8),
          strokeWidth: 1.6,
          dashLength: 6,
          gapLength: 4,
          borderRadius: 16,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF64748B), width: 1.8),
                ),
                child: const Center(
                  child: Icon(Icons.add_rounded, size: 26, color: Color(0xFF475569)),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Create New',
                style: GoogleFonts.vazirmatn(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF475569),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'برگه جدید',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Custom Painter for clean Dashed Border without external dependencies
class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double dashLength;
  final double gapLength;
  final double borderRadius;

  _DashedBorderPainter({
    required this.color,
    required this.strokeWidth,
    required this.dashLength,
    required this.gapLength,
    required this.borderRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        strokeWidth / 2,
        strokeWidth / 2,
        size.width - strokeWidth,
        size.height - strokeWidth,
      ),
      Radius.circular(borderRadius),
    );

    final path = Path()..addRRect(rrect);
    final metrics = path.computeMetrics();

    for (final metric in metrics) {
      double distance = 0.0;
      while (distance < metric.length) {
        final nextDistance = distance + dashLength;
        canvas.drawPath(
          metric.extractPath(distance, nextDistance.clamp(0.0, metric.length)),
          paint,
        );
        distance += dashLength + gapLength;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.borderRadius != borderRadius;
  }
}
