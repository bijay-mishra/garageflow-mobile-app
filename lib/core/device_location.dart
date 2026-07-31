import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// The phone's own position, with every refusal treated as an answer.
///
/// Wrapped rather than called directly from screens for one reason: location is
/// the most refusable thing the app asks for. The service can be off, the
/// permission can be denied, it can be denied forever, and the fix is different
/// each time. A screen that has to handle four cases at every call site handles
/// none of them, so this returns either a position or a sentence explaining why
/// there isn't one, and never throws.
class DeviceLocation {
  const DeviceLocation._();

  /// A single reading, asking for permission if it has not been asked yet.
  ///
  /// [LocationResult.point] is null on every failure. Nothing in the app
  /// *requires* a position — the directory falls back to alphabetical, and a
  /// driver can still mark a delivery done — so the caller's job is to carry on
  /// without one, not to block.
  static Future<LocationResult> current({
    LocationAccuracy accuracy = LocationAccuracy.high,
    Duration timeout = const Duration(seconds: 12),
  }) async {
    final gate = await _permit();
    if (gate != null) return gate;

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: accuracy,
          timeLimit: timeout,
        ),
      );

      return LocationResult(
        point: LatLng(position.latitude, position.longitude),
        accuracyMetres: position.accuracy,
      );
    } catch (_) {
      // A timeout indoors is ordinary rather than exceptional — a phone in a
      // workshop with a metal roof may simply never get a fix.
      return const LocationResult(
        reason: 'Could not get a location fix. Try again outdoors.',
      );
    }
  }

  /// A stream of positions, for a delivery in progress.
  ///
  /// [distanceFilter] means the phone only reports after it has actually moved,
  /// so a van sitting at a junction is not sending identical points every few
  /// seconds and draining the battery to say nothing.
  static Future<Stream<Position>?> watch({int distanceFilter = 25}) async {
    final gate = await _permit();
    if (gate != null) return null;

    return Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: distanceFilter,
      ),
    );
  }

  /// Opens the OS settings page for whichever thing is blocking us.
  static Future<void> openSettings({required bool appSettings}) =>
      appSettings ? Geolocator.openAppSettings() : Geolocator.openLocationSettings();

  /// Returns null when we are allowed to read a position, or the failure to
  /// report when we are not.
  static Future<LocationResult?> _permit() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return const LocationResult(
        reason: 'Location is switched off on this phone.',
        canOpenSettings: true,
      );
    }

    var permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      // Asking again does nothing at this point — Android will not show the
      // dialog a third time. The only route left is the app's settings page.
      return const LocationResult(
        reason: 'Location is blocked for GarageFlow in your phone settings.',
        canOpenSettings: true,
        needsAppSettings: true,
      );
    }

    if (permission == LocationPermission.denied) {
      return const LocationResult(reason: 'Location permission was declined.');
    }

    return null;
  }
}

/// Either a position or the reason there isn't one.
class LocationResult {
  const LocationResult({
    this.point,
    this.accuracyMetres,
    this.reason,
    this.canOpenSettings = false,
    this.needsAppSettings = false,
  });

  final LatLng? point;
  final double? accuracyMetres;

  /// Plain-language explanation, shown to the user as-is.
  final String? reason;

  /// True when there is an OS screen that would fix this.
  final bool canOpenSettings;

  /// True when the fix is the app's own permission page rather than the
  /// system location toggle.
  final bool needsAppSettings;

  bool get ok => point != null;
}
