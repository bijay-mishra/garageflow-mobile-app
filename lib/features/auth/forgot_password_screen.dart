import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/api_exception.dart';
import '../../core/config.dart';
import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../services/auth_service.dart';
import '../../widgets/gradient_header.dart';
import '../../widgets/states.dart';

/// Forgotten password, in three steps: the account, the emailed code, the new
/// password.
///
/// A six-digit code rather than a reset link, and this screen is why. A link
/// opens a browser, not this app; following one back into Flutter needs Android
/// App Links and a verified assetlinks.json on a public HTTPS domain, none of
/// which exists yet. So the old version of this screen sent an email it could
/// not act on and stopped there — a dead end dressed up as a finished feature.
///
/// Takes a company code only for staff, mirroring the login screen: a customer
/// has none, and the API accepts a blank one and looks the account up by email
/// alone.
///
/// The first step's response is the same whether or not an account matched.
/// That is the server's choice and this screen keeps it — a different message
/// for a known address turns the form into a way of discovering who has an
/// account. It moves to the code step either way.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, required this.isStaff});

  /// True when the login screen was on its staff tab.
  final bool isStaff;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

enum _Step { account, code, password, done }

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _accountKey = GlobalKey<FormState>();
  final _codeKey = GlobalKey<FormState>();
  final _passwordKey = GlobalKey<FormState>();

  final _company = TextEditingController(text: AppConfig.defaultCompanyCode);
  final _email = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  _Step _step = _Step.account;
  bool _busy = false;
  bool _obscure = true;

  /// Where the code went, as the server described it — masked.
  String _sentTo = '';
  int _expiresInMinutes = 15;

  /// Seconds until another code may be asked for. The server throttles too;
  /// this is so the button says why it is doing nothing.
  int _cooldown = 0;
  Timer? _ticker;

  String get _companyCode => widget.isStaff ? _company.text : '';

  @override
  void dispose() {
    _ticker?.cancel();
    _company.dispose();
    _email.dispose();
    _code.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _startCooldown() {
    _ticker?.cancel();
    setState(() => _cooldown = 60);

    _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      setState(() => _cooldown--);
      if (_cooldown <= 0) timer.cancel();
    });
  }

  /// Step one, and the resend button behind it.
  Future<void> _sendCode({bool resending = false}) async {
    FocusScope.of(context).unfocus();
    if (!resending && !_accountKey.currentState!.validate()) return;

    setState(() => _busy = true);

    try {
      final target = await context.read<AuthService>().forgotPassword(
        // Blank for a customer — the server falls back to an email-only lookup.
        companyCode: _companyCode,
        email: _email.text,
      );

      if (!mounted) return;

      setState(() {
        _busy = false;
        _sentTo = target.sentTo;
        _expiresInMinutes = target.expiresInMinutes;
        _step = _Step.code;
        _code.clear();
      });

      _startCooldown();
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      showSnack(context, error.message, isError: true);
    }
  }

  /// Step two. Checks the code without spending it, so a mistyped digit is
  /// caught here rather than after a password has been chosen and confirmed.
  Future<void> _verifyCode() async {
    FocusScope.of(context).unfocus();
    if (!_codeKey.currentState!.validate()) return;

    setState(() => _busy = true);

    try {
      await context.read<AuthService>().verifyResetCode(
        companyCode: _companyCode,
        email: _email.text,
        code: _code.text,
      );

      if (!mounted) return;
      setState(() {
        _busy = false;
        _step = _Step.password;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      showSnack(context, error.message, isError: true);
    }
  }

  /// Step three. Spends the code.
  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_passwordKey.currentState!.validate()) return;

    setState(() => _busy = true);

    try {
      await context.read<AuthService>().resetPassword(
        companyCode: _companyCode,
        email: _email.text,
        code: _code.text,
        newPassword: _password.text,
      );

      if (!mounted) return;
      setState(() {
        _busy = false;
        _step = _Step.done;
      });
    } on ApiException catch (error) {
      if (!mounted) return;

      // The code is spent or burnt on most failures here, so send them back a
      // step rather than leaving them retyping a password against a dead code.
      setState(() {
        _busy = false;
        _step = _Step.code;
        _code.clear();
      });

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
          if (_step != _Step.done) ...[
            _StepBar(step: _step),
            const SizedBox(height: 22),
          ],

          if (_step == _Step.account) ..._accountStep(t, palette),
          if (_step == _Step.code) ..._codeStep(t, palette),
          if (_step == _Step.password) ..._passwordStep(t, palette),
          if (_step == _Step.done) ..._doneStep(t, palette),
        ],
      ),
    );
  }

  // ── Step one: who ──────────────────────────────────────────────────────────

  List<Widget> _accountStep(AppText t, AppPalette palette) => [
    Text(
      t('forgot.intro'),
      style: TextStyle(fontSize: 13.5, color: palette.muted, height: 1.45),
    ),
    const SizedBox(height: 20),

    Form(
      key: _accountKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.isStaff) ...[
            TextFormField(
              controller: _company,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: t('auth.companyCode'),
                prefixIcon: const Icon(Icons.apartment_rounded, size: 20),
              ),
              validator: (value) => (value == null || value.trim().isEmpty)
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
            onFieldSubmitted: (_) => _sendCode(),
            decoration: InputDecoration(
              labelText: t('auth.email'),
              prefixIcon: const Icon(Icons.mail_outline_rounded, size: 20),
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
          _SubmitButton(
            busy: _busy,
            label: t('forgot.send'),
            onPressed: _sendCode,
          ),
        ],
      ),
    ),
  ];

  // ── Step two: the code ─────────────────────────────────────────────────────

  List<Widget> _codeStep(AppText t, AppPalette palette) => [
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
            t('forgot.codeTitle'),
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
      t('forgot.codeSent', [_sentTo, '$_expiresInMinutes']),
      style: TextStyle(fontSize: 13, color: palette.muted, height: 1.45),
    ),
    const SizedBox(height: 20),

    Form(
      key: _codeKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _code,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            // Lets the platform offer the code straight from the notification.
            autofillHints: const [AutofillHints.oneTimeCode],
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: 10,
            ),
            onFieldSubmitted: (_) => _verifyCode(),
            decoration: InputDecoration(
              labelText: t('forgot.code'),
              hintText: '000000',
              counterText: '',
            ),
            validator: (value) {
              final text = value?.trim() ?? '';
              if (text.isEmpty) return t('forgot.enterCode');
              if (text.length != 6) return t('forgot.badCode');
              return null;
            },
          ),

          const SizedBox(height: 22),
          _SubmitButton(
            busy: _busy,
            label: t('forgot.continue'),
            onPressed: _verifyCode,
          ),
        ],
      ),
    ),

    const SizedBox(height: 14),
    Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        TextButton(
          onPressed: (_cooldown > 0 || _busy)
              ? null
              : () => _sendCode(resending: true),
          child: Text(
            _cooldown > 0
                ? t('forgot.resendIn', ['$_cooldown'])
                : t('forgot.resend'),
          ),
        ),
        TextButton(
          onPressed: _busy ? null : () => setState(() => _step = _Step.account),
          child: Text(t('forgot.wrongAddress')),
        ),
      ],
    ),

    const SizedBox(height: 6),
    Text(
      t('forgot.noEmailNote'),
      style: TextStyle(fontSize: 12, color: palette.faint, height: 1.45),
    ),
  ];

  // ── Step three: the new password ───────────────────────────────────────────

  List<Widget> _passwordStep(AppText t, AppPalette palette) => [
    Text(
      t('forgot.newTitle'),
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w800,
        color: palette.text,
      ),
    ),
    const SizedBox(height: 8),
    Text(
      t('forgot.newIntro'),
      style: TextStyle(fontSize: 13, color: palette.muted, height: 1.45),
    ),
    const SizedBox(height: 20),

    Form(
      key: _passwordKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _password,
            obscureText: _obscure,
            decoration: InputDecoration(
              labelText: t('forgot.newPassword'),
              prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
              suffixIcon: IconButton(
                tooltip: _obscure
                    ? t('auth.showPassword')
                    : t('auth.hidePassword'),
                icon: Icon(
                  _obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  size: 20,
                ),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
            validator: (value) {
              final text = value ?? '';
              if (text.isEmpty) return t('forgot.enterNewPassword');
              if (text.length < 8) return t('forgot.shortPassword');
              return null;
            },
          ),
          const SizedBox(height: 14),

          TextFormField(
            controller: _confirm,
            obscureText: _obscure,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _save(),
            decoration: InputDecoration(
              labelText: t('forgot.confirmPassword'),
              prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
            ),
            validator: (value) =>
                value == _password.text ? null : t('forgot.mismatch'),
          ),

          const SizedBox(height: 22),
          _SubmitButton(busy: _busy, label: t('forgot.save'), onPressed: _save),
        ],
      ),
    ),
  ];

  // ── Done ───────────────────────────────────────────────────────────────────

  List<Widget> _doneStep(AppText t, AppPalette palette) => [
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
                  Icons.check_circle_outline_rounded,
                  size: 20,
                  color: AppTheme.emerald,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  t('forgot.done'),
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
            t('forgot.doneNote'),
            style: TextStyle(fontSize: 13, color: palette.muted, height: 1.45),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(t('auth.signIn')),
          ),
        ],
      ),
    ),
  ];
}

/// Where you are in the three steps.
class _StepBar extends StatelessWidget {
  const _StepBar({required this.step});

  final _Step step;

  @override
  Widget build(BuildContext context) {
    final palette = AppTheme.of(context);
    final at = step.index;

    return Row(
      children: List.generate(3, (i) {
        return Expanded(
          child: Container(
            height: 4,
            margin: EdgeInsets.only(right: i == 2 ? 0 : 6),
            decoration: BoxDecoration(
              color: i <= at ? AppTheme.brand : palette.faint.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }
}

class _SubmitButton extends StatelessWidget {
  const _SubmitButton({
    required this.busy,
    required this.label,
    required this.onPressed,
  });

  final bool busy;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
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
    );
  }
}
