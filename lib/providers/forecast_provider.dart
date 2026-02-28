import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/mock_forecasts.dart';
import '../models/forecast.dart';
import 'location_provider.dart';

final forecastProvider = Provider<List<NightForecast>>((ref) {
  final activeLocation = ref.watch(activeLocationProvider);
  if (activeLocation == null) return [];
  return mockForecasts[activeLocation.name] ?? [];
});

final tonightForecastProvider = Provider<NightForecast?>((ref) {
  final forecasts = ref.watch(forecastProvider);
  return forecasts.isNotEmpty ? forecasts.first : null;
});
