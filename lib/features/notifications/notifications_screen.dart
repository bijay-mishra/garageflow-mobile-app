import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/formatters.dart';
import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../models/app_notification.dart';
import '../../core/app_navigator.dart';
import '../../state/notification_controller.dart';
import '../../widgets/gradient_header.dart';
import '../../widgets/states.dart';

/// The in-app feed, shared by both roles.
///
/// Polled while the app is open — there is no push channel, so this list is
/// the delivery mechanism. Tapping a job notification opens the right detail
/// screen for whichever role is signed in.
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);

    final controller = context.watch<NotificationController>();

    return Scaffold(
      appBar: GradientAppBar(
        title: t('alerts.title'),
        actions: [
          if (controller.hasUnread)
            TextButton(
              onPressed: controller.markAllRead,
              // The theme paints text buttons brand blue, which is the same
              // blue as the gradient behind this one. Overridden rather than
              // left to inherit.
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              child: Text(t('alerts.markAllRead')),
            ),
          const SizedBox(width: 6),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: controller.refresh,
        child: controller.loading && controller.items.isEmpty
            ? const LoadingView()
            : controller.error != null && controller.items.isEmpty
            ? ErrorView(
                message: controller.error!,
                onRetry: controller.refresh,
              )
            : controller.items.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(height: 90),
                  EmptyView(
                    icon: Icons.notifications_none_rounded,
                    title: t('alerts.emptyTitle'),
                    message:
                        t('alerts.emptyMessage'),
                  ),
                ],
              )
            : ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(vertical: 6),
                itemCount: controller.items.length,
                separatorBuilder: (_, _) =>
                    const Divider(indent: 66, height: 1),
                itemBuilder: (context, index) {
                  final notification = controller.items[index];

                  return _NotificationTile(
                    notification: notification,
                    onTap: () => _open(context, notification),
                    onDismiss: () => controller.remove(notification),
                  );
                },
              ),
      ),
    );
  }

  void _open(BuildContext context, AppNotification notification) {
    context.read<NotificationController>().markRead(notification);

    // Which kinds have a screen, and which screen, is AppNavigator's decision
    // — the same one a push tap goes through. It lived here alone until push
    // existed, which would have meant a tapped push opening nothing.
    AppNavigator.openNotification(notification.entityId, notification.kind);
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.notification,
    required this.onTap,
    required this.onDismiss,
  });

  final AppNotification notification;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final palette = AppTheme.of(context);

    final color = switch (notification.kind) {
      'job' => AppTheme.brand,
      'booking' => AppTheme.emerald,
      'invoice' => AppTheme.violet,
      _ => palette.faint,
    };

    return Dismissible(
      key: ValueKey(notification.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDismiss(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 22),
        color: AppTheme.rose,
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
      ),
      child: Material(
        // Unread rows carry a faint brand wash. It is the only difference
        // between read and unread, and it survives a glance better than a dot.
        // Both sides come from the palette: hardcoded here, the read rows
        // stayed white and the unread ones stayed pale blue in dark mode, which
        // is the whole list drawn in the wrong theme.
        color: notification.isRead ? palette.card : palette.accentWash,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    AppTheme.notificationIcon(notification.kind),
                    size: 18,
                    color: color,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        notification.title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: notification.isRead
                              ? FontWeight.w600
                              : FontWeight.w800,
                          color: palette.text,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        notification.body,
                        style: TextStyle(
                          fontSize: 13,
                          color: palette.faint,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        Fmt.timeAgo(notification.createdAt),
                        style: TextStyle(
                          fontSize: 11.5,
                          color: palette.faint,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!notification.isRead)
                  Container(
                    margin: const EdgeInsets.only(top: 6, left: 8),
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppTheme.brand,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
