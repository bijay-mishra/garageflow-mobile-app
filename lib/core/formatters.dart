import 'package:intl/intl.dart';
import 'package:nepali_utils/nepali_utils.dart';

import 'bikram_sambat.dart';

/// Dates and money, formatted the way the dashboard formats them.
///
/// The web app writes "Rs 12,500" and "2026/07/24"; the phone must not invent
/// its own conventions, or the same invoice reads two different ways depending
/// on where you look at it.
///
/// ## Why dates are numerals
///
/// Year first, zero-padded, slash-separated — never a month name. "Jun" and
/// "Jul" differ by one letter and "असार" and "साउन" are adjacent months, which
/// is fine in prose and not fine in a list of jobs being scanned down a column
/// on a phone in a workshop. Numerals sort, align and compare at a glance.
///
/// Year-first also keeps the two calendars the same shape: 2026/07/24 and
/// 2083/04/08 have their digits in the same places, so switching language moves
/// the numbers without moving the layout.
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

  static final _weekday = DateFormat('EEE');
  static final _time = DateFormat('h:mm a');
  static final _number = NumberFormat('#,##0');
  static final _decimal = NumberFormat('#,##0.##');

  /// Rewrites ASCII digits as Devanagari.
  ///
  /// Money and counts only. Dates are deliberately exempt — see the note on
  /// [date].
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

  static String _pad(int n) => n.toString().padLeft(2, '0');

  /// `2026/07/24`, Gregorian.
  static String _ad(DateTime value) =>
      '${value.year}/${_pad(value.month)}/${_pad(value.day)}';

  /// `2083/04/08`, Bikram Sambat.
  static String _bsNumeric(NepaliDateTime bs) =>
      '${bs.year}/${_pad(bs.month)}/${_pad(bs.day)}';

  /// A date, in whichever calendar the language keeps books in — always in
  /// Latin numerals.
  ///
  /// English gets Gregorian, "2026/07/24". Nepali gets Bikram Sambat, but
  /// written "2083/04/08" rather than "२०८३/०४/०८".
  ///
  /// The calendar switches and the script does not, and those are two separate
  /// questions. Which calendar a date is in changes *what day it is*; which
  /// numerals it is written in changes only how it looks. A mechanic reading
  /// the app in Nepali is still typing plate numbers on a Latin keypad and
  /// still comparing this column against a printed job sheet — Devanagari made
  /// the date the one field that could not be read alongside everything beside
  /// it.
  static String date(DateTime? value) {
    if (value == null) return '—';
    if (!_nepali) return _ad(value);

    final bs = _bs(value);
    if (bs == null) return _ad(value);

    return _bsNumeric(bs);
  }

  /// The same date without the year, for rows where the year is obvious from
  /// context — today's work, this week's bookings.
  static String shortDate(DateTime? value) {
    if (value == null) return '—';
    if (!_nepali) return '${_pad(value.month)}/${_pad(value.day)}';

    final bs = _bs(value);
    if (bs == null) return '${_pad(value.month)}/${_pad(value.day)}';

    return '${_pad(bs.month)}/${_pad(bs.day)}';
  }

  static String dayAndDate(DateTime? value) {
    if (value == null) return '—';

    // The weekday survives the switch to numerals: it is the one part of a date
    // that is not a number, and "is that a Saturday" is a real question about a
    // promised date.
    final weekday =
        _nepali ? _neWeekdays[value.weekday % 7] : _weekday.format(value);

    return '$weekday ${shortDate(value)}';
  }

  /// Clock time. Not converted — a BS date does not change what o'clock it is,
  /// and Nepal has one timezone. Latin numerals, for the same reason dates are:
  /// a row reading "2083/04/08" beside "१२:३० अपराह्न" is one timestamp written
  /// two ways.
  static String time(DateTime value) => _time.format(value);

  /// Nepali rupees, matching the dashboard's `formatRs`.
  ///
  /// "Rs" stays Latin in both languages. "रु" is correct Nepali, but every
  /// price list and printed invoice in the country says "Rs", and changing it
  /// here would make the screen disagree with the paper beside it.
  static String rs(num value) => 'Rs ${_digits(_decimal.format(value))}';

  static String number(num value) => _digits(_number.format(value));

  static String km(num value) => '${_digits(_number.format(value))} km';

  // The BS month names that used to live here went with the named-month
  // format. The dashboard still keeps a list of them, because its date *input*
  // has a month dropdown to fill — picking a month is the one place a name
  // beats a number. The phone has no such control, so nothing here needs them.

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
      _ => 'Due ${shortDate(promised)}',
    };
  }

  /// Dates cross the wire as `yyyy-MM-dd` — the server's `DateOnly`.
  static String isoDate(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}
