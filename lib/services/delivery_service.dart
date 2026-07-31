import '../core/api_client.dart';
import '../models/delivery.dart';

/// Handovers — choosing how a finished vehicle comes back, and following it.
///
/// One service for both audiences. The API scopes every call to whoever is
/// signed in, so a customer asking for a handover they do not own gets a 404
/// rather than somebody else's car: there is no client-side filtering here to
/// get wrong.
class DeliveryApi {
  DeliveryApi(this._api);

  final ApiClient _api;

  /// Live handovers. Finished and cancelled ones are excluded by default,
  /// which is what both the driver's list and the customer's home want.
  Future<List<Delivery>> list({String? status, bool active = true}) async {
    final data = await _api.get<Map<String, dynamic>>(
      '/deliveries',
      query: {'status': status, 'active': active, 'take': 50},
    );

    return ((data['list'] as List?) ?? const [])
        .map((e) => Delivery.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Delivery> get(String id) async {
    final data = await _api.get<Map<String, dynamic>>('/deliveries/$id');
    return Delivery.fromJson(data);
  }

  /// What home delivery would cost, before committing to it. Quoting is free
  /// and changes nothing, so the app asks before showing the button rather than
  /// making the customer choose blind.
  Future<DeliveryQuote> quote(String id) async {
    final data = await _api.get<Map<String, dynamic>>('/deliveries/$id/quote');
    return DeliveryQuote.fromJson(data);
  }

  /// The customer says how they want the vehicle back. The server's message
  /// carries the fee, so it is passed back rather than reworded.
  Future<ApiEnvelope<Map<String, dynamic>>> choose(
    String id,
    String method,
  ) => _api.postEnvelope<Map<String, dynamic>>(
    '/deliveries/$id/choose',
    body: {'method': method},
  );

  /// The driver sets off. The server takes the driver's name from the token
  /// rather than the body, so a mechanic always drives as themselves.
  Future<Delivery> start(String id) async {
    final data = await _api.post<Map<String, dynamic>>(
      '/deliveries/$id/start',
      body: const <String, dynamic>{},
    );

    return Delivery.fromJson(data);
  }

  /// The driver's phone reports where it is. Called on a timer while the
  /// tracking screen is open.
  Future<void> ping(
    String id, {
    required double latitude,
    required double longitude,
    double? accuracyMetres,
  }) => _api.post<dynamic>(
    '/deliveries/$id/ping',
    body: {
      'latitude': latitude,
      'longitude': longitude,
      'accuracyMetres': accuracyMetres,
    },
  );

  Future<Delivery> complete(String id) async {
    final data = await _api.post<Map<String, dynamic>>(
      '/deliveries/$id/complete',
      body: const <String, dynamic>{},
    );

    return Delivery.fromJson(data);
  }

  /// Where the driver is, and the route so far. Polled by both sides.
  Future<DeliveryTrack> track(String id) async {
    final data = await _api.get<Map<String, dynamic>>('/deliveries/$id/track');
    return DeliveryTrack.fromJson(data);
  }
}
