import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../core/theme/atmosphere_colors.dart';
import '../../models/location.dart';

const crimsonMarker = Color(0xFF8B0000);
const cylHalfHeight = 1.22; // must match CYL_H in shader
const latTop = 75.0; // must match LAT_TOP in shader
const latBot = -65.0; // must match LAT_BOT in shader

/// Shared CustomPainter for the VIIRS LP cylinder — used by both
/// the Layer 1 globe widget and the full-screen LP map.
class LPCylinderPainter extends CustomPainter {
  LPCylinderPainter({
    required this.shader,
    required this.atlas,
    required this.yaw,
    required this.zoom,
    required this.panY,
    required this.locations,
    this.activeLocation,
  });

  final ui.FragmentShader shader;
  final ui.Image atlas;
  final double yaw;
  final double zoom;
  final double panY;
  final List<ObservatoryLocation> locations;
  final ObservatoryLocation? activeLocation;

  @override
  void paint(Canvas canvas, Size size) {
    // uResolution (vec2)
    shader.setFloat(0, size.width);
    shader.setFloat(1, size.height);
    // uYaw (float)
    shader.setFloat(2, yaw);
    // uZoom (float)
    shader.setFloat(3, zoom);
    // uPanY (float)
    shader.setFloat(4, panY);
    // uAtlas (sampler2D)
    shader.setImageSampler(0, atlas);

    final paint = Paint()..shader = shader;
    canvas.drawRect(Offset.zero & size, paint);

    _drawSiteMarkers(canvas, size);
  }

  void _drawSiteMarkers(Canvas canvas, Size size) {
    final fovRad = AtmosphereConstants.globeFov * math.pi / 180.0;
    final focalLen = 1.0 / math.tan(fovRad * 0.5);
    final minDim = math.min(size.width, size.height);

    for (final loc in locations) {
      final lngRad = loc.longitude * math.pi / 180.0;
      final angle = lngRad + yaw;

      final cx = math.sin(angle);
      final cz = math.cos(angle);
      final latClamped = loc.latitude.clamp(latBot, latTop);
      final cy = ((latClamped - latBot) / (latTop - latBot) * 2.0 - 1.0) *
          cylHalfHeight;

      if (cz < 0.05) continue;

      final pz = cz + zoom;
      if (pz < 0.01) continue;
      final px = (cx * focalLen / pz) * minDim + size.width * 0.5;
      final py = (-(cy - panY) * focalLen / pz) * minDim + size.height * 0.5;

      if (px < -10 ||
          px > size.width + 10 ||
          py < -10 ||
          py > size.height + 10) {
        continue;
      }

      final isActive = activeLocation != null &&
          loc.latitude == activeLocation!.latitude &&
          loc.longitude == activeLocation!.longitude;

      final center = Offset(px, py);

      if (isActive) {
        canvas.drawCircle(center, 6, Paint()..color = crimsonMarker);
        canvas.drawCircle(
          center,
          10,
          Paint()
            ..color = crimsonMarker.withValues(alpha: 0.8)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
      } else {
        final bortleIdx = (loc.bortleClass - 1)
            .clamp(0, AtmosphereColors.bortleColors.length - 1);
        canvas.drawCircle(
            center, 3, Paint()..color = AtmosphereColors.bortleColors[bortleIdx]);
        if (loc.bortleClass <= 2) {
          canvas.drawCircle(
            center,
            3.5,
            Paint()
              ..color = const Color(0x33FFFFFF)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 0.5,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(LPCylinderPainter old) =>
      old.yaw != yaw ||
      old.zoom != zoom ||
      old.panY != panY ||
      old.activeLocation != activeLocation;
}
