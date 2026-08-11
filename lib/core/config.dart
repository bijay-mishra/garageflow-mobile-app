/// Where the API lives, and the few knobs worth changing without a code edit.
library;

class AppConfig {
  const AppConfig._();

  /// Origin of the GarageFlow API, without a trailing slash.
  ///
  /// The live server. This is the default rather than an opt-in so that a build
  /// made without any flags reaches a server that actually exists — the first
  /// upload to Play went out pointing at `localhost`, which on a tester's
  /// handset means the handset, so every request failed and the app looked
  /// broken rather than misconfigured.
  ///
  /// **HTTPS**, which is what it should be: credentials and bearer tokens are
  /// encrypted in transit, and Play's Data safety form can honestly say so.
  /// Nothing needs a cleartext exception for this host — the entries in
  /// `android/app/src/main/res/xml/network_security_config.xml` and
  /// `ios/Runner/Info.plist` now cover only the local development addresses.
  ///
  /// The certificate has to be one the *phone* trusts, which is a stricter bar
  /// than a browser: Android validates against its own root store and there is
  /// no "proceed anyway". A self-signed certificate, or a chain served without
  /// its intermediate, fails every request with a handshake error that reads
  /// like the server being down. Verify with:
  ///
  /// ```
  /// curl -sI https://app.bijayamishra.com.np/api/plans
  /// ```
  ///
  /// If that needs `-k` to succeed, the app will not connect.
  ///
  /// Point this at a plain-HTTP server instead and the host must be added to
  /// both platform exception files, or requests fail in a way that reads as a
  /// dead network rather than a policy refusal.
  ///
  /// Override at build time. It is a compile-time constant, so changing it is a
  /// rebuild rather than a setting:
  ///
  /// ```
  /// # the API running on this machine, down the USB cable
  /// adb reverse tcp:5100 tcp:5100
  /// flutter run "-dart-define=API_BASE_URL=http://localhost:5100"
  ///
  /// # Android emulator
  /// flutter run "-dart-define=API_BASE_URL=http://10.0.2.2:5100"
  /// ```
  ///
  /// (Two leading dashes on that flag. Written with one here because a pair
  /// closes a comment in some of the config files that quote this.)
  ///
  /// On the USB route the API has to be listening on the `phone` launch
  /// profile, since `http` binds loopback only. `10.0.2.2` is the *emulator's*
  /// alias for the host and is unroutable from a real handset — it does not
  /// fail, it hangs until the timeout and then blames the server. A LAN address
  /// is no better here: this PC has a single Ethernet adapter on 192.168.1.x
  /// while the phone sits on 192.168.137.x, two networks with no route between
  /// them. The tunnel is per-connection, so re-run `adb reverse` after
  /// replugging; `adb reverse --list` shows whether it is live.
  ///
  /// The Account screen shows which server the app is talking to.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://app.bijayamishra.com.np',
  );

  /// Prefix every endpoint sits under.
  static String get apiRoot => '$apiBaseUrl/api';

  /// Tenant code sent with sign-in. Prefilled on the login screen; a workshop
  /// running its own build can bake its own in here.
  static const String defaultCompanyCode = String.fromEnvironment(
    'COMPANY_CODE',
    defaultValue: 'DEMO',
  );

  /// The Google **Web** OAuth client ID, for "Sign in with Google".
  ///
  /// Empty by default, which hides the button. Compile it in with:
  ///
  /// 
  ///
  /// The Web client, not the Android one — this is the audience the ID
  /// token is minted for, and what the API checks it against. The Android
  /// client is matched by the SHA-1 you registered and never appears here.
  ///
  /// The same id must also be in the API's GoogleAuth:ClientIds, or every
  /// token will be rejected for the right reason.
  static const String googleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
    defaultValue: '',
  );

  /// How often the notification badge re-checks while the app is open.
  ///
  /// This is a polling feed, not push — nothing arrives while the app is
  /// closed. Thirty seconds is frequent enough to feel live and slow enough
  /// that it costs neither battery nor data worth measuring.
  static const Duration notificationPollInterval = Duration(seconds: 30);

  /// Longest a request may take before the app gives up and says so.
  static const Duration requestTimeout = Duration(seconds: 20);

  /// Photos are downsized to this before upload — the API rejects anything
  /// over 4 MB, and a modern phone camera clears that in one shot.
  static const int photoMaxWidth = 1600;
  static const int photoQuality = 82;
}
