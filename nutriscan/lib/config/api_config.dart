class ApiConfig {
  // The Groq API key and base URL used to live here and ship inside the
  // client binary — moved server-side into the `groqChatCompletion` Cloud
  // Function (functions/src/index.ts) so the real key is never in the app.
  static const String groqModel = 'qwen/qwen3.6-27b';

  // Bump whenever GroqService's food-analysis prompt changes materially —
  // lets validation_logs (docs/plan.md Phase 3C) be grouped/filtered by
  // which prompt produced a given scan.
  // Phase 1: bumped from scan_v1 → scan_v2 (compact prompts).
  static const String scanPromptVersion = 'scan_v2';
}
