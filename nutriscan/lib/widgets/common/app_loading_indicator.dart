import 'package:flutter/material.dart';
import 'package:nutriscan/config/app_colors.dart';
import 'package:nutriscan/config/spacing.dart';

/// Shared loading spinner — replaces the 4 independently hand-rolled
/// AnimationController + Transform.rotate spinners previously duplicated in
/// home_screen.dart, analysis_screen.dart, history_screen.dart, and
/// meal_plan_generator.dart.
class AppLoadingIndicator extends StatelessWidget {
  final String? message;
  final double size;

  const AppLoadingIndicator({super.key, this.message, this.size = 40});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: const CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              backgroundColor: AppColors.primaryLight,
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: Spacing.lg),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: textColor),
            ),
          ],
        ],
      ),
    );
  }
}
