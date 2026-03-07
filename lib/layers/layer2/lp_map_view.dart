import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/theme/atmosphere_colors.dart';
import '../../providers/layer2_mode_provider.dart';
import '../../providers/location_provider.dart';
import '../../widgets/lp_globe/lp_cylinder_painter.dart';
import '../../widgets/lp_globe/lp_globe_widget.dart';

/// Full-screen high-res (4K) light pollution map — alternate Layer 2.
/// Supports drag to rotate, pinch to zoom, double-tap to ascend.
class LPMapView extends ConsumerStatefulWidget {
  const LPMapView({super.key});

  @override
  ConsumerState<LPMapView> createState() => _LPMapViewState();
}

class _LPMapViewState extends ConsumerState<LPMapView>
    with TickerProviderStateMixin {
  double _yaw = 0;
  double _zoom = AtmosphereConstants.lpMapMinZoom;
  double _panY = 0;

  ui.FragmentShader? _shader;
  ui.Image? _atlasImage;

  double? _baseZoom;
  Offset? _lastFocalPoint;

  // Tap detection within scale gesture
  Offset? _scaleStartPoint;
  DateTime? _scaleStartTime;
  DateTime? _lastTapTime;
  static const _tapMaxDistance = 10.0;
  static const _tapMaxDuration = Duration(milliseconds: 300);
  static const _doubleTapWindow = Duration(milliseconds: 400);

  // Animated zoom (single-tap zoom in)
  late final AnimationController _zoomController;
  double _fromZoom = AtmosphereConstants.lpMapMinZoom;
  double _targetZoom = AtmosphereConstants.lpMapMinZoom;

  @override
  void initState() {
    super.initState();
    _zoomController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..addListener(_onZoomTick);

    // Pick up camera state from shared provider
    final viewState = ref.read(lpGlobeViewStateProvider);
    _yaw = viewState.yaw;
    _zoom = viewState.zoom.clamp(
      AtmosphereConstants.lpMapMinZoom,
      AtmosphereConstants.lpMapMaxZoom,
    );
    _panY = viewState.panY;

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

  String _loadedAtlasKey = '';
  bool _isLoadingAtlas = false;

  Future<void> _loadAtlas([String atlas = 'viirs']) async {
    if (_isLoadingAtlas) return;
    _isLoadingAtlas = true;
    final assetPath = atlas == 'lorenz'
        ? 'assets/lp_lorenz_4k.jpg'
        : 'assets/lp_atlas_4k.jpg';
    final data = await rootBundle.load(assetPath);
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    _isLoadingAtlas = false;
    if (!mounted) return;
    _atlasImage?.dispose();
    setState(() {
      _atlasImage = frame.image;
      _loadedAtlasKey = atlas;
    });
  }

  @override
  void dispose() {
    _zoomController.dispose();
    _shader?.dispose();
    _atlasImage?.dispose();
    // Sync camera state back before disposal
    _syncViewState();
    super.dispose();
  }

  void _syncViewState() {
    ref.read(lpGlobeViewStateProvider.notifier).sync(
          yaw: _yaw,
          zoom: _zoom,
          panY: _panY,
        );
  }

  void _onZoomTick() {
    final t = Curves.easeInOut.transform(_zoomController.value);
    setState(() {
      _zoom = _fromZoom + (_targetZoom - _fromZoom) * t;
    });
  }

  void _animateZoomTo(double target) {
    _fromZoom = _zoom;
    _targetZoom = target.clamp(
      AtmosphereConstants.lpMapMinZoom,
      AtmosphereConstants.lpMapMaxZoom,
    );
    _zoomController
      ..reset()
      ..forward();
  }

  void _onTapZoomIn() {
    _animateZoomTo(_zoom * AtmosphereConstants.globeZoomStep);
  }

  // ── Gestures ────────────────────────────────────────────────────────────────
  void _onScaleStart(ScaleStartDetails details) {
    _lastFocalPoint = details.localFocalPoint;
    _scaleStartPoint = details.localFocalPoint;
    _scaleStartTime = DateTime.now();
    _baseZoom = _zoom;
    ref.read(lpGlobeInteractingProvider.notifier).state = true;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    final delta =
        details.localFocalPoint - (_lastFocalPoint ?? details.localFocalPoint);
    _lastFocalPoint = details.localFocalPoint;

    setState(() {
      if (_baseZoom != null && (details.scale - 1.0).abs() > 0.01) {
        _zoom = (_baseZoom! / details.scale).clamp(
          AtmosphereConstants.lpMapMinZoom,
          AtmosphereConstants.lpMapMaxZoom,
        );
      }

      _yaw -= delta.dx * AtmosphereConstants.globeRotationSensitivity;
      _panY = (_panY - delta.dy * AtmosphereConstants.globeRotationSensitivity)
          .clamp(-cylHalfHeight, cylHalfHeight);
    });
  }

  void _onScaleEnd(ScaleEndDetails details) {
    // Detect tap vs drag
    if (_scaleStartPoint != null && _scaleStartTime != null) {
      final distance = (_lastFocalPoint! - _scaleStartPoint!).distance;
      final duration = DateTime.now().difference(_scaleStartTime!);

      if (distance < _tapMaxDistance && duration < _tapMaxDuration) {
        final now = DateTime.now();
        if (_lastTapTime != null &&
            now.difference(_lastTapTime!) < _doubleTapWindow) {
          // Double tap — request ascend back to Layer 1
          _lastTapTime = null;
          _syncViewState();
          ref.read(lpMapAscendRequestProvider.notifier).state = true;
        } else {
          // Single tap — zoom in
          _lastTapTime = now;
          Future.delayed(_doubleTapWindow, () {
            if (_lastTapTime == now) {
              _onTapZoomIn();
              _lastTapTime = null;
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
    final locationsAsync = ref.watch(locationProvider);
    final locations = locationsAsync.valueOrNull ?? [];
    final location = ref.watch(activeLocationProvider);
    final activeAtlas = ref.watch(lpMapAtlasProvider);

    // Reload atlas image if provider changed
    if (activeAtlas != _loadedAtlasKey) {
      _loadAtlas(activeAtlas);
    }

    final attribution = activeAtlas == 'lorenz'
        ? 'Lorenz 2022 \u00b7 djlorenz.github.io'
        : 'VIIRS 2024 \u00b7 lightpollutionmap.info';

    return ColoredBox(
      color: const Color(0xFF06060E),
      child: GestureDetector(
        onScaleStart: _onScaleStart,
        onScaleUpdate: _onScaleUpdate,
        onScaleEnd: _onScaleEnd,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_shader != null && _atlasImage != null)
              CustomPaint(
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
            else
              const Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: Color(0xFF334466),
                  ),
                ),
              ),
            // Atlas toggle at top-center
            Positioned(
              top: MediaQuery.of(context).padding.top + 12,
              left: 0,
              right: 0,
              child: Center(
                child: _AtlasToggle(activeAtlas: activeAtlas),
              ),
            ),
            // Bortle legend at bottom
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _MapBortleLegend(),
                  const SizedBox(height: 4),
                  Text(
                    attribution,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 9,
                      color: Color(0x4CF0EEE8),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AtlasToggle extends ConsumerWidget {
  final String activeAtlas;
  const _AtlasToggle({required this.activeAtlas});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      // Absorb taps so they don't propagate to ClaritasShell
      onTap: () {},
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xAA0A0A16),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0x26FFFFFF), width: 0.5),
        ),
        padding: const EdgeInsets.all(3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _TogglePill(
              label: 'VIIRS 2024',
              isActive: activeAtlas == 'viirs',
              onTap: () =>
                  ref.read(lpMapAtlasProvider.notifier).state = 'viirs',
            ),
            const SizedBox(width: 2),
            _TogglePill(
              label: 'Lorenz 2022',
              isActive: activeAtlas == 'lorenz',
              onTap: () =>
                  ref.read(lpMapAtlasProvider.notifier).state = 'lorenz',
            ),
          ],
        ),
      ),
    );
  }
}

class _TogglePill extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  const _TogglePill({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isActive ? const Color(0x33FFFFFF) : Colors.transparent,
          borderRadius: BorderRadius.circular(13),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
            color: isActive
                ? const Color(0xFFF0EEE8)
                : const Color(0x66F0EEE8),
          ),
        ),
      ),
    );
  }
}

class _MapBortleLegend extends StatelessWidget {
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
