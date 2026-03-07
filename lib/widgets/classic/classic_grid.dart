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

      if (dayLabel != lastDay) {
        lastDay = dayLabel;
        final tp = TextPainter(
          text: TextSpan(text: dayLabel, style: dayStyle),
          textDirection: TextDirection.ltr,
        )..layout();
        final dx = screenX.clamp(labelWidth, viewportWidth - tp.width);
        tp.paint(canvas, Offset(dx, 2));
      }

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

    canvas.drawLine(
      Offset(labelWidth, timeAxisHeight - 0.5),
      Offset(size.width, timeAxisHeight - 0.5),
      Paint()
        ..color = DDACTheme.divider
        ..strokeWidth = 0.5,
    );
  }

  void _paintRowLabels(Canvas canvas, List<ClassicRow> rows, double rowH) {
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
