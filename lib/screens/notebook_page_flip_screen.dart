import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import '../models/notebook_model.dart';
import '../models/template_model.dart';
import '../models/page_style_model.dart';
import '../models/text_box_model.dart';
import '../models/sticker_model.dart';
import '../models/drawing_stroke_model.dart';
import '../services/notebook_storage_service.dart';
import '../widgets/interactive_template_sheet.dart';
import '../widgets/floating_editor_dock.dart';
import '../widgets/text_formatting_toolbar.dart';
import '../widgets/stickers_sheet.dart';
import '../widgets/color_picker_sheet.dart';
import 'choose_page_style_screen.dart';

class NotebookPageFlipScreen extends StatefulWidget {
  final NotebookModel notebook;
  final int initialPageIndex;
  final Function(NotebookModel) onNotebookChanged;

  const NotebookPageFlipScreen({
    super.key,
    required this.notebook,
    required this.initialPageIndex,
    required this.onNotebookChanged,
  });

  @override
  State<NotebookPageFlipScreen> createState() => _NotebookPageFlipScreenState();
}

class _NotebookPageFlipScreenState extends State<NotebookPageFlipScreen> {
  late NotebookModel _notebook;
  late int _currentPageIndex;
  late PageController _pageController;

  late TextEditingController _titleController;
  late TextEditingController _bodyController;
  late TextEditingController _cueController;
  late TextEditingController _summaryController;

  String? _selectedTextBoxId;
  String? _selectedStickerId;

  Color _currentInkColor = const Color(0xFF1E2024);
  double _currentFontSize = 14.0;
  String _currentFontName = 'Vazirmatn';
  bool _isBold = false;
  bool _isItalic = false;
  bool _isUnderline = false;
  TextAlign _textAlign = TextAlign.right;
  Color? _currentHighlightColor;

  // Freehand Drawing State
  bool _isDrawingMode = false;
  bool _isHighlighter = false;
  bool _isEraser = false;
  double _penStrokeWidth = 3.0;
  DrawingStroke? _currentStroke;

  // Undo / Redo History Stacks
  final List<NotebookPageModel> _undoStack = [];
  final List<NotebookPageModel> _redoStack = [];

  @override
  void initState() {
    super.initState();
    _notebook = widget.notebook;
    _currentPageIndex = widget.initialPageIndex.clamp(0, _notebook.pages.isEmpty ? 0 : _notebook.pages.length - 1);
    _pageController = PageController(initialPage: _currentPageIndex);

    _initControllersForPage(_currentPageIndex);
  }

  void _initControllersForPage(int index) {
    if (index < _notebook.pages.length) {
      final page = _notebook.pages[index];
      _titleController = TextEditingController(text: page.noteTitle);
      _bodyController = TextEditingController(text: page.noteBody);
      _cueController = TextEditingController(text: page.cueText);
      _summaryController = TextEditingController(text: page.summaryText);

      _titleController.addListener(_syncActivePageData);
      _bodyController.addListener(_syncActivePageData);
      _cueController.addListener(_syncActivePageData);
      _summaryController.addListener(_syncActivePageData);
    } else {
      _titleController = TextEditingController();
      _bodyController = TextEditingController();
      _cueController = TextEditingController();
      _summaryController = TextEditingController();
    }
  }

  void _disposeControllers() {
    _titleController.dispose();
    _bodyController.dispose();
    _cueController.dispose();
    _summaryController.dispose();
  }

  void _recordHistoryState() {
    if (_currentPageIndex < _notebook.pages.length) {
      final currentPage = _notebook.pages[_currentPageIndex];
      _undoStack.add(currentPage.copyWith());
      if (_undoStack.length > 30) {
        _undoStack.removeAt(0);
      }
      _redoStack.clear();
      setState(() {});
    }
  }

  void _undo() {
    if (_undoStack.isNotEmpty && _currentPageIndex < _notebook.pages.length) {
      final currentState = _notebook.pages[_currentPageIndex].copyWith();
      _redoStack.add(currentState);
      final previousState = _undoStack.removeLast();

      setState(() {
        _notebook.pages[_currentPageIndex] = previousState;
        _titleController.text = previousState.noteTitle;
        _bodyController.text = previousState.noteBody;
        _cueController.text = previousState.cueText;
        _summaryController.text = previousState.summaryText;
      });
      _saveNotebook();
    }
  }

  void _redo() {
    if (_redoStack.isNotEmpty && _currentPageIndex < _notebook.pages.length) {
      final currentState = _notebook.pages[_currentPageIndex].copyWith();
      _undoStack.add(currentState);
      final nextState = _redoStack.removeLast();

      setState(() {
        _notebook.pages[_currentPageIndex] = nextState;
        _titleController.text = nextState.noteTitle;
        _bodyController.text = nextState.noteBody;
        _cueController.text = nextState.cueText;
        _summaryController.text = nextState.summaryText;
      });
      _saveNotebook();
    }
  }

  void _syncActivePageData() {
    if (_currentPageIndex < _notebook.pages.length) {
      final page = _notebook.pages[_currentPageIndex];
      page.noteTitle = _titleController.text;
      page.noteBody = _bodyController.text;
      page.cueText = _cueController.text;
      page.summaryText = _summaryController.text;
      _saveNotebook();
    }
  }

  void _saveNotebook({bool showFeedback = false}) {
    NotebookStorageService.instance.saveOrUpdateNotebook(_notebook);
    widget.onNotebookChanged(_notebook);
    if (showFeedback && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text('تغییرات دفترچه با موفقیت ذخیره شد.'),
            ],
          ),
          backgroundColor: const Color(0xFF1E293B),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  void _onPageChanged(int index) {
    _syncActivePageData();
    _disposeControllers();
    setState(() {
      _currentPageIndex = index;
      _selectedTextBoxId = null;
      _selectedStickerId = null;
      _undoStack.clear();
      _redoStack.clear();
    });
    _initControllersForPage(index);
  }

  void _addNewBlankPage() {
    _recordHistoryState();
    final newPage = NotebookPageModel(
      id: 'p_${DateTime.now().millisecondsSinceEpoch}',
      title: 'برگه ${_notebook.pages.length + 1}',
      pageStyle: PageStyleConfig(pageType: PageType.blank),
    );

    setState(() {
      _notebook.pages.add(newPage);
    });

    _saveNotebook();

    final targetIndex = _notebook.pages.length - 1;
    _pageController.animateToPage(
      targetIndex,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _scheduleCurrentPage() async {
    if (_currentPageIndex >= _notebook.pages.length) return;
    final page = _notebook.pages[_currentPageIndex];

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: page.scheduledDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );

    if (pickedDate != null && mounted) {
      final pickedTime = await showTimePicker(
        context: context,
        initialTime: page.scheduledDate != null
            ? TimeOfDay.fromDateTime(page.scheduledDate!)
            : TimeOfDay.now(),
      );

      final combined = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime?.hour ?? 9,
        pickedTime?.minute ?? 0,
      );

      _recordHistoryState();
      setState(() {
        page.scheduledDate = combined;
      });
      _saveNotebook();

      if (mounted) {
        final formatted = DateFormat('yyyy/MM/dd HH:mm').format(combined);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('برگه برای تاریخ $formatted زمان‌بندی شد.'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  void _openPageStyleSelector() {
    if (_currentPageIndex >= _notebook.pages.length) return;
    final page = _notebook.pages[_currentPageIndex];

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChoosePageStyleScreen(
          onBeginPlanner: (newStyle) {
            Navigator.pop(context);
            _recordHistoryState();
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

  void _openTemplatePickerSheet() {
    if (_currentPageIndex >= _notebook.pages.length) return;
    final page = _notebook.pages[_currentPageIndex];

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
              'انتخاب و درج قالب در برگه جاری',
              style: GoogleFonts.vazirmatn(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'یکی از قالب‌های آماده زیر را انتخاب کنید تا با ابعاد اورجینال جایگزین شود:',
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
                      _recordHistoryState();
                      setState(() {
                        // Reset all previous style/dimensions and load original template
                        page.applyTemplate(tmpl);
                        _titleController.clear();
                        _bodyController.clear();
                        _cueController.clear();
                        _summaryController.clear();
                        _selectedTextBoxId = null;
                        _selectedStickerId = null;
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

  Future<void> _pickImageFromGallery() async {
    if (_currentPageIndex >= _notebook.pages.length) return;
    final page = _notebook.pages[_currentPageIndex];

    try {
      final result = await FilePicker.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final picked = result.files.first;
        String? imageUri;
        if (picked.bytes != null) {
          final b64 = base64Encode(picked.bytes!);
          imageUri = 'data:image/png;base64,$b64';
        } else if (picked.path != null) {
          imageUri = picked.path;
        }

        if (imageUri != null) {
          _recordHistoryState();
          final newSticker = StickerItem(
            id: 'st_img_${DateTime.now().millisecondsSinceEpoch}',
            imagePath: imageUri,
            position: const Offset(80, 140),
            scale: 1.5,
            isSelected: true,
          );

          setState(() {
            for (final s in page.stickers) {
              s.isSelected = false;
            }
            page.stickers.add(newSticker);
            _selectedStickerId = newSticker.id;
            _selectedTextBoxId = null;
          });
          _saveNotebook();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطا در انتخاب تصویر: $e')),
        );
      }
    }
  }

  void _showAddImageMenu() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEBE5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.add_photo_alternate_rounded, color: Color(0xFFFF7043)),
                ),
                title: const Text('انتخاب عکس از گالری', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('افزودن تصویر به عنوان المان روی برگه'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImageFromGallery();
                },
              ),
              const Divider(),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0F2FE),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.dashboard_customize_rounded, color: Color(0xFF0369A1)),
                ),
                title: const Text('انتخاب قالب آماده پلنر', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Daily Planner، Gratitude، Habit Tracker و ...'),
                onTap: () {
                  Navigator.pop(context);
                  _openTemplatePickerSheet();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFontPickerSheet() {
    final availableFonts = [
      {'name': 'Vazirmatn', 'label': 'وزیرمتن (استاندارد فارسی)'},
      {'name': 'Sahel', 'label': 'ساحل (کلاسیک و زیبا)'},
      {'name': 'Shabnam', 'label': 'شبنم (مدرن و خوانا)'},
      {'name': 'Lalezar', 'label': 'لاله‌زار (فانتزی و نمایشی)'},
      {'name': 'Playfair Display', 'label': 'Playfair Display (Serif انگلیسی)'},
      {'name': 'Lora', 'label': 'Lora (رسمی و اداری)'},
    ];

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'انتخاب فونت متن',
              style: GoogleFonts.vazirmatn(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 14),
            ...availableFonts.map((f) {
              final isSelected = _currentFontName == f['name'];
              return ListTile(
                title: Text(
                  f['label']!,
                  style: GoogleFonts.getFont(
                    f['name']!,
                    fontSize: 15,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? const Color(0xFFFF7043) : const Color(0xFF1E293B),
                  ),
                ),
                trailing: isSelected ? const Icon(Icons.check_circle_rounded, color: Color(0xFFFF7043)) : null,
                onTap: () {
                  Navigator.pop(context);
                  _recordHistoryState();
                  setState(() {
                    _currentFontName = f['name']!;
                    if (_currentPageIndex < _notebook.pages.length && _selectedTextBoxId != null) {
                      final box = _notebook.pages[_currentPageIndex].textBoxes.firstWhere((b) => b.id == _selectedTextBoxId);
                      box.fontName = f['name']!;
                    }
                  });
                  _saveNotebook();
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  void _renameCurrentPage() {
    if (_currentPageIndex >= _notebook.pages.length) return;
    final page = _notebook.pages[_currentPageIndex];
    final renameCtrl = TextEditingController(text: page.title);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('تغییر نام برگه', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: renameCtrl,
          decoration: const InputDecoration(
            hintText: 'عنوان برگه',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('انصراف')),
          ElevatedButton(
            onPressed: () {
              if (renameCtrl.text.trim().isNotEmpty) {
                _recordHistoryState();
                setState(() {
                  page.title = renameCtrl.text.trim();
                });
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

  void _deleteCurrentPage() {
    if (_currentPageIndex >= _notebook.pages.length) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('حذف برگه', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: const Text('آیا از حذف این برگه و تمام یادداشت‌های آن مطمئن هستید؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('انصراف')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade600, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _notebook.pages.removeAt(_currentPageIndex);
                if (_currentPageIndex >= _notebook.pages.length && _currentPageIndex > 0) {
                  _currentPageIndex = _notebook.pages.length - 1;
                }
              });
              _saveNotebook();
              _onPageChanged(_currentPageIndex);
            },
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }

  void _addTextBoxToActivePage() {
    if (_currentPageIndex >= _notebook.pages.length) return;
    final page = _notebook.pages[_currentPageIndex];

    _recordHistoryState();
    final newBox = TextBoxItem(
      id: 'tb_${DateTime.now().millisecondsSinceEpoch}',
      text: 'یادداشت جدید',
      position: const Offset(60, 120),
      inkColor: _currentInkColor,
      fontName: _currentFontName,
      fontSize: _currentFontSize,
      isBold: _isBold,
      textAlign: _textAlign,
      highlightColor: _currentHighlightColor,
      isSelected: true,
    );

    setState(() {
      for (final b in page.textBoxes) {
        b.isSelected = false;
      }
      page.textBoxes.add(newBox);
      _selectedTextBoxId = newBox.id;
    });
    _saveNotebook();
  }

  void _showStickersSheet() {
    if (_currentPageIndex >= _notebook.pages.length) return;
    final page = _notebook.pages[_currentPageIndex];

    StickersSheet.show(
      context,
      onStickerSelected: (emoji) {
        _recordHistoryState();
        final newSticker = StickerItem(
          id: 'st_${DateTime.now().millisecondsSinceEpoch}',
          content: emoji,
          position: const Offset(100, 150),
          scale: 1.2,
          isSelected: true,
        );

        setState(() {
          for (final s in page.stickers) {
            s.isSelected = false;
          }
          page.stickers.add(newSticker);
          _selectedStickerId = newSticker.id;
        });
        _saveNotebook();
      },
    );
  }

  void _showColorPicker() {
    ColorPickerSheet.show(
      context,
      initialColor: _currentInkColor,
      onColorSelected: (color) {
        _recordHistoryState();
        setState(() {
          _currentInkColor = color;
          if (_currentPageIndex < _notebook.pages.length && _selectedTextBoxId != null) {
            final box = _notebook.pages[_currentPageIndex].textBoxes.firstWhere((b) => b.id == _selectedTextBoxId);
            box.inkColor = color;
          }
        });
        _saveNotebook();
      },
    );
  }

  void _changeFontSize() {
    _recordHistoryState();
    setState(() {
      if (_currentFontSize >= 24) {
        _currentFontSize = 12;
      } else {
        _currentFontSize += 2;
      }
      if (_currentPageIndex < _notebook.pages.length && _selectedTextBoxId != null) {
        final box = _notebook.pages[_currentPageIndex].textBoxes.firstWhere((b) => b.id == _selectedTextBoxId);
        box.fontSize = _currentFontSize;
      }
    });
    _saveNotebook();
  }

  void _insertCurrentTimeToActiveField() {
    final nowStr = DateFormat('hh:mm a').format(DateTime.now());
    _recordHistoryState();
    if (_currentPageIndex < _notebook.pages.length && _selectedTextBoxId != null) {
      final box = _notebook.pages[_currentPageIndex].textBoxes.firstWhere((b) => b.id == _selectedTextBoxId);
      setState(() {
        box.text = '${box.text} $nowStr';
      });
      _saveNotebook();
    } else {
      setState(() {
        _bodyController.text = '${_bodyController.text} $nowStr';
      });
      _syncActivePageData();
    }
  }

  void _appendNumberedListItem() {
    _recordHistoryState();
    if (_currentPageIndex < _notebook.pages.length && _selectedTextBoxId != null) {
      final box = _notebook.pages[_currentPageIndex].textBoxes.firstWhere((b) => b.id == _selectedTextBoxId);
      setState(() {
        box.text = '${box.text}\n1. ';
      });
      _saveNotebook();
    } else {
      setState(() {
        _bodyController.text = '${_bodyController.text}\n1. ';
      });
      _syncActivePageData();
    }
  }

  void _toggleCheckItem(String id) {
    _recordHistoryState();
    if (_currentPageIndex < _notebook.pages.length) {
      final page = _notebook.pages[_currentPageIndex];
      final idx = page.checkItems.indexWhere((c) => c.id == id);
      if (idx != -1) {
        setState(() {
          page.checkItems[idx] = page.checkItems[idx].copyWith(
            isChecked: !page.checkItems[idx].isChecked,
          );
        });
        _saveNotebook();
      }
    }
  }

  void _goToPrevField() {
    if (_currentPageIndex >= _notebook.pages.length) return;
    final page = _notebook.pages[_currentPageIndex];
    if (page.textBoxes.isEmpty) return;

    int newIdx = 0;
    if (_selectedTextBoxId != null) {
      final curIdx = page.textBoxes.indexWhere((b) => b.id == _selectedTextBoxId);
      if (curIdx > 0) {
        newIdx = curIdx - 1;
      } else {
        newIdx = page.textBoxes.length - 1;
      }
    }
    setState(() {
      _selectedTextBoxId = page.textBoxes[newIdx].id;
      _selectedStickerId = null;
    });
  }

  void _goToNextField() {
    if (_currentPageIndex >= _notebook.pages.length) return;
    final page = _notebook.pages[_currentPageIndex];
    if (page.textBoxes.isEmpty) return;

    int newIdx = 0;
    if (_selectedTextBoxId != null) {
      final curIdx = page.textBoxes.indexWhere((b) => b.id == _selectedTextBoxId);
      if (curIdx != -1 && curIdx + 1 < page.textBoxes.length) {
        newIdx = curIdx + 1;
      } else {
        newIdx = 0;
      }
    }
    setState(() {
      _selectedTextBoxId = page.textBoxes[newIdx].id;
      _selectedStickerId = null;
    });
  }

  void _togglePenMode() {
    setState(() {
      if (_isDrawingMode && !_isHighlighter && !_isEraser) {
        _isDrawingMode = false;
      } else {
        _isDrawingMode = true;
        _isHighlighter = false;
        _isEraser = false;
        _penStrokeWidth = 3.0;
        _selectedTextBoxId = null;
        _selectedStickerId = null;
      }
    });
  }

  void _toggleHighlighterMode() {
    setState(() {
      if (_isDrawingMode && _isHighlighter) {
        _isDrawingMode = false;
      } else {
        _isDrawingMode = true;
        _isHighlighter = true;
        _isEraser = false;
        _penStrokeWidth = 16.0;
        _selectedTextBoxId = null;
        _selectedStickerId = null;
      }
    });
  }

  void _toggleEraserMode() {
    setState(() {
      if (_isDrawingMode && _isEraser) {
        _isDrawingMode = false;
      } else {
        _isDrawingMode = true;
        _isHighlighter = false;
        _isEraser = true;
        _penStrokeWidth = 20.0;
        _selectedTextBoxId = null;
        _selectedStickerId = null;
      }
    });
  }

  void _cycleStrokeWidth() {
    setState(() {
      if (_isHighlighter) {
        if (_penStrokeWidth < 16) {
          _penStrokeWidth = 16;
        } else if (_penStrokeWidth < 24) {
          _penStrokeWidth = 24;
        } else {
          _penStrokeWidth = 10;
        }
      } else if (_isEraser) {
        if (_penStrokeWidth < 20) {
          _penStrokeWidth = 20;
        } else if (_penStrokeWidth < 35) {
          _penStrokeWidth = 35;
        } else {
          _penStrokeWidth = 14;
        }
      } else {
        if (_penStrokeWidth <= 2.5) {
          _penStrokeWidth = 4.0;
        } else if (_penStrokeWidth <= 4.5) {
          _penStrokeWidth = 8.0;
        } else if (_penStrokeWidth <= 8.5) {
          _penStrokeWidth = 14.0;
        } else {
          _penStrokeWidth = 2.0;
        }
      }
    });
  }

  void _selectQuickColor(Color color) {
    _recordHistoryState();
    setState(() {
      _currentInkColor = color;
      if (_currentPageIndex < _notebook.pages.length && _selectedTextBoxId != null) {
        final box = _notebook.pages[_currentPageIndex].textBoxes.firstWhere((b) => b.id == _selectedTextBoxId);
        box.inkColor = color;
      }
    });
    _saveNotebook();
  }

  void _undoLastStroke() {
    if (_currentPageIndex >= _notebook.pages.length) return;
    final page = _notebook.pages[_currentPageIndex];
    if (page.drawingStrokes.isNotEmpty) {
      _recordHistoryState();
      setState(() {
        page.drawingStrokes.removeLast();
      });
      _saveNotebook();
    }
  }

  void _onDrawingPanStart(Offset localPos) {
    if (!_isDrawingMode || _currentPageIndex >= _notebook.pages.length) return;
    final page = _notebook.pages[_currentPageIndex];

    if (_isEraser) {
      _eraseNearPoint(localPos, page);
      return;
    }

    _recordHistoryState();
    final newStroke = DrawingStroke(
      id: 'stk_${DateTime.now().millisecondsSinceEpoch}',
      points: [DrawingPoint.fromOffset(localPos)],
      color: _currentInkColor,
      strokeWidth: _penStrokeWidth,
      isHighlighter: _isHighlighter,
    );

    setState(() {
      _currentStroke = newStroke;
    });
  }

  void _onDrawingPanUpdate(Offset localPos) {
    if (!_isDrawingMode || _currentPageIndex >= _notebook.pages.length) return;
    final page = _notebook.pages[_currentPageIndex];

    if (_isEraser) {
      _eraseNearPoint(localPos, page);
      return;
    }

    if (_currentStroke != null) {
      setState(() {
        _currentStroke!.points.add(DrawingPoint.fromOffset(localPos));
      });
    }
  }

  void _onDrawingPanEnd() {
    if (!_isDrawingMode || _currentPageIndex >= _notebook.pages.length) return;
    final page = _notebook.pages[_currentPageIndex];

    if (_currentStroke != null) {
      setState(() {
        page.drawingStrokes.add(_currentStroke!);
        _currentStroke = null;
      });
      _saveNotebook();
    }
  }

  void _eraseNearPoint(Offset localPos, NotebookPageModel page) {
    final threshold = _penStrokeWidth;
    bool modified = false;
    page.drawingStrokes.removeWhere((stroke) {
      for (final pt in stroke.points) {
        final dist = (Offset(pt.x, pt.y) - localPos).distance;
        if (dist <= threshold + stroke.strokeWidth) {
          modified = true;
          return true;
        }
      }
      return false;
    });
    if (modified) {
      setState(() {});
      _saveNotebook();
    }
  }

  void _toggleBold() {
    _recordHistoryState();
    setState(() {
      _isBold = !_isBold;
      if (_currentPageIndex < _notebook.pages.length && _selectedTextBoxId != null) {
        final box = _notebook.pages[_currentPageIndex].textBoxes.firstWhere((b) => b.id == _selectedTextBoxId);
        box.isBold = _isBold;
      }
    });
    _saveNotebook();
  }

  void _toggleItalic() {
    _recordHistoryState();
    setState(() {
      _isItalic = !_isItalic;
    });
    _saveNotebook();
  }

  void _toggleUnderline() {
    _recordHistoryState();
    setState(() {
      _isUnderline = !_isUnderline;
    });
    _saveNotebook();
  }

  void _insertChecklistBullet() {
    _recordHistoryState();
    if (_selectedTextBoxId != null && _currentPageIndex < _notebook.pages.length) {
      final box = _notebook.pages[_currentPageIndex].textBoxes.firstWhere((b) => b.id == _selectedTextBoxId);
      setState(() {
        box.text = '☐ ${box.text}';
      });
      _saveNotebook();
      return;
    }
    final text = _bodyController.text;
    final selection = _bodyController.selection;
    const bullet = '☐ ';
    if (selection.isValid && selection.start >= 0) {
      final newText = text.replaceRange(selection.start, selection.end, bullet);
      _bodyController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: selection.start + bullet.length),
      );
    } else {
      _bodyController.text = '$bullet$text';
    }
    _syncActivePageData();
  }

  @override
  void dispose() {
    _disposeControllers();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final totalItems = _notebook.pages.length + 1; // Last item is "Add New Page"
    final isEndPage = _currentPageIndex >= _notebook.pages.length;
    final currentPage = !isEndPage ? _notebook.pages[_currentPageIndex] : null;

    final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 50;
    final isEditingText = isKeyboardOpen || _selectedTextBoxId != null;

    final canUndo = _undoStack.isNotEmpty;
    final canRedo = _redoStack.isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      // PlanWiz Top App Bar
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: SafeArea(
            bottom: false,
            child: Row(
              children: [
                // Left 1: Squircle Back Button
                InkWell(
                  onTap: () {
                    _syncActivePageData();
                    Navigator.pop(context, _notebook);
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: const Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: Color(0xFF1E293B)),
                  ),
                ),
                const SizedBox(width: 8),

                // Left 2: PlanWiz Diamond Logo (with Rainbow Gradient Border)
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(9),
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF8E24AA), // Purple
                        Color(0xFFE91E63), // Pink
                        Color(0xFFFF5722), // Orange
                        Color(0xFFFFC107), // Yellow
                      ],
                    ),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: const Icon(Icons.diamond_rounded, size: 16, color: Color(0xFFFF7043)),
                  ),
                ),

                const Spacer(),

                // Right 1: Undo ↶ (Interactive State History)
                IconButton(
                  icon: Icon(
                    Icons.undo_rounded,
                    size: 20,
                    color: canUndo ? const Color(0xFF1E293B) : const Color(0xFFCBD5E1),
                  ),
                  onPressed: canUndo ? _undo : null,
                  tooltip: 'Undo (بازگشت تغییرات)',
                  visualDensity: VisualDensity.compact,
                ),

                // Right 2: Redo ↷ (Interactive State History)
                IconButton(
                  icon: Icon(
                    Icons.redo_rounded,
                    size: 20,
                    color: canRedo ? const Color(0xFF1E293B) : const Color(0xFFCBD5E1),
                  ),
                  onPressed: canRedo ? _redo : null,
                  tooltip: 'Redo (تکرار تغییرات)',
                  visualDensity: VisualDensity.compact,
                ),

                // Right 3: Calendar + (Schedule / Date Reminder)
                IconButton(
                  icon: Icon(
                    currentPage?.scheduledDate != null
                        ? Icons.event_available_rounded
                        : Icons.event_available_outlined,
                    size: 20,
                    color: currentPage?.scheduledDate != null
                        ? const Color(0xFFFF7043)
                        : const Color(0xFF64748B),
                  ),
                  onPressed: _scheduleCurrentPage,
                  tooltip: currentPage?.scheduledDate != null
                      ? 'زمان‌بندی شده: ${DateFormat('yyyy/MM/dd HH:mm').format(currentPage!.scheduledDate!)}'
                      : 'افزودن زمان‌بندی / تاریخ',
                  visualDensity: VisualDensity.compact,
                ),

                // Right 4: Squircle More Options (···)
                if (!isEndPage)
                  PopupMenuButton<String>(
                    icon: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: const Icon(Icons.more_horiz_rounded, size: 18, color: Color(0xFF1E293B)),
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    onSelected: (val) {
                      switch (val) {
                        case 'style':
                          _openPageStyleSelector();
                          break;
                        case 'template':
                          _openTemplatePickerSheet();
                          break;
                        case 'rename':
                          _renameCurrentPage();
                          break;
                        case 'delete':
                          _deleteCurrentPage();
                          break;
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'style',
                        child: Row(
                          children: [
                            Icon(Icons.tune_rounded, size: 18, color: Color(0xFFFF7043)),
                            SizedBox(width: 10),
                            Text('تنظیم استایل برگه (خط‌دار، شطرنجی، رنگ)', style: TextStyle(fontSize: 12.5)),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'template',
                        child: Row(
                          children: [
                            Icon(Icons.dashboard_customize_outlined, size: 18, color: Color(0xFF1976D2)),
                            SizedBox(width: 10),
                            Text('وارد کردن قالب (Daily Planner و ...)', style: TextStyle(fontSize: 12.5)),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'rename',
                        child: Row(
                          children: [
                            Icon(Icons.edit_outlined, size: 18, color: Color(0xFF455A64)),
                            SizedBox(width: 10),
                            Text('تغییر نام برگه', style: TextStyle(fontSize: 12.5)),
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
                            Text('حذف این برگه', style: TextStyle(fontSize: 12.5, color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  ),
                const SizedBox(width: 6),

                // Right 5: PlanWiz Dark Charcoal Serif Save Button
                InkWell(
                  onTap: () {
                    _syncActivePageData();
                    _saveNotebook(showFeedback: true);
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2C3437), // Solid dark charcoal
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Save',
                      style: GoogleFonts.lora(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          // Main Canvas with PageView
          PageView.builder(
            controller: _pageController,
            itemCount: totalItems,
            onPageChanged: _onPageChanged,
            itemBuilder: (context, index) {
              // End page card
              if (index >= _notebook.pages.length) {
                return _buildAddNewPageSlide();
              }

              final page = _notebook.pages[index];
              final isActive = index == _currentPageIndex;

              return Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 80),
                child: Column(
                  children: [
                    // Scheduled Date Chip (if set)
                    if (page.scheduledDate != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFEBE5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFFFCCBC)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.alarm_on_rounded, size: 14, color: Color(0xFFBF360C)),
                            const SizedBox(width: 6),
                            Text(
                              'زمان‌بندی: ${DateFormat('yyyy/MM/dd HH:mm').format(page.scheduledDate!)}',
                              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFFBF360C)),
                            ),
                          ],
                        ),
                      ),

                    // Sheet Canvas
                    Expanded(
                      child: InteractiveTemplateSheet(
                        template: page.template,
                        pageStyle: page.template == null ? page.pageStyle : null,
                        textBoxes: page.textBoxes,
                        stickers: page.stickers,
                        checkItems: page.checkItems,
                        drawingStrokes: page.drawingStrokes,
                        currentStroke: isActive ? _currentStroke : null,
                        isDrawingMode: isActive ? _isDrawingMode : false,
                        onDrawingStart: _onDrawingPanStart,
                        onDrawingUpdate: _onDrawingPanUpdate,
                        onDrawingEnd: _onDrawingPanEnd,
                        selectedTextBoxId: isActive ? _selectedTextBoxId : null,
                        selectedStickerId: isActive ? _selectedStickerId : null,
                        noteTitleController: isActive ? _titleController : null,
                        noteBodyController: isActive ? _bodyController : null,
                        cueController: isActive ? _cueController : null,
                        summaryController: isActive ? _summaryController : null,
                        fontSize: _currentFontSize,
                        fontName: _currentFontName,
                        inkColor: _currentInkColor,
                        textAlign: _textAlign,
                        isBold: _isBold,
                        isItalic: _isItalic,
                        highlightColor: _currentHighlightColor,
                        onToggleCheckItem: _toggleCheckItem,
                        onSelectTextBox: (id) {
                          setState(() {
                            _selectedTextBoxId = id;
                            _selectedStickerId = null;
                          });
                        },
                        onPositionChanged: (id, newPos) {
                          final box = page.textBoxes.firstWhere((b) => b.id == id);
                          box.position = newPos;
                          _saveNotebook();
                        },
                        onSizeChanged: (id, newW, newH) {
                          final box = page.textBoxes.firstWhere((b) => b.id == id);
                          box.width = newW;
                          box.height = newH;
                          _saveNotebook();
                        },
                        onTextChanged: (id, newText) {
                          final box = page.textBoxes.firstWhere((b) => b.id == id);
                          box.text = newText;
                          _saveNotebook();
                        },
                        onDeleteTextBox: (id) {
                          _recordHistoryState();
                          setState(() {
                            page.textBoxes.removeWhere((b) => b.id == id);
                            _selectedTextBoxId = null;
                          });
                          _saveNotebook();
                        },
                        onSelectSticker: (id) {
                          setState(() {
                            _selectedStickerId = id;
                            _selectedTextBoxId = null;
                          });
                        },
                        onStickerPositionChanged: (id, newPos) {
                          final st = page.stickers.firstWhere((s) => s.id == id);
                          st.position = newPos;
                          _saveNotebook();
                        },
                        onStickerScaleChanged: (id, newScale) {
                          final st = page.stickers.firstWhere((s) => s.id == id);
                          st.scale = newScale;
                          _saveNotebook();
                        },
                        onDeleteSticker: (id) {
                          _recordHistoryState();
                          setState(() {
                            page.stickers.removeWhere((s) => s.id == id);
                            _selectedStickerId = null;
                          });
                          _saveNotebook();
                        },
                        onCanvasTap: (offset) {
                          if (!_isDrawingMode) {
                            setState(() {
                              _selectedTextBoxId = null;
                              _selectedStickerId = null;
                            });
                            FocusManager.instance.primaryFocus?.unfocus();
                          }
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          // PlanWiz Floating Dock in Normal Canvas Mode (when not editing text and not in drawing mode)
          if (!isEndPage && !isEditingText && !_isDrawingMode)
            Align(
              alignment: Alignment.bottomCenter,
              child: FloatingEditorDock(
                onAddText: _addTextBoxToActivePage,
                onDrawOrStyle: _togglePenMode,
                onAddImage: _showAddImageMenu,
                onMoreTools: _showStickersSheet,
              ),
            ),
        ],
      ),

      // Text Formatting & Drawing Toolbar (when editing text OR in drawing mode)
      bottomNavigationBar: (!isEndPage && (isEditingText || _isDrawingMode))
          ? TextFormattingToolbar(
              fontSize: _currentFontSize,
              inkColor: _currentInkColor,
              textAlign: _textAlign,
              isBold: _isBold,
              isItalic: _isItalic,
              isUnderline: _isUnderline,
              isDrawingMode: _isDrawingMode,
              isHighlighter: _isHighlighter,
              isEraser: _isEraser,
              penStrokeWidth: _penStrokeWidth,
              onTogglePen: _togglePenMode,
              onToggleHighlighter: _toggleHighlighterMode,
              onToggleEraser: _toggleEraserMode,
              onStrokeWidthTap: _cycleStrokeWidth,
              onUndoDrawing: _undoLastStroke,
              onQuickColorSelected: _selectQuickColor,
              onColorTap: _showColorPicker,
              onToggleBold: _toggleBold,
              onToggleItalic: _toggleItalic,
              onToggleUnderline: _toggleUnderline,
              onPrevField: _goToPrevField,
              onNextField: _goToNextField,
              onFontTap: _showFontPickerSheet,
              onFontSizeTap: _changeFontSize,
              onAlignTap: () {
                _recordHistoryState();
                setState(() {
                  _textAlign = _textAlign == TextAlign.right
                      ? TextAlign.center
                      : (_textAlign == TextAlign.center ? TextAlign.left : TextAlign.right);
                });
              },
              onNumberedListTap: _appendNumberedListItem,
              onChecklistTap: _insertChecklistBullet,
              onInsertTimeTap: _insertCurrentTimeToActiveField,
              onStickersTap: _showStickersSheet,
              onCloseKeyboard: () {
                setState(() {
                  _isDrawingMode = false;
                  _selectedTextBoxId = null;
                  _selectedStickerId = null;
                });
                FocusManager.instance.primaryFocus?.unfocus();
              },
            )
          : null,
    );
  }

  Widget _buildAddNewPageSlide() {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        padding: const EdgeInsets.all(28),
        constraints: const BoxConstraints(maxWidth: 380, maxHeight: 460),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: const Color(0xFFFFEBE5),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFFFCCBC), width: 2),
              ),
              child: const Center(
                child: Icon(Icons.note_add_rounded, size: 42, color: Color(0xFFFF7043)),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'به انتهای دفترچه رسیدید',
              style: GoogleFonts.vazirmatn(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'این دفترچه تاکنون دارای ${_notebook.pages.length} برگه است. برای ادامه برنامه‌ریزی یا نوشتن، یک برگه تازه ایجاد کنید.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600, height: 1.5),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _addNewBlankPage,
                icon: const Icon(Icons.add_rounded, size: 20),
                label: const Text(
                  'افزودن برگه جدید',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF7043),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
