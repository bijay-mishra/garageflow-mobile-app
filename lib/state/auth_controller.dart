// The lint wants `required this._api` instead of an initializer list. Dart
// forbids named parameters beginning with an underscore, so that form does not
// compile — the fields are private and the parameters are named, and those two
// facts cannot both hold with an initializing formal.
// ignore_for_file: prefer_initializing_formals

import 'package:flutter/foundation.dart';

import '../core/api_client.dart';
import '../core/api_exception.dart';
import '../core/token_storage.dart';
import '../models/auth_user.dart';
import '../services/auth_service.dart';

/// Where the session lives.
enum AuthStatus {
  /// Reading the stored session on launch — the splash screen.
  checking,
  signedOut,
  signedIn,
}

/// Owns the session: who is signed in, and the transitions in and out.
///
/// The rest of the app never touches [TokenStorage] directly. It watches this,
/// and `AuthGate` picks the shell from [user].
class AuthController extends ChangeNotifier {
  AuthController({
    required ApiClient api,
    required AuthService auth,
    required TokenStorage storage,
  }) : _api = api,
       _auth = auth,
       _storage = storage {
    // The client cannot import Flutter, so it reports a dead session by
    // calling back into here.
    _api.onSessionExpired = _onSessionExpired;
  }

  final ApiClient _api;
  final AuthService _auth;
  final TokenStorage _storage;

  AuthStatus _status = AuthStatus.checking;
  AuthUser? _user;
  String? _error;
  bool _busy = false;

  AuthStatus get status => _status;
  AuthUser? get user => _user;
  String? get error => _error;
  bool get busy => _busy;

  /// Set when a session ended on its own rather than by the user signing out,
  /// so the login screen can explain why they are looking at it again.
  String? _expiryNotice;
  String? get expiryNotice => _expiryNotice;

  /// Restores a stored session on launch.
  ///
  /// The cached user is shown immediately so the app opens on the right shell
  /// rather than a spinner, then `/auth/me` confirms it in the background. If
  /// that call finds the account has been deactivated or deleted, the session
  /// ends there.
  Future<void> restore() async {
    final cached = await _storage.readUser();
    final token = await _storage.readRefreshToken();

    if (cached == null || token == null) {
      _set(AuthStatus.signedOut);
      return;
    }

    _user = cached;
    _set(AuthStatus.signedIn);

    try {
      final fresh = await _auth.me();
      _user = fresh;
      await _storage.saveUser(fresh);
      notifyListeners();
    } on ApiException catch (error) {
      // Only a rejection ends the session. A dead connection must not sign
      // someone out — a mechanic in a workshop basement should still see the
      // jobs they loaded earlier.
      if (error.statusCode == 401 || error.statusCode == 403) {
        await _clear('Your session has expired. Please sign in again.');
      }
    }
  }

  Future<bool> login({
    required String companyCode,
    required String email,
    required String password,
  }) async {
    _busy = true;
    _error = null;
    _expiryNotice = null;
    notifyListeners();

    try {
      final result = await _auth.login(
        companyCode: companyCode,
        email: email,
        password: password,
      );

      // Staff have a whole dashboard; this app has no screen for them, and
      // dropping them into an empty shell would look like a bug rather than a
      // deliberate boundary.
      if (result.user.isStaff) {
        _error =
            'This app is for mechanics and customers. '
            'Owners, managers and advisors should use the GarageFlow dashboard.';
        _busy = false;
        notifyListeners();
        return false;
      }

      await _storage.saveTokens(result.accessToken, result.refreshToken);
      await _storage.saveUser(result.user);

      _user = result.user;
      _busy = false;
      _set(AuthStatus.signedIn);
      return true;
    } on ApiException catch (error) {
      _error = error.message;
      _busy = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    final token = await _storage.readRefreshToken();

    if (token != null) {
      try {
        await _auth.logout(token);
      } on ApiException {
        // Signing out on a dead connection still has to sign you out locally.
        // The refresh token expires on its own.
      }
    }

    await _clear(null);
  }

  void clearError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }

  void _onSessionExpired() {
    // Fired from an interceptor, potentially mid-build, so the state change is
    // deferred to the next frame rather than mutating during a rebuild.
    Future.microtask(
      () => _clear('Your session has expired. Please sign in again.'),
    );
  }

  Future<void> _clear(String? notice) async {
    await _storage.clear();
    _user = null;
    _expiryNotice = notice;
    _set(AuthStatus.signedOut);
  }

  void _set(AuthStatus status) {
    _status = status;
    notifyListeners();
  }
}
