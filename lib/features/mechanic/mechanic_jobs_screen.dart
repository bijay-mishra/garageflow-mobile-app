import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_exception.dart';
import '../../core/formatters.dart';
import '../../core/theme.dart';
import '../../models/job.dart';
import '../../services/mechanic_service.dart';
import '../../state/auth_controller.dart';
import '../../widgets/states.dart';
import '../../widgets/stat_tile.dart';
import '../../widgets/status_chip.dart';
import 'mechanic_job_detail_screen.dart';

/// The mechanic's home: what they have been given, in the order it matters.
class MechanicJobsScreen extends StatefulWidget {
  const MechanicJobsScreen({super.key});

  @override
  State<MechanicJobsScreen> createState() => _MechanicJobsScreenState();
}

class _MechanicJobsScreenState extends State<MechanicJobsScreen> {
  /// null means "everything still open" — the default view.
  String? _statusFilter;

  bool _loading = true;
  String? _error;
  List<MechanicJob> _jobs = const [];
  MechanicSummary _summary = MechanicSummary.empty;

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

    try {
      final service = context.read<MechanicService>();

      // Both at once: the tiles and the list are one screen, and loading them
      // in sequence would show the user two separate spinners finishing.
      final results = await Future.wait([
        service.jobs(status: _statusFilter),
        service.summary(),
      ]);

      if (!mounted) return;
      setState(() {
        _jobs = results[0] as List<MechanicJob>;
        _summary = results[1] as MechanicSummary;
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

  void _filter(String? status) {
    setState(() => _statusFilter = _statusFilter == status ? null : status);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthController>().user;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Hi, ${user?.firstName ?? 'there'}'),
            Text(
              user?.workshop ?? '',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppTheme.ink400,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading && _jobs.isEmpty) {
      return const LoadingView(label: 'Loading your jobs…');
    }

    if (_error != null && _jobs.isEmpty) {
      return ErrorView(message: _error!, onRetry: _load);
    }

    return ListView(
      // Always scrollable, so pull-to-refresh works even when the list is
      // empty — which is exactly when someone wants to pull.
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      children: [
        _SummaryGrid(summary: _summary, onTapStatus: _filter),
        const SizedBox(height: 18),

        Row(
          children: [
            Text(
              _statusFilter ?? 'Active jobs',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppTheme.ink400,
                letterSpacing: 0.6,
              ),
            ),
            const Spacer(),
            if (_statusFilter != null)
              TextButton.icon(
                onPressed: () => _filter(_statusFilter),
                icon: const Icon(Icons.close_rounded, size: 15),
                label: const Text('Clear filter'),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),

        if (_jobs.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 40),
            child: EmptyView(
              icon: Icons.check_circle_outline_rounded,
              title: _statusFilter == null
                  ? 'Nothing on your ramp'
                  : 'No $_statusFilter jobs',
              message: _statusFilter == null
                  ? 'Jobs assigned to you will appear here.'
                  : 'Try clearing the filter.',
            ),
          )
        else
          ..._jobs.map(
            (job) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _JobCard(
                job: job,
                onTap: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => MechanicJobDetailScreen(jobId: job.id),
                    ),
                  );
                  // The detail screen can change status or add photos, so the
                  // list and tiles are stale by the time we come back.
                  if (mounted) _load();
                },
              ),
            ),
          ),
      ],
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.summary, required this.onTapStatus});

  final MechanicSummary summary;
  final void Function(String? status) onTapStatus;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Row(
        children: [
          Expanded(
            child: StatTile(
              label: 'Assigned',
              value: summary.assignedTotal,
              icon: Icons.assignment_outlined,
              color: AppTheme.brand,
              onTap: () => onTapStatus(null),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: StatTile(
              label: 'In progress',
              value: summary.inProgress,
              icon: Icons.handyman_outlined,
              color: AppTheme.cyan,
              onTap: () => onTapStatus('In Progress'),
            ),
          ),
        ],
      ),
      const SizedBox(height: 10),
      Row(
        children: [
          Expanded(
            child: StatTile(
              label: 'Awaiting parts',
              value: summary.awaitingParts,
              icon: Icons.inventory_2_outlined,
              color: AppTheme.amber,
              onTap: () => onTapStatus('Awaiting Parts'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: StatTile(
              label: summary.overdue > 0 ? 'Overdue' : 'Done today',
              value: summary.overdue > 0
                  ? summary.overdue
                  : summary.completedToday,
              icon: summary.overdue > 0
                  ? Icons.warning_amber_rounded
                  : Icons.task_alt_rounded,
              color: summary.overdue > 0 ? AppTheme.rose : AppTheme.emerald,
            ),
          ),
        ],
      ),
    ],
  );
}

/// One job in the list. Plate first and largest — it is how a mechanic
/// identifies a car across a yard.
class _JobCard extends StatelessWidget {
  const _JobCard({required this.job, required this.onTap});

  final MechanicJob job;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(AppTheme.radius),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radius),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTheme.radius),
          border: Border.all(
            // An overdue job wears its border red. It is the one thing on this
            // screen that should catch the eye before anything is read.
            color: job.isOverdue
                ? AppTheme.rose.withValues(alpha: 0.45)
                : AppTheme.ink200,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    job.vehiclePlate,
                    style: const TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.ink900,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
                StatusChip(job.status, dense: true),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              '${job.vehicleLabel} · ${job.customerName}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12.5, color: AppTheme.ink500),
            ),

            if (job.complaint.isNotEmpty) ...[
              const SizedBox(height: 9),
              Text(
                // Only the first line: a complaint accumulates work notes, and
                // the list is for scanning, not reading.
                job.complaint.split('\n').first,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.ink700,
                  height: 1.35,
                ),
              ),
            ],

            const SizedBox(height: 11),
            Row(
              children: [
                Icon(
                  job.isOverdue
                      ? Icons.warning_amber_rounded
                      : Icons.schedule_rounded,
                  size: 13,
                  color: job.isOverdue ? AppTheme.rose : AppTheme.ink400,
                ),
                const SizedBox(width: 4),
                Text(
                  Fmt.due(job.promisedAt),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: job.isOverdue
                        ? FontWeight.w700
                        : FontWeight.w500,
                    color: job.isOverdue ? AppTheme.rose : AppTheme.ink500,
                  ),
                ),
                const Spacer(),
                if (job.photoCount > 0) ...[
                  const Icon(
                    Icons.photo_library_outlined,
                    size: 13,
                    color: AppTheme.ink400,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    '${job.photoCount}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.ink400,
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                if (job.isUrgent)
                  MetaChip(
                    job.priority,
                    color: AppTheme.priorityColor(job.priority),
                    icon: Icons.priority_high_rounded,
                  ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
