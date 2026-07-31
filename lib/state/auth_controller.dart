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
import '../services/directory_service.dart';
import '../services/google_sign_in_service.dart';

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
    required DirectoryService directory,
    required TokenStorage storage,
  }) : _api = api,
       _auth = auth,
       _directory = directory,
       _storage = storage {
    // The client cannot import Flutter, so it reports a dead session by
    // calling back into here.
    _api.onSessionExpired = _onSessionExpired;
  }

  final ApiClient _api;
  final AuthService _auth;
  final DirectoryService _directory;
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

  /// Creates a customer account and signs straight into it.
  ///
  /// No company code, and no garage. The account belongs above any single
  /// workshop, so a new customer lands on the directory rather than inside
  /// somebody's books — see [needsGarage].
  Future<bool> signUp({
    required String name,
    required String email,
    required String phone,
    required String password,
  }) async {
    _busy = true;
    _error = null;
    _expiryNotice = null;
    notifyListeners();

    try {
      final result = await _directory.signUp(
        name: name,
        email: email,
        phone: phone,
        password: password,
      );

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

  /// True for a signed-in customer who has not joined a garage yet.
  ///
  /// The whole app below this point is scoped to one workshop, so there is
  /// nothing coherent to show until they pick one. The shell reads this and
  /// shows the directory instead of a home screen full of empty states.
  bool get needsGarage =>
      _user != null && _user!.isCustomer && _user!.companyCode.isEmpty;

  /// Points the session at a garage this customer has joined.
  ///
  /// The server mints a fresh token carrying that workshop, which is why this
  /// works at all: every other endpoint reads the garage out of the token, so
  /// switching is one call here rather than a parameter on all of them.
  ///
  /// Returns null on success, or the server's own refusal.
  Future<String?> switchWorkshop(String companyCode) async {
    _busy = true;
    notifyListeners();

    try {
      final result = await _directory.selectWorkshop(companyCode);

      await _storage.saveTokens(result.accessToken, result.refreshToken);
      await _storage.saveUser(result.user);

      _user = result.user;
      _busy = false;
      notifyListeners();
      return null;
    } on ApiException catch (error) {
      _busy = false;
      notifyListeners();
      return error.message;
    }
  }

  /// Re-reads the account after something changed it server-side — joining a
  /// first garage sets the cursor, and the cached user still says "no garage"
  /// until we ask again.
  Future<void> refreshUser() async {
    try {
      final fresh = await _auth.me();
      _user = fresh;
      await _storage.saveUser(fresh);
      notifyListeners();
    } on ApiException {
      // Nothing to do: the cached user is still the best answer we have, and a
      // failed refresh must not sign anyone out.
    }
  }

  /// Saves name, email and phone. Returns the server's refusal, or null.
  Future<String?> updateProfile({
    required String name,
    required String email,
    String? phone,
  }) async {
    _busy = true;
    notifyListeners();

    try {
      final fresh = await _auth.updateProfile(
        name: name,
        email: email,
        phone: phone,
      );

      _user = fresh;
      await _storage.saveUser(fresh);
      _busy = false;
      notifyListeners();
      return null;
    } on ApiException catch (error) {
      _busy = false;
      notifyListeners();
      return error.message;
    }
  }

  /// Replaces the profile photo. Returns the server's refusal, or null.
  Future<String?> setPhoto(String filePath) async {
    try {
      final fresh = await _auth.uploadPhoto(filePath);
      _user = fresh;
      await _storage.saveUser(fresh);
      notifyListeners();
      return null;
    } on ApiException catch (error) {
      return error.message;
    }
  }

  Future<String?> removePhoto() async {
    try {
      final fresh = await _auth.removePhoto();
      _user = fresh;
      await _storage.saveUser(fresh);
      notifyListeners();
      return null;
    } on ApiException catch (error) {
      return error.message;
    }
  }

  /// Changes the password and ends the session.
  ///
  /// The sign-out is not a courtesy: the server revokes every refresh token, so
  /// the one on this phone is already dead. Staying on screen would work until
  /// the access token expired and then fail in the middle of something.
  Future<String?> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    _busy = true;
    notifyListeners();

    try {
      await _auth.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );

      _busy = false;
      await _clear('Your password was changed. Please sign in again.');
      return null;
    } on ApiException catch (error) {
      _busy = false;
      notifyListeners();
      return error.message;
    }
  }

  /// Signs in with Google, creating the account if it is new.
  ///
  /// Returns true on success, false when the person backed out of the Google
  /// sheet — which is not a failure and leaves no error on screen.
  Future<bool> signInWithGoogle(GoogleSignInService google) async {
    _busy = true;
    _error = null;
    _expiryNotice = null;
    notifyListeners();

    try {
      final result = await google.signIn();

      if (result == null) {
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
    } catch (error) {
      // A misconfigured build throws a StateError rather than an ApiException,
      // and the message says what to fix — so it is shown rather than swallowed.
      _error = error is StateError ? error.message : 'Could not sign in with Google.';
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
