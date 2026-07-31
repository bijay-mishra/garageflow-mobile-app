import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_exception.dart';
import '../../core/formatters.dart';
import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../models/invoice.dart';
import '../../services/billing_service.dart';
import '../../widgets/gradient_header.dart';
import '../../widgets/states.dart';
import 'pay_sheet.dart';

/// The customer's bills, and paying them.
///
/// Unpaid first — a list of settled invoices is a filing cabinet, and the reason
/// anyone opens this screen is the one that still owes money.
class BillsScreen extends StatefulWidget {
  const BillsScreen({super.key});

  @override
  State<BillsScreen> createState() => _BillsScreenState();
}

class _BillsScreenState extends State<BillsScreen> {
  bool _loading = true;
  String? _error;
  List<Invoice> _invoices = const [];
  Workshop? _workshop;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);

    try {
      final billing = context.read<BillingService>();

      // Together: the workshop record carries which wallets are live, and a Pay
      // button that appears before that is known could offer one that is not.
      final results = await Future.wait([billing.invoices(), billing.workshop()]);

      if (!mounted) return;
      setState(() {
        _invoices = results[0] as List<Invoice>;
        _workshop = results[1] as Workshop;
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

  Future<void> _pay(Invoice invoice) async {
    final t = AppText.of(context);

    final paid = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      // The sheet has to survive the app being backgrounded while the customer
      // is in a wallet, so it cannot be dismissed by a stray tap behind it.
      isDismissible: false,
      enableDrag: false,
      builder: (_) => PaySheet(
        invoice: invoice,
        providers: _workshop?.onlineProviders ?? const [],
        workshop: _workshop,
      ),
    );

    if (paid == true && mounted) {
      await _load();
      if (mounted) showSnack(context, t('pay.received'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);

    final palette = AppTheme.of(context);

    // Unpaid first, then by date. Within each group the newest is on top.
    final sorted = [..._invoices]..sort((a, b) {
      if (a.isPaid != b.isPaid) return a.isPaid ? 1 : -1;
      return b.issuedAt.compareTo(a.issuedAt);
    });

    final due = _invoices.fold(0.0, (sum, i) => sum + i.due);

    return Scaffold(
      appBar: GradientAppBar(title: t('bills.title')),
      body: _loading
          ? const LoadingView()
          : _error != null
          ? ErrorView(message: _error!, onRetry: _load)
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  if (due > 0) _DueBanner(amount: due),
                  if (_invoices.isEmpty)
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 60),
                      child: Center(
                        child: Text(
                          t('bills.none'),
                          style: TextStyle(fontSize: 14, color: palette.faint),
                        ),
                      ),
                    ),
                  ...sorted.map(
                    (invoice) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _InvoiceCard(
                        invoice: invoice,
                        onPay: () => _pay(invoice),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _DueBanner extends StatelessWidget {
  const _DueBanner({required this.amount});

  final double amount;

  @override
  Widget build(BuildContext context) {

    return Container(
    margin: const EdgeInsets.only(bottom: 14),
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: AppTheme.brand,
      borderRadius: BorderRadius.circular(AppTheme.radius),
    ),
    child: Row(
      children: [
        Expanded(
          child: Text(
            'Outstanding',
            style: TextStyle(
              fontSize: 13.5,
              color: Colors.white70,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Text(
          Fmt.rs(amount),
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ],
    ),
  );
  }
}

class _InvoiceCard extends StatelessWidget {
  const _InvoiceCard({required this.invoice, required this.onPay});

  final Invoice invoice;
  final VoidCallback onPay;

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);

    final palette = AppTheme.of(context);

    final tone = invoice.isPaid
        ? AppTheme.emerald
        : invoice.paid > 0
        ? AppTheme.amber
        : AppTheme.rose;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      invoice.id,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: palette.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${invoice.vehiclePlate} · ${Fmt.date(invoice.issuedAt)}',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: palette.faint,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: tone.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  invoice.status,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: tone,
                  ),
                ),
              ),
            ],
          ),

          const Divider(height: 20),

          Row(
            children: [
              _Figure(label: 'Total', value: Fmt.rs(invoice.total)),
              const SizedBox(width: 18),
              _Figure(
                label: 'Paid',
                value: Fmt.rs(invoice.paid),
                color: AppTheme.emerald,
              ),
              const Spacer(),
              if (invoice.isPayable)
                _Figure(
                  label: 'Due',
                  value: Fmt.rs(invoice.due),
                  color: AppTheme.rose,
                  alignEnd: true,
                ),
            ],
          ),

          if (invoice.isPayable) ...[
            const SizedBox(height: 14),
            FilledButton(
              onPressed: onPay,
              style: FilledButton.styleFrom(
                minimumSize: Size.fromHeight(46),
              ),
              child: Text(t('pay.payAmount', [Fmt.rs(invoice.due)])),
            ),
          ] else if (invoice.method != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  size: 15,
                  color: AppTheme.emerald,
                ),
                const SizedBox(width: 7),
                Text(
                  t('pay.paidBy', [invoice.method]),
                  style: TextStyle(
                    fontSize: 12.5,
                    color: palette.faint,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({
    required this.label,
    required this.value,
    this.color,
    this.alignEnd = false,
  });

  final String label;
  final String value;
  /// Null takes the palette's default text colour.
  final Color? color;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final palette = AppTheme.of(context);

    return Column(
    crossAxisAlignment: alignEnd
        ? CrossAxisAlignment.end
        : CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: TextStyle(fontSize: 11, color: palette.faint),
      ),
      const SizedBox(height: 2),
      Text(
        value,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: color ?? palette.text,
        ),
      ),
    ],
  );
  }
}
