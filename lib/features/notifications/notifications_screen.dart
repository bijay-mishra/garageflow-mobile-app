import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/formatters.dart';
import '../../core/theme.dart';
import '../../models/app_notification.dart';
import '../../state/auth_controller.dart';
import '../../state/notification_controller.dart';
import '../../widgets/states.dart';
import '../customer/customer_job_detail_screen.dart';
import '../mechanic/mechanic_job_detail_screen.dart';

/// The in-app feed, shared by both roles.
///
/// Polled while the app is open — there is no push channel, so this list is
/// the delivery mechanism. Tapping a job notification opens the right detail
/// screen for whichever role is signed in.
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<NotificationController>();
    final isMechanic = context.watch<AuthController>().user?.isMechanic == true;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (controller.hasUnread)
            TextButton(
              onPressed: controller.markAllRead,
              child: const Text('Mark all read'),
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
                children: const [
                  SizedBox(height: 90),
                  EmptyView(
                    icon: Icons.notifications_none_rounded,
                    title: 'Nothing yet',
                    message:
                        'Updates about your jobs and bookings will appear '
                        'here.',
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
                    onTap: () => _open(context, notification, isMechanic),
                    onDismiss: () => controller.remove(notification),
                  );
                },
              ),
      ),
    );
  }

  void _open(
    BuildContext context,
    AppNotification notification,
    bool isMechanic,
  ) {
    context.read<NotificationController>().markRead(notification);

    final id = notification.entityId;

    // Only job notifications have a screen to open. A booking update is fully
    // described by its own text, and the home screen already lists bookings.
    if (id == null || notification.kind != 'job') return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => isMechanic
            ? MechanicJobDetailScreen(jobId: id)
            : CustomerJobDetailScreen(jobId: id),
      ),
    );
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
    final color = switch (notification.kind) {
      'job' => AppTheme.brand,
      'booking' => AppTheme.emerald,
      'invoice' => AppTheme.violet,
      _ => AppTheme.ink500,
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
        // Unread rows carry a faint blue wash. It is the only difference
        // between read and unread, and it survives a glance better than a dot.
        color: notification.isRead ? Colors.white : AppTheme.brandLight,
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
                          color: AppTheme.ink900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        notification.body,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.ink500,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        Fmt.timeAgo(notification.createdAt),
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: AppTheme.ink400,
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
