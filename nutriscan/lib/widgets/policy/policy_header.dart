import 'package:flutter/material.dart';
import 'package:nutriscan/config/app_colors.dart';
import 'package:nutriscan/providers/theme/theme_provider.dart';
import 'package:provider/provider.dart';

class PolicyHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;

  const PolicyHeader({
    super.key,
    required this.title,
    this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final tp = context.watch<ThemeProvider>();
    final d = tp.isDarkMode;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.skSurface(d),
        border: Border.all(color: AppColors.skRule(d)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, size: 40, color: AppColors.skAccent(d)),
          const SizedBox(height: 12),
          Text(
            title,
            style: tp.getSerifFont(
              fontSize: 26,
              color: AppColors.skInk(d),
            ),
            textAlign: TextAlign.center,
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              subtitle!,
              style: tp.getBodyFont(
                fontSize: 13,
                color: AppColors.skMuted(d),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}
