import '../models/condition_state.dart';
import '../models/forecast.dart';

// Pietown NM — exceptional tonight
final pietownTonight = NightForecast(
  date: DateTime.now(),
  overallCondition: ConditionState.exceptional,
  headline: 'Extraordinary clarity tonight. Every photon is yours.',
  hours: _generatePietownHours(DateTime.now()),
);

final pietownTomorrow = NightForecast(
  date: DateTime.now().add(const Duration(days: 1)),
  overallCondition: ConditionState.good,
  headline: 'Solid night ahead. Good transparency, steady seeing.',
  hours: _generatePietownHours(DateTime.now().add(const Duration(days: 1))),
);

final pietownDayAfter = NightForecast(
  date: DateTime.now().add(const Duration(days: 2)),
  overallCondition: ConditionState.marginalDegrading,
  headline: 'Conditions softening. Shoot your priority targets first.',
  hours: _generatePietownHours(DateTime.now().add(const Duration(days: 2))),
);

// Charlotte NC — marginal improving
final charlotteTonight = NightForecast(
  date: DateTime.now(),
  overallCondition: ConditionState.marginalImproving,
  headline: 'Conditions improving. A window may open later.',
  hours: _generateCharlotteHours(DateTime.now()),
);

final charlotteTomorrow = NightForecast(
  date: DateTime.now().add(const Duration(days: 1)),
  overallCondition: ConditionState.overcast,
  headline: 'Overcast tonight. Rest your gear.',
  hours: _generateCharlotteHours(DateTime.now().add(const Duration(days: 1))),
);

final charlotteDayAfter = NightForecast(
  date: DateTime.now().add(const Duration(days: 2)),
  overallCondition: ConditionState.good,
  headline: 'Solid night ahead. Good transparency, steady seeing.',
  hours: _generateCharlotteHours(DateTime.now().add(const Duration(days: 2))),
);

final mockForecasts = <String, List<NightForecast>>{
  'Pietown, NM': [pietownTonight, pietownTomorrow, pietownDayAfter],
  'Charlotte, NC': [charlotteTonight, charlotteTomorrow, charlotteDayAfter],
};

List<HourlyForecast> _generatePietownHours(DateTime date) {
  // Pietown: exceptional seeing — low GLT (high desert cools fast),
  // BLT collapses quickly, weak jet stream overhead
  // Darkness: Bortle 1 (SQM 21.8), 18% crescent moon sets hour 2
  final ct = DateTime(date.year, date.month, date.day, 19);

  // Per-night darkness variation: night 0 = plan values,
  // night 1 = slightly worse (thin cirrus), night 2 = degraded
  final dayOffset = date.difference(DateTime.now()).inDays.clamp(0, 2);
  final ceilings = [
    [4.8, 6.2, 7.2, 7.9, 7.9, 7.9, 7.8, 7.8, 7.6, 6.8], // tonight
    [4.6, 6.0, 7.0, 7.7, 7.7, 7.7, 7.6, 7.5, 7.3, 6.5], // tomorrow
    [4.5, 5.8, 6.8, 7.4, 7.4, 7.3, 7.2, 7.0, 6.8, 6.2], // day after
  ][dayOffset];
  final actuals = [
    [4.5, 5.8, 6.5, 7.4, 7.4, 7.4, 7.4, 7.3, 7.2, 6.5], // tonight
    [4.3, 5.5, 6.2, 7.1, 7.1, 7.0, 7.0, 6.9, 6.8, 6.2], // tomorrow
    [4.2, 5.3, 6.0, 6.8, 6.8, 6.7, 6.5, 6.3, 6.0, 5.5], // day after
  ][dayOffset];

  return [
    HourlyForecast(
      time: ct,
      cloudCoverPercent: 5, ecmwfCloudPercent: 8,
      seeing: 4, transparency: 5, windMph: 3, windDirectionDeg: 210,
      dewSpreadC: 15, temperatureC: 12, dewPointC: -3,
      moonIlluminationPercent: 18, moonAltitudeDeg: 25, moonAzimuthDeg: 240,
      gltHeatFlux: 120, bltCeilingM: 1400, jsWindSpeedKt: 25,
      limitingMagnitude: actuals[0], darknessCeiling: ceilings[0],
      condition: ConditionState.excellent,
    ),
    HourlyForecast(
      time: ct.add(const Duration(hours: 1)),
      cloudCoverPercent: 3, ecmwfCloudPercent: 5,
      seeing: 5, transparency: 5, windMph: 2, windDirectionDeg: 220,
      dewSpreadC: 14, temperatureC: 10, dewPointC: -4,
      moonIlluminationPercent: 18, moonAltitudeDeg: 15, moonAzimuthDeg: 255,
      gltHeatFlux: 60, bltCeilingM: 900, jsWindSpeedKt: 22,
      limitingMagnitude: actuals[1], darknessCeiling: ceilings[1],
      condition: ConditionState.exceptional,
    ),
    HourlyForecast(
      time: ct.add(const Duration(hours: 2)),
      cloudCoverPercent: 2, ecmwfCloudPercent: 4,
      seeing: 5, transparency: 5, windMph: 2, gustMph: 4, windDirectionDeg: 220,
      dewSpreadC: 13, temperatureC: 8, dewPointC: -5,
      moonIlluminationPercent: 18, moonAltitudeDeg: 5, moonAzimuthDeg: 270,
      gltHeatFlux: 20, bltCeilingM: 550, jsWindSpeedKt: 20,
      limitingMagnitude: actuals[2], darknessCeiling: ceilings[2],
      condition: ConditionState.exceptional,
    ),
    HourlyForecast(
      time: ct.add(const Duration(hours: 3)),
      cloudCoverPercent: 2, ecmwfCloudPercent: 3,
      seeing: 5, transparency: 5, windMph: 1, windDirectionDeg: 200,
      dewSpreadC: 12, temperatureC: 6, dewPointC: -6,
      moonIlluminationPercent: 18, moonAltitudeDeg: -5, moonAzimuthDeg: 285,
      gltHeatFlux: -5, bltCeilingM: 350, jsWindSpeedKt: 18,
      limitingMagnitude: actuals[3], darknessCeiling: ceilings[3],
      condition: ConditionState.exceptional,
    ),
    HourlyForecast(
      time: ct.add(const Duration(hours: 4)),
      cloudCoverPercent: 3, ecmwfCloudPercent: 5,
      seeing: 5, transparency: 5, windMph: 2, windDirectionDeg: 190,
      dewSpreadC: 11, temperatureC: 5, dewPointC: -6,
      moonIlluminationPercent: 18, moonAltitudeDeg: -15, moonAzimuthDeg: 300,
      gltHeatFlux: -15, bltCeilingM: 250, jsWindSpeedKt: 15,
      limitingMagnitude: actuals[4], darknessCeiling: ceilings[4],
      condition: ConditionState.exceptional,
    ),
    HourlyForecast(
      time: ct.add(const Duration(hours: 5)),
      cloudCoverPercent: 5, ecmwfCloudPercent: 7,
      seeing: 4, transparency: 5, windMph: 3, windDirectionDeg: 190,
      dewSpreadC: 10, temperatureC: 4, dewPointC: -6,
      moonIlluminationPercent: 18, moonAltitudeDeg: -20, moonAzimuthDeg: 315,
      gltHeatFlux: -20, bltCeilingM: 200, jsWindSpeedKt: 18,
      limitingMagnitude: actuals[5], darknessCeiling: ceilings[5],
      condition: ConditionState.excellent,
    ),
    HourlyForecast(
      time: ct.add(const Duration(hours: 6)),
      cloudCoverPercent: 8, ecmwfCloudPercent: 10,
      seeing: 4, transparency: 4, windMph: 3, windDirectionDeg: 180,
      dewSpreadC: 10, temperatureC: 3, dewPointC: -7,
      moonIlluminationPercent: 18, moonAltitudeDeg: -25, moonAzimuthDeg: 330,
      gltHeatFlux: -25, bltCeilingM: 180, jsWindSpeedKt: 22,
      limitingMagnitude: actuals[6], darknessCeiling: ceilings[6],
      condition: ConditionState.excellent,
    ),
    HourlyForecast(
      time: ct.add(const Duration(hours: 7)),
      cloudCoverPercent: 10, ecmwfCloudPercent: 12,
      seeing: 4, transparency: 4, windMph: 4, windDirectionDeg: 180,
      dewSpreadC: 9, temperatureC: 2, dewPointC: -7,
      moonIlluminationPercent: 18, moonAltitudeDeg: -30, moonAzimuthDeg: 345,
      gltHeatFlux: -25, bltCeilingM: 160, jsWindSpeedKt: 28,
      limitingMagnitude: actuals[7], darknessCeiling: ceilings[7],
      condition: ConditionState.good,
    ),
    HourlyForecast(
      time: ct.add(const Duration(hours: 8)),
      cloudCoverPercent: 12, ecmwfCloudPercent: 15,
      seeing: 3, transparency: 4, windMph: 5, windDirectionDeg: 170,
      dewSpreadC: 8, temperatureC: 1, dewPointC: -7,
      moonIlluminationPercent: 18, moonAltitudeDeg: -35, moonAzimuthDeg: 0,
      gltHeatFlux: -20, bltCeilingM: 150, jsWindSpeedKt: 35,
      limitingMagnitude: actuals[8], darknessCeiling: ceilings[8],
      condition: ConditionState.good,
    ),
    HourlyForecast(
      time: ct.add(const Duration(hours: 9)),
      cloudCoverPercent: 15, ecmwfCloudPercent: 18,
      seeing: 3, transparency: 3, windMph: 5, windDirectionDeg: 160,
      dewSpreadC: 7, temperatureC: 0, dewPointC: -7,
      moonIlluminationPercent: 18, moonAltitudeDeg: -40, moonAzimuthDeg: 15,
      gltHeatFlux: -15, bltCeilingM: 160, jsWindSpeedKt: 42,
      limitingMagnitude: actuals[9], darknessCeiling: ceilings[9],
      condition: ConditionState.good,
    ),
  ];
}

List<HourlyForecast> _generateCharlotteHours(DateTime date) {
  // Charlotte: marginal — higher GLT (humid, urban heat), BLT stays higher,
  // moderate jet stream, conditions improve mid-night
  // Darkness: Bortle 7 (SQM 19.5), 72% gibbous moon sets hour 8
  final ct = DateTime(date.year, date.month, date.day, 19);

  // Per-night darkness variation
  final dayOffset = date.difference(DateTime.now()).inDays.clamp(0, 2);
  final ceilings = [
    [4.5, 5.8, 6.8, 7.4, 7.6, 7.8, 7.7, 7.6, 7.4, 6.5], // tonight
    [4.3, 5.5, 6.5, 7.2, 7.4, 7.6, 7.5, 7.4, 7.2, 6.3], // tomorrow
    [4.6, 5.9, 6.9, 7.5, 7.7, 7.8, 7.7, 7.6, 7.4, 6.6], // day after
  ][dayOffset];
  final actuals = [
    [3.2, 3.5, 3.8, 4.0, 4.3, 4.8, 5.0, 4.8, 5.0, 4.2], // tonight
    [3.0, 3.3, 3.5, 3.8, 4.0, 4.5, 4.7, 4.5, 4.8, 4.0], // tomorrow
    [3.5, 3.8, 4.2, 4.5, 4.8, 5.0, 5.1, 5.0, 5.1, 4.5], // day after
  ][dayOffset];

  return [
    HourlyForecast(
      time: ct,
      cloudCoverPercent: 80, ecmwfCloudPercent: 75,
      seeing: 2, transparency: 2, windMph: 8, gustMph: 15, windDirectionDeg: 310,
      dewSpreadC: 3, temperatureC: 8, dewPointC: 5,
      smokePm25: 12,
      moonIlluminationPercent: 72, moonAltitudeDeg: 40, moonAzimuthDeg: 150,
      kpIndex: 2,
      gltHeatFlux: 180, bltCeilingM: 1800, jsWindSpeedKt: 55,
      limitingMagnitude: actuals[0], darknessCeiling: ceilings[0],
      condition: ConditionState.overcast,
    ),
    HourlyForecast(
      time: ct.add(const Duration(hours: 1)),
      cloudCoverPercent: 70, ecmwfCloudPercent: 65,
      seeing: 2, transparency: 2, windMph: 7, gustMph: 12, windDirectionDeg: 320,
      dewSpreadC: 4, temperatureC: 7, dewPointC: 3,
      smokePm25: 15,
      moonIlluminationPercent: 72, moonAltitudeDeg: 48, moonAzimuthDeg: 170,
      kpIndex: 2,
      gltHeatFlux: 100, bltCeilingM: 1500, jsWindSpeedKt: 50,
      limitingMagnitude: actuals[1], darknessCeiling: ceilings[1],
      condition: ConditionState.poorGap,
    ),
    HourlyForecast(
      time: ct.add(const Duration(hours: 2)),
      cloudCoverPercent: 55, ecmwfCloudPercent: 50,
      seeing: 3, transparency: 3, windMph: 6, gustMph: 10, windDirectionDeg: 330,
      dewSpreadC: 5, temperatureC: 6, dewPointC: 1,
      smokePm25: 18,
      moonIlluminationPercent: 72, moonAltitudeDeg: 52, moonAzimuthDeg: 190,
      kpIndex: 3,
      gltHeatFlux: 45, bltCeilingM: 1100, jsWindSpeedKt: 45,
      limitingMagnitude: actuals[2], darknessCeiling: ceilings[2],
      condition: ConditionState.marginalImproving,
    ),
    HourlyForecast(
      time: ct.add(const Duration(hours: 3)),
      cloudCoverPercent: 40, ecmwfCloudPercent: 35,
      seeing: 3, transparency: 3, windMph: 5, windDirectionDeg: 340,
      dewSpreadC: 5, temperatureC: 5, dewPointC: 0,
      smokePm25: 20,
      moonIlluminationPercent: 72, moonAltitudeDeg: 50, moonAzimuthDeg: 210,
      kpIndex: 3,
      gltHeatFlux: 10, bltCeilingM: 800, jsWindSpeedKt: 40,
      limitingMagnitude: actuals[3], darknessCeiling: ceilings[3],
      condition: ConditionState.marginalImproving,
    ),
    HourlyForecast(
      time: ct.add(const Duration(hours: 4)),
      cloudCoverPercent: 30, ecmwfCloudPercent: 28,
      seeing: 3, transparency: 4, windMph: 4, windDirectionDeg: 350,
      dewSpreadC: 6, temperatureC: 4, dewPointC: -2,
      smokePm25: 22,
      moonIlluminationPercent: 72, moonAltitudeDeg: 42, moonAzimuthDeg: 230,
      kpIndex: 3,
      gltHeatFlux: -5, bltCeilingM: 550, jsWindSpeedKt: 38,
      limitingMagnitude: actuals[4], darknessCeiling: ceilings[4],
      condition: ConditionState.marginalImproving,
    ),
    HourlyForecast(
      time: ct.add(const Duration(hours: 5)),
      cloudCoverPercent: 20, ecmwfCloudPercent: 22,
      seeing: 4, transparency: 4, windMph: 3, windDirectionDeg: 350,
      dewSpreadC: 7, temperatureC: 3, dewPointC: -4,
      smokePm25: 18,
      moonIlluminationPercent: 72, moonAltitudeDeg: 30, moonAzimuthDeg: 250,
      kpIndex: 4,
      gltHeatFlux: -15, bltCeilingM: 380, jsWindSpeedKt: 35,
      limitingMagnitude: actuals[5], darknessCeiling: ceilings[5],
      condition: ConditionState.good,
    ),
    HourlyForecast(
      time: ct.add(const Duration(hours: 6)),
      cloudCoverPercent: 25, ecmwfCloudPercent: 28,
      seeing: 3, transparency: 3, windMph: 4, windDirectionDeg: 0,
      dewSpreadC: 6, temperatureC: 2, dewPointC: -4,
      smokePm25: 15,
      moonIlluminationPercent: 72, moonAltitudeDeg: 18, moonAzimuthDeg: 265,
      kpIndex: 4,
      gltHeatFlux: -20, bltCeilingM: 300, jsWindSpeedKt: 40,
      limitingMagnitude: actuals[6], darknessCeiling: ceilings[6],
      condition: ConditionState.marginalDegrading,
    ),
    HourlyForecast(
      time: ct.add(const Duration(hours: 7)),
      cloudCoverPercent: 35, ecmwfCloudPercent: 38,
      seeing: 3, transparency: 3, windMph: 5, gustMph: 8, windDirectionDeg: 10,
      dewSpreadC: 5, temperatureC: 1, dewPointC: -4,
      smokePm25: 12,
      moonIlluminationPercent: 72, moonAltitudeDeg: 5, moonAzimuthDeg: 280,
      kpIndex: 5,
      gltHeatFlux: -20, bltCeilingM: 250, jsWindSpeedKt: 48,
      limitingMagnitude: actuals[7], darknessCeiling: ceilings[7],
      condition: ConditionState.marginalDegrading,
    ),
    HourlyForecast(
      time: ct.add(const Duration(hours: 8)),
      cloudCoverPercent: 50, ecmwfCloudPercent: 55,
      seeing: 2, transparency: 2, windMph: 6, gustMph: 10, windDirectionDeg: 20,
      dewSpreadC: 4, temperatureC: 0, dewPointC: -4,
      smokePm25: 10,
      moonIlluminationPercent: 72, moonAltitudeDeg: -5, moonAzimuthDeg: 290,
      kpIndex: 5,
      gltHeatFlux: -15, bltCeilingM: 220, jsWindSpeedKt: 55,
      limitingMagnitude: actuals[8], darknessCeiling: ceilings[8],
      condition: ConditionState.poorGap,
    ),
    HourlyForecast(
      time: ct.add(const Duration(hours: 9)),
      cloudCoverPercent: 65, ecmwfCloudPercent: 70,
      seeing: 2, transparency: 2, windMph: 7, gustMph: 12, windDirectionDeg: 30,
      dewSpreadC: 3, temperatureC: -1, dewPointC: -4,
      smokePm25: 8,
      moonIlluminationPercent: 72, moonAltitudeDeg: -15, moonAzimuthDeg: 305,
      kpIndex: 5,
      gltHeatFlux: -10, bltCeilingM: 200, jsWindSpeedKt: 60,
      limitingMagnitude: actuals[9], darknessCeiling: ceilings[9],
      condition: ConditionState.overcast,
    ),
  ];
}
