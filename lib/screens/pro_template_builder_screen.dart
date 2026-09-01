import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../models/ai_layout_model.dart';
import '../models/template_model.dart';
import '../models/journal_model.dart';
import '../services/ai_vision_layout_service.dart';
import '../services/notebook_export_service.dart';
import '../services/supabase_service.dart';
import '../widgets/pro_badge.dart';
import '../theme/app_theme.dart';
import 'journal_editor_screen.dart';

class ProTemplateBuilderScreen extends StatefulWidget {
  final Function(JournalItem) onJournalCreated;

  const ProTemplateBuilderScreen({
    super.key,
    required this.onJournalCreated,
  });

  @override
  State<ProTemplateBuilderScreen> createState() => _ProTemplateBuilderScreenState();
}

class _ProTemplateBuilderScreenState extends State<ProTemplateBuilderScreen> {
  int _currentStep = 0; // 0: Select/Input Image, 1: AI Scan & Text Boxes

  String _selectedImagePath = 'assets/templates/daily_planner.jpg';
  Uint8List? _selectedImageBytes;
  String? _selectedFileName;

  bool _isAnalyzing = false;
  AILayoutResult? _analysisResult;
  String? _selectedBoxId;

  // Conversational Assistant State
  final TextEditingController _chatController = TextEditingController();
  final List<Map<String, String>> _chatHistory = [];
  bool _isChatLoading = false;
  List<String> _currentChips = [
    'یک چک‌لیست اولویت‌ها اضافه کن',
    'باکس یادداشت رو ۳ خط بلندتر کن',
    'باکس‌ها رو متقارن و تراز کن',
    'یک کادر تاریخ در بالا اضافه کن',
  ];

  @override
  void initState() {
    super.initState();
    _refreshAiConfig();
  }

  Future<void> _refreshAiConfig() async {
    await AiConfigService.getConfig(forceRefresh: false);
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _chatController.dispose();
    super.dispose();
  }

  Future<void> _pickImageFile() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.image,
        withData: true, // Reads bytes for Cross-platform (Desktop, Web, Mobile)
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        setState(() {
          _selectedImageBytes = file.bytes;
          _selectedImagePath = file.path ?? '';
          _selectedFileName = file.name;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Expanded(child: Text('تصویر «${file.name}» با موفقیت بارگذاری شد.')),
                ],
              ),
              backgroundColor: const Color(0xFF2E7D32),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطا در انتخاب فایل تصویر: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  Future<void> _startAIScanningStep() async {
    setState(() {
      _currentStep = 1;
      _isAnalyzing = true;
      _selectedBoxId = null;
    });

    try {
      final result = await AiVisionLayoutService.detectLayout(
        imagePath: _selectedImagePath,
        imageBytes: _selectedImageBytes,
        aspectRatio: 2 / 3,
      );

      if (mounted) {
        setState(() {
          _analysisResult = result;
          _isAnalyzing = false;
          _chatHistory.clear();
          _chatHistory.add({
            'role': 'ai',
            'text': 'هوش مصنوعی تصویر برگه را اسکن کرد (${result.analysisEngine}) و ${_analysisResult!.detectedBoxes.length} باکس متن متناسب با خطوط و بخش‌ها قرار داد.',
          });
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isAnalyzing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطا در تحلیل هوش مصنوعی: $e'),
            backgroundColor: Colors.red.shade700,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _handleChatSubmit(String message) async {
    if (message.trim().isEmpty || _analysisResult == null) return;
    _chatController.clear();

    setState(() {
      _isChatLoading = true;
      _chatHistory.add({'role': 'user', 'text': message});
    });

    final res = await AiVisionLayoutService.processChatEditCommand(
      userCommand: message,
      currentBoxes: _analysisResult!.detectedBoxes,
    );

    if (mounted) {
      setState(() {
        _isChatLoading = false;
        _analysisResult = AILayoutResult(
          imagePath: _analysisResult!.imagePath,
          aspectRatio: _analysisResult!.aspectRatio,
          title: _analysisResult!.title,
          detectedBoxes: res.updatedBoxes,
          analysisEngine: _analysisResult!.analysisEngine,
        );
        _chatHistory.add({'role': 'ai', 'text': res.assistantMessage});
        _currentChips = res.suggestionChips;
      });
    }
  }

  void _proceedToEditor() {
    if (_analysisResult == null) return;

    // Convert detected boxes into actual TextBoxItems for the editor canvas
    const canvasSize = Size(420, 630);
    final textBoxes = _analysisResult!.detectedBoxes.map((b) => b.toTextBoxItem(canvasSize)).toList();
    final serializedData = jsonEncode({
      'textBoxes': textBoxes.map((b) => b.toJson()).toList(),
    });

    final customTemplate = JournalTemplate(
      id: 'ai_template_${DateTime.now().millisecondsSinceEpoch}',
      title: _selectedFileName != null ? 'قالب ${_selectedFileName!}' : 'قالب هوش مصنوعی',
      categoryId: 'ai_custom',
      subtitle: 'طراحی شده با AI Vision و باکس‌های متنی تطبیقی',
      themeColor: const Color(0xFFFF7043),
      cardBackground: const Color(0xFFFFF8F6),
      icon: Icons.auto_awesome_rounded,
      imageAsset: _selectedImagePath.isNotEmpty ? _selectedImagePath : null,
      imageBytes: _selectedImageBytes,
      tags: ['AI Vision', 'قالب حرفه‌ای', 'طراحی خودکار'],
      sections: [],
    );

    final initialJournal = JournalItem(
      id: 'ai_journal_${DateTime.now().millisecondsSinceEpoch}',
      title: _selectedFileName != null ? 'ژورنال ${_selectedFileName!}' : 'قالب اختصاصی هوش مصنوعی',
      subtitle: 'شناسایی خودکار ${_analysisResult!.detectedBoxes.length} باکس متن',
      category: 'قالب حرفه‌ای',
      createdAt: DateTime.now(),
      pageCount: 1,
      gradientColors: const [Color(0xFFFF7043), Color(0xFFFF8A65)],
      icon: Icons.auto_awesome_rounded,
      content: serializedData,
      tags: ['AI Vision', 'قالب حرفه‌ای'],
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => JournalEditorScreen(
          template: customTemplate,
          existingJournal: initialJournal,
          onSave: (j) {
            widget.onJournalCreated(j);
            Navigator.pop(context); // Close builder screen
          },
        ),
      ),
    );
  }

  Future<void> _exportAiLayoutToJson() async {
    if (_analysisResult == null) return;
    try {
      final file = await NotebookExportService.instance.exportAiLayoutToJson(_analysisResult!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✨ فایل JSON چیدمان لایه‌باز ذخیره شد:\n${file.path}'),
            backgroundColor: const Color(0xFF2E7D32),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطا در خروجی چیدمان: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _importAiLayoutFromJson() async {
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

        if (importRes.isSuccess && (importRes.aiLayout != null || importRes.template != null)) {
          setState(() {
            _currentStep = 1;
            if (importRes.aiLayout != null) {
              _analysisResult = importRes.aiLayout;
            } else if (importRes.template != null) {
              final tmpl = importRes.template!;
              _selectedImageBytes = tmpl.imageBytes;
              _selectedImagePath = tmpl.imageAsset ?? '';
              _selectedFileName = tmpl.title;
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
          SnackBar(content: Text('خطا در بارگذاری فایل JSON: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _buildRenderedImageWidget({required BoxFit fit}) {
    if (_selectedImageBytes != null) {
      return Image.memory(
        _selectedImageBytes!,
        fit: fit,
      );
    } else if (_selectedImagePath.isNotEmpty && !_selectedImagePath.startsWith('assets/')) {
      final file = File(_selectedImagePath);
      if (file.existsSync()) {
        return Image.file(
          file,
          fit: fit,
        );
      }
    }
    return Image.asset(
      _selectedImagePath.isNotEmpty ? _selectedImagePath : 'assets/templates/daily_planner.jpg',
      fit: fit,
      errorBuilder: (ctx, err, stack) => Container(
        color: const Color(0xFFF1F5F9),
        child: const Center(
          child: Icon(Icons.broken_image_rounded, size: 48, color: Colors.grey),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final aiConfig = AiConfigService.currentConfig;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: Color(0xFF1E293B)),
          onPressed: () {
            if (_currentStep == 1) {
              setState(() => _currentStep = 0);
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: Row(
          children: [
            const Text(
              'ساخت قالب با هوش مصنوعی',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
            ),
            const SizedBox(width: 8),
            const ProBadge(),
            const Spacer(),
            // Import JSON Button
            IconButton(
              tooltip: 'ورود فایل لایه‌باز JSON چیدمان',
              icon: const Icon(Icons.file_download_outlined, color: Color(0xFF1565C0), size: 20),
              onPressed: _importAiLayoutFromJson,
            ),
            // Export JSON Button
            if (_analysisResult != null)
              IconButton(
                tooltip: 'خروجی لایه‌باز JSON چیدمان',
                icon: const Icon(Icons.file_upload_outlined, color: Color(0xFF2E7D32), size: 20),
                onPressed: _exportAiLayoutToJson,
              ),
            // AI Model Pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF1EB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFFCCBC)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_done_rounded, size: 12, color: Color(0xFFE65100)),
                  const SizedBox(width: 4),
                  Text(
                    aiConfig.model,
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFBF360C)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Step Progress Indicator Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            color: Colors.white,
            child: Row(
              children: [
                _buildStepHeader(
                  stepNumber: 1,
                  title: 'انتخاب تصویر برگه',
                  isActive: _currentStep == 0,
                  isDone: _currentStep > 0,
                ),
                Expanded(
                  child: Container(
                    height: 2,
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                    color: _currentStep > 0 ? const Color(0xFFFF7043) : Colors.grey.shade300,
                  ),
                ),
                _buildStepHeader(
                  stepNumber: 2,
                  title: 'اسکن هوشمند و تعیین باکس‌ها',
                  isActive: _currentStep == 1,
                  isDone: false,
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppTheme.dividerLight),

          // Main Step Content
          Expanded(
            child: _currentStep == 0 ? _buildStep1ImageInput() : _buildStep2AIScanningAndBoxes(),
          ),
        ],
      ),
    );
  }

  Widget _buildStepHeader({
    required int stepNumber,
    required String title,
    required bool isActive,
    required bool isDone,
  }) {
    Color circleColor;
    Color textColor;
    if (isDone) {
      circleColor = const Color(0xFF2E7D32);
      textColor = const Color(0xFF2E7D32);
    } else if (isActive) {
      circleColor = const Color(0xFFFF7043);
      textColor = const Color(0xFFBF360C);
    } else {
      circleColor = Colors.grey.shade400;
      textColor = Colors.grey.shade600;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: circleColor,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: isDone
                ? const Icon(Icons.check, size: 16, color: Colors.white)
                : Text(
                    stepNumber.toString(),
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: isActive || isDone ? FontWeight.bold : FontWeight.normal,
            color: textColor,
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------
  // STEP 1: Select / Input Image
  // -------------------------------------------------------------
  Widget _buildStep1ImageInput() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner Info
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFF1EB), Color(0xFFFFE3D8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFFFCCBC)),
            ),
            child: const Row(
              children: [
                Icon(Icons.add_photo_alternate_rounded, color: Color(0xFFFF7043), size: 28),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'مرحله اول: تصویر برگه را وارد کنید',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFFBF360C)),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'تصویر برگه ژورنال، پلنر یا دفتر خود را انتخاب کنید تا هوش مصنوعی باکس‌های متنی را روی خطوط و بخش‌ها قرار دهد.',
                        style: TextStyle(fontSize: 11.5, color: Color(0xFFD84315), height: 1.3),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Upload Card / Action (Fully Functional File Picker)
          GestureDetector(
            onTap: _pickImageFile,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFFF7043).withValues(alpha: 0.6), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF7043).withValues(alpha: 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: const BoxDecoration(
                      color: Color(0xFFFFEBE5),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.cloud_upload_rounded, size: 38, color: Color(0xFFFF7043)),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _selectedFileName != null ? 'فایل انتخاب شده: $_selectedFileName' : 'انتخاب تصویر از حافظه دستگاه',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'پشتیبانی از انواع فرمت‌های JPG, PNG و عکس‌های ژورنال دست‌نویس',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _pickImageFile,
                    icon: const Icon(Icons.folder_open_rounded, size: 18),
                    label: const Text('انتخاب فایل تصویر', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF7043),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Preset Sample Templates Options
          const Text(
            'یا انتخاب از الگوهای آماده زیر:',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildPresetThumbnail(
                  path: 'assets/templates/daily_planner.jpg',
                  title: 'پلنر روزانه مینیمال',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildPresetThumbnail(
                  path: 'assets/templates/adhd_planner.jpg',
                  title: 'پلنر تمرکز ADHD',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildPresetThumbnail(
                  path: 'assets/templates/gratitude_diary.jpg',
                  title: 'شکرگزاری گلدار',
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Selected Image Preview
          const Text(
            'پیش‌نمایش تصویر انتخابی:',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
          ),
          const SizedBox(height: 12),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 340, maxHeight: 420),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: _buildRenderedImageWidget(fit: BoxFit.contain),
                ),
              ),
            ),
          ),
          const SizedBox(height: 30),

          // Next Step Button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _startAIScanningStep,
              icon: const Icon(Icons.auto_awesome_rounded, size: 20),
              label: const Text(
                'مرحله بعد: اسکن و ساخت باکس‌های متن با هوش مصنوعی',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF7043),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 3,
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildPresetThumbnail({required String path, required String title}) {
    final isSelected = _selectedImagePath == path && _selectedImageBytes == null;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedImagePath = path;
          _selectedImageBytes = null;
          _selectedFileName = null;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFFFF7043) : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(path, height: 75, width: double.infinity, fit: BoxFit.cover),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? const Color(0xFFBF360C) : const Color(0xFF334155),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // STEP 2: AI Scanning & Box Placement
  // -------------------------------------------------------------
  Widget _buildStep2AIScanningAndBoxes() {
    if (_isAnalyzing) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(
                width: 60,
                height: 60,
                child: CircularProgressIndicator(
                  strokeWidth: 4,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF7043)),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'هوش مصنوعی در حال اسکن دیداری برگه...',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
              ),
              const SizedBox(height: 8),
              Text(
                'شناسایی خطوط نگارش، جداول، عناوین و تنظیم باکس‌های متن متناسب با الگو',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner Success
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFA5D6A7)),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Color(0xFF2E7D32), size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'هوش مصنوعی ${_analysisResult?.detectedBoxes.length ?? 0} باکس متن را متناسب با خطوط تصویر قرار داد.',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF1B5E20)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Canvas with Bounding Boxes
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: AspectRatio(
                aspectRatio: 2 / 3,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return Stack(
                          fit: StackFit.expand,
                          children: [
                            // Background Image
                            _buildRenderedImageWidget(fit: BoxFit.cover),

                            // AI Detected Bounding Boxes Layer
                            if (_analysisResult != null)
                              ..._analysisResult!.detectedBoxes.map((box) {
                                final isSelected = box.id == _selectedBoxId;
                                final left = box.normalizedX * constraints.maxWidth;
                                final top = box.normalizedY * constraints.maxHeight;
                                final width = box.normalizedWidth * constraints.maxWidth;
                                final height = box.normalizedHeight * constraints.maxHeight;

                                return Positioned(
                                  left: left,
                                  top: top,
                                  width: width,
                                  height: height,
                                  child: GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _selectedBoxId = isSelected ? null : box.id;
                                      });
                                    },
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 180),
                                      decoration: BoxDecoration(
                                        color: box.badgeColor.withValues(alpha: isSelected ? 0.35 : 0.18),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: isSelected ? Colors.white : box.badgeColor,
                                          width: isSelected ? 2.5 : 1.5,
                                        ),
                                        boxShadow: [
                                          if (isSelected)
                                            BoxShadow(
                                              color: box.badgeColor.withValues(alpha: 0.4),
                                              blurRadius: 10,
                                              offset: const Offset(0, 2),
                                            ),
                                        ],
                                      ),
                                      padding: EdgeInsets.symmetric(
                                        horizontal: width < 50 ? 2 : 4,
                                        vertical: height < 30 ? 1 : 4,
                                      ),
                                      child: ClipRect(
                                        child: LayoutBuilder(
                                          builder: (context, boxConstraints) {
                                            // 1. Tiny box: height < 28 or width < 45
                                            if (boxConstraints.maxHeight < 28 || boxConstraints.maxWidth < 45) {
                                              return Center(
                                                child: FittedBox(
                                                  fit: BoxFit.scaleDown,
                                                  alignment: AlignmentDirectional.centerStart,
                                                  child: Text(
                                                    box.label.isNotEmpty ? box.label : box.typeTitlePersian,
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                      fontSize: 8.5,
                                                      fontWeight: FontWeight.bold,
                                                      color: Colors.black.withValues(alpha: 0.85),
                                                    ),
                                                  ),
                                                ),
                                              );
                                            }

                                            // 2. Compact box: 28 <= height < 46
                                            if (boxConstraints.maxHeight < 46) {
                                              return FittedBox(
                                                fit: BoxFit.scaleDown,
                                                alignment: AlignmentDirectional.topStart,
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                                      decoration: BoxDecoration(
                                                        color: box.badgeColor,
                                                        borderRadius: BorderRadius.circular(3),
                                                      ),
                                                      child: Text(
                                                        box.typeTitlePersian,
                                                        style: const TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 8,
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      box.label,
                                                      style: TextStyle(
                                                        fontSize: 9,
                                                        fontWeight: FontWeight.bold,
                                                        color: Colors.black.withValues(alpha: 0.8),
                                                      ),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ],
                                                ),
                                              );
                                            }

                                            // 3. Regular / Large box: height >= 46
                                            return FittedBox(
                                              fit: BoxFit.scaleDown,
                                              alignment: AlignmentDirectional.topStart,
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  // Badge Tag
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: box.badgeColor,
                                                      borderRadius: BorderRadius.circular(4),
                                                    ),
                                                    child: Text(
                                                      box.typeTitlePersian,
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 9,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    box.label,
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.bold,
                                                      color: Colors.black.withValues(alpha: 0.8),
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Conversational AI Box Modifier Assistant
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.smart_toy_rounded, color: Color(0xFFFF7043), size: 18),
                    SizedBox(width: 8),
                    Text('دستیار هوشمند چیدمان کادرها (اختیاری)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 8),

                // Chat history
                ..._chatHistory.map((msg) {
                  final isAi = msg['role'] == 'ai';
                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isAi ? const Color(0xFFF1F5F9) : const Color(0xFFFFEBE5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      msg['text']!,
                      style: TextStyle(fontSize: 11.5, color: isAi ? const Color(0xFF334155) : const Color(0xFFBF360C)),
                    ),
                  );
                }),

                if (_isChatLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2)),
                        SizedBox(width: 6),
                        Text('هوش مصنوعی در حال اعمال تغییرات...', style: TextStyle(fontSize: 11, color: Colors.grey)),
                      ],
                    ),
                  ),

                // Suggestion chips
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _currentChips.map((chip) {
                    return ActionChip(
                      label: Text(chip, style: const TextStyle(fontSize: 10.5)),
                      backgroundColor: const Color(0xFFF8FAFC),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      onPressed: () => _handleChatSubmit(chip),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 8),

                // Chat Input
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _chatController,
                        style: const TextStyle(fontSize: 12),
                        decoration: InputDecoration(
                          hintText: 'دستور تغییر کادرها (مثلاً: یک چک‌لیست اضافه کن)...',
                          hintStyle: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                          ),
                        ),
                        onSubmitted: _handleChatSubmit,
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      onPressed: () => _handleChatSubmit(_chatController.text),
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xFFFF7043),
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.send_rounded, size: 16),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Step 2 Action Buttons
          Row(
            children: [
              Expanded(
                flex: 1,
                child: OutlinedButton(
                  onPressed: () => setState(() => _currentStep = 0),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF94A3B8)),
                    foregroundColor: const Color(0xFF475569),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('تغییر تصویر', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: _proceedToEditor,
                  icon: const Icon(Icons.edit_note_rounded, size: 20),
                  label: const Text(
                    'تایید و ورود به ویرایشگر برگه ➔',
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF7043),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 3,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}
