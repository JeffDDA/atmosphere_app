import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../core/cmc_projections.dart';
import '../../core/constants.dart';
import '../../models/forecast.dart';
import '../../providers/cmc_map_provider.dart';
import '../../providers/location_provider.dart';
import '../../providers/scrub_provider.dart';

/// Layer 3 CMC forecast map viewer.
///
/// Auto-animates through forecast hours at ~1.5 fps. Shows a crosshair at
/// the user's location. Tap to pause/play, swipe to jump ±3h.
class CmcMapView extends ConsumerStatefulWidget {
  final CmcMapType type;
  final List<HourlyForecast> hours;

  const CmcMapView({
    super.key,
    required this.type,
    required this.hours,
  });

  @override
  ConsumerState<CmcMapView> createState() => _CmcMapViewState();
}

class _CmcMapViewState extends ConsumerState<CmcMapView> {
  final Map<int, ui.Image> _imageCache = {};
  ui.Image? _currentImage;
  bool _isLoading = true;
  String? _error;
  String? _activeQuadrant;

  // Animation state
  static const int _hourStep = 3;
  static const int _maxHour = 48;
  static const List<Duration> _speeds = [
    Duration(milliseconds: 1500),
    Duration(milliseconds: 1000),
    Duration(milliseconds: 700),
    Duration(milliseconds: 400),
    Duration(milliseconds: 200),
  ];
  static const List<String> _speedLabels = [
    '0.5x',
    '0.7x',
    '1x',
    '1.8x',
    '3.5x',
  ];
  int _speedIndex = 2;
  Duration get _frameInterval => _speeds[_speedIndex];
  Timer? _animTimer;
  bool _isPlaying = false;
  int _currentHour = 0;
  int _startHour = 0; // entry hour from scrub
  bool _prefetchDone = false;

  /// All forecast hours in the animation sequence.
  List<int> get _hourSequence {
    final hours = <int>[];
    for (int h = 0; h <= _maxHour; h += _hourStep) {
      hours.add(h);
    }
    return hours;
  }

  @override
  void initState() {
    super.initState();
    _initMapHour();
  }

  @override
  void dispose() {
    _animTimer?.cancel();
    for (final img in _imageCache.values) {
      img.dispose();
    }
    super.dispose();
  }

  void _initMapHour() {
    final scrub = ref.read(scrubProvider);
    final totalHours = widget.hours.length;
    if (totalHours == 0) return;

    final hourIndex = scrub.hourIndex(totalHours);
    final hourTime = widget.hours[hourIndex].time;
    final cmcHour = CmcMapRun.forecastHourOffset(hourTime);
    // Snap to nearest step
    _startHour = (cmcHour ~/ _hourStep) * _hourStep;
    _currentHour = _startHour;

    if (widget.type == CmcMapType.cloud) {
      final location = ref.read(activeLocationProvider);
      if (location != null) {
        _activeQuadrant =
            CmcProjections.determineCloudQuadrant(location.latitude, location.longitude);
      }
      _activeQuadrant ??= 'NE';
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(cmcMapHourProvider.notifier).state = _currentHour;
      _loadImage(_currentHour).then((_) {
        // Start prefetching all frames, then auto-play
        _prefetchAll();
      });
    });
  }

  /// Prefetch all frames in the animation sequence.
  Future<void> _prefetchAll() async {
    final sequence = _hourSequence;
    // Fetch starting from current hour outward
    final startIdx = sequence.indexOf(_currentHour).clamp(0, sequence.length - 1);

    // Fetch forward from current position, then wrap to beginning
    final ordered = <int>[
      ...sequence.sublist(startIdx),
      ...sequence.sublist(0, startIdx),
    ];

    for (final hour in ordered) {
      if (!mounted) return;
      if (_imageCache.containsKey(hour)) continue;
      await _fetchImage(hour);
    }

    if (mounted) {
      setState(() => _prefetchDone = true);
      // Auto-play once enough frames are cached
      if (_imageCache.length >= 3 && !_isPlaying) {
        _startPlaying();
      }
    }
  }

  Future<void> _fetchImage(int forecastHour) async {
    final url = CmcMapRun.buildUrl(
      type: widget.type,
      quadrant: _activeQuadrant,
      forecastHour: forecastHour,
    );

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final codec = await ui.instantiateImageCodec(response.bodyBytes);
        final frame = await codec.getNextFrame();
        if (mounted) {
          _imageCache[forecastHour] = frame.image;
        }
      }
    } catch (_) {
      // Skip failed frames silently
    }
  }

  Future<void> _loadImage(int forecastHour) async {
    if (_imageCache.containsKey(forecastHour)) {
      setState(() {
        _currentImage = _imageCache[forecastHour];
        _isLoading = false;
        _error = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    final url = CmcMapRun.buildUrl(
      type: widget.type,
      quadrant: _activeQuadrant,
      forecastHour: forecastHour,
    );

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final codec = await ui.instantiateImageCodec(response.bodyBytes);
        final frame = await codec.getNextFrame();
        if (mounted) {
          _imageCache[forecastHour] = frame.image;
          setState(() {
            _currentImage = frame.image;
            _isLoading = false;
          });
        }
      } else if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Map unavailable (${response.statusCode})';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Unable to load forecast map';
        });
      }
    }
  }

  void _startPlaying() {
    if (_isPlaying) return;
    setState(() => _isPlaying = true);
    _animTimer = Timer.periodic(_frameInterval, (_) => _advanceFrame());
  }

  void _stopPlaying() {
    _animTimer?.cancel();
    _animTimer = null;
    setState(() => _isPlaying = false);
  }

  void _togglePlayback() {
    if (_isPlaying) {
      _stopPlaying();
    } else {
      _startPlaying();
    }
  }

  void _advanceFrame() {
    final sequence = _hourSequence;
    var currentIdx = sequence.indexOf(_currentHour);
    if (currentIdx < 0) currentIdx = 0;

    final nextIdx = (currentIdx + 1) % sequence.length;
    final nextHour = sequence[nextIdx];

    // Skip to next cached frame, wrapping around
    for (int i = 0; i < sequence.length; i++) {
      final tryIdx = (nextIdx + i) % sequence.length;
      final tryHour = sequence[tryIdx];
      if (_imageCache.containsKey(tryHour)) {
        _setHour(tryHour);
        return;
      }
    }
  }

  void _setHour(int hour) {
    setState(() {
      _currentHour = hour;
      _currentImage = _imageCache[hour];
    });
    ref.read(cmcMapHourProvider.notifier).state = hour;
  }

  void _onSpeedChanged(double value) {
    final newIndex = value.round();
    if (newIndex == _speedIndex) return;
    setState(() => _speedIndex = newIndex);
    if (_isPlaying) {
      _animTimer?.cancel();
      _animTimer = Timer.periodic(_frameInterval, (_) => _advanceFrame());
    }
  }

  void _jumpHour(int delta) {
    _stopPlaying();
    final sequence = _hourSequence;
    final currentIdx = sequence.indexOf(_currentHour).clamp(0, sequence.length - 1);
    final nextIdx = (currentIdx + delta).clamp(0, sequence.length - 1);
    final nextHour = sequence[nextIdx];

    if (_imageCache.containsKey(nextHour)) {
      _setHour(nextHour);
    } else {
      _setHour(nextHour);
      _loadImage(nextHour);
    }
  }

  @override
  Widget build(BuildContext context) {
    final forecastHour = ref.watch(cmcMapHourProvider);
    final location = ref.watch(activeLocationProvider);
    final typeLabel = CmcMapRun.mapTypeLabel(widget.type);

    return GestureDetector(
      onTap: _togglePlayback,
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (velocity.abs() < AtmosphereConstants.cmcSwipeVelocityThreshold) {
          return;
        }
        _jumpHour(velocity < 0 ? 1 : -1);
      },
      child: Container(
        color: const Color(0xFF0A0A1A),
        child: Column(
          children: [
            Expanded(
              child: _buildMapArea(location),
            ),
            const SizedBox(height: 8),
            // Timeline progress bar
            _buildTimeline(),
            const SizedBox(height: 4),
            _buildSpeedSlider(),
            const SizedBox(height: 4),
            // Hour label pill
            _buildHourLabel(typeLabel, forecastHour),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildMapArea(dynamic location) {
    if (_isLoading && _currentImage == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(
              color: Color(0xFF4FC3F7),
              strokeWidth: 2,
            ),
            const SizedBox(height: 12),
            Text(
              'Loading forecast maps\u2026',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }

    if (_error != null && _currentImage == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off,
                color: Colors.white.withValues(alpha: 0.3), size: 48),
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5), fontSize: 14),
            ),
          ],
        ),
      );
    }

    if (_currentImage == null) {
      return const SizedBox.shrink();
    }

    return Stack(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            return CustomPaint(
              size: Size(constraints.maxWidth, constraints.maxHeight),
              painter: _CmcMapPainter(
                image: _currentImage!,
                location: location,
                type: widget.type,
                quadrant: _activeQuadrant,
              ),
            );
          },
        ),
        // Play/pause indicator (brief flash)
        if (!_isPlaying && _currentImage != null)
          Positioned(
            right: 16,
            top: 16,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.pause,
                color: Colors.white.withValues(alpha: 0.5),
                size: 18,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTimeline() {
    final sequence = _hourSequence;
    final currentIdx = sequence.indexOf(_currentHour).clamp(0, sequence.length - 1);
    final progress = sequence.isEmpty ? 0.0 : currentIdx / (sequence.length - 1);

    // Show cached frame indicators
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          // Thin progress bar
          SizedBox(
            height: 4,
            child: CustomPaint(
              size: const Size(double.infinity, 4),
              painter: _TimelinePainter(
                progress: progress,
                cachedFrames: sequence
                    .map((h) => _imageCache.containsKey(h))
                    .toList(),
              ),
            ),
          ),
          const SizedBox(height: 4),
          // Hour markers
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'h+0',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.3),
                  fontSize: 10,
                ),
              ),
              if (!_prefetchDone)
                Text(
                  '${_imageCache.length}/${sequence.length} frames',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.3),
                    fontSize: 10,
                  ),
                ),
              Text(
                'h+$_maxHour',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.3),
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSpeedSlider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Icon(
            Icons.speed,
            color: Colors.white.withValues(alpha: 0.4),
            size: 16,
          ),
          Expanded(
            child: CupertinoSlider(
              value: _speedIndex.toDouble(),
              min: 0,
              max: (_speeds.length - 1).toDouble(),
              divisions: _speeds.length - 1,
              activeColor: const Color(0xFF4FC3F7),
              onChanged: _onSpeedChanged,
            ),
          ),
          SizedBox(
            width: 32,
            child: Text(
              _speedLabels[_speedIndex],
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHourLabel(String typeLabel, int forecastHour) {
    final runStart = CmcMapRun.runStartTime();
    final forecastTime = runStart.add(Duration(hours: forecastHour));
    final localTime = forecastTime.toLocal();

    final hour = localTime.hour;
    final amPm = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour == 0
        ? 12
        : hour > 12
            ? hour - 12
            : hour;

    final timeStr = '$displayHour $amPm';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _isPlaying ? Icons.play_arrow : Icons.pause,
            color: Colors.white.withValues(alpha: 0.4),
            size: 14,
          ),
          const SizedBox(width: 6),
          Text(
            '$typeLabel · $timeStr · h+$forecastHour',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Paints the CMC map image scaled to fill the available space,
/// with a crosshair at the user's observatory location.
class _CmcMapPainter extends CustomPainter {
  final ui.Image image;
  final dynamic location;
  final CmcMapType type;
  final String? quadrant;

  _CmcMapPainter({
    required this.image,
    required this.location,
    required this.type,
    this.quadrant,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final imgW = image.width.toDouble();
    final imgH = image.height.toDouble();
    final scaleX = size.width / imgW;
    final scaleY = size.height / imgH;
    final scale = scaleX < scaleY ? scaleX : scaleY;

    final destW = imgW * scale;
    final destH = imgH * scale;
    final dx = (size.width - destW) / 2;
    final dy = (size.height - destH) / 2;

    final src = Rect.fromLTWH(0, 0, imgW, imgH);
    final dst = Rect.fromLTWH(dx, dy, destW, destH);

    canvas.drawImageRect(image, src, dst, Paint());

    // Draw crosshair at user location
    if (location != null) {
      final projection =
          CmcProjections.projectionFor(type, quadrant: quadrant);
      final point = projection.getXY(
          location.latitude as double, location.longitude as double);

      if (point != null && CmcProjection.inBounds(point)) {
        final cx = dx + point.dx * scale;
        final cy = dy + point.dy * scale;
        _drawCrosshair(canvas, cx, cy);
      }
    }
  }

  void _drawCrosshair(Canvas canvas, double cx, double cy) {
    const crossSize = 16.0;
    const gap = 4.0;

    final glowPaint = Paint()
      ..color = const Color(0xFF4FC3F7).withValues(alpha: 0.3)
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(Offset(cx, cy), crossSize * 0.7, glowPaint);

    final linePaint = Paint()
      ..color = const Color(0xFF4FC3F7)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
        Offset(cx - crossSize, cy), Offset(cx - gap, cy), linePaint);
    canvas.drawLine(
        Offset(cx + gap, cy), Offset(cx + crossSize, cy), linePaint);
    canvas.drawLine(
        Offset(cx, cy - crossSize), Offset(cx, cy - gap), linePaint);
    canvas.drawLine(
        Offset(cx, cy + gap), Offset(cx, cy + crossSize), linePaint);

    final dotPaint = Paint()
      ..color = const Color(0xFF4FC3F7)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx, cy), 2.0, dotPaint);
  }

  @override
  bool shouldRepaint(_CmcMapPainter oldDelegate) {
    return oldDelegate.image != image || oldDelegate.location != location;
  }
}

/// Paints the timeline progress bar with cached-frame indicators.
class _TimelinePainter extends CustomPainter {
  final double progress;
  final List<bool> cachedFrames;

  _TimelinePainter({required this.progress, required this.cachedFrames});

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, size.width, size.height),
          const Radius.circular(2)),
      bgPaint,
    );

    // Cached frame dots
    if (cachedFrames.isNotEmpty) {
      final dotPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.15);
      for (int i = 0; i < cachedFrames.length; i++) {
        if (!cachedFrames[i]) continue;
        final x = (i / (cachedFrames.length - 1)) * size.width;
        canvas.drawCircle(Offset(x, size.height / 2), 1.5, dotPaint);
      }
    }

    // Progress indicator
    final progressPaint = Paint()
      ..color = const Color(0xFF4FC3F7);
    final px = progress * size.width;
    canvas.drawCircle(Offset(px, size.height / 2), 3, progressPaint);
  }

  @override
  bool shouldRepaint(_TimelinePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.cachedFrames != cachedFrames;
  }
}
