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

  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.light(
        primary: const Color(0xFF1B3D1B),
        secondary: const Color(0xFF29622E),
        surface: Colors.white,
        onPrimary: Colors.white,
        onSurface: const Color(0xFF0E180E),
      ),
      scaffoldBackgroundColor: const Color(0xFFF8F7F3),
      textTheme: GoogleFonts.interTextTheme(ThemeData.light().textTheme),
      appBarTheme: AppBarTheme(
        backgroundColor: const Color(0xFFF8F7F3),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: GoogleFonts.inter(
          color: const Color(0xFF0E180E),
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: const IconThemeData(color: Color(0xFF0E180E)),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFFDDD8CB)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1B3D1B),
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFDDD8CB)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFDDD8CB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF1B3D1B), width: 1.5),
        ),
        labelStyle: const TextStyle(color: Color(0xFF5C6352)),
        hintStyle: const TextStyle(color: Color(0xFF5C6352)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: Color(0xFF1B3D1B),
        unselectedItemColor: Color(0xFF5C6352),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: Color(0xFF1B3D1B),
        foregroundColor: Colors.white,
      ),
      dividerTheme: const DividerThemeData(color: Color(0xFFDDD8CB)),
      progressIndicatorTheme:
          const ProgressIndicatorThemeData(color: Color(0xFF1B3D1B)),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: Color(0xFF0E180E),
        contentTextStyle: TextStyle(color: Colors.white),
      ),
    );
  }

  /// Dark Material theme for the web editorial dark mode.
  /// WT's WT.darkBg / WT.darkCard palette is used for editorial widgets;
  /// this ThemeData covers Material-layer widgets (Scaffold, Card, TextField, etc.).
  static ThemeData get webDark {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.dark(
        primary: const Color(0xFF66BB6A),   // greenDark
        secondary: const Color(0xFF66BB6A),
        surface: const Color(0xFF1E1E1E),   // WT.darkCard
        onPrimary: Colors.black,
        onSurface: const Color(0xFFE8E6DF), // WT.darkText
      ),
      scaffoldBackgroundColor: const Color(0xFF141414), // WT.darkBg
      textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
      appBarTheme: AppBarTheme(
        backgroundColor: const Color(0xFF0C0C0C), // WT.black
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: GoogleFonts.inter(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: const IconThemeData(color: Color(0xFFAAAAAA)), // WT.silver
      ),
      cardTheme: const CardThemeData(
        color: Color(0xFF1E1E1E),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(4)),
          side: BorderSide(color: Color(0xFF333333)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF66BB6A),
          foregroundColor: Colors.black,
          elevation: 0,
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF252525),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: Color(0xFF333333)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: Color(0xFF333333)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: Color(0xFF66BB6A), width: 1.5),
        ),
        hintStyle: const TextStyle(color: Color(0xFF888888)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Color(0xFF1E1E1E),
        selectedItemColor: Color(0xFF66BB6A),
        unselectedItemColor: Color(0xFF888888),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: Color(0xFF66BB6A),
        foregroundColor: Colors.black,
      ),
      dividerTheme: const DividerThemeData(color: Color(0xFF333333)),
      progressIndicatorTheme:
          const ProgressIndicatorThemeData(color: Color(0xFF66BB6A)),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: Color(0xFF252525),
        contentTextStyle: TextStyle(color: Color(0xFFE8E6DF)),
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
