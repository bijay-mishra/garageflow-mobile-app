/// A bill, as the customer app lists it — `GET /api/customer/invoices`.
class Invoice {
  const Invoice({
    required this.id,
    required this.jobCardId,
    required this.customerName,
    required this.vehiclePlate,
    required this.issuedAt,
    required this.subtotal,
    required this.discount,
    required this.discountNote,
    required this.pointsRedeemed,
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
  final String customerName;
  final String vehiclePlate;
  final DateTime issuedAt;

  final double subtotal;

  /// Money off before tax — a loyalty reward, an offer, or points. Zero on a
  /// bill that had none, which is most of them.
  final double discount;

  /// Why there was a discount, in the workshop's own words. Empty when there
  /// was none.
  final String discountNote;

  /// Points spent on this bill.
  final int pointsRedeemed;

  /// Fractional VAT rate — 0.13 for 13%.
  final double taxRate;

  /// VAT, charged on the subtotal *after* the discount.
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

  /// True when something came off before tax, so the bill draws the row.
  bool get hasDiscount => discount > 0;

  factory Invoice.fromJson(Map<String, dynamic> json) => Invoice(
    id: json['id'] as String,
    jobCardId: json['jobCardId'] as String? ?? '',
    customerName: json['customerName'] as String? ?? '',
    vehiclePlate: json['vehiclePlate'] as String? ?? '',
    issuedAt: DateTime.parse(json['issuedAt'] as String),
    subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0,
    discount: (json['discount'] as num?)?.toDouble() ?? 0,
    discountNote: json['discountNote'] as String? ?? '',
    pointsRedeemed: (json['pointsRedeemed'] as num?)?.toInt() ?? 0,
    taxRate: (json['taxRate'] as num?)?.toDouble() ?? 0,
    tax: (json['tax'] as num?)?.toDouble() ?? 0,
    total: (json['total'] as num?)?.toDouble() ?? 0,
    paid: (json['paid'] as num?)?.toDouble() ?? 0,
    due: (json['due'] as num?)?.toDouble() ?? 0,
    status: json['status'] as String? ?? 'Unpaid',
    method: json['method'] as String?,
  );
}

/// A whole bill, itemised — `GET /api/customer/invoices/{id}`.
///
/// The same document the workshop prints at the counter. It is assembled server
/// side from the invoice's own snapshot rather than recomputed from the job, so
/// a bill saved today and reopened next year still reads the same.
class BillDocument {
  const BillDocument({
    required this.invoice,
    required this.payments,
    required this.lines,
    required this.customerAddress,
    required this.customerPhone,
    required this.customerEmail,
    required this.vehicleLabel,
    required this.odometer,
    required this.complaint,
    required this.mechanic,
    required this.completedAt,
    required this.hasJobCard,
  });

  final Invoice invoice;

  /// Settled payments only, oldest first. A pending attempt is not a receipt.
  final List<BillPayment> payments;

  /// The itemised work. Empty when the job card behind the bill has since been
  /// deleted — see [hasJobCard], which is why rather than a silent blank.
  final List<BillLine> lines;

  final String customerAddress;
  final String customerPhone;
  final String customerEmail;

  /// "Toyota Corolla 2019", or empty if the vehicle has since gone.
  final String vehicleLabel;
  final int odometer;

  final String complaint;
  final String mechanic;
  final DateTime? completedAt;

  final bool hasJobCard;

  /// What the lines add up to before any discount or tax.
  double get linesTotal =>
      lines.fold(0.0, (sum, line) => sum + line.amount);

  factory BillDocument.fromJson(Map<String, dynamic> json) => BillDocument(
    invoice: Invoice.fromJson(json['invoice'] as Map<String, dynamic>),
    payments: ((json['payments'] as List?) ?? const [])
        .map((e) => BillPayment.fromJson(e as Map<String, dynamic>))
        .toList(),
    lines: ((json['lines'] as List?) ?? const [])
        .map((e) => BillLine.fromJson(e as Map<String, dynamic>))
        .toList(),
    customerAddress: json['customerAddress'] as String? ?? '',
    customerPhone: json['customerPhone'] as String? ?? '',
    customerEmail: json['customerEmail'] as String? ?? '',
    vehicleLabel: json['vehicleLabel'] as String? ?? '',
    odometer: (json['odometer'] as num?)?.toInt() ?? 0,
    complaint: json['complaint'] as String? ?? '',
    mechanic: json['mechanic'] as String? ?? '',
    completedAt: json['completedAt'] == null
        ? null
        : DateTime.parse(json['completedAt'] as String),
    hasJobCard: json['hasJobCard'] as bool? ?? false,
  );
}

/// One line of work on the bill.
class BillLine {
  const BillLine({
    required this.description,
    required this.qty,
    required this.unitPrice,
    required this.kind,
  });

  final String description;

  /// Hours for labour, units for parts and services.
  final double qty;
  final double unitPrice;

  /// `labour`, `part` or `service`.
  final String kind;

  double get amount => qty * unitPrice;

  factory BillLine.fromJson(Map<String, dynamic> json) => BillLine(
    description: json['description'] as String? ?? '',
    qty: (json['qty'] as num?)?.toDouble() ?? 0,
    unitPrice: (json['unitPrice'] as num?)?.toDouble() ?? 0,
    kind: json['kind'] as String? ?? 'service',
  );
}

/// One receipt against the bill.
class BillPayment {
  const BillPayment({
    required this.amount,
    required this.method,
    required this.reference,
    required this.at,
  });

  final double amount;

  /// Cash, Card, eSewa, Khalti or Bank Transfer.
  final String method;

  /// The gateway's transaction id, or the slip number staff typed in. Null for
  /// cash over the counter.
  final String? reference;

  final DateTime at;

  factory BillPayment.fromJson(Map<String, dynamic> json) => BillPayment(
    amount: (json['amount'] as num?)?.toDouble() ?? 0,
    method: json['method'] as String? ?? '',
    // The gateway's own id is the one worth printing; ours is an internal
    // reference the customer cannot do anything with.
    reference: json['providerRef'] as String? ?? json['reference'] as String?,
    at: DateTime.parse(json['at'] as String),
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
    required this.logoUrl,
    required this.latitude,
    required this.longitude,
    required this.openingHours,
    required this.onlineProviders,
    required this.bankName,
    required this.bankAccountName,
    required this.bankAccountNumber,
    required this.bankBranch,
    required this.canBankTransfer,
  });

  final String name;
  final String legalName;
  final String address;
  final String phone;
  final String email;
  final String taxNumber;

  /// The workshop's logo, or null until it uploads one. Absolute, because the
  /// phone has no idea what host the API is on.
  final String? logoUrl;

  /// Map pin, or null until the workshop sets one.
  final double? latitude;
  final double? longitude;

  final String openingHours;

  /// Wallets with working credentials on the server right now. The app draws a
  /// button per entry, so a shop with no Khalti key never shows a Khalti button.
  final List<String> onlineProviders;

  // ── Bank transfer ──────────────────────────────────────────────────────
  // Not a gateway. The app shows these, the customer moves the money in
  // their own banking app, and a staff member confirms it against the
  // statement — which is why the bill stays unpaid until they do.

  final String bankName;
  final String bankAccountName;
  final String bankAccountNumber;
  final String bankBranch;

  /// False when the workshop has not filled in an account, in which case
  /// the option is hidden rather than shown with an empty number.
  final bool canBankTransfer;

  bool get hasLocation => latitude != null && longitude != null;

  factory Workshop.fromJson(Map<String, dynamic> json) => Workshop(
    name: json['name'] as String? ?? '',
    legalName: json['legalName'] as String? ?? '',
    address: json['address'] as String? ?? '',
    phone: json['phone'] as String? ?? '',
    email: json['email'] as String? ?? '',
    taxNumber: json['taxNumber'] as String? ?? '',
    logoUrl: json['logoUrl'] as String?,
    latitude: (json['latitude'] as num?)?.toDouble(),
    longitude: (json['longitude'] as num?)?.toDouble(),
    openingHours: json['openingHours'] as String? ?? '',
    onlineProviders: ((json['onlineProviders'] as List?) ?? const [])
        .map((e) => e as String)
        .toList(),
    bankName: json['bankName'] as String? ?? '',
    bankAccountName: json['bankAccountName'] as String? ?? '',
    bankAccountNumber: json['bankAccountNumber'] as String? ?? '',
    bankBranch: json['bankBranch'] as String? ?? '',
    canBankTransfer: json['canBankTransfer'] as bool? ?? false,
  );
}
