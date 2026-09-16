import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppTheme {
  static const Color bgColor       = Color(0xFF0A0A0A);
  static const Color surfaceColor  = Color(0xFF111111);
  static const Color cardColor     = Color(0xFF161616);
  static const Color borderColor   = Color(0xFF2A2A2A);
  static const Color defaultAccent = Color(0xFF4ADE80);
  static final ValueNotifier<Color> accentNotifier = ValueNotifier<Color>(defaultAccent);
  static Color get accentGreen => accentNotifier.value;
  static Color get accentGreenDim {
    final hsl = HSLColor.fromColor(accentGreen);
    return hsl.withLightness((hsl.lightness * 0.75).clamp(0.0, 1.0)).toColor();
  }
  static const Color textPrimary   = Color(0xFFF0F0F0);
  static const Color textSecondary = Color(0xFF888888);
  static const Color textMuted     = Color(0xFF555555);

  static Future<void> loadAccent() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getInt('accent_color');
    if (value != null) accentNotifier.value = Color(value);
  }

  static Future<void> setAccent(Color color) async {
    accentNotifier.value = color;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('accent_color', color.value);
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bgColor,
      colorScheme: ColorScheme.dark(
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
        overlayColor: accentGreen.withOpacity(0.2),
      ),
    );
  }
}
