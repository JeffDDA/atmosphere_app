import 'condition_state.dart';

class HourlyForecast {
  final DateTime time;
  final double cloudCoverPercent;
  final int seeing; // 1-5
  final int transparency; // 1-5
  final double windMph;
  final double gustMph;
  final double dewSpreadC;
  final double smokePm25;
  final double kpIndex;
  final double moonIlluminationPercent;
  final ConditionState condition;

  const HourlyForecast({
    required this.time,
    required this.cloudCoverPercent,
    required this.seeing,
    required this.transparency,
    required this.windMph,
    this.gustMph = 0,
    required this.dewSpreadC,
    this.smokePm25 = 0,
    this.kpIndex = 0,
    this.moonIlluminationPercent = 0,
    required this.condition,
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
