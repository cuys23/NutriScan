import 'package:flutter/material.dart';
import 'package:nutriscan/config/app_colors.dart';
import 'package:nutriscan/providers/theme/theme_provider.dart';

/// Slow Kitchen text-only tab bar — uppercase labels, no icons.
class SkTabBar extends StatelessWidget {
  final String activeTab;
  final ValueChanged<String> onTabChanged;
  final bool isDarkMode;
  final ThemeProvider themeProvider;

  static const List<String> tabKeys = [
    'today',
    'history',
    'trends',
    'coach',
    'you',
  ];
  static const List<String> tabLabels = [
    'Today',
    'History',
    'Trends',
    'Coach',
    'You',
  ];

  const SkTabBar({
    super.key,
    required this.activeTab,
    required this.onTabChanged,
    required this.isDarkMode,
    required this.themeProvider,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 0, 28, 30),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(tabKeys.length, (i) {
          final isActive = activeTab == tabKeys[i];
          return GestureDetector(
            onTap: () => onTabChanged(tabKeys[i]),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(
                tabLabels[i].toUpperCase(),
                style: themeProvider.getBodyFont(
                  fontSize: 12,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                  color: isActive
                      ? AppColors.skInk(isDarkMode)
                      : AppColors.skTabOff(isDarkMode),
                  letterSpacing: 1.68,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
