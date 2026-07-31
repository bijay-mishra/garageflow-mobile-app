import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_exception.dart';
import '../../core/formatters.dart';
import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../models/delivery.dart';
import '../../services/delivery_service.dart';
import '../../widgets/gradient_header.dart';
import '../../widgets/states.dart';
import '../../widgets/status_chip.dart';
import 'driver_trip_screen.dart';

/// The handovers waiting to go out, from the driver's side.
///
/// A mechanic sees every live handover rather than only their own, because in a
/// small workshop whoever is free takes the next run — and the API records the
/// driver from the token at the moment they set off, so it is still that person's
/// trip once they start it.
class MechanicDeliveriesScreen extends StatefulWidget {
  const MechanicDeliveriesScreen({super.key});

  @override
  State<MechanicDeliveriesScreen> createState() =>
      _MechanicDeliveriesScreenState();
}

class _MechanicDeliveriesScreenState extends State<MechanicDeliveriesScreen> {
  bool _loading = true;
  String? _error;
  List<Delivery> _deliveries = const [];
  String? _busyId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);

    try {
      final deliveries = await context.read<DeliveryApi>().list();
      if (!mounted) return;
      setState(() {
        _deliveries = deliveries;
        _loading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _loading = false;
      });
    }
  }

  Future<void> _start(Delivery delivery) async {
    setState(() => _busyId = delivery.id);

    try {
      await context.read<DeliveryApi>().start(delivery.id);
      if (!mounted) return;
      setState(() => _busyId = null);

      // Straight onto the trip screen: starting a delivery and then having to
      // find it again in a list is a step that exists for no reason.
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => DriverTripScreen(deliveryId: delivery.id),
        ),
      );
      if (mounted) _load();
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _busyId = null);
      showSnack(context, error.message, isError: true);
    }
  }

  Future<void> _complete(Delivery delivery) async {
    final t = AppText.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(
          delivery.isHomeDelivery
              ? t('driver.deliveredQuestion')
              : t('driver.handedOverQuestion'),
        ),
        content: Text(
          delivery.isHomeDelivery
              ? '${delivery.vehiclePlate} has been delivered to '
                    '${delivery.customerName}.'
              : '${delivery.customerName} has collected '
                    '${delivery.vehiclePlate}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(t('driver.notYet')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(t('common.confirm')),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _busyId = delivery.id);

    try {
      await context.read<DeliveryApi>().complete(delivery.id);
      if (!mounted) return;
      setState(() => _busyId = null);
      showSnack(context, t('driver.handedOver'));
      await _load();
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _busyId = null);
      showSnack(context, error.message, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);

    final onTheWay = _deliveries.where((d) => d.isOnTheWay).length;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppTheme.brand,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          children: [
            GradientHeader(
              title: t('driver.handovers'),
              subtitle: onTheWay > 0
                  ? t('driver.outForDelivery', [onTheWay])
                  : _deliveries.isEmpty
                  ? t('driver.nothingOut')
                  : t('driver.waiting', [_deliveries.length]),
              onBack: () => Navigator.pop(context),
              actions: [
                HeaderAction(
                  icon: Icons.refresh_rounded,
                  tooltip: t('common.refresh'),
                  onPressed: _load,
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
              child: _buildBody(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    final t = AppText.of(context);

    if (_loading) {
      return Padding(
        padding: EdgeInsets.only(top: 60),
        child: LoadingView(label: t('common.loading')),
      );
    }

    if (_error != null && _deliveries.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 40),
        child: ErrorView(message: _error!, onRetry: _load),
      );
    }

    if (_deliveries.isEmpty) {
      return Padding(
        padding: EdgeInsets.only(top: 40),
        child: EmptyView(
          icon: Icons.local_shipping_outlined,
          title: t('driver.emptyTitle'),
          message:
              t('driver.emptyMessage'),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final delivery in _deliveries)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _DeliveryCard(
              delivery: delivery,
              busy: _busyId == delivery.id,
              onStart: () => _start(delivery),
              onComplete: () => _complete(delivery),
              onFollow: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => DriverTripScreen(deliveryId: delivery.id),
                  ),
                );
                if (mounted) _load();
              },
            ),
          ),
      ],
    );
  }
}

class _DeliveryCard extends StatelessWidget {
  const _DeliveryCard({
    required this.delivery,
    required this.busy,
    required this.onStart,
    required this.onComplete,
    required this.onFollow,
  });

  final Delivery delivery;
  final bool busy;
  final VoidCallback onStart;
  final VoidCallback onComplete;
  final VoidCallback onFollow;

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);

    final palette = AppTheme.of(context);

    return AppCard(
    padding: const EdgeInsets.all(15),
    accent: delivery.isOnTheWay
        ? AppTheme.brand
        : delivery.awaitingChoice
        ? AppTheme.amber
        : AppTheme.cyan,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                delivery.vehiclePlate,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: palette.text,
                  letterSpacing: -0.3,
                ),
              ),
            ),
            StatusChip(delivery.chipStatus, dense: true),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          '${delivery.vehicleLabel} · ${delivery.customerName}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 12.5, color: palette.faint),
        ),

        const SizedBox(height: 12),
        Row(
          children: [
            Icon(
              delivery.isHomeDelivery
                  ? Icons.local_shipping_rounded
                  : Icons.storefront_rounded,
              size: 15,
              color: palette.faint,
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                delivery.isHomeDelivery
                    ? delivery.address.isEmpty
                          ? t('handover.homeDelivery')
                          : delivery.address
                    : t('handover.collection'),
                maxLines: 2,
                style: TextStyle(
                  fontSize: 13,
                  color: palette.muted,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),

        if (delivery.isHomeDelivery) ...[
          const SizedBox(height: 9),
          Row(
            children: [
              if (delivery.distanceKm != null) ...[
                Icon(
                  Icons.straighten_rounded,
                  size: 14,
                  color: palette.faint,
                ),
                const SizedBox(width: 5),
                Text(
                  '${delivery.distanceKm!.toStringAsFixed(1)} km',
                  style: TextStyle(fontSize: 12, color: palette.faint),
                ),
                const SizedBox(width: 14),
              ],
              Icon(
                Icons.payments_outlined,
                size: 14,
                color: palette.faint,
              ),
              const SizedBox(width: 5),
              Text(
                delivery.fee == 0 ? t('common.free') : Fmt.rs(delivery.fee),
                style: TextStyle(fontSize: 12, color: palette.faint),
              ),
              if (delivery.driver.isNotEmpty) ...[
                const Spacer(),
                Text(
                  delivery.driver,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: palette.faint,
                  ),
                ),
              ],
            ],
          ),
        ],

        const SizedBox(height: 15),
        if (delivery.awaitingChoice)
          // Nothing for a driver to do: the customer has not said yet whether
          // they want it delivered, and there is no run to make until they do.
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 11),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: palette.field,
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            ),
            child: Text(
              t('driver.waitingCustomer'),
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: palette.faint,
              ),
            ),
          )
        else if (delivery.isOnTheWay)
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onFollow,
                  icon: const Icon(Icons.map_outlined, size: 17),
                  label: Text(t('driver.openTrip')),
                  style: OutlinedButton.styleFrom(
                    minimumSize: Size.fromHeight(44),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: busy ? null : onComplete,
                  style: FilledButton.styleFrom(
                    minimumSize: Size.fromHeight(44),
                    backgroundColor: AppTheme.emerald,
                  ),
                  child: Text(t('handover.delivered')),
                ),
              ),
            ],
          )
        else if (delivery.isHomeDelivery)
          FilledButton.icon(
            onPressed: busy ? null : onStart,
            icon: busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  )
                : const Icon(Icons.navigation_rounded, size: 18),
            label: Text(busy ? t('driver.starting') : t('driver.startRun')),
            style: FilledButton.styleFrom(
              minimumSize: Size.fromHeight(46),
            ),
          )
        else
          FilledButton.icon(
            onPressed: busy ? null : onComplete,
            icon: const Icon(Icons.check_rounded, size: 18),
            label: Text(t('driver.collectedIt')),
            style: FilledButton.styleFrom(
              minimumSize: Size.fromHeight(46),
              backgroundColor: AppTheme.emerald,
            ),
          ),
      ],
    ),
  );
  }
}
