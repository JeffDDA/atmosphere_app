import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants.dart';
import '../core/theme/atmosphere_colors.dart';
import '../models/layer_id.dart';
import '../providers/navigation_provider.dart';

class DepthIndicator extends ConsumerStatefulWidget {
  const DepthIndicator({super.key});

  @override
  ConsumerState<DepthIndicator> createState() => _DepthIndicatorState();
}

class _DepthIndicatorState extends ConsumerState<DepthIndicator> {
  double _opacity = 1.0;
  Timer? _hideTimer;

  static const _dotColors = [
    AtmosphereColors.layer1Dot,
    AtmosphereColors.layer2Dot,
    AtmosphereColors.layer3Dot,
    AtmosphereColors.layer4Dot,
  ];

  static const _layers = [
    LayerId.layer1,
    LayerId.layer2,
    LayerId.layer3,
    LayerId.layer4,
  ];

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  void _resetHideTimer() {
    _hideTimer?.cancel();
    setState(() => _opacity = 1.0);
    _hideTimer = Timer(AtmosphereConstants.depthIndicatorAutoHide, () {
      if (mounted) setState(() => _opacity = 0.0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final navState = ref.watch(navigationProvider);

    // Don't show on home
    if (navState.currentLayer == LayerId.home) {
      return const SizedBox.shrink();
    }

    // Reset timer on layer change
    ref.listen(navigationProvider, (prev, next) {
      if (prev?.currentLayer != next.currentLayer) {
        _resetHideTimer();
      }
    });

    // Start auto-hide on first build
    if (_hideTimer == null) {
      _resetHideTimer();
    }

    return Positioned(
      right: 12,
      top: 0,
      bottom: 0,
      child: AnimatedOpacity(
        opacity: _opacity,
        duration: const Duration(milliseconds: 300),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(4, (index) {
              final isActive = navState.currentLayer == _layers[index];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: isActive ? 8 : 6,
                  height: isActive ? 8 : 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isActive
                        ? _dotColors[index]
                        : _dotColors[index].withValues(alpha: 0.3),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
