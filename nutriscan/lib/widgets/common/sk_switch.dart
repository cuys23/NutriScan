import 'package:flutter/material.dart';
import 'package:nutriscan/config/app_colors.dart';

/// The Slow Kitchen toggle: a sage-filled pill with a paper-colored knob,
/// matching the one on the main Settings tab (slow_kitchen_home.dart).
class SkSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool isDarkMode;

  const SkSwitch({
    super.key,
    required this.value,
    required this.isDarkMode,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final d = isDarkMode;
    return Opacity(
      opacity: onChanged == null ? 0.5 : 1,
      child: GestureDetector(
        onTap: onChanged == null ? null : () => onChanged!(!value),
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 46,
          height: 26,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: value ? AppColors.skSage(d) : AppColors.skRule(d),
          ),
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 200),
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.skSurface(d),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.28),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
