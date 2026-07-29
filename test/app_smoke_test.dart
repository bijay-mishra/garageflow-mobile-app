import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garageflow_mobile/app.dart';
import 'package:garageflow_mobile/core/api_client.dart';
import 'package:garageflow_mobile/core/theme.dart';
import 'package:garageflow_mobile/core/token_storage.dart';
import 'package:garageflow_mobile/features/auth/login_screen.dart';
import 'package:garageflow_mobile/features/auth/splash_screen.dart';
import 'package:garageflow_mobile/features/customer/bills_screen.dart';
import 'package:garageflow_mobile/features/customer/book_service_screen.dart';
import 'package:garageflow_mobile/features/customer/customer_home_screen.dart';
import 'package:garageflow_mobile/features/customer/customer_job_detail_screen.dart';
import 'package:garageflow_mobile/features/customer/customer_shell.dart';
import 'package:garageflow_mobile/features/customer/service_history_screen.dart';
import 'package:garageflow_mobile/features/mechanic/add_service_sheet.dart';
import 'package:garageflow_mobile/features/mechanic/mechanic_job_detail_screen.dart';
import 'package:garageflow_mobile/features/mechanic/mechanic_jobs_screen.dart';
import 'package:garageflow_mobile/features/mechanic/mechanic_shell.dart';
import 'package:garageflow_mobile/features/mechanic/photo_upload_sheet.dart';
import 'package:garageflow_mobile/features/mechanic/update_status_sheet.dart';
import 'package:garageflow_mobile/features/notifications/notifications_screen.dart';
import 'package:garageflow_mobile/features/shared/account_screen.dart';
import 'package:garageflow_mobile/features/shared/photo_viewer.dart';
import 'package:garageflow_mobile/models/job.dart';
import 'package:garageflow_mobile/services/auth_service.dart';
import 'package:garageflow_mobile/services/billing_service.dart';
import 'package:garageflow_mobile/services/catalogue_service.dart';
import 'package:garageflow_mobile/services/customer_service.dart';
import 'package:garageflow_mobile/services/mechanic_service.dart';
import 'package:garageflow_mobile/services/notification_service.dart';
import 'package:garageflow_mobile/state/auth_controller.dart';
import 'package:garageflow_mobile/state/notification_controller.dart';
import 'package:provider/provider.dart';

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
    SplashScreen,
    MechanicShell,
    MechanicJobsScreen,
    MechanicJobDetailScreen,
    UpdateStatusSheet,
    PhotoUploadSheet,
    AddServiceSheet,
    CustomerShell,
    CustomerHomeScreen,
    CustomerJobDetailScreen,
    BookServiceScreen,
    BillsScreen,
    ServiceHistoryScreen,
    NotificationsScreen,
    AccountScreen,
    PhotoViewerScreen,
  ];

  test('every screen is reachable and compiled', () {
    expect(screens, hasLength(17));
  });

  test('theme resolves a colour for every job status', () {
    for (final status in jobStatuses) {
      expect(AppTheme.statusColor(status), isNotNull);
    }
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

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider.value(value: api),
          Provider(create: (_) => AuthService(api)),
          Provider(create: (_) => MechanicService(api)),
          Provider(create: (_) => CustomerService(api)),
          Provider(create: (_) => CatalogueService(api)),
          Provider(create: (_) => BillingService(api)),
          Provider(create: (_) => NotificationApi(api)),
          ChangeNotifierProvider(
            create: (context) => AuthController(
              api: api,
              auth: context.read<AuthService>(),
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
