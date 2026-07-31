import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_exception.dart';
import '../../core/config.dart';
import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../services/auth_service.dart';
import '../../widgets/gradient_header.dart';
import '../../widgets/states.dart';

/// Asks for a password reset link.
///
/// Takes a company code only for staff, mirroring the login screen — a customer
/// has none, and the API accepts a blank one and looks the account up by email
/// alone. Without that this screen was unreachable for every customer, which is
/// how it came to be missing entirely.
///
/// The response is the same whether or not an account matched. That is the
/// server's choice and this screen keeps it: a different message for a known
/// address turns the form into a way of discovering who has an account.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, required this.isStaff});

  /// True when the login screen was on its staff tab.
  final bool isStaff;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _company = TextEditingController(text: AppConfig.defaultCompanyCode);
  final _email = TextEditingController();

  bool _busy = false;

  /// The server's reply, once there is one. Shown in place of the form: having
  /// sent it, there is nothing more to do here.
  String? _sent;

  @override
  void dispose() {
    _company.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() => _busy = true);

    try {
      await context.read<AuthService>().forgotPassword(
        // Blank for a customer — the server falls back to an email-only lookup.
        companyCode: widget.isStaff ? _company.text : '',
        email: _email.text,
      );

      if (!mounted) return;
      setState(() {
        _busy = false;
        _sent =
            AppText.of(context)('forgot.sent', [_email.text.trim()]);
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      showSnack(context, error.message, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);
    final palette = AppTheme.of(context);

    return Scaffold(
      appBar: GradientAppBar(title: t('forgot.title')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 32),
        children: [
          if (_sent != null) ...[
            AppCard(
              lifted: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppTheme.emerald.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.mark_email_read_outlined,
                          size: 20,
                          color: AppTheme.emerald,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          t('forgot.checkEmail'),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: palette.text,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _sent!,
                    style: TextStyle(
                      fontSize: 13,
                      color: palette.muted,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(t('auth.signIn')),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),
            Text(
              t('forgot.noEmailNote'),
              style: TextStyle(
                fontSize: 12,
                color: palette.faint,
                height: 1.45,
              ),
            ),
          ] else ...[
            Text(
              t('forgot.intro'),
              style: TextStyle(
                fontSize: 13.5,
                color: palette.muted,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 20),

            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (widget.isStaff) ...[
                    TextFormField(
                      controller: _company,
                      textCapitalization: TextCapitalization.characters,
                      decoration: InputDecoration(
                        labelText: t('auth.companyCode'),
                        prefixIcon: const Icon(
                          Icons.apartment_rounded,
                          size: 20,
                        ),
                      ),
                      validator: (value) =>
                          (value == null || value.trim().isEmpty)
                          ? t('auth.enterCompanyCode')
                          : null,
                    ),
                    const SizedBox(height: 14),
                  ],

                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _submit(),
                    decoration: InputDecoration(
                      labelText: t('auth.email'),
                      prefixIcon: const Icon(
                        Icons.mail_outline_rounded,
                        size: 20,
                      ),
                    ),
                    validator: (value) {
                      final text = value?.trim() ?? '';
                      if (text.isEmpty) return t('auth.enterEmail');
                      if (!text.contains('@') || !text.contains('.')) {
                        return t('auth.badEmail');
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 22),
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: _busy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              valueColor: AlwaysStoppedAnimation(Colors.white),
                            ),
                          )
                        : Text(t('forgot.send')),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
