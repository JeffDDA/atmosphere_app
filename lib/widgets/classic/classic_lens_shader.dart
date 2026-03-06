import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../providers/classic_canvas_provider.dart';
import '../../providers/classic_lens_provider.dart';
import 'classic_grid.dart';

/// Wraps the ClassicGrid and applies a GLSL lens distortion shader when
/// the lens is active. When inactive, the grid renders directly with zero
/// overhead (no image capture, no shader).
class ClassicLensShader extends ConsumerStatefulWidget {
  const ClassicLensShader({super.key});

  @override
  ConsumerState<ClassicLensShader> createState() => _ClassicLensShaderState();
}

class _ClassicLensShaderState extends ConsumerState<ClassicLensShader>
    with SingleTickerProviderStateMixin {
  ui.FragmentProgram? _program;
  ui.FragmentShader? _shader;
  bool _shaderReady = false;

  // Double-buffered image capture
  ui.Image? _capturedImage;
  bool _isCapturing = false;
  Ticker? _captureTicker;

  @override
  void initState() {
    super.initState();
    _loadShader();
  }

  Future<void> _loadShader() async {
    try {
      _program =
          await ui.FragmentProgram.fromAsset('shaders/lens_distortion.frag');
      _shader = _program!.fragmentShader();
      if (mounted) {
        setState(() => _shaderReady = true);
      }
    } catch (e) {
      debugPrint('Failed to load lens distortion shader: $e');
    }
  }

  @override
  void dispose() {
    _stopCapture();
    _capturedImage?.dispose();
    _shader?.dispose();
    super.dispose();
  }

  void _startCapture() {
    if (_captureTicker != null) return;
    _captureTicker = createTicker(_onCaptureTick);
    _captureTicker!.start();
  }

  void _stopCapture() {
    _captureTicker?.stop();
    _captureTicker?.dispose();
    _captureTicker = null;
  }

  void _onCaptureTick(Duration elapsed) {
    if (_isCapturing) return;
    _captureGrid();
  }

  Future<void> _captureGrid() async {
    if (_isCapturing) return;
    _isCapturing = true;

    try {
      final boundary = classicGridBoundaryKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null || !boundary.hasSize) {
        _isCapturing = false;
        return;
      }

      final image = await boundary.toImage(pixelRatio: 1.0);
      if (mounted) {
        final oldImage = _capturedImage;
        setState(() {
          _capturedImage = image;
        });
        oldImage?.dispose();
      } else {
        image.dispose();
      }
    } catch (_) {
      // Capture can fail transiently during layout
    } finally {
      _isCapturing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final lensState = ref.watch(classicLensProvider);
    final canvasState = ref.watch(classicCanvasProvider);

    // When lens is active and shader ready, start capturing
    if (lensState.isActive && _shaderReady) {
      _startCapture();
    } else {
      _stopCapture();
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        // The actual grid — always in the tree so it can be captured
        const ClassicGrid(),

        // Shader overlay — only when lens is active and we have a captured image
        if (lensState.isActive && _shaderReady && _capturedImage != null)
          Positioned.fill(
            child: CustomPaint(
              painter: _LensShaderPainter(
                shader: _shader!,
                gridImage: _capturedImage!,
                lensState: lensState,
                canvasOffsetPx: canvasState.offsetPx,
                labelWidth: AtmosphereConstants.classicRowLabelWidth,
              ),
            ),
          ),
      ],
    );
  }
}

class _LensShaderPainter extends CustomPainter {
  final ui.FragmentShader shader;
  final ui.Image gridImage;
  final ClassicLensState lensState;
  final double canvasOffsetPx;
  final double labelWidth;

  _LensShaderPainter({
    required this.shader,
    required this.gridImage,
    required this.lensState,
    required this.canvasOffsetPx,
    required this.labelWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Convert grid-content-space lens center to screen-local
    final screenX = lensState.centerGridX - canvasOffsetPx + labelWidth;
    final screenY = lensState.centerGridY;
    final lensRadius = size.width * AtmosphereConstants.classicLensRadius;

    // Set uniforms (order matches shader declaration order)
    // vec2 uResolution
    shader.setFloat(0, size.width);
    shader.setFloat(1, size.height);
    // vec2 uLensCenter
    shader.setFloat(2, screenX);
    shader.setFloat(3, screenY);
    // float uLensRadius
    shader.setFloat(4, lensRadius);
    // float uStrength
    shader.setFloat(5, lensState.strength);
    // float uFocalDepth
    shader.setFloat(6, AtmosphereConstants.classicLensFocalDepth);
    // float uChromatic
    shader.setFloat(7, AtmosphereConstants.classicLensChromaticAberration ? 1.0 : 0.0);

    // sampler2D uTexture
    shader.setImageSampler(0, gridImage);

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..shader = shader,
    );
  }

  @override
  bool shouldRepaint(covariant _LensShaderPainter old) {
    return old.lensState != lensState ||
        old.gridImage != gridImage ||
        old.canvasOffsetPx != canvasOffsetPx;
  }
}
