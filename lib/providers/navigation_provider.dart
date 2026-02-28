import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/layer_id.dart';

enum TransitionDirection { descend, ascend }

enum TransitionPhase { idle, zoomOnset, crossover, settle }

class NavigationState {
  final LayerId currentLayer;
  final LayerId? targetLayer;
  final double transitionProgress;
  final TransitionDirection direction;
  final bool isTransitioning;
  final bool isInEyepiece;
  final bool eyepieceMicroPush;

  const NavigationState({
    this.currentLayer = LayerId.home,
    this.targetLayer,
    this.transitionProgress = 0.0,
    this.direction = TransitionDirection.descend,
    this.isTransitioning = false,
    this.isInEyepiece = false,
    this.eyepieceMicroPush = false,
  });

  TransitionPhase get phase {
    if (!isTransitioning) return TransitionPhase.idle;
    if (transitionProgress < 0.25) return TransitionPhase.zoomOnset;
    if (transitionProgress < 0.50) return TransitionPhase.crossover;
    return TransitionPhase.settle;
  }

  NavigationState copyWith({
    LayerId? currentLayer,
    LayerId? targetLayer,
    double? transitionProgress,
    TransitionDirection? direction,
    bool? isTransitioning,
    bool? isInEyepiece,
    bool? eyepieceMicroPush,
    bool clearTarget = false,
  }) {
    return NavigationState(
      currentLayer: currentLayer ?? this.currentLayer,
      targetLayer: clearTarget ? null : (targetLayer ?? this.targetLayer),
      transitionProgress: transitionProgress ?? this.transitionProgress,
      direction: direction ?? this.direction,
      isTransitioning: isTransitioning ?? this.isTransitioning,
      isInEyepiece: isInEyepiece ?? this.isInEyepiece,
      eyepieceMicroPush: eyepieceMicroPush ?? this.eyepieceMicroPush,
    );
  }
}

class NavigationNotifier extends Notifier<NavigationState> {
  @override
  NavigationState build() => const NavigationState();

  static const _layerOrder = [
    LayerId.home,
    LayerId.layer1,
    LayerId.layer2,
    LayerId.layer3,
    LayerId.layer4,
  ];

  LayerId? _nextLayer(LayerId current, TransitionDirection dir) {
    final idx = _layerOrder.indexOf(current);
    if (dir == TransitionDirection.descend && idx < _layerOrder.length - 1) {
      return _layerOrder[idx + 1];
    }
    if (dir == TransitionDirection.ascend && idx > 0) {
      return _layerOrder[idx - 1];
    }
    return null;
  }

  void descendTap() {
    final target = _nextLayer(state.currentLayer, TransitionDirection.descend);
    if (target == null) return;
    state = state.copyWith(
      targetLayer: target,
      direction: TransitionDirection.descend,
      isTransitioning: true,
      transitionProgress: 0.0,
    );
  }

  void ascendDoubleTap() {
    final target = _nextLayer(state.currentLayer, TransitionDirection.ascend);
    if (target == null) return;
    state = state.copyWith(
      targetLayer: target,
      direction: TransitionDirection.ascend,
      isTransitioning: true,
      transitionProgress: 0.0,
    );
  }

  void beginPinch(TransitionDirection direction) {
    final target = _nextLayer(state.currentLayer, direction);
    if (target == null) return;
    state = state.copyWith(
      targetLayer: target,
      direction: direction,
      isTransitioning: true,
      transitionProgress: 0.0,
    );
  }

  void updatePinchProgress(double progress) {
    state = state.copyWith(
      transitionProgress: progress.clamp(0.0, 1.0),
    );
  }

  void commitTransition() {
    if (state.targetLayer == null) return;
    state = NavigationState(
      currentLayer: state.targetLayer!,
      transitionProgress: 0.0,
      isTransitioning: false,
    );
  }

  void springBack() {
    state = state.copyWith(
      isTransitioning: false,
      transitionProgress: 0.0,
      clearTarget: true,
    );
  }

  void enterEyepiece() {
    state = state.copyWith(isInEyepiece: true);
  }

  void microPush(bool active) {
    state = state.copyWith(eyepieceMicroPush: active);
  }

  void releaseEyepiece() {
    state = state.copyWith(
      isInEyepiece: false,
      eyepieceMicroPush: false,
    );
  }

  void goToLayer(LayerId layer) {
    state = NavigationState(currentLayer: layer);
  }
}

final navigationProvider =
    NotifierProvider<NavigationNotifier, NavigationState>(
  NavigationNotifier.new,
);
