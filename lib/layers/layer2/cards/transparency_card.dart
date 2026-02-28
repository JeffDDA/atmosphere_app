import 'package:flutter/material.dart';

import '../../../core/theme/atmosphere_colors.dart';
import '../../../models/forecast.dart';
import 'base_card.dart';
import 'chart_card.dart';

class TransparencyCard extends StatelessWidget {
  final List<HourlyForecast> hours;

  const TransparencyCard({super.key, required this.hours});

  String _verdict() {
    final avg = hours.map((h) => h.transparency).reduce((a, b) => a + b) /
        hours.length;
    if (avg >= 4.5) return 'Crystal clear';
    if (avg >= 3.5) return 'Good transparency';
    if (avg >= 2.5) return 'Moderate haze';
    return 'Hazy';
  }

  @override
  Widget build(BuildContext context) {
    return BaseCard(
      parameterName: 'Transparency',
      verdict: _verdict(),
      body: ChartCard(
        values: hours.map((h) => h.transparency.toDouble()).toList(),
        maxValue: 5,
        type: ChartType.line,
        color: AtmosphereColors.mediumBlue,
      ),
      context:
          'How clearly you can see through the atmosphere. Affects limiting magnitude and contrast on faint targets.',
    );
  }
}
