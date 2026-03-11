import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/condition_state.dart';
import '../models/forecast.dart';
import '../services/dragon_cds_service.dart';
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

// ── Live forecast fetch ─────────────────────────────────────────────────────

/// Raw API response for the active location. Refreshes when location changes.
final _liveForecastResponseProvider =
    FutureProvider.autoDispose<ForecastResponse?>((ref) async {
  final location = ref.watch(activeLocationProvider);
  if (location == null) return null;

  final service = ref.read(dragonCDSServiceProvider);
  return service.getForecast(
    lat: location.latitude,
    lon: location.longitude,
  );
});

/// Whether forecast data is currently loading.
final forecastLoadingProvider = Provider<bool>((ref) {
  return ref.watch(_liveForecastResponseProvider).isLoading;
});

/// Error message if forecast fetch failed, null otherwise.
final forecastErrorProvider = Provider<String?>((ref) {
  return ref.watch(_liveForecastResponseProvider).whenOrNull(
    error: (e, _) => e.toString(),
  );
});

/// Bortle class from the live forecast response location object.
final liveBortleClassProvider = Provider<int>((ref) {
  final resp = ref.watch(_liveForecastResponseProvider).valueOrNull;
  return resp?.location.bortleClass ?? 0;
});

// ── Night grouping ──────────────────────────────────────────────────────────

/// Groups 84 hours of continuous API data into 3 nighttime windows.
/// Night = local hours 19:00–04:59 (10-hour window).
List<NightForecast> _groupIntoNights(List<HourlyForecast> allHours) {
  if (allHours.isEmpty) return [];

  // Bucket hours by calendar night. A "night" starting on day D
  // runs from 19:00 on day D to 04:59 on day D+1.
  // For a given hour, its "night date" is:
  //   - hour 0-4 local → belongs to previous day's night
  //   - hour 19-23 local → belongs to this day's night
  //   - hour 5-18 local → daytime, skip for Claritas

  final nightBuckets = <DateTime, List<HourlyForecast>>{};

  for (final hour in allHours) {
    final local = hour.time.toLocal();
    final h = local.hour;

    DateTime? nightDate;
    if (h >= 19) {
      // Evening: belongs to tonight
      nightDate = DateTime(local.year, local.month, local.day);
    } else if (h < 5) {
      // Early morning: belongs to previous calendar day's night
      final prev = local.subtract(const Duration(days: 1));
      nightDate = DateTime(prev.year, prev.month, prev.day);
    }
    // else: daytime hour (5-18), skip

    if (nightDate != null) {
      nightBuckets.putIfAbsent(nightDate, () => []).add(hour);
    }
  }

  // Sort nights chronologically and take first 3
  final sortedDates = nightBuckets.keys.toList()..sort();
  final nights = <NightForecast>[];

  for (final date in sortedDates.take(3)) {
    final hours = nightBuckets[date]!;
    if (hours.isEmpty) continue;

    final overall = _overallCondition(hours);
    final headline = _headlineFor(overall);

    nights.add(NightForecast(
      date: date,
      hours: hours,
      overallCondition: overall,
      headline: headline,
    ));
  }

  return nights;
}

ConditionState _overallCondition(List<HourlyForecast> hours) {
  // Use median condition approach: rank each hour's condition, take median
  final ranks = hours.map((h) => _conditionRank(h.condition)).toList()..sort();
  final medianRank = ranks[ranks.length ~/ 2];
  return _conditionFromRank(medianRank);
}

int _conditionRank(ConditionState c) {
  switch (c) {
    case ConditionState.exceptional:
      return 7;
    case ConditionState.excellent:
      return 6;
    case ConditionState.good:
      return 5;
    case ConditionState.astroDarkGood:
      return 5;
    case ConditionState.marginalImproving:
      return 4;
    case ConditionState.marginalDegrading:
      return 3;
    case ConditionState.astroDarkPoor:
      return 3;
    case ConditionState.poorGap:
      return 2;
    case ConditionState.poorSeeing:
      return 2;
    case ConditionState.smoke:
      return 1;
    case ConditionState.fog:
      return 1;
    case ConditionState.overcast:
      return 0;
    case ConditionState.multiDayOvercast:
      return 0;
  }
}

ConditionState _conditionFromRank(int rank) {
  if (rank >= 7) return ConditionState.exceptional;
  if (rank >= 6) return ConditionState.excellent;
  if (rank >= 5) return ConditionState.good;
  if (rank >= 4) return ConditionState.marginalImproving;
  if (rank >= 3) return ConditionState.marginalDegrading;
  if (rank >= 2) return ConditionState.poorGap;
  if (rank >= 1) return ConditionState.smoke;
  return ConditionState.overcast;
}

String _headlineFor(ConditionState condition) {
  switch (condition) {
    case ConditionState.exceptional:
      return 'Extraordinary clarity tonight. Every photon is yours.';
    case ConditionState.excellent:
      return 'Excellent conditions. A great night to image.';
    case ConditionState.good:
      return 'Solid night ahead. Good transparency, steady seeing.';
    case ConditionState.marginalImproving:
      return 'Conditions improving. A window may open later.';
    case ConditionState.marginalDegrading:
      return 'Conditions softening. Shoot your priority targets first.';
    case ConditionState.poorGap:
      return 'Mostly cloudy. Brief clearings possible.';
    case ConditionState.poorSeeing:
      return 'Poor seeing tonight. Wide-field only.';
    case ConditionState.smoke:
      return 'Smoke advisory. Transparency severely degraded.';
    case ConditionState.fog:
      return 'Fog expected. Protect your optics.';
    case ConditionState.overcast:
    case ConditionState.multiDayOvercast:
      return 'Overcast tonight. Rest your gear.';
    case ConditionState.astroDarkGood:
      return 'Dark skies and clear. Outstanding conditions.';
    case ConditionState.astroDarkPoor:
      return 'Dark skies but marginal transparency.';
  }
}

// ── Public providers (interface unchanged) ───────────────────────────────────

/// 3 NightForecasts for the active location. Empty list while loading.
final forecastProvider = Provider<List<NightForecast>>((ref) {
  final resp = ref.watch(_liveForecastResponseProvider);
  final hours = resp.valueOrNull?.hours;
  if (hours == null || hours.isEmpty) return [];
  return _groupIntoNights(hours);
});

/// All 84 hours (day + night) from the API for the active location.
/// Used by Classic Mode for 24h × 3-day grid.
final liveAllHoursProvider = Provider<List<HourlyForecast>>((ref) {
  final resp = ref.watch(_liveForecastResponseProvider);
  return resp.valueOrNull?.hours ?? [];
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

/// Per-location tonight summary. Keyed by (lat, lon) for home screen tiles.
final locationTonightProvider =
    FutureProvider.autoDispose.family<NightForecast?, (double, double)>(
  (ref, key) async {
    final (lat, lon) = key;
    final service = ref.read(dragonCDSServiceProvider);
    final response = await service.getForecast(lat: lat, lon: lon, hours: 24);
    final nights = _groupIntoNights(response.hours);
    return nights.isNotEmpty ? nights.first : null;
  },
);
