import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../models/app_notification.dart';
import '../services/notification_service.dart';
import 'api_exception.dart';
import 'device_notifications.dart';

/// Push notifications, from Google's servers to this handset.
///
/// The half [DeviceNotifications] could never do. That class draws a
/// notification the app already knows about; this one is how the app finds out
/// while it is closed, which is the case the whole feature exists for — a
/// mechanic with the app shut has no poll running, and until this landed the
/// job assigned to them simply waited until they next opened it.
///
/// ## What arrives, and when
///
/// * **App closed** — Android draws the notification itself, from the
///   `notification` block the server sends. No Dart runs. Tapping it launches
///   the app and [_openedApp] gets the message.
/// * **App backgrounded** — same.
/// * **App in the foreground** — Android draws *nothing*, by design, and hands
///   the message to [FirebaseMessaging.onMessage]. Drawing the banner is then
///   this class's job, which is why it routes straight into
///   [DeviceNotifications.show] and its existing channel.
///
/// That asymmetry is the single most confusing thing about FCM and the reason a
/// working integration still looks broken while you are staring at the app.
class PushMessaging {
  PushMessaging._();

  static NotificationApi? _api;
  static String? _registered;

  /// Called with the entity id and kind when a notification is tapped.
  ///
  /// Mirrors [DeviceNotifications.onTap] so a caller wires up one handler and
  /// gets both routes into it — a tap on a push and a tap on a locally drawn
  /// banner should land the user on the same screen.
  static void Function(String? entityId, String kind)? onTap;

  /// Wires up the listeners. Call once, at startup, after `Firebase.initializeApp`.
  ///
  /// Deliberately does not ask for permission and does not send anything to the
  /// server: at launch there may be nobody signed in, and a token filed against
  /// the wrong account sends someone else's job cards to this phone.
  static void listen() {
    FirebaseMessaging.onMessage.listen(_foreground);
    FirebaseMessaging.onMessageOpenedApp.listen(_openedApp);

    // The token FCM issues is not permanent: it rotates on reinstall, on a
    // restore to a new handset, and occasionally on its own. Without this the
    // app keeps working and the phone silently stops receiving anything, which
    // is the worst shape a bug can take.
    FirebaseMessaging.instance.onTokenRefresh.listen((token) {
      _registered = null;
      unawaited(_send(token));
    });
  }

  /// Asks permission, then files this handset against the signed-in account.
  ///
  /// Called after sign-in rather than at launch, for the same reason the poll's
  /// permission prompt is: this is the first moment there is a reason to give.
  static Future<void> registerFor(NotificationApi api) async {
    _api = api;

    try {
      await FirebaseMessaging.instance.requestPermission();

      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) return;

      await _send(token);
    } catch (error) {
      // Push is an enhancement over a feed that already works. A phone that
      // cannot register still polls, still shows its notifications in the app,
      // and must still finish signing in.
      debugPrint('Could not register for push: $error');
    }
  }

  /// Stops push to this handset, on sign-out.
  ///
  /// Without it the next person to sign in on this phone would keep receiving
  /// the last person's job updates — the token is the phone's, not theirs.
  static Future<void> unregister() async {
    final api = _api;
    _registered = null;

    if (api == null) return;

    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) return;

      await api.unregisterDevice(token);
    } catch (error) {
      debugPrint('Could not unregister push: $error');
    } finally {
      _api = null;
    }
  }

  static Future<void> _send(String token) async {
    final api = _api;

    // Unchanged token, already filed. This runs on every sign-in, so skipping
    // the round trip is worth the one field it costs to remember.
    if (api == null || token == _registered) return;

    try {
      await api.registerDevice(
        token,
        defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android',
      );

      _registered = token;
    } on ApiException catch (error) {
      debugPrint('Device registration refused: ${error.message}');
    }
  }

  /// A message that arrived while the app was on screen.
  ///
  /// Android suppresses its own banner in this case, so without this the phone
  /// stays silent while the app is open — which reads as push not working at
  /// all, when in fact it is working and being deliberately hidden.
  static void _foreground(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    unawaited(DeviceNotifications.show(
      AppNotification(
        // FCM has no row id of ours to reuse, so the server sends the
        // notification's own id in the data block. Falling back to a hash keeps
        // repeats collapsing onto one tray entry rather than stacking.
        id: int.tryParse(message.data['id'] ?? '') ?? message.messageId.hashCode,
        title: notification.title ?? 'GarageFlow',
        body: notification.body ?? '',
        kind: message.data['kind'] ?? 'system',
        entityId: message.data['entityId'],
        createdAt: DateTime.now(),
        isRead: false,
      ),
    ));
  }

  /// The app was brought to the front by tapping a notification.
  static void _openedApp(RemoteMessage message) {
    final entityId = message.data['entityId'];

    onTap?.call(
      entityId is String && entityId.isNotEmpty ? entityId : null,
      message.data['kind'] ?? 'system',
    );
  }

  /// The notification that launched the app from cold, if there was one.
  ///
  /// A cold start does not fire [FirebaseMessaging.onMessageOpenedApp] — the
  /// listener is attached long after the tap happened — so this is the only way
  /// to honour a tap that started the process.
  static Future<void> handleLaunchNotification() async {
    final message = await FirebaseMessaging.instance.getInitialMessage();
    if (message != null) _openedApp(message);
  }
}
