import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/atmosphere_colors.dart';
import '../../../models/forecast.dart';
import '../../../providers/scrub_provider.dart';
import 'base_card.dart';

class ImagingWindowCard extends ConsumerWidget {
  final List<HourlyForecast> hours;
  final List<int> nightBoundaryIndices;

  const ImagingWindowCard({
    super.key,
    required this.hours,
    this.nightBoundaryIndices = const [],
  });

  /// Returns (windowStart, windowEnd) indices for the best contiguous window,
  /// or null if no window exists.
  (int, int)? _bestWindow() {
    int bestStart = 0, bestEnd = 0, bestLen = 0;
    int curStart = -1;
    for (var i = 0; i < hours.length; i++) {
      final h = hours[i];
      final good = h.cloudCoverPercent < 40 && h.seeing >= 3 && h.transparency >= 3;
      if (good) {
        if (curStart < 0) curStart = i;
        final len = i - curStart + 1;
        if (len > bestLen) {
          bestStart = curStart;
          bestEnd = i;
          bestLen = len;
        }
      } else {
        curStart = -1;
      }
    }
    if (bestLen == 0) return null;
    return (bestStart, bestEnd);
  }

  String _verdict() {
    final goodHours = hours.where((h) {
      return h.cloudCoverPercent < 40 && h.seeing >= 3 && h.transparency >= 3;
    }).length;

    if (goodHours >= hours.length - 1) {
      final allExcellent = hours.every((h) => h.seeing >= 4 && h.transparency >= 4);
      if (allExcellent) return 'All Night — Exceptional';
      return 'All Night';
    }

    final window = _bestWindow();
    if (window == null) return 'No Usable Window';

    final (start, end) = window;
    final sh = hours[start].time.hour % 12 == 0 ? 12 : hours[start].time.hour % 12;
    final sa = hours[start].time.hour < 12 ? 'am' : 'pm';
    final eh = hours[end].time.hour % 12 == 0 ? 12 : hours[end].time.hour % 12;
    final ea = hours[end].time.hour < 12 ? 'am' : 'pm';

    if (end - start + 1 <= 2) return 'One Gap, $sh$sa to $eh$ea';
    if (start == 0) return 'Early Window Only, Closes $eh$ea';
    if (end == hours.length - 1) return 'Opens After $sh$sa';
    return '$sh$sa to $eh$ea';
  }

  String _contextLine() {
    final goodHours = hours.where((h) {
      return h.cloudCoverPercent < 40 && h.seeing >= 3 && h.transparency >= 3;
    }).length;

    if (goodHours >= hours.length - 1) {
      return 'Everything is working tonight and the window is wide open. This is the night you have been waiting for.';
    }

    final window = _bestWindow();
    if (window == null) return '';

    final (start, end) = window;
    final windowLen = end - start + 1;

    // Find peak seeing within window
    int bestSeeingIdx = start;
    for (var i = start; i <= end; i++) {
      if (hours[i].seeing > hours[bestSeeingIdx].seeing) bestSeeingIdx = i;
    }
    final peakHour = hours[bestSeeingIdx].time.hour % 12 == 0
        ? 12
        : hours[bestSeeingIdx].time.hour % 12;
    final peakAmpm = hours[bestSeeingIdx].time.hour < 12 ? 'am' : 'pm';

    if (windowLen <= 2) {
      return 'Brief clearing. One object, your best one, no filter changes.';
    }
    return 'Best window tonight is $windowLen hours. Seeing peaks around $peakHour$peakAmpm — front-load your most demanding targets.';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scrubState = ref.watch(scrubProvider);

    return BaseCard(
      parameterName: 'Imaging Window',
      verdict: _verdict(),
      body: CustomPaint(
        painter: _ImagingWindowPainter(
          hours: hours,
          bestWindow: _bestWindow(),
          scrubPosition: scrubState.position,
          isScrubbing: scrubState.isScrubbing,
          nightBoundaryIndices: nightBoundaryIndices,
        ),
        size: Size.infinite,
      ),
      context: _contextLine(),
    );
  }
}

class _ImagingWindowPainter extends CustomPainter {
  final List<HourlyForecast> hours;
  final (int, int)? bestWindow;
  final double scrubPosition;
  final bool isScrubbing;
  final List<int> nightBoundaryIndices;

  _ImagingWindowPainter({
    required this.hours,
    this.bestWindow,
    required this.scrubPosition,
    required this.isScrubbing,
    this.nightBoundaryIndices = const [],
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (hours.isEmpty) return;

    final segmentWidth = size.width / hours.length;
    final isBest = bestWindow != null;

    for (var i = 0; i < hours.length; i++) {
      final h = hours[i];
      // Composite quality
      final cloudScore = (100 - h.cloudCoverPercent) / 100.0;
      final seeingScore = h.seeing / 5.0;
      final transparencyScore = h.transparency / 5.0;
      final windPenalty = (h.windMph > 15) ? 0.8 : 1.0;
      final quality = (cloudScore * 0.35 + seeingScore * 0.25 +
              transparencyScore * 0.25 + windPenalty * 0.15)
          .clamp(0.0, 1.0);

      // CDS color mapping for quality bands
      Color color;
      if (quality >= 0.8) {
        color = AtmosphereColors.deepBlue; // Best window
      } else if (quality >= 0.6) {
        color = AtmosphereColors.mediumBlue; // Acceptable
      } else if (quality >= 0.4) {
        color = AtmosphereColors.blueGrey; // Marginal
      } else {
        color = AtmosphereColors.darkGrey; // Closed
      }

      // Highlight best window segments
      final inBestWindow = isBest && i >= bestWindow!.$1 && i <= bestWindow!.$2;
      if (inBestWindow) {
        color = Color.lerp(color, AtmosphereColors.deepIndigo, 0.3)!;
      }

      final rect = Rect.fromLTWH(
        i * segmentWidth + 1,
        size.height * (1.0 - quality),
        segmentWidth - 2,
        size.height * quality,
      );

      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(4)),
        Paint()..color = color,
      );

      // Best window boundary labels
      if (isBest && (i == bestWindow!.$1 || i == bestWindow!.$2)) {
        final hour = hours[i].time.hour % 12 == 0 ? 12 : hours[i].time.hour % 12;
        final ampm = hours[i].time.hour < 12 ? 'a' : 'p';
        final textPainter = TextPainter(
          text: TextSpan(
            text: '$hour$ampm',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 10,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        textPainter.paint(
          canvas,
          Offset(
            i * segmentWidth + segmentWidth / 2 - textPainter.width / 2,
            size.height * (1.0 - quality) - 14,
          ),
        );
      }
    }

    // Night boundary separators
    if (nightBoundaryIndices.isNotEmpty && hours.isNotEmpty) {
      final boundaryPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.12)
        ..strokeWidth = 1.0;
      for (final idx in nightBoundaryIndices) {
        final bx = idx * segmentWidth + segmentWidth / 2;
        canvas.drawLine(
          Offset(bx, 0),
          Offset(bx, size.height),
          boundaryPaint,
        );
      }
    }

    // Scrub indicator
    final x = scrubPosition * size.width;
    canvas.drawLine(
      Offset(x, 0),
      Offset(x, size.height),
      Paint()
        ..color = Colors.white.withValues(alpha: isScrubbing ? 0.8 : 0.3)
        ..strokeWidth = isScrubbing ? 1.5 : 1.0,
    );
  }

  @override
  bool shouldRepaint(_ImagingWindowPainter old) {
    return old.scrubPosition != scrubPosition ||
        old.isScrubbing != isScrubbing;
  }
}
