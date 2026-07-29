import 'package:flutter/material.dart';

import '../core/formatters.dart';
import '../core/theme.dart';
import '../models/service.dart';

/// Category → the colour it reads in, matching the dashboard's badges.
Color serviceCategoryColor(String category) => switch (category) {
  'Washing' => AppTheme.cyan,
  'Detailing' => AppTheme.violet,
  'Maintenance' => AppTheme.brand,
  'Repair' => AppTheme.amber,
  'Inspection' => AppTheme.emerald,
  'Convenience' => AppTheme.emerald,
  _ => AppTheme.ink500,
};

IconData serviceCategoryIcon(String category) => switch (category) {
  'Washing' => Icons.local_car_wash_rounded,
  'Detailing' => Icons.auto_awesome_rounded,
  'Maintenance' => Icons.build_circle_rounded,
  'Repair' => Icons.handyman_rounded,
  'Inspection' => Icons.fact_check_rounded,
  'Convenience' => Icons.local_shipping_rounded,
  _ => Icons.sell_rounded,
};

/// A selectable row on the price list.
///
/// Used by both sides of the app — the customer ticking extras when booking and
/// the mechanic adding one to a job — so a wash looks and costs the same
/// wherever it is offered.
class ServiceTile extends StatelessWidget {
  const ServiceTile({
    super.key,
    required this.service,
    required this.selected,
    required this.onTap,
    this.alreadyOn = false,
  });

  final WorkshopService service;
  final bool selected;
  final VoidCallback onTap;

  /// Already on the job. Shown ticked and inert rather than hidden, so it is
  /// obvious the wash is not missing — it is done.
  final bool alreadyOn;

  @override
  Widget build(BuildContext context) {
    final tone = serviceCategoryColor(service.category);
    final on = selected || alreadyOn;

    return Opacity(
      opacity: alreadyOn ? 0.6 : 1,
      child: Material(
        color: on && !alreadyOn ? AppTheme.brandLight : Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        child: InkWell(
          onTap: alreadyOn ? null : onTap,
          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              border: Border.all(
                color: on && !alreadyOn ? AppTheme.brand : AppTheme.ink200,
                width: on && !alreadyOn ? 1.6 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: tone.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(
                    serviceCategoryIcon(service.category),
                    size: 20,
                    color: tone,
                  ),
                ),
                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        service.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.ink900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        alreadyOn
                            ? 'Already on this job'
                            : _subtitle(service),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.ink500,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      // A free extra reads as "Free", not "Rs 0" — the latter
                      // looks like a price nobody got round to filling in.
                      service.price == 0 ? 'Free' : Fmt.rs(service.price),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.ink900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Icon(
                      on
                          ? Icons.check_circle_rounded
                          : Icons.add_circle_outline_rounded,
                      size: 19,
                      color: on ? AppTheme.brand : AppTheme.ink200,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The description if there is one, else the bay time, else the category —
  /// whichever tells the reader the most.
  static String _subtitle(WorkshopService service) {
    if (service.description.isNotEmpty) return service.description;
    if (service.durationLabel.isNotEmpty) {
      return '${service.category} · ${service.durationLabel}';
    }
    return service.category;
  }
}
