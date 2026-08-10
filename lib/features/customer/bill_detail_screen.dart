import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_exception.dart';
import '../../core/document_export.dart';
import '../../core/formatters.dart';
import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../models/invoice.dart';
import '../../services/billing_service.dart';
import '../../widgets/gradient_header.dart';
import '../../widgets/states.dart';
import 'pay_sheet.dart';

/// One bill, in full, and getting a copy of it off the phone.
///
/// The list before this could only ever say how much and whether it was paid.
/// That is enough to decide to pay and nothing else — not to check what was
/// charged for, not to query a line, and not to give anyone a copy. This is the
/// same document the workshop prints at the counter, assembled by the same
/// server code, so the customer's copy and the shop's copy cannot disagree.
class BillDetailScreen extends StatefulWidget {
  const BillDetailScreen({super.key, required this.invoiceId, this.workshop});

  final String invoiceId;

  /// The garage's own details for the letterhead. Passed in from the bills list,
  /// which has already fetched it — asking again would be a second request for
  /// something that has not changed in the two seconds since.
  final Workshop? workshop;

  @override
  State<BillDetailScreen> createState() => _BillDetailScreenState();
}

class _BillDetailScreenState extends State<BillDetailScreen> {
  /// Wraps the paper, and only the paper. What gets saved is the document, not
  /// the screen it is sitting on — no app bar, no buttons, no scrollbar.
  final _paper = GlobalKey();

  bool _loading = true;
  String? _error;
  BillDocument? _bill;
  Workshop? _workshop;

  /// Which save is running, so only that button shows a spinner.
  String? _saving;

  @override
  void initState() {
    super.initState();
    _workshop = widget.workshop;
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);

    try {
      final billing = context.read<BillingService>();

      final bill = await billing.bill(widget.invoiceId);
      // Only when it was not handed down. A bill opened from a notification has
      // no list behind it to have fetched the workshop already.
      final workshop = _workshop ?? await billing.workshop();

      if (!mounted) return;
      setState(() {
        _bill = bill;
        _workshop = workshop;
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

  Future<void> _pay() async {
    final t = AppText.of(context);
    final invoice = _bill?.invoice;

    if (invoice == null) return;

    final paid = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
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

  /// Captures the paper and hands the file to the system share sheet.
  ///
  /// [asPdf] decides only what the bytes are wrapped in — the picture is the
  /// same either way, which is the whole point: there is one bill layout in this
  /// app, not one for the screen and another for the file.
  Future<void> _save({required bool asPdf}) async {
    final t = AppText.of(context);
    final bill = _bill;

    if (bill == null || _saving != null) return;

    setState(() => _saving = asPdf ? 'pdf' : 'png');

    try {
      // A frame first: the button that started this is mid-press and the paper
      // may still be laying out at the size the previous frame gave it.
      await WidgetsBinding.instance.endOfFrame;

      final page = await DocumentExport.capture(_paper);

      if (page == null) throw StateError('nothing to capture');

      final id = bill.invoice.id;
      final bytes = asPdf ? await DocumentExport.toPdf(page) : page.bytes;

      await DocumentExport.share(
        bytes,
        filename: asPdf ? '$id.pdf' : '$id.png',
        mimeType: asPdf ? 'application/pdf' : 'image/png',
        subject: t('bill.shareSubject', [id, _workshop?.name ?? 'GarageFlow']),
        // iPads anchor the sheet to something. The bottom bar is where the
        // button that opened it lives.
        origin: _shareOrigin(),
      );
    } catch (_) {
      // Deliberately broad. Capture can fail on a GPU that refuses the texture,
      // the temp directory can be full, and the share sheet can be missing on a
      // stripped ROM — none of which the customer can act on differently, and
      // all of which are worse as a red screen than as one line saying try again.
      if (mounted) showSnack(context, t('bill.saveFailed'), isError: true);
    } finally {
      if (mounted) setState(() => _saving = null);
    }
  }

  /// The bottom strip of the screen, for the iPad popover to point at.
  Rect? _shareOrigin() {
    final box = context.findRenderObject() as RenderBox?;

    if (box == null || !box.hasSize) return null;

    final origin = box.localToGlobal(Offset.zero);

    return Rect.fromLTWH(
      origin.dx,
      origin.dy + box.size.height - 80,
      box.size.width,
      80,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);
    final palette = AppTheme.of(context);
    final bill = _bill;

    return Scaffold(
      appBar: GradientAppBar(
        title: t('bill.title'),
        subtitle: bill?.invoice.id,
      ),
      body: _loading
          ? LoadingView(label: t('bill.loading'))
          : _error != null || bill == null
          ? ErrorView(message: _error ?? t('bill.loading'), onRetry: _load)
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
                children: [
                  RepaintBoundary(
                    key: _paper,
                    child: BillPaper(bill: bill, workshop: _workshop),
                  ),
                ],
              ),
            ),
      bottomNavigationBar: bill == null
          ? null
          : SafeArea(
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                decoration: BoxDecoration(
                  color: palette.card,
                  border: Border(top: BorderSide(color: palette.border)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (bill.invoice.isPayable) ...[
                      FilledButton(
                        onPressed: _pay,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(46),
                        ),
                        child: Text(
                          t('pay.payAmount', [Fmt.rs(bill.invoice.due)]),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    Row(
                      children: [
                        Expanded(
                          child: _SaveButton(
                            icon: Icons.image_outlined,
                            label: t('bill.saveImage'),
                            busy: _saving == 'png',
                            // Disabled while the other one runs: two captures at
                            // once is two full-size bitmaps on a phone, for no
                            // reason anyone wanted.
                            onPressed: _saving == null
                                ? () => _save(asPdf: false)
                                : null,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _SaveButton(
                            icon: Icons.picture_as_pdf_outlined,
                            label: t('bill.savePdf'),
                            busy: _saving == 'pdf',
                            onPressed: _saving == null
                                ? () => _save(asPdf: true)
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _SaveButton extends StatelessWidget {
  const _SaveButton({
    required this.icon,
    required this.label,
    required this.busy,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final bool busy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);

    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: busy
          ? const SizedBox(
              width: 15,
              height: 15,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(icon, size: 18),
      label: Text(
        busy ? t('bill.preparing') : label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(44),
        foregroundColor: AppTheme.brand,
        side: const BorderSide(color: AppTheme.brand),
      ),
    );
  }
}

/// The bill itself, as a sheet of paper.
///
/// Painted on white in every theme, including dark. This is the one surface in
/// the app that is not a piece of interface: it is a document, it is what gets
/// captured to a PNG and a PDF, and a dark bill would be both wrong to send to
/// an insurer and expensive to print. The screen around it still follows the
/// theme, so it reads as paper laid on the app rather than as a screen that
/// forgot to switch.
class BillPaper extends StatelessWidget {
  const BillPaper({super.key, required this.bill, this.workshop});

  final BillDocument bill;
  final Workshop? workshop;

  // The document's own palette. Deliberately literal rather than from
  // AppTheme — see the class comment.
  static const _ink = Color(0xFF12172B);
  static const _muted = Color(0xFF5A6479);
  static const _faint = Color(0xFF8B93A5);
  static const _rule = Color(0xFFE2E6EF);

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);
    final invoice = bill.invoice;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        boxShadow: AppTheme.shadowCard,
      ),
      // Clipped so the coloured header band follows the corner.
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radius),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _letterhead(t),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _parties(t),
                  const SizedBox(height: 16),
                  _vehicle(t),
                  if (bill.complaint.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _field(t('bill.workRequested'), bill.complaint),
                  ],
                  const SizedBox(height: 18),
                  if (bill.lines.isEmpty)
                    _note(t('bill.noBreakdown'))
                  else
                    _lines(t),
                  const SizedBox(height: 14),
                  _totals(t, invoice),
                  if (bill.payments.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    _payments(t),
                  ],
                  const SizedBox(height: 20),
                  Center(
                    child: Text(
                      t('bill.thanks'),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _muted,
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Center(
                    child: Text(
                      t('bill.generated', [Fmt.date(DateTime.now())]),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 10, color: _faint),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The garage's name and contact details, on the product gradient.
  ///
  /// The garage's own uploaded logo goes here — this is the one place a tenant's
  /// mark belongs, because the bill is the tenant's document rather than the
  /// product's screen.
  Widget _letterhead(AppText t) {
    final shop = workshop;
    final logo = shop?.logoUrl;

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: const BoxDecoration(gradient: AppTheme.headerGradient),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (logo != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    logo,
                    width: 44,
                    height: 44,
                    fit: BoxFit.cover,
                    // A logo that will not load must not leave a broken-image
                    // glyph in the middle of a document somebody is about to
                    // send to their insurer.
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      shop?.name ?? '',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.2,
                      ),
                    ),
                    if ((shop?.legalName ?? '').isNotEmpty &&
                        shop!.legalName != shop.name) ...[
                      const SizedBox(height: 2),
                      Text(
                        shop.legalName,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Text(
                t('bill.taxInvoice'),
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            [
              if ((shop?.address ?? '').isNotEmpty) shop!.address,
              if ((shop?.phone ?? '').isNotEmpty) shop!.phone,
              if ((shop?.email ?? '').isNotEmpty) shop!.email,
              if ((shop?.taxNumber ?? '').isNotEmpty)
                '${t('bill.pan')} ${shop!.taxNumber}',
            ].join('  ·  '),
            style: TextStyle(
              fontSize: 11,
              height: 1.45,
              color: Colors.white.withValues(alpha: 0.82),
            ),
          ),
        ],
      ),
    );
  }

  /// Who it is for, and when it was raised.
  Widget _parties(AppText t) {
    final invoice = bill.invoice;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _label(t('bill.billedTo')),
              const SizedBox(height: 4),
              Text(
                invoice.customerName,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: _ink,
                ),
              ),
              for (final line in [
                bill.customerPhone,
                bill.customerEmail,
                bill.customerAddress,
              ])
                if (line.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      line,
                      style: const TextStyle(fontSize: 11.5, color: _muted),
                    ),
                  ),
            ],
          ),
        ),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _label(t('bill.issued')),
            const SizedBox(height: 4),
            Text(
              Fmt.date(invoice.issuedAt),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: _ink,
              ),
            ),
            if (invoice.jobCardId.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                '${t('bill.jobRef')} ${invoice.jobCardId}',
                style: const TextStyle(fontSize: 11, color: _faint),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _vehicle(AppText t) {
    final parts = <String>[
      if (bill.vehicleLabel.isNotEmpty) bill.vehicleLabel,
      bill.invoice.vehiclePlate,
    ].where((p) => p.isNotEmpty).toList();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F6FB),
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _field(t('bill.vehicle'), parts.join(' · '))),
          if (bill.odometer > 0)
            _field(t('bill.odometer'), Fmt.km(bill.odometer), alignEnd: true),
        ],
      ),
    );
  }

  /// The itemised work.
  ///
  /// Drawn as rows rather than a `Table`: the description is the only column
  /// that can wrap, and a Table with one flexible column and three intrinsic
  /// ones costs an extra layout pass on a widget that is about to be rasterised
  /// at three times its size.
  Widget _lines(AppText t) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Expanded(child: _label(t('bill.description'))),
          SizedBox(width: 42, child: _label(t('bill.qty'), alignEnd: true)),
          SizedBox(width: 72, child: _label(t('bill.rate'), alignEnd: true)),
          SizedBox(width: 82, child: _label(t('bill.amount'), alignEnd: true)),
        ],
      ),
      const Padding(
        padding: EdgeInsets.symmetric(vertical: 7),
        child: Divider(height: 1, thickness: 1, color: _rule),
      ),
      for (final line in bill.lines)
        Padding(
          padding: const EdgeInsets.only(bottom: 9),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      line.description,
                      style: const TextStyle(
                        fontSize: 12.5,
                        height: 1.3,
                        color: _ink,
                      ),
                    ),
                    Text(
                      t('bill.kind.${line.kind}'),
                      style: const TextStyle(fontSize: 10, color: _faint),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 42, child: _cell(Fmt.qty(line.qty))),
              SizedBox(width: 72, child: _cell(Fmt.rs(line.unitPrice))),
              SizedBox(
                width: 82,
                child: _cell(Fmt.rs(line.amount), bold: true),
              ),
            ],
          ),
        ),
    ],
  );

  Widget _totals(AppText t, Invoice invoice) {
    final taxable = invoice.subtotal - invoice.discount;
    // Shown as a whole number: 13, not 13.0 and not 0.13.
    final ratePct = (invoice.taxRate * 100).toStringAsFixed(
      invoice.taxRate * 100 % 1 == 0 ? 0 : 2,
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F6FB),
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
      ),
      child: Column(
        children: [
          _money(t('bill.subtotal'), invoice.subtotal),
          if (invoice.hasDiscount) ...[
            _money(
              t('bill.discount'),
              -invoice.discount,
              note: invoice.discountNote.isNotEmpty
                  ? invoice.discountNote
                  : invoice.pointsRedeemed > 0
                  ? t('bill.pointsRedeemed', [invoice.pointsRedeemed])
                  : null,
              tone: AppTheme.emerald,
            ),
            _money(t('bill.taxable'), taxable),
          ],
          _money(t('bill.vat', [ratePct]), invoice.tax),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(height: 1, thickness: 1, color: _rule),
          ),
          _money(t('bill.total'), invoice.total, big: true),
          if (invoice.paid > 0)
            _money(t('bill.paidLabel'), invoice.paid, tone: AppTheme.emerald),
          if (invoice.due > 0)
            _money(
              t('bill.dueLabel'),
              invoice.due,
              tone: AppTheme.rose,
              bold: true,
            ),
        ],
      ),
    );
  }

  Widget _payments(AppText t) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _label(t('bill.payments')),
      const SizedBox(height: 7),
      for (final payment in bill.payments)
        Padding(
          padding: const EdgeInsets.only(bottom: 5),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  [
                    Fmt.date(payment.at),
                    payment.method,
                    if ((payment.reference ?? '').isNotEmpty)
                      payment.reference!,
                  ].join(' · '),
                  style: const TextStyle(fontSize: 11.5, color: _muted),
                ),
              ),
              Text(
                Fmt.rs(payment.amount),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _ink,
                ),
              ),
            ],
          ),
        ),
    ],
  );

  // ── Small pieces ───────────────────────────────────────────────────────────

  Widget _label(String text, {bool alignEnd = false}) => Text(
    text.toUpperCase(),
    textAlign: alignEnd ? TextAlign.right : TextAlign.left,
    style: const TextStyle(
      fontSize: 9.5,
      fontWeight: FontWeight.w800,
      letterSpacing: 0.7,
      color: _faint,
    ),
  );

  Widget _cell(String text, {bool bold = false}) => Text(
    text,
    textAlign: TextAlign.right,
    style: TextStyle(
      fontSize: 12,
      fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
      color: _ink,
    ),
  );

  Widget _field(String label, String value, {bool alignEnd = false}) => Column(
    crossAxisAlignment: alignEnd
        ? CrossAxisAlignment.end
        : CrossAxisAlignment.start,
    children: [
      _label(label, alignEnd: alignEnd),
      const SizedBox(height: 3),
      Text(
        value,
        textAlign: alignEnd ? TextAlign.right : TextAlign.left,
        style: const TextStyle(
          fontSize: 12.5,
          height: 1.35,
          fontWeight: FontWeight.w600,
          color: _ink,
        ),
      ),
    ],
  );

  Widget _note(String text) => Container(
    padding: const EdgeInsets.all(11),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF6E5),
      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
    ),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 11.5,
        height: 1.4,
        color: Color(0xFF7A5A18),
      ),
    ),
  );

  /// One line of the totals block. A negative [amount] prints as "− Rs x".
  Widget _money(
    String label,
    double amount, {
    String? note,
    Color? tone,
    bool big = false,
    bool bold = false,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2.5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: big ? 13.5 : 12,
                  fontWeight: big || bold ? FontWeight.w800 : FontWeight.w500,
                  color: big ? _ink : _muted,
                ),
              ),
              if (note != null)
                Text(
                  note,
                  style: const TextStyle(fontSize: 10.5, color: _faint),
                ),
            ],
          ),
        ),
        Text(
          amount < 0 ? '− ${Fmt.rs(-amount)}' : Fmt.rs(amount),
          style: TextStyle(
            fontSize: big ? 16 : 12.5,
            fontWeight: big || bold ? FontWeight.w800 : FontWeight.w600,
            color: tone ?? _ink,
          ),
        ),
      ],
    ),
  );
}
