import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/notebook_model.dart';
import '../models/template_model.dart';
import '../models/page_style_model.dart';
import '../services/notebook_storage_service.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/navigation_rail_bar.dart';
import '../widgets/responsive_layout.dart';
import '../widgets/favorites_sheet.dart';
import '../widgets/edit_notebook_dialog.dart';
import 'my_journals_screen.dart';
import 'notebook_detail_screen.dart';
import 'choose_page_style_screen.dart';
import 'templates_screen.dart';
import 'pro_template_builder_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/notebook_export_service.dart';
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
  List<NotebookModel> _notebooks = [];
  final List<JournalTemplate> _templates = List.from(JournalTemplate.sampleTemplates);
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotebooks();
  }

  Future<void> _loadNotebooks() async {
    final list = await NotebookStorageService.instance.loadNotebooks();
    final customTmpls = await NotebookStorageService.instance.loadCustomTemplates();
    if (mounted) {
      setState(() {
        _notebooks = list;
        for (final ct in customTmpls) {
          if (!_templates.any((t) => t.id == ct.id)) {
            _templates.insert(0, ct);
          }
        }
        _isLoading = false;
      });
    }
  }

  Future<void> _importJsonPackage() async {
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
            if (importRes.notebook != null) {
              _notebooks.insert(0, importRes.notebook!);
              NotebookStorageService.instance.saveNotebooks(_notebooks);
            }
            if (importRes.notebooks != null && importRes.notebooks!.isNotEmpty) {
              for (final nb in importRes.notebooks!) {
                if (!_notebooks.any((n) => n.id == nb.id)) {
                  _notebooks.insert(0, nb);
                }
              }
              NotebookStorageService.instance.saveNotebooks(_notebooks);
            }
            if (importRes.template != null) {
              _templates.insert(0, importRes.template!);
              NotebookStorageService.instance.saveOrUpdateCustomTemplate(importRes.template!);
            }
            if (importRes.templates != null && importRes.templates!.isNotEmpty) {
              for (final tmpl in importRes.templates!) {
                if (!_templates.any((t) => t.id == tmpl.id)) {
                  _templates.insert(0, tmpl);
                }
                NotebookStorageService.instance.saveOrUpdateCustomTemplate(tmpl);
              }
            }
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('✨ ${importRes.message}'),
                backgroundColor: const Color(0xFF2E7D32),
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 4),
              ),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(importRes.message),
                backgroundColor: Colors.red,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطا در بارگذاری فایل JSON: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _onTabSelected(int index) {
    if (index == 2) {
      // Open Favorites Sheet (from Rail)
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
        setState(() => _currentIndex = 1); // Switch to Templates Tab
      },
      onTemplateSelected: _openEditorWithTemplate,
    );
  }

  void _toggleTemplateFavorite(JournalTemplate template) {
    setState(() {
      template.isFavorite = !template.isFavorite;
    });
  }

  void _toggleNotebookFavorite(NotebookModel notebook) {
    setState(() {
      notebook.isFavorite = !notebook.isFavorite;
    });
    NotebookStorageService.instance.saveNotebooks(_notebooks);
  }

  void _openNotebookDetail(NotebookModel notebook) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NotebookDetailScreen(
          notebook: notebook,
          onNotebookUpdated: (updated) {
            setState(() {
              final idx = _notebooks.indexWhere((n) => n.id == updated.id);
              if (idx != -1) {
                _notebooks[idx] = updated;
              }
            });
            NotebookStorageService.instance.saveNotebooks(_notebooks);
          },
          onNotebookDeleted: () {
            setState(() {
              _notebooks.removeWhere((n) => n.id == notebook.id);
            });
          },
        ),
      ),
    );
  }

  void _openEditNotebook(NotebookModel notebook) {
    EditNotebookDialog.show(
      context,
      notebook: notebook,
      onSave: (updated) {
        setState(() {
          final idx = _notebooks.indexWhere((n) => n.id == updated.id);
          if (idx != -1) {
            _notebooks[idx] = updated;
          }
        });
        NotebookStorageService.instance.saveNotebooks(_notebooks);
      },
    );
  }

  void _createNewNotebook() {
    EditNotebookDialog.show(
      context,
      onSave: (newNb) {
        setState(() {
          _notebooks.insert(0, newNb);
          _currentIndex = 0;
        });
        NotebookStorageService.instance.saveNotebooks(_notebooks);
        _openNotebookDetail(newNb);
      },
    );
  }

  void _deleteNotebook(NotebookModel notebook) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('حذف دفترچه', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Text('آیا از حذف دفترچه «${notebook.title}» مطمئن هستید؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('انصراف')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade600, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _notebooks.removeWhere((n) => n.id == notebook.id);
              });
              NotebookStorageService.instance.saveNotebooks(_notebooks);
            },
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }

  void _duplicateNotebook(NotebookModel notebook) {
    final duplicated = NotebookModel(
      id: 'nb_${DateTime.now().millisecondsSinceEpoch}',
      title: '${notebook.title} (کپی)',
      coverColor: notebook.coverColor,
      coverImagePath: notebook.coverImagePath,
      pages: notebook.pages
          .map((p) => p.copyWith(id: 'p_${DateTime.now().millisecondsSinceEpoch}_${p.id}'))
          .toList(),
      isFavorite: notebook.isFavorite,
    );

    setState(() {
      _notebooks.insert(0, duplicated);
    });
    NotebookStorageService.instance.saveNotebooks(_notebooks);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('نسخه کپی از «${notebook.title}» ساخته شد.'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _saveNotebookToGallery(NotebookModel notebook) {
    _saveNotebookPdf(notebook);
  }

  Future<void> _saveNotebookPdf(NotebookModel notebook) async {
    try {
      final res = await NotebookExportService.instance.exportHtmlPrintableDocument(notebook);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res.userMessage),
            backgroundColor: res.isSuccess ? const Color(0xFF2E7D32) : Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطا در صدور سند: $e')),
        );
      }
    }
  }

  void _printNotebook(NotebookModel notebook) {
    _saveNotebookPdf(notebook);
  }

  Future<void> _shareNotebook(NotebookModel notebook) async {
    final text = NotebookExportService.instance.formatNotebookAsText(notebook);
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('متن کامل و خلاصه دفترچه «${notebook.title}» در حافظه موقت (Clipboard) کپی شد (${text.length} کاراکتر).'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF2E7D32),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  Future<void> _exportNotebookBackup(NotebookModel notebook) async {
    try {
      final res = await NotebookExportService.instance.exportJsonBackup(notebook);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res.userMessage),
            backgroundColor: res.isSuccess ? const Color(0xFF2E7D32) : Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطا در صدور پشتیبان: $e')),
        );
      }
    }
  }

  Future<void> _setNotebookToWidget(NotebookModel notebook) async {
    NotebookExportService.instance.setActiveWidgetNotebook(notebook.id);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('active_widget_notebook_id', notebook.id);
    } catch (_) {}
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('دفترچه «${notebook.title}» به عنوان ویجت فعال انتخاب شد.'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  void _addNotebookToBook(NotebookModel notebook) {
    final otherNotebooks = _notebooks.where((n) => n.id != notebook.id).toList();
    if (otherNotebooks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('دفترچه دیگری برای ادغام وجود ندارد.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        height: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ادغام برگه‌ها در کتابچه دیگر',
              style: GoogleFonts.vazirmatn(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'دفترچه مقصد را برای افزودن برگه‌های «${notebook.title}» انتخاب کنید:',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                itemCount: otherNotebooks.length,
                itemBuilder: (context, idx) {
                  final target = otherNotebooks[idx];
                  return ListTile(
                    leading: const Icon(Icons.menu_book_rounded, color: Color(0xFFFF7043)),
                    title: Text(target.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('${target.pages.length} برگه موجود'),
                    onTap: () {
                      Navigator.pop(context);
                      setState(() {
                        target.pages.addAll(notebook.pages.map((p) => p.copyWith(id: 'p_${DateTime.now().millisecondsSinceEpoch}_${p.id}')));
                      });
                      NotebookStorageService.instance.saveNotebooks(_notebooks);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('برگه‌ها با موفقیت به «${target.title}» اضافه شدند.'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
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

  void _addNotebookToFolder(NotebookModel notebook) {
    final folderCtrl = TextEditingController(text: notebook.folderName ?? '');
    final presetFolders = ['شخصی', 'کاری', 'مطالعه', 'برنامه‌ریزی', 'ایده‌ها'];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('پوشه‌بندی دفترچه', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: folderCtrl,
                decoration: const InputDecoration(
                  labelText: 'نام پوشه',
                  hintText: 'مثال: کاری، شخصی',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              const Text('پوشه‌های پیشنهادی:', style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                children: presetFolders.map((f) {
                  return ActionChip(
                    label: Text(f, style: const TextStyle(fontSize: 11)),
                    onPressed: () {
                      setDialogState(() {
                        folderCtrl.text = f;
                      });
                    },
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            if (notebook.folderName != null && notebook.folderName!.isNotEmpty)
              TextButton(
                onPressed: () {
                  setState(() => notebook.folderName = null);
                  NotebookStorageService.instance.saveNotebooks(_notebooks);
                  Navigator.pop(context);
                },
                child: const Text('حذف از پوشه', style: TextStyle(color: Colors.red)),
              ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('انصراف'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  notebook.folderName = folderCtrl.text.trim().isEmpty ? null : folderCtrl.text.trim();
                });
                NotebookStorageService.instance.saveNotebooks(_notebooks);
                Navigator.pop(context);
              },
              child: const Text('تایید'),
            ),
          ],
        ),
      ),
    );
  }

  void _openEditorWithTemplate(JournalTemplate template) {
    final newNotebook = NotebookModel(
      id: 'nb_${DateTime.now().millisecondsSinceEpoch}',
      title: template.title.split('(').first.trim(),
      coverColor: template.themeColor,
      pages: [
        NotebookPageModel(
          id: 'p_${DateTime.now().millisecondsSinceEpoch}',
          title: template.title.split('(').first.trim(),
          templateId: template.id,
        ),
      ],
    );

    setState(() {
      _notebooks.insert(0, newNotebook);
      _currentIndex = 0;
    });
    NotebookStorageService.instance.saveNotebooks(_notebooks);
    _openNotebookDetail(newNotebook);
  }

  void _openEditorWithPageStyle(PageStyleConfig pageStyle) {
    final newNotebook = NotebookModel(
      id: 'nb_${DateTime.now().millisecondsSinceEpoch}',
      title: pageStyle.title,
      coverColor: const Color(0xFFE07A5F),
      pages: [
        NotebookPageModel(
          id: 'p_${DateTime.now().millisecondsSinceEpoch}',
          title: pageStyle.title,
          pageStyle: pageStyle,
        ),
      ],
    );

    setState(() {
      _notebooks.insert(0, newNotebook);
      _currentIndex = 0;
    });
    NotebookStorageService.instance.saveNotebooks(_notebooks);
    _openNotebookDetail(newNotebook);
  }

  void _openProTemplateBuilder() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProTemplateBuilderScreen(
          onJournalCreated: (newJournal) async {
            // Refresh custom templates list from storage
            final customTmpls = await NotebookStorageService.instance.loadCustomTemplates();
            for (final ct in customTmpls) {
              if (!_templates.any((t) => t.id == ct.id)) {
                _templates.insert(0, ct);
              }
            }

            String? resolvedTemplateId;
            try {
              final decoded = jsonDecode(newJournal.content);
              if (decoded is Map<String, dynamic> && decoded['templateId'] != null) {
                resolvedTemplateId = decoded['templateId'] as String?;
              }
            } catch (_) {}
            resolvedTemplateId ??= customTmpls.isNotEmpty ? customTmpls.first.id : null;

            final page = NotebookPageModel.fromJournalContent(
              id: 'p_${DateTime.now().millisecondsSinceEpoch}',
              title: newJournal.title,
              content: newJournal.content,
              templateId: resolvedTemplateId,
            );

            final newNotebook = NotebookModel(
              id: 'nb_${DateTime.now().millisecondsSinceEpoch}',
              title: newJournal.title,
              coverColor: const Color(0xFFFF7043),
              pages: [page],
            );

            setState(() {
              _notebooks.insert(0, newNotebook);
              _currentIndex = 0;
            });
            await NotebookStorageService.instance.saveNotebooks(_notebooks);
            _openNotebookDetail(newNotebook);
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
                const Text(
                  'ایجاد دفترچه یا برگه جدید',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 16),

                // Option 1: Create Notebook with custom cover (Image 1)
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3E0),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFFFCC80), width: 1.5),
                  ),
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE07A5F),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.book_rounded, color: Colors.white),
                    ),
                    title: const Text(
                      'ایجاد دفترچه جدید (طراحی جلد)',
                      style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFFBF360C)),
                    ),
                    subtitle: const Text('انتخاب رنگ جلد، تصویر از گالری و نام‌گذاری دفترچه'),
                    trailing: const Icon(Icons.chevron_left_rounded, size: 22, color: Color(0xFFBF360C)),
                    onTap: () {
                      Navigator.pop(context);
                      _createNewNotebook();
                    },
                  ),
                ),
                const SizedBox(height: 10),

                // Option 2: AI Vision Pro Template Builder
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

                // Option 3: Choose Page Style
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
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChoosePageStyleScreen(
                          onBeginPlanner: (pageStyle) {
                            Navigator.pop(context);
                            _openEditorWithPageStyle(pageStyle);
                          },
                          onClose: () => Navigator.pop(context),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),

                // Option 4: Ready Templates
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
                    setState(() => _currentIndex = 1);
                  },
                ),
                const SizedBox(height: 12),

                // Option 5: Import JSON File
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE3F2FD),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.file_download_rounded, color: Color(0xFF1565C0)),
                  ),
                  title: const Text('ورود فایل لایه‌باز (Import JSON)', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('بارگذاری قالب، برگه، دفترچه یا بسته ترکیبی از فایل .json'),
                  trailing: const Icon(Icons.chevron_left_rounded, size: 22),
                  onTap: () {
                    Navigator.pop(context);
                    _importJsonPackage();
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
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final List<Widget> screens = [
      // 0: My Notebooks
      MyJournalsScreen(
        notebooks: _notebooks,
        onNotebookSelected: _openNotebookDetail,
        onEditNotebook: _openEditNotebook,
        onFavoriteToggle: _toggleNotebookFavorite,
        onDeleteNotebook: _deleteNotebook,
        onDuplicateNotebook: _duplicateNotebook,
        onSaveToGallery: _saveNotebookToGallery,
        onSavePdf: _saveNotebookPdf,
        onPrint: _printNotebook,
        onShare: _shareNotebook,
        onExport: _exportNotebookBackup,
        onSetToWidget: _setNotebookToWidget,
        onAddToBook: _addNotebookToBook,
        onAddToFolder: _addNotebookToFolder,
        onAddNewNotebook: _createNewNotebook,
      ),
      // 1: Templates
      TemplatesScreen(
        templates: _templates,
        onTemplateSelected: _openEditorWithTemplate,
        onFavoriteToggle: _toggleTemplateFavorite,
        onProBuilderPressed: _openProTemplateBuilder,
      ),
    ];

    final isWide = ResponsiveLayout.isDesktop(context) || ResponsiveLayout.isTablet(context);

    return Scaffold(
      appBar: isWide
          ? null
          : CustomAppBar(
              title: _currentIndex == 1 ? 'قالب‌ها' : 'دفترچه‌ها',
              onFavoritesPressed: _openFavoritesSheet,
              onImportPressed: _importJsonPackage,
              onSettingsPressed: _showSettingsDialog,
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
              index: _currentIndex < 2 ? _currentIndex : 0,
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
