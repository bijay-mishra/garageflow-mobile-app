import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'app.dart';
import 'core/api_client.dart';
import 'core/device_notifications.dart';
import 'core/token_storage.dart';
import 'services/auth_service.dart';
import 'services/billing_service.dart';
import 'services/catalogue_service.dart';
import 'services/customer_service.dart';
import 'services/delivery_service.dart';
import 'services/directory_service.dart';
import 'services/loyalty_service.dart';
import 'services/support_service.dart';
import 'services/google_sign_in_service.dart';
import 'services/mechanic_service.dart';
import 'core/app_navigator.dart';
import 'core/push_messaging.dart';
import 'services/notification_service.dart';
import 'services/plans_service.dart';
import 'state/auth_controller.dart';
import 'state/notification_controller.dart';
import 'state/settings_controller.dart';

/// Runs in its own isolate when a push arrives with the app closed.
///
/// Must be a top-level function annotated `vm:entry-point`, or release builds
/// tree-shake it and background messages quietly stop arriving. It gets a fresh
/// isolate with none of the app's state, which is why it initialises Firebase
/// again and why there is nothing useful to do here beyond that: Android has
/// already drawn the notification from the `notification` block by the time
/// this runs. The work happens when the user taps it.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

Future<void> main() async {
  // 2. Ensure Flutter bindings are initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Before anything touches messaging. Registering the background handler
  // needs an initialised app, and so does the token lookup after sign-in.
  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Built once and shared. The API client holds the refresh-in-flight latch,
  // so a second instance would defeat it — two clients would each spend the
  // refresh token, and the server rotates it on use.
  final storage = TokenStorage();
  final api = ApiClient(storage);

  // Prepares the plugin and the Android channel. Not a permission request —
  // that waits until somebody has signed in and there is a reason to give. Safe
  // to await: it swallows its own failures, so a phone that refuses to set up
  // notifications still gets the app.
  await DeviceNotifications.init();

  // Attaches the foreground and tap listeners. No permission prompt and no
  // token sent yet — at this point there may be nobody signed in, and a token
  // filed against the wrong account sends one person's job cards to another
  // person's phone. That happens in PushMessaging.registerFor, after sign-in.
  PushMessaging.listen();

  // Both tap routes land on the same handler: a banner this app drew while it
  // was open, and a push Android drew while it was closed. They were separate
  // callbacks with no subscriber at all until now, so a tapped notification
  // opened the app and left you wherever you last were.
  DeviceNotifications.onTap = AppNavigator.openNotification;
  PushMessaging.onTap = AppNavigator.openNotification;

  // Awaited before the first frame on purpose. Theme, language and text size
  // are read during the very first build, and loading them afterwards would
  // open the app in English at the default size and then visibly correct
  // itself — a flash of the wrong app every launch.
  final settingsController = await SettingsController.load();

  runApp(
    MultiProvider(
      providers: [
        Provider.value(value: storage),
        ChangeNotifierProvider.value(value: settingsController),
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
        // What GarageFlow costs. Needs no session — a price list is public.
        Provider(create: (_) => PlansService(api)),
        // Rewards, offers and star ratings. Shared: the customer reads their
        // own card and rates finished work, the mechanic reads their score.
        Provider(create: (_) => LoyaltyService(api)),
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