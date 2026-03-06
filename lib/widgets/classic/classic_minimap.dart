import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/theme/ddac_theme.dart';
import '../../models/forecast.dart';
import '../../providers/classic_canvas_provider.dart';
import '../../providers/classic_lens_provider.dart';

class ClassicMinimap extends ConsumerWidget {
  const ClassicMinimap({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allHours = ref.watch(classicAllHoursProvider);
    final canvasState = ref.watch(classicCanvasProvider);
    final nowInfo = ref.watch(classicNowMarkerProvider);
    final lensState = ref.watch(classicLensProvider);

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

        // Lens center marker on minimap (when lens is active)
        final double? lensCenterX;
        if (lensState.isActive && lensState.focalHourIndex != null) {
          lensCenterX = hourCount > 1
              ? (lensState.focalHourIndex! / (hourCount - 1)) * chartWidth
              : 0.0;
        } else {
          lensCenterX = null;
        }

        return GestureDetector(
          onTapDown: (details) {
            if (lensState.isFullyOpen) {
              _handleLensReposition(details.localPosition.dx, chartWidth,
                  hourCount, pxPerHour, ref);
            } else {
              _handleTap(details.localPosition.dx, chartWidth, hourCount,
                  gridViewportWidth, totalContentWidth, ref);
            }
          },
          onHorizontalDragUpdate: (details) {
            if (lensState.isFullyOpen) {
              _handleLensReposition(details.localPosition.dx, chartWidth,
                  hourCount, pxPerHour, ref);
            } else {
              _handleDrag(details.localPosition.dx, chartWidth, selBoxWidth,
                  gridViewportWidth, totalContentWidth, ref);
            }
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
                lensCenterX: lensCenterX,
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

  /// When lens is active, tapping/dragging the minimap repositions the lens center.
  void _handleLensReposition(double tapX, double chartWidth, int hourCount,
      double pxPerHour, WidgetRef ref) {
    final tapFraction = (tapX / chartWidth).clamp(0.0, 1.0);
    final targetHour = (tapFraction * hourCount).floor().clamp(0, hourCount - 1);
    final gridX = targetHour * pxPerHour + pxPerHour / 2;

    // Keep the same Y position
    final currentState = ref.read(classicLensProvider);
    ref.read(classicLensProvider.notifier).moveLensCenter(gridX, currentState.centerGridY);

    // Update focal indices — keep same row, update hour
    final currentRow = currentState.focalRowIndex ?? 0;
    ref.read(classicLensProvider.notifier).updateFocalIndices(targetHour, currentRow);

    // Also scroll the grid to keep the lens center visible
    final labelW = AtmosphereConstants.classicRowLabelWidth;
    final canvasNotifier = ref.read(classicCanvasProvider.notifier);
    final maxOffset = canvasNotifier.maxOffset;
    final viewportWidth = chartWidth - labelW;
    final targetOffset = (gridX - viewportWidth / 2).clamp(0.0, maxOffset);
    canvasNotifier.jumpTo(targetOffset);
  }
}

class _MinimapPainter extends CustomPainter {
  final List<HourlyForecast> allHours;
  final double chickletWidth;
  final double selectionBoxLeft;
  final double selectionBoxWidth;
  final double nowX;
  final bool nowVisible;
  final double? lensCenterX;

  _MinimapPainter({
    required this.allHours,
    required this.chickletWidth,
    required this.selectionBoxLeft,
    required this.selectionBoxWidth,
    required this.nowX,
    required this.nowVisible,
    this.lensCenterX,
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

      for (var h = 0; h < allHours.length; h++) {
        final x = h * chickletWidth;
        final color = DDACTheme.chickletColor(row, allHours[h]);
        canvas.drawRect(
          Rect.fromLTWH(x, y, chickletWidth, rowH),
          Paint()..color = color,
        );
      }
      y += rowH;
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

    // Lens center marker
    if (lensCenterX != null) {
      final lensPaint = Paint()
        ..color = const Color(0xFFFFFF00)
        ..strokeWidth = 1.5;
      canvas.drawLine(
        Offset(lensCenterX!, timeH),
        Offset(lensCenterX!, y),
        lensPaint,
      );
      // Small diamond at center
      final midY = (timeH + y) / 2;
      final path = Path()
        ..moveTo(lensCenterX!, midY - 4)
        ..lineTo(lensCenterX! + 3, midY)
        ..lineTo(lensCenterX!, midY + 4)
        ..lineTo(lensCenterX! - 3, midY)
        ..close();
      canvas.drawPath(path, Paint()..color = const Color(0xFFFFFF00));
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
  }

  void _paintTimeAxis(Canvas canvas, Size size, double timeH) {
    if (allHours.isEmpty) return;

    final textStyle = TextStyle(
      color: DDACTheme.timeAxisText,
      fontSize: 7,
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

  @override
  bool shouldRepaint(covariant _MinimapPainter old) {
    return old.selectionBoxLeft != selectionBoxLeft ||
        old.selectionBoxWidth != selectionBoxWidth ||
        old.nowX != nowX ||
        old.allHours != allHours ||
        old.lensCenterX != lensCenterX;
  }
}
