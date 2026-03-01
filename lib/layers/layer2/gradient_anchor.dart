import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/theme/atmosphere_colors.dart';
import '../../models/forecast.dart';
import '../../providers/canvas_provider.dart';
import '../../providers/forecast_provider.dart';
import '../../providers/scrub_provider.dart';

class GradientAnchor extends ConsumerWidget {
  final List<HourlyForecast> allHours;
  final List<NightBoundary> nightBoundaries;
  final int activeNightIndex;

  const GradientAnchor({
    super.key,
    required this.allHours,
    required this.nightBoundaries,
    required this.activeNightIndex,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (allHours.isEmpty || nightBoundaries.isEmpty) {
      return const SizedBox.shrink();
    }

    final scrubState = ref.watch(scrubProvider);
    final boundary = nightBoundaries[activeNightIndex];
    final activeHours = boundary.forecast.hours;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Night label + indicator dots
          _NightLabelRow(
            nightBoundaries: nightBoundaries,
            activeNightIndex: activeNightIndex,
            allHoursCount: allHours.length,
            onNightTap: (nightIdx) {
              final b = nightBoundaries[nightIdx];
              ref.read(canvasProvider.notifier).jumpToHour(b.startIndex);
            },
          ),
          const SizedBox(height: 4),
          // Time labels for active night
          _TimeLabels(hours: activeHours),
          const SizedBox(height: 6),
          // Gradient bar with cursor
          GestureDetector(
            onHorizontalDragStart: (details) {
              ref.read(canvasProvider.notifier).startPan();
              _updateCanvasFromDrag(context, details.localPosition.dx, ref);
            },
            onHorizontalDragUpdate: (details) {
              _updateCanvasFromDrag(context, details.localPosition.dx, ref);
            },
            onHorizontalDragEnd: (details) {
              ref.read(canvasProvider.notifier).endPan(0);
            },
            child: SizedBox(
              height: 48,
              child: CustomPaint(
                painter: _GradientAnchorPainter(
                  activeHours: activeHours,
                  localCursorPosition: _globalToLocal(scrubState.position),
                  isScrubbing: scrubState.isScrubbing,
                ),
                size: Size.infinite,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Fraction range of the active night within the global timeline.
  double get _nightStartFrac {
    if (allHours.length <= 1) return 0.0;
    final boundary = nightBoundaries[activeNightIndex];
    return boundary.startIndex / (allHours.length - 1);
  }

  double get _nightEndFrac {
    if (allHours.length <= 1) return 1.0;
    final boundary = nightBoundaries[activeNightIndex];
    return (boundary.startIndex + boundary.hourCount - 1) /
        (allHours.length - 1);
  }

  /// Convert global scrub position to local position within active night.
  double _globalToLocal(double globalPos) {
    final range = _nightEndFrac - _nightStartFrac;
    if (range <= 0) return 0.0;
    return ((globalPos - _nightStartFrac) / range).clamp(0.0, 1.0);
  }

  /// Convert bar-local drag position to canvas offset.
  void _updateCanvasFromDrag(
      BuildContext context, double localX, WidgetRef ref) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final barWidth = box.size.width - 40; // account for 20px padding each side
    final barLocalPos = ((localX - 20) / barWidth).clamp(0.0, 1.0);

    // Map bar position to hour index within active night
    final boundary = nightBoundaries[activeNightIndex];
    final hourIndex = boundary.startIndex +
        (barLocalPos * (boundary.hourCount - 1)).round();
    final pph = AtmosphereConstants.canvasPixelsPerHour;
    final maxOffset = (allHours.length - 1) * pph;
    final targetOffset = (hourIndex * pph).clamp(0.0, maxOffset);
    ref.read(canvasProvider.notifier).updateOffset(targetOffset);
  }
}

class _NightLabelRow extends StatelessWidget {
  final List<NightBoundary> nightBoundaries;
  final int activeNightIndex;
  final int allHoursCount;
  final void Function(int) onNightTap;

  const _NightLabelRow({
    required this.nightBoundaries,
    required this.activeNightIndex,
    required this.allHoursCount,
    required this.onNightTap,
  });

  String _nightLabel(int index) {
    if (index == 0) return 'Tonight';
    if (index == 1) return 'Tomorrow Night';
    // Day-of-week for further nights
    final date = nightBoundaries[index].forecast.date;
    const weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return '${weekdays[date.weekday - 1]} Night';
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 20,
      child: Row(
        children: [
          Text(
            _nightLabel(activeNightIndex),
            style: TextStyle(
              color: AtmosphereColors.textPrimaryDark,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          // Night indicator dots
          Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(nightBoundaries.length, (i) {
              final isActive = i == activeNightIndex;
              return GestureDetector(
                onTap: () => onNightTap(i),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Container(
                    width: isActive ? 16 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: isActive
                          ? Colors.white.withValues(alpha: 0.7)
                          : Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _TimeLabels extends StatelessWidget {
  final List<HourlyForecast> hours;

  const _TimeLabels({required this.hours});

  String _formatHour(DateTime dt) {
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final ampm = dt.hour < 12 ? 'a' : 'p';
    return '$hour$ampm';
  }

  @override
  Widget build(BuildContext context) {
    if (hours.length < 2) return const SizedBox.shrink();

    final labels = <_LabelEntry>[];
    labels.add(_LabelEntry(0.0, _formatHour(hours.first.time)));
    if (hours.length > 2) {
      final midIdx = hours.length ~/ 2;
      labels.add(_LabelEntry(0.5, _formatHour(hours[midIdx].time)));
    }
    labels.add(_LabelEntry(1.0, _formatHour(hours.last.time)));

    return SizedBox(
      height: 16,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: labels.map((entry) {
              return Positioned(
                left: entry.position * constraints.maxWidth -
                    (entry.position == 1.0
                        ? 24
                        : (entry.position == 0.5 ? 12 : 0)),
                child: Text(
                  entry.label,
                  style: TextStyle(
                    color: AtmosphereColors.textSecondaryDark,
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

class _LabelEntry {
  final double position;
  final String label;
  const _LabelEntry(this.position, this.label);
}

class _GradientAnchorPainter extends CustomPainter {
  final List<HourlyForecast> activeHours;
  final double localCursorPosition;
  final bool isScrubbing;

  _GradientAnchorPainter({
    required this.activeHours,
    required this.localCursorPosition,
    required this.isScrubbing,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (activeHours.isEmpty) return;

    final barHeight = 36.0;
    final barY = (size.height - barHeight) / 2;
    final barRect = Rect.fromLTWH(0, barY, size.width, barHeight);
    final barRRect = RRect.fromRectAndRadius(
      barRect,
      Radius.circular(barHeight / 2),
    );

    // Build gradient from active night's hourly conditions
    final colors = activeHours
        .map((h) => AtmosphereColors.forCondition(h.condition))
        .toList();
    final stops = List.generate(
      activeHours.length,
      (i) =>
          i / (activeHours.length - 1).clamp(1, activeHours.length).toDouble(),
    );

    final gradient = LinearGradient(colors: colors, stops: stops);
    final paint = Paint()..shader = gradient.createShader(barRect);

    canvas.drawRRect(barRRect, paint);

    // Subtle border
    canvas.drawRRect(
      barRRect,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.08)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    // Position cursor using local position within active night
    final cursorX = localCursorPosition * size.width;

    // Cursor glow
    final glowAlpha = isScrubbing ? 0.4 : 0.15;
    canvas.drawCircle(
      Offset(cursorX, size.height / 2),
      isScrubbing ? 14 : 10,
      Paint()
        ..color = Colors.white.withValues(alpha: glowAlpha)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );

    // Cursor line
    canvas.drawLine(
      Offset(cursorX, barY + 2),
      Offset(cursorX, barY + barHeight - 2),
      Paint()
        ..color = Colors.white.withValues(alpha: isScrubbing ? 0.9 : 0.5)
        ..strokeWidth = isScrubbing ? 2.5 : 1.5
        ..strokeCap = StrokeCap.round,
    );

    // Cursor dot
    canvas.drawCircle(
      Offset(cursorX, size.height / 2),
      isScrubbing ? 5 : 3,
      Paint()
        ..color = Colors.white.withValues(alpha: isScrubbing ? 0.95 : 0.7)
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(_GradientAnchorPainter old) {
    return old.localCursorPosition != localCursorPosition ||
        old.isScrubbing != isScrubbing ||
        old.activeHours != activeHours;
  }
}
