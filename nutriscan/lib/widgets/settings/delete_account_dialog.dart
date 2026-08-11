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
  final ValueNotifier<bool> _canDeleteNotifier = ValueNotifier(false);
  bool _isDeleting = false;
  String? _errorMessage;

  String get _confirmWord => AppLocalizations.getString(
    'delete_account_confirm_word',
    widget.language,
  );

  bool get _canDelete =>
      _controller.text.trim().toUpperCase() == _confirmWord.toUpperCase();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    _canDeleteNotifier.value = _canDelete;
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _canDeleteNotifier.dispose();
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
          // Append the underlying error code/message so a failure is
          // diagnosable from a release/TestFlight build, where there's no
          // console to read debugPrint from — the generic copy alone
          // ("check your connection") hides real causes like a Firestore
          // permission-denied or App Check rejection behind a network-sounding
          // message that isn't actually about the network.
          : '${_t('delete_account_failed')}\n(${result.message ?? 'unknown'})';
    });
  }

  @override
  Widget build(BuildContext context) {
    final tp = Provider.of<ThemeProvider>(context);
    final d = tp.isDarkMode;

    return PopScope(
      canPop: !_isDeleting,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: AppColors.skPaper(d),
              border: Border.all(color: AppColors.skRule(d)),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header ──
                Center(
                  child: Text(
                    _t('delete_account_title'),
                    style: tp.getSerifFont(
                      fontSize: 24,
                      color: AppColors.skInk(d),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 16),

                // ── Description ──
                Text(
                  _t('delete_account_description'),
                  style: tp.getBodyFont(
                    fontSize: 14,
                    color: AppColors.skMuted(d),
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),

                // ── Store-required note ──
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.skSurface(d),
                    border: Border.all(color: AppColors.skRule(d)),
                  ),
                  child: Text(
                    _t('delete_account_purchase_note'),
                    style: tp.getBodyFont(
                      fontSize: 12,
                      color: AppColors.skMuted(d),
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // ── Confirm input ──
                Text(
                  _t('delete_account_confirm_hint'),
                  style: tp.getSkLabel(
                    fontSize: 11,
                    color: AppColors.skMuted(d),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _controller,
                  enabled: !_isDeleting,
                  autocorrect: false,
                  textCapitalization: TextCapitalization.characters,
                  onChanged: (_) {},
                  style: tp.getBodyFont(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.skInk(d),
                  ),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: AppColors.skSurface(d),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: BorderSide(color: AppColors.skRule(d)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: BorderSide(color: AppColors.skRule(d)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: BorderSide(
                        color: AppColors.skInk(d),
                        width: 1.5,
                      ),
                    ),
                  ),
                ),

                if (_errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _errorMessage!,
                    style: tp.getBodyFont(
                      fontSize: 13,
                      color: const Color(0xFFC44545),
                      height: 1.35,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],

                const SizedBox(height: 24),

                // ── Divider ──
                Divider(color: AppColors.skRule(d), height: 1),
                const SizedBox(height: 20),

                // ── Buttons ──
                Column(
                  children: [
                    // Delete
                    ValueListenableBuilder<bool>(
                      valueListenable: _canDeleteNotifier,
                      builder: (context, canDelete, _) {
                        return GestureDetector(
                          onTap: canDelete && !_isDeleting
                              ? _handleDelete
                              : null,
                          child: Container(
                            width: double.infinity,
                            height: 48,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: canDelete && !_isDeleting
                                  ? const Color(0xFFC44545)
                                  : const Color(0xFFC44545).withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(24),
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
                                    style: tp.getBodyFont(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 10),
                    // Cancel
                    GestureDetector(
                      onTap: _isDeleting
                          ? null
                          : () => Navigator.of(context).pop(false),
                      child: Container(
                        width: double.infinity,
                        height: 48,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          border: Border.all(color: AppColors.skRule(d)),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Text(
                          _t('cancel'),
                          style: tp.getBodyFont(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: AppColors.skMuted(d),
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
