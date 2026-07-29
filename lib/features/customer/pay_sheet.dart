import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api_exception.dart';
import '../../core/formatters.dart';
import '../../core/theme.dart';
import '../../models/invoice.dart';
import '../../services/billing_service.dart';

/// Pays a bill through eSewa or Khalti.
///
/// The flow, and why it looks like this:
///
/// 1. tap a wallet — the server opens an attempt and hands back a link;
/// 2. the link opens in the phone's browser, because authorising a payment
///    inside an embedded webview is exactly what wallets tell you not to do and
///    what customers are right to distrust;
/// 3. the customer comes back to the app, and it asks the server what happened.
///
/// Step 3 is why this watches the app lifecycle instead of registering a deep
/// link. A deep link means an intent-filter on Android, an associated domain on
/// iOS, and a scheme that has to survive both — for the same result as noticing
/// that the app was resumed and asking a question it can ask anyway.
class PaySheet extends StatefulWidget {
  const PaySheet({super.key, required this.invoice, required this.providers});

  final Invoice invoice;

  /// Wallets the server can actually take money through, from the workshop
  /// record. Never hardcoded — a button that dead-ends is worse than no button.
  final List<String> providers;

  @override
  State<PaySheet> createState() => _PaySheetState();
}

class _PaySheetState extends State<PaySheet> with WidgetsBindingObserver {
  /// The attempt in flight, if the customer has gone off to a wallet.
  String? _reference;
  String? _provider;

  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
    if (state == AppLifecycleState.resumed && _reference != null && !_busy) {
      _check();
    }
  }

  Future<void> _pay(String provider) async {
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final start = await context.read<BillingService>().startPayment(
        invoiceId: widget.invoice.id,
        provider: provider,
      );

      final opened = await launchUrl(
        Uri.parse(start.url),
        mode: LaunchMode.externalApplication,
      );

      if (!mounted) return;

      if (!opened) {
        setState(() {
          _busy = false;
          _error = 'Could not open $provider. Is a browser installed?';
        });
        return;
      }

      setState(() {
        _reference = start.reference;
        _provider = provider;
        _busy = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = error.message;
      });
    }
  }

  Future<void> _check() async {
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await context.read<BillingService>().verifyPayment(_reference!);

      // Settled. The caller reloads its list and shows the receipt.
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        // Not necessarily a failure — "still processing" arrives here too, which
        // is why the button below says "Check again" rather than "Retry".
        _error = error.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final waiting = _reference != null;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.ink200,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 18),

            Text('Pay this bill', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 3),
            Text(
              '${widget.invoice.id} · ${widget.invoice.vehiclePlate}',
              style: const TextStyle(fontSize: 13, color: AppTheme.ink500),
            ),

            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              decoration: BoxDecoration(
                color: AppTheme.brandLight,
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              ),
              child: Row(
                children: [
                  const Text(
                    'Amount due',
                    style: TextStyle(fontSize: 13.5, color: AppTheme.brandDark),
                  ),
                  const Spacer(),
                  Text(
                    Fmt.rs(widget.invoice.due),
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.brandDark,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            if (waiting) ...[
              // The customer has been sent off to a wallet. Nothing here can know
              // the outcome, so it says so plainly and offers the one useful action.
              Row(
                children: [
                  const Icon(
                    Icons.hourglass_top_rounded,
                    size: 18,
                    color: AppTheme.amber,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      'Waiting for $_provider to confirm. Finish paying, then come '
                      'back — this updates on its own.',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.ink700,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _busy ? null : _check,
                child: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : const Text('Check again'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: _busy
                    ? null
                    : () => setState(() {
                        _reference = null;
                        _provider = null;
                        _error = null;
                      }),
                child: const Text('Pay a different way'),
              ),
            ] else if (widget.providers.isEmpty) ...[
              const Text(
                'This workshop does not take online payment yet. Pay at the '
                'counter by cash, card or bank transfer.',
                style: TextStyle(
                  fontSize: 13.5,
                  color: AppTheme.ink500,
                  height: 1.45,
                ),
              ),
            ] else ...[
              const _Label('PAY WITH'),
              const SizedBox(height: 10),
              for (final provider in widget.providers)
                Padding(
                  padding: const EdgeInsets.only(bottom: 9),
                  child: _ProviderButton(
                    provider: provider,
                    enabled: !_busy,
                    onTap: () => _pay(provider),
                  ),
                ),
              const SizedBox(height: 4),
              const Text(
                'You will be taken to the app or website to authorise. Nothing is '
                'charged until you confirm there.',
                style: TextStyle(
                  fontSize: 11.5,
                  color: AppTheme.ink400,
                  height: 1.4,
                ),
              ),
            ],

            if (_error != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.rose.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      size: 17,
                      color: AppTheme.rose,
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        _error!,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppTheme.rose,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The wallets' own colours and marks.
///
/// Not their official logo files — those are brand assets from each provider's
/// kit and are not ours to ship. The colours and names are right, and the mark
/// is a placeholder: drop the official SVG in here once you have downloaded it
/// from the provider's brand page, and nothing else has to change.
class _ProviderButton extends StatelessWidget {
  const _ProviderButton({
    required this.provider,
    required this.enabled,
    required this.onTap,
  });

  final String provider;
  final bool enabled;
  final VoidCallback onTap;

  /// eSewa green and Khalti purple, from each brand's published palette.
  static const _colors = <String, Color>{
    'eSewa': Color(0xFF60BB46),
    'Khalti': Color(0xFF5C2D91),
  };

  static const _taglines = <String, String>{
    'eSewa': 'Wallet, bank or card',
    'Khalti': 'Wallet, bank or card',
  };

  @override
  Widget build(BuildContext context) {
    final color = _colors[provider] ?? AppTheme.brand;

    return Opacity(
      opacity: enabled ? 1 : 0.6,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          child: Container(
            height: 60,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              border: Border.all(color: color.withValues(alpha: 0.45), width: 1.4),
            ),
            child: Row(
              children: [
                // Placeholder mark — swap for the provider's official asset.
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    provider.substring(0, 1).toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 13),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      provider,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                    Text(
                      _taglines[provider] ?? 'Pay online',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.ink500,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Icon(Icons.arrow_forward_rounded, size: 19, color: color),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      fontSize: 11.5,
      fontWeight: FontWeight.w700,
      color: AppTheme.ink400,
      letterSpacing: 0.7,
    ),
  );
}
