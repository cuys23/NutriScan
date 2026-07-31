import 'package:flutter/material.dart';
import 'package:nutriscan/config/app_colors.dart';
import 'package:nutriscan/config/radii.dart';
import 'package:nutriscan/config/spacing.dart';

/// Shared card surface — replaces the hand-rolled Container+BoxDecoration+
/// boxShadow pattern repeated across info_card.dart, food_detail_card.dart,
/// nutrition_summary_card.dart, and settings_card.dart. Uses a thin border
/// instead of a shadow by default, per the Calm Wellness Minimal direction.
class SurfaceCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double radius;
  final Color? backgroundColor;
  final bool showBorder;
  final VoidCallback? onTap;

  const SurfaceCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.radius = Radii.lg,
    this.backgroundColor,
    this.showBorder = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final resolvedBackground =
        backgroundColor ?? (isDark ? AppColors.surfaceDark : AppColors.surfaceLight);
    final borderColor = isDark ? AppColors.borderDark : AppColors.borderLight;

    // Background/shape/border live on Material itself (not a separate opaque
    // Container) so InkWell's ripple — painted by Material above its own
    // background but below its child — stays visible instead of being
    // hidden under an opaque decoration layer.
    final surface = Material(
      color: resolvedBackground,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
        side: showBorder ? BorderSide(color: borderColor) : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: padding ?? const EdgeInsets.all(Spacing.lg),
          child: child,
        ),
      ),
    );

    return margin == null ? surface : Padding(padding: margin!, child: surface);
  }
}
