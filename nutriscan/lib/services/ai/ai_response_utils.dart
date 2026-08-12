/// Response-parsing and error-message helpers shared by [GroqService]
/// (text: meal plan, insights, health coach) and `VisionAiService` (vision:
/// scan, food validation). Both currently transport through the same Groq
/// callable and can hit the same reasoning-model quirks, so this stays one
/// file instead of being duplicated (docs/17_SPLIT_VISION_AI.md).
library;

import 'package:flutter/foundation.dart';

class AiResponseUtils {
  AiResponseUtils._();

  static String extractContentFromResponse(dynamic data) {
    if (data == null ||
        data['choices'] == null ||
        (data['choices'] as List).isEmpty) {
      return '';
    }
    final message = data['choices'][0]['message'];
    final rawContent = message?['content'];
    if (rawContent is String) return stripReasoning(rawContent);
    if (rawContent is List && rawContent.isNotEmpty) {
      final textPart = rawContent.firstWhere(
        (p) => p is Map && p['type'] == 'text',
        orElse: () => rawContent[0],
      );
      if (textPart is Map && textPart['text'] is String) {
        return stripReasoning(textPart['text'] as String);
      }
      return stripReasoning(rawContent.join('\n').toString());
    }
    return '';
  }

  /// Defense-in-depth for the `reasoning_format: hidden` request param sent
  /// by both services' call wrappers: some reasoning models still wrap a
  /// leaked chain-of-thought scratchpad in `<think>...</think>` regardless.
  /// Strip it so callers only ever see the final answer.
  @visibleForTesting
  static String stripReasoning(String content) {
    return content
        .replaceAll(
          RegExp(r'<think>[\s\S]*?</think>', caseSensitive: false),
          '',
        )
        .trim();
  }

  /// Finds the index *past* the closing `}` that matches the `{` at [start].
  static int? findMatchingBraceEnd(String content, int start) {
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

  /// Finds the index *past* the closing `]` that matches the `[` at [start].
  static int? findMatchingBracketEnd(String s, int start) {
    if (start < 0 || start >= s.length || s[start] != '[') return null;
    int depth = 0;
    bool inString = false;
    for (int i = start; i < s.length; i++) {
      final c = s[i];
      if (inString) {
        if (c == '\\') {
          i++;
          continue;
        }
        if (c == '"') inString = false;
        continue;
      }
      if (c == '"') {
        inString = true;
        continue;
      }
      if (c == '[') depth++;
      if (c == ']') {
        depth--;
        if (depth == 0) return i + 1;
      }
    }
    return null;
  }

  static String languageNameForModel(String code) {
    switch (code) {
      case 'bn':
        return 'Bangla';
      case 'hi':
        return 'Hindi';
      case 'es':
        return 'Spanish';
      case 'fr':
        return 'French';
      case 'de':
        return 'German';
      case 'zh':
        return 'Chinese';
      case 'tr':
        return 'Turkish';
      case 'ko':
        return 'Korean';
      case 'id':
        return 'Indonesian';
      case 'ja':
        return 'Japanese';
      case 'ru':
        return 'Russian';
      case 'ur':
        return 'Urdu';
      case 'pt':
      case 'pt-BR':
        return 'Portuguese';
      case 'ar':
        return 'Arabic';
      default:
        return 'English';
    }
  }

  static String getLocalizedErrorMessage(
    String errorKey,
    String language, [
    Map<String, String>? params,
  ]) {
    Map<String, Map<String, String>> errorMessages = {
      'en': {
        'no_internet':
            'No internet connection. Please check your network and try again.',
        'parse_error': 'Could not parse JSON response from AI',
        'api_failed': 'API request failed with status: {status}',
        'network_error': 'Network error occurred',
        'connection_timeout':
            'Connection timeout. Please check your internet speed and try again.',
        'response_timeout':
            'Response timeout. The server is taking too long to respond.',
        'connection_failed':
            'Connection failed. Please check your internet connection and try again.',
        'invalid_request': 'Invalid request. Please try with a different image.',
        'invalid_api_key': 'API key is invalid. Please check your configuration.',
        'access_denied': 'Access denied. Please check your API key permissions.',
        'rate_limit': 'Rate limit exceeded. Please wait a moment and try again.',
        'server_error': 'Server error ({status}). Please try again later.',
        'network_error_generic': 'Network error: {message}',
      },
      'bn': {
        'no_internet':
            'ইন্টারনেট সংযোগ নেই। অনুগ্রহ করে আপনার নেটওয়ার্ক পরীক্ষা করুন এবং আবার চেষ্টা করুন।',
        'parse_error': 'AI থেকে JSON প্রতিক্রিয়া পার্স করতে পারেনি',
        'api_failed': 'API অনুরোধ ব্যর্থ হয়েছে স্ট্যাটাস: {status}',
        'network_error': 'নেটওয়ার্ক ত্রুটি ঘটেছে',
        'connection_timeout':
            'সংযোগ টাইমআউট। অনুগ্রহ করে আপনার ইন্টারনেট গতি পরীক্ষা করুন এবং আবার চেষ্টা করুন।',
        'response_timeout':
            'প্রতিক্রিয়া টাইমআউট। সার্ভার প্রতিক্রিয়া দিতে খুব বেশি সময় নিচ্ছে।',
        'connection_failed':
            'সংযোগ ব্যর্থ হয়েছে। অনুগ্রহ করে আপনার ইন্টারনেট সংযোগ পরীক্ষা করুন এবং আবার চেষ্টা করুন।',
        'invalid_request': 'অবৈধ অনুরোধ। অনুগ্রহ করে একটি ভিন্ন ছবি দিয়ে চেষ্টা করুন।',
        'invalid_api_key': 'API কী অবৈধ। অনুগ্রহ করে আপনার কনফিগারেশন পরীক্ষা করুন।',
        'access_denied':
            'অ্যাক্সেস অস্বীকৃত। অনুগ্রহ করে আপনার API কী অনুমতি পরীক্ষা করুন।',
        'rate_limit':
            'হার সীমা অতিক্রম করেছে। অনুগ্রহ করে একটু অপেক্ষা করুন এবং আবার চেষ্টা করুন।',
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
}
