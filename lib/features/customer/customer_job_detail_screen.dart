import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_exception.dart';
import '../../core/formatters.dart';
import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../models/job.dart';
import '../../models/loyalty.dart';
import '../../services/customer_service.dart';
import '../../services/loyalty_service.dart';
import '../../widgets/gradient_header.dart';
import '../../widgets/states.dart';
import '../../widgets/stat_tile.dart';
import '../../widgets/status_chip.dart';
import '../shared/photo_viewer.dart';
import 'rate_job_sheet.dart';

/// One job, from the customer's side: how far along, what it will cost, and
/// what the workshop has photographed.
class CustomerJobDetailScreen extends StatefulWidget {
  const CustomerJobDetailScreen({super.key, required this.jobId});

  final String jobId;

  @override
  State<CustomerJobDetailScreen> createState() =>
      _CustomerJobDetailScreenState();
}

class _CustomerJobDetailScreenState extends State<CustomerJobDetailScreen> {
  bool _loading = true;
  String? _error;
  CustomerJob? _job;

  /// Their existing stars on this job, when they have left any.
  JobRating? _rating;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);

    try {
      final job = await context.read<CustomerService>().job(widget.jobId);
      if (!mounted) return;
      setState(() {
        _job = job;
        _loading = false;
      });

      // After the job, and only for finished work — there is nothing to have
      // rated otherwise. Separate from the job load so a rating endpoint that
      // fails cannot stop the screen drawing the job.
      if (job.isFinished) await _loadRating();
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _loading = false;
      });
    }
  }

  Future<void> _loadRating() async {
    try {
      final rating = await context.read<LoyaltyService>().ratingFor(widget.jobId);
      if (!mounted) return;
      setState(() => _rating = rating);
    } on ApiException {
      // Not worth an error state. The card falls back to "rate this service",
      // and rating again edits rather than duplicates.
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);

    final palette = AppTheme.of(context);

    final job = _job;

    return Scaffold(
      appBar: GradientAppBar(
        title: job?.vehiclePlate ?? widget.jobId,
        subtitle: job?.vehicleLabel,
      ),
      body: _loading
          ? const LoadingView()
          : job == null
          ? ErrorView(message: _error ?? t('job.notFound'), onRetry: _load)
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  _ProgressCard(job: job),

                  // Only once the work is done, and only ever one tap away.
                  // Asking mid-job would be asking someone to score a guess.
                  if (job.isFinished) ...[
                    const SizedBox(height: 14),
                    _RateCard(
                      job: job,
                      rating: _rating,
                      onRated: (rating) => setState(() => _rating = rating),
                    ),
                  ],

                  const SizedBox(height: 14),
                  SectionCard(
                    title: t('job.lookingAt'),
                    child: Text(
                      job.complaint.isEmpty
                          ? t('job.noDetails')
                          // Only the customer's own words. Everything after a
                          // newline is the mechanic's internal work notes, which
                          // are not written for the customer to read.
                          : job.complaint.split('\n').first,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        color: palette.muted,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SectionCard(
                    title: 'DATES',
                    child: Column(
                      children: [
                        DetailRow(
                          label: t('job.bookedIn'),
                          value: Fmt.date(job.createdAt),
                        ),
                        DetailRow(
                          label: t('job.readyBy'),
                          value: Fmt.date(job.promisedAt),
                          bold: true,
                        ),
                        if (job.completedAt != null)
                          DetailRow(
                            label: 'Completed',
                            value: Fmt.date(job.completedAt),
                            valueColor: AppTheme.emerald,
                            bold: true,
                          ),
                      ],
                    ),
                  ),
                  if (job.lines.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _Costs(job: job),
                  ],
                  if (job.photos.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _PhotoStrip(job: job),
                  ],
                ],
              ),
            ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.job});

  final CustomerJob job;

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);

    final palette = AppTheme.of(context);

    final color = AppTheme.statusColor(job.status);

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  job.vehicleLabel,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              StatusChip(job.status),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            '${job.vehiclePlate} · ${job.id}',
            style: TextStyle(fontSize: 12.5, color: palette.faint),
          ),
          const SizedBox(height: 18),
          ProgressBar(percent: job.progressPct, color: color),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                '${job.progressPct}%',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  switch (job.status) {
                    'Open' => t('job.stageOpen'),
                    'In Progress' => t('job.stageProgress'),
                    'Awaiting Parts' => t('job.stageParts'),
                    'Completed' => t('job.stageDone'),
                    'Delivered' => t('job.stageCollected'),
                    'Cancelled' => t('job.stageCancelled'),
                    _ => '',
                  },
                  style: TextStyle(
                    fontSize: 12.5,
                    color: palette.faint,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Costs extends StatelessWidget {
  const _Costs({required this.job});

  final CustomerJob job;

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);

    final palette = AppTheme.of(context);

    return SectionCard(
    title: t('job.workAndParts'),
    child: Column(
      children: [
        for (final line in job.lines)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        line.description,
                        style: TextStyle(
                          fontSize: 13.5,
                          color: palette.muted,
                        ),
                      ),
                      Text(
                        '${Fmt.number(line.qty)} × ${Fmt.rs(line.unitPrice)}',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: palette.faint,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  Fmt.rs(line.total),
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: palette.text,
                  ),
                ),
              ],
            ),
          ),
        const Divider(height: 22),
        Row(
          children: [
            Text(
              t('job.estimatedTotal'),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: palette.text,
              ),
            ),
            const Spacer(),
            Text(
              Fmt.rs(job.total),
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: palette.text,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            t('job.beforeTax'),
            style: TextStyle(fontSize: 11.5, color: palette.faint),
          ),
        ),
      ],
    ),
  );
  }
}

class _PhotoStrip extends StatelessWidget {
  const _PhotoStrip({required this.job});

  final CustomerJob job;

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);

    final palette = AppTheme.of(context);

    return SectionCard(
    title: t('job.photosFromWorkshop'),
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
    child: SizedBox(
      height: 120,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: job.photos.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final photo = job.photos[index];

          return GestureDetector(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => PhotoViewerScreen(
                  photos: job.photos,
                  initialIndex: index,
                ),
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              child: Image.network(
                photo.url,
                width: 120,
                height: 120,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  width: 120,
                  color: palette.border,
                  child: Icon(
                    Icons.broken_image_outlined,
                    color: palette.faint,
                  ),
                ),
                loadingBuilder: (_, child, progress) => progress == null
                    ? child
                    : Container(width: 120, color: palette.border),
              ),
            ),
          );
        },
      ),
    ),
  );
  }
}

/// "How did we do?" on a finished job, and the stars once they answer.
///
/// Two states in one card rather than a prompt that disappears: a customer who
/// rated 2 stars in annoyance and later wants to change it needs to be able to
/// find the thing they tapped. Rating again edits the first one server-side.
class _RateCard extends StatelessWidget {
  const _RateCard({
    required this.job,
    required this.rating,
    required this.onRated,
  });

  final CustomerJob job;
  final JobRating? rating;
  final ValueChanged<JobRating> onRated;

  Future<void> _open(BuildContext context) async {
    final saved = await RateJobSheet.show(
      context,
      jobId: job.id,
      mechanic: job.mechanic,
      existing: rating,
    );

    if (saved == null || !context.mounted) return;

    onRated(saved);
    showSnack(context, AppText.of(context)('rate.thanks'));
  }

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);
    final palette = AppTheme.of(context);
    final given = rating;

    return AppCard(
      accent: given == null ? AppTheme.amber : null,
      child: InkWell(
        onTap: () => _open(context),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    given == null ? t('rate.prompt') : t('rate.yours'),
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: palette.text,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (given == null)
                    Text(
                      t('rate.promptSub'),
                      style: TextStyle(
                        fontSize: 12.5,
                        color: palette.faint,
                        height: 1.35,
                      ),
                    )
                  else
                    Row(
                      children: [
                        for (var star = 1; star <= 5; star++)
                          Icon(
                            star <= given.stars
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                            size: 17,
                            color: star <= given.stars
                                ? AppTheme.amber
                                : palette.border,
                          ),
                        const SizedBox(width: 8),
                        Text(
                          t('rate.tapToChange'),
                          style: TextStyle(fontSize: 11.5, color: palette.faint),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 20, color: palette.faint),
          ],
        ),
      ),
    );
  }
}
