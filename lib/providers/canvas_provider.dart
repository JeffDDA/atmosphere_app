import 'package:flutter/physics.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart' show ClampingScrollSimulation;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants.dart';
import 'scrub_provider.dart';

class CanvasState {
  final double offsetPx;
  final bool isPanning;

  const CanvasState({this.offsetPx = 0.0, this.isPanning = false});

  CanvasState copyWith({double? offsetPx, bool? isPanning}) {
    return CanvasState(
      offsetPx: offsetPx ?? this.offsetPx,
      isPanning: isPanning ?? this.isPanning,
    );
  }
}

class CanvasNotifier extends Notifier<CanvasState> {
  Ticker? _ticker;
  Simulation? _simulation;
  double _maxOffset = 0;

  @override
  CanvasState build() {
    ref.keepAlive();
    ref.onDispose(_stopMomentum);
    return const CanvasState();
  }

  /// Called by Layer2View when layout or data changes.
  void updateMaxOffset(double maxOffset) {
    _maxOffset = maxOffset;
    if (state.offsetPx > _maxOffset && _maxOffset > 0) {
      state = state.copyWith(offsetPx: _maxOffset);
      _syncScrub();
    }
  }

  void startPan() {
    _stopMomentum();
    state = state.copyWith(isPanning: true);
    ref.read(scrubProvider.notifier).startScrub();
  }

  void updateOffset(double newOffset) {
    final clamped = newOffset.clamp(0.0, _maxOffset);
    state = state.copyWith(offsetPx: clamped);
    _syncScrub();
  }

  void endPan(double velocityPxPerSec) {
    state = state.copyWith(isPanning: false);
    ref.read(scrubProvider.notifier).endScrub();

    if (velocityPxPerSec.abs() > 50) {
      _startMomentum(-velocityPxPerSec);
    }
  }

  void jumpToHour(int hourIndex) {
    _stopMomentum();
    final pph = AtmosphereConstants.canvasPixelsPerHour;
    final targetOffset = (hourIndex * pph).clamp(0.0, _maxOffset);
    state = state.copyWith(offsetPx: targetOffset);
    _syncScrub();
  }

  void _syncScrub() {
    if (_maxOffset <= 0) {
      ref.read(scrubProvider.notifier).updatePosition(0.0);
      return;
    }
    final position = (state.offsetPx / _maxOffset).clamp(0.0, 1.0);
    ref.read(scrubProvider.notifier).updatePosition(position);
  }

  void _startMomentum(double velocity) {
    _stopMomentum();
    _simulation = ClampingScrollSimulation(
      position: state.offsetPx,
      velocity: velocity,
    );
    _ticker = Ticker(_onTick);
    _ticker!.start();
  }

  void _onTick(Duration elapsed) {
    final t = elapsed.inMicroseconds / Duration.microsecondsPerSecond;
    if (_simulation == null || _simulation!.isDone(t)) {
      _stopMomentum();
      return;
    }
    final newOffset = _simulation!.x(t).clamp(0.0, _maxOffset);
    state = state.copyWith(offsetPx: newOffset);
    _syncScrub();

    if (newOffset <= 0 || newOffset >= _maxOffset) {
      _stopMomentum();
    }
  }

  void _stopMomentum() {
    _ticker?.stop();
    _ticker?.dispose();
    _ticker = null;
    _simulation = null;
  }
}

final canvasProvider = NotifierProvider<CanvasNotifier, CanvasState>(
  CanvasNotifier.new,
);
