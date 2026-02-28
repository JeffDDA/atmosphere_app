import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/mock_locations.dart';
import '../models/location.dart';

class LocationNotifier extends Notifier<List<ObservatoryLocation>> {
  @override
  List<ObservatoryLocation> build() => mockLocations;
}

final locationProvider =
    NotifierProvider<LocationNotifier, List<ObservatoryLocation>>(
  LocationNotifier.new,
);

class ActiveLocationIndexNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void select(int index) {
    state = index;
  }
}

final activeLocationIndexProvider =
    NotifierProvider<ActiveLocationIndexNotifier, int>(
  ActiveLocationIndexNotifier.new,
);

final activeLocationProvider = Provider<ObservatoryLocation?>((ref) {
  final locations = ref.watch(locationProvider);
  final index = ref.watch(activeLocationIndexProvider);
  if (index < 0 || index >= locations.length) return null;
  return locations[index];
});
