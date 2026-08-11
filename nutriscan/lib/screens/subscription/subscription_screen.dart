import 'package:flutter/material.dart';
import 'package:iconly/iconly.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:nutriscan/config/app_colors.dart';
import 'package:nutriscan/config/app_config.dart';
import 'package:nutriscan/config/app_localizations.dart';
import 'package:nutriscan/providers/payment/subscription_provider.dart';
import 'package:nutriscan/providers/theme/language_provider.dart';
import 'package:nutriscan/providers/theme/theme_provider.dart';
import 'package:nutriscan/screens/legal/privacy_policy_screen.dart';
import 'package:nutriscan/screens/legal/terms_of_service_screen.dart';
import 'package:nutriscan/services/payment/iap_service.dart';
import 'package:nutriscan/widgets/subscription/subscription_widgets.dart';
import 'package:provider/provider.dart';


class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  String _selectedPlan = 'monthly';
  List<ProductDetails> _products = [];
  bool _loadingProducts = true;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    try {
      final products = await IAPService.instance.getProducts();
      if (mounted) {
        setState(() {
          _products = products;
          _loadingProducts = false;
        });

        if (_products.isEmpty) {
          debugPrint('IAP Error: No products found in the store. Check your configuration.');
        }
      }
    } catch (e) {
      debugPrint('IAP Error loading products: $e');
      if (mounted) {
        setState(() => _loadingProducts = false);
      }
    }
  }

  // Helper function to localize error messages
  String _getLocalizedErrorMessage(String error, String language) {
    // Map error messages to localization keys
    if (error.startsWith('Payment failed')) {
      return AppLocalizations.getString('payment_failed', language);
    } else if (error.startsWith('Invalid payment amount')) {
      return AppLocalizations.getString('invalid_payment_amount', language);
    } else if (error.startsWith('Subscription failed')) {
      return AppLocalizations.getString('subscription_error', language);
    } else if (error.startsWith('Failed to cancel subscription')) {
      return AppLocalizations.getString('cancellation_error', language);
    } else if (error.startsWith('Failed to load subscription status') ||
        error.startsWith('Failed to save subscription status')) {
      return AppLocalizations.getString('subscription_error', language);
    }
    // Return generic subscription error if no match
    return AppLocalizations.getString('subscription_error', language);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer3<ThemeProvider, LanguageProvider, SubscriptionProvider>(
      builder: (
        context,
        themeProvider,
        languageProvider,
        subscriptionProvider,
        child,
      ) {
        final isDarkMode = themeProvider.isDarkMode;
        final d = isDarkMode;

            return Scaffold(
              backgroundColor: AppColors.skPaper(d),
              appBar: AppBar(
                title: Text(
                  AppLocalizations.getString(
                    'premium_subscription',
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
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Check if user already has premium subscription
                    if (subscriptionProvider.hasPremiumFeatures) ...[
                      // Current Subscription Status
                      _buildCurrentSubscriptionSection(
                        subscriptionProvider,
                        themeProvider,
                        languageProvider,
                        isDarkMode,
                      ),
                      const SizedBox(height: 32),

                      // Cancel Subscription Button
                      _buildCancelSubscriptionButton(
                        subscriptionProvider,
                        themeProvider,
                        languageProvider,
                        isDarkMode,
                      ),
                    ] else ...[
                      // Header Section
                      _buildHeaderSection(
                        themeProvider,
                        languageProvider,
                        isDarkMode,
                      ),
                      const SizedBox(height: 32),

                      // Features Section
                      _buildFeaturesSection(
                        themeProvider,
                        languageProvider,
                        isDarkMode,
                      ),
                      const SizedBox(height: 32),

                      // Pricing Plans
                      _buildPricingPlans(
                        themeProvider,
                        languageProvider,
                        isDarkMode,
                      ),
                      const SizedBox(height: 32),

                      // Subscribe Button
                      _buildSubscribeButton(
                        subscriptionProvider,
                        themeProvider,
                        languageProvider,
                        isDarkMode,
                      ),
                      const SizedBox(height: 20),

                      // Terms and Privacy
                      _buildTermsSection(
                        themeProvider,
                        languageProvider,
                        isDarkMode,
                        subscriptionProvider,
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
    );
  }

  Widget _buildHeaderSection(
    ThemeProvider themeProvider,
    LanguageProvider languageProvider,
    bool isDarkMode,
  ) {
    final d = isDarkMode;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      decoration: BoxDecoration(
        color: AppColors.skSurface(d),
        border: Border.all(color: AppColors.skRule(d)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.skPaper(d),
              border: Border.all(color: AppColors.skRuleSoft(d)),
              shape: BoxShape.circle,
            ),
            child: Icon(IconlyBold.star, size: 36, color: AppColors.skAccent(d)),
          ),
          const SizedBox(height: 16),
          Text(
            AppLocalizations.getString(
              'upgrade_to_premium',
              languageProvider.currentLanguage,
            ),
            style: themeProvider.getSerifFont(
              fontSize: 26,
              color: AppColors.skInk(d),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            AppLocalizations.getString(
              'remove_ads_unlock_features',
              languageProvider.currentLanguage,
            ),
            style: themeProvider.getBodyFont(
              fontSize: 14,
              color: AppColors.skMuted(d),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturesSection(
    ThemeProvider themeProvider,
    LanguageProvider languageProvider,
    bool isDarkMode,
  ) {
    final features = [
      {
        'icon': IconlyBold.shield_done,
        'title': AppLocalizations.getString(
          'ad_free_experience',
          languageProvider.currentLanguage,
        ),
        'description': AppLocalizations.getString(
          'ad_free_description',
          languageProvider.currentLanguage,
        ),
      },
      {
        'icon': IconlyBold.scan,
        'title': AppLocalizations.getString(
          'unlimited_scans',
          languageProvider.currentLanguage,
        ),
        'description': AppLocalizations.getString(
          'unlimited_scans_description',
          languageProvider.currentLanguage,
        ),
      },
      {
        'icon': IconlyBold.chart,
        'title': AppLocalizations.getString(
          'advanced_analytics',
          languageProvider.currentLanguage,
        ),
        'description': AppLocalizations.getString(
          'advanced_analytics_description',
          languageProvider.currentLanguage,
        ),
      },
      {
        'icon': IconlyBold.call,
        'title': AppLocalizations.getString(
          'priority_support',
          languageProvider.currentLanguage,
        ),
        'description': AppLocalizations.getString(
          'priority_support_description',
          languageProvider.currentLanguage,
        ),
      },
    ];

    final d = isDarkMode;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.getString(
            'premium_features',
            languageProvider.currentLanguage,
          ),
          style: themeProvider.getSerifFont(
            fontSize: 22,
            color: AppColors.skInk(d),
          ),
        ),
        const SizedBox(height: 14),
        ...features.map(
          (feature) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              padding: const EdgeInsets.all(14),
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
                      feature['icon'] as IconData,
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
                          feature['title'] as String,
                          style: themeProvider.getSerifFont(
                            fontSize: 18,
                            color: AppColors.skInk(d),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          feature['description'] as String,
                          style: themeProvider.getBodyFont(
                            fontSize: 13,
                            color: AppColors.skMuted(d),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPricingPlans(
    ThemeProvider themeProvider,
    LanguageProvider languageProvider,
    bool isDarkMode,
  ) {
    final d = isDarkMode;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.getString(
            'choose_your_plan',
            languageProvider.currentLanguage,
          ),
          style: themeProvider.getSerifFont(
            fontSize: 22,
            color: AppColors.skInk(d),
          ),
        ),
        const SizedBox(height: 16),
        Column(
          children: [
            if (_loadingProducts)
              const Center(child: CircularProgressIndicator())
            else ...[
              _buildPlanListItem(
                AppLocalizations.getString(
                  'monthly_plan',
                  languageProvider.currentLanguage,
                ),
                _products.any((p) => p.id == AppConfig.monthlySubscriptionId)
                    ? _products.firstWhere((p) => p.id == AppConfig.monthlySubscriptionId).price
                    : '--',
                '/month',
                'monthly',
                AppLocalizations.getString(
                  'billed_monthly',
                  languageProvider.currentLanguage,
                ),
                themeProvider,
                isDarkMode,
              ),
              const SizedBox(height: 12),
              _buildPlanListItem(
                AppLocalizations.getString(
                  'yearly_plan',
                  languageProvider.currentLanguage,
                ),
                _products.any((p) => p.id == AppConfig.yearlySubscriptionId)
                    ? _products.firstWhere((p) => p.id == AppConfig.yearlySubscriptionId).price
                    : '--',
                '/year',
                'yearly',
                AppLocalizations.getString(
                  'billed_annually',
                  languageProvider.currentLanguage,
                ),
                themeProvider,
                isDarkMode,
                isPopular: true,
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildPlanListItem(
    String title,
    String price,
    String period,
    String planId,
    String description,
    ThemeProvider themeProvider,
    bool isDarkMode, {
    bool isPopular = false,
    bool isBestValue = false,
  }) {
    final languageProvider = Provider.of<LanguageProvider>(
      context,
      listen: false,
    );
    final isSelected = _selectedPlan == planId;
    final d = isDarkMode;

    return GestureDetector(
      onTap: () => setState(() => _selectedPlan = planId),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.skSurface(d) : AppColors.skPaper(d),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? AppColors.skInk(d) : AppColors.skRule(d),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            // Selection indicator
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? AppColors.skInk(d) : Colors.transparent,
                border: Border.all(
                  color: isSelected
                      ? AppColors.skInk(d)
                      : AppColors.skMuted(d),
                  width: 1.5,
                ),
              ),
              child: isSelected
                  ? Icon(
                      Icons.check,
                      color: AppColors.skPaper(d),
                      size: 14,
                    )
                  : null,
            ),
            const SizedBox(width: 16),

            // Plan details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: themeProvider.getSerifFont(
                            fontSize: 18,
                            color: AppColors.skInk(d),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isPopular) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.skSage(d),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            AppLocalizations.getString(
                              'popular',
                              languageProvider.currentLanguage,
                            ).toUpperCase(),
                            style: themeProvider.getSkLabel(
                              fontSize: 9,
                              color: AppColors.skPaper(d),
                            ),
                          ),
                        ),
                      ],
                      if (isBestValue) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.skSage(d),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            AppLocalizations.getString(
                              'best_value',
                              languageProvider.currentLanguage,
                            ).toUpperCase(),
                            style: themeProvider.getSkLabel(
                              fontSize: 9,
                              color: AppColors.skPaper(d),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: themeProvider.getBodyFont(
                      fontSize: 13,
                      color: AppColors.skMuted(d),
                    ),
                  ),
                ],
              ),
            ),

            // Price
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      price,
                      style: themeProvider.getSerifFont(
                        fontSize: 22,
                        color: AppColors.skInk(d),
                      ),
                    ),
                    Text(
                      period,
                      style: themeProvider.getBodyFont(
                        fontSize: 12,
                        color: AppColors.skMuted(d),
                      ),
                    ),
                  ],
                ),
                if (planId == 'yearly')
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      AppLocalizations.getString(
                        'save_percentage',
                        languageProvider.currentLanguage,
                      ),
                      style: themeProvider.getSkLabel(
                        fontSize: 10,
                        color: AppColors.skSage(d),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubscribeButton(
    SubscriptionProvider subscriptionProvider,
    ThemeProvider themeProvider,
    LanguageProvider languageProvider,
    bool isDarkMode,
  ) {
    return Column(
      children: [
        // Error message display
        if (subscriptionProvider.error != null)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(IconlyLight.danger, color: Colors.red, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _getLocalizedErrorMessage(
                      subscriptionProvider.error!,
                      languageProvider.currentLanguage,
                    ),
                    style: themeProvider.getFontForCurrentLanguage(
                      fontSize: 14,
                      color: Colors.red[700],
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => subscriptionProvider.clearError(),
                  icon: Icon(
                    IconlyLight.close_square,
                    color: Colors.red[700],
                    size: 18,
                  ),
                ),
              ],
            ),
          ),

        // Subscribe button
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: subscriptionProvider.isLoading
                ? null
                : () async {
                    // Clear any previous errors
                    subscriptionProvider.clearError();

                    // If no products loaded, show the error dialog
                    if (_products.isEmpty) {
                      StoreErrorDialog.show(context);
                      return;
                    }

                    bool success = false;
                    // Direct subscription
                    if (_selectedPlan == 'monthly') {
                      success = await subscriptionProvider.subscribeMonthly();
                    } else if (_selectedPlan == 'yearly') {
                      success = await subscriptionProvider.subscribeYearly();
                    }

                    if (success && mounted) {
                      Navigator.of(context).pop();
                    } else if (subscriptionProvider.error != null && mounted) {
                      // Error is already displayed above the button
                    }
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.skInk(isDarkMode),
              foregroundColor: AppColors.skPaper(isDarkMode),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
              elevation: 0,
            ),
            child: subscriptionProvider.isLoading
                ? SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: AppColors.skPaper(isDarkMode),
                      strokeWidth: 2,
                    ),
                  )
                : Text(
                    AppLocalizations.getString(
                      'subscribe_now',
                      languageProvider.currentLanguage,
                    ),
                    style: themeProvider.getBodyFont(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: AppColors.skPaper(isDarkMode),
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildTermsSection(
    ThemeProvider themeProvider,
    LanguageProvider languageProvider,
    bool isDarkMode,
    SubscriptionProvider subscriptionProvider,
  ) {
    final d = isDarkMode;
    return Column(
      children: [
        Text(
          AppLocalizations.getString(
            'subscription_terms_detailed',
            languageProvider.currentLanguage,
          ),
          style: themeProvider.getBodyFont(
            fontSize: 12,
            color: AppColors.skMuted(d),
            height: 1.4,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const TermsOfServiceScreen()),
                );
              },
              child: Text(
                AppLocalizations.getString(
                  'terms_of_service',
                  languageProvider.currentLanguage,
                ),
                style: themeProvider.getBodyFont(
                  fontSize: 12,
                  color: AppColors.skInk(d),
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
            Text(
              ' · ',
              style: TextStyle(
                color: AppColors.skMuted(d),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
                );
              },
              child: Text(
                AppLocalizations.getString(
                  'privacy_policy',
                  languageProvider.currentLanguage,
                ),
                style: themeProvider.getBodyFont(
                  fontSize: 12,
                  color: AppColors.skInk(d),
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: () async {
            final scaffoldMessenger = ScaffoldMessenger.of(context);
            final success = await subscriptionProvider.restoreSubscription();
            if (success) {
              scaffoldMessenger.showSnackBar(
                const SnackBar(
                  content: Text('Subscription successfully restored from cloud!'),
                  backgroundColor: Colors.green,
                ),
              );
            } else {
              scaffoldMessenger.showSnackBar(
                SnackBar(
                  content: Text(subscriptionProvider.error ?? 'Restoration failed'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
          child: Text(
            'Already subscribed? Restore',
            style: themeProvider.getBodyFont(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.skInk(d),
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCurrentSubscriptionSection(
    SubscriptionProvider subscriptionProvider,
    ThemeProvider themeProvider,
    LanguageProvider languageProvider,
    bool isDarkMode,
  ) {
    final subscriptionType = subscriptionProvider.subscriptionType ?? 'Unknown';
    String planName = '';
    String planDescription = '';

    switch (subscriptionType) {
        case 'monthly':
          planName = AppLocalizations.getString(
            'monthly_plan',
            languageProvider.currentLanguage,
          );
          planDescription = AppLocalizations.getString(
            'billed_monthly_desc',
            languageProvider.currentLanguage,
          );
          break;
        case 'yearly':
          planName = AppLocalizations.getString(
            'yearly_plan',
            languageProvider.currentLanguage,
          );
          planDescription = AppLocalizations.getString(
            'billed_annually_desc',
            languageProvider.currentLanguage,
          );
          break;
      }

    final d = isDarkMode;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.skSurface(d),
        border: Border.all(color: AppColors.skInk(d), width: 1.5),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ACTIVE',
            style: themeProvider.getSkLabel(
              fontSize: 11,
              color: AppColors.skSage(d),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            AppLocalizations.getString(
              'active_premium_subscription',
              languageProvider.currentLanguage,
            ),
            style: themeProvider.getSerifFont(
              fontSize: 24,
              color: AppColors.skInk(d),
            ),
          ),
          const SizedBox(height: 18),

          // Plan Details
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.skPaper(d),
              border: Border.all(color: AppColors.skRule(d)),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        planName,
                        style: themeProvider.getSerifFont(
                          fontSize: 18,
                          color: AppColors.skInk(d),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        planDescription,
                        style: themeProvider.getBodyFont(
                          fontSize: 13,
                          color: AppColors.skMuted(d),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCancelSubscriptionButton(
    SubscriptionProvider subscriptionProvider,
    ThemeProvider themeProvider,
    LanguageProvider languageProvider,
    bool isDarkMode,
  ) {
    final d = isDarkMode;
    return Column(
      children: [
        // Warning message
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.skSurface(d),
            border: Border.all(color: AppColors.skRule(d)),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline,
                  color: AppColors.skMuted(d), size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  AppLocalizations.getString(
                    'cancel_subscription_warning',
                    languageProvider.currentLanguage,
                  ),
                  style: themeProvider.getBodyFont(
                    fontSize: 13,
                    color: AppColors.skMuted(d),
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Cancel button
        SizedBox(
          width: double.infinity,
          height: 52,
          child: GestureDetector(
            onTap: subscriptionProvider.isLoading
                ? null
                : () => _showCancelConfirmationDialog(
                    subscriptionProvider,
                    themeProvider,
                    languageProvider,
                    isDarkMode,
                  ),
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFC44545),
                borderRadius: BorderRadius.circular(26),
              ),
              child: subscriptionProvider.isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      AppLocalizations.getString(
                        'cancel_subscription',
                        languageProvider.currentLanguage,
                      ),
                      style: themeProvider.getBodyFont(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }

  void _showCancelConfirmationDialog(
    SubscriptionProvider subscriptionProvider,
    ThemeProvider themeProvider,
    LanguageProvider languageProvider,
    bool isDarkMode,
  ) {
    final d = isDarkMode;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
          ),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: AppColors.skPaper(d),
              border: Border.all(color: AppColors.skRule(d)),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Center(
                  child: Text(
                    AppLocalizations.getString(
                      'cancel_subscription_question',
                      languageProvider.currentLanguage,
                    ),
                    style: themeProvider.getSerifFont(
                      fontSize: 22,
                      color: AppColors.skInk(d),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 14),

                // Description
                Text(
                  AppLocalizations.getString(
                    'cancel_subscription_description',
                    languageProvider.currentLanguage,
                  ),
                  style: themeProvider.getBodyFont(
                    fontSize: 14,
                    color: AppColors.skMuted(d),
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 18),

                // Warning Box
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.skSurface(d),
                    border: Border.all(color: AppColors.skRule(d)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: AppColors.skMuted(d),
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          AppLocalizations.getString(
                            'resubscribe_info',
                            languageProvider.currentLanguage,
                          ),
                          style: themeProvider.getBodyFont(
                            fontSize: 12,
                            color: AppColors.skMuted(d),
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Divider
                Divider(color: AppColors.skRule(d), height: 1),
                const SizedBox(height: 20),

                // Action Buttons
                Column(
                  children: [
                    // Keep Subscription Button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.skInk(d),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Text(
                            AppLocalizations.getString(
                              'keep_subscription',
                              languageProvider.currentLanguage,
                            ),
                            style: themeProvider.getBodyFont(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: AppColors.skPaper(d),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Cancel Subscription Button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: GestureDetector(
                        onTap: () async {
                          Navigator.of(context).pop();
                          await subscriptionProvider.cancelSubscription();
                        },
                        child: Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.transparent,
                            border: Border.all(color: const Color(0xFFC44545)),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Text(
                            AppLocalizations.getString(
                              'cancel_subscription',
                              languageProvider.currentLanguage,
                            ),
                            style: themeProvider.getBodyFont(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFFC44545),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
