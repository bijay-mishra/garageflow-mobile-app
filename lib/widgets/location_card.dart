import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/theme.dart';

/// Where the customer is, with a way to get there.
///
/// Two halves, and both earn their place. The map answers "roughly where am I
/// going" at a glance — which side of town, how far — and the Directions button
/// hands the actual navigation to Google Maps or whatever the phone has.
/// Turn-by-turn is not something this app should try to own.
///
/// Tiles come from OpenStreetMap, the same source the dashboard uses through
/// Leaflet, so a pin looks the same in both places. No API key and no billing
/// account, which is the whole reason it was chosen.
class LocationCard extends StatelessWidget {
  const LocationCard({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.label,
    this.address = '',
    this.height = 170,
  });

  final double latitude;
  final double longitude;

  /// Who or what is at this pin — shown under the map.
  final String label;
  final String address;
  final double height;

  LatLng get _point => LatLng(latitude, longitude);

  Future<void> _openDirections(BuildContext context) async {
    // The Google Maps URL scheme rather than `geo:` — this opens the app when
    // it is installed and the website when it is not, on both platforms.
    // A bare `geo:` URI does nothing at all on a device with no maps app.
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude',
    );

    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);

    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No maps app to open this in.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        child: SizedBox(
          height: height,
          child: Stack(
            children: [
              FlutterMap(
                options: MapOptions(
                  initialCenter: _point,
                  initialZoom: 15,
                  // A small preview, not a map to explore. Panning it inside a
                  // scrolling job sheet fights the scroll gesture, and the
                  // Directions button is the way out to a real map.
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.none,
                  ),
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    // OpenStreetMap's usage policy requires a real user agent
                    // identifying the app. A default or spoofed one gets the
                    // client blocked from the tile servers.
                    userAgentPackageName: 'com.garageflow.mobile',
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _point,
                        width: 40,
                        height: 40,
                        child: const Icon(
                          Icons.location_on_rounded,
                          size: 38,
                          color: AppTheme.rose,
                        ),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 2,
                  ),
                  color: Colors.white70,
                  child: const Text(
                    '© OpenStreetMap',
                    style: TextStyle(fontSize: 8.5, color: AppTheme.ink700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),

      const SizedBox(height: 10),
      Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.ink900,
                  ),
                ),
                if (address.isNotEmpty)
                  Text(
                    address,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppTheme.ink500,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          OutlinedButton.icon(
            onPressed: () => _openDirections(context),
            icon: const Icon(Icons.directions_rounded, size: 18),
            label: const Text('Directions'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 40),
              padding: const EdgeInsets.symmetric(horizontal: 14),
            ),
          ),
        ],
      ),
    ],
  );
}
