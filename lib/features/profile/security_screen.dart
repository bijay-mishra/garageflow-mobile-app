import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:provider/provider.dart';

import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../state/auth_controller.dart';
import '../../state/settings_controller.dart';
import '../../widgets/gradient_header.dart';
import '../../widgets/states.dart';

/// The app lock, and changing the password.
class SecurityScreen extends StatefulWidget {
  const SecurityScreen({super.key});

  @override
  State<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends State<SecurityScreen> {
  /// Null while we are still asking the phone what it can do.
  bool? _biometricsAvailable;

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    final available = await BiometricLock.isAvailable();
    if (mounted) setState(() => _biometricsAvailable = available);
  }

  Future<void> _toggleLock(bool enable) async {
    final settings = context.read<SettingsController>();
    final t = AppText.of(context);

    // Turning it *on* is proved first. Enabling a lock you cannot open would
    // leave someone shut out of their own app on the next launch, and the only
    // way back would be reinstalling.
    if (enable) {
      final ok = await BiometricLock.authenticate(t('security.unlockReason'));
      if (!mounted) return;

      if (!ok) {
        showSnack(context, t('security.unlockFailed'), isError: true);
        return;
      }
    }

    await settings.setBiometricLock(enable);
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    final t = AppText.of(context);
    final palette = AppTheme.of(context);
    final available = _biometricsAvailable ?? false;

    return Scaffold(
      appBar: GradientAppBar(title: t('security.title')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
        children: [
          AppCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppTheme.brand.withValues(alpha: 0.11),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.fingerprint_rounded,
                    size: 21,
                    color: AppTheme.brand,
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t('security.appLock'),
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: palette.text,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        // A greyed switch with no reason is a dead end, so the
                        // phone's own state is explained instead.
                        available
                            ? t('security.appLockSub')
                            : t('security.appLockUnavailable'),
                        style: TextStyle(
                          fontSize: 12.5,
                          color: available ? palette.faint : AppTheme.amber,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Switch(
                  value: settings.biometricLock && available,
                  onChanged: _biometricsAvailable == null || !available
                      ? null
                      : _toggleLock,
                ),
              ],
            ),
          ),

          const SizedBox(height: 22),
          SectionLabel(t('security.changePassword')),
          const _ChangePassword(),
        ],
      ),
    );
  }
}

/// Current password, new password, confirmation.
class _ChangePassword extends StatefulWidget {
  const _ChangePassword();

  @override
  State<_ChangePassword> createState() => _ChangePasswordState();
}

class _ChangePasswordState extends State<_ChangePassword> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();

  bool _obscure = true;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final failure = await context.read<AuthController>().changePassword(
      currentPassword: _current.text,
      newPassword: _next.text,
    );

    if (!mounted) return;

    if (failure != null) {
      showSnack(context, failure, isError: true);
      return;
    }
    // On success the controller has already ended the session, so AuthGate
    // swaps in the login screen and there is nothing to navigate.
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final t = AppText.of(context);
    final palette = AppTheme.of(context);

    return AppCard(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _current,
              obscureText: _obscure,
              decoration: InputDecoration(
                labelText: t('security.currentPassword'),
                prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                suffixIcon: IconButton(
                  onPressed: () => setState(() => _obscure = !_obscure),
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 20,
                  ),
                ),
              ),
              validator: (v) =>
                  (v?.isEmpty ?? true) ? t('auth.enterPassword') : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _next,
              obscureText: _obscure,
              decoration: InputDecoration(
                labelText: t('security.newPassword'),
                helperText: t('signup.passwordHelp'),
                prefixIcon: const Icon(Icons.key_outlined, size: 20),
              ),
              validator: (v) =>
                  (v?.length ?? 0) < 8 ? t('signup.passwordShort') : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _confirm,
              obscureText: _obscure,
              decoration: InputDecoration(
                labelText: t('security.confirmPassword'),
                prefixIcon: const Icon(Icons.key_outlined, size: 20),
              ),
              // Caught here rather than by the server: mistyping the
              // confirmation is not something the API can see, and finding out
              // after being signed out would be a bad way to learn.
              validator: (v) =>
                  v != _next.text ? t('security.passwordsDiffer') : null,
            ),

            const SizedBox(height: 14),
            Text(
              t('security.sessionNote'),
              style: TextStyle(fontSize: 12, color: palette.faint, height: 1.4),
            ),

            const SizedBox(height: 16),
            FilledButton(
              onPressed: auth.busy ? null : _submit,
              child: auth.busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  : Text(t('security.changePassword')),
            ),
          ],
        ),
      ),
    );
  }
}

/// The phone's fingerprint / face unlock, wrapped so no screen touches
/// `local_auth` directly.
///
/// Every failure is `false` rather than an exception. There are a dozen reasons
/// this can fail — no hardware, nothing enrolled, too many attempts, the user
/// pressed cancel — and none of them are the app's problem to distinguish: the
/// only question is whether the person is allowed in.
class BiometricLock {
  const BiometricLock._();

  static final _auth = LocalAuthentication();

  static Future<bool> isAvailable() async {
    try {
      if (!await _auth.isDeviceSupported()) return false;
      if (!await _auth.canCheckBiometrics) return false;

      // Supported hardware with nothing enrolled still cannot authenticate, and
      // offering the switch would produce a lock that never opens.
      return (await _auth.getAvailableBiometrics()).isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> authenticate(String reason) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        // Biometrics only: falling back to the device PIN would mean anyone who
        // can unlock the phone can open the app, which is exactly the situation
        // this setting exists to prevent.
        biometricOnly: true,
        // Survives the OS briefly backgrounding the app to show its own prompt,
        // which would otherwise cancel the very check it was opened for.
        persistAcrossBackgrounding: true,
      );
    } catch (_) {
      return false;
    }
  }
}
