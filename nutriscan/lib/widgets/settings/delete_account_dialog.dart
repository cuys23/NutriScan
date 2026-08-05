import 'package:flutter/material.dart';
import 'package:nutriscan/config/app_colors.dart';
import 'package:nutriscan/config/app_localizations.dart';
import 'package:nutriscan/providers/auth/cloud_backup_provider.dart';
import 'package:nutriscan/providers/theme/theme_provider.dart';
import 'package:nutriscan/services/auth/account_deletion_service.dart';
import 'package:provider/provider.dart';

/// Confirmation dialog for permanent account deletion.
///
/// Required by App Store Review Guideline 5.1.1(v). Uses a typed-confirmation
/// ("DELETE") rather than a plain two-button dialog because the action is
/// irreversible and destroys cloud data.
class DeleteAccountDialog extends StatefulWidget {
  const DeleteAccountDialog({super.key, required this.language});

  final String language;

  /// Shows the dialog. Resolves to `true` when the account was deleted.
  static Future<bool> show(BuildContext context, String language) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => DeleteAccountDialog(language: language),
    );
    return result ?? false;
  }

  @override
  State<DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<DeleteAccountDialog> {
  final TextEditingController _controller = TextEditingController();
  bool _isDeleting = false;
  String? _errorMessage;

  String get _confirmWord => AppLocalizations.getString(
    'delete_account_confirm_word',
    widget.language,
  );

  bool get _canDelete =>
      _controller.text.trim().toUpperCase() == _confirmWord.toUpperCase();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _t(String key) => AppLocalizations.getString(key, widget.language);

  Future<void> _handleDelete() async {
    if (!_canDelete || _isDeleting) return;

    setState(() {
      _isDeleting = true;
      _errorMessage = null;
    });

    final provider = context.read<CloudBackupProvider>();
    final result = await provider.deleteAccount(language: widget.language);

    if (!mounted) return;

    if (result.isSuccess ||
        result.status == AccountDeletionStatus.notSignedIn) {
      Navigator.of(context).pop(true);
      return;
    }

    setState(() {
      _isDeleting = false;
      _errorMessage = result.status == AccountDeletionStatus.requiresRecentLogin
          ? _t('delete_account_requires_login')
          : _t('delete_account_failed');
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;

    final textPrimary = isDarkMode
        ? AppColors.textPrimaryDark
        : AppColors.textPrimaryLight;
    final textSecondary = isDarkMode
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;

    return PopScope(
      canPop: !_isDeleting,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDarkMode
                  ? AppColors.surfaceDark
                  : AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: isDarkMode
                      ? Colors.black.withValues(alpha: 0.5)
                      : Colors.black.withValues(alpha: 0.1),
                  spreadRadius: 1,
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: Icon(
                    Icons.person_remove_alt_1,
                    size: 44,
                    color: Colors.red[600],
                  ),
                ),
                const SizedBox(height: 20),

                Text(
                  _t('delete_account_title'),
                  style: themeProvider.getFontForCurrentLanguage(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),

                Text(
                  _t('delete_account_description'),
                  style: themeProvider.getFontForCurrentLanguage(
                    fontSize: 15,
                    color: textSecondary,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),

                // Store-required clarification: deleting the account does not
                // cancel an active App Store subscription.
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDarkMode ? AppColors.grey800 : AppColors.grey100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _t('delete_account_purchase_note'),
                    style: themeProvider.getFontForCurrentLanguage(
                      fontSize: 13,
                      color: textSecondary,
                      height: 1.35,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 20),

                TextField(
                  controller: _controller,
                  enabled: !_isDeleting,
                  autocorrect: false,
                  textCapitalization: TextCapitalization.characters,
                  onChanged: (_) => setState(() {}),
                  style: themeProvider.getFontForCurrentLanguage(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: _t('delete_account_confirm_hint'),
                    hintStyle: themeProvider.getFontForCurrentLanguage(
                      fontSize: 14,
                      color: textSecondary,
                    ),
                    filled: true,
                    fillColor: isDarkMode
                        ? AppColors.grey800
                        : AppColors.grey100,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),

                if (_errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _errorMessage!,
                    style: themeProvider.getFontForCurrentLanguage(
                      fontSize: 13,
                      color: Colors.red[600],
                      height: 1.35,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],

                const SizedBox(height: 24),

                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: isDarkMode
                              ? AppColors.grey800
                              : AppColors.grey100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: TextButton(
                          onPressed: _isDeleting
                              ? null
                              : () => Navigator.of(context).pop(false),
                          style: TextButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            _t('cancel'),
                            style: themeProvider.getFontForCurrentLanguage(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: _canDelete && !_isDeleting
                              ? Colors.red[600]
                              : Colors.red.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: TextButton(
                          onPressed: _canDelete && !_isDeleting
                              ? _handleDelete
                              : null,
                          style: TextButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isDeleting
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : Text(
                                  _t('delete_account_button'),
                                  style: themeProvider
                                      .getFontForCurrentLanguage(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
