import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/notebook_model.dart';
import 'notebook_cover_widget.dart';
import 'color_picker_sheet.dart';

class EditNotebookDialog extends StatefulWidget {
  final NotebookModel? notebook;
  final Function(NotebookModel) onSave;

  const EditNotebookDialog({
    super.key,
    this.notebook,
    required this.onSave,
  });

  static Future<NotebookModel?> show(
    BuildContext context, {
    NotebookModel? notebook,
    required Function(NotebookModel) onSave,
  }) {
    return showDialog<NotebookModel>(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: EditNotebookDialog(
          notebook: notebook,
          onSave: onSave,
        ),
      ),
    );
  }

  @override
  State<EditNotebookDialog> createState() => _EditNotebookDialogState();
}

class _EditNotebookDialogState extends State<EditNotebookDialog> {
  late TextEditingController _titleController;
  late Color _selectedColor;
  String? _coverImagePath;

  // Preset Colors matching Image 1
  final List<Color> _presetColors = const [
    Color(0xFFF8BBD0), // Pastel Pink
    Color(0xFFA5D6A7), // Mint Green
    Color(0xFF90CAF9), // Sky Blue
    Color(0xFFCE93D8), // Lavender
    Color(0xFFE07A5F), // Coral / Terracotta (Active in screenshot)
    Color(0xFFFFCC80), // Warm Peach
    Color(0xFFB0BEC5), // Soft Slate
  ];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text: widget.notebook?.title ?? 'notebook 22',
    );
    _selectedColor = widget.notebook?.coverColor ?? const Color(0xFFE07A5F);
    _coverImagePath = widget.notebook?.coverImagePath;

    _titleController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _pickCoverFromGallery() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );
      if (result != null && result.files.isNotEmpty) {
        final path = result.files.first.path;
        if (path != null) {
          setState(() {
            _coverImagePath = path;
          });
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

  void _onSave() {
    final title = _titleController.text.trim().isEmpty ? 'دفترچه من' : _titleController.text.trim();
    final updated = (widget.notebook != null)
        ? widget.notebook!.copyWith(
            title: title,
            coverColor: _selectedColor,
            coverImagePath: _coverImagePath,
            updatedAt: DateTime.now(),
          )
        : NotebookModel(
            id: 'nb_${DateTime.now().millisecondsSinceEpoch}',
            title: title,
            coverColor: _selectedColor,
            coverImagePath: _coverImagePath,
            pages: [
              NotebookPageModel(
                id: 'p_${DateTime.now().millisecondsSinceEpoch}',
                title: 'برگه ۱',
              ),
            ],
          );

    widget.onSave(updated);
    Navigator.of(context).pop(updated);
  }

  @override
  Widget build(BuildContext context) {
    final isExisting = widget.notebook != null;

    return Container(
      constraints: const BoxConstraints(maxWidth: 420),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Bar: Close (X) on left, Confirm (Check) on right (Image 1)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Close button
                InkWell(
                  onTap: () => Navigator.of(context).pop(),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Icon(Icons.close_rounded, size: 20, color: Colors.grey.shade700),
                  ),
                ),

                Text(
                  isExisting ? 'ویرایش دفترچه' : 'دفترچه جدید',
                  style: GoogleFonts.vazirmatn(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1E293B),
                  ),
                ),

                // Save / Confirm checkmark button
                InkWell(
                  onTap: _onSave,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: const Icon(Icons.check_rounded, size: 20, color: Color(0xFF2E7D32)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Realistic Notebook Preview (Center)
            Center(
              child: NotebookCoverWidget(
                title: _titleController.text,
                coverColor: _selectedColor,
                coverImagePath: _coverImagePath,
                width: 210,
                height: 290,
                elevation: 14,
              ),
            ),
            const SizedBox(height: 22),

            // "Import From Gallery" Button (Image 1)
            Center(
              child: OutlinedButton.icon(
                onPressed: _pickCoverFromGallery,
                icon: const Icon(Icons.photo_library_outlined, size: 18, color: Color(0xFF475569)),
                label: Text(
                  'Import From Gallery',
                  style: GoogleFonts.vazirmatn(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF334155),
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  side: const BorderSide(color: Color(0xFF94A3B8), width: 1.4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  backgroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Title Input TextField (Image 1)
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: _titleController,
                textAlign: TextAlign.left,
                style: GoogleFonts.vazirmatn(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1E293B),
                ),
                decoration: InputDecoration(
                  hintText: 'notebook title',
                  hintStyle: TextStyle(color: Colors.grey.shade400, fontWeight: FontWeight.normal),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  border: InputBorder.none,
                  suffixIcon: _coverImagePath != null
                      ? IconButton(
                          tooltip: 'حذف تصویر گالری و بازگشت به رنگ',
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          onPressed: () => setState(() => _coverImagePath = null),
                        )
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Cover Color Header
            Text(
              'Cover Color',
              style: GoogleFonts.vazirmatn(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 10),

            // Color Swatches Row
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  // 1. Rainbow Gradient Wheel (Custom Color Picker)
                  GestureDetector(
                    onTap: () {
                      ColorPickerSheet.show(
                        context,
                        initialColor: _selectedColor,
                        onColorSelected: (color) {
                          setState(() {
                            _selectedColor = color;
                            _coverImagePath = null; // Revert to color
                          });
                        },
                      );
                    },
                    child: Container(
                      width: 46,
                      height: 46,
                      margin: const EdgeInsets.only(left: 6, right: 6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        gradient: const SweepGradient(
                          colors: [
                            Colors.red,
                            Colors.yellow,
                            Colors.green,
                            Colors.cyan,
                            Colors.blue,
                            Colors.purple,
                            Colors.red,
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(Icons.colorize_rounded, color: Colors.white, size: 20),
                      ),
                    ),
                  ),

                  // 2. Preset Rectangular Color Swatches
                  ..._presetColors.map((color) {
                    final isSelected = _selectedColor.toARGB32() == color.toARGB32() && _coverImagePath == null;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedColor = color;
                          _coverImagePath = null;
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 48,
                        height: 48,
                        margin: const EdgeInsets.symmetric(horizontal: 5),
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected ? const Color(0xFF1E293B) : Colors.black.withValues(alpha: 0.1),
                            width: isSelected ? 2.5 : 1.0,
                          ),
                          boxShadow: [
                            if (isSelected)
                              BoxShadow(
                                color: color.withValues(alpha: 0.5),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                          ],
                        ),
                        child: isSelected
                            ? Center(
                                child: Container(
                                  width: 14,
                                  height: 14,
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              )
                            : null,
                      ),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
