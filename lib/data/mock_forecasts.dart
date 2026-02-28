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

// Keyed by location name
final mockForecasts = <String, List<NightForecast>>{
  'Pietown, NM': [pietownTonight, pietownTomorrow, pietownDayAfter],
  'Charlotte, NC': [charlotteTonight, charlotteTomorrow, charlotteDayAfter],
};

List<HourlyForecast> _generatePietownHours(DateTime date) {
  // Civil twilight ~7pm through end of astro dark ~5am = 10 hours, 3-hour blocks
  final civilTwilight = DateTime(date.year, date.month, date.day, 19);
  return [
    HourlyForecast(
      time: civilTwilight,
      cloudCoverPercent: 5,
      seeing: 4,
      transparency: 5,
      windMph: 3,
      dewSpreadC: 15,
      condition: ConditionState.excellent,
    ),
    HourlyForecast(
      time: civilTwilight.add(const Duration(hours: 1)),
      cloudCoverPercent: 3,
      seeing: 5,
      transparency: 5,
      windMph: 2,
      dewSpreadC: 14,
      condition: ConditionState.exceptional,
    ),
    HourlyForecast(
      time: civilTwilight.add(const Duration(hours: 2)),
      cloudCoverPercent: 2,
      seeing: 5,
      transparency: 5,
      windMph: 2,
      gustMph: 4,
      dewSpreadC: 13,
      condition: ConditionState.exceptional,
    ),
    HourlyForecast(
      time: civilTwilight.add(const Duration(hours: 3)),
      cloudCoverPercent: 2,
      seeing: 5,
      transparency: 5,
      windMph: 1,
      dewSpreadC: 12,
      condition: ConditionState.exceptional,
    ),
    HourlyForecast(
      time: civilTwilight.add(const Duration(hours: 4)),
      cloudCoverPercent: 3,
      seeing: 5,
      transparency: 5,
      windMph: 2,
      dewSpreadC: 11,
      condition: ConditionState.exceptional,
    ),
    HourlyForecast(
      time: civilTwilight.add(const Duration(hours: 5)),
      cloudCoverPercent: 5,
      seeing: 4,
      transparency: 5,
      windMph: 3,
      dewSpreadC: 10,
      condition: ConditionState.excellent,
    ),
    HourlyForecast(
      time: civilTwilight.add(const Duration(hours: 6)),
      cloudCoverPercent: 8,
      seeing: 4,
      transparency: 4,
      windMph: 3,
      dewSpreadC: 10,
      condition: ConditionState.excellent,
    ),
    HourlyForecast(
      time: civilTwilight.add(const Duration(hours: 7)),
      cloudCoverPercent: 10,
      seeing: 4,
      transparency: 4,
      windMph: 4,
      dewSpreadC: 9,
      condition: ConditionState.good,
    ),
    HourlyForecast(
      time: civilTwilight.add(const Duration(hours: 8)),
      cloudCoverPercent: 12,
      seeing: 3,
      transparency: 4,
      windMph: 5,
      dewSpreadC: 8,
      condition: ConditionState.good,
    ),
    HourlyForecast(
      time: civilTwilight.add(const Duration(hours: 9)),
      cloudCoverPercent: 15,
      seeing: 3,
      transparency: 3,
      windMph: 5,
      dewSpreadC: 7,
      condition: ConditionState.good,
    ),
  ];
}

List<HourlyForecast> _generateCharlotteHours(DateTime date) {
  final civilTwilight = DateTime(date.year, date.month, date.day, 19);
  return [
    HourlyForecast(
      time: civilTwilight,
      cloudCoverPercent: 80,
      seeing: 2,
      transparency: 2,
      windMph: 8,
      gustMph: 15,
      dewSpreadC: 3,
      condition: ConditionState.overcast,
    ),
    HourlyForecast(
      time: civilTwilight.add(const Duration(hours: 1)),
      cloudCoverPercent: 70,
      seeing: 2,
      transparency: 2,
      windMph: 7,
      gustMph: 12,
      dewSpreadC: 4,
      condition: ConditionState.poorGap,
    ),
    HourlyForecast(
      time: civilTwilight.add(const Duration(hours: 2)),
      cloudCoverPercent: 55,
      seeing: 3,
      transparency: 3,
      windMph: 6,
      gustMph: 10,
      dewSpreadC: 5,
      condition: ConditionState.marginalImproving,
    ),
    HourlyForecast(
      time: civilTwilight.add(const Duration(hours: 3)),
      cloudCoverPercent: 40,
      seeing: 3,
      transparency: 3,
      windMph: 5,
      dewSpreadC: 5,
      condition: ConditionState.marginalImproving,
    ),
    HourlyForecast(
      time: civilTwilight.add(const Duration(hours: 4)),
      cloudCoverPercent: 30,
      seeing: 3,
      transparency: 4,
      windMph: 4,
      dewSpreadC: 6,
      condition: ConditionState.marginalImproving,
    ),
    HourlyForecast(
      time: civilTwilight.add(const Duration(hours: 5)),
      cloudCoverPercent: 20,
      seeing: 4,
      transparency: 4,
      windMph: 3,
      dewSpreadC: 7,
      condition: ConditionState.good,
    ),
    HourlyForecast(
      time: civilTwilight.add(const Duration(hours: 6)),
      cloudCoverPercent: 25,
      seeing: 3,
      transparency: 3,
      windMph: 4,
      dewSpreadC: 6,
      condition: ConditionState.marginalDegrading,
    ),
    HourlyForecast(
      time: civilTwilight.add(const Duration(hours: 7)),
      cloudCoverPercent: 35,
      seeing: 3,
      transparency: 3,
      windMph: 5,
      gustMph: 8,
      dewSpreadC: 5,
      condition: ConditionState.marginalDegrading,
    ),
    HourlyForecast(
      time: civilTwilight.add(const Duration(hours: 8)),
      cloudCoverPercent: 50,
      seeing: 2,
      transparency: 2,
      windMph: 6,
      gustMph: 10,
      dewSpreadC: 4,
      condition: ConditionState.poorGap,
    ),
    HourlyForecast(
      time: civilTwilight.add(const Duration(hours: 9)),
      cloudCoverPercent: 65,
      seeing: 2,
      transparency: 2,
      windMph: 7,
      gustMph: 12,
      dewSpreadC: 3,
      condition: ConditionState.overcast,
    ),
  ];
}
