import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/atmosphere_colors.dart';
import '../../../models/forecast.dart';
import '../../../providers/scrub_provider.dart';
import 'base_card.dart';
import 'chart_card.dart';

class WindCard extends ConsumerWidget {
  final List<HourlyForecast> hours;
  final List<int> nightBoundaryIndices;

  const WindCard({
    super.key,
    required this.hours,
    this.nightBoundaryIndices = const [],
  });

  String _verdict() {
    final maxWind =
        hours.map((h) => h.windMph).reduce((a, b) => a > b ? a : b);

    // Check for calm window
    final calmHours = hours.where((h) => h.windMph < 5).toList();
    final windyHours = hours.where((h) => h.windMph >= 15).toList();
    if (calmHours.isNotEmpty && calmHours.length < hours.length ~/ 2 && windyHours.isNotEmpty) {
      final start = calmHours.first.time;
      final end = calmHours.last.time;
      final sh = start.hour % 12 == 0 ? 12 : start.hour % 12;
      final sa = start.hour < 12 ? 'am' : 'pm';
      final eh = end.hour % 12 == 0 ? 12 : end.hour % 12;
      final ea = end.hour < 12 ? 'am' : 'pm';
      return 'Calm Window $sh$sa to $eh$ea';
    }

    if (maxWind < 5) return 'Calm';
    if (maxWind < 10) return 'Moderate — Manageable';
    if (maxWind < 25) return 'Strong — Mount Stability Risk';
    return 'Dangerous — Keep the Roof Closed';
  }

  String _contextLine() {
    final maxWind =
        hours.map((h) => h.windMph).reduce((a, b) => a > b ? a : b);
    final maxGust = hours.map((h) => h.gustMph).reduce((a, b) => a > b ? a : b);

    if (maxWind < 5) {
      return 'Calm all night. Wind is not a factor tonight.';
    }
    if (maxGust > 20) {
      return 'Moderate wind with gusts to ${maxGust.round()}mph — heavier imaging trains may struggle. Consider shorter focal lengths tonight.';
    }
    if (maxWind >= 25) {
      return 'Sustained wind above safe imaging limits all night. Tonight is a hard no for exposed setups.';
    }
    return 'Sustained wind speed and gust markers. High winds cause telescope shake and degrade long exposures.';
  }

  static const _compassLabels = [
    'N', 'NNE', 'NE', 'ENE', 'E', 'ESE', 'SE', 'SSE',
    'S', 'SSW', 'SW', 'WSW', 'W', 'WNW', 'NW', 'NNW',
  ];

  static String _compassDirection(double degrees) {
    final idx = ((degrees % 360) / 22.5).round() % 16;
    return _compassLabels[idx];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scrubState = ref.watch(scrubProvider);
    final scrubIdx = scrubState.hourIndex(hours.length);
    final currentHour = hours[scrubIdx];
    final windDir = _compassDirection(currentHour.windDirectionDeg);

    final maxGust = hours
        .map((h) => h.gustMph > 0 ? h.gustMph : h.windMph)
        .reduce((a, b) => a > b ? a : b);
    final chartMax = (maxGust * 1.2).clamp(10.0, 100.0);

    return BaseCard(
      parameterName: 'Wind',
      verdict: '${_verdict()} — $windDir',
      body: ChartCard(
        values: hours.map((h) => h.windMph).toList(),
        maxValue: chartMax,
        type: ChartType.area,
        color: AtmosphereColors.greyBlue,
        gustValues: hours.map((h) => h.gustMph).toList(),
        nightBoundaryIndices: nightBoundaryIndices,
      ),
      context: _contextLine(),
    );
  }
}
