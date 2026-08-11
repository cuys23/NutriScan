import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:nutriscan/config/app_colors.dart';
import 'package:nutriscan/config/app_localizations.dart';
import 'package:nutriscan/providers/auth/cloud_backup_provider.dart';
import 'package:nutriscan/providers/theme/language_provider.dart';
import 'package:nutriscan/providers/theme/theme_provider.dart';
import 'package:nutriscan/widgets/auth/login_widgets.dart';
import 'package:nutriscan/widgets/common/sk_snackbar.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final languageProvider = Provider.of<LanguageProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;
    final currentLanguage = languageProvider.currentLanguage;
    final d = isDarkMode;
    return Scaffold(
      backgroundColor: AppColors.skPaper(d),
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isDarkMode
              ? Brightness.light
              : Brightness.dark,
          statusBarBrightness: isDarkMode ? Brightness.dark : Brightness.light,
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // App Logo
                      const LoginLogo(),
                      const SizedBox(height: 40),

                      // Welcome Text
                      const LoginWelcomeText(),
                      const SizedBox(height: 16),

                      // Description
                      const LoginDescriptionText(),
                      const SizedBox(height: 60),

                      // Sign In with Google
                      Consumer<CloudBackupProvider>(
                        builder: (_, backupProvider, _) {
                          return GestureDetector(
                            onTap: backupProvider.isLoading
                                ? null
                                : () async {
                                    final success = await backupProvider
                                        .signInWithGoogle(
                                          language: currentLanguage,
                                        );

                                    if (success && mounted) {
                                      final prefs =
                                          await SharedPreferences.getInstance();
                                      await prefs.setBool(
                                        'has_logged_in',
                                        true,
                                      );

                                      await Future.delayed(
                                        const Duration(milliseconds: 500),
                                      );

                                      if (!context.mounted) return;
                                      final isStillSignedIn =
                                          backupProvider.isSignedIn;

                                      if (isStillSignedIn) {
                                        Navigator.of(
                                          context,
                                        ).pushReplacementNamed('/main');
                                      } else {
                                        SkSnackBar.error(
                                          context,
                                          message: AppLocalizations.getString(
                                            'login_failed',
                                            currentLanguage,
                                          ),
                                        );
                                      }
                                    } else {
                                      if (!context.mounted) return;
                                      SkSnackBar.error(
                                        context,
                                        message: AppLocalizations.getString(
                                          'login_failed',
                                          currentLanguage,
                                        ),
                                      );
                                    }
                                  },
                            child: Container(
                              width: double.infinity,
                              height: 56,
                              decoration: BoxDecoration(
                                color: AppColors.skInk(d),
                                borderRadius: BorderRadius.circular(28),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (backupProvider.isGoogleLoading)
                                    SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              AppColors.skPaper(d),
                                            ),
                                      ),
                                    )
                                  else
                                    SvgPicture.asset(
                                      'assets/images/svg/google_logo.svg',
                                      width: 22,
                                      height: 22,
                                    ),
                                  const SizedBox(width: 12),
                                  Text(
                                    backupProvider.isGoogleLoading
                                        ? AppLocalizations.getString(
                                            'signing_in',
                                            currentLanguage,
                                          )
                                        : AppLocalizations.getString(
                                            'sign_in_with_google',
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
                          );
                        },
                      ),
                      const SizedBox(height: 14),

                      // Sign In with Apple
                      Consumer2<CloudBackupProvider, ThemeProvider>(
                        builder: (context, backupProvider, themeProvider, child) {
                          final currentLanguage = context
                              .read<LanguageProvider>()
                              .currentLanguage;

                          return GestureDetector(
                            onTap: backupProvider.isLoading
                                ? null
                                : () async {
                                    final success = await backupProvider
                                        .signInWithApple(
                                          language: currentLanguage,
                                        );

                                    if (success && mounted) {
                                      final prefs =
                                          await SharedPreferences.getInstance();
                                      await prefs.setBool(
                                        'has_logged_in',
                                        true,
                                      );

                                      await Future.delayed(
                                        const Duration(milliseconds: 500),
                                      );

                                      if (!context.mounted) return;
                                      if (backupProvider.isSignedIn) {
                                        Navigator.of(
                                          context,
                                        ).pushReplacementNamed('/main');
                                      }
                                    } else {
                                      if (!context.mounted) return;
                                      SkSnackBar.error(
                                        context,
                                        message: AppLocalizations.getString(
                                          'login_failed',
                                          currentLanguage,
                                        ),
                                      );
                                    }
                                  },
                            child: Container(
                              width: double.infinity,
                              height: 56,
                              decoration: BoxDecoration(
                                color: Colors.transparent,
                                border: Border.all(
                                  color: AppColors.skInk(d),
                                  width: 1.5,
                                ),
                                borderRadius: BorderRadius.circular(28),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (backupProvider.isAppleLoading)
                                    SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              AppColors.skInk(d),
                                            ),
                                      ),
                                    )
                                  else
                                    Icon(
                                      Icons.apple,
                                      color: AppColors.skInk(d),
                                      size: 26,
                                    ),
                                  const SizedBox(width: 12),
                                  Text(
                                    backupProvider.isAppleLoading
                                        ? AppLocalizations.getString(
                                            'signing_in',
                                            currentLanguage,
                                          )
                                        : AppLocalizations.getString(
                                            'sign_in_with_apple',
                                            currentLanguage,
                                          ),
                                    style: themeProvider.getBodyFont(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.skInk(d),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),

                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
