import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/theme/atmosphere_colors.dart';
import '../../models/location.dart';
import '../../providers/location_provider.dart';

const _crimson = Color(0xFF8B0000);
const _cylHalfHeight = 1.22; // must match CYL_H in shader
const _latTop = 75.0; // must match LAT_TOP in shader
const _latBot = -65.0; // must match LAT_BOT in shader

/// Compact LP cylinder for Layer 1 — renders VIIRS atlas wrapped on a
/// 3D cylinder via GLSL. Drag to spin, pinch to zoom.
class LPGlobeWidget extends ConsumerStatefulWidget {
  const LPGlobeWidget({super.key});

  @override
  ConsumerState<LPGlobeWidget> createState() => _LPGlobeWidgetState();
}

class _LPGlobeWidgetState extends ConsumerState<LPGlobeWidget>
    with SingleTickerProviderStateMixin {
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

  // ── Gestures ────────────────────────────────────────────────────────────────
  void _onScaleStart(ScaleStartDetails details) {
    _spinController.stop();
    _lastFocalPoint = details.localFocalPoint;
    _baseZoom = _zoom;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    final delta =
        details.localFocalPoint - (_lastFocalPoint ?? details.localFocalPoint);
    _lastFocalPoint = details.localFocalPoint;

    setState(() {
      // Always apply scale — scale is 1.0 for single finger, changes on pinch
      if (_baseZoom != null && (details.scale - 1.0).abs() > 0.01) {
        _zoom = (_baseZoom! / details.scale).clamp(
          AtmosphereConstants.globeMinZoom,
          AtmosphereConstants.globeMaxZoom,
        );
      }

      // Drag: horizontal = yaw (negated for natural panning), vertical = pan
      _yaw -= delta.dx * AtmosphereConstants.globeRotationSensitivity;
      _panY = (_panY - delta.dy * AtmosphereConstants.globeRotationSensitivity)
          .clamp(-_cylHalfHeight, _cylHalfHeight);
    });
  }

  void _onScaleEnd(ScaleEndDetails details) {
    _lastFocalPoint = null;
    _baseZoom = null;
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
      onTap: () {},
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
                      painter: _LPCylinderPainter(
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

// ── Cylinder Painter ──────────────────────────────────────────────────────────

class _LPCylinderPainter extends CustomPainter {
  _LPCylinderPainter({
    required this.shader,
    required this.atlas,
    required this.yaw,
    required this.zoom,
    required this.panY,
    required this.locations,
    this.activeLocation,
  });

  final ui.FragmentShader shader;
  final ui.Image atlas;
  final double yaw;
  final double zoom;
  final double panY;
  final List<ObservatoryLocation> locations;
  final ObservatoryLocation? activeLocation;

  @override
  void paint(Canvas canvas, Size size) {
    // uResolution (vec2)
    shader.setFloat(0, size.width);
    shader.setFloat(1, size.height);
    // uYaw (float)
    shader.setFloat(2, yaw);
    // uZoom (float)
    shader.setFloat(3, zoom);
    // uPanY (float)
    shader.setFloat(4, panY);
    // uAtlas (sampler2D)
    shader.setImageSampler(0, atlas);

    final paint = Paint()..shader = shader;
    canvas.drawRect(Offset.zero & size, paint);

    _drawSiteMarkers(canvas, size);
  }

  void _drawSiteMarkers(Canvas canvas, Size size) {
    final fovRad = AtmosphereConstants.globeFov * math.pi / 180.0;
    final focalLen = 1.0 / math.tan(fovRad * 0.5);
    final minDim = math.min(size.width, size.height);

    for (final loc in locations) {
      // Place marker on cylinder surface
      final lngRad = loc.longitude * math.pi / 180.0;
      final angle = lngRad + yaw;

      // 3D position on cylinder (radius=1, Y from latitude)
      final cx = math.sin(angle);
      final cz = math.cos(angle);
      // Latitude → Y on cylinder: map lat range [LAT_BOT, LAT_TOP] to [-H, +H]
      final latClamped = loc.latitude.clamp(_latBot, _latTop);
      final cy = ((latClamped - _latBot) / (_latTop - _latBot) * 2.0 - 1.0) *
          _cylHalfHeight;

      // Skip if on back side of cylinder
      if (cz < 0.05) continue;

      // Perspective projection (camera at y=panY, z=-zoom)
      final pz = cz + zoom;
      if (pz < 0.01) continue;
      final px = (cx * focalLen / pz) * minDim + size.width * 0.5;
      final py = (-(cy - panY) * focalLen / pz) * minDim + size.height * 0.5;

      if (px < -10 ||
          px > size.width + 10 ||
          py < -10 ||
          py > size.height + 10) {
        continue;
      }

      final isActive = activeLocation != null &&
          loc.latitude == activeLocation!.latitude &&
          loc.longitude == activeLocation!.longitude;

      final center = Offset(px, py);

      if (isActive) {
        canvas.drawCircle(center, 6, Paint()..color = _crimson);
        canvas.drawCircle(
          center,
          10,
          Paint()
            ..color = _crimson.withValues(alpha: 0.8)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
      } else {
        final bortleIdx =
            (loc.bortleClass - 1).clamp(0, AtmosphereColors.bortleColors.length - 1);
        canvas.drawCircle(center, 3, Paint()..color = AtmosphereColors.bortleColors[bortleIdx]);
        if (loc.bortleClass <= 2) {
          canvas.drawCircle(
            center,
            3.5,
            Paint()
              ..color = const Color(0x33FFFFFF)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 0.5,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(_LPCylinderPainter old) =>
      old.yaw != yaw ||
      old.zoom != zoom ||
      old.panY != panY ||
      old.activeLocation != activeLocation;
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
