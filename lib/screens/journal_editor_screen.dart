import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../models/template_model.dart';
import '../models/page_style_model.dart';
import '../models/journal_model.dart';
import '../models/notebook_model.dart';
import '../models/text_box_model.dart';
import '../models/sticker_model.dart';
import '../models/check_item_model.dart';
import '../services/notebook_export_service.dart';
import '../theme/app_theme.dart';
import '../widgets/interactive_template_sheet.dart';
import '../widgets/editor_bottom_toolbar.dart';
import '../widgets/stickers_sheet.dart';
import '../widgets/pro_badge.dart';

class JournalEditorScreen extends StatefulWidget {
  final JournalTemplate? template;
  final PageStyleConfig? pageStyle;
  final JournalItem? existingJournal;
  final Function(JournalItem) onSave;

  const JournalEditorScreen({
    super.key,
    this.template,
    this.pageStyle,
    this.existingJournal,
    required this.onSave,
  });

  @override
  State<JournalEditorScreen> createState() => _JournalEditorScreenState();
}

class _JournalEditorScreenState extends State<JournalEditorScreen> {
  JournalTemplate? _currentTemplate;
  PageStyleConfig? _currentPageStyle;
  final List<TextBoxItem> _textBoxes = [];
  final List<StickerItem> _stickers = [];
  final List<InteractiveCheckItem> _checkItems = [];
  String? _selectedTextBoxId;
  String? _selectedStickerId;

  // Natural Note-taking Controllers (for Page Style Mode)
  final TextEditingController _noteTitleController = TextEditingController();
  final TextEditingController _noteBodyController = TextEditingController();
  final TextEditingController _cueController = TextEditingController();
  final TextEditingController _summaryController = TextEditingController();

  Color _currentInkColor = const Color(0xFF1E2024);
  String _currentFontName = 'Vazirmatn';
  double _currentFontSize = 14.0;
  bool _isBold = false;
  final bool _isItalic = false;
  TextAlign _textAlign = TextAlign.right;
  Color? _currentHighlightColor;

  bool get isPageStyleMode => _currentPageStyle != null;

  @override
  void initState() {
    super.initState();
    _currentPageStyle = widget.pageStyle;
    _currentTemplate = widget.template ?? (widget.pageStyle == null ? JournalTemplate.sampleTemplates[0] : null);

    // Load existing items if available
    if (widget.existingJournal != null && widget.existingJournal!.content.isNotEmpty) {
      try {
        final decoded = jsonDecode(widget.existingJournal!.content) as Map<String, dynamic>;
        if (decoded.containsKey('pageStyle') && decoded['pageStyle'] != null) {
          _currentPageStyle = PageStyleConfig.fromJson(decoded['pageStyle'] as Map<String, dynamic>);
        }
        if (decoded.containsKey('noteTitle')) {
          _noteTitleController.text = decoded['noteTitle'] as String? ?? '';
        }
        if (decoded.containsKey('noteBody')) {
          _noteBodyController.text = decoded['noteBody'] as String? ?? '';
        }
        if (decoded.containsKey('cueText')) {
          _cueController.text = decoded['cueText'] as String? ?? '';
        }
        if (decoded.containsKey('summaryText')) {
          _summaryController.text = decoded['summaryText'] as String? ?? '';
        }
        if (decoded.containsKey('textBoxes')) {
          for (final item in decoded['textBoxes'] as List) {
            _textBoxes.add(TextBoxItem.fromJson(item as Map<String, dynamic>));
          }
        }
        if (decoded.containsKey('stickers')) {
          for (final item in decoded['stickers'] as List) {
            _stickers.add(StickerItem.fromJson(item as Map<String, dynamic>));
          }
        }
        if (decoded.containsKey('checkItems')) {
          for (final item in decoded['checkItems'] as List) {
            try {
              _checkItems.add(InteractiveCheckItem.fromJson(item as Map<String, dynamic>));
            } catch (_) {}
          }
        }
      } catch (_) {
        // Fallback for older format
        try {
          final decoded = jsonDecode(widget.existingJournal!.content) as List;
          for (final item in decoded) {
            _textBoxes.add(TextBoxItem.fromJson(item as Map<String, dynamic>));
          }
        } catch (_) {}
      }
    }

    // Starter text box only for Image Templates, NOT for Page Style notebooks (which use natural full-page note writing)
    if (_currentPageStyle == null) {
      if (_textBoxes.isEmpty) {
        final initialBox = TextBoxItem(
          id: 'tb_${DateTime.now().millisecondsSinceEpoch}',
          text: '',
          hintText: 'برای شروع نوشتن اینجا کلیک کنید...',
          position: const Offset(40, 90),
          width: 220,
          height: 38,
          fontSize: _currentFontSize,
          fontName: _currentFontName,
          inkColor: _currentInkColor,
          isSelected: true,
        );
        _textBoxes.add(initialBox);
        _selectedTextBoxId = initialBox.id;
      } else {
        _selectedTextBoxId = null;
      }
    }
  }

  @override
  void dispose() {
    _noteTitleController.dispose();
    _noteBodyController.dispose();
    _cueController.dispose();
    _summaryController.dispose();
    super.dispose();
  }



  TextBoxItem? get _selectedBox {
    if (_selectedTextBoxId == null) return null;
    try {
      return _textBoxes.firstWhere((b) => b.id == _selectedTextBoxId);
    } catch (_) {
      return null;
    }
  }

  void _addNewTextBox([Offset? position]) {
    setState(() {
      _selectedStickerId = null;
      for (final b in _textBoxes) {
        b.isSelected = false;
      }

      final pos = position ?? Offset(60, 100 + (_textBoxes.length * 35.0) % 300);
      final double sheetW = isPageStyleMode ? 580.0 : 420.0;
      final double sheetH = sheetW / (_currentTemplate?.aspectRatio ?? (_currentPageStyle?.effectiveAspectRatio ?? (848 / 1264)));

      final newBox = TextBoxItem(
        id: 'tb_${DateTime.now().millisecondsSinceEpoch}_${_textBoxes.length}',
        text: '',
        hintText: 'متن خود را بنویسید...',
        position: pos,
        width: 180,
        height: 36,
        fontSize: _currentFontSize,
        fontName: _currentFontName,
        inkColor: _currentInkColor,
        isSelected: true,
        normalizedX: (pos.dx / sheetW).clamp(0.0, 1.0),
        normalizedY: (pos.dy / sheetH).clamp(0.0, 1.0),
        normalizedWidth: (180.0 / sheetW).clamp(0.05, 1.0),
        normalizedHeight: (36.0 / sheetH).clamp(0.02, 1.0),
      );

      _textBoxes.add(newBox);
      _selectedTextBoxId = newBox.id;
    });
  }

  void _addNewSticker(String emoji) {
    setState(() {
      _selectedTextBoxId = null;
      for (final b in _textBoxes) {
        b.isSelected = false;
      }
      for (final s in _stickers) {
        s.isSelected = false;
      }

      final newSticker = StickerItem(
        id: 'stk_${DateTime.now().millisecondsSinceEpoch}_${_stickers.length}',
        content: emoji,
        position: Offset(100 + (_stickers.length * 20.0) % 200, 120 + (_stickers.length * 20.0) % 200),
        isSelected: true,
      );

      _stickers.add(newSticker);
      _selectedStickerId = newSticker.id;
    });
  }

  void _deleteSelected() {
    setState(() {
      if (_selectedTextBoxId != null) {
        _textBoxes.removeWhere((b) => b.id == _selectedTextBoxId);
        _selectedTextBoxId = _textBoxes.isNotEmpty ? _textBoxes.last.id : null;
      } else if (_selectedStickerId != null) {
        _stickers.removeWhere((s) => s.id == _selectedStickerId);
        _selectedStickerId = _stickers.isNotEmpty ? _stickers.last.id : null;
      }
    });
  }

  void _toggleCheckItem(String id) {
    setState(() {
      final idx = _checkItems.indexWhere((c) => c.id == id);
      if (idx != -1) {
        _checkItems[idx] = _checkItems[idx].copyWith(isChecked: !_checkItems[idx].isChecked);
      }
    });
  }

  void _toggleTextAlign() {
    setState(() {
      if (_textAlign == TextAlign.right) {
        _textAlign = TextAlign.center;
      } else if (_textAlign == TextAlign.center) {
        _textAlign = TextAlign.left;
      } else {
        _textAlign = TextAlign.right;
      }
      if (_selectedBox != null) {
        _selectedBox!.textAlign = _textAlign;
      }
    });
  }

  void _toggleBold() {
    setState(() {
      _isBold = !_isBold;
      if (_selectedBox != null) {
        _selectedBox!.isBold = _isBold;
      }
    });
  }

  void _toggleHighlight() {
    final highlights = [
      const Color(0xFFFFEB3B), // Yellow
      const Color(0xFFFF80AB), // Pink
      const Color(0xFFB9F6CA), // Mint
      const Color(0xFFE1BEE7), // Lavender
      const Color(0xFFFFCC80), // Peach
      null, // Transparent
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('رنگ هایلایتر (Highlighter):', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: highlights.map((c) {
                final isSelected = (_selectedBox?.highlightColor == c) || (_currentPageStyle != null && _currentHighlightColor == c);
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _currentHighlightColor = c;
                      if (_selectedBox != null) {
                        _selectedBox!.highlightColor = c;
                      }
                    });
                    Navigator.pop(context);
                  },
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: c ?? Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? AppTheme.primaryColor : Colors.grey.shade400,
                        width: isSelected ? 3 : 1,
                      ),
                    ),
                    child: Center(
                      child: c == null
                          ? const Icon(Icons.block_rounded, size: 18, color: Colors.grey)
                          : (isSelected ? const Icon(Icons.check, size: 18, color: Colors.black87) : null),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _onFontPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('انتخاب قلم و فونت (Select Font):', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              ...['Vazirmatn (فارسی استاندارد)', 'Nunito (انگلیسی مدرن)', 'Roboto (تمیز و خوانا)', 'Courier (ماشین تحریر)'].map((name) {
                final fontKey = name.split(' ')[0];
                return ListTile(
                  title: Text(name),
                  trailing: _currentFontName == fontKey ? const Icon(Icons.check_circle_rounded, color: AppTheme.primaryColor) : null,
                  onTap: () {
                    setState(() {
                      _currentFontName = fontKey;
                      if (_selectedBox != null) {
                        _selectedBox!.fontName = fontKey;
                      }
                    });
                    Navigator.pop(context);
                  },
                );
              }),
              const SizedBox(height: 8),
              const Text('اندازه قلم (Font Size):', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              Slider(
                value: _currentFontSize,
                min: 10,
                max: 24,
                divisions: 14,
                label: '${_currentFontSize.toInt()}',
                activeColor: AppTheme.primaryColor,
                onChanged: (val) {
                  setModalState(() => _currentFontSize = val);
                  setState(() {
                    _currentFontSize = val;
                    if (_selectedBox != null) {
                      _selectedBox!.fontSize = val;
                    }
                  });
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onColorPicker() {
    final colors = [
      const Color(0xFF1E2024), // Black ink
      const Color(0xFF1565C0), // Royal Blue
      const Color(0xFF0D47A1), // Navy
      const Color(0xFFFF6F48), // Coral / Orange
      const Color(0xFF2E7D32), // Forest Green
      const Color(0xFF6A1B9A), // Purple
      const Color(0xFFB71C1C), // Deep Red
      const Color(0xFF455A64), // Slate
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('رنگ جوهر قلم (Ink Color):', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: colors.map((c) {
                final isSelected = _currentInkColor == c;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _currentInkColor = c;
                      if (_selectedBox != null) {
                        _selectedBox!.inkColor = c;
                      }
                    });
                    Navigator.pop(context);
                  },
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? AppTheme.primaryColor : Colors.grey.shade300,
                        width: isSelected ? 3 : 1,
                      ),
                      boxShadow: [
                        if (isSelected)
                          BoxShadow(color: c.withValues(alpha: 0.4), blurRadius: 8, offset: const Offset(0, 3)),
                      ],
                    ),
                    child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 20) : null,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _saveJournal() {
    final serializedData = jsonEncode({
      if (_currentPageStyle != null) ...{
        'pageStyle': _currentPageStyle!.toJson(),
        'noteTitle': _noteTitleController.text,
        'noteBody': _noteBodyController.text,
        'cueText': _cueController.text,
        'summaryText': _summaryController.text,
      },
      if (_currentTemplate != null) 'templateId': _currentTemplate!.id,
      'textBoxes': _textBoxes.map((b) => b.toJson()).toList(),
      'stickers': _stickers.map((s) => s.toJson()).toList(),
      'checkItems': _checkItems.map((c) => c.toJson()).toList(),
    });

    final defaultTitle = _currentPageStyle != null
        ? (_noteTitleController.text.trim().isNotEmpty
            ? _noteTitleController.text.trim()
            : '${_currentPageStyle!.sizeOption.title} ${_currentPageStyle!.pageType.name.toUpperCase()}')
        : (_currentTemplate?.title ?? 'برگه یادداشت');

    final defaultSubtitle = _currentPageStyle != null
        ? (_noteBodyController.text.trim().isNotEmpty
            ? _noteBodyController.text.trim().split('\n').first
            : 'الگوی ${_currentPageStyle!.sizeOption.title} - ${_currentPageStyle!.pageType.name}')
        : (_textBoxes.isNotEmpty && _textBoxes.first.text.isNotEmpty
            ? _textBoxes.first.text
            : 'یادداشت ثبت‌شده');

    final journal = JournalItem(
      id: widget.existingJournal?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: widget.existingJournal?.title ?? defaultTitle,
      subtitle: defaultSubtitle,
      category: _currentPageStyle != null ? 'ساخت برگه' : (_currentTemplate?.categoryId ?? 'عمومی'),
      createdAt: widget.existingJournal?.createdAt ?? DateTime.now(),
      pageCount: (widget.existingJournal?.pageCount ?? 0) + 1,
      gradientColors: _currentPageStyle != null
          ? [
              _currentPageStyle!.backgroundColor == Colors.white
                  ? const Color(0xFFFF7043)
                  : _currentPageStyle!.backgroundColor,
              const Color(0xFFFF8A65),
            ]
          : [
              _currentTemplate?.themeColor ?? AppTheme.primaryColor,
              (_currentTemplate?.themeColor ?? AppTheme.primaryColor).withValues(alpha: 0.8),
            ],
      icon: _currentPageStyle != null
          ? _currentPageStyle!.sizeOption.icon
          : (_currentTemplate?.icon ?? Icons.description_rounded),
      content: serializedData,
      tags: _currentPageStyle != null
          ? [_currentPageStyle!.sizeOption.title, _currentPageStyle!.pageType.name, 'یادداشت شخصی']
          : (_currentTemplate?.tags ?? ['یادداشت']),
      isFavorite: widget.existingJournal?.isFavorite ?? false,
    );

    widget.onSave(journal);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.white),
            SizedBox(width: 8),
            Text('برگه یادداشت با موفقیت ذخیره شد.'),
          ],
        ),
        backgroundColor: AppTheme.primaryColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
    Navigator.pop(context);
  }

  Future<void> _exportPageToJson() async {
    try {
      final page = NotebookPageModel(
        id: widget.existingJournal?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        title: widget.existingJournal?.title ?? (_currentTemplate?.title ?? 'برگه یادداشت'),
        pageStyle: _currentPageStyle,
        templateId: _currentTemplate?.id,
        noteTitle: _noteTitleController.text,
        noteBody: _noteBodyController.text,
        cueText: _cueController.text,
        summaryText: _summaryController.text,
        textBoxes: _textBoxes,
        stickers: _stickers,
        checkItems: _checkItems,
      );

      final res = await NotebookExportService.instance.exportPageToJson(page, associatedTemplate: _currentTemplate);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res.userMessage),
            backgroundColor: res.isSuccess ? const Color(0xFF2E7D32) : Colors.red.shade700,
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

  Future<void> _importPageFromJson() async {
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

        if (importRes.isSuccess && (importRes.page != null || importRes.template != null)) {
          if (importRes.template != null) {
            JournalTemplate.registerTemplate(importRes.template!);
            NotebookStorageService.instance.saveOrUpdateCustomTemplate(importRes.template!);
          }
          setState(() {
            if (importRes.template != null) {
              _currentTemplate = importRes.template;
              _currentPageStyle = null; // Clear pageStyle so template and text boxes render properly
            }
            if (importRes.page != null) {
              final p = importRes.page!;
              _noteTitleController.text = p.noteTitle;
              _noteBodyController.text = p.noteBody;
              _cueController.text = p.cueText;
              _summaryController.text = p.summaryText;
              _textBoxes.clear();
              _textBoxes.addAll(p.textBoxes);
              _stickers.clear();
              _stickers.addAll(p.stickers);
              _checkItems.clear();
              _checkItems.addAll(p.checkItems);

              if (p.templateId != null && _currentTemplate == null) {
                final found = JournalTemplate.findTemplateById(p.templateId);
                if (found != null) {
                  _currentTemplate = found;
                  _currentPageStyle = null;
                }
              }
            }
          });
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
          SnackBar(content: Text('خطا در خواندن فایل JSON: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPageStyleMode = _currentPageStyle != null;

    return Scaffold(
      backgroundColor: const Color(0xFFE5E8EC),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: SafeArea(
            bottom: false,
            child: Row(
              children: [
                IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: Colors.black87),
                  ),
                  onPressed: () => Navigator.pop(context),
                ),

                const SizedBox(width: 4),
                const ProBadge(),

                const Spacer(),

                // Import JSON Action
                IconButton(
                  tooltip: 'ورود برگه از فایل JSON',
                  icon: const Icon(Icons.file_download_outlined, color: Color(0xFF1565C0), size: 22),
                  onPressed: _importPageFromJson,
                ),

                // Export JSON Action
                IconButton(
                  tooltip: 'خروجی لایه‌باز JSON برگه',
                  icon: const Icon(Icons.file_upload_outlined, color: Color(0xFF2E7D32), size: 22),
                  onPressed: _exportPageToJson,
                ),

                // Add Sticker Action
                IconButton(
                  tooltip: 'افزودن استیکر',
                  icon: const Icon(Icons.auto_awesome_rounded, color: AppTheme.primaryColor, size: 22),
                  onPressed: () => StickersSheet.show(context, onStickerSelected: _addNewSticker),
                ),

                // Add Text Box Action (Only in template mode)
                if (!isPageStyleMode)
                  TextButton.icon(
                    onPressed: () => _addNewTextBox(),
                    icon: const Icon(Icons.add_circle_outline_rounded, size: 18, color: AppTheme.primaryColor),
                    label: const Text(
                      '+ باکس متن',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                    ),
                  ),

                const SizedBox(width: 6),

                // Save Button
                ElevatedButton(
                  onPressed: _saveJournal,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                  child: const Text('ذخیره (Save)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // Sheet Canvas Area with InteractiveViewer
          Expanded(
            child: InteractiveViewer(
              minScale: 0.8,
              maxScale: 3.5,
              boundaryMargin: const EdgeInsets.all(40),
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: isPageStyleMode ? 580 : 420),
                    child: InteractiveTemplateSheet(
                      template: _currentTemplate,
                      pageStyle: _currentPageStyle,
                      noteTitleController: _noteTitleController,
                      noteBodyController: _noteBodyController,
                      cueController: _cueController,
                      summaryController: _summaryController,
                      fontSize: _currentFontSize,
                      fontName: _currentFontName,
                      inkColor: _currentInkColor,
                      textAlign: _textAlign,
                      isBold: _isBold,
                      isItalic: _isItalic,
                      highlightColor: _currentHighlightColor,
                      textBoxes: _textBoxes,
                      stickers: _stickers,
                      checkItems: _checkItems,
                      selectedTextBoxId: _selectedTextBoxId,
                      selectedStickerId: _selectedStickerId,
                      onToggleCheckItem: _toggleCheckItem,
                      onSelectTextBox: (id) {
                        setState(() {
                          _selectedTextBoxId = id;
                          _selectedStickerId = null;
                          for (final b in _textBoxes) {
                            b.isSelected = b.id == id;
                          }
                          for (final s in _stickers) {
                            s.isSelected = false;
                          }
                        });
                      },
                      onPositionChanged: (id, newPos) {
                        setState(() {
                          final box = _textBoxes.firstWhere((b) => b.id == id);
                          box.position = newPos;
                        });
                      },
                      onSizeChanged: (id, newW, newH) {
                        setState(() {
                          final box = _textBoxes.firstWhere((b) => b.id == id);
                          box.width = newW;
                          box.height = newH;
                        });
                      },
                      onTextChanged: (id, newText) {
                        final box = _textBoxes.firstWhere((b) => b.id == id);
                        box.text = newText;
                      },
                      onDeleteTextBox: (id) {
                        setState(() {
                          _textBoxes.removeWhere((b) => b.id == id);
                          if (_selectedTextBoxId == id) {
                            _selectedTextBoxId = _textBoxes.isNotEmpty ? _textBoxes.last.id : null;
                          }
                        });
                      },
                      onAutoAdvance: (currentId) {
                        final currentIndex = _textBoxes.indexWhere((b) => b.id == currentId);
                        if (currentIndex != -1 && currentIndex + 1 < _textBoxes.length) {
                          final nextBox = _textBoxes[currentIndex + 1];
                          setState(() {
                            _selectedTextBoxId = nextBox.id;
                            _selectedStickerId = null;
                            for (final b in _textBoxes) {
                              b.isSelected = b.id == nextBox.id;
                            }
                          });
                        }
                      },
                      onSelectSticker: (id) {
                        setState(() {
                          _selectedStickerId = id;
                          _selectedTextBoxId = null;
                          for (final s in _stickers) {
                            s.isSelected = s.id == id;
                          }
                          for (final b in _textBoxes) {
                            b.isSelected = false;
                          }
                        });
                      },
                      onStickerPositionChanged: (id, newPos) {
                        setState(() {
                          final stk = _stickers.firstWhere((s) => s.id == id);
                          stk.position = newPos;
                        });
                      },
                      onStickerScaleChanged: (id, newScale) {
                        setState(() {
                          final stk = _stickers.firstWhere((s) => s.id == id);
                          stk.scale = newScale;
                        });
                      },
                      onDeleteSticker: (id) {
                        setState(() {
                          _stickers.removeWhere((s) => s.id == id);
                          if (_selectedStickerId == id) {
                            _selectedStickerId = _stickers.isNotEmpty ? _stickers.last.id : null;
                          }
                        });
                      },
                      onCanvasTap: (tapPos) {
                        if (isPageStyleMode) {
                          // Natural page style note: clicking focuses writing, no floating boxes spawned
                          return;
                        }
                        // Deselect any active box/sticker on background click (Behavior #1: No extra boxes created)
                        if (_selectedTextBoxId != null || _selectedStickerId != null) {
                          setState(() {
                            _selectedTextBoxId = null;
                            _selectedStickerId = null;
                            for (final b in _textBoxes) {
                              b.isSelected = false;
                            }
                            for (final s in _stickers) {
                              s.isSelected = false;
                            }
                          });
                        }
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Bottom Editor Toolbar
          EditorBottomToolbar(
            isPageStyleMode: isPageStyleMode,
            hasSelectedBox: _selectedTextBoxId != null,
            hasSelectedSticker: _selectedStickerId != null,
            onAddTextBox: () => _addNewTextBox(),
            onAddSticker: () => StickersSheet.show(context, onStickerSelected: _addNewSticker),
            onDeselect: () {
              setState(() {
                _selectedTextBoxId = null;
                _selectedStickerId = null;
                for (final b in _textBoxes) {
                  b.isSelected = false;
                }
                for (final s in _stickers) {
                  s.isSelected = false;
                }
              });
            },
            onFontPicker: _onFontPicker,
            onColorPicker: _onColorPicker,
            onToggleAlign: _toggleTextAlign,
            onToggleBold: _toggleBold,
            onToggleHighlight: _toggleHighlight,
            onDeleteSelected: _deleteSelected,
          ),
        ],
      ),
    );
  }
}
