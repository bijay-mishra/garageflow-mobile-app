import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_exception.dart';
import '../../core/formatters.dart';
import '../../core/theme.dart';
import '../../models/booking.dart';
import '../../models/job.dart';
import '../../models/vehicle.dart';
import '../../services/customer_service.dart';
import '../../state/auth_controller.dart';
import '../../widgets/states.dart';
import '../../widgets/stat_tile.dart';
import '../../widgets/status_chip.dart';
import 'book_service_screen.dart';
import 'customer_job_detail_screen.dart';

/// The customer's home: is my car ready, and when.
///
/// Everything above the fold answers that. Bookings and the vehicle list sit
/// underneath, because they are what you come here for second.
class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({super.key});

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  bool _loading = true;
  String? _error;
  List<CustomerJob> _jobs = const [];
  List<Vehicle> _vehicles = const [];
  List<Booking> _bookings = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);

    try {
      final service = context.read<CustomerService>();
      final results = await Future.wait([
        service.jobs(),
        service.vehicles(),
        service.bookings(),
      ]);

      if (!mounted) return;
      setState(() {
        _jobs = results[0] as List<CustomerJob>;
        _vehicles = results[1] as List<Vehicle>;
        // Only the live ones. A customer does not need a history of every
        // request they ever cancelled on their home screen.
        _bookings = (results[2] as List<Booking>)
            .where((b) => b.isOpen)
            .toList();
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

  Future<void> _book() async {
    if (_vehicles.isEmpty) {
      showSnack(
        context,
        'No vehicles on your account yet. Ask the workshop to add one.',
        isError: true,
      );
      return;
    }

    final booked = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => BookServiceScreen(vehicles: _vehicles),
      ),
    );

    if (booked == true && mounted) {
      await _load();
      if (mounted) showSnack(context, 'Booking requested.');
    }
  }

  Future<void> _cancelBooking(Booking booking) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cancel booking?'),
        content: Text(
          'Your booking for ${booking.vehiclePlate} on '
          '${Fmt.date(booking.preferredDate)} will be cancelled.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep it'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.rose),
            child: const Text('Cancel booking'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await context.read<CustomerService>().cancelBooking(booking.id);
      if (!mounted) return;
      await _load();
      if (mounted) showSnack(context, 'Booking cancelled.');
    } on ApiException catch (error) {
      if (mounted) showSnack(context, error.message, isError: true);
    }
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
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _book,
        backgroundColor: AppTheme.brand,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.event_available_rounded),
        label: const Text(
          'Book service',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: RefreshIndicator(onRefresh: _load, child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_loading) return const LoadingView(label: 'Loading your vehicles…');

    if (_error != null && _jobs.isEmpty && _vehicles.isEmpty) {
      return ErrorView(message: _error!, onRetry: _load);
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      children: [
        if (_jobs.isNotEmpty) ...[
          const _SectionLabel('IN THE WORKSHOP'),
          const SizedBox(height: 10),
          ..._jobs.map(
            (job) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ActiveJobCard(
                job: job,
                onTap: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => CustomerJobDetailScreen(jobId: job.id),
                    ),
                  );
                  if (mounted) _load();
                },
              ),
            ),
          ),
          const SizedBox(height: 18),
        ],

        if (_bookings.isNotEmpty) ...[
          const _SectionLabel('YOUR BOOKINGS'),
          const SizedBox(height: 10),
          ..._bookings.map(
            (booking) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _BookingCard(
                booking: booking,
                onCancel: () => _cancelBooking(booking),
              ),
            ),
          ),
          const SizedBox(height: 18),
        ],

        const _SectionLabel('YOUR VEHICLES'),
        const SizedBox(height: 10),

        if (_vehicles.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 24),
            child: EmptyView(
              icon: Icons.directions_car_outlined,
              title: 'No vehicles yet',
              message:
                  'The workshop adds vehicles to your account when you first '
                  'bring one in.',
            ),
          )
        else
          ..._vehicles.map(
            (vehicle) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _VehicleCard(vehicle: vehicle),
            ),
          ),

        if (_jobs.isEmpty && _vehicles.isNotEmpty) ...[
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.emerald.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(AppTheme.radius),
              border: Border.all(
                color: AppTheme.emerald.withValues(alpha: 0.25),
              ),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.check_circle_outline_rounded,
                  color: AppTheme.emerald,
                  size: 22,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Nothing in the workshop right now.',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.ink700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      fontSize: 11.5,
      fontWeight: FontWeight.w700,
      color: AppTheme.ink400,
      letterSpacing: 0.7,
    ),
  );
}

/// The headline card: a car currently being worked on, with its progress.
class _ActiveJobCard extends StatelessWidget {
  const _ActiveJobCard({required this.job, required this.onTap});

  final CustomerJob job;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.statusColor(job.status);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppTheme.radius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        child: Container(
          padding: const EdgeInsets.all(16),
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          job.vehicleLabel,
                          style: const TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.ink900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          job.vehiclePlate,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: AppTheme.ink500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  StatusChip(job.status, dense: true),
                ],
              ),
              const SizedBox(height: 14),
              ProgressBar(percent: job.progressPct, color: color),
              const SizedBox(height: 9),
              Row(
                children: [
                  Text(
                    '${job.progressPct}% complete',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                  const Spacer(),
                  const Icon(
                    Icons.schedule_rounded,
                    size: 13,
                    color: AppTheme.ink400,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Ready ${Fmt.shortDate(job.promisedAt)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.ink500,
                    ),
                  ),
                ],
              ),
              if (job.photos.isNotEmpty) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(
                      Icons.photo_library_outlined,
                      size: 14,
                      color: AppTheme.brand,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '${job.photos.length} photo'
                      '${job.photos.length == 1 ? '' : 's'} from the workshop',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.brand,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _BookingCard extends StatelessWidget {
  const _BookingCard({required this.booking, required this.onCancel});

  final Booking booking;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
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
                '${booking.vehiclePlate} · ${Fmt.dayAndDate(booking.preferredDate)}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.ink900,
                ),
              ),
            ),
            StatusChip(booking.status, dense: true),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          booking.explanation,
          style: const TextStyle(
            fontSize: 12.5,
            color: AppTheme.ink500,
            height: 1.35,
          ),
        ),
        if (booking.preferredTime.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            'Preferred time: ${booking.preferredTime}',
            style: const TextStyle(fontSize: 12, color: AppTheme.ink400),
          ),
        ],

        // The extras and what they were quoted at. Shown back rather than left
        // to memory: this is the number the workshop is holding to, and a
        // customer should be able to check it without ringing anyone.
        if (booking.services.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
            decoration: BoxDecoration(
              color: AppTheme.ink50,
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final extra in booking.services)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.check_rounded,
                          size: 13,
                          color: AppTheme.emerald,
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            extra.name,
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: AppTheme.ink700,
                            ),
                          ),
                        ),
                        Text(
                          extra.price == 0 ? 'Free' : Fmt.rs(extra.price),
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.ink700,
                          ),
                        ),
                      ],
                    ),
                  ),
                const Divider(height: 11),
                Row(
                  children: [
                    const Text(
                      'Extras estimate',
                      style: TextStyle(fontSize: 12, color: AppTheme.ink500),
                    ),
                    const Spacer(),
                    Text(
                      Fmt.rs(booking.estimatedTotal),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.ink900,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: onCancel,
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.rose,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Cancel booking'),
          ),
        ),
      ],
    ),
  );
}

class _VehicleCard extends StatelessWidget {
  const _VehicleCard({required this.vehicle});

  final Vehicle vehicle;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppTheme.radius),
      border: Border.all(color: AppTheme.ink200),
    ),
    child: Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: AppTheme.brandLight,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            switch (vehicle.type) {
              'Bike' => Icons.two_wheeler_rounded,
              'Bus' => Icons.directions_bus_rounded,
              'Truck' => Icons.local_shipping_rounded,
              'Van' => Icons.airport_shuttle_rounded,
              'Tractor' => Icons.agriculture_rounded,
              _ => Icons.directions_car_rounded,
            },
            size: 21,
            color: AppTheme.brand,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                vehicle.label,
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.ink900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${vehicle.plate} · ${Fmt.km(vehicle.odometer)}',
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AppTheme.ink500,
                ),
              ),
              if (vehicle.lastServiceDate != null) ...[
                const SizedBox(height: 3),
                Text(
                  'Last service ${Fmt.date(vehicle.lastServiceDate)}',
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppTheme.ink400,
                  ),
                ),
              ],
            ],
          ),
        ),
        MetaChip(vehicle.type),
      ],
    ),
  );
}
