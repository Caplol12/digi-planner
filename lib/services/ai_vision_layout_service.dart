import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../models/ai_layout_model.dart';
import 'supabase_service.dart';

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
  /// Downscales high-resolution template images proportionally to ~800px width
  /// to dramatically reduce payload size (from 800KB+ to ~40KB) and speed up AI inference.
  static Future<Uint8List> _optimizeImageForVision(Uint8List originalBytes) async {
    try {
      if (originalBytes.lengthInBytes < 120 * 1024) {
        return originalBytes;
      }

      final codec = await ui.instantiateImageCodec(
        originalBytes,
        targetWidth: 800,
      );
      final frame = await codec.getNextFrame();
      final image = frame.image;
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData != null) {
        final resized = byteData.buffer.asUint8List();
        debugPrint('⚡ Optimized image from ${originalBytes.lengthInBytes ~/ 1024}KB to ${resized.lengthInBytes ~/ 1024}KB');
        return resized;
      }
    } catch (e) {
      debugPrint('ℹ️ Image optimize note: $e');
    }
    return originalBytes;
  }

  /// Analyzes an image with Multimodal AI Vision (OpenAI/Kimi/Gemini Vision compatible via Supabase/9router config)
  static Future<AILayoutResult> detectLayout({
    String? imagePath,
    Uint8List? imageBytes,
    double aspectRatio = 2 / 3,
  }) async {
    final config = await AiConfigService.getConfig(forceRefresh: true);
    List<DetectedBox>? detectedBoxes;
    final engineUsed = '${config.model} (Vision AI)';

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

    // 2. Call AI Vision API directly without local fallback
    detectedBoxes = await _callVisionApi(
      bytes: bytes,
      config: config,
      aspectRatio: aspectRatio,
    );

    if (detectedBoxes == null || detectedBoxes.isEmpty) {
      throw Exception('هوش مصنوعی موفق به استخراج کادرها از این تصویر نشد.');
    }

    return AILayoutResult(
      imagePath: imagePath ?? '',
      aspectRatio: aspectRatio,
      title: 'قالب استخراج‌شده هوشمند',
      detectedBoxes: detectedBoxes,
      analysisEngine: engineUsed,
    );
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
تصویر این برگه را دقیق بررسی کن و تمام بخش‌ها، تیترها، کادرهای تاریخ، خطوط یادداشت، چک‌لیست‌ها و جدول‌ها را به صورت کادرهای استاندارد استخراج کن.

تمام مختصات باید نرمال‌شده (بین 0.0 تا 1.0) نسبت به کل عرض و ارتفاع تصویر باشند:
- normalizedX: موقعیت شروع از چپ (0.0 تا 1.0)
- normalizedY: موقعیت شروع از بالا (0.0 تا 1.0)
- normalizedWidth: عرض کادر (0.0 تا 1.0)
- normalizedHeight: ارتفاع کادر (0.0 تا 1.0)

نوع هر باکس (type) باید یکی از این مقادیر باشد:
"singleLine" (برای عنوان، تاریخ، وضعیت، تیتر),
"ruledLines" (برای خطوط یادداشت، جدول ساعات و نگارش),
"checklist" (برای چک‌لیست تسک‌ها، کارها و عادات),
"freeText" (برای یادداشت آزاد، تخلیه ذهن، باکس‌های متفرقه)

خروجی را صرفاً در قالب یک شیء JSON استاندارد بدون هیچ توضیح و متن اضافی بازگردانید:
{
  "title": "عنوان شناسایی شده برگه",
  "boxes": [
    {
      "id": "box_1",
      "label": "عنوان کادر به فارسی",
      "type": "singleLine",
      "normalizedX": 0.08,
      "normalizedY": 0.04,
      "normalizedWidth": 0.84,
      "normalizedHeight": 0.06,
      "estimatedLines": 1,
      "placeholderText": "تاریخ: .... / .... / ....",
      "fontSize": 13.0
    }
  ]
}
''';

    final url = Uri.parse('${config.baseUrl}/chat/completions');
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

        result.add(DetectedBox(
          id: b['id']?.toString() ?? 'box_ai_${DateTime.now().millisecondsSinceEpoch}_$i',
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
    final config = await AiConfigService.getConfig(forceRefresh: true);

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

      final response = await http.post(
        Uri.parse('${config.baseUrl}/chat/completions'),
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
            final updatedList = rawBoxes.map((item) => DetectedBox.fromJson(item as Map<String, dynamic>)).toList();
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
        id: 'box_chat_todo_${DateTime.now().millisecondsSinceEpoch}',
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
        id: 'box_chat_date_${DateTime.now().millisecondsSinceEpoch}',
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
        id: 'box_chat_gen_${DateTime.now().millisecondsSinceEpoch}',
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
