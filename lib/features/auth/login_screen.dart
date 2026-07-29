import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/config.dart';
import '../../core/theme.dart';
import '../../state/auth_controller.dart';

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
    child: Icon(
      Icons.build_rounded,
      size: size * 0.5,
      color: Colors.white,
    ),
  );
}

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
      companyCode: _company.text,
      email: _email.text,
      password: _password.text,
    );
    // No navigation here: AuthGate is watching the controller and swaps the
    // shell in as soon as the status changes.
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
            child: ConstrainedBox(
              // Keeps the form readable on a tablet instead of stretching the
              // fields to the full width of the screen.
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(child: BrandMark(size: 66)),
                    const SizedBox(height: 26),
                    Text(
                      'GarageFlow',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontSize: 27),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Sign in to your workshop',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14.5, color: AppTheme.ink500),
                    ),
                    const SizedBox(height: 30),

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

                    TextFormField(
                      controller: _company,
                      textCapitalization: TextCapitalization.characters,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Company code',
                        hintText: 'DEMO',
                        prefixIcon: Icon(Icons.apartment_rounded, size: 20),
                      ),
                      validator: (value) =>
                          (value == null || value.trim().isEmpty)
                          ? 'Enter your company code'
                          : null,
                    ),
                    const SizedBox(height: 14),

                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      textInputAction: TextInputAction.next,
                      onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        hintText: 'you@workshop.com',
                        prefixIcon: Icon(Icons.mail_outline_rounded, size: 20),
                      ),
                      validator: (value) {
                        final text = value?.trim() ?? '';
                        if (text.isEmpty) return 'Enter your email';
                        // Deliberately loose. The server is the authority on
                        // whether an account exists; the app only catches an
                        // obviously-not-an-address typo before the round trip.
                        if (!text.contains('@') || !text.contains('.')) {
                          return 'That does not look like an email address';
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
                        labelText: 'Password',
                        prefixIcon: const Icon(
                          Icons.lock_outline_rounded,
                          size: 20,
                        ),
                        suffixIcon: IconButton(
                          onPressed: () => setState(() => _obscure = !_obscure),
                          icon: Icon(
                            _obscure
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            size: 20,
                            color: AppTheme.ink400,
                          ),
                          tooltip: _obscure ? 'Show password' : 'Hide password',
                        ),
                      ),
                      validator: (value) => (value == null || value.isEmpty)
                          ? 'Enter your password'
                          : null,
                    ),
                    const SizedBox(height: 24),

                    FilledButton(
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
                          : const Text('Sign in'),
                    ),

                    const SizedBox(height: 26),
                    const _DemoCredentials(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// An inline banner — an error, or an explanation of why you are back here.
class _Notice extends StatelessWidget {
  const _Notice(this.message, {required this.icon, required this.color});

  final String message;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
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

/// The seeded logins, so a fresh install can be signed into without digging
/// through DbSeeder.cs. Debug builds only — this must never ship.
class _DemoCredentials extends StatelessWidget {
  const _DemoCredentials();

  @override
  Widget build(BuildContext context) {
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
        color: AppTheme.ink50,
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        border: Border.all(color: AppTheme.ink200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.science_outlined,
                size: 14,
                color: AppTheme.ink400,
              ),
              const SizedBox(width: 6),
              Text(
                'DEMO LOGINS',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.ink400,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const _CredentialRow(
            role: 'Mechanic',
            email: 'mechanic@garageflow.demo',
          ),
          const SizedBox(height: 6),
          const _CredentialRow(
            role: 'Customer',
            email: 'customer@garageflow.demo',
          ),
          const SizedBox(height: 8),
          const Text(
            'Company DEMO · password demo1234',
            style: TextStyle(fontSize: 11.5, color: AppTheme.ink400),
          ),
        ],
      ),
    );
  }
}

class _CredentialRow extends StatelessWidget {
  const _CredentialRow({required this.role, required this.email});

  final String role;
  final String email;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      SizedBox(
        width: 68,
        child: Text(
          role,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppTheme.ink700,
          ),
        ),
      ),
      Expanded(
        child: Text(
          email,
          style: const TextStyle(
            fontSize: 12,
            color: AppTheme.ink500,
            fontFamily: 'monospace',
          ),
        ),
      ),
      InkWell(
        onTap: () => Clipboard.setData(ClipboardData(text: email)),
        borderRadius: BorderRadius.circular(6),
        child: const Padding(
          padding: EdgeInsets.all(4),
          child: Icon(Icons.copy_rounded, size: 14, color: AppTheme.ink400),
        ),
      ),
    ],
  );
}
