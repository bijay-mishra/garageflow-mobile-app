import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_exception.dart';
import '../../core/formatters.dart';
import '../../core/theme.dart';
import '../../models/job.dart';
import '../../services/customer_service.dart';
import '../../widgets/states.dart';
import '../../widgets/stat_tile.dart';
import '../../widgets/status_chip.dart';
import '../shared/photo_viewer.dart';

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
    final job = _job;

    return Scaffold(
      appBar: AppBar(title: Text(job?.vehiclePlate ?? widget.jobId)),
      body: _loading
          ? const LoadingView()
          : job == null
          ? ErrorView(message: _error ?? 'Not found.', onRetry: _load)
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  _ProgressCard(job: job),
                  const SizedBox(height: 14),
                  SectionCard(
                    title: 'WHAT WE ARE LOOKING AT',
                    child: Text(
                      job.complaint.isEmpty
                          ? 'No details recorded.'
                          // Only the customer's own words. Everything after a
                          // newline is the mechanic's internal work notes, which
                          // are not written for the customer to read.
                          : job.complaint.split('\n').first,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        color: AppTheme.ink700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SectionCard(
                    title: 'DATES',
                    child: Column(
                      children: [
                        DetailRow(
                          label: 'Booked in',
                          value: Fmt.date(job.createdAt),
                        ),
                        DetailRow(
                          label: 'Ready by',
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
            style: const TextStyle(fontSize: 12.5, color: AppTheme.ink500),
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
                    'Open' => 'Booked in, work has not started yet.',
                    'In Progress' => 'Being worked on now.',
                    'Awaiting Parts' => 'Waiting for parts to arrive.',
                    'Completed' => 'Work finished — ready for collection.',
                    'Delivered' => 'Collected. Thank you!',
                    'Cancelled' => 'This job was cancelled.',
                    _ => '',
                  },
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppTheme.ink500,
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
  Widget build(BuildContext context) => SectionCard(
    title: 'WORK & PARTS',
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
                        style: const TextStyle(
                          fontSize: 13.5,
                          color: AppTheme.ink700,
                        ),
                      ),
                      Text(
                        '${Fmt.number(line.qty)} × ${Fmt.rs(line.unitPrice)}',
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: AppTheme.ink400,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  Fmt.rs(line.total),
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.ink900,
                  ),
                ),
              ],
            ),
          ),
        const Divider(height: 22),
        Row(
          children: [
            const Text(
              'Estimated total',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppTheme.ink900,
              ),
            ),
            const Spacer(),
            Text(
              Fmt.rs(job.total),
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppTheme.ink900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        const Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Before tax. Your invoice is the final figure.',
            style: TextStyle(fontSize: 11.5, color: AppTheme.ink400),
          ),
        ),
      ],
    ),
  );
}

class _PhotoStrip extends StatelessWidget {
  const _PhotoStrip({required this.job});

  final CustomerJob job;

  @override
  Widget build(BuildContext context) => SectionCard(
    title: 'PHOTOS FROM THE WORKSHOP',
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
                  color: AppTheme.ink100,
                  child: const Icon(
                    Icons.broken_image_outlined,
                    color: AppTheme.ink400,
                  ),
                ),
                loadingBuilder: (_, child, progress) => progress == null
                    ? child
                    : Container(width: 120, color: AppTheme.ink100),
              ),
            ),
          );
        },
      ),
    ),
  );
}
