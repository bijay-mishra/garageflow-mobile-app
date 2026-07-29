import '../core/api_client.dart';
import '../core/formatters.dart';
import '../models/booking.dart';
import '../models/job.dart';
import '../models/vehicle.dart';

/// Everything the customer app asks the server for.
///
/// As with the mechanic side, no endpoint takes a customer id — the server
/// scopes each one to the signed-in account.
class CustomerService {
  CustomerService(this._api);

  final ApiClient _api;

  Future<List<Vehicle>> vehicles() async {
    final data = await _api.get<Map<String, dynamic>>('/customer/vehicles');

    return (data['list'] as List)
        .map((e) => Vehicle.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Work on the customer's vehicles. [active] limits it to what is in the
  /// workshop now — the "track status" screen.
  Future<List<CustomerJob>> jobs({bool active = true, String? vehicleId}) async {
    final data = await _api.get<Map<String, dynamic>>(
      '/customer/jobs',
      query: {'active': active, 'vehicleId': vehicleId},
    );

    return (data['list'] as List)
        .map((e) => CustomerJob.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<CustomerJob> job(String id) async {
    final data = await _api.get<Map<String, dynamic>>('/customer/jobs/$id');
    return CustomerJob.fromJson(data);
  }

  /// Completed work, newest first.
  Future<List<CustomerJob>> serviceHistory({String? vehicleId}) async {
    final data = await _api.get<Map<String, dynamic>>(
      '/customer/service-history',
      query: {'vehicleId': vehicleId},
    );

    return (data['list'] as List)
        .map((e) => CustomerJob.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<Booking>> bookings({String? status}) async {
    final data = await _api.get<Map<String, dynamic>>(
      '/bookings',
      query: {'status': status},
    );

    return (data['list'] as List)
        .map((e) => Booking.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Asks the workshop to look at a vehicle.
  ///
  /// [serviceIds] are optional extras off the price list — "and give it a wash
  /// while it is in". The server quotes each one at today's price and holds it
  /// there, so the estimate shown before tapping Request is the estimate the
  /// workshop is bound to.
  Future<Booking> book({
    required String vehicleId,
    required String complaint,
    required DateTime preferredDate,
    String preferredTime = '',
    List<String> serviceIds = const [],
  }) async {
    final data = await _api.post<Map<String, dynamic>>(
      '/bookings',
      body: {
        'vehicleId': vehicleId,
        'complaint': complaint.trim(),
        // The server's PreferredDate is a DateOnly, so it wants a bare date —
        // a full ISO timestamp would carry a timezone that could shift the day.
        'preferredDate': Fmt.isoDate(preferredDate),
        'preferredTime': preferredTime.trim(),
        'serviceIds': serviceIds,
      },
    );

    return Booking.fromJson(data);
  }

  Future<Booking> cancelBooking(String id) async {
    final data = await _api.put<Map<String, dynamic>>('/bookings/$id/cancel');
    return Booking.fromJson(data);
  }
}
