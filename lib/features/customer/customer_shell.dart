import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../state/notification_controller.dart';
import '../mechanic/mechanic_shell.dart' show NotificationBadge;
import '../notifications/notifications_screen.dart';
import '../shared/account_screen.dart';
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
    AccountScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final unread = context.watch<NotificationController>().unreadCount;

    return Scaffold(
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
              icon: Icon(Icons.directions_car_outlined),
              activeIcon: Icon(Icons.directions_car_rounded),
              label: 'My vehicles',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.history_rounded),
              activeIcon: Icon(Icons.history_rounded),
              label: 'History',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.receipt_long_outlined),
              activeIcon: Icon(Icons.receipt_long_rounded),
              label: 'Bills',
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
