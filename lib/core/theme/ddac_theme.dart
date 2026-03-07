import 'dart:ui';

import '../../models/forecast.dart';
import 'atmosphere_colors.dart';

/// DDACTheme — CDS-faithful color system for Classic Mode.
/// Named constants with remote-override slots per spec Section 9.
class DDACTheme {
  DDACTheme._();

  // Layout
  static const Color chartBackground = Color(0xFF000000);
  static const Color nowMarker = Color(0xFFFF0000);
  static const Color divider = Color(0xFF444444);
  static const Color selectionBox = Color(0xFFFFFFFF);
  static const Color daytimeNoData = Color(0xFFD4B896);
  static const Color rowLabelText = Color(0xFFCCCCCC);
  static const Color timeAxisText = Color(0xFF999999);

  // CDS-faithful accent colors
  static const Color cdsTextCyan = Color(0xFF00FFFF);
  static const Color cdsTitleYellow = Color(0xFFFFFF00);
  static const Color midnightLine = Color(0xFFFF0000);
  static const Color skyGroupLabel = Color(0xFF4488FF);
  static const Color groundGroupLabel = Color(0xFFFFAA00);

  // ── Cloud Cover / ECMWF Cloud ──
  // 0% = clear sky (deep indigo) → 100% = overcast (pale grey)
  static Color forCloudPercent(double pct) {
    if (pct <= 5) return AtmosphereColors.deepIndigo;
    if (pct <= 20) return AtmosphereColors.deepBlue;
    if (pct <= 40) return AtmosphereColors.mediumBlue;
    if (pct <= 60) return AtmosphereColors.blueGrey;
    if (pct <= 80) return AtmosphereColors.greyBlue;
    return AtmosphereColors.paleGrey;
  }

  // ── Transparency (1-5 scale) ──
  static Color forTransparency(int value) {
    switch (value) {
      case 5:
        return AtmosphereColors.deepIndigo;
      case 4:
        return AtmosphereColors.deepBlue;
      case 3:
        return AtmosphereColors.mediumBlue;
      case 2:
        return AtmosphereColors.blueGrey;
      default:
        return AtmosphereColors.greyBlue;
    }
  }

  // ── Seeing (1-5 scale) ──
  static Color forSeeing(int value) {
    switch (value) {
      case 5:
        return AtmosphereColors.deepIndigo;
      case 4:
        return AtmosphereColors.deepBlue;
      case 3:
        return AtmosphereColors.mediumBlue;
      case 2:
        return AtmosphereColors.blueGrey;
      default:
        return AtmosphereColors.greyBlue;
    }
  }

  // ── Darkness (limiting magnitude) ──
  static Color forDarkness(double mag) {
    return AtmosphereColors.forLimitingMagnitude(mag);
  }

  // ── Smoke (PM2.5 µg/m³) ──
  // Low smoke = good (deep indigo), high = bad (pale grey)
  static Color forSmoke(double pm25) {
    if (pm25 <= 5) return AtmosphereColors.deepIndigo;
    if (pm25 <= 12) return AtmosphereColors.deepBlue;
    if (pm25 <= 20) return AtmosphereColors.mediumBlue;
    if (pm25 <= 35) return AtmosphereColors.blueGrey;
    if (pm25 <= 55) return AtmosphereColors.amberGrey;
    return AtmosphereColors.paleGrey;
  }

  // ── Wind (mph) ──
  // Calm = good (deep indigo), windy = bad (pale grey)
  static Color forWind(double mph) {
    if (mph <= 3) return AtmosphereColors.deepIndigo;
    if (mph <= 7) return AtmosphereColors.deepBlue;
    if (mph <= 12) return AtmosphereColors.mediumBlue;
    if (mph <= 20) return AtmosphereColors.blueGrey;
    if (mph <= 30) return AtmosphereColors.greyBlue;
    return AtmosphereColors.paleGrey;
  }

  // ── Humidity (dew spread °C) ──
  // Large spread = dry = good, small spread = saturated = bad
  static Color forHumidity(double dewSpreadC) {
    if (dewSpreadC >= 15) return AtmosphereColors.deepIndigo;
    if (dewSpreadC >= 10) return AtmosphereColors.deepBlue;
    if (dewSpreadC >= 6) return AtmosphereColors.mediumBlue;
    if (dewSpreadC >= 3) return AtmosphereColors.blueGrey;
    if (dewSpreadC >= 1) return AtmosphereColors.greyBlue;
    return AtmosphereColors.paleGrey;
  }

  // ── Temperature (°C) — CDS uses orange→red→green→blue gradient ──
  static Color forTemperature(double tempC) {
    if (tempC >= 30) return const Color(0xFFCC3333); // hot red
    if (tempC >= 20) return const Color(0xFFDD7733); // warm orange
    if (tempC >= 10) return const Color(0xFF88AA44); // mild green
    if (tempC >= 0) return const Color(0xFF4488AA); // cool blue-green
    if (tempC >= -10) return const Color(0xFF336699); // cold blue
    return const Color(0xFF224477); // frigid deep blue
  }

  /// Whether this hour is daytime (no data for seeing/transparency/darkness).
  static bool isDaytime(DateTime time) {
    return time.hour >= 5 && time.hour < 19;
  }

  /// Get chicklet color for a given row and hour.
  static Color chickletColor(ClassicRow row, HourlyForecast hour) {
    final daytime = isDaytime(hour.time);

    switch (row) {
      case ClassicRow.cloudCover:
        return forCloudPercent(hour.cloudCoverPercent);
      case ClassicRow.ecmwfCloud:
        return forCloudPercent(hour.ecmwfCloudPercent);
      case ClassicRow.transparency:
        return daytime ? daytimeNoData : forTransparency(hour.transparency);
      case ClassicRow.seeing:
        return daytime ? daytimeNoData : forSeeing(hour.seeing);
      case ClassicRow.darkness:
        return daytime ? daytimeNoData : forDarkness(hour.limitingMagnitude);
      case ClassicRow.smoke:
        return forSmoke(hour.smokePm25);
      case ClassicRow.wind:
        return forWind(hour.windMph);
      case ClassicRow.humidity:
        return forHumidity(hour.dewSpreadC);
      case ClassicRow.temperature:
        return forTemperature(hour.temperatureC);
    }
  }
}

/// The 9 CDS rows in display order.
/// Sky group: Cloud Cover → Darkness (top 5)
/// Ground group: Smoke → Temperature (bottom 4)
enum ClassicRow {
  cloudCover('Cloud Cover'),
  ecmwfCloud('ECMWF Cloud'),
  transparency('Transparency'),
  seeing('Seeing'),
  darkness('Darkness'),
  // ── sky/ground gap ──
  smoke('Smoke'),
  wind('Wind'),
  humidity('Humidity'),
  temperature('Temperature');

  final String label;
  const ClassicRow(this.label);

  bool get isSkyGroup => index <= ClassicRow.darkness.index;

  /// Whether this row shows daytimeNoData during daytime.
  bool get hasDaytimeBlank =>
      this == ClassicRow.seeing ||
      this == ClassicRow.transparency ||
      this == ClassicRow.darkness;

  /// Whether this row uses 3-hour blocks (ECMWF model data).
  bool get isThreeHour => this == ClassicRow.ecmwfCloud;
}
