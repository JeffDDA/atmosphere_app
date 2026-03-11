import 'package:flutter/physics.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart' show ClampingScrollSimulation;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants.dart';
import '../models/forecast.dart';
import 'forecast_provider.dart';

/// Full 24h x 3-day timeline for Classic Mode (72+ hours).
/// Uses live API data (all hours including daytime).
final classicAllHoursProvider = Provider<List<HourlyForecast>>((ref) {
  return ref.watch(liveAllHoursProvider);
});

/// Now marker computed against the classic 24h timeline.
final classicNowMarkerProvider = Provider<ClassicNowMarkerInfo>((ref) {
  final allHours = ref.watch(classicAllHoursProvider);
  if (allHours.isEmpty) {
    return const ClassicNowMarkerInfo(fractionalIndex: 0, isWithinTimeline: false);
  }

  final now = DateTime.now();
  final firstTime = allHours.first.time;
  final lastTime = allHours.last.time;

  if (now.isBefore(firstTime)) {
    return const ClassicNowMarkerInfo(fractionalIndex: 0, isWithinTimeline: false);
  }
  if (now.isAfter(lastTime)) {
    return ClassicNowMarkerInfo(
      fractionalIndex: (allHours.length - 1).toDouble(),
      isWithinTimeline: false,
    );
  }

  // Find bounding hour indices
  for (var i = 0; i < allHours.length - 1; i++) {
    if (!now.isBefore(allHours[i].time) && now.isBefore(allHours[i + 1].time)) {
      final segDur = allHours[i + 1].time.difference(allHours[i].time).inSeconds;
      final elapsed = now.difference(allHours[i].time).inSeconds;
      final t = segDur > 0 ? elapsed / segDur : 0.0;
      return ClassicNowMarkerInfo(
        fractionalIndex: i + t,
        isWithinTimeline: true,
      );
    }
  }

  return ClassicNowMarkerInfo(
    fractionalIndex: (allHours.length - 1).toDouble(),
    isWithinTimeline: true,
  );
});

class ClassicNowMarkerInfo {
  final double fractionalIndex;
  final bool isWithinTimeline;
  const ClassicNowMarkerInfo({
    required this.fractionalIndex,
    required this.isWithinTimeline,
  });
}

class ClassicCanvasState {
  final double offsetPx;
  final bool isPanning;

  const ClassicCanvasState({this.offsetPx = 0.0, this.isPanning = false});

  ClassicCanvasState copyWith({double? offsetPx, bool? isPanning}) {
    return ClassicCanvasState(
      offsetPx: offsetPx ?? this.offsetPx,
      isPanning: isPanning ?? this.isPanning,
    );
  }
}

class ClassicCanvasNotifier extends Notifier<ClassicCanvasState> {
  Ticker? _ticker;
  Simulation? _simulation;
  double _maxOffset = 0;
  bool _hasInitialized = false;

  double get maxOffset => _maxOffset;

  @override
  ClassicCanvasState build() {
    ref.keepAlive();
    ref.onDispose(_stopMomentum);
    return const ClassicCanvasState();
  }

  void updateMaxOffset(double maxOffset) {
    _maxOffset = maxOffset;
    if (!_hasInitialized && _maxOffset > 0) {
      _hasInitialized = true;
      final nowInfo = ref.read(classicNowMarkerProvider);
      final classicHours = ref.read(classicAllHoursProvider);
      if (classicHours.isNotEmpty) {
        final pxPerHour = AtmosphereConstants.classicChickletWidth +
            AtmosphereConstants.classicChickletGap;
        final nowPx = nowInfo.fractionalIndex * pxPerHour;
        jumpTo(nowPx);
      }
    }
    if (state.offsetPx > _maxOffset && _maxOffset > 0) {
      state = state.copyWith(offsetPx: _maxOffset);
    }
  }

  void jumpTo(double px) {
    _stopMomentum();
    final clamped = px.clamp(0.0, _maxOffset);
    state = state.copyWith(offsetPx: clamped);
  }

  void jumpToHourIndex(int hourIndex, double viewportWidth) {
    _stopMomentum();
    final pxPerHour = AtmosphereConstants.classicChickletWidth +
        AtmosphereConstants.classicChickletGap;
    // Center the target hour in viewport
    final targetPx =
        (hourIndex * pxPerHour - viewportWidth / 2 + pxPerHour / 2)
            .clamp(0.0, _maxOffset);
    state = state.copyWith(offsetPx: targetPx);
  }

  void startPan() {
    _stopMomentum();
    state = state.copyWith(isPanning: true);
  }

  void updateOffset(double newOffset) {
    final clamped = newOffset.clamp(0.0, _maxOffset);
    state = state.copyWith(offsetPx: clamped);
  }

  void endPan(double velocityPxPerSec) {
    state = state.copyWith(isPanning: false);
    if (velocityPxPerSec.abs() > 50) {
      _startMomentum(-velocityPxPerSec);
    }
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

final classicCanvasProvider =
    NotifierProvider<ClassicCanvasNotifier, ClassicCanvasState>(
  ClassicCanvasNotifier.new,
);

/// Tooltip state for Classic Mode chicklet taps.
class ClassicTooltipState {
  final int? hourIndex;
  final int? rowIndex;
  final double? globalX;
  final double? globalY;

  const ClassicTooltipState({
    this.hourIndex,
    this.rowIndex,
    this.globalX,
    this.globalY,
  });

  bool get isVisible => hourIndex != null && rowIndex != null;
}

class ClassicTooltipNotifier extends Notifier<ClassicTooltipState> {
  @override
  ClassicTooltipState build() => const ClassicTooltipState();

  void show({
    required int hourIndex,
    required int rowIndex,
    required double globalX,
    required double globalY,
  }) {
    state = ClassicTooltipState(
      hourIndex: hourIndex,
      rowIndex: rowIndex,
      globalX: globalX,
      globalY: globalY,
    );
  }

  void dismiss() {
    state = const ClassicTooltipState();
  }
}

final classicTooltipProvider =
    NotifierProvider<ClassicTooltipNotifier, ClassicTooltipState>(
  ClassicTooltipNotifier.new,
);
