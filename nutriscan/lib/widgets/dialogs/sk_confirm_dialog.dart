import 'package:flutter/material.dart';
import 'package:nutriscan/config/app_colors.dart';
import 'package:nutriscan/providers/theme/theme_provider.dart';
import 'package:provider/provider.dart';

/// Shared Slow Kitchen icon + title + message + cancel/confirm dialog shell,
/// matching CoinAdDialogs / DeleteAccountDialog: paper card, rule border,
/// serif title, stacked full-width pill buttons.
class SkConfirmDialog {
  static Future<void> show(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String message,
    required String cancelLabel,
    required String confirmLabel,
    required VoidCallback onConfirm,
    Color? iconColor,
    Color? confirmColor,
    Color? confirmTextColor,
  }) {
    final tp = context.read<ThemeProvider>();
    final d = tp.isDarkMode;

    return showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: AppColors.skPaper(d),
              border: Border.all(color: AppColors.skRule(d)),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.skSurface(d),
                    border: Border.all(color: AppColors.skRule(d)),
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Icon(
                    icon,
                    size: 28,
                    color: iconColor ?? AppColors.skAccent(d),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  title,
                  style: tp.getSerifFont(
                    fontSize: 22,
                    color: AppColors.skInk(d),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  message,
                  style: tp.getBodyFont(
                    fontSize: 14,
                    color: AppColors.skMuted(d),
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Container(height: 1, color: AppColors.skRule(d)),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: () {
                    Navigator.of(ctx).pop();
                    onConfirm();
                  },
                  child: Container(
                    width: double.infinity,
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: confirmColor ?? AppColors.skInk(d),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Text(
                      confirmLabel,
                      style: tp.getBodyFont(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: confirmTextColor ?? AppColors.skPaper(d),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: () => Navigator.of(ctx).pop(),
                  child: Container(
                    width: double.infinity,
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      border: Border.all(color: AppColors.skRule(d)),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Text(
                      cancelLabel,
                      style: tp.getBodyFont(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: AppColors.skMuted(d),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
