import 'package:flutter/material.dart';

import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../profile/profile_screen.dart';
import 'garage_directory_screen.dart';

/// What a customer sees before they have joined any garage.
///
/// The directory is still the point of the screen — everything else in the
/// customer app is scoped to one workshop, so there is genuinely nothing else
/// to show. What was missing was a way out of it. The directory was handed to a
/// brand-new account on its own, with no bottom bar and no back arrow, which
/// meant an account that had signed in could not sign out, change its password,
/// switch language, or reach anything at all except a list of garages. Joining
/// one was the only exit, and joining a real business is not a thing to be
/// cornered into.
///
/// So it becomes a shell with two destinations. Two, not six: the other four
/// tabs of [CustomerShell] read a workshop out of the token and would be four
/// empty states with no explanation. This is the same app with the parts that
/// cannot work yet left out, rather than a different one.
class ChooseGarageShell extends StatefulWidget {
  const ChooseGarageShell({super.key});

  @override
  State<ChooseGarageShell> createState() => _ChooseGarageShellState();
}

class _ChooseGarageShellState extends State<ChooseGarageShell> {
  int _index = 0;

  // mustChoose keeps the "choose a garage" wording and drops the back arrow —
  // correct here, because this tab is the destination rather than a page
  // something pushed.
  static const _screens = [
    GarageDirectoryScreen(mustChoose: true),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);
    final palette = AppTheme.of(context);

    return Scaffold(
      // IndexedStack, matching CustomerShell: the directory keeps its search
      // text, its scroll position and the location permission it just asked
      // for while the account tab is open.
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: palette.border)),
        ),
        child: BottomNavigationBar(
          currentIndex: _index,
          onTap: (index) => setState(() => _index = index),
          type: BottomNavigationBarType.fixed,
          items: [
            BottomNavigationBarItem(
              icon: const Icon(Icons.storefront_outlined),
              activeIcon: const Icon(Icons.storefront_rounded),
              label: t('tab.garages'),
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.person_outline_rounded),
              activeIcon: const Icon(Icons.person_rounded),
              label: t('tab.account'),
            ),
          ],
        ),
      ),
    );
  }
}
