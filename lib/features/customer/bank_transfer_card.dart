import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/api_exception.dart';
import '../../core/formatters.dart';
import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../models/invoice.dart';
import '../../services/billing_service.dart';
import '../../widgets/states.dart';

/// Bank transfer — the workshop's account, and a way to say you have paid.
///
/// The most honest option in the pay sheet, and the one whose wording needs the
/// most care. Nothing here talks to a bank: the customer copies an account
/// number, moves the money in their own banking app, and comes back. Tapping
/// the button records a *claim*, which a staff member confirms against the
/// statement.
///
/// So the button does not say "Pay", and the sheet does not close as though the
/// bill were settled. Getting that wrong would leave someone believing a bill
/// was paid when nothing had reached the account.
class BankTransferCard extends StatefulWidget {
  const BankTransferCard({
    super.key,
    required this.workshop,
    required this.invoice,
    required this.busy,
    required this.onDeclared,
  });

  final Workshop workshop;
  final Invoice invoice;
  final bool busy;

  /// Called with the server's own sentence once the claim is recorded.
  final void Function(String message) onDeclared;

  @override
  State<BankTransferCard> createState() => _BankTransferCardState();
}

class _BankTransferCardState extends State<BankTransferCard> {
  // Collapsed by default. An account number is only wanted by someone who has
  // chosen this route, and expanded it pushes the wallet buttons off screen.
  bool _open = false;
  bool _sending = false;

  Future<void> _declare() async {
    setState(() => _sending = true);

    try {
      final message = await context
          .read<BillingService>()
          .declareBankTransfer(widget.invoice.id);

      if (!mounted) return;
      widget.onDeclared(message);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _sending = false);
      showSnack(context, error.message, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppTheme.of(context);
    final t = AppText.of(context);
    final shop = widget.workshop;

    return Container(
      decoration: BoxDecoration(
        color: palette.field,
        borderRadius: BorderRadius.circular(AppTheme.radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: widget.busy ? null : () => setState(() => _open = !_open),
            borderRadius: BorderRadius.circular(AppTheme.radius),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppTheme.emerald.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.account_balance_rounded,
                      size: 20,
                      color: AppTheme.emerald,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t('pay.bankTransfer'),
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: palette.text,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          shop.bankName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: palette.faint),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _open
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: palette.faint,
                  ),
                ],
              ),
            ),
          ),

          if (_open) ...[
            Divider(height: 1, color: palette.border),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Line(label: t('pay.bankName'), value: shop.bankName),
                  if (shop.bankAccountName.isNotEmpty)
                    _Line(
                      label: t('pay.accountName'),
                      value: shop.bankAccountName,
                    ),
                  _Line(
                    label: t('pay.accountNumber'),
                    value: shop.bankAccountNumber,
                    copyable: true,
                  ),
                  if (shop.bankBranch.isNotEmpty)
                    _Line(label: t('pay.branch'), value: shop.bankBranch),
                  _Line(
                    label: t('pay.amountDue'),
                    value: Fmt.rs(widget.invoice.due),
                    copyable: true,
                  ),

                  const SizedBox(height: 14),
                  OutlinedButton(
                    onPressed: _sending ? null : _declare,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.emerald,
                      side: const BorderSide(color: AppTheme.emerald),
                      minimumSize: const Size.fromHeight(46),
                    ),
                    child: _sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(t('pay.iHaveTransferred')),
                  ),

                  const SizedBox(height: 8),
                  // The sentence that keeps this honest.
                  Text(
                    t('pay.bankNote'),
                    style: TextStyle(
                      fontSize: 11.5,
                      color: palette.faint,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// One label/value row, with a copy button where copying is the point.
class _Line extends StatelessWidget {
  const _Line({
    required this.label,
    required this.value,
    this.copyable = false,
  });

  final String label;
  final String value;
  final bool copyable;

  @override
  Widget build(BuildContext context) {
    final palette = AppTheme.of(context);
    final t = AppText.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(
            width: 104,
            child: Text(
              label,
              style: TextStyle(fontSize: 12.5, color: palette.faint),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: palette.text,
                // An account number is read digit by digit against a banking
                // app, so it gets a little air between the characters.
                letterSpacing: copyable ? 0.4 : 0,
              ),
            ),
          ),
          if (copyable)
            IconButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: value));
                showSnack(context, t('pay.copied'));
              },
              icon: const Icon(Icons.copy_rounded, size: 16),
              color: AppTheme.brand,
              visualDensity: VisualDensity.compact,
              tooltip: t('pay.copy'),
            ),
        ],
      ),
    );
  }
}
