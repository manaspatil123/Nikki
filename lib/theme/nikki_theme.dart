import 'package:flutter/material.dart';

class NikkiTheme {
  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: Colors.white,
      colorScheme: const ColorScheme.light(
        surface: Color(0xFFF5F5F5),
        onSurface: Color(0xFF333333),
        primary: Colors.black,
        onPrimary: Colors.white,
        secondary: Color(0xFF333333),
        onSecondary: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      dividerColor: const Color(0xFFCCCCCC),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? Colors.white
                : Colors.grey),
        trackColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? Colors.black
                : const Color(0xFFCCCCCC)),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
            fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black),
        titleMedium: TextStyle(
            fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black),
        bodyMedium: TextStyle(fontSize: 14, color: Colors.black),
        bodySmall: TextStyle(fontSize: 12, color: Color(0xFF666666)),
        labelSmall: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.5,
            color: Color(0xFF999999)),
      ),
    );
  }

  static ThemeData dark() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: Colors.black,
      colorScheme: const ColorScheme.dark(
        surface: Color(0xFF1A1A1A),
        onSurface: Color(0xFFCCCCCC),
        primary: Colors.white,
        onPrimary: Colors.black,
        secondary: Color(0xFFCCCCCC),
        onSecondary: Colors.black,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      dividerColor: const Color(0xFF333333),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? Colors.black
                : Colors.grey),
        trackColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? Colors.white
                : const Color(0xFF333333)),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
            fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
        titleMedium: TextStyle(
            fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
        bodyMedium: TextStyle(fontSize: 14, color: Colors.white),
        bodySmall: TextStyle(fontSize: 12, color: Color(0xFF999999)),
        labelSmall: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.5,
            color: Color(0xFF666666)),
      ),
    );
  }
}
