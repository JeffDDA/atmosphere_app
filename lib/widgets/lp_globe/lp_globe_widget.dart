import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/theme/atmosphere_colors.dart';
import '../../models/location.dart';
import '../../providers/layer2_mode_provider.dart';
import '../../providers/location_provider.dart';
import 'lp_cylinder_painter.dart';

/// True when the LP globe is handling a pinch/scale gesture.
/// ClaritasShell checks this to avoid triggering layer transitions.
final lpGlobeInteractingProvider = StateProvider<bool>((ref) => false);

/// Compact LP cylinder for Layer 1 — renders VIIRS atlas wrapped on a
/// 3D cylinder via GLSL. Drag to spin, pinch to zoom.
/// When zoom hits the minimum limit during a pinch-out, hands off to
/// ClaritasShell for transition to full-screen LP map (Layer 2 alternate).
class LPGlobeWidget extends ConsumerStatefulWidget {
  const LPGlobeWidget({super.key});

  @override
  ConsumerState<LPGlobeWidget> createState() => _LPGlobeWidgetState();
}

class _LPGlobeWidgetState extends ConsumerState<LPGlobeWidget>
    with TickerProviderStateMixin {
  double _yaw = 0;
  double _zoom = AtmosphereConstants.globeDefaultZoom;
  double _panY = 0;

  ui.FragmentShader? _shader;
  ui.Image? _atlasImage;

  late final AnimationController _spinController;
  double _fromYaw = 0;
  double _targetYaw = 0;

  ObservatoryLocation? _lastLocation;
  double? _baseZoom;
  Offset? _lastFocalPoint;

  // Tap detection within scale gesture
  Offset? _scaleStartPoint;
  DateTime? _scaleStartTime;
  DateTime? _lastTapTime;
  static const _tapMaxDistance = 10.0;
  static const _tapMaxDuration = Duration(milliseconds: 300);
  static const _doubleTapWindow = Duration(milliseconds: 400);

  // Handoff state — freeze gestures once we've triggered the handoff
  bool _handoffFired = false;

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(
      vsync: this,
      duration: Duration(
        milliseconds: AtmosphereConstants.globeSpinDurationMs.toInt(),
      ),
    )..addListener(_onSpinTick);
    _loadShader();
    _loadAtlas();

    // Pick up camera state from the shared provider (returning from LP map)
    final viewState = ref.read(lpGlobeViewStateProvider);
    _yaw = viewState.yaw;
    _zoom = viewState.zoom.clamp(
      AtmosphereConstants.globeMinZoom,
      AtmosphereConstants.globeMaxZoom,
    );
    _panY = viewState.panY;
  }

  Future<void> _loadShader() async {
    final program =
        await ui.FragmentProgram.fromAsset('shaders/lp_globe.frag');
    if (!mounted) return;
    setState(() {
      _shader = program.fragmentShader();
    });
  }

  Future<void> _loadAtlas() async {
    final data = await rootBundle.load('assets/lp_atlas_2k.jpg');
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    if (!mounted) return;
    setState(() {
      _atlasImage = frame.image;
    });
    _spinToActiveLocation(immediate: true);
  }

  @override
  void dispose() {
    _spinController.dispose();
    _shader?.dispose();
    _atlasImage?.dispose();
    super.dispose();
  }

  // ── Spin animation ──────────────────────────────────────────────────────────
  void _onSpinTick() {
    final t = Curves.easeInOut.transform(_spinController.value);
    setState(() {
      _yaw = _lerpAngle(_fromYaw, _targetYaw, t);
    });
  }

  double _lerpAngle(double from, double to, double t) {
    double diff = to - from;
    while (diff > math.pi) {
      diff -= 2 * math.pi;
    }
    while (diff < -math.pi) {
      diff += 2 * math.pi;
    }
    return from + diff * t;
  }

  void _spinToActiveLocation({bool immediate = false}) {
    final location = ref.read(activeLocationProvider);
    if (location == null) return;

    _targetYaw = -location.longitude * math.pi / 180.0;

    if (immediate) {
      setState(() {
        _yaw = _targetYaw;
      });
      return;
    }

    _fromYaw = _yaw;
    _spinController
      ..reset()
      ..forward();
  }

  // ── Handoff ─────────────────────────────────────────────────────────────────
  void _initiateHandoff(double currentSpan) {
    if (_handoffFired) return;
    _handoffFired = true;

    // Sync camera state to the shared provider
    ref.read(lpGlobeViewStateProvider.notifier).sync(
          yaw: _yaw,
          zoom: _zoom,
          panY: _panY,
        );

    // Set layer 2 mode to LP map
    ref.read(layer2ModeProvider.notifier).state = 'lp_map';

    // Release globe interaction so ClaritasShell can take over
    ref.read(lpGlobeInteractingProvider.notifier).state = false;

    // Fire handoff signal with current span
    ref.read(lpGlobePinchHandoffProvider.notifier).state = currentSpan;
  }

  // ── Gestures ────────────────────────────────────────────────────────────────
  void _onScaleStart(ScaleStartDetails details) {
    _spinController.stop();
    _lastFocalPoint = details.localFocalPoint;
    _scaleStartPoint = details.localFocalPoint;
    _scaleStartTime = DateTime.now();
    _baseZoom = _zoom;
    _handoffFired = false;
    ref.read(lpGlobeInteractingProvider.notifier).state = true;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    if (_handoffFired) return;

    final delta =
        details.localFocalPoint - (_lastFocalPoint ?? details.localFocalPoint);
    _lastFocalPoint = details.localFocalPoint;

    setState(() {
      // Always apply scale — scale is 1.0 for single finger, changes on pinch
      if (_baseZoom != null && (details.scale - 1.0).abs() > 0.01) {
        final rawZoom = _baseZoom! / details.scale;

        // Pinch-out handoff: zoom wants to go below min, hand off to ClaritasShell
        if (rawZoom < AtmosphereConstants.globeMinZoom &&
            details.pointerCount >= 2) {
          _zoom = AtmosphereConstants.globeMinZoom;
          // Compute current finger span from the scale gesture
          // Scale ratio × initial baseline → approximate pixel span
          final approxSpan = details.scale * 100.0; // heuristic span
          _initiateHandoff(approxSpan);
          return;
        }

        _zoom = rawZoom.clamp(
          AtmosphereConstants.globeMinZoom,
          AtmosphereConstants.globeMaxZoom,
        );
      }

      // Drag: horizontal = yaw (negated for natural panning), vertical = pan
      _yaw -= delta.dx * AtmosphereConstants.globeRotationSensitivity;
      _panY = (_panY - delta.dy * AtmosphereConstants.globeRotationSensitivity)
          .clamp(-cylHalfHeight, cylHalfHeight);
    });
  }

  void _onScaleEnd(ScaleEndDetails details) {
    if (_handoffFired) {
      _lastFocalPoint = null;
      _scaleStartPoint = null;
      _scaleStartTime = null;
      _baseZoom = null;
      return;
    }

    // Detect tap: minimal movement + short duration
    if (_scaleStartPoint != null && _scaleStartTime != null) {
      final distance =
          (_lastFocalPoint! - _scaleStartPoint!).distance;
      final duration = DateTime.now().difference(_scaleStartTime!);

      if (distance < _tapMaxDistance && duration < _tapMaxDuration) {
        final now = DateTime.now();
        if (_lastTapTime != null &&
            now.difference(_lastTapTime!) < _doubleTapWindow) {
          // Double tap — let ClaritasShell handle ascend
          _lastTapTime = null;
        } else {
          // Single tap — set LP map mode so ClaritasShell descends to LP map
          _lastTapTime = now;
          Future.delayed(_doubleTapWindow, () {
            if (_lastTapTime == now) {
              _lastTapTime = null;
              ref.read(lpGlobeViewStateProvider.notifier).sync(
                    yaw: _yaw,
                    zoom: _zoom,
                    panY: _panY,
                  );
              ref.read(layer2ModeProvider.notifier).state = 'lp_map';
            }
          });
        }
      }
    }

    _lastFocalPoint = null;
    _scaleStartPoint = null;
    _scaleStartTime = null;
    _baseZoom = null;
    ref.read(lpGlobeInteractingProvider.notifier).state = false;
  }

  @override
  Widget build(BuildContext context) {
    final location = ref.watch(activeLocationProvider);
    if (location != null && location != _lastLocation && _atlasImage != null) {
      if (_lastLocation != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _spinToActiveLocation();
        });
      }
      _lastLocation = location;
    }

    final locationsAsync = ref.watch(locationProvider);
    final locations = locationsAsync.valueOrNull ?? [];

    return GestureDetector(
      onScaleStart: _onScaleStart,
      onScaleUpdate: _onScaleUpdate,
      onScaleEnd: _onScaleEnd,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: (_shader != null && _atlasImage != null)
                  ? CustomPaint(
                      painter: LPCylinderPainter(
                        shader: _shader!,
                        atlas: _atlasImage!,
                        yaw: _yaw,
                        zoom: _zoom,
                        panY: _panY,
                        locations: locations,
                        activeLocation: location,
                      ),
                      size: Size.infinite,
                    )
                  : const ColoredBox(
                      color: Color(0xFF06060E),
                      child: Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            color: Color(0xFF334466),
                          ),
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 6),
          const _BortleLegend(),
          const SizedBox(height: 2),
          const Text(
            'VIIRS 2024 \u00b7 lightpollutionmap.info',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 9,
              color: Color(0x4CF0EEE8),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Bortle Legend Strip ────────────────────────────────────────────────────────

class _BortleLegend extends StatelessWidget {
  const _BortleLegend();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 22,
      child: Row(
        children: [
          const Text(
            'Dark',
            style: TextStyle(fontSize: 8, color: Color(0x4CF0EEE8)),
          ),
          const SizedBox(width: 4),
          ...AtmosphereColors.bortleColors.map(
            (c) => Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 0.5),
                decoration: BoxDecoration(
                  color: c,
                  borderRadius: BorderRadius.circular(2),
                  border: c == AtmosphereColors.bortleColors[0]
                      ? Border.all(
                          color: const Color(0x26FFFFFF),
                          width: 0.5,
                        )
                      : null,
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          const Text(
            'Bright',
            style: TextStyle(fontSize: 8, color: Color(0x4CF0EEE8)),
          ),
        ],
      ),
    );
  }
}
