import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../services/google_sign_in_service.dart';
import '../../state/auth_controller.dart';

/// "Continue with Google".
///
/// Renders nothing at all when the build has no client ID, rather than showing
/// a disabled button or one that fails on tap. A control that cannot work is
/// worse than an absent one: it looks like the app is broken instead of like
/// the feature is off.
///
/// The mark is drawn rather than shipped as an asset. Google's four-colour "G"
/// is their trademark with brand rules attached, and a hand-drawn imitation
/// would be both a poor copy and a misuse — so this uses a neutral mark and
/// leaves the real asset to be dropped in by whoever agrees to those rules.
class GoogleSignInButton extends StatelessWidget {
  const GoogleSignInButton({super.key, this.onSignedIn});

  /// Called after a successful sign-in, for a screen that needs to pop itself.
  /// AuthGate swaps the shell either way, so this is usually unnecessary.
  final VoidCallback? onSignedIn;

  @override
  Widget build(BuildContext context) {
    final google = context.read<GoogleSignInService>();

    if (!google.isConfigured) return const SizedBox.shrink();

    final auth = context.watch<AuthController>();
    final palette = AppTheme.of(context);
    final t = AppText.of(context);

    // Just the button. The "or" divider that used to live here belongs to
    // SocialSignIn, which knows how many providers are on screen — this widget
    // does not, and two configured providers would have drawn two dividers.
    return OutlinedButton.icon(
      onPressed: auth.busy
          ? null
          : () async {
              final signedIn = await context
                  .read<AuthController>()
                  .signInWithGoogle(google);

              if (signedIn) onSignedIn?.call();
              // A false result is either a cancel — nothing to say — or an
              // error the controller has already put on screen.
            },
      icon: const _GoogleMark(),
      label: Text(t('auth.continueWithGoogle')),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        foregroundColor: palette.text,
        side: BorderSide(color: palette.border),
      ),
    );
  }
}

/// A placeholder mark.
///
/// Deliberately not an imitation of Google's logo — see the note on the button.
/// Drop `assets/google.png` from Google's own brand kit in here when you have
/// accepted their terms.
class _GoogleMark extends StatelessWidget {
  const _GoogleMark();

  @override
  Widget build(BuildContext context) => Container(
    width: 20,
    height: 20,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: AppTheme.brand.withValues(alpha: 0.12),
      shape: BoxShape.circle,
    ),
    child: const Text(
      'G',
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w800,
        color: AppTheme.brand,
        height: 1.1,
      ),
    ),
  );
}
