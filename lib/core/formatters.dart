import 'package:intl/intl.dart';
import 'package:nepali_utils/nepali_utils.dart';

import 'bikram_sambat.dart';

/// Dates and money, formatted the way the dashboard formats them.
///
/// The web app writes "Rs 12,500" and "24 Jul 2026"; the phone must not invent
/// its own conventions, or the same invoice reads two different ways depending
/// on where you look at it.
///
/// ## Language
///
/// Set [language] and every date in the app switches calendar: English shows
/// Gregorian, Nepali shows Bikram Sambat in Devanagari. That pairing is
/// deliberate rather than two separate settings — somebody reading the app in
/// Nepali is keeping books in BS, and in practice the two have never been
/// independent choices.
///
/// It is a static field, which is usually a smell, and here is the right shape
/// anyway: this is one app-wide display preference read on every frame from a
/// hundred call sites. Threading a BuildContext through all of them would mean
/// touching every screen to express something that is genuinely global. The
/// field is set in `GarageFlowApp.build`, which runs whenever the setting
/// changes, so the value is always current before the tree that reads it.
class Fmt {
  const Fmt._();

  /// `en` or `ne`. Set by the app root; never read a stale value because the
  /// same rebuild that changes it is the one that redraws every date.
  static String language = 'en';

  static bool get _nepali => language == 'ne';

  static final _date = DateFormat('d MMM yyyy');
  static final _shortDate = DateFormat('d MMM');
  static final _dayAndDate = DateFormat('EEE, d MMM');
  static final _time = DateFormat('h:mm a');
  static final _number = NumberFormat('#,##0');
  static final _decimal = NumberFormat('#,##0.##');

  /// Rewrites ASCII digits as Devanagari.
  ///
  /// Applied to money and counts as well as dates: a screen showing "१५ साउन"
  /// next to "Rs 2,400" looks like two different products.
  static String _digits(String value) {
    if (!_nepali) return value;

    const ne = ['०', '१', '२', '३', '४', '५', '६', '७', '८', '९'];
    return value.replaceAllMapped(
      RegExp(r'\d'),
      (m) => ne[int.parse(m[0]!)],
    );
  }

  /// The BS equivalent, or null when the date is outside the library's range.
  ///
  /// Null is not an error to shout about — a date from 1970 is bad data, and
  /// falling back to Gregorian is more honest than rendering a wrong BS date.
  static NepaliDateTime? _bs(DateTime value) => Bs.from(value);

  static String date(DateTime? value) {
    if (value == null) return '—';
    if (!_nepali) return _date.format(value);

    final bs = _bs(value);
    if (bs == null) return _date.format(value);

    return _digits('${bs.day} ${_bsMonths[bs.month - 1]} ${bs.year}');
  }

  static String shortDate(DateTime? value) {
    if (value == null) return '—';
    if (!_nepali) return _shortDate.format(value);

    final bs = _bs(value);
    if (bs == null) return _shortDate.format(value);

    return _digits('${bs.day} ${_bsMonths[bs.month - 1]}');
  }

  static String dayAndDate(DateTime? value) {
    if (value == null) return '—';
    if (!_nepali) return _dayAndDate.format(value);

    final bs = _bs(value);
    if (bs == null) return _dayAndDate.format(value);

    // Weekday first, as the English form does — Sunday is index 1 in BS.
    final weekday = _neWeekdays[value.weekday % 7];
    return _digits('$weekday, ${bs.day} ${_bsMonths[bs.month - 1]}');
  }

  /// Clock time. Not converted — a BS date does not change what o'clock it is,
  /// and Nepal has one timezone.
  static String time(DateTime value) => _digits(_time.format(value));

  /// Nepali rupees, matching the dashboard's `formatRs`.
  ///
  /// "Rs" stays Latin in both languages. "रु" is correct Nepali, but every
  /// price list and printed invoice in the country says "Rs", and changing it
  /// here would make the screen disagree with the paper beside it.
  static String rs(num value) => 'Rs ${_digits(_decimal.format(value))}';

  static String number(num value) => _digits(_number.format(value));

  static String km(num value) => '${_digits(_number.format(value))} km';

  /// Bikram Sambat months, Baisakh first.
  static const _bsMonths = [
    'बैशाख',
    'जेठ',
    'असार',
    'साउन',
    'भदौ',
    'असोज',
    'कार्तिक',
    'मंसिर',
    'पुष',
    'माघ',
    'फागुन',
    'चैत',
  ];

  /// Indexed by `DateTime.weekday % 7`, so Sunday lands at 0.
  static const _neWeekdays = [
    'आइत',
    'सोम',
    'मंगल',
    'बुध',
    'बिहि',
    'शुक्र',
    'शनि',
  ];

  /// Sizes for a photo's caption line.
  static String bytes(int value) {
    if (value < 1024) return '$value B';
    if (value < 1024 * 1024) return '${(value / 1024).toStringAsFixed(0)} KB';
    return '${(value / 1024 / 1024).toStringAsFixed(1)} MB';
  }

  /// "just now", "5 min ago", "3 days ago" — for the notification feed, where
  /// an absolute timestamp is more precision than anyone wants.
  static String timeAgo(DateTime value) {
    final elapsed = DateTime.now().difference(value);

    if (elapsed.isNegative || elapsed.inSeconds < 60) {
      return _nepali ? 'भर्खरै' : 'just now';
    }

    if (elapsed.inMinutes < 60) {
      final n = _digits('${elapsed.inMinutes}');
      return _nepali ? '$n मिनेट अघि' : '$n min ago';
    }

    if (elapsed.inHours < 24) {
      final n = _digits('${elapsed.inHours}');
      return _nepali
          ? '$n घण्टा अघि'
          : '$n hour${elapsed.inHours == 1 ? '' : 's'} ago';
    }

    if (elapsed.inDays < 7) {
      final n = _digits('${elapsed.inDays}');
      return _nepali
          ? '$n दिन अघि'
          : '$n day${elapsed.inDays == 1 ? '' : 's'} ago';
    }

    // Past a week the relative form stops helping, so it falls through to the
    // full date — which is itself calendar-aware.
    return date(value);
  }

  /// How a promised date should read on a job: "today", "tomorrow", "2 days
  /// late". Relative wording is what a mechanic actually needs from that field.
  static String due(DateTime promised) {
    final today = DateTime.now();
    final days = DateTime(promised.year, promised.month, promised.day)
        .difference(DateTime(today.year, today.month, today.day))
        .inDays;

    if (_nepali) {
      return switch (days) {
        0 => 'आज सक्नुपर्ने',
        1 => 'भोलि सक्नुपर्ने',
        -1 => '१ दिन ढिलो',
        < -1 => '${_digits('${-days}')} दिन ढिलो',
        _ => '${shortDate(promised)} सम्म',
      };
    }

    return switch (days) {
      0 => 'Due today',
      1 => 'Due tomorrow',
      -1 => '1 day late',
      < -1 => '${-days} days late',
      _ => 'Due ${_shortDate.format(promised)}',
    };
  }

  /// Dates cross the wire as `yyyy-MM-dd` — the server's `DateOnly`.
  static String isoDate(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}
