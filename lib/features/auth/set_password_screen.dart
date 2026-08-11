import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../state/auth_controller.dart';
import '../../widgets/gradient_header.dart';
import '../../widgets/states.dart';

/// Choose your own password, before anything else.
///
/// Shown to an account that is signed in but still on a password somebody else
/// typed — a mechanic created on the dashboard's Staff screen, or an account an
/// owner has just reset. Until this is done the server refuses every endpoint
/// but `/auth/me`, `/auth/logout` and `/auth/set-password`, so the shell behind
/// this screen would load nothing.
///
/// There is no skip. Skipping would leave the account reachable by whoever
/// typed the handover password, which is the single thing this exists to end.
/// The way out without setting one is to sign out, and that is offered plainly
/// rather than hidden — somebody handed the wrong credentials needs a door.
class SetPasswordScreen extends StatefulWidget {
  const SetPasswordScreen({super.key});

  @override
  State<SetPasswordScreen> createState() => _SetPasswordScreenState();
}

class _SetPasswordScreenState extends State<SetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  bool _obscure = true;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthController>();
    final failure = await auth.setPassword(_password.text);

    if (!mounted) return;

    if (failure != null) {
      showSnack(context, failure, isError: true);
      return;
    }

    // No navigation. `AuthGate` watches the controller, so clearing the flag
    // swaps this screen for the shell on the next build — the same mechanism
    // that put this screen here.
    showSnack(context, AppText.of(context)('setPassword.done'));
  }

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);
    final palette = AppTheme.of(context);
    final auth = context.watch<AuthController>();

    return PopScope(
      // Back must not dismiss this. There is nothing behind it — the shell is
      // not in the tree — and on Android the gesture would otherwise drop the
      // person on a blank route with a session they cannot use.
      canPop: false,
      child: Scaffold(
        appBar: GradientAppBar(title: t('setPassword.title')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 32),
          children: [
            Text(
              t('setPassword.greeting', [auth.user?.firstName ?? '']),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: palette.text,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              t('setPassword.intro'),
              style: TextStyle(fontSize: 13, color: palette.muted, height: 1.45),
            ),
            const SizedBox(height: 20),

            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _password,
                    obscureText: _obscure,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: t('setPassword.newPassword'),
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
                      if (text.isEmpty) return t('setPassword.enterNewPassword');
                      if (text.length < 8) return t('setPassword.shortPassword');
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
                      labelText: t('setPassword.confirmPassword'),
                      prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                    ),
                    validator: (value) =>
                        value == _password.text ? null : t('setPassword.mismatch'),
                  ),

                  const SizedBox(height: 22),
                  FilledButton(
                    onPressed: auth.busy ? null : _save,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                    child: auth.busy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: Colors.white,
                            ),
                          )
                        : Text(t('setPassword.save')),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),
            Center(
              child: TextButton(
                onPressed: auth.busy
                    ? null
                    : () => context.read<AuthController>().logout(),
                child: Text(t('setPassword.signOut')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
