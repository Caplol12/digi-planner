import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import '../models/ai_layout_model.dart';
import '../models/check_item_model.dart';
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

class _ParsedLayoutData {
  final String title;
  final List<DetectedBox> boxes;
  final List<InteractiveCheckItem> checkpoints;

  _ParsedLayoutData({
    required this.title,
    required this.boxes,
    required this.checkpoints,
  });
}

class AiVisionLayoutService {
  /// Optimizes, downscales and encodes image to JPEG (max 1536px, 85% quality)
  /// for high-precision AI Vision inference with sharp lines and low payload.
  static Future<Uint8List> _optimizeImageForVision(Uint8List originalBytes) async {
    try {
      final decoded = img.decodeImage(originalBytes);
      if (decoded != null) {
        img.Image resized = decoded;
        const int maxDim = 1536;
        if (decoded.width > maxDim || decoded.height > maxDim) {
          if (decoded.width >= decoded.height) {
            resized = img.copyResize(decoded, width: maxDim);
          } else {
            resized = img.copyResize(decoded, height: maxDim);
          }
        }
        final jpegBytes = Uint8List.fromList(img.encodeJpg(resized, quality: 85));
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
        targetWidth: 1200,
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

  /// Draws a faint percentage coordinate grid (10% to 90%) with labels on all 4 borders
  /// on the image so the Vision AI can read precise coordinates using visual ruler ticks.
  static Uint8List _addCoordinateGridOverlay(Uint8List jpegBytes) {
    try {
      final image = img.decodeImage(jpegBytes);
      if (image == null) return jpegBytes;

      final gridColor = img.ColorRgba8(255, 30, 30, 100);
      final textColor = img.ColorRgba8(230, 0, 0, 200);
      final w = image.width;
      final h = image.height;

      for (int i = 1; i < 10; i++) {
        final x = (w * i / 10).round();
        final y = (h * i / 10).round();
        final pct = '${i * 10}%';

        // Draw vertical and horizontal ruler lines
        img.drawLine(image, x1: x, y1: 0, x2: x, y2: h - 1, color: gridColor, thickness: 1);
        img.drawLine(image, x1: 0, y1: y, x2: w - 1, y2: y, color: gridColor, thickness: 1);

        // Draw percentage labels on all 4 borders for visual reference
        img.drawString(image, pct, font: img.arial24, x: x + 4, y: 6, color: textColor);
        img.drawString(image, pct, font: img.arial24, x: x + 4, y: (h - 28).clamp(0, h), color: textColor);
        img.drawString(image, pct, font: img.arial24, x: 6, y: y + 4, color: textColor);
        img.drawString(image, pct, font: img.arial24, x: (w - 60).clamp(0, w), y: y + 4, color: textColor);
      }

      return Uint8List.fromList(img.encodeJpg(image, quality: 85));
    } catch (e) {
      debugPrint('⚠️ Grid overlay error: $e');
      return jpegBytes;
    }
  }

  static const String _visionExtractionPrompt = '''
شما یک سیستم هوش مصنوعی متخصص و بسیار دقیق در تحلیل ساختار و چیدمان صفحات ژورنال، پلنر و دفاتر برنامه‌ریزی هستید.
تصویر این برگه را با دقت دیداری بسیار بالا تحلیل کن و تمام بخش‌های نوشتن و نقاط تیک‌زدنی را استخراج کن.

📏 راهنمای خط‌کش و شبکه مختصات (Visual Grid Reference):
- روی تصویر یک شبکه راهنمای قرمز رنگ با برچسب درصد (از 10% تا 90%) در محورهای افقی و عمودی رسم شده است.
- از این خطوط و اعداد به عنوان خط‌کش دقیق دیداری استفاده کن و مختصات را مستقیماً با انطباق با این خطوط استخراج کن.
- مختصات را دقیق و با حداقل ۳ رقم اعشار (یا به صورت نسبت نرمال‌شده 0.0 تا 1.0) گزارش بده و اعداد را رند نکن (مثلاً اگر مرز بین ۲۰٪ و ۳۰٪ است عددی مثل 0.235 بنویس، نه 0.2 یا 0.25).

🎯 ۱. کادرهای متنی و نواحی نگارش (boxes):
تمام بخش‌های نوشتن، اسلات‌های ساعات، چک‌لیست‌های کار، کادرهای تاریخ، خطوط یادداشت و جدول‌ها را به صورت محدوده‌های ساختاریافته (Writing Zones) به ترتیب خواندن منطقی استخراج کن.
- مرز هر باکس باید دقیقاً منطبق بر ابتدا و انتهای واقعیِ فضای قابل‌نوشتن در تصویر باشد (Strict Bounding Box).
- نوع هر محدوده (type): "singleLine" (تیتر/تاریخ), "ruledLines" (خطوط یادداشت چندخطی), "checklist" (لیست کارها), "freeText" (یادداشت آزاد)

☑️ ۲. چک‌باکس‌ها و نقاط تیک‌زدنی مستقل (checkpoints):
تمام نقاطی از برگه که دارای مربع خالی تیک، دایره هبیت‌ترکر، ردیاب آب یا آیکون تیک‌زدنی هستند را به عنوان آیتم‌های تپ‌شدنی استخراج کن:
- مربع‌های خالی تسک‌ها و کارها (shape: "square")
- دایره‌های هبیت‌ترکر، روزهای هفته و عادات (shape: "circle")
- آیکون‌های لیوان آب، خودمراقبتی و وضعیت روحی (shape: "water" یا "heart")
- مختصات (normalizedX, normalizedY) باید دقیقاً بر روی مرکز/شروع همان مربع یا دایره قرار گیرد با عرض و ارتفاع متناسب (معمولاً بین 0.03 تا 0.06).

تمام مختصات باید نرمال‌شده (بین 0.0 تا 1.0) نسبت به کل عرض و ارتفاع تصویر باشند:
- normalizedX: موقعیت شروع از چپ (0.0 تا 1.0)
- normalizedY: موقعیت شروع از بالا (0.0 تا 1.0)
- normalizedWidth: عرض محدوده (0.0 تا 1.0)
- normalizedHeight: ارتفاع محدوده (0.0 تا 1.0)

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
  ],
  "checkpoints": [
    {
      "id": "chk_1",
      "label": "تسک اول",
      "normalizedX": 0.08,
      "normalizedY": 0.25,
      "normalizedWidth": 0.045,
      "normalizedHeight": 0.035,
      "shape": "square"
    }
  ]
}
''';

  /// Analyzes an image with Multimodal AI Vision (Developer server or Google AI Studio Gemini)
  static Future<AILayoutResult> detectLayout({
    String? imagePath,
    Uint8List? imageBytes,
    double aspectRatio = 2 / 3,
  }) async {
    await UserAiPreferencesService.ensureLoaded();
    final activeProvider = UserAiPreferencesService.activeProvider;

    // 1. Prepare image bytes
    Uint8List? bytes = imageBytes;
    if (bytes == null && imagePath != null && imagePath.isNotEmpty) {
      if (imagePath.startsWith('assets/')) {
        final byteData = await rootBundle.load(imagePath);
        bytes = byteData.buffer.asUint8List();
      } else {
        final file = File(imagePath);
        if (await file.exists()) {
          bytes = await file.readAsBytes();
        }
      }
    }

    if (bytes == null || bytes.isEmpty) {
      throw Exception('فایل تصویر معتبر یافت نشد یا داده‌های تصویر خالی است.');
    }

    // 2. Call the active AI Vision Provider
    _ParsedLayoutData? parsedData;
    String engineUsed;

    if (activeProvider == AiProviderType.googleAiStudio) {
      final apiKey = UserAiPreferencesService.geminiApiKey;
      if (apiKey.isEmpty) {
        throw Exception('کلید API گوگل AI استودیو وارد نشده است. لطفاً در بخش تنظیمات هوش مصنوعی، کلید اختصاصی خود را ثبت کنید.');
      }
      final model = UserAiPreferencesService.geminiModel;
      engineUsed = '$model (Google AI Studio)';
      parsedData = await _callGeminiVisionApi(
        bytes: bytes,
        apiKey: apiKey,
        model: model,
        aspectRatio: aspectRatio,
      );
    } else {
      final config = await AiConfigService.getConfig(forceRefresh: false);
      engineUsed = '${config.model} (سرور توسعه‌دهنده)';
      parsedData = await _callVisionApi(
        bytes: bytes,
        config: config,
        aspectRatio: aspectRatio,
      );
    }

    if (parsedData == null || (parsedData.boxes.isEmpty && parsedData.checkpoints.isEmpty)) {
      throw Exception('هوش مصنوعی موفق به استخراج کادرها از این تصویر نشد.');
    }

    return AILayoutResult(
      imagePath: imagePath ?? '',
      aspectRatio: aspectRatio,
      title: parsedData.title.isNotEmpty ? parsedData.title : 'قالب استخراج‌شده هوشمند',
      detectedBoxes: parsedData.boxes,
      checkpoints: parsedData.checkpoints,
      analysisEngine: engineUsed,
    );
  }

  /// Sends image to Developer Vision endpoint (OpenAI-compatible)
  static Future<_ParsedLayoutData?> _callVisionApi({
    required Uint8List bytes,
    required AiConfig config,
    required double aspectRatio,
  }) async {
    final optimizedBytes = await _optimizeImageForVision(bytes);
    final gridBytes = _addCoordinateGridOverlay(optimizedBytes);
    final base64Image = base64Encode(gridBytes);
    final dataUri = 'data:image/jpeg;base64,$base64Image';

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
              {'type': 'text', 'text': _visionExtractionPrompt},
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
        return _extractLayoutFromAiText(content);
      }
    } else {
      throw Exception('پاسخ ناموفق از سرور هوش مصنوعی (${response.statusCode}): ${response.body}');
    }

    return null;
  }

  /// Sends image to Google AI Studio Gemini API endpoint directly
  static Future<_ParsedLayoutData?> _callGeminiVisionApi({
    required Uint8List bytes,
    required String apiKey,
    required String model,
    required double aspectRatio,
  }) async {
    final optimizedBytes = await _optimizeImageForVision(bytes);
    final gridBytes = _addCoordinateGridOverlay(optimizedBytes);
    final base64Image = base64Encode(gridBytes);

    final cleanKey = apiKey.trim();
    final cleanModel = model.trim();
    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$cleanModel:generateContent?key=$cleanKey',
    );

    final requestPayload = {
      'contents': [
        {
          'role': 'user',
          'parts': [
            {'text': _visionExtractionPrompt},
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
        'temperature': 0.2,
        'maxOutputTokens': 4000,
        'responseMimeType': 'application/json',
      }
    };

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode(requestPayload),
    ).timeout(const Duration(seconds: 90));

    if (response.statusCode == 200) {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final candidates = decoded['candidates'] as List?;
      if (candidates != null && candidates.isNotEmpty) {
        final content = candidates[0]['content'];
        if (content != null && content['parts'] != null) {
          final parts = content['parts'] as List;
          final textPart = parts.firstWhere((p) => p['text'] != null, orElse: () => null);
          if (textPart != null && textPart['text'] is String) {
            return _extractLayoutFromAiText(textPart['text'] as String);
          }
        }
      }
      return null;
    } else {
      String errorMsg = 'پاسخ ناموفق از گوگل جمنای (${response.statusCode})';
      try {
        final errObj = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        if (errObj['error'] != null) {
          final err = errObj['error'];
          final msg = err['message']?.toString() ?? '';
          final status = err['status']?.toString() ?? '';
          if (status == 'API_KEY_INVALID' || msg.toLowerCase().contains('api key not valid')) {
            errorMsg = 'کلید Google AI Studio وارد شده نامعتبر است.';
          } else if (response.statusCode == 429 || msg.toLowerCase().contains('quota')) {
            errorMsg = 'محدودیت سهمیه (Quota) کلید جمنای رخ داده است.';
          } else if (msg.isNotEmpty) {
            errorMsg = 'خطای گوگل جمنای: $msg';
          }
        }
      } catch (_) {}
      throw Exception(errorMsg);
    }
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

  /// Parses AI response text into both DetectedBox list and InteractiveCheckItem list
  static _ParsedLayoutData? _extractLayoutFromAiText(String text) {
    try {
      final data = _cleanAndExtractJsonObject(text);
      if (data == null) return null;

      final title = data['title'] as String? ?? 'قالب هوشمند';
      final boxes = _extractBoxesFromJsonObject(data);
      final checkpoints = _extractCheckpointsFromJsonObject(data);

      return _ParsedLayoutData(
        title: title,
        boxes: boxes,
        checkpoints: checkpoints,
      );
    } catch (e) {
      debugPrint('Error parsing AI vision layout: $e\nRaw text: $text');
      return null;
    }
  }

  /// Parses boxes from json map
  static List<DetectedBox> _extractBoxesFromJsonObject(Map<String, dynamic> data) {
    final boxesJson = (data['boxes'] ?? data['detectedBoxes'] ?? data['items'] ?? data['elements']) as List? ?? [];
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
  }

  /// Parses checkpoints from json map
  static List<InteractiveCheckItem> _extractCheckpointsFromJsonObject(Map<String, dynamic> data) {
    final List<InteractiveCheckItem> checkpoints = [];
    final checkpointsJson = (data['checkpoints'] ?? data['checkItems'] ?? data['ticks'] ?? data['checkboxes']) as List? ?? [];

    for (int i = 0; i < checkpointsJson.length; i++) {
      try {
        final c = checkpointsJson[i] as Map<String, dynamic>;

        final shapeStr = (c['shape'] as String? ?? 'square').toLowerCase();
        CheckboxShape shape = CheckboxShape.square;
        if (shapeStr.contains('circle') || shapeStr.contains('round') || shapeStr.contains('dot') || shapeStr.contains('habit')) {
          shape = CheckboxShape.circle;
        } else if (shapeStr.contains('water') || shapeStr.contains('glass') || shapeStr.contains('drop')) {
          shape = CheckboxShape.water;
        } else if (shapeStr.contains('star') || shapeStr.contains('priority')) {
          shape = CheckboxShape.star;
        } else if (shapeStr.contains('heart') || shapeStr.contains('mood')) {
          shape = CheckboxShape.heart;
        }

        double rawX = (c['normalizedX'] as num?)?.toDouble() ?? 0.1;
        if (rawX > 1.0) rawX = rawX / 1000.0;
        double rawY = (c['normalizedY'] as num?)?.toDouble() ?? 0.1;
        if (rawY > 1.0) rawY = rawY / 1000.0;
        double rawW = (c['normalizedWidth'] as num?)?.toDouble() ?? 0.045;
        if (rawW > 1.0) rawW = rawW / 1000.0;
        double rawH = (c['normalizedHeight'] as num?)?.toDouble() ?? 0.035;
        if (rawH > 1.0) rawH = rawH / 1000.0;

        final rawId = c['id']?.toString().trim();
        final chkId = (rawId != null && rawId.isNotEmpty)
            ? '${rawId}_$i'
            : 'chk_ai_${DateTime.now().millisecondsSinceEpoch}_$i';

        Color checkColor = const Color(0xFF2E7D32);
        if (shape == CheckboxShape.water) {
          checkColor = const Color(0xFF0288D1);
        } else if (shape == CheckboxShape.heart) {
          checkColor = const Color(0xFFE91E63);
        } else if (shape == CheckboxShape.star) {
          checkColor = const Color(0xFFF57F17);
        }

        checkpoints.add(InteractiveCheckItem(
          id: chkId,
          label: c['label'] as String? ?? 'چک‌باکس',
          normalizedX: rawX.clamp(0.0, 0.96),
          normalizedY: rawY.clamp(0.0, 0.96),
          normalizedWidth: rawW.clamp(0.025, 0.15),
          normalizedHeight: rawH.clamp(0.02, 0.15),
          shape: shape,
          style: CheckboxStyle.checkmark,
          isChecked: false,
          checkColor: checkColor,
        ));
      } catch (e) {
        debugPrint('Error parsing checkpoint item: $e');
      }
    }
    return checkpoints;
  }

  static const String _chatEditSystemPrompt = '''
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

  /// Interactive Natural Language Chat Editing (Conversational Box Modification)
  static Future<ChatEditResponse> processChatEditCommand({
    required String userCommand,
    required List<DetectedBox> currentBoxes,
  }) async {
    await UserAiPreferencesService.ensureLoaded();
    final activeProvider = UserAiPreferencesService.activeProvider;

    // 1. Try Google AI Studio if active and key provided
    if (activeProvider == AiProviderType.googleAiStudio && UserAiPreferencesService.hasGeminiApiKey) {
      try {
        final geminiRes = await _callGeminiChatEdit(
          userCommand: userCommand,
          currentBoxes: currentBoxes,
          apiKey: UserAiPreferencesService.geminiApiKey,
          model: UserAiPreferencesService.geminiModel,
        );
        if (geminiRes != null) {
          return geminiRes;
        }
      } catch (e) {
        debugPrint('Gemini Chat Edit error, trying fallback: $e');
      }
    }

    // 2. Default Developer AI Endpoint
    try {
      final config = await AiConfigService.getConfig(forceRefresh: false);
      final boxesJson = currentBoxes.map((b) => b.toJson()).toList();

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
            {'role': 'system', 'content': _chatEditSystemPrompt},
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

            return ChatEditResponse(
              assistantMessage: msg,
              updatedBoxes: updatedList.isNotEmpty ? updatedList : currentBoxes,
              suggestionChips: chips,
            );
          }
        }
      }
    } catch (e) {
      debugPrint('AI Chat Edit fallback invoked: $e');
    }

    // Local Rule-based fallback for chat edit only if network fails
    return _localRuleBasedChatEdit(userCommand, currentBoxes);
  }

  /// Interactive Natural Language Chat Editing with Google AI Studio Gemini
  static Future<ChatEditResponse?> _callGeminiChatEdit({
    required String userCommand,
    required List<DetectedBox> currentBoxes,
    required String apiKey,
    required String model,
  }) async {
    final boxesJson = currentBoxes.map((b) => b.toJson()).toList();
    final prompt = '$_chatEditSystemPrompt\n\nدستور کاربر: "$userCommand"\n\nباکس‌های فعلی:\n${jsonEncode(boxesJson)}';

    final cleanKey = apiKey.trim();
    final cleanModel = model.trim();
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
            'role': 'user',
            'parts': [
              {'text': prompt}
            ]
          }
        ],
        'generationConfig': {
          'temperature': 0.3,
          'maxOutputTokens': 3000,
          'responseMimeType': 'application/json',
        }
      }),
    ).timeout(const Duration(seconds: 45));

    if (response.statusCode == 200) {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final candidates = decoded['candidates'] as List?;
      if (candidates != null && candidates.isNotEmpty) {
        final content = candidates[0]['content'];
        if (content != null && content['parts'] != null) {
          final parts = content['parts'] as List;
          final textPart = parts.firstWhere((p) => p['text'] != null, orElse: () => null);
          if (textPart != null && textPart['text'] is String) {
            final resObj = _cleanAndExtractJsonObject(textPart['text'] as String);
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
