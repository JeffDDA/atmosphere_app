import 'dart:math';

import 'condition_state.dart';

class HourlyForecast {
  final DateTime time;
  final double cloudCoverPercent;
  final double ecmwfCloudPercent;
  final int seeing; // 0-5 (0 = no data / worst)
  final int transparency; // 0-5 (0 = no data / worst)
  final double windMph;
  final double gustMph;
  final double windDirectionDeg; // 0-360 compass
  final double dewSpreadC;
  final double temperatureC;
  final double dewPointC;
  final double smokePm25;
  final int humidity; // 0-100 %
  final double pwvMm; // precipitable water vapor, mm
  final double kpIndex;
  final double moonIlluminationPercent;
  final double moonAltitudeDeg; // negative = below horizon
  final double moonAzimuthDeg;
  final ConditionState condition;

  // Layer 3 Seeing components
  final double gltHeatFlux; // W/m², sensible heat net flux (SHTFL)
  final double bltCeilingM; // meters AGL, planetary boundary layer height (HPBL)
  final double jsWindSpeedKt; // knots, 250mb wind speed

  // Darkness
  final double limitingMagnitude; // actual NELM accounting for all factors
  final double darknessCeiling; // theoretical max NELM if LP=0 (Sugerman output)

  const HourlyForecast({
    required this.time,
    required this.cloudCoverPercent,
    this.ecmwfCloudPercent = 0,
    required this.seeing,
    required this.transparency,
    required this.windMph,
    this.gustMph = 0,
    this.windDirectionDeg = 0,
    required this.dewSpreadC,
    this.temperatureC = 10,
    this.dewPointC = 0,
    this.smokePm25 = 0,
    this.humidity = 0,
    this.pwvMm = 0,
    this.kpIndex = 0,
    this.moonIlluminationPercent = 0,
    this.moonAltitudeDeg = -10,
    this.moonAzimuthDeg = 0,
    required this.condition,
    this.gltHeatFlux = 0,
    this.bltCeilingM = 500,
    this.jsWindSpeedKt = 30,
    this.limitingMagnitude = 5.5,
    this.darknessCeiling = 7.8,
  });

  /// Construct from a DragonCDS API JSON hour object.
  /// [bortleClass], [latitude], [longitude] from the ForecastResponse location.
  factory HourlyForecast.fromApiJson(
    Map<String, dynamic> json, {
    required int bortleClass,
    required double latitude,
    required double longitude,
  }) {
    // API returns UTC times without 'Z' suffix — force UTC parse, then local
    final timeStr = json['time'] as String;
    final utcTime = DateTime.parse(
      timeStr.endsWith('Z') ? timeStr : '${timeStr}Z',
    );
    final time = utcTime.toLocal();
    final cloud = (json['cloud_cover'] as num?)?.toDouble() ?? 0;
    final seeingRaw = json['seeing'] as int?;
    final transRaw = json['transparency'] as int?;
    final windMs = (json['wind_speed'] as num?)?.toDouble() ?? 0;
    final windDir = (json['wind_direction'] as num?)?.toDouble() ?? 0;
    final tempC = (json['temperature'] as num?)?.toDouble() ?? 10;
    final dewC = (json['dew_point'] as num?)?.toDouble() ?? 0;
    final smoke = (json['smoke_pm25'] as num?)?.toDouble() ?? 0;
    final humid = (json['humidity'] as num?)?.toInt() ?? 0;
    final pwv = (json['pwv_mm'] as num?)?.toDouble() ?? 0;
    final wind250Ms = (json['wind_speed_250hpa'] as num?)?.toDouble();
    // Unit conversions
    final windMph = windMs * 2.237;
    final jsKt = (wind250Ms ?? windMs) * 1.944;

    // Derive condition from raw fields
    final seeing = seeingRaw?.clamp(0, 5) ?? 0;
    final transparency = transRaw?.clamp(0, 5) ?? 0;
    final condition = _deriveCondition(
      cloud: cloud,
      seeing: seeing,
      transparency: transparency,
      smoke: smoke,
      windMph: windMph,
    );

    // Darkness: Schaefer-inspired limiting magnitude
    final darkCeiling = _darknessCeilingForBortle(bortleClass);
    final sunAlt = _estimateSunAltitude(utcTime, latitude, longitude);
    final actualNelm = _computeLimitingMagnitude(
      sunAltDeg: sunAlt,
      darkCeiling: darkCeiling,
      cloudPercent: cloud,
      moonAltDeg: 0, // API doesn't provide moon; computed elsewhere
      moonIllumPercent: 0,
    );

    return HourlyForecast(
      time: time,
      cloudCoverPercent: cloud,
      ecmwfCloudPercent: cloud, // API blends models; use same value for both
      seeing: seeing,
      transparency: transparency,
      windMph: windMph,
      windDirectionDeg: windDir,
      dewSpreadC: tempC - dewC,
      temperatureC: tempC,
      dewPointC: dewC,
      smokePm25: smoke,
      humidity: humid,
      pwvMm: pwv,
      condition: condition,
      jsWindSpeedKt: jsKt,
      limitingMagnitude: actualNelm,
      darknessCeiling: darkCeiling,
    );
  }

  static ConditionState _deriveCondition({
    required double cloud,
    required int seeing,
    required int transparency,
    required double smoke,
    required double windMph,
  }) {
    if (smoke > 35) return ConditionState.smoke;
    if (cloud > 80) return ConditionState.overcast;
    if (cloud > 60) return ConditionState.poorGap;
    if (seeing <= 1 && transparency <= 1) return ConditionState.poorSeeing;
    if (seeing >= 5 && transparency >= 5 && cloud < 10) {
      return ConditionState.exceptional;
    }
    if (seeing >= 4 && transparency >= 4 && cloud < 20) {
      return ConditionState.excellent;
    }
    if (seeing >= 3 && transparency >= 3 && cloud < 35) {
      return ConditionState.good;
    }
    if (cloud < 50 && (seeing >= 2 || transparency >= 2)) {
      return ConditionState.marginalImproving;
    }
    return ConditionState.marginalDegrading;
  }

  static double _darknessCeilingForBortle(int bortle) {
    const ceilings = [7.6, 7.3, 7.0, 6.7, 6.3, 5.8, 5.2, 4.6, 4.0];
    final idx = (bortle - 1).clamp(0, 8);
    return ceilings[idx];
  }

  /// Simplified solar altitude estimation from UTC time and location.
  /// Accurate to ~1° — sufficient for darkness band rendering.
  static double _estimateSunAltitude(
    DateTime utc,
    double latDeg,
    double lonDeg,
  ) {
    final doy =
        utc.difference(DateTime.utc(utc.year, 1, 1)).inDays + 1;

    // Solar declination
    final declRad =
        23.44 * sin((360.0 / 365.0) * (doy - 81) * pi / 180.0) * pi / 180.0;

    // Solar hour angle (approximate solar time from UTC + longitude)
    final solarNoonUtcH = 12.0 - lonDeg / 15.0;
    final utcH = utc.hour + utc.minute / 60.0;
    final hourAngleRad = (utcH - solarNoonUtcH) * 15.0 * pi / 180.0;

    final latRad = latDeg * pi / 180.0;

    // sin(alt) = sin(lat)*sin(decl) + cos(lat)*cos(decl)*cos(HA)
    final sinAlt =
        sin(latRad) * sin(declRad) + cos(latRad) * cos(declRad) * cos(hourAngleRad);

    return asin(sinAlt.clamp(-1.0, 1.0)) * 180.0 / pi;
  }

  /// Schaefer-inspired limiting magnitude from sun altitude, bortle ceiling,
  /// cloud cover, and moon. Matches CDS pipeline's darkness band behavior.
  static double _computeLimitingMagnitude({
    required double sunAltDeg,
    required double darkCeiling,
    required double cloudPercent,
    required double moonAltDeg,
    required double moonIllumPercent,
  }) {
    double mag;

    if (sunAltDeg > 0) {
      // Daylight — very bright
      mag = -4.0;
    } else if (sunAltDeg > -6) {
      // Civil twilight: -4 → 2
      final t = -sunAltDeg / 6.0;
      mag = -4.0 + t * 6.0; // -4 to 2
    } else if (sunAltDeg > -12) {
      // Nautical twilight: 2 → 5
      final t = (-sunAltDeg - 6.0) / 6.0;
      mag = 2.0 + t * 3.0;
    } else if (sunAltDeg > -18) {
      // Astronomical twilight: 5 → darkCeiling
      final t = (-sunAltDeg - 12.0) / 6.0;
      mag = 5.0 + t * (darkCeiling - 5.0);
    } else {
      // Full night — ceiling from bortle class
      mag = darkCeiling;
    }

    // Moon degradation (only significant when moon is up and sky is dark)
    if (moonAltDeg > 0 && sunAltDeg < -6) {
      final moonFrac = moonIllumPercent / 100.0;
      final altFrac = (moonAltDeg / 90.0).clamp(0.0, 1.0);
      mag -= moonFrac * altFrac * 2.0; // Up to 2 mag loss from full moon
    }

    // Cloud degradation
    if (cloudPercent > 0 && mag > 0) {
      mag -= (cloudPercent / 100.0) * 1.5;
    }

    return mag.clamp(-4.0, darkCeiling);
  }
}

class NightForecast {
  final DateTime date;
  final List<HourlyForecast> hours;
  final ConditionState overallCondition;
  final String headline;

  const NightForecast({
    required this.date,
    required this.hours,
    required this.overallCondition,
    required this.headline,
  });
}
