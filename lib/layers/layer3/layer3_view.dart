import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/cmc_projections.dart';
import '../../models/forecast.dart';
import '../../providers/forecast_provider.dart';
import '../../providers/layer3_entry_provider.dart';
import '../../providers/location_provider.dart';
import '../layer2/gradient_anchor.dart';
import 'cmc_map_view.dart';
import 'goes_map_view.dart';
import 'seeing_column_card.dart';

class Layer3View extends ConsumerWidget {
  const Layer3View({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allHours = ref.watch(allHoursProvider);
    final nightBoundaries = ref.watch(nightBoundariesProvider);
    final activeNightIndex = ref.watch(activeNightProvider);
    final location = ref.watch(activeLocationProvider);
    final entryDomain = ref.watch(layer3EntryDomainProvider);

    if (allHours.isEmpty) {
      return Container(
        color: const Color(0xFF0A0A1A),
        child: const Center(child: Text('No forecast data')),
      );
    }

    final elevationM = location?.elevationM ?? 0;

    final nightBoundaryIndices = nightBoundaries
        .skip(1)
        .map((b) => b.startIndex)
        .toList();

    return Container(
      color: const Color(0xFF0A0A1A),
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 8),
            // Gradient anchor — continuity from Layer 2
            GradientAnchor(
              allHours: allHours,
              nightBoundaries: nightBoundaries,
              activeNightIndex: activeNightIndex,
            ),
            const SizedBox(height: 4),
            // Detail card — determined by entry domain
            Expanded(
              child: _buildDetailCard(
                entryDomain,
                allHours,
                nightBoundaryIndices,
                elevationM,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailCard(
    String? domain,
    List<HourlyForecast> hours,
    List<int> nightBoundaryIndices,
    double elevationM,
  ) {
    switch (domain) {
      case 'cloud_cover':
        return CmcMapView(type: CmcMapType.cloud, hours: hours);
      case 'seeing':
        return CmcMapView(type: CmcMapType.seeing, hours: hours);
      case 'transparency':
        return CmcMapView(type: CmcMapType.transparency, hours: hours);
      case 'satellite':
        return GoesMapView(hours: hours);
      case 'wind':
        return CmcMapView(type: CmcMapType.wind, hours: hours);
      case 'humidity':
        return CmcMapView(type: CmcMapType.humidity, hours: hours);
      case 'temperature':
        return CmcMapView(type: CmcMapType.temperature, hours: hours);
      case 'darkness':
        return Center(
          child: Text(
            'Darkness Detail \u2014 Coming Soon',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
          ),
        );
      // Future: 'wind', 'imaging_window'
      default:
        return SeeingColumnCard(
          hours: hours,
          observatoryElevationM: elevationM,
          nightBoundaryIndices: nightBoundaryIndices,
        );
    }
  }
}
