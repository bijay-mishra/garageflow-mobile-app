import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/i18n.dart';
import '../features/notifications/notifications_screen.dart';
import '../state/notification_controller.dart';
import 'gradient_header.dart';

/// The bell, in the top right of a screen's header.
///
/// Alerts used to be a destination in the bottom bar. That put a badge that is
/// almost always at zero in the same row as the four things people actually
/// navigate between, and it cost a sixth of the bar — which on a phone is what
/// made the labels shrink to 11pt and still need clamped text scaling.
///
/// A bell in the header is where a phone user already looks for one, and it is
/// reachable from every root screen rather than only from wherever the tab
/// happened to sit. Tapping pushes the feed, so going back returns to what you
/// were reading instead of switching tabs under you.
///
/// Watches the controller directly rather than taking a count, so a screen only
/// has to place it — and only the bell rebuilds when the poll lands, not the
/// whole page behind it.
class AlertsAction extends StatelessWidget {
  const AlertsAction({super.key});

  @override
  Widget build(BuildContext context) {
    final unread = context.watch<NotificationController>().unreadCount;

    return HeaderAction(
      icon: unread > 0
          ? Icons.notifications_rounded
          : Icons.notifications_none_rounded,
      badge: unread,
      tooltip: AppText.of(context)('tab.alerts'),
      onPressed: () => Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const NotificationsScreen())),
    );
  }
}
