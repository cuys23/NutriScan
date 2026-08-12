import 'dart:convert';
import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:nutriscan/config/feature_flags.dart';
import 'package:nutriscan/services/ai/ai_response_utils.dart';
import 'package:nutriscan/services/ai/image_prepare.dart';
import 'package:nutriscan/services/ai/vision_prompts.dart';

/// Vision-only AI calls (food validation + image analysis) — split out of
/// `GroqService` so image prep and vision transport can evolve (a different
/// model, or a dedicated `visionCompletion` callable / provider) without
/// touching meal plan / insights / health coach (docs/17_SPLIT_VISION_AI.md).
///
/// `FoodProvider.analyzeFoodImage` is still the only scan entry point on the
/// provider — this is what it calls internally for the vision leg.
class VisionAiService {
  static String get _model => FeatureFlags().aiModelVision;

  final HttpsCallable _visionCallable = FirebaseFunctions.instance
      .httpsCallable(
        // Phase A (docs/17_SPLIT_VISION_AI.md §3): still the shared
        // groqChatCompletion callable. A dedicated `visionCompletion`
        // callable is Phase B/Step 6, not part of this split.
        'groqChatCompletion',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 90)),
      );

  /// Same call wrapper as `GroqService._callGroq`, kept as its own copy
  /// (not shared) so the vision transport can diverge — e.g. move to a
  /// `visionCompletion` callable or a different provider — without touching
  /// the text path.
  Future<Map<String, dynamic>> _callVision(
    Map<String, dynamic> requestBody,
  ) async {
    final body = {'reasoning_format': 'hidden', ...requestBody};
    final result = await _visionCallable.call<Map<String, dynamic>>(body);
    return Map<String, dynamic>.from(result.data);
  }

  String getLocalizedErrorMessage(
    String errorKey,
    String language, [
    Map<String, String>? params,
  ]) => AiResponseUtils.getLocalizedErrorMessage(errorKey, language, params);

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

      final base64Image = await ImagePrepare.processAndEncodeImage(imageFile);
      final mimeType = ImagePrepare.mimeTypeFromFile(imageFile);
      final prompt = VisionPrompts.foodValidationPrompt(language);

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
        responseData = await _callVision(requestBody);
      } catch (e) {
        debugPrint('groqChatCompletion error in isFoodImage: $e');
        return _fallbackAllow(imageFile);
      }

      String content = AiResponseUtils.extractContentFromResponse(
        responseData,
      );
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

      final base64Image = await ImagePrepare.processAndEncodeImage(imageFile);
      final mimeType = ImagePrepare.mimeTypeFromFile(imageFile);
      final prompt = multiFood
          ? VisionPrompts.multiAnalysisPrompt(language)
          : VisionPrompts.analysisPrompt(language);

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

      final responseData = await _callVision(requestBody);
      var content = AiResponseUtils.extractContentFromResponse(responseData);
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
      final jsonEnd = AiResponseUtils.findMatchingBraceEnd(content, jsonStart);
      if (jsonEnd == null) {
        throw Exception(getLocalizedErrorMessage('parse_error', language));
      }
      final jsonString = content.substring(jsonStart, jsonEnd);
      final Map<String, dynamic> result =
          json.decode(jsonString) as Map<String, dynamic>;
      return result;
    } on FirebaseFunctionsException catch (e) {
      debugPrint(
        'groqChatCompletion error in analyzeFoodImage: ${e.code} ${e.message}',
      );
      String errorMessage;
      switch (e.code) {
        case 'deadline-exceeded':
          errorMessage = getLocalizedErrorMessage(
            'response_timeout',
            language,
          );
          break;
        case 'unavailable':
          errorMessage = getLocalizedErrorMessage(
            'connection_failed',
            language,
          );
          break;
        case 'invalid-argument':
          errorMessage = getLocalizedErrorMessage(
            'invalid_request',
            language,
          );
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

  Future<bool> _checkNetworkConnectivity() async {
    try {
      final result = await InternetAddress.lookup(
        'google.com',
      ).timeout(const Duration(seconds: 5));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (e) {
      debugPrint('Connectivity check failed: $e');
      return false;
    }
  }
}
