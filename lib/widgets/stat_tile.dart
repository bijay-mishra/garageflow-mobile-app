import 'package:flutter/material.dart';

import '../core/theme.dart';
import 'gradient_header.dart';

/// One cell of a [StatStrip].
class Stat {
  const Stat({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.onTap,
    this.selected = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  /// Drawn as the active one — used when the strip doubles as a filter.
  final bool selected;
}

/// The numbers, as one card that hangs off the bottom of a gradient header.
///
/// A single strip rather than the 2×2 grid of bordered tiles this replaced. The
/// grid cost 150pt of vertical space above the list a mechanic actually came to
/// read, and four numbers in four boxes gave no clue which one mattered. Three
/// cells in one card is a glance instead of a scan.
class StatStrip extends StatelessWidget {
  const StatStrip({super.key, required this.stats});

  final List<Stat> stats;

  @override
  Widget build(BuildContext context) {
    final palette = AppTheme.of(context);

    return AppCard(
      lifted: true,
      padding: EdgeInsets.zero,
      // IntrinsicHeight, and it is load-bearing. `stretch` on a Row stretches
      // along the *cross* axis, which is vertical, so it needs a bounded height
      // to stretch to — and this card is laid out inside a Column, which hands
      // its children an unbounded one. Without this the Row demands infinite
      // height, the whole strip fails to lay out, and the mechanic's jobs
      // screen renders as a blank page.
      //
      // Two things need the stretch and neither is cosmetic: the dividers have
      // no height of their own, and the selected cell's colour wash has to
      // reach the edges of the card rather than stopping at the text.
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < stats.length; i++) ...[
              if (i > 0)
                VerticalDivider(
                  width: 1,
                  thickness: 1,
                  indent: 16,
                  endIndent: 16,
                  color: palette.border,
                ),
              Expanded(child: _Cell(stat: stats[i])),
            ],
          ],
        ),
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.stat});

  final Stat stat;

  @override
  Widget build(BuildContext context) {
    final palette = AppTheme.of(context);

    return InkWell(
      onTap: stat.onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        // The selected cell is washed in its own colour rather than outlined:
        // an outline inside a card that already has edges reads as clutter.
        color: stat.selected
            ? stat.color.withValues(alpha: 0.09)
            : Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(stat.icon, size: 17, color: stat.color),
            const SizedBox(height: 7),
            Text(
              stat.value,
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w800,
                height: 1,
                letterSpacing: -0.5,
                // A zero is greyed: "nothing awaiting parts" should not draw
                // the eye the way a real number does.
                color: stat.value == '0' ? palette.faint : palette.text,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              stat.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: palette.faint,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The bar under a customer job's status. Width and colour both come from the
/// server-computed progress, so the app never decides what "half done" means.
class ProgressBar extends StatelessWidget {
  const ProgressBar({super.key, required this.percent, required this.color});

  final int percent;
  final Color color;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(999),
    child: LinearProgressIndicator(
      value: percent / 100,
      minHeight: 7,
      backgroundColor: AppTheme.of(context).border,
      valueColor: AlwaysStoppedAnimation(color),
    ),
  );
}

/// A titled block of content with the app's card treatment.
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.child,
    this.title,
    this.trailing,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final String? title;
  final Widget? trailing;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final palette = AppTheme.of(context);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        // On dark a shadow under a dark card is invisible, so the edge does the
        // work instead. Same reasoning as AppCard.
        border: Theme.of(context).brightness == Brightness.dark
            ? Border.all(color: palette.border)
            : null,
        boxShadow: AppTheme.shadowCard,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title!,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: palette.faint,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                  ?trailing,
                ],
              ),
            ),
          Padding(padding: padding, child: child),
        ],
      ),
    );
  }
}

/// A label/value row, as used on every detail screen.
class DetailRow extends StatelessWidget {
  const DetailRow({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
    this.bold = false,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final palette = AppTheme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 116,
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: palette.faint),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13.5,
                color: valueColor ?? palette.text,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
