import 'package:flutter/material.dart';

/// Application theme configuration
class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.dark(
        primary: const Color(0xFF70C7BA), // Teal/Turquoise
        secondary: const Color(0xFF4FD1C7), // Lighter teal
        tertiary: const Color(0xFF38B2AC), // Darker teal
        surface: const Color(0xFF1E293B), // Dark slate
        error: const Color(0xFFEF4444),
        onPrimary: const Color(0xFF0F172A), // Dark text on light teal
        onSecondary: const Color(0xFF0F172A),
        onSurface: const Color(0xFFF9FAFB),
        onError: Colors.white,
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: const Color(0xFF0F172A),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1E293B),
        foregroundColor: Color(0xFF70C7BA), // Teal for icons and text
        elevation: 0,
        iconTheme: IconThemeData(color: Color(0xFF70C7BA)),
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF1E293B),
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF1E293B),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: Color(0xFF334155)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: Color(0xFF334155)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: Color(0xFF70C7BA), width: 2),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF70C7BA),
          foregroundColor: const Color(0xFF0F172A),
          elevation: 4,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: const Color(0xFF70C7BA),
        ),
      ),
      iconTheme: const IconThemeData(
        color: Color(0xFF70C7BA),
      ),
    );
  }
}

