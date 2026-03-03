enum LocationSourceType { manual, gps, bortle }

class ObservatoryLocation {
  final String name;
  final double latitude;
  final double longitude;
  final double elevationM; // ASL in meters
  final LocationSourceType sourceType;
  final int bortleClass; // 1–9
  final double sqmValue; // mag/arcsec²

  const ObservatoryLocation({
    required this.name,
    required this.latitude,
    required this.longitude,
    this.elevationM = 0,
    this.sourceType = LocationSourceType.manual,
    this.bortleClass = 4,
    this.sqmValue = 20.5,
  });

  /// Naked-eye limiting magnitude ceiling imposed by light pollution.
  /// Lookup table converting SQM to NELM.
  double get lpLimitingMagnitude {
    if (sqmValue >= 21.8) return 7.6;
    if (sqmValue >= 21.5) return 7.3;
    if (sqmValue >= 21.3) return 7.0;
    if (sqmValue >= 21.0) return 6.7;
    if (sqmValue >= 20.5) return 6.3;
    if (sqmValue >= 20.0) return 5.8;
    if (sqmValue >= 19.5) return 5.2;
    if (sqmValue >= 19.0) return 4.6;
    if (sqmValue >= 18.5) return 4.0;
    return 3.5;
  }
}
