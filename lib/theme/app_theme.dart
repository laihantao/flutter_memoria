import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_theme_extension.dart';
import 'theme_config.dart';

// ── 陶土 + 米白 Color Tokens ──────────────────────────────────────────────────

class AppColors {
  // Light mode
  static const background   = Color(0xFFF7F2EA);
  static const surface      = Color(0xFFFFFFFF);
  static const muted        = Color(0xFFF3EADE);
  static const primary      = Color(0xFFB0552F);
  static const primaryDeep  = Color(0xFF9A4E2E);
  static const primaryTint  = Color(0xFFE8D3C2);
  static const text         = Color(0xFF3A2D26);
  static const textMuted    = Color(0xFF94806F);
  static const border       = Color(0xFFEAE0D4);
  static const success      = Color(0xFF4E7A52);
  static const accent       = Color(0xFFC2632B);

  // Dark mode
  static const darkBackground  = Color(0xFF1E1A17);
  static const darkSurface     = Color(0xFF2A2521);
  static const darkMuted       = Color(0xFF332C26);
  static const darkPrimary     = Color(0xFFD2794E);
  static const darkPrimaryDeep = Color(0xFFB0552F);
  static const darkPrimaryTint = Color(0xFF46362C);
  static const darkText        = Color(0xFFF2EAE0);
  static const darkTextMuted   = Color(0xFFA8998A);
  static const darkBorder      = Color(0xFF3A332C);
  static const darkSuccess     = Color(0xFF6FA074);
  static const darkAccent      = Color(0xFFE0884F);

  // Legacy aliases — existing screens reference these
  static const cream           = background;
  static const parchment       = muted;
  static const warmBeige       = Color(0xFFEDD3A8);
  static const softWhite       = surface;
  static const terracotta      = primary;
  static const warmBrown       = textMuted;
  static const darkBrown       = text;
  static const chipBg          = muted;
  static const cardBg          = surface;
  static const textPrimary     = text;
  static const textSecondary   = textMuted;
  static const primaryLight    = Color(0xFFF0926B);
  static const emphasis        = Color(0xFFF4C76A);
  static const secondaryAccent = Color(0xFF9FD3C7);
  static const income          = success;
  static const expense         = Color(0xFFD4857A);
  static const expenseNegative = primary;
  static const error           = Color(0xFFB85450);
  static const indigoSlate     = Color(0xFF5B6E8C);
  static const keyboardActionKey = Color(0xFFEBD9B0);
  static const dustyRose       = expense;
  static const sageMoss        = secondaryAccent;
}

// Cover gradients (kept for any legacy references)
const kCoverGradientLight = LinearGradient(
  begin: Alignment(-0.5, -1.0),
  end: Alignment(0.5, 1.0),
  colors: [Color(0xFFCE9168), Color(0xFF9A4E2E), Color(0xFF6E3520)],
  stops: [0.0, 0.58, 1.0],
);

const kCoverGradientDark = LinearGradient(
  begin: Alignment(-0.5, -1.0),
  end: Alignment(0.5, 1.0),
  colors: [Color(0xFFA8623D), Color(0xFF6E3520), Color(0xFF3E1E12)],
  stops: [0.0, 0.58, 1.0],
);

// ── Theme ─────────────────────────────────────────────────────────────────────

class AppTheme {
  static ThemeData light([ThemeConfig? config]) =>
      _build(Brightness.light, config ?? kThemes.first);
  static ThemeData dark([ThemeConfig? config]) =>
      _build(Brightness.dark, config ?? kThemes.first);

  static ThemeData _build(Brightness brightness, ThemeConfig config) {
    final isDark = brightness == Brightness.dark;

    // All main colors come from the active ThemeConfig
    final bg        = config.backgroundColor;
    final surface   = config.surfaceColor;
    final primary   = config.accentColor;
    final text      = config.textPrimaryColor;
    final textMuted = config.textSecondaryColor;
    final border    = config.borderColor;
    final muted     = config.mutedColor;

    // Semantic colors are always fixed — never theme-overridden
    const errorColor = AppColors.error;

    final noto = (double size, FontWeight weight, Color color) =>
        GoogleFonts.notoSansSc(fontSize: size, fontWeight: weight, color: color);
    final jakarta = (double size, FontWeight weight, Color color) =>
        GoogleFonts.plusJakartaSans(fontSize: size, fontWeight: weight, color: color);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        brightness: brightness,
        surface: surface,
        onSurface: text,
      ).copyWith(
        primary: primary,
        onPrimary: isDark ? bg : Colors.white,
        secondary: muted,
        surface: surface,
        onSurface: text,
        surfaceContainerHighest: muted,
        error: errorColor,
      ),
      scaffoldBackgroundColor: bg,
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(18)),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        foregroundColor: text,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: noto(21, FontWeight.w800, text),
      ),
      textTheme: TextTheme(
        displayLarge:  noto(34, FontWeight.w900, text),
        displayMedium: noto(28, FontWeight.w900, text),
        headlineLarge: noto(22, FontWeight.w800, text),
        headlineMedium:noto(21, FontWeight.w800, text),
        headlineSmall: noto(16, FontWeight.w800, text),
        titleLarge:    noto(21, FontWeight.w800, text),
        titleMedium:   noto(16, FontWeight.w800, text),
        titleSmall:    jakarta(14, FontWeight.w700, text),
        bodyLarge:     noto(15, FontWeight.w500, text),
        bodyMedium:    noto(15, FontWeight.w500, textMuted),
        bodySmall:     noto(12, FontWeight.w500, textMuted),
        labelLarge:    jakarta(14, FontWeight.w700, primary),
        labelMedium:   jakarta(12, FontWeight.w500, textMuted),
        labelSmall:    jakarta(11, FontWeight.w500, textMuted),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: primary, width: 1.5),
        ),
        hintStyle: TextStyle(color: textMuted),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: isDark ? bg : Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
          padding:
              const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
          textStyle:
              GoogleFonts.notoSansSc(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: BorderSide(color: primary, width: 1.5),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
          padding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
          textStyle:
              GoogleFonts.notoSansSc(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: muted,
        selectedColor: primary.withValues(alpha: 0.2),
        labelStyle: GoogleFonts.notoSansSc(fontSize: 12, color: text),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        side: BorderSide(color: border, width: 0.5),
      ),
      dividerTheme: DividerThemeData(color: border, thickness: 1),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: isDark ? bg : Colors.white,
        elevation: 0,
        shape: const CircleBorder(),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: primary,
        unselectedItemColor: textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: text,
        contentTextStyle: TextStyle(
            color: isDark ? bg : Colors.white),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: primary),
      extensions: [
        AppThemeExtension(
          coverGradient: isDark ? config.darkGradient : config.lightGradient,
          cardGradient:
              isDark ? config.darkCardGradient : config.lightCardGradient,
          cardShadow: config.cardShadowColor,
          backgroundColor: bg,
          surfaceColor: surface,
          accentColor: primary,
          textPrimary: text,
          textSecondary: textMuted,
          mutedColor: muted,
          borderColor: border,
          // Fake-glass card tint: theme bg at 0.72 for light themes,
          // theme surface at 0.80 for dark (ensures readable light text).
          glassTintColor: isDark
              ? surface.withValues(alpha: 0.80)
              : bg.withValues(alpha: 0.72),
        ),
      ],
    );
  }
}
