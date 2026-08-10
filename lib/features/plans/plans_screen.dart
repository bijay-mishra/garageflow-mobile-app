import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api_exception.dart';
import '../../core/formatters.dart';
import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../models/plan.dart';
import '../../services/plans_service.dart';
import '../../widgets/gradient_header.dart';
import '../../widgets/states.dart';

/// What GarageFlow costs, what each tier includes, and paying for one.
///
/// The prices come from the server so they can be corrected without waiting for
/// an app release to reach a phone; the wording comes from the app's own
/// translation tables so it can be read in Nepali. See [Plan].
///
/// Paying works exactly like paying a bill — see `pay_sheet.dart`, whose flow
/// this deliberately mirrors rather than reinvents: the wallet opens in the
/// phone's own browser, and the app asks the server what happened when it comes
/// back to the foreground.
class PlansScreen extends StatefulWidget {
  const PlansScreen({super.key});

  @override
  State<PlansScreen> createState() => _PlansScreenState();
}

class _PlansScreenState extends State<PlansScreen> with WidgetsBindingObserver {
  bool _loading = true;
  String? _error;
  List<Plan> _plans = const [];
  MyPlan _mine = MyPlan.none;

  /// The attempt in flight, if the customer has gone off to a wallet.
  String? _reference;

  /// The plan code being paid for, so only that card shows a spinner.
  String? _paying;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Back from the browser. Whether they paid, cancelled or wandered off, the
    // server is the only thing that knows — so ask it.
    if (state == AppLifecycleState.resumed && _reference != null) _check();
  }

  Future<void> _load() async {
    setState(() => _error = null);

    try {
      final service = context.read<PlansService>();

      // Together: a card cannot be drawn correctly without knowing both what is
      // on offer and which one is already running.
      final results = await Future.wait([service.plans(), service.mine()]);

      if (!mounted) return;
      setState(() {
        _plans = results[0] as List<Plan>;
        _mine = results[1] as MyPlan;
        _loading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _loading = false;
      });
    }
  }

  /// Starts a payment for [plan] through [provider] and opens the wallet.
  Future<void> _pay(Plan plan, String provider) async {
    final t = AppText.of(context);

    setState(() {
      _paying = plan.code;
      _error = null;
    });

    try {
      final checkout = await context.read<PlansService>().subscribe(
        code: plan.code,
        provider: provider,
      );

      // The phone's own browser, not an embedded webview. Authorising a payment
      // inside a webview is what wallets tell you not to do and what customers
      // are right to distrust.
      final opened = await launchUrl(
        Uri.parse(checkout.url),
        mode: LaunchMode.externalApplication,
      );

      if (!mounted) return;

      setState(() {
        _paying = null;
        _reference = opened ? checkout.reference : null;
      });

      if (!opened) {
        showSnack(context, t('pay.couldNotOpen', [provider]), isError: true);
      }
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _paying = null);
      showSnack(context, error.message, isError: true);
    }
  }

  /// Asks the server whether the attempt settled.
  Future<void> _check() async {
    final reference = _reference;

    if (reference == null) return;

    // Cleared first: resuming twice while the check is in flight would fire two
    // verifications, and the second one's answer would arrive as an error about
    // a payment that has already succeeded.
    setState(() => _reference = null);

    try {
      final mine = await context.read<PlansService>().verify(reference);

      if (!mounted) return;
      setState(() => _mine = mine);

      if (mine.isActive && mounted) {
        showSnack(context, AppText.of(context)('plans.thanks'));
      }
    } on ApiException catch (error) {
      if (!mounted) return;
      // Not an error banner: cancelling at the wallet is a normal thing to do
      // and lands here identically to a genuine failure.
      showSnack(context, error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);
    final palette = AppTheme.of(context);

    return Scaffold(
      appBar: GradientAppBar(
        title: t('plans.title'),
        subtitle: t('plans.subtitle'),
      ),
      body: _loading
          ? const LoadingView()
          : _error != null && _plans.isEmpty
          ? ErrorView(message: _error!, onRetry: _load)
          : _plans.isEmpty
          ? EmptyView(
              icon: Icons.workspace_premium_outlined,
              title: t('plans.noneTitle'),
              message: t('plans.noneMessage'),
            )
          : RefreshIndicator(
              onRefresh: _load,
              color: AppTheme.brand,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
                children: [
                  if (_mine.isActive) ...[
                    _ActiveBanner(mine: _mine),
                    const SizedBox(height: 16),
                  ],

                  for (final plan in _plans)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: PlanCard(
                        plan: plan,
                        mine: _mine,
                        busy: _paying == plan.code,
                        // Locked out while another card's payment is starting,
                        // so two attempts cannot be opened at once — the server
                        // cancels the first, and the customer is left holding a
                        // wallet page that will never settle.
                        onPay: _paying == null
                            ? (provider) => _pay(plan, provider)
                            : null,
                      ),
                    ),

                  const SizedBox(height: 6),
                  Text(
                    _mine.canPay ? t('plans.footnote') : t('plans.noWallet'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11.5,
                      height: 1.45,
                      color: palette.faint,
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

/// What is running now, and until when.
class _ActiveBanner extends StatelessWidget {
  const _ActiveBanner({required this.mine});

  final MyPlan mine;

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);
    final ending = mine.isEndingSoon;
    final tone = ending ? AppTheme.amber : AppTheme.emerald;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: tone.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(
            ending ? Icons.schedule_rounded : Icons.verified_rounded,
            size: 20,
            color: tone,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              ending
                  ? t('plans.endingSoon', [mine.daysLeft ?? 0])
                  : t('plans.activeUntil', [Fmt.date(mine.expiresOn)]),
              style: TextStyle(
                fontSize: 13,
                height: 1.35,
                fontWeight: FontWeight.w600,
                color: tone,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One tier.
class PlanCard extends StatelessWidget {
  const PlanCard({
    super.key,
    required this.plan,
    required this.mine,
    required this.busy,
    required this.onPay,
  });

  final Plan plan;
  final MyPlan mine;
  final bool busy;

  /// Null while another card is mid-payment, which disables the button.
  final void Function(String provider)? onPay;

  bool get _isCurrent =>
      plan.isFree ? !mine.isActive : mine.isActive && mine.code == plan.code;

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);
    final palette = AppTheme.of(context);

    final features = plan.features(t);

    return AppCard(
      lifted: plan.isPopular,
      accent: _isCurrent
          ? AppTheme.emerald
          : plan.isPopular
          ? AppTheme.brand
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plan.label(t),
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: palette.text,
                        letterSpacing: -0.2,
                      ),
                    ),
                    if (plan.tagline(t).isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        plan.tagline(t),
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.35,
                          color: palette.faint,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (plan.isPopular && !_isCurrent)
                _Tag(t('plans.popular'), tone: AppTheme.brand),
            ],
          ),

          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                plan.isFree ? t('plans.freePrice') : Fmt.rs(plan.price),
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: palette.text,
                  letterSpacing: -0.8,
                ),
              ),
              if (!plan.isFree) ...[
                const SizedBox(width: 5),
                Text(
                  t('period.${plan.period}', [plan.periodMonths]),
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: palette.faint,
                  ),
                ),
              ],
            ],
          ),

          // The sum nobody does in their head, and the only way a quarterly and
          // a yearly price can be compared at a glance.
          if (!plan.isFree && plan.periodMonths > 1) ...[
            const SizedBox(height: 3),
            Text(
              t('plans.worksOutAt', [Fmt.rs(plan.perMonth)]),
              style: TextStyle(fontSize: 12, color: AppTheme.emerald),
            ),
          ],

          if (features.isNotEmpty) ...[
            const SizedBox(height: 14),
            for (final feature in features)
              Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.check_rounded,
                      size: 16,
                      color: plan.isFree ? palette.faint : AppTheme.emerald,
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        feature,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.35,
                          color: palette.muted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],

          const SizedBox(height: 12),
          _cta(context, t),
        ],
      ),
    );
  }

  /// The buttons, or the honest absence of them.
  Widget _cta(BuildContext context, AppText t) {
    final palette = AppTheme.of(context);

    if (_isCurrent) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: palette.field,
          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_rounded, size: 16, color: AppTheme.emerald),
            const SizedBox(width: 7),
            Text(
              t('plans.yourPlan'),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: palette.faint,
              ),
            ),
          ],
        ),
      );
    }

    // The free tier is not something anybody buys — it is what you fall back to.
    if (plan.isFree) {
      return Text(
        t('plans.freeFallback'),
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 12, height: 1.35, color: palette.faint),
      );
    }

    if (!plan.available) {
      return OutlinedButton(
        onPressed: null,
        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46)),
        child: Text(t('plans.comingSoon')),
      );
    }

    // No wallet configured on the server. A button here would open a payment
    // that cannot be started, so it says why instead.
    if (!mine.canPay) {
      return OutlinedButton(
        onPressed: null,
        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46)),
        child: Text(t('plans.noWalletShort')),
      );
    }

    if (busy) {
      return FilledButton(
        onPressed: null,
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(46)),
        child: const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2.2,
            valueColor: AlwaysStoppedAnimation(Colors.white),
          ),
        ),
      );
    }

    // One button per wallet the server can actually take money through. Never a
    // fixed list — a Khalti button on a server with no Khalti key is a button
    // that dead-ends, and the customer has no way to know why.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < mine.providers.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          _WalletButton(
            provider: mine.providers[i],
            // The first wallet leads, the rest are alternatives.
            primary: i == 0,
            onPressed: onPay == null ? null : () => onPay!(mine.providers[i]),
          ),
        ],
      ],
    );
  }
}

/// "Pay with Khalti", in that wallet's own name.
///
/// The brand's name in text rather than its logo. A real eSewa or Khalti mark is
/// their asset to license, and an approximation drawn here would be a worse kind
/// of wrong than plain type — it would look like the real thing.
class _WalletButton extends StatelessWidget {
  const _WalletButton({
    required this.provider,
    required this.primary,
    required this.onPressed,
  });

  final String provider;
  final bool primary;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final label = Text(AppText.of(context)('plans.payWith', [provider]));

    return primary
        ? FilledButton.icon(
            onPressed: onPressed,
            icon: const Icon(Icons.account_balance_wallet_outlined, size: 19),
            label: label,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(46),
            ),
          )
        : OutlinedButton.icon(
            onPressed: onPressed,
            icon: const Icon(Icons.account_balance_wallet_outlined, size: 18),
            label: label,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(44),
              foregroundColor: AppTheme.brand,
              side: const BorderSide(color: AppTheme.brand),
            ),
          );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.text, {required this.tone});

  final String text;
  final Color tone;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: tone.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 10.5,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.3,
        color: tone,
      ),
    ),
  );
}
