/// A garage as the directory lists it.
///
/// The consumer-facing shape: what a person choosing a workshop wants to know,
/// not what the workshop's own dashboard shows about itself.
class WorkshopCard {
  const WorkshopCard({
    required this.companyCode,
    required this.name,
    required this.address,
    required this.phone,
    required this.about,
    required this.openingHours,
    required this.serviceCount,
    required this.isJoined,
    required this.isPrimary,
    this.latitude,
    this.longitude,
    this.distanceKm,
  });

  final String companyCode;
  final String name;
  final String address;
  final String phone;
  final String about;
  final String openingHours;

  /// How many services it publishes — a rough sign of life.
  final int serviceCount;

  /// True when this customer has already joined it.
  final bool isJoined;

  /// True when this is the garage the app currently opens on.
  final bool isPrimary;

  final double? latitude;
  final double? longitude;

  /// Straight-line km from the phone, when it shared its position.
  final double? distanceKm;

  bool get hasLocation => latitude != null && longitude != null;

  /// "3.9 km away", or nothing when the phone's position is unknown. Written
  /// as a phrase rather than a bare number so it cannot be mistaken for a
  /// price or a rating.
  String? get distanceLabel =>
      distanceKm == null ? null : '${distanceKm!.toStringAsFixed(1)} km away';

  /// First letter, for the tile that stands in for a logo. A garage has not
  /// uploaded one, and inventing a picture for a real business would be worse
  /// than an initial.
  String get initial =>
      name.trim().isEmpty ? '?' : name.trim().substring(0, 1).toUpperCase();

  factory WorkshopCard.fromJson(Map<String, dynamic> json) => WorkshopCard(
    companyCode: json['companyCode'] as String? ?? '',
    name: json['name'] as String? ?? '',
    address: json['address'] as String? ?? '',
    phone: json['phone'] as String? ?? '',
    about: json['about'] as String? ?? '',
    openingHours: json['openingHours'] as String? ?? '',
    serviceCount: (json['serviceCount'] as num?)?.toInt() ?? 0,
    isJoined: json['isJoined'] as bool? ?? false,
    isPrimary: json['isPrimary'] as bool? ?? false,
    latitude: (json['latitude'] as num?)?.toDouble(),
    longitude: (json['longitude'] as num?)?.toDouble(),
    distanceKm: (json['distanceKm'] as num?)?.toDouble(),
  );
}
