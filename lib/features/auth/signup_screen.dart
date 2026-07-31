import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../state/auth_controller.dart';
import 'google_button.dart';
import 'login_screen.dart' show BrandMark;

/// Free sign-up, for customers.
///
/// No company code anywhere on this screen, and that is the point: a person who
/// downloaded the app has never heard of one. The account they create belongs to
/// no garage at all — they pick one, or several, on the directory afterwards.
///
/// There is no path here to a staff role. Mechanics and advisors are created by
/// a workshop on the dashboard, because a login that can see job data must be
/// issued by the business whose data it is, never claimed by whoever asks.
class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();

  final _emailFocus = FocusNode();
  final _phoneFocus = FocusNode();
  final _passwordFocus = FocusNode();

  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    // Any error left over from a failed sign-in belongs to the other screen.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<AuthController>().clearError(),
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    _emailFocus.dispose();
    _phoneFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    await context.read<AuthController>().signUp(
      name: _name.text,
      email: _email.text,
      phone: _phone.text,
      password: _password.text,
    );
    // No navigation on success: AuthGate is watching the controller and swaps
    // in the garage directory as soon as the status changes.
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppTheme.of(context);
    final t = AppText.of(context);

    final auth = context.watch<AuthController>();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: palette.field,
        // resizeToAvoidBottomInset default: the form scrolls, so the keyboard
        // covering a field is a scroll away rather than a layout break.
        body: Column(
          children: [
            _Hero(onBack: () => Navigator.of(context).pop()),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 32),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (auth.error != null) ...[
                            _Notice(auth.error!),
                            const SizedBox(height: 16),
                          ],

                          _Field(
                            controller: _name,
                            label: t('signup.fullName'),
                            hint: t('signup.nameHint'),
                            icon: Icons.person_outline_rounded,
                            capitalisation: TextCapitalization.words,
                            onSubmitted: () => _emailFocus.requestFocus(),
                            validator: (value) =>
                                (value?.trim().length ?? 0) < 2
                                ? t('signup.enterName')
                                : null,
                          ),
                          const SizedBox(height: 14),

                          _Field(
                            controller: _email,
                            focusNode: _emailFocus,
                            label: t('auth.email'),
                            hint: 'you@example.com',
                            icon: Icons.mail_outline_rounded,
                            keyboard: TextInputType.emailAddress,
                            onSubmitted: () => _phoneFocus.requestFocus(),
                            validator: (value) {
                              final text = value?.trim() ?? '';
                              if (text.isEmpty) return t('auth.enterEmail');
                              // Loose on purpose. The server decides whether an
                              // address is already taken; this only catches an
                              // obvious typo before the round trip.
                              if (!text.contains('@') || !text.contains('.')) {
                                return t('auth.badEmail');
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),

                          _Field(
                            controller: _phone,
                            focusNode: _phoneFocus,
                            label: t('signup.phone'),
                            hint: '98XXXXXXXX',
                            icon: Icons.call_outlined,
                            keyboard: TextInputType.phone,
                            onSubmitted: () => _passwordFocus.requestFocus(),
                            // Optional, and said so rather than left to guess.
                            // A garage will want it, but refusing to create an
                            // account over it would be the app's decision to
                            // make on the workshop's behalf.
                            helper: t('signup.phoneHelp'),
                          ),
                          const SizedBox(height: 14),

                          _Field(
                            controller: _password,
                            focusNode: _passwordFocus,
                            label: t('auth.password'),
                            icon: Icons.lock_outline_rounded,
                            obscure: _obscure,
                            action: TextInputAction.done,
                            onSubmitted: _submit,
                            helper: t('signup.passwordHelp'),
                            suffix: IconButton(
                              onPressed: () =>
                                  setState(() => _obscure = !_obscure),
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
                            validator: (value) => (value?.length ?? 0) < 8
                                ? t('signup.passwordShort')
                                : null,
                          ),

                          const SizedBox(height: 26),
                          _PrimaryButton(
                            label: t('signup.submit'),
                            busy: auth.busy,
                            onPressed: _submit,
                          ),

                          const SizedBox(height: 20),
                          const GoogleSignInButton(),

                          const SizedBox(height: 18),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                t('auth.haveAccount'),
                                style: TextStyle(
                                  fontSize: 13.5,
                                  color: palette.faint,
                                ),
                              ),
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: Text(t('auth.signIn')),
                              ),
                            ],
                          ),

                          const SizedBox(height: 6),
                          Text(
                            t('signup.footnote'),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: palette.faint,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The gradient band at the top, carrying the mark and the promise.
class _Hero extends StatelessWidget {
  const _Hero({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    decoration: const BoxDecoration(
      gradient: AppTheme.headerGradient,
      borderRadius: BorderRadius.vertical(
        bottom: Radius.circular(AppTheme.radiusHeader),
      ),
    ),
    child: SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 6, 20, 26),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_rounded),
                color: Colors.white,
                tooltip: 'Back',
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Row(
                children: [
                  BrandMark(size: 44, onDark: true),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppText.of(context)('signup.title'),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          AppText.of(context)('signup.subtitle'),
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// A text field on a white card, matching the rest of the redesign.
class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    required this.icon,
    this.hint,
    this.helper,
    this.focusNode,
    this.keyboard,
    this.obscure = false,
    this.suffix,
    this.validator,
    this.onSubmitted,
    this.action = TextInputAction.next,
    this.capitalisation = TextCapitalization.none,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final String? hint;
  final String? helper;
  final FocusNode? focusNode;
  final TextInputType? keyboard;
  final bool obscure;
  final Widget? suffix;
  final String? Function(String?)? validator;
  final VoidCallback? onSubmitted;
  final TextInputAction action;
  final TextCapitalization capitalisation;

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    focusNode: focusNode,
    keyboardType: keyboard,
    obscureText: obscure,
    autocorrect: false,
    textCapitalization: capitalisation,
    textInputAction: action,
    onFieldSubmitted: (_) => onSubmitted?.call(),
    validator: validator,
    decoration: InputDecoration(
      labelText: label,
      hintText: hint,
      helperText: helper,
      helperMaxLines: 2,
      prefixIcon: Icon(icon, size: 20),
      suffixIcon: suffix,
    ),
  );
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.busy,
    required this.onPressed,
  });

  final String label;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
      boxShadow: busy ? null : AppTheme.glow(AppTheme.brand),
    ),
    child: FilledButton(
      onPressed: busy ? null : onPressed,
      child: busy
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                valueColor: AlwaysStoppedAnimation(Colors.white),
              ),
            )
          : Text(label),
    ),
  );
}

class _Notice extends StatelessWidget {
  const _Notice(this.message);

  final String message;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: AppTheme.rose.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
      border: Border.all(color: AppTheme.rose.withValues(alpha: 0.3)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.error_outline_rounded, size: 18, color: AppTheme.rose),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(
              fontSize: 13,
              color: AppTheme.rose,
              height: 1.35,
            ),
          ),
        ),
      ],
    ),
  );
}
