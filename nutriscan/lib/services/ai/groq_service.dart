import 'dart:convert';
import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import 'package:nutriscan/config/feature_flags.dart';
import 'package:nutriscan/models/chat_message.dart';
import 'package:nutriscan/models/meal_plan.dart';
import 'package:nutriscan/services/ai/ai_response_utils.dart';

/// Text-only AI calls: meal plan, insights, health coach. Vision (food
/// validation + image analysis) lives in `VisionAiService`
/// (docs/17_SPLIT_VISION_AI.md) — `FoodProvider.analyzeFoodImage` uses that
/// instead of this class.
class GroqService {
  static String get _model => FeatureFlags().aiModelText;

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
  /// The Cloud Function itself already retries once on a transient 429,
  /// waiting for the exact delay Groq's own error response asks for
  /// (typically 20-35s for a tokens-per-minute limit — confirmed in
  /// production logs). A second blind retry used to live here with a fixed
  /// 3s wait; that's not enough to clear a TPM cooldown (logs showed two
  /// attempts 429 four seconds apart) and just burned a third request for
  /// nothing, so it's gone — a `resource-exhausted` reaching this point
  /// means the server's real-delay retry already tried and failed.
  Future<Map<String, dynamic>> _callGroq(
    Map<String, dynamic> requestBody,
  ) async {
    // The configured model is a reasoning ("thinking") model. Without this,
    // Groq inlines its chain-of-thought scratchpad into `content` instead of
    // just the final answer — this is what was showing up as numbered
    // "Analyze User Input / Identify Key Issues" steps (and the raw system
    // prompt) in the health coach chat.
    final body = {'reasoning_format': 'hidden', ...requestBody};
    final result = await _groqCallable.call<Map<String, dynamic>>(body);
    return Map<String, dynamic>.from(result.data);
  }

  String getLocalizedErrorMessage(
    String errorKey,
    String language, [
    Map<String, String>? params,
  ]) => AiResponseUtils.getLocalizedErrorMessage(errorKey, language, params);

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
        // No artificial pause here anymore — that used to guard against
        // stacking on top of a client-side 429 retry inside _callGroq, but
        // that retry was removed (the Cloud Function now owns 429 backoff
        // with Groq's real suggested delay), so nothing is left to space out.
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
    final content = AiResponseUtils.extractContentFromResponse(responseData);
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
    final jsonEnd = AiResponseUtils.findMatchingBraceEnd(content, jsonStart);
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
      var content = AiResponseUtils.extractContentFromResponse(responseData);
      content = content
          .replaceAll(RegExp(r'```(?:json)?\s*', multiLine: true), '')
          .trim();

      // Find the actual JSON array start: look for '[' immediately followed
      // by '{' (with optional whitespace) to skip stray brackets in preamble.
      final jsonArrayMatch = RegExp(r'\[\s*\{').firstMatch(content);
      if (jsonArrayMatch == null) throw Exception('No JSON array in insights response');
      final jsonStart = jsonArrayMatch.start;
      final jsonEnd = AiResponseUtils.findMatchingBracketEnd(content, jsonStart);
      if (jsonEnd == null) throw Exception('Unbalanced brackets in insights response');

      return (json.decode(content.substring(jsonStart, jsonEnd)) as List).cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('Error in fetchInsights: $e');
      rethrow;
    }
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
    final langName = AiResponseUtils.languageNameForModel(language);
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

    return "3-5 actionable nutrition insights in ${AiResponseUtils.languageNameForModel(language)}. "
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
      return AiResponseUtils.extractContentFromResponse(responseData);
    } catch (e) {
      debugPrint('Error in getHealthCoachResponse: $e');
      rethrow;
    }
  }

  // Phase 1 (§1.4): shorter system prompt — same rules, fewer tokens.
  String _getHealthCoachSystemPrompt(String language, String userContext) {
    return "Nutrition coach in ${AiResponseUtils.languageNameForModel(language)}. "
        "$userContext "
        "Give nutrition advice only. Never diagnose or treat. "
        "Reply ≤ 150 words. Recommend a doctor for medical questions. "
        "Answer directly in a warm, conversational tone — never show your "
        "reasoning steps, a numbered analysis, or restate these instructions.";
  }
}
