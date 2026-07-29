import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_exception.dart';
import '../../core/formatters.dart';
import '../../core/theme.dart';
import '../../models/job.dart';
import '../../services/customer_service.dart';
import '../../widgets/states.dart';
import 'customer_job_detail_screen.dart';

/// Every completed service, newest first.
///
/// Drawn as a timeline rather than a list: the value of this screen is the
/// shape of the record — how often the car comes in, how long between visits —
/// and a rail with dots on it shows that at a glance.
class ServiceHistoryScreen extends StatefulWidget {
  const ServiceHistoryScreen({super.key});

  @override
  State<ServiceHistoryScreen> createState() => _ServiceHistoryScreenState();
}

class _ServiceHistoryScreenState extends State<ServiceHistoryScreen> {
  bool _loading = true;
  String? _error;
  List<CustomerJob> _jobs = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);

    try {
      final jobs = await context.read<CustomerService>().serviceHistory();
      if (!mounted) return;
      setState(() {
        _jobs = jobs;
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
    final spent = _jobs.fold<double>(0, (sum, job) => sum + job.total);

    return Scaffold(
      appBar: AppBar(title: const Text('Service history')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const LoadingView(label: 'Loading your history…')
            : _error != null && _jobs.isEmpty
            ? ErrorView(message: _error!, onRetry: _load)
            : _jobs.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 80),
                  EmptyView(
                    icon: Icons.history_rounded,
                    title: 'No completed services yet',
                    message:
                        'Once the workshop finishes a job, it appears here as '
                        'a permanent record.',
                  ),
                ],
              )
            : ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
                children: [
                  _SummaryStrip(count: _jobs.length, spent: spent),
                  const SizedBox(height: 20),
                  for (var i = 0; i < _jobs.length; i++)
                    _TimelineEntry(
                      job: _jobs[i],
                      isFirst: i == 0,
                      isLast: i == _jobs.length - 1,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              CustomerJobDetailScreen(jobId: _jobs[i].id),
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({required this.count, required this.spent});

  final int count;
  final double spent;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppTheme.brand,
      borderRadius: BorderRadius.circular(AppTheme.radius),
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$count',
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                count == 1 ? 'service' : 'services',
                style: TextStyle(
                  fontSize: 12.5,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ),
        Container(
          width: 1,
          height: 40,
          color: Colors.white.withValues(alpha: 0.25),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                Fmt.rs(spent),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'total work',
                style: TextStyle(
                  fontSize: 12.5,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _TimelineEntry extends StatelessWidget {
  const _TimelineEntry({
    required this.job,
    required this.isFirst,
    required this.isLast,
    required this.onTap,
  });

  final CustomerJob job;
  final bool isFirst;
  final bool isLast;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => IntrinsicHeight(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // The rail: a line with a dot on it. IntrinsicHeight above is what lets
        // the line stretch to whatever height the card next to it turns out to
        // be.
        SizedBox(
          width: 28,
          child: Column(
            children: [
              Container(
                width: 2,
                height: 6,
                color: isFirst ? Colors.transparent : AppTheme.ink200,
              ),
              Container(
                width: 11,
                height: 11,
                decoration: BoxDecoration(
                  color: AppTheme.emerald,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
              Expanded(
                child: Container(
                  width: 2,
                  color: isLast ? Colors.transparent : AppTheme.ink200,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppTheme.radius),
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(AppTheme.radius),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppTheme.radius),
                    border: Border.all(color: AppTheme.ink200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              Fmt.date(job.completedAt),
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.ink900,
                              ),
                            ),
                          ),
                          Text(
                            Fmt.rs(job.total),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.ink900,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${job.vehicleLabel} · ${job.vehiclePlate}',
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppTheme.ink500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        job.complaint.split('\n').first,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.ink700,
                          height: 1.35,
                        ),
                      ),
                      if (job.lines.isNotEmpty || job.photos.isNotEmpty) ...[
                        const SizedBox(height: 9),
                        Row(
                          children: [
                            if (job.lines.isNotEmpty) ...[
                              const Icon(
                                Icons.build_outlined,
                                size: 12,
                                color: AppTheme.ink400,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${job.lines.length} item'
                                '${job.lines.length == 1 ? '' : 's'}',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  color: AppTheme.ink400,
                                ),
                              ),
                              const SizedBox(width: 12),
                            ],
                            if (job.photos.isNotEmpty) ...[
                              const Icon(
                                Icons.photo_library_outlined,
                                size: 12,
                                color: AppTheme.ink400,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${job.photos.length}',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  color: AppTheme.ink400,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
