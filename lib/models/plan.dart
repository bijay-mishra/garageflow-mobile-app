import '../core/i18n.dart';

/// One GarageFlow subscription tier — `GET /api/plans`.
///
/// The server sends facts and the app supplies words. Price and availability
/// change and have to come down the wire; the name and the list of what a tier
/// includes are translated copy, so they live in the app's own tables keyed by
/// [code] and can be read in Nepali.
///
/// A code the app has no wording for still renders: it falls back to the
/// server's [name] with no feature list, which is a plain card rather than a
/// blank one or a crash.
class Plan {
  const Plan({
    required this.code,
    required this.name,
    required this.price,
    required this.periodMonths,
    required this.isPopular,
    required this.available,
  });

  /// `free`, `plus`, `pro`.
  final String code;

  /// The server's own name, used only when the app has no translation.
  final String name;

  /// Rupees per [periodMonths]. Zero on the free tier.
  final double price;

  final int periodMonths;
  final bool isPopular;

  /// False while there is no way to actually pay for this tier. The card is
  /// still shown; the button says so.
  final bool available;

  bool get isFree => price <= 0;

  /// `monthly`, `quarterly`, `yearly`, or `months` for anything else.
  ///
  /// Derived from [periodMonths] rather than sent as its own field, so the
  /// number and the word it is described by cannot disagree.
  String get period => switch (periodMonths) {
    1 => 'monthly',
    3 => 'quarterly',
    12 => 'yearly',
    _ => 'months',
  };

  /// What one month works out at. The comparison people actually make between
  /// a quarterly and a yearly plan, and the one nobody does in their head.
  double get perMonth => periodMonths <= 1 ? price : price / periodMonths;

  /// The tier's name in the reader's language, or the server's if unknown.
  String label(AppText t) => _or(t, 'name', name);

  /// One line under the name.
  String tagline(AppText t) => _or(t, 'tagline', '');

  /// What the tier includes.
  ///
  /// Held as one `|`-separated string rather than as numbered keys, because a
  /// numbered scheme means guessing how many exist — and a guess that is one
  /// too high renders the literal key `plan.plus.f5` on a sales screen.
  List<String> features(AppText t) {
    final raw = _or(t, 'features', '');

    return raw.isEmpty
        ? const []
        : raw
              .split('|')
              .map((f) => f.trim())
              .where((f) => f.isNotEmpty)
              .toList();
  }

  /// Looks up `plan.<code>.<part>`, falling back to [fallback] when the key is
  /// missing — which [AppText] signals by handing the key straight back.
  String _or(AppText t, String part, String fallback) {
    final key = 'plan.$code.$part';
    final value = t(key);

    return value == key ? fallback : value;
  }

  factory Plan.fromJson(Map<String, dynamic> json) => Plan(
    code: (json['code'] as String? ?? '').toLowerCase(),
    name: json['name'] as String? ?? '',
    price: (json['price'] as num?)?.toDouble() ?? 0,
    periodMonths: (json['periodMonths'] as num?)?.toInt() ?? 1,
    isPopular: json['isPopular'] as bool? ?? false,
    available: json['available'] as bool? ?? false,
  );
}

/// Where this account stands with GarageFlow — `GET /api/plans/me`.
///
/// One object rather than a nullable subscription: the screen has to draw
/// something either way, and "on the free plan" is a real answer rather than an
/// absence.
class MyPlan {
  const MyPlan({
    required this.code,
    required this.isActive,
    required this.expiresOn,
    required this.daysLeft,
    required this.providers,
  });

  /// The tier in force, or `free`.
  final String code;

  final bool isActive;

  /// When cover ends. Null on the free tier.
  final DateTime? expiresOn;

  /// Days remaining, never negative. Null when nothing is running.
  final int? daysLeft;

  /// Wallets the server can take money through right now. Empty means no
  /// online payment is configured, and the app must not draw a button.
  final List<String> providers;

  /// Close enough to expiry to be worth saying so.
  bool get isEndingSoon => isActive && (daysLeft ?? 99) <= 7;

  bool get canPay => providers.isNotEmpty;

  static const none = MyPlan(
    code: 'free',
    isActive: false,
    expiresOn: null,
    daysLeft: null,
    providers: [],
  );

  factory MyPlan.fromJson(Map<String, dynamic> json) => MyPlan(
    code: (json['code'] as String? ?? 'free').toLowerCase(),
    isActive: json['isActive'] as bool? ?? false,
    expiresOn: json['expiresOn'] == null
        ? null
        : DateTime.parse(json['expiresOn'] as String),
    daysLeft: (json['daysLeft'] as num?)?.toInt(),
    providers: ((json['providers'] as List?) ?? const [])
        .map((e) => e as String)
        .toList(),
  );
}

/// Where to send the customer to pay for a plan — `POST /api/plans/subscribe`.
class PlanCheckout {
  const PlanCheckout({
    required this.reference,
    required this.provider,
    required this.amount,
    required this.url,
  });

  /// Our own id for the attempt. Quoted back when asking what happened.
  final String reference;

  final String provider;
  final double amount;

  /// Always openable as a plain link — for eSewa the server hands back a page
  /// of its own that carries the signed fields and submits itself, because an
  /// app cannot do a form POST by opening a URL.
  final String url;

  factory PlanCheckout.fromJson(Map<String, dynamic> json) => PlanCheckout(
    reference: json['reference'] as String,
    provider: json['provider'] as String? ?? '',
    amount: (json['amount'] as num?)?.toDouble() ?? 0,
    url: json['url'] as String? ?? '',
  );
}
