import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants.dart';
import '../../../core/theme/atmosphere_colors.dart';
import '../../../models/forecast.dart';
import '../../../providers/canvas_provider.dart';
import '../../../providers/now_marker_provider.dart';
import 'base_card.dart';

class DarknessCard extends ConsumerWidget {
  final List<HourlyForecast> hours;
  final List<int> nightBoundaryIndices;
  final double lpLimitingMagnitude;
  final int bortleClass;

  const DarknessCard({
    super.key,
    required this.hours,
    this.nightBoundaryIndices = const [],
    required this.lpLimitingMagnitude,
    required this.bortleClass,
  });

  String _verdict() {
    if (hours.isEmpty) return 'No Data';
    final peak = hours
        .map((h) => h.limitingMagnitude)
        .reduce((a, b) => a > b ? a : b);
    final peakHours =
        hours.where((h) => h.limitingMagnitude >= peak - 0.3).length;

    String tier;
    if (peak >= 7.6) {
      tier = 'Extraordinary';
    } else if (peak >= 7.0) {
      tier = 'Exceptional';
    } else if (peak >= 6.5) {
      tier = 'Excellent';
    } else if (peak >= 6.0) {
      tier = 'Good';
    } else if (peak >= 5.0) {
      tier = 'Moderate';
    } else if (peak >= 4.0) {
      tier = 'Light-Polluted';
    } else {
      tier = 'Bright';
    }

    return '$tier \u2014 Mag ${peak.toStringAsFixed(1)} for $peakHours hours';
  }

  String _contextLine() {
    final bortleDesc = switch (bortleClass) {
      1 => 'Bortle 1 \u2014 pristine dark site',
      2 => 'Bortle 2 \u2014 typical dark site',
      3 => 'Bortle 3 \u2014 rural sky',
      4 => 'Bortle 4 \u2014 rural/suburban transition',
      5 => 'Bortle 5 \u2014 suburban sky',
      6 => 'Bortle 6 \u2014 bright suburban',
      7 => 'Bortle 7 \u2014 suburban/urban transition',
      8 => 'Bortle 8 \u2014 city sky',
      9 => 'Bortle 9 \u2014 inner-city sky',
      _ => 'Light pollution data unavailable',
    };

    // Moon impact summary
    final moonUp = hours.where((h) => h.moonAltitudeDeg > 0).toList();
    String moonNote;
    if (moonUp.isEmpty) {
      moonNote = 'Moon below horizon all night.';
    } else {
      final illum = moonUp.first.moonIlluminationPercent.round();
      final setsIdx = hours.indexWhere(
        (h) => h.moonAltitudeDeg <= 0,
        moonUp.isNotEmpty ? 0 : 0,
      );
      if (setsIdx > 0 && setsIdx < hours.length) {
        final setTime = hours[setsIdx].time;
        final hr = setTime.hour % 12 == 0 ? 12 : setTime.hour % 12;
        final ampm = setTime.hour < 12 ? 'am' : 'pm';
        moonNote = '$illum% moon sets ~$hr$ampm.';
      } else {
        moonNote = '$illum% moon up all night.';
      }
    }

    return '$bortleDesc. $moonNote';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canvasState = ref.watch(canvasProvider);
    final nowMarker = ref.watch(nowMarkerProvider);

    return BaseCard(
      parameterName: 'Darkness',
      verdict: _verdict(),
      body: CustomPaint(
        painter: _DarknessPainter(
          hours: hours,
          lpLimitingMagnitude: lpLimitingMagnitude,
          canvasOffsetPx: canvasState.offsetPx,
          isPanning: canvasState.isPanning,
          pixelsPerHour: AtmosphereConstants.canvasPixelsPerHour,
          nightBoundaryIndices: nightBoundaryIndices,
          nowMarkerColor: nowMarker.glowColor,
          nowCanvasPositionPx: nowMarker.nowCanvasPositionPx,
        ),
        size: Size.infinite,
      ),
      context: _contextLine(),
    );
  }
}

class _DarknessPainter extends CustomPainter {
  final List<HourlyForecast> hours;
  final double lpLimitingMagnitude;
  final double canvasOffsetPx;
  final bool isPanning;
  final double pixelsPerHour;
  final List<int> nightBoundaryIndices;
  final Color nowMarkerColor;
  final double nowCanvasPositionPx;

  static const double _minMag = 0.0;
  static const double _maxMag = 8.5;

  _DarknessPainter({
    required this.hours,
    required this.lpLimitingMagnitude,
    required this.canvasOffsetPx,
    required this.isPanning,
    required this.pixelsPerHour,
    this.nightBoundaryIndices = const [],
    required this.nowMarkerColor,
    required this.nowCanvasPositionPx,
  });

  double get _anchorFraction => AtmosphereConstants.canvasReadingAnchorFraction;

  double _yForMag(double mag, double height) {
    // Higher mag = darker sky = higher on chart (lower Y)
    return height - ((mag - _minMag) / (_maxMag - _minMag)) * height;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (hours.isEmpty) return;

    final anchorScreenX = _anchorFraction * size.width;
    final tx = anchorScreenX - canvasOffsetPx;

    // --- Translated data layer ---
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.translate(tx, 0);

    // Build data points
    final actualPoints = <Offset>[];
    final ceilingPoints = <Offset>[];
    for (var i = 0; i < hours.length; i++) {
      final x = i * pixelsPerHour;
      actualPoints.add(Offset(x, _yForMag(hours[i].limitingMagnitude, size.height)));
      ceilingPoints.add(Offset(x, _yForMag(hours[i].darknessCeiling, size.height)));
    }

    // 1. LP floor band — horizontal amber band
    final lpY = _yForMag(lpLimitingMagnitude, size.height);
    final lpBandHalf = (0.3 / (_maxMag - _minMag)) * size.height; // ±0.15 mag
    canvas.drawRect(
      Rect.fromLTRB(
        -pixelsPerHour,
        lpY - lpBandHalf,
        hours.length * pixelsPerHour + pixelsPerHour,
        lpY + lpBandHalf,
      ),
      Paint()..color = AtmosphereColors.lpFloorAmber.withValues(alpha: 0.15),
    );
    canvas.drawLine(
      Offset(-pixelsPerHour, lpY),
      Offset(hours.length * pixelsPerHour + pixelsPerHour, lpY),
      Paint()
        ..color = AtmosphereColors.lpFloorAmber.withValues(alpha: 0.5)
        ..strokeWidth = 1.0,
    );
    // LP label
    _paintLabel(
      canvas,
      'LP ${lpLimitingMagnitude.toStringAsFixed(1)}',
      Offset(4, lpY - 14),
      TextStyle(
        color: AtmosphereColors.lpFloorAmber.withValues(alpha: 0.7),
        fontSize: 10,
      ),
    );

    // 2. Darkness ceiling line — dashed
    final ceilingPath = _buildCubicPath(ceilingPoints);
    _drawDashedPath(
      canvas,
      ceilingPath,
      Colors.white.withValues(alpha: 0.25),
      1.5,
    );

    // 3. Actual darkness curve — filled area + stroke
    final actualPath = _buildCubicPath(actualPoints);

    // Fill with gradient segments — approximate per-hour color
    final fillPath = Path.from(actualPath);
    fillPath.lineTo(actualPoints.last.dx, size.height);
    fillPath.lineTo(actualPoints.first.dx, size.height);
    fillPath.close();

    // Create gradient shader from darkness colors
    final gradientColors = <Color>[];
    final gradientStops = <double>[];
    for (var i = 0; i < hours.length; i++) {
      final color = AtmosphereColors.forLimitingMagnitude(
        hours[i].limitingMagnitude,
      );
      gradientColors.add(color.withValues(alpha: 0.35));
      gradientStops.add(i / (hours.length - 1));
    }
    final totalWidth = (hours.length - 1) * pixelsPerHour;
    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, 0),
          Offset(totalWidth, 0),
          gradientColors,
          gradientStops,
        ),
    );

    // Stroke the actual curve
    canvas.drawPath(
      actualPath,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.8)
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round,
    );

    // 4. Moon altitude shading — columns when moon is above horizon
    for (var i = 0; i < hours.length; i++) {
      final alt = hours[i].moonAltitudeDeg;
      if (alt > 0) {
        final alpha = (alt / 90.0).clamp(0.0, 1.0) * 0.15;
        final x = i * pixelsPerHour;
        final curveY = actualPoints[i].dy;
        canvas.drawRect(
          Rect.fromLTRB(x, 0, x + pixelsPerHour, curveY),
          Paint()..color = Colors.white.withValues(alpha: alpha),
        );
      }

      // Moonrise/set tick marks where altitude crosses 0
      if (i > 0) {
        final prevAlt = hours[i - 1].moonAltitudeDeg;
        if ((prevAlt > 0 && alt <= 0) || (prevAlt <= 0 && alt > 0)) {
          final crossX = (i - 0.5) * pixelsPerHour;
          final tickPaint = Paint()
            ..color = Colors.white.withValues(alpha: 0.4)
            ..strokeWidth = 1.5;
          canvas.drawLine(
            Offset(crossX, size.height - 8),
            Offset(crossX, size.height),
            tickPaint,
          );
          // Small crescent icon hint
          final label = alt > 0 ? '\u263D\u2191' : '\u263D\u2193';
          _paintLabel(
            canvas,
            label,
            Offset(crossX - 8, size.height - 22),
            TextStyle(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 10,
            ),
          );
        }
      }
    }

    // 5. Night boundaries
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

    // --- Fixed viewport layer (now marker) ---
    final m = _nowFadeMultiplier();
    final lineColor = Color.lerp(nowMarkerColor, Colors.white, 1.0 - m)!;
    final lineAlpha = isPanning
        ? AtmosphereConstants.nowMarkerLineAlphaPanning
        : AtmosphereConstants.nowMarkerLineAlphaIdle;
    final lineWidth = isPanning
        ? AtmosphereConstants.nowMarkerLineWidthPanning
        : AtmosphereConstants.nowMarkerLineWidthIdle;

    // Ambient glow
    if (m > 0) {
      final glowRadius = isPanning
          ? AtmosphereConstants.nowMarkerGlowRadiusPanning
          : AtmosphereConstants.nowMarkerGlowRadiusIdle;
      final glowAlpha = (isPanning
              ? AtmosphereConstants.nowMarkerGlowAlphaPanning
              : AtmosphereConstants.nowMarkerGlowAlphaIdle) *
          m;
      final blurSigma = isPanning
          ? AtmosphereConstants.nowMarkerBlurSigmaPanning
          : AtmosphereConstants.nowMarkerBlurSigmaIdle;

      canvas.drawLine(
        Offset(anchorScreenX, 0),
        Offset(anchorScreenX, size.height),
        Paint()
          ..color = nowMarkerColor.withValues(alpha: glowAlpha)
          ..strokeWidth = glowRadius
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, blurSigma),
      );
    }

    // Vertical indicator line
    canvas.drawLine(
      Offset(anchorScreenX, 0),
      Offset(anchorScreenX, size.height),
      Paint()
        ..color = lineColor.withValues(alpha: lineAlpha)
        ..strokeWidth = lineWidth,
    );

    // 6. Cursor value dot
    if (hours.length > 1) {
      final fracIdx = canvasOffsetPx / pixelsPerHour;
      final idx = fracIdx.floor().clamp(0, hours.length - 2);
      final t = fracIdx - idx;
      final curveY = actualPoints[idx].dy * (1 - t) +
          actualPoints[(idx + 1).clamp(0, actualPoints.length - 1)].dy * t;

      // Interpolate magnitude for color
      final mag = hours[idx].limitingMagnitude * (1 - t) +
          hours[(idx + 1).clamp(0, hours.length - 1)].limitingMagnitude * t;
      final dotColor = AtmosphereColors.forLimitingMagnitude(mag);

      canvas.drawCircle(
        Offset(anchorScreenX, curveY),
        isPanning ? 5 : 3,
        Paint()
          ..color = dotColor.withValues(alpha: isPanning ? 0.95 : 0.6),
      );
      // White ring for contrast
      canvas.drawCircle(
        Offset(anchorScreenX, curveY),
        isPanning ? 5 : 3,
        Paint()
          ..color = Colors.white.withValues(alpha: isPanning ? 0.5 : 0.25)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0,
      );
    }
  }

  Path _buildCubicPath(List<Offset> points) {
    final path = Path();
    if (points.isEmpty) return path;
    path.moveTo(points[0].dx, points[0].dy);
    for (var i = 1; i < points.length; i++) {
      final prev = points[i - 1];
      final curr = points[i];
      final cpx = (prev.dx + curr.dx) / 2;
      path.cubicTo(cpx, prev.dy, cpx, curr.dy, curr.dx, curr.dy);
    }
    return path;
  }

  void _drawDashedPath(
    Canvas canvas,
    Path path,
    Color color,
    double strokeWidth,
  ) {
    const dashLength = 6.0;
    const gapLength = 4.0;
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = (distance + dashLength).clamp(0.0, metric.length);
        final segment = metric.extractPath(distance, end);
        canvas.drawPath(segment, paint);
        distance += dashLength + gapLength;
      }
    }
  }

  void _paintLabel(
    Canvas canvas,
    String text,
    Offset offset,
    TextStyle style,
  ) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, offset);
  }

  double _nowFadeMultiplier() {
    final dist = (canvasOffsetPx - nowCanvasPositionPx).abs();
    if (dist <= AtmosphereConstants.nowMarkerFadeStartPx) return 1.0;
    if (dist >= AtmosphereConstants.nowMarkerFadeEndPx) return 0.0;
    return 1.0 -
        (dist - AtmosphereConstants.nowMarkerFadeStartPx) /
            (AtmosphereConstants.nowMarkerFadeEndPx -
                AtmosphereConstants.nowMarkerFadeStartPx);
  }

  @override
  bool shouldRepaint(_DarknessPainter old) {
    return old.canvasOffsetPx != canvasOffsetPx ||
        old.isPanning != isPanning ||
        old.nowMarkerColor != nowMarkerColor ||
        old.nowCanvasPositionPx != nowCanvasPositionPx;
  }
}
