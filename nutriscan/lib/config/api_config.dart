class ApiConfig {
  static const String _groqApiKey = String.fromEnvironment('GROQ_API_KEY');

  static String get groqApiKey => 
      _groqApiKey.isEmpty ? 'YOUR_GROQ_API_KEY_HERE' : _groqApiKey;

  static const String groqModel = 'qwen/qwen3.6-27b';

  static String get groqBaseUrl =>
      'https://api.groq.com/openai/v1/chat/completions';
}
