import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// How large the app draws its text.
///
/// Named steps rather than a free slider: every screen in this app was laid out
/// at one size, and an arbitrary multiplier turns a two-line card into four and
/// clips a button. Four steps are enough for the range people actually want —
/// a mechanic in bright light and an older customer reading a bill — and each
/// one is a layout that has been looked at.
enum TextSizeChoice {
  small('Small', 0.9),
  normal('Normal', 1.0),
  large('Large', 1.15),
  larger('Larger', 1.3);

  const TextSizeChoice(this.label, this.scale);

  final String label;
  final double scale;
}

/// The app's own settings: appearance, language, and the lock.
///
/// Deliberately separate from [AuthController]. These belong to the phone, not
/// the account — someone who signs out and hands the device to a colleague
/// should not have their theme and text size follow the next person's login,
/// and the settings must survive a signed-out app so the login screen is
/// readable at the size they chose.
class SettingsController extends ChangeNotifier {
  SettingsController(this._prefs);

  final SharedPreferences _prefs;

  static const _themeKey = 'gf_theme_mode';
  static const _textSizeKey = 'gf_text_size';
  static const _langKey = 'gf_language';
  static const _lockKey = 'gf_biometric_lock';

  /// Loads the stored settings before the first frame, so the app opens in the
  /// chosen theme rather than flashing the default and correcting itself.
  static Future<SettingsController> load() async =>
      SettingsController(await SharedPreferences.getInstance());

  // ── Appearance ─────────────────────────────────────────────────────────────

  ThemeMode get themeMode => switch (_prefs.getString(_themeKey)) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    // Following the phone is the default: a workshop that switches to dark at
    // dusk should not have to switch this too.
    _ => ThemeMode.system,
  };

  Future<void> setThemeMode(ThemeMode mode) async {
    await _prefs.setString(_themeKey, switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    });
    notifyListeners();
  }

  TextSizeChoice get textSize => TextSizeChoice.values.firstWhere(
    (t) => t.name == _prefs.getString(_textSizeKey),
    orElse: () => TextSizeChoice.normal,
  );

  Future<void> setTextSize(TextSizeChoice choice) async {
    await _prefs.setString(_textSizeKey, choice.name);
    notifyListeners();
  }

  // ── Language ───────────────────────────────────────────────────────────────

  /// `en` or `ne`. Defaults to English rather than the phone's locale: the
  /// Nepali translation is complete for this app's own words but a workshop's
  /// own data — service names, complaints, customer names — is whatever the
  /// shop typed, so guessing the language from the handset would give a mixed
  /// screen nobody chose.
  String get languageCode => _prefs.getString(_langKey) ?? 'en';

  Locale get locale => Locale(languageCode);

  Future<void> setLanguage(String code) async {
    await _prefs.setString(_langKey, code);
    notifyListeners();
  }

  // ── Security ───────────────────────────────────────────────────────────────

  /// Whether the app asks for a fingerprint or face before showing anything.
  ///
  /// This locks the *screens*, not the session. The tokens are already in the
  /// keychain; this stops someone picking up an unlocked phone and reading a
  /// customer's address or a job list. It is not a second factor and does not
  /// pretend to be one.
  bool get biometricLock => _prefs.getBool(_lockKey) ?? false;

  Future<void> setBiometricLock(bool enabled) async {
    await _prefs.setBool(_lockKey, enabled);
    notifyListeners();
  }
}
