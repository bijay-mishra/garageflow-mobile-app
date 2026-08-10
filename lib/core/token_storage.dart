import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/auth_user.dart';

/// The signed-in session, held in the platform's encrypted store.
///
/// Keychain on iOS, EncryptedSharedPreferences on Android. A refresh token is
/// a long-lived credential and does not belong in plain SharedPreferences,
/// which any process with disk access can read on a rooted device.
class TokenStorage {
  TokenStorage([FlutterSecureStorage? storage])
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(encryptedSharedPreferences: true),
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.first_unlock,
            ),
          );

  final FlutterSecureStorage _storage;

  static const _accessKey = 'gf_access_token';
  static const _refreshKey = 'gf_refresh_token';
  static const _userKey = 'gf_user';
  static const _rememberKey = 'gf_remembered_login';

  Future<String?> readAccessToken() => _storage.read(key: _accessKey);
  Future<String?> readRefreshToken() => _storage.read(key: _refreshKey);

  Future<void> saveTokens(String accessToken, String refreshToken) async {
    await _storage.write(key: _accessKey, value: accessToken);
    await _storage.write(key: _refreshKey, value: refreshToken);
  }

  /// Caches the user so a relaunch can show the right shell immediately,
  /// rather than a spinner while `/auth/me` answers.
  Future<void> saveUser(AuthUser user) =>
      _storage.write(key: _userKey, value: jsonEncode(user.toJson()));

  Future<AuthUser?> readUser() async {
    final raw = await _storage.read(key: _userKey);
    if (raw == null) return null;

    try {
      return AuthUser.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      // A payload written by an older build of the app. Treat it as no session
      // rather than crashing on launch — the user signs in again and it is
      // rewritten in the current shape.
      return null;
    }
  }

  /// Ends the session.
  ///
  /// Deliberately leaves the remembered login alone. Signing out and having to
  /// retype the credentials you asked the app to remember is the app forgetting
  /// the one thing you told it to keep — see [saveRemembered], and
  /// [forgetRemembered] for the cases where it really should be dropped.
  Future<void> clear() async {
    await _storage.delete(key: _accessKey);
    await _storage.delete(key: _refreshKey);
    await _storage.delete(key: _userKey);
  }

  // ── Remember me ────────────────────────────────────────────────────────────

  /// Keeps the credentials so the sign-in form opens filled in.
  ///
  /// In the same encrypted store as the refresh token, and for the same reason:
  /// this is a long-lived credential. A password in SharedPreferences is a
  /// password in a plain XML file that any process with disk access can read on
  /// a rooted phone — which would be worse than the session it is standing in
  /// for, because a stolen refresh token can be revoked from the server and a
  /// stolen password cannot.
  ///
  /// Off unless somebody ticks the box, and dropped the moment they untick it.
  Future<void> saveRemembered(RememberedLogin login) => _storage.write(
    key: _rememberKey,
    value: jsonEncode({
      'companyCode': login.companyCode,
      'email': login.email,
      'password': login.password,
    }),
  );

  Future<RememberedLogin?> readRemembered() async {
    final raw = await _storage.read(key: _rememberKey);
    if (raw == null) return null;

    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;

      return RememberedLogin(
        companyCode: json['companyCode'] as String? ?? '',
        email: json['email'] as String? ?? '',
        password: json['password'] as String? ?? '',
      );
    } catch (_) {
      // Written by an older build, or corrupt. An unreadable saved login is a
      // login form that opens empty, not a launch that crashes.
      return null;
    }
  }

  Future<void> forgetRemembered() => _storage.delete(key: _rememberKey);
}

/// Credentials the phone has been asked to hold on to.
class RememberedLogin {
  const RememberedLogin({
    required this.companyCode,
    required this.email,
    required this.password,
  });

  /// Empty for a customer — their account sits above any one garage.
  final String companyCode;

  final String email;

  /// Empty when only the email was kept. That happens after a saved password
  /// stops working: the address is still right, so it stays.
  final String password;

  bool get isStaff => companyCode.isNotEmpty;
  bool get hasPassword => password.isNotEmpty;
}
