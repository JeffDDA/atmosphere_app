import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Shared time scrub state for Layer 2.
/// Position is 0.0 (start of night) to 1.0 (end of night).
class ScrubState {
  final double position;
  final bool isScrubbing;

  const ScrubState({
    this.position = 0.0,
    this.isScrubbing = false,
  });

  /// Index into an hourly forecast list of given length.
  int hourIndex(int hourCount) {
    if (hourCount <= 0) return 0;
    return (position * (hourCount - 1)).round().clamp(0, hourCount - 1);
  }

  /// Fractional index for interpolation.
  double fractionalIndex(int hourCount) {
    if (hourCount <= 1) return 0.0;
    return position * (hourCount - 1);
  }

  ScrubState copyWith({double? position, bool? isScrubbing}) {
    return ScrubState(
      position: position ?? this.position,
      isScrubbing: isScrubbing ?? this.isScrubbing,
    );
  }
}

class ScrubNotifier extends Notifier<ScrubState> {
  @override
  ScrubState build() => const ScrubState();

  void startScrub() {
    state = state.copyWith(isScrubbing: true);
  }

  void updatePosition(double position) {
    state = state.copyWith(position: position.clamp(0.0, 1.0));
  }

  void endScrub() {
    state = state.copyWith(isScrubbing: false);
  }
}

final scrubProvider = NotifierProvider<ScrubNotifier, ScrubState>(
  ScrubNotifier.new,
);
