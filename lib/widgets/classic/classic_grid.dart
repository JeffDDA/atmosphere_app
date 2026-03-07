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
  double _dragStartX = 0.0;
  double _panStart = 0.0;

  @override
  Widget build(BuildContext context) {
    final allHours = ref.watch(classicAllHoursProvider);
    final canvasState = ref.watch(classicCanvasProvider);
    final nowInfo = ref.watch(classicNowMarkerProvider);

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
        final maxScroll =
            (totalContentWidth - viewportWidth).clamp(0.0, double.infinity);

        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref.read(classicCanvasProvider.notifier).updateMaxOffset(maxScroll);
        });

        final totalGridHeight =
            timeH + rows.length * (cH + gap) + groupGap;

        final nowPx = nowInfo.fractionalIndex * pxPerHour;
        final nowScreenX = nowPx - canvasState.offsetPx + labelW;

        return GestureDetector(
          onHorizontalDragStart: (details) {
            _dragStartX = details.localPosition.dx;
            _panStart = ref.read(classicCanvasProvider).offsetPx;
            ref.read(classicCanvasProvider.notifier).startPan();
          },
          onHorizontalDragUpdate: (details) {
            final dx = details.localPosition.dx - _dragStartX;
            ref
                .read(classicCanvasProvider.notifier)
                .updateOffset(_panStart - dx);
          },
          onHorizontalDragEnd: (details) {
            ref
                .read(classicCanvasProvider.notifier)
                .endPan(details.velocity.pixelsPerSecond.dx * -1);
          },
          child: Container(
            color: DDACTheme.chartBackground,
            child: CustomPaint(
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
          ),
        );
      },
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

  static const String _fontFamily = 'Courier';

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

    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, size.height));

    _paintTimeAxis(canvas, size);
    _paintRowLabels(canvas, rows, rowH);

    final firstVisibleHour =
        (offsetPx / pxPerHour).floor().clamp(0, allHours.length - 1);
    final lastVisibleHour =
        ((offsetPx + viewportWidth) / pxPerHour).ceil().clamp(0, allHours.length);

    // --- Paint chicklets ---
    double y = timeAxisHeight;
    final gridBottom = timeAxisHeight + rows.length * rowH + groupGap;
    final radius = Radius.circular(AtmosphereConstants.classicChickletRadius);

    for (var r = 0; r < rows.length; r++) {
      if (r == AtmosphereConstants.classicSkyRowCount) {
        y += groupGap;
      }

      final row = rows[r];

      if (row.isThreeHour) {
        // ECMWF row: 3-hour merged blocks with partial hour ticks
        final startH = (firstVisibleHour ~/ 3) * 3;
        final tickPaint = Paint()
          ..color = DDACTheme.chartBackground
          ..strokeWidth = 1.0;
        final tickLen = chickletHeight * 0.3; // partial tick ~30% from each edge

        for (var h = startH; h < lastVisibleHour && h < allHours.length; h += 3) {
          final blockEnd = (h + 3).clamp(0, allHours.length);
          final blockHours = blockEnd - h;
          final screenX = h * pxPerHour - offsetPx + labelWidth;
          final blockWidth =
              blockHours * chickletWidth + (blockHours - 1) * chickletGap;

          if (screenX + blockWidth < labelWidth || screenX > viewportWidth) {
            continue;
          }

          final color = DDACTheme.chickletColor(row, allHours[h]);
          final left = screenX < labelWidth ? labelWidth : screenX;
          final right = (screenX + blockWidth).clamp(0.0, viewportWidth);
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(left, y, right - left, chickletHeight),
              radius,
            ),
            Paint()..color = color,
          );

          // Draw partial hour ticks at the 1st and 2nd hour within this block
          for (var t = 1; t < blockHours; t++) {
            // Center tick in the gap between chicklets
            final tickX = screenX + t * pxPerHour - chickletGap / 2;
            if (tickX <= labelWidth || tickX >= viewportWidth) continue;
            // Tick from top
            canvas.drawLine(Offset(tickX, y), Offset(tickX, y + tickLen), tickPaint);
            // Tick from bottom
            canvas.drawLine(
              Offset(tickX, y + chickletHeight - tickLen),
              Offset(tickX, y + chickletHeight),
              tickPaint,
            );
          }
        }
      } else {
        // Hourly rows: normal 1px-gap chicklets
        for (var h = firstVisibleHour; h < lastVisibleHour; h++) {
          final screenX = h * pxPerHour - offsetPx + labelWidth;
          if (screenX + chickletWidth < labelWidth || screenX > viewportWidth) {
            continue;
          }

          final color = DDACTheme.chickletColor(row, allHours[h]);

          if (screenX < labelWidth) {
            canvas.drawRRect(
              RRect.fromRectAndRadius(
                Rect.fromLTWH(
                    labelWidth, y, screenX + chickletWidth - labelWidth, chickletHeight),
                radius,
              ),
              Paint()..color = color,
            );
          } else {
            canvas.drawRRect(
              RRect.fromRectAndRadius(
                Rect.fromLTWH(screenX, y, chickletWidth, chickletHeight),
                radius,
              ),
              Paint()..color = color,
            );
          }
        }
      }
      y += rowH;
    }

    // --- Midnight red lines ---
    _paintMidnightLines(canvas, pxPerHour, gridBottom);

    // --- Now marker ---
    if (nowVisible && nowScreenX > labelWidth && nowScreenX < viewportWidth) {
      final nowPaint = Paint()
        ..color = DDACTheme.nowMarker
        ..strokeWidth = 2.0;
      canvas.drawLine(
        Offset(nowScreenX, timeAxisHeight),
        Offset(nowScreenX, gridBottom),
        nowPaint,
      );
    }

    // --- Vertical group labels (Sky / Ground) ---
    _paintGroupLabels(canvas, rows, rowH);
  }

  void _paintMidnightLines(Canvas canvas, double pxPerHour, double gridBottom) {
    final midnightPaint = Paint()
      ..color = DDACTheme.midnightLine
      ..strokeWidth = 1.0;

    for (var h = 0; h < allHours.length; h++) {
      if (allHours[h].time.hour == 0) {
        final screenX = h * pxPerHour - offsetPx + labelWidth;
        if (screenX > labelWidth && screenX < viewportWidth) {
          canvas.drawLine(
            Offset(screenX, timeAxisHeight),
            Offset(screenX, gridBottom),
            midnightPaint,
          );
        }
      }
    }
  }

  void _paintTimeAxis(Canvas canvas, Size size) {
    if (allHours.isEmpty) return;

    final pxPerHour = chickletWidth + chickletGap;

    // Three-row layout:
    // Row 1 (y=2): Day label — e.g. "Saturday, 7"
    // Row 2 (y~24): Tens digit
    // Row 3 (y~36): Ones digit
    const dayFontSize = 10.0;
    const digitFontSize = 10.0;
    final dayStyle = TextStyle(
      color: DDACTheme.cdsTextCyan,
      fontSize: dayFontSize,
      fontWeight: FontWeight.w600,
      fontFamily: _fontFamily,
    );
    final digitStyle = TextStyle(
      color: DDACTheme.cdsTextCyan,
      fontSize: digitFontSize,
      fontFamily: _fontFamily,
    );

    final tensRowY = timeAxisHeight - 24.0;
    final onesRowY = timeAxisHeight - 12.0;

    String? lastDay;
    for (var h = 0; h < allHours.length; h++) {
      final screenX = h * pxPerHour - offsetPx + labelWidth;
      if (screenX + chickletWidth < labelWidth || screenX > viewportWidth) {
        continue;
      }

      final time = allHours[h].time;

      // Day label at first hour of each new day
      final dayLabel = _dayLabel(time);
      if (dayLabel != lastDay) {
        lastDay = dayLabel;
        final tp = TextPainter(
          text: TextSpan(text: dayLabel, style: dayStyle),
          textDirection: TextDirection.ltr,
        )..layout();
        final dx = screenX.clamp(labelWidth, viewportWidth - tp.width);
        tp.paint(canvas, Offset(dx, 2));
      }

      // Tens digit (blank for 0-9)
      final tens = time.hour ~/ 10;
      if (tens > 0) {
        final tp = TextPainter(
          text: TextSpan(text: '$tens', style: digitStyle),
          textDirection: TextDirection.ltr,
        )..layout();
        final dx = screenX + (chickletWidth - tp.width) / 2;
        if (dx >= labelWidth) {
          tp.paint(canvas, Offset(dx, tensRowY));
        }
      }

      // Ones digit (always shown)
      final ones = time.hour % 10;
      final tp = TextPainter(
        text: TextSpan(text: '$ones', style: digitStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      final dx = screenX + (chickletWidth - tp.width) / 2;
      if (dx >= labelWidth) {
        tp.paint(canvas, Offset(dx, onesRowY));
      }
    }

    // Divider line below time axis
    canvas.drawLine(
      Offset(labelWidth, timeAxisHeight - 0.5),
      Offset(size.width, timeAxisHeight - 0.5),
      Paint()
        ..color = DDACTheme.divider
        ..strokeWidth = 0.5,
    );
  }

  void _paintRowLabels(Canvas canvas, List<ClassicRow> rows, double rowH) {
    // Background fill for label area
    canvas.drawRect(
      Rect.fromLTWH(0, 0, labelWidth, canvas.getLocalClipBounds().height),
      Paint()..color = DDACTheme.chartBackground,
    );

    final groupLabelW = AtmosphereConstants.classicGroupLabelWidth;
    final labelStyle = TextStyle(
      color: DDACTheme.cdsTextCyan,
      fontSize: 10,
      fontFamily: _fontFamily,
    );

    final boxPaint = Paint()..color = const Color(0xFF333333);
    const boxPadH = 3.0; // horizontal padding
    const boxPadV = 1.0; // vertical padding
    final boxRadius = Radius.circular(2.0);

    double y = timeAxisHeight;
    for (var r = 0; r < rows.length; r++) {
      if (r == AtmosphereConstants.classicSkyRowCount) {
        y += groupGap;
      }

      // Right-aligned label with colon, flush to chicklet column
      final text = '${rows[r].label}:';
      final tp = TextPainter(
        text: TextSpan(text: text, style: labelStyle),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '...',
      )..layout(maxWidth: labelWidth - groupLabelW - 4);

      final dx = labelWidth - tp.width - 2;
      final textY = y + (chickletHeight - tp.height) / 2;

      // Grey background box
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            dx - boxPadH, textY - boxPadV,
            tp.width + boxPadH * 2, tp.height + boxPadV * 2,
          ),
          boxRadius,
        ),
        boxPaint,
      );

      tp.paint(canvas, Offset(dx, textY));
      y += rowH;
    }
  }

  void _paintGroupLabels(Canvas canvas, List<ClassicRow> rows, double rowH) {
    final groupLabelW = AtmosphereConstants.classicGroupLabelWidth;

    // Calculate sky group bounds
    final skyTop = timeAxisHeight;
    final skyBottom = skyTop + AtmosphereConstants.classicSkyRowCount * rowH;

    // Calculate ground group bounds
    final groundTop = skyBottom + groupGap;
    final groundBottom = groundTop + AtmosphereConstants.classicGroundRowCount * rowH;

    // Draw "Sky" vertically
    _paintVerticalLabel(
      canvas,
      'Sky',
      DDACTheme.skyGroupLabel,
      groupLabelW / 2,
      skyTop,
      skyBottom,
    );

    // Draw "Ground" vertically
    _paintVerticalLabel(
      canvas,
      'Ground',
      DDACTheme.groundGroupLabel,
      groupLabelW / 2,
      groundTop,
      groundBottom,
    );
  }

  void _paintVerticalLabel(
    Canvas canvas,
    String text,
    Color color,
    double x,
    double top,
    double bottom,
  ) {
    final style = TextStyle(
      color: color,
      fontSize: 9,
      fontWeight: FontWeight.w700,
      fontFamily: _fontFamily,
    );

    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();

    final centerY = (top + bottom) / 2;
    final groupHeight = bottom - top;

    canvas.save();
    canvas.translate(x, centerY);
    canvas.rotate(-3.14159 / 2); // -90 degrees

    // Grey background box aligned to row edges
    const padH = 2.0;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          -groupHeight / 2, -tp.height / 2 - padH,
          groupHeight, tp.height + padH * 2,
        ),
        const Radius.circular(2.0),
      ),
      Paint()..color = const Color(0xFF333333),
    );

    tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
    canvas.restore();
  }

  String _dayLabel(DateTime time) {
    const days = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday',
      'Friday', 'Saturday', 'Sunday',
    ];
    return '${days[time.weekday - 1]}, ${time.day}';
  }

  @override
  bool shouldRepaint(covariant _GridPainter old) {
    return old.offsetPx != offsetPx ||
        old.allHours != allHours ||
        old.nowScreenX != nowScreenX;
  }
}
