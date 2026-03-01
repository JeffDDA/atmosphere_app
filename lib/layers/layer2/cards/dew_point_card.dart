import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants.dart';
import '../../../core/theme/atmosphere_colors.dart';
import '../../../models/forecast.dart';
import '../../../providers/canvas_provider.dart';
import 'base_card.dart';

class DewPointCard extends ConsumerWidget {
  final List<HourlyForecast> hours;
  final List<int> nightBoundaryIndices;

  const DewPointCard({
    super.key,
    required this.hours,
    this.nightBoundaryIndices = const [],
  });

  /// Contextual trigger: spread narrows below 5C at any point.
  static bool shouldShow(List<HourlyForecast> hours) {
    return hours.any((h) => h.dewSpreadC < 5);
  }

  String _verdict() {
    final minSpread = hours.map((h) => h.dewSpreadC).reduce((a, b) => a < b ? a : b);
    final isFrost = hours.any((h) => h.temperatureC < 0 && h.dewSpreadC < 3);
    final isFog = hours.any((h) => h.dewSpreadC <= 0);

    if (isFog) {
      final fogHour = hours.firstWhere((h) => h.dewSpreadC <= 0);
      final hour = fogHour.time.hour % 12 == 0 ? 12 : fogHour.time.hour % 12;
      final ampm = fogHour.time.hour < 12 ? 'am' : 'pm';
      return 'Fog Warning — Spread Reaches Zero After $hour$ampm';
    }
    if (isFrost) return 'Frost Warning — Convergence Below Freezing';
    if (minSpread < 2) return 'Critical — Dew Likely';

    // Find convergence time
    final convergeHour = hours.firstWhere(
      (h) => h.dewSpreadC < 5,
      orElse: () => hours.last,
    );
    final hour = convergeHour.time.hour % 12 == 0 ? 12 : convergeHour.time.hour % 12;
    final ampm = convergeHour.time.hour < 12 ? 'am' : 'pm';

    if (minSpread < 5) return 'Convergence After $hour$ampm';
    return 'Narrowing — Monitor Tonight';
  }

  String _contextLine() {
    final minSpread = hours.map((h) => h.dewSpreadC).reduce((a, b) => a < b ? a : b);
    final hasCalm = hours.every((h) => h.windMph < 5);

    if (minSpread <= 0) {
      return 'Surface fog likely. Equipment exposure beyond this point risks condensation on all surfaces including electronics.';
    }
    if (hasCalm && minSpread < 5) {
      return 'Clearing skies, calm wind, and narrowing dew point spread — classic dew setup. Run heaters high from the start tonight.';
    }
    if (minSpread < 3) {
      return 'Prevention is the only dew strategy that works. Run dew heaters from the moment you open the roof, not when problems appear.';
    }
    return 'Dew point spread is narrowing. The convergence between temperature and dew point is the critical number — watch the closing gap.';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canvasState = ref.watch(canvasProvider);

    return BaseCard(
      parameterName: 'Dew Point',
      verdict: _verdict(),
      body: CustomPaint(
        painter: _DewPointPainter(
          hours: hours,
          canvasOffsetPx: canvasState.offsetPx,
          isPanning: canvasState.isPanning,
          pixelsPerHour: AtmosphereConstants.canvasPixelsPerHour,
          nightBoundaryIndices: nightBoundaryIndices,
        ),
        size: Size.infinite,
      ),
      context: _contextLine(),
    );
  }
}

class _DewPointPainter extends CustomPainter {
  final List<HourlyForecast> hours;
  final double canvasOffsetPx;
  final bool isPanning;
  final double pixelsPerHour;
  final List<int> nightBoundaryIndices;

  _DewPointPainter({
    required this.hours,
    required this.canvasOffsetPx,
    required this.isPanning,
    required this.pixelsPerHour,
    this.nightBoundaryIndices = const [],
  });

  double get _anchorFraction => AtmosphereConstants.canvasReadingAnchorFraction;

  @override
  void paint(Canvas canvas, Size size) {
    if (hours.isEmpty) return;

    final anchorScreenX = _anchorFraction * size.width;
    final tx = anchorScreenX - canvasOffsetPx;

    // Find temperature range for scaling
    final allTemps = [
      ...hours.map((h) => h.temperatureC),
      ...hours.map((h) => h.dewPointC),
    ];
    final minTemp = allTemps.reduce((a, b) => a < b ? a : b) - 2;
    final maxTemp = allTemps.reduce((a, b) => a > b ? a : b) + 2;
    final range = maxTemp - minTemp;

    double yForTemp(double temp) {
      return size.height - ((temp - minTemp) / range) * size.height;
    }

    // --- Translated data layer ---
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.translate(tx, 0);

    // Temperature line points
    final tempPoints = <Offset>[];
    final dewPoints = <Offset>[];
    for (var i = 0; i < hours.length; i++) {
      final x = i * pixelsPerHour;
      tempPoints.add(Offset(x, yForTemp(hours[i].temperatureC)));
      dewPoints.add(Offset(x, yForTemp(hours[i].dewPointC)));
    }

    // Fill the convergence zone between lines
    final spreadPath = Path();
    spreadPath.moveTo(tempPoints[0].dx, tempPoints[0].dy);
    for (var i = 1; i < tempPoints.length; i++) {
      final prev = tempPoints[i - 1];
      final curr = tempPoints[i];
      final cpx = (prev.dx + curr.dx) / 2;
      spreadPath.cubicTo(cpx, prev.dy, cpx, curr.dy, curr.dx, curr.dy);
    }
    for (var i = dewPoints.length - 1; i >= 0; i--) {
      if (i == dewPoints.length - 1) {
        spreadPath.lineTo(dewPoints[i].dx, dewPoints[i].dy);
      } else {
        final next = dewPoints[i + 1];
        final curr = dewPoints[i];
        final cpx = (next.dx + curr.dx) / 2;
        spreadPath.cubicTo(cpx, next.dy, cpx, curr.dy, curr.dx, curr.dy);
      }
    }
    spreadPath.close();

    // Color the spread zone — red when narrow, blue when safe
    final minSpread =
        hours.map((h) => h.dewSpreadC).reduce((a, b) => a < b ? a : b);
    final spreadAlpha = minSpread < 3 ? 0.25 : 0.12;
    final spreadColor = minSpread < 3
        ? const Color(0xFFFF6B6B).withValues(alpha: spreadAlpha)
        : AtmosphereColors.mediumBlue.withValues(alpha: spreadAlpha);
    canvas.drawPath(spreadPath, Paint()..color = spreadColor);

    // Draw temperature line
    _drawLine(canvas, tempPoints, AtmosphereColors.textPrimaryDark);

    // Draw dew point line (dashed appearance via lower opacity)
    _drawLine(canvas, dewPoints, AtmosphereColors.blueGrey);

    // Labels — draw at positions relative to data
    final labelStyle = TextStyle(
      color: Colors.white.withValues(alpha: 0.5),
      fontSize: 10,
    );
    _paintLabel(
        canvas, 'Temp', Offset(4, tempPoints.first.dy - 14), labelStyle);
    _paintLabel(
        canvas, 'Dew Pt', Offset(4, dewPoints.first.dy + 4), labelStyle);

    // Night boundary separators
    if (nightBoundaryIndices.isNotEmpty && hours.length > 1) {
      final boundaryPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.12)
        ..strokeWidth = 1.0;
      for (final idx in nightBoundaryIndices) {
        final bx = idx * pixelsPerHour;
        canvas.drawLine(Offset(bx, 0), Offset(bx, size.height), boundaryPaint);
      }
    }

    canvas.restore();

    // --- Fixed viewport layer (cursor indicator) ---
    final cursorAlpha = isPanning ? 0.8 : 0.3;
    canvas.drawLine(
      Offset(anchorScreenX, 0),
      Offset(anchorScreenX, size.height),
      Paint()
        ..color = Colors.white.withValues(alpha: cursorAlpha)
        ..strokeWidth = isPanning ? 1.5 : 1.0,
    );

    // Cursor value dots
    if (isPanning && hours.length > 1) {
      final fracIdx = canvasOffsetPx / pixelsPerHour;
      final idx = fracIdx.floor().clamp(0, hours.length - 2);
      final t = fracIdx - idx;
      final tempY = tempPoints[idx].dy * (1 - t) +
          tempPoints[(idx + 1).clamp(0, tempPoints.length - 1)].dy * t;
      final dewY = dewPoints[idx].dy * (1 - t) +
          dewPoints[(idx + 1).clamp(0, dewPoints.length - 1)].dy * t;

      // Convert data-space Y back to screen-space (account for translate)
      // Since Y is not translated, the values are already in screen space
      canvas.drawCircle(
        Offset(anchorScreenX, tempY),
        4,
        Paint()..color = Colors.white.withValues(alpha: 0.9),
      );
      canvas.drawCircle(
        Offset(anchorScreenX, dewY),
        4,
        Paint()..color = AtmosphereColors.blueGrey.withValues(alpha: 0.9),
      );
    }
  }

  void _drawLine(Canvas canvas, List<Offset> points, Color color) {
    if (points.isEmpty) return;
    final path = Path();
    path.moveTo(points[0].dx, points[0].dy);
    for (var i = 1; i < points.length; i++) {
      final prev = points[i - 1];
      final curr = points[i];
      final cpx = (prev.dx + curr.dx) / 2;
      path.cubicTo(cpx, prev.dy, cpx, curr.dy, curr.dx, curr.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round,
    );
  }

  void _paintLabel(
      Canvas canvas, String text, Offset offset, TextStyle style) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(_DewPointPainter old) {
    return old.canvasOffsetPx != canvasOffsetPx || old.isPanning != isPanning;
  }
}
