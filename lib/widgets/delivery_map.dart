import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../core/theme.dart';
import '../models/delivery.dart';

/// The tracking map — workshop, route travelled, and where the driver is now.
///
/// Shared by the customer following their own car and the driver watching their
/// own trip, because it is the same picture from both ends. The only difference
/// is who is allowed to ask for the data, and the API settles that.
///
/// Deliberately not a routing map. The trail is where the driver has actually
/// been, joined by straight lines; there is no road-following path and no ETA,
/// because the server computes straight-line distance and inventing a road route
/// on top of that would be presenting a guess as a fact.
class DeliveryMap extends StatefulWidget {
  const DeliveryMap({
    super.key,
    required this.track,
    this.height = 300,
    this.interactive = true,
  });

  final DeliveryTrack track;
  final double height;
  final bool interactive;

  @override
  State<DeliveryMap> createState() => _DeliveryMapState();
}

class _DeliveryMapState extends State<DeliveryMap> {
  final _controller = MapController();

  /// True once the user has panned or zoomed. From that point the map stops
  /// re-framing itself on every poll — a map that yanks itself back every ten
  /// seconds while you are trying to look at something is unusable.
  bool _userMoved = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(DeliveryMap oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (_userMoved) return;

    final bounds = _bounds();
    if (bounds != null) {
      _controller.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.all(44),
          maxZoom: 16,
        ),
      );
    }
  }

  /// Every point worth keeping in frame.
  LatLngBounds? _bounds() {
    final points = <LatLng>[
      if (widget.track.hasOrigin)
        LatLng(widget.track.originLatitude!, widget.track.originLongitude!),
      if (widget.track.delivery.hasDestination)
        LatLng(
          widget.track.delivery.latitude!,
          widget.track.delivery.longitude!,
        ),
      if (widget.track.delivery.hasDriverPin)
        LatLng(
          widget.track.delivery.driverLatitude!,
          widget.track.delivery.driverLongitude!,
        ),
    ];

    if (points.isEmpty) return null;

    // A single point has no extent, and fitCamera on a zero-size bounds zooms
    // to the maximum. Nudged into a small box so one pin lands at street level.
    if (points.length == 1) {
      final only = points.first;
      return LatLngBounds(
        LatLng(only.latitude - 0.004, only.longitude - 0.004),
        LatLng(only.latitude + 0.004, only.longitude + 0.004),
      );
    }

    return LatLngBounds.fromPoints(points);
  }

  @override
  Widget build(BuildContext context) {
    final delivery = widget.track.delivery;
    final bounds = _bounds();

    if (bounds == null) {
      return _NoMap(height: widget.height);
    }

    final trail = widget.track.trail
        .map((p) => LatLng(p.latitude, p.longitude))
        .toList();

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTheme.radius),
      child: SizedBox(
        height: widget.height,
        child: Stack(
          children: [
            FlutterMap(
              mapController: _controller,
              options: MapOptions(
                initialCameraFit: CameraFit.bounds(
                  bounds: bounds,
                  padding: const EdgeInsets.all(44),
                  maxZoom: 16,
                ),
                interactionOptions: InteractionOptions(
                  flags: widget.interactive
                      ? InteractiveFlag.all & ~InteractiveFlag.rotate
                      : InteractiveFlag.none,
                ),
                onPositionChanged: (_, hasGesture) {
                  if (hasGesture && !_userMoved) {
                    setState(() => _userMoved = true);
                  }
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  // OpenStreetMap's usage policy requires a real user agent
                  // identifying the app. A default one gets the client blocked.
                  userAgentPackageName: 'com.garageflow.mobile',
                ),

                if (trail.length > 1)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: trail,
                        strokeWidth: 4,
                        color: AppTheme.brand.withValues(alpha: 0.75),
                        borderStrokeWidth: 1.5,
                        borderColor: Colors.white,
                      ),
                    ],
                  ),

                MarkerLayer(
                  markers: [
                    if (widget.track.hasOrigin)
                      Marker(
                        point: LatLng(
                          widget.track.originLatitude!,
                          widget.track.originLongitude!,
                        ),
                        width: 34,
                        height: 34,
                        child: const _Pin(
                          icon: Icons.home_repair_service_rounded,
                          color: AppTheme.ink700,
                        ),
                      ),
                    if (delivery.hasDestination)
                      Marker(
                        point: LatLng(delivery.latitude!, delivery.longitude!),
                        width: 34,
                        height: 34,
                        child: const _Pin(
                          icon: Icons.location_on_rounded,
                          color: AppTheme.rose,
                        ),
                      ),
                    if (delivery.hasDriverPin)
                      Marker(
                        point: LatLng(
                          delivery.driverLatitude!,
                          delivery.driverLongitude!,
                        ),
                        width: 44,
                        height: 44,
                        child: _DriverPin(live: widget.track.isLive),
                      ),
                  ],
                ),
              ],
            ),

            // Required by the OpenStreetMap tile usage policy. Do not remove.
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                color: Colors.white70,
                child: const Text(
                  '© OpenStreetMap',
                  style: TextStyle(fontSize: 8.5, color: AppTheme.ink700),
                ),
              ),
            ),

            // Only offered once the map has been moved: a "recentre" button on
            // a map that is already centred does nothing and invites a tap.
            if (_userMoved)
              Positioned(
                right: 10,
                top: 10,
                child: Material(
                  color: Colors.white,
                  shape: const CircleBorder(),
                  elevation: 2,
                  child: IconButton(
                    onPressed: () {
                      setState(() => _userMoved = false);
                      final refit = _bounds();
                      if (refit != null) {
                        _controller.fitCamera(
                          CameraFit.bounds(
                            bounds: refit,
                            padding: const EdgeInsets.all(44),
                            maxZoom: 16,
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.center_focus_strong_rounded),
                    color: AppTheme.ink700,
                    iconSize: 20,
                    tooltip: 'Recentre',
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// What to show when nobody involved has a pin. Honest rather than an empty
/// grey rectangle that looks like a map that failed to load.
class _NoMap extends StatelessWidget {
  const _NoMap({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) => Container(
    height: height,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: AppTheme.of(context).field,
      borderRadius: BorderRadius.circular(AppTheme.radius),
    ),
    child: const Padding(
      padding: EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.map_outlined, size: 30, color: AppTheme.ink400),
          SizedBox(height: 10),
          Text(
            'No positions to show yet',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: AppTheme.ink400,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'The map fills in once the driver sets off.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppTheme.ink400),
          ),
        ],
      ),
    ),
  );
}

class _Pin extends StatelessWidget {
  const _Pin({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      shape: BoxShape.circle,
      boxShadow: AppTheme.shadowCard,
    ),
    child: Icon(icon, size: 19, color: color),
  );
}

/// The driver. Ringed while the position is fresh, flat once it is stale, so
/// the map itself says whether it is telling you something current.
class _DriverPin extends StatelessWidget {
  const _DriverPin({required this.live});

  final bool live;

  @override
  Widget build(BuildContext context) {
    final color = live ? AppTheme.brand : AppTheme.ink400;

    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: live ? 0.22 : 0.12),
        shape: BoxShape.circle,
      ),
      child: Container(
        width: 28,
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2.5),
          boxShadow: live ? AppTheme.glow(color) : null,
        ),
        child: const Icon(
          Icons.local_shipping_rounded,
          size: 14,
          color: Colors.white,
        ),
      ),
    );
  }
}
