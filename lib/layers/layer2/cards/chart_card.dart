import 'package:flutter/material.dart';

import '../../../core/theme/atmosphere_colors.dart';

enum ChartType { area, line }

/// A simple chart widget that renders mock data as area or line chart.
class ChartCard extends StatelessWidget {
  final List<double> values;
  final double maxValue;
  final ChartType type;
  final Color? color;
  final List<double>? gustValues;

  const ChartCard({
    super.key,
    required this.values,
    required this.maxValue,
    this.type = ChartType.area,
    this.color,
    this.gustValues,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _ChartPainter(
        values: values,
        maxValue: maxValue,
        type: type,
        color: color ?? AtmosphereColors.mediumBlue,
        gustValues: gustValues,
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

  _ChartPainter({
    required this.values,
    required this.maxValue,
    required this.type,
    required this.color,
    this.gustValues,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    final points = <Offset>[];

    for (var i = 0; i < values.length; i++) {
      final x = (i / (values.length - 1).clamp(1, values.length)) * size.width;
      final y = size.height - (values[i] / maxValue) * size.height;
      points.add(Offset(x, y));
    }

    // Smooth curve through points
    if (points.isNotEmpty) {
      path.moveTo(points[0].dx, points[0].dy);
      for (var i = 1; i < points.length; i++) {
        final prev = points[i - 1];
        final curr = points[i];
        final cpx = (prev.dx + curr.dx) / 2;
        path.cubicTo(cpx, prev.dy, cpx, curr.dy, curr.dx, curr.dy);
      }
    }

    canvas.drawPath(path, paint);

    // Fill for area chart
    if (type == ChartType.area && points.isNotEmpty) {
      final fillPath = Path.from(path);
      fillPath.lineTo(points.last.dx, size.height);
      fillPath.lineTo(points.first.dx, size.height);
      fillPath.close();

      final fillPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withValues(alpha: 0.3),
            color.withValues(alpha: 0.05),
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
        ..style = PaintingStyle.fill;

      canvas.drawPath(fillPath, fillPaint);
    }

    // Gust markers
    if (gustValues != null) {
      final gustPaint = Paint()
        ..color = color.withValues(alpha: 0.4)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;

      for (var i = 0; i < gustValues!.length; i++) {
        if (gustValues![i] <= 0) continue;
        final x =
            (i / (gustValues!.length - 1).clamp(1, gustValues!.length)) *
                size.width;
        final baseY =
            size.height - (values[i] / maxValue) * size.height;
        final gustY =
            size.height - (gustValues![i] / maxValue) * size.height;
        canvas.drawLine(Offset(x, baseY), Offset(x, gustY), gustPaint);

        // Small circle at gust peak
        canvas.drawCircle(
          Offset(x, gustY),
          3,
          Paint()
            ..color = color.withValues(alpha: 0.5)
            ..style = PaintingStyle.fill,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_ChartPainter oldDelegate) => true;
}
