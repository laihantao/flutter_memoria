import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // ── Watercolor Beach Palette (Psyduck-inspired) ──────────────────────────
  static const background      = Color(0xFFFBF3E3); // warm ivory — main BG
  static const surface         = Color(0xFFFFFDF8); // near-white cream — cards/Surface
  static const cardBg          = surface;

  static const primary         = Color(0xFFE8714A); // coral orange — FAB, buttons, CTA
  static const primaryLight    = Color(0xFFF0926B); // lighter coral
  static const emphasis        = Color(0xFFF4C76A); // Psyduck yellow — badges, soft selection
  static const secondaryAccent = Color(0xFF9FD3C7); // mint water-blue — avatar bg, positive
  static const chipBg          = Color(0xFFF6E3C5); // sand — chip/tag backgrounds

  static const textPrimary     = Color(0xFF4A3728); // deep coffee brown
  static const textSecondary   = Color(0xFF8B7355); // light coffee brown

  static const income          = secondaryAccent;           // mint for income
  static const expense         = Color(0xFFD4857A);         // dusty rose for expenses
  static const expenseNegative = Color(0xFFC2502F);         // deep warm red — expense amounts in text
  static const keyboardActionKey = Color(0xFFEBD9B0);       // sandy — numpad action/function keys
  static const error           = Color(0xFFB85450);

  // ── Legacy aliases — existing screens reference these; no per-screen edits needed
  static const cream           = background;
  static const parchment       = chipBg;
  static const warmBeige       = Color(0xFFEDD3A8); // placeholder covers / dividers
  static const softWhite       = surface;
  static const terracotta      = primary;
  static const dustyRose       = expense;
  static const sageMoss        = secondaryAccent;
  static const indigoSlate     = Color(0xFF5B6E8C);
  static const warmBrown       = textSecondary;
  static const darkBrown       = textPrimary;
}

class AppTheme {
  // Exposed so main.dart can use it as the root background decoration.
  static const backgroundGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFFDF8F0), // cooler/lighter corner
      Color(0xFFFBF3E3), // main ivory
      Color(0xFFF6EAD2), // warmer/darker corner
    ],
    stops: [0.0, 0.55, 1.0],
  );

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.light,
          surface: AppColors.surface,
          onSurface: AppColors.textPrimary,
        ).copyWith(
          primary: AppColors.primary,
          onPrimary: Colors.white,
          secondary: AppColors.emphasis,
          onSecondary: AppColors.textPrimary,
          tertiary: AppColors.secondaryAccent,
          onTertiary: Colors.white,
          surface: AppColors.surface,
          onSurface: AppColors.textPrimary,
          surfaceContainerHighest: AppColors.chipBg,
          error: AppColors.error,
        ),
        // Transparent so the gradient in main.dart shows through everywhere.
        scaffoldBackgroundColor: Colors.transparent,
        cardTheme: CardThemeData(
          color: AppColors.surface,
          elevation: 2,
          shadowColor: const Color(0x148B7355), // very soft brown shadow
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: const BorderRadius.all(Radius.circular(22)),
            side: const BorderSide(
              color: Color(0x1A4A3728), // ultra-subtle hand-drawn outline
              width: 1,
            ),
          ),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: AppColors.background,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          titleTextStyle: GoogleFonts.fredoka(
            fontSize: 22,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
        ),
        textTheme: TextTheme(
          displayLarge: GoogleFonts.fredoka(
              fontSize: 32, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
          displayMedium: GoogleFonts.fredoka(
              fontSize: 28, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
          headlineLarge: GoogleFonts.fredoka(
              fontSize: 24, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
          headlineMedium: GoogleFonts.fredoka(
              fontSize: 20, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
          headlineSmall: GoogleFonts.fredoka(
              fontSize: 16, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
          titleLarge: GoogleFonts.fredoka(
              fontSize: 18, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
          titleMedium: const TextStyle(
              fontSize: 16, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
          titleSmall: const TextStyle(
              fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
          bodyLarge: const TextStyle(fontSize: 16, color: AppColors.textPrimary),
          bodyMedium: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
          bodySmall: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          labelLarge: const TextStyle(
              fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.primary),
          labelMedium: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          labelSmall: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFD4C0A8)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFD4C0A8)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 2,
            shadowColor: AppColors.primary.withValues(alpha: 0.3),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            textStyle: GoogleFonts.fredoka(fontSize: 16, fontWeight: FontWeight.w500),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            side: const BorderSide(color: AppColors.primary),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          ),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: AppColors.chipBg,
          selectedColor: AppColors.emphasis.withValues(alpha: 0.4),
          labelStyle: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          side: const BorderSide(color: Color(0xFFD4C0A8), width: 0.5),
        ),
        dividerTheme: const DividerThemeData(
          color: Color(0xFFE8D5B7),
          thickness: 1,
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 3,
          highlightElevation: 6,
          shape: CircleBorder(),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: AppColors.background,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: AppColors.textSecondary,
          type: BottomNavigationBarType.fixed,
          elevation: 8,
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: AppColors.textPrimary,
          contentTextStyle: const TextStyle(color: Colors.white),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          behavior: SnackBarBehavior.floating,
        ),
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: AppColors.primary,
        ),
      );
}
