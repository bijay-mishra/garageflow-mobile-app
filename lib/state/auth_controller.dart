// The lint wants `required this._api` instead of an initializer list. Dart
// forbids named parameters beginning with an underscore, so that form does not
// compile — the fields are private and the parameters are named, and those two
// facts cannot both hold with an initializing formal.
// ignore_for_file: prefer_initializing_formals

import 'package:flutter/foundation.dart';

import '../core/api_client.dart';
import '../core/api_exception.dart';
import '../core/formatters.dart';
import '../core/token_storage.dart';
import '../models/auth_user.dart';
import '../services/auth_service.dart';
import '../services/directory_service.dart';
import '../services/google_sign_in_service.dart';

/// A line the login screen shows above the form, and why.
///
/// A translation key rather than a finished sentence, because the controller
/// has no [BuildContext] and therefore no language — the screen looks it up.
/// That is not a detail: these were plain English strings, which meant the one
/// message a Nepali user saw in English was the one explaining why they had
/// been signed out.
class AuthNotice {
  const AuthNotice(this.key, {this.args = const [], this.good = false});

  final String key;
  final List<Object?> args;

  /// True for news that is not a problem — an account created, a deletion
  /// scheduled exactly as asked. Decides whether the panel is drawn as a
  /// warning or as a confirmation; an amber alert over "your account is ready"
  /// reads as something having gone wrong.
  final bool good;
}

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

  /// Why the login screen is on screen, when it is there for a reason.
  ///
  /// Four things produce one: a session that expired, a password change that
  /// ended the session, an account just created, and an account just scheduled
  /// for deletion. All four answer the same question from the user's side —
  /// "why am I looking at this again?" — so they share one channel rather than
  /// four flags the screen has to prioritise between.
  AuthNotice? _notice;
  AuthNotice? get notice => _notice;

  /// Set once when a sign-in called off a pending deletion, and read by the
  /// shell to say so. Cleared by [consumeDeletionCancelled] so it announces
  /// itself on that sign-in and never again.
  bool _deletionCancelled = false;
  bool get deletionCancelled => _deletionCancelled;

  bool consumeDeletionCancelled() {
    if (!_deletionCancelled) return false;
    _deletionCancelled = false;
    return true;
  }

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
        await _clear(const AuthNotice('auth.sessionExpired'));
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
    _notice = null;
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
      _deletionCancelled = result.deletionCancelled;
      _set(AuthStatus.signedIn);
      return true;
    } on ApiException catch (error) {
      _error = error.message;
      _busy = false;
      notifyListeners();
      return false;
    }
  }

  /// Creates a customer account, and leaves them on the sign-in screen.
  ///
  /// The tokens the server hands back are deliberately thrown away. Signing
  /// somebody straight in is one tap fewer, but it also means the only
  /// confirmation that an account now exists is the app changing shape — and
  /// the password they just chose is never used, so nothing tells them whether
  /// they typed the one they meant. Signing in with it is the confirmation.
  ///
  /// No company code, and no garage: the account belongs above any single
  /// workshop and joins one from the directory afterwards — see [needsGarage].
  ///
  /// Returns true when the account was created; [notice] then carries the
  /// sentence the login screen shows.
  Future<bool> signUp({
    required String name,
    required String email,
    required String phone,
    required String password,
  }) async {
    _busy = true;
    _error = null;
    _notice = null;
    notifyListeners();

    try {
      await _directory.signUp(
        name: name,
        email: email,
        phone: phone,
        password: password,
      );

      _busy = false;
      _noteSignUp();
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

      // Carried over rather than dropped. Changing your password should not
      // quietly turn "remember me" off — and the alternative is a login screen
      // that helpfully prefills the password you have just stopped using.
      // Only when one is already stored: this never starts remembering for
      // somebody who did not ask.
      if (await _storage.readRemembered() case final saved?) {
        await _storage.saveRemembered(
          RememberedLogin(
            companyCode: saved.companyCode,
            email: saved.email,
            password: newPassword,
          ),
        );
      }

      _busy = false;
      await _clear(const AuthNotice('auth.passwordChangedNotice'));
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
    _notice = null;
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
      _deletionCancelled = result.deletionCancelled;
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
      _error = error is StateError
          ? error.message
          : 'Could not sign in with Google.';
      _busy = false;
      notifyListeners();
      return false;
    }
  }

  /// Schedules this account for deletion and ends the session.
  ///
  /// Returns the server's refusal, or null when it was accepted — at which
  /// point the app is back on the login screen with [notice] explaining the
  /// deadline. There is no signed-in state to return to: the server revoked
  /// every token, so staying put would mean a screen whose next request fails.
  ///
  /// The local sign-out happens even though the server has already invalidated
  /// the session. It has to: the tokens are still on this phone, the access
  /// token stays valid for a few more minutes, and leaving them there would
  /// leave the app looking signed in to an account on its way out.
  Future<String?> deleteAccount(String password) async {
    _busy = true;
    notifyListeners();

    try {
      final deletesOn = await _auth.requestAccountDeletion(password);

      // Nothing left to remember. Keeping the credentials would leave the login
      // screen prefilled for an account on its way out, and signing in is the
      // one thing that calls the deletion off — which is not something anybody
      // should be able to do by tapping a button that was already filled in.
      await _storage.forgetRemembered();

      _busy = false;
      await _clear(
        AuthNotice(
          'deleteAccount.scheduled',
          args: [Fmt.date(deletesOn)],
          // Good in the sense that matters here: it is exactly what was asked
          // for, and drawing it as an error would suggest something went wrong.
          good: true,
        ),
      );

      return null;
    } on ApiException catch (error) {
      _busy = false;
      notifyListeners();
      return error.message;
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
    Future.microtask(() => _clear(const AuthNotice('auth.sessionExpired')));
  }

  /// Signs out locally and leaves [notice] for the login screen.
  Future<void> _clear(AuthNotice? notice) async {
    await _storage.clear();
    _user = null;
    _notice = notice;
    _set(AuthStatus.signedOut);
  }

  /// Records that an account was created, without signing into it.
  ///
  /// Not [_clear]: there is no session to end — sign-up never opened one — and
  /// clearing storage here would wipe a session somebody else was already
  /// signed into, if they reached the sign-up screen from a signed-in phone.
  void _noteSignUp() {
    _notice = const AuthNotice('signup.created', good: true);
    notifyListeners();
  }

  void _set(AuthStatus status) {
    _status = status;
    notifyListeners();
  }
}
