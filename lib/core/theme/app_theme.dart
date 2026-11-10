import 'package:flutter/material.dart';

class AppTheme {
  // ── Brand palette ──────────────────────────────────────────────────────────
  static const Color primary      = Color(0xFF1A73E8);
  static const Color primaryDark  = Color(0xFF1557B0);
  static const Color primaryLight = Color(0xFFE8F0FE);
  static const Color secondary    = Color(0xFF34A853);
  static const Color warning      = Color(0xFFF9AB00); // slightly deeper amber
  static const Color error        = Color(0xFFD93025); // Google red
  static const Color surface      = Color(0xFFF1F3F4);
  static const Color cardBg       = Color(0xFFFFFFFF);
  static const Color textPrimary  = Color(0xFF202124);
  static const Color textSecondary= Color(0xFF5F6368);
  static const Color divider      = Color(0xFFE8EAED);
  static const Color onPrimary    = Colors.white;

  // ── Spacing system (4-pt grid) ─────────────────────────────────────────────
  static const double sp4  = 4;
  static const double sp8  = 8;
  static const double sp12 = 12;
  static const double sp16 = 16;
  static const double sp20 = 20;
  static const double sp24 = 24;
  static const double sp32 = 32;

  // ── Radius system ─────────────────────────────────────────────────────────
  static const double radiusSm  = 8;
  static const double radiusMd  = 12;
  static const double radiusLg  = 16;
  static const double radiusXl  = 24;
  static const double radiusFull= 100;

  // ── Severity (0 cosmetic → 4 catastrophic) ────────────────────────────────
  static const List<Color> severityColors = [
    Color(0xFF9AA0A6), // 0 cosmetic  — grey
    Color(0xFF34A853), // 1 low       — green
    Color(0xFFF9AB00), // 2 medium    — amber
    Color(0xFFFA7B17), // 3 high      — orange
    Color(0xFFD93025), // 4 critical  — red
  ];

  static const List<String> severityLabels = [
    'Cosmetic (0)',
    'Low (1)',
    'Medium (2)',
    'High (3)',
    'Critical (4)',
  ];

  // ── Theme ──────────────────────────────────────────────────────────────────
  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Roboto', // already bundled
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        brightness: Brightness.light,
      ).copyWith(
        primary: primary,
        onPrimary: Colors.white,
        secondary: secondary,
        surface: surface,
        error: error,
      ),
      scaffoldBackgroundColor: surface,

      // ── AppBar ──────────────────────────────────────────────────────────
      appBarTheme: const AppBarTheme(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 2,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.white,
          letterSpacing: 0.1,
        ),
        iconTheme: IconThemeData(color: Colors.white, size: 24),
      ),

      // ── Card ────────────────────────────────────────────────────────────
      cardTheme: CardThemeData(
        color: cardBg,
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          side: const BorderSide(color: divider, width: 1),
        ),
        margin: const EdgeInsets.symmetric(horizontal: sp16, vertical: sp4),
      ),

      // ── ElevatedButton ──────────────────────────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shadowColor: Colors.transparent,
          minimumSize: const Size(double.infinity, 48),
          padding: const EdgeInsets.symmetric(horizontal: sp24, vertical: sp12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusSm),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
      ),

      // ── OutlinedButton ──────────────────────────────────────────────────
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          minimumSize: const Size(0, 48),
          side: const BorderSide(color: primary, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: sp20, vertical: sp12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusSm),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // ── TextButton ──────────────────────────────────────────────────────
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // ── Chip ────────────────────────────────────────────────────────────
      chipTheme: ChipThemeData(
        backgroundColor: surface,
        selectedColor: primaryLight,
        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        padding: const EdgeInsets.symmetric(horizontal: sp8, vertical: sp4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusFull),
          side: const BorderSide(color: divider),
        ),
      ),

      // ── Divider ─────────────────────────────────────────────────────────
      dividerTheme: const DividerThemeData(
        color: divider,
        thickness: 1,
        space: 1,
      ),

      // ── Input ───────────────────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          borderSide: const BorderSide(color: divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          borderSide: const BorderSide(color: divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          borderSide: const BorderSide(color: error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          borderSide: const BorderSide(color: error, width: 2),
        ),
        labelStyle: const TextStyle(
          color: textSecondary,
          fontSize: 14,
        ),
        hintStyle: const TextStyle(
          color: Color(0xFFBDC1C6),
          fontSize: 14,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: sp16, vertical: sp14),
      ),

      // ── ListTile ────────────────────────────────────────────────────────
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: sp16, vertical: sp4),
        minLeadingWidth: 24,
      ),

      // ── BottomSheet ─────────────────────────────────────────────────────
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(radiusLg),
          ),
        ),
        elevation: 8,
      ),

      // ── Dialog ──────────────────────────────────────────────────────────
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
        ),
        elevation: 8,
      ),

      // ── SnackBar ────────────────────────────────────────────────────────
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSm),
        ),
      ),
    );
  }
}

// Extra constant needed by inputDecorationTheme
const double sp14 = 14;
