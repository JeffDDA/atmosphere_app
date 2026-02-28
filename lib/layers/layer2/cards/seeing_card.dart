import 'package:flutter/material.dart';

import '../../../core/theme/atmosphere_colors.dart';
import '../../../models/forecast.dart';
import 'base_card.dart';
import 'chart_card.dart';

class SeeingCard extends StatelessWidget {
  final List<HourlyForecast> hours;
  final List<int> nightBoundaryIndices;

  const SeeingCard({
    super.key,
    required this.hours,
    this.nightBoundaryIndices = const [],
  });

  String _verdict() {
    final avg =
        hours.map((h) => h.seeing).reduce((a, b) => a + b) / hours.length;

    // Check for degrading pattern
    final firstHalf = hours.sublist(0, hours.length ~/ 2);
    final secondHalf = hours.sublist(hours.length ~/ 2);
    final firstAvg = firstHalf.map((h) => h.seeing).reduce((a, b) => a + b) / firstHalf.length;
    final secondAvg = secondHalf.map((h) => h.seeing).reduce((a, b) => a + b) / secondHalf.length;

    if (firstAvg >= 4 && secondAvg < 3) {
      final degradeHour = hours.lastWhere((h) => h.seeing >= 4);
      final hour = degradeHour.time.hour % 12 == 0 ? 12 : degradeHour.time.hour % 12;
      final ampm = degradeHour.time.hour < 12 ? 'am' : 'pm';
      return 'Degrading After $hour$ampm';
    }

    if (avg >= 4.5) return 'Exceptional. This doesn\'t happen often.';
    if (avg >= 3.5) return 'Excellent';
    if (avg >= 2.5) return 'Average';
    return 'Poor';
  }

  String _contextLine() {
    final avgSeeing = hours.map((h) => h.seeing).reduce((a, b) => a + b) / hours.length;
    final avgTransparency = hours.map((h) => h.transparency).reduce((a, b) => a + b) / hours.length;

    if (avgSeeing >= 4 && avgTransparency >= 4) {
      return 'Seeing and transparency are both excellent tonight. This combination is rare. Everything in your target queue is viable.';
    }
    if (avgSeeing < 3 && avgTransparency >= 4) {
      return 'Rough air tonight but the sky is clear. Narrowband deep sky is your best option — seeing matters less at narrow bandwidths.';
    }
    if (avgSeeing >= 4 && avgTransparency < 3) {
      return 'Steady air but hazy sky. Bright targets and planets will look good. Faint nebulae will struggle.';
    }
    if (avgSeeing < 3) {
      return 'Turbulent atmosphere tonight. Planetary work will struggle. Narrowband imaging at wider focal lengths is less affected.';
    }
    return 'Atmospheric stability on a 1-5 scale. Higher values mean tighter stars and finer planetary detail.';
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
        nightBoundaryIndices: nightBoundaryIndices,
      ),
      context: _contextLine(),
    );
  }
}
