import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_exception.dart';
import '../../core/formatters.dart';
import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../models/loyalty.dart';
import '../../services/loyalty_service.dart';
import '../../services/notification_service.dart';
import '../../state/auth_controller.dart';
import '../../state/settings_controller.dart';
import '../../widgets/alerts_action.dart';
import '../../widgets/gradient_header.dart';
import '../../widgets/profile_avatar.dart';
import '../../widgets/states.dart';
import '../customer/garage_directory_screen.dart';
import '../customer/rewards_screen.dart';
import '../plans/plans_screen.dart';
import 'account_screen.dart';
import 'appearance_screen.dart';
import 'delete_account_screen.dart';
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
            // Customers only: the mechanic shell still keeps alerts as a tab of
            // its own, and two bells on one screen is one too many.
            actions: [if (user.isCustomer) const AlertsAction()],
            floating: AppCard(
              lifted: true,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  _RoleBadge(user.role),
                  const Spacer(),
                  // Points sit here, at the top of the account, because they are
                  // the one number on this screen that changes on its own and
                  // the one somebody opens the screen to look at.
                  if (user.isCustomer) const _PointsBadge(),
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
                    const _NotificationsRow(),

                    // Mechanics only. The customer half of ratings is the
                    // rewards/rating card in their own app; this is the other
                    // end of it — what the people whose cars you fixed thought.
                    if (user.isMechanic) const _MyRatingRow(),
                    // Customers only: a mechanic's workshop is the one that
                    // issued their login, so there is nothing to switch.
                    if (user.isCustomer)
                      _Row(
                        icon: Icons.storefront_outlined,
                        title: t('home.yourGarages'),
                        subtitle: user.workshop.isEmpty
                            ? t('garages.noneJoined')
                            : user.workshop,
                        onTap: () =>
                            _open(context, const GarageDirectoryScreen()),
                      ),

                    // Customers only: a mechanic has no card to fill. Shown
                    // unconditionally rather than gated on the garage running
                    // a scheme, because finding out is a request and a settings
                    // list that loads before it can be drawn is worse than a
                    // row that opens on an honest empty state.
                    if (user.isCustomer) const _RewardsRow(),

                    // Customers only. The pitch on the way in is a dialog
                    // somebody will close without reading nine times out of
                    // ten; this is where they find the plans on the one
                    // occasion they go looking.
                    if (user.isCustomer)
                      _Row(
                        icon: Icons.workspace_premium_outlined,
                        title: t('plans.title'),
                        subtitle: t('plans.rowSub'),
                        onTap: () => _open(context, const PlansScreen()),
                      ),

                    // Customers only, and for the opposite reason to the row
                    // above: a mechanic's login belongs to the workshop that
                    // issued it and is the workshop's to close, on the
                    // dashboard. A customer's account is nobody else's, so
                    // nobody else gets to end it — and Google requires an app
                    // with sign-up to offer this. The endpoint enforces the
                    // same rule; hiding the row is only the polite half.
                    if (user.isCustomer)
                      _Row(
                        icon: Icons.no_accounts_outlined,
                        title: t('deleteAccount.title'),
                        subtitle: t('deleteAccount.rowSub'),
                        tone: AppTheme.rose,
                        onTap: () =>
                            _open(context, const DeleteAccountScreen()),
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
                      trailing: _Pill(switch (settings.themeMode) {
                        ThemeMode.light => t('appearance.light'),
                        ThemeMode.dark => t('appearance.dark'),
                        ThemeMode.system => t('appearance.system'),
                      }),
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
            Divider(height: 1, indent: 56, color: AppTheme.of(context).border),
          children[i],
        ],
      ],
    ),
  );
}

/// The notifications switch.
///
/// Its own stateful widget rather than lifting state into [ProfileScreen],
/// which is stateless and shared by both shells — one row that needs to load
/// and save a value is not a reason to make the whole screen stateful.
///
/// The preference lives on the server, so the switch is read on open rather
/// than assumed. It flips optimistically and rolls back if the save fails: a
/// switch that visibly does nothing for a second reads as broken, and one that
/// silently lies about being off is worse.
class _NotificationsRow extends StatefulWidget {
  const _NotificationsRow();

  @override
  State<_NotificationsRow> createState() => _NotificationsRowState();
}

class _NotificationsRowState extends State<_NotificationsRow> {
  bool? _enabled;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final enabled = await context
          .read<NotificationApi>()
          .notificationsEnabled();
      if (mounted) setState(() => _enabled = enabled);
    } on ApiException {
      // A row that cannot read its own value shows the default rather than an
      // error: this is a settings list, not a screen whose job is this switch.
      if (mounted) setState(() => _enabled = true);
    }
  }

  Future<void> _toggle(bool next) async {
    if (_busy) return;

    final previous = _enabled;

    setState(() {
      _enabled = next;
      _busy = true;
    });

    try {
      final saved = await context
          .read<NotificationApi>()
          .setNotificationsEnabled(next);
      if (mounted) {
        setState(() {
          _enabled = saved;
          _busy = false;
        });
      }
    } on ApiException catch (error) {
      if (!mounted) return;

      setState(() {
        _enabled = previous;
        _busy = false;
      });
      showSnack(context, error.message, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);
    final enabled = _enabled ?? true;

    return _Row(
      icon: enabled
          ? Icons.notifications_active_outlined
          : Icons.notifications_off_outlined,
      title: t('profile.notifications'),
      subtitle: enabled
          ? t('profile.notificationsOn')
          : t('profile.notificationsOff'),
      trailing: Switch(
        value: enabled,
        onChanged: _enabled == null || _busy ? null : _toggle,
      ),
      // Tapping the row does what tapping the switch does — a settings row with
      // a switch on it that only responds at the switch is a small daily
      // annoyance.
      onTap: _enabled == null || _busy ? () {} : () => _toggle(!enabled),
    );
  }
}

/// The signed-in mechanic's own star average.
///
/// Its own stateful widget for the same reason the notifications switch is:
/// [ProfileScreen] is stateless and shared by both shells, and one row that has
/// to fetch a number is not a reason to make the whole screen stateful.
///
/// Shows nothing but a dash until somebody has actually rated them. A brand-new
/// mechanic displaying 0.0 stars would read as the worst in the shop rather
/// than as the absence of data.
/// The garage points balance, on the card at the top of the account.
///
/// Its own widget, loading its own number, rather than state lifted into
/// [ProfileScreen] — which is stateless and shared by both shells, and would
/// have to load a customer-only figure for a mechanic to find out it does not
/// need it. The cost is a second call to the same endpoint as [_RewardsRow]:
/// two small reads on a screen somebody opened deliberately, against making the
/// whole profile stateful and refetching on every rebuild of either shell.
///
/// Draws nothing at all until the number is known, and nothing ever at a garage
/// that runs no points scheme. A "0 pts" chip that turns out to mean "this
/// garage does not do points" is worse than no chip.
class _PointsBadge extends StatefulWidget {
  const _PointsBadge();

  @override
  State<_PointsBadge> createState() => _PointsBadgeState();
}

class _PointsBadgeState extends State<_PointsBadge> {
  LoyaltyCard? _card;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final card = await context.read<LoyaltyService>().card();
      if (mounted) setState(() => _card = card);
    } on ApiException {
      if (mounted) setState(() => _card = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);
    final card = _card;

    if (card == null || !card.pointsRun) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          gradient: AppTheme.tintGradient(AppTheme.brand),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.stars_rounded, size: 14, color: AppTheme.brand),
            const SizedBox(width: 5),
            Text(
              t('rewards.pillPoints', [Fmt.number(card.pointsBalance)]),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: AppTheme.brand,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The rewards row, with the customer's own balance on it.
///
/// The balance is the whole reason the row is interesting. Without it this said
/// "Rewards — points and offers", which is a description of a feature rather
/// than an answer to "how many points do I have" — and made everyone open the
/// screen to find out a number that fits in eleven characters.
///
/// Points win the pill when both schemes run: a stamp count is only meaningful
/// beside the reward it is working towards, and that will not fit here.
class _RewardsRow extends StatefulWidget {
  const _RewardsRow();

  @override
  State<_RewardsRow> createState() => _RewardsRowState();
}

class _RewardsRowState extends State<_RewardsRow> {
  LoyaltyCard? _card;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final card = await context.read<LoyaltyService>().card();
      if (mounted) setState(() => _card = card);
    } on ApiException {
      // No pill, and the row still opens. A settings list whose job is five
      // other things should not show an error because one number is missing.
      if (mounted) setState(() => _card = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);
    final card = _card;

    return _Row(
      icon: Icons.card_giftcard_outlined,
      title: t('rewards.title'),
      subtitle: switch (card) {
        // Still loading, or the garage runs nothing. Both get the plain
        // description rather than a number that might be about to change.
        null => t('rewards.rowSub'),
        final c when !c.runs => t('rewards.rowSub'),
        final c when c.rewardsAvailable > 0 => t('rewards.rowFree', [
          c.rewardsAvailable,
        ]),
        final c when c.pointsRun => t('rewards.rowWorth', [
          Fmt.rs(c.pointsValue),
        ]),
        final c => t('rewards.rowToGo', [c.stampsToGo]),
      },
      trailing: switch (card) {
        null => null,
        final c when c.pointsRun => _Pill(
          t('rewards.pillPoints', [Fmt.number(c.pointsBalance)]),
          tone: AppTheme.brand,
        ),
        final c when c.stampCardRuns => _Pill(
          '${c.stampsOnCard}/${c.jobsPerReward}',
          tone: AppTheme.emerald,
        ),
        _ => null,
      },
      // Reloaded on the way back: points may have been spent in there.
      onTap: () async {
        await Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const RewardsScreen()));
        if (mounted) await _load();
      },
    );
  }
}

class _MyRatingRow extends StatefulWidget {
  const _MyRatingRow();

  @override
  State<_MyRatingRow> createState() => _MyRatingRowState();
}

class _MyRatingRowState extends State<_MyRatingRow> {
  MechanicRating? _rating;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rating = await context.read<LoyaltyService>().myRating();
      if (mounted) setState(() => _rating = rating);
    } on ApiException {
      // A row that cannot read its own number shows the unrated state. This is
      // a settings list, not a screen whose job is this one figure.
      if (mounted) setState(() => _rating = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);
    final rating = _rating;
    final scored = rating?.average != null;

    return _Row(
      icon: Icons.star_outline_rounded,
      title: t('rate.myRating'),
      subtitle: scored
          ? t('rate.fromCount', [rating!.ratingCount])
          : t('rate.notRatedYet'),
      trailing: scored
          ? _Pill(rating!.average!.toStringAsFixed(1), tone: AppTheme.amber)
          : null,
      // Nothing to open: there is no per-mechanic screen, and a row that
      // navigates nowhere is worse than one that plainly does not.
      onTap: () {},
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.trailing,
    this.tone,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback onTap;

  /// Colours the icon tile away from the brand. One row uses it — deleting the
  /// account — and the point is that it does not look like the settings rows it
  /// sits among.
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final palette = AppTheme.of(context);
    final accent = tone ?? AppTheme.brand;

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
                color: accent.withValues(alpha: 0.11),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, size: 18, color: accent),
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
            Icon(Icons.chevron_right_rounded, size: 20, color: palette.faint),
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
void showLocalisedSnack(
  BuildContext context,
  String key, {
  bool isError = false,
}) {
  showSnack(context, AppText.of(context)(key), isError: isError);
}
