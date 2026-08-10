import 'package:flutter/material.dart';

import '../../core/i18n.dart';
import '../../core/theme.dart';
import 'plans_screen.dart';

/// The pitch, in the middle of the screen, every time a customer opens the app.
///
/// Every time is deliberate and was asked for. It used to show once and store a
/// flag, on the reasoning that an offer somebody has already declined is an
/// advert — but that is a call for whoever is selling the product to make, not
/// for the app to make on their behalf, and "once ever per install" turned out
/// to mean most people never saw it at all.
///
/// What it does keep is a way out that works: the X in the corner, the Not now
/// button, a tap outside it, and the back gesture all close it. Nothing here
/// can trap somebody who opened the app to check on their car.
///
/// A centred dialog rather than a bottom sheet. A sheet reads as part of the
/// screen it slid up over; this is meant to be the thing you look at first.
Future<void> showExplorePlansDialog(BuildContext context) => showDialog(
  context: context,
  // An offer that cannot be waved away is an advert with the door held shut.
  barrierDismissible: true,
  builder: (_) => const _ExplorePlansDialog(),
);

class _ExplorePlansDialog extends StatelessWidget {
  const _ExplorePlansDialog();

  /// What a paid plan buys, in the order somebody cares about it.
  static const _points = [
    (icon: Icons.block_rounded, key: 'plansPitch.noAds'),
    (icon: Icons.notifications_active_rounded, key: 'plansPitch.instant'),
    (icon: Icons.build_circle_outlined, key: 'plansPitch.parts'),
    (icon: Icons.history_rounded, key: 'plansPitch.history'),
  ];

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);
    final palette = AppTheme.of(context);

    return Dialog(
      backgroundColor: palette.card,
      insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 40),
      // Clipped so the gradient band follows the dialog's corners instead of
      // squaring them off.
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusHeader),
      ),
      child: SingleChildScrollView(
        // Scrollable, with a `min` column: on a small phone at the largest text
        // size this content is taller than the dialog, and one that cannot
        // scroll would simply clip the buttons that close it.
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 18),
              decoration: const BoxDecoration(
                gradient: AppTheme.headerGradient,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Icon(
                          Icons.workspace_premium_rounded,
                          size: 24,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            t('plansPitch.title'),
                            style: const TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.4,
                              height: 1.2,
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded, size: 20),
                        color: Colors.white,
                        tooltip: t('common.close'),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Text(
                      t('plansPitch.subtitle'),
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final point in _points)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: palette.accentWash,
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: Icon(
                              point.icon,
                              size: 18,
                              color: AppTheme.brand,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  t('${point.key}.title'),
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: palette.text,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  t('${point.key}.body'),
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    height: 1.4,
                                    color: palette.faint,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 2),
                  FilledButton(
                    onPressed: () {
                      // Held before the pop. Afterwards this context is defunct
                      // and `Navigator.of` on it would throw.
                      final navigator = Navigator.of(context);

                      // Popped first, so backing out of the plans screen
                      // returns to the app rather than to this dialog again.
                      navigator.pop();
                      navigator.push(
                        MaterialPageRoute(builder: (_) => const PlansScreen()),
                      );
                    },
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    child: Text(t('plansPitch.explore')),
                  ),
                  const SizedBox(height: 4),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(t('plansPitch.notNow')),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
