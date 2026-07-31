class ApiConfig {
  // The Groq API key and base URL used to live here and ship inside the
  // client binary — moved server-side into the `groqChatCompletion` Cloud
  // Function (functions/src/index.ts) so the real key is never in the app.
  static const String groqModel = 'qwen/qwen3.6-27b';
}
