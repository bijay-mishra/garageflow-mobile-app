/// Where the API lives, and the few knobs worth changing without a code edit.
library;

class AppConfig {
  const AppConfig._();

  /// Origin of the GarageFlow API, without a trailing slash.
  ///
  /// The default goes down the USB cable, not over wifi.
  ///
  /// `localhost` on a phone normally means the phone. It means this machine
  /// only because of a reverse tunnel set up alongside the build:
  ///
  /// ```
  /// adb reverse tcp:5100 tcp:5100
  /// ```
  ///
  /// That was chosen over a LAN address after two dead ends. `10.0.2.2` is the
  /// *emulator's* alias for the host and is unroutable from a real handset — it
  /// does not fail, it hangs until the timeout and then blames the server. And
  /// the obvious replacement, the machine's own LAN address, does not work here
  /// either: this PC has a single Ethernet adapter on 192.168.1.x while the
  /// phone sits on 192.168.137.x, two networks with no route between them.
  ///
  /// USB sidesteps all of it. Nothing has to be on the same wifi, no firewall
  /// rule is involved, and it keeps working when the router hands out different
  /// addresses tomorrow. The one catch is that the tunnel is per-connection:
  /// unplug the phone and it is gone, so re-run the adb command after
  /// replugging. `adb reverse --list` shows whether it is live.
  ///
  /// Override at build time for anything else. It is a compile-time constant,
  /// so changing it is a rebuild rather than a setting:
  ///
  /// ```
  /// # Android emulator
  /// flutter run "-dart-define=API_BASE_URL=http://10.0.2.2:5100"
  ///
  /// # real phone over wifi, when the PC and phone share a network
  /// flutter run "-dart-define=API_BASE_URL=http://192.168.1.97:5100"
  ///
  /// # a real shop, one day
  /// flutter build apk "-dart-define=API_BASE_URL=https://api.yourshop.com"
  /// ```
  ///
  /// (Two leading dashes on that flag. Written with one here because a pair
  /// closes a comment in some of the config files that quote this.)
  ///
  /// The API still has to be listening: use the `phone` launch profile, since
  /// `http` binds loopback only. The Account screen shows which server the app
  /// is talking to.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:5100',
  );

  /// Prefix every endpoint sits under.
  static String get apiRoot => '$apiBaseUrl/api';

  /// Tenant code sent with sign-in. Prefilled on the login screen; a workshop
  /// running its own build can bake its own in here.
  static const String defaultCompanyCode = String.fromEnvironment(
    'COMPANY_CODE',
    defaultValue: 'DEMO',
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
