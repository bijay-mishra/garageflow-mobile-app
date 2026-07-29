import 'service.dart';

/// Where a booking sits. Mirrors `Vocabulary.BookingStatuses`.
const bookingStatuses = <String>[
  'Requested',
  'Confirmed',
  'Rejected',
  'Converted',
  'Cancelled',
];

/// A service request raised from the customer app.
class Booking {
  const Booking({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.vehicleId,
    required this.vehiclePlate,
    required this.vehicleLabel,
    required this.complaint,
    required this.preferredDate,
    required this.preferredTime,
    required this.status,
    required this.staffNote,
    required this.jobCardId,
    required this.createdAt,
    required this.respondedAt,
    this.services = const [],
    this.estimatedTotal = 0,
  });

  final String id;
  final String customerId;
  final String customerName;
  final String vehicleId;
  final String vehiclePlate;
  final String vehicleLabel;
  final String complaint;
  final DateTime preferredDate;
  final String preferredTime;

  /// One of [bookingStatuses].
  final String status;

  /// The workshop's reply — the reason, when they declined.
  final String? staffNote;

  /// Set once the workshop turned this into real work.
  final String? jobCardId;

  final DateTime createdAt;
  final DateTime? respondedAt;

  /// Extras asked for on top of the complaint — a wash, a polish, a pickup.
  final List<BookedService> services;

  /// Sum of the quoted extras. The complaint itself is deliberately unpriced:
  /// nobody can quote a knocking noise before they have looked at it.
  final double estimatedTotal;

  /// Still awaiting an answer or waiting to happen — the customer can cancel.
  bool get isOpen => status == 'Requested' || status == 'Confirmed';

  bool get isConverted => status == 'Converted';

  /// What the customer should be told this booking means right now.
  String get explanation => switch (status) {
    'Requested' => 'Waiting for the workshop to confirm.',
    'Confirmed' => 'Confirmed — bring your vehicle in on the day.',
    'Rejected' => staffNote?.isNotEmpty == true
        ? staffNote!
        : 'The workshop could not take this booking.',
    'Converted' => 'A job card is open for this booking.',
    'Cancelled' => 'This booking was cancelled.',
    _ => '',
  };

  factory Booking.fromJson(Map<String, dynamic> json) => Booking(
    id: json['id'] as String,
    customerId: json['customerId'] as String? ?? '',
    customerName: json['customerName'] as String? ?? '',
    vehicleId: json['vehicleId'] as String? ?? '',
    vehiclePlate: json['vehiclePlate'] as String? ?? '',
    vehicleLabel: json['vehicleLabel'] as String? ?? '',
    complaint: json['complaint'] as String? ?? '',
    preferredDate: DateTime.parse(json['preferredDate'] as String),
    preferredTime: json['preferredTime'] as String? ?? '',
    status: json['status'] as String? ?? 'Requested',
    staffNote: json['staffNote'] as String?,
    jobCardId: json['jobCardId'] as String?,
    createdAt: DateTime.parse(json['createdAt'] as String),
    respondedAt: json['respondedAt'] == null
        ? null
        : DateTime.parse(json['respondedAt'] as String),
    services: ((json['services'] as List?) ?? const [])
        .map((e) => BookedService.fromJson(e as Map<String, dynamic>))
        .toList(),
    estimatedTotal: (json['estimatedTotal'] as num?)?.toDouble() ?? 0,
  );
}
