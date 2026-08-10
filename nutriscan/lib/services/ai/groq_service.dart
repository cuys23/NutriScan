import 'dart:convert';
import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import 'package:image/image.dart' as img;
import 'package:nutriscan/config/feature_flags.dart';
import 'package:nutriscan/models/chat_message.dart';
import 'package:nutriscan/models/meal_plan.dart';

class GroqService {
  static String get _model => FeatureFlags().aiModelScan;

  final HttpsCallable _groqCallable = FirebaseFunctions.instance
      .httpsCallable(
        'groqChatCompletion',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 90)),
      );

  /// Sends a Groq chat-completion request through the `groqChatCompletion`
  /// Cloud Function instead of calling api.groq.com directly — keeps the
  /// Groq API key server-side and lets the function enforce a real per-user
  /// daily rate limit (see functions/src/index.ts).
  ///
  /// Automatically retries once with a short backoff on transient 429
  /// (resource-exhausted) errors from the provider.
  Future<Map<String, dynamic>> _callGroq(
    Map<String, dynamic> requestBody,
  ) async {
    try {
      final result = await _groqCallable.call<Map<String, dynamic>>(
        requestBody,
      );
      return Map<String, dynamic>.from(result.data);
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'resource-exhausted') {
        // Transient provider rate-limit — wait briefly and retry once.
        debugPrint('Groq 429, retrying after 3s backoff...');
        await Future.delayed(const Duration(seconds: 3));
        final result = await _groqCallable.call<Map<String, dynamic>>(
          requestBody,
        );
        return Map<String, dynamic>.from(result.data);
      }
      rethrow;
    }
  }

  static String _mimeTypeFromFile(File file) {
    final path = file.path.toLowerCase();
    if (path.endsWith('.png')) return 'image/png';
    if (path.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  // Phase 2 (PLAN_AI_COST_PROMPT_OPT §2.1): resize max side to 1024px,
  // JPEG quality 75. Always encode to JPEG to guarantee a bounded payload
  // regardless of the source format (PNG screenshots can be 5-10MB raw).
  static const int _maxImageSide = 1024;
  static const int _jpegQuality = 75;

  static Future<String> _processAndEncodeImage(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final originalKB = bytes.length ~/ 1024;

      final decoded = img.decodeImage(bytes);
      if (decoded == null) {
        debugPrint('[img] decode failed, sending raw ${originalKB}KB');
        return base64Encode(bytes);
      }

      img.Image resized = decoded;
      if (decoded.width > _maxImageSide || decoded.height > _maxImageSide) {
        final isLandscape = decoded.width > decoded.height;
        resized = img.copyResize(
          decoded,
          width: isLandscape ? _maxImageSide : null,
          height: !isLandscape ? _maxImageSide : null,
        );
      }
      final compressed = img.encodeJpg(resized, quality: _jpegQuality);
      final compressedKB = compressed.length ~/ 1024;
      debugPrint('[img] ${decoded.width}x${decoded.height} ${originalKB}KB'
          ' → ${resized.width}x${resized.height} ${compressedKB}KB');
      return base64Encode(compressed);
    } catch (e) {
      debugPrint('Error in _processAndEncodeImage: $e');
      final rawBytes = await imageFile.readAsBytes();
      return base64Encode(rawBytes);
    }
  }

  static int? _findMatchingBraceEnd(String content, int start) {
    int depth = 0;
    bool inDouble = false;
    bool escape = false;
    for (int i = start; i < content.length; i++) {
      final c = content[i];
      if (escape) {
        escape = false;
        continue;
      }
      if (inDouble) {
        if (c == '\\') {
          escape = true;
        } else if (c == '"') {
          inDouble = false;
        }
        continue;
      }
      if (c == '"') {
        inDouble = true;
        continue;
      }
      if (c == '{') {
        depth++;
      } else if (c == '}') {
        depth--;
        if (depth == 0) return i + 1;
      }
    }
    return null;
  }

  static String _extractContentFromResponse(dynamic data) {
    if (data == null ||
        data['choices'] == null ||
        (data['choices'] as List).isEmpty) {
      return '';
    }
    final message = data['choices'][0]['message'];
    final rawContent = message?['content'];
    if (rawContent is String) return rawContent.trim();
    if (rawContent is List && rawContent.isNotEmpty) {
      final textPart = rawContent.firstWhere(
        (p) => p is Map && p['type'] == 'text',
        orElse: () => rawContent[0],
      );
      if (textPart is Map && textPart['text'] is String) {
        return (textPart['text'] as String).trim();
      }
      return rawContent.join('\n').toString().trim();
    }
    return '';
  }

  // -----------------------------------------------------------------------
  // Phase 1 (PLAN_AI_COST_PROMPT_OPT §1.1): isFoodImage is no longer called
  // as a separate vision request. The analysis prompt already returns
  // `is_food`, so food_provider checks that field after a single vision
  // call — cutting per-scan API calls from 2 to 1.
  //
  // The method is kept (not deleted) so callers outside the happy-path
  // scan flow can still use it if needed (e.g. a future A/B test), but
  // the main scan pipeline in food_provider.analyzeFoodImage bypasses it.
  // -----------------------------------------------------------------------

  Future<bool> isFoodImage(File imageFile, {String language = 'en'}) async {
    try {
      if (!await _checkNetworkConnectivity()) {
        throw Exception(getLocalizedErrorMessage('no_internet', language));
      }
      if (!await imageFile.exists()) return false;

      int fileSize = await imageFile.length();
      if (fileSize > 10 * 1024 * 1024) return false;

      final base64Image = await _processAndEncodeImage(imageFile);
      final mimeType = _mimeTypeFromFile(imageFile);
      final prompt = _getFoodValidationPrompt(language);

      final requestBody = {
        "model": _model,
        "messages": [
          {
            "role": "user",
            "content": [
              {"type": "text", "text": prompt},
              {
                "type": "image_url",
                "image_url": {"url": "data:$mimeType;base64,$base64Image"},
              },
            ],
          },
        ],
        "temperature": 0.1,
        "top_p": 1,
        "max_tokens": 256,
      };

      Map<String, dynamic> responseData;
      try {
        responseData = await _callGroq(requestBody);
      } catch (e) {
        debugPrint('groqChatCompletion error in isFoodImage: $e');
        return _fallbackAllow(imageFile);
      }

      String content = _extractContentFromResponse(responseData);
      if (content.isEmpty) return true;

      content = content
          .replaceAll(RegExp(r'^```(?:json)?\s*'), '')
          .replaceAll(RegExp(r'\s*```$'), '')
          .trim();

      int jsonStart = content.indexOf('{');
      int jsonEnd = content.lastIndexOf('}') + 1;
      if (jsonStart != -1 && jsonEnd > jsonStart) {
        try {
          String jsonString = content.substring(jsonStart, jsonEnd);
          Map<String, dynamic> result = json.decode(jsonString);
          if (result['is_food'] == true) return true;
          if (result['is_food'] == false) return false;
        } catch (e) {
          debugPrint('JSON parse error in food validation: $e');
        }
      }

      final lower = content.toLowerCase();
      if (lower.contains('"is_food":true') ||
          lower.contains('"is_food": true')) {
        return true;
      }
      if (lower.contains('"is_food":false') ||
          lower.contains('"is_food": false')) {
        return false;
      }

      final notFood =
          lower.contains('not a food') ||
          lower.contains('not food') ||
          lower.contains('no food') ||
          lower.contains('খাবারের ছবি নয়') ||
          lower.contains('not a food image');
      if (notFood) return false;

      if (lower.contains('is_food') && lower.contains('true')) return true;
      if (RegExp(r'\b(true|yes)\b').hasMatch(lower) &&
          (lower.contains('food') ||
              lower.contains('খাবার') ||
              lower.contains('dish') ||
              lower.contains('meal'))) {
        return true;
      }
      if (lower.contains('this is food') ||
          lower.contains('contains food') ||
          lower.contains('it is food') ||
          lower.contains('খাবারের ছবি') ||
          lower.contains('food image') ||
          lower.contains('image of food')) {
        return true;
      }

      return false;
    } catch (e) {
      debugPrint('Error in isFoodImage: $e');
      try {
        return await _fallbackFoodDetection(imageFile);
      } catch (inner) {
        debugPrint('Fallback food detection failed: $inner');
        return true;
      }
    }
  }

  Future<bool> _fallbackAllow(File imageFile) async {
    try {
      return await _fallbackFoodDetection(imageFile);
    } catch (e) {
      debugPrint('Fallback allow failed: $e');
      return true;
    }
  }

  Future<bool> _fallbackFoodDetection(File imageFile) async {
    try {
      String fileName = imageFile.path.toLowerCase();
      List<String> foodKeywords = [
        'food', 'meal', 'lunch', 'dinner', 'breakfast', 'snack',
        'খাবার', 'খাওয়া', 'রান্না', 'ভাত', 'রুটি', 'মাছ', 'মাংস',
      ];

      for (String keyword in foodKeywords) {
        if (fileName.contains(keyword)) return true;
      }

      int fileSize = await imageFile.length();
      if (fileSize < 1024 || fileSize > 5 * 1024 * 1024) return false;

      return true;
    } catch (e) {
      debugPrint('Error in fallbackFoodDetection: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>> analyzeFoodImage(
    File imageFile, {
    String language = 'en',
    bool multiFood = false,
  }) async {
    try {
      if (!await _checkNetworkConnectivity()) {
        throw Exception(getLocalizedErrorMessage('no_internet', language));
      }

      final base64Image = await _processAndEncodeImage(imageFile);
      final mimeType = _mimeTypeFromFile(imageFile);
      final prompt = multiFood
          ? _getLocalizedMultiPrompt(language)
          : _getLocalizedPrompt(language);

      final requestBody = {
        "model": _model,
        "messages": [
          {
            "role": "user",
            "content": [
              {"type": "text", "text": prompt},
              {
                "type": "image_url",
                "image_url": {"url": "data:$mimeType;base64,$base64Image"},
              },
            ],
          },
        ],
        // Phase 1 (§1.6): lower temperature for more deterministic JSON.
        "temperature": 0.2,
        "top_p": 1,
        // Multi-food (docs/plan.md Phase 7A) asks for up to 8 items.
        // Single-item max_tokens: 2048→1536 (compact schema saves ~25%).
        // NOTE: 1024 was tried first but truncated responses mid-JSON.
        "max_tokens": multiFood ? 4096 : 1536,
      };

      final responseData = await _callGroq(requestBody);
      var content = _extractContentFromResponse(responseData);
      if (content.isEmpty) {
        throw Exception(getLocalizedErrorMessage('parse_error', language));
      }

      // Strip markdown code fences and any conversational preamble/epilogue.
      content = content
          .replaceAll(RegExp(r'```(?:json)?\s*', multiLine: true), '')
          .trim();

      final jsonStart = content.indexOf('{');
      if (jsonStart == -1) {
        throw Exception(getLocalizedErrorMessage('parse_error', language));
      }
      final jsonEnd = _findMatchingBraceEnd(content, jsonStart);
      if (jsonEnd == null) {
        throw Exception(getLocalizedErrorMessage('parse_error', language));
      }
      final jsonString = content.substring(jsonStart, jsonEnd);
      final Map<String, dynamic> result =
          json.decode(jsonString) as Map<String, dynamic>;
      return result;
    } on FirebaseFunctionsException catch (e) {
      debugPrint('groqChatCompletion error in analyzeFoodImage: ${e.code} ${e.message}');
      String errorMessage;
      switch (e.code) {
        case 'deadline-exceeded':
          errorMessage = getLocalizedErrorMessage('response_timeout', language);
          break;
        case 'unavailable':
          errorMessage = getLocalizedErrorMessage('connection_failed', language);
          break;
        case 'invalid-argument':
          errorMessage = getLocalizedErrorMessage('invalid_request', language);
          break;
        case 'unauthenticated':
          errorMessage = getLocalizedErrorMessage('access_denied', language);
          break;
        case 'resource-exhausted':
          errorMessage = getLocalizedErrorMessage('rate_limit', language);
          break;
        default:
          errorMessage = getLocalizedErrorMessage('server_error', language, {
            'status': e.code,
          });
      }
      throw Exception(errorMessage);
    } catch (e) {
      debugPrint('General error in analyzeFoodImage: $e');
      rethrow;
    }
  }

  String getLocalizedErrorMessage(
    String errorKey,
    String language, [
    Map<String, String>? params,
  ]) {
    Map<String, Map<String, String>> errorMessages = {
      'en': {
        'no_internet': 'No internet connection. Please check your network and try again.',
        'parse_error': 'Could not parse JSON response from AI',
        'api_failed': 'API request failed with status: {status}',
        'network_error': 'Network error occurred',
        'connection_timeout': 'Connection timeout. Please check your internet speed and try again.',
        'response_timeout': 'Response timeout. The server is taking too long to respond.',
        'connection_failed': 'Connection failed. Please check your internet connection and try again.',
        'invalid_request': 'Invalid request. Please try with a different image.',
        'invalid_api_key': 'API key is invalid. Please check your configuration.',
        'access_denied': 'Access denied. Please check your API key permissions.',
        'rate_limit': 'Rate limit exceeded. Please wait a moment and try again.',
        'server_error': 'Server error ({status}). Please try again later.',
        'network_error_generic': 'Network error: {message}',
      },
      'bn': {
        'no_internet': 'ইন্টারনেট সংযোগ নেই। অনুগ্রহ করে আপনার নেটওয়ার্ক পরীক্ষা করুন এবং আবার চেষ্টা করুন।',
        'parse_error': 'AI থেকে JSON প্রতিক্রিয়া পার্স করতে পারেনি',
        'api_failed': 'API অনুরোধ ব্যর্থ হয়েছে স্ট্যাটাস: {status}',
        'network_error': 'নেটওয়ার্ক ত্রুটি ঘটেছে',
        'connection_timeout': 'সংযোগ টাইমআউট। অনুগ্রহ করে আপনার ইন্টারনেট গতি পরীক্ষা করুন এবং আবার চেষ্টা করুন।',
        'response_timeout': 'প্রতিক্রিয়া টাইমআউট। সার্ভার প্রতিক্রিয়া দিতে খুব বেশি সময় নিচ্ছে।',
        'connection_failed': 'সংযোগ ব্যর্থ হয়েছে। অনুগ্রহ করে আপনার ইন্টারনেট সংযোগ পরীক্ষা করুন এবং আবার চেষ্টা করুন।',
        'invalid_request': 'অবৈধ অনুরোধ। অনুগ্রহ করে একটি ভিন্ন ছবি দিয়ে চেষ্টা করুন।',
        'invalid_api_key': 'API কী অবৈধ। অনুগ্রহ করে আপনার কনফিগারেশন পরীক্ষা করুন।',
        'access_denied': 'অ্যাক্সেস অস্বীকৃত। অনুগ্রহ করে আপনার API কী অনুমতি পরীক্ষা করুন।',
        'rate_limit': 'হার সীমা অতিক্রম করেছে। অনুগ্রহ করে একটু অপেক্ষা করুন এবং আবার চেষ্টা করুন।',
        'server_error': 'সার্ভার ত্রুটি ({status})। অনুগ্রহ করে পরে আবার চেষ্টা করুন।',
        'network_error_generic': 'নেটওয়ার্ক ত্রুটি: {message}',
      },
    };

    final langMap = errorMessages[language] ?? errorMessages['en']!;
    String message = langMap[errorKey] ?? langMap['network_error']!;

    params?.forEach((key, value) {
      message = message.replaceAll('{$key}', value);
    });

    return message;
  }

  String _getFoodValidationPrompt(String language) {
    switch (language) {
      case 'bn':
        return """ছবিতে খাবার আছে কিনা যাচাই করুন। উত্তর শুধুমাত্র এই JSON ফরম্যাটে দিন:
{"is_food": true/false, "confidence": 0.95}

নিয়ম:
- ছবিতে যেকোনো খাবার থাকলে is_food: true দিন (ভাত, রুটি, মাছ, মাংস, সবজি, ফল, পানীয়, স্ন্যাকস, প্যাকেট/ক্যান/বোতলের খাবার, প্লেটে খাবার, টেবিলে খাবার, মানুষ সহ খাবারের ছবি)
- শুধুমাত্র যখন ছবিতে কোনো খাবার নেই (শুধু মানুষ, প্রাণী, গাড়ি, দৃশ্য, বস্তু) তখনই is_food: false দিন
- সন্দেহ থাকলে true দিন। শুধুমাত্র JSON লিখুন।""";
      default:
        return """Decide if this image contains any food. Reply with ONLY this JSON (no other text):
{"is_food": true/false, "confidence": 0.95}

Rules:
- Set is_food to true if the image shows ANY food: meals, dishes, drinks, snacks, fruits, vegetables, packaged food, food on plate/table, or person with food.
- Set is_food to false ONLY when there is clearly NO food (e.g. only person, animal, car, landscape, object with no food).
- When unsure, use true. Output only the JSON object.""";
    }
  }

  // Phase 1 (§1.2): compact schema — dropped health_benefits,
  // health_warnings (UI never rendered them). Kept health_score because
  // food_detail_card, health_score_chart, and analysis_screen depend on it.
  static const String _foodAnalysisJsonSchema = '''
{
  "is_food": true,
  "food_name": "",
  "portion_grams": 0,
  "calories": 0,
  "protein": 0,
  "carbs": 0,
  "fat": 0,
  "fiber": 0,
  "sugar": 0,
  "sodium": 0,
  "health_score": 0,
  "serving_size": "",
  "description": ""
}''';

  // docs/plan.md Phase 7A — leaner than the single-item schema above on
  // purpose: health_benefits/health_warnings are dropped and description is
  // one short phrase instead of 1-3 sentences. Multiplied by up to 8 items,
  // the full single-item schema was blowing the multi-food max_tokens budget
  // (a real truncated-JSON failure hit during testing) and burning this
  // Groq account's 8000 TPM ceiling — and the review sheet
  // (multi_food_review_sheet.dart) only ever displays name/calories/portion/
  // source, so those fields were paid for and never shown. Food.fromJson
  // defaults both to [] when absent, so this is safe; a later detail-view
  // improvement could re-fetch them per selected item if ever needed.
  static const String _foodAnalysisMultiJsonSchema = '''
{
  "is_food": true,
  "items": [
    {
      "food_name": "string",
      "description": "string",
      "calories": 0,
      "protein": 0,
      "carbs": 0,
      "fat": 0,
      "fiber": 0,
      "sugar": 0,
      "sodium": 0,
      "health_score": 0,
      "serving_size": "string",
      "portion_grams": 0
    }
  ]
}''';

  // Phase 1 (§1.3): leaner meal plan schema — kept hydration_reminders,
  // lifestyle_tips, grocery_list, ingredients, instructions because the UI
  // (meal_plan_generator.dart) renders them. Made descriptions short.
  static const String _mealPlanJsonSchema = '''
{
  "plan_title": "",
  "goal_summary": "",
  "target_calories": 2000,
  "nutrition_overview": {
    "total_calories": 2000,
    "protein": 100,
    "carbs": 250,
    "fat": 65,
    "fiber": 30,
    "sugar": 50
  },
  "meals": [
    {
      "type": "breakfast",
      "title": "",
      "description": "",
      "calories": 500,
      "protein": 25,
      "carbs": 60,
      "fat": 15,
      "ingredients": ["item"],
      "instructions": ["step"]
    }
  ],
  "hydration_reminders": ["tip"],
  "lifestyle_tips": ["tip"],
  "grocery_list": ["item"]
}''';

  static String _languageNameForModel(String code) {
    switch (code) {
      case 'bn': return 'Bangla';
      case 'hi': return 'Hindi';
      case 'es': return 'Spanish';
      case 'fr': return 'French';
      case 'de': return 'German';
      case 'zh': return 'Chinese';
      case 'tr': return 'Turkish';
      case 'ko': return 'Korean';
      case 'id': return 'Indonesian';
      case 'ja': return 'Japanese';
      case 'ru': return 'Russian';
      case 'ur': return 'Urdu';
      case 'pt': case 'pt-BR': return 'Portuguese';
      case 'ar': return 'Arabic';
      default: return 'English';
    }
  }

  // Phase 1 (§1.2): compact prompt from PLAN_AI_COST_PROMPT_OPT.md.
  // health_score kept because UI depends on it; health_benefits/warnings
  // dropped (never rendered).
  String _getLocalizedPrompt(String language) {
    final langName = _languageNameForModel(language);
    return '''Role: Food image → JSON only. Language for ALL text fields: $langName.

Return ONE JSON object, no markdown:
$_foodAnalysisJsonSchema

Rules:
- is_food=false only if no edible item. Unsure → true.
- portion_grams > 0 when is_food=true; estimate visible edible portion.
- health_score: integer 1–10 based on nutrition.
- description ≤ 2 short sentences in $langName; food_name in $langName.
- No medical claims. No extra keys.''';
  }

  // Phase 1 (§1.2): compact multi-food prompt — same terse style.
  String _getLocalizedMultiPrompt(String language) {
    final langName = _languageNameForModel(language);
    return '''Role: Food image → JSON only. Language: $langName. Image may show multiple foods.

Return ONE JSON object, no markdown:
$_foodAnalysisMultiJsonSchema

Rules:
- List every distinct food up to 8 items. Merge duplicates.
- is_food=false + empty items only if clearly no food.
- Composite dishes (burger, sandwich): break into component items.
- Each item: portion_grams > 0, health_score 1–10, description ≤ 6 words in $langName.
- Keep every field terse. No extra keys. No markdown.''';
  }

  Future<MealPlan> generateMealPlan({
    required int targetCalories,
    required String dietStyle,
    required int mealsPerDay,
    List<String> restrictions = const [],
    String language = 'en',
    String? userNutritionContext,
  }) async {
    try {
      if (!await _checkNetworkConnectivity()) {
        throw Exception(getLocalizedErrorMessage('no_internet', language));
      }

      final prompt = _getMealPlanPrompt(
        language: language,
        targetCalories: targetCalories,
        dietStyle: dietStyle,
        mealsPerDay: mealsPerDay,
        restrictions: restrictions,
        userNutritionContext: userNutritionContext,
      );

      final messages = [
        {"role": "user", "content": prompt},
      ];

      String content = await _requestMealPlanContent(messages, language);
      try {
        return _parseMealPlan(content, language);
      } catch (e) {
        // One repair retry: show the model its own invalid output and ask
        // it to fix it, instead of failing generation on a single bad reply.
        debugPrint('Meal plan parse failed, retrying with repair prompt: $e');
        messages.add({"role": "assistant", "content": content});
        messages.add({
          "role": "user",
          "content":
              "That response was not valid JSON matching the schema. "
              "Return ONLY the corrected JSON object, no markdown, no explanation.",
        });
        content = await _requestMealPlanContent(messages, language);
        return _parseMealPlan(content, language);
      }
    } on FirebaseFunctionsException catch (e) {
      debugPrint('groqChatCompletion error in generateMealPlan: ${e.code} ${e.message}');
      String errorMessage;
      switch (e.code) {
        case 'deadline-exceeded':
          errorMessage = getLocalizedErrorMessage('response_timeout', language);
          break;
        case 'unavailable':
          errorMessage = getLocalizedErrorMessage('connection_failed', language);
          break;
        case 'resource-exhausted':
          errorMessage = getLocalizedErrorMessage('rate_limit', language);
          break;
        default:
          errorMessage = getLocalizedErrorMessage('server_error', language, {
            'status': e.code,
          });
      }
      throw Exception(errorMessage);
    } catch (e) {
      debugPrint('Error in generateMealPlan: $e');
      rethrow;
    }
  }

  Future<String> _requestMealPlanContent(
    List<Map<String, String>> messages,
    String language,
  ) async {
    // Phase 1 (§1.3): reduced max_tokens from 8192→4096 — the leaner schema
    // and shorter descriptions fit well within this budget.
    final requestBody = {
      "model": _model,
      "messages": messages,
      "temperature": 0.45,
      "top_p": 0.95,
      "max_tokens": 4096,
      "receiveTimeoutMs": 90000,
    };

    final responseData = await _callGroq(requestBody);
    final content = _extractContentFromResponse(responseData);
    if (content.isEmpty) throw Exception(getLocalizedErrorMessage('parse_error', language));
    return content;
  }

  MealPlan _parseMealPlan(String rawContent, String language) {
    final content = rawContent
        .replaceAll(RegExp(r'^```(?:json)?\s*', multiLine: true), '')
        .replaceAll(RegExp(r'\s*```\s*$', multiLine: true), '')
        .trim();
    final jsonStart = content.indexOf('{');
    if (jsonStart == -1) throw Exception(getLocalizedErrorMessage('parse_error', language));
    final jsonEnd = _findMatchingBraceEnd(content, jsonStart);
    if (jsonEnd == null) throw Exception(getLocalizedErrorMessage('parse_error', language));
    final jsonString = content.substring(jsonStart, jsonEnd);
    final Map<String, dynamic> result = json.decode(jsonString) as Map<String, dynamic>;
    return MealPlan.fromMap(result);
  }

  Future<List<Map<String, dynamic>>> fetchInsights(
    List<Map<String, dynamic>> foodData, {
    String language = 'en',
  }) async {
    try {
      if (!await _checkNetworkConnectivity()) throw Exception(getLocalizedErrorMessage('no_internet', language));

      final requestBody = {
        "model": _model,
        "messages": [
          {"role": "user", "content": _getInsightsPrompt(language, foodData)},
        ],
        "temperature": 0.3, "top_p": 1, "max_tokens": 2048,
      };

      final responseData = await _callGroq(requestBody);
      // Strip markdown code fences and any conversational preamble.
      var content = _extractContentFromResponse(responseData);
      content = content
          .replaceAll(RegExp(r'```(?:json)?\s*', multiLine: true), '')
          .trim();

      // Find the actual JSON array start: look for '[' immediately followed
      // by '{' (with optional whitespace) to skip stray brackets in preamble.
      final jsonArrayMatch = RegExp(r'\[\s*\{').firstMatch(content);
      if (jsonArrayMatch == null) throw Exception('No JSON array in insights response');
      final jsonStart = jsonArrayMatch.start;
      final jsonEnd = _findMatchingBracketEnd(content, jsonStart);
      if (jsonEnd == null) throw Exception('Unbalanced brackets in insights response');

      return (json.decode(content.substring(jsonStart, jsonEnd)) as List).cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('Error in fetchInsights: $e');
      rethrow;
    }
  }

  /// Finds the index *past* the closing `]` that matches the `[` at [start].
  static int? _findMatchingBracketEnd(String s, int start) {
    if (start < 0 || start >= s.length || s[start] != '[') return null;
    int depth = 0;
    bool inString = false;
    for (int i = start; i < s.length; i++) {
      final c = s[i];
      if (inString) {
        if (c == '\\') { i++; continue; }
        if (c == '"') inString = false;
        continue;
      }
      if (c == '"') { inString = true; continue; }
      if (c == '[') depth++;
      if (c == ']') { depth--; if (depth == 0) return i + 1; }
    }
    return null;
  }

  // Phase 1 (§1.3): shorter meal plan prompt — same constraints, fewer words.
  String _getMealPlanPrompt({
    required String language,
    required int targetCalories,
    required String dietStyle,
    required int mealsPerDay,
    required List<String> restrictions,
    String? userNutritionContext,
  }) {
    final langName = _languageNameForModel(language);
    return '''$mealsPerDay-meal plan, $targetCalories kcal/day, $dietStyle diet. Language: $langName.
Restrictions: ${restrictions.isEmpty ? 'None' : restrictions.join(', ')}
${userNutritionContext != null ? 'Context: $userNutritionContext' : ''}
Return ONLY JSON, all text in $langName. Keep descriptions ≤ 1 sentence, instructions ≤ 3 steps each.
Schema:
$_mealPlanJsonSchema''';
  }

  // Phase 1 (§1.5): send aggregate summary instead of raw food log to
  // reduce input tokens. The previous version sent every food item's full
  // data; now we compute totals/averages and send a compact summary.
  String _getInsightsPrompt(String language, List<Map<String, dynamic>> foodData) {
    // Build aggregate summary instead of sending raw data.
    final count = foodData.length;
    double totalCal = 0, totalProtein = 0, totalCarbs = 0, totalFat = 0;
    final names = <String>[];
    for (final f in foodData) {
      totalCal += (f['calories'] as num?)?.toDouble() ?? 0;
      totalProtein += (f['protein'] as num?)?.toDouble() ?? 0;
      totalCarbs += (f['carbs'] as num?)?.toDouble() ?? 0;
      totalFat += (f['fat'] as num?)?.toDouble() ?? 0;
      final name = f['name']?.toString();
      if (name != null && name.isNotEmpty && names.length < 15) {
        names.add(name);
      }
    }
    final summary = '{"items":$count,'
        '"total_cal":${totalCal.round()},'
        '"avg_cal":${count > 0 ? (totalCal / count).round() : 0},'
        '"total_protein":${totalProtein.round()},'
        '"total_carbs":${totalCarbs.round()},'
        '"total_fat":${totalFat.round()},'
        '"foods":[${names.map((n) => '"$n"').join(',')}]}';

    return "3-5 actionable nutrition insights in ${_languageNameForModel(language)}. "
        "JSON array only: [{\"title\":\"...\",\"description\":\"...\"}]. "
        "No markdown.\nSummary: $summary";
  }

  Future<bool> _checkNetworkConnectivity() async {
    try {
      final result = await InternetAddress.lookup('google.com').timeout(const Duration(seconds: 5));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (e) {
      debugPrint('Connectivity check failed: $e');
      return false; 
    }
  }

  static void showNonFoodImageDialog(BuildContext context, {String language = 'en'}) {
    // Show dialog implementation...
  }

  // Phase 1 (§1.4): limit chat history to the most recent 8 messages to
  // cap input tokens. Older context is dropped — the system prompt already
  // carries the user's nutrition profile so the coach stays relevant.
  static const int _maxCoachHistoryMessages = 8;

  Future<String> getHealthCoachResponse({
    required List<ChatMessage> history,
    required String userContext,
    String language = 'en',
  }) async {
    try {
      final messages = [{"role": "system", "content": _getHealthCoachSystemPrompt(language, userContext)}];
      // Only send the N most recent messages to keep input tokens bounded.
      final trimmed = history.length > _maxCoachHistoryMessages
          ? history.sublist(history.length - _maxCoachHistoryMessages)
          : history;
      messages.addAll(trimmed.map((m) => {"role": m.role == MessageRole.user ? "user" : "assistant", "content": m.content}));
      final responseData = await _callGroq({"model": _model, "messages": messages});
      return _extractContentFromResponse(responseData);
    } catch (e) {
      debugPrint('Error in getHealthCoachResponse: $e');
      rethrow;
    }
  }

  // Phase 1 (§1.4): shorter system prompt — same rules, fewer tokens.
  String _getHealthCoachSystemPrompt(String language, String userContext) {
    return "Nutrition coach in ${_languageNameForModel(language)}. "
        "$userContext "
        "Give nutrition advice only. Never diagnose or treat. "
        "Reply ≤ 150 words. Recommend a doctor for medical questions.";
  }
}
