import 'dart:math';
import 'dart:ui';

/// Polar stereographic projection for CMC forecast map images.
///
/// Each projection maps geographic coordinates (lat/lon) to pixel positions
/// on a 720×600 PNG image from weather.gc.ca.
class CmcProjection {
  final double centerLat;
  final double centerLon;
  final double offsetX;
  final double offsetY;
  final double scale;

  const CmcProjection({
    required this.centerLat,
    required this.centerLon,
    required this.offsetX,
    required this.offsetY,
    required this.scale,
  });

  static const double _projectionScale = 11893578.0;
  static const double _earthRadius = 6371000.0;

  /// Convert geographic coordinates to pixel position on the map image.
  /// Returns null if the point falls outside the image bounds.
  Offset? getXY(double lat, double lon) {
    final phi = lat * pi / 180.0;
    final lam = lon * pi / 180.0;
    final phi0 = centerLat * pi / 180.0;
    final lam0 = centerLon * pi / 180.0;

    // Polar stereographic forward projection (north pole tangent plane)
    final k =
        2.0 * _earthRadius / (1.0 + sin(phi0) * sin(phi) + cos(phi0) * cos(phi) * cos(lam - lam0));
    final x = k * cos(phi) * sin(lam - lam0);
    final y = k * (cos(phi0) * sin(phi) - sin(phi0) * cos(phi) * cos(lam - lam0));

    // Scale to pixel coordinates
    final px = (x / _projectionScale) * scale + offsetX;
    final py = (-y / _projectionScale) * scale + offsetY;

    return Offset(px, py);
  }

  /// Check if a pixel coordinate is within the 719×600 image bounds.
  static bool inBounds(Offset? point) {
    if (point == null) return false;
    return point.dx >= 0 && point.dx < 719 && point.dy >= 0 && point.dy < 600;
  }
}

/// CMC map type for Layer 3 detail views.
enum CmcMapType {
  cloud,
  seeing,
  transparency,
  wind,
  humidity,
  temperature,
}

/// Named projections for each CMC map type.
/// Constants calibrated to match weather.gc.ca image output.
class CmcProjections {
  CmcProjections._();

  // Cloud cover quadrant maps (720×600 each)
  static const cloudNW = CmcProjection(
    centerLat: 90.0,
    centerLon: -110.0,
    offsetX: 530.0,
    offsetY: 780.0,
    scale: 4200.0,
  );

  static const cloudNE = CmcProjection(
    centerLat: 90.0,
    centerLon: -80.0,
    offsetX: 190.0,
    offsetY: 780.0,
    scale: 4200.0,
  );

  static const cloudSW = CmcProjection(
    centerLat: 90.0,
    centerLon: -110.0,
    offsetX: 530.0,
    offsetY: 380.0,
    scale: 4200.0,
  );

  static const cloudSE = CmcProjection(
    centerLat: 90.0,
    centerLon: -80.0,
    offsetX: 190.0,
    offsetY: 380.0,
    scale: 4200.0,
  );

  // Seeing continent map
  static const seeing = CmcProjection(
    centerLat: 90.0,
    centerLon: -95.0,
    offsetX: 360.0,
    offsetY: 570.0,
    scale: 3400.0,
  );

  // Transparency continent map
  static const transparency = CmcProjection(
    centerLat: 90.0,
    centerLon: -95.0,
    offsetX: 360.0,
    offsetY: 570.0,
    scale: 3400.0,
  );

  // Additional continent maps (wind, humidity) — same projection
  static const wind = CmcProjection(
    centerLat: 90.0,
    centerLon: -95.0,
    offsetX: 360.0,
    offsetY: 570.0,
    scale: 3400.0,
  );

  static const humidity = CmcProjection(
    centerLat: 90.0,
    centerLon: -95.0,
    offsetX: 360.0,
    offsetY: 570.0,
    scale: 3400.0,
  );

  /// Determine the correct cloud quadrant for a given location.
  /// Returns the quadrant name ('NW', 'NE', 'SW', 'SE') or null if
  /// the location doesn't fall in any quadrant's bounds.
  static String? determineCloudQuadrant(double lat, double lon) {
    // Try each quadrant — order: NW, NE, SW, SE
    // Western quadrants first (lon < ~-95), then eastern
    final candidates = <String, CmcProjection>{
      'NW': cloudNW,
      'NE': cloudNE,
      'SW': cloudSW,
      'SE': cloudSE,
    };

    for (final entry in candidates.entries) {
      final point = entry.value.getXY(lat, lon);
      if (CmcProjection.inBounds(point)) {
        return entry.key;
      }
    }
    return null;
  }

  /// Get the projection for a cloud quadrant by name.
  static CmcProjection cloudProjectionForQuadrant(String quadrant) {
    switch (quadrant) {
      case 'NW':
        return cloudNW;
      case 'NE':
        return cloudNE;
      case 'SW':
        return cloudSW;
      case 'SE':
        return cloudSE;
      default:
        return cloudNE; // fallback
    }
  }

  /// Get the projection for a given map type and optional quadrant.
  static CmcProjection projectionFor(CmcMapType type, {String? quadrant}) {
    switch (type) {
      case CmcMapType.cloud:
        return cloudProjectionForQuadrant(quadrant ?? 'NE');
      case CmcMapType.seeing:
        return seeing;
      case CmcMapType.transparency:
        return transparency;
      case CmcMapType.wind:
        return wind;
      case CmcMapType.humidity:
        return humidity;
      case CmcMapType.temperature:
        return transparency; // same continent projection
    }
  }
}
