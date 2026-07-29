import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The app's visual language.
///
/// Deliberately the dashboard's palette rather than a stock Material one: a
/// mechanic glancing at the phone and an advisor looking at the web screen
/// should recognise the same product. The blue, the slate greys and the status
/// tones are the Tailwind values from `tailwind.config.js`.
class AppTheme {
  const AppTheme._();

  // ── Brand ──────────────────────────────────────────────────────────────────
  static const brand = Color(0xFF2563EB); // brand-600
  static const brandDark = Color(0xFF1D4ED8); // brand-700
  static const brandLight = Color(0xFFEFF6FF); // brand-50

  // ── Ink (text and surfaces) ────────────────────────────────────────────────
  static const ink900 = Color(0xFF0F172A);
  static const ink700 = Color(0xFF334155);
  static const ink500 = Color(0xFF64748B);
  static const ink400 = Color(0xFF94A3B8);
  static const ink200 = Color(0xFFE2E8F0);
  static const ink100 = Color(0xFFF1F5F9);
  static const ink50 = Color(0xFFF8FAFC);

  // ── Status ─────────────────────────────────────────────────────────────────
  static const emerald = Color(0xFF10B981);
  static const amber = Color(0xFFF59E0B);
  static const rose = Color(0xFFF43F5E);
  static const violet = Color(0xFF8B5CF6);
  static const cyan = Color(0xFF06B6D4);

  /// Job status → the colour it reads in. Kept in one place so a status looks
  /// the same on a list row, a chip and a progress bar.
  static Color statusColor(String status) => switch (status) {
    'Open' => cyan,
    'In Progress' => brand,
    'Awaiting Parts' => amber,
    'Completed' => emerald,
    'Delivered' => ink500,
    'Cancelled' => rose,
    // Bookings share the scale.
    'Requested' => amber,
    'Confirmed' => emerald,
    'Rejected' => rose,
    'Converted' => brand,
    _ => ink500,
  };

  static Color priorityColor(String priority) => switch (priority) {
    'Urgent' => rose,
    'High' => amber,
    'Normal' => ink500,
    'Low' => ink400,
    _ => ink500,
  };

  static IconData notificationIcon(String kind) => switch (kind) {
    'job' => Icons.build_rounded,
    'booking' => Icons.event_available_rounded,
    'invoice' => Icons.receipt_long_rounded,
    _ => Icons.notifications_rounded,
  };

  /// Radius used by every card, field and sheet. One value, so nothing looks
  /// almost-but-not-quite like its neighbour.
  static const radius = 14.0;
  static const radiusSmall = 10.0;

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: brand,
      primary: brand,
      surface: Colors.white,
      error: rose,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: ink50,
      splashFactory: InkSparkle.splashFactory,

      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: ink900,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: ink900,
          fontSize: 19,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),

      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: const BorderSide(color: ink200),
        ),
      ),

      // 52pt tall: these are pressed with a thumb, often by someone holding a
      // spanner in the other hand.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          backgroundColor: brand,
          foregroundColor: Colors.white,
          disabledBackgroundColor: ink200,
          disabledForegroundColor: ink400,
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusSmall),
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          foregroundColor: ink700,
          side: const BorderSide(color: ink200),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusSmall),
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: brand,
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 15,
        ),
        hintStyle: const TextStyle(color: ink400, fontSize: 15),
        labelStyle: const TextStyle(color: ink500, fontSize: 14),
        border: _border(ink200),
        enabledBorder: _border(ink200),
        focusedBorder: _border(brand, width: 1.6),
        errorBorder: _border(rose),
        focusedErrorBorder: _border(rose, width: 1.6),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: ink100,
        side: BorderSide.none,
        labelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: ink700,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
      ),

      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: brand,
        unselectedItemColor: ink400,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w500,
        ),
      ),

      dividerTheme: const DividerThemeData(
        color: ink100,
        thickness: 1,
        space: 1,
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: ink900,
        contentTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
        ),
      ),

      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),

      textTheme: const TextTheme(
        headlineSmall: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: ink900,
          letterSpacing: -0.4,
        ),
        titleLarge: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: ink900,
        ),
        titleMedium: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: ink900,
        ),
        bodyLarge: TextStyle(fontSize: 15, color: ink700, height: 1.4),
        bodyMedium: TextStyle(fontSize: 14, color: ink700, height: 1.4),
        bodySmall: TextStyle(fontSize: 12.5, color: ink500, height: 1.35),
        labelLarge: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: ink700,
        ),
      ),
    );
  }

  static OutlineInputBorder _border(Color color, {double width = 1}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusSmall),
        borderSide: BorderSide(color: color, width: width),
      );
}
