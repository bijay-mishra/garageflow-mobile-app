import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garageflow_mobile/core/i18n.dart';
import 'package:garageflow_mobile/core/theme.dart';
import 'package:garageflow_mobile/features/profile/appearance_screen.dart';
import 'package:garageflow_mobile/state/settings_controller.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SettingsController settings;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    settings = await SettingsController.load();
  });

  Widget harness() => ChangeNotifierProvider.value(
    value: settings,
    child: Consumer<SettingsController>(
      builder: (context, s, _) => MaterialApp(
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: s.themeMode,
        home: AppLocalizations(
          languageCode: s.languageCode,
          child: const AppearanceScreen(),
        ),
      ),
    ),
  );

  testWidgets('the screen renders its options', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pump();

    expect(find.text('Follow the phone'), findsOneWidget);
    expect(find.text('Light'), findsOneWidget);
    expect(find.text('Dark'), findsOneWidget);
    expect(find.text('Normal'), findsOneWidget);
  });

  testWidgets('tapping Dark repaints the app dark', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pump();

    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();

    expect(settings.themeMode, ThemeMode.dark);

    final context = tester.element(find.byType(Scaffold).first);
    expect(
      Theme.of(context).brightness,
      Brightness.dark,
      reason: 'the tree did not repaint',
    );
  });
}
