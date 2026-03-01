import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants.dart';
import '../core/theme/atmosphere_colors.dart';
import 'forecast_provider.dart';

class NowMarkerInfo {
  /// Fractional index of "now" within the allHours list.
  /// E.g. 2.5 means halfway between hour index 2 and 3.
  final double fractionalIndex;

  /// True if DateTime.now() falls within the timeline's data range.
  final bool isWithinTimeline;

  /// CDS condition color at the current real time.
  final Color glowColor;

  /// Canvas-space X position of "now" in pixels.
  final double nowCanvasPositionPx;

  const NowMarkerInfo({
    required this.fractionalIndex,
    required this.isWithinTimeline,
    required this.glowColor,
    required this.nowCanvasPositionPx,
  });
}

final nowMarkerProvider = Provider<NowMarkerInfo>((ref) {
  final allHours = ref.watch(allHoursProvider);

  if (allHours.isEmpty) {
    return const NowMarkerInfo(
      fractionalIndex: 0,
      isWithinTimeline: false,
      glowColor: Color(0xFFFFFFFF),
      nowCanvasPositionPx: 0,
    );
  }

  final now = DateTime.now();
  final firstTime = allHours.first.time;
  final lastTime = allHours.last.time;

  // Compute fractional index: where does "now" fall in the hour list?
  double fractionalIndex;
  bool isWithinTimeline;

  if (now.isBefore(firstTime)) {
    fractionalIndex = 0;
    isWithinTimeline = false;
  } else if (now.isAfter(lastTime)) {
    fractionalIndex = (allHours.length - 1).toDouble();
    isWithinTimeline = false;
  } else {
    isWithinTimeline = true;
    // Find the bounding hour indices
    fractionalIndex = 0;
    for (var i = 0; i < allHours.length - 1; i++) {
      if (!now.isBefore(allHours[i].time) &&
          now.isBefore(allHours[i + 1].time)) {
        final segmentDuration =
            allHours[i + 1].time.difference(allHours[i].time).inSeconds;
        final elapsed = now.difference(allHours[i].time).inSeconds;
        final t = segmentDuration > 0 ? elapsed / segmentDuration : 0.0;
        fractionalIndex = i + t;
        break;
      }
    }
    // Edge case: exactly at last time
    if (now.isAtSameMomentAs(lastTime)) {
      fractionalIndex = (allHours.length - 1).toDouble();
    }
  }

  // Glow color from CDS condition at the floor hour
  final floorIdx = fractionalIndex.floor().clamp(0, allHours.length - 1);
  final glowColor = AtmosphereColors.forCondition(allHours[floorIdx].condition);

  // Canvas position in pixels
  final nowCanvasPositionPx =
      fractionalIndex * AtmosphereConstants.canvasPixelsPerHour;

  return NowMarkerInfo(
    fractionalIndex: fractionalIndex,
    isWithinTimeline: isWithinTimeline,
    glowColor: glowColor,
    nowCanvasPositionPx: nowCanvasPositionPx,
  );
});
