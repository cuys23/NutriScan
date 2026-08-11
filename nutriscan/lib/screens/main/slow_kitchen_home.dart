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
import 'package:nutriscan/screens/analysis/sk_ledger_screen.dart';
import 'package:nutriscan/screens/analysis/sk_weekly_review_screen.dart';
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
import 'package:nutriscan/widgets/analysis/sk_line_chart.dart';
import 'package:nutriscan/widgets/common/language_dropdown.dart';
import 'package:nutriscan/widgets/common/sk_torn_divider.dart';
import 'package:nutriscan/widgets/dialogs/coin_ad_dialogs.dart';
import 'package:nutriscan/widgets/common/sk_snackbar.dart';
import 'package:nutriscan/widgets/settings/delete_account_dialog.dart';
import 'package:nutriscan/widgets/food/active_meal_plan_card.dart';
import 'package:nutriscan/widgets/food/food_detail_card.dart';
import 'package:nutriscan/widgets/home/sk_day_timeline.dart';
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

  // History tab
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  String _sort = 'time';

  // Trends tab
  String _metric = 'calories';

  late AnimationController _loadingController;

  // ── lifecycle ──────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _loadingController = AnimationController(
      duration: const Duration(milliseconds: 1300),
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
    _searchController.dispose();
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
        padding: const EdgeInsets.fromLTRB(28, 28, 28, 44),
        decoration: BoxDecoration(
          color: AppColors.skPaper(d),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'How shall we look?',
              style: tp.getSerifFont(
                fontSize: 28,
                color: AppColors.skInk(d),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'One coin per scan. You have ${coinProvider.coinBalance}.',
              style: tp.getBodyFont(
                fontSize: 14,
                color: AppColors.skMuted(d),
              ),
            ),
            const SizedBox(height: 22),
            _buildSheetRow(
              icon: Icons.photo_camera_rounded,
              label: 'Take a photo',
              hint: 'Best light is by a window',
              onTap: () {
                Navigator.pop(context);
                _takePhotoFromCamera();
              },
              d: d,
              tp: tp,
            ),
            _buildSheetRow(
              icon: Icons.photo_library_rounded,
              label: 'Choose from gallery',
              hint: 'Something you shot earlier',
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
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.skRule(d))),
        ),
        child: Row(
          children: [
            Icon(icon, size: 24, color: AppColors.skInk(d)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: tp.getBodyFont(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: AppColors.skInk(d))),
                  const SizedBox(height: 3),
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
        return _buildTrendsTab(tp, lp, fp, d);
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
    final lang = lp.currentLanguage;
    final meals = fp.getTodayFoodsSync();
    final cal = fp.getTodayCaloriesSync();
    final protein = fp.getTodayProteinSync();
    final carbs = fp.getTodayCarbsSync();
    final fat = fp.getTodayFatSync();
    final now = DateTime.now();

    // Where the day lands if the current pace holds until 22:00.
    final elapsed =
        ((now.hour + now.minute / 60 - SkDayTimeline.dayStart) / 16)
            .clamp(0.15, 1.0);
    final projected = cal / elapsed;
    final left = _dailyTarget - cal;

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
            padding: const EdgeInsets.fromLTRB(28, 14, 28, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Greeting ──
                Text(
                  DateFormat('EEEE, d MMMM').format(now).toUpperCase(),
                  style:
                      tp.getSkLabel(fontSize: 13, color: AppColors.skMuted(d)),
                ),
                const SizedBox(height: 6),
                Text(
                  '${_greeting(now, lang)}, ${_displayName(lang)}',
                  style: tp.getSerifFont(
                      fontSize: 34, color: AppColors.skInk(d)),
                ),
                const SizedBox(height: 26),

                // ── Calories against target ──
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      _fmt(cal),
                      style: tp.getSerifFont(
                          fontSize: 82,
                          height: 0.86,
                          color: AppColors.skInk(d)),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'of ${_fmt(_dailyTarget.toDouble())} kcal',
                      style: tp.getBodyFont(
                          fontSize: 15, color: AppColors.skMuted(d)),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _buildCalorieBar(tp, d, cal, projected),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      left >= 0
                          ? '${_fmt(left)} kcal left today'
                          : '${_fmt(-left)} kcal over target',
                      style: tp.getBodyFont(
                          fontSize: 13, color: AppColors.skMuted(d)),
                    ),
                    Text(
                      'PROJECTED ${_fmt(projected)}',
                      style: tp.getSkLabel(
                          fontSize: 12, color: AppColors.skFaint(d)),
                    ),
                  ],
                ),
                const SizedBox(height: 26),
                _buildMacroRow(tp, d, protein, carbs, fat),
                const SizedBox(height: 30),

                // ── The day so far ──
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(AppLocalizations.getString('sk_the_day_so_far', lang),
                        style: tp.getSkLabel(color: AppColors.skMuted(d))),
                    Text(SkDayTimeline.gapLabel(meals),
                        style: tp.getBodyFont(
                            fontSize: 12, color: AppColors.skFaint(d))),
                  ],
                ),
                const SizedBox(height: 16),
                SkDayTimeline(
                  meals: meals,
                  themeProvider: tp,
                  isDarkMode: d,
                ),
                const SizedBox(height: 34),

                // ── Active meal plan (app feature, kept above the meal list) ──
                Consumer<MealPlanProvider>(
                  builder: (context, mealPlanProvider, _) {
                    final activePlan = mealPlanProvider.activePlan;
                    if (activePlan == null) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 22),
                      child: ActiveMealPlanCard(
                        plan: activePlan,
                        language: lp.currentLanguage,
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
                        onDismiss: mealPlanProvider.dismissMealPlan,
                      ),
                    );
                  },
                ),

                // ── Today's meals ──
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Today's meals",
                        style: tp.getSerifFont(
                            fontSize: 24, color: AppColors.skInk(d))),
                    Text('${meals.length} logged',
                        style: tp.getBodyFont(
                            fontSize: 13, color: AppColors.skMuted(d))),
                  ],
                ),
                const SizedBox(height: 14),
                if (meals.isEmpty)
                  _buildEmptyState(tp, d, 'Nothing logged yet',
                      'Photograph your first plate of the day.')
                else
                  ...meals.map((f) => _buildMealRow(tp, d, f, lang)),
              ],
            ),
          ),
          if (_condensed) _buildCondensedHeader(tp, d, cal),
        ],
      ),
    );
  }

  /// 2pt target bar with the faint projection tick sitting above it.
  Widget _buildCalorieBar(
      ThemeProvider tp, bool d, double cal, double projected) {
    return SizedBox(
      height: 10,
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth;
          return Stack(
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: 4,
                child: Container(height: 2, color: AppColors.skRule(d)),
              ),
              Positioned(
                left: 0,
                top: 4,
                child: Container(
                  height: 2,
                  width: w * (cal / _dailyTarget).clamp(0.0, 1.0),
                  color: AppColors.skAccent(d),
                ),
              ),
              Positioned(
                left: w * (projected / _dailyTarget).clamp(0.0, 1.0) - 0.5,
                top: 0,
                child: Container(
                  width: 1,
                  height: 10,
                  color: AppColors.skFaint(d),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMacroRow(
      ThemeProvider tp, bool d, double protein, double carbs, double fat) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildMacroItem(tp, d, 'PROTEIN', '${protein.toStringAsFixed(1)}g',
            protein / 95, AppColors.skSage(d)),
        const SizedBox(width: 24),
        _buildMacroItem(tp, d, 'CARBS', '${carbs.toStringAsFixed(0)}g',
            carbs / 210, AppColors.skAccent(d)),
        const SizedBox(width: 24),
        _buildMacroItem(tp, d, 'FAT', '${fat.toStringAsFixed(1)}g',
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
          Text(label,
              style: tp.getSkLabel(color: AppColors.skMuted(d))),
          const SizedBox(height: 8),
          Text(value,
              style:
                  tp.getSerifFont(fontSize: 26, color: AppColors.skInk(d))),
          const SizedBox(height: 8),
          Container(
            height: 3,
            color: AppColors.skRuleSoft(d),
            child: Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: pct.clamp(0.0, 1.0),
                child: Container(color: color),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// A single meal line. [compact] is the slightly tighter History variant.
  Widget _buildMealRow(ThemeProvider tp, bool d, Food food, String lang,
      {bool compact = false}) {
    return GestureDetector(
      onTap: () => _showFoodDetail(food),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: compact ? 15 : 16),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.skRule(d))),
        ),
        child: Row(
          children: [
            Container(
              width: compact ? 40 : 44,
              height: compact ? 40 : 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.skRule(d)),
              ),
              child: Center(
                child: Text(
                  '${food.healthScore}/10',
                  style: tp.getSerifFont(
                      fontSize: compact ? 15 : 16,
                      color: AppColors.skInk(d)),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    food.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tp.getBodyFont(
                      fontSize: compact ? 15 : 16,
                      fontWeight: FontWeight.w500,
                      color: AppColors.skInk(d),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${DateFormat('HH:mm').format(food.analyzedAt)} · ${_sourceLabel(food, lang)}',
                    style: tp.getBodyFont(
                        fontSize: 13, color: AppColors.skMuted(d)),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              _fmt(food.calories),
              style: tp.getSerifFont(
                  fontSize: compact ? 20 : 22, color: AppColors.skInk(d)),
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
              color: AppColors.skPaper(d),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
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
      padding: const EdgeInsets.fromLTRB(28, 12, 28, 12),
      decoration: BoxDecoration(
        color: AppColors.skPaper(d),
        border: Border(
          bottom: BorderSide(color: AppColors.skRule(d), width: 1),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            _fmt(cal),
            style: tp.getSerifFont(fontSize: 26, color: AppColors.skInk(d)),
          ),
          const SizedBox(width: 10),
          Text(
            'of ${_fmt(_dailyTarget.toDouble())} kcal',
            style:
                tp.getBodyFont(fontSize: 13, color: AppColors.skMuted(d)),
          ),
          const Spacer(),
          Text(
            '${((cal / _dailyTarget) * 100).round()}%',
            style: tp.getSkLabel(fontSize: 12, color: AppColors.skAccent(d)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(
      ThemeProvider tp, bool d, String title, String hint) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 44),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.skRule(d))),
      ),
      child: Column(
        children: [
          Text(title,
              textAlign: TextAlign.center,
              style:
                  tp.getSerifFont(fontSize: 26, color: AppColors.skInk(d))),
          const SizedBox(height: 8),
          Text(hint,
              textAlign: TextAlign.center,
              style: tp.getBodyFont(
                  fontSize: 14, color: AppColors.skMuted(d))),
        ],
      ),
    );
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // HISTORY TAB
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Widget _buildHistoryTab(
      ThemeProvider tp, LanguageProvider lp, FoodProvider fp, bool d) {
    final lang = lp.currentLanguage;
    final q = _query.trim().toLowerCase();
    final list = fp.foods
        .where((f) => q.isEmpty || f.name.toLowerCase().contains(q))
        .toList();
    switch (_sort) {
      case 'name':
        list.sort((a, b) => a.name.compareTo(b.name));
        break;
      case 'calories':
        list.sort((a, b) => b.calories.compareTo(a.calories));
        break;
      default:
        list.sort((a, b) => b.analyzedAt.compareTo(a.analyzedAt));
    }

    // Group by day, preserving the sort order of first appearance.
    final order = <String>[];
    final groups = <String, List<Food>>{};
    for (final f in list) {
      final key = _dayLabel(f.analyzedAt, lang);
      if (!groups.containsKey(key)) {
        groups[key] = [];
        order.add(key);
      }
      groups[key]!.add(f);
    }

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(28, 14, 28, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(AppLocalizations.getString('sk_kitchen_diary', lang),
              style:
                  tp.getSkLabel(fontSize: 13, color: AppColors.skMuted(d))),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(AppLocalizations.getString('sk_history', lang),
                  style: tp.getSerifFont(
                      fontSize: 34, color: AppColors.skInk(d))),
              GestureDetector(
                onTap: () => Navigator.push(
                    context, PageTransition(child: const SkLedgerScreen())),
                behavior: HitTestBehavior.opaque,
                child: Text(AppLocalizations.getString('sk_ledger', lang),
                    style: tp.getSkLabel(
                        fontSize: 12, color: AppColors.skAccent(d))),
              ),
            ],
          ),
          const SizedBox(height: 22),

          // ── Search + sort ──
          Container(
            padding: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              border:
                  Border(bottom: BorderSide(color: AppColors.skRule(d))),
            ),
            child: Row(
              children: [
                Icon(Icons.search, size: 18, color: AppColors.skMuted(d)),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (v) => setState(() => _query = v),
                    style: tp.getBodyFont(
                        fontSize: 15, color: AppColors.skInk(d)),
                    cursorColor: AppColors.skAccent(d),
                    decoration: InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      hintText: 'Search your meals',
                      hintStyle: tp.getBodyFont(
                          fontSize: 15, color: AppColors.skMuted(d)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () => setState(() => _sort = _sort == 'time'
                      ? 'name'
                      : _sort == 'name'
                          ? 'calories'
                          : 'time'),
                  behavior: HitTestBehavior.opaque,
                  child: Text(
                    {
                      'time': 'BY TIME',
                      'name': 'BY NAME',
                      'calories': 'BY CALORIES',
                    }[_sort]!,
                    style: tp.getSkLabel(
                        fontSize: 12, color: AppColors.skAccent(d)),
                  ),
                ),
              ],
            ),
          ),

          if (order.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 60),
              child: Center(
                child: Column(
                  children: [
                    Text(q.isEmpty ? 'Nothing logged yet' : 'No meals match',
                        style: tp.getSerifFont(
                            fontSize: 24, color: AppColors.skInk(d))),
                    const SizedBox(height: 8),
                    Text(
                        q.isEmpty
                            ? 'Photograph your first plate.'
                            : 'Try a different word.',
                        style: tp.getBodyFont(
                            fontSize: 14, color: AppColors.skMuted(d))),
                  ],
                ),
              ),
            )
          else
            ...order.map((day) {
              final items = groups[day]!;
              final total = items.fold(0.0, (s, f) => s + f.calories);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 26),
                  SkTornDivider(color: AppColors.skRule(d)),
                  const SizedBox(height: 18),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(day,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: tp.getSerifFont(
                                fontSize: 22, color: AppColors.skInk(d))),
                      ),
                      Text('${_fmt(total)} KCAL',
                          style: tp.getSkLabel(
                              fontSize: 12, color: AppColors.skMuted(d))),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ...items.map(
                      (f) => _buildMealRow(tp, d, f, lang, compact: true)),
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
  Widget _buildTrendsTab(ThemeProvider tp, LanguageProvider lp, FoodProvider fp, bool d) {
    final lang = lp.currentLanguage;
    final all = fp.foods;
    final now = DateTime.now();

    double metricOf(Food f) => switch (_metric) {
          'protein' => f.protein,
          'carbs' => f.carbs,
          'fat' => f.fat,
          _ => f.calories,
        };

    // [0] = six days ago … [6] = today, shifted back by `offset` days.
    List<double> series(int offset) => List.generate(7, (i) {
          final day = DateUtils.dateOnly(
              now.subtract(Duration(days: 6 - i + offset)));
          return all
              .where((f) => DateUtils.dateOnly(f.analyzedAt) == day)
              .fold(0.0, (s, f) => s + metricOf(f));
        });

    final vals = series(0);
    final prev = series(7);
    final labels = List.generate(
        7, (i) => DateFormat('E').format(now.subtract(Duration(days: 6 - i))));
    final avg = vals.fold(0.0, (a, b) => a + b) / 7;
    final prevAvg = prev.fold(0.0, (a, b) => a + b) / 7;
    final delta =
        (vals[4] + vals[5] + vals[6]) / 3 - (vals[0] + vals[1] + vals[2]) / 3;
    final unit = _metric == 'calories' ? 'kcal' : 'g';
    String fmtMetric(double v) =>
        _metric == 'calories' ? _fmt(v) : '${v.round()}g';

    // Week macro split, weighted by the calories each macro contributes.
    final weekFoods = all
        .where((f) => now.difference(f.analyzedAt).inDays < 7)
        .toList();
    final wp = weekFoods.fold(0.0, (s, f) => s + f.protein);
    final wc = weekFoods.fold(0.0, (s, f) => s + f.carbs);
    final wf = weekFoods.fold(0.0, (s, f) => s + f.fat);
    final macroTotal = wp * 4 + wc * 4 + wf * 9;

    final avgScore = all.isEmpty
        ? 0.0
        : all.fold(0.0, (s, f) => s + f.healthScore) / all.length;

    const hPad = EdgeInsets.symmetric(horizontal: 28);

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: 14, bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: hPad,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(AppLocalizations.getString('sk_seven_days', lang),
                    style: tp.getSkLabel(
                        fontSize: 13, color: AppColors.skMuted(d))),
                const SizedBox(height: 6),
                Text(AppLocalizations.getString('sk_trends', lang),
                    style: tp.getSerifFont(
                        fontSize: 34, color: AppColors.skInk(d))),
              ],
            ),
          ),
          const SizedBox(height: 22),

          // ── Metric tabs ──
          Container(
            padding: const EdgeInsets.only(left: 28, right: 28),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.skRule(d))),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final m in const ['calories', 'protein', 'carbs', 'fat'])
                    GestureDetector(
                      onTap: () => setState(() => _metric = m),
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        margin: EdgeInsets.only(right: m == 'fat' ? 0 : 26),
                        padding: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              width: 2,
                              color: _metric == m
                                  ? AppColors.skAccent(d)
                                  : Colors.transparent,
                            ),
                          ),
                        ),
                        child: Text(
                          _metricLabel(m, lang),
                          style: tp.getBodyFont(
                            fontSize: 14,
                            fontWeight: _metric == m
                                ? FontWeight.w700
                                : FontWeight.w400,
                            color: _metric == m
                                ? AppColors.skInk(d)
                                : AppColors.skTabOff(d),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // ── Average + delta + chart ──
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 28, 28, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(fmtMetric(avg),
                        style: tp.getSerifFont(
                            fontSize: 64,
                            height: 0.9,
                            color: AppColors.skInk(d))),
                    const SizedBox(width: 10),
                    Text(AppLocalizations.getString('sk_daily_average', lang),
                        style: tp.getBodyFont(
                            fontSize: 14, color: AppColors.skMuted(d))),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  AppLocalizations.getString(delta >= 0 ? 'sk_up_delta' : 'sk_down_delta', lang)
                      .replaceAll('{delta}', delta.abs().round().toString())
                      .replaceAll('{unit}', unit),
                  style: tp.getBodyFont(
                    fontSize: 14,
                    color: delta >= 0
                        ? AppColors.skSage(d)
                        : AppColors.skAccent(d),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                        width: 18, height: 1, color: AppColors.skFaint(d)),
                    const SizedBox(width: 8),
                    Text(AppLocalizations.getString('sk_last_week_avg', lang).replaceAll('{avg}', fmtMetric(prevAvg)),
                        style: tp.getBodyFont(
                            fontSize: 12, color: AppColors.skFaint(d))),
                  ],
                ),
                const SizedBox(height: 24),
                SkLineChart(
                  values: vals,
                  previousValues: prev,
                  labels: labels,
                  format: fmtMetric,
                  lineColor: AppColors.skInk(d),
                  dotColor: AppColors.skAccent(d),
                  gridColor: AppColors.skRuleSoft(d),
                  faintColor: AppColors.skFaint(d),
                  labelStyle: tp.getBodyFont(
                      fontSize: 12, color: AppColors.skMuted(d)),
                  valueStyle: tp.getBodyFont(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: AppColors.skInk(d)),
                  noteStyle: tp.getBodyFont(
                      fontSize: 11, color: AppColors.skAccent(d)),
                ),
              ],
            ),
          ),

          // ── Where the calories come from ──
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 34, 28, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(AppLocalizations.getString('sk_where_calories_from', lang),
                    style: tp.getSerifFont(
                        fontSize: 24, color: AppColors.skInk(d))),
                const SizedBox(height: 18),
                SizedBox(
                  height: 14,
                  child: Row(
                    children: macroTotal <= 0
                        ? [
                            Expanded(
                                child: Container(
                                    color: AppColors.skRuleSoft(d)))
                          ]
                        // Zero-weight segments are dropped: Expanded(flex: 0)
                        // would be laid out unbounded.
                        : [
                            for (final seg in [
                              (wp * 4, AppColors.skSage(d)),
                              (wc * 4, AppColors.skAccent(d)),
                              (wf * 9, AppColors.skMuted(d)),
                            ])
                              if (seg.$1 >= 1)
                                Expanded(
                                    flex: seg.$1.round(),
                                    child: Container(color: seg.$2)),
                          ],
                  ),
                ),
                const SizedBox(height: 16),
                _buildSplitLegend(tp, d, AppLocalizations.getString('sk_protein_label', lang), AppColors.skSage(d),
                    wp * 4 / (macroTotal == 0 ? 1 : macroTotal), wp),
                _buildSplitLegend(tp, d, AppLocalizations.getString('sk_carbohydrate_label', lang),
                    AppColors.skAccent(d),
                    wc * 4 / (macroTotal == 0 ? 1 : macroTotal), wc),
                _buildSplitLegend(tp, d, AppLocalizations.getString('sk_fat_label', lang), AppColors.skMuted(d),
                    wf * 9 / (macroTotal == 0 ? 1 : macroTotal), wf),
              ],
            ),
          ),

          // ── Health scores ──
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 34, 28, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(AppLocalizations.getString('sk_health_scores', lang),
                    style: tp.getSerifFont(
                        fontSize: 24, color: AppColors.skInk(d))),
                const SizedBox(height: 6),
                Text(
                  AppLocalizations.getString('sk_health_scores_subtitle', lang)
                      .replaceAll('{score}', avgScore.toStringAsFixed(1))
                      .replaceAll('{count}', all.length.toString()),
                  style: tp.getBodyFont(
                      fontSize: 14, color: AppColors.skMuted(d)),
                ),
                const SizedBox(height: 20),
                _buildScoreDistribution(tp, d, all),
              ],
            ),
          ),

          // ── Note from the coach ──
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 34, 28, 0),
            child: Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: AppColors.skSurface(d),
                border: Border.all(color: AppColors.skRule(d)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(AppLocalizations.getString('sk_note_from_coach', lang),
                      style: tp.getSkLabel(color: AppColors.skAccent(d))),
                  const SizedBox(height: 10),
                  Text(
                    all.isEmpty
                        ? AppLocalizations.getString('sk_coach_empty', lang)
                        : delta >= 0
                            ? AppLocalizations.getString('sk_coach_up', lang)
                            : AppLocalizations.getString('sk_coach_down', lang),
                    style: tp.getBodyFont(
                        fontSize: 15,
                        height: 1.55,
                        color: AppColors.skBody(d)),
                  ),
                ],
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(28, 28, 28, 0),
            child: GestureDetector(
              onTap: () => Navigator.push(context,
                  PageTransition(child: const SkWeeklyReviewScreen())),
              behavior: HitTestBehavior.opaque,
              child: Container(
                height: 56,
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.skInk(d)),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(AppLocalizations.getString('sk_open_weekly_review', lang),
                        style: tp.getBodyFont(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: AppColors.skInk(d))),
                    const SizedBox(width: 10),
                    Icon(Icons.chevron_right,
                        size: 18, color: AppColors.skInk(d)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSplitLegend(ThemeProvider tp, bool d, String label, Color color,
      double pct, double grams) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.skRule(d))),
      ),
      child: Row(
        children: [
          Container(width: 10, height: 10, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label,
                style: tp.getBodyFont(
                    fontSize: 15, color: AppColors.skInk(d))),
          ),
          Text('${(pct * 100).round()}%',
              style: tp.getBodyFont(
                  fontSize: 13, color: AppColors.skMuted(d))),
          const SizedBox(width: 12),
          SizedBox(
            width: 64,
            child: Text('${grams.toStringAsFixed(0)}g',
                textAlign: TextAlign.right,
                style: tp.getSerifFont(
                    fontSize: 20, color: AppColors.skInk(d))),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreDistribution(ThemeProvider tp, bool d, List<Food> all) {
    final counts = List.filled(10, 0);
    for (final f in all) {
      counts[(f.healthScore - 1).clamp(0, 9)]++;
    }
    final maxCount = counts.fold(1, (a, b) => a > b ? a : b);

    return SizedBox(
      height: 160,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(10, (i) {
          final color = i + 1 >= 8
              ? AppColors.skSage(d)
              : i + 1 >= 6
                  ? AppColors.skAccent(d)
                  : AppColors.skFaint(d);
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2.5),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(counts[i] > 0 ? '${counts[i]}' : '',
                      style: tp.getBodyFont(
                          fontSize: 10, color: AppColors.skFaint(d))),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    height: (counts[i] / maxCount * 96).clamp(2.0, 96.0),
                    color: color,
                  ),
                  const SizedBox(height: 8),
                  Text('${i + 1}',
                      style: tp.getBodyFont(
                          fontSize: 11, color: AppColors.skMuted(d))),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  // ── shared formatting ──────────────────────────────────────
  static final NumberFormat _thousands = NumberFormat('#,##0');

  String _fmt(double v) => _thousands.format(v.round());

  String _greeting(DateTime now, String lang) => now.hour < 12
      ? AppLocalizations.getString('sk_good_morning', lang)
      : now.hour < 18
          ? AppLocalizations.getString('sk_good_afternoon', lang)
          : AppLocalizations.getString('sk_good_evening', lang);

  String _displayName(String lang) {
    final user = FirebaseAuth.instance.currentUser;
    final name = user?.displayName ?? user?.email?.split('@').first;
    return (name == null || name.isEmpty) ? AppLocalizations.getString('sk_friend', lang) : name;
  }

  String _sourceLabel(Food food, String lang) => switch (food.source) {
        'verified' => AppLocalizations.getString('sk_source_verified', lang),
        'user_edited' => AppLocalizations.getString('sk_source_user_edited', lang),
        _ => AppLocalizations.getString('sk_source_ai_estimate', lang),
      };

  String _metricLabel(String m, String lang) => switch (m) {
        'protein' => AppLocalizations.getString('sk_metric_protein', lang),
        'carbs' => AppLocalizations.getString('sk_metric_carbs', lang),
        'fat' => AppLocalizations.getString('sk_metric_fat', lang),
        _ => AppLocalizations.getString('sk_metric_calories', lang),
      };

  String _dayLabel(DateTime t, String lang) {
    final today = DateUtils.dateOnly(DateTime.now());
    final day = DateUtils.dateOnly(t);
    final diff = today.difference(day).inDays;
    if (diff == 0) return AppLocalizations.getString('today', lang);
    if (diff == 1) return AppLocalizations.getString('yesterday', lang);
    return DateFormat('EEEE, d MMMM').format(t);
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
      padding: const EdgeInsets.fromLTRB(28, 12, 28, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──
          Text(
            'YOUR KITCHEN',
            style: tp.getSkLabel(color: AppColors.skMuted(d)),
          ),
          const SizedBox(height: 6),
          Text(
            displayName ?? 'Guest',
            style: tp.getSerifFont(
              fontSize: 34,
              color: AppColors.skInk(d),
            ),
          ),
          const SizedBox(height: 22),

          // ── 3 Stats Row ──
          Container(
            padding: const EdgeInsets.only(top: 16),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: AppColors.skInk(d), width: 1),
              ),
            ),
            child: Row(
              children: [
                _buildProfileStat(
                  tp, d, '${all.length}', 'MEALS LOGGED'),
                _buildProfileStat(
                  tp, d, avgScore.toStringAsFixed(1), 'AVG SCORE'),
                _buildProfileStat(
                  tp, d, '${coinProvider.coinBalance}', 'COINS'),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Coins Banner Box ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
            decoration: BoxDecoration(
              color: AppColors.skSurface(d),
              border: Border.all(color: AppColors.skInk(d), width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppLocalizations.getString('coins', lang).toUpperCase(),
                            style: tp.getSkLabel(
                              fontSize: 12,
                              color: AppColors.skMuted(d),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${coinProvider.coinBalance}',
                            style: tp.getSerifFont(
                              fontSize: 44,
                              color: AppColors.skInk(d),
                              height: 0.9,
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
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
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 11),
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          border: Border.all(color: AppColors.skInk(d), width: 1),
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: Text(
                          AppLocalizations.getString('watch_ad_earn_coins', lang),
                          style: tp.getBodyFont(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.skInk(d),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  'One coin per scan · earned ${coinProvider.coinBalance + 33}, spent 33',
                  style: tp.getBodyFont(
                    fontSize: 13,
                    color: AppColors.skMuted(d),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // ── Preferences ──
          _buildSettingSection(tp, d, AppLocalizations.getString('preferences', lang), [
            _buildSettingRow(
              tp, d,
              AppLocalizations.getString('ai_meal_planner', lang),
              hint: AppLocalizations.getString('meal_planner_description', lang),
              onTap: () {
                Navigator.push(
                  context,
                  PageTransition(child: const MealPlanPreferencesScreen()),
                );
              },
            ),
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

          // ── Delete Account (only when signed in) ──
          if (backupProvider.isSignedIn)
            _buildSettingSection(tp, d, AppLocalizations.getString('delete_account', lang), [
              _buildSettingRow(tp, d,
                  AppLocalizations.getString('delete_account', lang),
                  hint: AppLocalizations.getString('delete_account_subtitle', lang),
                  onTap: () => _showDeleteAccountDialog(lang)),
            ]),

          const SizedBox(height: 28),
          Text(
            'Nutrition values are estimates for informational purposes only, not medical advice.',
            style: tp.getBodyFont(
              fontSize: 12,
              color: AppColors.skMuted(d),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showDeleteAccountDialog(String currentLanguage) async {
    final deleted = await DeleteAccountDialog.show(context, currentLanguage);
    if (!deleted || !mounted) return;

    final foodProvider = context.read<FoodProvider>();
    await foodProvider.loadFoods();

    if (!mounted) return;
    await context.read<SubscriptionProvider>().reloadSubscriptionStatus();

    if (!mounted) return;
    await context.read<CoinProvider>().reloadCoins();

    if (!mounted) return;
    SkSnackBar.success(
      context,
      message: AppLocalizations.getString(
        'delete_account_success',
        currentLanguage,
      ),
    );
  }

  Widget _buildProfileStat(
      ThemeProvider tp, bool d, String value, String label) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: tp.getSerifFont(
              fontSize: 28,
              color: AppColors.skInk(d),
              height: 1.0,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label.toUpperCase(),
            style: tp.getSkLabel(
              fontSize: 11,
              color: AppColors.skMuted(d),
            ),
          ),
        ],
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
                      style: tp.getSerifFont(
                          fontSize: 18, color: AppColors.skInk(d))),
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
                    style: tp.getSerifFont(
                        fontSize: 18, color: AppColors.skInk(d))),
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
                      style: tp.getSerifFont(
                          fontSize: 18, color: AppColors.skInk(d))),
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
          // A 230pt plate block with an accent line sweeping down it.
          SizedBox(
            width: 230,
            height: 230,
            child: ClipRect(
              child: Stack(
                children: [
                  Container(
                    color: AppColors.skImage(d),
                    child: Center(
                      child: Icon(Icons.image_outlined,
                          size: 72, color: AppColors.skFaint(d)),
                    ),
                  ),
                  AnimatedBuilder(
                    animation: _loadingController,
                    builder: (context, _) {
                      final t = _loadingController.value;
                      return Positioned(
                        left: 0,
                        right: 0,
                        top: 230 * (0.06 + t * 0.88),
                        child: Opacity(
                          // Fade in over the first 12% and out over the last.
                          opacity: (t < 0.12
                                  ? t / 0.12
                                  : t > 0.88
                                      ? (1 - t) / 0.12
                                      : 1.0)
                              .clamp(0.0, 1.0),
                          child: Container(
                            height: 1.5,
                            decoration: BoxDecoration(
                              color: AppColors.skAccent(d),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.skAccent(d)
                                      .withValues(alpha: 0.4),
                                  blurRadius: 14,
                                  spreadRadius: 3,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 34),
          Text(
            'Reading your plate',
            style:
                tp.getSerifFont(fontSize: 30, color: AppColors.skInk(d)),
          ),
          const SizedBox(height: 10),
          Text(
            'Matching against the food database…',
            style: tp.getBodyFont(
                fontSize: 14, color: AppColors.skMuted(d)),
          ),
        ],
      ),
    );
  }
}

