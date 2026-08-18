import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../features/customer/customer_job_detail_screen.dart';
import '../features/mechanic/mechanic_job_detail_screen.dart';
import '../state/auth_controller.dart';

/// Opening the right screen when a notification is tapped.
///
/// A notification can be tapped from three places that share nothing else: the
/// in-app feed, a banner this app drew while it was open, and a push Android
/// drew while the app was closed. The last two arrive with no [BuildContext] at
/// all — the tap is delivered to a static callback, long after whatever widget
/// might have handled it is gone — which is why the navigator is reachable
/// through a global key here rather than passed down.
///
/// Keeping the kind-to-screen decision in one function is the point. It used to
/// live only in the notifications feed, so a push carrying the same job id
/// would have opened nothing.
class AppNavigator {
  AppNavigator._();

  /// Handed to [MaterialApp.navigatorKey] in app.dart.
  static final key = GlobalKey<NavigatorState>();

  /// Routes a tapped notification, from anywhere.
  ///
  /// Silent when there is nothing to open. Most notifications are fully
  /// described by their own text — a confirmed booking says everything a
  /// booking screen would — and pushing a screen for those would take somebody
  /// somewhere they did not ask to go.
  static void openNotification(String? entityId, String kind) {
    if (entityId == null || entityId.isEmpty || kind != 'job') return;

    final context = key.currentContext;

    // No navigator yet. Happens on a cold start where the tap is replayed
    // before the first frame; the caller retries once the app is up.
    if (context == null) return;

    final isMechanic = context.read<AuthController>().user?.isMechanic == true;

    key.currentState?.push(
      MaterialPageRoute(
        builder: (_) => isMechanic
            ? MechanicJobDetailScreen(jobId: entityId)
            : CustomerJobDetailScreen(jobId: entityId),
      ),
    );
  }
}
