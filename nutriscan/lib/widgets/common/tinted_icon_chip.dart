import 'package:flutter/material.dart';
import 'package:nutriscan/config/app_colors.dart';
import 'package:nutriscan/config/radii.dart';

/// Tinted icon-in-a-circle/square chip — unifies the pattern independently
/// reimplemented in info_card.dart and settings_card.dart (a colored icon on
/// a low-alpha tint of that same color).
class TintedIconChip extends StatelessWidget {
  final IconData icon;
  final Color? color;
  final double size;
  final double boxSize;
  final bool circular;

  const TintedIconChip({
    super.key,
    required this.icon,
    this.color,
    this.size = 20,
    this.boxSize = 40,
    this.circular = false,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedColor = color ?? AppColors.primary;
    return Container(
      width: boxSize,
      height: boxSize,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: resolvedColor.withValues(alpha: 0.1),
        shape: circular ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: circular ? null : BorderRadius.circular(Radii.sm),
      ),
      child: Icon(icon, color: resolvedColor, size: size),
    );
  }
}
