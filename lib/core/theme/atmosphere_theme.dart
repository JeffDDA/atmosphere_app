import 'package:flutter/material.dart';

import 'atmosphere_colors.dart';

class AtmosphereTheme {
  AtmosphereTheme._();

  static const Color dragonBurgundy = Color(0xFF731b1d);

  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: const Color(0xFF121212),
    colorScheme: ColorScheme.fromSeed(
      seedColor: dragonBurgundy,
      brightness: Brightness.dark,
      surface: const Color(0xFF121212),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: dragonBurgundy,
      foregroundColor: Colors.white,
      elevation: 2,
    ),
    cardColor: AtmosphereColors.cardDark,
    textTheme: const TextTheme(
      headlineLarge: TextStyle(
        color: AtmosphereColors.textPrimaryDark,
        fontSize: 32,
        fontWeight: FontWeight.bold,
      ),
      headlineMedium: TextStyle(
        color: AtmosphereColors.textPrimaryDark,
        fontSize: 24,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: TextStyle(
        color: AtmosphereColors.textPrimaryDark,
        fontSize: 16,
      ),
      bodyMedium: TextStyle(
        color: AtmosphereColors.textSecondaryDark,
        fontSize: 14,
      ),
      labelSmall: TextStyle(
        color: AtmosphereColors.textSecondaryDark,
        fontSize: 12,
      ),
    ),
  );

  static ThemeData get light => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: AtmosphereColors.surfaceLight,
    colorScheme: ColorScheme.fromSeed(
      seedColor: dragonBurgundy,
      brightness: Brightness.light,
      surface: AtmosphereColors.surfaceLight,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: dragonBurgundy,
      foregroundColor: Colors.white,
      elevation: 2,
    ),
    cardColor: AtmosphereColors.cardLight,
    textTheme: const TextTheme(
      headlineLarge: TextStyle(
        color: AtmosphereColors.textPrimaryLight,
        fontSize: 32,
        fontWeight: FontWeight.bold,
      ),
      headlineMedium: TextStyle(
        color: AtmosphereColors.textPrimaryLight,
        fontSize: 24,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: TextStyle(
        color: AtmosphereColors.textPrimaryLight,
        fontSize: 16,
      ),
      bodyMedium: TextStyle(
        color: AtmosphereColors.textSecondaryLight,
        fontSize: 14,
      ),
      labelSmall: TextStyle(
        color: AtmosphereColors.textSecondaryLight,
        fontSize: 12,
      ),
    ),
  );
}
