import 'package:flutter/material.dart';
import 'package:nikki/core/constants/camera_colors.dart';
import 'package:nikki/theme/nikki_colors.dart';

class NikkiTheme {
  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: NikkiColors.light.background,
      extensions: const [NikkiColors.light],
      colorScheme: const ColorScheme.light(
        surface: Color(0xFFF5F5F5),
        onSurface: Color(0xFF333333),
        primary: Color(0xFF008B8B),
        onPrimary: Colors.white,
        secondary: Color(0xFF664C36),
        onSecondary: Colors.white,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: NikkiColors.light.background,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      dividerColor: NikkiColors.light.divider,
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) ? Colors.white : Colors.grey),
        trackColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) ? CameraColors.teal : const Color(0xFFCCCCCC)),
      ),
    );
  }

  static ThemeData dark() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: NikkiColors.dark.background,
      extensions: const [NikkiColors.dark],
      colorScheme: const ColorScheme.dark(
        surface: Color(0xFF1E1E1E),
        onSurface: Color(0xFFE0E0E0),
        primary: Color(0xFF008B8B),
        onPrimary: Colors.white,
        secondary: Color(0xFFEAC096),
        onSecondary: Colors.black,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: NikkiColors.dark.background,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      dividerColor: NikkiColors.dark.divider,
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) ? Colors.white : Colors.grey),
        trackColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) ? CameraColors.teal : const Color(0xFF333333)),
      ),
    );
  }
}
