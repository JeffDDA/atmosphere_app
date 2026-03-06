import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/theme/ddac_theme.dart';
import '../../models/forecast.dart';
import '../../providers/classic_canvas_provider.dart';

class ClassicGrid extends ConsumerStatefulWidget {
  const ClassicGrid({super.key});

  @override
  ConsumerState<ClassicGrid> createState() => _ClassicGridState();
}

class _ClassicGridState extends ConsumerState<ClassicGrid> {

  @override
  Widget build(BuildContext context) {
    final allHours = ref.watch(classicAllHoursProvider);
    final canvasState = ref.watch(classicCanvasProvider);
    final nowInfo = ref.watch(classicNowMarkerProvider);
    final tooltip = ref.watch(classicTooltipProvider);

    if (allHours.isEmpty) return const SizedBox.shrink();

    final cW = AtmosphereConstants.classicChickletWidth;
    final cH = AtmosphereConstants.classicChickletHeight;
    final gap = AtmosphereConstants.classicChickletGap;
    final pxPerHour = cW + gap;
    final totalContentWidth = allHours.length * pxPerHour;
    final labelW = AtmosphereConstants.classicRowLabelWidth;
    final timeH = AtmosphereConstants.classicTimeAxisHeight;
    final groupGap = AtmosphereConstants.classicGroupGap;
    final rows = ClassicRow.values;

    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportWidth = constraints.maxWidth - labelW;
        final maxScroll = (totalContentWidth - viewportWidth).clamp(0.0, double.infinity);

        // Update max offset for provider
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref.read(classicCanvasProvider.notifier).updateMaxOffset(maxScroll);
        });

        final totalGridHeight = timeH +
            rows.length * (cH + gap) +
            groupGap;

        // Now marker in grid space
        final nowPx = nowInfo.fractionalIndex * pxPerHour;
        final nowScreenX = nowPx - canvasState.offsetPx + labelW;

        return GestureDetector(
          onHorizontalDragStart: (d) {
            ref.read(classicCanvasProvider.notifier).startPan();
          },
          onHorizontalDragUpdate: (d) {
            ref.read(classicCanvasProvider.notifier).updateOffset(
                  canvasState.offsetPx - d.delta.dx,
                );
          },
          onHorizontalDragEnd: (d) {
            ref
                .read(classicCanvasProvider.notifier)
                .endPan(d.primaryVelocity ?? 0);
          },
          onTapUp: (details) {
            _handleTap(details, canvasState.offsetPx, labelW, timeH, cW, cH,
                gap, groupGap, allHours, ref);
          },
          child: Container(
            color: DDACTheme.chartBackground,
            child: Stack(
              children: [
                CustomPaint(
                  size: Size(constraints.maxWidth, totalGridHeight),
                  painter: _GridPainter(
                    allHours: allHours,
                    offsetPx: canvasState.offsetPx,
                    labelWidth: labelW,
                    chickletWidth: cW,
                    chickletHeight: cH,
                    chickletGap: gap,
                    timeAxisHeight: timeH,
                    groupGap: groupGap,
                    viewportWidth: constraints.maxWidth,
                    nowScreenX: nowScreenX,
                    nowVisible: nowInfo.isWithinTimeline,
                  ),
                ),
                // Tooltip overlay
                if (tooltip.isVisible)
                  Positioned(
                    left: (tooltip.globalX ?? 0) -
                        40, // rough centering
                    top: (tooltip.globalY ?? 0) - 60,
                    child: _ChickletTooltip(
                      hourIndex: tooltip.hourIndex!,
                      rowIndex: tooltip.rowIndex!,
                      allHours: allHours,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _handleTap(
    TapUpDetails details,
    double offsetPx,
    double labelW,
    double timeH,
    double cW,
    double cH,
    double gap,
    double groupGap,
    List<HourlyForecast> allHours,
    WidgetRef ref,
  ) {
    final localX = details.localPosition.dx;
    final localY = details.localPosition.dy;

    // Dismiss if tapping in label area
    if (localX < labelW) {
      ref.read(classicTooltipProvider.notifier).dismiss();
      return;
    }

    // Convert to grid coordinates
    final gridX = localX - labelW + offsetPx;
    final pxPerHour = cW + gap;
    final hourIndex = (gridX / pxPerHour).floor();
    if (hourIndex < 0 || hourIndex >= allHours.length) {
      ref.read(classicTooltipProvider.notifier).dismiss();
      return;
    }

    // Determine row
    var rowY = localY - timeH;
    if (rowY < 0) {
      ref.read(classicTooltipProvider.notifier).dismiss();
      return;
    }

    final rowHeight = cH + gap;
    final rows = ClassicRow.values;
    int? rowIndex;

    double accY = 0;
    for (var r = 0; r < rows.length; r++) {
      if (r == AtmosphereConstants.classicSkyRowCount) {
        accY += groupGap;
      }
      if (rowY >= accY && rowY < accY + rowHeight) {
        rowIndex = r;
        break;
      }
      accY += rowHeight;
    }

    if (rowIndex == null) {
      ref.read(classicTooltipProvider.notifier).dismiss();
      return;
    }

    ref.read(classicTooltipProvider.notifier).show(
          hourIndex: hourIndex,
          rowIndex: rowIndex,
          globalX: localX,
          globalY: localY,
        );
  }
}

class _GridPainter extends CustomPainter {
  final List<HourlyForecast> allHours;
  final double offsetPx;
  final double labelWidth;
  final double chickletWidth;
  final double chickletHeight;
  final double chickletGap;
  final double timeAxisHeight;
  final double groupGap;
  final double viewportWidth;
  final double nowScreenX;
  final bool nowVisible;

  _GridPainter({
    required this.allHours,
    required this.offsetPx,
    required this.labelWidth,
    required this.chickletWidth,
    required this.chickletHeight,
    required this.chickletGap,
    required this.timeAxisHeight,
    required this.groupGap,
    required this.viewportWidth,
    required this.nowScreenX,
    required this.nowVisible,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final pxPerHour = chickletWidth + chickletGap;
    final rows = ClassicRow.values;
    final rowH = chickletHeight + chickletGap;

    // Clip to viewport (avoid painting beyond bounds)
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, size.height));

    // Time axis
    _paintTimeAxis(canvas, size);

    // Row labels (pinned left)
    _paintRowLabels(canvas, rows, rowH);

    // Chicklets
    // Determine visible hour range
    final firstVisibleHour = (offsetPx / pxPerHour).floor().clamp(0, allHours.length - 1);
    final lastVisibleHour = ((offsetPx + viewportWidth) / pxPerHour).ceil().clamp(0, allHours.length);

    double y = timeAxisHeight;
    for (var r = 0; r < rows.length; r++) {
      if (r == AtmosphereConstants.classicSkyRowCount) {
        y += groupGap;
      }

      for (var h = firstVisibleHour; h < lastVisibleHour; h++) {
        final screenX = h * pxPerHour - offsetPx + labelWidth;
        if (screenX + chickletWidth < labelWidth || screenX > viewportWidth) {
          continue;
        }

        final color = DDACTheme.chickletColor(rows[r], allHours[h]);
        final rect = Rect.fromLTWH(screenX, y, chickletWidth, chickletHeight);

        // Clip chicklets to not overlap label area
        if (screenX < labelWidth) {
          final clipped = Rect.fromLTWH(
              labelWidth, y, screenX + chickletWidth - labelWidth, chickletHeight);
          canvas.drawRect(clipped, Paint()..color = color);
        } else {
          canvas.drawRect(rect, Paint()..color = color);
        }
      }
      y += rowH;
    }

    // Now marker
    if (nowVisible && nowScreenX > labelWidth && nowScreenX < viewportWidth) {
      final nowPaint = Paint()
        ..color = DDACTheme.nowMarker
        ..strokeWidth = 2.0;
      canvas.drawLine(
        Offset(nowScreenX, timeAxisHeight),
        Offset(nowScreenX, y),
        nowPaint,
      );
    }
  }

  void _paintTimeAxis(Canvas canvas, Size size) {
    if (allHours.isEmpty) return;

    final pxPerHour = chickletWidth + chickletGap;
    final dayStyle = TextStyle(
      color: DDACTheme.timeAxisText,
      fontSize: 10,
      fontWeight: FontWeight.w600,
    );
    final hourStyle = TextStyle(
      color: DDACTheme.timeAxisText.withAlpha(180),
      fontSize: 9,
    );

    String? lastDay;
    for (var h = 0; h < allHours.length; h++) {
      final screenX = h * pxPerHour - offsetPx + labelWidth;
      if (screenX + chickletWidth < labelWidth || screenX > viewportWidth) {
        continue;
      }

      final time = allHours[h].time;
      final dayLabel = _dayLabel(time);

      // Day label at first hour of each day
      if (dayLabel != lastDay) {
        lastDay = dayLabel;
        final tp = TextPainter(
          text: TextSpan(text: dayLabel, style: dayStyle),
          textDirection: TextDirection.ltr,
        )..layout();
        final dx = screenX.clamp(labelWidth, viewportWidth - tp.width);
        tp.paint(canvas, Offset(dx, 2));
      }

      // Hour label
      final hourLabel = _formatHour(time.hour);
      final tp = TextPainter(
        text: TextSpan(text: hourLabel, style: hourStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      final dx = screenX + (chickletWidth - tp.width) / 2;
      if (dx >= labelWidth) {
        tp.paint(canvas, Offset(dx, timeAxisHeight - tp.height - 2));
      }
    }

    // Divider line under time axis
    canvas.drawLine(
      Offset(labelWidth, timeAxisHeight - 0.5),
      Offset(size.width, timeAxisHeight - 0.5),
      Paint()
        ..color = DDACTheme.divider
        ..strokeWidth = 0.5,
    );
  }

  void _paintRowLabels(Canvas canvas, List<ClassicRow> rows, double rowH) {
    // Label background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, labelWidth, canvas.getLocalClipBounds().height),
      Paint()..color = DDACTheme.chartBackground,
    );

    final labelStyle = TextStyle(
      color: DDACTheme.rowLabelText,
      fontSize: 10,
    );

    double y = timeAxisHeight;
    for (var r = 0; r < rows.length; r++) {
      if (r == AtmosphereConstants.classicSkyRowCount) {
        y += groupGap;
      }

      final tp = TextPainter(
        text: TextSpan(text: rows[r].label, style: labelStyle),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '...',
      )..layout(maxWidth: labelWidth - 8);

      tp.paint(
        canvas,
        Offset(4, y + (chickletHeight - tp.height) / 2),
      );
      y += rowH;
    }
  }

  String _dayLabel(DateTime time) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${days[time.weekday - 1]} ${time.month}/${time.day}';
  }

  String _formatHour(int hour) {
    if (hour == 0) return '12a';
    if (hour < 12) return '${hour}a';
    if (hour == 12) return '12p';
    return '${hour - 12}p';
  }

  @override
  bool shouldRepaint(covariant _GridPainter old) {
    return old.offsetPx != offsetPx ||
        old.allHours != allHours ||
        old.nowScreenX != nowScreenX;
  }
}

/// Inline tooltip widget rendered inside the grid stack.
class _ChickletTooltip extends StatelessWidget {
  final int hourIndex;
  final int rowIndex;
  final List<HourlyForecast> allHours;

  const _ChickletTooltip({
    required this.hourIndex,
    required this.rowIndex,
    required this.allHours,
  });

  @override
  Widget build(BuildContext context) {
    final rows = ClassicRow.values;
    if (rowIndex >= rows.length || hourIndex >= allHours.length) {
      return const SizedBox.shrink();
    }

    final row = rows[rowIndex];
    final hour = allHours[hourIndex];
    final isDaytime = DDACTheme.isDaytime(hour.time);
    final hasDaytimeBlank = row.hasDaytimeBlank && isDaytime;

    final value = hasDaytimeBlank
        ? 'No data during daylight'
        : _valueText(row, hour);

    final timeLabel = _formatTime(hour.time);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xEE222222),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF555555), width: 0.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${row.label} — $timeLabel',
            style: const TextStyle(
              color: Color(0xFFCCCCCC),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFFAAAAAA),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  String _valueText(ClassicRow row, HourlyForecast hour) {
    switch (row) {
      case ClassicRow.cloudCover:
        return '${hour.cloudCoverPercent.round()}% cloud cover';
      case ClassicRow.ecmwfCloud:
        return '${hour.ecmwfCloudPercent.round()}% ECMWF cloud';
      case ClassicRow.transparency:
        return 'Transparency ${hour.transparency}/5';
      case ClassicRow.seeing:
        return 'Seeing ${hour.seeing}/5';
      case ClassicRow.darkness:
        return 'NELM ${hour.limitingMagnitude.toStringAsFixed(1)} mag';
      case ClassicRow.smoke:
        return 'PM2.5 ${hour.smokePm25.round()} µg/m³';
      case ClassicRow.wind:
        return '${hour.windMph.round()} mph wind';
      case ClassicRow.humidity:
        return 'Dew spread ${hour.dewSpreadC.round()}°C';
      case ClassicRow.temperature:
        return '${hour.temperatureC.round()}°C';
    }
  }

  String _formatTime(DateTime time) {
    final h = time.hour;
    final period = h < 12 ? 'AM' : 'PM';
    final displayHour = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    return '$displayHour:00 $period';
  }
}
