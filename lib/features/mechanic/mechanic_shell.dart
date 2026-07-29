import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../state/notification_controller.dart';
import '../notifications/notifications_screen.dart';
import '../shared/account_screen.dart';
import 'mechanic_jobs_screen.dart';

/// The mechanic's app: their jobs, the feed, and their account.
///
/// Three tabs is the whole surface. A mechanic on the shop floor is holding a
/// phone in one hand, and every extra destination is one more thing to get
/// lost in.
class MechanicShell extends StatefulWidget {
  const MechanicShell({super.key});

  @override
  State<MechanicShell> createState() => _MechanicShellState();
}

class _MechanicShellState extends State<MechanicShell> {
  int _index = 0;

  static const _screens = [
    MechanicJobsScreen(),
    NotificationsScreen(),
    AccountScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final unread = context.watch<NotificationController>().unreadCount;

    return Scaffold(
      // IndexedStack, not a swap: switching tabs keeps each screen's scroll
      // position and loaded data, so a mechanic flicking to the feed and back
      // does not re-fetch their job list.
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppTheme.ink200)),
        ),
        child: BottomNavigationBar(
          currentIndex: _index,
          onTap: (index) => setState(() => _index = index),
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.build_outlined),
              activeIcon: Icon(Icons.build_rounded),
              label: 'My jobs',
            ),
            BottomNavigationBarItem(
              icon: NotificationBadge(
                count: unread,
                child: const Icon(Icons.notifications_outlined),
              ),
              activeIcon: NotificationBadge(
                count: unread,
                child: const Icon(Icons.notifications_rounded),
              ),
              label: 'Alerts',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.person_outline_rounded),
              activeIcon: Icon(Icons.person_rounded),
              label: 'Account',
            ),
          ],
        ),
      ),
    );
  }
}

/// The red dot over the bell. Caps at 9+ so a long-ignored feed cannot widen
/// the tab and shove the labels around.
class NotificationBadge extends StatelessWidget {
  const NotificationBadge({super.key, required this.count, required this.child});

  final int count;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (count == 0) return child;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          top: -3,
          right: -6,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4.5, vertical: 1.5),
            constraints: const BoxConstraints(minWidth: 17),
            decoration: BoxDecoration(
              color: AppTheme.rose,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white, width: 1.5),
            ),
            child: Text(
              count > 9 ? '9+' : '$count',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                height: 1.1,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
