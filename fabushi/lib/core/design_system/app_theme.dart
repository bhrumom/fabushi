import 'package:flutter/material.dart';
import 'colors.dart';
import 'dart:ui';

class AppTheme {
  // Primary Colors
  static const Color primaryColor = nebulaPurple;
  static const Color secondaryColor = spaceBlue;
  static const Color accentColor = cosmicGold;
  static const Color alipayBlue = Color(0xFF1677FF);

  // Gradients
  static const LinearGradient cosmicGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [spaceDeepBlue, Color(0xFF1A237E)], // Deep Blue to Deep Indigo
  );

  static const LinearGradient nebulaGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [nebulaPurple, nebulaPink],
  );

  static const LinearGradient primaryGradient = cosmicGradient;

  // Glassmorphism Decorations
  static BoxDecoration glassDecoration = BoxDecoration(
    color: glassSurface,
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: glassBorder, width: 1),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.2),
        blurRadius: 20,
        spreadRadius: 5,
      ),
    ],
  );

  // Helper to get a glass effect (requires ClipRRect / BackdropFilter usage in widget tree)
  // but here we define the container style.

  // Dark Theme (The Main Cosmic Theme)
  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor:
        Colors.transparent, // Important for background image/gradient
    fontFamily: 'NotoSansSC',

    colorScheme: const ColorScheme.dark(
      primary: primaryColor,
      secondary: secondaryColor,
      tertiary: accentColor,
      surface: Color(0xFF1E1E2C), // Fallback surface
      background: Colors.transparent,
    ),

    appBarTheme: const AppBarTheme(
      centerTitle: true,
      elevation: 0,
      backgroundColor: Colors.transparent, // Glass effect usually
      foregroundColor: starlightWhite,
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: starlightWhite,
        fontFamily: 'NotoSansSC',
      ),
    ),

    cardTheme: CardThemeData(
      elevation: 0, // We use glass decoration instead usually
      color: glassSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: glassBorder, width: 0.5),
      ),
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 10,
        shadowColor: nebulaPurple.withOpacity(0.5),
        backgroundColor:
            primaryColor, // Use gradient in widget if possible, but here solid
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          fontFamily: 'NotoSansSC',
        ),
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: glassSurface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: glassBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: glassBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: accentColor, width: 1),
      ),
      hintStyle: TextStyle(color: starlightWhite.withOpacity(0.5)),
      labelStyle: const TextStyle(color: starlightWhite),
    ),

    // Keep existing text themes but ensure colors are correct
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: starlightWhite),
      bodyMedium: TextStyle(color: starlightWhite),
      titleLarge: TextStyle(color: starlightWhite, fontWeight: FontWeight.bold),
    ),
  );

  // Light Theme (Keeping it but making it compatible if needed, or just redirect to Dark)
  // For this request, we might want to force Dark mode or make Light mode also "Spacey" (maybe day-sky).
  // Let's stick to the user request "Space travel" -> Dark.
  static ThemeData lightTheme =
      darkTheme; // Force Dark/Space theme for now as requested style.
}
