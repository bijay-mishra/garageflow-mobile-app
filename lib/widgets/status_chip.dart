import 'package:flutter/material.dart';

import '../core/theme.dart';

/// A coloured pill for a job or booking status.
///
/// The colour carries the meaning, so the tint is derived from the status
/// rather than passed in — one status cannot end up two colours on two screens.
class StatusChip extends StatelessWidget {
  const StatusChip(this.status, {super.key, this.dense = false, this.icon});

  final String status;
  final bool dense;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.statusColor(status);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 8 : 10,
        vertical: dense ? 3 : 5,
      ),
      decoration: BoxDecoration(
        // A tint of the status colour rather than the colour itself: a solid
        // fill at this size fights the text next to it for attention.
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: dense ? 11 : 13, color: color),
            const SizedBox(width: 4),
          ] else ...[
            Container(
              width: dense ? 5 : 6,
              height: dense ? 5 : 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            status,
            style: TextStyle(
              color: color,
              fontSize: dense ? 11 : 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}

/// A small outline pill — priority, fuel, vehicle type.
class MetaChip extends StatelessWidget {
  const MetaChip(this.label, {super.key, this.color, this.icon});

  final String label;
  final Color? color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final tone = color ?? AppTheme.ink500;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        border: Border.all(color: tone.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: tone),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: tone,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
