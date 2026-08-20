import '../core/api_client.dart';
import '../core/api_exception.dart';
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
  ///
  /// A lost reply is not a failed write. This is the one call in the customer
  /// app that both creates something and cannot be safely repeated, and over a
  /// phone connection the request routinely arrives while the response does
  /// not — the row is committed and the app hears nothing. Reporting that as an
  /// error was wrong twice over: the customer was told their car had not been
  /// added while it sat on their account, and tapping Add again came back as
  /// "already registered at this garage. Ask the workshop", which is advice to
  /// go and solve a problem that does not exist.
  ///
  /// So a connection-class failure asks the server what it actually holds
  /// before deciding. Only a genuine miss is reported as one.
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
    try {
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
    } on ApiException catch (error) {
      // Anything the server answered — a duplicate plate, a rejected year — is
      // its verdict and stands. Only "no answer at all" is ambiguous.
      if (!error.isConnectionProblem) rethrow;

      final saved = await _vehicleByPlate(plate.trim());
      if (saved != null) return saved;

      rethrow;
    }
  }

  /// The customer's vehicle carrying [plate], or null if there is none.
  ///
  /// Used to settle an add whose reply was lost. A failure here is swallowed:
  /// the second call teaches nothing the first did not, and the original
  /// error is the one worth showing.
  Future<Vehicle?> _vehicleByPlate(String plate) async {
    try {
      final mine = await vehicles();

      for (final vehicle in mine) {
        if (vehicle.plate.toLowerCase() == plate.toLowerCase()) return vehicle;
      }
    } on ApiException {
      // Still offline, most likely. Fall through to the original failure.
    }

    return null;
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
    bool isUrgent = false,
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
        // A flag, never an amount. The fee is the server's to decide; sending
        // a number would be the app naming its own price.
        'isUrgent': isUrgent,
        'serviceIds': serviceIds,
      },
    );

    return Booking.fromJson(data);
  }

  /// What the priority option costs here, or that it is not on offer.
  ///
  /// A failure is not thrown on: the booking screen has to draw either way, and
  /// a customer who cannot reach this endpoint should still be able to describe
  /// a fault. They lose the option, not the screen.
  Future<BookingOptions> bookingOptions() async {
    try {
      final data = await _api.get<Map<String, dynamic>>('/bookings/options');
      return BookingOptions.fromJson(data);
    } on ApiException {
      return BookingOptions.unavailable;
    }
  }

  Future<Booking> cancelBooking(String id) async {
    final data = await _api.put<Map<String, dynamic>>('/bookings/$id/cancel');
    return Booking.fromJson(data);
  }
}
