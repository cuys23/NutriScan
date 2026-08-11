import 'package:flutter/material.dart';
import 'package:nutriscan/config/app_colors.dart';
import 'package:nutriscan/providers/theme/theme_provider.dart';
import 'package:provider/provider.dart';

/// Slow Kitchen–styled snack bar that replaces the default Material SnackBar.
///
/// Usage:
///   SkSnackBar.show(context, message: 'Something happened');
///   SkSnackBar.success(context, message: 'Saved!');
///   SkSnackBar.error(context, message: 'Login failed');
class SkSnackBar {
  SkSnackBar._();

  /// Neutral / informational toast.
  static void show(
    BuildContext context, {
    required String message,
    Duration duration = const Duration(seconds: 3),
  }) {
    _display(context, message: message, type: _Type.info, duration: duration);
  }

  /// Success toast (e.g. account deleted, backup complete).
  static void success(
    BuildContext context, {
    required String message,
    Duration duration = const Duration(seconds: 3),
  }) {
    _display(context, message: message, type: _Type.success, duration: duration);
  }

  /// Error toast (e.g. login failed, network error).
  static void error(
    BuildContext context, {
    required String message,
    Duration duration = const Duration(seconds: 4),
  }) {
    _display(context, message: message, type: _Type.error, duration: duration);
  }

  static void _display(
    BuildContext context, {
    required String message,
    required _Type type,
    required Duration duration,
  }) {
    final tp = context.read<ThemeProvider>();
    final d = tp.isDarkMode;

    final Color bg;
    final Color fg;
    final IconData icon;

    switch (type) {
      case _Type.info:
        bg = AppColors.skInk(d);
        fg = AppColors.skPaper(d);
        icon = Icons.info_outline;
      case _Type.success:
        bg = AppColors.skInk(d);
        fg = AppColors.skPaper(d);
        icon = Icons.check_circle_outline;
      case _Type.error:
        bg = AppColors.skInk(d);
        fg = AppColors.skPaper(d);
        icon = Icons.error_outline;
    }

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: fg, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: tp.getBodyFont(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: fg,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: bg,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        elevation: 0,
        duration: duration,
        dismissDirection: DismissDirection.horizontal,
      ),
    );
  }
}

enum _Type { info, success, error }
