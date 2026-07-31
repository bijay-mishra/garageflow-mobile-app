import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api_exception.dart';
import '../../core/formatters.dart';
import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../models/delivery.dart';
import '../../services/delivery_service.dart';
import '../../widgets/delivery_map.dart';
import '../../widgets/gradient_header.dart';
import '../../widgets/states.dart';
import '../../widgets/status_chip.dart';
import 'handover_sheet.dart';

/// Following your own vehicle home.
///
/// Polls rather than holds a socket. The driver's phone reports every time it
/// moves 25 metres, so there is nothing to stream between those points, and a
/// poll survives the connection dropping in a lift without any reconnect logic.
class TrackDeliveryScreen extends StatefulWidget {
  const TrackDeliveryScreen({super.key, required this.deliveryId});

  final String deliveryId;

  @override
  State<TrackDeliveryScreen> createState() => _TrackDeliveryScreenState();
}

class _TrackDeliveryScreenState extends State<TrackDeliveryScreen>
    with WidgetsBindingObserver {
  static const _interval = Duration(seconds: 10);

  DeliveryTrack? _track;
  String? _error;
  bool _loading = true;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    _poll?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Polling a position nobody is looking at is a request every ten seconds
    // for nothing. Stopped when the app goes to the background, and one
    // immediate refresh on the way back so the map is not showing a minute-old
    // dot when the screen reappears.
    if (state == AppLifecycleState.resumed) {
      _load();
    } else {
      _poll?.cancel();
      _poll = null;
    }
  }

  void _schedule() {
    _poll?.cancel();

    // Only while the vehicle is actually moving. A delivered or not-yet-started
    // handover will not change on its own, and polling it forever would be a
    // timer running for the life of the screen to learn nothing.
    if (_track?.delivery.isOnTheWay != true) return;

    _poll = Timer(_interval, _load);
  }

  Future<void> _load() async {
    try {
      final track = await context.read<DeliveryApi>().track(widget.deliveryId);

      if (!mounted) return;
      setState(() {
        _track = track;
        _error = null;
        _loading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        // A failed poll keeps the last good position on screen rather than
        // replacing a working map with an error — the car has not vanished
        // because one request timed out.
        _error = error.message;
        _loading = false;
      });
    }

    _schedule();
  }

  Future<void> _call(String phone) async {
    final t = AppText.of(context);

    final uri = Uri.parse('tel:$phone');
    if (!await launchUrl(uri) && mounted) {
      showSnack(context, t('driver.noDialler'), isError: true);
    }
  }

  Future<void> _choose(Delivery delivery) async {
    if (await showHandoverSheet(context, delivery) && mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);

    final track = _track;
    final delivery = track?.delivery;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppTheme.brand,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          children: [
            GradientHeader(
              title: delivery?.headline ?? t('handover.yourVehicle'),
              subtitle: delivery == null
                  ? null
                  : '${delivery.vehicleLabel} · ${delivery.vehiclePlate}',
              onBack: () => Navigator.pop(context),
              actions: [
                HeaderAction(
                  icon: Icons.refresh_rounded,
                  tooltip: 'Refresh',
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

    final palette = AppTheme.of(context);

    if (_loading) {
      return Padding(
        padding: EdgeInsets.only(top: 60),
        child: LoadingView(label: t('handover.finding')),
      );
    }

    final track = _track;

    if (track == null) {
      return Padding(
        padding: const EdgeInsets.only(top: 40),
        child: ErrorView(
          message: _error ?? t('driver.notFound'),
          onRetry: _load,
        ),
      );
    }

    final delivery = track.delivery;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Still waiting on the customer. The map is pointless here; the choice
        // is the whole screen.
        if (delivery.awaitingChoice) ...[
          AppCard(
            lifted: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      size: 20,
                      color: AppTheme.emerald,
                    ),
                    SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        t('handover.workFinished'),
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                          color: palette.text,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                Text(
                  t('handover.workFinishedBody'),
                  style: TextStyle(
                    fontSize: 13,
                    color: palette.muted,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => _choose(delivery),
                  child: Text(t('handover.chooseCta')),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ] else if (delivery.isHomeDelivery) ...[
          _StatusStrip(track: track),
          const SizedBox(height: 14),
          DeliveryMap(track: track),
          const SizedBox(height: 20),
        ],

        if (_error != null) ...[
          _StaleNotice(_error!),
          const SizedBox(height: 16),
        ],

        const SectionLabel('Handover'),
        AppCard(
          child: Column(
            children: [
              _Row(
                label: t('handover.method'),
                value: delivery.isHomeDelivery
                    ? t('handover.homeDelivery')
                    : t('handover.collection'),
              ),
              _Row(label: t('handover.status'), child: StatusChip(delivery.chipStatus)),
              if (delivery.isHomeDelivery) ...[
                if (delivery.address.isNotEmpty)
                  _Row(label: t('handover.address'), value: delivery.address),
                if (delivery.distanceKm != null)
                  _Row(
                    label: t('handover.distance'),
                    value: '${delivery.distanceKm!.toStringAsFixed(1)} km',
                  ),
                _Row(
                  label: t('handover.fee'),
                  value: delivery.fee == 0
                      ? 'Free'
                      : '${Fmt.rs(delivery.fee)} — on your bill',
                ),
              ],
              if (delivery.driver.isNotEmpty)
                _Row(label: t('handover.driver'), value: delivery.driver),
              if (delivery.startedAt != null)
                _Row(
                  label: t('handover.setOff'),
                  value: Fmt.time(delivery.startedAt!),
                ),
              if (delivery.completedAt != null)
                _Row(
                  label: delivery.isHomeDelivery ? 'Delivered' : 'Collected',
                  value: Fmt.time(delivery.completedAt!),
                ),
            ],
          ),
        ),

        if (delivery.customerPhone.isNotEmpty && !delivery.isDone) ...[
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => _call(delivery.customerPhone),
            icon: const Icon(Icons.call_rounded, size: 18),
            label: Text(t('handover.callWorkshop')),
          ),
        ],

        if (!delivery.isDone && !delivery.awaitingChoice) ...[
          const SizedBox(height: 16),
          Text(
            delivery.isHomeDelivery
                ? t('handover.trackingNote')
                : t('handover.bringId'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: palette.faint,
              height: 1.4,
            ),
          ),
        ],
      ],
    );
  }
}

/// The live line above the map: is this current, and who has the car.
class _StatusStrip extends StatelessWidget {
  const _StatusStrip({required this.track});

  final DeliveryTrack track;

  @override
  Widget build(BuildContext context) {
    final palette = AppTheme.of(context);

    final live = track.isLive;
    final color = live ? AppTheme.emerald : palette.faint;

    return AppCard(
      lifted: true,
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
      child: Row(
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: live ? AppTheme.glow(color) : null,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  track.freshness,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: live ? palette.text : palette.faint,
                  ),
                ),
                if (track.delivery.driver.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    '${track.delivery.driver} is bringing it',
                    style: TextStyle(
                      fontSize: 12,
                      color: palette.faint,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (track.delivery.distanceKm != null)
            Text(
              '${track.delivery.distanceKm!.toStringAsFixed(1)} km trip',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: palette.faint,
              ),
            ),
        ],
      ),
    );
  }
}

/// Shown when a poll failed but the map is still holding its last good state.
class _StaleNotice extends StatelessWidget {
  const _StaleNotice(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    final palette = AppTheme.of(context);
    final t = AppText.of(context);

    return Container(
    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
    decoration: BoxDecoration(
      gradient: AppTheme.tintGradient(AppTheme.amber),
      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
    ),
    child: Row(
      children: [
        const Icon(Icons.cloud_off_rounded, size: 17, color: AppTheme.amber),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            t('handover.stale', [message]),
            style: TextStyle(
              fontSize: 12,
              color: palette.muted,
              height: 1.3,
            ),
          ),
        ),
      ],
    ),
  );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, this.value, this.child});

  final String label;
  final String? value;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final palette = AppTheme.of(context);

    return Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 108,
          child: Text(
            label,
            style: TextStyle(fontSize: 13, color: palette.faint),
          ),
        ),
        Expanded(
          child: child == null
              ? Text(
                  value ?? '—',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: palette.text,
                  ),
                )
              : Align(alignment: Alignment.centerLeft, child: child),
        ),
      ],
    ),
  );
  }
}
