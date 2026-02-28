import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../core/theme/atmosphere_colors.dart';
import '../../models/forecast.dart';

class GradientAnchor extends StatelessWidget {
  final List<HourlyForecast> hours;

  const GradientAnchor({super.key, required this.hours});

  @override
  Widget build(BuildContext context) {
    if (hours.isEmpty) return const SizedBox.shrink();

    final colors = hours
        .map((h) => AtmosphereColors.forCondition(h.condition))
        .toList();
    final stops = List.generate(
      hours.length,
      (i) => i / (hours.length - 1).clamp(1, hours.length),
    );

    return Container(
      height: AtmosphereConstants.gradientAnchorHeight,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(
          AtmosphereConstants.gradientAnchorHeight / 2,
        ),
        gradient: LinearGradient(colors: colors, stops: stops),
      ),
    );
  }
}
