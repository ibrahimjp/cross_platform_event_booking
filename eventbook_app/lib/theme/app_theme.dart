import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Brand Primary & Gradient colors from DESIGN.md
  static const Color primary = Color(0xFF6B38D4);
  static const Color primaryContainer = Color(0xFF8455EF);
  static const Color primaryFixedDim = Color(0xFFD0BCFF);
  static const Color primaryFixed = Color(0xFFE9DDFF);
  static const Color deepPurpleGradientEnd = Color(0xFF6D28D9);

  // Surface colors
  static const Color surface = Color(0xFFF8F9FF);
  static const Color surfaceDim = Color(0xFFD0DBED);
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color surfaceContainerLow = Color(0xFFEFF4FF);
  static const Color surfaceContainer = Color(0xFFE6EEFF);
  static const Color surfaceContainerHigh = Color(0xFFDEE9FC);
  static const Color surfaceContainerHighest = Color(0xFFD9E3F6);

  // Content colors
  static const Color onSurface = Color(0xFF121C2A);
  static const Color onSurfaceVariant = Color(0xFF494454);
  static const Color secondary = Color(0xFF5C5F60);
  static const Color outline = Color(0xFF7B7486);
  static const Color outlineVariant = Color(0xFFCBC3D7);
  static const Color aiHighlightBg = Color(0xFFEDE9FE);

  // Light Theme Data
  static ThemeData get lightTheme {
    final baseTextTheme = GoogleFonts.interTextTheme();
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: surface,
      colorScheme: const ColorScheme.light(
        primary: primary,
        primaryContainer: primaryContainer,
        surface: surface,
        onSurface: onSurface,
        onSurfaceVariant: onSurfaceVariant,
        secondary: secondary,
        outline: outline,
        outlineVariant: outlineVariant,
      ),
      textTheme: baseTextTheme.copyWith(
        displayLarge: GoogleFonts.inter(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          height: 1.25,
          letterSpacing: -0.5,
        ),
        headlineMedium: GoogleFonts.inter(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          height: 1.33,
          letterSpacing: -0.25,
        ),
        headlineSmall: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          height: 1.4,
        ),
        bodyLarge: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w400,
          height: 1.55,
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          height: 1.5,
        ),
        bodySmall: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          height: 1.42,
        ),
        labelLarge: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
        labelSmall: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: onSurface),
      ),
      cardTheme: CardThemeData(
        color: surfaceContainerLowest,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFF3F4F6), width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
      ),
    );
  }

  // Dark Theme Data
  static ThemeData get darkTheme {
    final baseTextTheme = GoogleFonts.interTextTheme(ThemeData.dark().textTheme);
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF121824),
      colorScheme: const ColorScheme.dark(
        primary: primaryFixedDim,
        primaryContainer: primaryContainer,
        surface: Color(0xFF1E2638),
        onSurface: Colors.white,
        onSurfaceVariant: Color(0xFFC4C7C5),
        secondary: Color(0xFFA8ABAD),
        outline: outline,
        outlineVariant: Color(0xFF494454),
      ),
      textTheme: baseTextTheme.copyWith(
        displayLarge: GoogleFonts.inter(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          height: 1.25,
          letterSpacing: -0.5,
        ),
        headlineMedium: GoogleFonts.inter(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          height: 1.33,
          letterSpacing: -0.25,
        ),
        headlineSmall: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          height: 1.4,
        ),
        bodyLarge: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w400,
          height: 1.55,
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          height: 1.5,
        ),
        bodySmall: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          height: 1.42,
        ),
        labelLarge: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
        labelSmall: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF1E2638),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF2A344A), width: 1),
        ),
      ),
    );
  }

  // Linear Gradient for Primary Action Buttons
  static const Gradient primaryGradient = LinearGradient(
    colors: [primary, deepPurpleGradientEnd],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static bool isDark(BuildContext context) => Theme.of(context).brightness == Brightness.dark;

  // Soft Ambient Shadow Decoration for Cards (theme-aware so text stays readable in dark mode)
  static BoxDecoration cardDecoration(
    BuildContext context, {
    Color? backgroundColor,
    double borderRadius = 16,
    Color? borderColor,
  }) {
    final dark = isDark(context);
    return BoxDecoration(
      color: backgroundColor ?? (dark ? const Color(0xFF1E2638) : surfaceContainerLowest),
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(color: borderColor ?? (dark ? const Color(0xFF2A344A) : const Color(0xFFF3F4F6)), width: 1),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0D1F2937),
          blurRadius: 20,
          offset: Offset(0, 4),
        ),
      ],
    );
  }

  // Glassmorphism AI Note Panel Decoration
  static BoxDecoration glassDecoration(BuildContext context, {double borderRadius = 16}) {
    final dark = isDark(context);
    return BoxDecoration(
      color: dark ? const Color(0xFF241D3A) : Colors.white.withValues(alpha: 0.85),
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(color: primary.withValues(alpha: 0.15), width: 1.5),
      boxShadow: [
        BoxShadow(
          color: primary.withValues(alpha: 0.12),
          blurRadius: 30,
          offset: const Offset(0, 10),
        ),
      ],
    );
  }

  /// Subtle filled background for inputs, steppers and pills.
  static Color subtle(BuildContext context) =>
      isDark(context) ? const Color(0xFF2A344A) : surfaceContainerLow;

  /// Background for bottom action bars.
  static Color barColor(BuildContext context) =>
      isDark(context) ? const Color(0xFF1E2638) : Colors.white;
}
