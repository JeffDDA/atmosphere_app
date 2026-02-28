import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/atmosphere_colors.dart';
import '../../../models/forecast.dart';
import '../../../providers/scrub_provider.dart';
import 'base_card.dart';

class MoonCard extends ConsumerWidget {
  final List<HourlyForecast> hours;
  final List<int> nightBoundaryIndices;

  const MoonCard({
    super.key,
    required this.hours,
    this.nightBoundaryIndices = const [],
  });

  String _verdict() {
    final illumination = hours.first.moonIlluminationPercent;

    if (illumination < 5) return 'New Moon Window';
    if (illumination > 95) return 'Full Moon, ${illumination.round()}% — All Night';

    // Find moonset time
    final moonsetHour = hours.where((h) => h.moonAltitudeDeg > 0).toList();
    if (moonsetHour.isEmpty) {
      return 'Below Horizon — Dark Sky';
    }

    final lastAbove = moonsetHour.last;
    final sh = lastAbove.time.hour % 12 == 0 ? 12 : lastAbove.time.hour % 12;
    final sa = lastAbove.time.hour < 12 ? 'am' : 'pm';

    final phase = illumination < 50 ? 'Crescent' : 'Gibbous';
    final waxWane = illumination < 50 ? 'Waxing' : 'Waning';
    return '$waxWane $phase, ${illumination.round()}% — Sets $sh$sa';
  }

  String _contextLine() {
    final illumination = hours.first.moonIlluminationPercent;
    final aboveHorizon = hours.where((h) => h.moonAltitudeDeg > 0).toList();

    if (illumination < 5) {
      return 'New moon window — darkest skies of the month. Everything in your target queue is viable.';
    }
    if (illumination > 85) {
      return 'Moon at ${illumination.round()}% tonight. Ha and SII are largely unaffected — deep red wavelengths cut through moonlight scatter. OIII at 501nm will show elevated sky background.';
    }
    if (aboveHorizon.isEmpty) {
      return 'Moon below the horizon all night. Clean dark window for all targets.';
    }

    final setsAtIdx = aboveHorizon.last;
    final sh = setsAtIdx.time.hour % 12 == 0 ? 12 : setsAtIdx.time.hour % 12;
    final sa = setsAtIdx.time.hour < 12 ? 'am' : 'pm';
    return 'Moon sets at $sh$sa — good dark window opens after that. Plan your faint targets for the second half of the night.';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scrubState = ref.watch(scrubProvider);

    return BaseCard(
      parameterName: 'Moon',
      verdict: _verdict(),
      body: CustomPaint(
        painter: _MoonSkyPainter(
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

class _MoonSkyPainter extends CustomPainter {
  final List<HourlyForecast> hours;
  final double scrubPosition;
  final List<int> nightBoundaryIndices;

  _MoonSkyPainter({
    required this.hours,
    required this.scrubPosition,
    this.nightBoundaryIndices = const [],
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (hours.isEmpty) return;

    // Interpolate current hour from scrub position
    final fracIdx = scrubPosition * (hours.length - 1);
    final idx = fracIdx.floor().clamp(0, hours.length - 2);
    final t = fracIdx - idx;
    final h0 = hours[idx];
    final h1 = hours[(idx + 1).clamp(0, hours.length - 1)];

    final moonAlt = h0.moonAltitudeDeg * (1 - t) + h1.moonAltitudeDeg * t;
    final moonAz = h0.moonAzimuthDeg * (1 - t) + h1.moonAzimuthDeg * t;
    final illumination = h0.moonIlluminationPercent;

    // Sky background gradient — darker when moon is below or far
    final skyBrightness = moonAlt > 0
        ? (moonAlt / 90.0 * illumination / 100.0 * 0.3).clamp(0.0, 0.3)
        : 0.0;

    final skyGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Color.lerp(AtmosphereColors.deepIndigo, AtmosphereColors.blueGrey, skyBrightness)!,
        Color.lerp(const Color(0xFF050510), AtmosphereColors.darkGrey, skyBrightness * 0.5)!,
      ],
    );
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..shader = skyGradient.createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );

    // Horizon line
    final horizonY = size.height * 0.82;
    canvas.drawLine(
      Offset(0, horizonY),
      Offset(size.width, horizonY),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.15)
        ..strokeWidth = 1,
    );

    // Moon arc path (pre-computed positions for all hours)
    final arcPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final arcPath = Path();
    bool started = false;
    for (var i = 0; i < hours.length; i++) {
      final pos = _moonPosition(hours[i], size, horizonY);
      if (!started) {
        arcPath.moveTo(pos.dx, pos.dy);
        started = true;
      } else {
        arcPath.lineTo(pos.dx, pos.dy);
      }
    }
    canvas.drawPath(arcPath, arcPaint);

    // Moon at current scrub position
    final moonX = (moonAz / 360.0) * size.width;
    final moonY = moonAlt > 0
        ? horizonY - (moonAlt / 90.0) * (horizonY - 20)
        : horizonY + (-moonAlt / 30.0) * (size.height - horizonY - 10);

    if (moonAlt > -5) {
      // Moon glow
      if (moonAlt > 0) {
        canvas.drawCircle(
          Offset(moonX, moonY),
          30,
          Paint()
            ..color = Colors.white.withValues(alpha: illumination / 100.0 * 0.15)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20),
        );
      }

      // Moon disc
      final moonRadius = 12.0;
      canvas.drawCircle(
        Offset(moonX, moonY),
        moonRadius,
        Paint()
          ..color = Colors.white.withValues(
            alpha: moonAlt > 0 ? 0.9 : 0.2,
          ),
      );

      // Phase shadow (crescent rendering)
      if (illumination < 95) {
        final shadowOffset = (1.0 - illumination / 100.0) * moonRadius * 2;
        canvas.drawCircle(
          Offset(moonX - moonRadius + shadowOffset, moonY),
          moonRadius * 0.95,
          Paint()
            ..color = moonAlt > 0
                ? const Color(0xFF1A1A2E).withValues(alpha: 0.8)
                : const Color(0xFF1A1A2E).withValues(alpha: 0.9),
        );
      }
    }

    // Subtle glow on horizon if moon is near horizon
    if (moonAlt.abs() < 10) {
      canvas.drawRect(
        Rect.fromLTWH(
          moonX - 60, horizonY - 5,
          120, 10,
        ),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.05)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15),
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
  }

  Offset _moonPosition(HourlyForecast h, Size size, double horizonY) {
    final x = (h.moonAzimuthDeg / 360.0) * size.width;
    final y = h.moonAltitudeDeg > 0
        ? horizonY - (h.moonAltitudeDeg / 90.0) * (horizonY - 20)
        : horizonY + 10;
    return Offset(x, y);
  }

  @override
  bool shouldRepaint(_MoonSkyPainter old) {
    return old.scrubPosition != scrubPosition;
  }
}
