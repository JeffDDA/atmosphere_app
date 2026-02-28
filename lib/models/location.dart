enum LocationSourceType { manual, gps, bortle }

class ObservatoryLocation {
  final String name;
  final double latitude;
  final double longitude;
  final double elevationM; // ASL in meters
  final LocationSourceType sourceType;

  const ObservatoryLocation({
    required this.name,
    required this.latitude,
    required this.longitude,
    this.elevationM = 0,
    this.sourceType = LocationSourceType.manual,
  });
}
