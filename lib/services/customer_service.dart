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

  /// Registers a vehicle on the signed-in customer's own account.
  ///
  /// No customer id goes up: the server takes the owner from the token, so this
  /// can only ever add to your own account.
  ///
  /// [fuel] and [type] are sent as the server's own vocabulary rather than the
  /// translated label on screen — the Nepali for "Petrol" is not a value the
  /// API accepts.
  Future<Vehicle> addVehicle({
    required String plate,
    required String make,
    required String model,
    required int year,
    String type = 'Car',
    String fuel = 'Petrol',
    int odometer = 0,
    String color = '',
  }) async {
    final data = await _api.post<Map<String, dynamic>>(
      '/customer/vehicles',
      body: {
        'plate': plate.trim(),
        'make': make.trim(),
        'model': model.trim(),
        'year': year,
        'type': type,
        'fuel': fuel,
        'odometer': odometer,
        'color': color.trim(),
      },
    );

    return Vehicle.fromJson(data);
  }

  /// Corrects one of the customer's own vehicles.
  ///
  /// The whole record goes up, not a patch: the form shows every field already
  /// filled in, so anything missing from the body would be a field the customer
  /// could see on screen and could not change.
  ///
  /// The plate may be edited — cars really are re-registered, and past bills
  /// keep their own snapshot of it. A plate already used at this garage comes
  /// back as an [ApiException] with the server's own wording.
  Future<Vehicle> updateVehicle({
    required String id,
    required String plate,
    required String make,
    required String model,
    required int year,
    String type = 'Car',
    String fuel = 'Petrol',
    int odometer = 0,
    String color = '',
  }) async {
    final data = await _api.put<Map<String, dynamic>>(
      '/customer/vehicles/$id',
      body: {
        'plate': plate.trim(),
        'make': make.trim(),
        'model': model.trim(),
        'year': year,
        'type': type,
        'fuel': fuel,
        'odometer': odometer,
        'color': color.trim(),
      },
    );

    return Vehicle.fromJson(data);
  }

  /// Removes a vehicle from the customer's account.
  ///
  /// Only works on a car the workshop has no record against — one added by
  /// mistake, or sold before it was ever booked in. Anything with a service
  /// history or a booking is refused by the server, which names what is
  /// blocking it; that message is worth showing verbatim, because the answer is
  /// "ask the workshop" rather than "try again".
  Future<void> deleteVehicle(String id) =>
      _api.delete<dynamic>('/customer/vehicles/$id');

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
