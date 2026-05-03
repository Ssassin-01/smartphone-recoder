import 'package:flutter/material.dart';

class AppTheme {
  static const Color primaryNavy = Color(0xFF0A1E32);
  static const Color accentOrange = Color(0xFFFF6D00);
  static const Color glassWhite = Color(0x22FFFFFF);
  static const Color backgroundNavy = Color(0xFF05111B);

  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    primaryColor: accentOrange,
    scaffoldBackgroundColor: backgroundNavy,
    colorScheme: ColorScheme.dark(
      primary: accentOrange,
      secondary: accentOrange,
      surface: Color(0xFF0F1F2C),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: accentOrange,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        textStyle: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    ),
  );
}
