import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/app_navigator.dart';
import 'core/app_update.dart';
import 'core/formatters.dart';
import 'core/i18n.dart';
import 'core/theme.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/set_password_screen.dart';
import 'features/auth/splash_screen.dart';
import 'features/customer/customer_shell.dart';
import 'features/mechanic/mechanic_shell.dart';
import 'features/profile/lock_gate.dart';
import 'widgets/states.dart';
import 'services/app_release_service.dart';
import 'state/auth_controller.dart';
import 'state/notification_controller.dart';
import 'state/support_controller.dart';
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
      // Reachable from the static notification-tap callbacks, which have no
      // BuildContext of their own — see AppNavigator.
      navigatorKey: AppNavigator.key,
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
      home: const UpdateCheck(child: AuthGate()),
    );
  }
}

/// Asks the server whether a newer build exists, once per launch.
///
/// Wrapped around [AuthGate] rather than put inside a shell, because the answer
/// matters before anybody has signed in. An app old enough that logging in has
/// stopped working is precisely the one that needs the prompt, and a check that
/// only ran after a successful login would never reach it.
///
/// Everything it decides lives in [AppUpdate] — this widget's whole job is to
/// have a [BuildContext] under the [MaterialApp] and a moment after the first
/// frame to use it in.
class UpdateCheck extends StatefulWidget {
  const UpdateCheck({super.key, required this.child});

  final Widget child;

  @override
  State<UpdateCheck> createState() => _UpdateCheckState();
}

class _UpdateCheckState extends State<UpdateCheck> {
  @override
  void initState() {
    super.initState();

    // After the first frame: the dialog needs a route to sit on, and there is
    // no navigator yet during this build. The round trip that follows also
    // gives the splash time to resolve, so an optional prompt lands on the app
    // rather than on a loading screen.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      AppUpdate.promptIfAvailable(context, context.read<AppReleaseService>());
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
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
    final support = context.read<SupportController>();

    return switch (auth.status) {
      AuthStatus.checking => const SplashScreen(),
      AuthStatus.signedOut => _stopPolling(notifications, support, const LoginScreen()),
      // The lock wraps only the signed-in shells. Locking the login screen
      // would leave anyone whose fingerprint stopped working with no way in.
      // Signed in, but still on a password somebody else typed. The shell is
      // deliberately not built: the server refuses its every request until this
      // is done, so showing it would be five tabs of "you do not have
      // permission". Polling stays off for the same reason.
      AuthStatus.signedIn when auth.mustSetPassword => _stopPolling(
        notifications,
        support,
        const SetPasswordScreen(),
      ),

      AuthStatus.signedIn => LockGate(
        child: _announceDeletionCancelled(
          context,
          auth,
          _startPolling(notifications, support, _shellFor(auth)),
        ),
      ),
    };
  }

  /// Says so when this sign-in called off a pending account deletion.
  ///
  /// It happens as a side effect of signing in — nobody pressed a button that
  /// said "keep my account" — so somebody who meant to leave has to be told
  /// they no longer are. Shown once: [AuthController.consumeDeletionCancelled]
  /// clears the flag, so it does not reappear on every rebuild.
  Widget _announceDeletionCancelled(
    BuildContext context,
    AuthController auth,
    Widget child,
  ) {
    if (!auth.deletionCancelled) return child;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted || !auth.consumeDeletionCancelled()) return;
      showSnack(context, AppText.of(context)('deleteAccount.cancelled'));
    });

    return child;
  }

  /// Which app a signed-in person gets.
  ///
  /// Two shells, not three. A customer who has joined no garage yet used to be
  /// held on the directory until they picked one, on the reasoning that every
  /// other screen is scoped to a workshop and would be empty without one.
  ///
  /// That reasoning was right about the screens and wrong about the order. The
  /// first thing somebody wants to do after signing up is put their car in —
  /// which the server now accepts with no garage, holding it as a draft against
  /// the account — and choosing a workshop is a decision they can only make
  /// sensibly once they know what they are booking and for which vehicle. So
  /// the home screen is the landing place for everybody, empty sections and
  /// all, and the directory is asked for at the one moment it is genuinely
  /// needed: pressing Book service. See `_book` in CustomerHomeScreen.
  Widget _shellFor(AuthController auth) {
    if (auth.user!.isMechanic) return const MechanicShell();

    return const CustomerShell();
  }

  Widget _startPolling(
    NotificationController controller,
    SupportController support,
    Widget child,
  ) {
    // Deferred to after this frame: start() notifies listeners, and doing that
    // during a build is exactly the "setState during build" error.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.start();
      support.start();
    });
    return child;
  }

  Widget _stopPolling(
    NotificationController controller,
    SupportController support,
    Widget child,
  ) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.reset();
      support.reset();
    });
    return child;
  }
}
