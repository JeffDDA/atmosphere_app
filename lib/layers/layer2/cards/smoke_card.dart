import 'package:flutter/material.dart';

import '../../../core/theme/atmosphere_colors.dart';
import '../../../models/forecast.dart';
import 'base_card.dart';
import 'chart_card.dart';

class SmokeCard extends StatelessWidget {
  final List<HourlyForecast> hours;
  final List<int> nightBoundaryIndices;

  const SmokeCard({
    super.key,
    required this.hours,
    this.nightBoundaryIndices = const [],
  });

  /// Contextual trigger: PM2.5 above imaging threshold.
  static bool shouldShow(List<HourlyForecast> hours) {
    return hours.any((h) => h.smokePm25 > 10);
  }

  String _verdict() {
    final maxPm = hours.map((h) => h.smokePm25).reduce((a, b) => a > b ? a : b);

    // Check for clearing trend
    final firstHalf = hours.sublist(0, hours.length ~/ 2);
    final secondHalf = hours.sublist(hours.length ~/ 2);
    final firstAvg = firstHalf.map((h) => h.smokePm25).reduce((a, b) => a + b) / firstHalf.length;
    final secondAvg = secondHalf.map((h) => h.smokePm25).reduce((a, b) => a + b) / secondHalf.length;
    if (firstAvg > 25 && secondAvg < firstAvg * 0.6) {
      return 'Clearing — Improving Through Night';
    }

    if (maxPm > 150) return 'Extreme — Imaging Not Recommended';
    if (maxPm > 55) return 'Heavy — Significant Degradation';
    if (maxPm > 25) return 'Moderate — Transparency Affected';
    return 'Light Haze — Minor Impact';
  }

  String _contextLine() {
    final maxPm = hours.map((h) => h.smokePm25).reduce((a, b) => a > b ? a : b);

    if (maxPm > 55) {
      return 'Heavy smoke all night. Ha and SII remain viable. OIII degraded. Broadband RGB not recommended tonight.';
    }
    if (maxPm > 25) {
      return 'Smoke in the atmosphere tonight. Ha and SII remain viable — red wavelengths cut through aerosols. OIII will struggle.';
    }
    return 'Light smoke haze tonight — minor transparency impact. Broadband imaging will see slight degradation. Narrowband largely unaffected.';
  }

  @override
  Widget build(BuildContext context) {
    return BaseCard(
      parameterName: 'Smoke',
      verdict: _verdict(),
      body: ChartCard(
        values: hours.map((h) => h.smokePm25).toList(),
        maxValue: 100,
        type: ChartType.area,
        color: AtmosphereColors.amberGrey,
        nightBoundaryIndices: nightBoundaryIndices,
      ),
      context: _contextLine(),
    );
  }
}
