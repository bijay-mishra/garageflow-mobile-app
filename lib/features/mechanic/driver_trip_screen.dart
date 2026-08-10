import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api_exception.dart';
import '../../core/device_location.dart';
import '../../core/formatters.dart';
import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../models/delivery.dart';
import '../../services/delivery_service.dart';
import '../../widgets/delivery_map.dart';
import '../../widgets/gradient_header.dart';
import '../../widgets/states.dart';

/// The driver's own screen while a vehicle is out.
///
/// This is the one place in the app that reports the phone's position, and it
/// only does so while it is on screen. Leaving it — backgrounding the app,
/// tapping back — stops the reporting, which is why the customer's side is
/// careful to say how old a position is rather than treating the last one as
/// live. The alternative was a background location permission, and following a
/// mechanic's phone when they are not working is not something a delivery
/// feature has any business asking for.
class DriverTripScreen extends StatefulWidget {
  const DriverTripScreen({super.key, required this.deliveryId});

  final String deliveryId;

  @override
  State<DriverTripScreen> createState() => _DriverTripScreenState();
}

class _DriverTripScreenState extends State<DriverTripScreen>
    with WidgetsBindingObserver {
  /// How often the map itself is re-read. The *position* is pushed as the phone
  /// moves rather than on this timer.
  static const _refresh = Duration(seconds: 12);

  DeliveryTrack? _track;
  String? _error;
  bool _loading = true;
  bool _completing = false;

  Timer? _poll;
  StreamSubscription<Position>? _positions;

  /// Why we are not reporting, when we are not. Shown as a banner rather than
  /// silently failing — a driver whose position is not being sent should know,
  /// because the customer is watching a map that will not move.
  String? _trackingProblem;
  bool _needsAppSettings = false;
  int _sent = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load().then((_) => _startReporting());
  }

  @override
  void dispose() {
    _poll?.cancel();
    _positions?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _load();
      _startReporting();
    } else {
      _poll?.cancel();
      _poll = null;
      // The promise this screen makes: reporting stops with the screen.
      _positions?.cancel();
      _positions = null;
    }
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
        _error = error.message;
        _loading = false;
      });
    }

    _poll?.cancel();
    if (_track?.delivery.isOnTheWay == true) {
      _poll = Timer(_refresh, _load);
    }
  }

  Future<void> _startReporting() async {
    final t = AppText.of(context);

    // Only a live run has anywhere to send positions to.
    if (_track?.delivery.isOnTheWay != true) return;
    if (_positions != null) return;

    final stream = await DeviceLocation.watch();

    if (!mounted) return;

    if (stream == null) {
      // Find out *why* so the banner can say something useful, and so the
      // "open settings" button goes to the right screen.
      final probe = await DeviceLocation.current();
      if (!mounted) return;
      setState(() {
        _trackingProblem = probe.reason ?? t('driver.locationUnavailable');
        _needsAppSettings = probe.needsAppSettings;
      });
      return;
    }

    setState(() {
      _trackingProblem = null;
      _needsAppSettings = false;
    });

    // Resolved once, here, rather than inside the callback. The stream outlives
    // any single frame, and reaching for the context from a listener that fires
    // after this widget has gone is exactly the lookup that throws.
    final api = context.read<DeliveryApi>();

    _positions = stream.listen((position) async {
      try {
        await api.ping(
          widget.deliveryId,
          latitude: position.latitude,
          longitude: position.longitude,
          accuracyMetres: position.accuracy,
        );
        if (mounted) setState(() => _sent++);
      } on ApiException {
        // A dropped ping is ordinary — a van goes through places with no
        // signal. The next one carries the current position anyway, so there
        // is nothing to retry and nothing worth interrupting the driver over.
      }
    });
  }

  Future<void> _navigate(Delivery delivery) async {
    final t = AppText.of(context);

    if (!delivery.hasDestination) {
      showSnack(context, t('driver.noPin'), isError: true);
      return;
    }

    // Handed off to whatever maps app the phone has. Turn-by-turn is not
    // something this app should try to own.
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination='
      '${delivery.latitude},${delivery.longitude}&travelmode=driving',
    );

    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
        mounted) {
      showSnack(context, t('driver.noMapsApp'), isError: true);
    }
  }

  Future<void> _call(String phone) async {
    final t = AppText.of(context);

    final uri = Uri.parse('tel:$phone');
    if (!await launchUrl(uri) && mounted) {
      showSnack(context, t('driver.noDialler'), isError: true);
    }
  }

  Future<void> _complete() async {
    final t = AppText.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(t('driver.deliveredQuestion')),
        content: Text(
          t('driver.confirmDelivered', [
            _track?.delivery.vehiclePlate ?? '—',
            _track?.delivery.customerName ?? '—',
          ]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(t('driver.notYet')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(t('handover.delivered')),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _completing = true);

    try {
      await context.read<DeliveryApi>().complete(widget.deliveryId);
      if (!mounted) return;

      _positions?.cancel();
      _positions = null;
      _poll?.cancel();

      showSnack(context, t('driver.handedOver'));
      Navigator.of(context).pop();
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _completing = false);
      showSnack(context, error.message, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final delivery = _track?.delivery;

    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          GradientHeader(
            title: delivery?.vehiclePlate ?? 'Delivery',
            subtitle: delivery == null
                ? null
                : 'to ${delivery.customerName}',
            onBack: () => Navigator.pop(context),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
            child: _buildBody(),
          ),
        ],
      ),
      bottomNavigationBar: delivery?.isOnTheWay == true
          ? _CompleteBar(busy: _completing, onComplete: _complete)
          : null,
    );
  }

  Widget _buildBody() {
    final t = AppText.of(context);

    final palette = AppTheme.of(context);

    if (_loading) {
      return Padding(
        padding: EdgeInsets.only(top: 60),
        child: LoadingView(label: t('driver.loadingTrip')),
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
        if (_trackingProblem != null) ...[
          _ProblemBanner(
            message: _trackingProblem!,
            needsAppSettings: _needsAppSettings,
            onFix: () => DeviceLocation.openSettings(
              appSettings: _needsAppSettings,
            ),
            onRetry: _startReporting,
          ),
          const SizedBox(height: 14),
        ] else if (delivery.isOnTheWay) ...[
          _ReportingStrip(sent: _sent, track: track),
          const SizedBox(height: 14),
        ],

        DeliveryMap(track: track, height: 320),

        const SizedBox(height: 20),
        const SectionLabel('Drop-off'),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                delivery.customerName,
                style: TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w700,
                  color: palette.text,
                ),
              ),
              if (delivery.address.isNotEmpty) ...[
                const SizedBox(height: 5),
                Text(
                  delivery.address,
                  style: TextStyle(
                    fontSize: 13,
                    color: palette.muted,
                    height: 1.4,
                  ),
                ),
              ],
              const SizedBox(height: 12),
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
                      style: TextStyle(
                        fontSize: 12.5,
                        color: palette.faint,
                      ),
                    ),
                    const SizedBox(width: 16),
                  ],
                  Icon(
                    Icons.payments_outlined,
                    size: 14,
                    color: palette.faint,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    delivery.fee == 0 ? 'Free' : Fmt.rs(delivery.fee),
                    style: TextStyle(
                      fontSize: 12.5,
                      color: palette.faint,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _navigate(delivery),
                      icon: const Icon(Icons.directions_rounded, size: 17),
                      label: Text(t('driver.navigate')),
                      style: OutlinedButton.styleFrom(
                        minimumSize: Size.fromHeight(44),
                      ),
                    ),
                  ),
                  if (delivery.customerPhone.isNotEmpty) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _call(delivery.customerPhone),
                        icon: const Icon(Icons.call_rounded, size: 17),
                        label: Text(t('driver.call')),
                        style: OutlinedButton.styleFrom(
                          minimumSize: Size.fromHeight(44),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),

        if (delivery.isDone) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: AppTheme.tintGradient(AppTheme.emerald),
              borderRadius: BorderRadius.circular(AppTheme.radius),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  size: 19,
                  color: AppTheme.emerald,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    delivery.completedAt == null
                        ? t('driver.handedOver')
                        : t('driver.handedOverAt', [
                            Fmt.time(delivery.completedAt!),
                          ]),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: palette.text,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Confirms, out loud, that positions are going out — and how many.
class _ReportingStrip extends StatelessWidget {
  const _ReportingStrip({required this.sent, required this.track});

  final int sent;
  final DeliveryTrack track;

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);

    final palette = AppTheme.of(context);

    return AppCard(
    lifted: true,
    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
    child: Row(
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            color: AppTheme.emerald,
            shape: BoxShape.circle,
            boxShadow: AppTheme.glow(AppTheme.emerald),
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t('driver.sharing'),
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: palette.text,
                ),
              ),
              SizedBox(height: 2),
              Text(
                t('driver.sharingStops'),
                style: TextStyle(fontSize: 11.5, color: palette.faint),
              ),
            ],
          ),
        ),
        if (sent > 0)
          Text(
            '$sent sent',
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

class _ProblemBanner extends StatelessWidget {
  const _ProblemBanner({
    required this.message,
    required this.needsAppSettings,
    required this.onFix,
    required this.onRetry,
  });

  final String message;
  final bool needsAppSettings;
  final VoidCallback onFix;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);

    final palette = AppTheme.of(context);

    return Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      gradient: AppTheme.tintGradient(AppTheme.rose),
      borderRadius: BorderRadius.circular(AppTheme.radius),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.location_off_rounded,
              size: 19,
              color: AppTheme.rose,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t('driver.cannotSee'),
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: palette.text,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    message,
                    style: TextStyle(
                      fontSize: 12,
                      color: palette.muted,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 11),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: onFix,
                style: OutlinedButton.styleFrom(
                  minimumSize: Size.fromHeight(40),
                ),
                child: Text(
                  needsAppSettings
                      ? t('driver.appSettings')
                      : t('driver.locationSettings'),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton(
                onPressed: onRetry,
                style: FilledButton.styleFrom(
                  minimumSize: Size.fromHeight(40),
                ),
                child: Text(t('common.retry')),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // The delivery still works without tracking. Said plainly so nobody
        // thinks they are stuck.
        Text(
          t('driver.stillWorks'),
          style: TextStyle(fontSize: 11.5, color: palette.faint),
        ),
      ],
    ),
  );
  }
}

/// The one action a driver needs while holding a phone in a car park.
class _CompleteBar extends StatelessWidget {
  const _CompleteBar({required this.busy, required this.onComplete});

  final bool busy;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);

    return Container(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
    decoration: BoxDecoration(
      color: AppTheme.of(context).card,
      boxShadow: AppTheme.shadowLifted,
    ),
    child: SafeArea(
      top: false,
      child: FilledButton.icon(
        onPressed: busy ? null : onComplete,
        icon: busy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(Colors.white),
                ),
              )
            : const Icon(Icons.check_circle_rounded, size: 20),
        label: Text(busy ? t('common.saving') : t('driver.markDelivered')),
        style: FilledButton.styleFrom(
          backgroundColor: AppTheme.emerald,
          minimumSize: Size.fromHeight(52),
        ),
      ),
    ),
  );
  }
}
