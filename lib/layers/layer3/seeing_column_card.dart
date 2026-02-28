import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/forecast.dart';
import '../../providers/scrub_provider.dart';

// Shared altitude constants — instrument panel and column painter must agree.
const _maxAltM = 13000.0;
const _topPad = 16.0;
const _bottomPad = 28.0;
const _jsAltM = 10000.0;
const _jsBandHalfM = 500.0;

class SeeingColumnCard extends ConsumerWidget {
  final List<HourlyForecast> hours;
  final double observatoryElevationM;
  final List<int> nightBoundaryIndices;

  const SeeingColumnCard({
    super.key,
    required this.hours,
    required this.observatoryElevationM,
    this.nightBoundaryIndices = const [],
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (hours.isEmpty) {
      return const Center(child: Text('No hourly data'));
    }

    final scrubState = ref.watch(scrubProvider);
    final theme = Theme.of(context);

    // Interpolate values at current scrub position
    final fracIdx = scrubState.fractionalIndex(hours.length);
    final idx = hours.length <= 1
        ? 0
        : fracIdx.floor().clamp(0, hours.length - 2);
    final t = fracIdx - idx;
    final h0 = hours[idx];
    final h1 = hours[(idx + 1).clamp(0, hours.length - 1)];

    final currentGLT = h0.gltHeatFlux * (1 - t) + h1.gltHeatFlux * t;
    final currentBLT = h0.bltCeilingM * (1 - t) + h1.bltCeilingM * t;
    final currentJS = h0.jsWindSpeedKt * (1 - t) + h1.jsWindSpeedKt * t;

    return Container(
      color: const Color(0xFF0A0A1A),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
            child: Row(
              children: [
                Text(
                  'Seeing',
                  style:
                      theme.textTheme.headlineMedium?.copyWith(fontSize: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _verdict(),
                    style: theme.textTheme.bodyMedium,
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ),

          // Main content: left instruments + right atmospheric column
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Left panel — fixed instruments
                SizedBox(
                  width: 76,
                  child: _InstrumentPanel(
                    gltValue: currentGLT,
                    bltValue: currentBLT,
                    jsValue: currentJS,
                    observatoryElevationM: observatoryElevationM,
                  ),
                ),

                // Divider
                Container(
                  width: 1,
                  color: Colors.white.withValues(alpha: 0.08),
                ),

                // Right panel — atmospheric column
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final width = constraints.maxWidth;
                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onHorizontalDragStart: (d) {
                          ref.read(scrubProvider.notifier).startScrub();
                          ref
                              .read(scrubProvider.notifier)
                              .updatePosition(
                                (d.localPosition.dx / width).clamp(0.0, 1.0),
                              );
                        },
                        onHorizontalDragUpdate: (d) {
                          ref
                              .read(scrubProvider.notifier)
                              .updatePosition(
                                (d.localPosition.dx / width).clamp(0.0, 1.0),
                              );
                        },
                        onHorizontalDragEnd: (_) {
                          ref.read(scrubProvider.notifier).endScrub();
                        },
                        child: CustomPaint(
                          painter: _AtmosphericColumnPainter(
                            hours: hours,
                            scrubPosition: scrubState.position,
                            observatoryElevationM: observatoryElevationM,
                            nightBoundaryIndices: nightBoundaryIndices,
                          ),
                          size: Size.infinite,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // Context line
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Text(
              _contextLine(),
              style: theme.textTheme.bodyMedium?.copyWith(fontSize: 13),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  String _verdict() {
    final avg =
        hours.map((h) => h.seeing).reduce((a, b) => a + b) / hours.length;
    if (avg >= 4.5) return 'Exceptional';
    if (avg >= 3.5) return 'Excellent';
    if (avg >= 2.5) return 'Average';
    return 'Poor';
  }

  String _contextLine() {
    final avgGLT =
        hours.map((h) => h.gltHeatFlux).reduce((a, b) => a + b) /
            hours.length;
    final avgBLT =
        hours.map((h) => h.bltCeilingM).reduce((a, b) => a + b) /
            hours.length;
    final avgJS =
        hours.map((h) => h.jsWindSpeedKt).reduce((a, b) => a + b) /
            hours.length;

    if (avgGLT < 0 && avgBLT < 400 && avgJS < 30) {
      return 'All three layers are quiet. Ground has cooled, boundary layer collapsed, jet stream weak. Textbook excellent seeing.';
    }
    if (avgGLT > 50) {
      return 'Ground layer turbulence is dominant tonight. Surface hasn\'t finished cooling. Seeing improves as GLT heat flux goes negative.';
    }
    if (avgJS > 50) {
      return 'Strong jet stream overhead is the main seeing limiter. 250mb winds are introducing high-altitude turbulence.';
    }
    if (avgBLT > 800) {
      return 'Boundary layer still deep, mixing turbulence to ${avgBLT.round()}m. As it collapses through the night, seeing should improve.';
    }
    return 'Three atmospheric layers affect seeing: ground heat flux, boundary layer ceiling, and jet stream winds at the tropopause.';
  }
}

// ---------------------------------------------------------------------------
// Left panel: three fixed instruments at their physical altitude positions
// ---------------------------------------------------------------------------

class _InstrumentPanel extends StatelessWidget {
  final double gltValue;
  final double bltValue;
  final double jsValue;
  final double observatoryElevationM;

  // BLT instrument fixed at 1500m AGL (representative boundary layer zone)
  static const _bltInstrumentAglM = 1500.0;

  const _InstrumentPanel({
    required this.gltValue,
    required this.bltValue,
    required this.jsValue,
    required this.observatoryElevationM,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalH = constraints.maxHeight;
        final chartH = totalH - _topPad - _bottomPad;

        double altToY(double altM) {
          return _topPad + chartH * (1.0 - (altM / _maxAltM).clamp(0.0, 1.0));
        }

        // Clamp positions to keep instruments within visible bounds
        const instrumentH = 36.0;
        final minY = _topPad;
        final maxY = totalH - _bottomPad - instrumentH;

        final jsY =
            altToY(_jsAltM).clamp(minY, maxY);
        final bltY = altToY(
          observatoryElevationM + _bltInstrumentAglM,
        ).clamp(minY, maxY);
        final gltY =
            altToY(observatoryElevationM).clamp(minY, maxY);

        // Prevent overlap: push BLT up if too close to GLT
        final adjustedBltY =
            bltY > gltY - instrumentH - 4 ? gltY - instrumentH - 4 : bltY;
        final adjustedJsY =
            jsY > adjustedBltY - instrumentH - 4
                ? adjustedBltY - instrumentH - 4
                : jsY;

        return Stack(
          children: [
            // Connection lines from instrument to its altitude
            CustomPaint(
              painter: _InstrumentLinePainter(
                jsY: adjustedJsY + instrumentH / 2,
                bltY: adjustedBltY + instrumentH / 2,
                gltY: gltY + instrumentH / 2,
                jsTargetY: altToY(_jsAltM),
                bltTargetY: altToY(
                  observatoryElevationM + _bltInstrumentAglM,
                ),
                gltTargetY: altToY(observatoryElevationM),
              ),
              size: Size.infinite,
            ),
            Positioned(
              top: adjustedJsY,
              left: 4,
              right: 8,
              child: _InstrumentReadout(
                label: 'JS',
                value: '${jsValue.round()} kt',
                color: _jsColor(jsValue),
              ),
            ),
            Positioned(
              top: adjustedBltY,
              left: 4,
              right: 8,
              child: _InstrumentReadout(
                label: 'BLT',
                value: '${bltValue.round()} m',
                color: _bltColor(bltValue),
              ),
            ),
            Positioned(
              top: gltY,
              left: 4,
              right: 8,
              child: _InstrumentReadout(
                label: 'GLT',
                value: '${gltValue.round()} W/m²',
                color: _gltColor(gltValue),
              ),
            ),
          ],
        );
      },
    );
  }

  static Color _jsColor(double speedKt) {
    if (speedKt > 50) return const Color(0xFFB84A2F);
    if (speedKt > 30) return const Color(0xFFC4883A);
    return const Color(0xFF5A9B7A);
  }

  static Color _bltColor(double ceilingM) {
    if (ceilingM > 1000) return const Color(0xFFB84A2F);
    if (ceilingM > 500) return const Color(0xFFC4883A);
    return const Color(0xFF5A9B7A);
  }

  static Color _gltColor(double heatFlux) {
    if (heatFlux > 50) return const Color(0xFFC4883A);
    if (heatFlux > 0) return const Color(0xFF7A8A9A);
    return const Color(0xFF5A9B7A);
  }
}

class _InstrumentLinePainter extends CustomPainter {
  final double jsY, bltY, gltY;
  final double jsTargetY, bltTargetY, gltTargetY;

  _InstrumentLinePainter({
    required this.jsY,
    required this.bltY,
    required this.gltY,
    required this.jsTargetY,
    required this.bltTargetY,
    required this.gltTargetY,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..strokeWidth = 0.5;

    // Horizontal tick lines from instrument panel to column edge
    canvas.drawLine(Offset(size.width - 4, jsY), Offset(size.width, jsY), paint);
    canvas.drawLine(
      Offset(size.width - 4, bltY),
      Offset(size.width, bltY),
      paint,
    );
    canvas.drawLine(
      Offset(size.width - 4, gltY),
      Offset(size.width, gltY),
      paint,
    );
  }

  @override
  bool shouldRepaint(_InstrumentLinePainter old) => false;
}

class _InstrumentReadout extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _InstrumentReadout({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          value,
          style: TextStyle(
            color: color.withValues(alpha: 0.85),
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Right panel: atmospheric column — time × altitude with GLT, BLT, JS
// ---------------------------------------------------------------------------

class _AtmosphericColumnPainter extends CustomPainter {
  final List<HourlyForecast> hours;
  final double scrubPosition;
  final double observatoryElevationM;
  final List<int> nightBoundaryIndices;

  _AtmosphericColumnPainter({
    required this.hours,
    required this.scrubPosition,
    required this.observatoryElevationM,
    this.nightBoundaryIndices = const [],
  });

  Rect _chart(Size size) =>
      Rect.fromLTRB(0, _topPad, size.width, size.height - _bottomPad);

  double _altToY(double altM, Rect r) {
    final frac = (altM / _maxAltM).clamp(0.0, 1.0);
    return r.bottom - frac * r.height;
  }

  double _timeToX(int i, Rect r) {
    if (hours.length <= 1) return r.center.dx;
    return r.left + (i / (hours.length - 1)) * r.width;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (hours.isEmpty) return;
    final r = _chart(size);
    final groundY = _altToY(observatoryElevationM, r);

    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, size.height));

    _drawBackground(canvas, size);
    _drawAltitudeGrid(canvas, r);
    _drawNightBoundaries(canvas, r);
    _drawGLT(canvas, r, groundY);
    _drawBLT(canvas, r, groundY);
    _drawJS(canvas, r);
    _drawGroundLine(canvas, r, groundY);
    _drawScrubCursor(canvas, r);
    _drawTimeLabels(canvas, r);

    canvas.restore();
  }

  void _drawBackground(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = const Color(0xFF0A0A1A),
    );
  }

  void _drawAltitudeGrid(Canvas canvas, Rect r) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.04)
      ..strokeWidth = 0.5;

    for (final alt in [1000, 2000, 5000, 10000]) {
      final y = _altToY(alt.toDouble(), r);
      if (y >= r.top && y <= r.bottom) {
        canvas.drawLine(Offset(r.left, y), Offset(r.right, y), paint);
      }
    }

    // Altitude labels on right edge
    final labelStyle = const TextStyle(
      color: Color(0x40FFFFFF),
      fontSize: 9,
    );
    for (final alt in [1, 2, 5, 10]) {
      final y = _altToY(alt * 1000.0, r);
      if (y >= r.top + 8 && y <= r.bottom - 8) {
        final tp = TextPainter(
          text: TextSpan(text: '${alt}km', style: labelStyle),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(r.right - tp.width - 4, y - tp.height - 2));
      }
    }
  }

  void _drawNightBoundaries(Canvas canvas, Rect r) {
    if (nightBoundaryIndices.isEmpty || hours.length <= 1) return;

    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.12)
      ..strokeWidth = 1.0;

    for (final idx in nightBoundaryIndices) {
      final x = _timeToX(idx, r);
      canvas.drawLine(Offset(x, r.top), Offset(x, r.bottom), paint);
    }
  }

  // GLT: heat glow at ground level
  void _drawGLT(Canvas canvas, Rect r, double groundY) {
    final colW = hours.length > 1 ? r.width / (hours.length - 1) : r.width;

    for (int i = 0; i < hours.length; i++) {
      final x = _timeToX(i, r);
      final flux = hours[i].gltHeatFlux;

      // Glow height scales with |flux|
      final glowHeightM = (flux.abs() / 200.0 * 800.0).clamp(50.0, 1500.0);
      final glowTopY = _altToY(observatoryElevationM + glowHeightM, r);

      // Warm amber for positive (convective), cool teal for negative (radiative)
      final Color baseColor;
      final double alpha;
      if (flux > 0) {
        alpha = (flux / 200.0).clamp(0.05, 0.45);
        baseColor = const Color(0xFFC4883A);
      } else {
        alpha = (flux.abs() / 40.0).clamp(0.03, 0.20);
        baseColor = const Color(0xFF4A90B8);
      }

      final rect = Rect.fromLTRB(
        x - colW / 2,
        glowTopY,
        x + colW / 2,
        groundY,
      );

      final gradient = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          baseColor.withValues(alpha: 0),
          baseColor.withValues(alpha: alpha),
        ],
      );

      canvas.drawRect(rect, Paint()..shader = gradient.createShader(rect));
    }
  }

  // BLT: ceiling curve + shaded turbulent zone below
  void _drawBLT(Canvas canvas, Rect r, double groundY) {
    if (hours.length < 2) return;

    final ceilingPath = Path();
    final fillPath = Path();

    final firstX = _timeToX(0, r);
    final firstCeilY =
        _altToY(observatoryElevationM + hours[0].bltCeilingM, r);

    ceilingPath.moveTo(firstX, firstCeilY);
    fillPath.moveTo(firstX, groundY);
    fillPath.lineTo(firstX, firstCeilY);

    for (int i = 1; i < hours.length; i++) {
      final x = _timeToX(i, r);
      final y = _altToY(observatoryElevationM + hours[i].bltCeilingM, r);
      ceilingPath.lineTo(x, y);
      fillPath.lineTo(x, y);
    }

    // Close fill path along ground
    fillPath.lineTo(_timeToX(hours.length - 1, r), groundY);
    fillPath.close();

    // Turbulent zone fill — subtle purple-blue
    canvas.drawPath(
      fillPath,
      Paint()
        ..color = const Color(0xFF6A7BAA).withValues(alpha: 0.12)
        ..style = PaintingStyle.fill,
    );

    // Ceiling line — dashed effect via short segments
    final ceilingPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    canvas.drawPath(ceilingPath, ceilingPaint);

    // "BLT" label near the first point of the ceiling
    final tp = TextPainter(
      text: const TextSpan(
        text: 'BLT ceiling',
        style: TextStyle(color: Color(0x50FFFFFF), fontSize: 9),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(firstX + 4, firstCeilY - tp.height - 3));
  }

  // JS: intensity band near the tropopause
  void _drawJS(Canvas canvas, Rect r) {
    final bandTopY = _altToY(_jsAltM + _jsBandHalfM, r);
    final bandBottomY = _altToY(_jsAltM - _jsBandHalfM, r);
    final colW = hours.length > 1 ? r.width / (hours.length - 1) : r.width;

    for (int i = 0; i < hours.length; i++) {
      final x = _timeToX(i, r);
      final speed = hours[i].jsWindSpeedKt;

      // 15kt = barely visible, 60kt = intense
      final intensity = ((speed - 15.0) / 50.0).clamp(0.0, 1.0);

      final Color bandColor =
          Color.lerp(
            const Color(0x00B84A2F),
            const Color(0xA0B84A2F),
            intensity,
          )!;

      final rect = Rect.fromLTRB(
        x - colW / 2,
        bandTopY,
        x + colW / 2,
        bandBottomY,
      );

      final gradient = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          bandColor.withValues(alpha: 0),
          bandColor,
          bandColor,
          bandColor.withValues(alpha: 0),
        ],
        stops: const [0.0, 0.3, 0.7, 1.0],
      );

      canvas.drawRect(rect, Paint()..shader = gradient.createShader(rect));
    }

    // "Jet Stream" label
    final jsY = _altToY(_jsAltM, r);
    final tp = TextPainter(
      text: const TextSpan(
        text: 'Jet Stream 250mb',
        style: TextStyle(color: Color(0x50FFFFFF), fontSize: 9),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(r.right - tp.width - 4, jsY - tp.height / 2));
  }

  void _drawGroundLine(Canvas canvas, Rect r, double groundY) {
    // Ground fill below the line
    canvas.drawRect(
      Rect.fromLTRB(r.left, groundY, r.right, r.bottom),
      Paint()..color = const Color(0xFF1A1510).withValues(alpha: 0.6),
    );

    // Ground line
    canvas.drawLine(
      Offset(r.left, groundY),
      Offset(r.right, groundY),
      Paint()
        ..color = const Color(0xFFC4A862).withValues(alpha: 0.45)
        ..strokeWidth = 1.5,
    );

    // Label
    final elev = observatoryElevationM.round();
    final tp = TextPainter(
      text: TextSpan(
        text: '${elev}m ASL',
        style: const TextStyle(color: Color(0x60C4A862), fontSize: 9),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(4, groundY + 3));
  }

  void _drawScrubCursor(Canvas canvas, Rect r) {
    final x = r.left + scrubPosition * r.width;

    // Cursor line
    canvas.drawLine(
      Offset(x, r.top),
      Offset(x, r.bottom),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.45)
        ..strokeWidth = 1.0,
    );

    // Dot on BLT ceiling at scrub position
    final fracIdx = scrubPosition * (hours.length - 1);
    final idx = hours.length <= 1
        ? 0
        : fracIdx.floor().clamp(0, hours.length - 2);
    final t = fracIdx - idx;
    final blt0 = hours[idx].bltCeilingM;
    final blt1 = hours[(idx + 1).clamp(0, hours.length - 1)].bltCeilingM;
    final currentBLT = blt0 * (1 - t) + blt1 * t;
    final bltY = _altToY(observatoryElevationM + currentBLT, r);

    canvas.drawCircle(
      Offset(x, bltY),
      3.5,
      Paint()..color = Colors.white.withValues(alpha: 0.7),
    );
  }

  void _drawTimeLabels(Canvas canvas, Rect r) {
    final step = hours.length > 6 ? 2 : 1;

    for (int i = 0; i < hours.length; i += step) {
      final x = _timeToX(i, r);
      final h = hours[i].time.hour;
      final display = h % 12 == 0 ? 12 : h % 12;
      final ampm = h < 12 ? 'a' : 'p';

      final tp = TextPainter(
        text: TextSpan(
          text: '$display$ampm',
          style: const TextStyle(color: Color(0x60FFFFFF), fontSize: 10),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x - tp.width / 2, r.bottom + 6));
    }
  }

  @override
  bool shouldRepaint(_AtmosphericColumnPainter old) {
    return old.scrubPosition != scrubPosition;
  }
}
