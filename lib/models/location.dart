enum LocationSourceType { manual, gps, bortle, map }

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

  Map<String, dynamic> toJson() => {
        'name': name,
        'latitude': latitude,
        'longitude': longitude,
        'elevationM': elevationM,
        'sourceType': sourceType.name,
        'bortleClass': bortleClass,
        'sqmValue': sqmValue,
      };

  factory ObservatoryLocation.fromJson(Map<String, dynamic> json) {
    return ObservatoryLocation(
      name: json['name'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      elevationM: (json['elevationM'] as num?)?.toDouble() ?? 0,
      sourceType: LocationSourceType.values.byName(
        json['sourceType'] as String? ?? 'manual',
      ),
      bortleClass: json['bortleClass'] as int? ?? 4,
      sqmValue: (json['sqmValue'] as num?)?.toDouble() ?? 20.5,
    );
  }

  ObservatoryLocation copyWith({
    String? name,
    double? latitude,
    double? longitude,
    double? elevationM,
    LocationSourceType? sourceType,
    int? bortleClass,
    double? sqmValue,
  }) {
    return ObservatoryLocation(
      name: name ?? this.name,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      elevationM: elevationM ?? this.elevationM,
      sourceType: sourceType ?? this.sourceType,
      bortleClass: bortleClass ?? this.bortleClass,
      sqmValue: sqmValue ?? this.sqmValue,
    );
  }
}
