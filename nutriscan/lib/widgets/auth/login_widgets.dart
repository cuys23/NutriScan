import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:nutriscan/config/app_colors.dart';
import 'package:nutriscan/config/app_localizations.dart';
import 'package:nutriscan/providers/theme/language_provider.dart';
import 'package:nutriscan/providers/theme/theme_provider.dart';
import 'package:provider/provider.dart';

/// Reusable widget for login screen welcome text
class LoginWelcomeText extends StatelessWidget {
  const LoginWelcomeText({super.key});

  @override
  Widget build(BuildContext context) {
    final tp = Provider.of<ThemeProvider>(context);
    final languageProvider = Provider.of<LanguageProvider>(context);
    final d = tp.isDarkMode;
    final currentLanguage = languageProvider.currentLanguage;

    return Text(
      AppLocalizations.getString(
        'welcome_to_nutriscan',
        currentLanguage,
      ).replaceAll(
        'NutriSnap',
        AppLocalizations.getString('nutriscan', currentLanguage),
      ),
      style: tp.getSerifFont(
        fontSize: 30,
        color: AppColors.skInk(d),
      ),
      textAlign: TextAlign.center,
    );
  }
}

/// Reusable widget for login screen description
class LoginDescriptionText extends StatelessWidget {
  const LoginDescriptionText({super.key});

  @override
  Widget build(BuildContext context) {
    final tp = Provider.of<ThemeProvider>(context);
    final languageProvider = Provider.of<LanguageProvider>(context);
    final d = tp.isDarkMode;
    final currentLanguage = languageProvider.currentLanguage;

    return Text(
      AppLocalizations.getString(
        'login_description',
        currentLanguage,
      ).replaceAll(
        'Google',
        AppLocalizations.getString('google', currentLanguage),
      ),
      style: tp.getBodyFont(
        fontSize: 15,
        height: 1.5,
        color: AppColors.skMuted(d),
      ),
      textAlign: TextAlign.center,
    );
  }
}

/// Reusable widget for Google sign-in button
class GoogleSignInButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback? onPressed;

  const GoogleSignInButton({
    super.key,
    required this.isLoading,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final languageProvider = Provider.of<LanguageProvider>(context);
    final currentLanguage = languageProvider.currentLanguage;

    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 2,
          shadowColor: AppColors.primary.withValues(alpha: 0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        icon: isLoading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : SvgPicture.asset(
                'assets/images/svg/google_logo.svg',
                width: 26,
                height: 26,
              ),
        label: Text(
          isLoading
              ? AppLocalizations.getString('signing_in', currentLanguage)
              : AppLocalizations.getString(
                  'sign_in_with_google',
                  currentLanguage,
                ).replaceAll(
                  'Google',
                  AppLocalizations.getString('google', currentLanguage),
                ),
          style: themeProvider.getFontForCurrentLanguage(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

/// Reusable widget for login screen logo
class LoginLogo extends StatelessWidget {
  const LoginLogo({super.key});

  @override
  Widget build(BuildContext context) {
    final tp = context.watch<ThemeProvider>();
    final d = tp.isDarkMode;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 140,
          height: 120,
          child: CustomPaint(
            size: const Size(140, 120),
            painter: _SimpleBowlPainter(
              inkColor: AppColors.skInk(d),
              accentColor: AppColors.skAccent(d),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'NutriSnap',
          style: tp.getSerifFont(
            fontSize: 40,
            color: AppColors.skInk(d),
          ),
        ),
      ],
    );
  }
}

class _SimpleBowlPainter extends CustomPainter {
  final Color inkColor;
  final Color accentColor;

  _SimpleBowlPainter({required this.inkColor, required this.accentColor});

  @override
  void paint(Canvas canvas, Size size) {
    final inkPaint = Paint()
      ..color = inkColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    final accentPaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    // Bowl
    final bowlPath = Path()
      ..moveTo(15, 45)
      ..cubicTo(15, 80, 45, 100, 70, 100)
      ..cubicTo(95, 100, 125, 80, 125, 45);
    canvas.drawPath(bowlPath, inkPaint);

    // Rim
    final rimPath = Path()
      ..moveTo(5, 48)
      ..lineTo(135, 48);
    canvas.drawPath(rimPath, inkPaint);

    // Smile accent
    final smilePath = Path()
      ..moveTo(48, 100)
      ..cubicTo(58, 107, 82, 107, 92, 100);
    canvas.drawPath(smilePath, accentPaint);

    // Steam lines
    final steamPaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final steam1 = Path()
      ..moveTo(45, 38)
      ..cubicTo(43, 28, 47, 20, 45, 12);
    canvas.drawPath(steam1, steamPaint);

    final steam2 = Path()
      ..moveTo(70, 35)
      ..cubicTo(68, 24, 72, 15, 70, 6);
    canvas.drawPath(steam2, steamPaint);

    final steam3 = Path()
      ..moveTo(95, 38)
      ..cubicTo(93, 28, 97, 20, 95, 12);
    canvas.drawPath(steam3, steamPaint);
  }

  @override
  bool shouldRepaint(_SimpleBowlPainter oldDelegate) => false;
}
