import 'dart:io';
import 'package:flutter/material.dart';
import 'package:iconly/iconly.dart';

/// Image helper utility for managing local and Firebase images
class ImageHelper {
  /// Determines if an image path is a Firebase Storage URL
  static bool isFirebaseUrl(String imagePath) {
    return imagePath.startsWith('http') &&
        (imagePath.contains('firebasestorage.googleapis.com') ||
            imagePath.contains('googleapis.com'));
  }

  /// Determines if an image path is any HTTP/HTTPS URL
  static bool isNetworkUrl(String imagePath) {
    return imagePath.startsWith('http://') || imagePath.startsWith('https://');
  }

  /// Determines if an image path is a local file path
  static bool isLocalPath(String imagePath) {
    return !isNetworkUrl(imagePath) && imagePath.isNotEmpty;
  }

  /// Creates appropriate ImageProvider based on image path type
  static ImageProvider? getImageProvider(String imagePath) {
    if (isNetworkUrl(imagePath)) {
      return NetworkImage(imagePath);
    } else if (isLocalPath(imagePath)) {
      return FileImage(File(imagePath));
    } else {
      // Return null for invalid paths - will be handled by error widget
      return null;
    }
  }

  /// Renders [imagePath] as an [Image], falling back to [getPlaceholderWidget]
  /// on any load failure (missing/deleted file, corrupt data, network error)
  /// instead of rendering nothing. Uses `Image`'s own `errorBuilder`, unlike
  /// `DecorationImage.onError` which has no way to swap in fallback content —
  /// a failure there just silently paints nothing, indistinguishable from a
  /// slow load. Logs the real exception so a failure is diagnosable instead
  /// of a blank card with no trace.
  ///
  /// [cacheWidth] caps the decoded bitmap size (device px) so a full-res
  /// camera photo isn't decoded into memory just to render a small card —
  /// default covers the largest current use (200dp-tall food card) at 2x.
  static Widget getImageWidget(
    String imagePath, {
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
    int cacheWidth = 400,
  }) {
    final imageProvider = getImageProvider(imagePath);
    if (imageProvider == null) {
      return getPlaceholderWidget(width: width, height: height);
    }

    return Image(
      image: ResizeImage(imageProvider, width: cacheWidth),
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (context, error, stackTrace) {
        debugPrint('ImageHelper: failed to load "$imagePath": $error');
        return getPlaceholderWidget(width: width, height: height);
      },
    );
  }

  /// Checks if a local file exists
  static bool localFileExists(String imagePath) {
    if (!isLocalPath(imagePath)) return false;
    return File(imagePath).existsSync();
  }

  /// Gets the appropriate image source type
  static ImageSource getImageSource(String imagePath) {
    if (isNetworkUrl(imagePath)) {
      return ImageSource.network;
    } else if (isLocalPath(imagePath)) {
      return ImageSource.file;
    } else {
      return ImageSource.asset;
    }
  }

  /// Validates if an image path is valid
  static bool isValidImagePath(String imagePath) {
    if (imagePath.isEmpty) return false;

    if (isNetworkUrl(imagePath)) {
      return true; // Assume network URLs are valid
    } else if (isLocalPath(imagePath)) {
      return localFileExists(imagePath);
    }

    return false;
  }

  /// Creates a placeholder widget for missing images
  static Widget getPlaceholderWidget({double? width, double? height}) {
    return Container(
      width: width,
      height: height,
      color: Colors.grey[300],
      child: const Icon(IconlyLight.image, color: Colors.grey, size: 48),
    );
  }
}

/// Enum for image source types
enum ImageSource { network, file, asset }
