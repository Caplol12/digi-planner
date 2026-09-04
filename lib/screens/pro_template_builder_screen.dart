import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import '../models/ai_layout_model.dart';
import '../models/notebook_model.dart';
import '../models/template_model.dart';
import '../services/ai_subscription_service.dart';
import '../services/ai_vision_layout_service.dart';
import '../services/notebook_export_service.dart';
import '../services/notebook_storage_service.dart';
import '../services/supabase_service.dart';
import '../services/user_ai_preferences_service.dart';
import '../widgets/platform_image_helper.dart';
import '../widgets/pro_badge.dart';
import '../widgets/interactive_check_box_widget.dart';
import '../theme/app_theme.dart';
import 'premium_upgrade_screen.dart';

class ProTemplateBuilderScreen extends StatefulWidget {
  final Function(JournalTemplate template, NotebookPageModel initialPage) onTemplateCreated;

  const ProTemplateBuilderScreen({
    super.key,
    required this.onTemplateCreated,
  });

  @override
  State<ProTemplateBuilderScreen> createState() => _ProTemplateBuilderScreenState();
}

class _ProTemplateBuilderScreenState extends State<ProTemplateBuilderScreen> {
  int _currentStep = 0; // 0: Select/Input Image, 1: AI Scan & Text Boxes

  String _selectedImagePath = 'assets/templates/daily_planner.jpg';
  Uint8List? _selectedImageBytes;
  String? _selectedFileName;
  double _detectedImageAspectRatio = 2 / 3;

  bool _isAnalyzing = false;
  AILayoutResult? _analysisResult;
  String? _selectedBoxId;
  bool _isManualEditMode = false;
  bool _isDraggingBoxOrHandle = false;
  DetectedBox? _lastDeletedBox;
  int? _lastDeletedBoxIndex;

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
    await UserAiPreferencesService.ensureLoaded();
    await AiSubscriptionService.instance.ensureInitialized();
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
        final rawBytes = file.bytes ?? (file.path != null ? await readBytesFromPath(file.path!) : null);
        if (rawBytes == null || rawBytes.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('خطا در خواندن داده‌های تصویر انتخاب شده.'),
                backgroundColor: Colors.red.shade700,
              ),
            );
          }
          return;
        }

        double? detectedRatio;
        try {
          final decoded = await decodeImageFromList(rawBytes);
          if (decoded.height > 0) {
            detectedRatio = decoded.width / decoded.height;
          }
        } catch (_) {}

        setState(() {
          _selectedImageBytes = rawBytes;
          _selectedImagePath = file.path ?? '';
          _selectedFileName = file.name;
          if (detectedRatio != null) {
            _detectedImageAspectRatio = detectedRatio;
          }
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
    await UserAiPreferencesService.ensureLoaded();
    await AiSubscriptionService.instance.ensureInitialized();
    final isGoogleAi = UserAiPreferencesService.activeProvider == AiProviderType.googleAiStudio &&
        UserAiPreferencesService.hasGeminiApiKey;

    if (!isGoogleAi && !AiSubscriptionService.instance.canUseDefaultAi) {
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PremiumUpgradeScreen(
              onOpenAiSettings: _showAiSettingsBottomSheet,
            ),
          ),
        );
      }
      return;
    }

    setState(() {
      _currentStep = 1;
      _isAnalyzing = true;
      _selectedBoxId = null;
    });

    try {
      final result = await AiVisionLayoutService.detectLayout(
        imagePath: _selectedImagePath,
        imageBytes: _selectedImageBytes,
        aspectRatio: _detectedImageAspectRatio,
      );

      if (mounted) {
        final boxCount = result.detectedBoxes.length;
        final checkCount = result.checkpoints.length;
        String countMsg = 'هوش مصنوعی تصویر برگه را اسکن کرد (${result.analysisEngine}) و $boxCount باکس متن';
        if (checkCount > 0) {
          countMsg += ' و $checkCount نقطه تیک‌زدنی هوشمند';
        }
        countMsg += ' متناسب با خطوط و بخش‌ها قرار داد.';

        setState(() {
          if (result.imageBytes != null && result.imageBytes!.isNotEmpty) {
            _selectedImageBytes = result.imageBytes;
          }
          _analysisResult = AILayoutResult(
            imagePath: result.imagePath,
            imageBytes: _selectedImageBytes,
            aspectRatio: result.aspectRatio,
            title: result.title,
            detectedBoxes: result.detectedBoxes,
            checkpoints: result.checkpoints,
            analysisEngine: result.analysisEngine,
            detectedAt: result.detectedAt,
          );
          _isAnalyzing = false;
          _chatHistory.clear();
          _chatHistory.add({
            'role': 'ai',
            'text': countMsg,
          });
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isAnalyzing = false);
        if (e is AiUsageLimitExceededException) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PremiumUpgradeScreen(
                onOpenAiSettings: _showAiSettingsBottomSheet,
              ),
            ),
          );
        } else {
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
  }

  Future<void> _handleChatSubmit(String message) async {
    if (message.trim().isEmpty || _analysisResult == null) return;

    await UserAiPreferencesService.ensureLoaded();
    await AiSubscriptionService.instance.ensureInitialized();
    final isGoogleAi = UserAiPreferencesService.activeProvider == AiProviderType.googleAiStudio &&
        UserAiPreferencesService.hasGeminiApiKey;

    if (!isGoogleAi && !AiSubscriptionService.instance.canUseDefaultAi) {
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PremiumUpgradeScreen(
              onOpenAiSettings: _showAiSettingsBottomSheet,
            ),
          ),
        );
      }
      return;
    }

    _chatController.clear();

    setState(() {
      _isChatLoading = true;
      _chatHistory.add({'role': 'user', 'text': message});
    });

    try {
      final res = await AiVisionLayoutService.processChatEditCommand(
        userCommand: message,
        currentBoxes: _analysisResult!.detectedBoxes,
      );

      if (mounted) {
        setState(() {
          _isChatLoading = false;
          _analysisResult = AILayoutResult(
            imagePath: _analysisResult!.imagePath,
            imageBytes: _analysisResult!.imageBytes ?? _selectedImageBytes,
            aspectRatio: _analysisResult!.aspectRatio,
            title: _analysisResult!.title,
            detectedBoxes: res.updatedBoxes,
            checkpoints: _analysisResult!.checkpoints,
            analysisEngine: _analysisResult!.analysisEngine,
          );
          _chatHistory.add({'role': 'ai', 'text': res.assistantMessage});
          _currentChips = res.suggestionChips;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isChatLoading = false);
        if (e is AiUsageLimitExceededException) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PremiumUpgradeScreen(
                onOpenAiSettings: _showAiSettingsBottomSheet,
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('خطا در چت هوش مصنوعی: $e'),
              backgroundColor: Colors.red.shade700,
            ),
          );
        }
      }
    }
  }

  void _deleteBox(DetectedBox box) {
    if (_analysisResult == null) return;
    final idx = _analysisResult!.detectedBoxes.indexOf(box);
    setState(() {
      _lastDeletedBox = box;
      _lastDeletedBoxIndex = idx;
      _analysisResult!.detectedBoxes.removeWhere((b) => b.id == box.id);
      if (_selectedBoxId == box.id) {
        _selectedBoxId = null;
      }
    });

    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'باکس «${box.label.isNotEmpty ? box.label : box.typeTitlePersian}» حذف شد.',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
          action: SnackBarAction(
            label: 'بازگردانی',
            textColor: const Color(0xFFFFCC80),
            onPressed: () {
              if (_lastDeletedBox != null && _analysisResult != null) {
                setState(() {
                  if (_lastDeletedBoxIndex != null &&
                      _lastDeletedBoxIndex! >= 0 &&
                      _lastDeletedBoxIndex! <= _analysisResult!.detectedBoxes.length) {
                    _analysisResult!.detectedBoxes.insert(_lastDeletedBoxIndex!, _lastDeletedBox!);
                  } else {
                    _analysisResult!.detectedBoxes.add(_lastDeletedBox!);
                  }
                  _selectedBoxId = _lastDeletedBox!.id;
                });
              }
            },
          ),
          backgroundColor: const Color(0xFF1E293B),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  void _proceedToEditor() {
    if (_analysisResult == null) return;

    final actualAspectRatio = _analysisResult!.aspectRatio > 0
        ? _analysisResult!.aspectRatio
        : _detectedImageAspectRatio;
    const canvasWidth = 420.0;
    final canvasHeight = canvasWidth / actualAspectRatio;
    final canvasSize = Size(canvasWidth, canvasHeight);

    // Convert detected boxes into actual TextBoxItems for the editor canvas (keeping normalized coordinates)
    final textBoxes = _analysisResult!.detectedBoxes.map((b) => b.toTextBoxItem(canvasSize)).toList();
    final checkItems = _analysisResult!.checkpoints;
    final templateId = 'ai_template_${DateTime.now().millisecondsSinceEpoch}';

    final serializedData = jsonEncode({
      'templateId': templateId,
      'textBoxes': textBoxes.map((b) => b.toJson()).toList(),
      'checkItems': checkItems.map((c) => c.toJson()).toList(),
    });

    final customTemplate = JournalTemplate(
      id: templateId,
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
      aspectRatio: actualAspectRatio,
    );

    // Persist custom template to storage registry so it is reusable and resolves in NotebookPageModel
    NotebookStorageService.instance.saveOrUpdateCustomTemplate(customTemplate);

    final page = NotebookPageModel.fromJournalContent(
      id: 'p_${DateTime.now().millisecondsSinceEpoch}',
      title: _selectedFileName != null ? 'برگه ${_selectedFileName!}' : 'قالب هوش مصنوعی',
      content: serializedData,
      templateId: customTemplate.id,
    );

    widget.onTemplateCreated(customTemplate, page);
    Navigator.pop(context); // Close builder screen
  }

  Future<void> _exportAiLayoutToJson() async {
    if (_analysisResult == null) return;
    try {
      final res = await NotebookExportService.instance.exportAiLayoutToJson(_analysisResult!);
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
        final rawBytes = bytes ??
            (result.files.first.path != null
                ? await readBytesFromPath(result.files.first.path!)
                : null);
        if (rawBytes == null) return;
        final fileStr = utf8.decode(rawBytes);
        final importRes = NotebookExportService.instance.importPackageFromJson(fileStr);

        if (importRes.isSuccess && (importRes.aiLayout != null || importRes.template != null || importRes.page != null)) {
          setState(() {
            _currentStep = 1;
            if (importRes.aiLayout != null) {
              _analysisResult = importRes.aiLayout;
              if (importRes.aiLayout!.imageBytes != null) {
                _selectedImageBytes = importRes.aiLayout!.imageBytes;
              }
              if (importRes.aiLayout!.imagePath.isNotEmpty) {
                _selectedImagePath = importRes.aiLayout!.imagePath;
              }
              _detectedImageAspectRatio = importRes.aiLayout!.aspectRatio;
            } else if (importRes.page != null) {
              final tmpl = importRes.template ?? (importRes.page!.templateId != null ? JournalTemplate.findTemplateById(importRes.page!.templateId) : null);
              if (tmpl != null) {
                _selectedImageBytes = tmpl.imageBytes;
                _selectedImagePath = tmpl.imageAsset ?? '';
                _selectedFileName = tmpl.title;
                _detectedImageAspectRatio = tmpl.aspectRatio;
              }
              final detectedBoxes = importRes.page!.textBoxes.map((b) => DetectedBox(
                id: b.id,
                label: b.text.isNotEmpty ? b.text : (b.hintText.isNotEmpty ? b.hintText : 'باکس متن'),
                type: DetectedBoxType.freeText,
                normalizedX: b.normalizedX ?? 0.1,
                normalizedY: b.normalizedY ?? 0.1,
                normalizedWidth: b.normalizedWidth ?? 0.8,
                normalizedHeight: b.normalizedHeight ?? 0.08,
                placeholderText: b.text.isNotEmpty ? b.text : b.hintText,
                fontSize: b.fontSize,
                fontName: b.fontName,
                inkColor: b.inkColor,
                textAlign: b.textAlign,
                isBold: b.isBold,
              )).toList();

              _analysisResult = AILayoutResult(
                imagePath: _selectedImagePath,
                imageBytes: _selectedImageBytes,
                aspectRatio: _detectedImageAspectRatio,
                title: importRes.page!.title,
                detectedBoxes: detectedBoxes,
                checkpoints: importRes.page!.checkItems,
                analysisEngine: 'Imported Page Layers',
                detectedAt: DateTime.now(),
              );
            } else if (importRes.template != null) {
              final tmpl = importRes.template!;
              _selectedImageBytes = tmpl.imageBytes;
              _selectedImagePath = tmpl.imageAsset ?? '';
              _selectedFileName = tmpl.title;
              _detectedImageAspectRatio = tmpl.aspectRatio;

              final detectedBoxes = <DetectedBox>[];
              for (int i = 0; i < tmpl.sections.length; i++) {
                final s = tmpl.sections[i];
                detectedBoxes.add(DetectedBox(
                  id: 'sec_$i',
                  label: s.title,
                  type: DetectedBoxType.ruledLines,
                  normalizedX: 0.1,
                  normalizedY: 0.15 + (i * 0.2),
                  normalizedWidth: 0.8,
                  normalizedHeight: 0.15,
                  placeholderText: s.items.join('\n'),
                ));
              }

              _analysisResult = AILayoutResult(
                imagePath: _selectedImagePath,
                imageBytes: _selectedImageBytes,
                aspectRatio: _detectedImageAspectRatio,
                title: tmpl.title,
                detectedBoxes: detectedBoxes,
                checkpoints: [],
                analysisEngine: 'Imported Template',
                detectedAt: DateTime.now(),
              );
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

  void _showAiSettingsBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        AiProviderType tempProvider = UserAiPreferencesService.activeProvider;
        String tempSelectedModel = UserAiPreferencesService.rawModelSelection;
        final keyController = TextEditingController(text: UserAiPreferencesService.geminiApiKey);
        final customModelController = TextEditingController(text: UserAiPreferencesService.customModelName);
        bool obscureKey = true;
        bool isTesting = false;
        GeminiConnectionTestResult? testResult;

        return StatefulBuilder(
          builder: (context, setSheetState) {
            final isGoogleSelected = tempProvider == AiProviderType.googleAiStudio;
            final isPrem = AiSubscriptionService.instance.isPremium;
            final rem = AiSubscriptionService.instance.remainingFreeUsage;
            final badgeTxt = isPrem ? '💎 پرمیوم نامحدود' : (rem > 0 ? '$rem/15 رایگان' : 'اتمام سهمیه');
            final badgeClr = isPrem ? const Color(0xFF2E7D32) : (rem > 0 ? const Color(0xFFE65100) : const Color(0xFFC62828));
            final subTxt = isPrem
                ? 'دسترسی نامحدود پرمیوم فعال است'
                : (rem > 0
                    ? 'استفاده شده: ${AiSubscriptionService.instance.usageCount} از ۱۵ بار رایگان'
                    : 'سقف ۱۵ بار استفاده رایگان به پایان رسیده است');

            return Container(
              margin: EdgeInsets.only(
                top: 40,
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.85,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Drag Handle
                    Container(
                      margin: const EdgeInsets.only(top: 12, bottom: 8),
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),

                    // Header
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF1EB),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.tune_rounded, color: Color(0xFFFF7043), size: 20),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'تنظیمات موتور هوش مصنوعی',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'انتخاب بین سیستم پیش‌فرض یا کلید شخصی Google AI Studio',
                                  style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                            onPressed: () => Navigator.pop(sheetContext),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: Color(0xFFE2E8F0)),

                    // Scrollable Body
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'ارائه‌دهنده سرویس هوش مصنوعی:',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                            ),
                            const SizedBox(height: 12),

                            // Option 1: Developer Default AI
                            _buildProviderSelectCard(
                              isSelected: tempProvider == AiProviderType.developer,
                              title: 'هوش مصنوعی پیش‌فرض برنامه (توسعه‌دهنده)',
                              subtitle: subTxt,
                              badgeText: badgeTxt,
                              badgeColor: badgeClr,
                              icon: Icons.cloud_done_rounded,
                              iconColor: const Color(0xFF2E7D32),
                              onTap: () {
                                setSheetState(() {
                                  tempProvider = AiProviderType.developer;
                                });
                              },
                            ),
                            if (!isPrem && rem <= 0)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: InkWell(
                                  onTap: () {
                                    Navigator.pop(sheetContext);
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => PremiumUpgradeScreen(
                                          onOpenAiSettings: _showAiSettingsBottomSheet,
                                        ),
                                      ),
                                    );
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFF3E0),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: const Color(0xFFFFB74D)),
                                    ),
                                    child: const Row(
                                      children: [
                                        Icon(Icons.diamond_rounded, size: 18, color: Color(0xFFE65100)),
                                        SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'ارتقا به پرمیوم (پیام به @metarwa در تلگرام)',
                                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFE65100)),
                                          ),
                                        ),
                                        Icon(Icons.chevron_left_rounded, size: 18, color: Color(0xFFE65100)),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            const SizedBox(height: 12),

                            // Option 2: Google AI Studio (Personal Key)
                            _buildProviderSelectCard(
                              isSelected: tempProvider == AiProviderType.googleAiStudio,
                              title: 'Google AI Studio (کلید شخصی شما)',
                              subtitle: 'اتصال مستقیم به مدل‌های Gemini با سهمیه رایگان شخصی خودتان',
                              badgeText: 'پیشنهادی برای سرعت و دقت بالاتر',
                              badgeColor: const Color(0xFF1565C0),
                              icon: Icons.auto_awesome_rounded,
                              iconColor: const Color(0xFF1565C0),
                              onTap: () {
                                setSheetState(() {
                                  tempProvider = AiProviderType.googleAiStudio;
                                });
                              },
                            ),

                            // Google AI Studio Details
                            if (isGoogleSelected) ...[
                              const SizedBox(height: 20),
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Row(
                                      children: [
                                        Icon(Icons.smart_toy_outlined, size: 18, color: Color(0xFF1565C0)),
                                        SizedBox(width: 8),
                                        Text(
                                          'انتخاب مدل جمنای (Gemini Model):',
                                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),

                                    // Model Dropdown
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: const Color(0xFFCBD5E1)),
                                      ),
                                      child: DropdownButtonHideUnderline(
                                        child: DropdownButton<String>(
                                          value: tempSelectedModel,
                                          isExpanded: true,
                                          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF64748B)),
                                          items: [
                                            ...UserAiPreferencesService.availableModels.map((m) {
                                              return DropdownMenuItem<String>(
                                                value: m.id,
                                                child: Row(
                                                  children: [
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        mainAxisAlignment: MainAxisAlignment.center,
                                                        children: [
                                                          Text(
                                                            m.displayName,
                                                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                                                          ),
                                                          Text(
                                                            m.description,
                                                            style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600),
                                                            maxLines: 1,
                                                            overflow: TextOverflow.ellipsis,
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    if (m.isRecommended)
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                        decoration: BoxDecoration(
                                                          color: const Color(0xFFE3F2FD),
                                                          borderRadius: BorderRadius.circular(6),
                                                        ),
                                                        child: const Text(
                                                          'پیشنهادی',
                                                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF1565C0)),
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                              );
                                            }),
                                            const DropdownMenuItem<String>(
                                              value: 'custom',
                                              child: Text('مدل دلخواه... (Custom Model Name)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                            ),
                                          ],
                                          onChanged: (val) {
                                            if (val != null) {
                                              setSheetState(() {
                                                tempSelectedModel = val;
                                              });
                                            }
                                          },
                                        ),
                                      ),
                                    ),

                                    // Custom model field
                                    if (tempSelectedModel == 'custom') ...[
                                      const SizedBox(height: 10),
                                      TextField(
                                        controller: customModelController,
                                        style: const TextStyle(fontSize: 13),
                                        decoration: InputDecoration(
                                          hintText: 'نام مدل، مثلاً gemini-2.0-flash-lite',
                                          labelText: 'نام دقیق مدل',
                                          isDense: true,
                                          filled: true,
                                          fillColor: Colors.white,
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(10),
                                            borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                                          ),
                                        ),
                                      ),
                                    ],

                                    const SizedBox(height: 18),
                                    const Row(
                                      children: [
                                        Icon(Icons.key_rounded, size: 18, color: Color(0xFF1565C0)),
                                        SizedBox(width: 8),
                                        Text(
                                          'کلید اختصاصی API Key:',
                                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),

                                    // API Key Field
                                    TextField(
                                      controller: keyController,
                                      obscureText: obscureKey,
                                      style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
                                      decoration: InputDecoration(
                                        hintText: 'AIzaSy...',
                                        filled: true,
                                        fillColor: Colors.white,
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: const BorderSide(color: Color(0xFF1565C0), width: 1.5),
                                        ),
                                        suffixIcon: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              icon: Icon(
                                                obscureKey ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                                size: 19,
                                                color: Colors.grey.shade600,
                                              ),
                                              onPressed: () {
                                                setSheetState(() => obscureKey = !obscureKey);
                                              },
                                              tooltip: obscureKey ? 'نمایش کلید' : 'مخفی‌سازی کلید',
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.content_paste_rounded, size: 19, color: Color(0xFF1565C0)),
                                              onPressed: () async {
                                                final data = await Clipboard.getData(Clipboard.kTextPlain);
                                                if (data?.text != null && data!.text!.isNotEmpty) {
                                                  keyController.text = data.text!.trim();
                                                  setSheetState(() {});
                                                }
                                              },
                                              tooltip: 'جای‌گذاری از کلیپ‌بورد',
                                            ),
                                            if (keyController.text.isNotEmpty)
                                              IconButton(
                                                icon: const Icon(Icons.clear_rounded, size: 18, color: Colors.grey),
                                                onPressed: () {
                                                  keyController.clear();
                                                  setSheetState(() {});
                                                },
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    const Text(
                                      '🔒 کلید شما تنها در حافظه امن همین دستگاه ذخیره می‌شود و در اختیار شخص دیگری قرار نمی‌گیرد.',
                                      style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                                    ),

                                    const SizedBox(height: 14),

                                    // Guide Link
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEFF6FF),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: const Color(0xFFBFDBFE)),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.info_outline_rounded, color: Color(0xFF1D4ED8), size: 18),
                                          const SizedBox(width: 8),
                                          const Expanded(
                                            child: Text(
                                              'هنوز کلید ندارید؟ دریافت رایگان از:\naistudio.google.com',
                                              style: TextStyle(fontSize: 11, color: Color(0xFF1E40AF), height: 1.3),
                                            ),
                                          ),
                                          TextButton.icon(
                                            onPressed: () {
                                              Clipboard.setData(const ClipboardData(text: 'https://aistudio.google.com/app/apikey'));
                                              ScaffoldMessenger.of(sheetContext).showSnackBar(
                                                const SnackBar(
                                                  content: Text('آدرس aistudio.google.com در کلیپ‌بورد کپی شد.'),
                                                  behavior: SnackBarBehavior.floating,
                                                  duration: Duration(seconds: 2),
                                                ),
                                              );
                                            },
                                            icon: const Icon(Icons.copy_rounded, size: 14),
                                            label: const Text('کپی آدرس', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                            style: TextButton.styleFrom(
                                              foregroundColor: const Color(0xFF1D4ED8),
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              minimumSize: Size.zero,
                                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    const SizedBox(height: 16),

                                    // Test Connection Button
                                    SizedBox(
                                      width: double.infinity,
                                      child: OutlinedButton.icon(
                                        onPressed: isTesting
                                            ? null
                                            : () async {
                                                final inputKey = keyController.text.trim();
                                                if (inputKey.isEmpty) {
                                                  setSheetState(() {
                                                    testResult = const GeminiConnectionTestResult(
                                                      isSuccess: false,
                                                      message: 'لطفاً ابتدا کلید API را وارد کنید.',
                                                    );
                                                  });
                                                  return;
                                                }

                                                setSheetState(() {
                                                  isTesting = true;
                                                  testResult = null;
                                                });

                                                final targetModel = tempSelectedModel == 'custom'
                                                    ? customModelController.text.trim()
                                                    : tempSelectedModel;

                                                final res = await UserAiPreferencesService.testGeminiConnection(
                                                  apiKey: inputKey,
                                                  model: targetModel.isNotEmpty ? targetModel : 'gemini-2.5-flash',
                                                );

                                                setSheetState(() {
                                                  isTesting = false;
                                                  testResult = res;
                                                });
                                              },
                                        icon: isTesting
                                            ? const SizedBox(
                                                width: 16,
                                                height: 16,
                                                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1565C0)),
                                              )
                                            : const Icon(Icons.network_check_rounded, size: 18),
                                        label: Text(
                                          isTesting ? 'در حال برقراری ارتباط...' : 'تست اتصال به سرور Google AI',
                                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                                        ),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: const Color(0xFF1565C0),
                                          side: const BorderSide(color: Color(0xFF90CAF9)),
                                          padding: const EdgeInsets.symmetric(vertical: 11),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                      ),
                                    ),

                                    // Test Result Banner
                                    if (testResult != null) ...[
                                      const SizedBox(height: 10),
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: testResult!.isSuccess ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE),
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(
                                            color: testResult!.isSuccess ? const Color(0xFFA5D6A7) : const Color(0xFFFFCDD2),
                                          ),
                                        ),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Icon(
                                              testResult!.isSuccess ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                                              size: 18,
                                              color: testResult!.isSuccess ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                testResult!.message,
                                                style: TextStyle(
                                                  fontSize: 11.5,
                                                  fontWeight: FontWeight.w600,
                                                  color: testResult!.isSuccess ? const Color(0xFF1B5E20) : const Color(0xFFB71C1C),
                                                  height: 1.3,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),

                    // Actions
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(sheetContext),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 13),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                side: const BorderSide(color: Color(0xFFCBD5E1)),
                              ),
                              child: const Text('انصراف', style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.bold)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                if (tempProvider == AiProviderType.googleAiStudio && keyController.text.trim().isEmpty) {
                                  ScaffoldMessenger.of(sheetContext).showSnackBar(
                                    const SnackBar(
                                      content: Text('لطفاً کلید API را وارد کنید یا گزینه سرور پیش‌فرض را انتخاب فرمایید.'),
                                      backgroundColor: Color(0xFFC62828),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                  return;
                                }

                                final messenger = ScaffoldMessenger.of(context);
                                final navigator = Navigator.of(sheetContext);

                                await UserAiPreferencesService.savePreferences(
                                  providerType: tempProvider,
                                  geminiApiKey: keyController.text.trim(),
                                  geminiModel: tempSelectedModel,
                                  customModelName: customModelController.text.trim(),
                                );

                                if (mounted) {
                                  setState(() {});
                                  navigator.pop();
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: Row(
                                        children: [
                                          const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              tempProvider == AiProviderType.googleAiStudio
                                                  ? 'موتور هوش مصنوعی به Google AI Studio (${UserAiPreferencesService.geminiModel}) تغییر یافت.'
                                                  : 'موتور هوش مصنوعی به سرور پیش‌فرض توسعه‌دهنده تغییر یافت.',
                                            ),
                                          ),
                                        ],
                                      ),
                                      backgroundColor: const Color(0xFF2E7D32),
                                      behavior: SnackBarBehavior.floating,
                                      duration: const Duration(seconds: 3),
                                    ),
                                  );
                                }
                              },
                              icon: const Icon(Icons.check_rounded, size: 18),
                              label: const Text('ذخیره و اعمال تنظیمات', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isGoogleSelected ? const Color(0xFF1565C0) : const Color(0xFFFF7043),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 13),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 2,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildProviderSelectCard({
    required bool isSelected,
    required String title,
    required String subtitle,
    required String badgeText,
    required Color badgeColor,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? badgeColor.withValues(alpha: 0.05) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? badgeColor : const Color(0xFFE2E8F0),
            width: isSelected ? 1.8 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: badgeColor.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 2),
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? badgeColor : Colors.grey.shade400,
                  width: 2,
                ),
                color: isSelected ? badgeColor : Colors.transparent,
              ),
              child: isSelected
                  ? const Center(child: Icon(Icons.circle, size: 8, color: Colors.white))
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(icon, size: 16, color: iconColor),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isSelected ? FontWeight.w800 : FontWeight.bold,
                            color: const Color(0xFF1E293B),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600, height: 1.3),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: badgeColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      badgeText,
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: badgeColor),
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

  Widget _buildAiEngineStatusCard(bool isGoogleAi, String devModel) {
    final activeTitle = isGoogleAi
        ? 'Google AI Studio (${UserAiPreferencesService.geminiModel})'
        : 'هوش مصنوعی پیش‌فرض ($devModel)';
    final activeDesc = isGoogleAi
        ? 'سهمیه کلید شخصی شما در گوگل فعال است'
        : 'رایگان، بدون نیاز به تنظیمات (سرور توسعه‌دهنده)';
    final cardColor = isGoogleAi ? const Color(0xFF1565C0) : const Color(0xFFFF7043);

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cardColor.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: cardColor.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: cardColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isGoogleAi ? Icons.auto_awesome_rounded : Icons.cloud_done_rounded,
              color: cardColor,
              size: 22,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'موتور هوش مصنوعی:',
                      style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: cardColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isGoogleAi ? 'کلید شخصی جمنای' : 'سرور توسعه‌دهنده',
                        style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: cardColor),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  activeTitle,
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
                ),
                Text(
                  activeDesc,
                  style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          OutlinedButton.icon(
            onPressed: _showAiSettingsBottomSheet,
            icon: const Icon(Icons.tune_rounded, size: 14),
            label: const Text('تنظیمات کلید', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
            style: OutlinedButton.styleFrom(
              foregroundColor: cardColor,
              side: BorderSide(color: cardColor.withValues(alpha: 0.4)),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRenderedImageWidget({required BoxFit fit}) {
    if (_selectedImageBytes != null) {
      return Image.memory(
        _selectedImageBytes!,
        fit: fit,
      );
    } else if (_selectedImagePath.startsWith('http://') ||
        _selectedImagePath.startsWith('https://') ||
        _selectedImagePath.startsWith('blob:')) {
      return Image.network(
        _selectedImagePath,
        fit: fit,
        errorBuilder: (ctx, err, stack) => Container(
          color: const Color(0xFFF1F5F9),
          child: const Center(
            child: Icon(Icons.broken_image_rounded, size: 48, color: Colors.grey),
          ),
        ),
      );
    } else if (platformFileExists(_selectedImagePath) && !_selectedImagePath.startsWith('assets/')) {
      return buildPlatformFileImage(
        filePath: _selectedImagePath,
        fit: fit,
        errorWidget: Container(
          color: const Color(0xFFF1F5F9),
          child: const Center(
            child: Icon(Icons.broken_image_rounded, size: 48, color: Colors.grey),
          ),
        ),
      );
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
    final isGoogleAi = UserAiPreferencesService.activeProvider == AiProviderType.googleAiStudio;
    final activeModelName = isGoogleAi ? UserAiPreferencesService.geminiModel : aiConfig.model;

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
            // AI Model Pill & Settings Trigger
            InkWell(
              onTap: _showAiSettingsBottomSheet,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: isGoogleAi ? const Color(0xFFEFF6FF) : const Color(0xFFFFF1EB),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isGoogleAi ? const Color(0xFFBFDBFE) : const Color(0xFFFFCCBC)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isGoogleAi ? Icons.auto_awesome_rounded : Icons.cloud_done_rounded,
                      size: 13,
                      color: isGoogleAi ? const Color(0xFF1D4ED8) : const Color(0xFFE65100),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      activeModelName,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: isGoogleAi ? const Color(0xFF1E40AF) : const Color(0xFFBF360C),
                      ),
                    ),
                    const SizedBox(width: 3),
                    Icon(
                      Icons.arrow_drop_down_rounded,
                      size: 14,
                      color: isGoogleAi ? const Color(0xFF1D4ED8) : const Color(0xFFE65100),
                    ),
                  ],
                ),
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
          const SizedBox(height: 14),

          // AI Engine Status & Personal Key Card
          _buildAiEngineStatusCard(
            UserAiPreferencesService.activeProvider == AiProviderType.googleAiStudio,
            AiConfigService.currentConfig.model,
          ),

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
          const SizedBox(height: 24),

          // AI Quota / Subscription Banner
          _buildAiQuotaBanner(),
          const SizedBox(height: 14),

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

  Widget _buildAiQuotaBanner() {
    return AnimatedBuilder(
      animation: AiSubscriptionService.instance,
      builder: (context, _) {
        final isGoogleAi = UserAiPreferencesService.activeProvider == AiProviderType.googleAiStudio &&
            UserAiPreferencesService.hasGeminiApiKey;
        if (isGoogleAi) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome_rounded, size: 16, color: Color(0xFF1565C0)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'استفاده با کلید شخصی Google AI Studio (${UserAiPreferencesService.geminiModel})',
                    style: const TextStyle(fontSize: 11.5, color: Color(0xFF1565C0), fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          );
        }

        final isPremium = AiSubscriptionService.instance.isPremium;
        final remaining = AiSubscriptionService.instance.remainingFreeUsage;
        final isExhausted = !isPremium && remaining <= 0;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isPremium
                ? const Color(0xFFE8F5E9)
                : isExhausted
                    ? const Color(0xFFFBE9E7)
                    : const Color(0xFFFFF8E1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isPremium
                  ? const Color(0xFFA5D6A7)
                  : isExhausted
                      ? const Color(0xFFFFAB91)
                      : const Color(0xFFFFE082),
            ),
          ),
          child: Row(
            children: [
              Icon(
                isPremium
                    ? Icons.verified_rounded
                    : isExhausted
                        ? Icons.warning_amber_rounded
                        : Icons.timelapse_rounded,
                size: 18,
                color: isPremium
                    ? const Color(0xFF2E7D32)
                    : isExhausted
                        ? const Color(0xFFD84315)
                        : const Color(0xFFF57F17),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isPremium
                      ? 'اشتراک پرمیوم فعال است (استفاده نامحدود از هوش مصنوعی)'
                      : isExhausted
                          ? 'سقف ۱۵ استفاده رایگان تمام شد! برای ارتقا پیام دهید.'
                          : 'سهمیه رایگان هوش مصنوعی پیش‌فرض: $remaining از ۱۵ باقی‌مانده',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isPremium
                        ? const Color(0xFF1B5E20)
                        : isExhausted
                            ? const Color(0xFFBF360C)
                            : const Color(0xFFE65100),
                  ),
                ),
              ),
              if (!isPremium)
                InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PremiumUpgradeScreen(
                          onOpenAiSettings: _showAiSettingsBottomSheet,
                        ),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isExhausted ? const Color(0xFFD84315) : const Color(0xFFFF8F00),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isExhausted ? 'ارتقا به پرمیوم' : 'پرمیوم',
                      style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
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

  Widget _buildManualEditControlCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _isManualEditMode ? const Color(0xFFFFF7ED) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _isManualEditMode ? const Color(0xFFFF9800) : const Color(0xFFE2E8F0),
          width: _isManualEditMode ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: (_isManualEditMode ? const Color(0xFFFF9800) : Colors.black).withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _isManualEditMode ? const Color(0xFFFF7043) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              _isManualEditMode ? Icons.edit_note_rounded : Icons.tune_rounded,
              size: 20,
              color: _isManualEditMode ? Colors.white : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'ویرایش دستی باکس‌ها',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: _isManualEditMode ? const Color(0xFFE65100) : const Color(0xFF1E293B),
                      ),
                    ),
                    if (_isManualEditMode) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF7043),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'فعال',
                          style: TextStyle(fontSize: 9.5, color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  _isManualEditMode
                      ? 'روی باکس لمس کنید: دستگیره ⤡ برای تغییر سایز، مرکز برای جابه‌جایی و ✖ برای حذف'
                      : 'امکان کوچک یا بزرگ کردن اندازه باکس‌ها با دست، جابه‌جایی و حذف',
                  style: TextStyle(
                    fontSize: 11,
                    color: _isManualEditMode ? const Color(0xFFBF360C) : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: _isManualEditMode,
            activeThumbColor: const Color(0xFFFF7043),
            activeTrackColor: const Color(0xFFFFCCBC),
            onChanged: (val) {
              setState(() {
                _isManualEditMode = val;
                if (_isManualEditMode) {
                  if (_selectedBoxId == null &&
                      _analysisResult != null &&
                      _analysisResult!.detectedBoxes.isNotEmpty) {
                    _selectedBoxId = _analysisResult!.detectedBoxes.first.id;
                  }
                } else {
                  _selectedBoxId = null;
                }
              });
            },
          ),
        ],
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
      physics: _isDraggingBoxOrHandle
          ? const NeverScrollableScrollPhysics()
          : const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
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
                    () {
                      final boxes = _analysisResult?.detectedBoxes.length ?? 0;
                      final checks = _analysisResult?.checkpoints.length ?? 0;
                      if (checks > 0) {
                        return 'هوش مصنوعی $boxes باکس متن و $checks نقطه تیک هوشمند شناسایی کرد.';
                      }
                      return 'هوش مصنوعی $boxes باکس متن را متناسب با خطوط تصویر قرار داد.';
                    }(),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF1B5E20)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Manual Edit Mode Toggle & Controls Card
          _buildManualEditControlCard(),
          const SizedBox(height: 16),

          // Canvas with Bounding Boxes
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: AspectRatio(
                aspectRatio: _analysisResult?.aspectRatio ?? _detectedImageAspectRatio,
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

                                // Keep buttons and handles visible without being cut off by canvas edges
                                final deleteTop = top < 14 ? 2.0 : -10.0;
                                final deleteLeft = left < 14 ? 2.0 : -10.0;
                                final resizeBottom = (top + height > constraints.maxHeight - 16) ? 2.0 : -10.0;
                                final resizeRight = (left + width > constraints.maxWidth - 16) ? 2.0 : -10.0;

                                return Positioned(
                                  left: left,
                                  top: top,
                                  width: width,
                                  height: height,
                                  child: Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      // Main Box Container
                                      Positioned.fill(
                                        child: GestureDetector(
                                          behavior: HitTestBehavior.opaque,
                                          onTap: () {
                                            setState(() {
                                              _selectedBoxId = isSelected ? null : box.id;
                                            });
                                          },
                                          onPanStart: (_isManualEditMode && isSelected)
                                              ? (_) => setState(() => _isDraggingBoxOrHandle = true)
                                              : null,
                                          onPanUpdate: (_isManualEditMode && isSelected)
                                              ? (details) {
                                                  setState(() {
                                                    final deltaNormX = details.delta.dx / constraints.maxWidth;
                                                    final deltaNormY = details.delta.dy / constraints.maxHeight;
                                                    final newX = (box.normalizedX + deltaNormX).clamp(0.0, 1.0 - box.normalizedWidth);
                                                    final newY = (box.normalizedY + deltaNormY).clamp(0.0, 1.0 - box.normalizedHeight);
                                                    box.normalizedX = newX;
                                                    box.normalizedY = newY;
                                                  });
                                                }
                                              : null,
                                          onPanEnd: (_isManualEditMode && isSelected)
                                              ? (_) => setState(() => _isDraggingBoxOrHandle = false)
                                              : null,
                                          onPanCancel: (_isManualEditMode && isSelected)
                                              ? () => setState(() => _isDraggingBoxOrHandle = false)
                                              : null,
                                          child: AnimatedContainer(
                                            duration: const Duration(milliseconds: 150),
                                            decoration: BoxDecoration(
                                              color: box.badgeColor.withValues(
                                                alpha: isSelected
                                                    ? (_isManualEditMode ? 0.38 : 0.35)
                                                    : (_isManualEditMode ? 0.22 : 0.18),
                                              ),
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(
                                                color: isSelected
                                                    ? (_isManualEditMode ? const Color(0xFFFF7043) : Colors.white)
                                                    : (_isManualEditMode ? box.badgeColor.withValues(alpha: 0.85) : box.badgeColor),
                                                width: isSelected ? 2.5 : (_isManualEditMode ? 1.8 : 1.5),
                                              ),
                                              boxShadow: [
                                                if (isSelected)
                                                  BoxShadow(
                                                    color: (_isManualEditMode ? const Color(0xFFFF7043) : box.badgeColor).withValues(alpha: 0.45),
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
                                      ),

                                      // In Manual Edit Mode and selected: Delete Cross & Resize Handle
                                      if (_isManualEditMode && isSelected) ...[
                                        // Delete Cross Button (Corner)
                                        Positioned(
                                          top: deleteTop,
                                          left: deleteLeft,
                                          child: GestureDetector(
                                            behavior: HitTestBehavior.opaque,
                                            onTap: () => _deleteBox(box),
                                            child: Container(
                                              width: 26,
                                              height: 26,
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFE53935),
                                                shape: BoxShape.circle,
                                                border: Border.all(color: Colors.white, width: 2),
                                                boxShadow: const [
                                                  BoxShadow(color: Colors.black38, blurRadius: 4, offset: Offset(0, 2)),
                                                ],
                                              ),
                                              child: const Center(
                                                child: Icon(Icons.close_rounded, size: 15, color: Colors.white),
                                              ),
                                            ),
                                          ),
                                        ),

                                        // Resize Handle (Bottom-Right Corner)
                                        Positioned(
                                          right: resizeRight,
                                          bottom: resizeBottom,
                                          child: GestureDetector(
                                            behavior: HitTestBehavior.opaque,
                                            onPanStart: (_) => setState(() => _isDraggingBoxOrHandle = true),
                                            onPanUpdate: (details) {
                                              setState(() {
                                                final deltaNormW = details.delta.dx / constraints.maxWidth;
                                                final deltaNormH = details.delta.dy / constraints.maxHeight;

                                                final minNormW = 32.0 / constraints.maxWidth;
                                                final minNormH = 20.0 / constraints.maxHeight;
                                                final maxNormW = 1.0 - box.normalizedX;
                                                final maxNormH = 1.0 - box.normalizedY;

                                                box.normalizedWidth = (box.normalizedWidth + deltaNormW).clamp(minNormW, maxNormW);
                                                box.normalizedHeight = (box.normalizedHeight + deltaNormH).clamp(minNormH, maxNormH);
                                              });
                                            },
                                            onPanEnd: (_) => setState(() => _isDraggingBoxOrHandle = false),
                                            onPanCancel: () => setState(() => _isDraggingBoxOrHandle = false),
                                            child: Container(
                                              width: 26,
                                              height: 26,
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFFF7043),
                                                shape: BoxShape.circle,
                                                border: Border.all(color: Colors.white, width: 2),
                                                boxShadow: const [
                                                  BoxShadow(color: Colors.black38, blurRadius: 4, offset: Offset(0, 2)),
                                                ],
                                              ),
                                              child: const Center(
                                                child: Icon(Icons.open_in_full_rounded, size: 13, color: Colors.white),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                );
                              }),

                            // Empty State Message if all boxes are deleted
                            if (_analysisResult != null && _analysisResult!.detectedBoxes.isEmpty)
                              Center(
                                child: Container(
                                  margin: const EdgeInsets.all(24),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.72),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Text(
                                    'تمام کادرهای متن حذف شده‌اند.\nمی‌توانید با دستیار هوش مصنوعی پایین، کادرهای جدید اضافه کنید.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Colors.white, fontSize: 12, height: 1.4),
                                  ),
                                ),
                              ),

                            // AI Detected Checkpoints Preview Layer
                            if (_analysisResult != null)
                              ..._analysisResult!.checkpoints.map((chk) {
                                final left = chk.normalizedX * constraints.maxWidth;
                                final top = chk.normalizedY * constraints.maxHeight;
                                final w = (chk.normalizedWidth * constraints.maxWidth).clamp(24.0, 50.0);
                                final h = (chk.normalizedHeight * constraints.maxHeight).clamp(24.0, 50.0);

                                return Positioned(
                                  left: left,
                                  top: top,
                                  width: w,
                                  height: h,
                                  child: InteractiveCheckBoxWidget(
                                    key: ValueKey(chk.id),
                                    item: chk,
                                    isBuilderPreview: true,
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
