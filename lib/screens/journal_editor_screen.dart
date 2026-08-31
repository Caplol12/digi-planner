import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/template_model.dart';
import '../models/page_style_model.dart';
import '../models/journal_model.dart';
import '../models/text_box_model.dart';
import '../models/sticker_model.dart';
import '../models/ai_layout_model.dart';
import '../services/ai_vision_layout_service.dart';
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
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          text: 'برای شروع نوشتن اینجا کلیک کنید...',
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

      final newBox = TextBoxItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text: '',
        position: position ?? Offset(60, 100 + (_textBoxes.length * 35.0) % 300),
        width: 180,
        height: 36,
        fontSize: _currentFontSize,
        fontName: _currentFontName,
        inkColor: _currentInkColor,
        isSelected: true,
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
        id: DateTime.now().millisecondsSinceEpoch.toString(),
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

  void _showAIChatAssistant() {
    final chatInputCtrl = TextEditingController();
    List<String> chips = [
      'یک چک‌لیست اولویت‌ها اضافه کن',
      'باکس یادداشت رو ۳ خط بلندتر کن',
      'باکس‌ها رو متقارن و تراز کن',
      'یک کادر تاریخ در بالا اضافه کن',
    ];
    String? lastAiMessage;
    bool isLoading = false;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 16,
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            ),
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
                const SizedBox(height: 14),
                const Row(
                  children: [
                    Icon(Icons.auto_awesome_rounded, color: Color(0xFFFF7043), size: 22),
                    SizedBox(width: 8),
                    Text(
                      'دستیار هوش مصنوعی ویرایشگر (AI Layout Chat)',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'با دستور متنی می‌توانید ساختار باکس‌ها را تغییر دهید یا کادرهای جدید اضافه کنید.',
                  style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 14),
                if (lastAiMessage != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.smart_toy_rounded, size: 18, color: AppTheme.primaryColor),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            lastAiMessage!,
                            style: const TextStyle(fontSize: 12, color: Color(0xFF334155), height: 1.35),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (isLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                        SizedBox(width: 8),
                        Text('هوش مصنوعی در حال اعمال تغییرات...', style: TextStyle(fontSize: 11, color: Colors.grey)),
                      ],
                    ),
                  ),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: chips.map((chip) {
                    return ActionChip(
                      label: Text(chip, style: const TextStyle(fontSize: 11)),
                      backgroundColor: const Color(0xFFF8FAFC),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      onPressed: () async {
                        setModalState(() => isLoading = true);
                        final detectedList = _textBoxes.map((b) => DetectedBox(
                          id: b.id,
                          label: b.text,
                          type: DetectedBoxType.freeText,
                          normalizedX: (b.position.dx / 400).clamp(0.0, 1.0),
                          normalizedY: (b.position.dy / 600).clamp(0.0, 1.0),
                          normalizedWidth: (b.width / 400).clamp(0.0, 1.0),
                          normalizedHeight: (b.height / 600).clamp(0.0, 1.0),
                        )).toList();

                        final res = await AiVisionLayoutService.processChatEditCommand(
                          userCommand: chip,
                          currentBoxes: detectedList,
                        );

                        setState(() {
                          _textBoxes.clear();
                          const canvasSize = Size(400, 600);
                          for (final box in res.updatedBoxes) {
                            _textBoxes.add(box.toTextBoxItem(canvasSize));
                          }
                          if (_textBoxes.isNotEmpty) {
                            _selectedTextBoxId = _textBoxes.last.id;
                          }
                        });

                        setModalState(() {
                          isLoading = false;
                          lastAiMessage = res.assistantMessage;
                          chips = res.suggestionChips;
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: chatInputCtrl,
                        style: const TextStyle(fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'دستور متنی (مثلاً: یک کادر تاریخ در بالا اضافه کن)...',
                          hintStyle: TextStyle(fontSize: 11.5, color: Colors.grey.shade400),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () async {
                        final text = chatInputCtrl.text.trim();
                        if (text.isEmpty) return;
                        chatInputCtrl.clear();
                        setModalState(() => isLoading = true);

                        final detectedList = _textBoxes.map((b) => DetectedBox(
                          id: b.id,
                          label: b.text,
                          type: DetectedBoxType.freeText,
                          normalizedX: (b.position.dx / 400).clamp(0.0, 1.0),
                          normalizedY: (b.position.dy / 600).clamp(0.0, 1.0),
                          normalizedWidth: (b.width / 400).clamp(0.0, 1.0),
                          normalizedHeight: (b.height / 600).clamp(0.0, 1.0),
                        )).toList();

                        final res = await AiVisionLayoutService.processChatEditCommand(
                          userCommand: text,
                          currentBoxes: detectedList,
                        );

                        setState(() {
                          _textBoxes.clear();
                          const canvasSize = Size(400, 600);
                          for (final box in res.updatedBoxes) {
                            _textBoxes.add(box.toTextBoxItem(canvasSize));
                          }
                          if (_textBoxes.isNotEmpty) {
                            _selectedTextBoxId = _textBoxes.last.id;
                          }
                        });

                        setModalState(() {
                          isLoading = false;
                          lastAiMessage = res.assistantMessage;
                          chips = res.suggestionChips;
                        });
                      },
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xFFFF7043),
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.send_rounded, size: 18),
                    ),
                  ],
                ),
              ],
            ),
          ),
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
      'textBoxes': _textBoxes.map((b) => b.toJson()).toList(),
      'stickers': _stickers.map((s) => s.toJson()).toList(),
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
                    constraints: const BoxConstraints(maxWidth: 580),
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
                      selectedTextBoxId: _selectedTextBoxId,
                      selectedStickerId: _selectedStickerId,
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
            onAIChatEdit: _showAIChatAssistant,
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
