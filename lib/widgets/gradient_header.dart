import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme.dart';

/// The deep blue band at the top of every screen.
///
/// Replaces the white `AppBar` the app used everywhere. The reason is hierarchy:
/// with a white bar over a near-white background, a screen had no anchor — the
/// title, the tiles and the list all sat at the same visual depth and the eye
/// had nowhere to land. A saturated band gives the top of the screen weight, and
/// everything below it reads as content by contrast.
///
/// Scrolls away with the content rather than staying pinned. A phone screen is
/// mostly vertical space and a permanent 140pt header would spend a third of it
/// on a greeting nobody needs to read twice.
class GradientHeader extends StatelessWidget {
  const GradientHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.actions = const [],
    this.floating,
    this.onBack,
    this.padBottom = 26,
  });

  final String title;
  final String? subtitle;

  /// Drawn to the left of the title — an avatar, or a garage's initial.
  final Widget? leading;

  /// Icon buttons on the right. Tinted for the gradient by [_HeaderAction], so
  /// pass plain [IconData] through that rather than raw [IconButton]s.
  final List<Widget> actions;

  /// A card that hangs off the bottom edge, half on the gradient and half on
  /// the page. This is what makes the header feel like a layer rather than a
  /// stripe, and it is where the numbers go.
  final Widget? floating;

  /// Shows a back chevron. Null on a shell's root screen.
  final VoidCallback? onBack;

  final double padBottom;

  /// How far [floating] hangs below the gradient.
  static const _overhang = 34.0;

  @override
  Widget build(BuildContext context) {
    final band = Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: AppTheme.headerGradient,
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(AppTheme.radiusHeader),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            onBack != null ? 6 : 18,
            // 18, not 10. SafeArea already clears the status bar, but clearing
            // it and sitting *on* it are different things — at 10 the greeting
            // started immediately under the clock and the whole band read as
            // cramped. This is the gap that makes the header feel like a header.
            18,
            10,
            // Room for the floating card to sit on colour rather than straddling
            // the rounded corner.
            floating != null ? padBottom + 18 : padBottom,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (onBack != null)
                _HeaderIcon(
                  icon: Icons.arrow_back_rounded,
                  onPressed: onBack!,
                  tooltip: 'Back',
                ),
              if (leading != null) ...[
                leading!,
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.onHeader,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        height: 1.15,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppTheme.onHeaderMuted,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              ...actions,
            ],
          ),
        ),
      ),
    );

    // A light status bar is only correct while the gradient is under it. Set
    // here rather than in the theme because a screen with no header — the login
    // form on white — needs the opposite.
    final styled = AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: band,
    );

    if (floating == null) return styled;

    return Column(
      children: [
        // clipBehavior none, so the negatively-positioned card is drawn rather
        // than cut off at the gradient's edge.
        Stack(
          clipBehavior: Clip.none,
          children: [
            styled,
            Positioned(
              left: 16,
              right: 16,
              bottom: -_overhang,
              child: floating!,
            ),
          ],
        ),
        // Reclaims the space the overhang is drawn into. Without this the first
        // real content block would sit underneath the floating card.
        const SizedBox(height: _overhang + 14),
      ],
    );
  }
}

/// The gradient as a conventional app bar, for pushed screens.
///
/// [GradientHeader] scrolls away with its content, which is right for a shell's
/// root screen but wrong for a detail page: those need a back button that stays
/// put. This keeps the same band and the same colour, in an `AppBar` that behaves
/// like one — so a detail screen still looks like the screen it came from.
class GradientAppBar extends StatelessWidget implements PreferredSizeWidget {
  const GradientAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
    this.bottom,
  });

  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final PreferredSizeWidget? bottom;

  @override
  Size get preferredSize => Size.fromHeight(
    kToolbarHeight +
        (subtitle == null ? 0 : 12) +
        (bottom?.preferredSize.height ?? 0),
  );

  @override
  Widget build(BuildContext context) => AppBar(
    // Transparent, with the gradient supplied by flexibleSpace — an AppBar's
    // own `backgroundColor` takes a single colour and cannot hold one.
    backgroundColor: Colors.transparent,
    foregroundColor: Colors.white,
    elevation: 0,
    scrolledUnderElevation: 0,
    systemOverlayStyle: SystemUiOverlayStyle.light,
    toolbarHeight: kToolbarHeight + (subtitle == null ? 0 : 12),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        bottom: Radius.circular(AppTheme.radiusHeader),
      ),
    ),
    flexibleSpace: Container(
      decoration: const BoxDecoration(
        gradient: AppTheme.headerGradient,
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(AppTheme.radiusHeader),
        ),
      ),
    ),
    title: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 19,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.35,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(
            subtitle!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.72),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    ),
    actions: actions,
    bottom: bottom,
  );
}

/// A round translucent button for the gradient. A plain white icon on this
/// background is hard to hit and harder to see; the disc gives it a target.
class _HeaderIcon extends StatelessWidget {
  const _HeaderIcon({
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.badge = 0,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final int badge;

  @override
  Widget build(BuildContext context) {
    final button = IconButton(
      onPressed: onPressed,
      icon: Icon(icon, size: 21),
      tooltip: tooltip,
      style: IconButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: Colors.white.withValues(alpha: 0.14),
        disabledForegroundColor: Colors.white.withValues(alpha: 0.4),
        minimumSize: const Size(40, 40),
        padding: EdgeInsets.zero,
      ),
    );

    if (badge == 0) return button;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        button,
        Positioned(
          top: 2,
          right: 2,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            constraints: const BoxConstraints(minWidth: 16),
            decoration: BoxDecoration(
              color: AppTheme.rose,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white, width: 1.2),
            ),
            child: Text(
              badge > 9 ? '9+' : '$badge',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.w800,
                height: 1.2,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Public alias — screens build their header actions with this.
class HeaderAction extends StatelessWidget {
  const HeaderAction({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.badge = 0,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final int badge;

  @override
  Widget build(BuildContext context) => _HeaderIcon(
    icon: icon,
    onPressed: onPressed,
    tooltip: tooltip,
    badge: badge,
  );
}

/// The circle with someone's initials, for the header's leading slot.
class HeaderAvatar extends StatelessWidget {
  const HeaderAvatar({super.key, required this.initials, this.size = 42});

  final String initials;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: AppTheme.avatarOnHeader,
      shape: BoxShape.circle,
      border: Border.all(color: AppTheme.avatarOnHeaderBorder, width: 1.4),
    ),
    child: Text(
      initials,
      style: TextStyle(
        color: Colors.white,
        fontSize: size * 0.36,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.2,
      ),
    ),
  );
}

/// The app's card. One shape, one shadow, no outline.
///
/// Everything that used to be a `Container` with a grey border is this instead,
/// so a screen is a set of surfaces at a consistent height above the page
/// rather than a grid of boxes.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
    this.lifted = false,
    this.accent,
    this.gradient,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;

  /// Uses the taller shadow. For the one card on a screen that leads.
  final bool lifted;

  /// Draws a 3pt bar down the left edge in this colour — a status, carried
  /// without spending a row on it.
  final Color? accent;

  final Gradient? gradient;

  /// Width of the status bar down the left edge.
  static const _accentWidth = 4.0;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppTheme.radius);
    final palette = AppTheme.of(context);

    // The accent bar is drawn as an overlay rather than as a flex child.
    //
    // It used to be a `Row(crossAxisAlignment: stretch)` with a fixed-width
    // Container beside the content. That is broken: `stretch` on a Row stretches
    // along the *cross* axis, which is vertical, and inside a ListView the
    // height is unbounded — so the Row demanded infinite height and the card
    // failed to lay out. Every accented card rendered as a blank space.
    //
    // A Stack sizes itself to the content and the Positioned bar takes the
    // height that resolves to, so nothing is ever asked for an infinite bound.
    // It also avoids IntrinsicHeight, which would have fixed the crash at the
    // cost of a second layout pass on every card in a scrolling list.
    Widget content = Padding(
      // The bar sits over the left edge, so the content is inset past it.
      padding: accent == null
          ? padding
          : padding.copyWith(left: padding.left + _accentWidth),
      child: child,
    );

    if (accent != null) {
      content = Stack(
        children: [
          content,
          Positioned(
            top: 0,
            bottom: 0,
            left: 0,
            width: _accentWidth,
            child: ColoredBox(color: accent!),
          ),
        ],
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: gradient == null ? palette.card : null,
        gradient: gradient,
        borderRadius: radius,
        // On dark, a shadow under a dark card is invisible, so depth comes from
        // the card being *lighter* than the page plus a hairline edge. Keeping
        // the shadow as well costs nothing and helps on lighter dark themes.
        border: Theme.of(context).brightness == Brightness.dark
            ? Border.all(color: palette.border)
            : null,
        boxShadow: lifted ? AppTheme.shadowLifted : AppTheme.shadowCard,
      ),
      // Clipped so the accent bar follows the rounded corner and the ink
      // splash cannot paint over it.
      child: ClipRRect(
        borderRadius: radius,
        child: Material(
          color: Colors.transparent,
          child: InkWell(onTap: onTap, child: content),
        ),
      ),
    );
  }
}

/// A small all-caps label above a group of cards.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      children: [
        Expanded(
          child: Text(
            text.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: AppTheme.ink400,
              letterSpacing: 0.9,
            ),
          ),
        ),
        ?trailing,
      ],
    ),
  );
}
