import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/theme/ddac_theme.dart';
import '../../models/forecast.dart';
import '../../providers/classic_canvas_provider.dart';
import '../../providers/classic_lens_provider.dart';
import '../../layers/layer2/cards/cloud_cover_card.dart';
import '../../layers/layer2/cards/seeing_card.dart';
import '../../layers/layer2/cards/transparency_card.dart';
import '../../layers/layer2/cards/darkness_card.dart';
import '../../layers/layer2/cards/wind_card.dart';
import '../../layers/layer2/cards/smoke_card.dart';
import '../../layers/layer2/cards/dew_point_card.dart';

/// Renders the appropriate Claritas Layer 2 card at the lens focal point,
/// clipped to a circle. Only visible when the lens is fully open (strength == 1.0).
class ClassicFocalCard extends ConsumerWidget {
  const ClassicFocalCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lensState = ref.watch(classicLensProvider);
    final canvasState = ref.watch(classicCanvasProvider);
    final allHours = ref.watch(classicAllHoursProvider);

    if (!lensState.isFullyOpen || allHours.isEmpty) {
      return const SizedBox.shrink();
    }

    final rowIndex = lensState.focalRowIndex;
    if (rowIndex == null || rowIndex < 0 || rowIndex >= ClassicRow.values.length) {
      return const SizedBox.shrink();
    }

    final row = ClassicRow.values[rowIndex];

    return LayoutBuilder(
      builder: (context, constraints) {
        final lensRadius =
            constraints.maxWidth * AtmosphereConstants.classicLensRadius;
        final focalDiameter =
            lensRadius * 2 * AtmosphereConstants.classicLensFocalDepth;
        final labelW = AtmosphereConstants.classicRowLabelWidth;

        // Convert grid-content-space to screen-local
        final screenX =
            lensState.centerGridX - canvasState.offsetPx + labelW;
        final screenY = lensState.centerGridY;

        final card = _buildCard(row, allHours);
        if (card == null) return const SizedBox.shrink();

        return Positioned(
          left: screenX - focalDiameter / 2,
          top: screenY - focalDiameter / 2,
          child: ClipOval(
            child: SizedBox(
              width: focalDiameter,
              height: focalDiameter,
              child: card,
            ),
          ),
        );
      },
    );
  }

  Widget? _buildCard(ClassicRow row, List<HourlyForecast> hours) {
    switch (row) {
      case ClassicRow.cloudCover:
      case ClassicRow.ecmwfCloud:
        return CloudCoverCard(hours: hours);
      case ClassicRow.transparency:
        return TransparencyCard(hours: hours);
      case ClassicRow.seeing:
        return SeeingCard(hours: hours);
      case ClassicRow.darkness:
        return DarknessCard(
          hours: hours,
          lpLimitingMagnitude: 5.0,
          bortleClass: 4,
        );
      case ClassicRow.wind:
        return WindCard(hours: hours);
      case ClassicRow.smoke:
        return SmokeCard(hours: hours);
      case ClassicRow.humidity:
        return DewPointCard(hours: hours);
      case ClassicRow.temperature:
        // No dedicated temperature card in Layer 2 yet
        return null;
    }
  }
}
