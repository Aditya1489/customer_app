import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Dark Theme Colors (The Modern Grooming Lounge)
  static const darkBGStart = Color(0xFF0B0F0E); // Deep Obsidian
  static const darkBGMiddle = Color(0xFF060908); // Even deeper
  static const darkBGEnd = Color(0xFF052116);   // Deep Dark Green (for mesh gradient)
  
  static const darkCardBG = Color(0xAA0F1716); // semi-transparent obsidian
  static const darkAccent = Color(0xFFF59E0B); // Vibrant Amber
  static const darkButton = Color(0xFF10B981); // Emerald Green
  static const emerald = Color(0xFF10B981);    // emerald-500
  static const mutedRed = Color(0xFF991B1B);   // muted red

  // Light Theme Colors (matching reference UI)
  static const lightBGStart = Color(0xFFF5F5F7); // light gray
  static const lightBGMiddle = Color(0xFFF5F5F7); // light gray
  static const lightBGEnd = Color(0xFFEFEFF0);  // slightly darker gray
  
  static const lightCardBG = Color(0xFFFFFFFF); // pure white for cards
  static const lightAccent = Color(0xFF7C3AED); // purple accent
  static const lightButton = Color(0xFF7C3AED); // purple button

  static const double radiusXL = 32.0; // rounded-[32px]
  static const double radiusL = 24.0;  // rounded-3xl
  static const double radiusM = 16.0;  // rounded-2xl
  static const double radiusS = 12.0;  // rounded-xl

  static ThemeData getDarkTheme() {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: Colors.transparent,
      textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
      cardTheme: CardThemeData(
        color: darkCardBG,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusL)),
        elevation: 0,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: darkButton,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusM)),
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
    );
  }

  static ThemeData getLightTheme() {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: Colors.transparent,
      textTheme: GoogleFonts.interTextTheme(ThemeData.light().textTheme),
      cardTheme: CardThemeData(
        color: lightCardBG,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        elevation: 0,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: lightButton,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
    );
  }
}
