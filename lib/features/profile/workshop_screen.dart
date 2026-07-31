import 'package:flutter/material.dart';

import '../../core/config.dart';
import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../widgets/gradient_header.dart';
import '../customer/workshop_card.dart';

/// Where the workshop is, how to reach it, and which server the app is on.
///
/// Shown to both roles. A customer wants the address and a Directions button; a
/// mechanic wants the shop's own number to give out. The server line is the one
/// piece of engineering detail that has earned its place on a user-facing
/// screen — "is it talking to the right machine" is the first question when the
/// app cannot load, and it saves a rebuild to find out.
class WorkshopScreen extends StatelessWidget {
  const WorkshopScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);
    final palette = AppTheme.of(context);

    return Scaffold(
      appBar: GradientAppBar(title: t('profile.workshop')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        children: [
          const WorkshopCard(),

          const SizedBox(height: 22),
          SectionLabel(t('profile.about')),
          AppCard(
            child: Column(
              children: [
                _Line(t('about.version'), 'GarageFlow 1.0.0'),
                _Line(t('about.server'), AppConfig.apiBaseUrl),
              ],
            ),
          ),

          const SizedBox(height: 16),
          Text(
            t('about.accountManaged'),
            style: TextStyle(fontSize: 12, color: palette.faint, height: 1.45),
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
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: palette.faint),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: palette.text,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
