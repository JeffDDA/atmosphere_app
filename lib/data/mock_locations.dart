import '../models/location.dart';

final mockLocations = [
  const ObservatoryLocation(
    name: 'Pietown, NM',
    latitude: 32.90,
    longitude: -108.88,
    elevationM: 2100, // ~6890 ft, high desert
    sourceType: LocationSourceType.manual,
    bortleClass: 1,
    sqmValue: 21.8,
  ),
  const ObservatoryLocation(
    name: 'Charlotte, NC',
    latitude: 35.22,
    longitude: -80.84,
    elevationM: 230, // ~750 ft, piedmont
    sourceType: LocationSourceType.manual,
    bortleClass: 7,
    sqmValue: 19.5,
  ),
];
