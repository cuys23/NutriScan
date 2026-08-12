import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Pure image resize/encode for the vision path — no network, no Firebase.
/// Split out of `GroqService` so it's independently testable and so
/// `VisionAiService` doesn't need the rest of the text-model plumbing
/// (docs/17_SPLIT_VISION_AI.md §2.1).
class ImagePrepare {
  ImagePrepare._();

  static String mimeTypeFromFile(File file) {
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

  static Future<String> processAndEncodeImage(File imageFile) async {
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
}
