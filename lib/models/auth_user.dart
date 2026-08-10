/// The signed-in person, as `POST /api/auth/login` returns them.
class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    required this.workshop,
    required this.companyCode,
    this.phone,
    this.photoUrl,
    this.mechanicName,
    this.customerId,
  });

  final String id;
  final String email;
  final String name;

  /// Owner, Manager, Advisor, Mechanic or Customer.
  final String role;

  final String workshop;
  final String companyCode;
  final String? phone;

  /// Their profile photo, or null when they have not set one.
  ///
  /// Null is the normal case and there is no placeholder image: the app draws
  /// [initials] instead, which says who it is rather than showing a grey
  /// silhouette that says nothing.
  final String? photoUrl;

  bool get hasPhoto => photoUrl != null && photoUrl!.isNotEmpty;

  /// Set for a Mechanic — the name they are assigned under on job cards.
  final String? mechanicName;

  /// Set for a Customer — the customer record this login speaks for.
  final String? customerId;

  bool get isMechanic => role == 'Mechanic';
  bool get isCustomer => role == 'Customer';

  /// Staff belong on the web dashboard. The app refuses their sign-in rather
  /// than dropping them into a shell with nothing in it.
  bool get isStaff => !isMechanic && !isCustomer;

  /// First name, for greetings — "Welcome back, Suresh".
  String get firstName => name.split(' ').first;

  /// Two letters for the avatar. Falls back to the email when the name is
  /// blank, so the circle is never empty.
  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);

    if (parts.isEmpty) {
      return email.isEmpty ? '?' : email.substring(0, 1).toUpperCase();
    }
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }

    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
    id: json['id'] as String? ?? '',
    email: json['email'] as String? ?? '',
    name: json['name'] as String? ?? '',
    role: json['role'] as String? ?? '',
    workshop: json['workshop'] as String? ?? '',
    companyCode: json['companyCode'] as String? ?? '',
    phone: json['phone'] as String?,
    photoUrl: json['photoUrl'] as String?,
    mechanicName: json['mechanicName'] as String?,
    customerId: json['customerId'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'name': name,
    'role': role,
    'workshop': workshop,
    'companyCode': companyCode,
    'phone': phone,
    'photoUrl': photoUrl,
    'mechanicName': mechanicName,
    'customerId': customerId,
  };
}

/// A successful sign-in or refresh: the token pair plus who it belongs to.
class AuthResult {
  const AuthResult({
    required this.accessToken,
    required this.refreshToken,
    required this.user,
    this.deletionCancelled = false,
  });

  final String accessToken;
  final String refreshToken;
  final AuthUser user;

  /// True when this sign-in called off a deletion the account had asked for.
  ///
  /// Signing in is the only thing that cancels one, which means it happens
  /// without anybody pressing a button that says so. The app tells them rather
  /// than letting an account quietly stop being deleted.
  final bool deletionCancelled;

  factory AuthResult.fromJson(Map<String, dynamic> json) => AuthResult(
    accessToken: json['accessToken'] as String,
    refreshToken: json['refreshToken'] as String,
    user: AuthUser.fromJson(json['user'] as Map<String, dynamic>),
    deletionCancelled: json['deletionCancelled'] as bool? ?? false,
  );
}
