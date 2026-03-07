import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/theme/ddac_theme.dart';
import '../../models/forecast.dart';
import '../../providers/classic_canvas_provider.dart';

class ClassicMinimap extends ConsumerWidget {
  const ClassicMinimap({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allHours = ref.watch(classicAllHoursProvider);
    final canvasState = ref.watch(classicCanvasProvider);
    final nowInfo = ref.watch(classicNowMarkerProvider);

    if (allHours.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final chartWidth = totalWidth;
        final hourCount = allHours.length;
        final chickletW = chartWidth / hourCount;

        // Selection box dimensions
        final pxPerHour = AtmosphereConstants.classicChickletWidth +
            AtmosphereConstants.classicChickletGap;
        final totalContentWidth = hourCount * pxPerHour;
        final gridViewportWidth =
            totalWidth - AtmosphereConstants.classicRowLabelWidth;
        final visibleFraction = totalContentWidth > 0
            ? (gridViewportWidth / totalContentWidth).clamp(0.0, 1.0)
            : 1.0;
        final selBoxWidth = (visibleFraction * chartWidth)
            .clamp(AtmosphereConstants.classicSelectionBoxMinWidth, chartWidth);
        final scrollFraction = totalContentWidth > gridViewportWidth
            ? (canvasState.offsetPx / (totalContentWidth - gridViewportWidth))
                .clamp(0.0, 1.0)
            : 0.0;
        final selBoxLeft =
            scrollFraction * (chartWidth - selBoxWidth);

        // Now marker position
        final nowX = hourCount > 1
            ? (nowInfo.fractionalIndex / (hourCount - 1)) * chartWidth
            : 0.0;

        return GestureDetector(
          onTapDown: (details) {
            _handleTap(details.localPosition.dx, chartWidth, hourCount,
                gridViewportWidth, totalContentWidth, ref);
          },
          onHorizontalDragUpdate: (details) {
            _handleDrag(details.localPosition.dx, chartWidth, selBoxWidth,
                gridViewportWidth, totalContentWidth, ref);
          },
          child: Container(
            height: AtmosphereConstants.classicMinimapHeight,
            color: DDACTheme.chartBackground,
            child: CustomPaint(
              size: Size(totalWidth, AtmosphereConstants.classicMinimapHeight),
              painter: _MinimapPainter(
                allHours: allHours,
                chickletWidth: chickletW,
                selectionBoxLeft: selBoxLeft,
                selectionBoxWidth: selBoxWidth,
                nowX: nowX,
                nowVisible: nowInfo.isWithinTimeline,
              ),
            ),
          ),
        );
      },
    );
  }

  void _handleTap(double tapX, double chartWidth, int hourCount,
      double gridViewportWidth, double totalContentWidth, WidgetRef ref) {
    final tapFraction = (tapX / chartWidth).clamp(0.0, 1.0);
    final targetHour = (tapFraction * hourCount).floor();
    ref.read(classicCanvasProvider.notifier).jumpToHourIndex(
          targetHour,
          gridViewportWidth,
        );
  }

  void _handleDrag(double dragX, double chartWidth, double selBoxWidth,
      double gridViewportWidth, double totalContentWidth, WidgetRef ref) {
    final scrollableChartRange = chartWidth - selBoxWidth;
    if (scrollableChartRange <= 0) return;
    final fraction =
        ((dragX - selBoxWidth / 2) / scrollableChartRange).clamp(0.0, 1.0);
    final maxScroll = totalContentWidth - gridViewportWidth;
    if (maxScroll <= 0) return;
    ref.read(classicCanvasProvider.notifier).jumpTo(fraction * maxScroll);
  }
}

class _MinimapPainter extends CustomPainter {
  final List<HourlyForecast> allHours;
  final double chickletWidth;
  final double selectionBoxLeft;
  final double selectionBoxWidth;
  final double nowX;
  final bool nowVisible;

  static const String _fontFamily = 'Courier';

  _MinimapPainter({
    required this.allHours,
    required this.chickletWidth,
    required this.selectionBoxLeft,
    required this.selectionBoxWidth,
    required this.nowX,
    required this.nowVisible,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rows = ClassicRow.values;
    final rowH = AtmosphereConstants.classicMinimapRowHeight;
    final gap = AtmosphereConstants.classicMinimapGroupGap;
    final timeH = AtmosphereConstants.classicMinimapTimeAxisHeight;

    _paintTimeAxis(canvas, size, timeH);

    double y = timeH;

    for (var r = 0; r < rows.length; r++) {
      final row = rows[r];
      if (r == AtmosphereConstants.classicSkyRowCount) {
        y += gap;
      }

      // Inset chicklets to create black gap lines between columns and rows
      const insetX = 0.5;
      const insetY = 0.5;
      final drawH = rowH - insetY;

      if (row.isThreeHour) {
        // ECMWF row: 3-hour merged blocks with partial hour ticks
        final tickPaint = Paint()
          ..color = DDACTheme.chartBackground
          ..strokeWidth = 0.5;
        final tickLen = drawH * 0.3;

        for (var h = 0; h < allHours.length; h += 3) {
          final x = h * chickletWidth;
          final blockEnd = (h + 3).clamp(0, allHours.length);
          final blockHours = blockEnd - h;
          final blockWidth = blockHours * chickletWidth;
          final color = DDACTheme.chickletColor(row, allHours[h]);
          canvas.drawRect(
            Rect.fromLTWH(x + insetX, y, blockWidth - insetX * 2, drawH),
            Paint()..color = color,
          );

          // Partial hour ticks at 1st and 2nd hour within block
          for (var t = 1; t < blockHours; t++) {
            final tickX = x + t * chickletWidth;
            canvas.drawLine(Offset(tickX, y), Offset(tickX, y + tickLen), tickPaint);
            canvas.drawLine(
              Offset(tickX, y + drawH - tickLen),
              Offset(tickX, y + drawH),
              tickPaint,
            );
          }
        }
      } else {
        for (var h = 0; h < allHours.length; h++) {
          final x = h * chickletWidth;
          final color = DDACTheme.chickletColor(row, allHours[h]);
          canvas.drawRect(
            Rect.fromLTWH(x + insetX, y, chickletWidth - insetX * 2, drawH),
            Paint()..color = color,
          );
        }
      }
      y += rowH;
    }

    // Daytime hour labels overlaid on grid
    _paintDaytimeHours(canvas, timeH, y);

    // Midnight lines
    final midnightPaint = Paint()
      ..color = DDACTheme.midnightLine
      ..strokeWidth = 0.5;
    for (var h = 0; h < allHours.length; h++) {
      if (allHours[h].time.hour == 0) {
        final x = h * chickletWidth;
        canvas.drawLine(Offset(x, timeH), Offset(x, y), midnightPaint);
      }
    }

    // Now marker
    if (nowVisible) {
      final nowPaint = Paint()
        ..color = DDACTheme.nowMarker
        ..strokeWidth = 1.0;
      canvas.drawLine(
        Offset(nowX, timeH),
        Offset(nowX, y),
        nowPaint,
      );
    }

    // Selection box
    final selPaint = Paint()
      ..color = DDACTheme.selectionBox
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawRect(
      Rect.fromLTWH(selectionBoxLeft, timeH, selectionBoxWidth, y - timeH),
      selPaint,
    );

    // Attribution line
    _paintAttribution(canvas, size, y + 2);
  }

  void _paintAttribution(Canvas canvas, Size size, double y) {
    const copyrightStyle = TextStyle(
      color: DDACTheme.rowLabelText,
      fontSize: 8,
      fontFamily: _fontFamily,
    );
    const nameStyle = TextStyle(
      color: DDACTheme.cdsTitleYellow,
      fontSize: 8,
      fontFamily: _fontFamily,
    );
    const labelStyle = TextStyle(
      color: DDACTheme.rowLabelText,
      fontSize: 8,
      fontFamily: _fontFamily,
    );
    const forecastStyle = TextStyle(
      color: DDACTheme.cdsTitleYellow,
      fontSize: 8,
      fontFamily: _fontFamily,
    );
    const dataStyle = TextStyle(
      color: DDACTheme.rowLabelText,
      fontSize: 8,
      fontFamily: _fontFamily,
    );
    const cmcStyle = TextStyle(
      color: DDACTheme.cdsTextCyan,
      fontSize: 8,
      fontWeight: FontWeight.w700,
      fontFamily: _fontFamily,
    );

    final tp = TextPainter(
      text: const TextSpan(
        children: [
          TextSpan(text: '\u00A9 2026 ', style: copyrightStyle),
          TextSpan(text: 'Attilla Danko', style: nameStyle),
          TextSpan(text: '   forecast: ', style: labelStyle),
          TextSpan(text: 'A. Rahill', style: forecastStyle),
          TextSpan(text: '   data: ', style: dataStyle),
          TextSpan(text: 'CMC', style: cmcStyle),
          TextSpan(text: ' Environment Canada', style: dataStyle),
        ],
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final dx = (size.width - tp.width) / 2;
    tp.paint(canvas, Offset(dx, y));
  }

  void _paintTimeAxis(Canvas canvas, Size size, double timeH) {
    if (allHours.isEmpty) return;

    final textStyle = TextStyle(
      color: DDACTheme.cdsTextCyan,
      fontSize: 7,
      fontFamily: _fontFamily,
    );

    String? lastDay;
    for (var h = 0; h < allHours.length; h++) {
      final x = h * chickletWidth;
      final time = allHours[h].time;
      final dayLabel = '${time.month}/${time.day}';

      if (dayLabel != lastDay) {
        lastDay = dayLabel;
        final tp = TextPainter(
          text: TextSpan(text: dayLabel, style: textStyle),
          textDirection: TextDirection.ltr,
        )..layout();
        if (x + tp.width < size.width) {
          tp.paint(canvas, Offset(x + 1, 0));
        }
      }

      if (time.hour % 3 == 0) {
        final hourLabel = '${time.hour}';
        final tp = TextPainter(
          text: TextSpan(text: hourLabel, style: textStyle),
          textDirection: TextDirection.ltr,
        )..layout();
        if (x + tp.width < size.width) {
          tp.paint(canvas, Offset(x + 1, timeH - tp.height - 1));
        }
      }
    }
  }

  void _paintDaytimeHours(Canvas canvas, double gridTop, double gridBottom) {
    final textStyle = TextStyle(
      color: DDACTheme.chartBackground.withAlpha(180),
      fontSize: 7,
      fontWeight: FontWeight.w700,
      fontFamily: _fontFamily,
    );
    final centerY = (gridTop + gridBottom) / 2;

    for (var h = 0; h < allHours.length; h++) {
      final hour = allHours[h].time.hour;
      if (!DDACTheme.isDaytime(allHours[h].time)) continue;
      if (hour % 2 != 0) continue; // every 2nd hour to avoid crowding

      final x = h * chickletWidth;
      final tp = TextPainter(
        text: TextSpan(text: '$hour', style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x + (chickletWidth - tp.width) / 2, centerY - tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant _MinimapPainter old) {
    return old.selectionBoxLeft != selectionBoxLeft ||
        old.selectionBoxWidth != selectionBoxWidth ||
        old.nowX != nowX ||
        old.allHours != allHours;
  }
}
