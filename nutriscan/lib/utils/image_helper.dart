import 'dart:io';
import 'package:flutter/material.dart';
import 'package:iconly/iconly.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

/// Image helper utility for managing local and Firebase images.
///
/// On iOS (especially the Simulator) the app-container UUID changes on every
/// rebuild/reinstall, which makes previously stored **absolute** paths point
/// to a non-existent directory. The [_resolveLocalPath] method detects this
/// situation by looking for the `food_images/` segment inside the path and
/// re-joining the relative tail with the *current* documents directory.
class ImageHelper {
  /// Cached documents-directory path so we don't call path_provider on every
  /// image load. Populated lazily by [_ensureDocsDirCached].
  static String? _cachedDocsDir;

  /// Ensures [_cachedDocsDir] is populated. Safe to call multiple times.
  static Future<void> _ensureDocsDirCached() async {
    _cachedDocsDir ??= (await getApplicationDocumentsDirectory()).path;
  }

  /// Call once at app startup (e.g. in `main()` or provider init) so that
  /// subsequent synchronous [_resolveLocalPath] calls have a cached value.
  static Future<void> init() async {
    await _ensureDocsDirCached();
  }

  /// Given an absolute local path that may contain a stale container UUID,
  /// returns a corrected path using the current documents directory.
  ///
  /// Example stored path:
  ///   `/…/Devices/<OLD_UUID>/…/Documents/food_images/abc.jpg`
  /// Resolved to:
  ///   `/…/Devices/<CURRENT_UUID>/…/Documents/food_images/abc.jpg`
  ///
  /// If the path doesn't contain `food_images/`, or if it already points to
  /// an existing file, it is returned unchanged.
  static String _resolveLocalPath(String imagePath) {
    if (_cachedDocsDir == null) {
      // Cache not ready yet – return as-is; the errorBuilder will handle it.
      return imagePath;
    }

    // If the file already exists at the stored path, nothing to fix.
    if (File(imagePath).existsSync()) return imagePath;

    // Try to extract the relative portion starting from 'food_images/'.
    const marker = 'food_images/';
    final idx = imagePath.indexOf(marker);
    if (idx == -1) return imagePath; // Not a managed image path.

    final relativeTail = imagePath.substring(idx); // e.g. food_images/abc.jpg
    final resolved = path.join(_cachedDocsDir!, relativeTail);

    if (File(resolved).existsSync()) {
      debugPrint('ImageHelper: resolved stale path → $resolved');
      return resolved;
    }

    // Neither path works – return the resolved one anyway (closer to truth).
    return resolved;
  }

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

  /// Creates appropriate ImageProvider based on image path type.
  /// For local paths, resolves stale container UUIDs first.
  static ImageProvider? getImageProvider(String imagePath) {
    if (isNetworkUrl(imagePath)) {
      return NetworkImage(imagePath);
    } else if (isLocalPath(imagePath)) {
      final resolved = _resolveLocalPath(imagePath);
      return FileImage(File(resolved));
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
    // Resolve potentially stale local paths before creating the provider.
    final effectivePath =
        isLocalPath(imagePath) ? _resolveLocalPath(imagePath) : imagePath;

    final imageProvider = getImageProvider(effectivePath);
    if (imageProvider == null) {
      return getPlaceholderWidget(width: width, height: height);
    }

    return Image(
      image: ResizeImage(imageProvider, width: cacheWidth),
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (context, error, stackTrace) {
        debugPrint('ImageHelper: failed to load "$effectivePath": $error');
        return getPlaceholderWidget(width: width, height: height);
      },
    );
  }

  /// Checks if a local file exists (resolves stale paths first)
  static bool localFileExists(String imagePath) {
    if (!isLocalPath(imagePath)) return false;
    final resolved = _resolveLocalPath(imagePath);
    return File(resolved).existsSync();
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
