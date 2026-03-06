import 'condition_state.dart';

class HourlyForecast {
  final DateTime time;
  final double cloudCoverPercent;
  final double ecmwfCloudPercent;
  final int seeing; // 1-5
  final int transparency; // 1-5
  final double windMph;
  final double gustMph;
  final double windDirectionDeg; // 0-360 compass
  final double dewSpreadC;
  final double temperatureC;
  final double dewPointC;
  final double smokePm25;
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
