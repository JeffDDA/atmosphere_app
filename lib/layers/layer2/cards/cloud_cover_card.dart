import 'package:flutter/material.dart';

import '../../../core/theme/atmosphere_colors.dart';
import '../../../models/forecast.dart';
import 'base_card.dart';
import 'chart_card.dart';

class CloudCoverCard extends StatelessWidget {
  final List<HourlyForecast> hours;

  const CloudCoverCard({super.key, required this.hours});

  String _verdict() {
    final avg =
        hours.map((h) => h.cloudCoverPercent).reduce((a, b) => a + b) /
            hours.length;
    if (avg < 15) return 'Clear skies';
    if (avg < 40) return 'Mostly clear';
    if (avg < 70) return 'Partly cloudy';
    return 'Mostly cloudy';
  }

  @override
  Widget build(BuildContext context) {
    return BaseCard(
      parameterName: 'Cloud Cover',
      verdict: _verdict(),
      body: ChartCard(
        values: hours.map((h) => h.cloudCoverPercent).toList(),
        maxValue: 100,
        type: ChartType.area,
        color: AtmosphereColors.blueGrey,
      ),
      context:
          'Cloud coverage percentage throughout the night. Lower is better for all types of observing.',
    );
  }
}
