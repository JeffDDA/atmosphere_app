import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/mock_locations.dart';
import '../models/location.dart';

const _storageKey = 'saved_locations';

class LocationNotifier extends AsyncNotifier<List<ObservatoryLocation>> {
  @override
  Future<List<ObservatoryLocation>> build() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = prefs.getStringList(_storageKey);
    if (jsonList == null || jsonList.isEmpty) {
      // First install — seed with mock locations and persist them
      await _persist(prefs, mockLocations);
      return mockLocations;
    }
    return jsonList
        .map((s) => ObservatoryLocation.fromJson(
              jsonDecode(s) as Map<String, dynamic>,
            ))
        .toList();
  }

  Future<void> _persist(
    SharedPreferences prefs,
    List<ObservatoryLocation> locations,
  ) async {
    final jsonList = locations.map((l) => jsonEncode(l.toJson())).toList();
    await prefs.setStringList(_storageKey, jsonList);
  }

  Future<void> _save(List<ObservatoryLocation> locations) async {
    final prefs = await SharedPreferences.getInstance();
    await _persist(prefs, locations);
    state = AsyncData(locations);
  }

  Future<void> addLocation(ObservatoryLocation location) async {
    final current = state.valueOrNull ?? [];
    await _save([...current, location]);
  }

  Future<void> updateLocation(int index, ObservatoryLocation location) async {
    final current = List<ObservatoryLocation>.from(state.valueOrNull ?? []);
    if (index < 0 || index >= current.length) return;
    current[index] = location;
    await _save(current);
  }

  Future<void> deleteLocation(int index) async {
    final current = List<ObservatoryLocation>.from(state.valueOrNull ?? []);
    if (index < 0 || index >= current.length) return;
    current.removeAt(index);
    await _save(current);
  }
}

final locationProvider =
    AsyncNotifierProvider<LocationNotifier, List<ObservatoryLocation>>(
  LocationNotifier.new,
);

class ActiveLocationIndexNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void select(int index) {
    state = index;
  }

  /// Clamp index to valid range after a location deletion.
  void clampTo(int maxIndex) {
    if (state > maxIndex) {
      state = maxIndex.clamp(0, maxIndex);
    }
  }
}

final activeLocationIndexProvider =
    NotifierProvider<ActiveLocationIndexNotifier, int>(
  ActiveLocationIndexNotifier.new,
);

final activeLocationProvider = Provider<ObservatoryLocation?>((ref) {
  final locationsAsync = ref.watch(locationProvider);
  final index = ref.watch(activeLocationIndexProvider);
  return locationsAsync.whenOrNull(
    data: (locations) {
      if (index < 0 || index >= locations.length) return null;
      return locations[index];
    },
  );
});
