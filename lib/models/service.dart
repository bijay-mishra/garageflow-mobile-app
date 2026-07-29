/// How the price list is grouped. Mirrors `Vocabulary.ServiceCategories`.
const serviceCategories = <String>[
  'Washing',
  'Detailing',
  'Maintenance',
  'Repair',
  'Inspection',
  'Convenience',
  'Other',
];

/// An item on the workshop's price list — `GET /api/services`.
///
/// A wash, a polish, an AC regas. Picking one adds a priced line to a job card;
/// the price is copied at that moment, so a service that goes up next month
/// does not rewrite what a customer was already quoted.
class WorkshopService {
  const WorkshopService({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.price,
    required this.durationMinutes,
    required this.isActive,
    required this.isBookable,
    required this.appliesTo,
  });

  final String id;
  final String name;
  final String description;

  /// One of [serviceCategories].
  final String category;

  final double price;

  /// Rough bay time. 0 means the workshop does not quote one.
  final int durationMinutes;

  final bool isActive;

  /// False for extras the workshop adds itself. The customer app never receives
  /// these — the server filters them out — but the mechanic app does, because a
  /// courtesy wash is exactly the sort of thing a mechanic adds.
  final bool isBookable;

  /// Vehicle types this is offered for. Empty means every vehicle.
  final List<String> appliesTo;

  /// True when this is offered for [vehicleType]. An unrestricted service
  /// matches everything.
  bool suits(String? vehicleType) =>
      appliesTo.isEmpty || vehicleType == null || appliesTo.contains(vehicleType);

  /// "45 min", "1 hr 15 min", or empty when the shop does not quote a time.
  String get durationLabel {
    if (durationMinutes <= 0) return '';
    if (durationMinutes < 60) return '$durationMinutes min';

    final hours = durationMinutes ~/ 60;
    final rest = durationMinutes % 60;

    return rest == 0 ? '$hours hr' : '$hours hr $rest min';
  }

  factory WorkshopService.fromJson(Map<String, dynamic> json) => WorkshopService(
    id: json['id'] as String,
    name: json['name'] as String? ?? '',
    description: json['description'] as String? ?? '',
    category: json['category'] as String? ?? 'Other',
    price: (json['price'] as num?)?.toDouble() ?? 0,
    durationMinutes: json['durationMinutes'] as int? ?? 0,
    isActive: json['isActive'] as bool? ?? true,
    isBookable: json['isBookable'] as bool? ?? true,
    appliesTo: ((json['appliesTo'] as List?) ?? const [])
        .map((e) => e as String)
        .toList(),
  );
}

/// An extra attached to a booking, at the price the customer was shown.
class BookedService {
  const BookedService({
    required this.serviceId,
    required this.name,
    required this.category,
    required this.price,
  });

  final String serviceId;
  final String name;
  final String category;

  /// What it was quoted at when the booking was made — not today's price.
  final double price;

  factory BookedService.fromJson(Map<String, dynamic> json) => BookedService(
    serviceId: json['serviceId'] as String? ?? '',
    name: json['name'] as String? ?? '',
    category: json['category'] as String? ?? 'Other',
    price: (json['price'] as num?)?.toDouble() ?? 0,
  );
}
