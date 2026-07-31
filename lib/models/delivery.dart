/// Getting a finished vehicle back to its owner.
///
/// One record seen from three sides: the customer choosing how they want it
/// back, the driver taking it there, and the workshop watching both.
class Delivery {
  const Delivery({
    required this.id,
    required this.jobCardId,
    required this.customerId,
    required this.customerName,
    required this.customerPhone,
    required this.vehiclePlate,
    required this.vehicleLabel,
    required this.method,
    required this.status,
    required this.address,
    required this.fee,
    required this.driver,
    required this.createdAt,
    this.latitude,
    this.longitude,
    this.distanceKm,
    this.driverLatitude,
    this.driverLongitude,
    this.driverAt,
    this.chosenAt,
    this.startedAt,
    this.completedAt,
  });

  final String id;
  final String jobCardId;
  final String customerId;
  final String customerName;
  final String customerPhone;
  final String vehiclePlate;
  final String vehicleLabel;

  /// Pickup or HomeDelivery.
  final String method;

  /// AwaitingChoice, Scheduled, OutForDelivery, Delivered or Cancelled.
  final String status;

  final String address;
  final double? latitude;
  final double? longitude;
  final double? distanceKm;

  /// What was charged. Fixed when the customer chose, never recomputed.
  final num fee;

  final String driver;
  final double? driverLatitude;
  final double? driverLongitude;
  final DateTime? driverAt;

  final DateTime createdAt;
  final DateTime? chosenAt;
  final DateTime? startedAt;
  final DateTime? completedAt;

  bool get isHomeDelivery => method == 'HomeDelivery';
  bool get awaitingChoice => status == 'AwaitingChoice';
  bool get isScheduled => status == 'Scheduled';
  bool get isOnTheWay => status == 'OutForDelivery';
  bool get isDone => status == 'Delivered';

  /// True once a driver has reported a position we can put on a map.
  bool get hasDriverPin => driverLatitude != null && driverLongitude != null;

  bool get hasDestination => latitude != null && longitude != null;

  /// The sentence the customer reads at the top of the tracking screen.
  String get headline => switch (status) {
    'AwaitingChoice' => 'Ready — how would you like it back?',
    'Scheduled' when isHomeDelivery => 'Booked in for delivery',
    'Scheduled' => 'Ready to collect',
    'OutForDelivery' => 'On the way to you',
    'Delivered' when isHomeDelivery => 'Delivered',
    'Delivered' => 'Collected',
    'Cancelled' => 'Cancelled',
    _ => status,
  };

  /// The status a [StatusChip] should wear. Handover statuses are their own
  /// vocabulary, so they are mapped onto the job scale the app already colours
  /// rather than adding five more names to it.
  String get chipStatus => switch (status) {
    'AwaitingChoice' => 'Awaiting Parts',
    'Scheduled' => 'Open',
    'OutForDelivery' => 'In Progress',
    'Delivered' => 'Completed',
    'Cancelled' => 'Cancelled',
    _ => status,
  };

  factory Delivery.fromJson(Map<String, dynamic> json) => Delivery(
    id: json['id'] as String? ?? '',
    jobCardId: json['jobCardId'] as String? ?? '',
    customerId: json['customerId'] as String? ?? '',
    customerName: json['customerName'] as String? ?? '',
    customerPhone: json['customerPhone'] as String? ?? '',
    vehiclePlate: json['vehiclePlate'] as String? ?? '',
    vehicleLabel: (json['vehicleLabel'] as String? ?? '').trim(),
    method: json['method'] as String? ?? '',
    status: json['status'] as String? ?? '',
    address: json['address'] as String? ?? '',
    fee: (json['fee'] as num?) ?? 0,
    driver: json['driver'] as String? ?? '',
    latitude: (json['latitude'] as num?)?.toDouble(),
    longitude: (json['longitude'] as num?)?.toDouble(),
    distanceKm: (json['distanceKm'] as num?)?.toDouble(),
    driverLatitude: (json['driverLatitude'] as num?)?.toDouble(),
    driverLongitude: (json['driverLongitude'] as num?)?.toDouble(),
    driverAt: _date(json['driverAt']),
    createdAt: _date(json['createdAt']) ?? DateTime.now(),
    chosenAt: _date(json['chosenAt']),
    startedAt: _date(json['startedAt']),
    completedAt: _date(json['completedAt']),
  );

  static DateTime? _date(Object? value) =>
      value is String ? DateTime.tryParse(value)?.toLocal() : null;
}

/// What home delivery would cost, or why it is not on offer.
class DeliveryQuote {
  const DeliveryQuote({
    required this.available,
    required this.distanceKm,
    required this.fee,
    this.reason,
  });

  final bool available;
  final double distanceKm;
  final num fee;

  /// Set when [available] is false. Shown to the customer verbatim — the server
  /// knows whether the reason is distance, a missing pin or delivery being off.
  final String? reason;

  bool get isFree => available && fee == 0;

  factory DeliveryQuote.fromJson(Map<String, dynamic> json) => DeliveryQuote(
    available: json['available'] as bool? ?? false,
    distanceKm: (json['distanceKm'] as num?)?.toDouble() ?? 0,
    fee: (json['fee'] as num?) ?? 0,
    reason: json['reason'] as String?,
  );
}

/// One point on a driver's route.
class TrailPoint {
  const TrailPoint({
    required this.latitude,
    required this.longitude,
    required this.at,
  });

  final double latitude;
  final double longitude;
  final DateTime at;

  factory TrailPoint.fromJson(Map<String, dynamic> json) => TrailPoint(
    latitude: (json['latitude'] as num).toDouble(),
    longitude: (json['longitude'] as num).toDouble(),
    at: DateTime.parse(json['at'] as String).toLocal(),
  );
}

/// A live delivery with the route so far — what the tracking map draws.
class DeliveryTrack {
  const DeliveryTrack({
    required this.delivery,
    required this.trail,
    this.originLatitude,
    this.originLongitude,
    this.secondsSinceUpdate,
  });

  final Delivery delivery;
  final List<TrailPoint> trail;

  /// The workshop's pin — where the journey started.
  final double? originLatitude;
  final double? originLongitude;

  /// Seconds since the driver's phone last reported, or null before they set
  /// off. Shown as words rather than assumed to be zero: tracking only runs
  /// while the driver has the app open, so a position can be minutes old.
  final int? secondsSinceUpdate;

  bool get hasOrigin => originLatitude != null && originLongitude != null;

  /// True when the last position is recent enough to present as live. Thirty
  /// seconds is two missed pings at the app's ten-second interval.
  bool get isLive =>
      secondsSinceUpdate != null && secondsSinceUpdate! <= 30;

  /// How fresh the driver's position is, in words.
  String get freshness {
    final seconds = secondsSinceUpdate;

    if (seconds == null) return 'Not started yet';
    if (seconds <= 30) return 'Live now';
    if (seconds < 120) return 'Updated a minute ago';
    if (seconds < 3600) return 'Updated ${seconds ~/ 60} minutes ago';

    // Beyond an hour the driver's app has almost certainly been closed, and
    // saying "updated 4 hours ago" is the honest answer rather than a dot that
    // looks current.
    final hours = seconds ~/ 3600;
    return 'Updated $hours hour${hours == 1 ? '' : 's'} ago';
  }

  factory DeliveryTrack.fromJson(Map<String, dynamic> json) => DeliveryTrack(
    delivery: Delivery.fromJson(json['delivery'] as Map<String, dynamic>),
    trail: ((json['trail'] as List?) ?? const [])
        .map((e) => TrailPoint.fromJson(e as Map<String, dynamic>))
        .toList(),
    originLatitude: (json['originLatitude'] as num?)?.toDouble(),
    originLongitude: (json['originLongitude'] as num?)?.toDouble(),
    secondsSinceUpdate: (json['secondsSinceUpdate'] as num?)?.toInt(),
  );
}
