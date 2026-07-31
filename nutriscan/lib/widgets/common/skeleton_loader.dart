import 'package:flutter/material.dart';
import 'package:nutriscan/config/app_colors.dart';
import 'package:nutriscan/config/radii.dart';
import 'package:nutriscan/config/spacing.dart';

/// Content-shaped loading placeholder — replaces bare spinners in list/card
/// contexts with a shimmering box matching the eventual layout's shape.
/// Hand-rolled (single AnimationController + a sweeping gradient), consistent
/// with the rest of this app's animation code rather than adding the
/// `shimmer` package for something this small.
class SkeletonLoader extends StatefulWidget {
  final double width;
  final double height;
  final double radius;

  const SkeletonLoader({
    super.key,
    this.width = double.infinity,
    this.height = 16,
    this.radius = Radii.sm,
  });

  @override
  State<SkeletonLoader> createState() => _SkeletonLoaderState();
}

class _SkeletonLoaderState extends State<SkeletonLoader> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? AppColors.surfaceDark : AppColors.grey200;
    final highlightColor = isDark ? AppColors.borderDark : AppColors.grey100;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            final dx = _controller.value * 2 - 1; // sweeps from -1 to 1
            return LinearGradient(
              colors: [baseColor, highlightColor, baseColor],
              stops: const [0.35, 0.5, 0.65],
              begin: Alignment(-1 + dx, 0),
              end: Alignment(1 + dx, 0),
            ).createShader(bounds);
          },
          child: Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              color: baseColor,
              borderRadius: BorderRadius.circular(widget.radius),
            ),
          ),
        );
      },
    );
  }
}

/// Skeleton placeholder shaped like a typical list tile (icon + two text lines).
class SkeletonListTile extends StatelessWidget {
  const SkeletonListTile({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
      child: Row(
        children: [
          const SkeletonLoader(width: 40, height: 40, radius: Radii.sm),
          const SizedBox(width: Spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                SkeletonLoader(height: 14, width: 160),
                SizedBox(height: Spacing.sm),
                SkeletonLoader(height: 12, width: 100),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Skeleton placeholder shaped like a SurfaceCard (title + body block).
class SkeletonCard extends StatelessWidget {
  const SkeletonCard({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(Spacing.lg),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          SkeletonLoader(height: 18, width: 140),
          SizedBox(height: Spacing.md),
          SkeletonLoader(height: 12),
          SizedBox(height: Spacing.sm),
          SkeletonLoader(height: 12, width: 220),
        ],
      ),
    );
  }
}
