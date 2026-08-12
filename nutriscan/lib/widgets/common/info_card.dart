import 'package:flutter/material.dart';
import 'package:nutriscan/config/app_colors.dart';
import 'package:nutriscan/providers/theme/theme_provider.dart';

class InfoCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final IconData icon;
  final bool isDarkMode;
  final ThemeProvider themeProvider;

  const InfoCard({
    super.key,
    required this.title,
    required this.children,
    required this.icon,
    required this.isDarkMode,
    required this.themeProvider,
  });

  @override
  Widget build(BuildContext context) {
    final d = isDarkMode;
    return Container(
      width: double.infinity,
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
              Icon(icon, color: AppColors.skInk(d), size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: themeProvider.getSerifFont(
                    fontSize: 20,
                    color: AppColors.skInk(d),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}
