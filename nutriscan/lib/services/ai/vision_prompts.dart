import 'package:nutriscan/services/ai/ai_response_utils.dart';

/// Vision-only prompts and JSON schemas — split out of `GroqService`
/// (docs/17_SPLIT_VISION_AI.md §2.2). Meal plan / insights / coach prompts
/// stay in `groq_service.dart`.
class VisionPrompts {
  VisionPrompts._();

  static String foodValidationPrompt(String language) {
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
  static const String foodAnalysisJsonSchema = '''
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
  static const String foodAnalysisMultiJsonSchema = '''
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

  // Phase 1 (§1.2): compact prompt from PLAN_AI_COST_PROMPT_OPT.md.
  // health_score kept because UI depends on it; health_benefits/warnings
  // dropped (never rendered).
  static String analysisPrompt(String language) {
    final langName = AiResponseUtils.languageNameForModel(language);
    return '''Role: Food image → JSON only. Language for ALL text fields: $langName.

Return ONE JSON object, no markdown:
$foodAnalysisJsonSchema

Rules:
- is_food=false only if no edible item. Unsure → true.
- portion_grams > 0 when is_food=true; estimate visible edible portion.
- health_score: integer 1–10 based on nutrition.
- description ≤ 2 short sentences in $langName; food_name in $langName.
- No medical claims. No extra keys.''';
  }

  // Phase 1 (§1.2): compact multi-food prompt — same terse style.
  static String multiAnalysisPrompt(String language) {
    final langName = AiResponseUtils.languageNameForModel(language);
    return '''Role: Food image → JSON only. Language: $langName. Image may show multiple foods.

Return ONE JSON object, no markdown:
$foodAnalysisMultiJsonSchema

Rules:
- List every distinct food up to 8 items. Merge duplicates.
- is_food=false + empty items only if clearly no food.
- Composite dishes (burger, sandwich): break into component items.
- Each item: portion_grams > 0, health_score 1–10, description ≤ 6 words in $langName.
- Keep every field terse. No extra keys. No markdown.''';
  }
}
