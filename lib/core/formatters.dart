import 'package:intl/intl.dart';

/// Dates and money, formatted the way the dashboard formats them.
///
/// The web app writes "Rs 12,500" and "24 Jul 2026"; the phone must not invent
/// its own conventions, or the same invoice reads two different ways depending
/// on where you look at it.
class Fmt {
  const Fmt._();

  static final _date = DateFormat('d MMM yyyy');
  static final _shortDate = DateFormat('d MMM');
  static final _dayAndDate = DateFormat('EEE, d MMM');
  static final _time = DateFormat('h:mm a');
  static final _number = NumberFormat('#,##0');
  static final _decimal = NumberFormat('#,##0.##');

  static String date(DateTime? value) => value == null ? '—' : _date.format(value);

  static String shortDate(DateTime? value) =>
      value == null ? '—' : _shortDate.format(value);

  static String dayAndDate(DateTime? value) =>
      value == null ? '—' : _dayAndDate.format(value);

  static String time(DateTime value) => _time.format(value);

  /// Nepali rupees, matching the dashboard's `formatRs`.
  static String rs(num value) => 'Rs ${_decimal.format(value)}';

  static String number(num value) => _number.format(value);

  static String km(num value) => '${_number.format(value)} km';

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

    if (elapsed.isNegative) return 'just now';
    if (elapsed.inSeconds < 60) return 'just now';
    if (elapsed.inMinutes < 60) return '${elapsed.inMinutes} min ago';
    if (elapsed.inHours < 24) {
      return '${elapsed.inHours} hour${elapsed.inHours == 1 ? '' : 's'} ago';
    }
    if (elapsed.inDays < 7) {
      return '${elapsed.inDays} day${elapsed.inDays == 1 ? '' : 's'} ago';
    }

    return _date.format(value);
  }

  /// How a promised date should read on a job: "today", "tomorrow", "2 days
  /// late". Relative wording is what a mechanic actually needs from that field.
  static String due(DateTime promised) {
    final today = DateTime.now();
    final days = DateTime(promised.year, promised.month, promised.day)
        .difference(DateTime(today.year, today.month, today.day))
        .inDays;

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
