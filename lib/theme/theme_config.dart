import 'package:flutter/material.dart';

class ThemeConfig {
  final String id;
  final String name;
  final Brightness brightness;
  final LinearGradient lightGradient;
  final LinearGradient darkGradient;
  final LinearGradient lightCardGradient;
  final LinearGradient darkCardGradient;
  final Color cardShadowColor;
  final Color backgroundColor;
  final Color surfaceColor;
  final Color accentColor;
  final Color textPrimaryColor;
  final Color textSecondaryColor;
  final Color mutedColor;
  final Color borderColor;
  final List<String> decorations;
  // Page-level background (ThemeBackground uses these, NOT lightGradient/darkGradient).
  // null → flat backgroundColor.
  final Gradient? lightPageBackground;
  final Gradient? darkPageBackground;
  // Theme-internal multipliers (invisible to user sliders).
  final double densityBaseMultiplier;
  final double speedBaseMultiplier;

  const ThemeConfig({
    required this.id,
    required this.name,
    required this.brightness,
    required this.lightGradient,
    required this.darkGradient,
    required this.lightCardGradient,
    required this.darkCardGradient,
    required this.cardShadowColor,
    required this.backgroundColor,
    required this.surfaceColor,
    required this.accentColor,
    required this.textPrimaryColor,
    required this.textSecondaryColor,
    required this.mutedColor,
    required this.borderColor,
    this.decorations = const [],
    this.lightPageBackground,
    this.darkPageBackground,
    this.densityBaseMultiplier = 1.0,
    this.speedBaseMultiplier = 1.0,
  });
}

const kThemes = <ThemeConfig>[
  ThemeConfig(
    id: 'warm_clay',
    name: '暖陶',
    brightness: Brightness.light,
    backgroundColor: Color(0xFFF7F2EA),
    surfaceColor: Color(0xFFFFFFFF),
    accentColor: Color(0xFFB0552F),
    textPrimaryColor: Color(0xFF3A2D26),
    textSecondaryColor: Color(0xFF94806F),
    mutedColor: Color(0xFFF3EADE),
    borderColor: Color(0xFFEAE0D4),
    lightGradient: LinearGradient(
      begin: Alignment(-0.5, -1.0),
      end: Alignment(0.5, 1.0),
      colors: [Color(0xFFCE9168), Color(0xFF9A4E2E), Color(0xFF6E3520)],
      stops: [0.0, 0.58, 1.0],
    ),
    darkGradient: LinearGradient(
      begin: Alignment(-0.5, -1.0),
      end: Alignment(0.5, 1.0),
      colors: [Color(0xFFA8623D), Color(0xFF6E3520), Color(0xFF3E1E12)],
      stops: [0.0, 0.58, 1.0],
    ),
    lightCardGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Colors.white, Color(0xFFFAF5EF)],
    ),
    darkCardGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF2A2521), Color(0xFF2E2623)],
    ),
    cardShadowColor: Color(0xFF78461E),
    decorations: [],
    // flat page background — no lightPageBackground
  ),
  ThemeConfig(
    id: 'frost_blue',
    name: '霜蓝',
    brightness: Brightness.light,
    backgroundColor: Color(0xFFEFF6FB),
    surfaceColor: Color(0xFFFFFFFF),
    accentColor: Color(0xFF3B7CA0),
    textPrimaryColor: Color(0xFF1E3545),
    textSecondaryColor: Color(0xFF5A7D93),
    mutedColor: Color(0xFFDEEFF8),
    borderColor: Color(0xFFC4DDF0),
    lightGradient: LinearGradient(
      begin: Alignment(-0.5, -1.0),
      end: Alignment(0.5, 1.0),
      colors: [Color(0xFF9BBDD4), Color(0xFF4A7F9E), Color(0xFF2C5A74)],
      stops: [0.0, 0.58, 1.0],
    ),
    darkGradient: LinearGradient(
      begin: Alignment(-0.5, -1.0),
      end: Alignment(0.5, 1.0),
      colors: [Color(0xFF4A7F9E), Color(0xFF2C5A74), Color(0xFF162E3C)],
      stops: [0.0, 0.58, 1.0],
    ),
    lightCardGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Colors.white, Color(0xFFDDEEF8)],
    ),
    darkCardGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF1F2A38), Color(0xFF162030)],
    ),
    cardShadowColor: Color(0xFF1A4A6E),
    decorations: ['snowflake'],
    lightPageBackground: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFFEAF4FB), Color(0xFFBFDBF7), Color(0xFF8FB8E8)],
      stops: [0.0, 0.55, 1.0],
    ),
    densityBaseMultiplier: 0.7,
    speedBaseMultiplier: 0.5,
  ),
  ThemeConfig(
    id: 'heat_wave',
    name: '热浪',
    brightness: Brightness.light,
    backgroundColor: Color(0xFFFEDDC1),
    surfaceColor: Color(0xFFFFFFFF),
    accentColor: Color(0xFFD4521A),
    textPrimaryColor: Color(0xFF3D1A0A),
    textSecondaryColor: Color(0xFF8C5030),
    mutedColor: Color(0xFFFED9A8),
    borderColor: Color(0xFFEDD4B8),
    lightGradient: LinearGradient(
      begin: Alignment(-0.5, -1.0),
      end: Alignment(0.5, 1.0),
      colors: [Color(0xFFFFB347), Color(0xFFE8522A), Color(0xFFC0392B)],
      stops: [0.0, 0.58, 1.0],
    ),
    darkGradient: LinearGradient(
      begin: Alignment(-0.5, -1.0),
      end: Alignment(0.5, 1.0),
      colors: [Color(0xFFE8522A), Color(0xFFC0392B), Color(0xFF7B241C)],
      stops: [0.0, 0.58, 1.0],
    ),
    lightCardGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Colors.white, Color(0xFFFEEEE0)],
    ),
    darkCardGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF2A1E14), Color(0xFF201510)],
    ),
    cardShadowColor: Color(0xFF8B3A1A),
    decorations: ['flame'],
    // flat page background — no lightPageBackground
  ),
  ThemeConfig(
    id: 'starry_night',
    name: '星夜',
    brightness: Brightness.dark,
    backgroundColor: Color(0xFF1A2744),
    surfaceColor: Color(0xFF243660),
    accentColor: Color(0xFFD4AF37),
    textPrimaryColor: Color(0xFFE8E2D5),
    textSecondaryColor: Color(0xFF9E9880),
    mutedColor: Color(0xFF1E2E54),
    borderColor: Color(0xFF2D4070),
    lightGradient: LinearGradient(
      begin: Alignment(-0.5, -1.0),
      end: Alignment(0.5, 1.0),
      colors: [Color(0xFF6B7DB3), Color(0xFF3D4F85), Color(0xFF1E2952)],
      stops: [0.0, 0.58, 1.0],
    ),
    darkGradient: LinearGradient(
      begin: Alignment(-0.5, -1.0),
      end: Alignment(0.5, 1.0),
      colors: [Color(0xFF3D4F85), Color(0xFF1E2952), Color(0xFF0D1329)],
      stops: [0.0, 0.58, 1.0],
    ),
    lightCardGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Colors.white, Color(0xFFF3F3FB)],
    ),
    darkCardGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF243660), Color(0xFF1C2A54)],
    ),
    cardShadowColor: Color(0xFF2A2A6A),
    decorations: ['star'],
    darkPageBackground: LinearGradient(
      begin: Alignment(-0.5, -1.0),
      end: Alignment(0.5, 1.0),
      colors: [Color(0xFF3D4F85), Color(0xFF1E2952), Color(0xFF0D1329)],
      stops: [0.0, 0.58, 1.0],
    ),
    speedBaseMultiplier: 1.2,
  ),
];

/// Resolves which ThemeConfig to use.
/// [entryThemeIdOverride] is reserved for future per-entry theme overrides.
ThemeConfig resolveTheme(String globalThemeId, [String? entryThemeIdOverride]) {
  final id = entryThemeIdOverride ?? globalThemeId;
  return kThemes.firstWhere((t) => t.id == id, orElse: () => kThemes.first);
}
