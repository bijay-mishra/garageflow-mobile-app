import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config.dart';
import '../../core/theme.dart';
import '../../state/auth_controller.dart';
import '../../widgets/stat_tile.dart';
import '../customer/workshop_card.dart';

/// Who you are signed in as, and the way out.
///
/// Shared by both shells — the content differs only in the one row that names
/// the mechanic or the customer the account is attached to.
class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  Future<void> _confirmSignOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('You will need your password to sign back in.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.rose),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    await context.read<AuthController>().logout();
    // No navigation: AuthGate is watching, and swaps the login screen in.
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthController>().user;
    if (user == null) return const SizedBox.shrink();

    return Scaffold(
      appBar: AppBar(title: const Text('Account')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppTheme.brand,
              borderRadius: BorderRadius.circular(AppTheme.radius),
            ),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.35),
                      width: 1.5,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    user.initials,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        user.email,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 12.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          user.role.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),
          SectionCard(
            title: 'DETAILS',
            child: Column(
              children: [
                DetailRow(label: 'Workshop', value: user.workshop),
                DetailRow(label: 'Company code', value: user.companyCode),
                if (user.phone?.isNotEmpty == true)
                  DetailRow(label: 'Phone', value: user.phone!),
                if (user.isMechanic && user.mechanicName != null)
                  DetailRow(
                    label: 'Assigned as',
                    value: user.mechanicName!,
                    bold: true,
                  ),
                if (user.isCustomer && user.customerId != null)
                  DetailRow(label: 'Customer', value: user.customerId!),
              ],
            ),
          ),

          // Where the workshop is, with directions and a call button. Shown to
          // both roles: a customer wants to know which way to drive, and a
          // mechanic wants the shop's own number to hand out.
          const SizedBox(height: 16),
          const Text(
            'THE WORKSHOP',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: AppTheme.ink400,
              letterSpacing: 0.7,
            ),
          ),
          const SizedBox(height: 8),
          const WorkshopCard(),

          const SizedBox(height: 16),
          SectionCard(
            title: 'ABOUT',
            child: Column(
              children: [
                const DetailRow(label: 'App', value: 'GarageFlow 1.0.0'),
                DetailRow(label: 'Server', value: AppConfig.apiBaseUrl),
              ],
            ),
          ),

          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.brandLight,
              borderRadius: BorderRadius.circular(AppTheme.radius),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.lock_outline_rounded,
                  size: 17,
                  color: AppTheme.brand,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'To change your password or your details, ask the '
                    'workshop — accounts are managed from the dashboard.',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: AppTheme.brandDark,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 22),
          OutlinedButton.icon(
            onPressed: () => _confirmSignOut(context),
            icon: const Icon(Icons.logout_rounded, size: 19),
            label: const Text('Sign out'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.rose,
              side: BorderSide(color: AppTheme.rose.withValues(alpha: 0.4)),
            ),
          ),
        ],
      ),
    );
  }
}
