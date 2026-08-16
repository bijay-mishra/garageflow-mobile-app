library;
class AppConfig {
  const AppConfig._();
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://202.51.3.68:8013',
  );
  static String get apiRoot => '$apiBaseUrl/api';
  static const String defaultCompanyCode = String.fromEnvironment(
    'COMPANY_CODE',
    defaultValue: 'DEMO',
  );
  static const String googleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
    defaultValue: '',
  );

  static const Duration notificationPollInterval = Duration(seconds: 30);

  /// Longest a request may take before the app gives up and says so.
  static const Duration requestTimeout = Duration(seconds: 20);

  /// Photos are downsized to this before upload — the API rejects anything
  /// over 4 MB, and a modern phone camera clears that in one shot.
  static const int photoMaxWidth = 1600;
  static const int photoQuality = 82;
}
