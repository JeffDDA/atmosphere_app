enum LocationSourceType { manual, gps, bortle }

class ObservatoryLocation {
  final String name;
  final double latitude;
  final double longitude;
  final LocationSourceType sourceType;

  const ObservatoryLocation({
    required this.name,
    required this.latitude,
    required this.longitude,
    this.sourceType = LocationSourceType.manual,
  });
}
