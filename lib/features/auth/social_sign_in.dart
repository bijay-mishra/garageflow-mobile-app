import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../services/google_sign_in_service.dart';
import 'google_button.dart';

/// The one-tap ways in, above the email and password fields.
///
/// ## Why above
///
/// Someone who has an account with one of these providers should not have to
/// read past a form they are not going to fill in. Putting the providers first
/// and the email form under an "or" is the arrangement almost every consumer
/// app has converged on, and it is the right way round here for the same
/// reason: the fastest route should be the one you see first.
///
/// ## Why it can vanish entirely
///
/// Each provider is hidden unless this build is configured for it, so a
/// workshop that has set up neither sees a plain email form with no gap where
/// something used to be — the divider belongs to this widget precisely so it
/// disappears along with the buttons rather than sitting above nothing.
///
/// A provider that cannot work is never shown as a disabled button. A control
/// that fails on tap reads as a broken app; an absent one reads as a feature
/// that is off, which is the truth.
class SocialSignIn extends StatelessWidget {
  const SocialSignIn({super.key, this.onSignedIn});

  /// Called after a successful sign-in, for a screen that needs to pop itself.
  final VoidCallback? onSignedIn;

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);
    final palette = AppTheme.of(context);

    // Asked of the service rather than of the config directly: being
    // "configured" also means the platform can actually run the flow, which
    // desktop and web cannot.
    final hasGoogle = context.read<GoogleSignInService>().isConfigured;

    final buttons = <Widget>[
      if (hasGoogle) GoogleSignInButton(onSignedIn: onSignedIn),
    ];

    if (buttons.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final button in buttons) ...[button, const SizedBox(height: 10)],

        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: Divider(color: palette.border)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                t('auth.orWithEmail'),
                style: TextStyle(fontSize: 12, color: palette.faint),
              ),
            ),
            Expanded(child: Divider(color: palette.border)),
          ],
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}
