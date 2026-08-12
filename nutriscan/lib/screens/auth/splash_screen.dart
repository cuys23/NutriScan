import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nutriscan/config/app_colors.dart';
import 'package:nutriscan/providers/ads/admob_provider.dart';
import 'package:nutriscan/providers/auth/cloud_backup_provider.dart';
import 'package:nutriscan/providers/theme/theme_provider.dart';
import 'package:nutriscan/screens/auth/onboarding_screen.dart';
import 'package:nutriscan/screens/auth/login_screen.dart';
import 'package:nutriscan/screens/main/main_navigation.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ─────────────────────────────────────────────────────────────
/// Slow Kitchen Splash — animated bowl draw, title fade-in,
/// then auto-navigate after ~2.8s.
/// ─────────────────────────────────────────────────────────────
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // Bowl SVG draw
  late AnimationController _drawController;
  late Animation<double> _bowlDraw;
  late Animation<double> _rimDraw;
  late Animation<double> _smileDraw;

  // Title + subtitle fade-up
  late AnimationController _titleController;
  late Animation<double> _titleFade;
  late Animation<Offset> _titleSlide;
  late Animation<double> _subFade;
  late Animation<Offset> _subSlide;

  // Exit
  late AnimationController _exitController;
  late Animation<double> _exitFade;

  // Blinking dots
  late AnimationController _dotsController;

  // Steam pillars
  late AnimationController _steamController;

  @override
  void initState() {
    super.initState();

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
      ),
    );

    // ── Bowl draw (0 → 1 over 1.15s, starts at 0.1s via Interval) ──
    _drawController = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    );

    _bowlDraw = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _drawController,
        curve: const Interval(0.06, 0.7, curve: Curves.easeInOut),
      ),
    );
    _rimDraw = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _drawController,
        curve: const Interval(0.53, 0.80, curve: Curves.easeOut),
      ),
    );
    _smileDraw = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _drawController,
        curve: const Interval(0.70, 1.0, curve: Curves.easeOut),
      ),
    );

    // ── Title fade-up ──
    _titleController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _titleFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _titleController, curve: Curves.easeOut),
    );
    _titleSlide = Tween<Offset>(
            begin: const Offset(0, 0.15), end: Offset.zero)
        .animate(
      CurvedAnimation(parent: _titleController, curve: Curves.easeOut),
    );
    _subFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _titleController,
        curve: const Interval(0.4, 1, curve: Curves.easeOut),
      ),
    );
    _subSlide = Tween<Offset>(
            begin: const Offset(0, 0.2), end: Offset.zero)
        .animate(
      CurvedAnimation(
        parent: _titleController,
        curve: const Interval(0.4, 1, curve: Curves.easeOut),
      ),
    );

    // ── Exit fade ──
    _exitController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _exitFade = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(parent: _exitController, curve: Curves.easeIn),
    );

    // ── Dots blink ──
    _dotsController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat();

    // ── Steam ──
    _steamController = AnimationController(
      duration: const Duration(milliseconds: 2400),
      vsync: this,
    )..repeat();

    // ── Sequence ──
    _drawController.forward();
    Future.delayed(const Duration(milliseconds: 1350), () {
      if (mounted) _titleController.forward();
    });
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) _exitController.forward().then((_) => _navigate());
    });
  }

  Future<void> _navigate() async {
    if (!mounted) return;
    final prefs = await SharedPreferences.getInstance();
    final hasSeenOnboarding = prefs.getBool('has_seen_onboarding') ?? false;
    final hasLoggedIn = prefs.getBool('has_logged_in') ?? false;

    if (!mounted) return;
    final backup = context.read<CloudBackupProvider>();
    final isLoggedIn = backup.isSignedIn && hasLoggedIn;

    // Show open ad if applicable
    if (hasSeenOnboarding && mounted) {
      final admob = context.read<AdMobProvider>();
      if (admob.canShowAppOpenAd()) {
        await admob.showAppOpenAd();
      }
    }

    if (!mounted) return;

    final Widget target;
    if (!hasSeenOnboarding) {
      target = const OnboardingScreen();
    } else if (!isLoggedIn) {
      target = const LoginScreen();
    } else {
      target = const MainNavigation();
    }

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, a2, a3) => target,
        transitionsBuilder: (_, anim, a2, child) {
          return FadeTransition(opacity: anim, child: child);
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  @override
  void dispose() {
    _drawController.dispose();
    _titleController.dispose();
    _exitController.dispose();
    _dotsController.dispose();
    _steamController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tp = context.watch<ThemeProvider>();
    final d = tp.isDarkMode;

    return Scaffold(
      body: AnimatedBuilder(
        animation: _exitController,
        builder: (_, child2) => FadeTransition(
          opacity: _exitFade,
          child: Container(
            width: double.infinity,
            height: double.infinity,
            color: AppColors.skPaper(d),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(flex: 3),
                // ── Bowl + Steam ──
                SizedBox(
                  width: 180,
                  height: 160,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Steam pillars
                      ..._buildSteamPillars(d),
                      // Bowl SVG drawn
                      AnimatedBuilder(
                        animation: _drawController,
                        builder: (_, child2) => CustomPaint(
                          size: const Size(180, 150),
                          painter: _BowlPainter(
                            bowlProgress: _bowlDraw.value,
                            rimProgress: _rimDraw.value,
                            smileProgress: _smileDraw.value,
                            inkColor: AppColors.skInk(d),
                            accentColor: AppColors.skAccent(d),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                // ── Title ──
                SlideTransition(
                  position: _titleSlide,
                  child: FadeTransition(
                    opacity: _titleFade,
                    child: Text(
                      'NutriSnap',
                      style: tp.getSerifFont(
                          fontSize: 46, color: AppColors.skInk(d)),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                // ── Subtitle ──
                SlideTransition(
                  position: _subSlide,
                  child: FadeTransition(
                    opacity: _subFade,
                    child: Text(
                      'Eat well, one photo at a time',
                      style: tp.getBodyFont(
                          fontSize: 15, color: AppColors.skMuted(d)),
                    ),
                  ),
                ),
                const Spacer(flex: 2),
                // ── Blinking dots ──
                _buildBlinkingDots(d),
                const SizedBox(height: 64),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Steam pillars ──
  List<Widget> _buildSteamPillars(bool d) {
    return [
      Positioned(
        left: 52,
        top: 0,
        child: AnimatedBuilder(
          animation: _steamController,
          builder: (_, child2) {
            final t = (_steamController.value * 1.0).clamp(0.0, 1.0);
            return Opacity(
              opacity: _steamOpacity(t, 0.0),
              child: Transform.translate(
                offset: Offset(0, _steamY(t, 0.0)),
                child: Container(
                  width: 3,
                  height: 34,
                  decoration: BoxDecoration(
                    color: AppColors.skAccent(d),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            );
          },
        ),
      ),
      Positioned(
        left: 88,
        top: -10,
        child: AnimatedBuilder(
          animation: _steamController,
          builder: (_, child2) {
            final t = (_steamController.value * 1.0).clamp(0.0, 1.0);
            return Opacity(
              opacity: _steamOpacity(t, 0.15),
              child: Transform.translate(
                offset: Offset(0, _steamY(t, 0.15)),
                child: Container(
                  width: 3,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.skAccent(d),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            );
          },
        ),
      ),
      Positioned(
        left: 124,
        top: 0,
        child: AnimatedBuilder(
          animation: _steamController,
          builder: (_, child2) {
            final t = (_steamController.value * 1.0).clamp(0.0, 1.0);
            return Opacity(
              opacity: _steamOpacity(t, 0.3),
              child: Transform.translate(
                offset: Offset(0, _steamY(t, 0.3)),
                child: Container(
                  width: 3,
                  height: 34,
                  decoration: BoxDecoration(
                    color: AppColors.skAccent(d),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    ];
  }

  double _steamOpacity(double t, double offset) {
    final p = (t - offset) % 1.0;
    if (p < 0.3) return p / 0.3;
    if (p < 0.7) return 1.0;
    return 1.0 - ((p - 0.7) / 0.3);
  }

  double _steamY(double t, double offset) {
    final p = (t - offset) % 1.0;
    return -p * 20;
  }

  // ── Blinking dots ──
  Widget _buildBlinkingDots(bool d) {
    return AnimatedBuilder(
      animation: _dotsController,
      builder: (_, child2) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (i) {
            final delay = i * 0.133; // ~160ms stagger
            final phase =
                ((_dotsController.value - delay) % 1.0).clamp(0.0, 1.0);
            final opacity =
                (phase < 0.5 ? phase * 2 : 2 - phase * 2).clamp(0.2, 1.0);
            return Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.skAccent(d).withValues(alpha: opacity),
              ),
            );
          }),
        );
      },
    );
  }
}

// ── Custom painter: bowl SVG drawn progressively ──
class _BowlPainter extends CustomPainter {
  final double bowlProgress;
  final double rimProgress;
  final double smileProgress;
  final Color inkColor;
  final Color accentColor;

  _BowlPainter({
    required this.bowlProgress,
    required this.rimProgress,
    required this.smileProgress,
    required this.inkColor,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final inkPaint = Paint()
      ..color = inkColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    final accentPaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    // Bowl body: U-shape from (20,62) curving down to (90,130) and back to (160,62)
    if (bowlProgress > 0) {
      final bowlPath = Path();
      bowlPath.moveTo(20, 62);
      // Approximate the bowl curve
      bowlPath.cubicTo(20, 104, 55, 130, 90, 130);
      bowlPath.cubicTo(125, 130, 160, 104, 160, 62);

      final metric = bowlPath.computeMetrics().first;
      final drawn = metric.extractPath(0, metric.length * bowlProgress);
      canvas.drawPath(drawn, inkPaint);
    }

    // Rim: horizontal line at y=66
    if (rimProgress > 0) {
      final rimPath = Path();
      rimPath.moveTo(8, 66);
      rimPath.lineTo(172, 66);

      final metric = rimPath.computeMetrics().first;
      final drawn = metric.extractPath(0, metric.length * rimProgress);
      canvas.drawPath(drawn, inkPaint);
    }

    // Smile arc in accent color
    if (smileProgress > 0) {
      final smilePath = Path();
      smilePath.moveTo(62, 130);
      smilePath.cubicTo(74, 139, 106, 139, 118, 130);

      final metric = smilePath.computeMetrics().first;
      final drawn = metric.extractPath(0, metric.length * smileProgress);
      canvas.drawPath(drawn, accentPaint);
    }
  }

  @override
  bool shouldRepaint(_BowlPainter old) =>
      bowlProgress != old.bowlProgress ||
      rimProgress != old.rimProgress ||
      smileProgress != old.smileProgress;
}
