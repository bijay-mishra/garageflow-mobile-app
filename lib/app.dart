import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/theme.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/splash_screen.dart';
import 'features/customer/customer_shell.dart';
import 'features/mechanic/mechanic_shell.dart';
import 'state/auth_controller.dart';
import 'state/notification_controller.dart';

class GarageFlowApp extends StatelessWidget {
  const GarageFlowApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'GarageFlow',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light,
    home: const AuthGate(),
  );
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
      AuthStatus.signedIn => _startPolling(
        notifications,
        auth.user!.isMechanic ? const MechanicShell() : const CustomerShell(),
      ),
    };
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
