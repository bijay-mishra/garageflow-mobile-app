import 'photo.dart';

/// Statuses a job can hold, in workflow order. Mirrors `Vocabulary.JobStatuses`
/// on the server, which rejects anything else.
const jobStatuses = <String>[
  'Open',
  'In Progress',
  'Awaiting Parts',
  'Completed',
  'Delivered',
  'Cancelled',
];

/// What a mechanic may move a job to from the app.
///
/// "Delivered" is missing on purpose: handing the keys back is a front-desk
/// act, usually alongside taking payment, and it is not the mechanic's to
/// record.
const mechanicSelectableStatuses = <String>[
  'Open',
  'In Progress',
  'Awaiting Parts',
  'Completed',
];

/// One labour, parts or service line.
class JobLine {
  const JobLine({
    required this.description,
    required this.qty,
    required this.unitPrice,
    required this.kind,
    this.serviceId,
  });

  final String description;
  final double qty;
  final double unitPrice;

  /// `labour`, `part` or `service`.
  final String kind;

  /// Set when the line came off the workshop's price list. Used only to mark
  /// the row — the description and price on the line are what is charged.
  final String? serviceId;

  double get total => qty * unitPrice;
  bool get isLabour => kind == 'labour';

  /// A priced extra — a wash, a polish — rather than parts or hourly labour.
  bool get isService => kind == 'service';

  factory JobLine.fromJson(Map<String, dynamic> json) => JobLine(
    description: json['description'] as String? ?? '',
    qty: (json['qty'] as num?)?.toDouble() ?? 0,
    unitPrice: (json['unitPrice'] as num?)?.toDouble() ?? 0,
    kind: json['kind'] as String? ?? 'part',
    serviceId: json['serviceId'] as String?,
  );
}

/// A job as the mechanic app sees it — `GET /api/mechanic/jobs`.
///
/// Carries no money. A mechanic is told what to do, not what it bills for.
class MechanicJob {
  const MechanicJob({
    required this.id,
    required this.vehicleId,
    required this.vehiclePlate,
    required this.vehicleLabel,
    required this.vehicleType,
    required this.customerName,
    required this.customerPhone,
    required this.customerAddress,
    required this.customerLatitude,
    required this.customerLongitude,
    required this.complaint,
    required this.status,
    required this.priority,
    required this.odometer,
    required this.createdAt,
    required this.promisedAt,
    required this.completedAt,
    required this.isOverdue,
    required this.lines,
    required this.photoCount,
  });

  final String id;
  final String vehicleId;
  final String vehiclePlate;
  final String vehicleLabel;

  /// Body class — used to lead with the services that suit this vehicle.
  final String vehicleType;

  final String customerName;
  final String customerPhone;

  /// Written address — what you read out on the phone.
  final String customerAddress;

  /// The customer's map pin, or null if nobody set one. Present for pickup and
  /// drop: an address is what you post a bill to, a pin is where you drive.
  final double? customerLatitude;
  final double? customerLongitude;

  final String complaint;
  final String status;
  final String priority;
  final int odometer;
  final DateTime createdAt;
  final DateTime promisedAt;
  final DateTime? completedAt;

  /// Past its promised date with the work unfinished — computed server-side so
  /// the app and the dashboard cannot disagree about what is late.
  final bool isOverdue;

  final List<JobLine> lines;
  final int photoCount;

  bool get isFinished => status == 'Completed' || status == 'Delivered';
  bool get isUrgent => priority == 'Urgent' || priority == 'High';

  /// True when there is a pin worth putting on a map.
  bool get hasCustomerLocation =>
      customerLatitude != null && customerLongitude != null;

  factory MechanicJob.fromJson(Map<String, dynamic> json) => MechanicJob(
    id: json['id'] as String,
    vehicleId: json['vehicleId'] as String? ?? '',
    vehiclePlate: json['vehiclePlate'] as String? ?? '',
    vehicleLabel: json['vehicleLabel'] as String? ?? '',
    vehicleType: json['vehicleType'] as String? ?? 'Car',
    customerName: json['customerName'] as String? ?? '',
    customerPhone: json['customerPhone'] as String? ?? '',
    customerAddress: json['customerAddress'] as String? ?? '',
    customerLatitude: (json['customerLatitude'] as num?)?.toDouble(),
    customerLongitude: (json['customerLongitude'] as num?)?.toDouble(),
    complaint: json['complaint'] as String? ?? '',
    status: json['status'] as String? ?? 'Open',
    priority: json['priority'] as String? ?? 'Normal',
    odometer: json['odometer'] as int? ?? 0,
    createdAt: DateTime.parse(json['createdAt'] as String),
    promisedAt: DateTime.parse(json['promisedAt'] as String),
    completedAt: json['completedAt'] == null
        ? null
        : DateTime.parse(json['completedAt'] as String),
    isOverdue: json['isOverdue'] as bool? ?? false,
    lines: (json['lines'] as List? ?? [])
        .map((e) => JobLine.fromJson(e as Map<String, dynamic>))
        .toList(),
    photoCount: json['photoCount'] as int? ?? 0,
  );
}

/// The tiles above the mechanic's job list.
class MechanicSummary {
  const MechanicSummary({
    required this.assignedTotal,
    required this.inProgress,
    required this.awaitingParts,
    required this.completedToday,
    required this.overdue,
  });

  final int assignedTotal;
  final int inProgress;
  final int awaitingParts;
  final int completedToday;
  final int overdue;

  static const empty = MechanicSummary(
    assignedTotal: 0,
    inProgress: 0,
    awaitingParts: 0,
    completedToday: 0,
    overdue: 0,
  );

  factory MechanicSummary.fromJson(Map<String, dynamic> json) =>
      MechanicSummary(
        assignedTotal: json['assignedTotal'] as int? ?? 0,
        inProgress: json['inProgress'] as int? ?? 0,
        awaitingParts: json['awaitingParts'] as int? ?? 0,
        completedToday: json['completedToday'] as int? ?? 0,
        overdue: json['overdue'] as int? ?? 0,
      );
}

/// A job as the customer app sees it — `GET /api/customer/jobs`.
///
/// Carries the money and the photos, never the mechanic's name.
class CustomerJob {
  const CustomerJob({
    required this.id,
    required this.vehicleId,
    required this.vehiclePlate,
    required this.vehicleLabel,
    required this.complaint,
    required this.status,
    required this.createdAt,
    required this.promisedAt,
    required this.completedAt,
    required this.total,
    required this.lines,
    required this.photos,
    required this.progressPct,
  });

  final String id;
  final String vehicleId;
  final String vehiclePlate;
  final String vehicleLabel;
  final String complaint;
  final String status;
  final DateTime createdAt;
  final DateTime promisedAt;
  final DateTime? completedAt;
  final double total;
  final List<JobLine> lines;
  final List<JobPhoto> photos;

  /// 0–100, derived server-side from the status so every client draws the same
  /// bar.
  final int progressPct;

  bool get isFinished => status == 'Completed' || status == 'Delivered';

  factory CustomerJob.fromJson(Map<String, dynamic> json) => CustomerJob(
    id: json['id'] as String,
    vehicleId: json['vehicleId'] as String? ?? '',
    vehiclePlate: json['vehiclePlate'] as String? ?? '',
    vehicleLabel: json['vehicleLabel'] as String? ?? '',
    complaint: json['complaint'] as String? ?? '',
    status: json['status'] as String? ?? 'Open',
    createdAt: DateTime.parse(json['createdAt'] as String),
    promisedAt: DateTime.parse(json['promisedAt'] as String),
    completedAt: json['completedAt'] == null
        ? null
        : DateTime.parse(json['completedAt'] as String),
    total: (json['total'] as num?)?.toDouble() ?? 0,
    lines: (json['lines'] as List? ?? [])
        .map((e) => JobLine.fromJson(e as Map<String, dynamic>))
        .toList(),
    photos: (json['photos'] as List? ?? [])
        .map((e) => JobPhoto.fromJson(e as Map<String, dynamic>))
        .toList(),
    progressPct: json['progressPct'] as int? ?? 0,
  );
}
