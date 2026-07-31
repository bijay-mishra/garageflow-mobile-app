import 'package:google_sign_in/google_sign_in.dart';

import '../core/api_client.dart';
import '../core/config.dart';
import '../models/auth_user.dart';

/// "Sign in with Google", for customers.
///
/// ## What actually crosses the wire
///
/// The app never sends Google a password and never sends us one either. Google
/// hands back an **ID token** — a short-lived JWT signed by Google asserting
/// "this is rita@example.com". That token goes to our API, which verifies the
/// signature, the audience and the expiry before trusting a single field of it.
///
/// The access token Google also offers is deliberately unused: it is a bearer
/// key for calling Google's own APIs and proves nothing about identity.
///
/// ## Why it can be switched off
///
/// [isConfigured] is false until a server client ID is compiled in. The button
/// is hidden in that case rather than shown and failing on tap — the same rule
/// the Khalti button follows. A dead button is worse than an absent one.
class GoogleSignInService {
  GoogleSignInService(this._api);

  final ApiClient _api;

  bool _initialised = false;

  /// True when this build has a client ID and the platform can sign in.
  ///
  /// Both halves matter: the desktop and web plugins do not implement the
  /// interactive `authenticate()` flow, so a configured build can still be
  /// unable to use it.
  bool get isConfigured =>
      AppConfig.googleServerClientId.isNotEmpty &&
      GoogleSignIn.instance.supportsAuthenticate();

  /// Prepares the plugin. Safe to call more than once.
  Future<void> _ensureInitialised() async {
    if (_initialised) return;

    await GoogleSignIn.instance.initialize(
      // The *Web* client ID, not the Android one — this is what the ID token is
      // minted for so our server can verify its audience. Google's own naming
      // here is a well-known trap: the Android client is configured by the
      // SHA-1 you registered, and is never passed in code.
      serverClientId: AppConfig.googleServerClientId,
    );

    _initialised = true;
  }

  /// Runs the Google flow and exchanges the result for a GarageFlow session.
  ///
  /// Returns null when the person backed out — which is not an error and must
  /// not raise one, because tapping Google and changing your mind is ordinary.
  Future<AuthResult?> signIn() async {
    await _ensureInitialised();

    final GoogleSignInAccount account;

    try {
      account = await GoogleSignIn.instance.authenticate();
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) return null;
      rethrow;
    }

    final idToken = account.authentication.idToken;

    if (idToken == null || idToken.isEmpty) {
      // Almost always a configuration fault rather than a user one: no
      // serverClientId, or an Android client whose SHA-1 does not match this
      // build. Worth saying plainly, because the fix is not on the phone.
      throw StateError(
        'Google did not return an ID token. Check that the server client ID is '
        'set and that this build\'s SHA-1 is registered in Google Cloud.',
      );
    }

    final data = await _api.post<Map<String, dynamic>>(
      '/auth/google',
      body: {'idToken': idToken},
      noAuth: true,
    );

    return AuthResult.fromJson(data);
  }

  /// Clears the cached Google account, so the next sign-in offers the chooser.
  ///
  /// Called on sign-out. Without it, someone handing the phone to a colleague
  /// would find it silently signing back in as them.
  Future<void> signOut() async {
    if (!_initialised) return;

    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {
      // Local cleanup only. Failing to clear Google's cache must not stop the
      // GarageFlow sign-out that matters.
    }
  }
}
