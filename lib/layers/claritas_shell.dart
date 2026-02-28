import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants.dart';
import '../models/layer_id.dart';
import '../providers/navigation_provider.dart';
import '../widgets/condition_flags.dart';
import '../widgets/depth_indicator.dart';
import 'claritas_transition.dart';
import 'layer1/layer1_card.dart';
import 'layer2/layer2_view.dart';

class ClaritasShell extends ConsumerStatefulWidget {
  const ClaritasShell({super.key});

  @override
  ConsumerState<ClaritasShell> createState() => _ClaritasShellState();
}

class _ClaritasShellState extends ConsumerState<ClaritasShell>
    with SingleTickerProviderStateMixin {
  late final ClaritasTransitionController _controller;
  DateTime? _lastTapTime;

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

  void _handleTap() {
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

    final nav = ref.read(navigationProvider.notifier);
    nav.ascendDoubleTap();
    _controller.startTapTransition(TransitionDirection.ascend);
  }

  void _handleScaleStart(ScaleStartDetails details) {
    if (_controller.isAnimating) return;
  }

  void _handleScaleUpdate(ScaleUpdateDetails details) {
    final scale = details.scale;
    if (scale == 1.0) return; // No pinch happening

    final navState = ref.read(navigationProvider);

    if (!_controller.isPinching) {
      // Determine direction from initial gesture
      final direction = scale > 1.0
          ? TransitionDirection.descend
          : TransitionDirection.ascend;

      // Check if we can go in this direction
      if (direction == TransitionDirection.ascend &&
          navState.currentLayer == LayerId.home) {
        return;
      }

      final nav = ref.read(navigationProvider.notifier);
      nav.beginPinch(direction);
      _controller.beginPinch(direction);
    }

    _controller.updatePinchScale(scale);
  }

  void _handleScaleEnd(ScaleEndDetails details) {
    if (!_controller.isPinching) return;
    _controller.onPinchEnd(details.velocity.pixelsPerSecond.distance);
  }

  Widget _buildLayerContent(LayerId layer) {
    switch (layer) {
      case LayerId.home:
        return const SizedBox.shrink();
      case LayerId.layer1:
        return const Layer1Card();
      case LayerId.layer2:
        return const Layer2View();
      case LayerId.layer3:
        // Stub for future
        return Container(
          color: const Color(0xFF2E5090),
          child: const Center(
            child: Text(
              'Layer 3',
              style: TextStyle(color: Colors.white, fontSize: 24),
            ),
          ),
        );
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

    return Scaffold(
      body: GestureDetector(
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
    );
  }
}
