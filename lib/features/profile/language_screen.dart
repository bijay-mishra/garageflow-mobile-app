import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../state/settings_controller.dart';
import '../../widgets/gradient_header.dart';

/// English or Nepali.
///
/// Each option is written in its own script, because someone looking for Nepali
/// is looking for "नेपाली" — the English word "Nepali" is no help to a person
/// who cannot read the screen they are on.
///
/// The note at the bottom is not filler. This switch changes the *app's* words
/// and cannot touch the workshop's data: service names, job notes and vehicle
/// details are whatever the shop typed, so a Nepali app will still show
/// "Full synthetic oil change" if that is what is in the price list. Saying so
/// here avoids it reading as a broken translation.
class LanguageScreen extends StatelessWidget {
  const LanguageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    final t = AppText.of(context);
    final palette = AppTheme.of(context);

    return Scaffold(
      appBar: GradientAppBar(title: t('language.title')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
        children: [
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (final language in AppText.languages) ...[
                  if (language != AppText.languages.first)
                    Divider(height: 1, indent: 16, color: palette.border),
                  _Option(
                    native: language.native,
                    english: language.label,
                    selected: settings.languageCode == language.code,
                    onTap: () => settings.setLanguage(language.code),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: AppTheme.tintGradient(AppTheme.brand),
              borderRadius: BorderRadius.circular(AppTheme.radius),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  size: 18,
                  color: AppTheme.brand,
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    t('language.note'),
                    style: TextStyle(
                      fontSize: 12.5,
                      color: palette.muted,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Option extends StatelessWidget {
  const _Option({
    required this.native,
    required this.english,
    required this.selected,
    required this.onTap,
  });

  final String native;
  final String english;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = AppTheme.of(context);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    native,
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: palette.text,
                    ),
                  ),
                  // The English name underneath, so the list is navigable by
                  // someone who does not read the other script either.
                  if (native != english) ...[
                    const SizedBox(height: 2),
                    Text(
                      english,
                      style: TextStyle(fontSize: 12, color: palette.faint),
                    ),
                  ],
                ],
              ),
            ),
            if (selected)
              const Icon(
                Icons.check_circle_rounded,
                size: 21,
                color: AppTheme.brand,
              ),
          ],
        ),
      ),
    );
  }
}
