/// Body classes, mirroring `Vocabulary.VehicleTypes` on the server.
const vehicleTypes = <String>[
  'Bike',
  'Car',
  'Van',
  'Bus',
  'Truck',
  'Tractor',
];

/// Fuels, mirroring `Vocabulary.FuelTypes` on the server.
///
/// These are values, not labels. The API validates against these exact strings,
/// so a screen shows a translation of them and sends the entry from this list.
const fuelTypes = <String>[
  'Petrol',
  'Diesel',
  'Electric',
  'Hybrid',
  'CNG',
];

/// A vehicle on the customer's account.
class Vehicle {
  const Vehicle({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.make,
    required this.model,
    required this.year,
    required this.plate,
    required this.vin,
    required this.type,
    required this.fuel,
    required this.odometer,
    required this.color,
    required this.lastServiceDate,
  });

  final String id;
  final String customerId;
  final String customerName;
  final String make;
  final String model;
  final int year;
  final String plate;
  final String vin;

  /// One of [vehicleTypes].
  final String type;

  final String fuel;
  final int odometer;
  final String color;

  /// Completion date of the most recent finished job, or null if never
  /// serviced here.
  final DateTime? lastServiceDate;

  /// "Toyota Corolla 2019".
  String get label => '$make $model $year'.trim();

  factory Vehicle.fromJson(Map<String, dynamic> json) => Vehicle(
    id: json['id'] as String,
    customerId: json['customerId'] as String? ?? '',
    customerName: json['customerName'] as String? ?? '',
    make: json['make'] as String? ?? '',
    model: json['model'] as String? ?? '',
    year: json['year'] as int? ?? 0,
    plate: json['plate'] as String? ?? '',
    vin: json['vin'] as String? ?? '',
    type: json['type'] as String? ?? 'Car',
    fuel: json['fuel'] as String? ?? '',
    odometer: json['odometer'] as int? ?? 0,
    color: json['color'] as String? ?? '',
    lastServiceDate: json['lastServiceDate'] == null
        ? null
        : DateTime.parse(json['lastServiceDate'] as String),
  );
}
