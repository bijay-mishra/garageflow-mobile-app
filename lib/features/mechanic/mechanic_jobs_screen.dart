import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_exception.dart';
import '../../core/formatters.dart';
import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../models/job.dart';
import '../../services/mechanic_service.dart';
import '../../state/auth_controller.dart';
import '../../widgets/gradient_header.dart';
import '../../widgets/support_action.dart';
import '../../widgets/states.dart';
import '../../widgets/stat_tile.dart';
import '../../widgets/status_chip.dart';
import 'deliveries_screen.dart';
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
    final t = AppText.of(context);

    final user = context.watch<AuthController>().user;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _load,
        // Pulled down over the gradient, so it needs to be visible on blue.
        color: AppTheme.brand,
        child: ListView(
          // Always scrollable, so pull-to-refresh works even when the list is
          // empty — which is exactly when someone wants to pull.
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          children: [
            GradientHeader(
              title: t('jobs.greeting', [user?.firstName ?? '—']),
              subtitle: user?.workshop,
              leading: HeaderAvatar(initials: user?.initials ?? '?'),
              actions: [
                HeaderAction(
                  icon: Icons.local_shipping_outlined,
                  tooltip: t('driver.handovers'),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const MechanicDeliveriesScreen(),
                    ),
                  ),
                ),
                // Ask the office. Same control the customer app puts on its home
                // screen, and the server routes it by role — a mechanic's
                // question reaches their own workshop rather than the platform.
                const SupportAction(),
                HeaderAction(
                  icon: Icons.refresh_rounded,
                  tooltip: t('common.refresh'),
                  onPressed: _loading ? null : _load,
                ),
              ],
              floating: StatStrip(
                stats: [
                  Stat(
                    label: t('jobs.assigned'),
                    value: '${_summary.assignedTotal}',
                    icon: Icons.assignment_outlined,
                    color: AppTheme.brand,
                    selected: _statusFilter == null,
                    onTap: () => _filter(null),
                  ),
                  Stat(
                    label: t('jobs.inProgress'),
                    value: '${_summary.inProgress}',
                    icon: Icons.handyman_outlined,
                    color: AppTheme.cyan,
                    selected: _statusFilter == 'In Progress',
                    onTap: () => _filter('In Progress'),
                  ),
                  Stat(
                    label: t('jobs.awaitingParts'),
                    value: '${_summary.awaitingParts}',
                    icon: Icons.inventory_2_outlined,
                    color: AppTheme.amber,
                    selected: _statusFilter == 'Awaiting Parts',
                    onTap: () => _filter('Awaiting Parts'),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
              child: _buildBody(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    final t = AppText.of(context);

    if (_loading && _jobs.isEmpty) {
      return Padding(
        padding: EdgeInsets.only(top: 60),
        child: LoadingView(label: t('jobs.loading')),
      );
    }

    if (_error != null && _jobs.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 40),
        child: ErrorView(message: _error!, onRetry: _load),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // The day's headline, before any list. An overdue job is the one thing
        // on this screen that should be read before anything is scanned.
        if (_summary.overdue > 0) ...[
          _Banner(
            icon: Icons.warning_amber_rounded,
            color: AppTheme.rose,
            text: _summary.overdue == 1
                ? t('jobs.overdueOne')
                : t('jobs.overdueMany', [_summary.overdue]),
          ),
          const SizedBox(height: 16),
        ] else if (_summary.completedToday > 0) ...[
          _Banner(
            icon: Icons.task_alt_rounded,
            color: AppTheme.emerald,
            text: _summary.completedToday == 1
                ? t('jobs.doneOne')
                : t('jobs.doneMany', [_summary.completedToday]),
          ),
          const SizedBox(height: 16),
        ],

        SectionLabel(
          _statusFilter ?? t('jobs.active'),
          trailing: _statusFilter != null
              ? TextButton.icon(
                  onPressed: () => _filter(_statusFilter),
                  icon: const Icon(Icons.close_rounded, size: 15),
                  label: Text(t('jobs.clearFilter')),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                )
              : null,
        ),

        if (_jobs.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 30),
            child: EmptyView(
              icon: Icons.check_circle_outline_rounded,
              title: _statusFilter == null
                  ? t('jobs.emptyTitle')
                  : t('jobs.noneOfStatus', [_statusFilter]),
              message: _statusFilter == null
                  ? t('jobs.emptyMessage')
                  : t('jobs.tryClearing'),
            ),
          )
        else
          ..._jobs.map(
            (job) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
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

/// One line of context above the list, in the colour of what it is saying.
class _Banner extends StatelessWidget {
  const _Banner({required this.icon, required this.color, required this.text});

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    final palette = AppTheme.of(context);

    return Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    decoration: BoxDecoration(
      gradient: AppTheme.tintGradient(color),
      borderRadius: BorderRadius.circular(AppTheme.radius),
    ),
    child: Row(
      children: [
        Icon(icon, size: 19, color: color),
        const SizedBox(width: 11),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: palette.text,
              height: 1.3,
            ),
          ),
        ),
      ],
    ),
  );
  }
}

/// One job in the list. Plate first and largest — it is how a mechanic
/// identifies a car across a yard.
class _JobCard extends StatelessWidget {
  const _JobCard({required this.job, required this.onTap});

  final MechanicJob job;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = AppTheme.of(context);

    return AppCard(
    onTap: onTap,
    padding: const EdgeInsets.all(15),
    // The status is carried by the left edge instead of a coloured border
    // around the whole card, so a list of six jobs is readable at a glance
    // rather than being six competing outlines.
    accent: job.isOverdue ? AppTheme.rose : AppTheme.statusColor(job.status),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                job.vehiclePlate,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: palette.text,
                  letterSpacing: -0.3,
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
          style: TextStyle(fontSize: 12.5, color: palette.faint),
        ),

        if (job.complaint.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            // Only the first line: a complaint accumulates work notes, and
            // the list is for scanning, not reading.
            job.complaint.split('\n').first,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              color: palette.muted,
              height: 1.35,
            ),
          ),
        ],

        const SizedBox(height: 12),
        Row(
          children: [
            Icon(
              job.isOverdue
                  ? Icons.warning_amber_rounded
                  : Icons.schedule_rounded,
              size: 13,
              color: job.isOverdue ? AppTheme.rose : palette.faint,
            ),
            const SizedBox(width: 4),
            Text(
              Fmt.due(job.promisedAt),
              style: TextStyle(
                fontSize: 12,
                fontWeight: job.isOverdue ? FontWeight.w700 : FontWeight.w500,
                color: job.isOverdue ? AppTheme.rose : palette.faint,
              ),
            ),
            const Spacer(),
            if (job.photoCount > 0) ...[
              Icon(
                Icons.photo_library_outlined,
                size: 13,
                color: palette.faint,
              ),
              const SizedBox(width: 3),
              Text(
                '${job.photoCount}',
                style: TextStyle(fontSize: 12, color: palette.faint),
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
  );
  }
}
