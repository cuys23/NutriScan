import 'package:flutter/material.dart';
import 'package:nutriscan/config/app_colors.dart';
import 'package:nutriscan/config/app_localizations.dart';
import 'package:nutriscan/providers/theme/language_provider.dart';
import 'package:nutriscan/providers/theme/theme_provider.dart';
import 'package:provider/provider.dart';

class LanguageDropdown extends StatelessWidget {
  final EdgeInsets? padding;
  final double? fontSize;
  final FontWeight? fontWeight;

  const LanguageDropdown({
    super.key,
    this.padding,
    this.fontSize,
    this.fontWeight,
  });

  static const _languages = [
    ('en', '🇺🇸', 'english'),
    ('bn', '🇧🇩', 'bangla'),
    ('hi', '🇮🇳', 'hindi'),
    ('es', '🇪🇸', 'spanish'),
    ('fr', '🇫🇷', 'french'),
    ('de', '🇩🇪', 'german'),
    ('zh', '🇨🇳', 'chinese'),
    ('tr', '🇹🇷', 'turkish'),
    ('ko', '🇰🇷', 'korean'),
    ('id', '🇮🇩', 'indonesian'),
    ('ja', '🇯🇵', 'japanese'),
    ('ru', '🇷🇺', 'russian'),
    ('ur', '🇵🇰', 'urdu'),
    ('pt', '🇵🇹', 'portuguese'),
    ('pt-BR', '🇧🇷', 'brazilian_portuguese'),
    ('ar', '🇸🇦', 'arabic'),
  ];

  @override
  Widget build(BuildContext context) {
    return Consumer2<ThemeProvider, LanguageProvider>(
      builder: (context, tp, lp, _) {
        final d = tp.isDarkMode;
        final lang = lp.currentLanguage;

        // Find current flag
        final current = _languages.firstWhere(
          (l) => l.$1 == lang,
          orElse: () => _languages.first,
        );

        return GestureDetector(
          onTap: () => _showLanguagePicker(context, tp, lp),
          child: Container(
            padding: padding ??
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.skSurface(d),
              border: Border.all(color: AppColors.skRule(d)),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(current.$2, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                Text(
                  AppLocalizations.getString(current.$3, lang),
                  style: tp.getBodyFont(
                    fontSize: fontSize ?? 14,
                    fontWeight: fontWeight ?? FontWeight.w500,
                    color: AppColors.skInk(d),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.keyboard_arrow_down,
                  color: AppColors.skMuted(d),
                  size: 18,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showLanguagePicker(
    BuildContext context,
    ThemeProvider tp,
    LanguageProvider lp,
  ) {
    final d = tp.isDarkMode;
    final lang = lp.currentLanguage;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.65,
          ),
          decoration: BoxDecoration(
            color: AppColors.skPaper(d),
            border: Border(top: BorderSide(color: AppColors.skRule(d))),
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(8),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 8),
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.skRule(d),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Title
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Text(
                      AppLocalizations.getString('language', lang),
                      style: tp.getSerifFont(
                        fontSize: 22,
                        color: AppColors.skInk(d),
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => Navigator.of(ctx).pop(),
                      child: Icon(
                        Icons.close,
                        color: AppColors.skMuted(d),
                        size: 22,
                      ),
                    ),
                  ],
                ),
              ),

              Container(height: 1, color: AppColors.skRule(d)),

              // Language list
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: _languages.length,
                  separatorBuilder: (_, __) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Container(height: 1, color: AppColors.skRuleSoft(d)),
                  ),
                  itemBuilder: (_, index) {
                    final item = _languages[index];
                    final isSelected = item.$1 == lang;

                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        lp.setLanguage(item.$1);
                        Navigator.of(ctx).pop();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 14,
                        ),
                        color: isSelected
                            ? AppColors.skSurface(d)
                            : Colors.transparent,
                        child: Row(
                          children: [
                            Text(
                              item.$2,
                              style: const TextStyle(fontSize: 18),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                AppLocalizations.getString(item.$3, lang),
                                style: tp.getBodyFont(
                                  fontSize: 15,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                  color: AppColors.skInk(d),
                                ),
                              ),
                            ),
                            if (isSelected)
                              Icon(
                                Icons.check,
                                color: AppColors.skInk(d),
                                size: 20,
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
