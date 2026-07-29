import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_exception.dart';
import '../../core/formatters.dart';
import '../../core/theme.dart';
import '../../models/service.dart';
import '../../models/vehicle.dart';
import '../../services/catalogue_service.dart';
import '../../services/customer_service.dart';
import '../../widgets/service_tile.dart';
import '../../widgets/states.dart';

/// Ask the workshop to look at a vehicle.
///
/// Four questions: which car, what is wrong, when, and is there anything else
/// you want doing while it is in. The last one is optional and priced — a
/// customer who would never ring up to ask for a wash will happily tick one.
class BookServiceScreen extends StatefulWidget {
  const BookServiceScreen({super.key, required this.vehicles});

  final List<Vehicle> vehicles;

  @override
  State<BookServiceScreen> createState() => _BookServiceScreenState();
}

class _BookServiceScreenState extends State<BookServiceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _complaint = TextEditingController();

  late String _vehicleId = widget.vehicles.first.id;
  late DateTime _date = DateTime.now().add(const Duration(days: 1));
  String _time = 'Morning';
  bool _saving = false;

  /// The extras on offer for the chosen vehicle, and what has been ticked.
  ///
  /// Reloaded when the vehicle changes: a bike wash and a heavy vehicle wash
  /// are different rows at different prices, and the server decides which
  /// applies rather than the app guessing.
  List<WorkshopService> _extras = [];
  final Set<String> _chosen = {};
  bool _loadingExtras = true;

  /// Coarse slots rather than a time picker. A workshop does not run to the
  /// minute, and asking for one implies a precision the shop cannot honour.
  static const _slots = ['Morning', 'Afternoon', 'Evening', 'Any time'];

  Vehicle get _vehicle =>
      widget.vehicles.firstWhere((v) => v.id == _vehicleId);

  double get _estimate => _extras
      .where((s) => _chosen.contains(s.id))
      .fold(0.0, (sum, s) => sum + s.price);

  @override
  void initState() {
    super.initState();
    _loadExtras();
  }

  @override
  void dispose() {
    _complaint.dispose();
    super.dispose();
  }

  Future<void> _loadExtras() async {
    setState(() => _loadingExtras = true);

    try {
      final services = await context.read<CatalogueService>().services(
        vehicleType: _vehicle.type,
      );

      if (!mounted) return;

      setState(() {
        _extras = services;
        // Anything ticked that this vehicle cannot have is dropped rather than
        // left to fail on submit — switching from the car to the bike should
        // not carry a car wash across.
        _chosen.retainWhere((id) => services.any((s) => s.id == id));
        _loadingExtras = false;
      });
    } on ApiException {
      // A price list that will not load must not block a booking. The customer
      // can still describe the problem, which is the part that matters.
      if (mounted) setState(() => _loadingExtras = false);
    }
  }

  void _selectVehicle(String id) {
    if (id == _vehicleId) return;
    setState(() => _vehicleId = id);
    _loadExtras();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      // The server rejects a date before today, so the picker will not offer
      // one — the rule is enforced in both places, not just the server.
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 120)),
    );

    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    try {
      await context.read<CustomerService>().book(
        vehicleId: _vehicleId,
        complaint: _complaint.text,
        preferredDate: _date,
        preferredTime: _time,
        serviceIds: _chosen.toList(),
      );

      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      showSnack(context, error.message, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Book a service')),
    body: Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
        children: [
          const _Label('WHICH VEHICLE?'),
          const SizedBox(height: 10),
          ...widget.vehicles.map(
            (vehicle) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _VehicleOption(
                vehicle: vehicle,
                selected: _vehicleId == vehicle.id,
                onTap: () => _selectVehicle(vehicle.id),
              ),
            ),
          ),

          const SizedBox(height: 20),
          const _Label('WHAT IS WRONG?'),
          const SizedBox(height: 10),
          TextFormField(
            controller: _complaint,
            maxLines: 4,
            maxLength: 1000,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText:
                  'Describe what you have noticed — a noise, a warning light, '
                  'or just a routine service.',
              alignLabelWithHint: true,
            ),
            validator: (value) => (value == null || value.trim().isEmpty)
                ? 'Tell the workshop what to look at'
                : null,
          ),

          const SizedBox(height: 10),
          const _Label('WHEN SUITS YOU?'),
          const SizedBox(height: 10),

          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            child: InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              child: Container(
                height: 56,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                  border: Border.all(color: AppTheme.ink200),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.calendar_today_rounded,
                      size: 19,
                      color: AppTheme.ink500,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      Fmt.dayAndDate(_date),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.ink900,
                      ),
                    ),
                    const Spacer(),
                    const Icon(
                      Icons.expand_more_rounded,
                      color: AppTheme.ink400,
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final slot in _slots)
                ChoiceChip(
                  label: Text(slot),
                  selected: _time == slot,
                  onSelected: (_) => setState(() => _time = slot),
                  selectedColor: AppTheme.brand.withValues(alpha: 0.12),
                  labelStyle: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _time == slot ? AppTheme.brand : AppTheme.ink700,
                  ),
                  side: BorderSide(
                    color: _time == slot ? AppTheme.brand : AppTheme.ink200,
                  ),
                ),
            ],
          ),

          const SizedBox(height: 22),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Expanded(child: _Label('ANYTHING ELSE WHILE IT IS IN?')),
              if (_chosen.isNotEmpty)
                Text(
                  '${_chosen.length} added',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.brand,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Optional extras for your ${_vehicle.type.toLowerCase()}. '
            'Prices are held at what you see here.',
            style: const TextStyle(fontSize: 12.5, color: AppTheme.ink500),
          ),
          const SizedBox(height: 10),

          if (_loadingExtras)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.2),
                ),
              ),
            )
          else if (_extras.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                border: Border.all(color: AppTheme.ink200),
              ),
              child: const Text(
                'The workshop has not listed any extras yet.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5, color: AppTheme.ink400),
              ),
            )
          else
            ...(_extras.map(
              (service) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ServiceTile(
                  service: service,
                  selected: _chosen.contains(service.id),
                  onTap: () => setState(() {
                    if (!_chosen.remove(service.id)) _chosen.add(service.id);
                  }),
                ),
              ),
            )),

          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: AppTheme.brandLight,
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 17,
                  color: AppTheme.brand,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'This is a request. The workshop will confirm the date, and '
                    'you will get a notification either way.',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: AppTheme.brandDark,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
    bottomNavigationBar: SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppTheme.ink100)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Only shown once something is ticked. A permanent "Rs 0" on a
            // screen whose main job is describing a fault reads as a price for
            // the repair, which is exactly what it is not.
            if (_chosen.isNotEmpty) ...[
              Row(
                children: [
                  const Text(
                    'Extras estimate',
                    style: TextStyle(fontSize: 13, color: AppTheme.ink500),
                  ),
                  const Spacer(),
                  Text(
                    Fmt.rs(_estimate),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.ink900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'The repair itself is quoted after the workshop has looked at it.',
                style: TextStyle(fontSize: 11.5, color: AppTheme.ink400),
              ),
              const SizedBox(height: 10),
            ],
            FilledButton(
              onPressed: _saving ? null : _submit,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  : const Text('Request booking'),
            ),
          ],
        ),
      ),
    ),
  );
}

class _Label extends StatelessWidget {
  const _Label(this.text);

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

class _VehicleOption extends StatelessWidget {
  const _VehicleOption({
    required this.vehicle,
    required this.selected,
    required this.onTap,
  });

  final Vehicle vehicle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: selected ? AppTheme.brandLight : Colors.white,
    borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          border: Border.all(
            color: selected ? AppTheme.brand : AppTheme.ink200,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    vehicle.label,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: selected ? AppTheme.brandDark : AppTheme.ink900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    vehicle.plate,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppTheme.ink500,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: selected ? AppTheme.brand : AppTheme.ink200,
              size: 21,
            ),
          ],
        ),
      ),
    ),
  );
}
