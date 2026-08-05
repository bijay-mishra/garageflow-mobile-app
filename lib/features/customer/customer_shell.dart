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
import 'garage_directory_screen.dart';
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
    // Every garage on the platform, not just the ones this customer has
    // joined. It was reachable only from inside the account screen, which
    // made finding a new garage something you had to already know how to do.
    GarageDirectoryScreen(),
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
        // Six labels divide a phone into ~60pt slots, and the app's own text
        // size setting is applied at the root as a hard scale — so at Large
        // the labels grew past their slot and the outer two were clipped by
        // the screen edge. Capped here rather than at the root because this
        // is the one place in the app where the width is fixed by the number
        // of destinations: everything else can reflow or scroll, a tab bar
        // cannot. Only the ceiling is lowered, so Small still shrinks.
        child: MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.1,
          child: BottomNavigationBar(
            currentIndex: _index,
            onTap: (index) => setState(() => _index = index),
            // Fixed, and explicitly so: with more than three destinations the
            // default is `shifting`, which hides the label of every tab except
            // the selected one. Six unlabelled icons is a guessing game.
            type: BottomNavigationBarType.fixed,
            // Six labels on a phone are tight. Smaller rather than truncated —
            // "Garages" clipped to "Gara…" helps nobody.
            selectedFontSize: 11,
            unselectedFontSize: 11,
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
                icon: Icon(Icons.storefront_outlined),
                activeIcon: Icon(Icons.storefront_rounded),
                label: t('tab.garages'),
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
      ),
    );
  }
}
