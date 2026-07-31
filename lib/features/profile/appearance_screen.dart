import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../state/settings_controller.dart';
import '../../widgets/gradient_header.dart';

/// Theme and text size, with a live sample.
///
/// The sample is the point of the screen. "Large" means nothing on its own, and
/// a person changing text size is doing it because something was hard to read —
/// so the thing they were struggling with is shown at the new size immediately,
/// in the shape it actually appears in the app.
class AppearanceScreen extends StatelessWidget {
  const AppearanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    final t = AppText.of(context);

    return Scaffold(
      appBar: GradientAppBar(title: t('appearance.title')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
        children: [
          SectionLabel(t('appearance.theme')),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (final mode in ThemeMode.values) ...[
                  if (mode != ThemeMode.values.first)
                    Divider(height: 1, indent: 52, color: AppTheme.of(context).border),
                  _Choice(
                    label: switch (mode) {
                      ThemeMode.system => t('appearance.system'),
                      ThemeMode.light => t('appearance.light'),
                      ThemeMode.dark => t('appearance.dark'),
                    },
                    icon: switch (mode) {
                      ThemeMode.system => Icons.brightness_auto_rounded,
                      ThemeMode.light => Icons.light_mode_rounded,
                      ThemeMode.dark => Icons.dark_mode_rounded,
                    },
                    selected: settings.themeMode == mode,
                    onTap: () => settings.setThemeMode(mode),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 22),
          SectionLabel(t('appearance.textSize')),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (final choice in TextSizeChoice.values) ...[
                  if (choice != TextSizeChoice.values.first)
                    Divider(height: 1, indent: 52, color: AppTheme.of(context).border),
                  _Choice(
                    label: choice.label,
                    icon: Icons.format_size_rounded,
                    // Each row is drawn at its own size, so the list is its own
                    // preview before anything is selected.
                    labelScale: choice.scale,
                    selected: settings.textSize == choice,
                    onTap: () => settings.setTextSize(choice),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 22),
          SectionLabel(t('appearance.preview')),
          const _Preview(),
        ],
      ),
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.labelScale = 1,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final double labelScale;

  @override
  Widget build(BuildContext context) {
    final palette = AppTheme.of(context);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: selected ? AppTheme.brand : palette.faint,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14.5 * labelScale,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? palette.text : palette.muted,
                ),
              ),
            ),
            if (selected)
              const Icon(
                Icons.check_circle_rounded,
                size: 20,
                color: AppTheme.brand,
              ),
          ],
        ),
      ),
    );
  }
}

/// A real job card, at the chosen size and in the chosen theme.
class _Preview extends StatelessWidget {
  const _Preview();

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);
    final palette = AppTheme.of(context);

    return AppCard(
      padding: const EdgeInsets.all(15),
      accent: AppTheme.cyan,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t('appearance.previewPlate'),
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: palette.text,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            t('appearance.previewLine'),
            style: TextStyle(fontSize: 12.5, color: palette.faint),
          ),
        ],
      ),
    );
  }
}
