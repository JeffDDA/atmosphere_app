import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/forecast.dart';
import '../../../providers/scrub_provider.dart';
import 'base_card.dart';

class AuroraCard extends ConsumerWidget {
  final List<HourlyForecast> hours;
  final double siteLatitude;
  final List<int> nightBoundaryIndices;

  const AuroraCard({
    super.key,
    required this.hours,
    required this.siteLatitude,
    this.nightBoundaryIndices = const [],
  });

  /// Contextual trigger: Kp forecast above latitude visibility threshold.
  static bool shouldShow(List<HourlyForecast> hours, double latitude) {
    final threshold = _kpThreshold(latitude);
    return hours.any((h) => h.kpIndex >= threshold);
  }

  static double _kpThreshold(double latitude) {
    final absLat = latitude.abs();
    if (absLat >= 65) return 1;
    if (absLat >= 55) return 3;
    if (absLat >= 45) return 5;
    if (absLat >= 35) return 7;
    return 8;
  }

  String _verdict() {
    final maxKp = hours.map((h) => h.kpIndex).reduce((a, b) => a > b ? a : b);
    if (maxKp >= 7) return 'Major Storm — Kp ${maxKp.round()}+';
    return 'Kp ${maxKp.round()} Forecast — Visible From Your Latitude';
  }

  String _contextLine() {
    final maxKp = hours.map((h) => h.kpIndex).reduce((a, b) => a > b ? a : b);
    if (maxKp >= 7) {
      return 'Kp ${maxKp.round()} and you\'re at a dark site. This is the one.';
    }
    if (maxKp >= 5) {
      return 'Strong aurora activity possible. Your sky might do something better than your imaging plan.';
    }
    return 'Aurora possible from your latitude. Look north after midnight.';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scrubState = ref.watch(scrubProvider);

    return BaseCard(
      parameterName: 'Aurora',
      verdict: _verdict(),
      body: CustomPaint(
        painter: _AuroraSkyPainter(
          hours: hours,
          scrubPosition: scrubState.position,
          nightBoundaryIndices: nightBoundaryIndices,
        ),
        size: Size.infinite,
      ),
      context: _contextLine(),
    );
  }
}

class _AuroraSkyPainter extends CustomPainter {
  final List<HourlyForecast> hours;
  final double scrubPosition;
  final List<int> nightBoundaryIndices;

  _AuroraSkyPainter({
    required this.hours,
    required this.scrubPosition,
    this.nightBoundaryIndices = const [],
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (hours.isEmpty) return;

    // Interpolate Kp at scrub position
    final fracIdx = scrubPosition * (hours.length - 1);
    final idx = fracIdx.floor().clamp(0, hours.length - 2);
    final t = fracIdx - idx;
    final kp = hours[idx].kpIndex * (1 - t) +
        hours[(idx + 1).clamp(0, hours.length - 1)].kpIndex * t;

    // Sky background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = const Color(0xFF050510),
    );

    // Horizon
    final horizonY = size.height * 0.85;
    canvas.drawLine(
      Offset(0, horizonY),
      Offset(size.width, horizonY),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.1)
        ..strokeWidth = 1,
    );

    // Dark ground below horizon
    canvas.drawRect(
      Rect.fromLTWH(0, horizonY, size.width, size.height - horizonY),
      Paint()..color = const Color(0xFF0A0A12),
    );

    if (kp < 1) return;

    // Aurora intensity drives visual height and color
    final intensity = (kp / 9.0).clamp(0.0, 1.0);
    final auroraHeight = horizonY * intensity * 0.8;

    // Green aurora base layer
    final greenGradient = LinearGradient(
      begin: Alignment.bottomCenter,
      end: Alignment.topCenter,
      colors: [
        const Color(0xFF00FF66).withValues(alpha: intensity * 0.5),
        const Color(0xFF00FF66).withValues(alpha: intensity * 0.15),
        Colors.transparent,
      ],
      stops: const [0.0, 0.5, 1.0],
    );
    canvas.drawRect(
      Rect.fromLTWH(0, horizonY - auroraHeight, size.width, auroraHeight),
      Paint()..shader = greenGradient.createShader(
        Rect.fromLTWH(0, horizonY - auroraHeight, size.width, auroraHeight),
      ),
    );

    // Aurora rays/curtains
    final rayCount = (intensity * 12).round().clamp(3, 12);
    final rng = math.Random(42); // Deterministic for smooth scrubbing
    for (var i = 0; i < rayCount; i++) {
      final rayX = (i / rayCount) * size.width + rng.nextDouble() * 30;
      final rayWidth = 8.0 + rng.nextDouble() * 15;
      final rayHeight = auroraHeight * (0.5 + rng.nextDouble() * 0.5);
      final rayAlpha = intensity * (0.15 + rng.nextDouble() * 0.2);

      canvas.drawRect(
        Rect.fromLTWH(rayX, horizonY - rayHeight, rayWidth, rayHeight),
        Paint()
          ..color = const Color(0xFF00FF66).withValues(alpha: rayAlpha)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
      );
    }

    // Red/purple at higher altitudes for strong storms (Kp 7+)
    if (kp >= 7) {
      final redHeight = auroraHeight * 0.4;
      final redGradient = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [
          Colors.transparent,
          const Color(0xFFCC3366).withValues(alpha: intensity * 0.3),
          const Color(0xFF6633CC).withValues(alpha: intensity * 0.15),
          Colors.transparent,
        ],
        stops: const [0.0, 0.3, 0.7, 1.0],
      );
      canvas.drawRect(
        Rect.fromLTWH(0, horizonY - auroraHeight - redHeight, size.width, redHeight),
        Paint()..shader = redGradient.createShader(
          Rect.fromLTWH(0, horizonY - auroraHeight - redHeight, size.width, redHeight),
        ),
      );
    }

    // Night boundary separators
    if (nightBoundaryIndices.isNotEmpty && hours.length > 1) {
      final boundaryPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.12)
        ..strokeWidth = 1.0;
      for (final idx in nightBoundaryIndices) {
        final bx = (idx / (hours.length - 1)) * size.width;
        canvas.drawLine(Offset(bx, 0), Offset(bx, size.height), boundaryPaint);
      }
    }

    // Kp value label
    final tp = TextPainter(
      text: TextSpan(
        text: 'Kp ${kp.toStringAsFixed(1)}',
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.6),
          fontSize: 12,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(size.width - tp.width - 8, 8));
  }

  @override
  bool shouldRepaint(_AuroraSkyPainter old) {
    return old.scrubPosition != scrubPosition;
  }
}
