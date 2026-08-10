import 'package:flutter/material.dart';

import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../plans/explore_plans_sheet.dart';
import '../profile/profile_screen.dart';
import 'bills_screen.dart';
import 'customer_home_screen.dart';
import 'garage_directory_screen.dart';
import 'service_history_screen.dart';

/// The customer's app: what is happening now, what has happened before, the
/// bills, the garages and their account.
///
/// Alerts are not a destination here. The feed lives behind the bell in each
/// screen's header — see [AlertsAction] — which took the bar from six slots to
/// five and gave the labels room to be read.
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
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // After the first frame: the shell is what somebody sees when they sign in,
    // and a sheet raised during its build would have nothing behind it.
    WidgetsBinding.instance.addPostFrameCallback((_) => _offerPlans());
  }

  /// Shows the plans pitch on the way in.
  ///
  /// Every time the app opens, not once per install. It used to keep a "seen"
  /// flag; that was the wrong call to make on the seller's behalf, and in
  /// practice meant almost nobody ever saw it. The dialog itself is what makes
  /// this bearable — it closes on the X, on Not now, on a tap outside and on
  /// the back gesture, so it costs one tap to dismiss.
  ///
  /// Not on every rebuild: this runs from `initState`, so it fires when the
  /// shell is created — a cold start or a sign-in — and not when somebody
  /// switches tabs or comes back from the background.
  Future<void> _offerPlans() async {
    if (!mounted) return;
    await showExplorePlansDialog(context);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);

    final palette = AppTheme.of(context);

    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: palette.border)),
        ),
        // Five labels divide a phone into ~72pt slots, and the app's own text
        // size setting is applied at the root as a hard scale — so at Large
        // the labels grew past their slot and the outer two were clipped by
        // the screen edge. Capped here rather than at the root because this
        // is the one place in the app where the width is fixed by the number
        // of destinations: everything else can reflow or scroll, a tab bar
        // cannot. Only the ceiling is lowered, so Small still shrinks.
        child: MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.2,
          child: BottomNavigationBar(
            currentIndex: _index,
            onTap: (index) => setState(() => _index = index),
            // Fixed, and explicitly so: with more than three destinations the
            // default is `shifting`, which hides the label of every tab except
            // the selected one. Six unlabelled icons is a guessing game.
            type: BottomNavigationBarType.fixed,
            // Small rather than truncated — "Garages" clipped to "Gara…" helps
            // nobody. With the alerts tab gone there is room for 11.5.
            selectedFontSize: 11.5,
            unselectedFontSize: 11.5,
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
