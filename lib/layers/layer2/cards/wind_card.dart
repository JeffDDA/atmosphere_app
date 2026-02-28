import 'package:flutter/material.dart';

import '../../../core/theme/atmosphere_colors.dart';
import '../../../models/forecast.dart';
import 'base_card.dart';
import 'chart_card.dart';

class WindCard extends StatelessWidget {
  final List<HourlyForecast> hours;

  const WindCard({super.key, required this.hours});

  String _verdict() {
    final maxWind =
        hours.map((h) => h.windMph).reduce((a, b) => a > b ? a : b);
    if (maxWind < 5) return 'Calm';
    if (maxWind < 10) return 'Light breeze';
    if (maxWind < 20) return 'Moderate wind';
    return 'Windy';
  }

  @override
  Widget build(BuildContext context) {
    final maxGust = hours
        .map((h) => h.gustMph > 0 ? h.gustMph : h.windMph)
        .reduce((a, b) => a > b ? a : b);
    final chartMax = (maxGust * 1.2).clamp(10.0, 100.0);

    return BaseCard(
      parameterName: 'Wind',
      verdict: _verdict(),
      body: ChartCard(
        values: hours.map((h) => h.windMph).toList(),
        maxValue: chartMax,
        type: ChartType.area,
        color: AtmosphereColors.greyBlue,
        gustValues: hours.map((h) => h.gustMph).toList(),
      ),
      context:
          'Sustained wind speed and gust markers. High winds cause telescope shake and degrade long exposures.',
    );
  }
}
