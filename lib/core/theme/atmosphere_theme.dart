import 'package:flutter/material.dart';

import 'atmosphere_colors.dart';

class AtmosphereTheme {
  AtmosphereTheme._();

  static ThemeData get dark => ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AtmosphereColors.surfaceDark,
    colorScheme: const ColorScheme.dark(
      surface: AtmosphereColors.surfaceDark,
      primary: AtmosphereColors.mediumBlue,
      secondary: AtmosphereColors.blueGrey,
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
    brightness: Brightness.light,
    scaffoldBackgroundColor: AtmosphereColors.surfaceLight,
    colorScheme: const ColorScheme.light(
      surface: AtmosphereColors.surfaceLight,
      primary: AtmosphereColors.mediumBlue,
      secondary: AtmosphereColors.blueGrey,
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
