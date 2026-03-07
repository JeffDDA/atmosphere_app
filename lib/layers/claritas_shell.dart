import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants.dart';
import '../models/layer_id.dart';
import '../providers/layer2_mode_provider.dart';
import '../providers/navigation_provider.dart';
import '../widgets/condition_flags.dart';
import '../widgets/depth_indicator.dart';
import '../widgets/lp_globe/lp_globe_widget.dart';
import 'claritas_transition.dart';
import 'layer1/classic_layer1.dart';
import 'layer2/layer2_view.dart';
import 'layer2/lp_map_view.dart';
import 'layer3/layer3_view.dart';

class ClaritasShell extends ConsumerStatefulWidget {
  const ClaritasShell({super.key});

  @override
  ConsumerState<ClaritasShell> createState() => _ClaritasShellState();
}

class _ClaritasShellState extends ConsumerState<ClaritasShell>
    with SingleTickerProviderStateMixin {
  late final ClaritasTransitionController _controller;
  DateTime? _lastTapTime;

  // Raw pointer tracking for absolute spread calculation
  final Map<int, Offset> _activePointers = {};
  double _initialSpan = 0.0;

  double get _currentSpan {
    if (_activePointers.length < 2) return 0.0;
    final pts = _activePointers.values.toList();
    return (pts[0] - pts[1]).distance;
  }

  @override
  void initState() {
    super.initState();
    _controller = ClaritasTransitionController(vsync: this);

    _controller.onProgressChanged = () {
      ref
          .read(navigationProvider.notifier)
          .updatePinchProgress(_controller.progress);
      setState(() {});
    };

    _controller.onTransitionComplete = () {
      ref.read(navigationProvider.notifier).commitTransition();
      setState(() {});
    };

    _controller.onSpringBackComplete = () {
      ref.read(navigationProvider.notifier).springBack();
      setState(() {});
    };

    _controller.onEyepieceStateChanged = (eyepieceState) {
      final nav = ref.read(navigationProvider.notifier);
      switch (eyepieceState) {
        case EyepieceState.holding:
          nav.enterEyepiece();
        case EyepieceState.microPush:
          nav.microPush(true);
        case EyepieceState.idle:
          nav.releaseEyepiece();
        case EyepieceState.pinching:
          break;
      }
      setState(() {});
    };
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // --- Pointer tracking ---

  void _onPointerDown(PointerDownEvent event) {
    _activePointers[event.pointer] = event.localPosition;
    if (_activePointers.length == 2) {
      _initialSpan = _currentSpan;
    }
  }

  void _onPointerMove(PointerMoveEvent event) {
    _activePointers[event.pointer] = event.localPosition;
  }

  void _onPointerUp(PointerUpEvent event) {
    _activePointers.remove(event.pointer);
  }

  void _onPointerCancel(PointerCancelEvent event) {
    _activePointers.remove(event.pointer);
  }

  // --- Tap handling ---

  void _handleTap() {
    if (ref.read(lpGlobeInteractingProvider)) return;
    final now = DateTime.now();

    // Double-tap detection
    if (_lastTapTime != null &&
        now.difference(_lastTapTime!) < AtmosphereConstants.doubleTapWindow) {
      _lastTapTime = null;
      _handleDoubleTap();
      return;
    }

    _lastTapTime = now;

    // Delayed single tap — wait to confirm it's not a double tap
    Future.delayed(AtmosphereConstants.doubleTapWindow, () {
      if (_lastTapTime != null &&
          now == _lastTapTime &&
          !_controller.isAnimating) {
        _handleSingleTap();
      }
    });
  }

  void _handleSingleTap() {
    final navState = ref.read(navigationProvider);
    if (navState.isTransitioning) return;

    final nav = ref.read(navigationProvider.notifier);
    nav.descendTap();
    _controller.startTapTransition(TransitionDirection.descend);
  }

  void _handleDoubleTap() {
    final navState = ref.read(navigationProvider);
    if (navState.isTransitioning) return;
    if (navState.currentLayer == LayerId.home) return;

    // Clear LP map mode when ascending from Layer 2
    if (navState.currentLayer == LayerId.layer2) {
      ref.read(layer2ModeProvider.notifier).state = null;
    }

    final nav = ref.read(navigationProvider.notifier);
    nav.ascendDoubleTap();
    _controller.startTapTransition(TransitionDirection.ascend);
  }

  // --- Pinch handling ---

  void _handleScaleStart(ScaleStartDetails details) {
    if (_controller.isAnimating) return;
  }

  void _handleScaleUpdate(ScaleUpdateDetails details) {
    if (details.pointerCount < 2) return;
    if (_controller.isAnimating) return;
    // Don't hijack pinch when LP globe is handling it
    if (ref.read(lpGlobeInteractingProvider)) return;

    // Check for handoff signal from LP globe — auto-complete descend
    final handoffSpan = ref.read(lpGlobePinchHandoffProvider);
    if (handoffSpan != null) {
      ref.read(lpGlobePinchHandoffProvider.notifier).state = null;
      // Immediately trigger a tap-style descend transition (no dead zone)
      final navState = ref.read(navigationProvider);
      if (!navState.isTransitioning) {
        ref.read(navigationProvider.notifier).descendTap();
        _controller.startTapTransition(TransitionDirection.descend);
      }
      return;
    }

    // Ensure we have a valid initial span
    if (_initialSpan <= 0 && _activePointers.length >= 2) {
      _initialSpan = _currentSpan;
    }
    if (_initialSpan <= 0) return;

    final spread = _currentSpan - _initialSpan;
    final absSpread = spread.abs();

    if (!_controller.isPinching) {
      // Dead zone — first 40 points filtered
      if (absSpread < AtmosphereConstants.pinchDeadZonePoints) return;

      // Determine direction from spread sign
      final direction = spread > 0
          ? TransitionDirection.descend
          : TransitionDirection.ascend;

      // Check if we can go in this direction
      final navState = ref.read(navigationProvider);
      if (direction == TransitionDirection.ascend &&
          navState.currentLayer == LayerId.home) {
        return;
      }

      final nav = ref.read(navigationProvider.notifier);
      nav.beginPinch(direction);
      _controller.beginPinch(direction);
    }

    _controller.updatePinchSpread(absSpread);
  }

  void _handleScaleEnd(ScaleEndDetails details) {
    if (!_controller.isPinching) return;
    _controller.onPinchEnd(details.velocity.pixelsPerSecond.distance);
    _initialSpan = 0.0;
  }

  Widget _buildLayerContent(LayerId layer) {
    switch (layer) {
      case LayerId.home:
        return const SizedBox.shrink();
      case LayerId.layer1:
        return const ClassicLayer1();
      case LayerId.layer2:
        final mode = ref.watch(layer2ModeProvider);
        if (mode == 'lp_map') {
          return const LPMapView();
        }
        return const Layer2View();
      case LayerId.layer3:
        return const Layer3View();
      case LayerId.layer4:
        // Stub for future
        return Container(
          color: const Color(0xFF5A7B9A),
          child: const Center(
            child: Text(
              'Layer 4',
              style: TextStyle(color: Colors.white, fontSize: 24),
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final navState = ref.watch(navigationProvider);
    final currentLayer = navState.currentLayer;
    final targetLayer = navState.targetLayer;
    final isTransitioning = navState.isTransitioning;

    // Listen for LP map ascend requests
    ref.listen<bool>(lpMapAscendRequestProvider, (prev, next) {
      if (next) {
        ref.read(lpMapAscendRequestProvider.notifier).state = false;
        _handleDoubleTap();
      }
    });

    return Scaffold(
      body: Listener(
        onPointerDown: _onPointerDown,
        onPointerMove: _onPointerMove,
        onPointerUp: _onPointerUp,
        onPointerCancel: _onPointerCancel,
        child: GestureDetector(
          onTap: _handleTap,
          onScaleStart: _handleScaleStart,
          onScaleUpdate: _handleScaleUpdate,
          onScaleEnd: _handleScaleEnd,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Incoming layer (underneath)
              if (isTransitioning && targetLayer != null)
                Opacity(
                  opacity: _controller.incomingOpacity,
                  child: Transform.scale(
                    scale: _controller.incomingScale,
                    child: _buildLayerContent(targetLayer),
                  ),
                ),

              // Current layer (on top)
              if (!isTransitioning || _controller.outgoingOpacity > 0)
                Opacity(
                  opacity: isTransitioning
                      ? _controller.outgoingOpacity
                      : 1.0,
                  child: Transform.scale(
                    scale: isTransitioning
                        ? _controller.outgoingScale
                        : 1.0,
                    child: _buildLayerContent(currentLayer),
                  ),
                ),

              // Overlays
              const SafeArea(
                child: Stack(
                  children: [
                    DepthIndicator(),
                    ConditionFlags(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
