import 'package:flutter/material.dart';
import 'package:nutriscan/config/app_colors.dart';
import 'package:nutriscan/providers/theme/theme_provider.dart';

/// Full-width dark pill scan button — Slow Kitchen style.
class SkScanButton extends StatefulWidget {
  final VoidCallback onTap;
  final bool isDarkMode;
  final ThemeProvider themeProvider;

  const SkScanButton({
    super.key,
    required this.onTap,
    required this.isDarkMode,
    required this.themeProvider,
  });

  @override
  State<SkScanButton> createState() => _SkScanButtonState();
}

class _SkScanButtonState extends State<SkScanButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 0, 28, 14),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) {
          setState(() => _pressed = false);
          widget.onTap();
        },
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 0.97 : 1.0,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          child: Container(
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.skInk(widget.isDarkMode),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.crop_free_rounded,
                  size: 20,
                  color: AppColors.skPaper(widget.isDarkMode),
                ),
                const SizedBox(width: 10),
                Text(
                  'Scan a meal',
                  style: widget.themeProvider.getBodyFont(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: AppColors.skPaper(widget.isDarkMode),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
