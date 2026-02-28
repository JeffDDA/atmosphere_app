import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';

import '../core/constants.dart';
import '../providers/navigation_provider.dart';

/// Custom curve for balloon overshoot: peaks at ~1.04 then settles to 1.0.
/// Single easing curve, no bounce.
class BalloonSettleCurve extends Curve {
  const BalloonSettleCurve();

  @override
  double transformInternal(double t) {
    // Peaks at ~1.04 around t=0.7, settles to 1.0 at t=1.0
    // Using a combination: overshoot via sin curve
    final overshoot = AtmosphereConstants.balloonOvershoot;
    return t + overshoot * math.sin(t * math.pi);
  }
}

/// Reverse settle for ascent (deflation): dips to ~0.96 then settles to 1.0.
class DeflationSettleCurve extends Curve {
  const DeflationSettleCurve();

  @override
  double transformInternal(double t) {
    final overshoot = AtmosphereConstants.balloonOvershoot;
    return t - overshoot * math.sin(t * math.pi) * (1.0 - t);
  }
}

/// Eyepiece state machine states
enum EyepieceState { idle, pinching, holding, microPush }

/// Controls the Claritas zoom transition between layers.
class ClaritasTransitionController {
  ClaritasTransitionController({required TickerProvider vsync})
      : _animationController = AnimationController(
          vsync: vsync,
          duration: AtmosphereConstants.transitionDuration,
        ) {
    _animationController.addListener(_onAnimationTick);
    _animationController.addStatusListener(_onAnimationStatus);
  }

  final AnimationController _animationController;

  // Transition state
  double _progress = 0.0;
  TransitionDirection _direction = TransitionDirection.descend;
  bool _isAnimating = false;
  bool _isPinching = false;

  // Eyepiece state
  EyepieceState _eyepieceState = EyepieceState.idle;
  Timer? _eyepieceHoldTimer;
  double _lastPinchScale = 1.0;
  double _eyepieceLockProgress = 0.0;

  // Callbacks
  VoidCallback? onProgressChanged;
  VoidCallback? onTransitionComplete;
  VoidCallback? onSpringBackComplete;
  void Function(EyepieceState)? onEyepieceStateChanged;

  // Curves
  static const _balloonCurve = BalloonSettleCurve();
  static const _deflationCurve = DeflationSettleCurve();

  double get progress => _progress;
  bool get isAnimating => _isAnimating;
  bool get isPinching => _isPinching;
  EyepieceState get eyepieceState => _eyepieceState;
  TransitionDirection get direction => _direction;

  // --- Tap-driven transitions ---

  void startTapTransition(TransitionDirection direction) {
    _direction = direction;
    _isAnimating = true;
    _animationController.forward(from: 0.0);
  }

  void _onAnimationTick() {
    if (!_isAnimating || _isPinching) return;

    final raw = _animationController.value;
    // Apply settle curve in phase 3 (progress > 0.5)
    if (raw > 0.5) {
      final settleT = (raw - 0.5) / 0.5; // 0..1 within phase 3
      final curve = _direction == TransitionDirection.descend
          ? _balloonCurve
          : _deflationCurve;
      final settleValue = curve.transform(settleT);
      // Map back: 0.5 + settleValue * 0.5
      _progress = 0.5 + settleValue * 0.5;
    } else {
      _progress = raw;
    }
    onProgressChanged?.call();
  }

  void _onAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && _isAnimating && !_isPinching) {
      _isAnimating = false;
      _progress = 1.0;
      onTransitionComplete?.call();
    }
  }

  // --- Pinch-driven transitions ---

  void beginPinch(TransitionDirection direction) {
    _direction = direction;
    _isPinching = true;
    _isAnimating = false;
    _lastPinchScale = 1.0;
    _eyepieceState = EyepieceState.pinching;
    _animationController.stop();
  }

  void updatePinchScale(double scale) {
    if (!_isPinching) return;

    _lastPinchScale = scale;

    // Reset eyepiece hold timer on movement
    _cancelEyepieceHoldTimer();
    if (_eyepieceState == EyepieceState.holding ||
        _eyepieceState == EyepieceState.microPush) {
      // Check for micro-push: additional outward movement while in hold
      final delta = (scale - _lastPinchScale).abs();
      if (_eyepieceState == EyepieceState.holding && delta > AtmosphereConstants.eyepieceScaleDeltaThreshold) {
        _eyepieceState = EyepieceState.microPush;
        onEyepieceStateChanged?.call(_eyepieceState);
        return;
      }
    }

    double newProgress;
    if (_direction == TransitionDirection.descend) {
      newProgress = (scale - 1.0) /
          (AtmosphereConstants.pinchMaxScale - 1.0);
    } else {
      newProgress = (1.0 - scale) /
          (1.0 - AtmosphereConstants.pinchMinScale);
    }

    _progress = newProgress.clamp(0.0, 1.0);
    onProgressChanged?.call();

    // Start eyepiece hold detection
    _startEyepieceHoldTimer();
  }

  void onPinchEnd(double velocity) {
    if (!_isPinching) return;
    _isPinching = false;
    _cancelEyepieceHoldTimer();

    if (_eyepieceState != EyepieceState.idle) {
      _eyepieceState = EyepieceState.idle;
      onEyepieceStateChanged?.call(_eyepieceState);
    }

    if (_progress >= AtmosphereConstants.transitionThreshold) {
      // Auto-complete
      _autoComplete();
    } else {
      // Spring back
      _springBackToRest();
    }
  }

  void _autoComplete() {
    _isAnimating = true;
    // Animate from current progress to 1.0
    _animationController.value = _progress;
    _animationController.forward();
  }

  void _springBackToRest() {
    _isAnimating = true;
    final spring = SpringDescription.withDampingRatio(
      mass: 1.0,
      stiffness: 300.0,
      ratio: 0.7,
    );
    final simulation = SpringSimulation(spring, _progress, 0.0, 0.0);

    _animationController.animateWith(simulation).then((_) {
      _isAnimating = false;
      _progress = 0.0;
      onSpringBackComplete?.call();
    });
  }

  // --- Eyepiece ---

  void _startEyepieceHoldTimer() {
    _cancelEyepieceHoldTimer();
    _eyepieceHoldTimer = Timer(AtmosphereConstants.eyepieceHoldDelay, () {
      if (_isPinching && _eyepieceState == EyepieceState.pinching) {
        _eyepieceState = EyepieceState.holding;
        _eyepieceLockProgress = _progress;
        onEyepieceStateChanged?.call(_eyepieceState);
      }
    });
  }

  void _cancelEyepieceHoldTimer() {
    _eyepieceHoldTimer?.cancel();
    _eyepieceHoldTimer = null;
  }

  void releaseMicroPush() {
    if (_eyepieceState == EyepieceState.microPush) {
      _eyepieceState = EyepieceState.holding;
      onEyepieceStateChanged?.call(_eyepieceState);
    }
  }

  // --- Computed visual values ---

  /// Outgoing card opacity: 1.0 → 0.0 during crossover (0.25–0.50)
  double get outgoingOpacity {
    if (_eyepieceState == EyepieceState.microPush) return 0.0;
    if (_progress <= 0.25) return 1.0;
    if (_progress >= 0.50) return 0.0;
    return 1.0 - ((_progress - 0.25) / 0.25);
  }

  /// Incoming layer opacity: 0.0 → 1.0 during crossover (0.25–0.50)
  double get incomingOpacity {
    if (_eyepieceState == EyepieceState.microPush) return 1.0;
    if (_progress <= 0.25) return 0.0;
    if (_progress >= 0.50) return 1.0;
    return (_progress - 0.25) / 0.25;
  }

  /// Outgoing card scale: 1.0 → ~1.5 (zoom in feel for descend)
  double get outgoingScale {
    if (_eyepieceState == EyepieceState.holding) {
      return 1.0 + _eyepieceLockProgress * 0.5;
    }
    if (_direction == TransitionDirection.descend) {
      return 1.0 + _progress * 0.5;
    } else {
      return 1.0 - _progress * 0.3;
    }
  }

  /// Incoming layer scale: starts slightly small, settles to 1.0
  double get incomingScale {
    if (_progress >= 1.0) return 1.0;
    if (_direction == TransitionDirection.descend) {
      return 0.85 + _progress * 0.15;
    } else {
      return 1.15 - _progress * 0.15;
    }
  }

  void dispose() {
    _cancelEyepieceHoldTimer();
    _animationController.removeListener(_onAnimationTick);
    _animationController.removeStatusListener(_onAnimationStatus);
    _animationController.dispose();
  }
}
