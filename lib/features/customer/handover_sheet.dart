import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_exception.dart';
import '../../core/formatters.dart';
import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../models/delivery.dart';
import '../../services/delivery_service.dart';
import '../../widgets/states.dart';

/// Asks the customer how they want their vehicle back.
///
/// Returns true when the choice was saved, so the caller knows to reload.
Future<bool> showHandoverSheet(BuildContext context, Delivery delivery) async {
  final changed = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _HandoverSheet(delivery: delivery),
  );

  return changed ?? false;
}

/// Collection or home delivery.
///
/// The price is fetched before the buttons are usable, and shown on the option
/// itself. Asking someone to commit to "home delivery" and only then telling
/// them what it costs is the pattern this deliberately avoids — the fee depends
/// on how far away they live, so it is not something they could have guessed.
class _HandoverSheet extends StatefulWidget {
  const _HandoverSheet({required this.delivery});

  final Delivery delivery;

  @override
  State<_HandoverSheet> createState() => _HandoverSheetState();
}

class _HandoverSheetState extends State<_HandoverSheet> {
  DeliveryQuote? _quote;
  String? _error;
  bool _loading = true;
  bool _saving = false;

  /// Starts on whatever they already chose, so reopening the sheet to change
  /// their mind does not silently reset to the cheaper option.
  late String _method = widget.delivery.isHomeDelivery
      ? 'HomeDelivery'
      : 'Pickup';

  @override
  void initState() {
    super.initState();
    _loadQuote();
  }

  Future<void> _loadQuote() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final quote = await context.read<DeliveryApi>().quote(widget.delivery.id);
      if (!mounted) return;
      setState(() {
        _quote = quote;
        _loading = false;
        // Never leave the selection on an option that turned out not to be on
        // offer — the confirm button would fail for a reason already on screen.
        if (!quote.available) _method = 'Pickup';
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _loading = false;
      });
    }
  }

  Future<void> _confirm() async {
    setState(() => _saving = true);

    try {
      final response = await context.read<DeliveryApi>().choose(
        widget.delivery.id,
        _method,
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
      // The server's sentence carries the fee, and whether it came out free on
      // this bill. Rewording it here would lose that.
      showSnack(context, response.message);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      showSnack(context, error.message, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppTheme.of(context);
    final t = AppText.of(context);

    return Padding(
    padding: EdgeInsets.only(
      left: 20,
      right: 20,
      top: 8,
      // Clears the keyboard and the home indicator both.
      bottom: MediaQuery.of(context).viewInsets.bottom + 24,
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 38,
            height: 4,
            margin: const EdgeInsets.only(bottom: 18),
            decoration: BoxDecoration(
              color: palette.border,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),

        Text(
          t('handover.readyTitle'),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: palette.text,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          '${widget.delivery.vehicleLabel} · ${widget.delivery.vehiclePlate}',
          style: TextStyle(fontSize: 13.5, color: palette.faint),
        ),

        const SizedBox(height: 22),

        if (_loading)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: LoadingView(label: t('handover.checking')),
          )
        else ...[
          if (_error != null) ...[
            _Warning(_error!, onRetry: _loadQuote),
            const SizedBox(height: 16),
          ],

          _Option(
            title: t('handover.collect'),
            subtitle: t('handover.collectSub'),
            icon: Icons.storefront_rounded,
            trailing: t('common.free'),
            selected: _method == 'Pickup',
            onTap: () => setState(() => _method = 'Pickup'),
          ),
          const SizedBox(height: 11),
          _Option(
            title: t('handover.deliver'),
            subtitle: _quote == null
                ? t('handover.notAvailableNow')
                : _quote!.available
                ? t('handover.fromWorkshop', [_quote!.distanceKm.toStringAsFixed(1)])
                // The server's own explanation — too far, no pin on the
                // account, delivery switched off. It knows which.
                : _quote!.reason ?? t('handover.notAvailableAddress'),
            icon: Icons.local_shipping_rounded,
            trailing: _quote?.available == true
                ? _quote!.isFree
                      ? t('common.free')
                      : Fmt.rs(_quote!.fee)
                : null,
            // The fee is added to the bill, not taken now, and that is worth
            // saying before someone commits to it.
            footnote: _quote?.available == true && !_quote!.isFree
                ? t('handover.onBill')
                : null,
            selected: _method == 'HomeDelivery',
            enabled: _quote?.available == true,
            onTap: () => setState(() => _method = 'HomeDelivery'),
          ),

          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving ? null : _confirm,
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  )
                : Text(
                    _method == 'Pickup'
                        ? t('handover.collect')
                        : _quote?.isFree == true
                        ? t('handover.confirmDelivery')
                        : t('handover.confirmFee', [Fmt.rs(_quote?.fee ?? 0)]),
                  ),
          ),

          const SizedBox(height: 10),
          Text(
            t('handover.changeNote'),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: palette.faint),
          ),
        ],
      ],
    ),
    );
  }
}

class _Option extends StatelessWidget {
  const _Option({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.trailing,
    this.footnote,
    this.enabled = true,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final String? trailing;
  final String? footnote;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final palette = AppTheme.of(context);

    final color = enabled ? AppTheme.brand : palette.faint;

    return Opacity(
      opacity: enabled ? 1 : 0.6,
      child: Material(
        color: selected && enabled
            ? AppTheme.brand.withValues(alpha: 0.06)
            : Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(AppTheme.radius),
          child: Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTheme.radius),
              // The one place in the redesign an outline survives: a chooser
              // needs to show which of two equal things is picked, and a
              // shadow cannot say that.
              border: Border.all(
                color: selected && enabled ? AppTheme.brand : palette.border,
                width: selected && enabled ? 1.8 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.11),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(icon, size: 21, color: color),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: palette.text,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: palette.faint,
                          height: 1.3,
                        ),
                      ),
                      if (footnote != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          footnote!,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: palette.faint,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    trailing!,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: trailing == 'Free'
                          ? AppTheme.emerald
                          : palette.text,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Warning extends StatelessWidget {
  const _Warning(this.message, {required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final palette = AppTheme.of(context);

    return Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      gradient: AppTheme.tintGradient(AppTheme.amber),
      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
    ),
    child: Row(
      children: [
        const Icon(Icons.info_outline_rounded, size: 18, color: AppTheme.amber),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            message,
            style: TextStyle(
              fontSize: 12.5,
              color: palette.muted,
              height: 1.3,
            ),
          ),
        ),
        TextButton(onPressed: onRetry, child: Text('Retry')),
      ],
    ),
  );

  }
}
