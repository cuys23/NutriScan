import 'package:flutter/material.dart';
import 'package:nutriscan/config/app_colors.dart';
import 'package:nutriscan/providers/theme/theme_provider.dart';
import 'package:provider/provider.dart';

class PolicySection extends StatelessWidget {
  final String title;
  final String content;
  final IconData? icon;

  const PolicySection({
    super.key,
    required this.title,
    required this.content,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final tp = context.watch<ThemeProvider>();
    final d = tp.isDarkMode;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.skSurface(d),
        border: Border.all(color: AppColors.skRule(d)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, color: AppColors.skInk(d), size: 20),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Text(
                  title,
                  style: tp.getSerifFont(
                    fontSize: 20,
                    color: AppColors.skInk(d),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: tp.getBodyFont(
              fontSize: 14,
              color: AppColors.skBody(d),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
