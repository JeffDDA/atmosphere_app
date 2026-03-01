import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants.dart';
import '../../../core/theme/atmosphere_colors.dart';
import '../../../providers/canvas_provider.dart';

enum ChartType { area, line }

/// Chart widget with canvas-panning rendering at fixed pixel-per-hour scale.
class ChartCard extends ConsumerWidget {
  final List<double> values;
  final double maxValue;
  final ChartType type;
  final Color? color;
  final List<double>? gustValues;
  final List<double>? secondaryValues;
  final Color? secondaryColor;
  final List<Color>? segmentColors;
  final List<int> nightBoundaryIndices;

  const ChartCard({
    super.key,
    required this.values,
    required this.maxValue,
    this.type = ChartType.area,
    this.color,
    this.gustValues,
    this.secondaryValues,
    this.secondaryColor,
    this.segmentColors,
    this.nightBoundaryIndices = const [],
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canvasState = ref.watch(canvasProvider);

    return CustomPaint(
      painter: _ChartPainter(
        values: values,
        maxValue: maxValue,
        type: type,
        color: color ?? AtmosphereColors.mediumBlue,
        gustValues: gustValues,
        secondaryValues: secondaryValues,
        secondaryColor: secondaryColor,
        segmentColors: segmentColors,
        canvasOffsetPx: canvasState.offsetPx,
        isPanning: canvasState.isPanning,
        pixelsPerHour: AtmosphereConstants.canvasPixelsPerHour,
        nightBoundaryIndices: nightBoundaryIndices,
      ),
      size: Size.infinite,
    );
  }
}

class _ChartPainter extends CustomPainter {
  final List<double> values;
  final double maxValue;
  final ChartType type;
  final Color color;
  final List<double>? gustValues;
  final List<double>? secondaryValues;
  final Color? secondaryColor;
  final List<Color>? segmentColors;
  final double canvasOffsetPx;
  final bool isPanning;
  final double pixelsPerHour;
  final List<int> nightBoundaryIndices;

  _ChartPainter({
    required this.values,
    required this.maxValue,
    required this.type,
    required this.color,
    this.gustValues,
    this.secondaryValues,
    this.secondaryColor,
    this.segmentColors,
    required this.canvasOffsetPx,
    required this.isPanning,
    required this.pixelsPerHour,
    this.nightBoundaryIndices = const [],
  });

  double get _anchorFraction => AtmosphereConstants.canvasReadingAnchorFraction;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;

    final anchorScreenX = _anchorFraction * size.width;
    final tx = anchorScreenX - canvasOffsetPx;

    // --- Translated data layer ---
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.translate(tx, 0);

    _drawDataLine(canvas, size, values, color, type,
        filled: type == ChartType.area);

    if (secondaryValues != null && secondaryValues!.isNotEmpty) {
      _drawDataLine(
        canvas,
        size,
        secondaryValues!,
        secondaryColor ?? color.withValues(alpha: 0.5),
        ChartType.line,
        filled: false,
        dashed: true,
      );
    }

    _drawNightBoundaries(canvas, size);

    if (gustValues != null) {
      _drawGustMarkers(canvas, size);
    }

    canvas.restore();

    // --- Fixed viewport layer (cursor indicator) ---
    _drawCursorIndicator(canvas, size, anchorScreenX);
  }

  void _drawDataLine(
    Canvas canvas,
    Size size,
    List<double> data,
    Color lineColor,
    ChartType chartType, {
    bool filled = false,
    bool dashed = false,
  }) {
    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    final points = <Offset>[];

    for (var i = 0; i < data.length; i++) {
      final x = i * pixelsPerHour;
      final y =
          size.height - (data[i] / maxValue).clamp(0.0, 1.0) * size.height;
      points.add(Offset(x, y));
    }

    if (points.isEmpty) return;

    path.moveTo(points[0].dx, points[0].dy);
    for (var i = 1; i < points.length; i++) {
      final prev = points[i - 1];
      final curr = points[i];
      final cpx = (prev.dx + curr.dx) / 2;
      path.cubicTo(cpx, prev.dy, cpx, curr.dy, curr.dx, curr.dy);
    }

    canvas.drawPath(path, paint);

    // Fill for area chart
    if (filled && points.isNotEmpty) {
      final fillPath = Path.from(path);
      fillPath.lineTo(points.last.dx, size.height);
      fillPath.lineTo(points.first.dx, size.height);
      fillPath.close();

      final dataWidth = (data.length - 1) * pixelsPerHour;

      Paint fillPaint;
      if (segmentColors != null && segmentColors!.length == data.length) {
        fillPaint = Paint()
          ..shader = LinearGradient(
            colors:
                segmentColors!.map((c) => c.withValues(alpha: 0.3)).toList(),
            stops: List.generate(
              segmentColors!.length,
              (i) =>
                  i /
                  (segmentColors!.length - 1)
                      .clamp(1, segmentColors!.length),
            ),
          ).createShader(Rect.fromLTWH(0, 0, dataWidth, size.height))
          ..style = PaintingStyle.fill;
      } else {
        fillPaint = Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              lineColor.withValues(alpha: 0.3),
              lineColor.withValues(alpha: 0.05),
            ],
          ).createShader(Rect.fromLTWH(0, 0, dataWidth, size.height))
          ..style = PaintingStyle.fill;
      }

      canvas.drawPath(fillPath, fillPaint);
    }
  }

  void _drawNightBoundaries(Canvas canvas, Size size) {
    if (nightBoundaryIndices.isEmpty || values.length <= 1) return;

    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.12)
      ..strokeWidth = 1.0;

    for (final idx in nightBoundaryIndices) {
      final x = idx * pixelsPerHour;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
  }

  void _drawGustMarkers(Canvas canvas, Size size) {
    final gustPaint = Paint()
      ..color = color.withValues(alpha: 0.4)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    for (var i = 0; i < gustValues!.length; i++) {
      if (gustValues![i] <= 0) continue;
      final x = i * pixelsPerHour;
      final baseY =
          size.height - (values[i] / maxValue).clamp(0.0, 1.0) * size.height;
      final gustY = size.height -
          (gustValues![i] / maxValue).clamp(0.0, 1.0) * size.height;
      canvas.drawLine(Offset(x, baseY), Offset(x, gustY), gustPaint);

      canvas.drawCircle(
        Offset(x, gustY),
        3,
        Paint()
          ..color = color.withValues(alpha: 0.5)
          ..style = PaintingStyle.fill,
      );
    }
  }

  void _drawCursorIndicator(Canvas canvas, Size size, double anchorScreenX) {
    final alpha = isPanning ? 0.8 : 0.3;

    // Vertical indicator line at fixed screen position
    canvas.drawLine(
      Offset(anchorScreenX, 0),
      Offset(anchorScreenX, size.height),
      Paint()
        ..color = Colors.white.withValues(alpha: alpha)
        ..strokeWidth = isPanning ? 1.5 : 1.0,
    );

    // Value dot on the primary line at cursor position
    if (values.isNotEmpty) {
      final fracIdx = canvasOffsetPx / pixelsPerHour;
      final idx = fracIdx.floor().clamp(0, values.length - 2);
      final t = fracIdx - idx;
      final interpolatedValue = values[idx] * (1 - t) +
          values[(idx + 1).clamp(0, values.length - 1)] * t;
      final dotY = size.height -
          (interpolatedValue / maxValue).clamp(0.0, 1.0) * size.height;

      // Glow
      if (isPanning) {
        canvas.drawCircle(
          Offset(anchorScreenX, dotY),
          8,
          Paint()
            ..color = color.withValues(alpha: 0.3)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
        );
      }

      // Dot
      canvas.drawCircle(
        Offset(anchorScreenX, dotY),
        isPanning ? 5 : 3,
        Paint()
          ..color =
              Colors.white.withValues(alpha: isPanning ? 0.95 : 0.5)
          ..style = PaintingStyle.fill,
      );
    }
  }

  @override
  bool shouldRepaint(_ChartPainter old) {
    return old.canvasOffsetPx != canvasOffsetPx ||
        old.isPanning != isPanning ||
        old.values != values;
  }
}
