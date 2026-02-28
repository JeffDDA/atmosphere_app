import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/theme/atmosphere_colors.dart';
import '../../providers/forecast_provider.dart';
import 'gradient_bar.dart';
import 'voice_guide.dart';

class Layer1Card extends ConsumerWidget {
  const Layer1Card({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final forecast = ref.watch(tonightForecastProvider);

    if (forecast == null) {
      return Container(
        color: AtmosphereColors.darkGrey,
        child: const Center(
          child: Text(
            'No forecast data',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    final conditionColor =
        AtmosphereColors.forCondition(forecast.overallCondition);

    return Container(
      decoration: BoxDecoration(
        color: conditionColor,
        borderRadius: BorderRadius.circular(AtmosphereConstants.cardBorderRadius),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(flex: 2),
              VoiceGuide(
                headline: forecast.headline,
                timestamp: DateTime.now(),
              ),
              const SizedBox(height: 40),
              GradientBar(
                hours: forecast.hours,
                currentTime: DateTime.now(),
              ),
              const Spacer(flex: 3),
            ],
          ),
        ),
      ),
    );
  }
}
