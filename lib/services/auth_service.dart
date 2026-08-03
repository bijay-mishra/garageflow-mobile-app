import '../core/api_client.dart';
import '../models/auth_user.dart';

/// Sign-in, sign-out and "who am I".
class AuthService {
  AuthService(this._api);

  final ApiClient _api;

  /// Signs in. `noAuth` matters: a 401 here means bad credentials, and the
  /// client must show the server's message rather than trying to refresh a
  /// session that was never established.
  Future<AuthResult> login({
    required String companyCode,
    required String email,
    required String password,
  }) async {
    final data = await _api.post<Map<String, dynamic>>(
      '/auth/login',
      body: {
        'companyCode': companyCode.trim(),
        'email': email.trim(),
        'password': password,
      },
      noAuth: true,
    );

    return AuthResult.fromJson(data);
  }

  Future<AuthUser> me() async {
    final data = await _api.get<Map<String, dynamic>>('/auth/me');
    return AuthUser.fromJson(data);
  }

  /// Revokes the refresh token server-side. Failure is deliberately swallowed
  /// by the caller: the local session is cleared either way, and a user who
  /// taps sign-out on a dead connection must still end up signed out.
  Future<void> logout(String refreshToken) =>
      _api.post<dynamic>('/auth/logout', body: {'refreshToken': refreshToken});

  /// Updates name, email and phone. Returns the account as it now stands.
  Future<AuthUser> updateProfile({
    required String name,
    required String email,
    String? phone,
  }) async {
    final data = await _api.put<Map<String, dynamic>>(
      '/auth/profile',
      body: {'name': name.trim(), 'email': email.trim(), 'phone': phone?.trim()},
    );

    return AuthUser.fromJson(data);
  }

  /// Changes the password.
  ///
  /// The server revokes every refresh token, so this always ends the session —
  /// on this phone too. The caller signs the user out rather than pretending
  /// they are still signed in with a token that will fail on next refresh.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) => _api.put<dynamic>(
    '/auth/change-password',
    body: {'currentPassword': currentPassword, 'newPassword': newPassword},
  );

  /// Uploads a profile photo.
  Future<AuthUser> uploadPhoto(String filePath) async {
    final data = await _api.upload<Map<String, dynamic>>(
      '/auth/photo',
      filePath: filePath,
      fieldName: 'file',
    );

    return AuthUser.fromJson(data);
  }

  Future<AuthUser> removePhoto() async {
    final data = await _api.delete<Map<String, dynamic>>('/auth/photo');
    return AuthUser.fromJson(data);
  }

  // ── Forgotten password ─────────────────────────────────────────────────────
  // Three steps: ask for a code, check it, choose a new password.
  //
  // A code and not a link. The server used to email a reset link, which opens a
  // browser rather than this app — following it back into Flutter needs Android
  // App Links and a verified assetlinks.json on a public HTTPS domain, which
  // does not exist yet. So the phone could ask for a reset and then do nothing
  // with the mail that arrived. Six digits need no such plumbing.

  /// Asks for a six-digit code by email.
  ///
  /// Succeeds whether or not the account exists — the server refuses to say, so
  /// that this cannot be used to discover which addresses have accounts. There
  /// is nothing to branch on and the screen moves on either way.
  Future<PasswordResetTarget> forgotPassword({
    required String companyCode,
    required String email,
  }) async {
    final data = await _api.post<Map<String, dynamic>>(
      '/auth/forgot-password',
      body: {'companyCode': companyCode.trim(), 'email': email.trim()},
      noAuth: true,
    );

    return PasswordResetTarget.fromJson(data);
  }

  /// Checks a code without spending it, so a mistyped digit is caught before
  /// the user has chosen and confirmed a password.
  Future<void> verifyResetCode({
    required String companyCode,
    required String email,
    required String code,
  }) => _api.post<dynamic>(
    '/auth/verify-reset-code',
    body: {
      'companyCode': companyCode.trim(),
      'email': email.trim(),
      'code': code.trim(),
    },
    noAuth: true,
  );

  /// Spends the code and sets the new password. Signs out every device.
  Future<void> resetPassword({
    required String companyCode,
    required String email,
    required String code,
    required String newPassword,
  }) => _api.post<dynamic>(
    '/auth/reset-password',
    body: {
      'companyCode': companyCode.trim(),
      'email': email.trim(),
      'code': code.trim(),
      'newPassword': newPassword,
    },
    noAuth: true,
  );
}

/// Where a reset code went, and how long it lasts.
class PasswordResetTarget {
  const PasswordResetTarget({required this.sentTo, required this.expiresInMinutes});

  /// Masked, e.g. `ra••••@gmail.com`. Built by the server from what was typed
  /// rather than from the account, so it says nothing about whether one exists.
  final String sentTo;
  final int expiresInMinutes;

  factory PasswordResetTarget.fromJson(Map<String, dynamic> json) =>
      PasswordResetTarget(
        sentTo: json['sentTo'] as String? ?? '',
        expiresInMinutes: json['expiresInMinutes'] as int? ?? 15,
      );
}
