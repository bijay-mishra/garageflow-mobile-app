import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'core/api_client.dart';
import 'core/token_storage.dart';
import 'services/auth_service.dart';
import 'services/billing_service.dart';
import 'services/catalogue_service.dart';
import 'services/customer_service.dart';
import 'services/delivery_service.dart';
import 'services/directory_service.dart';
import 'services/support_service.dart';
import 'services/google_sign_in_service.dart';
import 'services/mechanic_service.dart';
import 'services/notification_service.dart';
import 'state/auth_controller.dart';
import 'state/notification_controller.dart';
import 'state/settings_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Built once and shared. The API client holds the refresh-in-flight latch,
  // so a second instance would defeat it — two clients would each spend the
  // refresh token, and the server rotates it on use.
  final storage = TokenStorage();
  final api = ApiClient(storage);

  // Awaited before the first frame on purpose. Theme, language and text size
  // are read during the very first build, and loading them afterwards would
  // open the app in English at the default size and then visibly correct
  // itself — a flash of the wrong app every launch.
  final settings = await SettingsController.load();

  runApp(
    MultiProvider(
      providers: [
        Provider.value(value: storage),
        ChangeNotifierProvider.value(value: settings),
        Provider.value(value: api),
        Provider(create: (_) => AuthService(api)),
        Provider(create: (_) => MechanicService(api)),
        Provider(create: (_) => CustomerService(api)),
        // Shared: the price list is the same list whichever side is signed in.
        Provider(create: (_) => CatalogueService(api)),
        // Bills, paying them, and the workshop's own details.
        Provider(create: (_) => BillingService(api)),
        Provider(create: (_) => NotificationApi(api)),
        // The garage directory, signing up, and switching between garages.
        Provider(create: (_) => DirectoryService(api)),
        // Sign in with Google. Inert unless a client ID is compiled in.
        Provider(create: (_) => GoogleSignInService(api)),
        // Handovers. Shared: a driver and a customer look at the same record.
        Provider(create: (_) => DeliveryApi(api)),
        // Chat with the garage. An assistant answers first and passes anything
        // it cannot to a person at the workshop.
        Provider(create: (_) => SupportService(api)),
        ChangeNotifierProvider(
          create: (context) => AuthController(
            api: api,
            auth: context.read<AuthService>(),
            directory: context.read<DirectoryService>(),
            storage: storage,
          )..restore(),
        ),
        ChangeNotifierProvider(
          create: (context) =>
              NotificationController(context.read<NotificationApi>()),
        ),
      ],
      child: const GarageFlowApp(),
    ),
  );
}
