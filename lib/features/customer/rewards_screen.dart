import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_exception.dart';
import '../../core/formatters.dart';
import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../models/loyalty.dart';
import '../../services/loyalty_service.dart';
import '../../widgets/gradient_header.dart';
import '../../widgets/states.dart';

/// The customer's stamps, points and the offers running today.
///
/// Everything here belongs to the garage they are currently viewing. Switching
/// garages switches the card with it, because a scheme is one workshop's
/// promise and stamps at one shop are not something another has agreed to
/// honour.
///
/// A garage running no scheme gets the empty state rather than a screen of
/// zeroes: "0 points" and "this garage does not do points" are identical in the
/// data and completely different to a person.
class RewardsScreen extends StatefulWidget {
  const RewardsScreen({super.key});

  @override
  State<RewardsScreen> createState() => _RewardsScreenState();
}

class _RewardsScreenState extends State<RewardsScreen> {
  bool _loading = true;
  String? _error;

  LoyaltyCard? _card;
  List<Offer> _offers = const [];
  List<LoyaltyEntry> _history = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final service = context.read<LoyaltyService>();

    try {
      // Three calls, awaited together: they are independent, and doing them in
      // sequence would make the screen take three round trips to open.
      final results = await Future.wait([
        service.card(),
        service.offers(),
        service.history(),
      ]);

      if (!mounted) return;

      setState(() {
        _card = results[0] as LoyaltyCard;
        _offers = results[1] as List<Offer>;
        _history = results[2] as List<LoyaltyEntry>;
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

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);

    return Scaffold(
      appBar: GradientAppBar(title: t('rewards.title')),
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppTheme.brand,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
          children: [_buildBody()],
        ),
      ),
    );
  }

  Widget _buildBody() {
    final t = AppText.of(context);

    if (_loading && _card == null) {
      return Padding(
        padding: const EdgeInsets.only(top: 60),
        child: LoadingView(label: t('rewards.loading')),
      );
    }

    if (_error != null && _card == null) {
      return Padding(
        padding: const EdgeInsets.only(top: 40),
        child: ErrorView(message: _error!, onRetry: _load),
      );
    }

    final card = _card;

    // Nothing running and nothing on: say so plainly rather than drawing an
    // empty card that looks like a scheme the person is failing at.
    if (card == null || (!card.runs && _offers.isEmpty)) {
      return Padding(
        padding: const EdgeInsets.only(top: 40),
        child: EmptyView(
          icon: Icons.card_giftcard_outlined,
          title: t('rewards.noneTitle'),
          message: t('rewards.noneMessage'),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (card.stampCardRuns) ...[
          _StampCard(card: card),
          const SizedBox(height: 16),
        ],

        if (card.pointsRun) ...[
          _PointsCard(card: card),
          const SizedBox(height: 16),
        ],

        if (_offers.isNotEmpty) ...[
          SectionLabel(t('rewards.running')),
          for (final offer in _offers)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _OfferCard(offer: offer),
            ),
          const SizedBox(height: 8),
        ],

        if (_history.isNotEmpty) ...[
          SectionLabel(t('rewards.history')),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < _history.length; i++) ...[
                  if (i > 0)
                    Divider(height: 1, indent: 52, color: AppTheme.of(context).border),
                  _HistoryRow(entry: _history[i]),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// The stamp card, drawn as stamps rather than as a number.
///
/// A row of filled and empty circles is the thing itself — the paper card a
/// workshop would otherwise be stamping — and it answers "how many more?" at a
/// glance in a way "3/4" does not.
class _StampCard extends StatelessWidget {
  const _StampCard({required this.card});

  final LoyaltyCard card;

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);
    final palette = AppTheme.of(context);
    final ready = card.rewardsAvailable > 0;

    return AppCard(
      accent: ready ? AppTheme.emerald : AppTheme.brand,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                ready ? Icons.card_giftcard_rounded : Icons.local_activity_outlined,
                size: 20,
                color: ready ? AppTheme.emerald : AppTheme.brand,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  card.rewardName ?? t('rewards.freeService'),
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    color: palette.text,
                  ),
                ),
              ),
              if (card.rewardValue > 0)
                Text(
                  Fmt.rs(card.rewardValue),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: palette.faint,
                  ),
                ),
            ],
          ),

          const SizedBox(height: 14),
          // Capped at twelve on screen. Beyond that the circles stop being
          // countable at a glance and the number below carries the meaning.
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < card.jobsPerReward.clamp(0, 12); i++)
                _Stamp(filled: i < card.stampsOnCard),
            ],
          ),

          const SizedBox(height: 14),
          if (ready)
            _Banner(
              tone: AppTheme.emerald,
              icon: Icons.check_circle_outline_rounded,
              text: card.rewardsAvailable == 1
                  ? t('rewards.readyOne', [card.rewardName ?? ''])
                  : t('rewards.readyMany', [card.rewardsAvailable]),
            )
          else
            Text(
              card.stampsToGo == 1
                  ? t('rewards.oneToGo', [card.rewardName ?? ''])
                  : t('rewards.manyToGo', [card.stampsToGo, card.rewardName ?? '']),
              style: TextStyle(fontSize: 13, color: palette.muted, height: 1.4),
            ),

          const SizedBox(height: 6),
          Text(
            t('rewards.askAtCounter'),
            style: TextStyle(fontSize: 11.5, color: palette.faint, height: 1.35),
          ),
        ],
      ),
    );
  }
}

class _Stamp extends StatelessWidget {
  const _Stamp({required this.filled});

  final bool filled;

  @override
  Widget build(BuildContext context) {
    final palette = AppTheme.of(context);

    return Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: filled ? AppTheme.brand : Colors.transparent,
        border: Border.all(
          color: filled ? AppTheme.brand : palette.border,
          width: 1.6,
        ),
      ),
      child: filled
          ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
          : null,
    );
  }
}

class _PointsCard extends StatelessWidget {
  const _PointsCard({required this.card});

  final LoyaltyCard card;

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);
    final palette = AppTheme.of(context);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t('rewards.points'),
                      style: TextStyle(fontSize: 12.5, color: palette.faint),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      Fmt.number(card.pointsBalance),
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        color: palette.text,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                t('rewards.worth', [Fmt.rs(card.pointsValue)]),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.emerald,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          Text(
            card.canRedeemPoints
                ? t('rewards.canSpend')
                : t('rewards.needMore', [
                    Fmt.number(card.minimumPointsToRedeem - card.pointsBalance),
                    Fmt.number(card.minimumPointsToRedeem),
                  ]),
            style: TextStyle(fontSize: 13, color: palette.muted, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _OfferCard extends StatelessWidget {
  const _OfferCard({required this.offer});

  final Offer offer;

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);
    final palette = AppTheme.of(context);

    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
            decoration: BoxDecoration(
              gradient: AppTheme.headerGradient,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Text(
              '${offer.percent.toStringAsFixed(offer.percent % 1 == 0 ? 0 : 1)}%',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  offer.name,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: palette.text,
                  ),
                ),
                if (offer.description.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    offer.description,
                    style: TextStyle(fontSize: 12.5, color: palette.muted, height: 1.35),
                  ),
                ],
                if (offer.scope.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    offer.scope,
                    style: TextStyle(fontSize: 11.5, color: palette.faint),
                  ),
                ],
                if (offer.endsOn != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    t('rewards.until', [Fmt.date(offer.endsOn)]),
                    style: TextStyle(fontSize: 11.5, color: palette.faint),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.entry});

  final LoyaltyEntry entry;

  @override
  Widget build(BuildContext context) {
    final palette = AppTheme.of(context);

    final colour = entry.isReward
        ? AppTheme.emerald
        : entry.isSpend
        ? AppTheme.rose
        : AppTheme.brand;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colour.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              entry.isReward
                  ? Icons.card_giftcard_rounded
                  : entry.isSpend
                  ? Icons.remove_rounded
                  : Icons.add_rounded,
              size: 15,
              color: colour,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  // The server's own sentence, shown verbatim — it knows which
                  // invoice or job this was and the app does not.
                  entry.note,
                  style: TextStyle(fontSize: 13, color: palette.text, height: 1.3),
                ),
                const SizedBox(height: 2),
                Text(
                  Fmt.date(entry.at),
                  style: TextStyle(fontSize: 11.5, color: palette.faint),
                ),
              ],
            ),
          ),
          if (entry.points != 0) ...[
            const SizedBox(width: 8),
            Text(
              entry.points > 0 ? '+${entry.points}' : '${entry.points}',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: colour,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.tone, required this.icon, required this.text});

  final Color tone;
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      gradient: AppTheme.tintGradient(tone),
      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
    ),
    child: Row(
      children: [
        Icon(icon, size: 17, color: tone),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppTheme.of(context).text,
              height: 1.35,
            ),
          ),
        ),
      ],
    ),
  );
}
