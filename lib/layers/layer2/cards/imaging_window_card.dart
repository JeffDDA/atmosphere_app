import 'package:flutter/material.dart';

import '../../../core/theme/atmosphere_colors.dart';
import '../../../models/forecast.dart';
import 'base_card.dart';

class ImagingWindowCard extends StatelessWidget {
  final List<HourlyForecast> hours;

  const ImagingWindowCard({super.key, required this.hours});

  String _verdict() {
    final goodHours = hours.where((h) {
      return h.cloudCoverPercent < 30 && h.seeing >= 3 && h.transparency >= 3;
    }).length;
    if (goodHours >= 8) return 'Full night available';
    if (goodHours >= 5) return 'Good window';
    if (goodHours >= 3) return 'Short window';
    if (goodHours >= 1) return 'Brief gap';
    return 'No usable window';
  }

  @override
  Widget build(BuildContext context) {
    return BaseCard(
      parameterName: 'Imaging Window',
      verdict: _verdict(),
      body: CustomPaint(
        painter: _ImagingWindowPainter(hours: hours),
        size: Size.infinite,
      ),
      context:
          'Composite quality assessment combining cloud cover, seeing, and transparency. Green bands are your best imaging windows.',
    );
  }
}

class _ImagingWindowPainter extends CustomPainter {
  final List<HourlyForecast> hours;

  _ImagingWindowPainter({required this.hours});

  @override
  void paint(Canvas canvas, Size size) {
    if (hours.isEmpty) return;

    final segmentWidth = size.width / hours.length;

    for (var i = 0; i < hours.length; i++) {
      final h = hours[i];
      // Composite quality: 0.0 (poor) to 1.0 (excellent)
      final cloudScore = (100 - h.cloudCoverPercent) / 100.0;
      final seeingScore = h.seeing / 5.0;
      final transparencyScore = h.transparency / 5.0;
      final quality = (cloudScore * 0.4 + seeingScore * 0.3 + transparencyScore * 0.3)
          .clamp(0.0, 1.0);

      final color = Color.lerp(
        AtmosphereColors.darkGrey,
        AtmosphereColors.deepBlue,
        quality,
      )!;

      final rect = Rect.fromLTWH(
        i * segmentWidth,
        size.height * (1.0 - quality),
        segmentWidth - 1,
        size.height * quality,
      );

      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(4)),
        Paint()..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(_ImagingWindowPainter oldDelegate) => true;
}
