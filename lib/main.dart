import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'core/api_client.dart';
import 'core/token_storage.dart';
import 'services/auth_service.dart';
import 'services/billing_service.dart';
import 'services/catalogue_service.dart';
import 'services/customer_service.dart';
import 'services/mechanic_service.dart';
import 'services/notification_service.dart';
import 'state/auth_controller.dart';
import 'state/notification_controller.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Built once and shared. The API client holds the refresh-in-flight latch,
  // so a second instance would defeat it — two clients would each spend the
  // refresh token, and the server rotates it on use.
  final storage = TokenStorage();
  final api = ApiClient(storage);

  runApp(
    MultiProvider(
      providers: [
        Provider.value(value: storage),
        Provider.value(value: api),
        Provider(create: (_) => AuthService(api)),
        Provider(create: (_) => MechanicService(api)),
        Provider(create: (_) => CustomerService(api)),
        // Shared: the price list is the same list whichever side is signed in.
        Provider(create: (_) => CatalogueService(api)),
        // Bills, paying them, and the workshop's own details.
        Provider(create: (_) => BillingService(api)),
        Provider(create: (_) => NotificationApi(api)),
        ChangeNotifierProvider(
          create: (context) => AuthController(
            api: api,
            auth: context.read<AuthService>(),
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
