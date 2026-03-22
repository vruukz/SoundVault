import 'package:flutter/material.dart';

class AppTheme {
  static const Color bgColor       = Color(0xFF0A0A0A);
  static const Color surfaceColor  = Color(0xFF111111);
  static const Color cardColor     = Color(0xFF161616);
  static const Color borderColor   = Color(0xFF2A2A2A);
  static const Color accentGreen   = Color(0xFF4ADE80);
  static const Color accentGreenDim= Color(0xFF22C55E);
  static const Color textPrimary   = Color(0xFFF0F0F0);
  static const Color textSecondary = Color(0xFF888888);
  static const Color textMuted     = Color(0xFF555555);

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bgColor,
      colorScheme: const ColorScheme.dark(
        primary: accentGreen,
        secondary: accentGreenDim,
        surface: surfaceColor,
        onPrimary: bgColor,
        onSurface: textPrimary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: bgColor,
        foregroundColor: textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: borderColor),
        ),
      ),
      dividerTheme: const DividerThemeData(color: borderColor),
      sliderTheme: SliderThemeData(
        trackHeight: 3,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
        thumbColor: accentGreen,
        activeTrackColor: accentGreen,
        inactiveTrackColor: borderColor,
        overlayColor: Color(0x334ADE80),
      ),
    );
  }
}
