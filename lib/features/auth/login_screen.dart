import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/config.dart';
import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../state/auth_controller.dart';
import 'forgot_password_screen.dart';
import 'signup_screen.dart';
import 'social_sign_in.dart';

/// The GarageFlow logo — a wrench in a rounded tile.
///
/// Drawn rather than shipped as an asset so it stays crisp at any size and the
/// repo needs no binary files.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 64, this.onDark = false});

  final double size;
  final bool onDark;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: onDark ? Colors.white.withValues(alpha: 0.16) : AppTheme.brand,
      borderRadius: BorderRadius.circular(size * 0.28),
      border: onDark
          ? Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1.5)
          : null,
    ),
    child: Icon(Icons.build_rounded, size: size * 0.5, color: Colors.white),
  );
}

/// Who is signing in.
///
/// The two audiences genuinely have different credentials: staff belong to one
/// workshop and prove it with a company code, while a customer's account sits
/// above every garage and has no code to give. The server accepts both shapes;
/// this is where the app stops asking customers for something they cannot know.
///
/// It is *not* a 50/50 choice, and it used to be drawn as one — a segmented
/// Customer | Staff control above the form. That made every customer answer a
/// question about the app's internal structure before they could type anything,
/// and handed half the screen to the smaller audience. This is a customer app:
/// nearly everyone who opens it is a customer, and the occasional mechanic
/// knows perfectly well that they are staff.
///
/// So the screen opens as a plain customer form and staff take a quiet link at
/// the bottom. It stays one form underneath — [staff] only adds the company
/// code field and sends it — rather than a second screen duplicating the email,
/// password, validation and error handling.
enum _SignInAs { customer, staff }

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _company = TextEditingController(text: AppConfig.defaultCompanyCode);
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _passwordFocus = FocusNode();

  _SignInAs _as = _SignInAs.customer;
  bool _obscure = true;

  @override
  void dispose() {
    _company.dispose();
    _email.dispose();
    _password.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    await context.read<AuthController>().login(
      // Blank for a customer. The server falls back to a customer-only lookup,
      // and the garage comes from whichever one their account opens on.
      companyCode: _as == _SignInAs.staff ? _company.text : '',
      email: _email.text,
      password: _password.text,
    );
    // No navigation here: AuthGate is watching the controller and swaps the
    // shell in as soon as the status changes.
  }

  void _switchTo(_SignInAs value) {
    if (_as == value) return;
    setState(() => _as = value);
    // An error about the wrong credentials is about the other mode.
    context.read<AuthController>().clearError();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);

    final palette = AppTheme.of(context);

    final auth = context.watch<AuthController>();
    final isStaff = _as == _SignInAs.staff;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: palette.field,
        body: Column(
          children: [
            const _Hero(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 32),
                child: Center(
                  child: ConstrainedBox(
                    // Keeps the form readable on a tablet instead of stretching
                    // the fields to the full width of the screen.
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Only staff get a heading. The customer form needs
                          // none — the hero above already says GarageFlow, and
                          // a second "Sign in" over two fields is noise.
                          if (isStaff) ...[
                            _StaffHeader(
                              onBack: () => _switchTo(_SignInAs.customer),
                            ),
                            const SizedBox(height: 20),
                          ],

                          if (auth.expiryNotice != null) ...[
                            _Notice(
                              auth.expiryNotice!,
                              icon: Icons.info_outline_rounded,
                              color: AppTheme.amber,
                            ),
                            const SizedBox(height: 14),
                          ],

                          if (auth.error != null) ...[
                            _Notice(
                              auth.error!,
                              icon: Icons.error_outline_rounded,
                              color: AppTheme.rose,
                            ),
                            const SizedBox(height: 14),
                          ],

                          // Customers only, and above the form on purpose:
                          // somebody who signs in with Google should not have
                          // to read past fields they will never fill in. Staff
                          // accounts are created by their workshop and have no
                          // provider behind them.
                          if (!isStaff) const SocialSignIn(),

                          // Staff only. Animated rather than swapped so the
                          // form does not jump when the mode changes.
                          AnimatedSize(
                            duration: const Duration(milliseconds: 180),
                            curve: Curves.easeOut,
                            child: isStaff
                                ? Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      TextFormField(
                                        controller: _company,
                                        textCapitalization:
                                            TextCapitalization.characters,
                                        textInputAction: TextInputAction.next,
                                        decoration: InputDecoration(
                                          labelText: t('auth.companyCode'),
                                          hintText: 'DEMO',
                                          helperText:
                                              t('auth.companyCodeHint'),
                                          prefixIcon: Icon(
                                            Icons.apartment_rounded,
                                            size: 20,
                                          ),
                                        ),
                                        validator: (value) => isStaff &&
                                                (value == null ||
                                                    value.trim().isEmpty)
                                            ? t('auth.enterCompanyCode')
                                            : null,
                                      ),
                                      const SizedBox(height: 14),
                                    ],
                                  )
                                : const SizedBox.shrink(),
                          ),

                          TextFormField(
                            controller: _email,
                            keyboardType: TextInputType.emailAddress,
                            autocorrect: false,
                            textInputAction: TextInputAction.next,
                            onFieldSubmitted: (_) =>
                                _passwordFocus.requestFocus(),
                            decoration: InputDecoration(
                              labelText: t('auth.email'),
                              hintText: isStaff
                                  ? 'you@workshop.com'
                                  : 'you@example.com',
                              prefixIcon: const Icon(
                                Icons.mail_outline_rounded,
                                size: 20,
                              ),
                            ),
                            validator: (value) {
                              final text = value?.trim() ?? '';
                              if (text.isEmpty) return t('auth.enterEmail');
                              // Deliberately loose. The server is the authority
                              // on whether an account exists; the app only
                              // catches an obvious typo before the round trip.
                              if (!text.contains('@') || !text.contains('.')) {
                                return t('auth.badEmail');
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),

                          TextFormField(
                            controller: _password,
                            focusNode: _passwordFocus,
                            obscureText: _obscure,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _submit(),
                            decoration: InputDecoration(
                              labelText: t('auth.password'),
                              prefixIcon: const Icon(
                                Icons.lock_outline_rounded,
                                size: 20,
                              ),
                              suffixIcon: IconButton(
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
                            ),
                            validator: (value) =>
                                (value == null || value.isEmpty)
                                ? t('auth.enterPassword')
                                : null,
                          ),

                          const SizedBox(height: 6),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => ForgotPasswordScreen(
                                    isStaff: isStaff,
                                  ),
                                ),
                              ),
                              child: Text(t('auth.forgotPassword')),
                            ),
                          ),

                          const SizedBox(height: 10),
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(
                                AppTheme.radiusSmall,
                              ),
                              boxShadow: auth.busy
                                  ? null
                                  : AppTheme.glow(AppTheme.brand),
                            ),
                            child: FilledButton(
                              onPressed: auth.busy ? null : _submit,
                              child: auth.busy
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.2,
                                        valueColor: AlwaysStoppedAnimation(
                                          Colors.white,
                                        ),
                                      ),
                                    )
                                  : Text(t('auth.signIn')),
                            ),
                          ),

                          // Customers can create their own account; staff
                          // cannot, so offering it in that mode would be an
                          // invitation to a dead end.
                          if (!isStaff) ...[
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  t('auth.newHere'),
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    color: palette.faint,
                                  ),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => const SignUpScreen(),
                                    ),
                                  ),
                                  child: Text(t('auth.createAccount')),
                                ),
                              ],
                            ),

                            // The staff door. Below everything a customer
                            // needs, quiet enough to ignore, and unmissable if
                            // you came here looking for it.
                            const SizedBox(height: 18),
                            _StaffDoor(onTap: () => _switchTo(_SignInAs.staff)),
                          ] else
                            const SizedBox(height: 10),

                          const SizedBox(height: 18),
                          const _DemoCredentials(),
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

/// The gradient band with the mark. Same language as every header in the app,
/// so the first screen already looks like the product.
class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {

    return Container(
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
        padding: const EdgeInsets.fromLTRB(24, 30, 24, 30),
        child: Column(
          children: [
            const BrandMark(size: 58, onDark: true),
            const SizedBox(height: 18),
            Text(
              'GarageFlow',
              style: TextStyle(
                color: Colors.white,
                fontSize: 27,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.6,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              AppText.of(context)('auth.tagline'),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.75),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    ),
  );
  }
}

/// The way in for mechanics and workshop staff, at the foot of the customer form.
///
/// A bordered row rather than a bare TextButton. This is the one control on the
/// screen that changes what the form *is*, so it needs enough weight to read as
/// a destination — but it sits below the sign-up line and stays in the muted
/// palette, because for almost everyone opening this app it is the wrong door.
class _StaffDoor extends StatelessWidget {
  const _StaffDoor({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);
    final palette = AppTheme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          border: Border.all(color: palette.border),
        ),
        child: Row(
          children: [
            Icon(Icons.build_rounded, size: 18, color: palette.faint),
            const SizedBox(width: 11),
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '${t('auth.staffPrompt')} ',
                      style: TextStyle(fontSize: 13.5, color: palette.faint),
                    ),
                    TextSpan(
                      text: t('auth.staffLink'),
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.brand,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 20, color: palette.faint),
          ],
        ),
      ),
    );
  }
}

/// The heading over the staff form, and the way back out of it.
///
/// The way back matters more than it looks: without it a customer who tapped
/// the staff link out of curiosity is stranded in a form asking for a company
/// code they have never been given, with nothing to say this is the wrong place.
class _StaffHeader extends StatelessWidget {
  const _StaffHeader({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);
    final palette = AppTheme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppTheme.brandLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.build_rounded,
                size: 19,
                color: AppTheme.brand,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                t('auth.staffTitle'),
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: palette.text,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          t('auth.staffSubtitle'),
          style: TextStyle(fontSize: 13, color: palette.faint, height: 1.4),
        ),
        // Padding cancelled so the link aligns with the text above it rather
        // than sitting proud of this block.
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: onBack,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            icon: const Icon(Icons.arrow_back_rounded, size: 16),
            label: Text(t('auth.backToCustomer')),
          ),
        ),
      ],
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice(this.message, {required this.icon, required this.color});

  final String message;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {

    return Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
      border: Border.all(color: color.withValues(alpha: 0.3)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            message,
            style: TextStyle(fontSize: 13, color: color, height: 1.35),
          ),
        ),
      ],
    ),
  );
  }
}

/// The seeded logins, so a fresh install can be signed into without digging
/// through DbSeeder.cs. Debug builds only — this must never ship.
class _DemoCredentials extends StatelessWidget {
  const _DemoCredentials();

  @override
  Widget build(BuildContext context) {
    final palette = AppTheme.of(context);

    // `kReleaseMode` via assert: the whole widget is compiled out of a release
    // build rather than merely hidden.
    var isDebug = false;
    assert(() {
      isDebug = true;
      return true;
    }());

    if (!isDebug) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        boxShadow: AppTheme.shadowCard,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.science_outlined, size: 14, color: palette.faint),
              SizedBox(width: 6),
              Text(
                'DEMO LOGINS',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: palette.faint,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const _CredentialRow(
            role: 'Mechanic',
            email: 'mechanic@garageflow.demo',
            note: 'staff · code DEMO',
          ),
          const SizedBox(height: 6),
          const _CredentialRow(
            role: 'Customer',
            email: 'customer@garageflow.demo',
            note: 'customer · no code',
          ),
          const SizedBox(height: 8),
          Text(
            'Password demo1234',
            style: TextStyle(fontSize: 11.5, color: palette.faint),
          ),
        ],
      ),
    );
  }
}

class _CredentialRow extends StatelessWidget {
  const _CredentialRow({
    required this.role,
    required this.email,
    required this.note,
  });

  final String role;
  final String email;
  final String note;

  @override
  Widget build(BuildContext context) {
    final palette = AppTheme.of(context);

    return Row(
    children: [
      SizedBox(
        width: 68,
        child: Text(
          role,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: palette.muted,
          ),
        ),
      ),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              email,
              style: TextStyle(
                fontSize: 12,
                color: palette.faint,
                fontFamily: 'monospace',
              ),
            ),
            Text(
              note,
              style: TextStyle(fontSize: 10.5, color: palette.faint),
            ),
          ],
        ),
      ),
      InkWell(
        onTap: () => Clipboard.setData(ClipboardData(text: email)),
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: EdgeInsets.all(4),
          child: Icon(Icons.copy_rounded, size: 14, color: palette.faint),
        ),
      ),
    ],
  );
  }
}
