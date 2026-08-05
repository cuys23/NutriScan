import 'package:flutter/material.dart';
import 'package:nutriscan/config/app_colors.dart';
import 'package:nutriscan/config/app_localizations.dart';
import 'package:nutriscan/providers/theme/theme_provider.dart';
import 'package:provider/provider.dart';

/// Shows the trust level of a [Food]'s nutrition data: verified (FKB),
/// estimated (AI), or user_edited.
class SourceBadge extends StatelessWidget {
  final String source;
  final String currentLanguage;

  const SourceBadge({
    super.key,
    required this.source,
    required this.currentLanguage,
  });

  Color get _color {
    switch (source) {
      case 'verified':
        return AppColors.success;
      case 'user_edited':
        return AppColors.warning;
      default:
        return Colors.grey;
    }
  }

  String get _labelKey {
    switch (source) {
      case 'verified':
        return 'source_verified';
      case 'user_edited':
        return 'source_user_edited';
      default:
        return 'source_estimated';
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _color,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Text(
        AppLocalizations.getString(_labelKey, currentLanguage),
        style: themeProvider.getFontForCurrentLanguage(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }
}
