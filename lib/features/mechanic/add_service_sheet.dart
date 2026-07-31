import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_exception.dart';
import '../../core/formatters.dart';
import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../models/job.dart';
import '../../models/service.dart';
import '../../services/catalogue_service.dart';
import '../../services/mechanic_service.dart';
import '../../widgets/service_tile.dart';
import '../../widgets/states.dart';

/// Adds services from the workshop's price list to a job.
///
/// The case this exists for: the car is up on the ramp, it is filthy underneath,
/// and the mechanic can see it needs an underbody wash that nobody booked. Under
/// the old model that had to wait for someone at the desk to remember; now it is
/// two taps, and the customer is told.
///
/// What the mechanic picks is a *service*, never a price. There is no amount to
/// type here — the server reads it from the catalogue — which is what makes this
/// safe to put in the hands of everyone on the floor.
class AddServiceSheet extends StatefulWidget {
  const AddServiceSheet({super.key, required this.job, this.vehicleType});

  final MechanicJob job;

  /// Body class of the vehicle, when the caller knows it. Used to lead with the
  /// services that suit it; the rest are still reachable below.
  final String? vehicleType;

  @override
  State<AddServiceSheet> createState() => _AddServiceSheetState();
}

class _AddServiceSheetState extends State<AddServiceSheet> {
  List<WorkshopService> _services = [];
  final Set<String> _chosen = {};

  bool _loading = true;
  bool _saving = false;
  String? _loadError;

  /// Catalogue ids already on the job — shown ticked out rather than hidden, so
  /// it is obvious the wash is not missing, it is already there.
  late final Set<String> _alreadyOn = widget.job.lines
      .map((line) => line.serviceId)
      .whereType<String>()
      .toSet();

  double get _total => _services
      .where((s) => _chosen.contains(s.id))
      .fold(0.0, (sum, s) => sum + s.price);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      // Unfiltered by vehicle type: a mechanic looking at the car can decide
      // that the heavy-vehicle wash is the right one, and the shop's own
      // internal extras — a courtesy wash — are theirs to add.
      final services = await context.read<CatalogueService>().services();

      if (!mounted) return;
      setState(() {
        _services = services;
        _loading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = error.message;
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);

    try {
      final updated = await context.read<MechanicService>().addServices(
        widget.job.id,
        _chosen.toList(),
      );

      if (mounted) Navigator.pop(context, updated);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      showSnack(context, error.message, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);

    final palette = AppTheme.of(context);

    // Split so the ones that suit this vehicle come first. Nothing is hidden —
    // the mechanic is standing in front of the car and knows better than the
    // list does.
    final suited = _services
        .where((s) => s.suits(widget.vehicleType))
        .toList();
    final others = _services
        .where((s) => !s.suits(widget.vehicleType))
        .toList();

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
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

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t('extras.addService'),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 3),
                Text(
                  '${widget.job.vehiclePlate} · ${widget.job.id}',
                  style: TextStyle(fontSize: 13, color: palette.faint),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          Flexible(
            child: _loading
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: CircularProgressIndicator(strokeWidth: 2.4),
                  )
                : _loadError != null
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                    child: Text(
                      _loadError!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: palette.faint,
                      ),
                    ),
                  )
                : _services.isEmpty
                ? Padding(
                    padding: EdgeInsets.fromLTRB(20, 20, 20, 40),
                    child: Text(
                      t('extras.noPriceList'),
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: palette.faint),
                    ),
                  )
                : ListView(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                    children: [
                      ...suited.map(_tile),
                      if (others.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(
                          t('extras.notUsuallyFor', [
                            (widget.vehicleType ?? '—').toUpperCase(),
                          ]),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: palette.faint,
                            letterSpacing: 0.6,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...others.map(_tile),
                      ],
                    ],
                  ),
          ),

          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: palette.border)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_chosen.isNotEmpty) ...[
                  Row(
                    children: [
                      Text(
                        '${_chosen.length} selected',
                        style: TextStyle(
                          fontSize: 13,
                          color: palette.faint,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        Fmt.rs(_total),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: palette.text,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
                FilledButton(
                  onPressed: _saving || _chosen.isEmpty ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : Text(
                          _chosen.isEmpty
                              ? t('extras.chooseService')
                              : t('extras.addToJob'),
                        ),
                ),
                const SizedBox(height: 6),
                Text(
                  t('extras.pricedFrom'),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11.5, color: palette.faint),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tile(WorkshopService service) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: ServiceTile(
      service: service,
      selected: _chosen.contains(service.id),
      alreadyOn: _alreadyOn.contains(service.id),
      onTap: () => setState(() {
        if (!_chosen.remove(service.id)) _chosen.add(service.id);
      }),
    ),
  );
}
