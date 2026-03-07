import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/atmosphere_colors.dart';
import '../data/mock_forecasts.dart';
import '../layers/claritas_shell.dart';
import '../models/layer_id.dart';
import '../providers/location_provider.dart';
import '../providers/navigation_provider.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final navState = ref.watch(navigationProvider);

    // When not at home, show the Claritas shell
    if (navState.currentLayer != LayerId.home) {
      return const ClaritasShell();
    }

    return const Scaffold(
      body: SafeArea(
        child: _LocationGrid(),
      ),
    );
  }
}

class _LocationGrid extends ConsumerWidget {
  const _LocationGrid();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locations = ref.watch(locationProvider);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          Text(
            'Atmosphere',
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Your observing locations',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 32),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 0.85,
              ),
              itemCount: locations.length,
              itemBuilder: (context, index) {
                final location = locations[index];
                final forecasts = mockForecasts[location.name];
                final tonightCondition = forecasts?.first.overallCondition;
                final conditionColor = tonightCondition != null
                    ? AtmosphereColors.forCondition(tonightCondition)
                    : AtmosphereColors.darkGrey;
                final headline = forecasts?.first.headline ?? '';

                return GestureDetector(
                  onTap: () {
                    ref
                        .read(activeLocationIndexProvider.notifier)
                        .select(index);
                    ref.read(navigationProvider.notifier).goToLayer(LayerId.layer1);
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: conditionColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          location.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          headline,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
