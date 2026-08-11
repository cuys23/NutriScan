import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nutriscan/config/app_colors.dart';
import 'package:nutriscan/config/app_config.dart';
import 'package:nutriscan/config/app_localizations.dart';
import 'package:nutriscan/models/food.dart';
import 'package:nutriscan/providers/ads/admob_provider.dart';
import 'package:nutriscan/providers/auth/cloud_backup_provider.dart';
import 'package:nutriscan/providers/coins/coin_provider.dart';
import 'package:nutriscan/providers/food/food_provider.dart';
import 'package:nutriscan/providers/food/meal_plan_provider.dart';
import 'package:nutriscan/providers/payment/subscription_provider.dart';
import 'package:nutriscan/providers/theme/language_provider.dart';
import 'package:nutriscan/providers/theme/theme_provider.dart';
import 'package:nutriscan/screens/chat/health_coach_screen.dart';
import 'package:nutriscan/screens/food/meal_plan_screen.dart';
import 'package:nutriscan/screens/legal/privacy_policy_screen.dart';
import 'package:nutriscan/screens/legal/terms_of_service_screen.dart';
import 'package:nutriscan/screens/settings/app_version_screen.dart';
import 'package:nutriscan/screens/settings/cloud_backup_screen.dart';
import 'package:nutriscan/screens/settings/notification_settings_screen.dart';
import 'package:nutriscan/screens/subscription/subscription_screen.dart';
import 'package:nutriscan/services/ai/groq_service.dart';
import 'package:nutriscan/services/media/image_picker_service.dart';
import 'package:nutriscan/utils/page_transition.dart';
import 'package:nutriscan/widgets/ads/adaptive_banner_ad.dart';
import 'package:nutriscan/widgets/common/language_dropdown.dart';
import 'package:nutriscan/widgets/dialogs/coin_ad_dialogs.dart';
import 'package:nutriscan/widgets/food/active_meal_plan_card.dart';
import 'package:nutriscan/widgets/food/food_detail_card.dart';
import 'package:nutriscan/widgets/home/sk_scan_button.dart';
import 'package:nutriscan/widgets/home/sk_tab_bar.dart';
import 'package:nutriscan/widgets/scan/multi_food_review_sheet.dart';
import 'package:provider/provider.dart';

/// ─────────────────────────────────────────────────────────────
/// Slow Kitchen — the main app shell.
/// Embeds Today, History, Trends, Coach and You as body tabs.
/// ─────────────────────────────────────────────────────────────
class SlowKitchenHome extends StatefulWidget {
  const SlowKitchenHome({super.key});

  @override
  State<SlowKitchenHome> createState() => _SlowKitchenHomeState();
}

class _SlowKitchenHomeState extends State<SlowKitchenHome>
    with TickerProviderStateMixin {
  // ── state ──────────────────────────────────────────────────
  final ImagePickerService _imagePickerService = ImagePickerService();
  String _activeTab = 'today';
  bool _isInitialLoading = true;
  bool _multiFoodSheetOpen = false;
  bool _condensed = false;
  final int _dailyTarget = 2000;

  late AnimationController _loadingController;

  // ── lifecycle ──────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _loadingController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeData();
      _setupErrorListener();
      _setupMultiFoodListener();
    });
  }

  @override
  void dispose() {
    _loadingController.dispose();
    try {
      final foodProvider = context.read<FoodProvider>();
      foodProvider.removeListener(_setupErrorListener);
    } catch (_) {}
    super.dispose();
  }

  Future<void> _initializeData() async {
    try {
      final foodProvider = context.read<FoodProvider>();
      final mealPlanProvider = context.read<MealPlanProvider>();
      await Future.delayed(const Duration(milliseconds: 800));
      await Future.wait([
        foodProvider.loadFoods(),
        mealPlanProvider.loadActiveMealPlan(),
      ]);
      if (mounted) setState(() => _isInitialLoading = false);
    } catch (_) {
      if (mounted) setState(() => _isInitialLoading = false);
    }
  }

  void _setupErrorListener() {
    final foodProvider = context.read<FoodProvider>();
    foodProvider.addListener(() {
      if (mounted && foodProvider.error == 'NOT_FOOD_IMAGE') {
        foodProvider.clearError();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            final currentLanguage =
                context.read<LanguageProvider>().currentLanguage;
            GroqService.showNonFoodImageDialog(context,
                language: currentLanguage);
          }
        });
      }
    });
  }

  void _setupMultiFoodListener() {
    final foodProvider = context.read<FoodProvider>();
    foodProvider.addListener(() {
      final pending = foodProvider.pendingMultiFoodCandidates;
      if (!mounted ||
          pending == null ||
          pending.isEmpty ||
          _multiFoodSheetOpen) {
        return;
      }
      _multiFoodSheetOpen = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) {
          _multiFoodSheetOpen = false;
          return;
        }
        final currentLanguage =
            context.read<LanguageProvider>().currentLanguage;
        await showModalBottomSheet(
          context: context,
          isDismissible: false,
          enableDrag: false,
          isScrollControlled: true,
          builder: (_) => MultiFoodReviewSheet(
            candidates: pending,
            currentLanguage: currentLanguage,
          ),
        );
        _multiFoodSheetOpen = false;
      });
    });
  }

  // ── scan logic (preserved from original) ───────────────────
  Future<void> _showImageSourceSheet() async {
    final tp = Provider.of<ThemeProvider>(context, listen: false);
    final d = tp.isDarkMode;
    final coinProvider = context.read<CoinProvider>();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.fromLTRB(28, 28, 28, 36),
        decoration: BoxDecoration(
          color: AppColors.skPaper(d),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.skRule(d),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 22),
            Text(
              'How shall we look?',
              style: tp.getSerifFont(
                fontSize: 28,
                color: AppColors.skInk(d),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'One coin per scan. You have ${coinProvider.coinBalance}.',
              style: tp.getBodyFont(
                fontSize: 14,
                color: AppColors.skMuted(d),
              ),
            ),
            const SizedBox(height: 24),
            _buildSheetRow(
              icon: Icons.camera_alt_outlined,
              label: 'Camera',
              hint: 'Take a photo of your plate',
              onTap: () {
                Navigator.pop(context);
                _takePhotoFromCamera();
              },
              d: d,
              tp: tp,
            ),
            Container(height: 1, color: AppColors.skRule(d)),
            _buildSheetRow(
              icon: Icons.photo_library_outlined,
              label: 'Gallery',
              hint: 'Pick an existing photo',
              onTap: () {
                Navigator.pop(context);
                _pickImageFromGallery();
              },
              d: d,
              tp: tp,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSheetRow({
    required IconData icon,
    required String label,
    required String hint,
    required VoidCallback onTap,
    required bool d,
    required ThemeProvider tp,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 17),
        child: Row(
          children: [
            Icon(icon, size: 22, color: AppColors.skInk(d)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: tp.getBodyFont(
                          fontSize: 16, color: AppColors.skInk(d))),
                  Text(hint,
                      style: tp.getBodyFont(
                          fontSize: 13, color: AppColors.skMuted(d))),
                ],
              ),
            ),
            Icon(Icons.chevron_right,
                size: 18, color: AppColors.skMuted(d)),
          ],
        ),
      ),
    );
  }

  Future<void> _takePhotoFromCamera() async {
    try {
      final sub = context.read<SubscriptionProvider>();
      final ad = context.read<AdMobProvider>();
      final coin = context.read<CoinProvider>();
      if (!sub.hasPremiumFeatures && !coin.canScan()) {
        _showNoCoinDialog();
        return;
      }
      File? file = await _imagePickerService.takePhotoFromCamera();
      if (file != null && mounted) {
        final lang = context.read<LanguageProvider>().currentLanguage;
        if (mounted) {
          await context.read<FoodProvider>().analyzeFoodImage(file,
              language: lang, isPremiumUser: sub.hasPremiumFeatures);
          ad.trackScan();
          await ad.showInterstitialAfterScans();
        }
      }
    } catch (_) {}
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final sub = context.read<SubscriptionProvider>();
      final ad = context.read<AdMobProvider>();
      final coin = context.read<CoinProvider>();
      if (!sub.hasPremiumFeatures && !coin.canScan()) {
        _showNoCoinDialog();
        return;
      }
      File? file = await _imagePickerService.pickImageFromGallery();
      if (file != null && mounted) {
        final lang = context.read<LanguageProvider>().currentLanguage;
        if (mounted) {
          await context.read<FoodProvider>().analyzeFoodImage(file,
              language: lang, isPremiumUser: sub.hasPremiumFeatures);
          ad.trackScan();
          await ad.showInterstitialAfterScans();
        }
      }
    } catch (_) {}
  }

  void _showNoCoinDialog() {
    final tp = Provider.of<ThemeProvider>(context, listen: false);
    final lp = Provider.of<LanguageProvider>(context, listen: false);
    final d = tp.isDarkMode;
    final lang = lp.currentLanguage;

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: AppColors.skPaper(d),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.toll, size: 48, color: AppColors.skAccent(d)),
              const SizedBox(height: 18),
              Text(
                AppLocalizations.getString('not_enough_coins', lang),
                style: tp.getSerifFont(
                    fontSize: 24, color: AppColors.skInk(d)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                AppLocalizations.getString(
                    'not_enough_coins_description', lang),
                style: tp.getBodyFont(
                    fontSize: 14,
                    color: AppColors.skBody(d),
                    height: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: () async {
                  Navigator.of(ctx).pop();
                  final admob = context.read<AdMobProvider>();
                  final coin = context.read<CoinProvider>();
                  final backup = context.read<CloudBackupProvider>();
                  await admob
                      .showRewardedAd(
                    isLoggedIn: backup.isSignedIn,
                    onRewardEarned: (amount, type) async {
                      await coin.addCoins(CoinProvider.coinsPerAd);
                      if (mounted) {
                        CoinAdDialogs.showCoinEarnedDialog(
                            context, CoinProvider.coinsPerAd);
                      }
                    },
                  )
                      .then((ok) {
                    if (!ok && mounted) {
                      CoinAdDialogs.showAdNotAvailableDialog(context);
                    }
                  });
                },
                child: Container(
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppColors.skInk(d),
                    borderRadius: BorderRadius.circular(26),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.play_circle_fill,
                          size: 20, color: AppColors.skPaper(d)),
                      const SizedBox(width: 8),
                      Text(
                        AppLocalizations.getString(
                            'watch_ad_earn_coins', lang),
                        style: tp.getBodyFont(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: AppColors.skPaper(d),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(
                  AppLocalizations.getString('cancel', lang),
                  style: tp.getBodyFont(
                      fontSize: 14, color: AppColors.skMuted(d)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── build ──────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Consumer3<ThemeProvider, LanguageProvider, FoodProvider>(
      builder: (context, tp, lp, fp, _) {
        final d = tp.isDarkMode;

        return Scaffold(
          backgroundColor: AppColors.skPaper(d),
          body: SafeArea(
            bottom: false,
            child: Column(
              children: [
                // Body
                Expanded(
                  child: _isInitialLoading
                      ? _buildSkLoading(tp, d)
                      : fp.isLoading
                          ? _buildSkScanning(tp, d)
                          : _buildTabBody(tp, lp, fp, d),
                ),
                // Scan button (only on Today & History)
                if (!_isInitialLoading &&
                    !fp.isLoading &&
                    (_activeTab == 'today' || _activeTab == 'history'))
                  SkScanButton(
                    onTap: _showImageSourceSheet,
                    isDarkMode: d,
                    themeProvider: tp,
                  ),
                // Tab bar
                SkTabBar(
                  activeTab: _activeTab,
                  onTabChanged: (tab) =>
                      setState(() {
                        _activeTab = tab;
                        _condensed = false;
                      }),
                  isDarkMode: d,
                  themeProvider: tp,
                ),
                // Ad banner
                const AdaptiveBannerAd(),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── tab body router ────────────────────────────────────────
  Widget _buildTabBody(
      ThemeProvider tp, LanguageProvider lp, FoodProvider fp, bool d) {
    switch (_activeTab) {
      case 'today':
        return _buildTodayTab(tp, lp, fp, d);
      case 'history':
        return _buildHistoryTab(tp, lp, fp, d);
      case 'trends':
        return _buildTrendsTab(tp, fp, d);
      case 'coach':
        return _buildCoachTab(tp, d);
      case 'you':
        return _buildYouTab(tp, lp, d);
      default:
        return _buildTodayTab(tp, lp, fp, d);
    }
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // TODAY TAB
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Widget _buildTodayTab(
      ThemeProvider tp, LanguageProvider lp, FoodProvider fp, bool d) {
    final meals = fp.getTodayFoodsSync();
    final cal = fp.getTodayCaloriesSync();
    final protein = fp.getTodayProteinSync();
    final carbs = fp.getTodayCarbsSync();
    final fat = fp.getTodayFatSync();
    final now = DateTime.now();
    final dateStr =
        DateFormat('EEEE, d MMMM').format(now);

    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n is ScrollUpdateNotification) {
          final c = n.metrics.pixels > 170;
          if (c != _condensed) setState(() => _condensed = c);
        }
        return false;
      },
      child: Stack(
        children: [
          SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(28, 12, 28, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date label
                Text(
                  dateStr.toUpperCase(),
                  style: tp.getSkLabel(color: AppColors.skMuted(d)),
                ),
                const SizedBox(height: 14),
                // Large calorie number
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      cal.toStringAsFixed(0),
                      style: tp.getSerifFont(
                          fontSize: 82,
                          color: AppColors.skInk(d),
                          height: 0.9),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'of $_dailyTarget kcal',
                          style: tp.getBodyFont(
                              fontSize: 13, color: AppColors.skMuted(d)),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${((cal / _dailyTarget) * 100).round()}%',
                          style: tp.getBodyFont(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppColors.skAccent(d),
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Calorie progress bar
                Container(
                  height: 2,
                  decoration: BoxDecoration(
                    color: AppColors.skRuleSoft(d),
                    borderRadius: BorderRadius.circular(1),
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor:
                          (cal / _dailyTarget).clamp(0, 1).toDouble(),
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.skAccent(d),
                          borderRadius: BorderRadius.circular(1),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                // Macro row
                _buildMacroRow(tp, d, protein, carbs, fat),
                const SizedBox(height: 26),
                // Remaining / projected
                _buildDayInfo(tp, d, cal, meals),
                const SizedBox(height: 22),
                // Active Meal Plan (if any)
                Consumer<MealPlanProvider>(
                  builder: (context, mealPlanProvider, _) {
                    final activePlan = mealPlanProvider.activePlan;
                    if (activePlan == null) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 22),
                      child: ActiveMealPlanCard(
                        plan: activePlan,
                        language: Provider.of<LanguageProvider>(context, listen: false).currentLanguage,
                        themeProvider: tp,
                        isDarkMode: d,
                        onTap: () {
                          mealPlanProvider.showActivePlan();
                          Navigator.push(
                            context,
                            PageTransition(
                              child: const MealPlanPreferencesScreen(),
                            ),
                          );
                        },
                        onDismiss: () {
                          mealPlanProvider.dismissMealPlan();
                        },
                      ),
                    );
                  },
                ),
                // Section header
                Text(
                  'TODAY\'S MEALS',
                  style: tp.getSkLabel(
                      fontSize: 11, color: AppColors.skMuted(d)),
                ),
                const SizedBox(height: 14),
                // Meal list
                if (meals.isEmpty)
                  _buildEmptyState(tp, d)
                else
                  ...meals.asMap().entries.map(
                      (e) => _buildMealRow(tp, d, e.value, e.key)),
              ],
            ),
          ),
          // Condensed header
          if (_condensed) _buildCondensedHeader(tp, d, cal),
        ],
      ),
    );
  }

  Widget _buildMacroRow(
      ThemeProvider tp, bool d, double protein, double carbs, double fat) {
    return Row(
      children: [
        _buildMacroItem(tp, d, 'Protein', '${protein.toStringAsFixed(1)}g',
            protein / 95, AppColors.skSage(d)),
        const SizedBox(width: 20),
        _buildMacroItem(tp, d, 'Carbs', '${carbs.toStringAsFixed(0)}g',
            carbs / 210, AppColors.skAccent(d)),
        const SizedBox(width: 20),
        _buildMacroItem(tp, d, 'Fat', '${fat.toStringAsFixed(1)}g',
            fat / 65, AppColors.skMuted(d)),
      ],
    );
  }

  Widget _buildMacroItem(ThemeProvider tp, bool d, String label, String value,
      double pct, Color color) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label,
                  style: tp.getBodyFont(
                      fontSize: 11,
                      color: AppColors.skMuted(d),
                      letterSpacing: 1.2)),
              Text(value,
                  style: tp.getBodyFont(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.skInk(d))),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            height: 3,
            decoration: BoxDecoration(
              color: AppColors.skRuleSoft(d),
              borderRadius: BorderRadius.circular(1.5),
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: pct.clamp(0, 1).toDouble(),
                child: Container(
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(1.5),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayInfo(
      ThemeProvider tp, bool d, double cal, List<Food> meals) {
    final left = _dailyTarget - cal;
    final leftStr = left >= 0
        ? '${left.toStringAsFixed(0)} kcal left today'
        : '${(-left).toStringAsFixed(0)} kcal over target';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.skSurface(d),
        border: Border.all(color: AppColors.skRule(d)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  leftStr,
                  style: tp.getBodyFont(
                      fontSize: 14, color: AppColors.skBody(d)),
                ),
                if (meals.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    '${meals.length} ${meals.length == 1 ? 'meal' : 'meals'} logged',
                    style: tp.getBodyFont(
                        fontSize: 13, color: AppColors.skMuted(d)),
                  ),
                ],
              ],
            ),
          ),
          Text(
            '${((cal / _dailyTarget) * 100).round()}%',
            style: tp.getSerifFont(
                fontSize: 28, color: AppColors.skAccent(d)),
          ),
        ],
      ),
    );
  }

  Widget _buildMealRow(ThemeProvider tp, bool d, Food food, int index) {
    final timeStr = DateFormat('HH:mm').format(food.analyzedAt);
    return GestureDetector(
      onTap: () => _showFoodDetail(food),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: AppColors.skRule(d), width: 1),
          ),
        ),
        child: Row(
          children: [
            // Score circle
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: food.healthScore >= 7
                      ? AppColors.skSage(d)
                      : food.healthScore >= 5
                          ? AppColors.skAccent(d)
                          : AppColors.skMuted(d),
                  width: 1.5,
                ),
              ),
              child: Center(
                child: Text(
                  '${food.healthScore}',
                  style: tp.getSerifFont(
                    fontSize: 18,
                    color: AppColors.skInk(d),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            // Name + time
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    food.name,
                    style: tp.getBodyFont(
                        fontSize: 16, color: AppColors.skInk(d)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        timeStr,
                        style: tp.getBodyFont(
                            fontSize: 13, color: AppColors.skMuted(d)),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        food.source == 'verified' ? 'Verified' : 'AI estimate',
                        style: tp.getBodyFont(
                          fontSize: 12,
                          color: food.source == 'verified'
                              ? AppColors.skSage(d)
                              : AppColors.skMuted(d),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Kcal
            Text(
              food.calories.toStringAsFixed(0),
              style: tp.getSerifFont(
                  fontSize: 22, color: AppColors.skInk(d)),
            ),
          ],
        ),
      ),
    );
  }

  void _showFoodDetail(Food food) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (sheetCtx, controller) {
          final tp = Provider.of<ThemeProvider>(context, listen: false);
          final d = tp.isDarkMode;
          return Container(
            decoration: BoxDecoration(
              color: d ? AppColors.surfaceDark : AppColors.surfaceLight,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: SingleChildScrollView(
              controller: controller,
              child: FoodDetailCard(
                food: food,
                onFoodDeleted: () {
                  Navigator.pop(sheetCtx);
                },
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCondensedHeader(ThemeProvider tp, bool d, double cal) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          28, MediaQuery.of(context).padding.top > 0 ? 8 : 12, 28, 12),
      decoration: BoxDecoration(
        color: AppColors.skPaper(d),
        border: Border(
          bottom: BorderSide(color: AppColors.skRule(d), width: 1),
        ),
      ),
      child: Row(
        children: [
          Text(
            cal.toStringAsFixed(0),
            style: tp.getSerifFont(
                fontSize: 26, color: AppColors.skInk(d)),
          ),
          const SizedBox(width: 8),
          Text(
            'of $_dailyTarget kcal',
            style: tp.getBodyFont(
                fontSize: 13, color: AppColors.skMuted(d)),
          ),
          const Spacer(),
          Text(
            '${((cal / _dailyTarget) * 100).round()}%',
            style: tp.getBodyFont(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.skAccent(d),
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeProvider tp, bool d) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Center(
        child: Column(
          children: [
            Text(
              '·',
              style: tp.getSerifFont(
                  fontSize: 48, color: AppColors.skFaint(d)),
            ),
            const SizedBox(height: 12),
            Text(
              'No meals yet today',
              style: tp.getSerifFont(
                  fontSize: 24, color: AppColors.skInk(d)),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap "Scan a meal" to start',
              style: tp.getBodyFont(
                  fontSize: 14, color: AppColors.skMuted(d)),
            ),
          ],
        ),
      ),
    );
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // HISTORY TAB
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Widget _buildHistoryTab(
      ThemeProvider tp, LanguageProvider lp, FoodProvider fp, bool d) {
    final all = fp.foods;

    // Group by date
    final Map<String, List<Food>> grouped = {};
    for (final f in all) {
      final key = DateFormat('EEEE, d MMMM').format(f.analyzedAt);
      grouped.putIfAbsent(key, () => []);
      grouped[key]!.add(f);
    }

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(28, 12, 28, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Text(
            'HISTORY',
            style: tp.getSkLabel(color: AppColors.skMuted(d)),
          ),
          const SizedBox(height: 6),
          Text(
            'Everything logged',
            style: tp.getSerifFont(
                fontSize: 32, color: AppColors.skInk(d)),
          ),
          const SizedBox(height: 20),

          if (all.isEmpty)
            _buildEmptyState(tp, d)
          else
            ...grouped.entries.map((entry) {
              final dayTotal =
                  entry.value.fold(0.0, (s, f) => s + f.calories);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Day header
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          entry.key.toUpperCase(),
                          style: tp.getSkLabel(
                              fontSize: 11,
                              color: AppColors.skMuted(d)),
                        ),
                        Text(
                          '${dayTotal.toStringAsFixed(0)} kcal',
                          style: tp.getBodyFont(
                              fontSize: 13,
                              color: AppColors.skMuted(d)),
                        ),
                      ],
                    ),
                  ),
                  ...entry.value.asMap().entries.map(
                      (e) => _buildMealRow(tp, d, e.value, e.key)),
                  const SizedBox(height: 12),
                ],
              );
            }),
        ],
      ),
    );
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // TRENDS TAB
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Widget _buildTrendsTab(ThemeProvider tp, FoodProvider fp, bool d) {
    final all = fp.foods;
    final avgScore = all.isEmpty
        ? 0.0
        : all.fold(0.0, (s, f) => s + f.healthScore) / all.length;

    // Last 7 days data
    final now = DateTime.now();
    final weekData = <String, double>{};
    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final key = DateFormat('E').format(date);
      weekData[key] = 0;
    }
    for (final f in all) {
      final diff = now.difference(f.analyzedAt).inDays;
      if (diff < 7) {
        final key = DateFormat('E').format(f.analyzedAt);
        weekData[key] = (weekData[key] ?? 0) + f.calories;
      }
    }
    final maxCal =
        weekData.values.fold(1.0, (a, b) => a > b ? a : b);

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(28, 12, 28, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'THIS WEEK',
            style: tp.getSkLabel(color: AppColors.skMuted(d)),
          ),
          const SizedBox(height: 6),
          Text(
            'Seven-day review',
            style: tp.getSerifFont(
                fontSize: 32, color: AppColors.skInk(d)),
          ),
          const SizedBox(height: 28),

          // Weekly bars
          SizedBox(
            height: 180,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: weekData.entries.map((e) {
                final pct = (e.value / maxCal).clamp(0, 1).toDouble();
                return Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (e.value > 0)
                        Text(
                          e.value.toStringAsFixed(0),
                          style: tp.getBodyFont(
                              fontSize: 11,
                              color: AppColors.skMuted(d)),
                        ),
                      const SizedBox(height: 6),
                      Container(
                        height: pct * 130,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: AppColors.skInk(d),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        e.key,
                        style: tp.getBodyFont(
                          fontSize: 11,
                          color: AppColors.skMuted(d),
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 30),
          Container(height: 1, color: AppColors.skInk(d)),
          const SizedBox(height: 20),

          // Stats row
          Row(
            children: [
              _buildStatItem(tp, d, 'TOTAL',
                  weekData.values.fold(0.0, (a, b) => a + b).toStringAsFixed(0)),
              _buildStatItem(tp, d, 'DAILY',
                  (weekData.values.fold(0.0, (a, b) => a + b) / 7).toStringAsFixed(0)),
              _buildStatItem(tp, d, 'SCORE', avgScore.toStringAsFixed(1)),
            ],
          ),
          const SizedBox(height: 30),

          // Health score
          Text(
            'HEALTH SCORES',
            style: tp.getSkLabel(
                fontSize: 11, color: AppColors.skMuted(d)),
          ),
          const SizedBox(height: 14),
          // Score distribution bars
          _buildScoreDistribution(tp, d, all),
          const SizedBox(height: 30),

          // Insight box
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.skRule(d)),
              color: AppColors.skSurface(d),
            ),
            child: Text(
              all.isEmpty
                  ? 'Start logging meals to see trends and insights here.'
                  : 'You average ${avgScore.toStringAsFixed(1)} out of 10. Broth-based bowls and fresh rolls score highest — keeping fried and rice-heavy plates to twice a week would lift the score.',
              style: tp.getBodyFont(
                  fontSize: 15,
                  height: 1.6,
                  color: AppColors.skBody(d)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
      ThemeProvider tp, bool d, String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: tp.getBodyFont(
              fontSize: 11,
              color: AppColors.skMuted(d),
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: tp.getSerifFont(
                fontSize: 30, color: AppColors.skInk(d)),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreDistribution(
      ThemeProvider tp, bool d, List<Food> all) {
    final counts = List.filled(10, 0);
    for (final f in all) {
      final idx = (f.healthScore - 1).clamp(0, 9);
      counts[idx]++;
    }
    final maxCount = counts.fold(1, (a, b) => a > b ? a : b);

    return SizedBox(
      height: 120,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(10, (i) {
          final pct = (counts[i] / maxCount).clamp(0, 1).toDouble();
          final color = i >= 7
              ? AppColors.skSage(d)
              : i >= 5
                  ? AppColors.skAccent(d)
                  : AppColors.skFaint(d);
          return Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  height: (pct * 80).clamp(2, 80),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  color: color,
                ),
                const SizedBox(height: 6),
                Text(
                  '${i + 1}',
                  style: tp.getBodyFont(
                      fontSize: 11, color: AppColors.skMuted(d)),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // COACH TAB
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Widget _buildCoachTab(ThemeProvider tp, bool d) {
    return const HealthCoachScreen(showAppBar: false);
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // YOU TAB
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Widget _buildYouTab(ThemeProvider tp, LanguageProvider lp, bool d) {
    final coinProvider = context.watch<CoinProvider>();
    final fp = context.watch<FoodProvider>();
    final backupProvider = context.watch<CloudBackupProvider>();
    final subProvider = context.watch<SubscriptionProvider>();
    final all = fp.foods;
    final avgScore = all.isEmpty
        ? 0.0
        : all.fold(0.0, (s, f) => s + f.healthScore) / all.length;
    final lang = lp.currentLanguage;

    final user = backupProvider.isSignedIn
        ? FirebaseAuth.instance.currentUser
        : null;
    final displayName = user?.displayName ?? user?.email?.split('@').first;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(28, 12, 28, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Profile header
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border:
                      Border.all(color: AppColors.skRule(d), width: 1.5),
                ),
                child: Center(
                  child: Text(
                    displayName?.isNotEmpty == true
                        ? displayName![0].toUpperCase()
                        : '?',
                    style: tp.getSerifFont(
                        fontSize: 24, color: AppColors.skInk(d)),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName ?? 'Guest',
                      style: tp.getSerifFont(
                          fontSize: 28, color: AppColors.skInk(d)),
                    ),
                    Text(
                      '${coinProvider.coinBalance} ${AppLocalizations.getString('coins', lang)}',
                      style: tp.getBodyFont(
                          fontSize: 13, color: AppColors.skMuted(d)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          // Stats
          Row(
            children: [
              _buildProfileStat(
                  tp, d, '${all.length}', 'Meals'),
              _buildProfileStat(
                  tp, d, avgScore.toStringAsFixed(1), 'Avg score'),
              _buildProfileStat(
                  tp, d, '${coinProvider.coinBalance}', AppLocalizations.getString('coins', lang)),
            ],
          ),
          const SizedBox(height: 10),

          // ── Earn coins ──
          _buildSettingSection(tp, d, AppLocalizations.getString('earn_coins', lang), [
            _buildSettingRow(tp, d, AppLocalizations.getString('watch_ad_earn_coins', lang),
                hint: 'Watch a short ad to earn scan coins',
                onTap: () async {
              final admob = context.read<AdMobProvider>();
              final coin = context.read<CoinProvider>();
              final backup = context.read<CloudBackupProvider>();
              await admob
                  .showRewardedAd(
                isLoggedIn: backup.isSignedIn,
                onRewardEarned: (amount, type) async {
                  await coin.addCoins(CoinProvider.coinsPerAd);
                  if (mounted) {
                    CoinAdDialogs.showCoinEarnedDialog(
                        context, CoinProvider.coinsPerAd);
                  }
                },
              )
                  .then((ok) {
                if (!ok && mounted) {
                  CoinAdDialogs.showAdNotAvailableDialog(context);
                }
              });
            }),
          ]),

          // ── Subscription ──
          _buildSettingSection(tp, d, AppLocalizations.getString('subscription', lang), [
            _buildSettingRow(tp, d,
                subProvider.isSubscribed
                    ? AppLocalizations.getString('premium_active', lang)
                    : AppLocalizations.getString('upgrade_to_premium', lang),
                hint: subProvider.isSubscribed
                    ? AppLocalizations.getString('manage_subscription', lang)
                    : AppLocalizations.getString('remove_ads_unlock_features', lang),
                onTap: () {
              Navigator.push(context,
                  PageTransition(child: const SubscriptionScreen()));
            }),
          ]),

          // ── Your diary ──
          _buildSettingSection(tp, d, AppLocalizations.getString('notification_settings', lang), [
            _buildSettingRow(tp, d,
                AppLocalizations.getString('notification_settings', lang),
                hint: AppLocalizations.getString('notification_settings_subtitle', lang),
                onTap: () {
              Navigator.push(context,
                  PageTransition(child: const NotificationSettingsScreen()));
            }),
          ]),

          // ── The app ──
          _buildSettingSection(tp, d, AppLocalizations.getString('app_settings', lang), [
            _buildSettingToggleRow(tp, d,
                AppLocalizations.getString('dark_mode', lang),
                hint: AppLocalizations.getString('dark_mode_subtitle', lang),
                value: tp.isDarkMode, onTap: () {
              tp.toggleTheme();
            }),
            _buildSettingRowWithTrailing(tp, d,
                AppLocalizations.getString('language', lang),
                hint: AppLocalizations.getString('language_subtitle', lang),
                trailing: const LanguageDropdown()),
          ]),

          // ── Data & privacy ──
          _buildSettingSection(tp, d, AppLocalizations.getString('data_privacy', lang), [
            _buildSettingRow(tp, d,
                AppLocalizations.getString('cloud_backup_settings', lang),
                hint: AppLocalizations.getString('cloud_backup_settings_subtitle', lang),
                onTap: () {
              Navigator.push(context,
                  PageTransition(child: const CloudBackupScreen()));
            }),
          ]),

          // ── About ──
          _buildSettingSection(tp, d, AppLocalizations.getString('about', lang), [
            _buildSettingRow(tp, d,
                AppLocalizations.getString('privacy_policy', lang),
                hint: AppLocalizations.getString('privacy_policy_subtitle', lang),
                onTap: () {
              Navigator.push(context,
                  PageTransition(child: const PrivacyPolicyScreen()));
            }),
            _buildSettingRow(tp, d,
                AppLocalizations.getString('terms_of_service', lang),
                hint: AppLocalizations.getString('terms_of_service_subtitle', lang),
                onTap: () {
              Navigator.push(context,
                  PageTransition(child: const TermsOfServiceScreen()));
            }),
            _buildSettingRow(tp, d,
                AppLocalizations.getString('app_version', lang),
                value: AppConfig.appVersion, showChevron: false,
                onTap: () {
              Navigator.push(context,
                  PageTransition(child: const AppVersionScreen()));
            }),
          ]),
        ],
      ),
    );
  }

  Widget _buildProfileStat(
      ThemeProvider tp, bool d, String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: AppColors.skRule(d)),
          ),
        ),
        child: Column(
          children: [
            Text(value,
                style: tp.getSerifFont(
                    fontSize: 24, color: AppColors.skInk(d))),
            const SizedBox(height: 4),
            Text(label,
                style: tp.getBodyFont(
                    fontSize: 12, color: AppColors.skMuted(d))),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingSection(
      ThemeProvider tp, bool d, String title, List<Widget> rows) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 20, bottom: 10),
          child: Text(
            title.toUpperCase(),
            style: tp.getSkLabel(
                fontSize: 11, color: AppColors.skMuted(d)),
          ),
        ),
        ...rows,
      ],
    );
  }

  Widget _buildSettingRow(ThemeProvider tp, bool d, String label,
      {String? hint, String? value, bool showChevron = true,
       VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: AppColors.skRule(d)),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: tp.getBodyFont(
                          fontSize: 16, color: AppColors.skInk(d))),
                  if (hint != null)
                    Text(hint,
                        style: tp.getBodyFont(
                            fontSize: 13, color: AppColors.skMuted(d))),
                ],
              ),
            ),
            if (value != null)
              Text(value,
                  style: tp.getBodyFont(
                      fontSize: 14, color: AppColors.skMuted(d))),
            if (showChevron) ...[
              const SizedBox(width: 8),
              Icon(Icons.chevron_right,
                  size: 18, color: AppColors.skMuted(d)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSettingRowWithTrailing(ThemeProvider tp, bool d, String label,
      {String? hint, required Widget trailing}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 15),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: AppColors.skRule(d)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: tp.getBodyFont(
                        fontSize: 16, color: AppColors.skInk(d))),
                if (hint != null)
                  Text(hint,
                      style: tp.getBodyFont(
                          fontSize: 13, color: AppColors.skMuted(d))),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }

  Widget _buildSettingToggleRow(ThemeProvider tp, bool d, String label,
      {String? hint, required bool value, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: AppColors.skRule(d)),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: tp.getBodyFont(
                          fontSize: 16, color: AppColors.skInk(d))),
                  if (hint != null)
                    Text(hint,
                        style: tp.getBodyFont(
                            fontSize: 13, color: AppColors.skMuted(d))),
                ],
              ),
            ),
            // Toggle
            Container(
              width: 46,
              height: 26,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: value
                    ? AppColors.skSage(d)
                    : AppColors.skRule(d),
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 200),
                alignment: value
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
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
          ],
        ),
      ),
    );
  }

  // ── loading states ─────────────────────────────────────────
  Widget _buildSkLoading(ThemeProvider tp, bool d) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.skMuted(d),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Loading your diary',
            style: tp.getBodyFont(
                fontSize: 14, color: AppColors.skMuted(d)),
          ),
        ],
      ),
    );
  }

  Widget _buildSkScanning(ThemeProvider tp, bool d) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.skAccent(d),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Reading your plate',
            style: tp.getSerifFont(
                fontSize: 20, color: AppColors.skInk(d)),
          ),
          const SizedBox(height: 6),
          Text(
            'Matching ingredients and estimating nutrients',
            style: tp.getBodyFont(
                fontSize: 13, color: AppColors.skMuted(d)),
          ),
        ],
      ),
    );
  }
}

