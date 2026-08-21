import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_update.dart';
import '../../core/config.dart';
import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../state/auth_controller.dart';
import '../../widgets/gradient_header.dart';
import '../../widgets/states.dart';

/// Suggest a feature, or report something broken.
///
/// Hands off to the phone's email app rather than posting to an endpoint, and
/// that is a deliberate choice rather than a shortcut. There is no feedback
/// inbox on the server, and building one means somewhere to store it, a screen
/// to read it and someone whose job is to answer it — none of which exists yet.
/// A form that silently posted into a table nobody opens would be worse than
/// this: it would look like it was heard.
///
/// The email opens pre-filled and *visible*, so the person can see exactly what
/// is being sent before they send it. What goes with it is listed on the screen,
/// because "diagnostics" attached without saying what they are is how apps end
/// up sending things people did not agree to.
class FeedbackScreen extends StatelessWidget {
  const FeedbackScreen({super.key});

  /// Where feedback goes. A workshop shipping its own build points this at
  /// whoever actually reads it.
  static const _to = String.fromEnvironment(
    'FEEDBACK_EMAIL',
    defaultValue: 'hello@garageflow.demo',
  );

  Future<void> _compose(BuildContext context) async {
    final t = AppText.of(context);
    final user = context.read<AuthController>().user;

    // Built here, in plain sight, and nothing is added that is not on screen.
    final body = [
      '',
      '',
      '---',
      '${t('feedback.appVersion')}: GarageFlow ${AppUpdate.installedLabel}',
      '${t('feedback.role')}: ${user?.role ?? '—'}',
      'Server: ${AppConfig.apiBaseUrl}',
    ].join('\n');

    final uri = Uri(
      scheme: 'mailto',
      path: _to,
      queryParameters: {'subject': t('feedback.subject'), 'body': body},
    );

    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);

    if (!opened && context.mounted) {
      showSnack(context, t('feedback.noEmailApp'), isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);
    final user = context.watch<AuthController>().user;
    final palette = AppTheme.of(context);

    return Scaffold(
      appBar: GradientAppBar(title: t('feedback.title')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        children: [
          AppCard(
            lifted: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppTheme.amber.withValues(alpha: 0.13),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.lightbulb_outline_rounded,
                        size: 21,
                        color: AppTheme.amber,
                      ),
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Text(
                        t('profile.featureRequestSub'),
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: palette.text,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  t('feedback.intro'),
                  style: TextStyle(
                    fontSize: 13,
                    color: palette.muted,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: () => _compose(context),
                  icon: const Icon(Icons.mail_outline_rounded, size: 19),
                  label: Text(t('feedback.compose')),
                ),
              ],
            ),
          ),

          const SizedBox(height: 22),
          SectionLabel(t('feedback.includes')),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Line(t('feedback.appVersion'), 'GarageFlow ${AppUpdate.installedLabel}'),
                _Line(t('feedback.role'), user?.role ?? '—'),
                _Line('Server', AppConfig.apiBaseUrl),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.shield_outlined,
                      size: 16,
                      color: AppTheme.emerald,
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        t('feedback.nothingElse'),
                        style: TextStyle(
                          fontSize: 12,
                          color: palette.faint,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final palette = AppTheme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: palette.faint),
            ),
          ),
          Flexible(
            child: Text(
              value,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: palette.muted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
