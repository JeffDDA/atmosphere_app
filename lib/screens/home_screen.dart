import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/theme/atmosphere_colors.dart';
import '../core/theme/atmosphere_theme.dart';
import '../data/mock_forecasts.dart';
import '../layers/claritas_shell.dart';
import '../models/layer_id.dart';
import '../providers/location_provider.dart';
import '../providers/navigation_provider.dart';
import '../widgets/liquid_glass.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final navState = ref.watch(navigationProvider);

    // When not at home, show the Claritas shell
    if (navState.currentLayer != LayerId.home) {
      return const ClaritasShell();
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Atmosphere',
          style: GoogleFonts.workSans(
            fontWeight: FontWeight.w700,
            fontStyle: FontStyle.italic,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {},
          ),
        ],
      ),
      body: const SafeArea(
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
          const SizedBox(height: 8),
          Text(
            'Your observing locations',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
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
                    ref
                        .read(navigationProvider.notifier)
                        .goToLayer(LayerId.layer1);
                  },
                  child: LiquidGlass(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Location name
                        Text(
                          location.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Condition accent dot + headline
                        Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: conditionColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                headline,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        // Bortle class + SQM
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Bortle ${location.bortleClass}',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.6),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              'SQM ${location.sqmValue.toStringAsFixed(1)}',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.6),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          // DDA brand footer
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 16, bottom: 8),
              child: TextButton.icon(
                onPressed: () {},
                icon: Icon(
                  Icons.auto_awesome,
                  size: 16,
                  color: AtmosphereTheme.dragonBurgundy,
                ),
                label: Text(
                  'Dark Dragons Astro',
                  style: TextStyle(
                    color: AtmosphereTheme.dragonBurgundy,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
