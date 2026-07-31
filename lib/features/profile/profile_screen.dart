import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../state/auth_controller.dart';
import '../../state/settings_controller.dart';
import '../../widgets/gradient_header.dart';
import '../../widgets/profile_avatar.dart';
import '../../widgets/states.dart';
import '../customer/garage_directory_screen.dart';
import 'account_screen.dart';
import 'appearance_screen.dart';
import 'feedback_screen.dart';
import 'language_screen.dart';
import 'security_screen.dart';
import 'workshop_screen.dart';

/// The profile hub — one list of everything about *you* rather than the app.
///
/// Replaces the old Account tab, which was a single scroll containing the
/// signed-in name, the workshop's address, the app version and a sign-out
/// button. That worked while there were four things to show; with account
/// details, security, appearance, language, feedback and the workshop it would
/// be a screen nobody reaches the bottom of. Each row now owns its own page.
///
/// Shared by both shells. A mechanic and a customer want the same things here —
/// their name, their photo, a readable text size, their language — and the two
/// rows that differ are marked.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final user = auth.user;
    final settings = context.watch<SettingsController>();
    final t = AppText.of(context);
    final palette = AppTheme.of(context);

    if (user == null) return const SizedBox.shrink();

    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          GradientHeader(
            title: user.name,
            subtitle: user.email,
            leading: const ProfilePhotoButton(),
            floating: AppCard(
              lifted: true,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  _RoleBadge(user.role),
                  const Spacer(),
                  if (user.isCustomer && user.customerId != null)
                    Text(
                      user.customerId!,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: palette.faint,
                        fontFamily: 'monospace',
                      ),
                    )
                  else if (user.isMechanic && user.mechanicName != null)
                    Text(
                      user.mechanicName!,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: palette.faint,
                      ),
                    ),
                ],
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SectionLabel(t('profile.account')),
                _Group(
                  children: [
                    _Row(
                      icon: Icons.person_outline_rounded,
                      title: t('profile.account'),
                      subtitle: t('profile.accountSub'),
                      onTap: () => _open(context, const AccountEditScreen()),
                    ),
                    _Row(
                      icon: Icons.lock_outline_rounded,
                      title: t('profile.security'),
                      subtitle: t('profile.securitySub'),
                      trailing: settings.biometricLock
                          ? _Pill(t('common.on'), tone: AppTheme.emerald)
                          : null,
                      onTap: () => _open(context, const SecurityScreen()),
                    ),
                    // Customers only: a mechanic's workshop is the one that
                    // issued their login, so there is nothing to switch.
                    if (user.isCustomer)
                      _Row(
                        icon: Icons.storefront_outlined,
                        title: t('home.yourGarages'),
                        subtitle: user.workshop,
                        onTap: () =>
                            _open(context, const GarageDirectoryScreen()),
                      ),
                  ],
                ),

                const SizedBox(height: 20),
                SectionLabel(t('profile.settings')),
                _Group(
                  children: [
                    _Row(
                      icon: Icons.palette_outlined,
                      title: t('profile.appearance'),
                      subtitle: t('profile.appearanceSub'),
                      trailing: _Pill(
                        switch (settings.themeMode) {
                          ThemeMode.light => t('appearance.light'),
                          ThemeMode.dark => t('appearance.dark'),
                          ThemeMode.system => t('appearance.system'),
                        },
                      ),
                      onTap: () => _open(context, const AppearanceScreen()),
                    ),
                    _Row(
                      icon: Icons.translate_rounded,
                      title: t('profile.language'),
                      subtitle: t('language.title'),
                      trailing: _Pill(
                        AppText.languages
                            .firstWhere((l) => l.code == settings.languageCode)
                            .native,
                      ),
                      onTap: () => _open(context, const LanguageScreen()),
                    ),
                  ],
                ),

                const SizedBox(height: 20),
                SectionLabel(t('profile.about')),
                _Group(
                  children: [
                    _Row(
                      icon: Icons.storefront_rounded,
                      title: t('profile.workshop'),
                      subtitle: t('profile.helpSub'),
                      onTap: () => _open(context, const WorkshopScreen()),
                    ),
                    _Row(
                      icon: Icons.lightbulb_outline_rounded,
                      title: t('profile.featureRequest'),
                      subtitle: t('profile.featureRequestSub'),
                      onTap: () => _open(context, const FeedbackScreen()),
                    ),
                  ],
                ),

                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: () => _confirmSignOut(context),
                  icon: const Icon(Icons.logout_rounded, size: 19),
                  label: Text(t('auth.signOut')),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.rose,
                    side: BorderSide(
                      color: AppTheme.rose.withValues(alpha: 0.4),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _open(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final t = AppText.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('${t('auth.signOut')}?'),
        content: Text(t('auth.signOutConfirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(t('common.cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.rose),
            child: Text(t('auth.signOut')),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    await context.read<AuthController>().logout();
    // No navigation: AuthGate is watching, and swaps the login screen in.
  }
}

/// A card holding a run of rows, divided rather than spaced — a settings list
/// reads as one surface, not as five floating cards.
class _Group extends StatelessWidget {
  const _Group({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => AppCard(
    padding: EdgeInsets.zero,
    child: Column(
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0)
            Divider(
              height: 1,
              indent: 56,
              color: AppTheme.of(context).border,
            ),
          children[i],
        ],
      ],
    ),
  );
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = AppTheme.of(context);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppTheme.brand.withValues(alpha: 0.11),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, size: 18, color: AppTheme.brand),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: palette.text,
                    ),
                  ),
                  if (subtitle != null && subtitle!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: palette.faint),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[trailing!, const SizedBox(width: 6)],
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: palette.faint,
            ),
          ],
        ),
      ),
    );
  }
}

/// The current value of a setting, shown on its row so the list answers
/// "what is my text size" without being opened.
class _Pill extends StatelessWidget {
  const _Pill(this.text, {this.tone});

  final String text;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final palette = AppTheme.of(context);
    final color = tone ?? palette.faint;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: tone ?? palette.muted,
        ),
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge(this.role);

  final String role;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: AppTheme.brand.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      role.toUpperCase(),
      style: const TextStyle(
        color: AppTheme.brand,
        fontSize: 10.5,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.8,
      ),
    ),
  );
}

/// Shows a message using the active language.
void showLocalisedSnack(BuildContext context, String key, {bool isError = false}) {
  showSnack(context, AppText.of(context)(key), isError: isError);
}
