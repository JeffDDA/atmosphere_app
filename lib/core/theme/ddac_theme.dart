import 'dart:ui';

import '../../models/forecast.dart';

/// DDACTheme — CDS-faithful color system for Classic Mode.
/// Colors sourced from cleardarksky-pipeline cmc_grib.py LUTs.
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
  // Smooth gradient from CLOUD_COVER_LUT (101 entries, 0-100%).
  // Key stops: 0%→dark blue, 25%→medium blue, 50%→light blue,
  // 52%→cyan transition, 75%→bright cyan, 78%→gray transition, 100%→near white.
  static const _cloudStops = <(double, Color)>[
    (0, Color(0xFF003E7E)),   // RGB(0, 62, 126)
    (10, Color(0xFF124D8D)),  // RGB(18, 82, 146)
    (25, Color(0xFF3070B0)),  // RGB(48, 112, 176)
    (40, Color(0xFF62A2E2)),  // RGB(98, 162, 226)
    (50, Color(0xFF7BBBFB)),  // RGB(123, 187, 251)
    (52, Color(0xFF80C0C0)),  // RGB(128, 192, 192) — cyan transition
    (65, Color(0xFFA3E7E7)),  // RGB(163, 227, 227)
    (75, Color(0xFFBCFCFC)),  // RGB(188, 252, 252)
    (78, Color(0xFFC1C1C1)),  // RGB(193, 193, 193) — gray transition
    (90, Color(0xFFE9E9E9)),  // RGB(233, 233, 233)
    (100, Color(0xFFFBFBFB)), // RGB(251, 251, 251)
  ];

  static Color forCloudPercent(double pct) {
    final p = pct.clamp(0.0, 100.0);
    // Find surrounding stops and lerp
    for (var i = 0; i < _cloudStops.length - 1; i++) {
      final (lo, cLo) = _cloudStops[i];
      final (hi, cHi) = _cloudStops[i + 1];
      if (p <= hi) {
        final t = (hi == lo) ? 0.0 : (p - lo) / (hi - lo);
        return Color.lerp(cLo, cHi, t)!;
      }
    }
    return _cloudStops.last.$2;
  }

  // ── Seeing/Transparency (0-5 index) — ASTRO_INDEX_LUT ──
  // 0=Worst(white), 1=Very Poor(gray), 2=Poor(cyan),
  // 3=Average(light blue), 4=Good(medium blue), 5=Excellent(dark blue)
  static const _astroIndexColors = <Color>[
    Color(0xFFF9F9F9), // 0: RGB(249, 249, 249)
    Color(0xFFC7C7C7), // 1: RGB(199, 199, 199)
    Color(0xFF95D5D5), // 2: RGB(149, 213, 213)
    Color(0xFF63A3E3), // 3: RGB(99, 163, 227)
    Color(0xFF2C6CAC), // 4: RGB(44, 108, 172)
    Color(0xFF003F7F), // 5: RGB(0, 63, 127)
  ];

  static Color forTransparency(int value) {
    return _astroIndexColors[value.clamp(0, 5)];
  }

  static Color forSeeing(int value) {
    return _astroIndexColors[value.clamp(0, 5)];
  }

  // ── Darkness (limiting magnitude) ──
  // Interpolated from chart_renderer.py breakpoints.
  static const _darknessStops = <(double, Color)>[
    (-4.0, Color(0xFFFFFFFF)),  // RGB(255, 255, 255) — brightest
    (2.0, Color(0xFFFFAA14)),   // RGB(255, 170, 20) — orange
    (3.0, Color(0xFF00FFFF)),   // RGB(0, 255, 255) — cyan
    (4.0, Color(0xFF0096FF)),   // RGB(0, 150, 255) — bright blue
    (5.5, Color(0xFF0000AF)),   // RGB(0, 0, 175) — dark blue
    (6.3, Color(0xFF000000)),   // RGB(0, 0, 0) — black
    (6.5, Color(0xFF00004B)),   // RGB(0, 0, 75) — very dark blue
  ];

  static Color forDarkness(double mag) {
    final m = mag.clamp(-4.0, 6.5);
    for (var i = 0; i < _darknessStops.length - 1; i++) {
      final (lo, cLo) = _darknessStops[i];
      final (hi, cHi) = _darknessStops[i + 1];
      if (m <= hi) {
        final t = (hi == lo) ? 0.0 : (m - lo) / (hi - lo);
        return Color.lerp(cLo, cHi, t)!;
      }
    }
    return _darknessStops.last.$2;
  }

  // ── Smoke (PM2.5 µg/m³) — SMOKE_LUT ──
  static Color forSmoke(double pm25) {
    if (pm25 < 2) return const Color(0xFF003F7F);    // RGB(0, 63, 127)
    if (pm25 < 5) return const Color(0xFF4F8FCF);    // RGB(79, 143, 207)
    if (pm25 < 10) return const Color(0xFF78BEC8);   // RGB(120, 190, 200)
    if (pm25 < 20) return const Color(0xFF87D2C1);   // RGB(135, 210, 193)
    if (pm25 < 40) return const Color(0xFFD68F87);   // RGB(214, 143, 135)
    if (pm25 < 60) return const Color(0xFFC96459);   // RGB(201, 100, 89)
    if (pm25 < 80) return const Color(0xFFBD3B2D);   // RGB(189, 59, 45)
    if (pm25 < 100) return const Color(0xFFB51504);  // RGB(181, 21, 4)
    if (pm25 < 200) return const Color(0xFF654321);  // RGB(101, 67, 33)
    return const Color(0xFF37220F);                   // RGB(55, 34, 15)
  }

  // ── Wind (mph — converted from m/s WIND_LUT thresholds) ──
  // LUT bands: 0-1 m/s, 2-3, 4-5, 6-9, 10-15, 16+
  // Converted: ≤2.2mph, ≤6.7, ≤11.2, ≤20.1, ≤33.6, >33.6
  static Color forWind(double mph) {
    if (mph <= 2.2) return const Color(0xFF003E7E);   // RGB(0, 62, 126)
    if (mph <= 6.7) return const Color(0xFF2B6BAB);   // RGB(43, 107, 171)
    if (mph <= 11.2) return const Color(0xFF62A2E2);  // RGB(98, 162, 226)
    if (mph <= 20.1) return const Color(0xFF94D4D4);  // RGB(148, 212, 212)
    if (mph <= 33.6) return const Color(0xFFC6C6C6);  // RGB(198, 198, 198)
    return const Color(0xFFF8F8F8);                    // RGB(248, 248, 248)
  }

  // ── Humidity (raw RH %) — HUMIDITY_LUT ──
  // 16 discrete bands from dark purple (dry) through cyan/green/yellow/red (wet)
  static Color forHumidity(int rh) {
    if (rh < 25) return const Color(0xFF08035D);      // RGB(8, 3, 93)
    if (rh < 30) return const Color(0xFF0D4D8D);      // RGB(13, 77, 141)
    if (rh < 35) return const Color(0xFF3070B0);      // RGB(48, 112, 176)
    if (rh < 40) return const Color(0xFF4E8ECE);      // RGB(78, 142, 206)
    if (rh < 45) return const Color(0xFF71B1F1);      // RGB(113, 177, 241)
    if (rh < 50) return const Color(0xFF80C0C0);      // RGB(128, 192, 192)
    if (rh < 55) return const Color(0xFF08FEED);      // RGB(8, 254, 237)
    if (rh < 60) return const Color(0xFF55FAAD);      // RGB(85, 250, 173)
    if (rh < 65) return const Color(0xFF94FE6A);      // RGB(148, 254, 106)
    if (rh < 70) return const Color(0xFFEAFB16);      // RGB(234, 251, 22)
    if (rh < 75) return const Color(0xFFFEC600);      // RGB(254, 198, 0)
    if (rh < 80) return const Color(0xFFFC8602);      // RGB(252, 134, 2)
    if (rh < 85) return const Color(0xFFFE3401);      // RGB(254, 52, 1)
    if (rh < 90) return const Color(0xFFEA0000);      // RGB(234, 0, 0)
    if (rh < 95) return const Color(0xFFB70000);      // RGB(183, 0, 0)
    return const Color(0xFFE10000);                    // RGB(225, 0, 0)
  }

  // ── Temperature (°C) — TEMPERATURE_LUT (Kelvin offset by 200) ──
  static Color forTemperature(double tempC) {
    if (tempC < -40) return const Color(0xFFFC00FC);  // RGB(252, 0, 252) magenta
    if (tempC < -35) return const Color(0xFF000084);  // RGB(0, 0, 132)
    if (tempC < -30) return const Color(0xFF0000B2);  // RGB(0, 0, 178)
    if (tempC < -25) return const Color(0xFF0000EB);  // RGB(0, 0, 235)
    if (tempC < -20) return const Color(0xFF0033FD);  // RGB(0, 51, 253)
    if (tempC < -15) return const Color(0xFF0088FD);  // RGB(0, 136, 253)
    if (tempC < -10) return const Color(0xFF00D3FD);  // RGB(0, 211, 253)
    if (tempC < -5) return const Color(0xFF1DFDDD);   // RGB(29, 253, 221) cyan
    if (tempC < 0) return const Color(0xFFFAFAFA);    // RGB(250, 250, 250) white
    if (tempC < 5) return const Color(0xFF5DFD9D);    // RGB(93, 253, 157) light green
    if (tempC < 10) return const Color(0xFFA1FD59);   // RGB(161, 253, 89) green
    if (tempC < 15) return const Color(0xFFFDDD00);   // RGB(253, 221, 0) yellow
    if (tempC < 20) return const Color(0xFFFD9D00);   // RGB(253, 157, 0) orange
    if (tempC < 25) return const Color(0xFFFD5900);   // RGB(253, 89, 0) orange-red
    if (tempC < 30) return const Color(0xFFFD1D00);   // RGB(253, 29, 0) red-orange
    if (tempC < 35) return const Color(0xFFE10000);   // RGB(225, 0, 0) red
    if (tempC < 40) return const Color(0xFFA80000);   // RGB(168, 0, 0) dark red
    if (tempC < 45) return const Color(0xFF7D0000);   // RGB(125, 0, 0) very dark red
    return const Color(0xFFC6C6C6);                    // RGB(198, 198, 198) off-scale
  }

  /// Whether this hour is daytime (no data for seeing/transparency/darkness).
  static bool isDaytime(DateTime time) {
    return time.hour >= 5 && time.hour < 19;
  }

  /// Get chicklet color for a given row and hour.
  static Color chickletColor(ClassicRow row, HourlyForecast hour) {
    switch (row) {
      case ClassicRow.cloudCover:
        return forCloudPercent(hour.cloudCoverPercent);
      case ClassicRow.ecmwfCloud:
        return forCloudPercent(hour.ecmwfCloudPercent);
      case ClassicRow.transparency:
        return forTransparency(hour.transparency);
      case ClassicRow.seeing:
        return forSeeing(hour.seeing);
      case ClassicRow.darkness:
        return forDarkness(hour.limitingMagnitude);
      case ClassicRow.smoke:
        return forSmoke(hour.smokePm25);
      case ClassicRow.wind:
        return forWind(hour.windMph);
      case ClassicRow.humidity:
        return forHumidity(hour.humidity);
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
