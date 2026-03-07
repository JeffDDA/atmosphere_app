import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/mock_forecasts.dart';
import '../models/forecast.dart';
import 'location_provider.dart';
import 'scrub_provider.dart';

class NightBoundary {
  final int startIndex;
  final int hourCount;
  final NightForecast forecast;

  const NightBoundary({
    required this.startIndex,
    required this.hourCount,
    required this.forecast,
  });
}

final forecastProvider = Provider<List<NightForecast>>((ref) {
  final activeLocation = ref.watch(activeLocationProvider);
  if (activeLocation == null) return [];
  return mockForecasts[activeLocation.name] ??
      generateMockForecast(activeLocation);
});

final tonightForecastProvider = Provider<NightForecast?>((ref) {
  final forecasts = ref.watch(forecastProvider);
  return forecasts.isNotEmpty ? forecasts.first : null;
});

/// All hourly forecasts across all nights, concatenated into a flat list.
final allHoursProvider = Provider<List<HourlyForecast>>((ref) {
  final forecasts = ref.watch(forecastProvider);
  return forecasts.expand((f) => f.hours).toList();
});

/// Night boundaries with cumulative start indices into the allHours list.
final nightBoundariesProvider = Provider<List<NightBoundary>>((ref) {
  final forecasts = ref.watch(forecastProvider);
  final boundaries = <NightBoundary>[];
  int cumulative = 0;
  for (final forecast in forecasts) {
    boundaries.add(NightBoundary(
      startIndex: cumulative,
      hourCount: forecast.hours.length,
      forecast: forecast,
    ));
    cumulative += forecast.hours.length;
  }
  return boundaries;
});

/// Index of the night containing the current scrub position.
final activeNightProvider = Provider<int>((ref) {
  final scrub = ref.watch(scrubProvider);
  final boundaries = ref.watch(nightBoundariesProvider);
  final allHours = ref.watch(allHoursProvider);
  if (boundaries.isEmpty || allHours.isEmpty) return 0;

  final totalHours = allHours.length;
  final currentIndex = scrub.hourIndex(totalHours);

  for (int i = boundaries.length - 1; i >= 0; i--) {
    if (currentIndex >= boundaries[i].startIndex) return i;
  }
  return 0;
});
