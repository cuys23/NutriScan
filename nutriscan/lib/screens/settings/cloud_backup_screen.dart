import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nutriscan/config/app_colors.dart';
import 'package:nutriscan/config/app_localizations.dart';
import 'package:nutriscan/providers/auth/cloud_backup_provider.dart';
import 'package:nutriscan/providers/payment/subscription_provider.dart';
import 'package:nutriscan/providers/theme/language_provider.dart';
import 'package:nutriscan/providers/theme/theme_provider.dart';
import 'package:nutriscan/widgets/ads/adaptive_banner_ad.dart';
import 'package:nutriscan/widgets/cloud_backup/cloud_backup_widgets.dart';
import 'package:nutriscan/widgets/common/sk_switch.dart';
import 'package:nutriscan/widgets/dialogs/sk_confirm_dialog.dart';
import 'package:provider/provider.dart';


class CloudBackupScreen extends StatefulWidget {
  const CloudBackupScreen({super.key});

  @override
  State<CloudBackupScreen> createState() => _CloudBackupScreenState();
}

class _CloudBackupScreenState extends State<CloudBackupScreen> {
  @override
  void initState() {
    super.initState();
    // Initialize silently without loading state
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CloudBackupProvider>().initializeSilently();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh data when returning to the page without loading
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final backupProvider = context.read<CloudBackupProvider>();
      if (backupProvider.isInitialized && backupProvider.isSignedIn) {
        backupProvider.refreshBackupInfo();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final languageProvider = Provider.of<LanguageProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;
    final d = isDarkMode;
    final currentLanguage = languageProvider.currentLanguage;

    return Scaffold(
      backgroundColor: AppColors.skPaper(d),
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.skInk(d), size: 24),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          AppLocalizations.getString('cloud_backup', currentLanguage),
          style: themeProvider.getSerifFont(
            fontSize: 22,
            color: AppColors.skInk(d),
          ),
        ),
        backgroundColor: AppColors.skPaper(d),
        elevation: 0,
        actions: [
          Consumer<CloudBackupProvider>(
            builder: (context, backupProvider, child) {
              // Check if user is premium
              final subscriptionProvider = Provider.of<SubscriptionProvider>(
                context,
                listen: false,
              );
              final isPremium = subscriptionProvider.hasPremiumFeatures;

              if (!isPremium) return const SizedBox.shrink();

              return BackupStatusIndicator(
                isSignedIn: backupProvider.isSignedIn,
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Consumer<CloudBackupProvider>(
              builder: (context, backupProvider, child) {
                final languageProvider = Provider.of<LanguageProvider>(
                  context,
                  listen: false,
                );
                final currentLanguage = languageProvider.currentLanguage;

                if (backupProvider.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Backup Info Section
                      _buildBackupInfoSection(
                        backupProvider,
                        themeProvider,
                        isDarkMode,
                        currentLanguage,
                      ),

                      const SizedBox(height: 30),

                      // Auto Backup Section
                      _buildAutoBackupSection(
                        backupProvider,
                        themeProvider,
                        isDarkMode,
                        currentLanguage,
                      ),

                      const SizedBox(height: 30),
                    ],
                  ),
                );
              },
            ),
          ),
          const AdaptiveBannerAd(),
        ],
      ),
    );
  }

  Widget _buildBackupInfoSection(
    CloudBackupProvider backupProvider,
    ThemeProvider themeProvider,
    bool isDarkMode,
    String currentLanguage,
  ) {
    // Check if user is premium
    final subscriptionProvider = Provider.of<SubscriptionProvider>(
      context,
      listen: false,
    );
    final isPremium = subscriptionProvider.hasPremiumFeatures;
    final d = isDarkMode;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.skSurface(d),
        border: Border.all(color: AppColors.skRule(d)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                AppLocalizations.getString('backup_actions', currentLanguage),
                style: themeProvider.getSerifFont(
                  fontSize: 18,
                  color: AppColors.skInk(d),
                ),
              ),
              if (!isPremium) ...[
                const SizedBox(width: 8),
                const PremiumBadge(),
              ],
            ],
          ),
          const SizedBox(height: 8),
          // The provider was already loading this (initializeSilently,
          // refreshBackupInfo, and after every successful backupData call)
          // but nothing ever rendered it — the screen showed buttons with
          // no indication of whether a backup exists or when it last ran.
          Text(
            _backupStatusLabel(backupProvider, currentLanguage),
            style: themeProvider.getBodyFont(
              fontSize: 13,
              color: AppColors.skMuted(d),
            ),
          ),
          const SizedBox(height: 15),

          // Backup Button
          GestureDetector(
            onTap:
                (!isPremium ||
                    backupProvider.isLoading ||
                    backupProvider.isBackingUp)
                ? null
                : () async {
                    final subscriptionProvider =
                        Provider.of<SubscriptionProvider>(
                          context,
                          listen: false,
                        );
                    final languageProvider = Provider.of<LanguageProvider>(
                      context,
                      listen: false,
                    );
                    await backupProvider.backupData(
                      isPremiumUser: subscriptionProvider.hasPremiumFeatures,
                      language: languageProvider.currentLanguage,
                    );
                    // Backup completed - UI will update automatically
                  },
            child: Container(
              width: double.infinity,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isPremium ? AppColors.skInk(d) : AppColors.skRule(d),
                borderRadius: BorderRadius.circular(24),
              ),
              child: backupProvider.isBackingUp
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.skPaper(d),
                        ),
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isPremium ? Icons.cloud_upload : Icons.lock,
                          size: 18,
                          color: AppColors.skPaper(d),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isPremium
                              ? AppLocalizations.getString(
                                  'backup_to_cloud',
                                  currentLanguage,
                                )
                              : AppLocalizations.getString(
                                  'backup_to_cloud_premium',
                                  currentLanguage,
                                ),
                          style: themeProvider.getBodyFont(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: AppColors.skPaper(d),
                          ),
                        ),
                      ],
                    ),
            ),
          ),

          const SizedBox(height: 12),

          // Restore Button
          GestureDetector(
            onTap:
                (!isPremium ||
                    backupProvider.isLoading ||
                    backupProvider.isRestoring)
                ? null
                : () => _showRestoreDialog(backupProvider, currentLanguage),
            child: Container(
              width: double.infinity,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.transparent,
                border: Border.all(
                  color: isPremium ? AppColors.skInk(d) : AppColors.skRule(d),
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: backupProvider.isRestoring
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.skInk(d),
                        ),
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isPremium ? Icons.cloud_download : Icons.lock,
                          size: 18,
                          color: isPremium
                              ? AppColors.skInk(d)
                              : AppColors.skMuted(d),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isPremium
                              ? AppLocalizations.getString(
                                  'restore_from_cloud',
                                  currentLanguage,
                                )
                              : AppLocalizations.getString(
                                  'restore_from_cloud_premium',
                                  currentLanguage,
                                ),
                          style: themeProvider.getBodyFont(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: isPremium
                                ? AppColors.skInk(d)
                                : AppColors.skMuted(d),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  String _backupStatusLabel(
    CloudBackupProvider backupProvider,
    String currentLanguage,
  ) {
    if (!backupProvider.isSignedIn) {
      return AppLocalizations.getString('not_signed_in', currentLanguage);
    }
    final info = backupProvider.backupInfo;
    final backupDate = info?['backupDate'];
    if (info == null || backupDate is! DateTime) {
      return AppLocalizations.getString('no_backup_yet', currentLanguage);
    }
    final formattedDate = DateFormat('d MMMM yyyy, HH:mm').format(backupDate);
    return AppLocalizations.getString('last_backup_items', currentLanguage)
        .replaceAll('{date}', formattedDate)
        .replaceAll('{count}', '${info['totalItems'] ?? 0}');
  }

  Widget _buildAutoBackupSection(
    CloudBackupProvider backupProvider,
    ThemeProvider themeProvider,
    bool isDarkMode,
    String currentLanguage,
  ) {
    // Check if user is premium
    final subscriptionProvider = Provider.of<SubscriptionProvider>(
      context,
      listen: false,
    );
    final isPremium = subscriptionProvider.hasPremiumFeatures;
    final d = isDarkMode;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.skSurface(d),
        border: Border.all(color: AppColors.skRule(d)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                AppLocalizations.getString('auto_backup', currentLanguage),
                style: themeProvider.getSerifFont(
                  fontSize: 18,
                  color: AppColors.skInk(d),
                ),
              ),
              if (!isPremium) ...[
                const SizedBox(width: 8),
                const PremiumBadge(),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.getString(
              'auto_backup_description',
              currentLanguage,
            ),
            style: themeProvider.getBodyFont(
              fontSize: 14,
              color: AppColors.skMuted(d),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          Container(height: 1, color: AppColors.skRuleSoft(d)),
          const SizedBox(height: 16),
          FutureBuilder<bool>(
            future: backupProvider.isAutoBackupEnabled(),
            builder: (context, snapshot) {
              final isEnabled = snapshot.data ?? true;
              return Row(
                children: [
                  Expanded(
                    child: Text(
                      AppLocalizations.getString(
                        'enable_auto_backup',
                        currentLanguage,
                      ),
                      style: themeProvider.getBodyFont(
                        fontSize: 15,
                        color: AppColors.skInk(d),
                      ),
                    ),
                  ),
                  SkSwitch(
                    value: isPremium ? isEnabled : false,
                    isDarkMode: d,
                    onChanged: isPremium
                        ? (value) async {
                            await backupProvider.setAutoBackupEnabled(value);
                            if (mounted) {
                              setState(() {});
                            }
                          }
                        : null,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  void _showRestoreDialog(
    CloudBackupProvider backupProvider,
    String currentLanguage,
  ) {
    SkConfirmDialog.show(
      context,
      icon: Icons.cloud_download,
      title: AppLocalizations.getString('restore_data', currentLanguage),
      message: AppLocalizations.getString(
        'restore_data_warning',
        currentLanguage,
      ),
      cancelLabel: AppLocalizations.getString('cancel_btn', currentLanguage),
      confirmLabel: AppLocalizations.getString('restore', currentLanguage),
      onConfirm: () async {
        final subscriptionProvider = Provider.of<SubscriptionProvider>(
          context,
          listen: false,
        );
        final languageProvider = Provider.of<LanguageProvider>(
          context,
          listen: false,
        );
        await backupProvider.restoreData(
          isPremiumUser: subscriptionProvider.hasPremiumFeatures,
          language: languageProvider.currentLanguage,
        );
        // Restore completed - UI will update automatically
      },
    );
  }
}
