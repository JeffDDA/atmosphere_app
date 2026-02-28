import 'package:flutter/material.dart';

import '../../../core/theme/atmosphere_colors.dart';
import '../../../models/forecast.dart';
import 'base_card.dart';
import 'chart_card.dart';

class CloudCoverCard extends StatelessWidget {
  final List<HourlyForecast> hours;
  final List<int> nightBoundaryIndices;

  const CloudCoverCard({
    super.key,
    required this.hours,
    this.nightBoundaryIndices = const [],
  });

  String _verdict() {
    final avg =
        hours.map((h) => h.cloudCoverPercent).reduce((a, b) => a + b) /
            hours.length;

    // Check for sucker hole: brief clearing < 90min in otherwise overcast
    final overcastCount = hours.where((h) => h.cloudCoverPercent > 70).length;
    final clearCount = hours.where((h) => h.cloudCoverPercent < 30).length;
    if (overcastCount > hours.length * 0.6 && clearCount > 0 && clearCount <= 2) {
      final clearHour = hours.firstWhere((h) => h.cloudCoverPercent < 30);
      final hour = clearHour.time.hour % 12 == 0 ? 12 : clearHour.time.hour % 12;
      final ampm = clearHour.time.hour < 12 ? 'am' : 'pm';
      return 'Sucker Hole ~$hour$ampm';
    }

    if (avg < 15) return 'Clear';
    if (avg < 30) return 'Mostly Clear';
    if (avg < 50) return 'Partly Cloudy';
    if (avg < 70) return 'Mostly Cloudy';
    return 'Overcast';
  }

  String _contextLine() {
    final avg =
        hours.map((h) => h.cloudCoverPercent).reduce((a, b) => a + b) /
            hours.length;

    // Find clearing trend
    final firstHalf = hours.sublist(0, hours.length ~/ 2);
    final secondHalf = hours.sublist(hours.length ~/ 2);
    final firstAvg = firstHalf.map((h) => h.cloudCoverPercent).reduce((a, b) => a + b) / firstHalf.length;
    final secondAvg = secondHalf.map((h) => h.cloudCoverPercent).reduce((a, b) => a + b) / secondHalf.length;

    if (firstAvg > 50 && secondAvg < 30) {
      return 'Clouds clearing later. Your best window opens in the second half of the night.';
    }
    if (avg < 15) {
      return 'Clear skies all night. No cloud concerns for any target.';
    }
    if (avg < 40) {
      return 'Scattered cloud all night — expect interruptions but not a complete washout.';
    }
    if (avg > 70) {
      return 'Solid overcast with no breaks forecast. Not tonight.';
    }
    return 'Variable cloud cover. Monitor conditions and shoot through the gaps.';
  }

  @override
  Widget build(BuildContext context) {
    // CDS color vocabulary: map each hour's condition to its CDS color
    final segmentColors = hours
        .map((h) => AtmosphereColors.forCondition(h.condition))
        .toList();

    return BaseCard(
      parameterName: 'Cloud Cover',
      verdict: _verdict(),
      body: ChartCard(
        values: hours.map((h) => h.cloudCoverPercent).toList(),
        maxValue: 100,
        type: ChartType.area,
        color: AtmosphereColors.blueGrey,
        segmentColors: segmentColors,
        nightBoundaryIndices: nightBoundaryIndices,
      ),
      context: _contextLine(),
    );
  }
}
