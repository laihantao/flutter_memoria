import 'package:flutter/material.dart';

/// ThemeExtension that carries per-theme visual tokens.
/// Access via: `Theme.of(context).extension<AppThemeExtension>()!`
class AppThemeExtension extends ThemeExtension<AppThemeExtension> {
  final LinearGradient coverGradient;
  final LinearGradient cardGradient;
  final Color cardShadow;
  final Color backgroundColor;
  final Color surfaceColor;
  final Color accentColor;
  final Color textPrimary;
  final Color textSecondary;
  final Color mutedColor;
  final Color borderColor;

  const AppThemeExtension({
    required this.coverGradient,
    required this.cardGradient,
    required this.cardShadow,
    required this.backgroundColor,
    required this.surfaceColor,
    required this.accentColor,
    required this.textPrimary,
    required this.textSecondary,
    required this.mutedColor,
    required this.borderColor,
  });

  @override
  AppThemeExtension copyWith({
    LinearGradient? coverGradient,
    LinearGradient? cardGradient,
    Color? cardShadow,
    Color? backgroundColor,
    Color? surfaceColor,
    Color? accentColor,
    Color? textPrimary,
    Color? textSecondary,
    Color? mutedColor,
    Color? borderColor,
  }) {
    return AppThemeExtension(
      coverGradient: coverGradient ?? this.coverGradient,
      cardGradient: cardGradient ?? this.cardGradient,
      cardShadow: cardShadow ?? this.cardShadow,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      surfaceColor: surfaceColor ?? this.surfaceColor,
      accentColor: accentColor ?? this.accentColor,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      mutedColor: mutedColor ?? this.mutedColor,
      borderColor: borderColor ?? this.borderColor,
    );
  }

  @override
  AppThemeExtension lerp(ThemeExtension<AppThemeExtension>? other, double t) {
    if (other is! AppThemeExtension) return this;
    return AppThemeExtension(
      coverGradient:
          LinearGradient.lerp(coverGradient, other.coverGradient, t)!,
      cardGradient: LinearGradient.lerp(cardGradient, other.cardGradient, t)!,
      cardShadow: Color.lerp(cardShadow, other.cardShadow, t)!,
      backgroundColor: Color.lerp(backgroundColor, other.backgroundColor, t)!,
      surfaceColor: Color.lerp(surfaceColor, other.surfaceColor, t)!,
      accentColor: Color.lerp(accentColor, other.accentColor, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      mutedColor: Color.lerp(mutedColor, other.mutedColor, t)!,
      borderColor: Color.lerp(borderColor, other.borderColor, t)!,
    );
  }
}
