import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_exception.dart';
import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../models/loyalty.dart';
import '../../services/loyalty_service.dart';
import '../../widgets/states.dart';

/// Stars on a finished job.
///
/// Two scores, not one, and they are genuinely different questions: the garage
/// score covers the price, the wait and the handover, the mechanic score covers
/// the work. A shop with good mechanics and a slow front desk should be able to
/// see that, and one combined number hides it.
///
/// The mechanic half only appears when somebody was assigned. Asking a customer
/// to rate nobody is asking them to invent an answer.
class RateJobSheet extends StatefulWidget {
  const RateJobSheet({
    super.key,
    required this.jobId,
    required this.mechanic,
    this.existing,
  });

  final String jobId;

  /// The mechanic named on the job. Blank means nobody was assigned.
  final String mechanic;

  /// Their previous rating, when they are changing their mind.
  final JobRating? existing;

  /// Opens the sheet and returns the saved rating, or null if they backed out.
  static Future<JobRating?> show(
    BuildContext context, {
    required String jobId,
    required String mechanic,
    JobRating? existing,
  }) => showModalBottomSheet<JobRating>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => RateJobSheet(
      jobId: jobId,
      mechanic: mechanic,
      existing: existing,
    ),
  );

  @override
  State<RateJobSheet> createState() => _RateJobSheetState();
}

class _RateJobSheetState extends State<RateJobSheet> {
  late int _stars = widget.existing?.stars ?? 0;
  late int _mechanicStars = widget.existing?.mechanicStars ?? 0;
  late final _comment = TextEditingController(text: widget.existing?.comment ?? '');

  bool _busy = false;

  bool get _hasMechanic => widget.mechanic.trim().isNotEmpty;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_stars == 0 || _busy) return;

    setState(() => _busy = true);

    try {
      final saved = await context.read<LoyaltyService>().rate(
        widget.jobId,
        stars: _stars,
        // Zero means untouched, and the API takes null for "no opinion" — a 0
        // would be an invalid score rather than an absent one.
        mechanicStars: _hasMechanic && _mechanicStars > 0 ? _mechanicStars : null,
        comment: _comment.text,
      );

      if (!mounted) return;
      Navigator.of(context).pop(saved);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      showSnack(context, error.message, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);
    final palette = AppTheme.of(context);

    return Padding(
      // The keyboard, when the comment field has focus.
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: palette.card,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppTheme.radiusHeader),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: palette.border,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),

              const SizedBox(height: 18),
              Text(
                t('rate.title'),
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: palette.text,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                t('rate.subtitle'),
                style: TextStyle(fontSize: 13, color: palette.faint, height: 1.35),
              ),

              const SizedBox(height: 20),
              _StarRow(
                label: t('rate.garage'),
                value: _stars,
                onChanged: (v) => setState(() => _stars = v),
              ),

              if (_hasMechanic) ...[
                const SizedBox(height: 16),
                _StarRow(
                  label: t('rate.mechanic', [widget.mechanic]),
                  value: _mechanicStars,
                  onChanged: (v) => setState(() => _mechanicStars = v),
                ),
              ],

              const SizedBox(height: 18),
              TextField(
                controller: _comment,
                maxLines: 3,
                maxLength: 1000,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: t('rate.comment'),
                  hintText: t('rate.commentHint'),
                  alignLabelWithHint: true,
                ),
              ),

              const SizedBox(height: 6),
              FilledButton(
                // Disabled until the garage has a score. The mechanic half and
                // the comment are both genuinely optional; this one is what the
                // sheet is for.
                onPressed: _stars == 0 || _busy ? null : _submit,
                child: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : Text(widget.existing == null
                        ? t('rate.submit')
                        : t('rate.update')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StarRow extends StatelessWidget {
  const _StarRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = AppTheme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: palette.muted,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (var star = 1; star <= 5; star++)
              IconButton(
                onPressed: () => onChanged(star),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                constraints: const BoxConstraints(),
                // Named for screen readers, which otherwise announce five
                // identical unlabelled buttons.
                tooltip: '$star',
                icon: Icon(
                  star <= value ? Icons.star_rounded : Icons.star_outline_rounded,
                  size: 34,
                  color: star <= value ? AppTheme.amber : palette.border,
                ),
              ),
          ],
        ),
      ],
    );
  }
}
