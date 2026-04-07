import 'package:flutter/material.dart';

ThemeData ottDarkTheme() {
  const background = Color(0xFF0B0D10);
  const surface = Color(0xFF12161D);
  const surface2 = Color(0xFF171C25);
  const primary = Color(0xFF1EA0FF);
  const onPrimary = Color(0xFF061018);
  const onSurface = Color(0xFFEAF0F6);
  const outline = Color(0xFF2A3442);

  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: const ColorScheme.dark(
      primary: primary,
      onPrimary: onPrimary,
      secondary: primary,
      surface: surface,
      surfaceContainerHighest: surface2,
      onSurface: onSurface,
      outline: outline,
      error: Color(0xFFFF5D5D),
    ),
  );

  final textTheme = base.textTheme.apply(
    bodyColor: onSurface,
    displayColor: onSurface,
  );

  return base.copyWith(
    scaffoldBackgroundColor: background,
    canvasColor: background,
    dividerColor: outline,
    textTheme: textTheme.copyWith(
      headlineLarge: textTheme.headlineLarge?.copyWith(letterSpacing: -0.5),
      headlineMedium: textTheme.headlineMedium?.copyWith(letterSpacing: -0.4),
      titleLarge: textTheme.titleLarge?.copyWith(letterSpacing: -0.2),
      titleMedium: textTheme.titleMedium?.copyWith(letterSpacing: -0.1),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: surface2,
      surfaceTintColor: Colors.transparent,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: surface2,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
    ),
    cardTheme: const CardThemeData(
      color: surface2,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface2,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: primary, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        side: const BorderSide(color: outline),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    iconTheme: const IconThemeData(color: onSurface),
  );
}

