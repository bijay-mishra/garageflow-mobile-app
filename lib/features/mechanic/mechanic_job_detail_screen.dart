import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_exception.dart';
import '../../core/formatters.dart';
import '../../core/theme.dart';
import '../../models/job.dart';
import '../../models/photo.dart';
import '../../services/mechanic_service.dart';
import '../../widgets/location_card.dart';
import '../../widgets/states.dart';
import '../../widgets/stat_tile.dart';
import '../../widgets/status_chip.dart';
import '../shared/photo_viewer.dart';
import 'add_service_sheet.dart';
import 'photo_upload_sheet.dart';
import 'update_status_sheet.dart';

/// One job: what is wrong, what it needs, and the three things a mechanic does
/// to it — move the status, attach photos, and add a service the car turns out
/// to need once it is on the ramp.
class MechanicJobDetailScreen extends StatefulWidget {
  const MechanicJobDetailScreen({super.key, required this.jobId});

  final String jobId;

  @override
  State<MechanicJobDetailScreen> createState() =>
      _MechanicJobDetailScreenState();
}

class _MechanicJobDetailScreenState extends State<MechanicJobDetailScreen> {
  bool _loading = true;
  String? _error;
  MechanicJob? _job;
  List<JobPhoto> _photos = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);

    try {
      final service = context.read<MechanicService>();
      final results = await Future.wait([
        service.job(widget.jobId),
        service.photos(widget.jobId),
      ]);

      if (!mounted) return;
      setState(() {
        _job = results[0] as MechanicJob;
        _photos = results[1] as List<JobPhoto>;
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

  Future<void> _updateStatus() async {
    final job = _job;
    if (job == null) return;

    final updated = await showModalBottomSheet<MechanicJob>(
      context: context,
      isScrollControlled: true,
      builder: (_) => UpdateStatusSheet(job: job),
    );

    if (updated != null && mounted) {
      setState(() => _job = updated);
      showSnack(context, 'Job marked ${updated.status}.');
    }
  }

  Future<void> _addService() async {
    final job = _job;
    if (job == null) return;

    final updated = await showModalBottomSheet<MechanicJob>(
      context: context,
      isScrollControlled: true,
      // Capped so the sheet cannot swallow the whole screen on a long price
      // list — the job stays visible behind it, which is the point of a sheet.
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      builder: (_) => AddServiceSheet(job: job, vehicleType: job.vehicleType),
    );

    if (updated != null && mounted) {
      setState(() => _job = updated);
      showSnack(context, 'Added to the job card. The customer has been told.');
    }
  }

  Future<void> _addPhoto() async {
    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => PhotoUploadSheet(jobId: widget.jobId),
    );

    if (added == true && mounted) {
      await _load();
      if (mounted) showSnack(context, 'Photo added.');
    }
  }

  Future<void> _deletePhoto(JobPhoto photo) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete photo?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.rose),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await context.read<MechanicService>().deletePhoto(
        widget.jobId,
        photo.id,
      );
      if (!mounted) return;
      setState(() => _photos = _photos.where((p) => p.id != photo.id).toList());
      showSnack(context, 'Photo deleted.');
    } on ApiException catch (error) {
      if (mounted) showSnack(context, error.message, isError: true);
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
          ? ErrorView(message: _error ?? 'Job not found.', onRetry: _load)
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                children: [
                  _Header(job: job),
                  const SizedBox(height: 14),
                  _Complaint(job: job),
                  const SizedBox(height: 14),
                  _Details(job: job),
                  // Only when there is a pin. Most customers will not have one,
                  // and an empty grey box on every job would read as broken.
                  if (job.hasCustomerLocation) ...[
                    const SizedBox(height: 14),
                    _Location(job: job),
                  ],
                  const SizedBox(height: 14),
                  // Always rendered now, even with no lines: it carries the
                  // "Add service" action, and a mechanic cannot add a wash to a
                  // job card that has nothing on it yet if the whole section is
                  // hidden until something is.
                  _Lines(lines: job.lines, onAddService: _addService),
                  const SizedBox(height: 14),
                  _Photos(
                    photos: _photos,
                    onAdd: _addPhoto,
                    onDelete: _deletePhoto,
                  ),
                ],
              ),
            ),
      bottomNavigationBar: job == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _addPhoto,
                        icon: const Icon(Icons.add_a_photo_outlined, size: 19),
                        label: const Text('Photo'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        onPressed: _updateStatus,
                        icon: const Icon(Icons.published_with_changes_rounded,
                            size: 19),
                        label: const Text('Update status'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.job});

  final MechanicJob job;

  @override
  Widget build(BuildContext context) => SectionCard(
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
                    job.vehicleLabel,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${job.id} · ${job.customerName}',
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppTheme.ink500,
                    ),
                  ),
                ],
              ),
            ),
            StatusChip(job.status),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: job.isOverdue
                ? AppTheme.rose.withValues(alpha: 0.08)
                : AppTheme.ink50,
            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          ),
          child: Row(
            children: [
              Icon(
                job.isOverdue
                    ? Icons.warning_amber_rounded
                    : Icons.schedule_rounded,
                size: 17,
                color: job.isOverdue ? AppTheme.rose : AppTheme.ink500,
              ),
              const SizedBox(width: 9),
              Text(
                Fmt.due(job.promisedAt),
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: job.isOverdue ? AppTheme.rose : AppTheme.ink700,
                ),
              ),
              const Spacer(),
              Text(
                Fmt.date(job.promisedAt),
                style: const TextStyle(fontSize: 12.5, color: AppTheme.ink500),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _Complaint extends StatelessWidget {
  const _Complaint({required this.job});

  final MechanicJob job;

  @override
  Widget build(BuildContext context) => SectionCard(
    title: 'COMPLAINT & NOTES',
    child: Text(
      job.complaint.isEmpty ? 'No complaint recorded.' : job.complaint,
      style: TextStyle(
        fontSize: 14,
        height: 1.5,
        color: job.complaint.isEmpty ? AppTheme.ink400 : AppTheme.ink700,
      ),
    ),
  );
}

class _Details extends StatelessWidget {
  const _Details({required this.job});

  final MechanicJob job;

  @override
  Widget build(BuildContext context) => SectionCard(
    title: 'DETAILS',
    child: Column(
      children: [
        DetailRow(label: 'Plate', value: job.vehiclePlate, bold: true),
        DetailRow(label: 'Customer', value: job.customerName),
        if (job.customerPhone.isNotEmpty)
          DetailRow(label: 'Phone', value: job.customerPhone),
        DetailRow(label: 'Odometer', value: Fmt.km(job.odometer)),
        DetailRow(
          label: 'Priority',
          value: job.priority,
          valueColor: AppTheme.priorityColor(job.priority),
          bold: job.isUrgent,
        ),
        DetailRow(label: 'Opened', value: Fmt.date(job.createdAt)),
        if (job.completedAt != null)
          DetailRow(label: 'Completed', value: Fmt.date(job.completedAt)),
      ],
    ),
  );
}

class _Location extends StatelessWidget {
  const _Location({required this.job});

  final MechanicJob job;

  @override
  Widget build(BuildContext context) => SectionCard(
    title: 'CUSTOMER LOCATION',
    child: LocationCard(
      latitude: job.customerLatitude!,
      longitude: job.customerLongitude!,
      label: job.customerName,
      address: job.customerAddress,
    ),
  );
}

class _Lines extends StatelessWidget {
  const _Lines({required this.lines, required this.onAddService});

  final List<JobLine> lines;
  final VoidCallback onAddService;

  @override
  Widget build(BuildContext context) => SectionCard(
    title: 'WORK ON THIS JOB',
    // Same affordance as the photos section above — an "Add" in the header
    // rather than a third button in the bottom bar, which would leave three
    // competing actions and no obvious primary one.
    trailing: TextButton.icon(
      onPressed: onAddService,
      icon: const Icon(Icons.add_rounded, size: 16),
      label: const Text('Service'),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    ),
    child: lines.isEmpty
        ? const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: Text(
                'Nothing costed yet.\n'
                'Add a wash or a polish if the car needs one.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppTheme.ink400),
              ),
            ),
          )
        : Column(
            children: [
              for (final line in lines)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    children: [
                      Icon(
                        line.isService
                            ? Icons.local_car_wash_rounded
                            : line.isLabour
                            ? Icons.handyman_outlined
                            : Icons.settings_outlined,
                        size: 15,
                        // Services stand out slightly — they are the lines a
                        // mechanic can add, so they are the ones worth finding.
                        color: line.isService
                            ? AppTheme.cyan
                            : AppTheme.ink400,
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          line.description,
                          style: const TextStyle(
                            fontSize: 13.5,
                            color: AppTheme.ink700,
                          ),
                        ),
                      ),
                      Text(
                        '×${Fmt.number(line.qty)}',
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppTheme.ink400,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
  );
}

class _Photos extends StatelessWidget {
  const _Photos({
    required this.photos,
    required this.onAdd,
    required this.onDelete,
  });

  final List<JobPhoto> photos;
  final VoidCallback onAdd;
  final void Function(JobPhoto) onDelete;

  @override
  Widget build(BuildContext context) => SectionCard(
    title: 'PHOTOS (${photos.length})',
    trailing: TextButton.icon(
      onPressed: onAdd,
      icon: const Icon(Icons.add_rounded, size: 16),
      label: const Text('Add'),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    ),
    child: photos.isEmpty
        ? const Padding(
            padding: EdgeInsets.symmetric(vertical: 18),
            child: Center(
              child: Text(
                'No photos yet.\nPhotos help the customer see the work.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppTheme.ink400),
              ),
            ),
          )
        : GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
            ),
            itemCount: photos.length,
            itemBuilder: (context, index) {
              final photo = photos[index];

              return GestureDetector(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        PhotoViewerScreen(photos: photos, initialIndex: index),
                  ),
                ),
                onLongPress: () => onDelete(photo),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(
                        photo.url,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          color: AppTheme.ink100,
                          child: const Icon(
                            Icons.broken_image_outlined,
                            color: AppTheme.ink400,
                          ),
                        ),
                        loadingBuilder: (_, child, progress) =>
                            progress == null
                            ? child
                            : Container(color: AppTheme.ink100),
                      ),
                      Positioned(
                        left: 4,
                        bottom: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            photo.kind,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
  );
}
