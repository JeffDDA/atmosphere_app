import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../core/theme/atmosphere_colors.dart';
import '../../models/forecast.dart';

class GradientBar extends StatelessWidget {
  final List<HourlyForecast> hours;
  final DateTime? currentTime;

  const GradientBar({
    super.key,
    required this.hours,
    this.currentTime,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AtmosphereConstants.gradientBarHeight,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(
          AtmosphereConstants.gradientBarHeight / 2,
        ),
        child: CustomPaint(
          painter: _GradientBarPainter(
            hours: hours,
            currentTime: currentTime ?? DateTime.now(),
          ),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _GradientBarPainter extends CustomPainter {
  final List<HourlyForecast> hours;
  final DateTime currentTime;

  _GradientBarPainter({
    required this.hours,
    required this.currentTime,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (hours.isEmpty) return;

    // Build gradient stops from hourly conditions
    final colors = hours
        .map((h) => AtmosphereColors.forCondition(h.condition))
        .toList();
    final stops = List.generate(
      hours.length,
      (i) => i / (hours.length - 1).clamp(1, hours.length),
    );

    final gradient = LinearGradient(
      colors: colors,
      stops: stops,
    );

    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final paint = Paint()..shader = gradient.createShader(rect);

    // Draw rounded rect
    final rrect = RRect.fromRectAndRadius(
      rect,
      Radius.circular(size.height / 2),
    );
    canvas.drawRRect(rrect, paint);

    // Current time indicator
    final firstTime = hours.first.time;
    final lastTime = hours.last.time;
    final totalDuration = lastTime.difference(firstTime);
    if (totalDuration.inSeconds > 0) {
      final elapsed = currentTime.difference(firstTime);
      final fraction =
          (elapsed.inSeconds / totalDuration.inSeconds).clamp(0.0, 1.0);
      final x = fraction * size.width;

      final linePaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.6)
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke;

      canvas.drawLine(
        Offset(x, 4),
        Offset(x, size.height - 4),
        linePaint,
      );
    }
  }

  @override
  bool shouldRepaint(_GradientBarPainter oldDelegate) => true;
}
