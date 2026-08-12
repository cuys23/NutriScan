import 'package:flutter/material.dart';
import 'package:iconly/iconly.dart';

import 'package:nutriscan/config/app_colors.dart';
import 'package:nutriscan/config/app_localizations.dart';
import 'package:nutriscan/providers/theme/language_provider.dart';
import 'package:nutriscan/providers/theme/theme_provider.dart';
import 'package:nutriscan/widgets/common/sk_switch.dart';

class NotificationCategoryHeader extends StatelessWidget {
  final String titleKey;
  final IconData icon;
  final ThemeProvider themeProvider;
  final LanguageProvider languageProvider;
  final bool isDarkMode;

  const NotificationCategoryHeader({
    super.key,
    required this.titleKey,
    required this.icon,
    required this.themeProvider,
    required this.languageProvider,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    final d = isDarkMode;
    return Row(
      children: [
        Icon(icon, color: AppColors.skInk(d), size: 18),
        const SizedBox(width: 8),
        Text(
          AppLocalizations.getString(
            titleKey,
            languageProvider.currentLanguage,
          ).toUpperCase(),
          style: themeProvider.getSkLabel(
            fontSize: 11,
            color: AppColors.skMuted(d),
          ),
        ),
      ],
    );
  }
}

class NotificationToggleCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String titleKey;
  final String subtitleKey;
  final bool value;
  final ValueChanged<bool> onChanged;
  final ThemeProvider themeProvider;
  final LanguageProvider languageProvider;
  final bool isDarkMode;
  final VoidCallback? onTap;

  const NotificationToggleCard({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.titleKey,
    required this.subtitleKey,
    required this.value,
    required this.onChanged,
    required this.themeProvider,
    required this.languageProvider,
    required this.isDarkMode,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final d = isDarkMode;
    final content = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.skSurface(d),
        border: Border.all(color: AppColors.skRule(d)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.skPaper(d),
              border: Border.all(color: AppColors.skRuleSoft(d)),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, color: AppColors.skInk(d), size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.getString(
                    titleKey,
                    languageProvider.currentLanguage,
                  ),
                  style: themeProvider.getBodyFont(
                    fontSize: 15,
                    color: AppColors.skInk(d),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  AppLocalizations.getString(
                    subtitleKey,
                    languageProvider.currentLanguage,
                  ),
                  style: themeProvider.getBodyFont(
                    fontSize: 12,
                    color: AppColors.skMuted(d),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SkSwitch(value: value, isDarkMode: d, onChanged: onChanged),
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: content,
      );
    }

    return content;
  }
}

class MealReminderCard extends StatelessWidget {
  final String mealNameKey;
  final IconData icon;
  final TimeOfDay time;
  final bool isEnabled;
  final VoidCallback onTimePressed;
  final ValueChanged<bool> onToggle;
  final ThemeProvider themeProvider;
  final LanguageProvider languageProvider;
  final bool isDarkMode;
  final String formattedTime;

  const MealReminderCard({
    super.key,
    required this.mealNameKey,
    required this.icon,
    required this.time,
    required this.isEnabled,
    required this.onTimePressed,
    required this.onToggle,
    required this.themeProvider,
    required this.languageProvider,
    required this.isDarkMode,
    required this.formattedTime,
  });

  @override
  Widget build(BuildContext context) {
    final d = isDarkMode;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.skSurface(d),
        border: Border.all(color: AppColors.skRule(d)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: isEnabled ? AppColors.skInk(d) : AppColors.skMuted(d),
            size: 24,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.getString(
                    mealNameKey,
                    languageProvider.currentLanguage,
                  ),
                  style: themeProvider.getSerifFont(
                    fontSize: 18,
                    color: AppColors.skInk(d),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  formattedTime,
                  style: themeProvider.getBodyFont(
                    fontSize: 13,
                    color: AppColors.skMuted(d),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(IconlyLight.time_circle, color: AppColors.skAccent(d)),
            onPressed: onTimePressed,
          ),
          SkSwitch(value: isEnabled, isDarkMode: d, onChanged: onToggle),
        ],
      ),
    );
  }
}

class NotificationPauseCard extends StatelessWidget {
  final int remainingDays;
  final VoidCallback onResume;
  final ThemeProvider themeProvider;
  final LanguageProvider languageProvider;
  final bool isDarkMode;

  const NotificationPauseCard({
    super.key,
    required this.remainingDays,
    required this.onResume,
    required this.themeProvider,
    required this.languageProvider,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    final d = isDarkMode;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: AppColors.skSurface(d),
                border: Border.all(color: AppColors.skRule(d)),
                shape: BoxShape.circle,
              ),
              child: Icon(
                IconlyBold.time_circle,
                color: AppColors.skAccent(d),
                size: 72,
              ),
            ),
            const SizedBox(height: 36),
            Text(
              AppLocalizations.getString(
                'pause_active',
                languageProvider.currentLanguage,
              ),
              style: themeProvider.getSerifFont(
                fontSize: 30,
                color: AppColors.skInk(d),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  IconlyBold.calendar,
                  color: AppColors.skAccent(d),
                  size: 28,
                ),
                const SizedBox(width: 12),
                Text(
                  '$remainingDays ${AppLocalizations.getString('days', languageProvider.currentLanguage)} ${AppLocalizations.getString('remaining', languageProvider.currentLanguage)}',
                  style: themeProvider.getBodyFont(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: AppColors.skAccent(d),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                AppLocalizations.getString(
                  'pause_info_message',
                  languageProvider.currentLanguage,
                ),
                style: themeProvider.getBodyFont(
                  fontSize: 16,
                  color: AppColors.skMuted(d),
                  height: 1.7,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 48),
            GestureDetector(
              onTap: onResume,
              child: Container(
                width: 280,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.skInk(d),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      IconlyBold.play,
                      size: 22,
                      color: AppColors.skPaper(d),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      AppLocalizations.getString(
                        'resume_now',
                        languageProvider.currentLanguage,
                      ),
                      style: themeProvider.getBodyFont(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.skPaper(d),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// The master "enable notifications" toggle used NotificationToggleCard's
// look-alike but with off-brand blue styling; the call site now uses
// NotificationToggleCard directly (same title/subtitle/value/onChanged shape).
