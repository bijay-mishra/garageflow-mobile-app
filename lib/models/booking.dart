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
    this.isUrgent = false,
    this.urgentFee = 0,
    this.queuePosition,
    this.queueTotal = 0,
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

  /// Paid the priority fee to skip the queue.
  final bool isUrgent;

  /// What skipping the queue cost. Zero on an ordinary booking.
  ///
  /// Added to the bill when the workshop opens the job card, not taken up
  /// front — so a workshop that cannot fit you in has taken no money to
  /// give back.
  final double urgentFee;

  /// Place in the workshop's queue, counting from 1.
  ///
  /// Null once the booking is no longer waiting. Worked out by the server
  /// across every booking in the queue, so it moves when other people's
  /// bookings are dealt with rather than being a number frozen at booking
  /// time.
  final int? queuePosition;

  /// How many bookings are in that queue altogether.
  final int queueTotal;

  /// Still in the line, so the position means something.
  bool get isQueued => queuePosition != null;

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
    isUrgent: json['isUrgent'] as bool? ?? false,
    urgentFee: (json['urgentFee'] as num?)?.toDouble() ?? 0,
    queuePosition: (json['queuePosition'] as num?)?.toInt(),
    queueTotal: (json['queueTotal'] as num?)?.toInt() ?? 0,
  );
}

/// What the priority option costs, as the server reports it.
///
/// Fetched rather than built into the app: a price baked into an APK is wrong
/// for everybody who has not updated it. [urgentAvailable] is the same decision
/// the server makes when a booking arrives, so an app offering the option and a
/// server ignoring it cannot disagree.
class BookingOptions {
  const BookingOptions({this.urgentFee = 0, this.urgentAvailable = false});

  final double urgentFee;
  final bool urgentAvailable;

  /// What is assumed when the request fails. Not offering the option costs a
  /// customer a choice; offering one at a price we could not read would put a
  /// number on screen that nobody is held to.
  static const unavailable = BookingOptions();

  factory BookingOptions.fromJson(Map<String, dynamic> json) => BookingOptions(
    urgentFee: (json['urgentFee'] as num?)?.toDouble() ?? 0,
    urgentAvailable: json['urgentAvailable'] as bool? ?? false,
  );
}
