import 'package:flutter/physics.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants.dart';

/// Lens distortion state for Classic Mode.
/// Center coordinates are in grid-content space (pixels relative to full grid).
class ClassicLensState {
  final double centerGridX; // grid-content space X
  final double centerGridY; // grid-content space Y
  final double strength; // 0.0 = flat, 1.0 = fully open
  final bool isPinching;
  final int? focalHourIndex;
  final int? focalRowIndex;

  const ClassicLensState({
    this.centerGridX = 0,
    this.centerGridY = 0,
    this.strength = 0,
    this.isPinching = false,
    this.focalHourIndex,
    this.focalRowIndex,
  });

  bool get isActive => strength > 0 || isPinching;
  bool get isFullyOpen => strength >= 1.0;

  ClassicLensState copyWith({
    double? centerGridX,
    double? centerGridY,
    double? strength,
    bool? isPinching,
    int? focalHourIndex,
    int? focalRowIndex,
  }) {
    return ClassicLensState(
      centerGridX: centerGridX ?? this.centerGridX,
      centerGridY: centerGridY ?? this.centerGridY,
      strength: strength ?? this.strength,
      isPinching: isPinching ?? this.isPinching,
      focalHourIndex: focalHourIndex ?? this.focalHourIndex,
      focalRowIndex: focalRowIndex ?? this.focalRowIndex,
    );
  }
}

class ClassicLensNotifier extends Notifier<ClassicLensState> {
  Ticker? _ticker;
  SpringSimulation? _simulation;

  @override
  ClassicLensState build() {
    ref.keepAlive();
    ref.onDispose(_stopAnimation);
    return const ClassicLensState();
  }

  /// Called when a two-finger pinch-out begins on the grid.
  /// [gridX], [gridY] = midpoint in grid-content space.
  void beginPinch(double gridX, double gridY) {
    _stopAnimation();
    state = state.copyWith(
      centerGridX: gridX,
      centerGridY: gridY,
      isPinching: true,
      strength: 0,
    );
  }

  /// Update strength based on absolute pinch spread (points).
  void updatePinchSpread(double spreadPoints) {
    if (!state.isPinching) return;

    final deadZone = AtmosphereConstants.classicLensPinchDeadZone;
    final commitPoints = AtmosphereConstants.classicLensPinchCommit;
    final effective = (spreadPoints - deadZone).clamp(0.0, double.infinity);
    final commitRange = commitPoints - deadZone; // 180pt for 50%
    final fullRange = commitRange * 2.0; // 360pt for 100%

    final newStrength = (effective / fullRange).clamp(0.0, 1.0);
    state = state.copyWith(strength: newStrength);
  }

  /// Called when pinch gesture ends.
  void endPinch() {
    if (!state.isPinching) return;
    state = state.copyWith(isPinching: false);

    if (state.strength >= AtmosphereConstants.classicLensCommitThreshold) {
      // Auto-complete to 1.0
      _animateStrengthTo(1.0);
    } else {
      // Spring back to 0.0
      _animateStrengthTo(0.0);
    }
  }

  /// Move lens center while lens is active (single-finger drag).
  void moveLensCenter(double gridX, double gridY) {
    if (!state.isActive) return;
    state = state.copyWith(centerGridX: gridX, centerGridY: gridY);
  }

  /// Update focal indices based on current lens center position.
  void updateFocalIndices(int hourIndex, int rowIndex) {
    state = state.copyWith(
      focalHourIndex: hourIndex,
      focalRowIndex: rowIndex,
    );
  }

  /// Close the lens (e.g. from pinch-in when lens is open).
  void closeLens() {
    state = state.copyWith(isPinching: false);
    _animateStrengthTo(0.0);
  }

  void _animateStrengthTo(double target) {
    _stopAnimation();

    final spring = SpringDescription.withDampingRatio(
      mass: 1.0,
      stiffness: AtmosphereConstants.classicLensSpringStiffness,
      ratio: AtmosphereConstants.classicLensSpringDampingRatio,
    );
    _simulation = SpringSimulation(spring, state.strength, target, 0.0);

    _ticker = Ticker(_onTick);
    _ticker!.start();
  }

  void _onTick(Duration elapsed) {
    final t = elapsed.inMicroseconds / Duration.microsecondsPerSecond;
    if (_simulation == null || _simulation!.isDone(t)) {
      final target = _simulation?.x(t) ?? 0.0;
      state = state.copyWith(strength: target.clamp(0.0, 1.0));
      _stopAnimation();
      return;
    }
    final newStrength = _simulation!.x(t).clamp(0.0, 1.0);
    state = state.copyWith(strength: newStrength);
  }

  void _stopAnimation() {
    _ticker?.stop();
    _ticker?.dispose();
    _ticker = null;
    _simulation = null;
  }
}

final classicLensProvider =
    NotifierProvider<ClassicLensNotifier, ClassicLensState>(
  ClassicLensNotifier.new,
);
