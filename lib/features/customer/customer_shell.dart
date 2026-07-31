import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../state/notification_controller.dart';
import '../mechanic/mechanic_shell.dart' show NotificationBadge;
import '../notifications/notifications_screen.dart';
import '../profile/profile_screen.dart';
import 'bills_screen.dart';
import 'customer_home_screen.dart';
import 'service_history_screen.dart';

/// The customer's app: what is happening now, what has happened before, the
/// feed, and their account.
class CustomerShell extends StatefulWidget {
  const CustomerShell({super.key});

  @override
  State<CustomerShell> createState() => _CustomerShellState();
}

class _CustomerShellState extends State<CustomerShell> {
  int _index = 0;

  static const _screens = [
    CustomerHomeScreen(),
    ServiceHistoryScreen(),
    BillsScreen(),
    NotificationsScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);

    final palette = AppTheme.of(context);

    final unread = context.watch<NotificationController>().unreadCount;

    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: palette.border)),
        ),
        child: BottomNavigationBar(
          currentIndex: _index,
          onTap: (index) => setState(() => _index = index),
          items: [
            BottomNavigationBarItem(
              icon: Icon(Icons.directions_car_outlined),
              activeIcon: Icon(Icons.directions_car_rounded),
              label: t('tab.myVehicles'),
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.history_rounded),
              activeIcon: Icon(Icons.history_rounded),
              label: t('tab.history'),
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.receipt_long_outlined),
              activeIcon: Icon(Icons.receipt_long_rounded),
              label: t('tab.bills'),
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
              label: t('tab.alerts'),
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline_rounded),
              activeIcon: Icon(Icons.person_rounded),
              label: t('tab.account'),
            ),
          ],
        ),
      ),
    );
  }
}
