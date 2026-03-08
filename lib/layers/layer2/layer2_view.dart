import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../models/forecast.dart';
import '../../models/location.dart';
import '../../providers/canvas_provider.dart';
import '../../providers/forecast_provider.dart';
import '../../providers/layer3_entry_provider.dart';
import '../../providers/location_provider.dart';
import 'cards/aurora_card.dart';
import 'cards/cloud_cover_card.dart';
import 'cards/satellite_card.dart';
import 'cards/darkness_card.dart';
import 'cards/dew_point_card.dart';
import 'cards/imaging_window_card.dart';
import 'cards/moon_card.dart';
import 'cards/seeing_card.dart';
import 'cards/smoke_card.dart';
import 'cards/transparency_card.dart';
import 'cards/wind_card.dart';
import 'gradient_anchor.dart';

class Layer2View extends ConsumerWidget {
  const Layer2View({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allHours = ref.watch(allHoursProvider);
    final nightBoundaries = ref.watch(nightBoundariesProvider);
    final activeNightIndex = ref.watch(activeNightProvider);
    final location = ref.watch(activeLocationProvider);

    if (allHours.isEmpty) {
      return Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: const Center(
          child: Text('No forecast data'),
        ),
      );
    }

    // Compute and set maxOffset for the canvas
    final pph = AtmosphereConstants.canvasPixelsPerHour;
    final maxOffset = ((allHours.length - 1) * pph).clamp(0.0, double.infinity);
    // Schedule post-frame to avoid modifying provider during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(canvasProvider.notifier).updateMaxOffset(maxOffset);
    });

    // Night boundary start indices for card separator lines
    final nightBoundaryIndices = nightBoundaries
        .skip(1)
        .map((b) => b.startIndex)
        .toList();

    // Build relevance-ordered card list with entry domain Listeners
    final cards =
        _buildRelevanceStack(allHours, nightBoundaryIndices, location, ref);

    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 12),
            // Gradient anchor pinned at top — prominent navigation element
            GradientAnchor(
              allHours: allHours,
              nightBoundaries: nightBoundaries,
              activeNightIndex: activeNightIndex,
            ),
            const SizedBox(height: 4),

            // Scrollable card list
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 24),
                children: cards,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Wraps a card with a Listener that sets the Layer 3 entry domain
  /// on pointer-down, so the domain is ready before ClaritasShell's
  /// tap handler fires the transition.
  Widget _domainCard(String domain, Widget card, WidgetRef ref) {
    return Listener(
      onPointerDown: (_) {
        ref.read(layer3EntryDomainProvider.notifier).state = domain;
      },
      child: card,
    );
  }

  /// Builds the card stack ordered by relevance to tonight's conditions.
  List<Widget> _buildRelevanceStack(
    List<HourlyForecast> hours,
    List<int> nightBoundaryIndices,
    ObservatoryLocation? location,
    WidgetRef ref,
  ) {
    final cards = <Widget>[];
    final latitude = location?.latitude ?? 35.0;

    // 1. Aurora rises to top when above latitude threshold
    final showAurora = AuroraCard.shouldShow(hours, latitude);
    if (showAurora) {
      cards.add(_domainCard(
        'aurora',
        AuroraCard(
          hours: hours,
          siteLatitude: latitude,
          nightBoundaryIndices: nightBoundaryIndices,
        ),
        ref,
      ));
    }

    // 2. Imaging Window position depends on urgency
    final goodHourCount = hours.where((h) {
      return h.cloudCoverPercent < 40 && h.seeing >= 3 && h.transparency >= 3;
    }).length;

    final imagingWindowUrgent = goodHourCount < 3; // Narrow or time-critical
    final imagingWindowMid = goodHourCount >= 3 && goodHourCount < 7;

    if (imagingWindowUrgent && !showAurora) {
      cards.add(_domainCard(
        'imaging_window',
        ImagingWindowCard(
          hours: hours,
          nightBoundaryIndices: nightBoundaryIndices,
        ),
        ref,
      ));
    }

    // 3. Always-present cards in standard order
    cards.add(_domainCard(
      'cloud_cover',
      CloudCoverCard(
        hours: hours,
        nightBoundaryIndices: nightBoundaryIndices,
      ),
      ref,
    ));
    cards.add(_domainCard(
      'satellite',
      SatelliteCard(longitude: location?.longitude ?? -98.0),
      ref,
    ));
    cards.add(_domainCard(
      'darkness',
      DarknessCard(
        hours: hours,
        nightBoundaryIndices: nightBoundaryIndices,
        lpLimitingMagnitude: location?.lpLimitingMagnitude ?? 6.0,
        bortleClass: location?.bortleClass ?? 4,
      ),
      ref,
    ));
    cards.add(_domainCard(
      'seeing',
      SeeingCard(
        hours: hours,
        nightBoundaryIndices: nightBoundaryIndices,
      ),
      ref,
    ));
    cards.add(_domainCard(
      'transparency',
      TransparencyCard(
        hours: hours,
        nightBoundaryIndices: nightBoundaryIndices,
      ),
      ref,
    ));

    // 4. Imaging Window in middle position
    if (imagingWindowMid) {
      cards.add(_domainCard(
        'imaging_window',
        ImagingWindowCard(
          hours: hours,
          nightBoundaryIndices: nightBoundaryIndices,
        ),
        ref,
      ));
    }

    cards.add(_domainCard(
      'wind',
      WindCard(
        hours: hours,
        nightBoundaryIndices: nightBoundaryIndices,
      ),
      ref,
    ));

    // 5. Contextual cards — only when triggered
    if (DewPointCard.shouldShow(hours)) {
      cards.add(_domainCard(
        'dew_point',
        DewPointCard(
          hours: hours,
          nightBoundaryIndices: nightBoundaryIndices,
        ),
        ref,
      ));
    }
    if (SmokeCard.shouldShow(hours)) {
      cards.add(_domainCard(
        'smoke',
        SmokeCard(
          hours: hours,
          nightBoundaryIndices: nightBoundaryIndices,
        ),
        ref,
      ));
    }

    // 6. Moon — always present
    cards.add(_domainCard(
      'moon',
      MoonCard(
        hours: hours,
        nightBoundaryIndices: nightBoundaryIndices,
      ),
      ref,
    ));

    // 7. Imaging Window in lower position when conditions are uniformly good
    if (!imagingWindowUrgent && !imagingWindowMid) {
      cards.add(_domainCard(
        'imaging_window',
        ImagingWindowCard(
          hours: hours,
          nightBoundaryIndices: nightBoundaryIndices,
        ),
        ref,
      ));
    }

    return cards;
  }
}
