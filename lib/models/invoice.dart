/// A bill, as the customer app lists it — `GET /api/customer/invoices`.
class Invoice {
  const Invoice({
    required this.id,
    required this.jobCardId,
    required this.vehiclePlate,
    required this.issuedAt,
    required this.subtotal,
    required this.taxRate,
    required this.tax,
    required this.total,
    required this.paid,
    required this.due,
    required this.status,
    required this.method,
  });

  final String id;
  final String jobCardId;
  final String vehiclePlate;
  final DateTime issuedAt;

  final double subtotal;

  /// Fractional VAT rate — 0.13 for 13%.
  final double taxRate;

  final double tax;
  final double total;
  final double paid;

  /// Outstanding balance. Computed server-side so every client agrees.
  final double due;

  /// Paid, Partial or Unpaid.
  final String status;

  /// How the most recent payment arrived; null until something is paid.
  final String? method;

  bool get isPaid => due <= 0;

  /// Only an unsettled bill is worth offering a Pay button for.
  bool get isPayable => due > 0;

  factory Invoice.fromJson(Map<String, dynamic> json) => Invoice(
    id: json['id'] as String,
    jobCardId: json['jobCardId'] as String? ?? '',
    vehiclePlate: json['vehiclePlate'] as String? ?? '',
    issuedAt: DateTime.parse(json['issuedAt'] as String),
    subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0,
    taxRate: (json['taxRate'] as num?)?.toDouble() ?? 0,
    tax: (json['tax'] as num?)?.toDouble() ?? 0,
    total: (json['total'] as num?)?.toDouble() ?? 0,
    paid: (json['paid'] as num?)?.toDouble() ?? 0,
    due: (json['due'] as num?)?.toDouble() ?? 0,
    status: json['status'] as String? ?? 'Unpaid',
    method: json['method'] as String?,
  );
}

/// Where to send the customer to pay — `POST /api/payments/start`.
class PaymentStart {
  const PaymentStart({
    required this.reference,
    required this.provider,
    required this.amount,
    required this.url,
  });

  /// Our own id for this attempt. Quote it when checking what happened.
  final String reference;

  final String provider;
  final double amount;

  /// Always openable as a plain link.
  ///
  /// eSewa actually needs an HTML form POST, which an app cannot do by opening
  /// a URL — so for eSewa the server hands back a page of its own that carries
  /// the signed fields and submits itself. The app never has to know which.
  final String url;

  factory PaymentStart.fromJson(Map<String, dynamic> json) => PaymentStart(
    reference: json['reference'] as String,
    provider: json['provider'] as String? ?? '',
    amount: (json['amount'] as num?)?.toDouble() ?? 0,
    url: json['url'] as String? ?? '',
  );
}

/// The workshop itself — `GET /api/workshop`.
class Workshop {
  const Workshop({
    required this.name,
    required this.legalName,
    required this.address,
    required this.phone,
    required this.email,
    required this.taxNumber,
    required this.latitude,
    required this.longitude,
    required this.openingHours,
    required this.onlineProviders,
  });

  final String name;
  final String legalName;
  final String address;
  final String phone;
  final String email;
  final String taxNumber;

  /// Map pin, or null until the workshop sets one.
  final double? latitude;
  final double? longitude;

  final String openingHours;

  /// Wallets with working credentials on the server right now. The app draws a
  /// button per entry, so a shop with no Khalti key never shows a Khalti button.
  final List<String> onlineProviders;

  bool get hasLocation => latitude != null && longitude != null;

  factory Workshop.fromJson(Map<String, dynamic> json) => Workshop(
    name: json['name'] as String? ?? '',
    legalName: json['legalName'] as String? ?? '',
    address: json['address'] as String? ?? '',
    phone: json['phone'] as String? ?? '',
    email: json['email'] as String? ?? '',
    taxNumber: json['taxNumber'] as String? ?? '',
    latitude: (json['latitude'] as num?)?.toDouble(),
    longitude: (json['longitude'] as num?)?.toDouble(),
    openingHours: json['openingHours'] as String? ?? '',
    onlineProviders: ((json['onlineProviders'] as List?) ?? const [])
        .map((e) => e as String)
        .toList(),
  );
}
