import 'package:flutter/material.dart';
import 'package:iconly/iconly.dart';
import 'package:nutriscan/config/app_colors.dart';
import 'package:nutriscan/config/app_localizations.dart';
import 'package:nutriscan/providers/notifications/notification_provider.dart';
import 'package:nutriscan/providers/payment/subscription_provider.dart';
import 'package:nutriscan/providers/theme/language_provider.dart';
import 'package:nutriscan/providers/theme/theme_provider.dart';
import 'package:nutriscan/screens/analysis/monthly_report_screen.dart';
import 'package:nutriscan/screens/analysis/weekly_report_screen.dart';
import 'package:nutriscan/screens/subscription/subscription_screen.dart';
import 'package:nutriscan/utils/page_transition.dart';
import 'package:nutriscan/widgets/ads/adaptive_banner_ad.dart';
import 'package:nutriscan/widgets/common/sk_switch.dart';
import 'package:nutriscan/widgets/dialogs/sk_confirm_dialog.dart';
import 'package:nutriscan/widgets/settings/notification_widgets.dart';
import 'package:provider/provider.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return Consumer4<
      ThemeProvider,
      LanguageProvider,
      NotificationProvider,
      SubscriptionProvider
    >(
      builder: (
        context,
        themeProvider,
        languageProvider,
        notificationProvider,
        subscriptionProvider,
        child,
      ) {
        final isDarkMode = themeProvider.isDarkMode;
        final d = isDarkMode;
        final hasPremium = subscriptionProvider.hasPremiumFeatures;

            return Scaffold(
              backgroundColor: AppColors.skPaper(d),
              appBar: AppBar(
                title: Text(
                  AppLocalizations.getString(
                    'notification_settings',
                    languageProvider.currentLanguage,
                  ),
                  style: themeProvider.getSerifFont(
                    fontSize: 22,
                    color: AppColors.skInk(d),
                  ),
                ),
                backgroundColor: AppColors.skPaper(d),
                elevation: 0,
                leading: IconButton(
                  icon: Icon(Icons.arrow_back, color: AppColors.skInk(d)),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              body: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // If paused, show only pause info card, hide all other settings
                          if (notificationProvider.notificationsPaused) ...[
                            NotificationPauseCard(
                              remainingDays:
                                  notificationProvider.remainingPauseDays,
                              onResume: () {
                                notificationProvider.resumeNotifications();
                              },
                              themeProvider: themeProvider,
                              languageProvider: languageProvider,
                              isDarkMode: isDarkMode,
                            ),
                          ] else ...[
                            // 7 Days Pause Button (Premium Only) - Only show when NOT paused
                            if (hasPremium) ...[
                              NotificationCategoryHeader(
                                titleKey: 'pause_category',
                                icon: IconlyBold.time_circle,
                                themeProvider: themeProvider,
                                languageProvider: languageProvider,
                                isDarkMode: isDarkMode,
                              ),
                              const SizedBox(height: 12),
                              _buildPauseButton(
                                themeProvider,
                                languageProvider,
                                notificationProvider,
                                isDarkMode,
                              ),
                              const SizedBox(height: 24),
                            ],

                            // Category: Meal Reminders
                            NotificationCategoryHeader(
                              titleKey: 'meal_reminders_category',
                              icon: IconlyBold.buy,
                              themeProvider: themeProvider,
                              languageProvider: languageProvider,
                              isDarkMode: isDarkMode,
                            ),
                            const SizedBox(height: 12),

                            // Meal Reminders Toggle
                            NotificationToggleCard(
                              icon: IconlyBold.buy,
                              iconColor: AppColors.skInk(d),
                              titleKey: 'enable_notifications',
                              subtitleKey: 'notification_description',
                              value: notificationProvider.notificationsEnabled,
                              onChanged: (value) {
                                notificationProvider.toggleNotifications(value);
                              },
                              themeProvider: themeProvider,
                              languageProvider: languageProvider,
                              isDarkMode: isDarkMode,
                            ),
                            const SizedBox(height: 12),

                            // Meal Reminder Cards (only show when enabled)
                            if (notificationProvider.notificationsEnabled) ...[
                              ...notificationProvider.mealReminders.map(
                                (reminder) => MealReminderCard(
                                  mealNameKey: reminder.name,
                                  icon: _getMealIcon(reminder.name),
                                  time: reminder.time,
                                  isEnabled: reminder.isEnabled,
                                  formattedTime: notificationProvider
                                      .formatTime(reminder.time),
                                  onTimePressed: () async {
                                    final newTime = await showTimePicker(
                                      context: context,
                                      initialTime: reminder.time,
                                      builder:
                                          (
                                            BuildContext context,
                                            Widget? child,
                                          ) {
                                            return MediaQuery(
                                              data: MediaQuery.of(context)
                                                  .copyWith(
                                                    alwaysUse24HourFormat:
                                                        false,
                                                  ),
                                              child: child!,
                                            );
                                          },
                                    );
                                    if (newTime != null) {
                                      notificationProvider.updateReminderTime(
                                        reminder.id,
                                        newTime,
                                      );
                                    }
                                  },
                                  onToggle: (value) {
                                    notificationProvider.toggleReminder(
                                      reminder.id,
                                      value,
                                    );
                                  },
                                  themeProvider: themeProvider,
                                  languageProvider: languageProvider,
                                  isDarkMode: isDarkMode,
                                ),
                              ),
                            ],
                            const SizedBox(height: 24),

                            // Category: Progress Notifications
                            NotificationCategoryHeader(
                              titleKey: 'progress_category',
                              icon: IconlyBold.chart,
                              themeProvider: themeProvider,
                              languageProvider: languageProvider,
                              isDarkMode: isDarkMode,
                            ),
                            const SizedBox(height: 12),
                            NotificationToggleCard(
                              icon: IconlyBold.chart,
                              iconColor: AppColors.secondary,
                              titleKey: 'daily_progress',
                              subtitleKey: 'daily_progress_subtitle',
                              value: notificationProvider.dailyProgressEnabled,
                              onChanged: (value) {
                                notificationProvider.toggleDailyProgress(value);
                              },
                              themeProvider: themeProvider,
                              languageProvider: languageProvider,
                              isDarkMode: isDarkMode,
                            ),
                            const SizedBox(height: 24),

                            // Category: Inactivity Notifications
                            NotificationCategoryHeader(
                              titleKey: 'inactivity_category',
                              icon: IconlyBold.time_circle,
                              themeProvider: themeProvider,
                              languageProvider: languageProvider,
                              isDarkMode: isDarkMode,
                            ),
                            const SizedBox(height: 12),
                            NotificationToggleCard(
                              icon: IconlyBold.time_circle,
                              iconColor: AppColors.warning,
                              titleKey: 'inactivity_reminder',
                              subtitleKey: 'inactivity_reminder_subtitle',
                              value: notificationProvider
                                  .inactivityReminderEnabled,
                              onChanged: (value) {
                                notificationProvider.toggleInactivityReminder(
                                  value,
                                );
                              },
                              themeProvider: themeProvider,
                              languageProvider: languageProvider,
                              isDarkMode: isDarkMode,
                            ),
                            const SizedBox(height: 24),

                            // Category: Summary Notifications
                            NotificationCategoryHeader(
                              titleKey: 'summary_category',
                              icon: IconlyBold.calendar,
                              themeProvider: themeProvider,
                              languageProvider: languageProvider,
                              isDarkMode: isDarkMode,
                            ),
                            const SizedBox(height: 12),
                            NotificationToggleCard(
                              icon: IconlyBold.calendar,
                              iconColor: AppColors.success,
                              titleKey: 'weekly_summary',
                              subtitleKey: 'weekly_summary_subtitle',
                              value: notificationProvider.weeklySummaryEnabled,
                              onChanged: (value) {
                                notificationProvider.toggleWeeklySummary(value);
                              },
                              onTap: () {
                                Navigator.push(
                                  context,
                                  PageTransition(child: const WeeklyReportScreen()),
                                );
                              },
                              themeProvider: themeProvider,
                              languageProvider: languageProvider,
                              isDarkMode: isDarkMode,
                            ),
                            const SizedBox(height: 12),
                            NotificationToggleCard(
                              icon: IconlyBold.document,
                              iconColor: AppColors.accent,
                              titleKey: 'monthly_summary',
                              subtitleKey: 'monthly_summary_subtitle',
                              value: notificationProvider.monthlySummaryEnabled,
                              onChanged: (value) {
                                notificationProvider.toggleMonthlySummary(
                                  value,
                                );
                              },
                              onTap: () {
                                final now = DateTime.now();
                                final previousMonth = now.month == 1
                                    ? 12
                                    : now.month - 1;
                                final previousYear = now.month == 1
                                    ? now.year - 1
                                    : now.year;
                                Navigator.push(
                                  context,
                                  PageTransition(
                                    child: MonthlyReportScreen(
                                      month: previousMonth,
                                      year: previousYear,
                                    ),
                                  ),
                                );
                              },
                              themeProvider: themeProvider,
                              languageProvider: languageProvider,
                              isDarkMode: isDarkMode,
                            ),
                            const SizedBox(height: 24),

                            // Category: Promotion Notifications
                            if (!hasPremium) ...[
                              NotificationCategoryHeader(
                                titleKey: 'promotion_category',
                                icon: IconlyBold.star,
                                themeProvider: themeProvider,
                                languageProvider: languageProvider,
                                isDarkMode: isDarkMode,
                              ),
                              const SizedBox(height: 12),
                              _buildPremiumPromotionToggle(
                                themeProvider,
                                languageProvider,
                                notificationProvider,
                                isDarkMode,
                              ),
                            ],
                          ],
                        ],
                      ),
                    ),
                  ),
                  const AdaptiveBannerAd(),
                ],
              ),
            );
          },
    );
  }

  Widget _buildPremiumPromotionToggle(
    ThemeProvider themeProvider,
    LanguageProvider languageProvider,
    NotificationProvider notificationProvider,
    bool isDarkMode,
  ) {
    final d = isDarkMode;
    return Container(
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
            child: Icon(IconlyBold.star, color: AppColors.skInk(d), size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.getString(
                    'premium_promotion',
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
                    'premium_promotion_subtitle',
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
          SkSwitch(
            value: notificationProvider.premiumPromotionEnabled,
            isDarkMode: d,
            onChanged: (value) {
              // If trying to disable, show upgrade dialog
              if (!value) {
                _showUpgradeToDisableDialog();
              } else {
                // Allow enabling
                notificationProvider.togglePremiumPromotion(value);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPauseButton(
    ThemeProvider themeProvider,
    LanguageProvider languageProvider,
    NotificationProvider notificationProvider,
    bool isDarkMode,
  ) {
    final isPaused = notificationProvider.notificationsPaused;
    final remainingDays = notificationProvider.remainingPauseDays;
    final d = isDarkMode;

    return Container(
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
            child: Icon(
              IconlyBold.time_circle,
              color: AppColors.skInk(d),
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.getString(
                    'pause_notifications',
                    languageProvider.currentLanguage,
                  ),
                  style: themeProvider.getBodyFont(
                    fontSize: 15,
                    color: AppColors.skInk(d),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  isPaused
                      ? '${AppLocalizations.getString('pause_days_remaining', languageProvider.currentLanguage)}: $remainingDays'
                      : AppLocalizations.getString(
                          'pause_subtitle',
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
          SkSwitch(
            value: isPaused,
            isDarkMode: d,
            onChanged: (value) {
              if (value) {
                _showPauseConfirmDialog(notificationProvider, languageProvider);
              } else {
                notificationProvider.resumeNotifications();
              }
            },
          ),
        ],
      ),
    );
  }

  void _showPauseConfirmDialog(
    NotificationProvider notificationProvider,
    LanguageProvider languageProvider,
  ) {
    final lang = languageProvider.currentLanguage;
    SkConfirmDialog.show(
      context,
      icon: IconlyBold.time_circle,
      title: AppLocalizations.getString('pause_confirm_title', lang),
      message: AppLocalizations.getString('pause_confirm_message', lang),
      cancelLabel: AppLocalizations.getString('cancel', lang),
      confirmLabel: AppLocalizations.getString('pause_confirm', lang),
      onConfirm: () => notificationProvider.pauseNotificationsFor7Days(),
    );
  }

  IconData _getMealIcon(String mealName) {
    switch (mealName) {
      case 'breakfast':
        return IconlyBold.time_circle;
      case 'lunch':
        return IconlyBold.time_square;
      case 'snack':
        return IconlyBold.activity;
      case 'dinner':
        return IconlyBold.calendar;
      default:
        return IconlyBold.notification;
    }
  }

  void _showUpgradeToDisableDialog() {
    final languageProvider = Provider.of<LanguageProvider>(
      context,
      listen: false,
    );
    final lang = languageProvider.currentLanguage;

    SkConfirmDialog.show(
      context,
      icon: IconlyBold.star,
      title: AppLocalizations.getString('upgrade_required', lang),
      message: AppLocalizations.getString('upgrade_to_disable_promotion', lang),
      cancelLabel: AppLocalizations.getString('cancel', lang),
      confirmLabel: AppLocalizations.getString('upgrade_now', lang),
      onConfirm: () {
        Navigator.push(
          context,
          PageTransition(child: const SubscriptionScreen()),
        );
      },
    );
  }
}
