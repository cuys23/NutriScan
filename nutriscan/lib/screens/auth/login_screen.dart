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

                      // Sign In Button
                      Consumer<CloudBackupProvider>(
                        builder: (_, backupProvider, _) {
                          return Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.primary,
                                  AppColors.primary.withValues(alpha: 0.8),
                                ],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                              borderRadius: BorderRadius.circular(15),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.3,
                                  ),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ElevatedButton.icon(
                              onPressed: backupProvider.isLoading
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
                              icon: backupProvider.isGoogleLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                      ),
                                    )
                                  : SvgPicture.asset(
                                      'assets/images/svg/google_logo.svg',
                                      width: 26,
                                      height: 26,
                                    ),
                              label: Text(
                                backupProvider.isGoogleLoading
                                    ? AppLocalizations.getString(
                                        'signing_in',
                                        currentLanguage,
                                      )
                                    : AppLocalizations.getString(
                                        'sign_in_with_google',
                                        currentLanguage,
                                      ).replaceAll(
                                        'Google',
                                        AppLocalizations.getString(
                                          'google',
                                          currentLanguage,
                                        ),
                                      ),
                                style: themeProvider.getFontForCurrentLanguage(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                elevation: 0,
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 14),

                      // Apple Sign In Button (Sleek Premium Black Button)
                      Consumer2<CloudBackupProvider, ThemeProvider>(
                        builder: (context, backupProvider, themeProvider, child) {
                          final currentLanguage = context
                              .read<LanguageProvider>()
                              .currentLanguage;

                          return Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.black,
                              borderRadius: BorderRadius.circular(15),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.25),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ElevatedButton.icon(
                              onPressed: backupProvider.isLoading
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
                              icon: backupProvider.isAppleLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                      ),
                                    )
                                  : const Icon(
                                      Icons.apple,
                                      color: Colors.white,
                                      size: 28,
                                    ),
                              label: Text(
                                backupProvider.isAppleLoading
                                    ? AppLocalizations.getString(
                                        'signing_in',
                                        currentLanguage,
                                      )
                                    : AppLocalizations.getString(
                                        'sign_in_with_apple',
                                        currentLanguage,
                                      ),
                                style: themeProvider.getFontForCurrentLanguage(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                elevation: 0,
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
