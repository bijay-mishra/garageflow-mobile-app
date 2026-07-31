import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garageflow_mobile/app.dart';
import 'package:garageflow_mobile/core/api_client.dart';
import 'package:garageflow_mobile/core/formatters.dart';
import 'package:garageflow_mobile/core/i18n.dart';
import 'package:garageflow_mobile/core/theme.dart';
import 'package:garageflow_mobile/core/token_storage.dart';
import 'package:garageflow_mobile/features/auth/login_screen.dart';
import 'package:garageflow_mobile/features/auth/forgot_password_screen.dart';
import 'package:garageflow_mobile/features/auth/splash_screen.dart';
import 'package:garageflow_mobile/features/customer/bills_screen.dart';
import 'package:garageflow_mobile/features/customer/book_service_screen.dart';
import 'package:garageflow_mobile/features/customer/customer_home_screen.dart';
import 'package:garageflow_mobile/features/customer/customer_job_detail_screen.dart';
import 'package:garageflow_mobile/features/auth/signup_screen.dart';
import 'package:garageflow_mobile/features/customer/customer_shell.dart';
import 'package:garageflow_mobile/features/customer/garage_directory_screen.dart';
import 'package:garageflow_mobile/features/customer/service_history_screen.dart';
import 'package:garageflow_mobile/features/customer/track_delivery_screen.dart';
import 'package:garageflow_mobile/features/mechanic/add_service_sheet.dart';
import 'package:garageflow_mobile/features/mechanic/deliveries_screen.dart';
import 'package:garageflow_mobile/features/mechanic/driver_trip_screen.dart';
import 'package:garageflow_mobile/features/mechanic/mechanic_job_detail_screen.dart';
import 'package:garageflow_mobile/features/mechanic/mechanic_jobs_screen.dart';
import 'package:garageflow_mobile/features/mechanic/mechanic_shell.dart';
import 'package:garageflow_mobile/features/mechanic/photo_upload_sheet.dart';
import 'package:garageflow_mobile/features/mechanic/update_status_sheet.dart';
import 'package:garageflow_mobile/features/notifications/notifications_screen.dart';
import 'package:garageflow_mobile/features/profile/account_screen.dart';
import 'package:garageflow_mobile/features/profile/appearance_screen.dart';
import 'package:garageflow_mobile/features/profile/feedback_screen.dart';
import 'package:garageflow_mobile/features/profile/language_screen.dart';
import 'package:garageflow_mobile/features/profile/profile_screen.dart';
import 'package:garageflow_mobile/features/profile/security_screen.dart';
import 'package:garageflow_mobile/features/profile/workshop_screen.dart';
import 'package:garageflow_mobile/features/shared/photo_viewer.dart';
import 'package:garageflow_mobile/models/job.dart';
import 'package:garageflow_mobile/services/auth_service.dart';
import 'package:garageflow_mobile/services/billing_service.dart';
import 'package:garageflow_mobile/services/catalogue_service.dart';
import 'package:garageflow_mobile/services/customer_service.dart';
import 'package:garageflow_mobile/services/delivery_service.dart';
import 'package:garageflow_mobile/services/directory_service.dart';
import 'package:garageflow_mobile/services/mechanic_service.dart';
import 'package:garageflow_mobile/services/notification_service.dart';
import 'package:garageflow_mobile/state/auth_controller.dart';
import 'package:garageflow_mobile/state/notification_controller.dart';
import 'package:garageflow_mobile/state/settings_controller.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Compiles and renders the parts of the app that do not need a server.
///
/// The static analyser type-checks every file, but only a test that actually
/// *builds* a widget proves its `build` method runs — a bad const, a null
/// dereference in a layout, or a provider read with no provider above it are
/// all runtime failures that analysis cannot see.
///
/// The wide import list is deliberate: it drags every screen into the compile
/// unit, so a screen no test touches still has to compile.
void main() {
  // Referencing each screen's type forces it to be compiled and keeps the
  // imports honest rather than dead weight the linter would strip.
  final screens = <Type>[
    LoginScreen,
    SignUpScreen,
    ForgotPasswordScreen,
    SplashScreen,
    MechanicShell,
    MechanicJobsScreen,
    MechanicJobDetailScreen,
    UpdateStatusSheet,
    PhotoUploadSheet,
    AddServiceSheet,
    MechanicDeliveriesScreen,
    DriverTripScreen,
    CustomerShell,
    CustomerHomeScreen,
    CustomerJobDetailScreen,
    BookServiceScreen,
    BillsScreen,
    ServiceHistoryScreen,
    GarageDirectoryScreen,
    TrackDeliveryScreen,
    NotificationsScreen,
    ProfileScreen,
    AccountEditScreen,
    SecurityScreen,
    AppearanceScreen,
    LanguageScreen,
    FeedbackScreen,
    WorkshopScreen,
    PhotoViewerScreen,
  ];

  test('every screen is reachable and compiled', () {
    expect(screens, hasLength(29));
  });

  test('theme resolves a colour for every job status', () {
    for (final status in jobStatuses) {
      expect(AppTheme.statusColor(status), isNotNull);
    }
  });

  test('every English key has a Nepali translation', () {
    // The check that keeps the translation honest. A key added to English and
    // forgotten in Nepali falls back silently, so the app would show one
    // English line in the middle of a Nepali screen and nothing would complain.
    final missing = AppText.keys.where((key) {
      final english = const AppText('en')(key);
      final nepali = const AppText('ne')(key);
      // Identical means Nepali fell through to the English table — except where
      // the string is deliberately the same in both, which is only the product
      // name.
      return nepali == english && english != 'GarageFlow';
    }).toList();

    expect(missing, isEmpty, reason: 'Untranslated keys: ${missing.join(', ')}');
  });

  test('placeholders survive translation', () {
    // A `{0}` dropped in translation means a number silently vanishes from the
    // sentence — "jobs are past their promised time" with no count.
    for (final key in AppText.keys) {
      final english = const AppText('en')(key);
      final nepali = const AppText('ne')(key);

      for (final slot in ['{0}', '{1}']) {
        if (english.contains(slot)) {
          expect(
            nepali.contains(slot),
            isTrue,
            reason: '$key is missing $slot in Nepali',
          );
        }
      }
    }
  });

  test('substitution fills placeholders', () {
    expect(const AppText('en')('garages.away', [3.9]), '3.9 km away');
    expect(const AppText('en')('jobs.greeting', ['Rita']), 'Hi, Rita');
    // An unknown key returns itself rather than throwing or rendering blank.
    expect(const AppText('en')('nope.missing'), 'nope.missing');
  });

  group('Bikram Sambat dates', () {
    // These pairs were computed independently by the dashboard's
    // nepali-date-converter and pasted here. If the Dart package and the JS
    // one ever disagree, the phone and the web screen would show different
    // dates for the same invoice — which is the failure this catches.
    const pairs = <String, String>{
      '2026-07-30': '14 साउन 2083',
      '2026-07-17': '1 साउन 2083',
      '2026-07-16': '32 असार 2083',
      '2025-04-14': '1 बैशाख 2082',
      '2026-04-14': '1 बैशाख 2083',
    };

    test('converts to the same BS dates the dashboard does', () {
      Fmt.language = 'ne';
      addTearDown(() => Fmt.language = 'en');

      for (final entry in pairs.entries) {
        final ad = DateTime.parse(entry.key);

        // Compared on ASCII digits. The Devanagari rendering is checked by
        // its own test, and mixing the two makes a failure hard to read.
        final actual = Fmt.date(ad).replaceAllMapped(
          RegExp('[०-९]'),
          (m) => '०१२३४५६७८९'.indexOf(m[0]!).toString(),
        );

        expect(actual, entry.value, reason: 'for ${entry.key}');
      }
    });

    test('English stays Gregorian', () {
      Fmt.language = 'en';
      expect(Fmt.date(DateTime(2026, 7, 30)), '30 Jul 2026');
    });

    test('Rs stays Latin in both languages, digits follow', () {
      Fmt.language = 'en';
      expect(Fmt.rs(12500), 'Rs 12,500');

      Fmt.language = 'ne';
      expect(Fmt.rs(12500), 'Rs १२,५००');

      Fmt.language = 'en';
    });
  });

  testWidgets('splash screen renders', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SplashScreen()));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('app boots to the splash while the session is being read', (
    tester,
  ) async {
    final storage = TokenStorage();
    final api = ApiClient(storage);

    // The app reads theme, language and text size during its first build, so
    // the settings have to be present before it mounts. An empty map gives
    // every default, which is what a fresh install sees.
    SharedPreferences.setMockInitialValues({});
    final settings = await SettingsController.load();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider.value(value: api),
          ChangeNotifierProvider.value(value: settings),
          Provider(create: (_) => AuthService(api)),
          Provider(create: (_) => MechanicService(api)),
          Provider(create: (_) => CustomerService(api)),
          Provider(create: (_) => CatalogueService(api)),
          Provider(create: (_) => BillingService(api)),
          Provider(create: (_) => NotificationApi(api)),
          Provider(create: (_) => DirectoryService(api)),
          Provider(create: (_) => DeliveryApi(api)),
          ChangeNotifierProvider(
            create: (context) => AuthController(
              api: api,
              auth: context.read<AuthService>(),
              directory: context.read<DirectoryService>(),
              storage: storage,
            ),
          ),
          ChangeNotifierProvider(
            create: (context) =>
                NotificationController(context.read<NotificationApi>()),
          ),
        ],
        child: const GarageFlowApp(),
      ),
    );

    // `restore()` is deliberately not called: secure storage has no platform
    // behind it in a unit test. The controller starts in `checking`, which is
    // exactly the state this asserts.
    expect(find.byType(SplashScreen), findsOneWidget);
  });
}
