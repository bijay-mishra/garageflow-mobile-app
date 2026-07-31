import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/formatters.dart';
import 'core/i18n.dart';
import 'core/theme.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/splash_screen.dart';
import 'features/customer/customer_shell.dart';
import 'features/customer/garage_directory_screen.dart';
import 'features/mechanic/mechanic_shell.dart';
import 'features/profile/lock_gate.dart';
import 'state/auth_controller.dart';
import 'state/notification_controller.dart';
import 'state/settings_controller.dart';

class GarageFlowApp extends StatelessWidget {
  const GarageFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();

    // Dates and money follow the language: English shows Gregorian, Nepali
    // shows Bikram Sambat in Devanagari. Set here rather than passed down
    // because Fmt is called from a hundred places without a context — and this
    // build runs on every language change, so the value is never stale by the
    // time anything reads it.
    Fmt.language = settings.languageCode;

    return MaterialApp(
      title: 'GarageFlow',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      // The setting decides; ThemeMode.system hands it back to the phone.
      themeMode: settings.themeMode,
      locale: settings.locale,
      builder: (context, child) => AppLocalizations(
        languageCode: settings.languageCode,
        child: MediaQuery.withClampedTextScaling(
          // The chosen size, applied once at the root so every screen inherits
          // it. Clamped rather than set outright: the *phone's* accessibility
          // setting is also a text scale, and multiplying the two produced
          // layouts at 2.6× that nothing survives. This makes the app's setting
          // the ceiling as well as the floor, so the two cannot compound.
          minScaleFactor: settings.textSize.scale,
          maxScaleFactor: settings.textSize.scale,
          child: child ?? const SizedBox.shrink(),
        ),
      ),
      home: const AuthGate(),
    );
  }
}

/// Picks the shell from the signed-in role.
///
/// This is the whole of the app's "routing": one app, two audiences, and the
/// role on the login response decides which one you are. A mechanic can never
/// reach a customer screen or the reverse, because the other shell is not in
/// the tree at all — not merely hidden behind a guard.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();

    // Polling belongs to a signed-in session. Started and stopped here so it
    // cannot outlive one and start firing 401s after sign-out.
    final notifications = context.read<NotificationController>();

    return switch (auth.status) {
      AuthStatus.checking => const SplashScreen(),
      AuthStatus.signedOut => _stopPolling(notifications, const LoginScreen()),
      // The lock wraps only the signed-in shells. Locking the login screen
      // would leave anyone whose fingerprint stopped working with no way in.
      AuthStatus.signedIn => LockGate(
        child: _startPolling(notifications, _shellFor(auth)),
      ),
    };
  }

  /// Which app a signed-in person gets.
  ///
  /// The third case is the marketplace one: a customer whose account belongs to
  /// no garage yet. Everything in the customer shell is scoped to one workshop,
  /// so showing it would mean five tabs of empty states and no explanation. The
  /// directory *is* their home until they join somewhere.
  Widget _shellFor(AuthController auth) {
    if (auth.user!.isMechanic) return const MechanicShell();

    if (auth.needsGarage) {
      return const GarageDirectoryScreen(mustChoose: true);
    }

    return const CustomerShell();
  }

  Widget _startPolling(NotificationController controller, Widget child) {
    // Deferred to after this frame: start() notifies listeners, and doing that
    // during a build is exactly the "setState during build" error.
    WidgetsBinding.instance.addPostFrameCallback((_) => controller.start());
    return child;
  }

  Widget _stopPolling(NotificationController controller, Widget child) {
    WidgetsBinding.instance.addPostFrameCallback((_) => controller.reset());
    return child;
  }
}
