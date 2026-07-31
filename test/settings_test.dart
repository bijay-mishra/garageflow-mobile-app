import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garageflow_mobile/state/settings_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('theme mode round-trips and notifies', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = await SettingsController.load();

    var notifications = 0;
    settings.addListener(() => notifications++);

    expect(settings.themeMode, ThemeMode.system);

    await settings.setThemeMode(ThemeMode.dark);
    expect(settings.themeMode, ThemeMode.dark);

    await settings.setThemeMode(ThemeMode.light);
    expect(settings.themeMode, ThemeMode.light);

    await settings.setThemeMode(ThemeMode.system);
    expect(settings.themeMode, ThemeMode.system);

    expect(notifications, 3, reason: 'every change must notify listeners');
  });

  test('text size round-trips', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = await SettingsController.load();

    expect(settings.textSize, TextSizeChoice.normal);

    await settings.setTextSize(TextSizeChoice.large);
    expect(settings.textSize, TextSizeChoice.large);
  });

  test('survives a reload', () async {
    SharedPreferences.setMockInitialValues({});
    final first = await SettingsController.load();
    await first.setThemeMode(ThemeMode.dark);

    // A fresh controller over the same store, as a relaunch would build.
    final second = await SettingsController.load();
    expect(second.themeMode, ThemeMode.dark);
  });
}
