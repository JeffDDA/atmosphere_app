import 'package:flutter/material.dart';

import '../../../core/theme/atmosphere_colors.dart';
import '../../../models/forecast.dart';
import 'base_card.dart';
import 'chart_card.dart';

class SeeingCard extends StatelessWidget {
  final List<HourlyForecast> hours;

  const SeeingCard({super.key, required this.hours});

  String _verdict() {
    final avg =
        hours.map((h) => h.seeing).reduce((a, b) => a + b) / hours.length;
    if (avg >= 4.5) return 'Exceptional stability';
    if (avg >= 3.5) return 'Steady atmosphere';
    if (avg >= 2.5) return 'Moderate turbulence';
    return 'Turbulent';
  }

  @override
  Widget build(BuildContext context) {
    return BaseCard(
      parameterName: 'Seeing',
      verdict: _verdict(),
      body: ChartCard(
        values: hours.map((h) => h.seeing.toDouble()).toList(),
        maxValue: 5,
        type: ChartType.line,
        color: AtmosphereColors.deepBlue,
      ),
      context:
          'Atmospheric stability on a 1-5 scale. Higher values mean tighter stars and finer planetary detail.',
    );
  }
}
