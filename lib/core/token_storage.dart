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

  Future<void> clear() async {
    await _storage.delete(key: _accessKey);
    await _storage.delete(key: _refreshKey);
    await _storage.delete(key: _userKey);
  }
}
