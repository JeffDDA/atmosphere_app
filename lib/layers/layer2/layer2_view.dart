import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/forecast_provider.dart';
import 'cards/cloud_cover_card.dart';
import 'cards/imaging_window_card.dart';
import 'cards/seeing_card.dart';
import 'cards/transparency_card.dart';
import 'cards/wind_card.dart';
import 'gradient_anchor.dart';

class Layer2View extends ConsumerWidget {
  const Layer2View({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final forecast = ref.watch(tonightForecastProvider);

    if (forecast == null) {
      return Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: const Center(
          child: Text('No forecast data'),
        ),
      );
    }

    final hours = forecast.hours;

    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 12),
            // Gradient anchor pinned at top
            GradientAnchor(hours: hours),
            const SizedBox(height: 8),

            // Scrollable card list
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  ImagingWindowCard(hours: hours),
                  CloudCoverCard(hours: hours),
                  SeeingCard(hours: hours),
                  TransparencyCard(hours: hours),
                  WindCard(hours: hours),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
