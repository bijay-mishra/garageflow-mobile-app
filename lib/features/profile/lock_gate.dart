import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../state/auth_controller.dart';
import '../../state/settings_controller.dart';
import '../auth/login_screen.dart' show BrandMark;
import 'security_screen.dart' show BiometricLock;

/// Holds the app behind a fingerprint while the lock is on.
///
/// Wraps the signed-in shells only. The login screen is never locked: someone
/// who cannot pass the biometric check must still be able to sign out and sign
/// in as somebody else, and locking the door to the door is how a phone becomes
/// a brick.
///
/// Re-locks when the app goes to the background, not on a timer. A timer means
/// choosing a number nobody can justify; the background is the moment the phone
/// might change hands, which is the thing being guarded against.
class LockGate extends StatefulWidget {
  const LockGate({super.key, required this.child});

  final Widget child;

  @override
  State<LockGate> createState() => _LockGateState();
}

class _LockGateState extends State<LockGate> with WidgetsBindingObserver {
  bool _unlocked = false;

  /// True while the OS prompt is up. Needed because showing that prompt
  /// *itself* backgrounds the app — without this the lifecycle callback would
  /// see `inactive`, re-lock, and fight the dialog it just opened.
  bool _prompting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryUnlock());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_prompting) return;

    if (state == AppLifecycleState.resumed) {
      if (!_unlocked) _tryUnlock();
    } else if (state == AppLifecycleState.paused) {
      // paused, not inactive: `inactive` fires for a notification shade pull or
      // an incoming call banner, and re-locking on those would be relentless.
      if (mounted) setState(() => _unlocked = false);
    }
  }

  Future<void> _tryUnlock() async {
    if (!mounted) return;

    final settings = context.read<SettingsController>();

    // Lock off, or nothing enrolled on this phone any more — the setting must
    // not be able to strand someone if they removed their fingerprints.
    if (!settings.biometricLock || !await BiometricLock.isAvailable()) {
      if (mounted) setState(() => _unlocked = true);
      return;
    }

    if (!mounted) return;
    final reason = AppText.of(context)('security.unlockReason');

    setState(() => _prompting = true);
    final ok = await BiometricLock.authenticate(reason);

    if (!mounted) return;
    setState(() {
      _prompting = false;
      _unlocked = ok;
    });
  }

  @override
  Widget build(BuildContext context) {
    final locked = context.watch<SettingsController>().biometricLock;

    if (!locked || _unlocked) return widget.child;

    return _LockScreen(onUnlock: _tryUnlock, busy: _prompting);
  }
}

class _LockScreen extends StatelessWidget {
  const _LockScreen({required this.onUnlock, required this.busy});

  final VoidCallback onUnlock;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.headerGradient),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const BrandMark(size: 66, onDark: true),
                  const SizedBox(height: 26),
                  Text(
                    t('security.locked'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    t('security.appLockSub'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.75),
                      fontSize: 13.5,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: 220,
                    child: FilledButton.icon(
                      onPressed: busy ? null : onUnlock,
                      icon: const Icon(Icons.fingerprint_rounded, size: 22),
                      label: Text(t('security.unlock')),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppTheme.brandDark,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  // The way out. Without this a phone whose fingerprint reader
                  // has stopped working has no route back into the app at all.
                  TextButton(
                    onPressed: () => context.read<AuthController>().logout(),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white.withValues(alpha: 0.85),
                    ),
                    child: Text(t('security.useSignOut')),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
