import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Which variant of Layer 2 to show.
/// `null` → normal card stack, `'lp_map'` → full-screen LP map.
final layer2ModeProvider = StateProvider<String?>((ref) => null);

/// Shared camera state between the Layer 1 LP globe and the full-screen LP map.
class LPGlobeViewState {
  final double yaw;
  final double zoom;
  final double panY;

  const LPGlobeViewState({
    this.yaw = 0,
    this.zoom = 4.5,
    this.panY = 0,
  });

  LPGlobeViewState copyWith({double? yaw, double? zoom, double? panY}) {
    return LPGlobeViewState(
      yaw: yaw ?? this.yaw,
      zoom: zoom ?? this.zoom,
      panY: panY ?? this.panY,
    );
  }
}

class LPGlobeViewNotifier extends Notifier<LPGlobeViewState> {
  @override
  LPGlobeViewState build() => const LPGlobeViewState();

  void sync({required double yaw, required double zoom, required double panY}) {
    state = LPGlobeViewState(yaw: yaw, zoom: zoom, panY: panY);
  }
}

final lpGlobeViewStateProvider =
    NotifierProvider<LPGlobeViewNotifier, LPGlobeViewState>(
  LPGlobeViewNotifier.new,
);

/// One-shot signal: when set to a non-null span value, ClaritasShell should
/// consume it as the initial span for a seamless pinch handoff from the globe.
final lpGlobePinchHandoffProvider = StateProvider<double?>((ref) => null);

/// LPMapView sets this to true to request ClaritasShell trigger an ascend.
final lpMapAscendRequestProvider = StateProvider<bool>((ref) => false);

/// Which LP atlas to show: 'viirs' (default) or 'lorenz'.
final lpMapAtlasProvider = StateProvider<String>((ref) => 'viirs');
