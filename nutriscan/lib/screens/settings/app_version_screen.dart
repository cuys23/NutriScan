import 'package:flutter/material.dart';
import 'package:nutriscan/config/app_colors.dart';
import 'package:nutriscan/config/app_config.dart';
import 'package:nutriscan/config/app_localizations.dart';
import 'package:nutriscan/providers/theme/language_provider.dart';
import 'package:nutriscan/providers/theme/theme_provider.dart';
import 'package:nutriscan/widgets/common/info_card.dart';
import 'package:nutriscan/widgets/common/info_row.dart';
import 'package:provider/provider.dart';

class AppVersionScreen extends StatelessWidget {
  const AppVersionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;

    final d = isDarkMode;

    return Scaffold(
      backgroundColor: AppColors.skPaper(d),
      appBar: AppBar(
        title: Consumer2<ThemeProvider, LanguageProvider>(
          builder: (context, themeProvider, languageProvider, child) {
            return Text(
              AppLocalizations.getString(
                'app_version',
                languageProvider.currentLanguage,
              ),
              style: themeProvider.getSerifFont(
                fontSize: 22,
                color: AppColors.skInk(d),
              ),
            );
          },
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
          children: [
            // App Logo and Version
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: AppColors.skSurface(d),
                border: Border.all(color: AppColors.skRule(d)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  // App Logo (Bowl custom painter)
                  SizedBox(
                    width: 100,
                    height: 80,
                    child: CustomPaint(
                      painter: _SimpleBowlPainter(
                        inkColor: AppColors.skInk(d),
                        accentColor: AppColors.skAccent(d),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // App Name
                  Text(
                    AppConfig.appName,
                    style: themeProvider.getSerifFont(
                      fontSize: 32,
                      color: AppColors.skInk(d),
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Version
                  Consumer<LanguageProvider>(
                    builder: (context, languageProvider, child) {
                      return Text(
                        '${AppLocalizations.getString('version', languageProvider.currentLanguage)} ${AppConfig.appVersion}',
                        style: themeProvider.getFontForCurrentLanguage(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // App Information
            Consumer2<ThemeProvider, LanguageProvider>(
              builder: (context, themeProvider, languageProvider, child) {
                return InfoCard(
                  title: AppLocalizations.getString(
                    'app_details',
                    languageProvider.currentLanguage,
                  ),
                  icon: Icons.info,
                  isDarkMode: isDarkMode,
                  themeProvider: themeProvider,
                  children: [
                    InfoRow(
                      label: AppLocalizations.getString(
                        'version',
                        languageProvider.currentLanguage,
                      ),
                      value: AppConfig.appVersion,
                      isDarkMode: isDarkMode,
                      themeProvider: themeProvider,
                    ),
                    InfoRow(
                      label: AppLocalizations.getString(
                        'build_number',
                        languageProvider.currentLanguage,
                      ),
                      value: AppConfig.buildNumber,
                      isDarkMode: isDarkMode,
                      themeProvider: themeProvider,
                    ),
                    InfoRow(
                      label: AppLocalizations.getString(
                        'developer',
                        languageProvider.currentLanguage,
                      ),
                      value: 'SoftSync Agency',
                      isDarkMode: isDarkMode,
                      themeProvider: themeProvider,
                    ),
                    InfoRow(
                      label: AppLocalizations.getString(
                        'platform_support',
                        languageProvider.currentLanguage,
                      ),
                      value: 'Android 15+ & iOS',
                      isDarkMode: isDarkMode,
                      themeProvider: themeProvider,
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 32),

            // Update Button
            Consumer2<ThemeProvider, LanguageProvider>(
              builder: (context, themeProvider, languageProvider, child) {
                return Container(
                  width: double.infinity,
                  height: 50,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: TextButton(
                    onPressed: () {
                      // Check for updates - no snackbar shown
                    },
                    style: TextButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      AppLocalizations.getString(
                        'check_for_updates',
                        languageProvider.currentLanguage,
                      ),
                      style: themeProvider.getFontForCurrentLanguage(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
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
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    final accentPaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    final bowlPath = Path()
      ..moveTo(10, 35)
      ..cubicTo(10, 65, 30, 75, 50, 75)
      ..cubicTo(70, 75, 90, 65, 90, 35);
    canvas.drawPath(bowlPath, inkPaint);

    final rimPath = Path()
      ..moveTo(2, 38)
      ..lineTo(98, 38);
    canvas.drawPath(rimPath, inkPaint);

    final smilePath = Path()
      ..moveTo(35, 75)
      ..cubicTo(42, 80, 58, 80, 65, 75);
    canvas.drawPath(smilePath, accentPaint);

    final steamPaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final steam1 = Path()
      ..moveTo(32, 28)
      ..cubicTo(30, 20, 34, 14, 32, 8);
    canvas.drawPath(steam1, steamPaint);

    final steam2 = Path()
      ..moveTo(50, 26)
      ..cubicTo(48, 17, 52, 11, 50, 4);
    canvas.drawPath(steam2, steamPaint);

    final steam3 = Path()
      ..moveTo(68, 28)
      ..cubicTo(66, 20, 70, 14, 68, 8);
    canvas.drawPath(steam3, steamPaint);
  }

  @override
  bool shouldRepaint(_SimpleBowlPainter oldDelegate) => false;
}
