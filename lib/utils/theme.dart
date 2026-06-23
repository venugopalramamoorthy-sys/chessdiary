// lib/utils/theme.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color primary      = Color(0xFF4CAF50);
  static const Color primaryDark  = Color(0xFF2E7D32);
  static const Color secondary    = Color(0xFFFFD700);
  static const Color background   = Color(0xFF0F0F0F);
  static const Color surface      = Color(0xFF1A1A1A);
  static const Color surfaceAlt   = Color(0xFF242424);
  static const Color textPrimary  = Color(0xFFF0F0F0);
  static const Color textSecondary= Color(0xFF8A8A8A);
  static const Color win          = Color(0xFF4CAF50);
  static const Color loss         = Color(0xFFEF5350);
  static const Color draw         = Color(0xFF9E9E9E);
  static const Color blunder      = Color(0xFFEF5350);
  static const Color mistake      = Color(0xFFFF9800);
  static const Color inaccuracy   = Color(0xFFFFEB3B);
  static const Color goodMove     = Color(0xFF4CAF50);

  static ThemeData get dark {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: secondary,
        background: background,
        surface: surface,
        onPrimary: Colors.white,
        onSecondary: Colors.black,
        onBackground: textPrimary,
        onSurface: textPrimary,
      ),
      scaffoldBackgroundColor: background,
      textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.inter(
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: const IconThemeData(color: textPrimary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 16),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceAlt,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        labelStyle: const TextStyle(color: textSecondary),
        hintStyle: const TextStyle(color: textSecondary),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: primary,
        unselectedItemColor: textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
      ),
    );
  }

  static Color resultColor(String result) {
    switch (result) {
      case 'Win': return win;
      case 'Loss': return loss;
      default: return draw;
    }
  }

  static Color qualityColor(String quality) {
    switch (quality) {
      case 'best':
      case 'good': return goodMove;
      case 'inaccuracy': return inaccuracy;
      case 'mistake': return mistake;
      case 'blunder': return blunder;
      default: return textSecondary;
    }
  }

  static IconData qualityIcon(String quality) {
    switch (quality) {
      case 'best': return Icons.star_rounded;
      case 'good': return Icons.check_circle_rounded;
      case 'inaccuracy': return Icons.info_rounded;
      case 'mistake': return Icons.warning_rounded;
      case 'blunder': return Icons.cancel_rounded;
      default: return Icons.circle;
    }
  }
}
