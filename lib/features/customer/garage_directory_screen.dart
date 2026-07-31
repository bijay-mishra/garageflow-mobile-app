import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_exception.dart';
import '../../core/device_location.dart';
import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../models/workshop_card.dart';
import '../../services/directory_service.dart';
import '../../state/auth_controller.dart';
import '../../widgets/gradient_header.dart';
import '../../widgets/states.dart';

/// The garages using GarageFlow, and joining one.
///
/// The screen the marketplace turns on. A customer's account belongs above any
/// single workshop, so this is where they decide which books they want to be in
/// — and they can be in several.
///
/// Two modes. [mustChoose] is the version a brand-new account lands on: there is
/// nothing else to show them, so there is no way back and no bottom bar. Pushed
/// from the account screen instead, it is an ordinary page with a back button.
class GarageDirectoryScreen extends StatefulWidget {
  const GarageDirectoryScreen({super.key, this.mustChoose = false});

  final bool mustChoose;

  @override
  State<GarageDirectoryScreen> createState() => _GarageDirectoryScreenState();
}

class _GarageDirectoryScreenState extends State<GarageDirectoryScreen> {
  final _search = TextEditingController();

  bool _loading = true;
  String? _error;
  List<WorkshopCard> _garages = const [];

  /// Set once the phone has shared a position, so the list can be sorted by
  /// distance. Null is the normal case until someone allows it.
  double? _lat;
  double? _lng;

  /// Why there are no distances, when there are none. Shown once as a prompt
  /// rather than as an error — an alphabetical list is a perfectly good list.
  String? _locationNote;
  bool _locating = false;

  /// The join in flight, by company code, so only that card shows a spinner.
  String? _joining;

  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _load();
    // Asked on open rather than behind a button: "which garage is nearest" is
    // the question this screen exists to answer, and a prompt on arrival is
    // easier to connect to a reason than one that appears later.
    _locate(quiet: true);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final garages = await context.read<DirectoryService>().browse(
        search: _search.text,
        latitude: _lat,
        longitude: _lng,
      );

      if (!mounted) return;
      setState(() {
        _garages = garages;
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

  /// Typing re-queries the server rather than filtering what is already here,
  /// so a search matches garages that are not on the first page.
  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _load);
  }

  Future<void> _locate({bool quiet = false}) async {
    setState(() => _locating = true);

    final result = await DeviceLocation.current();

    if (!mounted) return;

    setState(() {
      _locating = false;
      _lat = result.point?.latitude;
      _lng = result.point?.longitude;
      _locationNote = result.ok ? null : result.reason;
    });

    if (result.ok) {
      await _load();
    } else if (!quiet && mounted) {
      showSnack(context, result.reason!, isError: true);
    }
  }

  Future<void> _join(WorkshopCard garage) async {
    setState(() => _joining = garage.companyCode);

    try {
      final message = await context.read<DirectoryService>().join(
        garage.companyCode,
      );

      if (!mounted) return;

      // The account's cursor moves on a first join, and the cached user still
      // says "no garage" until we ask again. Without this the shell would keep
      // showing this very screen.
      await context.read<AuthController>().refreshUser();

      if (!mounted) return;
      setState(() => _joining = null);

      showSnack(context, message);
      await _load();

      // A first join is the end of this screen's job. Anything after it is the
      // ordinary app, so get out of the way.
      if (mounted && !widget.mustChoose && Navigator.of(context).canPop()) {
        Navigator.of(context).pop(true);
      }
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _joining = null);
      showSnack(context, error.message, isError: true);
    }
  }

  Future<void> _open(WorkshopCard garage) async {
    final t = AppText.of(context);

    final failure = await context.read<AuthController>().switchWorkshop(
      garage.companyCode,
    );

    if (!mounted) return;

    if (failure != null) {
      showSnack(context, failure, isError: true);
      return;
    }

    showSnack(context, t('garages.nowViewing', [garage.name]));
    if (Navigator.of(context).canPop()) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);

    final joinedCount = _garages.where((g) => g.isJoined).length;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppTheme.brand,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          children: [
            GradientHeader(
              title: widget.mustChoose ? t('garages.choose') : t('garages.find'),
              subtitle: widget.mustChoose
                  ? t('garages.chooseSubtitle')
                  : joinedCount > 0
                  ? '$joinedCount ${t('garages.joined')}'
                  : t('garages.listed'),
              onBack: widget.mustChoose ? null : () => Navigator.pop(context),
              actions: [
                HeaderAction(
                  icon: _lat == null
                      ? Icons.my_location_outlined
                      : Icons.my_location,
                  tooltip: t('garages.sortNearest'),
                  onPressed: _locating ? null : () => _locate(),
                ),
              ],
              floating: _SearchField(
                controller: _search,
                onChanged: _onSearchChanged,
                onClear: () {
                  _search.clear();
                  _load();
                },
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

    if (_loading && _garages.isEmpty) {
      return Padding(
        padding: EdgeInsets.only(top: 60),
        child: LoadingView(label: t('garages.finding')),
      );
    }

    if (_error != null && _garages.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 40),
        child: ErrorView(message: _error!, onRetry: _load),
      );
    }

    if (_garages.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 40),
        child: EmptyView(
          icon: Icons.storefront_outlined,
          title: _search.text.trim().isEmpty
              ? t('garages.noneTitle')
              : t('garages.noMatch', [_search.text.trim()]),
          message: _search.text.trim().isEmpty
              // The honest reason: a workshop appears here only once it has
              // opted in, so an empty list is not necessarily a fault.
              ? t('garages.noneMessage')
              : t('garages.tryShorter'),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_locationNote != null) ...[
          _LocationPrompt(
            note: _locationNote!,
            busy: _locating,
            onEnable: () => _locate(),
          ),
          const SizedBox(height: 16),
        ],

        for (final garage in _garages)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _GarageCard(
              garage: garage,
              busy: _joining == garage.companyCode,
              onJoin: () => _join(garage),
              onOpen: () => _open(garage),
            ),
          ),
      ],
    );
  }
}

/// The search box, floating off the bottom of the header.
class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppTheme.radius),
      boxShadow: AppTheme.shadowLifted,
    ),
    child: TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: AppText.of(context)('garages.search'),
        prefixIcon: const Icon(Icons.search_rounded, size: 21),
        // The field supplies its own surface and shadow, so the theme's border
        // would draw a second edge inside the card.
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(vertical: 15),
        suffixIcon: ValueListenableBuilder(
          valueListenable: controller,
          builder: (context, value, _) => value.text.isEmpty
              ? const SizedBox.shrink()
              : IconButton(
                  onPressed: onClear,
                  icon: const Icon(Icons.close_rounded, size: 19),
                  color: AppTheme.of(context).faint,
                  tooltip: 'Clear',
                ),
        ),
      ),
    ),
  );
}

/// Why distances are missing, and the one tap that fixes it.
class _LocationPrompt extends StatelessWidget {
  const _LocationPrompt({
    required this.note,
    required this.busy,
    required this.onEnable,
  });

  final String note;
  final bool busy;
  final VoidCallback onEnable;

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);

    final palette = AppTheme.of(context);

    return Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      gradient: AppTheme.tintGradient(AppTheme.brand),
      borderRadius: BorderRadius.circular(AppTheme.radius),
    ),
    child: Row(
      children: [
        const Icon(Icons.near_me_outlined, size: 19, color: AppTheme.brand),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t('garages.sortedAZ'),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: palette.text,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                note,
                style: TextStyle(
                  fontSize: 12,
                  color: palette.faint,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        TextButton(
          onPressed: busy ? null : onEnable,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            minimumSize: Size.zero,
          ),
          child: Text(busy ? 'Checking…' : 'Retry'),
        ),
      ],
    ),
  );
  }
}

/// One garage. Everything a person needs to choose between two of them, and
/// nothing invented: no star rating, no photo, no review count, because the
/// product does not have those yet and a placeholder five stars would be a lie
/// about a real business.
class _GarageCard extends StatelessWidget {
  const _GarageCard({
    required this.garage,
    required this.busy,
    required this.onJoin,
    required this.onOpen,
  });

  final WorkshopCard garage;
  final bool busy;
  final VoidCallback onJoin;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);

    final palette = AppTheme.of(context);

    return AppCard(
    padding: const EdgeInsets.all(15),
    accent: garage.isPrimary ? AppTheme.brand : null,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 46,
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: AppTheme.headerGradient,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                garage.initial,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          garage.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: palette.text,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                      if (garage.isPrimary)
                        _Tag(t('garages.current'), color: AppTheme.brand)
                      else if (garage.isJoined)
                        _Tag(t('garages.joined'), color: AppTheme.emerald),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    garage.address.isEmpty
                        ? t('garages.noAddress')
                        : garage.address,
                    maxLines: 2,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: palette.faint,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        if (garage.about.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            garage.about,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              color: palette.muted,
              height: 1.4,
            ),
          ),
        ],

        const SizedBox(height: 13),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: [
            if (garage.distanceLabel != null)
              _Fact(
                icon: Icons.near_me_rounded,
                text: garage.distanceLabel!,
                highlight: true,
              ),
            if (garage.serviceCount > 0)
              _Fact(
                icon: Icons.build_outlined,
                text: t('garages.services', [garage.serviceCount]),
              ),
            if (garage.openingHours.isNotEmpty)
              _Fact(
                icon: Icons.schedule_rounded,
                text: garage.openingHours,
              ),
            if (garage.phone.isNotEmpty)
              _Fact(icon: Icons.call_outlined, text: garage.phone),
          ],
        ),

        const SizedBox(height: 15),
        if (garage.isPrimary)
          // Nothing to do: this is already the garage the app is showing.
          _Resting(text: t('garages.viewing'))
        else if (garage.isJoined)
          OutlinedButton.icon(
            onPressed: onOpen,
            icon: const Icon(Icons.swap_horiz_rounded, size: 18),
            label: Text(t('garages.switchTo')),
            style: OutlinedButton.styleFrom(
              minimumSize: Size.fromHeight(44),
              foregroundColor: AppTheme.brand,
              side: const BorderSide(color: AppTheme.brand),
            ),
          )
        else
          FilledButton.icon(
            onPressed: busy ? null : onJoin,
            icon: busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  )
                : const Icon(Icons.add_rounded, size: 19),
            label: Text(busy ? t('garages.joining') : t('garages.join')),
            style: FilledButton.styleFrom(
              minimumSize: Size.fromHeight(46),
            ),
          ),
      ],
    ),
  );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.text, {required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {

    return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 10.5,
        fontWeight: FontWeight.w800,
        color: color,
        letterSpacing: 0.3,
      ),
    ),
  );
  }
}

/// One fact about a garage — distance, hours, a phone number.
class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.text, this.highlight = false});

  final IconData icon;
  final String text;

  /// Distance gets the brand colour: it is the one fact that answers "which of
  /// these should I pick".
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final palette = AppTheme.of(context);

    final color = highlight ? AppTheme.brand : palette.faint;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: highlight
            ? AppTheme.brand.withValues(alpha: 0.09)
            : palette.border,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12.5, color: color),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: highlight ? AppTheme.brand : palette.muted,
            ),
          ),
        ],
      ),
    );
  }
}

class _Resting extends StatelessWidget {
  const _Resting({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final palette = AppTheme.of(context);

    return Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(vertical: 12),
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: palette.field,
      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.check_rounded, size: 16, color: AppTheme.emerald),
        const SizedBox(width: 7),
        Text(
          text,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: palette.faint,
          ),
        ),
      ],
    ),
  );
  }
}
