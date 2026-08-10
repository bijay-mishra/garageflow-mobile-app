import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../models/app_notification.dart';

/// Raising an actual notification on the phone.
///
/// The app has always *had* notifications — the server records them and the
/// feed shows them — but nothing ever made the handset itself do anything. The
/// bell moved and that was all, so a customer whose car was ready found out by
/// opening the app and looking, which is the opposite of what a notification is
/// for.
///
/// This is the missing half, and it is deliberately the small half:
///
/// * It shows notifications the app has **already fetched**. There is no push
///   service behind it, no Firebase project, no server key, and nothing to
///   configure per environment.
/// * It therefore cannot wake a killed app. Android will not start a process
///   on behalf of a timer that is no longer running. Alerts arrive while the
///   app is alive — open, or backgrounded and not yet reclaimed.
///
/// The gap is real and closing it needs FCM. When that lands, this class is
/// what displays its foreground messages and [_channel] is the channel it posts
/// to, so nothing here is throwaway work.
class DeviceNotifications {
  DeviceNotifications._();

  static final _plugin = FlutterLocalNotificationsPlugin();

  /// Android needs a channel before anything can be posted to it, and the
  /// channel — not the individual notification — is what carries importance.
  /// `high` is what earns a heads-up banner rather than a silent tray entry.
  ///
  /// The id is stable and must stay that way: Android remembers a channel's
  /// settings against it, so renaming the id resets whatever the user chose
  /// about sound and silences nothing they asked to silence.
  static const _channel = AndroidNotificationChannel(
    'garageflow_updates',
    'Job and bill updates',
    description:
        'Your vehicle\'s progress, bills, bookings and rewards. '
        'Mechanics also get the jobs assigned to them.',
    importance: Importance.high,
  );

  static bool _ready = false;

  /// True once [init] has succeeded. Everything else is a no-op until then.
  static bool get ready => _ready;

  /// Called by whoever taps a notification, with the entity id it carried.
  ///
  /// A hook rather than navigation done here, because this file has no
  /// [BuildContext] and no business knowing what a job card screen is.
  static void Function(String? entityId, String kind)? onTap;

  /// Prepares the plugin and creates the Android channel.
  ///
  /// Safe to call more than once. Failures are swallowed to a debug line: a
  /// phone that refuses to set up notifications must not stop the app starting,
  /// and every method below already checks [_ready].
  static Future<void> init() async {
    if (_ready) return;

    try {
      await _plugin.initialize(
        const InitializationSettings(
          // The launcher icon, which every build already has. A dedicated
          // white-on-transparent status-bar icon would be better on Android —
          // it silhouettes anything else — but shipping a wrong-looking icon is
          // better than shipping none, which crashes the notification.
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(
            // Asked for separately, with context, once somebody has signed in.
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
        onDidReceiveNotificationResponse: (response) {
          final payload = response.payload;
          if (payload == null) return;

          // "kind|entityId", with entityId possibly empty.
          final parts = payload.split('|');
          final kind = parts.isNotEmpty ? parts[0] : 'system';
          final entityId = parts.length > 1 && parts[1].isNotEmpty ? parts[1] : null;

          onTap?.call(entityId, kind);
        },
      );

      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_channel);

      _ready = true;
    } catch (error) {
      debugPrint('Notifications unavailable: $error');
    }
  }

  /// Asks the phone for permission to post notifications.
  ///
  /// Android 13 and up need it; below that it returns true without a prompt.
  /// iOS always prompts. Called once a session exists rather than at launch —
  /// a permission request on the login screen has no context behind it.
  ///
  /// Returns false when refused, and nothing else changes: the in-app feed is
  /// unaffected, so the app keeps working exactly as it did before.
  static Future<bool> requestPermission() async {
    if (!_ready) return false;

    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

      if (android != null) {
        return await android.requestNotificationsPermission() ?? false;
      }

      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();

      if (ios != null) {
        return await ios.requestPermissions(alert: true, badge: true, sound: true) ??
            false;
      }

      return false;
    } catch (error) {
      debugPrint('Notification permission request failed: $error');
      return false;
    }
  }

  /// Posts one notification to the tray.
  ///
  /// The server's row id becomes the notification id, which makes this
  /// idempotent for free: showing the same notification twice replaces it
  /// rather than stacking a duplicate, so a poll that overlaps another cannot
  /// buzz the phone twice for one event.
  static Future<void> show(AppNotification notification) async {
    if (!_ready) return;

    try {
      await _plugin.show(
        notification.id,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channel.id,
            _channel.name,
            channelDescription: _channel.description,
            importance: Importance.high,
            priority: Priority.high,
            // A bill line or a mechanic's note can run past one line, and the
            // collapsed form truncates. This lets it expand when pulled down.
            styleInformation: BigTextStyleInformation(notification.body),
          ),
          iOS: const DarwinNotificationDetails(),
        ),
        payload: '${notification.kind}|${notification.entityId ?? ''}',
      );
    } catch (error) {
      debugPrint('Could not show notification ${notification.id}: $error');
    }
  }

  /// Clears the tray. Called on sign-out, so one person's job updates are not
  /// left sitting on the phone for whoever signs in next.
  static Future<void> clearAll() async {
    if (!_ready) return;

    try {
      await _plugin.cancelAll();
    } catch (error) {
      debugPrint('Could not clear notifications: $error');
    }
  }
}
