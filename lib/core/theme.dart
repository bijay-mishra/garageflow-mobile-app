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

  /// The brand, lifted for dark surfaces.
  ///
  /// brand-600 on a near-black background fails contrast for body text and
  /// reads as muddy rather than blue. This is brand-400, which keeps the same
  /// hue at a legible weight.
  static const brandOnDark = Color(0xFF60A5FA);

  // ── Ink (text and surfaces) ────────────────────────────────────────────────
  //
  // These are the *light* values, and most of the app names them directly —
  // `AppTheme.ink900` for a heading, `Colors.white` for a card. That is why
  // dark mode is not a second ColorScheme: it would leave several hundred
  // hardcoded colours untouched and produce black text on a black card.
  //
  // Instead the app swaps what these names resolve to. `AppTheme.of(context)`
  // returns the palette for the active brightness, and anything that needs to
  // flip reads it from there. The constants below stay as the light palette so
  // the screens that never flip — the gradient headers, white-on-blue — keep
  // working unchanged.
  static const ink900 = Color(0xFF0F172A);
  static const ink700 = Color(0xFF334155);
  static const ink500 = Color(0xFF64748B);
  static const ink400 = Color(0xFF94A3B8);
  static const ink200 = Color(0xFFE2E8F0);
  static const ink100 = Color(0xFFF1F5F9);
  static const ink50 = Color(0xFFF8FAFC);

  /// The palette for the current brightness.
  ///
  /// Read this instead of the constants above anywhere the colour has to differ
  /// between themes — text, card surfaces, dividers.
  static AppPalette of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? AppPalette.dark
      : AppPalette.light;

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

  /// Radius of the curve a header sweeps into the content below it.
  static const radiusHeader = 26.0;

  // ── Depth ──────────────────────────────────────────────────────────────────
  // The app used to draw every card as a 1px grey outline, which reads flat and
  // makes a busy screen look like a spreadsheet. Cards now sit *above* the
  // background on a real shadow, and the outline is gone. Two levels only:
  // resting, and lifted for the one thing on a screen that matters most.

  /// A card at rest. Wide, soft and very light — visible as depth rather than
  /// as a grey smudge under the corners.
  static List<BoxShadow> get shadowCard => [
    BoxShadow(
      color: ink900.withValues(alpha: 0.05),
      blurRadius: 14,
      offset: const Offset(0, 4),
    ),
    BoxShadow(
      color: ink900.withValues(alpha: 0.03),
      blurRadius: 3,
      offset: const Offset(0, 1),
    ),
  ];

  /// The headline card, and anything floating over the gradient.
  static List<BoxShadow> get shadowLifted => [
    BoxShadow(
      color: ink900.withValues(alpha: 0.1),
      blurRadius: 26,
      offset: const Offset(0, 10),
    ),
    BoxShadow(
      color: ink900.withValues(alpha: 0.04),
      blurRadius: 5,
      offset: const Offset(0, 2),
    ),
  ];

  /// Cast by a coloured button onto the background, in its own colour, so a
  /// primary action feels like it is sitting on the page rather than stamped
  /// into it.
  static List<BoxShadow> glow(Color color) => [
    BoxShadow(
      color: color.withValues(alpha: 0.32),
      blurRadius: 16,
      offset: const Offset(0, 6),
    ),
  ];

  // ── Gradients ──────────────────────────────────────────────────────────────

  /// The header behind every screen's title.
  ///
  /// Runs top-left to bottom-right rather than straight down: on a tall narrow
  /// header a vertical ramp is barely perceptible, and the diagonal gives the
  /// band a light source. The third stop is what stops it looking like a
  /// two-colour CSS gradient from 2014.
  static const headerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1E3A8A), brandDark, Color(0xFF2F6BF0)],
    stops: [0, 0.55, 1],
  );

  /// A tinted wash for a card that needs to feel like part of the header
  /// family without competing with it.
  static LinearGradient tintGradient(Color color) => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      color.withValues(alpha: 0.14),
      color.withValues(alpha: 0.04),
    ],
  );

  /// Text on the gradient. Not pure white for the secondary line — a header
  /// with two identical whites has no hierarchy.
  static const onHeader = Colors.white;
  static Color get onHeaderMuted => Colors.white.withValues(alpha: 0.72);
  static Color get onHeaderFaint => Colors.white.withValues(alpha: 0.5);

  /// A frosted panel on the gradient — the stat tiles in a header.
  static Color get headerPanel => Colors.white.withValues(alpha: 0.14);
  static Color get headerPanelBorder => Colors.white.withValues(alpha: 0.2);

  /// An avatar drawn on the gradient.
  ///
  /// Stronger than [headerPanel] deliberately. A frosted tile is a background
  /// for text and should recede; an avatar is a subject and should not. At the
  /// panel's own 0.14/0.2 the circle came out around #4662B2 over the navy end
  /// of the gradient — close enough to the band behind it that it read as a
  /// smudge rather than a portrait, most obviously on the profile screen where
  /// it is the largest thing on the header.
  ///
  /// Kept here rather than in the two widgets that draw it. `ProfileAvatar` and
  /// `HeaderAvatar` are the same treatment at two sizes, and held identical by
  /// copy-paste they would drift the first time one of them was adjusted.
  static Color get avatarOnHeader => Colors.white.withValues(alpha: 0.22);
  static Color get avatarOnHeaderBorder => Colors.white.withValues(alpha: 0.45);

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

  /// The dark counterpart of [light].
  ///
  /// Not an inversion. A workshop phone is used outdoors in daylight and in a
  /// bay under a car, so the dark theme is a deep slate rather than pure black:
  /// black surfaces with white text smear on OLED when you scroll, and the
  /// contrast is harsher than anyone wants at arm's length. Cards sit *above*
  /// the background by being lighter, which is the same depth cue the light
  /// theme gets from its shadows — shadows are nearly invisible on dark.
  static ThemeData get dark {
    const p = AppPalette.dark;

    final scheme = ColorScheme.fromSeed(
      seedColor: brand,
      brightness: Brightness.dark,
      primary: brandOnDark,
      surface: p.card,
      error: rose,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: p.background,
      splashFactory: InkSparkle.splashFactory,

      appBarTheme: AppBarTheme(
        backgroundColor: p.card,
        foregroundColor: p.text,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: p.text,
          fontSize: 19,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),

      cardTheme: CardThemeData(
        color: p.card,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: BorderSide(color: p.border),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          backgroundColor: brandOnDark,
          foregroundColor: Colors.white,
          disabledBackgroundColor: p.border,
          disabledForegroundColor: p.faint,
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusSmall),
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          foregroundColor: p.text,
          side: BorderSide(color: p.border),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusSmall),
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: brandOnDark,
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.field,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
        hintStyle: TextStyle(color: p.faint, fontSize: 15),
        labelStyle: TextStyle(color: p.muted, fontSize: 14),
        border: _border(p.border),
        enabledBorder: _border(p.border),
        focusedBorder: _border(brandOnDark, width: 1.6),
        errorBorder: _border(rose),
        focusedErrorBorder: _border(rose, width: 1.6),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: p.field,
        side: BorderSide.none,
        labelStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: p.text,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),

      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: p.card,
        selectedItemColor: brandOnDark,
        unselectedItemColor: p.faint,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w500,
        ),
      ),

      dividerTheme: DividerThemeData(color: p.border, thickness: 1, space: 1),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: p.field,
        contentTextStyle: TextStyle(
          color: p.text,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
        ),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.card,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),

      dialogTheme: DialogThemeData(backgroundColor: p.card),

      textTheme: TextTheme(
        headlineSmall: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: p.text,
          letterSpacing: -0.4,
        ),
        titleLarge: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: p.text,
        ),
        titleMedium: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: p.text,
        ),
        bodyLarge: TextStyle(fontSize: 15, color: p.muted, height: 1.4),
        bodyMedium: TextStyle(fontSize: 14, color: p.muted, height: 1.4),
        bodySmall: TextStyle(fontSize: 12.5, color: p.faint, height: 1.35),
        labelLarge: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: p.muted,
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

/// The colours that differ between light and dark.
///
/// A small fixed set on purpose. Every screen already names a colour directly,
/// and a palette with thirty entries would be thirty decisions per screen; these
/// six cover text, surfaces and edges, which is all that actually has to change.
class AppPalette {
  const AppPalette({
    required this.background,
    required this.card,
    required this.field,
    required this.border,
    required this.text,
    required this.muted,
    required this.faint,
    required this.accentWash,
  });

  /// Behind everything.
  final Color background;

  /// A card sitting on [background].
  final Color card;

  /// An input, or a card-within-a-card.
  final Color field;

  final Color border;

  /// Headings and primary values.
  final Color text;

  /// Body copy.
  final Color muted;

  /// Captions, and anything deliberately quiet.
  final Color faint;

  /// A brand-tinted surface: a selected row, an unread notification, the tile
  /// behind a brand icon.
  ///
  /// This exists because [AppTheme.brandLight] does not have a dark twin. It is
  /// `brand-50` — a very pale blue — and eight screens were using it as a
  /// surface colour, which meant a selected service, an unread alert and the
  /// icon tile on the workshop card all stayed almost-white in dark mode. Any
  /// tint that has to sit *behind* something belongs here rather than in the
  /// fixed swatches at the top of this file.
  final Color accentWash;

  static const light = AppPalette(
    background: AppTheme.ink50,
    card: Colors.white,
    field: AppTheme.ink50,
    border: AppTheme.ink200,
    text: AppTheme.ink900,
    muted: AppTheme.ink700,
    faint: AppTheme.ink500,
    accentWash: AppTheme.brandLight,
  );

  /// Slate, not black — see the note on [AppTheme.dark].
  static const dark = AppPalette(
    background: Color(0xFF0B1120),
    card: Color(0xFF151E31),
    field: Color(0xFF1D283D),
    border: Color(0xFF2A3654),
    text: Color(0xFFF1F5F9),
    muted: Color(0xFFCBD5E1),
    faint: Color(0xFF94A3B8),
    // The brand hue at low saturation against the dark card, rather than a
    // lightened blue. Reads as "tinted" at a glance without becoming a bright
    // panel on a dark screen, which is what a literal dark-mode brand-50 does.
    accentWash: Color(0xFF1B2A4A),
  );
}
