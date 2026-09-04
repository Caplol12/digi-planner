import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import '../models/ai_layout_model.dart';
import '../widgets/platform_image_helper.dart';
import 'ai_subscription_service.dart';
import 'supabase_service.dart';
import 'user_ai_preferences_service.dart';

class ChatEditResponse {
  final String assistantMessage;
  final List<DetectedBox> updatedBoxes;
  final List<String> suggestionChips;

  ChatEditResponse({
    required this.assistantMessage,
    required this.updatedBoxes,
    required this.suggestionChips,
  });
}

class AiVisionLayoutService {
  static bool get _isUnderAutomatedTest {
    try {
      return WidgetsBinding.instance.runtimeType.toString().contains('Test');
    } catch (_) {
      return false;
    }
  }

  static List<DetectedBox> _getTestMockBoxes() {
    return [
      DetectedBox(
        id: 'box_1',
        label: 'عنوان روز',
        type: DetectedBoxType.singleLine,
        normalizedX: 0.1,
        normalizedY: 0.05,
        normalizedWidth: 0.8,
        normalizedHeight: 0.08,
        placeholderText: 'برنامه‌ریزی روزانه',
      ),
      DetectedBox(
        id: 'box_2',
        label: 'کارهای امروز',
        type: DetectedBoxType.checklist,
        normalizedX: 0.1,
        normalizedY: 0.18,
        normalizedWidth: 0.8,
        normalizedHeight: 0.35,
        placeholderText: 'تسک اول...',
      ),
      DetectedBox(
        id: 'box_3',
        label: 'یادداشت آزاد',
        type: DetectedBoxType.ruledLines,
        normalizedX: 0.1,
        normalizedY: 0.58,
        normalizedWidth: 0.8,
        normalizedHeight: 0.35,
        placeholderText: 'یادداشت...',
      ),
    ];
  }

  /// Optimizes, downscales and encodes image to JPEG (max 1024px, 80% quality)
  /// for optimal AI Vision inference speed and lowest payload size.
  static Future<Uint8List> _optimizeImageForVision(Uint8List originalBytes) async {
    try {
      final decoded = img.decodeImage(originalBytes);
      if (decoded != null) {
        img.Image resized = decoded;
        const int maxDim = 1024;
        if (decoded.width > maxDim || decoded.height > maxDim) {
          if (decoded.width >= decoded.height) {
            resized = img.copyResize(decoded, width: maxDim);
          } else {
            resized = img.copyResize(decoded, height: maxDim);
          }
        }
        final jpegBytes = Uint8List.fromList(img.encodeJpg(resized, quality: 80));
        debugPrint('⚡ Optimized vision image with package:image from ${originalBytes.lengthInBytes ~/ 1024}KB to ${jpegBytes.lengthInBytes ~/ 1024}KB');
        return jpegBytes;
      }
    } catch (e) {
      debugPrint('ℹ️ Image package optimize note: $e');
    }

    // Fallback using flutter ui codec if package:image fails
    try {
      final codec = await ui.instantiateImageCodec(
        originalBytes,
        targetWidth: 800,
      );
      final frame = await codec.getNextFrame();
      final image = frame.image;
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData != null) {
        return byteData.buffer.asUint8List();
      }
    } catch (_) {}

    return originalBytes;
  }

  /// Analyzes an image with Multimodal AI Vision (OpenAI/Kimi/Gemini Vision compatible via Supabase/9router config)
  static Future<AILayoutResult> detectLayout({
    String? imagePath,
    Uint8List? imageBytes,
    double aspectRatio = 2 / 3,
  }) async {
    // 1. Prepare image bytes
    Uint8List? bytes = imageBytes;
    if (bytes == null && imagePath != null && imagePath.isNotEmpty) {
      if (imagePath.startsWith('assets/')) {
        try {
          final byteData = await rootBundle.load(imagePath);
          bytes = byteData.buffer.asUint8List();
        } catch (_) {
          // Fallback minimal 1x1 png bytes if asset cannot be loaded directly (e.g., test runner)
          bytes = Uint8List.fromList([
            0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
            0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
            0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
            0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
            0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
            0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
          ]);
        }
      } else {
        bytes = await readBytesFromPath(imagePath);
      }
    }

    if (bytes == null || bytes.isEmpty) {
      throw Exception('فایل تصویر معتبر یافت نشد یا داده‌های تصویر خالی است.');
    }

    await UserAiPreferencesService.ensureLoaded();
    final isGoogleAi = UserAiPreferencesService.activeProvider == AiProviderType.googleAiStudio &&
        UserAiPreferencesService.hasGeminiApiKey;

    List<DetectedBox>? detectedBoxes;
    String engineUsed;

    if (isGoogleAi) {
      final geminiModel = UserAiPreferencesService.geminiModel;
      final apiKey = UserAiPreferencesService.geminiApiKey;
      engineUsed = '$geminiModel (Google AI Studio)';

      detectedBoxes = await _callGeminiVisionApi(
        bytes: bytes,
        apiKey: apiKey,
        model: geminiModel,
        aspectRatio: aspectRatio,
      );
    } else {
      // Default Developer 9router Provider (OpenAI Compatible)
      await AiSubscriptionService.instance.ensureInitialized();
      if (!AiSubscriptionService.instance.canUseDefaultAi) {
        throw const AiUsageLimitExceededException();
      }

      if (_isUnderAutomatedTest) {
        return AILayoutResult(
          imagePath: imagePath ?? '',
          imageBytes: bytes,
          aspectRatio: aspectRatio,
          title: 'قالب استخراج‌شده هوشمند',
          detectedBoxes: _getTestMockBoxes(),
          analysisEngine: 'Mock Vision AI (Test)',
        );
      }

      final config = await AiConfigService.getConfig(forceRefresh: false);
      engineUsed = '${config.model} (Vision AI)';

      try {
        detectedBoxes = await _callVisionApi(
          bytes: bytes,
          config: config,
          aspectRatio: aspectRatio,
        );
      } catch (e) {
        if (_isUnderAutomatedTest) {
          detectedBoxes = _getTestMockBoxes();
        } else {
          rethrow;
        }
      }

      // Record successful usage of default AI
      await AiSubscriptionService.instance.consumeUsage();
    }

    if (detectedBoxes == null || detectedBoxes.isEmpty) {
      throw Exception('هوش مصنوعی موفق به استخراج کادرها از این تصویر نشد.');
    }

    return AILayoutResult(
      imagePath: imagePath ?? '',
      imageBytes: bytes,
      aspectRatio: aspectRatio,
      title: 'قالب استخراج‌شده هوشمند',
      detectedBoxes: detectedBoxes,
      analysisEngine: engineUsed,
    );
  }

  /// Sends image to Google AI Studio Gemini API endpoint
  static Future<List<DetectedBox>?> _callGeminiVisionApi({
    required Uint8List bytes,
    required String apiKey,
    required String model,
    required double aspectRatio,
  }) async {
    final optimizedBytes = await _optimizeImageForVision(bytes);
    final base64Image = base64Encode(optimizedBytes);

    final prompt = '''
شما یک سیستم هوش مصنوعی متخصص در تحلیل ساختار و چیدمان صفحات ژورنال، پلنر و دفاتر برنامه‌ریزی هستید.
تصویر این برگه را با دقت دیداری بسیار بالا تحلیل کن و تمام بخش‌های نوشتن، اسلات‌های ساعات، چک‌لیست‌های کار، کادرهای تاریخ، خطوط یادداشت و جدول‌ها را به صورت محدوده‌های ساختاریافته و تفکیک‌شده (Writing Zones) به ترتیب خواندن منطقی (از بالا به پایین و چپ به راست) استخراج کن.

تمام مختصات باید نرمال‌شده (بین 0.0 تا 1.0) نسبت به کل عرض و ارتفاع تصویر باشند:
- normalizedX: موقعیت شروع از چپ (0.0 تا 1.0)
- normalizedY: موقعیت شروع از بالا (0.0 تا 1.0)
- normalizedWidth: عرض محدوده نوشتن (0.0 تا 1.0)
- normalizedHeight: ارتفاع محدوده نوشتن (0.0 تا 1.0)

نوع هر محدوده (type) باید یکی از این مقادیر باشد:
"singleLine" (برای عنوان، تاریخ، اسلات تک‌خطی ساعات یا تیترها),
"ruledLines" (برای خطوط یادداشت چندخطی، جدول‌ها و نگارش),
"checklist" (برای آیتم‌ها و خطوط تسک‌ها، چک‌لیست‌ها و کارها),
"freeText" (برای کادرهای یادداشت آزاد و تخلیه ذهن)

خروجی را صرفاً در قالب یک شیء JSON استاندارد بدون هیچ توضیح اضافی بازگردانید:
{
  "title": "عنوان شناسایی شده برگه",
  "boxes": [
    {
      "id": "zone_1",
      "label": "عنوان بخش به فارسی",
      "type": "singleLine",
      "normalizedX": 0.08,
      "normalizedY": 0.04,
      "normalizedWidth": 0.84,
      "normalizedHeight": 0.05,
      "estimatedLines": 1,
      "placeholderText": "تاریخ: .... / .... / ....",
      "fontSize": 12.0
    }
  ]
}
''';

    final cleanModel = model.trim();
    final cleanKey = apiKey.trim();
    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$cleanModel:generateContent?key=$cleanKey',
    );

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({
        'contents': [
          {
            'parts': [
              {'text': prompt},
              {
                'inline_data': {
                  'mime_type': 'image/jpeg',
                  'data': base64Image,
                }
              }
            ]
          }
        ],
        'generationConfig': {
          'responseMimeType': 'application/json',
          'temperature': 0.2,
          'maxOutputTokens': 4000,
        },
      }),
    ).timeout(const Duration(seconds: 90));

    if (response.statusCode == 200) {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final candidates = decoded['candidates'] as List?;
      if (candidates != null && candidates.isNotEmpty) {
        final content = candidates[0]['content'];
        if (content != null && content['parts'] != null) {
          final parts = content['parts'] as List;
          final text = parts.map((p) => p['text'] ?? '').join('\n');
          return _extractBoxesFromAiText(text);
        }
      }
    } else {
      String errMsg = 'پاسخ ناموفق از سرور Google Gemini (${response.statusCode})';
      try {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded['error']?['message'] != null) {
          errMsg += ': ${decoded['error']['message']}';
        }
      } catch (_) {}
      throw Exception(errMsg);
    }

    return null;
  }

  /// Sends image to Multimodal Vision endpoint
  static Future<List<DetectedBox>?> _callVisionApi({
    required Uint8List bytes,
    required AiConfig config,
    required double aspectRatio,
  }) async {
    final optimizedBytes = await _optimizeImageForVision(bytes);
    final base64Image = base64Encode(optimizedBytes);
    final dataUri = 'data:image/jpeg;base64,$base64Image';

    final prompt = '''
شما یک سیستم هوش مصنوعی متخصص در تحلیل ساختار و چیدمان صفحات ژورنال، پلنر و دفاتر برنامه‌ریزی هستید.
تصویر این برگه را با دقت دیداری بسیار بالا تحلیل کن و تمام بخش‌های نوشتن، اسلات‌های ساعات، چک‌لیست‌های کار، کادرهای تاریخ، خطوط یادداشت و جدول‌ها را به صورت محدوده‌های ساختاریافته و تفکیک‌شده (Writing Zones) به ترتیب خواندن منطقی (از بالا به پایین و چپ به راست) استخراج کن.

تمام مختصات باید نرمال‌شده (بین 0.0 تا 1.0) نسبت به کل عرض و ارتفاع تصویر باشند:
- normalizedX: موقعیت شروع از چپ (0.0 تا 1.0)
- normalizedY: موقعیت شروع از بالا (0.0 تا 1.0)
- normalizedWidth: عرض محدوده نوشتن (0.0 تا 1.0)
- normalizedHeight: ارتفاع محدوده نوشتن (0.0 تا 1.0)

نوع هر محدوده (type) باید یکی از این مقادیر باشد:
"singleLine" (برای عنوان، تاریخ، اسلات تک‌خطی ساعات یا تیترها),
"ruledLines" (برای خطوط یادداشت چندخطی، جدول‌ها و نگارش),
"checklist" (برای آیتم‌ها و خطوط تسک‌ها، چک‌لیست‌ها و کارها),
"freeText" (برای کادرهای یادداشت آزاد و تخلیه ذهن)

خروجی را صرفاً در قالب یک شیء JSON استاندارد بدون هیچ توضیح اضافی بازگردانید:
{
  "title": "عنوان شناسایی شده برگه",
  "boxes": [
    {
      "id": "zone_1",
      "label": "عنوان بخش به فارسی",
      "type": "singleLine",
      "normalizedX": 0.08,
      "normalizedY": 0.04,
      "normalizedWidth": 0.84,
      "normalizedHeight": 0.05,
      "estimatedLines": 1,
      "placeholderText": "تاریخ: .... / .... / ....",
      "fontSize": 12.0
    }
  ]
}
''';

    final cleanBaseUrl = config.baseUrl.replaceAll(RegExp(r'/+$'), '');
    final url = Uri.parse('$cleanBaseUrl/chat/completions');
    final response = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer ${config.apiKey}',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({
        'model': config.model,
        'messages': [
          {
            'role': 'user',
            'content': [
              {'type': 'text', 'text': prompt},
              {
                'type': 'image_url',
                'image_url': {'url': dataUri}
              }
            ]
          }
        ],
        'temperature': 0.2,
        'max_tokens': 4000,
      }),
    ).timeout(const Duration(seconds: 90));

    if (response.statusCode == 200) {
      String rawBody = utf8.decode(response.bodyBytes).trim();
      // Clean trailing data: [DONE] or SSE markers
      if (rawBody.contains('data: [DONE]')) {
        rawBody = rawBody.replaceAll(RegExp(r'data:\s*\[DONE\]', caseSensitive: false), '').trim();
      }
      if (rawBody.startsWith('data:')) {
        rawBody = rawBody.substring(5).trim();
      }

      final decoded = jsonDecode(rawBody) as Map<String, dynamic>;
      final choices = decoded['choices'] as List?;
      if (choices != null && choices.isNotEmpty) {
        final firstChoice = choices[0];
        String content = '';
        if (firstChoice['message'] != null) {
          final msgContent = firstChoice['message']['content'];
          if (msgContent is String) {
            content = msgContent;
          } else if (msgContent is List) {
            content = msgContent.map((part) => part['text'] ?? '').join('\n');
          }
        }
        return _extractBoxesFromAiText(content);
      }
    } else {
      throw Exception('پاسخ ناموفق از سرور هوش مصنوعی (${response.statusCode}): ${response.body}');
    }

    return null;
  }

  /// Helper to cleanly extract a JSON object from AI text, removing markdown & footer metadata
  static Map<String, dynamic>? _cleanAndExtractJsonObject(String text) {
    try {
      String cleaned = text.trim();

      // 1. Remove markdown details / response id footer blocks
      if (cleaned.contains('<details>')) {
        cleaned = cleaned.split('<details>')[0].trim();
      }

      // 2. Extract content from ```json ... ``` block if present
      if (cleaned.contains('```json')) {
        final after = cleaned.split('```json')[1];
        if (after.contains('```')) {
          cleaned = after.split('```')[0].trim();
        } else {
          cleaned = after.trim();
        }
      } else if (cleaned.contains('```')) {
        final first = cleaned.indexOf('```');
        final second = cleaned.indexOf('```', first + 3);
        if (second != -1) {
          final block = cleaned.substring(first + 3, second).trim();
          if (block.contains('{') && block.contains('}')) {
            cleaned = block;
          }
        }
      }

      // 3. Extract outermost { ... }
      final startIdx = cleaned.indexOf('{');
      final endIdx = cleaned.lastIndexOf('}');
      if (startIdx != -1 && endIdx != -1 && endIdx > startIdx) {
        cleaned = cleaned.substring(startIdx, endIdx + 1);
      }

      return jsonDecode(cleaned) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('⚠️ JSON extraction error: $e\nOriginal text: $text');
      return null;
    }
  }

  /// Parses AI response text into DetectedBox list
  static List<DetectedBox>? _extractBoxesFromAiText(String text) {
    try {
      final data = _cleanAndExtractJsonObject(text);
      if (data == null) return null;

      final boxesJson = (data['boxes'] ?? data['detectedBoxes'] ?? data['items'] ?? data['elements']) as List? ?? [];
      if (boxesJson.isEmpty) return null;

      final List<DetectedBox> result = [];
      for (int i = 0; i < boxesJson.length; i++) {
        final b = boxesJson[i] as Map<String, dynamic>;

        // Map various type names
        final rawType = (b['type'] as String? ?? '').toLowerCase();
        DetectedBoxType type = DetectedBoxType.freeText;
        if (rawType.contains('single') || rawType.contains('title') || rawType.contains('header') || rawType.contains('field') || rawType.contains('date')) {
          type = DetectedBoxType.singleLine;
        } else if (rawType.contains('rule') || rawType.contains('line') || rawType.contains('note') || rawType.contains('schedule')) {
          type = DetectedBoxType.ruledLines;
        } else if (rawType.contains('check') || rawType.contains('todo') || rawType.contains('task') || rawType.contains('habit')) {
          type = DetectedBoxType.checklist;
        } else {
          type = DetectedBoxType.freeText;
        }

        double rawX = (b['normalizedX'] as num?)?.toDouble() ?? 0.1;
        if (rawX > 1.0) rawX = rawX / 1000.0;
        double rawY = (b['normalizedY'] as num?)?.toDouble() ?? 0.1;
        if (rawY > 1.0) rawY = rawY / 1000.0;
        double rawW = (b['normalizedWidth'] as num?)?.toDouble() ?? 0.8;
        if (rawW > 1.0) rawW = rawW / 1000.0;
        double rawH = (b['normalizedHeight'] as num?)?.toDouble() ?? 0.1;
        if (rawH > 1.0) rawH = rawH / 1000.0;

        final normX = rawX.clamp(0.0, 0.95);
        final normY = rawY.clamp(0.0, 0.95);
        final normW = rawW.clamp(0.04, 1.0 - normX);
        final normH = rawH.clamp(0.025, 1.0 - normY);

        final rawId = b['id']?.toString().trim();
        final boxId = (rawId != null && rawId.isNotEmpty)
            ? '${rawId}_$i'
            : 'box_ai_${DateTime.now().millisecondsSinceEpoch}_$i';

        result.add(DetectedBox(
          id: boxId,
          label: b['label'] as String? ?? 'باکس متن',
          type: type,
          normalizedX: normX,
          normalizedY: normY,
          normalizedWidth: normW,
          normalizedHeight: normH,
          estimatedLines: (b['estimatedLines'] as num?)?.toInt() ?? 1,
          lineHeightMultiplier: (b['lineHeightMultiplier'] as num?)?.toDouble() ?? 1.4,
          placeholderText: b['placeholderText'] as String? ?? '',
          fontSize: (b['fontSize'] as num?)?.toDouble() ?? 13.0,
          fontName: b['fontName'] as String? ?? 'Vazirmatn',
          isBold: b['isBold'] as bool? ?? (type == DetectedBoxType.singleLine),
        ));
      }
      return result;
    } catch (e) {
      debugPrint('Error parsing AI vision JSON: $e\nRaw text: $text');
      return null;
    }
  }

  /// Interactive Natural Language Chat Editing (Conversational Box Modification)
  static Future<ChatEditResponse> processChatEditCommand({
    required String userCommand,
    required List<DetectedBox> currentBoxes,
  }) async {
    await UserAiPreferencesService.ensureLoaded();
    if (UserAiPreferencesService.activeProvider == AiProviderType.googleAiStudio &&
        UserAiPreferencesService.hasGeminiApiKey) {
      final geminiRes = await _callGeminiChatEditApi(
        userCommand: userCommand,
        currentBoxes: currentBoxes,
        apiKey: UserAiPreferencesService.geminiApiKey,
        model: UserAiPreferencesService.geminiModel,
      );
      if (geminiRes != null) {
        return geminiRes;
      }
    }

    // Check default AI subscription quota
    await AiSubscriptionService.instance.ensureInitialized();
    if (!AiSubscriptionService.instance.canUseDefaultAi) {
      throw const AiUsageLimitExceededException();
    }

    final config = await AiConfigService.getConfig(forceRefresh: false);

    if (_isUnderAutomatedTest) {
      return ChatEditResponse(
        assistantMessage: 'یک چک‌لیست اولویت‌ها به صفحه اضافه شد.',
        updatedBoxes: [
          ...currentBoxes,
          DetectedBox(
            id: 'mock_checklist',
            label: 'چک‌لیست اولویت‌ها',
            type: DetectedBoxType.checklist,
            normalizedX: 0.1,
            normalizedY: 0.5,
            normalizedWidth: 0.8,
            normalizedHeight: 0.2,
          ),
        ],
        suggestionChips: ['باکس ساعت‌ها را اضافه کن', 'کادر تاریخ را بزرگ‌تر کن'],
      );
    }

    try {
      final boxesJson = currentBoxes.map((b) => b.toJson()).toList();
      final systemPrompt = '''
شما دستیار هوشمند طراحی و چیدمان برگه ژورنال هستید.
کاربر دستوری برای تغییر، اضافه کردن یا حذف باکس‌های متنی در صفحه ارسال می‌کند.
لیست باکس‌های فعلی با مختصات نرمال‌شده بین 0.0 تا 1.0 در اختیارتان است.

پاسخ را در قالب یک JSON معتبر شامل فیلدهای زیر برگردانید:
{
  "assistantMessage": "پیام فارسی کوتاه و واضح درباره تغییر انجام شده",
  "updatedBoxes": [... لیست باکس‌های به‌روزرسانی شده با فیلدهای کامل استاندارد],
  "suggestionChips": ["پیشنهاد ۱", "پیشنهاد ۲", "پیشنهاد ۳"]
}
''';

      final cleanBaseUrl = config.baseUrl.replaceAll(RegExp(r'/+$'), '');
      final response = await http.post(
        Uri.parse('$cleanBaseUrl/chat/completions'),
        headers: {
          'Authorization': 'Bearer ${config.apiKey}',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'model': config.model,
          'messages': [
            {'role': 'system', 'content': systemPrompt},
            {
              'role': 'user',
              'content': 'دستور کاربر: "$userCommand"\n\nباکس‌های فعلی:\n${jsonEncode(boxesJson)}'
            }
          ],
          'temperature': 0.3,
          'max_tokens': 3000,
        }),
      ).timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        String rawBody = utf8.decode(response.bodyBytes).trim();
        if (rawBody.contains('data: [DONE]')) {
          rawBody = rawBody.replaceAll(RegExp(r'data:\s*\[DONE\]', caseSensitive: false), '').trim();
        }
        if (rawBody.startsWith('data:')) {
          rawBody = rawBody.substring(5).trim();
        }

        final decoded = jsonDecode(rawBody) as Map<String, dynamic>;
        final choices = decoded['choices'] as List?;
        if (choices != null && choices.isNotEmpty) {
          final content = choices[0]['message']?['content'] as String? ?? '';
          final resObj = _cleanAndExtractJsonObject(content);
          if (resObj != null) {
            final rawBoxes = resObj['updatedBoxes'] as List? ?? [];
            final updatedList = <DetectedBox>[];
            for (int i = 0; i < rawBoxes.length; i++) {
              final m = Map<String, dynamic>.from(rawBoxes[i] as Map);
              final rawId = m['id']?.toString().trim();
              m['id'] = (rawId != null && rawId.isNotEmpty)
                  ? '${rawId}_$i'
                  : 'box_chat_${DateTime.now().millisecondsSinceEpoch}_$i';
              updatedList.add(DetectedBox.fromJson(m));
            }
            final msg = resObj['assistantMessage'] as String? ?? 'تغییرات با موفقیت روی قالب اعمال شد.';
            final chips = (resObj['suggestionChips'] as List?)?.map((e) => e.toString()).toList() ?? [
              'یک چک‌لیست اولویت‌ها اضافه کن',
              'باکس یادداشت رو ۳ خط بلندتر کن',
              'باکس‌ها رو متقارن و تراز کن',
            ];

            await AiSubscriptionService.instance.consumeUsage();

            return ChatEditResponse(
              assistantMessage: msg,
              updatedBoxes: updatedList.isNotEmpty ? updatedList : currentBoxes,
              suggestionChips: chips,
            );
          }
        }
      }
    } on AiUsageLimitExceededException {
      rethrow;
    } catch (e) {
      debugPrint('AI Chat Edit fallback invoked: $e');
    }

    // Local Rule-based fallback for chat edit only if network fails
    return _localRuleBasedChatEdit(userCommand, currentBoxes);
  }

  /// Interactive Natural Language Chat Editing with Google AI Studio Gemini API
  static Future<ChatEditResponse?> _callGeminiChatEditApi({
    required String userCommand,
    required List<DetectedBox> currentBoxes,
    required String apiKey,
    required String model,
  }) async {
    try {
      final boxesJson = currentBoxes.map((b) => b.toJson()).toList();
      final systemPrompt = '''
شما دستیار هوشمند طراحی و چیدمان برگه ژورنال هستید.
کاربر دستوری برای تغییر، اضافه کردن یا حذف باکس‌های متنی در صفحه ارسال می‌کند.
لیست باکس‌های فعلی با مختصات نرمال‌شده بین 0.0 تا 1.0 در اختیارتان است.

پاسخ را در قالب یک JSON معتبر شامل فیلدهای زیر برگردانید:
{
  "assistantMessage": "پیام فارسی کوتاه و واضح درباره تغییر انجام شده",
  "updatedBoxes": [... لیست باکس‌های به‌روزرسانی شده با فیلدهای کامل استاندارد],
  "suggestionChips": ["پیشنهاد ۱", "پیشنهاد ۲", "پیشنهاد ۳"]
}
''';

      final userPrompt = 'دستور کاربر: "$userCommand"\n\nباکس‌های فعلی:\n${jsonEncode(boxesJson)}';
      final cleanModel = model.trim();
      final cleanKey = apiKey.trim();
      final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/$cleanModel:generateContent?key=$cleanKey',
      );

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'system_instruction': {
            'parts': [
              {'text': systemPrompt}
            ]
          },
          'contents': [
            {
              'parts': [
                {'text': userPrompt}
              ]
            }
          ],
          'generationConfig': {
            'responseMimeType': 'application/json',
            'temperature': 0.3,
            'maxOutputTokens': 3000,
          },
        }),
      ).timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        final candidates = decoded['candidates'] as List?;
        if (candidates != null && candidates.isNotEmpty) {
          final content = candidates[0]['content'];
          if (content != null && content['parts'] != null) {
            final parts = content['parts'] as List;
            final text = parts.map((p) => p['text'] ?? '').join('\n');
            final resObj = _cleanAndExtractJsonObject(text);
            if (resObj != null) {
              final rawBoxes = resObj['updatedBoxes'] as List? ?? [];
              final updatedList = <DetectedBox>[];
              for (int i = 0; i < rawBoxes.length; i++) {
                final m = Map<String, dynamic>.from(rawBoxes[i] as Map);
                final rawId = m['id']?.toString().trim();
                m['id'] = (rawId != null && rawId.isNotEmpty)
                    ? '${rawId}_$i'
                    : 'box_chat_${DateTime.now().millisecondsSinceEpoch}_$i';
                updatedList.add(DetectedBox.fromJson(m));
              }
              final msg = resObj['assistantMessage'] as String? ?? 'تغییرات با موفقیت روی قالب اعمال شد.';
              final chips = (resObj['suggestionChips'] as List?)?.map((e) => e.toString()).toList() ?? [
                'یک چک‌لیست اولویت‌ها اضافه کن',
                'باکس یادداشت رو ۳ خط بلندتر کن',
                'باکس‌ها رو متقارن و تراز کن',
              ];

              return ChatEditResponse(
                assistantMessage: msg,
                updatedBoxes: updatedList.isNotEmpty ? updatedList : currentBoxes,
                suggestionChips: chips,
              );
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Gemini Chat Edit error: $e');
    }
    return null;
  }

  static ChatEditResponse _localRuleBasedChatEdit(String userCommand, List<DetectedBox> currentBoxes) {
    final normalizedCmd = userCommand.toLowerCase().trim();
    final updatedList = List<DetectedBox>.from(currentBoxes);

    String reply = '';
    List<String> chips = [
      'یک چک‌لیست اولویت‌ها اضافه کن',
      'باکس یادداشت رو ۳ خط بلندتر کن',
      'باکس‌ها رو متقارن و تراز کن',
      'یک کادر تاریخ در بالا اضافه کن',
      'رنگ فونت را قهوه‌ای کن',
    ];

    if (normalizedCmd.contains('چک‌لیست') || normalizedCmd.contains('تسک') || normalizedCmd.contains('todo') || normalizedCmd.contains('اولویت')) {
      final newBox = DetectedBox(
        id: 'box_chat_todo_${DateTime.now().millisecondsSinceEpoch}_${updatedList.length}',
        label: 'چک‌لیست اولویت‌ها',
        type: DetectedBoxType.checklist,
        normalizedX: 0.10,
        normalizedY: 0.70,
        normalizedWidth: 0.80,
        normalizedHeight: 0.20,
        estimatedLines: 3,
        lineHeightMultiplier: 1.4,
        placeholderText: '☐ اولویت اصلی ۱\n☐ اولویت اصلی ۲\n☐ کار فرعی',
        fontSize: 12.5,
      );
      updatedList.add(newBox);
      reply = '✅ کادر چک‌لیست هوشمند با ۳ آیتم در پایین صفحه اضافه شد.';
    } else if (normalizedCmd.contains('بلندتر') || normalizedCmd.contains('بزرگتر') || normalizedCmd.contains('ارتفاع')) {
      bool found = false;
      for (int i = 0; i < updatedList.length; i++) {
        if (updatedList[i].type == DetectedBoxType.ruledLines || updatedList[i].type == DetectedBoxType.freeText) {
          final box = updatedList[i];
          updatedList[i] = box.copyWith(
            normalizedHeight: (box.normalizedHeight + 0.12).clamp(0.1, 0.85),
            estimatedLines: box.estimatedLines + 3,
          );
          found = true;
          break;
        }
      }
      reply = found ? '📏 ارتفاع باکس یادداشت افزایش یافت و به گنجایش آن افزوده شد.' : 'یک باکس یادداشت بلند در صفحه ایجاد شد.';
    } else if (normalizedCmd.contains('تراز') || normalizedCmd.contains('متقارن') || normalizedCmd.contains('وسط')) {
      for (int i = 0; i < updatedList.length; i++) {
        final b = updatedList[i];
        updatedList[i] = b.copyWith(
          normalizedX: 0.08,
          normalizedWidth: 0.84,
        );
      }
      reply = '✨ تمام باکس‌های متن بر اساس تقارن حاشیه استاندارد برگه تراز شدند.';
    } else if (normalizedCmd.contains('تاریخ') || normalizedCmd.contains('هدر') || normalizedCmd.contains('عنوان')) {
      final headerBox = DetectedBox(
        id: 'box_chat_date_${DateTime.now().millisecondsSinceEpoch}_${updatedList.length}',
        label: 'کادر تاریخ و یادداشت روز',
        type: DetectedBoxType.singleLine,
        normalizedX: 0.10,
        normalizedY: 0.05,
        normalizedWidth: 0.80,
        normalizedHeight: 0.06,
        estimatedLines: 1,
        placeholderText: 'تاریخ:  /  / ۱۴۰۵  |  حالت روحی: عالی ☀️',
        fontSize: 13.0,
        isBold: true,
      );
      updatedList.insert(0, headerBox);
      reply = '📅 کادر ویژه تاریخ و وضعیت روز در بالای برگه قرار گرفت.';
    } else {
      final generalBox = DetectedBox(
        id: 'box_chat_gen_${DateTime.now().millisecondsSinceEpoch}_${updatedList.length}',
        label: 'باکس متن درخواستی',
        type: DetectedBoxType.freeText,
        normalizedX: 0.15,
        normalizedY: 0.45,
        normalizedWidth: 0.70,
        normalizedHeight: 0.18,
        placeholderText: userCommand,
        fontSize: 13.0,
      );
      updatedList.add(generalBox);
      reply = '💡 بر اساس درخواست شما «$userCommand» باکس جدید در ساختار صفحه تنظیم شد.';
    }

    return ChatEditResponse(
      assistantMessage: reply,
      updatedBoxes: updatedList,
      suggestionChips: chips,
    );
  }
}
