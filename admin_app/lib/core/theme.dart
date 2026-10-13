import 'package:flutter/material.dart';

/// EventBook purple, shared with the customer app's brand.
const brand = Color(0xFF6B38D4);

/// Semantic colours that read well on both light and dark surfaces.
class Tone {
  static const success = Color(0xFF16A34A);
  static const warning = Color(0xFFD97706);
  static const danger = Color(0xFFDC2626);
  static const info = Color(0xFF2563EB);
  static const neutral = Color(0xFF64748B);
}

ThemeData buildTheme(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(seedColor: brand, brightness: brightness);
  final isDark = brightness == Brightness.dark;
  final base = ThemeData(useMaterial3: true, colorScheme: scheme, brightness: brightness);
  return base.copyWith(
    scaffoldBackgroundColor: isDark ? const Color(0xFF0F1117) : const Color(0xFFF5F6FB),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: isDark ? const Color(0xFF181B24) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: isDark ? 0.35 : 0.6)),
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: isDark ? const Color(0xFF0F1117) : const Color(0xFFF5F6FB),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: base.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700, color: scheme.onSurface),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: isDark ? const Color(0xFF1E2230) : Colors.white,
      isDense: true,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      side: BorderSide(color: scheme.outlineVariant),
    ),
    dividerTheme: DividerThemeData(color: scheme.outlineVariant.withValues(alpha: 0.5), space: 1),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: isDark ? const Color(0xFF141720) : Colors.white,
      indicatorColor: scheme.primaryContainer,
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}
