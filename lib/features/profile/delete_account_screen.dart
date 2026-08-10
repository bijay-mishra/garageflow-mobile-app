import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../state/auth_controller.dart';
import '../../widgets/gradient_header.dart';
import '../../widgets/states.dart';

/// Closing a customer account for good.
///
/// Reached only by a customer. A mechanic's login was issued by the workshop
/// that employs them and is that workshop's to withdraw on the dashboard — see
/// the row that offers this in [ProfileScreen], and the role check on the
/// endpoint behind it, which is what actually enforces it.
///
/// The screen is deliberately unhurried. It is the one action in the app that
/// cannot be taken back, so it says what goes, what stays, and how long there
/// is to change your mind — before it asks for the password. Three things stand
/// between a stray tap and a deleted account: reading this, typing the
/// password, and confirming the dialog.
class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();

  bool _obscure = true;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    if (!await _confirm()) return;
    if (!mounted) return;

    final failure = await context.read<AuthController>().deleteAccount(
      _password.text,
    );

    if (!mounted) return;

    if (failure != null) {
      showSnack(context, failure, isError: true);
      return;
    }

    // Nothing to navigate to. The controller has signed the session out, so
    // AuthGate has already replaced everything below this screen with the login
    // screen — and the notice waiting there carries the date.
  }

  /// The last check. Dismissing it — tapping outside, or the back gesture —
  /// returns null and counts as no, because "get me out of this" must never
  /// mean "yes" on this particular screen.
  Future<bool> _confirm() async {
    final t = AppText.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(t('deleteAccount.confirmTitle')),
        content: Text(t('deleteAccount.confirmBody')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(t('deleteAccount.keep')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.rose),
            child: Text(t('deleteAccount.confirmAction')),
          ),
        ],
      ),
    );

    return confirmed ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);
    final palette = AppTheme.of(context);
    final auth = context.watch<AuthController>();

    return Scaffold(
      appBar: GradientAppBar(title: t('deleteAccount.title')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        children: [
          _Banner(
            title: t('deleteAccount.graceTitle'),
            body: t('deleteAccount.graceBody'),
          ),

          const SizedBox(height: 20),
          SectionLabel(t('deleteAccount.whatGoes')),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Point(t('deleteAccount.goesLogin')),
                _Point(t('deleteAccount.goesGarages')),
                _Point(t('deleteAccount.goesMessages')),
              ],
            ),
          ),

          const SizedBox(height: 20),
          SectionLabel(t('deleteAccount.whatStays')),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Point(t('deleteAccount.staysInvoices'), tone: AppTheme.emerald),
                const SizedBox(height: 8),
                // The honest reason, not a reassurance. A workshop's invoices
                // are its own records and it has tax reasons to keep them; what
                // this app can promise is that they stop naming anybody.
                Text(
                  t('deleteAccount.staysWhy'),
                  style: TextStyle(
                    fontSize: 12.5,
                    color: palette.faint,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),
          AppCard(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    t('deleteAccount.confirmPassword'),
                    style: TextStyle(
                      fontSize: 13.5,
                      color: palette.muted,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _password,
                    obscureText: _obscure,
                    autocorrect: false,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _submit(),
                    decoration: InputDecoration(
                      labelText: t('auth.password'),
                      prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                      suffixIcon: IconButton(
                        onPressed: () => setState(() => _obscure = !_obscure),
                        icon: Icon(
                          _obscure
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          size: 20,
                          color: palette.faint,
                        ),
                        tooltip: _obscure
                            ? t('auth.showPassword')
                            : t('auth.hidePassword'),
                      ),
                    ),
                    validator: (value) => (value?.isEmpty ?? true)
                        ? t('auth.enterPassword')
                        : null,
                  ),

                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: auth.busy ? null : _submit,
                    icon: auth.busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              valueColor: AlwaysStoppedAnimation(Colors.white),
                            ),
                          )
                        : const Icon(Icons.delete_outline_rounded, size: 19),
                    label: Text(t('deleteAccount.action')),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.rose,
                      minimumSize: const Size.fromHeight(48),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 14),
          Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(t('deleteAccount.keep')),
            ),
          ),
        ],
      ),
    );
  }
}

/// The grace period, said first and said loudest — it is the fact that turns
/// this from irreversible into reversible.
class _Banner extends StatelessWidget {
  const _Banner({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final palette = AppTheme.of(context);

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        gradient: AppTheme.tintGradient(AppTheme.amber),
        borderRadius: BorderRadius.circular(AppTheme.radius),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.schedule_rounded, size: 20, color: AppTheme.amber),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: palette.text,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: palette.muted,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One line in the goes / stays lists.
class _Point extends StatelessWidget {
  const _Point(this.text, {this.tone});

  final String text;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final palette = AppTheme.of(context);
    final color = tone ?? AppTheme.rose;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            tone == null ? Icons.close_rounded : Icons.check_rounded,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13.5,
                color: palette.text,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
