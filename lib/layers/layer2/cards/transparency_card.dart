import 'package:flutter/material.dart';

import '../../../core/theme/atmosphere_colors.dart';
import '../../../models/forecast.dart';
import 'base_card.dart';
import 'chart_card.dart';

class TransparencyCard extends StatelessWidget {
  final List<HourlyForecast> hours;
  final List<int> nightBoundaryIndices;

  const TransparencyCard({
    super.key,
    required this.hours,
    this.nightBoundaryIndices = const [],
  });

  String _verdict() {
    final avg = hours.map((h) => h.transparency).reduce((a, b) => a + b) /
        hours.length;

    // Check for smoke-affected
    final hasSmoke = hours.any((h) => h.smokePm25 > 25);
    if (hasSmoke) return 'Smoke Affected';

    // Check for degrading
    final firstHalf = hours.sublist(0, hours.length ~/ 2);
    final secondHalf = hours.sublist(hours.length ~/ 2);
    final firstAvg = firstHalf.map((h) => h.transparency).reduce((a, b) => a + b) / firstHalf.length;
    final secondAvg = secondHalf.map((h) => h.transparency).reduce((a, b) => a + b) / secondHalf.length;
    if (firstAvg >= 4 && secondAvg < 3) {
      final degradeHour = hours.lastWhere((h) => h.transparency >= 4);
      final hour = degradeHour.time.hour % 12 == 0 ? 12 : degradeHour.time.hour % 12;
      final ampm = degradeHour.time.hour < 12 ? 'am' : 'pm';
      return 'Degrading After $hour$ampm';
    }

    if (avg >= 4.5) return 'Exceptional';
    if (avg >= 3.5) return 'Excellent';
    if (avg >= 2.5) return 'Average';
    return 'Poor';
  }

  String _contextLine() {
    final avgTransparency = hours.map((h) => h.transparency).reduce((a, b) => a + b) / hours.length;
    final avgSeeing = hours.map((h) => h.seeing).reduce((a, b) => a + b) / hours.length;
    final hasSmoke = hours.any((h) => h.smokePm25 > 25);

    if (hasSmoke) {
      return 'Smoke in the atmosphere tonight. Ha and SII remain viable — red wavelengths cut through aerosols effectively. OIII will struggle.';
    }
    if (avgTransparency >= 4 && avgSeeing < 3) {
      return 'Excellent transparency but seeing is rough tonight. Narrowband imaging will benefit from the clear sky regardless.';
    }
    if (avgTransparency >= 4 && avgSeeing >= 4) {
      return 'Transparency and seeing are both excellent tonight. This combination is rare. Everything in your target queue is viable.';
    }
    return 'How clearly you can see through the atmosphere. Affects limiting magnitude and contrast on faint targets.';
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
        nightBoundaryIndices: nightBoundaryIndices,
      ),
      context: _contextLine(),
    );
  }
}
