import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/api_exception.dart';
import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../models/vehicle.dart';
import '../../services/customer_service.dart';
import '../../widgets/gradient_header.dart';
import '../../widgets/states.dart';

/// Put a vehicle on your own account.
///
/// Until this existed the only way onto the vehicle list was a staff member
/// typing it in at the counter, which left a customer who had just found a
/// garage in the directory with nothing to book against — they could join a
/// workshop and then do nothing until they physically turned up. The workshop
/// still sees every booking before it becomes work, so nothing here commits the
/// shop to anything; it just lets someone say which car they own.
///
/// Asks for the six things a workshop needs to recognise a vehicle on the
/// forecourt and no more. VIN, service history and the exact trim are the
/// workshop's to record when the car actually arrives.
class AddVehicleScreen extends StatefulWidget {
  const AddVehicleScreen({super.key});

  @override
  State<AddVehicleScreen> createState() => _AddVehicleScreenState();
}

class _AddVehicleScreenState extends State<AddVehicleScreen> {
  final _formKey = GlobalKey<FormState>();
  final _plate = TextEditingController();
  final _make = TextEditingController();
  final _model = TextEditingController();
  final _year = TextEditingController();
  final _colour = TextEditingController();
  final _odometer = TextEditingController();

  String _type = 'Car';
  String _fuel = 'Petrol';
  bool _saving = false;

  @override
  void dispose() {
    _plate.dispose();
    _make.dispose();
    _model.dispose();
    _year.dispose();
    _colour.dispose();
    _odometer.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    try {
      final vehicle = await context.read<CustomerService>().addVehicle(
        plate: _plate.text,
        make: _make.text,
        model: _model.text,
        year: int.parse(_year.text.trim()),
        type: _type,
        fuel: _fuel,
        // Empty means "not given", which the server stores as zero rather than
        // guessing. Asking someone to walk to their car to read the dashboard
        // before they can add it is how a form gets abandoned.
        odometer: int.tryParse(_odometer.text.trim()) ?? 0,
        color: _colour.text,
      );

      if (mounted) Navigator.pop(context, vehicle);
    } on ApiException catch (error) {
      if (!mounted) return;

      setState(() => _saving = false);
      // The duplicate-plate case lands here, and its message tells the customer
      // to ask the workshop — worth reading, so it is a snack rather than a
      // field error under a box they filled in correctly.
      showSnack(context, error.message, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);
    final palette = AppTheme.of(context);

    // Next year's models are on sale this year, so the ceiling is not "now".
    final maxYear = DateTime.now().year + 1;

    return Scaffold(
      appBar: GradientAppBar(title: t('vehicle.addTitle')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
          children: [
            _Label(t('vehicle.plate')),
            const SizedBox(height: 10),
            TextFormField(
              controller: _plate,
              // Plates are read back to a mechanic across a yard, and a lower
              // case one on a list of upper case ones looks like a typo.
              textCapitalization: TextCapitalization.characters,
              maxLength: 40,
              decoration: InputDecoration(
                hintText: t('vehicle.plateHint'),
                counterText: '',
              ),
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? t('vehicle.plateRequired')
                  : null,
            ),

            const SizedBox(height: 16),
            _Label(t('vehicle.makeAndModel')),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _make,
                    textCapitalization: TextCapitalization.words,
                    maxLength: 80,
                    decoration: InputDecoration(
                      hintText: t('vehicle.makeHint'),
                      counterText: '',
                    ),
                    validator: (value) => (value == null || value.trim().isEmpty)
                        ? t('vehicle.makeRequired')
                        : null,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: _model,
                    textCapitalization: TextCapitalization.words,
                    maxLength: 80,
                    decoration: InputDecoration(
                      hintText: t('vehicle.modelHint'),
                      counterText: '',
                    ),
                    validator: (value) => (value == null || value.trim().isEmpty)
                        ? t('vehicle.modelRequired')
                        : null,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),
            _Label(t('vehicle.year')),
            const SizedBox(height: 10),
            TextFormField(
              controller: _year,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(4),
              ],
              decoration: InputDecoration(hintText: '$maxYear'),
              validator: (value) {
                final year = int.tryParse((value ?? '').trim());

                // Checked here as well as on the server because the server's
                // reply for this one is a bare model-validation message, and
                // "The field Year must be between 1900 and 2200" is not an
                // answer to give someone who typed 20 by mistake.
                if (year == null || year < 1900 || year > maxYear) {
                  return t('vehicle.yearRange', ['1900', '$maxYear']);
                }

                return null;
              },
            ),

            const SizedBox(height: 20),
            _Label(t('vehicle.type')),
            const SizedBox(height: 10),
            _Choices(
              values: vehicleTypes,
              selected: _type,
              // Translated for display only — the value sent up stays English,
              // because that is what the API validates against.
              label: (value) => t('vehicleType.$value'),
              onSelected: (value) => setState(() => _type = value),
            ),

            const SizedBox(height: 20),
            _Label(t('vehicle.fuel')),
            const SizedBox(height: 10),
            _Choices(
              values: fuelTypes,
              selected: _fuel,
              label: (value) => t('fuel.$value'),
              onSelected: (value) => setState(() => _fuel = value),
            ),

            const SizedBox(height: 20),
            _Label(t('vehicle.optional')),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _colour,
                    textCapitalization: TextCapitalization.words,
                    maxLength: 40,
                    decoration: InputDecoration(
                      hintText: t('vehicle.colourHint'),
                      counterText: '',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: _odometer,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(8),
                    ],
                    decoration: InputDecoration(
                      hintText: t('vehicle.odometerHint'),
                      counterText: '',
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: AppTheme.brandLight,
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    size: 17,
                    color: AppTheme.brand,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      t('vehicle.addNote'),
                      style: const TextStyle(
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
          decoration: BoxDecoration(
            color: palette.card,
            border: Border(top: BorderSide(color: palette.border)),
          ),
          child: FilledButton(
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
                : Text(t('vehicle.addSubmit')),
          ),
        ),
      ),
    );
  }
}

/// A row of single-choice chips over a fixed vocabulary.
class _Choices extends StatelessWidget {
  const _Choices({
    required this.values,
    required this.selected,
    required this.label,
    required this.onSelected,
  });

  final List<String> values;
  final String selected;
  final String Function(String) label;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final palette = AppTheme.of(context);

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final value in values)
          ChoiceChip(
            label: Text(label(value)),
            selected: selected == value,
            onSelected: (_) => onSelected(value),
            selectedColor: AppTheme.brand.withValues(alpha: 0.12),
            labelStyle: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected == value ? AppTheme.brand : palette.muted,
            ),
            side: BorderSide(
              color: selected == value ? AppTheme.brand : palette.border,
            ),
          ),
      ],
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(
      fontSize: 11.5,
      fontWeight: FontWeight.w700,
      color: AppTheme.of(context).faint,
      letterSpacing: 0.7,
    ),
  );
}
