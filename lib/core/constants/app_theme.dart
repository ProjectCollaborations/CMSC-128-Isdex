import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  AppTheme._();

  // ── Color Palette ──
  static const Color navy900 = Color(0xFF001A3E);
  static const Color navy700 = Color(0xFF002F6C);
  static const Color navy500 = Color(0xFF004A9E);
  static const Color teal400 = Color(0xFF26C6DA);
  static const Color teal200 = Color(0xFF80DEEA);
  static const Color teal50 = Color(0xFFE0F7FA);
  static const Color surface = Color(0xFFF5F7FB);
  static const Color card = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF001A3E);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color error = Color(0xFFDC2626);
  static const Color success = Color(0xFF16A34A);

  // IUCN conservation status colors (from fish_detail_page.dart)
  static const Map<String, Color> statusColors = {
    'Extinct (EX)': Color(0xFF000000),
    'Extinct in the Wild (EW)': Color(0xFF4A0080),
    'Critically Endangered (CR)': Color(0xFFCC0000),
    'Endangered (EN)': Color(0xFFE65C00),
    'Vulnerable (VU)': Color(0xFFE6A800),
    'Near Threatened (NT)': Color(0xFF2E8B57),
    'Least Concern (LC)': Color(0xFF006400),
    'Data Deficient (DD)': Color(0xFF607D8B),
    'Not Evaluated (NE)': Color(0xFF9E9E9E),
  };

  static ThemeData get light => ThemeData(
    useMaterial3: true,
    fontFamily: GoogleFonts.inter().fontFamily,
    scaffoldBackgroundColor: surface,
    colorScheme: ColorScheme.light(
      primary: teal400,
      secondary: navy500,
      surface: card,
      error: error,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: navy900,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: GoogleFonts.poppins(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: teal400,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      color: card,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: teal50,
      labelStyle: const TextStyle(fontSize: 12),
      side: const BorderSide(color: teal200),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: Colors.white,
      selectedItemColor: teal400,
      unselectedItemColor: textSecondary,
      type: BottomNavigationBarType.fixed,
      elevation: 8,
    ),
    dividerTheme: DividerThemeData(
      color: navy900.withValues(alpha: 0.08),
      thickness: 1,
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: teal400,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: navy900,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: navy900,
        side: const BorderSide(color: navy900),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
    ),
  );
}
