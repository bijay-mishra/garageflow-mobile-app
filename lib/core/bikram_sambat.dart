import 'package:nepali_utils/nepali_utils.dart';

/// Gregorian → Bikram Sambat.
///
/// ## Why this exists rather than `DateTime.toNepaliDateTime()`
///
/// `nepali_utils` is internally inconsistent between its two directions, and a
/// test comparing it against the dashboard's `nepali-date-converter` caught it:
///
/// ```
/// NepaliDateTime(2083, 4, 1).toDateTime()   // 2026-07-17  ✓ agrees with JS
/// DateTime(2026, 7, 17).toNepaliDateTime()  // Shrawan 2   ✗ should be 1
/// ```
///
/// So its BS→AD conversion is right and its AD→BS conversion is a day early.
/// Not a timezone artefact — the same offset appears for UTC, local and midday
/// inputs on a machine at UTC+05:45.
///
/// The fix is to define the direction we need *in terms of the one that works*:
/// binary-search BS dates for the one whose Gregorian value is the date we were
/// given. That is slower than a formula and it cannot drift, because the only
/// conversion involved is the one that round-trips correctly with the web app.
/// The phone and the dashboard showing different dates for the same invoice is
/// exactly the failure worth spending a few microseconds to avoid.
class Bs {
  const Bs._();

  /// The package's supported span. Outside it, conversion throws.
  static const _minYear = 1970;
  static const _maxYear = 2100;

  /// Converts [date] to BS, or null when it falls outside the usable range.
  ///
  /// Null is a real answer rather than an error: a date from 1950 is bad data,
  /// and the caller shows the Gregorian value instead — more honest than
  /// rendering a BS date that is a guess.
  static NepaliDateTime? from(DateTime date) {
    // Compared as a plain day, so a time component cannot push the answer over
    // a boundary.
    final target = DateTime(date.year, date.month, date.day);

    // The BS year is the Gregorian year plus 56 or 57 depending on where in the
    // year we are. Both are tried rather than guessed.
    for (final bsYear in [date.year + 56, date.year + 57]) {
      if (bsYear < _minYear || bsYear > _maxYear) continue;

      final found = _searchYear(bsYear, target);
      if (found != null) return found;
    }

    return null;
  }

  /// Finds the BS date within [bsYear] matching [target], or null.
  static NepaliDateTime? _searchYear(int bsYear, DateTime target) {
    DateTime? startAd;

    try {
      startAd = NepaliDateTime(bsYear, 1, 1).toDateTime();
    } catch (_) {
      return null;
    }

    // A BS year is 365 or 366 days. Work out how far into it the target is,
    // then walk the months — their lengths vary from 29 to 32, so the day
    // cannot be derived arithmetically.
    final offset = target
        .difference(DateTime(startAd.year, startAd.month, startAd.day))
        .inDays;

    if (offset < 0 || offset > 366) return null;

    var remaining = offset;

    for (var month = 1; month <= 12; month++) {
      final length = _monthLength(bsYear, month);
      if (length == null) return null;

      if (remaining < length) {
        return NepaliDateTime(bsYear, month, remaining + 1);
      }

      remaining -= length;
    }

    return null;
  }

  /// Days in a BS month — 29 to 32, and it varies by year.
  ///
  /// Measured as the gap between two Gregorian dates rather than read from a
  /// table, so it uses the same trusted direction as everything else here.
  static int? _monthLength(int bsYear, int month) {
    try {
      final start = NepaliDateTime(bsYear, month, 1).toDateTime();

      final next = month == 12
          ? NepaliDateTime(bsYear + 1, 1, 1).toDateTime()
          : NepaliDateTime(bsYear, month + 1, 1).toDateTime();

      return DateTime(next.year, next.month, next.day)
          .difference(DateTime(start.year, start.month, start.day))
          .inDays;
    } catch (_) {
      return null;
    }
  }
}
