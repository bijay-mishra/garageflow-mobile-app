import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api_exception.dart';
import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../models/invoice.dart';
import '../../services/billing_service.dart';
import '../../widgets/location_card.dart';

/// Where the workshop is, and how to reach it.
///
/// The one thing a customer needs from the app that has nothing to do with their
/// own vehicle: which way to drive, and what number to ring when they are lost.
/// Loads itself so it can be dropped anywhere without the host screen having to
/// know about workshops.
class WorkshopCard extends StatefulWidget {
  const WorkshopCard({super.key});

  @override
  State<WorkshopCard> createState() => _WorkshopCardState();
}

class _WorkshopCardState extends State<WorkshopCard> {
  Workshop? _workshop;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final workshop = await context.read<BillingService>().workshop();
      if (mounted) setState(() { _workshop = workshop; _loading = false; });
    } on ApiException {
      // Silent. This is a supporting card on somebody else's screen, and an
      // error banner for "could not load the address" would be louder than the
      // information is worth.
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _call(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone.replaceAll(' ', ''));
    await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppTheme.of(context);

    final workshop = _workshop;

    if (_loading) {
      return const SizedBox(
        height: 90,
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2.2),
          ),
        ),
      );
    }

    if (workshop == null || workshop.name.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppTheme.brandLight,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(
                  Icons.storefront_rounded,
                  size: 20,
                  color: AppTheme.brand,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      workshop.name,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: palette.text,
                      ),
                    ),
                    if (workshop.address.isNotEmpty)
                      Text(
                        workshop.address,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: palette.faint,
                        ),
                      ),
                  ],
                ),
              ),
              if (workshop.phone.isNotEmpty)
                IconButton(
                  onPressed: () => _call(workshop.phone),
                  icon: const Icon(Icons.phone_rounded, size: 20),
                  color: AppTheme.brand,
                  tooltip: AppText.of(context)('handover.callWorkshop'),
                ),
            ],
          ),

          if (workshop.openingHours.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  Icons.schedule_rounded,
                  size: 15,
                  color: palette.faint,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    workshop.openingHours,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: palette.faint,
                    ),
                  ),
                ),
              ],
            ),
          ],

          // Only when the workshop has actually dropped a pin. A grey box where
          // a map should be reads as broken rather than as unset.
          if (workshop.hasLocation) ...[
            const SizedBox(height: 14),
            LocationCard(
              latitude: workshop.latitude!,
              longitude: workshop.longitude!,
              label: workshop.name,
              address: workshop.address,
              height: 150,
            ),
          ],
        ],
      ),
    );
  }
}
