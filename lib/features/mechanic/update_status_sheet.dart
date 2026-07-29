import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/api_exception.dart';
import '../../core/theme.dart';
import '../../models/job.dart';
import '../../services/mechanic_service.dart';
import '../../widgets/states.dart';

/// The one write a mechanic makes most often, so it is a sheet rather than a
/// screen: two taps from the job, and the job stays visible behind it.
///
/// Odometer and note are optional. A mechanic moving a job to "In Progress"
/// should not have to fill in a form to do it.
class UpdateStatusSheet extends StatefulWidget {
  const UpdateStatusSheet({super.key, required this.job});

  final MechanicJob job;

  @override
  State<UpdateStatusSheet> createState() => _UpdateStatusSheetState();
}

class _UpdateStatusSheetState extends State<UpdateStatusSheet> {
  late String _status = widget.job.status;
  late final _odometer = TextEditingController(
    text: widget.job.odometer > 0 ? '${widget.job.odometer}' : '',
  );
  final _note = TextEditingController();

  bool _saving = false;

  @override
  void dispose() {
    _odometer.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);

    try {
      final typed = int.tryParse(_odometer.text.trim());

      final updated = await context.read<MechanicService>().updateStatus(
        widget.job.id,
        status: _status,
        // Only sent when it actually changed — an untouched field should not
        // count as the mechanic asserting a reading.
        odometer: typed != null && typed != widget.job.odometer ? typed : null,
        note: _note.text,
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
    final unchanged = _status == widget.job.status &&
        _note.text.trim().isEmpty &&
        (int.tryParse(_odometer.text.trim()) ?? widget.job.odometer) ==
            widget.job.odometer;

    return Padding(
      // Lifts the sheet above the keyboard when the note field has focus.
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.ink200,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              Text(
                'Update status',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 3),
              Text(
                '${widget.job.vehiclePlate} · ${widget.job.id}',
                style: const TextStyle(fontSize: 13, color: AppTheme.ink500),
              ),
              const SizedBox(height: 20),

              // Full-width rows rather than a wrap of chips: these are tapped
              // with a thumb, sometimes with gloves on, and a 52pt row is a
              // target that does not need aiming at.
              for (final status in mechanicSelectableStatuses)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _StatusOption(
                    status: status,
                    selected: _status == status,
                    onTap: () => setState(() => _status = status),
                  ),
                ),

              const SizedBox(height: 12),
              TextField(
                controller: _odometer,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: 'Odometer (km)',
                  hintText: '${widget.job.odometer}',
                  prefixIcon: const Icon(Icons.speed_rounded, size: 20),
                  helperText: 'Optional — recorded against the vehicle too',
                  helperStyle: const TextStyle(
                    fontSize: 11.5,
                    color: AppTheme.ink400,
                  ),
                ),
              ),
              const SizedBox(height: 14),

              TextField(
                controller: _note,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Work note',
                  hintText: 'Ordered front pads, waiting on delivery…',
                  alignLabelWithHint: true,
                  helperText: 'Optional — added to the job card',
                  helperStyle: TextStyle(
                    fontSize: 11.5,
                    color: AppTheme.ink400,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              FilledButton(
                onPressed: _saving || unchanged ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : Text(unchanged ? 'Nothing to save' : 'Save'),
              ),
              const SizedBox(height: 6),
              Text(
                'The customer is notified when the status changes.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11.5, color: AppTheme.ink400),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusOption extends StatelessWidget {
  const _StatusOption({
    required this.status,
    required this.selected,
    required this.onTap,
  });

  final String status;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.statusColor(status);

    return Material(
      color: selected ? color.withValues(alpha: 0.09) : Colors.white,
      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        child: Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            border: Border.all(
              color: selected ? color : AppTheme.ink200,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  status,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? color : AppTheme.ink700,
                  ),
                ),
              ),
              if (selected)
                Icon(Icons.check_circle_rounded, size: 20, color: color),
            ],
          ),
        ),
      ),
    );
  }
}
