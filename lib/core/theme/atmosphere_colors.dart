import 'dart:ui';

import '../../models/condition_state.dart';

class AtmosphereColors {
  AtmosphereColors._();

  // CDS Color Palette
  static const Color deepIndigo = Color(0xFF0A0A2E);
  static const Color deepBlue = Color(0xFF0D1B4A);
  static const Color mediumBlue = Color(0xFF2E5090);
  static const Color blueGrey = Color(0xFF5A7B9A);
  static const Color greyBlue = Color(0xFF7A8A9A);
  static const Color darkGrey = Color(0xFF4A4A5A);
  static const Color amberGrey = Color(0xFF8A7A5A);
  static const Color paleGrey = Color(0xFFA0A0A8);

  // Surface colors
  static const Color surfaceDark = Color(0xFF0E0E1A);
  static const Color surfaceLight = Color(0xFFF5F5F8);
  static const Color cardDark = Color(0xFF1A1A2E);
  static const Color cardLight = Color(0xFFFFFFFF);

  // Text colors
  static const Color textPrimaryDark = Color(0xFFE8E8F0);
  static const Color textSecondaryDark = Color(0xFFA0A0B0);
  static const Color textPrimaryLight = Color(0xFF1A1A2E);
  static const Color textSecondaryLight = Color(0xFF6A6A7A);

  // Layer depth colors (for depth indicator dots)
  static const Color layer1Dot = deepIndigo;
  static const Color layer2Dot = deepBlue;
  static const Color layer3Dot = mediumBlue;
  static const Color layer4Dot = blueGrey;

  // CDS Darkness color vocabulary
  static const Color darknessBlack = Color(0xFF0A0A14); // Mag 7.6+
  static const Color darknessDeepBlue = Color(0xFF0D1B4A); // Mag 6.5–7.5
  static const Color darknessBlue = Color(0xFF2E5090); // Mag 5.5–6.4
  static const Color darknessLightBlue = Color(0xFF5A7B9A); // Mag 4.0–5.4
  static const Color darknessTurquoise = Color(0xFF4A9A8A); // Mag 2.0–3.9
  static const Color darknessYellow = Color(0xFFB8A860); // Mag < 2.0
  static const Color lpFloorAmber = Color(0xFFD4A843); // LP floor band

  static Color forLimitingMagnitude(double mag) {
    if (mag >= 7.6) return darknessBlack;
    if (mag >= 6.5) return darknessDeepBlue;
    if (mag >= 5.5) return darknessBlue;
    if (mag >= 4.0) return darknessLightBlue;
    if (mag >= 2.0) return darknessTurquoise;
    return darknessYellow;
  }

  // Bortle class colors (Lorenz / CDS vocabulary)
  static const bortleColors = <Color>[
    Color(0xFF000000), // 1 — true dark
    Color(0xFF05031A), // 2
    Color(0xFF0A062D), // 3 — rural
    Color(0xFF00234B), // 4
    Color(0xFF00465F), // 5 — suburban
    Color(0xFF1E5F1E), // 6
    Color(0xFFAA8700), // 7
    Color(0xFFD24100), // 8 — city
    Color(0xFFFF1405), // 9 — inner city
  ];

  static Color forBortle(int bortleClass) {
    final idx = (bortleClass - 1).clamp(0, bortleColors.length - 1);
    return bortleColors[idx];
  }

  static Color forCondition(ConditionState condition) {
    switch (condition) {
      case ConditionState.exceptional:
        return deepIndigo;
      case ConditionState.excellent:
        return deepBlue;
      case ConditionState.good:
      case ConditionState.astroDarkGood:
        return mediumBlue;
      case ConditionState.marginalImproving:
      case ConditionState.marginalDegrading:
        return blueGrey;
      case ConditionState.poorGap:
      case ConditionState.poorSeeing:
      case ConditionState.astroDarkPoor:
        return greyBlue;
      case ConditionState.overcast:
      case ConditionState.multiDayOvercast:
        return darkGrey;
      case ConditionState.smoke:
        return amberGrey;
      case ConditionState.fog:
        return paleGrey;
    }
  }
}
