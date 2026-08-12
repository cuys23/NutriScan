import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nutriscan/config/app_colors.dart';
import 'package:nutriscan/providers/theme/theme_provider.dart';
import 'package:nutriscan/screens/auth/login_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ─────────────────────────────────────────────────────────────
/// Slow Kitchen Onboarding — 3 steps:
///   1. "What shall I call you?" (name input)
///   2. "How much, on an ordinary day?" (calorie target ±50)
///   3. "When shall I remind you?" (meal reminder toggles)
/// ─────────────────────────────────────────────────────────────
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  int _step = 0; // 0, 1, 2
  final TextEditingController _nameController = TextEditingController();
  int _target = 2000;

  // Reminder toggles
  bool _remBreakfast = true;
  bool _remLunch = true;
  bool _remDinner = true;
  bool _remSnack = false;

  late AnimationController _slideController;
  late Animation<Offset> _slideAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 450),
      vsync: this,
    );
    _slideAnim = Tween<Offset>(
            begin: const Offset(0.08, 0), end: Offset.zero)
        .animate(CurvedAnimation(
            parent: _slideController, curve: Curves.easeOutCubic));
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(
        parent: _slideController, curve: Curves.easeOutCubic));

    _slideController.forward();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  void _next() {
    if (_step < 2) {
      setState(() => _step++);
      _slideController.reset();
      _slideController.forward();
    } else {
      _finish();
    }
  }

  void _skip() => _finish();

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_onboarding', true);

    // Save user preferences
    if (_nameController.text.isNotEmpty) {
      await prefs.setString('user_name', _nameController.text.trim());
    }
    await prefs.setInt('calorie_target', _target);
    await prefs.setBool('rem_breakfast', _remBreakfast);
    await prefs.setBool('rem_lunch', _remLunch);
    await prefs.setBool('rem_dinner', _remDinner);
    await prefs.setBool('rem_snack', _remSnack);

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, a2, a3) => const LoginScreen(),
        transitionsBuilder: (_, anim, a2, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tp = context.watch<ThemeProvider>();
    final d = tp.isDarkMode;

    return Scaffold(
      backgroundColor: AppColors.skPaper(d),
      body: Column(
        children: [
          // ── Progress bar + Skip ──
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 16, 28, 0),
              child: Row(
                children: [
                  // 3-segment progress bar
                  ...List.generate(3, (i) => Expanded(
                        child: Container(
                          height: 2,
                          margin: EdgeInsets.only(right: i < 2 ? 8 : 0),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(1),
                            color: i <= _step
                                ? AppColors.skInk(d)
                                : AppColors.skRule(d),
                          ),
                        ),
                      )),
                  const SizedBox(width: 14),
                  GestureDetector(
                    onTap: _skip,
                    child: Text(
                      'SKIP',
                      style: tp.getBodyFont(
                        fontSize: 12,
                        letterSpacing: 1.4,
                        color: AppColors.skMuted(d),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Step content ──
          Expanded(
            child: SlideTransition(
              position: _slideAnim,
              child: FadeTransition(
                opacity: _fadeAnim,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: _step == 0
                      ? _buildStep1(tp, d)
                      : _step == 1
                          ? _buildStep2(tp, d)
                          : _buildStep3(tp, d),
                ),
              ),
            ),
          ),

          // ── CTA button ──
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 16, 28, 34),
            child: GestureDetector(
              onTap: _next,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.skInk(d),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Center(
                  child: Text(
                    _step == 2 ? "Let's cook" : 'Continue',
                    style: tp.getBodyFont(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: AppColors.skPaper(d),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Step 1: Name ──
  Widget _buildStep1(ThemeProvider tp, bool d) {
    return Padding(
      padding: const EdgeInsets.only(top: 56),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'FIRST THINGS FIRST',
            style: tp.getBodyFont(
              fontSize: 12,
              letterSpacing: 1.8,
              color: AppColors.skMuted(d),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'What shall I\ncall you?',
            style:
                tp.getSerifFont(fontSize: 40, color: AppColors.skInk(d)),
          ),
          const SizedBox(height: 16),
          Text(
            'It only appears at the top of your diary. Nothing leaves the phone.',
            style: tp.getBodyFont(
                fontSize: 15, height: 1.55, color: AppColors.skBody(d)),
          ),
          const SizedBox(height: 36),
          TextField(
            controller: _nameController,
            style:
                tp.getSerifFont(fontSize: 32, color: AppColors.skInk(d)),
            decoration: InputDecoration(
              hintText: 'Your name',
              hintStyle: tp.getSerifFont(
                  fontSize: 32, color: AppColors.skFaint(d)),
              border: InputBorder.none,
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: AppColors.skInk(d)),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide:
                    BorderSide(color: AppColors.skAccent(d), width: 2),
              ),
              contentPadding: const EdgeInsets.only(bottom: 14),
            ),
            cursorColor: AppColors.skAccent(d),
          ),
        ],
      ),
    );
  }

  // ── Step 2: Calorie target ──
  Widget _buildStep2(ThemeProvider tp, bool d) {
    // Macro split based on target
    final protein = (_target * 0.25 / 4).round(); // 25% from protein
    final carbs = (_target * 0.50 / 4).round(); // 50% from carbs
    final fat = (_target * 0.25 / 9).round(); // 25% from fat

    return Padding(
      padding: const EdgeInsets.only(top: 56),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'STEP TWO',
            style: tp.getBodyFont(
              fontSize: 12,
              letterSpacing: 1.8,
              color: AppColors.skMuted(d),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'How much, on\nan ordinary day?',
            style:
                tp.getSerifFont(fontSize: 40, color: AppColors.skInk(d)),
          ),
          const SizedBox(height: 36),
          // Target selector
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildCircleButton(tp, d, '−', () {
                setState(() => _target = (_target - 50).clamp(1000, 4000));
              }),
              Column(
                children: [
                  Text(
                    '$_target',
                    style: tp.getSerifFont(
                        fontSize: 60, color: AppColors.skInk(d)),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'KCAL A DAY',
                    style: tp.getBodyFont(
                      fontSize: 12,
                      letterSpacing: 1.6,
                      color: AppColors.skMuted(d),
                    ),
                  ),
                ],
              ),
              _buildCircleButton(tp, d, '+', () {
                setState(() => _target = (_target + 50).clamp(1000, 4000));
              }),
            ],
          ),
          const SizedBox(height: 32),
          // Macro split rows
          _buildSplitRow(tp, d, 'Protein', '${protein}g',
              AppColors.skSage(d)),
          _buildSplitRow(tp, d, 'Carbohydrate', '${carbs}g',
              AppColors.skAccent(d)),
          _buildSplitRow(tp, d, 'Fat', '${fat}g',
              AppColors.skMuted(d)),
        ],
      ),
    );
  }

  // ── Step 3: Reminders ──
  Widget _buildStep3(ThemeProvider tp, bool d) {
    return Padding(
      padding: const EdgeInsets.only(top: 56),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'LAST ONE',
            style: tp.getBodyFont(
              fontSize: 12,
              letterSpacing: 1.8,
              color: AppColors.skMuted(d),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'When shall I\nremind you?',
            style:
                tp.getSerifFont(fontSize: 40, color: AppColors.skInk(d)),
          ),
          const SizedBox(height: 16),
          Text(
            'A single quiet line on the lock screen. No sound.',
            style: tp.getBodyFont(
                fontSize: 15, height: 1.55, color: AppColors.skBody(d)),
          ),
          const SizedBox(height: 28),
          _buildReminderRow(tp, d, 'Breakfast', '8:00 AM', _remBreakfast,
              (v) => setState(() => _remBreakfast = v)),
          _buildReminderRow(tp, d, 'Lunch', '12:30 PM', _remLunch,
              (v) => setState(() => _remLunch = v)),
          _buildReminderRow(tp, d, 'Dinner', '7:00 PM', _remDinner,
              (v) => setState(() => _remDinner = v)),
          _buildReminderRow(tp, d, 'Late snack', '9:30 PM', _remSnack,
              (v) => setState(() => _remSnack = v)),
        ],
      ),
    );
  }

  // ── Helper widgets ──
  Widget _buildCircleButton(
      ThemeProvider tp, bool d, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.skRule(d)),
        ),
        child: Center(
          child: Text(
            label,
            style: tp.getBodyFont(fontSize: 24, color: AppColors.skInk(d)),
          ),
        ),
      ),
    );
  }

  Widget _buildSplitRow(
      ThemeProvider tp, bool d, String label, String grams, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.skRule(d))),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              color: color,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: tp.getBodyFont(
                  fontSize: 15, color: AppColors.skInk(d)),
            ),
          ),
          Text(
            grams,
            style:
                tp.getSerifFont(fontSize: 19, color: AppColors.skInk(d)),
          ),
        ],
      ),
    );
  }

  Widget _buildReminderRow(ThemeProvider tp, bool d, String label,
      String hint, bool value, ValueChanged<bool> onChanged) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 17),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.skRule(d))),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: tp.getBodyFont(
                        fontSize: 16, color: AppColors.skInk(d)),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    hint,
                    style: tp.getBodyFont(
                        fontSize: 13, color: AppColors.skMuted(d)),
                  ),
                ],
              ),
            ),
            // SK-style toggle
            Container(
              width: 46,
              height: 26,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: value ? AppColors.skSage(d) : AppColors.skRule(d),
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 200),
                alignment:
                    value ? Alignment.centerRight : Alignment.centerLeft,
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
}
