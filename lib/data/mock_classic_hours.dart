import '../models/condition_state.dart';
import '../models/forecast.dart';

/// Generates full 24-hour days for Classic Mode CDS chart.
/// 3 days x 24 hours = 72 hours per location.
/// Nighttime hours (19:00–04:00) carry real astro data.
/// Daytime hours (05:00–18:00) have weather-only data; seeing/transparency/
/// darkness values exist but Classic Mode renders them as daytimeNoData.

List<HourlyForecast> generateClassicHours(String locationName) {
  switch (locationName) {
    case 'Pietown, NM':
      return _pietownFullTimeline();
    case 'Charlotte, NC':
      return _charlotteFullTimeline();
    default:
      return [];
  }
}

// ═══════════════════════════════════════════════════════════════
// Pietown, NM — 3 full days
// ═══════════════════════════════════════════════════════════════

List<HourlyForecast> _pietownFullTimeline() {
  final now = DateTime.now();
  final hours = <HourlyForecast>[];

  for (var day = 0; day < 3; day++) {
    final date = now.add(Duration(days: day));
    for (var h = 0; h < 24; h++) {
      final time = DateTime(date.year, date.month, date.day, h);
      hours.add(_pietownHour(time, day, h));
    }
  }
  return hours;
}

HourlyForecast _pietownHour(DateTime time, int day, int hour) {
  // Pietown: high desert, exceptional skies, Bortle 1
  final isDaytime = hour >= 5 && hour < 19;

  // Temperature curve: cool at night (0–6°C), warm daytime (15–28°C)
  final temp = isDaytime
      ? _lerp(12.0, 28.0, _daytimeCurve(hour)) - day * 2
      : _lerp(0.0, 6.0, _nightProgression(hour)) - day * 1;

  // Cloud cover: mostly clear, slight afternoon cumulus
  final cloud = isDaytime
      ? _lerpI(5.0, 25.0, _afternoonBump(hour)) + day * 3
      : _lerpI(2.0, 15.0, _nightProgression(hour)) + day * 4;

  final ecmwf = (cloud + 2 + day).clamp(0, 100).toDouble();

  // Wind: light, picks up in afternoon
  final wind = isDaytime
      ? _lerp(3.0, 10.0, _afternoonBump(hour))
      : _lerp(1.0, 5.0, _nightProgression(hour));

  // Dew spread: very dry desert
  final dewSpread = isDaytime
      ? _lerp(20.0, 25.0, _daytimeCurve(hour))
      : _lerp(7.0, 15.0, 1 - _nightProgression(hour));

  // Seeing (night only meaningful): 3–5
  final seeing = isDaytime ? 3 : (5 - _nightProgression(hour)).round().clamp(3, 5);
  // Transparency: 3–5
  final transparency = isDaytime ? 3 : (5 - _nightProgression(hour) * 0.5).round().clamp(3, 5);

  // Darkness
  final ceilingBase = [7.9, 7.7, 7.4][day];
  final actualBase = [7.4, 7.1, 6.8][day];
  final darknessMult = isDaytime ? 0.3 : _darknessCurve(hour);

  return HourlyForecast(
    time: time,
    cloudCoverPercent: cloud.toDouble().clamp(0, 100),
    ecmwfCloudPercent: ecmwf.clamp(0, 100),
    seeing: seeing,
    transparency: transparency,
    windMph: wind.clamp(0, 50),
    gustMph: isDaytime && hour >= 13 && hour <= 17 ? wind * 1.5 : 0,
    windDirectionDeg: 200 + hour * 5.0,
    dewSpreadC: dewSpread.clamp(0, 30),
    temperatureC: temp,
    dewPointC: temp - dewSpread,
    smokePm25: 2.0 + day,
    moonIlluminationPercent: 18,
    moonAltitudeDeg: isDaytime ? -20 : (25 - hour * 3.0),
    moonAzimuthDeg: hour * 15.0,
    kpIndex: 1,
    gltHeatFlux: isDaytime ? 200 : _lerp(120, -25, _nightProgression(hour)),
    bltCeilingM: isDaytime ? 2000 : _lerp(1400, 150, _nightProgression(hour)),
    jsWindSpeedKt: _lerp(15, 42, _nightProgression(hour)),
    limitingMagnitude: actualBase * darknessMult,
    darknessCeiling: ceilingBase * darknessMult,
    condition: isDaytime
        ? ConditionState.good
        : _pietownNightCondition(hour, day),
  );
}

ConditionState _pietownNightCondition(int hour, int day) {
  if (day == 0) {
    if (hour >= 21 || hour <= 1) return ConditionState.exceptional;
    if (hour >= 19) return ConditionState.excellent;
    return ConditionState.good;
  }
  if (day == 1) {
    if (hour >= 22 || hour <= 0) return ConditionState.excellent;
    return ConditionState.good;
  }
  return ConditionState.good;
}

// ═══════════════════════════════════════════════════════════════
// Charlotte, NC — 3 full days
// ═══════════════════════════════════════════════════════════════

List<HourlyForecast> _charlotteFullTimeline() {
  final now = DateTime.now();
  final hours = <HourlyForecast>[];

  for (var day = 0; day < 3; day++) {
    final date = now.add(Duration(days: day));
    for (var h = 0; h < 24; h++) {
      final time = DateTime(date.year, date.month, date.day, h);
      hours.add(_charlotteHour(time, day, h));
    }
  }
  return hours;
}

HourlyForecast _charlotteHour(DateTime time, int day, int hour) {
  // Charlotte: humid, urban, Bortle 7, variable clouds
  final isDaytime = hour >= 5 && hour < 19;

  // Temperature: mild (0–22°C range)
  final temp = isDaytime
      ? _lerp(10.0, 22.0, _daytimeCurve(hour)) - day
      : _lerp(-1.0, 8.0, 1 - _nightProgression(hour)) - day;

  // Cloud cover: much more variable
  final cloudBase = [65.0, 75.0, 40.0][day]; // per-day variation
  final cloud = isDaytime
      ? _lerpI(cloudBase - 15, cloudBase + 10, _afternoonBump(hour))
      : _lerpI(cloudBase - 20, cloudBase, _nightProgression(hour));

  final ecmwf = (cloud - 5 + day * 2).clamp(0, 100).toDouble();

  // Wind: moderate
  final wind = isDaytime
      ? _lerp(8.0, 15.0, _afternoonBump(hour))
      : _lerp(3.0, 8.0, _nightProgression(hour));

  // Dew spread: humid, tight
  final dewSpread = isDaytime
      ? _lerp(5.0, 10.0, _daytimeCurve(hour))
      : _lerp(3.0, 7.0, _nightProgression(hour));

  // Seeing: 2–4
  final seeing = isDaytime ? 2 : (day == 2 ? 3 : 2) + (_nightProgression(hour) > 0.5 ? 1 : 0);
  final transparency = isDaytime ? 2 : (day == 2 ? 3 : 2) + (_nightProgression(hour) > 0.6 ? 1 : 0);

  // Smoke: urban area
  final smoke = isDaytime
      ? _lerp(10.0, 25.0, _afternoonBump(hour))
      : _lerp(8.0, 22.0, 1 - _nightProgression(hour));

  // Darkness: Bortle 7, much worse
  final ceilingBase = [7.6, 7.4, 7.7][day];
  final actualBase = [4.8, 4.5, 5.0][day];
  final darknessMult = isDaytime ? 0.2 : _darknessCurve(hour);

  return HourlyForecast(
    time: time,
    cloudCoverPercent: cloud.toDouble().clamp(0, 100),
    ecmwfCloudPercent: ecmwf.clamp(0, 100),
    seeing: seeing.clamp(1, 5),
    transparency: transparency.clamp(1, 5),
    windMph: wind.clamp(0, 50),
    gustMph: wind * 1.6,
    windDirectionDeg: 310 + hour * 4.0,
    dewSpreadC: dewSpread.clamp(0, 30),
    temperatureC: temp,
    dewPointC: temp - dewSpread,
    smokePm25: smoke.clamp(0, 100),
    moonIlluminationPercent: 72,
    moonAltitudeDeg: isDaytime ? -10 : (40 - (hour - 19).abs() * 5.0),
    moonAzimuthDeg: hour * 15.0,
    kpIndex: (day == 2 ? 4 : 2 + day).toDouble(),
    gltHeatFlux: isDaytime ? 250 : _lerp(180, -20, _nightProgression(hour)),
    bltCeilingM: isDaytime ? 2200 : _lerp(1800, 200, _nightProgression(hour)),
    jsWindSpeedKt: _lerp(35, 60, _nightProgression(hour)),
    limitingMagnitude: actualBase * darknessMult,
    darknessCeiling: ceilingBase * darknessMult,
    condition: isDaytime
        ? ConditionState.marginalImproving
        : _charlotteNightCondition(hour, day),
  );
}

ConditionState _charlotteNightCondition(int hour, int day) {
  if (day == 0) {
    if (hour >= 23 || hour <= 1) return ConditionState.good;
    if (hour >= 19 && hour < 21) return ConditionState.overcast;
    return ConditionState.marginalImproving;
  }
  if (day == 1) {
    return ConditionState.overcast;
  }
  // Day 2: better
  if (hour >= 22 || hour <= 2) return ConditionState.good;
  return ConditionState.marginalImproving;
}

// ═══════════════════════════════════════════════════════════════
// Helper curves
// ═══════════════════════════════════════════════════════════════

/// 0→1 curve peaking mid-afternoon (~14:00)
double _daytimeCurve(int hour) {
  if (hour < 5 || hour > 18) return 0;
  final mid = 14.0;
  final span = 7.0;
  return (1 - ((hour - mid) / span).abs()).clamp(0.0, 1.0);
}

/// 0→1 bump peaking at ~15:00 for afternoon thermals
double _afternoonBump(int hour) {
  if (hour < 10 || hour > 18) return 0;
  final peak = 15.0;
  final width = 4.0;
  return (1 - ((hour - peak) / width).abs()).clamp(0.0, 1.0);
}

/// 0→1 progression through the night (19→04)
double _nightProgression(int hour) {
  if (hour >= 19) return (hour - 19) / 9.0;
  if (hour <= 4) return (hour + 5) / 9.0;
  return 0;
}

/// 0→1 darkness depth: peaks at 00–02, low at twilight
double _darknessCurve(int hour) {
  if (hour >= 19 && hour <= 20) return 0.5 + (hour - 19) * 0.2;
  if (hour >= 21 && hour <= 23) return 0.85 + (hour - 21) * 0.05;
  if (hour >= 0 && hour <= 2) return 1.0;
  if (hour >= 3 && hour <= 4) return 0.9 - (hour - 3) * 0.15;
  return 0.3; // daytime fallback
}

double _lerp(double a, double b, double t) => a + (b - a) * t.clamp(0.0, 1.0);
double _lerpI(double a, double b, double t) => (a + (b - a) * t.clamp(0.0, 1.0));
