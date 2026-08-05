import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_exception.dart';
import '../../core/formatters.dart';
import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../models/booking.dart';
import '../../models/delivery.dart';
import '../../models/job.dart';
import '../../models/vehicle.dart';
import '../../services/customer_service.dart';
import '../../services/delivery_service.dart';
import '../../state/auth_controller.dart';
import '../../widgets/gradient_header.dart';
import '../../widgets/states.dart';
import '../../widgets/stat_tile.dart';
import '../../widgets/status_chip.dart';
import 'add_vehicle_screen.dart';
import 'book_service_screen.dart';
import 'customer_job_detail_screen.dart';
import 'garage_directory_screen.dart';
import 'handover_sheet.dart';
import 'support_screen.dart';
import 'track_delivery_screen.dart';

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
  List<Delivery> _handovers = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);

    try {
      final service = context.read<CustomerService>();
      final deliveries = context.read<DeliveryApi>();

      final results = await Future.wait([
        service.jobs(),
        service.vehicles(),
        service.bookings(),
        // Handovers are on the home screen rather than a tab of their own
        // because "your car is ready, how do you want it back" is the single
        // most time-sensitive thing this app ever has to say.
        deliveries.list(),
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
        _handovers = results[3] as List<Delivery>;
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

  /// Opens the add-vehicle form. Returns true if one was actually added.
  Future<bool> _addVehicle() async {
    final t = AppText.of(context);

    final vehicle = await Navigator.of(context).push<Vehicle>(
      MaterialPageRoute(builder: (_) => const AddVehicleScreen()),
    );

    if (vehicle == null || !mounted) return false;

    // Reloaded rather than appended: the server assigns the id and fills in
    // fields the form never asked about, and a locally-built Vehicle would be
    // a slightly different object from the one every other screen sees.
    await _load();
    if (mounted) showSnack(context, t('vehicle.added', [vehicle.plate]));

    return true;
  }

  Future<void> _book() async {
    final t = AppText.of(context);

    // Nothing to book against yet. Refusing here is what the app used to do,
    // and it left the customer holding an error with no way out of it — the
    // vehicle could only be added by the workshop. Asking for the vehicle at
    // exactly the moment they need one, then carrying on into the booking they
    // originally asked for, turns the dead end into the first step.
    if (_vehicles.isEmpty) {
      // Deliberately not an error: they have done nothing wrong. The snack
      // outlives the route change, so it reads as a caption on the form they
      // are about to land on.
      showSnack(context, t('home.noVehiclesSnack'));

      if (!await _addVehicle() || !mounted) return;
    }

    final booked = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => BookServiceScreen(vehicles: _vehicles),
      ),
    );

    if (booked == true && mounted) {
      await _load();
      if (mounted) showSnack(context, t('home.bookingRequested'));
    }
  }

  Future<void> _cancelBooking(Booking booking) async {
    final t = AppText.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(t('home.cancelTitle')),
        content: Text(
          t('home.cancelBody', [
            booking.vehiclePlate,
            Fmt.date(booking.preferredDate),
          ]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(t('home.keepIt')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.rose),
            child: Text(t('home.cancelBooking')),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await context.read<CustomerService>().cancelBooking(booking.id);
      if (!mounted) return;
      await _load();
      if (mounted) showSnack(context, t('home.bookingCancelled'));
    } on ApiException catch (error) {
      if (mounted) showSnack(context, error.message, isError: true);
    }
  }

  Future<void> _openHandover(Delivery handover) async {
    if (handover.awaitingChoice) {
      if (await showHandoverSheet(context, handover) && mounted) _load();
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TrackDeliveryScreen(deliveryId: handover.id),
      ),
    );
    if (mounted) _load();
  }

  Future<void> _switchGarage() async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const GarageDirectoryScreen()),
    );
    // The token may now point at a different garage, so everything on this
    // screen belongs to a different set of books.
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);

    final user = context.watch<AuthController>().user;

    // The one handover that deserves the headline slot: something the customer
    // has to answer, or something currently on the road.
    final urgent = _handovers.where((h) => h.awaitingChoice).firstOrNull ??
        _handovers.where((h) => h.isOnTheWay).firstOrNull;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _book,
        backgroundColor: AppTheme.brand,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.event_available_rounded),
        label: Text(
          t('home.bookService'),
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppTheme.brand,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          children: [
            GradientHeader(
              title: t('jobs.greeting', [user?.firstName ?? '—']),
              subtitle: user?.workshop,
              leading: HeaderAvatar(initials: user?.initials ?? '?'),
              actions: [
                HeaderAction(
                  icon: Icons.storefront_outlined,
                  tooltip: t('home.yourGarages'),
                  onPressed: _switchGarage,
                ),
                // On the screen people land on, because the question they want
                // to ask is almost always about something they can see here.
                HeaderAction(
                  icon: Icons.support_agent_rounded,
                  tooltip: t('support.title'),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SupportScreen()),
                  ),
                ),
              ],
              // The headline card. A handover awaiting an answer outranks
              // everything; otherwise the car being worked on; otherwise a
              // prompt to book.
              floating: urgent != null
                  ? _HandoverCard(
                      handover: urgent,
                      onTap: () => _openHandover(urgent),
                    )
                  : _jobs.isNotEmpty
                  ? _ActiveJobCard(
                      job: _jobs.first,
                      onTap: () => _openJob(_jobs.first),
                    )
                  : _QuietCard(
                      hasVehicles: _vehicles.isNotEmpty,
                      loading: _loading,
                      onBook: _book,
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
              child: _buildBody(),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openJob(CustomerJob job) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CustomerJobDetailScreen(jobId: job.id),
      ),
    );
    if (mounted) _load();
  }

  Widget _buildBody() {
    final t = AppText.of(context);

    if (_loading) {
      return Padding(
        padding: EdgeInsets.only(top: 40),
        child: LoadingView(label: t('home.loading')),
      );
    }

    if (_error != null && _jobs.isEmpty && _vehicles.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 30),
        child: ErrorView(message: _error!, onRetry: _load),
      );
    }

    // The headline card already carries the first one.
    final restOfJobs = _handovers.any((h) => h.awaitingChoice || h.isOnTheWay)
        ? _jobs
        : _jobs.skip(1).toList();

    final otherHandovers = _handovers
        .where((h) => !h.awaitingChoice && !h.isOnTheWay)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (restOfJobs.isNotEmpty) ...[
          SectionLabel(t('home.inWorkshop')),
          for (final job in restOfJobs)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _ActiveJobCard(job: job, onTap: () => _openJob(job)),
            ),
          const SizedBox(height: 20),
        ],

        if (otherHandovers.isNotEmpty) ...[
          SectionLabel(t('home.readyForYou')),
          for (final handover in otherHandovers)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _HandoverCard(
                handover: handover,
                onTap: () => _openHandover(handover),
              ),
            ),
          const SizedBox(height: 20),
        ],

        if (_bookings.isNotEmpty) ...[
          SectionLabel(t('home.yourBookings')),
          for (final booking in _bookings)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _BookingCard(
                booking: booking,
                onCancel: () => _cancelBooking(booking),
              ),
            ),
          const SizedBox(height: 20),
        ],

        SectionLabel(
          t('home.yourVehicles'),
          // Only once there is a list to add to. On an empty account the
          // empty state below carries the button, and two of them a hundred
          // pixels apart asking for the same thing is just noise.
          trailing: _vehicles.isEmpty
              ? null
              : TextButton.icon(
                  onPressed: _addVehicle,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: Text(t('vehicle.addCta')),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
        ),
        if (_vehicles.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: EmptyView(
              icon: Icons.directions_car_outlined,
              title: t('home.noVehiclesTitle'),
              message: t('home.noVehiclesMessage'),
              action: FilledButton.icon(
                onPressed: _addVehicle,
                icon: const Icon(Icons.add_rounded, size: 19),
                label: Text(t('vehicle.addCta')),
              ),
            ),
          )
        else
          for (final vehicle in _vehicles)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _VehicleCard(vehicle: vehicle),
            ),
      ],
    );
  }
}

/// The headline when a vehicle is finished: either a question the customer has
/// to answer, or a car on its way to them.
class _HandoverCard extends StatelessWidget {
  const _HandoverCard({required this.handover, required this.onTap});

  final Delivery handover;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);

    final palette = AppTheme.of(context);

    final needsAnswer = handover.awaitingChoice;
    final color = needsAnswer ? AppTheme.amber : AppTheme.brand;

    return AppCard(
      onTap: onTap,
      lifted: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  needsAnswer
                      ? Icons.check_circle_outline_rounded
                      : Icons.local_shipping_rounded,
                  size: 20,
                  color: color,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      handover.headline,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: palette.text,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${handover.vehicleLabel} · ${handover.vehiclePlate}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: palette.faint,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text(
                  needsAnswer
                      ? t('home.chooseHandover')
                      : handover.driver.isEmpty
                      ? t('home.followMap')
                      : '${handover.driver} is bringing it',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
              Icon(Icons.arrow_forward_rounded, size: 17, color: color),
            ],
          ),
        ],
      ),
    );
  }
}

/// The card in the headline slot when nothing is in the workshop.
class _QuietCard extends StatelessWidget {
  const _QuietCard({
    required this.hasVehicles,
    required this.loading,
    required this.onBook,
  });

  final bool hasVehicles;
  final bool loading;
  final VoidCallback onBook;

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);

    final palette = AppTheme.of(context);

    return AppCard(
    lifted: true,
    // Tappable with no vehicles too: the caption below now offers to add one,
    // and `onBook` opens the form before the booking. A card that advertises
    // the next step and then does nothing when you press it is worse than one
    // that says nothing at all.
    onTap: loading ? null : onBook,
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
            Icons.check_circle_outline_rounded,
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
                loading ? t('home.checkingVehicles') : t('home.nothingIn'),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: palette.text,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                loading
                    ? t('home.oneMoment')
                    : hasVehicles
                    ? t('home.tapToBook')
                    : t('home.askWorkshop'),
                style: TextStyle(fontSize: 12.5, color: palette.faint),
              ),
            ],
          ),
        ),
        if (!loading)
          Icon(
            Icons.chevron_right_rounded,
            size: 22,
            color: palette.faint,
          ),
      ],
    ),
  );
  }
}

/// A car currently being worked on, with its progress.
class _ActiveJobCard extends StatelessWidget {
  const _ActiveJobCard({required this.job, required this.onTap});

  final CustomerJob job;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);

    final palette = AppTheme.of(context);

    final color = AppTheme.statusColor(job.status);

    return AppCard(
      onTap: onTap,
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
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        color: palette.text,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      job.vehiclePlate,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: palette.faint,
                      ),
                    ),
                  ],
                ),
              ),
              StatusChip(job.status, dense: true),
            ],
          ),
          const SizedBox(height: 15),
          ProgressBar(percent: job.progressPct, color: color),
          const SizedBox(height: 9),
          Row(
            children: [
              Text(
                t('home.percentComplete', [job.progressPct]),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              const Spacer(),
              Icon(
                Icons.schedule_rounded,
                size: 13,
                color: palette.faint,
              ),
              const SizedBox(width: 4),
              Text(
                t('home.ready', [Fmt.shortDate(job.promisedAt)]),
                style: TextStyle(fontSize: 12, color: palette.faint),
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
    );
  }
}

class _BookingCard extends StatelessWidget {
  const _BookingCard({required this.booking, required this.onCancel});

  final Booking booking;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);

    final palette = AppTheme.of(context);

    return AppCard(
    padding: const EdgeInsets.all(15),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${booking.vehiclePlate} · '
                '${Fmt.dayAndDate(booking.preferredDate)}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: palette.text,
                ),
              ),
            ),
            StatusChip(booking.status, dense: true),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          booking.explanation,
          style: TextStyle(
            fontSize: 12.5,
            color: palette.faint,
            height: 1.35,
          ),
        ),
        if (booking.preferredTime.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            t('home.preferredTime', [booking.preferredTime]),
            style: TextStyle(fontSize: 12, color: palette.faint),
          ),
        ],

        // The extras and what they were quoted at. Shown back rather than left
        // to memory: this is the number the workshop is holding to, and a
        // customer should be able to check it without ringing anyone.
        if (booking.services.isNotEmpty) ...[
          const SizedBox(height: 11),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
            decoration: BoxDecoration(
              color: palette.field,
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
                            style: TextStyle(
                              fontSize: 12.5,
                              color: palette.muted,
                            ),
                          ),
                        ),
                        Text(
                          extra.price == 0 ? 'Free' : Fmt.rs(extra.price),
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: palette.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                const Divider(height: 11),
                Row(
                  children: [
                    Text(
                      t('home.extrasEstimate'),
                      style: TextStyle(fontSize: 12, color: palette.faint),
                    ),
                    const Spacer(),
                    Text(
                      Fmt.rs(booking.estimatedTotal),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: palette.text,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 6),
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
            child: Text(t('home.cancelBooking')),
          ),
        ),
      ],
    ),
  );
  }
}

class _VehicleCard extends StatelessWidget {
  const _VehicleCard({required this.vehicle});

  final Vehicle vehicle;

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);

    final palette = AppTheme.of(context);

    return AppCard(
    padding: const EdgeInsets.all(14),
    child: Row(
      children: [
        Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: AppTheme.tintGradient(AppTheme.brand),
            borderRadius: BorderRadius.circular(11),
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
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: palette.text,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${vehicle.plate} · ${Fmt.km(vehicle.odometer)}',
                style: TextStyle(fontSize: 12.5, color: palette.faint),
              ),
              if (vehicle.lastServiceDate != null) ...[
                const SizedBox(height: 3),
                Text(
                  t('home.lastService', [Fmt.date(vehicle.lastServiceDate)]),
                  style: TextStyle(
                    fontSize: 11.5,
                    color: palette.faint,
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
}
